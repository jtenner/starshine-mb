# 0445 — 2026-05-05 — asyncify current-main recheck

## Question

Did Binaryen's current-main `asyncify` surface drift in a way that changes the living dossier?

## Sources reviewed

- `src/passes/Asyncify.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/asyncify.wast`
- Emscripten Asyncify docs

## Findings

- The pass still reads as a whole-module pause/resume transform, not a shrink or peephole optimization.
- The runtime helper surface still includes `asyncify_get_state` and the unwind/rewind helpers.
- The source still distinguishes wasm32 and wasm64 pointer width handling.
- Catch-block unwinding remains an explicit boundary with an ignore option.
- The public pass registration for `asyncify` is unchanged.
- No teaching-relevant drift was found against the existing 2026-04-26 dossier.

## Follow-up

Refresh the living `asyncify` pages so the new 2026-05-05 source capture is visible from the index, tracker, and page-level source lists.
