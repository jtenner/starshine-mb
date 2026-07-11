# Binaryen `mark-js-called` / `remove-exports` Current-Main Recheck

Capture date: 2026-07-11

Purpose: refresh the two small Binaryen `version_130` pass dossiers whose last current-`main` behavior check was 2026-06-04. This is a source reconciliation, not a Starshine implementation change.

## Primary Sources Rechecked

- `version_130` `MarkJSCalled.cpp`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/MarkJSCalled.cpp>
- current `main` `MarkJSCalled.cpp`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MarkJSCalled.cpp>
- `version_130` `mark-js-called.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/mark-js-called.wast>
- current `main` `mark-js-called.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/mark-js-called.wast>
- `version_130` `RemoveExports.cpp`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/RemoveExports.cpp>
- current `main` `RemoveExports.cpp`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveExports.cpp>
- `version_130` `remove-exports.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/remove-exports.wast>
- current `main` `remove-exports.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-exports.wast>
- current `main` pass registration: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>

## Findings

### `mark-js-called`

- The current owner remains a `Pass` that first checks for a `configureAll` intrinsic. With no such intrinsic it does nothing.
- When present, it runs a parallel analysis over defined functions, recognizes `configureAll` calls, and marks every referred target with the `jsCalled` function-annotation bit.
- The explicit owner-file scheduling comment remains important: intrinsic processing already handles a `configureAll` use in the start function; this pass finds other uses, such as calls from an exported entry point.
- The current fixture still covers both the ordinary configured-target result and the start-function interaction. No current-main behavior-bearing drift was found relative to the reviewed `version_130` owner/fixture contract.
- The pass remains metadata synthesis. It does not rewrite calls, exports, ABI wrappers, or function signatures.

### `remove-exports`

- Current `main` still exposes a parameterized export-list filter, registered as `remove-exports`.
- It reads the supplied pattern string, supports response-file expansion, accepts newline/comma-separated patterns, expands Binaryen bracketing operators, wildcard-matches export names, and removes only matching `Export` entries.
- The current fixture still demonstrates `__*` removal for function plus memory/table exports while the corresponding definitions remain. No current-main behavior-bearing drift was found relative to the reviewed `version_130` owner/fixture contract.
- The pass does not delete definitions, change function/table/memory/global/tag index spaces, or substitute for liveness cleanup. Removing an export remains an observable host-ABI change.

## Starshine Reconciliation

Focused local searches on 2026-07-11 still found no `mark-js-called`, `MarkJSCalled`, `remove-exports`, or `RemoveExports` spelling under `src/`:

- `mark-js-called` remains **upstream-only / local-unknown**. Starshine can carry an existing `(@binaryen.js.called)` through the WAST-to-`FuncAnnotationSec` path, but that is not configureAll-driven annotation synthesis.
- `remove-exports` remains **upstream-only / local-unknown**. Starshine has `ExportSec` plus normal binary/WAST/validation handling, but no direct pass has an approved policy for removing host-visible exports.

The June 2026 captures remain useful historical source reads. This note supersedes them only for unqualified current-`main` freshness claims about these two pass owner/test/registration surfaces.

## Wiki Consequences

- Refresh the two landing pages, pass catalog/tracker rows, and their concept-page backlinks to cite this 2026-07-11 recheck rather than presenting the 2026-06-04 current-main check as current.
- Preserve the two distinct implementation boundaries: configureAll recognition before `js.called` synthesis, and explicit host-ABI policy before export filtering.
- Do not add a Starshine registry spelling or compare-pass command from this source refresh alone.
