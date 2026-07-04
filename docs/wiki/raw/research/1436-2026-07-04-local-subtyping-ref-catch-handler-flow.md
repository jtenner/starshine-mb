# Local-subtyping ref-catch handler-flow boundary

Date: 2026-07-04

## Question

Can the remaining LS EH residual be implemented as ordinary `try_table` body dominance, or does `catch_ref` / `catch_all_ref` handler-result flow need a separate Starshine representation/tooling slice?

## Sources and probes

- Binaryen local oracle: `wasm-opt version 130 (version_130)`.
- Primary source basis remains `docs/wiki/raw/research/1431-2026-07-04-local-subtyping-behavior-family-matrix.md`: local `LocalSubtyping.cpp`, `local-subtyping.wast`, and `local-structural-dominance.h` matched the earlier `version_129` source copies.
- New local probes under `.tmp/ls-eh-probes-20260704/`:
  - `catch-result-local-anyref.wat`
  - `catch-skips-block-write.wat`
  - `catch-ref-skips-block-write.wat`
  - `catch-all-ref-skips-block-write.wat`
- Focused Starshine boundary tests in `src/passes/local_subtyping_test.mbt`:
  - `local-subtyping boundary no-ops catch_ref skipped block write until handler flow is represented`
  - `local-subtyping boundary no-ops catch_all_ref skipped block write until handler flow is represented`

## Findings

### Catch result keeps a broad join when the catch payload can supply the broader value

`catch-result-local-anyref.wat` assigns a local from a block whose normal path is `ref.null none`, but whose catch path can branch an `anyref` tag payload to the block result.

Binaryen v130 keeps the block result and assigned local at `anyref` rather than narrowing to `nullref`. That matches the official `try_table-catch-result` lit intent: handler branch payloads are part of the result join.

### Ref-catch skipped-write post-state is a real Binaryen-observable local narrowing, but nullable

The new `catch_ref` and `catch_all_ref` probes use this shape:

```wat
(local $x (ref null $t))
(drop
  (block $catch (result exnref)
    (try_table (catch_ref $e $catch) ;; or catch_all_ref
      (throw $e))
    (local.set $x (struct.new_default $t))
    (ref.null noexn)))
(drop (local.get $x))
```

Binaryen v130 narrows `$x` from the parent type to `(ref null (exact $t))`, not to non-null. The catch path can skip the local write and still reach the outside get, so non-null narrowing would be invalid. The assigned value still proves a more precise nullable heap type.

A non-ref `catch` variant with a void target has the same nullable-post-state implication for writes after the catching `try_table`, but the immediate blocker this slice addressed is the ref-catch transport family called out in the LS backlog.

### Current Starshine representation/tooling boundary

The corresponding Starshine AST fixtures are valid after using a nullable exn block result, but the active `local-subtyping` implementation must not HOT-lift these functions today: the ref-catch result-flow shape aborts in the HOT lifting path before assignment collection. This is a representation/tooling blocker, not a Starshine win.

The pass now fail-closes on raw `TryTable` instructions containing `CatchRef` or `CatchAllRef` before HOT lifting. The focused tests are deliberately boundary tests: they require the pass to succeed, leave the body local unchanged, and validate the unchanged module. This prevents a pass crash while keeping the Binaryen parity residual explicit.

## Classification

- **Not a Starshine win.** Starshine does not measure a size, validation, or performance advantage for leaving ref-catch handler-flow locals broader.
- **Precise blocker.** The residual is `catch_ref` / `catch_all_ref` handler-result and skipped-write post-state local flow, currently blocked by Starshine HOT representation/tooling for ref-catch result-flow modules.
- **Fail-closed behavior.** Starshine no-ops functions containing ref-catch flow instead of attempting unsound local narrowing or aborting.

## Reopening criteria

Reopen this residual for implementation when Starshine can HOT-lift and validate ref-catch result-flow shapes with local writes/gets, or when a raw/lib-only local-subtyping path can collect assignment types and structural dominance without relying on the current HOT lift. The implementation should then match Binaryen's nullable exact-child narrowing for skipped post-catch writes and preserve broad joins when catch payloads can produce a broader block result.

## Validation in this slice

- Red-first focused test before the guard: the two new ref-catch fixtures failed by aborting in HOT lift.
- After the guard: `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` passed `71/71`.

Final LS closeout remains open until this precise blocker and the two nondefaultable-local validator/tooling boundaries are either implemented or accepted with refreshed full direct-pass evidence.
