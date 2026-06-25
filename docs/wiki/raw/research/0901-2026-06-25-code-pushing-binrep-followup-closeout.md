# 0901 - code-pushing Binaryen replacement follow-up closeout

Date: 2026-06-25

## Question

Can `[O4Z-AUDIT-CP-BINREP]` close now that the replacement-oriented follow-up items after the v0.1.0 direct-pass closeout have either landed behavior changes with evidence or been explicitly resolved as narrow boundaries?

## Answer

Yes. `[O4Z-AUDIT-CP-BINREP]` is complete as a follow-up to the old `[O4Z-AUDIT-CP]` closeout in [`0892`](0892-2026-06-25-code-pushing-final-closeout.md). The old closeout remains valid: it closed the v0.1.0 direct-pass release-gating audit with the then-current four-lane matrix and explicit reopening criteria. This replacement follow-up shrank additional Binaryen v130 gaps where safe and documented the remaining source-backed surfaces as narrow accepted boundaries with reopening criteria.

This is not a claim of byte-for-byte output parity, full `CodePushing.cpp` source equivalence, `--ignore-implicit-traps` compatibility, no-effects intrinsic support, refinalization support, or public preset-neighborhood parity.

## Completed subitems

- [`0893`](0893-2026-06-25-code-pushing-dependency-chain-into-if.md) / `[CP-BINREP-001]`: implemented consecutive local-copy dependency-chain sinking into the sole consuming `if` arm with red-first tests and bounded `code-pushing-all` smoke.
- [`0895`](0895-2026-06-25-code-pushing-tnh-movement.md) / `[CP-BINREP-002]`: plumbed `traps_never_happen` into `HotPassContext` and implemented TNH-only exact integer div/rem into-if movement with default/TNH red-first tests and bounded `code-pushing-all` smoke.
- [`0897`](0897-2026-06-25-code-pushing-ignore-implicit-traps-boundary.md) / `[CP-BINREP-003]`: documented Binaryen `--ignore-implicit-traps` / `-iit` as a distinct accepted current Starshine boundary, not a TNH alias; Starshine does not claim the lit `value-might-interfere` memory-load movement.
- [`0899`](0899-2026-06-25-code-pushing-intrinsic-no-effects-boundary.md) / `[CP-BINREP-004]`: documented `binaryen-intrinsics/call.without.effects` as a current import-metadata/API boundary; no unsafe type/arity heuristic was added.
- [`0900`](0900-2026-06-25-code-pushing-gc-ref-boundary.md) / `[CP-BINREP-005]`: documented GC/ref coverage and boundaries: existing `RefFunc`, `br_on_*`, and atomics/GC non-null `struct.get` families remain covered, while `ref-into-if` requires local type weakening/refinalization.
- [`0896`](0896-2026-06-25-code-pushing-independent-into-if-order.md) / `[CP-BINREP-006]`: implemented source-order-preserving consecutive independent multi-set sinking into the sole consuming `if` arm with red-first test and bounded `code-pushing-all` smoke.
- [`0898`](0898-2026-06-25-code-pushing-branch-switch-boundary-closeout.md) / `[CP-BINREP-007]`: closed low-priority branch/switch work as no-new-positive boundary; existing notes already implemented branch-value `br_if` positives and protect probed `br_table` stationary shapes.

## Validation and matrix decision

A full four-lane direct-pass matrix was not rerun for this replacement-oriented closeout. A smaller validation set is sufficient for this closeout because:

1. The old release-gating direct-pass closeout and four-lane matrix remain preserved in `0892`.
2. Every behavior-changing replacement slice ran red-first focused tests and then refreshed a bounded dedicated `code-pushing-all` compare smoke with `--normalize local-cleanup-debris` and the current `_build/native/release/build/cmd/cmd.exe` binary:
   - `[CP-BINREP-001]`: `1000/1000` compared, `466` normalized, `534` cleanup-normalized, raw mismatches/failures `0`.
   - `[CP-BINREP-002]`: `1000/1000` compared, `466` normalized, `534` cleanup-normalized, raw mismatches/failures `0`.
   - `[CP-BINREP-006]`: `1000/1000` compared, `466` normalized, `534` cleanup-normalized, raw mismatches/failures `0`.
3. `[CP-BINREP-003]`, `[CP-BINREP-004]`, `[CP-BINREP-005]`, and `[CP-BINREP-007]` are docs/status boundary resolutions only; they changed no pass behavior, generated profiles, public API, or CLI behavior.
4. The closeout is a backlog-resolution closeout for the replacement follow-up, not a new direct-pass release-gating signoff. Reopen and rerun the full four-lane matrix if a future slice implements any of the accepted boundaries or if direct-compare evidence changes.

## Reopening criteria

Reopen under a new source-backed item if any of the following occur:

- a reduced Binaryen v130/current-main probe shows a new positive `code-pushing` movement family Starshine leaves stationary and that is not one of the accepted boundaries above;
- Starshine implements a distinct implicit-trap policy, no-effects intrinsic identity metadata, local refinalization, or broader GC/switch representation and needs behavior parity tests;
- a direct compare lane finds raw mismatches not explained by the documented `local-cleanup-debris` normalizer, known value-`br_if` representation gap, or Binaryen/tool command-failure classes;
- Starshine emits invalid wasm after `code-pushing`;
- public preset-neighborhood evidence requires code-pushing scheduling changes.

## Decision

Close `[O4Z-AUDIT-CP-BINREP]` in `agent-todo.md`. Future code-pushing replacement work should enter as a new source-backed widening slice or a generated-mismatch fix rather than keeping this follow-up active.
