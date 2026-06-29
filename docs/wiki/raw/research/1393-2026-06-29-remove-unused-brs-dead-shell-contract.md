# RemoveUnusedBrs dead-shell cleanup contract

Date: 2026-06-29

## Scope

Closeout note for `[O4Z-AUDIT-RUB-R]`. This slice makes the note `1392` accepted Starshine-win family explicit in tests, source comments, and the living RUB dossier.

## Finding

The accepted dead structured shell cleanup was already implemented. Adding focused coverage did not produce a red test because the current pass already prunes the representatives through `remove_unused_brs_prune_dead_suffix_after_nonfallthrough(...)` after branch/table cleanup exposes a proven nonfallthrough root.

The implementation owner is now documented inline: the helper is intentionally root-only and deletes suffix roots after side-effect-free branch/table cleanup rather than preserving Binaryen's dead structured trap/control shells. It still preserves suffix roots when a result-typed function needs following values after a void structured terminal.

## Tests added

Focused coverage in `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs makes constant br_if dead-shell deletion explicit`
- `remove-unused-brs forwards same-target br_table payload through dead shell`
- `remove-unused-brs forwards same-target br_table multivalue payload through dead shell`

These cover the two reduced representatives from note `1392` and a locally representable multivalue variant. The scalar `br_table` test returns the forwarded payload instead of dropping it so the test protects both selector drop and payload forwarding.

## Validation

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` — passed `217/217`.

The tests were green on first run, so this slice did not require a behavior change beyond source/documentation clarification.

## Dossier updates

Updated:

- `docs/wiki/binaryen/passes/remove-unused-brs/pattern-catalog.md` — documents `remove_unused_brs_prune_dead_suffix_after_nonfallthrough(...)` as the note-`1392` / RUB-R owner.
- `docs/wiki/binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md` — records the accepted Starshine-only dead-shell cleanup in the Binaryen phase matrix.
- `docs/wiki/binaryen/passes/remove-unused-brs/parity.md` — adds the family to the current coverage surface and marks the dedicated-profile closeout as accepted rather than open validation evidence.
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-strategy.md` — replaces stale RUB-Q-open wording with the note-`1392` approved-substitute closeout and RUB-R contract.
- `agent-todo.md` — marks `[O4Z-AUDIT-RUB-R]` complete and leaves `[O4Z-AUDIT-RUB-S]` onward active.

## Contract

Keep Starshine's cleanup for side-effect-free dead structured trap/control shells, pure selector drops, and branch-payload forwarding after branch/table cleanup. Do not reintroduce Binaryen's dead `block`/`unreachable` shells merely to make dedicated normalized compare output greener.

Reopen under note `1392` criteria only: a current-binary Starshine validation failure, runtime semantic mismatch, effectful mismatch facts, mismatch outside the accepted family, unaccepted size-losing family, or Binaryen/source drift that invalidates the proof.
