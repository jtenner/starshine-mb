# Binaryen `inlining-optimizing` current-main implementation/test-map capture

_Capture date:_ 2026-04-25  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/inlining-optimizing/` dossier

## Scope

This file captures the primary online sources rechecked while adding the missing `inlining-optimizing` implementation/test-map page.
It is provenance-heavy on purpose. Use the living pages for explanation:

- `docs/wiki/binaryen/passes/inlining-optimizing/index.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/planning-partial-inlining-and-reruns.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/inlining-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/inlining/index.md`
- `docs/wiki/binaryen/passes/inlining/implementation-structure-and-tests.md`

## Provenance

### Official release and current source surfaces consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Retained as the tagged source oracle for this dossier.
- Binaryen `main` `Inlining.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Inlining.cpp>
  - Rechecked for the shared inliner engine, `FunctionInfo` scan, direct-call planner surface, rewrite/update helper, partial splitter integration, and optimizing-mode orchestration.
- Binaryen `version_129` `Inlining.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
  - Retained as the tagged comparison target for the same implementation surface.
- Binaryen `main` `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Rechecked for public registration of `inlining`, `inlining-optimizing`, `inline-main`, and no-inline helper passes, plus the late post-pass placement of `inlining-optimizing`.
- Binaryen `version_129` `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `main` `opt-utils.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - Rechecked for `optimizeAfterInlining(...)` / useful-pass-after-inlining behavior: prepend `precompute-propagate`, then rerun the default function optimization pass set on the changed-function filter.
- Binaryen `version_129` `opt-utils.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `main` `pass.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
  - Rechecked for default inlining heuristic knobs.
- Binaryen `version_129` `pass.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- Binaryen `main` `NoInline.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/NoInline.cpp>
  - Rechecked for the separate `no-inline` / `no-full-inline` / `no-partial-inline` flag-setting helpers that feed the shared inliner.
- Binaryen `version_129` `NoInline.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/NoInline.cpp>
- Binaryen `main` `module-utils.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>
  - Rechecked for cloned-function preservation of inlining policy flags.
- Binaryen `version_129` `module-utils.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>

### Official test files consulted

- `test/lit/passes/inlining.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining.wast>
- `test/lit/passes/inlining_optimize-level=3.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_optimize-level=3.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_optimize-level=3.wast>
- `test/lit/passes/inlining_enable-tail-call.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_enable-tail-call.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_enable-tail-call.wast>
- `test/lit/passes/inlining_splitting.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_splitting.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting.wast>
- `test/lit/passes/inlining_splitting_basics.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining_splitting_basics.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting_basics.wast>
- `test/lit/passes/inlining-trivial-instructions.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-trivial-instructions.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-instructions.wast>
- `test/lit/passes/inlining-trivial-calls-1.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-trivial-calls-1.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-calls-1.wast>
- `test/lit/passes/inlining-unreachable.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-unreachable.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-unreachable.wast>
- `test/lit/passes/inlining-gc.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inlining-gc.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-gc.wast>
- `test/lit/passes/no-inline.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline.wast>
- `test/lit/passes/no-inline-monomorphize-inlining.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/no-inline-monomorphize-inlining.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
- `test/lit/passes/inline-main.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inline-main.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>

## Durable observations from this source bridge

- The implementation owner remains the shared `Inlining.cpp` engine. `inlining-optimizing` is still best documented as the same inliner as plain `inlining` with the optimizing helper enabled, not as a separate algorithm.
- The current-main spot check did not surface teaching-relevant drift from the dossier's `version_129` contract: chosen inline actions remain source-backed as a direct `call` / `return_call` planning surface; `call_ref` / `call_indirect` families still matter in copied-body repair, roots, and surrounding helpers rather than as a broad generic selected-callsite planner.
- The source/test split is important: most lit files are shared with plain `inlining`; the optimizing variant's unique public obligation is the filtered post-inline rerun through `opt-utils.h`, which is only indirectly visible in ordinary WAT diffs.
- `NoInline.cpp`, inline policy flag cloning in `module-utils.cpp`, and the `no-inline*` tests are still part of the real proof surface because they constrain whether the shared inliner can act before the optimizing rerun ever matters.
- No contradiction was found between the 2026-04-23 raw manifest and this 2026-04-25 implementation/test-map bridge. The new value is owner/test-map precision and current-main freshness, not a strategy correction.

## Consumability rule

Cite this raw bridge when a page needs current-main implementation/test-map provenance.
For the actual explanation, point readers at `docs/wiki/binaryen/passes/inlining-optimizing/implementation-structure-and-tests.md` and the existing strategy/shape/Starshine pages.
