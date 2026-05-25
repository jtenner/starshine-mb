# SGO refactor queue closeout

## Scope

Bookkeeping/research-only `[SGO]003O4` closeout for the `simplify-globals-optimizing` refactor-only matcher maintainability queue.

This slice decides whether the opportunistic `[SGO]003O` queue should remain open after the visible child slices `[SGO]003O1` through `[SGO]003O3` were resolved.

## Audit

The completed queue now covers the known refactor-only families discovered during recent source-alignment work:

- 0641 and 0645 centralized repeated FlowScanner clean-pop / taint checks.
- 0643 centralized repeated call-boundary stack handling while preserving the adjacent-`global.get` arm-result exception.
- 0646 centralized block / no-catch `try_table` wrapper extraction plus external-pure condition index handling.
- 0647 centralized exact `if return; set` tail dispatch.
- 0648 centralized clean leaf pushes for constants, nullary pure size queries, and `local.get`.
- 0649 centralized clean pair/triple side-effect opcode predicates.
- 0650 centralized value-producing `if` arm-result scan/merge handling.
- 0651 audited remaining FlowScanner predicate grouping and found no duplicated predicate cluster needing extraction.
- 0652 renamed the condition-body helper to document the shared body-plus-`if`-index wrapper contract.
- 0653 renamed the clean leaf replacement helper to document the one-clean-pop / one-clean-push stack contract.

No additional hidden refactor blocker, prerequisite, or deferred matcher family was identified during this closeout pass.

## Decision

Close `[SGO]003O` now instead of keeping an open opportunistic queue.

Rationale:

- all visible `[SGO]003O*` child slices are resolved;
- the remaining SGO backlog already contains explicit behavior, source-alignment, interface, and tooling follow-ups;
- keeping a generic refactor bucket open would hide work that should be filed as a concrete child slice with a clear contract;
- this audit does not change matcher logic or broaden optimizer behavior.

Future maintainability discoveries should be added as new explicit `[SGO]003*` child slices, or under the relevant existing behavior/source-alignment item, before implementation.

## Validation

- `git diff --check` — passed.

No Moon tests or direct SGO fuzz were required for this docs/backlog-only closeout because no code, matcher logic, behavior, or normative pass docs changed.

## Status

`[SGO]003O4` is complete and `[SGO]003O` is closed. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
