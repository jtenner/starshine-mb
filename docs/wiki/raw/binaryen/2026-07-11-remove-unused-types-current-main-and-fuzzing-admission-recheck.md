# Binaryen `remove-unused-types` current-main and Starshine fuzz-admission recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable source and local-admission bridge for the `docs/wiki/binaryen/passes/remove-unused-types/` dossier

## Scope

This bridge rechecks two independent maintenance boundaries that must not be conflated:

1. Binaryen's current-`main` owner and helper interface for `remove-unused-types`.
2. Whether Starshine can currently run a `compare-pass` oracle lane for that spelling.

The first is upstream transform evidence. The second is local tooling/registry evidence. A real upstream Binaryen pass does **not** make a Starshine compare-pass command runnable.

## Official primary sources consulted

- `src/passes/RemoveUnusedTypes.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedTypes.cpp>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedTypes.cpp>
- `src/passes/pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `src/ir/type-updating.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h>
- `src/ir/module-utils.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h>
- `test/lit/passes/remove-unused-types.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-types.wast>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-types.wast>

## Current-main observation: wrapper interface drift

The previous 2026-05-05 bridge says that `RemoveUnusedTypes.cpp` rejects open-world execution itself and then calls `GlobalTypeRewriter(*module).update()`.

The current owner instead constructs the helper with pass options' world mode:

```cpp
GlobalTypeRewriter(*module, getPassOptions().worldMode).update();
```

That is a behavior-relevant interface change from the older living wording. This focused reread does **not** establish the new full open-world semantic policy: that requires reading the current `GlobalTypeRewriter` world-mode branches and relevant fixtures as one unit. Until that review is filed into the living pages, do not repeat the old categorical claim that the wrapper itself fatally rejects every open-world execution.

The durable parts that remain supported by the reviewed owner/helper/test surface are narrower:

- the pass remains a small wrapper around `GlobalTypeRewriter`, rather than a pass-local type scanner or builder;
- the pass remains a GC/type-graph rewrite, not an expression peephole;
- the helper/type-updating and dedicated lit surfaces remain necessary to explain survivor collection, visibility, rebuild, and module-wide remapping;
- the older correction against preserving an entire old private rec group merely because one member is live remains the current teaching baseline unless a later helper review disproves it.

## Local compare-pass admission recheck

The live local sources are authoritative for whether a copyable command can run today:

- `scripts/lib/pass-fuzz-compare-task.ts`
  - `SUPPORTED_PASS_FLAGS` is the harness allowlist;
  - argument normalization rejects a requested pass absent from that set before generation or either optimizer runs.
- `src/passes/optimize.mbt`
  - `remove-unused-types` remains in `pass_registry_boundary_only_names()`;
  - boundary-only requests are deliberately rejected rather than dispatched to a transform.

`remove-unused-types` is absent from `SUPPORTED_PASS_FLAGS`, and no active local owner exists. Therefore this is **not** a runnable `bun fuzz compare-pass --pass remove-unused-types ...` lane. An older `fuzzing.md` that prints a 10,000-case command is stale: that command fails admission before it provides Binaryen-parity evidence.

## Correct current documentation posture

Until both gates change, the living fuzzing page must say:

- **planned-only**, not runnable smoke lane;
- `bun fuzz compare-pass --list-passes` is safe status inspection, not oracle evidence for this pass;
- a future lane needs all four general gates documented in `docs/wiki/tooling/pass-fuzz-compare.md`:
  1. harness allowlist admission,
  2. active Starshine registry/dispatcher admission,
  3. Binaryen public-flag mapping,
  4. a generator/profile that reaches the closed-world GC type-graph surface with a meaningful compared-case threshold;
- targeted `wasm-opt --closed-world --remove-unused-types` fixtures remain suitable upstream-oracle preparation, but are not a substitute for an active Starshine pass.

## Follow-up and uncertainty

- The upstream world-mode constructor change is a **freshness warning**, not a completed semantic reclassification. A future living-page update must reconcile `RemoveUnusedTypes.cpp`, the current `GlobalTypeRewriter` world-mode logic, scheduler options, and the dedicated lit fixture before changing claims about open-world behavior.
- The compare-pass correction is high confidence and needs no external-source inference: it follows directly from the current local harness allowlist and boundary-only registry.
- This raw bridge was added while unrelated in-progress edits already occupied the live dossier catalog and audit log. It intentionally does not modify those contested files. The next owner of that work should link this bridge from the dossier, refresh the affected `last_reviewed` metadata, correct `fuzzing.md`, and append the normal `docs/wiki/log.md` entry in the same atomic wiki change.

## Related local evidence

- [`../../tooling/pass-fuzz-compare.md`](../../tooling/pass-fuzz-compare.md)
- [`../../binaryen/passes/remove-unused-types/index.md`](../../binaryen/passes/remove-unused-types/index.md)
- [`../../binaryen/passes/remove-unused-types/fuzzing.md`](../../binaryen/passes/remove-unused-types/fuzzing.md)
- [`../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../scripts/lib/pass-fuzz-compare-task.ts)
- [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
