# SGO plain family exposure audit

## Scope

Research-only `[SGO]003M` slice for the `simplify-globals` / `simplify-globals-optimizing` / `propagate-globals-globally` pass family.

This slice decides whether Starshine should expose the existing partial `simplify-globals-optimizing` engine under the plain `simplify-globals` or `propagate-globals-globally` public pass names.

## Sources checked

- Starshine boundary-only registry list in `src/passes/optimize.mbt`: plain `simplify-globals` and `propagate-globals-globally` are recognized boundary-only names.
- Starshine active module-pass registry in `src/passes/optimize.mbt`: only `simplify-globals-optimizing` is active for this family.
- Starshine pass expansion guard in `src/passes/optimize.mbt`: boundary-only requests reject before dispatch.
- Starshine module dispatcher in `src/passes/pass_manager.mbt`: only `simplify-globals-optimizing` has an active SGO dispatcher path.
- Existing wiki strategy pages for `simplify-globals`, `simplify-globals-optimizing`, and `propagate-globals-globally`.
- Existing Binaryen source refresh notes:
  - `docs/wiki/raw/binaryen/2026-05-05-simplify-globals-current-main-recheck.md`
  - `docs/wiki/raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md`
  - `docs/wiki/raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`
- A focused official-GitHub check on 2026-05-25 of Binaryen `SimplifyGlobals.cpp`, `pass.cpp`, and the dedicated `propagate-globals-globally.wast` surface found no reason to reinterpret the already documented family split.

## Contract comparison

The family remains three separate public contracts, even though Binaryen implements them in the same source family:

| Public pass | Binaryen contract | Safe Starshine exposure today? |
| --- | --- | --- |
| `simplify-globals` | Shared global rewrite engine: startup/global propagation plus function-body/global-write simplification, without the optimizing nested default-function rerun. | No. Starshine has no exact plain stop point, no plain-pass public tests, and no direct plain-pass fuzz evidence. |
| `simplify-globals-optimizing` | Same shared engine with the optimizing nested default-function rerun on changed functions. | Partially exposed already as Starshine's active SGO pass. It remains active/partial, not full `SimplifyGlobals.cpp` parity. |
| `propagate-globals-globally` | Startup/module-level propagation-only sibling: later global initializers and active element/data offsets, not ordinary function-body propagation. | No. Starshine has no exact startup-only module pass or public tests for this narrower stop point. |

## Decision

Keep plain `simplify-globals` and `propagate-globals-globally` boundary-only for now.

Do not alias either name to the active partial `simplify-globals-optimizing` implementation.

Rationale:

- aliasing plain `simplify-globals` to SGO would accidentally include the optimizing nested cleanup behavior and still would not prove the exact plain stop point;
- aliasing `propagate-globals-globally` to SGO would be broader than Binaryen's startup-only public contract because SGO also rewrites function bodies and removes writes;
- exposing a new public pass name would require registry/dispatcher tests, behavior tests, direct pass fuzz for that name, and docs that define the exact stop point;
- no current user-facing blocker requires those names to be active before the partial optimizing sibling is further stabilized.

## Backlog result

`[SGO]003M` is closed as a research-only exposure decision.

Future work must be filed as a new explicit child slice before moving either boundary-only name to active status. A future `propagate-globals-globally` slice should implement the startup-only module contract first; a future plain `simplify-globals` slice should implement or extract the shared global engine without the optimizing nested rerun.

## Validation

- `git diff --check` — passed.

No Moon tests or direct fuzz were required for this slice because no code, registry, dispatcher, behavior, preset, or normative pass docs changed.

## Status

`[SGO]003M` is complete. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
