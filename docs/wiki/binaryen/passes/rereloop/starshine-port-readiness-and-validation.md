---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md
  - ../../../raw/research/0484-2026-05-05-rereloop-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md
  - ../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-cfg-builder-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../flatten/index.md
  - ../merge-blocks/index.md
  - ../simplify-locals-nonesting/index.md
  - ../dataflow-optimization/index.md
---

# Starshine port readiness and validation for `rereloop`

This page is the bridge between the upstream source-backed `rereloop` contract and a future Starshine port.
It does **not** claim an implementation.
It says what is already in-tree, what the nearest landing zone is, and what should be proven first once work starts.

For the exact upstream algorithm and source/test map, read:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./flat-cfg-builder-and-boundaries.md`](./flat-cfg-builder-and-boundaries.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)

## Current readiness status

Starshine still treats `re-reloop` as **removed**.
There is no owner file, no dispatcher case, and no active backlog slice yet.

That is the honest state to keep until the missing neighbors exist and the first real transform lands.

## What already exists locally

The nearest local surfaces are:

| Surface | Why it matters |
| --- | --- |
| `src/passes/optimize.mbt` | Keeps `re-reloop` in the removed registry, preserves the known pass spelling, and blocks active requests cleanly. |
| `src/passes/pass_manager.mbt` | Has no `re-reloop` dispatcher case, so no transform can run by accident. |
| `src/cli/cli_test.mbt` | Proves the CLI parser still accepts `--re-reloop` as a known removed spelling. |
| `src/cmd/cmd_wbtest.mbt` | Proves command execution rejects `--re-reloop` and keeps the help surface hidden. |
| `src/passes/optimize_test.mbt` | Keeps the flatten-era aggressive neighborhood gate honest while the pass remains removed. |
| `src/passes/merge_blocks.mbt` | Nearest landed structured-control cleanup surface. |
| `src/passes/simplify_locals.mbt` | Nearest landed local-traffic cleanup surface. |
| `src/passes/reorder_locals.mbt` | Nearest landed local-index rewrite surface. |
| `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` | Documents the current no-DWARF boundary where `rereloop` still does not participate. |
| `agent-todo.md` | Holds the active pass backlog, and it currently has no dedicated `rereloop` slice. |

For the exact local code-map anchors, see [`./starshine-strategy.md`](./starshine-strategy.md).

## What a faithful first slice must prove

1. **Flatness precondition**
   - reject or preclude non-flat value-carrying bodies
   - accept only the flat control forms that `ReReloop.cpp` actually handles
2. **CFG reconstruction**
   - build named-block join targets
   - build named-loop backedges
   - lower `if` and `br_table` in the same source-backed way Binaryen does
3. **Renderer honesty**
   - allocate the helper `i32` label local or an equivalent explicit renderer state
   - emit dead-end terminators before render
   - repair apparent result fallthroughs with `unreachable`
4. **Cleanup compatibility**
   - preserve the existing interactions with `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, and `vacuum`

## Validation ladder

Start small and stay honest about the missing neighbors.

### 1. Shape tests first

Add focused tests for the source-backed families in [`./wat-shapes.md`](./wat-shapes.md):

- flat `if` rebuilds
- skip-empty ladders
- grouped `br_table` restructuring
- helper-label boilerplate
- dead-end terminator repair
- result-typed `unreachable` repair
- EH rejection
- non-flat rejection

### 2. Registry and CLI proof

Before any optimizer-slot claim, prove that:

- the pass name is still tracked as removed
- explicit `--re-reloop` requests fail cleanly
- the current catalog text still points at the real implementation gap
- the flatten-era neighborhood gate stays false in the local regression surface

### 3. Pass-targeted parity

Once active code exists, sign off with pass-targeted fuzz compare against Binaryen on the canonical pass spelling.

### 4. Neighborhood replay

Only after the adjacent local cleanup neighbors are represented locally should the no-DWARF neighborhood replay claim be made.
That means the validation story should stay conservative until the `flatten -> simplify-locals-notee-nostructure -> rereloop` and `coalesce-locals -> rereloop -> simplify-locals` slots are actually testable end to end.

## Bottom line

`rereloop` is still documentation plus port planning.
The current repo already has nearby structured-control, local-cleanup, and local-index machinery that a future port will need, but it does not yet have the pass itself.
Keep this page as the implementation-readiness bridge until that changes.
