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
- non-constant `eqz` / compare-to-zero rewrites and relational constant canonicalization
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
- relational operand canonicalization
- relational-constant normalization

This is the part of the implementation that most closely matches the mental model most readers start with.

### 2. Commutative canonicalization with HOT-specific safety proof

The local file has explicit machinery for:

- moving constants to the preferred side
- sorting local gets and some node kinds conservatively
- refusing reordering across same-local writes, shared tee payloads, trapping loads, and loop-carried inputs

That matches the upstream strategy of canonicalize-first, but the proof substrate is local-HOT-specific.

### 3. Add / sub / mul / shift rewrites

The in-tree HOT pass includes helpers for:

- add/sub normalization
- multiply-by-power-of-two to shift rewrites
- redundant shift-mask removal
- effective-zero shift cleanup
- compare-to-zero reductions

So Starshine already covers a meaningful subset of the arithmetic rewrite surface.

### 4. Boolean and nested-`if` cleanup

The local file goes fairly deep on HOT-IR boolean and control patterns.
It can:

- optimize `if` conditions directly
- fold constant conditions
- recursively negate nested boolean trees
- wrap certain boolean value-`if`s in `eqz`
- flip some nested conditions when the tree is unshared
- collapse duplicate then-branch `if`s into a direct branch

### 5. Artifact-backed dead-suffix and fallback-branch cleanup

The current local pass includes logic for:

- truncating dead suffixes after escaping control
- preserving value-carrying fallback branches in mixed-label and nested-return shapes
- keeping explicit zero sentinels when the result carrier still flows to a `drop` or another value-preserving boundary

Those are local HOT-IR and writeback-survival rules, not a literal upstream phase mirror.

## What upstream Binaryen still does that Starshine lacks

The local pass does not yet model the upstream visitor families for:

- broad reference-typed and GC rewrites
- `call_ref` directization families
- broader memory and bulk-memory lowering
- tuple extraction parity
- a whole-function local prescan equivalent
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
