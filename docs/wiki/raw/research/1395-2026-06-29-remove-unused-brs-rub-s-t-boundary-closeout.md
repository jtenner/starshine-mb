# RemoveUnusedBrs RUB-S/T boundary closeout

Date: 2026-06-29

## Scope

Follow-up for `[O4Z-AUDIT-RUB-S]` residual raw-size positives after the `v128.const` same-target `br_table` fix, plus `[O4Z-AUDIT-RUB-T]` fallthrough-producing GC payload split evaluation.

## RUB-S residual no-`br_table` triage

After the `v128` table fix, saved-lane reruns had no residual Starshine `br_table` outputs, but `1000-max100` still had `11` positive raw-size cases and runtime `max20` still had `7`. The leading case remained `case-000073-gen-valid`, now Starshine `1083` raw bytes versus Binaryen `1045` (`+38`).

A triage re-encode showed the residual positives are not still owned by switch collapse:

| lane | current positive cases | current positive raw delta | Binaryen-reencoded Starshine delta over those positives |
| --- | ---: | ---: | ---: |
| `1000-max100` saved failures | `11` | `+181` | `-1584` |
| runtime `max20` saved failures | `7` | `+122` | `-1027` |

This is only diagnostic evidence: Binaryen's no-pass reader/writer changes structured form, so it is not a Starshine encoder proof. It did, however, confirm the remaining positives are no longer `br_table` residue.

The leading residual case reduces to a void structured block in a result-typed function whose body unconditionally returns, followed by a dead result suffix. Starshine intentionally keeps that suffix through `remove_unused_brs_root_suffix_required_after_void_structured_terminal(...)`. The guard is backed by the stale validation failure reduced in note `1388` and by existing suffix-preservation tests; this slice added `remove-unused-brs boundary keeps result suffix after void return block` to lock the specific RUB-S residual owner.

RUB-S closeout: the actionable raw-size bug is fixed; the residual no-table positives are a precise result-suffix safety blocker. Reopen only if a new positive raw-size family is outside the fixed `v128` same-target table owner and the guarded void-structured-return/result-suffix family, or if a future proof can prune those suffixes while preserving HOT lowering validation.

## RUB-T fallthrough-producing GC payload split

Note `1373` already reduced the Binaryen family to the exact missing facility. Binaryen `RemoveUnusedBrs.cpp::optimizeGC(...)` uses `ChildLocalizer`/scratch locals for `SuccessOnlyIfNonNull` payload splits so it can move the payload and ref into an inner `br_on_non_null`, branch with the correct payload arity, and still drop the payload on the not-taken fallthrough path. A naive stack rewrite was locally invalid because the inner branch could not consume an outer-stack payload.

Current Starshine still lacks a RUB-local child localizer or scratch-local materialization path for this shape. The existing focused boundary test `remove-unused-brs boundary keeps fallthrough-producing payload br_on_cast split` remains the correct fail-closed behavior.

RUB-T closeout: no safe implementation was made. Reopen only when a localizer-backed rewrite can prove all of the note-`1373` criteria: branch arity including payload plus casted ref, fallthrough result type after the appended `ref.null`, single evaluation/order of payload and ref operands, correct payload dropping on the not-taken path, and valid lowering without relying on values below an inner block's stack height.

## Validation

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `219/219` after adding the RUB-S boundary test.
