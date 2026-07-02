---
kind: raw-source
status: supported
last_reviewed: 2026-07-02
source_type: primary-source-manifest
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/ReorderLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/reorder-locals.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/reorder-locals.txt
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/reorder-locals_print_roundtrip.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/reorder-locals_print_roundtrip.txt
  - ../../../binaryen/passes/reorder-locals/index.md
  - ../../../binaryen/passes/reorder-locals/binaryen-strategy.md
  - ../../../binaryen/passes/reorder-locals/parity.md
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
---

# Binaryen `reorder-locals` `version_130` source refresh

## Capture purpose

This manifest records the first O4Z `[O4Z-AUDIT-RL]` source-inventory slice for `reorder-locals` against the current local Binaryen oracle. The local workspace reports:

```text
wasm-opt version 130 (version_130)
```

The reviewed primary-source files were downloaded from the official `version_130` tag into `.tmp/rl-v130/` for local diff/review only. The `.tmp` copies are not normative repo content.

## Primary sources checked

Official Binaryen `version_130` sources:

- `src/passes/ReorderLocals.cpp`
- `src/passes/pass.cpp`
- `test/passes/reorder-locals.wast`
- `test/passes/reorder-locals.txt`
- `test/passes/reorder-locals_print_roundtrip.wast`
- `test/passes/reorder-locals_print_roundtrip.txt`

Local Starshine sources/docs checked in this slice:

- `src/passes/reorder_locals.mbt`
- `src/passes/reorder_locals_test.mbt`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `docs/wiki/binaryen/passes/reorder-locals/`
- `agent-todo.md` `[O4Z-AUDIT-RL]`

## Source comparison result

The downloaded `version_130` `ReorderLocals.cpp` and the two dedicated lit input/output pairs are byte-identical to the previously reviewed `version_129` copies:

```text
ReorderLocals.cpp: no diff against version_129
reorder-locals.wast: no diff against version_129
reorder-locals.txt: no diff against version_129
reorder-locals_print_roundtrip.wast: no diff against version_129
reorder-locals_print_roundtrip.txt: no diff against version_129
```

`version_130` `pass.cpp` still registers `reorder-locals` with the public summary `sorts locals by access frequency` and still schedules three no-DWARF function-pipeline slots: after `simplify-locals-nostructure -> vacuum`, after `simplify-locals -> vacuum`, and after the later `coalesce-locals` before final `vacuum`.

## Transform-family inventory

The `version_130` owner and lit surface continues to define these relevant families:

| Family | Binaryen `version_130` source/lit surface | Current Starshine status after source inventory |
| --- | --- | --- |
| Params-only no-op | `ReorderLocals.cpp` returns when `getNumVars() == 0`; lit covers param stability. | Covered by `reorder_locals_test.mbt` params-only and multi-defined-function tests. |
| Access counting | `visitLocalGet` and `visitLocalSet` increment counts; tee traffic is represented as `LocalSet` in Binaryen IR. | Covered by Starshine explicit `LocalGet`, `LocalSet`, and separate `LocalTee` scan/rewrite tests. |
| Body-local sorting | Comparator keeps params first, sorts body locals by descending count, breaks nonzero ties by first observed use, and zero-count ties by old index. | Covered by access-count/first-use and materialized carrier fixtures; no new `version_130` drift found. |
| Zero-count truncation | Rebuilt `vars` stops at first zero-count body-local after sorting, dropping the entire zero-count suffix. | Covered by unused trailing-local trim and write-only/tee-only survival tests; future audit still needs generated-profile exercise. |
| Local-user reindex | Nested `ReIndexer` rewrites all `LocalGet` / `LocalSet` nodes wherever they occur. | Starshine recursively rewrites boundary instructions through blocks, loops, `if`, and `try_table`; tests cover nested bodies. |
| Local-name repair | `localNames` and `localIndices` are rebuilt over kept `newToOld`; print-roundtrip lit files prove declaration/name visibility. | Starshine rewrites local-name maps, preserves imported-function names, and clears stale raw name-section payloads; tests and CLI roundtrip cover this surface. |
| No non-nullable fixups / no heavy analyses | `requiresNonNullableLocalFixups() == false`; pass does not use CFG, LocalGraph, effects, liveness, dominance, or refinalization. | Starshine keeps this as a module-level local table/name repair pass; no HOT analysis requirement is implied. |
| Multivalue scratch locals / writer boundary | Not owned by `ReorderLocals.cpp`; previous dossier points to Binaryen writer/IR-builder layers for scratch-local drift. | Still a documented boundary decision, not a sorter gap; O4Z audit should only reopen it with fresh failing evidence. |
| Scheduler repetition | `pass.cpp` no-DWARF function pipeline schedules three `reorder-locals` slots. | Starshine public presets currently claim one tuple/no-structure lane; extra slots remain ordered-neighborhood work, not direct pass algorithm drift. |

## O4Z audit implications

- The Binaryen algorithm contract did not drift from the previously documented `version_129` story under the current local `version_130` oracle.
- The active O4Z audit should therefore focus on fresh evidence rather than algorithm rediscovery: dedicated GenValid profile coverage, current 4-lane compare evidence, TypeIdx invariant inline/doc closure, pass-local timing, and ordered `RL` slot evidence.
- Existing docs that still say the primary oracle is `version_129` should be read as superseded for new O4Z audit work by this `version_130` refresh, while retaining the older manifests as provenance.
