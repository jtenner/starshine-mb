# Agent Tasks

Active unreleased work only, reviewed October 20, 2026. Follow
[the docs schema](docs/README.md). Completed mechanisms, measurements and
rejected experiments belong in the linked wiki dossiers and git history.
New comparisons require verified
[Binaryen 133](docs/wiki/binaryen/release-horizon-and-oracles.md); historical
oracle versions and checkpoints do not sign current source.

Completed October 7 default-gate and ten-item audit repairs are recorded in
[the wiki log](docs/wiki/log.md). They are removed from this active backlog.


## Next unreleased patch — GSI exported-origin measurement [IR2-GSI-BURN-001]

- **Goal / why:** measure the added exported-resource origin scan after the
  BURN-001 correctness repair for both GSI variants.
- **Deliverables / tasks:** compare pass-local time and allocations on modules
  with many exports/aliases, broad resource types and deep subtype candidates.
- **APIs / invariants:** `gsi_build_closed_world_facts`, shared external-origin
  cache and subtype propagation; preserve host values and private folds.
- **Dependencies / exit / tests:** a later authorized measurement lane; retain
  exact burn, in-file type/resource matrix and command regressions. No benchmark
  or large fuzz lane is authorized in this repair. See the
  [repair evidence](docs/wiki/binaryen/passes/global-struct-inference/closed-world-analysis-and-unnesting.md#october-28-2026--burn-001-host-writable-origins).

## Next unreleased patch — DAE signature-key correctness follow-up [IR2-DAE-PERF-08]

- **Goal / why:** assess the existing embedded-subtype shared-metadata key
  equivalence in the separate correctness sweep. The old renderer omits that
  metadata; the landed structural key preserves the same equivalence.
- **Deliverables / tasks:** establish a reachable semantic repro before changing
  key identity; preserve exact spelling, metadata admission, first index,
  ownership and batch lifetime. This is not a new memory-trade decision.
- **APIs / invariants:** `dae_structural_func_type_lookup`,
  `dae_update_defined_func_type`, unread-parameter and dropped-result batches.
- **Dependencies / exit / tests:** renewed verified-v133 comparison evidence in
  the next leased lane; retain key, type-update and batch regressions. The
  [measured landing](experiment-results.md#item-8--landed-under-the-corrected-procedure)
  closes the prior measurement task, with its accepted RSS cost explicit.
## Next unreleased patch — OI reaching-source proof cost [IR2-BURN-003]

- **Goal / why:** measure the necessary written-local reaching-value proof
  added for BURN-003; unchanged-base runtime execution confirmed wrong folds.
- **Deliverables / tasks:** compare pass time, allocations and peak memory on
  candidate-free, unwritten-parameter, initialized-local, repeated-candidate,
  nested-control and frequent-mutation workloads. No timing is authorized on
  the borrowed fix-wave machine.
- **APIs / invariants:** shared `optimize_instructions_same_local_value`,
  borrowed use-def write rows, operand-expanded CFG/read-source-only flow;
  same singleton reaching source, revision invalidation, retained value order.
- **Dependencies / exit / tests:** a measurement slot; retain implementing-file,
  dispatcher and both-width runtime regressions. Explain any material analysis
  regression before further optimization. See the
  [fix and limits](docs/wiki/binaryen/passes/optimize-instructions/index.md#october-28-2026-burn-003-reaching-value-equality).

## Next unreleased patch — Coverage and output quality [IR2-REVIEW-LIMITS]


### BURN-009 DCE signature-constraint measurement [IR2-DCE-BURN-009]

- **Goal / why:** quantify the correctness-required signature bitset cost;
  no performance improvement or neutrality is established by the bounded repair.
- **Deliverables / tasks:** measure ordinary-only, catch-only, mixed catch and
  mixed continuation targets, many labels and repeated cache invalidations;
  compare pass time, allocation and output on the same fixtures.
- **APIs / invariants:** `dead_code_elimination_build_branch_users_by_label`,
  `dead_code_elimination_try_voidify_nonfallthrough_block_with_pure_incoming_branches`;
  preserve catch/handler signatures and ordinary-only dropped-result removal.
- **Dependencies / exit / tests:** separate controlled measurement; retain
  direct owner, label-target and active dispatcher regressions. No benchmark,
  large fuzz or broad parity closure ran in the repair. See the
  [reproduction, limits and handoff](docs/wiki/binaryen/passes/dead-code-elimination/typed-control-voidification-and-eh.md#burn-009-mixed-incoming-edges-2026-10-28).
