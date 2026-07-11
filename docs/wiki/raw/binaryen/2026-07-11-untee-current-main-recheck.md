# Binaryen `untee` current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness manifest for `docs/wiki/binaryen/passes/untee/`

## Scope

This capture supersedes the **freshness claim** in the 2026-04-25 `untee` bridge. It does not replace either older immutable capture: the 2026-04-23 manifest remains the tagged `version_129` provenance, and the 2026-04-25 bridge remains historical evidence.

The review was deliberately narrow. It reread the current Binaryen `main` owner, public registration/default-scheduler surface, constructor declaration, and dedicated lit oracle; it also reconciled the living Starshine status against the active local owner and focused tests.

## Primary sources reread

### Upstream Binaryen `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Untee.cpp>
- Registration and default function scheduler: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Constructor declaration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Focused oracle: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/untee.wast>

### Current Starshine evidence

- Pass owner: `src/passes/untee.mbt`
- Focused tests: `src/passes/untee_test.mbt`
- Registry: `src/passes/optimize.mbt`
- Dispatcher: `src/passes/pass_manager.mbt`

## Current upstream result

No behavior-bearing drift was found on the reviewed upstream surface:

- `Untee` is still a function-parallel `PostWalker` over `LocalSet` nodes.
- A reachable `local.tee` still becomes the original node changed to `local.set`, followed by a synthetic `local.get` made with the function's declared local type.
- A tee whose child has `unreachable` type still loses only the tee wrapper; Binaryen keeps the unreachable child.
- `untee` remains a public registered pass with the same set-plus-get description, and `createUnteePass()` remains declared in the normal pass-constructor header.
- The default function-optimization roster still does not schedule `untee`; it remains an explicit pass rather than a default `-O` / `-Os` slot.
- The dedicated lit file still covers the dropped i32 and f64 cases, tee-as-set-value, nested inside-out expansion, and unreachable deletion.

The review is a source check, not a claim that all Binaryen history, option interactions, or unreviewed test files were exhaustively audited.

## Starshine representation/status reconciliation

Starshine is now an active direct module pass, unlike the local status recorded in the historical 2026-04-25 raw bridge. That historical statement was true for its capture date and must not be reused as current local status.

The local representation is intentionally different from Binaryen's expression-tree `makeSequence(...)` construction: `src/passes/untee.mbt` rewrites the stack-program instruction array by appending `local.set` then `local.get` after the already-emitted producer. The focused tests cover root, nested, direct-unreachable, and structured-body shapes. This is a representation distinction, not a license to accept unmeasured pass drift; future changes still need the direct Binaryen-oracle lane.

## Consumability rule

Use this capture for current-main freshness and current local-status claims. Use the 2026-04-23 capture for tagged-release provenance, and retain the 2026-04-25 bridge as dated historical evidence rather than silently rewriting it.