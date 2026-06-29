# Remove-unused-brs complete-family recursive kickoff

Date: 2026-06-29

## Goal

User request: start a recursive handoff whose end state is **complete audit and implementation of all `remove-unused-brs` (RUB) transform families**.

Operational interpretation for follow-up threads:

- Treat the current v0.1.0 RUB closeout (`[O4Z-AUDIT-RUB-O]` / `[O4Z-AUDIT-RUB-P]`) as a strong baseline, not the final stop condition for this user-directed goal.
- Keep already accepted representation/tooling boundaries explicit, but actively revisit every implementable remaining Binaryen `RemoveUnusedBrs.cpp` transform family.
- Do not close the recursive goal until the RUB dossier no longer lists broad unimplemented transform families except narrow, source-backed, user-accepted blockers with concrete reopening criteria.

## Sources inspected in this kickoff slice

- `agent-todo.md` `[O4Z-AUDIT-RUB]` through `[O4Z-AUDIT-RUB-P]`.
- `docs/wiki/binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md`, especially the `version_130` behavior matrix.
- `docs/wiki/binaryen/passes/remove-unused-brs/parity.md` current open gap and RUB-O/RUB-P closeout notes.
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-strategy.md` remaining upstream-vs-local boundaries.
- `src/passes/remove_unused_brs.mbt` and `src/passes/remove_unused_brs_test.mbt` by search for retargeting, `br_table`, `br_on_*`, sink, payload, and branch-hint surfaces.

## Current baseline

RUB has a documented direct v0.1.0 closeout. The final direct lane after RUB-P compared `99751/100000` with two raw mismatches classified as Starshine-win dropped-expression cleanup before unconditional trap/branch and `249` Binaryen/tool command failures. Generated O4z slot14/slot40 replays validate. RUB-N remains the only fully accepted unsupported metadata/pass-option boundary in that closeout.

The implementation already covers major families: tail branch/return removal, payload branch cleanup, constant `br_if`, early switch cleanup, loop cleanup, sink-block safe subset, GC `br_on_*` safe subset, JumpThreader safe subset, adjacent `br_if` merge subset, dense no-payload `tablify`, local `restructureIf`, direct `selectify`, `optimizeSetIf`, branch-to-trap, and one-target value-switch collapse.

## Remaining families to audit / implement before this recursive goal can close

This list is intentionally broader than the release closeout. Each item needs a source-backed decision: implement with red-first tests, prove Binaryen keeps it stationary, or document a narrow blocker.

1. **JumpThreader beyond no-payload `br_if`**
   - Unconditional direct `br` retargeting beyond the trap subset.
   - `br_table` retargeting.
   - Payload sent-type preservation when retargeting value branches.
   - Broader `replacePossibleTarget` parity.

2. **GC `optimizeGC(...)` `br_on_*` breadth**
   - Payload/prefix-child `BrOn` forms.
   - Nullable-cast success-only-if-non-null splitting to `br_on_non_null` plus appended `ref.null`.
   - Descriptor variants if/when local `Instruction` / `HotOp` support exists.
   - Broader fallthrough-type / local.tee cast insertion.
   - Unreachable-input dropped-child construction.

3. **Block sinking breadth**
   - Result-typed block / result-typed `if` sinks.
   - Direct sink-specific unreachable-condition cases that DCE does not erase first.
   - Refinalization details for newly moved labels/types.

4. **FinalOptimizer block-tail / adjacent branch breadth**
   - Payload/value branches for adjacent merges.
   - Adjacent `br_if` + unconditional `br` cleanup.
   - Broader Binaryen effect/cost modeling beyond the current local speculation proof.
   - Metadata-aware branch-hint `applyOrTo` is blocked on RUB-N representation work unless that broader infrastructure is added.

5. **`tablify(...)` / `visitSwitch(...)` breadth**
   - Payload/value equality ladders.
   - Child-less stack-payload value switches.
   - Effectful selector/value reordering decisions.

6. **`selectify(...)`, `restructureIf(...)`, and `optimizeSetIf(...)` breadth**
   - Broader value/select legality beyond single-result scalar / pure fallthrough cases.
   - Any source-backed multivalue/all-features forms not covered by current tests.
   - `never-unconditionalize` remains unavailable until pass-option support exists.

7. **EH / legacy try boundary**
   - Recheck whether any current binary-decoder path can expose HOT `Try` forms; if not, keep the old-`try` boundary as tooling/representation only.

8. **Raw-gate and performance accountability**
   - Every new family must avoid reopening historical RUB performance cliffs.
   - Prefer narrow candidate gates and piggyback on existing per-cycle scans.

9. **Dedicated generator/signoff freshness**
   - Before final closeout, refresh or add a RUB-specific GenValid profile if the current profile surface undersamples the newly implemented families.
   - Final signoff should include the repo-standard four-lane pass matrix unless the user explicitly approves a smaller closeout.

## Recommended next slice

Start with **JumpThreader direct unconditional `br` retargeting beyond branch-to-trap** because it is explicitly named as a remaining reopening criterion, appears locally bounded, and can be tested before touching broad GC/refinalization or metadata infrastructure.

Suggested first implementation slice:

1. Re-read Binaryen `RemoveUnusedBrs.cpp` / `branch-utils.h` around `JumpThreader` in the checked-in raw Binaryen source or fetch from the existing `version_130` source note.
2. Write red-first focused tests in `src/passes/remove_unused_brs_test.mbt` for a reduced direct unconditional `br` through a one-child named block or child-block-to-following-simple-jump shape that Binaryen rewrites and Starshine currently preserves.
3. Add negative tests for branch payloads, `br_table`, and label-use/sent-type cases if the slice remains no-payload-only.
4. Implement via existing helpers near `remove_unused_brs_collect_retargetable_branches_to_label(...)`, `remove_unused_brs_retarget_retargetable_branches(...)`, and `remove_unused_brs_try_thread_jump_through_block(...)`.
5. Validate with focused RUB tests, `moon test src/passes`, native `src/cmd` build if behavior changes, and a bounded direct compare smoke.

## Completion criteria for the recursive handoff

The recursive goal is complete only when:

- All remaining families above are either implemented with red-first focused coverage and validation, or are documented as narrow non-goals/blockers with exact source evidence and reopening criteria.
- `agent-todo.md` and the RUB wiki pages agree on current status.
- `src/passes/remove_unused_brs_test.mbt` includes positive/negative coverage for every implemented/boundary family.
- Direct pass comparison is refreshed after behavior changes, with mismatches classified as agent judgment, not merely accepted because outputs validate.
- The final RUB closeout includes exact commands/results, artifact paths, pass-local timing if available, command-failure classes, and remaining accepted boundaries.
