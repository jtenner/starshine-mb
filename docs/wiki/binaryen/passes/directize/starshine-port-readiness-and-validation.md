---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md
  - ../../../raw/research/0380-2026-04-26-directize-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-directize-primary-sources.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./table-info-and-immutability.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/lib/show.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/typecheck_negative_tests.mbt
  - ../../../../../src/ir/hot_side_tables.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./table-info-and-immutability.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../reorder-globals/index.md
  - ../string-gathering/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine port readiness and validation for `directize`

Use this page after the overview in [`./index.md`](./index.md) and the current Starshine status page in [`./starshine-strategy.md`](./starshine-strategy.md).

The goal here is narrower than either page:

- turn Binaryen's source-backed `directize` contract into a practical first Starshine implementation sequence, and
- give future agents a validation ladder that starts from beginner-friendly reduced shapes and ends at Binaryen oracle comparison.

## Current local status in one sentence

Starshine does not implement `directize` yet; it tracks the pass as boundary-only and rejects active requests, but it already has the table, element, indirect-call, binary, validation, and HOT-roundtrip primitives a faithful module/boundary pass will need.

## Why the first slice is not a peephole

Binaryen's strategy page teaches the crucial ordering:

1. compute module-wide table facts with `TableUtils`,
2. decide whether any table can optimize by entry,
3. walk functions only if the module facts justify it,
4. classify each indirect target as `Known`, `Trap`, or `Unknown`,
5. rewrite only the supported families,
6. refinalize after edits.

That means a Starshine port that begins with only:

```wat
(call_indirect (type $t) ... (i32.const 0))
```

and immediately rewrites to:

```wat
(call $f ...)
```

would be teaching the wrong architecture. The first real local contract is table-entry trust.

## Current Starshine code map

### Pass registry and request behavior

- `src/passes/optimize.mbt:127-136`
  - `pass_registry_boundary_only_names()` includes `"directize"`.
- `src/passes/optimize.mbt:452-470`
  - active requests for boundary-only names return `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.

This is the executable local truth today: known pass name, no transform.

### WAT and lib IR surfaces

- `src/wast/parser.mbt:1874-1885`
  - parses `call_indirect` and `return_call_indirect` with optional table index plus type use.
- `src/wast/lower_to_lib.mbt:1919-1958`
  - lowers WAT indirect-call forms to lib instructions with resolved type and table indices.
- `src/wast/lower_to_lib.mbt:2171-2252`
  - lowers `table.set`, `table.fill`, `table.copy`, and `table.init`, the same mutation-family facts Binaryen uses as barriers.
- `src/lib/types.mbt:198-212`
  - represents active/passive/declarative element segments and element payload forms.
- `src/lib/types.mbt:221`
  - represents table definitions.
- `src/lib/types.mbt:526-531`
  - represents `Call`, `CallIndirect`, `ReturnCall`, `ReturnCallIndirect`, `CallRef`, and `ReturnCallRef` distinctly.
- `src/lib/types.mbt:780-785`
  - represents table mutation instructions relevant to entry trust.

These are enough to write shape tests in Starshine syntax, but not enough to infer table facts yet.

### Binary and text roundtrip surfaces

- `src/binary/decode.mbt:2544-2564`
  - decodes `call_indirect` and `return_call_indirect`.
- `src/binary/decode.mbt:3264-3269`
  - decodes `table.copy`.
- `src/binary/encode.mbt:2008-2028`
  - encodes indirect and tail-indirect call forms.
- `src/lib/show.mbt:866-882`
  - renders indirect and tail-indirect calls.

A future port should keep codec/text tests in the loop for reduced directize cases because the pass changes between direct and indirect call opcodes.

### HOT surfaces that are useful but not sufficient

- `src/ir/hot_side_tables.mbt:249-254`
  - records indirect-call signature/table side data for HOT instructions.
- `src/ir/hot_lower.mbt:993-1018`
  - lowers HOT `CallIndirect` / `ReturnCallIndirect` back to lib instructions.

These surfaces make a HOT-assisted rewrite plausible, but they do not replace Binaryen's module-wide table analysis. Treat them as implementation substrates, not as the pass boundary.

### Validation surfaces

- `src/validate/typecheck.mbt:907-944`
  - typechecks `call_indirect` by resolving a function type, validating a funcref-compatible table, popping the table index, then popping call parameters and pushing results.
- `src/validate/typecheck.mbt:3216-3219`
  - dispatches `CallIndirect` and `ReturnCallIndirect` through the typechecker.
- `src/validate/typecheck_negative_tests.mbt:332-391`
  - covers invalid table index, non-funcref-compatible tables, and tail-call mismatch negatives.

The first pass tests should reuse validation aggressively. Known-trap rewrites and direct-call rewrites both change stack behavior enough that a text-only diff is too weak.

## Recommended first implementation slices

### Slice 0: keep registry honesty green

Before landing the pass, keep the current behavior:

- `directize` remains boundary-only,
- explicit requests still reject,
- the tracker says no transform exists.

The first code change should add failing tests that demonstrate the future pass will become active, not silently reinterpret the current boundary-only status as implementation.

### Slice 1: table facts and no-op proof

Build module-level facts before rewriting any call.

Minimum reduced cases:

- no tables -> no-op,
- flat active funcref table with constant offsets -> entry facts exist,
- imported table in ordinary mode -> entry facts are not trusted,
- exported table in ordinary mode -> entry facts are not trusted,
- `table.set` / `table.fill` / destination `table.copy` / `table.init` -> mutation barrier,
- nonconstant active segment offset -> non-flat bailout,
- non-func element payload -> non-flat or non-callable bailout.

Exit criterion:

- the pass can explain whether a table is entry-optimizable without editing functions.

### Slice 2: target classifier

Add a named classifier with the three Binaryen outcomes:

| Outcome | Meaning | Later rewrite |
| --- | --- | --- |
| `Known` | constant index names a compatible function | direct `call` / `return_call` |
| `Trap` | target is a known hole, out-of-range immutable trap, or wrong type | preserve effects then `unreachable` |
| `Unknown` | target expression or table entry is not provable | leave indirect call unchanged |

Minimum reduced cases:

- known function slot,
- known null / missing slot inside known prefix,
- beyond-known-prefix under mutable-but-initial-immutable assumptions,
- wrong-function-type slot,
- nonconstant target expression,
- wasm64 large index stays width-correct if/when memory64/table64 support is active for the test.

Exit criterion:

- classifier tests pass without yet relying on pretty WAT output.

### Slice 3: constant call rewrites

Rewrite only constant-target `CallIndirect` / `ReturnCallIndirect` after table facts and classification are in place.

Minimum reduced cases:

- direct-call positive,
- tail `return_call_indirect` positive,
- wrong-type target -> `unreachable`,
- known hole -> `unreachable`,
- side-effectful operands survive trap replacement,
- unknown target remains indirect.

Exit criterion:

- every rewritten function validates after the pass.

### Slice 4: supported `select` lowering

Only after constant rewrites are green, add the narrow `call-utils.h`-style `select` family.

Minimum reduced cases:

- two known arms -> `if` of direct calls,
- one known arm and one known-trap arm -> `if` with one `unreachable` arm,
- one unknown arm -> unchanged indirect call,
- unreachable select operand or unreachable select type -> unchanged indirect call,
- operand evaluation happens once via locals or an equivalent local-safe Starshine mechanism.

Exit criterion:

- Starshine output preserves operand side effects and validates.

### Slice 5: option surface and late-tail scheduling

Only after direct `--pass directize` behavior is correct should the pass be wired into the late no-DWARF tail.

Minimum checks:

- decide and document where `directize-initial-contents-immutable` is represented locally,
- preserve the no-DWARF order `string-gathering -> reorder-globals -> directize`,
- ensure `directize` does not incorrectly trigger follow-up inlining or DAE unless an explicit converge-style outer loop is present,
- compare the late tail against Binaryen on targeted fixtures before replaying the debug artifact.

## Binaryen oracle validation ladder

Use the official Binaryen files in this order:

1. `directize_all-features.wast`
   - main direct, trap, imported/exported/mutated, immutable-mode, multi-table, and select families.
2. `directize-gc.wast`
   - subtype compatibility and result-type refinement.
3. `directize-wasm64.wast`
   - full-width table index behavior.
4. no-DWARF late-tail replay
   - verify the neighborhood ending in `reorder-globals -> directize`.
5. generated artifact compare
   - use the `DIR` backlog slice and compare against Binaryen's final-tail output.

## What to avoid

Do not claim parity if the implementation only handles constant-index happy paths.
That would miss the source-backed correctness core:

- ordinary imported/exported/mutated-table conservatism,
- initial-contents immutability as a narrower opt-in,
- hole versus beyond-known-prefix,
- wrong-type targets as known traps,
- side-effect preservation before `unreachable`,
- refinalization / validation after edits,
- unsupported `select` and nonconstant target bailouts.

Do not fold `call_ref` into this pass. Binaryen's `directize` source does not do that.
If Starshine later wants `call_ref` directization, document it as a separate local extension or a different upstream parity target.

## Open questions before implementation

- Should Starshine land `directize` as a pure module pass over `@lib.Module`, or as module facts plus a HOT rewrite phase?
- Where should the pass argument for immutable initial contents be exposed?
- What shared type-repair helper should own post-rewrite validation / refinalization equivalents for boundary passes?
- Should table-info construction become reusable infrastructure for future table-layout or call-target passes?

## Bottom line

The pass is now port-ready from a documentation standpoint:

- Binaryen's strategy is source-backed,
- transformed shapes are cataloged,
- Starshine's current non-implementation is explicit,
- local code surfaces are mapped,
- and the implementation can start with table facts, then target classification, then rewrites, instead of guessing from the short public pass summary.
