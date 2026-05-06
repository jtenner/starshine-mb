# Validate Proof Boundary Audit

Status: completed PRV006 audit on 2026-05-06.

## Scope

- Audited active `src/validate_proof` helpers, direct `src/validate/env.mbt` index helpers, `src/validate/match.mbt`, and typechecker-helper proof candidates.
- Checked the committed trust surface for `proof_axiomatized`.
- Re-ran the local proof entrypoint far enough to classify the host/tooling state.

## Current machine-checkable kernel

`src/validate_proof` remains the only required proof gate. It contains 15 helper contracts:

1. `bounded_index`
2. `defined_func_body_index`
3. `defined_func_absolute_index`
4. `defined_body_func_index`
5. `group_relative_absolute_index`
6. `group_member_relative_index`
7. `label_stack_storage_index`
8. `rectype_suffix_member_index`
9. `stack_len_after_push1`
10. `stack_len_after_push_types`
11. `stack_len_after_pop1`
12. `stack_len_after_pop_types`
13. `stack_suffix_start_after_end_check`
14. `latest_stack_index`
15. `suffix_start_index`

These cover the validator's current high-value arithmetic/index boundary: label-stack reverse lookup, current rec-stack frame lookup, group-relative type indexing, code-body/function index translation, name/declared-function bounds, suffix-base recovery, suffix-local rectype member recovery, and stack-length discipline.

## Candidate classification

| Candidate surface | Decision | Rationale |
| --- | --- | --- |
| More sidecar arithmetic helpers in `src/validate_proof` | Complete for this rollout | No obvious unmodeled helper with the same small, high-value, package-local proof shape remains after the 15-goal kernel. |
| `src/validate/env.mbt` direct getters | Defer | Remaining getters are mostly thin `Array::get` wrappers around unsigned index newtypes; executable tests already pin behavior, while broader direct proving pulls in `lib` and `bitset` dependency proof output. |
| `LabelStack` structural invariant (`head`, `parents`, `len`) | Defer | Valuable but no longer first-wave: it requires modeling mutable parent-chain structure rather than pure arithmetic. Keep covered by `env_tests.mbt` until a second proof wave targets data-structure invariants. |
| `src/validate/match.mbt` recursive subtype/exactness facts | Defer | The Boolean symmetry pilot is landed, but recursive fuel/visited reasoning should not be replaced with trusted axioms. Requires a dedicated design slice. |
| Typechecker value-stack compatibility and branch-exit normalization | Defer | First-wave length discipline is proved. Full type compatibility depends on validator matching semantics and recursive subtype facts, so it belongs after the `match.mbt` proof design slice. |
| Broad `src/validate` package proving | Defer | The package is proof-enabled, but targeted file commands still emit a whole-package proof command plus dependency proof artifacts. Keep required gates at `src/validate_proof`. |
| `src/binary`, `src/bitset`, pass, and fuzz packages | Out of boundary | These are outside the validator-first proof rollout and remain covered by tests/fuzz/roundtrip gates. |

## Trust-surface audit

- `grep proof_axiomatized` found no committed `.mbt` or `.mbtp` use on 2026-05-06.
- Mentions remain only in docs/backlog as policy and deferred-debt tracking.
- No new trusted assumptions were introduced.

## Validation evidence

Commands run on 2026-05-06:

- `moon prove src/validate_proof`
  - Result: environment/tooling failure, not semantic proof failure.
  - Diagnostic: `why3_harness: no configured provers are available`.
  - Follow-up attempted: `why3 config detect -C _build/verif/why3.conf`, which found local Z3 installations and updated the generated local config, but `moon prove src/validate_proof` still reported no configured provers through the MoonBit harness.
- `moon prove src/validate/match.mbt --dry-run` and `moon prove src/validate/env.mbt --dry-run`
  - Result: both emit whole-validate-package proof commands plus dependency proof outputs, confirming that targeted direct-validator proving is not an isolated first-wave gate in this workspace.

## PRV006 closure

PRV006 is complete as an audit/closure task:

- Remaining high-value first-wave proofs are already represented by the 15-goal `src/validate_proof` kernel.
- Direct `env`, recursive `match`, and broader typechecker helper proofs are explicitly deferred with reasons.
- No trusted assumptions were added.
- The durable policy remains: required formal proof evidence is `moon prove src/validate_proof` on a host where MoonBit's Why3 harness recognizes a configured prover; otherwise record the host limitation and continue executable signoff.
