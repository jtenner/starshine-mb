# remove-unused-brs accepted boundary consolidation

Date: 2026-06-29

Slice: `[O4Z-AUDIT-RUB-Q]` recursive complete-family audit.

## Question

Which remaining RUB-Q items are broad open implementation work, and which are already accepted representation/tooling/source boundaries with exact reopening criteria?

## Consolidated accepted boundaries

The following entries should no longer be phrased as broad open transform-family work:

1. **Legacy `try` / HOT catch-region exposure** — note `1376` proves the public WAT pipeline lowers legacy `try` away before RUB observes a live old-`try` caught-throw candidate. Reopen only if a binary/lib/HOT path exposes a live `HotOp::Try` or equivalent catch-region body from real input before RUB.
2. **Child-less stack-payload value switches** — notes `1369` and `1379` prove public stack-style value `br_table` WAT lifts to child-form payload+selector tables, which the RUB-P one-target switch collapse covers. Reopen only if HOT grows or exposes a verified child-less stack-payload `BrTable` representation.
3. **Unreachable-condition selectify preservation** — note `1378` records this as a HOT-lift command/tooling blocker: valid source-level polymorphic unreachable conditions can fail before RUB. Reopen RUB-specific coverage after HOT lift supports unreachable-typed conditions cleanly.
4. **Large `br_table` JumpThreader beyond the nine-target guard** — note `1381` protects the current `<= 9` guard with a ten-target boundary test. Reopen only with a predicate that distinguishes pure one-child-shell JumpThreader retargeting from early mostly-default switch-lowering candidates that regressed under a broad 32-target admission.
5. **Remaining GC descriptor/fallthrough/localizer cases** — note `1380` closes these as exact blockers/non-goals: descriptor BrOn representation, broader fallthrough/local.tee cast insertion proof, fallthrough-producing payload split scratch-local repair, public stack-form unreachable-input raw proof or child-form exposure, and Binaryen's own nullable disjoint `SuccessOnlyIfNull` TODO.
6. **Final adjacent/value legality residue** — note `1382` closes the remaining adjacent/self-target final-optimizer wording: no-payload adjacent cleanup is implemented, value-carrying adjacent branch cleanup is not a Binaryen `version_130` transform because the source asserts no values, and broader self-target equality needs a future HOT structural-equality/effect proof.

## Still genuinely open before closeout

The remaining active RUB-Q work is now narrower:

- raw-gate/performance accountability for the widened RUB surface, including pass-local timing where available;
- a stronger final direct comparison matrix/signoff, with command/tool failures separated from mismatches and mismatches classified by agent judgment;
- any source drift or new local representation that reopens one of the accepted boundaries above.

## Status impact

`agent-todo.md` and the living RUB dossier should describe the six groups above as accepted boundaries rather than broad missing transform families. `[O4Z-AUDIT-RUB-Q]` should remain open until final validation/signoff evidence is refreshed and recorded.
