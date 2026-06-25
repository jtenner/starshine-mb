---
kind: concept
status: supported
last_reviewed: 2026-06-19
sources:
  - ../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/research/0444-2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md
  - ../../../raw/research/0858-2026-06-25-optimize-instructions-oi-g-parameterized-memory-copy.md
  - ../../../raw/research/0859-2026-06-25-optimize-instructions-oi-m-tuple-optimization-boundary.md
  - ../../../raw/research/0860-2026-06-25-optimize-instructions-oi-g-mixed-parameterized-memory-copy.md
  - ../../../raw/research/0861-2026-06-25-optimize-instructions-oi-g-parameterized-byte-fill.md
  - ../../../raw/research/0862-2026-06-25-optimize-instructions-oi-g-multiparam-bulk-memory.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
---

# Current Starshine `optimize-instructions` strategy

This page is the local strategy overview.
For the exact helper walk and finer-grained code map, use [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).

## Short version

Current Starshine `src/passes/optimize_instructions.mbt` is a real HOT pass, but it is still narrower than Binaryen `OptimizeInstructions.cpp`. The `[O4Z-AUDIT-OI-A]` `version_130` matrix now makes that gap actionable by assigning each upstream source/lit family to current coverage, an explicit local boundary, or a follow-up slice.

The implemented center of gravity is:

- exact binary constant folding
- non-constant `eqz` / compare-to-zero rewrites, same-local integer compare and binary operand folding, pure and effect-preserving i32/i64 masked unsigned-compare folds plus first pure/effect-preserving i32/i64 `shr_u` bounded unsigned-compare folds, and relational constant canonicalization
- commutative operand ordering with HOT use-def safety guards
- add/sub/mul/shift rewrites
- constant-`if` folding
- nested boolean-`if` normalization and `eqz` wrapping
- duplicate-branch collapse in then-regions
- dead-region-suffix cleanup with explicit fallback-branch and zero-sentinel preservation

That is a meaningful implemented pass.
But it is not yet the full upstream AST surface.

## Exact local code map

| Surface | Exact code location |
| --- | --- |
| registry descriptor and public summary | `src/passes/optimize.mbt:189-191` |
| hot-preset placement | `src/passes/optimize.mbt:288-303`, `src/passes/optimize.mbt:442-461` |
| hot-pipeline dispatch | `src/passes/pass_manager.mbt:8989` |
| owner file and main entry | `src/passes/optimize_instructions.mbt:2-16`, `src/passes/optimize_instructions.mbt:30-31`, `src/passes/optimize_instructions.mbt:3239-3248` |
| focused reduced-pass tests | `src/passes/optimize_instructions_test.mbt:2`, `src/passes/optimize_instructions_test.mbt:83`, `src/passes/optimize_instructions_test.mbt:135`, `src/passes/optimize_instructions_test.mbt:1338`, `src/passes/optimize_instructions_test.mbt:1971` |
| registry sanity | `src/passes/registry_test.mbt:20`, `src/passes/registry_test.mbt:168`, `src/passes/registry_test.mbt:203-215` |
| CLI replay coverage | `src/cmd/cmd_wbtest.mbt:6720-6755`, `src/cmd/cmd_wbtest.mbt:6765-6864`, `src/cmd/cmd_wbtest.mbt:6870-6908` |

The exact code map is the practical read-along path for the current local implementation.

## What the local pass already models well

### 1. Exact integer and compare peepholes

The local file has dedicated helpers for:

- exact constant folding of binary ops
- `eqz` rewrites such as subtraction/addition compare lowering while intentionally preserving literal-constant `eqz` nodes to match Binaryen's direct pass output
- compare-to-zero rewrites
- same-local integer compare folding plus direct same-local integer binary folds for `sub`/`xor` to zero and `and`/`or` to the local value
- pure and effect-preserving i32/i64 masked unsigned-compare folding when an `and` with a nonnegative mask proves the value is below an out-of-range constant, first recursive i32/i64 `shr_u` bounded unsigned-compare folds for constant shift amounts `1..31` / `1..63`, carrying direct child `and`/`shr_u` maxBits facts and dropping effectful masked/shifted values before the replacement constant, plus first direct i32 sign-extension equality range folds for `i32.extend8_s` / `i32.extend16_s`
- relational operand canonicalization
- relational-constant normalization

This is the part of the implementation that most closely matches the mental model most readers start with.

### 2. Commutative canonicalization with HOT-specific safety proof

The local file has explicit machinery for:

- moving constants to the preferred side
- sorting local gets and some node kinds conservatively
- refusing reordering across same-local writes, shared tee payloads, trapping loads, and loop-carried inputs

That matches the upstream strategy of canonicalize-first, but the proof substrate is local-HOT-specific. The general commutative canonicalizer is live for ranked HOT value nodes, including call / indirect-call / call_ref value operands, and uses the same sound reorder proof (`optimize_instructions_subtrees_can_swap`) exercised by the leading `(0 - x) + y -> y - x` rewrite (see section 3). Calls rank before locals/constants to match Binaryen's call-first spelling, but memory/table/global/local conflicts and may-trap-past-side-effect hazards still block the swap. The public/raw pipeline now admits the narrow straight-line stack form `pure local.get/const; no-param direct call; commutative integer binop` so simple call-operand fixtures reach this HOT path; broader stack-carried effects still skip.

### 3. Add / sub / mul / shift rewrites

The in-tree HOT pass includes helpers for:

- add/sub normalization
- multiply-by-power-of-two to shift rewrites
- redundant shift-mask removal
- effective-zero shift cleanup
- compare-to-zero reductions

The leading `(0 - x) + y -> y - x` rewrite (i32/i64) reorders the two operands and is therefore gated by the sound `subtrees_can_swap` reorder proof (no RAW/WAR/WAW region conflict, no may-trap/throw past a side effect, no control-flow operands); the trailing `y + (0 - x) -> y - x` needs no guard. The sibling `-x * -y -> x * y` (i32/i64) strips both negations in place, so it needs no reorder proof and applies even for effectful factors such as `(0 - call) * (0 - y)`.

So Starshine already covers a meaningful subset of the arithmetic rewrite surface.

### 4. Memory and stored-value cleanup

The local pass covers the small Binaryen-style memory surface that has direct HOT support: tiny `memory.copy` / `memory.fill` lowering for selected constant sizes, including flat stack-carried tiny `memory.copy` and byte `memory.fill` forms whose operands may independently be local/constant operands, no-param direct-call operands, or direct calls with pure local/constant arguments, and mixed flat tiny-copy/byte-fill functions when every bulk operation matches the narrow size rules. It also covers constant-pointer static-offset folding (including the narrow public `i32.const; nonzero-offset scalar load; drop; call` raw-gate escape), narrow-store redundant-mask and constant truncation cleanup, direct `i32.wrap_i64` store widening with source memargs preserved, direct reinterpret-store representation rewrites such as `f32.store(f32.reinterpret_i32 x)` to `i32.store x` with source memargs preserved, one-use full-width reinterpret-load result rewrites such as `f32.reinterpret_i32(i32.load p)` to `f32.load p`, and one-use `i64.extend_i32_*` load-result rewrites such as `i64.extend_i32_u(i32.load p)` to `i64.load32_u p`. The representation-load rewrites preserve the original load memarg offset and alignment.

Broader memory work remains deliberately open or boundary-tested: zero-size bulk-memory cleanup needs trap-relaxed mode support, non-flat or broader effect/control `memory.copy` localization remains open beyond the covered pure-argument direct-call address/value subsets and their source-backed mixed combinations, nonconstant-pointer load/drop/call shapes such as `local.get; i32.load offset=4; drop; call` are source-backed keep-spelling boundaries and broader mixed load/call functions still stop at the public raw gate, non-local wider `memory.fill` values such as calls or computed `i32.add` values are source-backed keep-spelling boundaries rather than missing materialization (size-1 byte fills, including pure-argument direct-call subsets, are the covered store8 exception), local-carried/shared load-result spellings such as `local.tee(i32.load)` plus reinterpret or extend are source-backed boundaries rather than direct one-use load-result gaps, local-carried/shared reinterpret-store spellings such as `local.tee(f32.reinterpret_i32(...))` or `local.set`/`local.get` before `f32.store` are source-backed boundaries rather than direct one-use stored-value gaps, and local-carried/shared `i32.wrap_i64` values before narrow i32 stores are source-backed keep-spelling boundaries rather than hidden broader store-widening parity.

### 5. Boolean and nested-`if` cleanup

The local file goes fairly deep on HOT-IR boolean and control patterns.
It can:

- optimize `if` conditions directly
- fold constant conditions
- recursively negate nested boolean trees
- wrap certain boolean value-`if`s in `eqz`
- flip some nested conditions when the tree is unshared
- collapse duplicate then-branch `if`s into a direct branch

### 6. Artifact-backed dead-suffix and fallback-branch cleanup

The current local pass includes logic for:

- truncating dead suffixes after escaping control
- preserving value-carrying fallback branches in mixed-label and nested-return shapes
- keeping explicit zero sentinels when the result carrier still flows to a `drop` or another value-preserving boundary

Those are local HOT-IR and writeback-survival rules, not a literal upstream phase mirror.

## What upstream Binaryen still does that Starshine lacks

The local pass does not yet model the upstream visitor families for:

- broad reference-typed and GC rewrites beyond the many narrow OI-I/OI-K subsets already covered
- GC aggregate RMW/cmpxchg lowering: Starshine exposes `struct.atomic.get*` but not aggregate RMW/cmpxchg text/core constructors, while Binaryen optimizes source-backed non-mutating RMW/cmpxchg forms to `struct.get`-like reads
- `call_ref` directization families beyond the covered direct/ref.func, constant-index and call-indexed table.get, select, and fallthrough-known subsets with zero arguments or localized single-result arguments; multi-result argument select-of-`ref.func` directization is now a documented tuple-scratch localization boundary for both `call_ref` and `return_call_ref`
- broader memory and bulk-memory lowering beyond the covered tiny-copy/fill, stored-value, load-result, offset-fold, and narrow raw-gate escapes
- tuple extraction parity beyond the one-use tuple.make subset with pure siblings or covered single-result effectful sibling drop/localization; the covered single-result effectful-sibling localization now has first `simplify-locals-nostructure` neighbor coverage, full `simplify-locals` and dedicated `tuple-optimization` on the public multivalue-block probe are documented boundaries because Binaryen uses tuple scratch while Starshine keeps the block/drop spelling, direct-HOT replay of the full-simplify shape currently hits `InvalidChildRef`, local-carried / multi-use tuple extraction is a documented keep-spelling boundary for the probed Binaryen `version_130` shape, and multi-result non-selected siblings plus multi-result selected children, including the selected-second lane, remain documented tuple-scratch localization boundaries
- a whole-function local prescan equivalent beyond the narrow fallthrough sign facts and direct sign-extension equality range folds
- deferred `ReFinalize` / EH-pop repair inside this pass

The 2026-06-19 `version_130` matrix routes those gaps to `[O4Z-AUDIT-OI-D]` through `[O4Z-AUDIT-OI-M]`, with `[O4Z-AUDIT-OI-N]` reserved for final direct/O4z closeout. That gap is intentional and documented so readers do not mistake the current local pass for a full upstream port.

## How to read this with the rest of the folder

- [`./index.md`](./index.md) explains the overall pass role and page map.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) explains the upstream Binaryen contract.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) maps the owning files and proof surfaces.
- [`./gc-casts-call_ref-and-trap-sensitive-rewrites.md`](./gc-casts-call_ref-and-trap-sensitive-rewrites.md) covers the upstream reference-typed half that the current local pass does not model.
- [`./wat-shapes.md`](./wat-shapes.md) gives the beginner-friendly shape catalog.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) is the exact MoonBit helper/code-map companion.

## Validation guidance

The current local evidence surface is:

- focused WAT tests for the exact families listed above,
- registry and explicit-pass CLI tests proving `optimize-instructions` remains active,
- repeated-pass replay coverage on the debug artifact and ordered generated-artifact predecessors, and
- pass-targeted fuzz comparison when the implementation changes.

That is enough to keep the current HOT subset honest while preserving the distinction between local reality and upstream Binaryen's wider pass contract.
