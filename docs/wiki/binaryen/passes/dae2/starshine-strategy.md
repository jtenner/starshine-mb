---
kind: entity
status: working
last_reviewed: 2026-10-04
sources:
  - ../../../../../src/passes/cleanup_subtree_reads_perf_wbtest.mbt
  - ../../../../../src/passes/pass_manager_nop_run_perf_wbtest.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/typecheck_probe_perf_wbtest.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_build_node0_wbtest.mbt
  - ../../../../../src/ir/hot_build_node0_perf_wbtest.mbt
  - ../../../../../src/ir/cfg.mbt
  - ../../../../../src/ir/cfg_presence_wbtest.mbt
  - ../../../../../src/ir/cfg_presence_perf_wbtest.mbt
  - ../../../../../src/ir/cfg_lazy_source_order_wbtest.mbt
  - ../../../../../src/ir/cfg_lazy_source_order_perf_wbtest.mbt
  - ../../../../../src/passes/lower_capture_cleanup.mbt
  - ../../../../../src/passes/dae2_parameter_aliases.mbt
  - ../../../../../src/passes/unread_write_wbtest.mbt
  - ../../../../../src/passes/unread_write_reference_wbtest.mbt
  - ../../../../../src/passes/unread_write_perf_wbtest.mbt
  - ../../../../../src/cmd/unread_write_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_legacy.mbt
  - ../../../../../src/passes/legacy_setup_wbtest.mbt
  - ../../../../../src/passes/legacy_setup_reference_wbtest.mbt
  - ../../../../../src/passes/legacy_setup_perf_wbtest.mbt
  - ../../../../../src/cmd/legacy_setup_wbtest.mbt
  - ../../../../../src/passes/single_entry_row_wbtest.mbt
  - ../../../../../src/passes/single_entry_row_reference_wbtest.mbt
  - ../../../../../src/passes/single_entry_row_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_write_facts_wbtest.mbt
  - ../../../../../src/passes/dae2_write_facts_reference_wbtest.mbt
  - ../../../../../src/passes/dae2_write_facts_perf_wbtest.mbt
  - ../../../../../src/cmd/dae2_write_facts_wbtest.mbt
  - ../../../../../src/passes/root_constant_cleanup.mbt
  - ../../../../../src/passes/root_constant_cleanup_wbtest.mbt
  - ../../../../../src/passes/root_constant_cleanup_perf_wbtest.mbt
  - ../../../../../src/cmd/root_constant_cleanup_wbtest.mbt
  - ../../../../../src/passes/no_write_cleanup_wbtest.mbt
  - ../../../../../src/passes/no_write_cleanup_reference_wbtest.mbt
  - ../../../../../src/passes/no_write_cleanup_perf_wbtest.mbt
  - ../../../../../src/cmd/no_write_cleanup_wbtest.mbt
  - ../../../../../src/passes/cleanup_future_reads.mbt
  - ../../../../../src/passes/future_read_mask_wbtest.mbt
  - ../../../../../src/passes/future_read_mask_reference_wbtest.mbt
  - ../../../../../src/passes/future_read_mask_perf_wbtest.mbt
  - ../../../../../src/cmd/future_read_mask_wbtest.mbt
  - ../../../../../src/passes/cleanup_borrow_wbtest.mbt
  - ../../../../../src/passes/cleanup_borrow_perf_wbtest.mbt
  - ../../../../../src/passes/cleanup_borrow_reference_wbtest.mbt
  - ../../../../../src/cmd/cleanup_borrow_wbtest.mbt
  - ../../../../../src/passes/constant_store_pending_wbtest.mbt
  - ../../../../../src/passes/constant_store_pending_perf_wbtest.mbt
  - ../../../../../src/passes/constant_store_pending_reference_wbtest.mbt
  - ../../../../../src/passes/constant_store_sink.mbt
  - ../../../../../src/passes/constant_store_sink_wbtest.mbt
  - ../../../../../src/passes/constant_store_sink_perf_wbtest.mbt
  - ../../../../../src/passes/constant_store_sink_reference_wbtest.mbt
  - ../../../../../src/cmd/constant_store_sink_wbtest.mbt
  - ../../../../../src/ir/local_graph_selected_reads_wbtest.mbt
  - ../../../../../src/ir/local_graph_selected_reads_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_selected_flow.mbt
  - ../../../../../src/passes/dae2_selected_flow_wbtest.mbt
  - ../../../../../src/cmd/dae2_selected_flow_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_trivial_sort_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_trivial_sort_perf_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_trivial_sort_reference_wbtest.mbt
  - ../../../../../src/cmd/trivial_sort_wbtest.mbt
  - ../../../../../src/ir/local_graph_flow_tags_wbtest.mbt
  - ../../../../../src/ir/local_graph_flow_tags_perf_wbtest.mbt
  - ../../../../../src/ir/local_graph_flow_tags_reference_wbtest.mbt
  - ../../../../../src/cmd/dae2_flow_tags_wbtest.mbt
  - ../../../../../src/passes/profitable_alias_wbtest.mbt
  - ../../../../../src/passes/profitable_alias_perf_wbtest.mbt
  - ../../../../../src/passes/profitable_alias_reference_wbtest.mbt
  - ../../../../../src/cmd/profitable_alias_wbtest.mbt
  - ../../../../../src/passes/statement_type_seed.mbt
  - ../../../../../src/passes/compound_suffix_seed_wbtest.mbt
  - ../../../../../src/passes/compound_suffix_seed_reference_wbtest.mbt
  - ../../../../../src/passes/compound_suffix_seed_perf_wbtest.mbt
  - ../../../../../src/cmd/compound_suffix_seed_wbtest.mbt
  - ../../../../../src/passes/statement_type_seed_wbtest.mbt
  - ../../../../../src/passes/statement_type_seed_perf_wbtest.mbt
  - ../../../../../src/cmd/statement_type_seed_wbtest.mbt
  - ../../../../../src/passes/dae2_alias_index_bounds.mbt
  - ../../../../../src/passes/wide_reverse_alias_wbtest.mbt
  - ../../../../../src/passes/wide_reverse_alias_perf_wbtest.mbt
  - ../../../../../src/cmd/wide_reverse_alias_wbtest.mbt
  - ../../../../../src/cmd/dae2_sparse_replay_wbtest.mbt
  - ../../../../../src/passes/dae2_sparse_replay_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_sparse_replay_wbtest.mbt
  - ../../../../../src/passes/dae2_sparse_replay.mbt
  - ../../../../../src/passes/dae2_raw_conditionals.mbt
  - ../../../../../src/passes/dae2_raw_conditionals_wbtest.mbt
  - ../../../../../src/passes/dae2_raw_conditionals_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_raw_analysis.mbt
  - ../../../../../src/passes/dae2_stack_suffix_rewrite.mbt
  - ../../../../../src/cmd/dae2_raw_conditionals_wbtest.mbt
  - ../../../../../src/passes/fused_alias_wbtest.mbt
  - ../../../../../src/passes/fused_alias_reference_wbtest.mbt
  - ../../../../../src/passes/fused_alias_perf_wbtest.mbt
  - ../../../../../src/cmd/fused_alias_wbtest.mbt
  - ../../../../../src/passes/reverse_alias_wbtest.mbt
  - ../../../../../src/passes/reverse_alias_reference_wbtest.mbt
  - ../../../../../src/passes/reverse_alias_perf_wbtest.mbt
  - ../../../../../src/cmd/reverse_alias_wbtest.mbt
  - ../../../../../src/passes/single_leaf_wbtest.mbt
  - ../../../../../src/passes/single_leaf_reference_wbtest.mbt
  - ../../../../../src/passes/single_leaf_perf_wbtest.mbt
  - ../../../../../src/cmd/single_leaf_wbtest.mbt
  - ../../../../../src/passes/balanced_tree_wbtest.mbt
  - ../../../../../src/passes/balanced_tree_reference_wbtest.mbt
  - ../../../../../src/passes/balanced_tree_perf_wbtest.mbt
  - ../../../../../src/cmd/balanced_tree_wbtest.mbt
  - ../../../../../src/passes/terminal_ranges_wbtest.mbt
  - ../../../../../src/passes/terminal_ranges_reference_wbtest.mbt
  - ../../../../../src/passes/terminal_ranges_perf_wbtest.mbt
  - ../../../../../src/cmd/terminal_ranges_wbtest.mbt
  - ../../../../../src/passes/producer_ranges_wbtest.mbt
  - ../../../../../src/passes/producer_ranges_reference_wbtest.mbt
  - ../../../../../src/passes/producer_ranges_perf_wbtest.mbt
  - ../../../../../src/cmd/producer_ranges_wbtest.mbt
  - ../../../../../src/passes/balanced_ranges_wbtest.mbt
  - ../../../../../src/passes/balanced_ranges_bounds_wbtest.mbt
  - ../../../../../src/passes/balanced_ranges_reference_wbtest.mbt
  - ../../../../../src/passes/balanced_ranges_perf_wbtest.mbt
  - ../../../../../src/cmd/balanced_ranges_wbtest.mbt
  - ../../../../../src/passes/dae2_local_aliases_wbtest.mbt
  - ../../../../../src/passes/dae2_local_aliases_reference_wbtest.mbt
  - ../../../../../src/passes/dae2_local_aliases_perf_wbtest.mbt
  - ../../../../../src/cmd/dae2_local_aliases_wbtest.mbt
  - ../../../../../src/passes/dae2_compaction_admission_wbtest.mbt
  - ../../../../../src/passes/dae2_compaction_admission_reference_wbtest.mbt
  - ../../../../../src/passes/dae2_compaction_admission_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_local_counting_wbtest.mbt
  - ../../../../../src/passes/dae2_local_counting_perf_wbtest.mbt
  - ../../../../../src/cmd/dae2_stack_suffix_wbtest.mbt
  - ../../../../../src/passes/dae2_stack_suffix_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_stack_suffix_admission_wbtest.mbt
  - ../../../../../src/passes/dae2_stack_suffix_wbtest.mbt
  - ../../../../../src/passes/dae2_parameter_aliases_wbtest.mbt
  - ../../../../../src/passes/dae2_parameter_aliases_reference_wbtest.mbt
  - ../../../../../src/passes/dae2_parameter_aliases_perf_wbtest.mbt
  - ../../../../../src/cmd/dae2_parameter_aliases_wbtest.mbt
  - ../../../../../src/passes/dae_stack_effect_ref_eq_wbtest.mbt
  - ../../../../../src/cmd/dae_stack_effect_ref_eq_wbtest.mbt
  - ../../../../../src/passes/dae2_capture_callbacks_wbtest.mbt
  - ../../../../../src/passes/dae2_capture_callbacks_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_capture_callbacks_reference_wbtest.mbt
  - ../../../../../src/passes/dae2_scalar_forwarding_wbtest.mbt
  - ../../../../../src/passes/dae2_scalar_forwarding_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_scalar_forwarding_reference_wbtest.mbt
  - ../../../../../src/cmd/dae2_scalar_forwarding_wbtest.mbt
  - ../../../../../src/passes/dae2_balanced_captures_wbtest.mbt
  - ../../../../../src/passes/dae2_balanced_captures_perf_wbtest.mbt
  - ../../../../../src/passes/dae2_balanced_captures_reference_wbtest.mbt
  - ../../../../../src/cmd/dae2_balanced_captures_wbtest.mbt
  - ../../../../../src/ir/local_graph_read_flow_wbtest.mbt
  - ../../../../../src/ir/local_graph_read_flow_perf_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_carried_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_carried_reference_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_carried_perf_wbtest.mbt
  - ../../../../../src/ir/hot_source_order.mbt
  - ../../../../../src/ir/hot_region_fields_wbtest.mbt
  - ../../../../../src/ir/hot_region_fields_reference_wbtest.mbt
  - ../../../../../src/ir/hot_region_fields_perf_wbtest.mbt
  - ../../../../../src/ir/hot_labels.mbt
  - ../../../../../src/ir/hot_region_edit.mbt
  - ../../../../../src/ir/hot_query.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/signature_lookup_wbtest.mbt
  - ../../../../../src/passes/signature_lookup_reference_wbtest.mbt
  - ../../../../../src/passes/signature_lookup_perf_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_minimum_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_minimum_reference_wbtest.mbt
  - ../../../../../src/ir/hot_source_order_minimum_perf_wbtest.mbt
  - ../../../../../src/ir/local_graph_source_union_wbtest.mbt
  - ../../../../../src/ir/local_graph_source_union_perf_wbtest.mbt
  - ../../../../../src/ir/local_graph_entry_reads_wbtest.mbt
  - ../../../../../src/ir/local_graph_entry_reads_reference_wbtest.mbt
  - ../../../../../src/ir/local_graph.mbt
  - ../../../../../src/ir/local_graph_sparse.mbt
  - ../../../../../src/ir/local_graph_write_facts_wbtest.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_lower_input_header_wbtest.mbt
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/ir/catch_payload_preflight_wbtest.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp
  - ../../../../../src/passes/dae2_module_env_wbtest.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/pull/8903
  - https://github.com/WebAssembly/binaryen/pull/8994
  - ../../../../../src/passes/dead_argument_elimination2.mbt
  - ../../../../../src/passes/dae2_repeated_solve_perf_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_types.mbt
  - ../../../../../src/passes/dead_argument_elimination2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt
related:
  - ./index.md
  - ./fuzzing.md
  - ../../version-132-upgrade.md
---

# Starshine DAE2 implementation

**Native counter scope correction (September 30):** the callback section below
also supersedes earlier descriptions of allocator or query-call counts as
dependency-window-only. Toggled event collection scopes instruction totals;
call counters retain the whole command. Historical values remain evidence under
that broader call domain. Direct code-site budgets and whole-command profiles
retain their stated scope.



## September 30, 2026: rejected scalar prefix-counter trial

V60 replaces the prefix builder's `makei` callback with a scalar loop over a
zero-filled array. A red generated-C budget detects two boxed counters in V59;
the candidate has zero, with the same one lazy body scan and exact V59 output.
The allocation count alone does not establish a performance win. Reject this
trial and restore V59's accepted implementation.

All 13,101 default tests, info/fmt/release build, ten native rows and existing
work budgets pass. The 1,442-module / 10,269-observation original-primary replay
has no mismatch or changed output. Small/large raw and canonical artifacts,
every body and non-code section are byte-identical to V59. No public API changes.

Native bounded-discovery means V59→V60, µs: short 8 0.351→0.367,
two-byte 8 3.68→3.75, two-byte 512 28.17→26.34, two-byte 4096
189.28→198.38 (+4.81%), three-byte 8 392.57→396.98. The 4096-copy
regression is greater than the reported spread; the 512-copy benefit is mixed
with a faster legacy control and larger predecessor spread. The replacement
also zeroes the whole bounds array before writing every entry.

The first three-pair large optimizing cohort gives 7560.015→6961.457 ms
(-7.92%, MAD 221.539/144.142), despite the mixed local benchmarks. Retain it,
but do not attribute it to removing two boxes. A separately retained seven-pair
repeat gives 7456.854→7500.883 ms (+0.59%, MAD 46.976/116.907), with exact
bytes. The early enclosing reduction is not reproduced. Three-pair small
optimizing is 10.052→9.992 ms; tee is 105.427→106.120. Optimizing RSS is
290124→290204 KiB; historical plain RSS bimodality remains. Do not multiply
these percentages into earlier checkpoints or promote V60's fresh oracle to
the current accepted baseline.

A bounded balanced-tail probe on 8/32 imported produce/tick/consume groups
records zero qualifying query/read calls; another cleanup path handles them
first. Both outputs equal unprofiled runs, but the probe fails its activity
assertion and is rejected as performance/coverage evidence. Do not use it to
justify a suffix cache or conclude the compiler's repeated scans are absent.
The actual compiler profile still motivates carrier/query ownership work.

Local artifacts under `.tmp/dae2-lean-20260929/`: `candidate-v60.json`,
`validation-v60.json`, `wide-bounds-allocation-v59.json` (red),
`wide-bounds-allocation-v60.json`, `v60-bench.log`, `oracle-v60-*`,
`pairs-v60-*`, `pairs-v60-large-repeat/`, `memory-v60/`,
`balanced-tail-coverage-v59/`, and the restored V59 source manifest. Source
hashes remain frozen through all trial cohorts and the repeat before restoration.
The accepted size improvement and 232,292-byte gap remain at V59.

## September 30, 2026: final-index bounds for reverse aliases

The focused regression initially retains 130 locals instead of 129 for a
source 129 → target 128 copy with 128 stable producer locals. The old guard cannot
prove a wider reverse edge safe: equal original LEB widths may diverge when
compaction puts the target at 127 and source at 128.

[Final-index bounds](../../../../../src/passes/dae2_alias_index_bounds.mbt)
extend [alias discovery](../../../../../src/passes/dae2_parameter_aliases.mbt)
without changing dominance, single-write, lexical restoration or remap rules.
Initially retained prefix ranks bound the root's final index above. Protected
slots and guaranteed noncopy writers bound a retained target's index below.
Admit the reverse edge only when the source's upper LEB width is no greater
than the target's lower width. Potential copy writers are excluded from the
lower bound even when actual discovery will reject them. Discovery retires no
writes and introduces reads only on already retained roots, so lazy construction
does not invalidate the upper bound. Facts require one body/local scan, are
reused across candidates, and are released before the final remap. Short-index
and forward edges use the existing cheap proof.

[Regressions](../../../../../src/passes/wide_reverse_alias_wbtest.mbt) cover
i32/i64/f64/externref, indexed GC references, sets/tees, sparse final indices,
127/128 compaction rejection, all five unsigned LEB bands, nested/loop
dominance, future and sibling writers, validation and input ownership. The
[active dispatcher](../../../../../src/cmd/wide_reverse_alias_wbtest.mbt)
checks retained locals and producer/consumer calls. All 13,101 default tests,
info/fmt/native build, and existing generated-C work/storage guards pass; no
public `.mbti` changes. Long randomized signoff remains deferred by the user.

The 44 new fixtures execute 308 original/previous/current/v133 modules and 1,848
observations, including imported-call exceptions, traps, defaults, branches,
loop iterations and GC/reference identity. All match the original; 38 optimizing
outputs change, none grows in raw or canonical bytes. Existing bounded replay
also passes: 1,134 modules and 8,421 observations. Together this checkpoint has
1,442 modules and 10,269 observations, not a randomized-fuzz signoff.

The large optimizing artifact loses 25,453 raw and 26,177 canonical bytes across
238 functions, with no per-function size increase and exact non-code section
identity against V58. This closes 10.13% of its previous canonical gap. Small
and large plain outputs remain byte-identical to V58. The remaining canonical
gap is 232,292 bytes; 7,866 functions remain larger and 2,380 smaller than v133.
The largest body gaps are defined 7292: +8,454 bytes,10435: +4,702,7293: +3,997.

This is an artifact size win with flat enclosing optimizing timing, not a speed
parity claim. The reduced i32 flat fixture shrinks 1,381 → 1,378 bytes and ties
v133 at 1,378. Explicit nonempty normalized WAT still differs: Starshine removes
an unused declaration and renumbers the root, while v133 retains it. Fewer
locals alone do not prove a win; this equal-size shape remains a parity gap.
Among the 44 optimizing fixtures, 32 tie v133 canonical size, 11 remain larger
and one is smaller. Tee cases retain 257-byte gaps, future-write cases 3 bytes;
these pre-existing cleanup families remain open and do not grow against V58.
The corrected comparison has 44/44 plain normalized matches and 0/44 optimizing
matches (previous 10/44). Do not substitute byte validity or runtime replay for
that output-quality gap. An earlier empty-stdout comparison is invalid and
retained as `normalized-empty-invalid.json`; explicit `-S -o` files plus a
nonempty module assertion replace it.

The [dedicated native controls](../../../../../src/passes/wide_reverse_alias_perf_wbtest.mbt)
measure the extra admission cost against the old rejecting guard. Fixtures,
validation, actual compaction and ownership checks sit outside timing.

| Prefix / copies | Legacy discovery µs | Bounded discovery µs |
| --- | ---: | ---: |
| Short indices / 8 | 0.348 | 0.351 |
| 128 stable / 8 | 2.36 | 3.68 |
| 128 stable / 512 | 16.91 | 28.17 |
| 128 stable / 4096 | 115.85 | 189.28 |
| 16384 stable / 8 | 241.12 | 392.57 |

All ten rows pass. Additional work scales linearly; it is not a native speedup.
Generated C currently boxes the two prefix counters; this is a possible setup
follow-up, not an attributed compiler bottleneck. The unchanged plain control
and small timing differences below are not causal gains. Historical plain RSS
bimodality remains; optimizing RSS is approximately flat.

Frozen native V59 SHA-256: `c3c9c97e610bf31c5572392c47eac488687372a3098af98c9fff90c9e008605b`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.753 | 1.012 | 3.707× | -123 / -97 B |
| small / `dae2-optimizing` | 11.972 | 3.232 | 3.705× | -392 / -290 B |
| large / `dae2` | 3998.720 | 563.604 | 7.095× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 7479.616 | 1835.960 | 4.074× | +103,433 / +232,292 B |

Matched V58→V59 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V58 ms | V59 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.693 | 3.654 | -1.06% | 0.096 / 0.109 |
| small / `dae2-optimizing` | 10.220 | 10.118 | -1.00% | 0.058 / 0.096 |
| large / `dae2` | 3767.740 | 3718.861 | -1.30% | 35.385 / 19.452 |
| large / `dae2-optimizing` | 6541.373 | 6551.199 | +0.15% | 11.222 / 80.654 |
| tee / `dae2` | 2.888 | 2.898 | +0.35% | 0.006 / 0.006 |
| tee / `dae2-optimizing` | 104.378 | 105.037 | +0.63% | 0.781 / 0.830 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 265,584 [245,864–265,784] → after 246,752 [245,508–265,928].
- `dae2-optimizing`: before 290,160 [290,100–290,200] → after 290,368 [290,056–291,288].

Local provenance under `.tmp/dae2-lean-20260929/`: `candidate-v59.json`,
`validation-v59.json`, `validate-wide-alias-v59.py`, `finish-wide-alias-v59.py`,
`wide-alias-runtime-v59/`, `wide-alias-normalized-v59.py`,
`artifact-quality-v59.json`, `remaining-size-v59.json`, `pairs-v59-*`,
`memory-v59/`, and the preserved predecessor controls. Both artifact cohorts,
extra probes and full source hashes finish before the next source mutation.
Next larger targets remain repeated carrier/balanced-suffix scans, validation
stack-copy churn and the remaining optimizing body gaps. Keep all-DAE timing
renewal, aggregate fuzz and release signoff open.

## September 30, 2026: sparse replay boundaries and ownership

A per-module workspace keeps an owned immutable boundary mask, reusable
expression graph, epoch marks and distinct consumer rows. The existing HOT
analysis emits boundary-consumer edges only for the function result and called
parameter/results. Its original direct/indirect/reference/tail-call summary is
complete before rewrites; captures introduce no calls. Register these consumers,
seed live rows that have actual edges, and retain their heads for the next reset.
Successful reset truncates expression storage and clears only those boundary
rows. Original true bits stay true; every newly true bit enters the body's
worklist, so checking that queue reproduces the old full-prefix comparison.
Missing/invalid metadata or underestimated demand requests the existing complete
HOT fallback. Failed workspace reuse restores the full mask; epoch wrap clears
marks once. The normal graph edge/solver paths are unchanged.

The first work-budget regression failed with 127 unrelated queued boundaries
instead of zero. Focused tests require exact expression/boundary masks and
adjacency against legacy replay, alternating bodies, duplicate consumers,
recursive/indirect/reference/tail/tuple calls, GC values, branches/loops,
underestimated demand, invalid metadata, failed reuse and forced epoch wrap.
The dispatcher covers indirect conditional arms under both pass names.

The V57 trial retained the entire solved expression mask in its source field.
Its plain RSS pair measured 245,632→266,724 KiB; this trial was rejected as the
final design. A retention regression then failed with 36 locations instead of
four. V58 copies only the boundary prefix, owns that mask independently from
both the source and mutable replay graph, and retains no source adjacency.
A bounded native probe confirms **399 sparse resets / zero full resets**, no
failed resets and exactly **46,613 retained mask locations** on the large plain
artifact. Its output bytes equal the unprofiled frozen output. This eliminates
the prior 399 × 46,613 boundary-reset work without retaining expression masks
through finalization. Snapshot initialization remains O(boundaries) once per
module; per-body work follows its consumers, expression edges and work queue.

`moon info`, `moon fmt`, all **13,093** default tests, the release CLI and all
**12** native controls pass with no public API change. Bounded original/V56/
verified-release-v133 replay covers **1,134 modules / 8,421 observations**.
Raw and canonical small/large compiler bytes and all bounded runtime outputs
match V56 exactly. Long aggregate fuzz and release/shared-consumer renewal
remain deferred until performance bottleneck trials settle.

Native controls compare the previous full reset/seed/check against sparse
replay in the same binary, over 16 alternating bodies. Setup, complete graph
storage/liveness and source ownership checks stay outside timing. Boundary
counts vary independently from expression counts to expose module-size × body
work; the smaller case measures overhead and the larger bodies retain useful
solve work rather than timing an empty graph.

| Boundaries / expression nodes | Full µs | Sparse µs | Change |
| --- | ---: | ---: | ---: |
| 128 / 8 | 8.74 | 1.57 | -82.04% |
| 128 / 128 | 25.18 | 18.42 | -26.85% |
| 8,192 / 8 | 458.37 | 2.33 | -99.49% |
| 8,192 / 128 | 484.84 | 18.48 | -96.19% |
| 65,536 / 8 | 3630.00 | 1.81 | -99.95% |
| 65,536 / 128 | 3670.00 | 19.05 | -99.48% |

Frozen native V58 SHA-256: `48bfd6f3b15db2ed2077b6dc7b85eef76bfade46bd915d04779966d2e75a02f3`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.533 | 0.966 | 3.657× | -123 / -97 B |
| small / `dae2-optimizing` | 11.725 | 3.041 | 3.856× | -392 / -290 B |
| large / `dae2` | 3434.586 | 437.007 | 7.859× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 6474.372 | 1645.450 | 3.935× | +128,886 / +258,469 B |

Matched V56→V58 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V56 ms | V58 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.311 | 3.350 | +1.18% | 0.030 / 0.098 |
| small / `dae2-optimizing` | 9.825 | 15.601 | +58.79% | 0.360 / 0.723 |
| large / `dae2` | 3644.112 | 3599.451 | -1.23% | 1.568 / 52.560 |
| large / `dae2-optimizing` | 6481.543 | 6486.935 | +0.08% | 48.764 / 0.834 |
| tee / `dae2` | 2.937 | 2.866 | -2.42% | 0.066 / 0.003 |
| tee / `dae2-optimizing` | 104.869 | 102.447 | -2.31% | 0.913 / 0.800 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 266,212 [265,876–267,636] → after 246,228 [245,860–255,964].
- `dae2-optimizing`: before 289,860 [289,856–290,136] → after 290,072 [289,896–290,108].

The initial small optimizing wall median is distorted by slow samples on both
sides: roughly 23 ms command wall versus 14 ms CPU, compared with fast runs near
14 ms wall/CPU. Keep those accepted samples; the reference bracket did not
exclude them. A separate seven-pair repeat measures plain
**3.779→3.524 ms (-6.75%)**, MAD 0.254/0.085, and optimizing
**10.333→10.718 ms (+3.73%)**, MAD 0.200/0.310. Corresponding whole-command CPU
medians are **8.296→8.261** and **15.039→15.119 ms**. The residual small optimizing
cost stays open; do not describe the original +58.79% as a proved intrinsic
regression or replace it silently with the repeat.

Large plain rewrite improves **1003.414→911.989 ms (-91.425 ms)** while enclosing
plain is -1.23% with candidate MAD 52.560 ms. The earlier V57 cohort measured
-2.22% with low MAD but retained too much source storage. Large optimizing is
flat (+0.08%). The current plain RSS median is lower, but prior cohorts are
bimodal and this candidate ranges 245,860–255,964 KiB; the owned-prefix invariant
is proven, while a universal RSS-saving claim is not. Optimizing RSS stays flat.
Speed parity and the **258,469 canonical / 128,886 raw-byte** optimizing gap remain
open. Smaller plain output alone does not prove a Starshine win.

A separate bounded native stack sample contains **316** 20–26 ms samples,
maximum 600, with 24-frame depth and exact unprofiled output. Inclusive counts
overlap: DAE2 module work appears in 124, HOT function pipeline work in 63,
Expr typechecking in 44, analysis in 42, raw SimplifyLocals in 36 and complete
node reads in 12. Leaf samples include 36 object destructions, 27 allocator
slow paths and 16 frees. Node-read callers span source/flow, CFG, lowering,
verification and cleanup; this does not establish that one getter owns all
costs. The original thread-timer sampler and the first signal configuration
produced zero samples and are rejected, not profiling evidence. Debugger wall
time is excluded from benchmark claims.

Next output-quality trial: reverse aliases with wider original LEB indices
need conservative **final-index** bounds; merely equal original widths can
widen after compaction. Derive lower ranks from locals that cannot be alias
writers and upper ranks from initially retained locals, preserving dominance,
source order, effects/traps, defaults, lexical restoration and exact byte guards.
Also retain remaining dependency/lift/lower, allocation/source queries and raw
carrier cleanup costs. Use the sample to select targeted experiments, rather
than summing overlapping percentages or claiming completion of P03.

Sources: [workspace](../../../../../src/passes/dae2_sparse_replay.mbt),
[graph and ownership regressions](../../../../../src/passes/dae2_sparse_replay_wbtest.mbt),
[scaling controls](../../../../../src/passes/dae2_sparse_replay_perf_wbtest.mbt),
[dispatcher](../../../../../src/cmd/dae2_sparse_replay_wbtest.mbt), and
[caller](../../../../../src/passes/dead_argument_elimination2.mbt).
Local evidence under `.tmp/dae2-lean-20260929/`: `validation-v58.json`,
`validate-sparse-replay-v58.py`, `finish-sparse-replay-v58.py`,
`v58-{retention-tdd,bench}.log`, `v57-tdd.log`, `v58-bench-summary.json`,
`oracle-v58-{small,large}/`, `pairs-v58-{small,large,tee,small-repeat}/`,
`memory-v58/`, `raw-replay-coverage-v58/`, `sample-large-v58-attempt3/`,
`v58-plain-phase-comparison.json`, bounded runtime directories and preserved
V57 retention/zero-sample attempts. Full source hashes are checked before/after
both cohorts. The verified v133 oracle/input hashes remain those recorded below.


## September 30, 2026: raw fallthrough control dependencies

The existing flat planner remains first. A separate preflight admits no-input
void/single-value blocks and fallthrough conditionals, using the established
pure/observer/trapping-producer opcode classifiers. It declines loops, branches,
handlers, unreachable instructions, indexed control types, nested returns and
intrinsics. Qualification and partial symbolic execution never mutate the
module graph; existing function validation precedes commit.

One function-local value array and a sparse undo journal replace branch-wide
local copies. An arm allocates write rows only when it writes, restores entry
values in reverse order, then joins distinct final definitions. Unwritten arms
retain entry values. Nested controls enforce stack floors, and conditions remain
observed even when arm results are dead, matching the current HOT contract.

Each source write receives a symbolic demand location, including constant writes
and tee results. Lexically ordered local/location rows feed structured suffix
replay. This preserves its demanded-write proof without requiring an analysis
lift. Missing these facts in the first trial rejected an existing replay and
moved an initial constant behind the first conditional; the native write controls
failed exact output equality. That trial was rejected and fixed, rather than
retaining an unmeasured shape difference. Raw general rewrite admission is still
separate and unchanged. Shared opcode classifiers avoid divergent leaf families;
the existing flat execution loop is preserved to limit its control costs.

TDD first recorded five failing admission/lift regressions out of six cases.
A further producer-order/replay regression failed before write-demand support.
The final ten focused families compare every solved function/type boundary and
each conditional source-write demand against HOT in both worlds, including
unchanged functions that never replay. Cases cover entry/default/overwritten and
nested writes, tee results, scalar/reference/GC values, prefix stack slots,
tuple results, direct/indirect/reference calls, effects and traps. Intentionally
unsupported control and invalid stack/local fixtures preserve HOT fallback and
atomic rejection. The dispatcher checks both DAE2 modes. Existing HOT work-count
regressions retain explicit forced-HOT controls; current mutable branches also
verify zero LocalGraph construction.

`moon info`, `moon fmt`, all **13,087** default tests, the release CLI build and
all **24** native controls pass. No public `.mbti` change or new warning was
introduced. Bounded original/V55/release-v133 replay covers **1,134 modules /
8,421 observations**, including **385 / 3,850** new conditional cases: both arms,
repeated/overwritten/default stores, import exceptions and ordered effects,
loads/division/stores and traps, tuple/reference calls, NaN/signed zero, i64 and
GC/reference identity. Output bytes match V55 exactly on every replay and on
both raw/canonical small and large compiler artifacts. Long aggregate fuzz and
shared-consumer/release renewal remain deferred until bottleneck trials settle.

Native controls compare conditional admission enabled/disabled in one binary,
retaining the same flat raw analysis and rewrite on both sides. Setup, complete
output equality, lift counts, signature/validation and input ownership checks
are outside timing. Tiny rows use one helper/eight controls/eight locals; wide
rows use 32 helpers/128 controls/eight locals; sparse rows use one helper/128
controls/4,096 locals. Results and write cases expose avoided HOT/CFG work;
flat and loop cases exercise the existing path and conservative fallback.

| Control | Conditional off µs | Conditional on µs | Change |
| --- | ---: | ---: | ---: |
| tiny results | 42.88 | 29.47 | -31.27% |
| tiny writes | 81.85 | 31.59 | -61.41% |
| tiny flat | 20.46 | 19.80 | -3.23% |
| tiny loop | 30.20 | 29.95 | -0.83% |
| wide results | 14460.00 | 7410.00 | -48.76% |
| wide writes | 48760.00 | 9580.00 | -80.35% |
| wide flat | 2470.00 | 2480.00 | +0.40% |
| wide loop | 4950.00 | 4930.00 | -0.40% |
| sparse results | 433.92 | 223.69 | -48.45% |
| sparse writes | 1480.00 | 281.12 | -81.01% |
| sparse flat | 263.00 | 269.38 | +2.43% |
| sparse loop | 191.62 | 193.44 | +0.95% |

Frozen native V56 SHA-256: `ddbf89321f87824ccc7c8621188f83928e4f9e5fe62ca5fe5cd1dbb81eb166ae`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.644 | 0.999 | 3.649× | -123 / -97 B |
| small / `dae2-optimizing` | 11.851 | 3.247 | 3.649× | -392 / -290 B |
| large / `dae2` | 3683.989 | 460.530 | 7.999× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 6859.218 | 1730.190 | 3.964× | +128,886 / +258,469 B |

Matched V55→V56 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V55 ms | V56 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.230 | 3.500 | -17.26% | 0.360 / 0.045 |
| small / `dae2-optimizing` | 11.762 | 11.413 | -2.97% | 0.048 / 0.517 |
| large / `dae2` | 3749.917 | 3895.188 | +3.87% | 25.916 / 150.983 |
| large / `dae2-optimizing` | 6615.352 | 6664.800 | +0.75% | 2.490 / 126.511 |
| tee / `dae2` | 2.900 | 2.926 | +0.90% | 0.025 / 0.014 |
| tee / `dae2-optimizing` | 104.995 | 103.898 | -1.04% | 0.513 / 0.496 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 280,576 [245,468–281,516] → after 267,264 [266,064–268,476].
- `dae2-optimizing`: before 290,124 [290,096–290,180] → after 290,036 [290,016–290,172].

The initial large medians do not establish an enclosing gain. A separate
seven-pair repeat retains costs: plain **3945.220→4110.194 ms (+4.18%)**, MAD
119.589/116.554 ms; optimizing **6665.418→6792.294 ms (+1.90%)**, MAD
93.681/102.385 ms. Keep these costs open. The initial small plain improvement
is larger than either MAD; small optimizing and tee changes remain limited
controls. Native active rows improve 31–81%, but unchanged sparse flat/loop
controls cost 2.43%/0.95%; no universal speed claim follows.

Paired large-plain phase medians show less analysis work: initially analysis
1903.414→1844.929 ms, lift 698.355→663.121 and dependency construction
1155.384→1113.684. The repeat gives analysis 1933.366→1911.900, lift
710.891→689.882 and dependencies 1170.642→1146.018 ms, while rewrite grows
996.831→1124.892 ms. These overlapping scopes locate work; they do not prove
that one routine causes the entire enclosing cost.

A bounded native debugger probe counts actual planner returns on the large
plain artifact: **10,721 attempts / 2,767 admissions / 7,954 rejections**.
This replaces the earlier 2,774-function control-shape upper bound as coverage
evidence; it does not certify unsupported families. Another probe counts
**399 replay resets × 46,613 module boundaries = 18,598,587 boundary slots**,
before counting the multiple initialization/seeding/check loops. The current
workspace resets and checks all module boundaries for every rewritten raw body,
although that body's consumers are its result and called signatures. This
module-size-times-rewritten-body work is the next priority. Preserve full
expression/boundary liveness, source-write demand, metadata validity and
underestimated-projection fallback while making it sparse. The admission probe also
counts 1,613 replacement-signature appends; that counts appends, not allocation
bytes or proof that interning is the largest timing target. Debugger outputs
match the unprofiled oracle artifacts exactly; debugger wall time is excluded.

Plain peak RSS has a lower candidate median but the before range is wide and
bimodal, so a stable memory-saving claim remains unproved. Optimizing RSS is
flat. The **258,469 canonical / 128,886 raw-byte** optimizing gap and speed
parity remain open.

Local reproduction/evidence remains under `.tmp/dae2-lean-20260929/`:
`validate-raw-conditionals-v56.py`, `finish-raw-conditionals-v56.py`,
`validation-v56.json`, `v56-bench{.log,-summary.json}`, `raw-conditionals-runtime-v56/`,
`local-alias-runtime-v56/`, `parameter-alias-runtime-v56/`, `runtime-v56/`,
`oracle-v56-{small,large}/`, `pairs-v56-{small,large,tee,large-repeat}/`,
`memory-v56/`, `raw-conditional-coverage-v56/`, `raw-replay-coverage-v56/`,
`v56-plain{,-repeat}-phase-comparison.json` and the preserved rejected attempts.
The probe asserts the frozen binary/source hashes and exact unprofiled bytes.
CPU affinity, oracle hashes and reference brackets follow the preceding dossiers.


## September 30, 2026 fused alias discovery and remap

Alias discovery now walks the original instruction/control tree without
materializing a forwarded copy. An integer virtual previous-read/root replaces
instruction-option alias state. It updates read counts and records proven
writer roots with the existing lexical undo discipline. The original body is
borrowed unchanged; all three storage regressions fail on frozen V54 first.
The generated native V54 path has two instruction-materialization sites:
an Instruction-array allocation and a reconstructing child visitor.

The required final compaction remap now replays writer activations, forwards
reads to their resolved roots and deletes only aliases whose final local index
is negative. Partial aliases retain their writes and earlier/default reads;
forwarded reads still use the root. Each child/sibling/handler restores its
active roots on exit. The discovery workspace is reused after undo restores
it; ordinary-writer facts are released before remap. No extra graph traversal
or producer duplication is introduced. The cheap no-alias path remains intact.

The private discovery return carries a plan rather than a rewritten body;
its sole production caller applies that plan during remap. Direct tests apply
the new private contract and retain their exact final rewrite expectations.
No public API is changed. Every admitted source is a nonalias root under the
same one-writer/dominating-scope rules proved by V54; nonwidening index admission
is unchanged. The remap always constructs the final output; borrowed input
storage remains read-only.

Three red-first storage/replay regressions plus existing root/default/tee/
loop/handler/width tests compare complete compaction with frozen V54. Twenty
native complete-compaction controls cover reverse/forward copies, no aliases,
partial/default aliases and nested aliases at widths 8/64. Setup, exact output
validation and input ownership checks occur outside timed loops. All artifact
raw/canonical bytes and bounded runtime observations must remain identical to
V54. Frozen release binaries are compared against verified release Binaryen
v133 on small/large compiler inputs, and against each other with alternating
pairs, independent reference brackets, MAD and RSS. Long fuzz remains deferred.

`moon info`, `moon fmt`, **13,076** default tests, release native build,
all **20** native controls and existing alias/suffix/dispatcher guards pass.
No public API change or new warning category occurs. Native discovery's two
instruction-materialization sites become **zero**, including the private
child walker. Complete compaction preserves exact frozen-reference output.

Native complete-compaction means:

| Width / shape | V54 µs | V55 µs | Change |
| --- | ---: | ---: | ---: |
| 8 reverse copy | 1.61000 | 1.48000 | -8.07% |
| 8 forward copy | 1.62000 | 1.51000 | -6.79% |
| 8 no alias | 0.39511 | 0.33389 | -15.49% |
| 8 partial alias | 2.04000 | 1.97000 | -3.43% |
| 8 nested alias | 2.31000 | 1.90000 | -17.75% |
| 64 reverse copy | 11.64000 | 9.96000 | -14.43% |
| 64 forward copy | 11.15000 | 9.81000 | -12.02% |
| 64 no alias | 2.23000 | 2.22000 | -0.45% |
| 64 partial alias | 15.56000 | 12.89000 | -17.16% |
| 64 nested alias | 16.43000 | 12.95000 | -21.18% |

Frozen native V55 SHA-256: `14a531305a5a83b732d61fa4c1d86d2db588add421e526372c6119c112c5109e`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.220 | 1.190 | 3.548× | -123 / -97 B |
| small / `dae2-optimizing` | 14.443 | 3.447 | 4.190× | -392 / -290 B |
| large / `dae2` | 3756.280 | 469.084 | 8.008× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 6969.606 | 1733.970 | 4.019× | +128,886 / +258,469 B |

Matched V54→V55 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V54 ms | V55 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 6.116 | 3.938 | -35.61% | 1.938 / 0.051 |
| small / `dae2-optimizing` | 10.513 | 10.431 | -0.78% | 0.205 / 0.081 |
| large / `dae2` | 3748.956 | 3725.572 | -0.62% | 16.989 / 25.287 |
| large / `dae2-optimizing` | 6603.478 | 6609.061 | +0.08% | 25.288 / 113.734 |
| tee / `dae2` | 2.894 | 2.956 | +2.14% | 0.032 / 0.087 |
| tee / `dae2-optimizing` | 103.539 | 103.663 | +0.12% | 0.179 / 0.405 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 244,204 [243,868–280,928] → after 281,120 [245,672–281,264].
- `dae2-optimizing`: before 290,056 [289,928–290,308] → after 290,116 [290,108–290,132].

Active width-64 native controls improve 12–21%, including partial and nested
aliases. Compiler and tee optimizing pairs remain flat within dispersion:
−0.78% small / +0.08% large / +0.12% tee. The first small plain cohort has
three rejected rounds and very large baseline MAD; its −35.61% median change
is not a stable gain. An independent seven-pair repeat gives 4.228→3.820 ms
(−9.65%, MAD 0.446/0.062 ms), with two rejected rounds including warmup.
Its optimizing repeat gives 10.335→10.411 ms (+0.74%, MAD 0.138/0.141 ms),
with two rejected rounds. These repeats do not establish a general speed win.

Initial plain RSS rises from 244,204 to 281,120 KiB with overlapping bimodal
ranges. An independent repeat reverses the medians: 268,100 [244,692–281,124]
→244,852 [243,864–281,320] KiB. There is no stable memory-saving direction;
retain the initial cohort and historical plain memory costs. Optimizing RSS
is close to flat. Small whole-command optimizing instructions fall from
154,324,921 to 154,286,421 (−0.025%), with exact unprofiled output; this is
not a pass-local timer. Most enclosing cost lies outside this alias visitor.

All **749 bounded runtime modules / 4,571 observations** match their originals,
including events, traps, loop values and reference identity. All small/large
raw and canonical artifact bytes match V54 exactly, retaining its 39,161 raw /
40,806 canonical byte saving and the remaining **128,886 raw / 258,469 canonical
byte** v133 gap. No output-shape family is closed by this performance change.

A separate bounded capture-scaling probe uses widths 8/128/1,024, distinct,
reused and nested locals, on frozen V55 plus verified v133 outputs. The simple
pipeline fixtures scale roughly linearly (DAE2-O at width1,024: 1.87–1.96 ms).
They do not prove the balanced helper's repeated tail scans are an enclosing
bottleneck. Profile actual compiler query density before adding tail caches.
This exploratory probe validates outputs and sizes; it is not new runtime or
oracle-timing parity evidence. Long fuzz/release signoff remain deferred.

Sources: [discovery/remap](../../../../../src/passes/dae2_parameter_aliases.mbt),
[sole caller](../../../../../src/passes/lower_capture_cleanup.mbt),
[storage/replay regressions](../../../../../src/passes/fused_alias_wbtest.mbt),
[frozen V54 path](../../../../../src/passes/fused_alias_reference_wbtest.mbt),
[native controls](../../../../../src/passes/fused_alias_perf_wbtest.mbt),
[retained alias guards](../../../../../src/passes/reverse_alias_wbtest.mbt) and
[dispatcher](../../../../../src/cmd/fused_alias_wbtest.mbt).
Local evidence: `.tmp/dae2-lean-20260929/validation-v55.json`,
`candidate-v55.json`, `v55-baseline.json`, `alias-discovery-work-{v54,v55}.json`,
`v55-bench.log`, `oracle-v55-{small,large}/`, `pairs-v55-{small,large,tee}/`,
`pairs-v55-small-repeat/`, `memory-v55/`, `memory-v55-plain-repeat/`,
`profile-small-v55/`, `tail-scaling-v55/`, `local-alias-runtime-v55/`,
`parameter-alias-runtime-v55/` and `runtime-v55/`.

## September 30, 2026 reverse short-index aliases

Alias cleanup now admits higher-index sources below 128 as well as the
existing lower-index sources. Both source and target stay one-byte local
indices under monotone compaction; wider equal-width reverse edges remain
unsupported because compaction can narrow only the target. The same private
width predicate governs cheap admission and the actual transform.

Single-writer and lexical-dominance rules remain: a source is unwritten or
its ordinary writer precedes the alias in the active scope/iteration. Reads
of active aliases resolve to their final root before copy recognition, and
alias writers do not establish ordinary roots. Consequently admitted edges
point to nonalias roots; retirement remains one linear pass without relying
on descending local IDs. Earlier/default reads and sibling/handler reads
retain their original target. Producer evaluation is never duplicated.

Before implementation, six of seven focused regressions and the dispatcher
regression fail on V53. Tests cover scalar and reference types, GC construction,
partial/default reads, flattened mixed-order tee chains, future/multiple source
writes, sibling/handler/loop scope and the 127/128 local-index boundary.

Frozen V53/V54 native controls compare reverse-copy compaction with existing
forward-copy and no-alias paths at widths 8 and 64. Setup, typing, input
ownership and output-size checks occur outside timed loops. Artifact evidence
uses verified Binaryen release v133, CPU 6, one warmup, three samples,
alternating predecessor pairs with reference-drift rejection, MAD and RSS.
Every compiler function is audited for raw growth and exact preservation of
nonlocal opcode/immediate streams and non-code semantic sections. Bounded
runtime replay compares originals with predecessor, candidate and v133,
including changing per-iteration producers, thrown imports, memory traps,
handler/default paths and GC object identity. Long fuzz remains deferred.

All seven focused tests, dispatcher and related alias/suffix guards, `moon
info`, `moon fmt`, **13,072** default tests, release native build and **12**
native controls pass. No public API change or new warning category occurs.

Native complete-compaction means:

| Width / shape | V53 µs | V54 µs | Change |
| --- | ---: | ---: | ---: |
| 8 reverse copy | 0.32549 | 1.67000 | +413.07% |
| 8 forward copy | 1.64000 | 1.66000 | +1.22% |
| 8 no alias | 0.34862 | 0.34400 | -1.33% |
| 64 reverse copy | 2.07000 | 11.10000 | +436.23% |
| 64 forward copy | 10.98000 | 11.02000 | +0.36% |
| 64 no alias | 2.35000 | 2.32000 | -1.28% |

Frozen native V54 SHA-256: `15092f91dbb53c9ad69466c120b824d9984ebc51457989baa6ccc16407ccb9f1`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.026 | 1.006 | 4.000× | -123 / -97 B |
| small / `dae2-optimizing` | 12.041 | 3.428 | 3.513× | -392 / -290 B |
| large / `dae2` | 3682.545 | 469.123 | 7.850× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 6998.603 | 1738.600 | 4.025× | +128,886 / +258,469 B |

Matched V53→V54 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V53 ms | V54 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.935 | 3.934 | -0.03% | 0.063 / 0.074 |
| small / `dae2-optimizing` | 10.564 | 10.625 | +0.58% | 0.050 / 0.154 |
| large / `dae2` | 3774.807 | 3780.024 | +0.14% | 32.471 / 41.462 |
| large / `dae2-optimizing` | 6646.683 | 6699.535 | +0.80% | 44.310 / 66.450 |
| tee / `dae2` | 2.946 | 2.930 | -0.54% | 0.061 / 0.013 |
| tee / `dae2-optimizing` | 102.487 | 104.185 | +1.66% | 0.111 / 0.108 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 280,320 [245,040–281,328] → after 281,324 [279,376–281,428].
- `dae2-optimizing`: before 289,964 [289,604–290,108] → after 290,012 [289,784–292,276].

Reverse-copy controls now perform cleanup that V53 skipped: their added
cost is explicit, while existing forward/no-alias controls remain close to
flat. Matched compiler optimizing costs +0.58% small / +0.80% large,
within the candidate MADs; active tee costs +1.66%, greater than either MAD.
Keep the tee cost open. Plain timings and RSS are close to flat in this
cohort; historical plain costs remain unresolved. This unit proves an
output-size improvement, not a general pass-speed win.

The large artifact removes 9,023 set/get pairs and 1,386 tees. All 12,904
functions preserve nonlocal opcode/immediate streams and non-code semantic
sections, with no raw function growth. Raw output shrinks 39,161 bytes and
canonical output shrinks 40,806 bytes. The remaining v133 gap is **128,886
raw / 258,469 canonical bytes**; 7,884 canonical function bodies remain
larger and 2,362 are smaller. Small optimizing shrinks six bytes. Plain
artifact bytes remain identical to V53. These are measured predecessor
improvements under the scoped-alias contract; overall v133 parity stays open.

All **749 bounded runtime modules / 4,571 observations** agree with their
originals, including effects, traps, changing loop values and reference identity.
The reduced fixture and function audit support the transform contract; they
do not replace deferred aggregate fuzz or final release/shared-consumer signoff.

Sources: [alias implementation](../../../../../src/passes/dae2_parameter_aliases.mbt),
[regressions](../../../../../src/passes/reverse_alias_wbtest.mbt),
[frozen V53 path](../../../../../src/passes/reverse_alias_reference_wbtest.mbt),
[native controls](../../../../../src/passes/reverse_alias_perf_wbtest.mbt) and
[dispatcher](../../../../../src/cmd/reverse_alias_wbtest.mbt).
Local evidence: `.tmp/dae2-lean-20260929/validation-v54.json`,
`candidate-v54.json`, `v54-baseline.json`, `v54-bench.log`,
`oracle-v54-{small,large}/`, `alias-shape-v54.json`, `remaining-size-v54.json`,
`pairs-v54-{small,large,tee}/`, `memory-v54/`, `local-alias-runtime-v54/`,
`parameter-alias-runtime-v54/` and `runtime-v54/`.

Whole-command small optimizing instructions: 154,335,857 → 154,324,921 (-0.007%), with exact unprofiled output. This is not a pass-local timer. Local profile: `profile-small-v54/`.

## September 30, 2026 single-leaf suffix typing

Single-value suffix admission now returns numeric constants and valid local
reads directly. The existing scanner and full typechecker still handle
compound expressions, unknown/out-of-bounds locals, reference constants and
other opcodes. The returned array is owned. This avoids constructing a type
state and initialized-local mask for a leaf whose type is already known.

Numeric-constant typechecking only pushes its fixed scalar type. Local reads
use the same environment bounds check as the original typechecker, whose
suffix state initializes every local. Complete module validation is retained.
Exact floating bits, nullable and nonnullable reference locals, exclusive
end offsets, invalid indices, compound/fallback typing and result ownership
are checked against the frozen original helper. Two focused work assertions
fail before the change, while the dispatcher guard passes.

Measurements use 24 native old/new controls across 8- and 4,096-local
environments, frozen release binaries, fresh verified Binaryen v133 small
and large open-world cohorts, alternating matched pairs with reference-drift
rejection, and matched RSS samples. Whole-command instruction profiles are
reported separately from pass-local wall time. Long fuzz remains deferred.

All three focused regressions, the dispatcher guard, related suffix/copy
regressions, `moon info`, `moon fmt`, **13,064** default tests, the native
release build and **24** native controls pass. No public API change or new
warning category is introduced.

Native means (frozen original helper → single-leaf admission):

| Local count / shape | Before µs | After µs | Change |
| --- | ---: | ---: | ---: |
| 8 constant | 0.12678 | 0.02208 | -82.58% |
| 8 local | 0.13601 | 0.02820 | -79.27% |
| 8 compound | 0.18053 | 0.18511 | +2.54% |
| 8 invalid local | 0.34066 | 0.36634 | +7.54% |
| 8 reference fallback | 0.15104 | 0.15399 | +1.95% |
| 8 empty | 0.01675 | 0.01719 | +2.63% |
| 4096 constant | 0.16285 | 0.02227 | -86.32% |
| 4096 local | 0.17109 | 0.02846 | -83.37% |
| 4096 compound | 0.21396 | 0.22505 | +5.18% |
| 4096 invalid local | 0.36216 | 0.38173 | +5.40% |
| 4096 reference fallback | 0.18442 | 0.19094 | +3.54% |
| 4096 empty | 0.01708 | 0.01695 | -0.76% |

Frozen native V53 SHA-256: `d47c01e8ff54045880fad64173ab844bb9edf764cdaa5759e99f86589c13ad6b`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.122 | 1.006 | 4.097× | -123 / -97 B |
| small / `dae2-optimizing` | 11.847 | 3.251 | 3.644× | -386 / -284 B |
| large / `dae2` | 3920.073 | 473.290 | 8.283× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 7022.732 | 1740.300 | 4.035× | +168,047 / +299,275 B |

Matched V52→V53 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V52 ms | V53 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.944 | 3.781 | -4.13% | 0.011 / 0.003 |
| small / `dae2-optimizing` | 10.480 | 10.482 | +0.02% | 0.037 / 0.007 |
| large / `dae2` | 3709.607 | 3763.067 | +1.44% | 44.338 / 0.537 |
| large / `dae2-optimizing` | 7209.969 | 6849.142 | -5.00% | 92.437 / 105.942 |
| tee / `dae2` | 2.989 | 2.895 | -3.14% | 0.036 / 0.018 |
| tee / `dae2-optimizing` | 107.989 | 108.128 | +0.13% | 0.745 / 1.137 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 240,480 [239,940–240,972] → after 273,908 [240,856–280,032].
- `dae2-optimizing`: before 287,488 [287,368–287,836] → after 287,540 [287,496–287,588].

Leaf controls improve 79–86%; fallback controls cost about 2–8% in these
native means, so this is a narrow admission improvement. Matched large
optimizing improves 5.00% (360.827 ms, larger than either MAD); small and
active-tee optimizing remain flat. Large plain costs 1.44% (53.460 ms,
before MAD 44.338 ms); keep that cost open. Plain peak RSS rises from
240,480 to 273,908 KiB with a wide candidate range; optimizing RSS is flat.
No general speed or memory parity is claimed. A whole-command small
optimizing instruction profile falls from 154,949,402 to 154,335,857
(−0.396%); its output exactly matches the unprofiled command. That profile
is not a pass-local timer and does not explain large plain costs.

All 469 bounded runtime modules / 2,891 observations match their originals,
including events, traps and GC reference identity. V52/V53 raw and canonical
compiler artifact bytes are identical; the large optimizing gap remains
+168,047 raw / +299,275 canonical bytes. Long fuzz and shared-consumer/
release signoff remain deferred.

Sources: [implementation](../../../../../src/passes/pass_manager.mbt),
[leaf regressions](../../../../../src/passes/single_leaf_wbtest.mbt),
[frozen helper](../../../../../src/passes/single_leaf_reference_wbtest.mbt),
[native controls](../../../../../src/passes/single_leaf_perf_wbtest.mbt),
[dispatcher guard](../../../../../src/cmd/single_leaf_wbtest.mbt),
[constant/local typing](../../../../../src/validate/typecheck.mbt) and
[environment bounds](../../../../../src/validate/env.mbt).
Local evidence: `.tmp/dae2-lean-20260929/validation-v53.json`,
`candidate-v53.json`, `v53-baseline.json`, `v53-bench.log`,
`oracle-v53-{small,large}/`, `pairs-v53-{small,large,tee}/`, `memory-v53/`,
`profile-small-v53/`, `local-alias-runtime-v53/`,
`parameter-alias-runtime-v53/` and `runtime-v53/`.

## September 30, 2026 balanced control storage

Balanced raw local cleanup previously rebuilt every nested Block, Loop,
TryTable and If and copied every body even when it made no edits. The trial
retains unchanged instruction/array storage, copies a parent before its first
changed child and builds only controls whose recursive rewrite count is
positive. The flat scan still runs; zero rewrites return the borrowed body
before copying its tail. Admission, traversal order and the four-round fixpoint
bound are unchanged.

This helper is private to its fixpoint and skipped-effectful-carrier cleanup.
That caller passes the result through pure, carrier and effectful cleanup;
those consumers read the borrowed input and construct their output. Tests run
that chain, check original encoded bytes and mutate newly owned changed paths
to prove that the original module is unaffected. Unchanged child storage is
shared read-only; this is not a general mutable-output ownership guarantee.

The focused tests compare exact instructions/counts against a frozen V51
recursive/flat implementation. They cover all four control forms, active and
blocked candidates, both changed if arms, mixed unchanged siblings, nested
calls/traps and i32/i64/externref values. The dispatcher checks observable call
order and input ownership. Native controls exercise 8/128 wide control trees
and depth-32 trees, each with no candidates, blocked candidates or active edits.
Setup, output validation and input-byte checks remain outside timed loops.

Before implementation, two storage/ownership regressions fail on V51 while
all active rewrite comparisons and the dispatcher guard pass. Afterward all
three focused tests pass, with `moon info`, `moon fmt`, **13,060** default tests,
the release native build and all **18** native controls. No public API changes
or new warning categories occur.

Native means (frozen V51 traversal → retained control storage):

| Tree / candidates | Before µs | After µs | Change |
| --- | ---: | ---: | ---: |
| tiny no candidate | 0.7654 | 0.2224 | -70.94% |
| tiny blocked | 2.5200 | 1.9000 | -24.60% |
| tiny active | 3.8100 | 3.4200 | -10.24% |
| wide no candidate | 11.7600 | 2.9300 | -75.09% |
| wide blocked | 38.8600 | 28.9400 | -25.53% |
| wide active | 59.5200 | 53.5400 | -10.05% |
| deep no candidate | 2.6300 | 0.8462 | -67.83% |
| deep blocked | 2.8600 | 1.0800 | -62.24% |
| deep active | 2.9900 | 2.2900 | -23.41% |

Frozen native V52 SHA-256: `85a68688f60413e34219af00000d6ee2ef66fd399793ea1a16c01ad88d39d98a`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.136 | 1.009 | 4.098× | -123 / -97 B |
| small / `dae2-optimizing` | 12.291 | 3.250 | 3.782× | -386 / -284 B |
| large / `dae2` | 3772.584 | 480.414 | 7.853× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 7716.738 | 1722.850 | 4.479× | +168,047 / +299,275 B |

Matched V51→V52 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V51 ms | V52 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.948 | 3.844 | -2.63% | 0.056 / 0.009 |
| small / `dae2-optimizing` | 11.007 | 10.464 | -4.93% | 0.472 / 0.057 |
| large / `dae2` | 3842.769 | 3893.695 | +1.33% | 70.387 / 47.239 |
| large / `dae2-optimizing` | 7379.898 | 7192.429 | -2.54% | 165.668 / 16.021 |
| tee / `dae2` | 2.950 | 3.005 | +1.86% | 0.008 / 0.021 |
| tee / `dae2-optimizing` | 110.367 | 107.500 | -2.60% | 0.962 / 0.812 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 244,724 [244,308–281,096] → after 280,812 [280,632–280,880].
- `dae2-optimizing`: before 290,280 [290,204–295,888] → after 290,064 [289,984–290,236].

The matched optimizing pipeline medians improve 4.93% small / 2.54% large
and 2.60% on active tee. The large before-MAD is 165.668 ms versus a
187.469 ms median difference; small before-MAD is 0.472 ms versus a 0.543 ms
difference. Retain this spread and avoid claiming those percentages as a
stable release gain. Active-tee's 2.867 ms difference exceeds both MADs.
Plain changes −2.63% small / +1.33% large / +1.86% active tee. The 50.926 ms
large plain difference is below its 70.387 / 47.239 ms MADs. Keep plain/control
costs open rather than using the independent oracle cohort as a causal gain.
Two reference-drift rounds are rejected (one small plain, one optimizing tee).

The small optimizing whole-command instruction comparison changes
155,529,391 → 154,949,402 (−0.37%), with exact profiled output bytes. This
includes startup, decoding, validation and encoding, not only pass work.
The storage change removes allocation/reconstruction, not the full balanced
traversal or typed suffix checks. Other recursive cleanup and single-leaf
suffix state setup remain separate active targets.

Initial plain peak-RSS medians are 244,724 → 280,812 KiB. The focused
repeat retains a higher candidate median (244,456 → 280,716 KiB), with both
sides spanning roughly 244,000–282,000 KiB. Identical-V51 calibration is
281,628 → 279,720 KiB with a low after sample. Thus the higher plain median
persists across the two candidate cohorts, while allocator/RSS bimodality
limits attribution. Keep it as an unresolved cost; do not claim a memory win
or assert that calibration disproves it. Optimizing RSS is close to flat
(290,280 → 290,064 KiB), with overlapping ranges.

All 469 bounded runtime modules / 2,891 observations agree with their originals,
including effects, traps and reference identity. Frozen V51/V52 raw and canonical
compiler artifact bytes are identical. The large optimizing gap remains
+168,047 raw / +299,275 canonical bytes; no output-shape family is closed here.

Sources: [`pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt),
[storage regressions](../../../../../src/passes/balanced_tree_wbtest.mbt),
[frozen traversal](../../../../../src/passes/balanced_tree_reference_wbtest.mbt),
[native controls](../../../../../src/passes/balanced_tree_perf_wbtest.mbt) and
[dispatcher guard](../../../../../src/cmd/balanced_tree_wbtest.mbt).
Local evidence under `.tmp/dae2-lean-20260929/`: `validation-v52.json`,
`candidate-v52.json`, `v52-baseline.json`, `v52-bench.log`,
`local-alias-runtime-v52/`, `parameter-alias-runtime-v52/`, `runtime-v52/`,
`oracle-v52-{small,large}/`, `pairs-v52-{small,large,tee}/`, `profile-small-v52/`,
`v52-plain-phase-comparison.json` and `memory-v52{,-plain-repeat,-plain-calibration}/`.
Long fuzz, shared-consumer and release signoff remain deferred.

## September 30, 2026 terminal cleanup ranges

The terminal-copy helper can only accept one final `local.get` of the target.
It now checks that shape before searching or copying anything, typechecks the
single instruction with the same prevalidated local environment, and retains
the structured-control, terminator, source-write and target-write barriers.
The terminal and next-if helpers also accept a start offset into the original
body; their callers no longer construct two complete remaining-tail arrays.
Consumed lengths stay relative to that start, while future-read checks use
absolute indices. No transform, traversal order or cleanup round is removed.

The two statement-split wrappers left without production callers by V50 now
live with the frozen test reference. The statement ownership regression calls
the production array-only helper and checks that editing the extracted array
does not edit its source. No public API changes are required.

Before implementation, three focused tests and the dispatcher guard pass on
V50; the native work budget fails with one full suffix-split site. The new
implementation removes that site. The focused cases cover i32/i64/externref,
prevalidated nonnullable locals, invalid local indices, side effects, control
and source/target-write barriers. A fourth test compares offset terminal and
next-if decisions against sliced reference inputs, including later reads and
intervening writes. The dispatcher checks the resulting function signature and
retained observable consumer call. An initial test incorrectly assumed suffix
checking starts with uninitialized locals; it was corrected to reflect the
prevalidated-prefix contract before the baseline was accepted.

The 24 native controls compare 8/512/4096 instruction tails with an accepted
final read, a final drop, an early conflicting source write and a wrong final
local. They compare the frozen V50 helper, validate results outside timed loops
and check that input arrays remain unchanged. The separate repeated-constant
producer controls measure the enclosing path that motivated this change.

The enclosing constant-copy repeat measures **8.48 µs** at width 8 and
**557.47 µs** at width 512, versus V50's previous 12.67 µs / 14.09 ms.
Those are separate native benchmark cohorts, not alternating binary pairs.
The approximately 25× wide-case difference is consistent with eliminating the
repeated full-tail search/copies; the separate compiler pairs below determine
the enclosing artifact effect. All producer output/ownership checks pass.

The candidate passes `moon info`, `moon fmt`, all **13,056** default tests,
the release native build and all **24** native controls. The two V50 unused
wrapper warnings are removed; no public API changes occur.

Native means (frozen V50 helper → terminal range helper):

| Tail / decision | Before µs | After µs | Change |
| --- | ---: | ---: | ---: |
| 8 accepted | 0.3025 | 0.2014 | -33.42% |
| 8 final drop | 0.1183 | 0.0103 | -91.26% |
| 8 early source write | 0.2321 | 0.1013 | -56.34% |
| 8 wrong final local | 0.1771 | 0.0111 | -93.75% |
| 512 accepted | 6.5800 | 4.9500 | -24.77% |
| 512 final drop | 3.9700 | 0.0106 | -99.73% |
| 512 early source write | 2.9800 | 0.1159 | -96.11% |
| 512 wrong final local | 2.2200 | 0.0122 | -99.45% |
| 4096 accepted | 53.3000 | 41.1000 | -22.89% |
| 4096 final drop | 31.7200 | 0.0098 | -99.97% |
| 4096 early source write | 24.8900 | 0.1025 | -99.59% |
| 4096 wrong final local | 13.2600 | 0.0104 | -99.92% |

Frozen native V51 SHA-256: `32f30c85a59b7c5283c6a27f73656924a87d70a5d8e1433516a5fb8d70814b3f`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.319 | 1.090 | 3.963× | -123 / -97 B |
| small / `dae2-optimizing` | 12.164 | 3.339 | 3.643× | -386 / -284 B |
| large / `dae2` | 3774.433 | 494.823 | 7.628× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 7326.431 | 1791.420 | 4.090× | +168,047 / +299,275 B |

Matched V50→V51 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V50 ms | V51 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.151 | 4.155 | +0.10% | 0.039 / 0.249 |
| small / `dae2-optimizing` | 10.630 | 10.541 | -0.84% | 0.081 / 0.005 |
| large / `dae2` | 3754.229 | 4089.598 | +8.93% | 62.721 / 138.292 |
| large / `dae2-optimizing` | 6727.240 | 6707.700 | -0.29% | 32.394 / 32.183 |
| tee / `dae2` | 3.304 | 2.961 | -10.38% | 0.091 / 0.001 |
| tee / `dae2-optimizing` | 108.105 | 108.977 | +0.81% | 0.499 / 0.612 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 245,280 [245,020–281,500] → after 281,092 [280,532–281,756].
- `dae2-optimizing`: before 290,152 [289,760–292,460] → after 290,156 [290,112–290,256].

The small optimizing whole-command Callgrind comparison changes
156,032,829 → 155,529,391 instructions (−0.32%), with byte identity against
unprofiled output. These include startup/decode/validation/encoding and do not
represent pass-only counts. Recursive balanced cleanup still accounts for
10.72% inclusive work, overlapping the skipped-carrier scope; this motivates
the next allocation trial rather than predicting its gain.

The matched optimizing medians change −0.84% small / −0.29% large and +0.81%
on active tee. Plain is +0.10% small, +8.93% large and −10.38% active tee.
The independent large-plain repeat is +1.76% (3770.027 → 3836.350 ms;
MAD 5.610 / 98.484). Identical-V50 calibration is −1.74%
(4008.439 → 3938.515 ms; MAD 20.004 / 7.572). Neither erases the original
plain cost, and the optimizing changes are small relative to spread. Keep
plain and active-tee costs open; this is a targeted scaling win.

Initial plain trace medians locate 88.884 ms in finalize, 36.534 ms in rewrite
and 28.785 ms in analysis within the 335.369 ms pipeline delta. Lift and
dependency construction are nested analysis scopes. Do not add overlapping
medians or identify a cause from this attribution alone.

Plain whole-command instructions are essentially flat: 73,070,097 →
73,077,211 (+0.010%), with exact profiler output bytes. This small-fixture
count does not explain or erase the large-fixture wall-time cost.

The initial plain peak-RSS median rises 245,280 → 281,092 KiB, but the focused
repeat is 280,692 → 280,464 KiB with both sides ranging near 244,000–282,000 KiB.
Identical-V50 calibration itself changes 268,272 → 244,656 KiB with broad
ranges. Preserve the initial cohort; the allocator/RSS bimodality does not
establish a stable candidate-specific memory increase or a memory saving.
Optimizing RSS is effectively flat (290,152 → 290,156 KiB).

All 469 bounded runtime modules / 2,891 observations agree with their originals,
including effects, traps and reference identity. Frozen V50/V51 raw and canonical
compiler artifact bytes are identical. The remaining large optimizing gap is
+168,047 raw / +299,275 canonical bytes; this change closes no output-shape family.

Sources: [`pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt),
[terminal regressions](../../../../../src/passes/terminal_ranges_wbtest.mbt),
[frozen helper](../../../../../src/passes/terminal_ranges_reference_wbtest.mbt),
[native controls](../../../../../src/passes/terminal_ranges_perf_wbtest.mbt) and
[dispatcher regression](../../../../../src/cmd/terminal_ranges_wbtest.mbt).
Local evidence under `.tmp/dae2-lean-20260929/`: `validation-v51.json`,
`candidate-v51.json`, `v51-baseline.json`, `terminal-copy-work-{v50,v51}.json`,
`v51-bench.log`, `v51-producer-{tiny,wide}.log`, `local-alias-runtime-v51/`,
`parameter-alias-runtime-v51/`, `runtime-v51/`, `oracle-v51-{small,large}/`,
`pairs-v51-{small,large,tee,plain-repeat,plain-calibration}/`,
`profile-small-v51{,-plain}/`, `v51-plain-phase-comparison.json` and
`memory-v51{,-plain-repeat,-plain-calibration}/`.
Long fuzz, shared-consumer and release signoff remain deferred.

## September 30, 2026 producer cleanup ranges

Pure- and effectful-suffix cleanup now pass an exclusive producer end to the
existing typed suffix scanner. They no longer copy the entire producer prefix
or construct the discarded head. Pure cleanup also obtains only the statement
it examines, instead of copying and splitting the remaining tail at three
sites. The escape fallback still runs only after ordinary statement admission
fails, with the same absolute boundary and rewrite order.

The small `sl_statement_at` helper shares statement extraction across those
sites and returns an owned array directly. It does not add a tuple for an
unused tail. Typechecking, local source/write barriers, producer duplication
rules, effects, traps and bounded cleanup rounds are unchanged. This removes
additional quadratic materialization; it does not make all raw cleanup linear.
The two terminal/condition helper callers still copy tails, and terminal
admission still searches suffixes before rejecting an impossible final opcode.

Before implementation, a native V48 work budget failed with six discarded
split call sites: two value-suffix splits, three ordinary statement-prefix
splits and one escape-prefix fallback. A new bounded regression covers 24
pure/effectful i32/i64/externref cases against frozen previous functions, with
input ownership and output validation checks. The active dispatcher regression
preserves the producer/tick/consumer call order in SimplifyLocals and DAE2-O.

The native controls compare 8/512 repeated constant copies, pure expressions,
active effects and blocked effects, plus independent no-candidate controls for
both producer scans. Setup, validation and ownership checks are outside the
timed loops. Existing range-boundary and suffix/prefix typing tests remain in
the validation set. Old statement-split wrappers currently have only test
consumers; relocating these references out of production code is follow-up
cleanup, not a public API change.

The candidate passes `moon info`, `moon fmt`, all **13,051** default tests,
the native release build and all **24** native benchmark cases. No public API
changes occur. `moon info` reports two additional unused-function warnings for
the now test-only split wrappers described above.

Native means, frozen pre-change functions → range-based functions:

| Control | Before | After |
| --- | ---: | ---: |
| 8 constant copies | 22.92 µs | 12.67 µs |
| 8 pure expressions | 4.38 µs | 1.74 µs |
| 8 active effects | 4.06 µs | 2.23 µs |
| 8 blocked effects | 3.69 µs | 1.88 µs |
| 512 constant copies | 41.86 ms | 14.09 ms |
| 512 pure expressions | 8.21 ms | 107.32 µs |
| 512 active effects | 6.27 ms | 144.49 µs |
| 512 blocked effects | 5.90 ms | 130.36 µs |

The 512 constant-copy control still costs 14.09 ms: its remaining terminal
helper performs repeated suffix searches and copies. This is a concrete next
bottleneck, not a claim that range extraction makes the entire path linear.

The initial effectful no-candidate control costs 7.94% at width 8 and 25.45%
at width 512; the wide after-run has substantial dispersion (8.43 ± 1.25 µs).
A focused repeat on the unchanged executable measures 155.36 → 157.13 ns
(+1.14%) and 6.61 → 6.66 µs (+0.76%). Keep both cohorts: the initial percentage
is not stable. Pure no-candidate repeats improve 167.39 → 158.90 ns and
8.33 → 6.93 µs. All eight repeated cases pass their behavior/ownership checks.
These are helper measurements; enclosing gains require the separate paired
compiler and active-tee comparisons below.

A separate small-fixture Callgrind comparison uses the same frozen binaries
and verifies byte identity against the unprofiled outputs. Whole-command
native instructions change 73,073,790 → 73,070,097 for plain DAE2 (essentially
flat), and 157,117,354 → 156,032,829 for DAE2-O (−0.69%). These include command
startup, decoding, validation and encoding; they are not pass-only counts.

The updated optimizing profile still locates 31.65% of inclusive instructions
under raw SimplifyLocals, 12.11% under skipped-effectful-carrier cleanup and
10.69% under recursive balanced cleanup. These scopes overlap and must not be
added. The self profile attributes 16.02% to object destruction, 7.17% to free
and 4.35% to reference-array copying. This motivates a separate investigation
of unchanged control/array reconstruction and repeated cleanup traversals;
it does not prove that eliminating any one helper saves those percentages.

Frozen native V50 SHA-256: `940f179b84128ef253a0a7cafd9a048f2a0f094ecee24e7b530c9e33d3bb2f3a`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.134 | 1.051 | 3.935× | -123 / -97 B |
| small / `dae2-optimizing` | 13.029 | 3.241 | 4.020× | -386 / -284 B |
| large / `dae2` | 4188.636 | 467.031 | 8.969× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 7880.098 | 1920.370 | 4.103× | +168,047 / +299,275 B |

Matched V48→V50 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V48 ms | V50 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.904 | 3.969 | +1.66% | 0.041 / 0.012 |
| small / `dae2-optimizing` | 10.871 | 10.867 | -0.04% | 0.257 / 0.065 |
| large / `dae2` | 3879.328 | 3989.225 | +2.83% | 3.665 / 16.129 |
| large / `dae2-optimizing` | 6694.417 | 6712.530 | +0.27% | 17.477 / 38.737 |
| tee / `dae2` | 2.969 | 2.907 | -2.09% | 0.088 / 0.024 |
| tee / `dae2-optimizing` | 106.282 | 106.866 | +0.55% | 0.245 / 0.458 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 244,124 [244,060–281,596] → after 244,984 [244,060–281,660].
- `dae2-optimizing`: before 290,360 [290,184–292,156] → after 290,212 [290,100–292,544].

Peak RSS ranges overlap in both passes; the small median differences do not
establish a memory improvement.

All 469 bounded runtime modules / 2,891 observations agree with their originals,
including effects, traps and reference identity. V48/V50 raw fixture bytes are
identical; both compiler artifacts also retain exact raw and canonical bytes.
The remaining large optimizing gap is +168,047 raw / +299,275 canonical bytes.
No output-quality family is closed by this change.

The matched compiler optimizing runs are effectively flat (small −0.04%, large
+0.27%); active-tee optimizing costs 0.55%. Plain costs 1.66% small and 2.83%
large in the initial cohort. A separate large-plain repeat is +1.59%
(3734.210 → 3793.709 ms; MAD 15.721 / 64.289). An identical-V48 calibration is
+0.29% (3717.366 → 3728.029 ms; MAD 7.752 / 5.467). The repeat's spread exceeds
its median difference, but neither it nor the calibration erases the initial
cost. Three initial small reference-drift rounds were rejected; repeat and
calibration had none. Retain the unresolved plain and control costs.

Initial trace medians attribute 79.560 ms of the 109.897 ms plain pipeline
difference to analysis, including 39.825 ms in lift and 33.404 ms in dependency
construction. These nested scopes cannot be added to the enclosing total and
precede the changed cleanup. They locate the difference, not its cause. The
independent oracle cohort cannot be subtracted from historical runs to claim
a causal speedup. This is a scaling/work-reduction checkpoint, not a general
compiler-pipeline speed win.

Sources: [`pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt),
[`statement_prefix_reuse.mbt`](../../../../../src/passes/statement_prefix_reuse.mbt),
[producer regressions](../../../../../src/passes/producer_ranges_wbtest.mbt),
[native controls](../../../../../src/passes/producer_ranges_perf_wbtest.mbt) and
[dispatcher regression](../../../../../src/cmd/producer_ranges_wbtest.mbt).
Local evidence under `.tmp/dae2-lean-20260929/`: `validation-v50.json`,
`candidate-v50.json`, `v50-baseline.json`, `producer-ranges-work-{v48,v50}.json`,
`v50-bench.log`, `v50-repeat-{tiny,wide}.log`, `profile-small-v50/`,
`local-alias-runtime-v50/`, `parameter-alias-runtime-v50/`, `runtime-v50/`,
`oracle-v50-{small,large}/`, `pairs-v50-{small,large,tee,plain-repeat,plain-calibration}/`,
`v50-plain-phase-comparison.json` and `memory-v50/`.
Long fuzz and final shared-consumer/release signoff remain deferred.

## September 30, 2026 bounded raw cleanup ranges

Balanced-statement local cleanup previously copied every candidate's entire
producer prefix, then split it and discarded the head. It also copied the
remaining tail for each intervening statement, split that copy and discarded
the next tail. Repeated candidates therefore materialized quadratic amounts
of irrelevant instruction storage even when a local could not be forwarded.

`sl_value_suffix_at` now finds and copies only the accepted suffix within an
exclusive end of the original instruction array. The statement-prefix scanner
accepts a start offset and returns an absolute end. The balanced scan copies
only that statement. Typed admission, the unknown-opcode fallback, read/write
barriers, rewrite order and the bounded fixpoint remain unchanged. Existing
split callers keep their original owned head/suffix interface and copy behavior.
The helper returns its suffix array directly; the start follows from its length.
This avoids adding an allocated tuple to every existing suffix-wrapper call.

This removes quadratic *materialization*, not every repeated scan in raw
cleanup. Pure/effectful producer-prefix copies and other pure-statement tail
copies remain follow-up work. Repeated future-read checks may also still be
superlinear.

TDD uses the frozen native V47 implementation: its balanced scan has two
unused-region split call sites, failing a zero-site work budget. Bounded
behavior guards pass on that baseline. An initial tuple-return prototype
failed a separate generated-native-code budget with three tuple-allocation
return sites (one per executed return, not three allocations per invocation).
The array-return refinement removes those sites. An early command fixture
incorrectly expected standalone SimplifyLocals to compact declarations; its
expectation was corrected before the implementation. That fixture mistake is
not counted as the performance red.

Three pass regressions cover 21 i32/i64/externref capture cases plus exclusive
suffix ends, absolute statement starts, escape handling and deliberately
invalid/incomplete prefixes. Frozen reference functions retain prior behavior.
The dispatcher regression preserves producer/tick/consumer order in both
SimplifyLocals and DAE2-O. Native controls compare tiny/wide repeated captures,
intervening statements, blocked reads and no-candidate bodies; shared suffix
wrapper controls cover present/absent values at widths 0, 8 and 512. Output
validation and input ownership checks run outside timed loops.

The final array-return candidate passes `moon info`, `moon fmt`, all **13,049**
default tests, the focused native regression, native release build and all
28 native benchmark cases. Native means (frozen reference → ranged helper):

| Control | Before | After |
| --- | ---: | ---: |
| 8 repeated captures | 6.23 µs | 2.81 µs |
| 8 intervening statements | 1.83 µs | 1.06 µs |
| 8 blocked reads | 7.73 µs | 2.87 µs |
| 512 repeated captures | 11.91 ms | 181.20 µs |
| 512 intervening statements | 1.05 ms | 50.88 µs |
| 512 blocked reads | 15.71 ms | 186.26 µs |
| 512 no-candidate body | 7.39 µs | 7.41 µs |
| shared suffix, 0-prefix present | 139.22 ns | 140.11 ns |
| shared suffix, 0-prefix absent | 31.96 ns | 32.36 ns |
| shared suffix, 8-prefix present | 163.95 ns | 170.75 ns |
| shared suffix, 8-prefix absent | 93.70 ns | 97.09 ns |
| shared suffix, 512-prefix present | 1.76 µs | 1.78 µs |
| shared suffix, 512-prefix absent | 3.43 µs | 3.54 µs |

The wide active/blocked cases improve 95.2–98.8%; no-candidate timing is flat.
The shared wrapper is slightly slower: 4.15% on the 8-prefix present case and
3.21% on the 512-prefix absent case. Their small absolute costs remain part of
the adoption decision; the wide helper gain is not a whole-pass speedup claim.
The earlier tuple-return trial remains local evidence only and is superseded
by the final array-return measurements above.

Frozen native V48 SHA-256: `06466c3121961400d431b10eb1cc8ac893f0e144eb90b3462536466032d653ae`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.471 | 1.128 | 3.965× | -123 / -97 B |
| small / `dae2-optimizing` | 12.682 | 3.323 | 3.817× | -386 / -284 B |
| large / `dae2` | 4398.904 | 604.036 | 7.283× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 8372.674 | 1887.200 | 4.437× | +168,047 / +299,275 B |

Matched V47→V48 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V47 ms | V48 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.797 | 3.875 | +2.05% | 0.013 / 0.003 |
| small / `dae2-optimizing` | 11.075 | 10.891 | -1.66% | 0.143 / 0.054 |
| large / `dae2` | 4473.855 | 4581.916 | +2.42% | 112.916 / 30.598 |
| large / `dae2-optimizing` | 8226.962 | 8108.390 | -1.44% | 56.304 / 161.019 |
| tee / `dae2` | 2.858 | 3.043 | +6.47% | 0.016 / 0.166 |
| tee / `dae2-optimizing` | 103.930 | 103.810 | -0.12% | 0.328 / 0.415 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 280,864 [280,488–281,184] → after 280,808 [244,588–281,396].
- `dae2-optimizing`: before 290,216 [289,988–312,552] → after 290,016 [289,908–290,320].

The RSS ranges overlap; these samples do not establish a robust memory win.

Original/V47/V48/v133 bounded replay passes **469 modules / 2,891 observations**,
including values, side effects, traps and reference identity. All before/after
fixture bytes match. Both small and large compiler artifacts retain exact raw
and canonical bytes; the optimizing size gap remains +299,275 canonical bytes.
This performance change does not close an output-quality family.

The matched large optimizing reduction is 1.44%, smaller than the after-run
MAD; active-tee optimizing is flat (−0.12%). Plain medians cost 2.05% small,
2.42% large and 6.47% tee, with substantial tee and large-baseline variability.
Two small-optimizing rounds and one tee-optimizing round were rejected by the
reference-drift gate. These results establish the wide-case scaling improvement,
not a robust general pipeline win. Retain the wrapper/control costs as active
work. The independently timed oracle cohort must not be subtracted from earlier
cohorts to claim a causal gain.

The next producer cleanup experiment targets remaining prefix/head and
statement-tail copies. A control-shape census also identifies at most 2,774
conditional functions (195,613 of 2,807,768 WAT instruction/control lines) for a
raw fallthrough-conditional analysis trial. This is an upper bound only:
opcode/signature/stack/intrinsic admission and actual timing remain unmeasured.

Sources: [`pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt),
[`statement_prefix_reuse.mbt`](../../../../../src/passes/statement_prefix_reuse.mbt),
[range regressions](../../../../../src/passes/balanced_ranges_wbtest.mbt),
[boundary regressions](../../../../../src/passes/balanced_ranges_bounds_wbtest.mbt),
[native controls](../../../../../src/passes/balanced_ranges_perf_wbtest.mbt) and
[dispatcher regression](../../../../../src/cmd/balanced_ranges_wbtest.mbt).
Local evidence under `.tmp/dae2-lean-20260929/`: `validation-v48.json`,
`candidate-v48.json`, `v48-bench.log`, `balanced-ranges-{red-v47.log,work-v48.json}`,
`suffix-range-return-{red.log,v48.json}`, `local-alias-runtime-v48/`,
`parameter-alias-runtime-v48/`, `runtime-v48/`, `oracle-v48-{small,large}/`,
`pairs-v48-{small,large,tee}/`, `memory-v48/` and `control-census.json`.
Long fuzz and final shared-consumer/release signoff remain deferred.

## September 30, 2026 dominated local aliases

The optimizing capture cleanup now forwards a body-local copy when its source
is unwritten or has one dominating static writer. Lexical children inherit
facts and undo only their own definitions on exit. This proves the source has
the same value in the active loop iteration; it does not infer that a static
single writer executes only once. Earlier/default reads and sibling/handler
reads keep their original target. A multiply-written or later-written source
cannot supply a forwarded snapshot.

The existing packed alias row and undo stack are reused. An established-writer
bitmap is allocated lazily, only when ordinary single-writer definitions need
tracking. Reads through active aliases are already resolved to the final source.
The source index must be lower than the target, so partial forwarding cannot
widen local-index encodings. Dead alias writers are retired in descending index
order, then removed during the existing local remap. A removed `local.set`
also removes only its adjacent `local.get`; a removed `local.tee` retains its
value. Effectful producers are never moved or duplicated. The pre-existing
balanced stack-capture plan runs before this alias rewrite.

The counter-based no-work shortcut from V46 is retained only for optimizing
cleanup; plain lowering keeps its previous balanced-scan path. The combined
change is compared against accepted V45, not against the rejected V46
compaction-only trial. Native references freeze both the V45 compactor and its
old parameter-only alias helper.

TDD began with four failing positive tests (two locals rather than one, and
three retained target reads rather than one) plus a passing future-write guard.
Ten focused regressions cover i32, i64, externref and GC structure identities;
flat/nested/loop copies; pre-assignment defaults; later/multiple source writes;
sibling and branch boundaries; parameter writes; and tee chains. The active
CLI dispatcher has a separate i64 regression. All eleven original parameter
alias tests remain in the validation set. Performance fixtures validate outputs
and ownership outside their timed loop, including inactive and parameter-only
controls. Long fuzz remains deferred by user instruction.

The frozen V47 source passes `moon info`, `moon fmt`, all **13,045** default
tests, ten native alias tests, the dispatcher regression, a release build and
32 native benchmarks. The native no-work probe now records zero balanced-scan
and remap calls. Original/V45/V47/v133 replay covers 245 local-alias modules /
1,470 observations and 98 parameter-alias modules / 392 observations, including
reference identity, changing per-iteration values, producer/consumer exceptions
and traps. All observations match; no tested output grows and plain bytes stay
identical. These are bounded controls, not aggregate fuzz signoff.

The complete artifact audit verifies identical non-code semantic sections and
nonlocal opcode/immediate streams, with no raw function-size regression. Small
optimizing output removes four set/get pairs and five tee writes, saving 26 raw
and canonical bytes. Large optimizing removes **2,293 set/get pairs and 16,634
tee writes**, saving **54,687 raw / 56,875 canonical bytes**. The `changedFunctions`
field counts only functions losing set/get pairs (984), not every tee-only or
index-compaction change. The remaining large gap is **168,047 raw / 299,275
canonical bytes** against release v133. Of 12,904 canonical functions, 8,282
remain larger and 2,183 smaller; body payload accounts for +299,115 bytes.

Reduced flat i32/i64/f64/externref/GC and loop examples now match v133's byte
size. Exact bytes differ because v133 retains an extra unused local in the same
declaration group; the instruction bytes match. Fewer declarations alone do not
prove a Starshine performance win, so this distinction is not counted as closed
output-shape parity. Original-primary replay establishes the tested behavior.

Native full-compaction means, V45 reference → V47:

| Control | Before | After |
| --- | ---: | ---: |
| 8 flat local aliases | 2.06 µs | 1.65 µs |
| 128 flat local aliases | 31.71 µs | 22.06 µs |
| 128 nested local aliases | 43.20 µs | 32.57 µs |
| 128 no-alias groups | 31.44 µs | 4.56 µs |
| 128 parameter-alias groups | 15.30 µs | 10.30 µs |
| 512 active balanced captures | 18.93 µs | 18.87 µs |
| 512 active parameter aliases | 59.04 µs | 38.70 µs |
| 512 idle optimizing locals | 64.80 µs | 9.91 µs |
| 8 idle plain locals | 1.16 µs | 1.19 µs |
| 512 idle plain locals | 60.65 µs | 60.26 µs |

The flat 128-group run has noticeable dispersion (σ .799 / .846 µs); the
quieter precheck is 28.89 → 21.41 µs. Its nested control is 43.79 → 32.06 µs.
Tiny plain costs 2.59% in the final run; the earlier precheck is 1.14 → 1.14 µs.
These measure the combined alias and admission change, not the alias helper
alone. Strong microbenchmark gains do not establish a full-pipeline speedup.

Frozen native V47 SHA-256: `bd6e5bfdffaa2788504d6616216d55973800715d3ff53c32aac882be33cc91cd`.

Fresh verified release-v133 comparison (CPU 6, one warmup, three samples; pass-local medians):

| Input / pass | Starshine ms | v133 ms | Ratio | Raw / canonical size gap |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 3.985 | 1.019 | 3.913× | -123 / -97 B |
| small / `dae2-optimizing` | 13.592 | 3.584 | 3.792× | -386 / -284 B |
| large / `dae2` | 3995.880 | 479.646 | 8.331× | -117,365 / -100,237 B |
| large / `dae2-optimizing` | 7380.880 | 1730.980 | 4.264× | +168,047 / +299,275 B |

Matched V45→V47 pipeline medians (same CPU/warmup, three accepted alternating pairs, independent reference bracket ≤1.15):

| Input / pass | V45 ms | V47 ms | Change | MAD before / after ms |
| --- | ---: | ---: | ---: | ---: |
| small / `dae2` | 4.111 | 4.155 | +1.07% | 0.009 / 0.037 |
| small / `dae2-optimizing` | 10.783 | 10.791 | +0.07% | 0.073 / 0.071 |
| large / `dae2` | 3706.226 | 3919.365 | +5.75% | 45.896 / 12.442 |
| large / `dae2-optimizing` | 6864.440 | 6836.408 | -0.41% | 74.271 / 3.707 |
| tee / `dae2` | 2.885 | 2.929 | +1.53% | 0.024 / 0.031 |
| tee / `dae2-optimizing` | 106.887 | 105.963 | -0.86% | 0.709 / 0.540 |

Three alternating peak-RSS pairs, KiB (median [range]):

- `dae2`: before 273,492 [239,740–280,356] → after 241,228 [240,844–279,244].
- `dae2-optimizing`: before 288,432 [288,352–300,860] → after 287,712 [287,108–289,700].

The RSS ranges overlap; these runs do not establish a robust memory reduction.
The oracle cohort is independent of the matched before/after cohort; do not
subtract their times or treat the ratios as causal speedups.

The unchanged fixed runtime lane also passes 126 modules / 1,029 observations,
for 2,891 bounded observations across the three lanes. None of those fixed
fixtures changes bytes. The two alias-specific lanes cover the new behavior.

The initial matched large-plain run costs **5.75%** (3706.226 → 3919.365 ms;
MAD 45.896 / 12.442). A separate three-pair repeat is **+1.11%** (4114.923 →
4160.604 ms; MAD 109.272 / 11.568), with one rejected reference-drift round.
Retain both cohorts: the repeat does not erase the first cost, and the first
percentage is not stable across the two cohorts. Initial trace medians locate
189.623 ms of the 213.139 ms enclosing difference in analysis, including
99.315 ms in dependencies and 84.958 ms in analysis lift. These nested scopes
must not be added again, and they do not establish why code outside the changed
cleanup differs. Optimizing is essentially flat in the matched large run.
The quality improvement is retained with this unresolved timing cost; it is not
a general full-pipeline performance win or release signoff.

Local evidence is retained under `.tmp/dae2-lean-20260929/`: `local-alias-before.log`,
`validation-v47.json`, `candidate-v47.json`, both `v47-bench*.log` files,
`compaction-admission-work-v47.json`, `local-alias-runtime-v47/result.json`,
`parameter-alias-runtime-v47/result.json`, `alias-shape-v47.json`,
`remaining-size-v47.json`, `v47-plain-phase-comparison.json`, the independent
`pairs-v47-large-plain-repeat/` cohort, and the frozen oracle/pair/RSS reports.

## September 30, 2026 capture-compaction admission trial

**V46 is not accepted as a standalone change.** Its native controls improve,
but the matched large plain compiler regresses 3.84% and optimizing is flat.
V47 restricts this admission work to optimizing cleanup and compares the
combined result against V45; its quality gain and remaining timing cost are
recorded above.

The V46 trial reuses its initial read/write counts to avoid balanced-pair
scanning and body remapping when there is no eligible single-read/single-write
capture, no unused declaration and no immutable parameter alias. It returns the
identity local map and retains existing local-group normalization, including
zero-sized groups. Functions with active aliases still run alias cleanup;
functions with capture pairs preserve the original leaf-first, effect-spanning
order. No producer or effect is reordered, and the input remains read-only.

The pre-change V45 native work probe fails with two balanced-scan function
entries (wrapper plus inner, not two independent scans) and one remap call in
final capture cleanup. Its required counts are zero. Four bounded behavior
cases cover multiply-read and multiply-written locals, loops, dead declarations,
active set/tee/unread aliases, identity maps and redundant declaration groups.
They are behavior guards, not claimed pre-change transform failures.

Sixteen native controls compare the frozen pre-admission compactor using the
same current counter and cleanup helpers. Setup, parsing, validation and output
comparison are outside timing. A repeat was necessary because the first run's
active-capture samples had high dispersion; retain both runs. The quieter
repeat records:

| Groups / workload | Original | Admission | Change |
| --- | ---: | ---: | ---: |
| 8 / no eligible capture | 1.14 µs | 159.23 ns | −86.0% |
| 512 / no eligible capture | 57.98 µs | 5.64 µs | −90.3% |
| 8 / unused-parameter alias guard | 1.24 µs | 159.02 ns | −87.2% |
| 512 / unused-parameter alias guard | 63.42 µs | 5.58 µs | −91.2% |
| 8 / active captures | 490.87 ns | 498.31 ns | +1.52% |
| 512 / active captures | 19.84 µs | 20.13 µs | +1.46% |
| 8 / active aliases | 1.25 µs | 864.78 ns | −30.8% |
| 512 / active aliases | 59.87 µs | 39.37 µs | −34.2% |

The active-capture cost remains an explicit tradeoff; it cannot be inferred away
from the much larger idle/alias microbenchmark gains. V47 above extends the
parameter-only admission proof to body locals, so the fast path does not
conceal the new transform candidates.

The V46 candidate passes all 13,034 default tests, four native cases, the
command and admission fixtures, info/fmt, release build and 16 benchmarks.
Its native work probe reaches zero balanced-scan entries and zero remaps with
the same output hash. The final benchmark rerun retains the wide idle and
alias improvements (58.35→5.64 µs / 62.96→39.27 µs) and the smaller active
capture cost (19.70→19.89 µs). No public interface changes were required.
Frozen native V46 SHA-256:
`88af0bbcce56ee1fd82bd436170cffecaa45d78918cfc099aa61db1b91c0e39f`.

V46's matched V45→V46 medians (CPU 6, one warmup, three accepted pairs)
are small plain 3.869→3.886 ms (MAD .007/.053), small optimizing
10.703→10.949 (.068/.107), large plain 3711.954→3854.337 (10.907/68.360),
large optimizing 7013.212→7032.712 (47.773/33.876), tee plain 2.975→2.775
(.031/.006) and tee optimizing 111.379→113.103 (4.476/1.360).
The tee plain gain is 6.72%; the compiler and optimizing costs remain open.
All measured before/after bytes match, and 126 modules / 1,029 original-primary
runtime observations pass. Three RSS pairs give plain 281,408→245,436 KiB
(ranges 280,100–281,476 / 243,612–282,308) and optimizing 290,124→290,304 KiB
(289,840–290,384 / 290,120–308,048). These ranges do not establish a memory win.

The separate fresh v133 cohort records small plain 4.198/1.04849 ms (4.004×),
small optimizing 13.079/3.27961 (3.988×), large plain 3776.841/455.847 (8.285×)
and large optimizing 7281.865/1793.410 (4.060×). Output sizes remain V45's;
the 356,150 canonical / 222,734 raw optimizing gap is unchanged. These are
historical V46 observations, not a replacement accepted baseline.

Local-only evidence is under `.tmp/dae2-lean-20260929`: `validation-v46.json`,
`v46-precheck-bench.log`, `v46-recheck-bench.log`, `v46-bench.log`,
`compaction-admission-work-v{45,46}.json`, `candidate-v46.json`,
`oracle-v46-{small,large}/result.json`, `pairs-v46-{small,large,tee}/result.json`,
`runtime-v46/result.json` and `memory-v46/result.json`.

## September 30, 2026 read-only local counting

`pass_lower_count_locals` now descends directly through block, loop, if,
try-table and legacy catch bodies. The previous generic child mapper rebuilt
control and catch wrappers that the counter immediately discarded, and allocated
a recursive visitor for each region. The direct walk preserves source traversal
order, seeded count accumulation, and input ownership.

Before implementation, the native V43 work budget fails with one body-mapper
call site and one recursive-visitor allocation site; the required count is zero
for each. These are generated-code sites, not dynamic allocations or heap bytes.
Two behavior guards pass on both implementations, checking exact read/write
counts and source bytes across nested control, tagged catches, try-table and
empty siblings. The benchmark compares the unchanged historical counter against
the new one for 8/512 flat and structured groups; parsing and setup are outside
timing, and both reuse and reset the same count buffers.

`moon info`, `moon fmt`, two native cases, the command fixture and all **13,030**
default tests pass. There are no public interface changes. Enclosing comparisons
require byte-identical before/after output, not merely validation or size parity.

The first direct-walk trial V44 passes the native zero-site budget, but is not
accepted: 8 flat groups improve 68.99 to 55.42 ns and structured 8/512 groups
improve 465.64 to 120.11 ns / 28.55 to 6.92 us, while 512 flat groups regress
2.69 to 8.93 us. Generated benchmark C grows the counter from a three-case
local-access switch to a combined local/control switch, and the native loop
uses an indirect jump table. That is a source-backed hypothesis for the flat
regression, not established causality. The next trial separates recursive child
handling from the hot local-access loop while retaining zero reconstruction and
visitor-allocation sites. V44 samples and its native hash remain separate.

V44's complete matched CPU-6 cohort (V43 baseline, one warmup, three valid
samples) records small plain 3.749 to 3.725 ms (MAD .010/.093), small optimizing
10.514 to 10.777 ms (MAD .101/.020; +2.50%), large plain 3692.442 to 3707.172 ms
(MAD 27.334/14.479; +.40%), large optimizing 7040.839 to 6771.924 ms (MAD
91.679/99.163; -3.82%), and tee plain 2.889 to 2.885 / optimizing 105.105 to
104.410 ms. This shows a useful enclosing optimizing improvement but leaves the
flat microbenchmark and small optimizing costs unresolved. All fixed 126
modules / 1029 runtime observations match, and every before/after output is
byte-identical. Frozen native V44 SHA-256:
3475039477103f6bef32be57605c9cfcedce8f3380a22fb0db57c27d304675a9.

V45 separates child-region recursion from the three-case local-access loop.
Both functions have zero reconstruction/visitor-allocation sites. Generated
native CLI code has one indirect hot-loop jump in V44 and none in V45; the
revised loop calls the separate child helper for other instructions. Native
benchmarks retain the nested win while resolving the flat regression:

| Groups | Shape | Original | V45 |
| --- | --- | ---: | ---: |
| 8 | Flat | 73.93 ± 4.14 ns | 59.76 ± 2.05 ns |
| 512 | Flat | 2.72 ± .064 µs | 2.69 ± .075 µs |
| 8 | Structured | 486.22 ± 9.77 ns | 138.42 ± 4.34 ns |
| 512 | Structured | 29.19 ± .115 µs | 8.18 ± .065 µs |

The wide flat result is within dispersion; the wide structured case improves
72.0%. All 13,030 default tests, the focused native and command cases, info/fmt,
native build and eight benchmarks pass. Frozen V45 native SHA-256:
`b6ba6b15aa44d6fe34c779cfdb668a48fb21b50cec524e26f932c290e777ba99`.

V45's fresh release-v133 cohort uses CPU 6, one warmup and three samples.
These are independent pass-local observations, not paired causal improvements:

| Pass | Small Starshine / v133 ms | Ratio | Large Starshine / v133 ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| `dae2` | 3.902 / 1.009 | 3.87× | 3,642.904 / 457.079 | 7.97× |
| `dae2-optimizing` | 12.369 / 3.216 | 3.85× | 7,010.621 / 1,714.600 | 4.09× |

Small raw/canonical sizes remain 192,271/192,297 for plain and
191,546/191,648 for optimizing. Large sizes remain 6,115,221/6,132,349
and 5,796,184/5,929,600 respectively. The optimizing output still exceeds
v133 by 222,734 raw / 356,150 canonical bytes. The fixed original/V43/V45/v133
comparison passes all 126 modules / 1,029 runtime observations with no output
byte differences between V43 and V45.

The complete V43→V45 matched cohort records the following pipeline medians
in milliseconds (one warmup, three accepted alternating CPU-6 pairs):

| Input / pass | V43 | V45 | Change | MAD before / after |
| --- | ---: | ---: | ---: | ---: |
| Small plain | 3.985 | 3.921 | −1.61% | .029 / .077 |
| Small optimizing | 11.287 | 11.469 | +1.61% | .164 / .246 |
| Large plain | 3,947.059 | 3,764.711 | −4.62% | 283.460 / 77.596 |
| Large optimizing | 6,696.781 | 6,686.157 | −.16% | 12.126 / 16.593 |
| Tee plain | 2.934 | 2.940 | +.20% | .030 / .026 |
| Tee optimizing | 114.332 | 115.729 | +1.22% | 1.031 / .979 |

All measured outputs are byte-identical, including traced versus untraced runs.
The reference bracket rejects two noisy large-plain pairs and retains them in
the raw record. Large plain still has substantial dispersion; large optimizing
is essentially flat. The local structured-counting gain does not establish a
large whole-pass gain. Small/tee optimizing costs remain visible for cumulative
review. No long fuzz campaign was run, as requested.

Three matched RSS pairs record plain 280,988 KiB [280,876–281,376] →
244,408 KiB [243,996–244,864] and optimizing 291,340 KiB
[290,232–291,552] → 290,008 KiB [289,940–291,868]. Plain RSS falls in
this cohort; optimizing ranges overlap. Earlier cohorts varied between lower
and higher plain RSS plateaus, so these three samples do not establish a
universal memory reduction. Every RSS output matches its frozen oracle artifact.

Reproduction artifacts are local-only under `.tmp/dae2-lean-20260929`:
`validation-v45.json`, `v45-bench.log`, `counting-work-v43.json`,
`counting-work-v45.json`, `counting-dispatch-v45.json`, `candidate-v45.json`,
`oracle-v45-{small,large}/result.json`, `pairs-v45-{small,large,tee}/result.json`,
`runtime-v45/result.json` and `memory-v45/result.json`. The source controls
listed above and explicit hashes preserve the contract when these local
artifacts are absent.

## September 30, 2026 structured call-suffix replay

The new private raw path removes an adjacent pure argument suffix in structured
bodies after the complete module-wide DAE2 fixed point. The existing flat demand
projection runs first. Control headers, branch depths, retained producers and
observable operations keep their order. Removed result tuples require exact
following drops or writes to unread body locals; their callee keeps HOT result
rewriting. Unknown/interleaved producers, trapping discarded arguments, indexed
control signatures, indirect calls, own removed results, returns and repaired
catch-payload provenance keep the general HOT path. There is no retained HOT
expression graph between functions.

Source-order original write IDs from the checked unmodified lift are retained
until solve. Qualification uses their actual demand to reject overwritten stores
that a global read mask alone cannot distinguish. Synthetic captures have no raw
entries. The cursor checks every original writer in lexical child order and
rejects missing/polymorphic provenance. Raw liveness excludes discarded argument
reads, removes unread tees while preserving their stack values, and drops unused
stored results without removing their producer effects. General pure-expression
deletion stays HOT. Monotonic suffix-call lookahead avoids quadratic rescanning
or an instruction-sized marker array.

TDD first fails two lift budgets (one versus zero). Later reduced regressions
fail an unread-tee count, a tuple-store lift budget, encoded equality for a dead
overwritten store and a return after `br`. Scalar-result/void return guards keep
HOT control normalization. The full suite exposes a stale source map after catch
payload localization; repaired lifts now retain HOT replay and that intake
regression passes. Other exact opcode/type/local/ownership and trapping fallback
fixtures are behavior guards rather than claimed red-first gaps.

V39 is rejected despite an 84.4% wide synthetic improvement and a 5.7% matched
large plain improvement: large raw output grows 15,338 plain / 12,038 optimizing
bytes, with 663/519 larger functions. Missing unread tee/store cleanup explains
the main family. V40 narrows this to four plain / three optimizing regressions:
two unused result-if headers with trailing returns, one unreachable return and
one overwritten initialization. Optimizing raw output still grows six bytes;
its 3.0% matched optimizing improvement is rejected rather than accepted as
representation drift. Both failed checkpoints and their complete samples stay
under their original frozen hashes. Catch provenance invalidation also rejects
the first V41 validation attempt (13,026 passing / one failing); the corrected
checkpoint is separate evidence.

V41 repairs all four byte regressions: three large plain functions save 42 raw
bytes, optimizing bytes are unchanged, and no function grows. All 13,027 default
tests, 11 native core cases, the command case and four native benchmarks pass.
Runtime replay matches original/v133 in 133 modules / 532 observations plus the
fixed 126 / 1,029 cohort. Wide synthetic replay improves 18.87 to 3.14 ms (83.4%).
However matched V38-to-V41 optimizing grows 7,191.769 to 7,396.666 ms (2.85%), and
tee optimizing grows 105.396 to 108.439 ms (2.89%). Plain improves 4,152.105 to
4,012.866 ms (3.35%) with a large 206.224 ms baseline MAD. This checkpoint is
rejected for those optimizing costs. Its source retains provenance for every HOT
body and rescans unsupported return bodies before declining; the next trial
shares static eligibility with existing mandatory call/control collection.
The partial RSS driver validates output but incorrectly selects V35 as the
optimizing baseline; preserve the valid plain samples and do not claim an
optimizing RSS result from that failed comparison. The corrected driver derives
its baseline from the actual frozen executable.

V42 caches eligibility in the existing call/control scan and declines unsupported
bodies before retaining provenance or allocating raw rewrite scratch. The new
metadata regression fails zero versus one first, then verifies control/call
fields, source ownership and independent function rows. All 13,028 default tests
and native controls pass. The frozen executable is
`c1a00cbeb23480e9ad3b8900dc29df2ce89c852a8f3e0e8f998b989a0fac024f`.
Output remains exactly V41 across both artifacts; no raw function grows.
Matched large optimizing still rises 6,631.143 to 6,728.035 ms (1.46%; MAD
5.192/11.110), and tee optimizing 114.446 to 118.498 ms (3.54%; MAD .730/2.833).
Small optimizing improves 10.907 to 10.683 ms (2.05%); large plain
3,725.568 to 3,713.771 ms is within the 38.128 ms candidate MAD. This trial also
remains unaccepted. Corrected three-pair RSS records plain 280,464 to 281,216 KiB
and optimizing 290,268 to 290,384 KiB, with no demonstrated memory win. Native
`sizeof` shows the dependency function payload grew 64 to 80 bytes, including
irrelevant type-family records. A new actual red native layout budget requires
64 bytes. The following trial stores optional metadata in two module-wide arrays
and restores the original record layout; it does not assume the layout change
causes the observed timing cost without a paired measurement.

V43 keeps the same qualification contract but stores admissions and original
write rows in module-wide arrays. The native function payload returns to its
original **64 bytes**, satisfying the actual red 80-byte layout budget. This is
a native declaration-size measurement, not a heap-byte or RSS claim. The
mandatory call/control collector owns admission; no extra admission body walk is
added. The private switch disables only this new path for focused benchmarks.

The accepted candidate passes **13,028 default tests**, 11 focused native core
cases, one admission case (eight subfixtures), one command case and four native
benchmarks, plus `moon info`, `moon fmt` and the native release build. Public
interfaces do not change. Native one-call replay improves **34.73 → 19.15 µs**;
32 helpers with 128 calls each improve **19.81 → 3.26 ms (83.5%)**, with setup
outside timing. Fresh small/large oracle cohorts retain source freeze and exact
traced/untraced output agreement. Small outputs stay identical to V38. Large
plain saves **42 raw / 40 canonical bytes** across three functions; large
optimizing stays identical. All 12,904 large functions per pass have no raw size
increase, and semantic non-code sections are unchanged. This narrow replay win
does not close the wider output parity gap.

CPU-6 matched V38/V43 medians use one warmup and three valid samples; reject and
retain rounds with a reference bracket above 1.15. MAD follows each median:

| Input / pass | V38 ms (MAD) | V43 ms (MAD) | Median change |
| --- | ---: | ---: | ---: |
| Small plain | 3.970 (.095) | 3.766 (.012) | −5.14% |
| Small optimizing | 10.617 (.047) | 10.782 (.014) | +1.55% cost |
| Large plain | 3,765.215 (.313) | 3,743.932 (.544) | −.57% |
| Large optimizing | 6,894.869 (28.662) | 6,825.965 (29.211) | −1.00% |
| Active tee plain | 2.925 (.011) | 2.881 (.010) | −1.50% |
| Active tee optimizing | 103.845 (.650) | 104.944 (.274) | +1.06% cost |

The large optimizing change is modest relative to dispersion. Accept the
measured structured replay benefit and stable plain gain; keep small/tee costs
and the wider cleanup bottleneck active rather than claim a dominant optimizing
win. Three-pair peak RSS medians are plain **281,672 → 280,968 KiB**, ranges
269,308–282,484 / 244,352–281,732; optimizing **290,128 → 290,088 KiB**, ranges
289,984–292,332 / 290,008–312,472. There is no robust RSS win.

The dedicated reduced runtime cohort compares original, corrected V38, V43 and
verified v133: **133 modules / 532 observations**, with no value, reference
identity, call-order or trap/throw mismatch. The fixed cohort adds **126 modules /
1,029 observations**. These bounded controls and the transform contract support
this replay family; validation and size alone are not semantic proof.

Fresh V43/v133 pass-local medians in their own cohort are small plain
**3.938 / 1.027 ms (3.836×)**, small optimizing **12.285 / 3.298 ms (3.724×)**,
large plain **3,760.792 / 475.614 ms (7.907×)** and large optimizing
**7,134.916 / 1,749.760 ms (4.078×)**. The optimizing canonical gap remains
**356,150 bytes** (5,929,600 versus 5,573,450), raw gap **222,734**. Read-only
local counting, no-work compaction admission, repeated flow-header queries and
conditional raw analysis are next measured trials. Long fuzz and final
aggregate/release gates remain deferred until those performance trials settle.

Frozen V43 native SHA-256:
`14db078506a705f270f1fe7387817efe9ed20272cbf77cbb663a81438d603e1a`.
Oracle: verified release `wasm-opt version 133 (version_133)`, SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
Local evidence stays under `.tmp/dae2-lean-20260929/`: `validation-v43.json`,
`counting-work-v41.json`, `suffix-info-layout-work-v43.json`, native benchmark
logs, `suffix-shape-v43.json`, runtime cohorts, matched pair samples, corrected
RSS samples and both `oracle-v43-{small,large}` manifests. Rejected V39–V42
samples retain their original versions; their absolute times are not causal
comparisons across cohorts.

## September 30, 2026 binary reference equality correction

The shared `dae_instr_stack_effect` incorrectly groups `ref.eq` with unary
instructions. Its actual stack effect is **two inputs, one output**. Extended
capture cleanup can consequently consume its held capture while leaving an
earlier stack reference behind. Both outputs validate, yet the earlier reference
becomes the return value. Moving `RefEq` to the existing binary group restores
the checked stack floor; the capture stays in a local when equality needs an
operand below it. No other opcode family or cleanup ordering changes.

The [arity and direct-capture regressions](../../../../../src/passes/dae_stack_effect_ref_eq_wbtest.mbt)
fail **Some((1,1)) != Some((2,1))** and **zero locals instead of one**.
The [public command fixture](../../../../../src/cmd/dae_stack_effect_ref_eq_wbtest.mbt)
also fails zero versus one before implementation. All three focused wasm-gc
tests pass after the correction. A bounded original/V35/verified-v133 runtime
replay confirms a **true semantic mismatch**: original and Binaryen return the
produced GC reference and observe equality **1**; V35 returns null and observes
**0**, with the same ordered base/producer/observer calls. An earlier dropped
equality variant also returns null incorrectly. Validation alone missed both.

The V32–V37 capture checkpoints therefore retain a reference-equality correctness
hole. Their previously documented runtime results cover their selected fixtures;
they are not general correctness or release signoff. Corrected frozen V38 native replay returns the produced reference and observes
**1**, matching the original and verified v133. Info/fmt, focused wasm-gc/native
tests and **13,015 default tests** pass. The small and large compiler outputs
contain no `ref.eq` instructions, so their historical artifact comparisons retain
that limited scope. The current V38 CLI is SHA-256
`5f93f13ab6609f8494637a45edbf9d3373213e5050ccc290f9a2e6b262b090e7`;
it also includes the separately measured parameter-alias cleanup. Its fresh
v133 oracle artifacts and size/timing evidence are retained. Long fuzz remains
deferred while performance iteration continues. Evidence:
`.tmp/dae2-lean-20260929/{ref-eq-{core,command}-{red,green}.log,
ref-eq-initial-probe.json,ref-eq-initial-{original,v35,binaryen}.wasm,
ref-eq-stack.{wat,mjs},ref-eq-stack-probe.json,ref-eq-stack-v38-result.json,
ref-eq-macro-opcodes.json,validation-v38.json,oracle-v38-{small,large}}`.

## September 30, 2026 immutable parameter aliases

Final DAE2 capture cleanup now substitutes dominated reads of a singly written
body-local alias with an unwritten parameter. Sources stay immutable across the
whole function. Child regions inherit dominating aliases and undo their own
definitions on exit; no full local-array copies or branch joins are introduced.
Earlier/default reads, sibling arms, first loop iterations and catch paths keep
their original local reads. A packed source/write-kind row removes unread alias
stores during the existing local remap. `local.tee` removal preserves its original
stack value. Shared lower cleanup enables this only for final DAE2 capture cleanup.

The complete legacy leaf/effect-spanning capture plan runs first. The rejected
V36 ordering moved pure reads before that plan and enlarged one small function
**186 → 190 bytes**, despite a smaller large module. A reduced overlap fixture
fails one local versus zero; legacy-first V37 fixes it. V38 additionally contains
the binary-reference-equality correction above. Initial positive scalar/reference,
branch, chain and metadata tests fail before implementation; tee and overlap
fixtures expose subsequent gaps. Eleven [core tests](../../../../../src/passes/dae2_parameter_aliases_wbtest.mbt)
and the [public command fixture](../../../../../src/cmd/dae2_parameter_aliases_wbtest.mbt)
pass, with exact fields/opcodes/metadata and input-ownership assertions.

Info/fmt, focused native/wasm-gc tests, **13,015 default tests**, the native CLI
and sixteen [benchmarks](../../../../../src/passes/dae2_parameter_aliases_perf_wbtest.mbt)
pass. The frozen V35 test reference copies the actual old helpers. At 8/64/512
set aliases, means are **2.49 → 2.61µs / 11.89 → 11.92µs /
85.21 → 84.51µs**; tee aliases are **2.87 → 2.88 / 13.29 → 12.72 /
97.09 → 91.31µs**. No-alias controls cost **2.48 → 2.62µs** and
**86.70 → 93.07µs**. Setup and correctness checks stay outside timed regions.
These costs remain targets; this unit establishes an output-quality improvement.
A full-collection dump-before/dump-after capture window for V38 records
**3,076,607,165 instructions**, **9,720,615 `mi_malloc` calls** and
**7,845,927 `mi_free` calls**. Unlike toggled collection, this part-2 window
scopes both events and calls. Direct allocator callers include balanced cleanup
(1,637,292), forwarding (1,418,060), local remapping (913,110), and read-only
counting (280,180). Counting currently rebuilds and discards control wrappers;
no-candidate compaction still walks/remaps bodies. These are allocation-request
counts, not bytes or live objects, and require measured enclosing trials.
Evidence: `capture-window-v38{,-callers}.json` and
`callgrind-v38-captures-window.2`; no true-window V35 call baseline is claimed.

The strict V35/V38 artifact audit finds **329 changed large functions**, removes
**610 set/get pairs and 3,487 tee writes**, and finds **no raw function-size
regression**. Non-code semantic sections and nonlocal opcode/immediate streams
remain unchanged; source indices change only through immutable substitution and
remapping. Large optimizing output shrinks **5,808,601 → 5,796,184 raw bytes**
and **5,942,450 → 5,929,600 canonical bytes**, saving **12,417 / 12,850**.
All small functions and plain artifact bytes stay identical. Against verified
v133's 5,573,450 bytes, the remaining gap is **222,734 raw / 356,150 canonical**.
The reduced imported-call loop improves **260/272 → 244/248 raw/writer bytes**;
v133 is **220/220**, and symmetric extra SimplifyLocals/Vacuum gives **220**
on every output. The remaining difference is an open parity gap.

Original-primary bounded replays match **126 modules / 1,029 observations**;
alias-specific scalar, reference/GC, tee/set, branch/default, loop/chain, mutable
snapshot, handler, signed-zero and trapping fixtures match **98 modules / 392
observations**, and the loop matches **7 modules / 42 observations**. Current GC
reference-equality replay separately repairs the historical V35 semantic bug.
Repeated i32/f64/externref alias fixtures are **66 bytes versus v133's 70**, with
matching values, reference identity, call/throw order and independently validated
outputs. This is a measured Starshine win for that family, not a general semantic
claim based on size or validation alone.

Matched CPU-6 V35/V38 medians (one warmup, three samples; before/after MAD) are
small plain **3.977 → 4.045ms** (0.031/0.040), optimizing
**10.815 → 10.814ms** (0.110/0.163); large plain
**4253.440 → 4490.821ms** (42.219/7.352), optimizing
**7294.671 → 7220.300ms** (261.299/79.500). Tee is
**3.060 → 3.106ms** (0.001/0.016) / **104.480 → 105.994ms**
(0.323/0.112). The large plain **+5.58%** cost remains unresolved; the optimizing
**−1.02%** median has substantial dispersion and is not an established speed win.
The earlier V35/V37 quality cohort records **+2.54%** large optimizing cost;
retain both cohorts rather than selecting the favorable result. Rejected tee
reference bracket **1.206** is retained. Three-pair RSS medians/ranges (KiB) are
plain **280,404 [269,120–281,588] → 282,012 [281,872–282,544]**;
optimizing **290,104 [289,884–302,000] → 290,024 [289,808–303,760]**.
There is no established RSS improvement.

Fresh V38/v133 pass-local medians are small **4.424 / 1.002260ms (4.41×)**,
optimizing **12.726 / 3.415470ms (3.73×)**; large
**3806.409 / 495.202ms (7.69×)**, optimizing
**7253.819 / 1764.950ms (4.11×)**. These oracle cohorts are separate from
causal pairs. P03 remains open, with structured signature-only rewrites,
conditional raw analysis, cleanup churn and broader copy aliases next.

Frozen V38 SHA-256:
`5f93f13ab6609f8494637a45edbf9d3373213e5050ccc290f9a2e6b262b090e7`.
Oracle release-v133 SHA-256:
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
Evidence: `.tmp/dae2-lean-20260929/{v36-red.log,v36-command-tee-red.log,
v36-tee-red.log,v37-overlap-red.log,validation-v38.json,candidate-v38.json,
alias-shape-v38.json,parameter-alias-runtime-v38,forwarding-loop-v38,
runtime-v38,oracle-v38-{small,large},pairs-v38-{small,large,tee},
alias-memory-v38.log,v38-bench.log}`. No public API changes. Long fuzz and
final aggregate signoff remain deferred until bottleneck trials are addressed.

## September 30, 2026 capture callback reuse

Five raw cleanup traversals now create their recursive child visitor once per
region: local counting, balanced capture removal, local remapping, DAE2 forwarding
and branchless block flattening. Flattening resets its per-instruction child
branch flag before every sibling. Shared counters, accumulated changes, label
masks and recursive scopes retain their previous lifetime. Native generated-code
TDD finds **five per-instruction allocation sites in V34, zero in V35**; this is
a compiled work-budget regression, not an initially failing semantic fixture.
The [three behavior guards](../../../../../src/passes/dae2_capture_callbacks_wbtest.mbt)
compare exact fields, instructions, flags, counters and label masks against the
[frozen V34 reference](../../../../../src/passes/dae2_capture_callbacks_reference_wbtest.mbt).

Info/fmt, native/debug guards, the existing command forwarding test, **13,000
default tests**, native CLI build and twelve native benchmarks pass. At 8/64/512
captures, cleanup improves **2.84 → 1.36µs / 21.04 → 8.62µs /
163.85 → 65.14µs**; branchless traversal improves **1.34 → 0.432µs /
9.61 → 2.82µs / 77.76 → 22.05µs**. Setup stays outside timed regions.
The large final-capture-only native profile falls **5,075,747,935 →
2,955,409,451 instructions (41.8%)**. Incoming `mi_malloc` calls fall
**52,254,437 → 43,495,605**, `mi_free` **164,228,390 → 151,194,926**.
Instructions are capture-scoped; call counters cover the whole command even
with event collection toggled. A deterministic counter check records 3,007
allocator calls while only seven occur in the selected function. The request
reduction therefore cannot be attributed solely to final capture cleanup; these
are not allocated bytes or live objects. See the
[Callgrind collection/instrumentation distinction](https://valgrind.org/docs/manual/cl-manual.html#cl-manual.limits).
Both profiled outputs validate and are byte-identical.

Matched CPU-6 V34/V35 medians (one warmup, three samples; before/after MAD) are
large plain **3516.314 → 3458.885ms** (10.612/37.971), optimizing
**6342.742 → 6180.746ms** (3.028/15.229); small **3.914 → 3.746ms**
(0.029/0.034), optimizing **10.741 → 9.972ms** (0.029/0.064).
Active tee is **3.530 → 2.694ms** (0.010/0.049) /
**101.413 → 99.306ms** (1.018/0.200). Rejected small reference brackets
1.170 and 1.207 remain recorded. Large peak RSS medians/ranges (KiB) are plain
**279,864 [279,736–279,992] → 269,828 [258,548–281,564]**, optimizing
**290,140 [289,708–291,028] → 292,364 [291,908–312,168]**. Optimizing RSS
is not an established improvement and remains a control cost.

All paired raw outputs are identical. Bounded original/V34/V35/v133 replays
match **126 modules / 1,029 observations**, with independently validated outputs.
Fresh v133 pass-local medians are small **3.828 / 0.957863ms (4.00×)** and
**11.469 / 3.176240ms (3.61×)**; large **3429.937 / 419.500ms (8.18×)**
and **6552.495 / 1615.990ms (4.05×)**. These oracle cohorts are separate
from causal pairs. The optimizing gap remains **235,151 raw / 369,000 canonical
bytes**. Remaining callback/storage churn, aliases, HOT lifting and optimizing
cleanup are active work; this checkpoint does not close Binaryen parity.

Frozen V35 SHA-256:
`e91d6a105bbceed6ffdf6f375a26e3e1c886928a6f1bc70d5b05e9d3706345e3`.
Oracle is verified release-v133 SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
Evidence: `.tmp/dae2-lean-20260929/{validation-v35.json,candidate-v35.json,
callback-cost-{v34,v35}.json,callback-native-cost-v35.json,native-{v34,v35}.c,
oracle-v35-{small,large},pairs-v35-{small,large,tee},runtime-v35,
callbacks-memory-v35.log,callgrind-{v34,v35}-captures,
callgrind-counter-scope.{c,json},v35-bench.log}`.
No public API changes. Long fuzz and final signoff remain deferred.

## September 30, 2026 scoped scalar forwarding cleanup

The final optimizing cleanup now exposes scalar and nested local-read forwarding
blocks, including nonnullable GC references. The reduced direct cleanup fails
**one local instead of zero** before the change. A bottom-up forwarding walk uses
the existing shared type snapshot; finding a scalar forwarding wrapper triggers
`pass_lower_cleanup_branchless_blocks` for that function. Its environment is
built lazily once. Blocks with inputs or control transfers retain their headers.
Changed functions lose stale label maps; the metadata guard now retains an actual
branch target instead of an obsolete scalar wrapper. The frozen V30 tuple helper
moves into its test reference, keeping that earlier benchmark control unchanged.

[Four fixtures](../../../../../src/passes/dae2_scalar_forwarding_wbtest.mbt)
cover nested i32/f64/externref captures, loads, nonnullable GC forwarding and
intentional input/branch fences. The [command guard](../../../../../src/cmd/dae2_scalar_forwarding_wbtest.mbt)
checks f64 results and calls. **12,997 default tests**, native/debug, command,
info/fmt, native release build and six native controls pass. Guarded V34 improves
8/64/512 forwarding controls **12.07 → 10.18µs / 87.97 → 61.47µs /
726.56 → 483.98µs**. The eager V33 trial is rejected: despite faster synthetic
controls, it changes no artifact bytes and matched large optimizing rises 2.21%.

V32/V34 raw artifact outputs are identical, including all 12,904 large functions;
this latent forwarding improvement saves no additional artifact bytes. Bounded
original/V32/V34/v133 replays match **126 modules / 1,029 observations**, plus
**36 modules / 108 call/reference/trap observations** and a reduced imported-call
loop's **7 modules / 42 observations**. Every output validates. That loop remains
**260 raw / 272 writer bytes versus 220** for v133 optimizing; another symmetric
SimplifyLocals/Vacuum round brings all three outputs to 220. The remaining loop
family contains parameter aliases and reused local captures, not raw forwarding
blocks. Writer-created expression wrappers must not be mistaken for raw blocks.

Matched CPU-6 V32/V34 compiler medians (one warmup, three samples; before/after
MAD) are large plain **3721.289 → 3668.633ms** (22.954/13.784), optimizing
**6705.669 → 6755.573ms** (9.821/28.158); small **4.110 → 3.951ms**
(0.030/0.006), optimizing **11.512 → 11.273ms** (0.055/0.036).
Tee is **3.743 → 3.779ms** (0.000/0.018) / **102.939 → 105.275ms**
(0.729/0.258). Rejected small reference brackets 1.186 and 1.180 stay recorded.
The optimizing artifact and tee costs remain explicit; this does not establish a
whole-pass win. Native C review finds per-instruction callback allocations in
forwarding, local counting and balanced-capture traversal; hoisting them is the
next allocation trial. Parameter-alias regressions also fail on retained locals
and branch-dominated reads and remain pending implementation.

Fresh v133 pass-local medians are small **4.142 / 0.999541ms** and
**13.505 / 3.174240ms**; large **3707.065 / 466.812ms (7.94×)** and
**7124.317 / 1690.510ms (4.21×)**. Output gaps remain **235,151 raw /
369,000 canonical optimizing bytes**. V34 binary SHA-256 is
`7b6e08f6af505a1b8dfe5f1fa19983448efd3d421568f3125bc4609f9b3c4725`.
Both oracle runs precede the next uncommitted alias fixtures. Evidence:
`.tmp/dae2-lean-20260929/{validation-v34.json,candidate-v34.json,
oracle-v34-{small,large},pairs-v34-{small,large,tee},runtime-v34,
forwarding-shape-v34.json,forwarding-runtime-v34,forwarding-loop-v34,
v33-red.log,v34-bench.log,native-{count,balanced,forwarding}-v34.c}`.
No public API changes; long fuzz and final signoff remain deferred.

## September 30, 2026 balanced effect-spanning captures

The final optimizing cleanup now removes a single-write/single-read capture
across balanced calls, arithmetic and known trapping producers. The producer
stays at its original position; its stack value remains below every intervening
operand. A checked stack-height scan requires each operand to come from above
that value. Unknown effects, structured regions, branches and unreachable
instructions end the scan. Calls resolve through the shared module type snapshot;
indirect/reference calls include their target operand. The interval remains
bounded at 256 instruction slots. Other callers keep their existing leaf scan.

The original scalar/reference fixtures fail with **one local instead of zero**.
[Six focused tests](../../../../../src/passes/dae2_balanced_captures_wbtest.mbt)
cover i32/f64/externref, trapping loads, indirect/reference/multivalue calls,
consumption of an earlier stack operand, branch intervals, repeated reads and
overlapping captures. The [command fixture](../../../../../src/cmd/dae2_balanced_captures_wbtest.mbt)
checks the public optimizing route's exact opcodes and validity. The first
extended-greedy prototype adds capture pairs in **25 artifact functions**; the
reduced overlap test fails **2 != 1 locals**. Final V32 runs the original smaller
leaf plan first, then removes additional balanced pairs. It preserves that test's
one-local output. V31 is rejected evidence, not the final size checkpoint.

All non-code semantic sections and nonlocal opcode/immediate streams of V30/V32
are identical. Across 12,904 large defined functions, **6,444 functions lose
32,070 set/get pairs**, none gain pairs, and tee counts stay unchanged. Small
loses four pairs in two functions. Raw optimizing output falls
**5,956,477 → 5,808,601 bytes (147,876 saved)**. The verified-v133 result is
5,573,450, leaving **235,151 raw bytes**. The comparison writer expands Starshine's
new held stack values: its canonical output is **5,942,450**, down 53,470 but
still **369,000 bytes larger**. This writer rewrites Starshine; it is not a
symmetric downstream optimization comparison. Plain DAE2 bytes stay unchanged.
These reductions prove a win over the previous Starshine capture shape; they do
not classify all remaining Binaryen drift or close the optimizing quality gap.

Info/fmt, **12,992 default tests**, six native/debug cases, the command case,
native CLI build and six native benchmarks pass. The bounded original/V30/V32/v133
replay matches **126 modules / 1,029 observations**. Another **36 modules /
108 observations** cover normal calls, side-effecting throws, out-of-bounds loads,
divide-by-zero traps, references and signed zero. Every output validates. All
producer/consumer event order, result and trap observations match the original.

The legacy-first plan has a cost: 8/64/512 capture microbenchmarks are
**4.24 → 4.76µs / 24.65 → 29.78µs / 193.45 → 222.34µs**. Matched CPU-6 V30/V32
compiler medians (one warmup, three samples; before/after MAD) are large plain
**3721.430 → 3753.686ms** (5.083/8.693), optimizing
**6667.219 → 6729.063ms** (36.251/23.845); small **3.900 → 3.976ms**
(0.015/0.068), optimizing **10.915 → 11.613ms** (0.051/0.096).
Active tee is **3.896 → 3.767ms** (0.137/0.031) /
**105.353 → 104.819ms** (0.303/0.477). A rejected small reference bracket
(1.152) is retained. This is a quality improvement with measured control costs,
not a demonstrated whole-pass speed improvement. Extra scan/materialization work
and scalar forwarding blocks remain optimization targets; peak RSS and native
allocation counts have not been renewed for this unit.

Fresh release-v133 pass-local medians are small **4.136 / 1.020240ms** and
**12.827 / 3.251740ms**; large **3679.039 / 451.402ms (8.15×)** and
**7060.102 / 1686.680ms (4.19×)**. This separate cohort is not a causal
comparison with V30. Long fuzz and final signoff remain deferred.

Frozen V32 native SHA-256 is
`3801863d728b9f07e166f0225a327597f150f91a3f88e4b8b310d494d3455c3c`;
V30 baseline and verified release-v133 hashes are recorded in the next section.
Both small and large oracle runs use the frozen source snapshot before the next
forwarding-block tests are added. Evidence:
`.tmp/dae2-lean-20260929/{validation-v32.json,candidate-v32.json,
oracle-v32-{small,large},pairs-v32-{small,large,tee},runtime-v32,
balanced-runtime-v32,capture-shape-v32.json,capture-shape-v31.json,
v32-bench.log,v33-red.log}`. No public API changes.

## September 30, 2026 read-source flow projection

DAE2 now requests `HotLocalReadSources`, an immutable snapshot with checked
count/scalar queries. The shared reverse/sparse solver preserves full-flow
source order, exceptional edges, unknown rows and shared-action fallback.
Only complete `HotLocalGraph` callers build writer influences, tee metadata,
already-SSA classification and defaultability. The narrower type has private
storage; no partial object is returned through the full graph API.

The original native work guard fails on **749,781 influence publications** and
**9,887 builds each** of already-SSA and defaultability metadata. Frozen V30
reduces all three to zero. Dependency-only instructions fall
**14,932,874,985 → 14,408,661,632 (3.51%)**; incoming allocator/free calls each
fall **754,570**, to 33,574,154 / 109,020,401. These are call counts, not
allocated bytes or whole optimizing-pipeline totals.

[Three fixtures](../../../../../src/ir/local_graph_read_flow_wbtest.mbt) compare
all ordered source rows and full graph fields against the frozen solver,
including joins, loops, references, exceptional edges, shared fallback,
unknown reads and snapshot ownership after mutation. Native/debug and wasm-gc
checks pass, including **12,985 default tests** and **549 IR tests**.
[Eight native controls](../../../../../src/ir/local_graph_read_flow_perf_wbtest.mbt)
compare identical CFG work: 8/64/512 conditional writers improve
2.68 → 2.28µs / 16.25 → 13.71µs / 128.33 → 106.20µs. The cold lift+CFG control
is 10.21 → 10.12µs. These isolate the solver, not compiler gains.

Matched V29/V30 CPU-6 compiler medians (one warmup, three samples; before/after
MAD in parentheses) are large DAE2 **3724.037 → 3736.133ms**
(17.523/4.853), optimizing **6650.038 → 6604.935ms** (6.424/37.735); small
3.985 → 3.951ms (0.036/0.033), optimizing 11.104 → 10.991ms (0.016/0.087).
Active tee is 3.783 → 3.852ms (0.004/0.105) / 104.228 → 104.248ms
(0.378/1.168). Conditional writers are 11.294 → 11.311ms (0.026/0.133) /
16.306 → 16.424ms (0.142/0.021), with a rejected 1.162 reference bracket kept.
No large plain-pass wall-time win is established.

Three-pair large peak-RSS medians are 281,020 → 268,772KiB for plain, with
259,644–281,116 / 257,656–282,200 ranges; optimizing 291,908 → 292,088KiB,
with 291,752–292,220 / 292,024–305,380 ranges. Overlapping ranges and the
optimizing increase remain explicit. The bounded original/V29/V30/v133 replay
matches **126 modules / 1,029 observations**, plus conditional-writer
**7 modules / 42 observations**. Every measured output validates and Starshine
bytes remain unchanged.

Fresh verified release-v133 pass-local medians are small
**4.133 / 1.014870ms** and **13.222 / 3.195760ms**; large
**3695.418 / 447.885ms (8.25×)** and
**6965.520 / 1682.870ms (4.14×)**. This separate cohort does not establish
causal improvement over earlier oracle runs. Canonical optimizing output
remains **+422,470 bytes**. Long fuzz and final signoff remain deferred.

Size attribution now isolates **+422,257 bytes in function bodies**: 8,687
positive functions add 432,374 bytes; 1,729 smaller bodies save 10,117. Compact
samples contain retained local captures around calls and arithmetic. The
imported-call loop reduction is **284 versus 215 raw bytes**. At this checkpoint, balanced-call
capture regressions failed with one retained local instead of zero. The later
balanced-capture section above supersedes that gap and its size baseline.

Evidence: `.tmp/dae2-lean-20260929/{validation-v30.json,candidate-v30.json,
oracle-v30-{small,large},pairs-v30-{small,large,tee},runtime-v30,
conditional-writers-v30,callgrind-v30-dependencies,dependency-cost-v30.json,
flow-work-{v29,v30}.json,memory-v30.json,size-v29.json}`. Frozen V30 native SHA
is `d8c339b06f04a18840a13acc5a05a144dcfba844ff11dcd85e31dd90d1e87af7`.
After freezing evidence, the internal solver record was marked private to
avoid an accidental opaque API export; the three source fixtures were rerun.
The next native checkpoint will include that visibility-only cleanup.

## September 30, 2026 carried dependency workspace

Nonempty preceding-dependency queries now reuse the carried-value vector in the
existing immutable facts workspace. Each query clears its temporary values and
visited flags before returning; selected rows remain independently owned.
Pure roots and empty candidate sets return before creating the workspace.
The collector appends a carried node only while its consumer bound is unset,
so the retained vector's high-water length is bounded by the snapshot's node
count. No per-query result row is retained or returned as workspace storage.

The actual original construction point is instrumented before implementation:
the reuse guard fails **8 vectors != 1**, and a fresh empty-future query wrongly
creates scratch. A semantic effect/ownership guard is initially green. Four
[focused guards](../../../../../src/ir/hot_source_order_carried_wbtest.mbt)
now pass, including alternating widths, held/mutated caller results, pure/empty
and indexed exits, independent facts, traps, local writes and reference values.
They retain revision, source ordering, all consumer flags and empty temporary
storage. The 32-value high-water fixture retains its capacity across narrower
and empty queries; the sibling owns a different vector. The private work counter
is a nullable native Int-array pointer; the emitted default wrapper maps an
omitted counter to zero without constructing a counter object.

An independent native allocation budget is also red on frozen V28. With the
same **1,070,492 root-header checks**, direct query `mi_malloc` calls fall
**3,092,437 → 1,788,660 (42.16%)**, passing the required 25% reduction.
Sorting calls fall **977,587 → 651,397** because empty candidates avoid the
old empty-vector sorting/selection setup; scratch construction falls
12,718 → 12,393. The matched complete large dependency scope falls
**15,059,317,658 → 14,932,874,985 instructions (0.84%)** and removes
**1,310,672 incoming `mi_malloc` calls and 1,310,672 `mi_free` calls**
(35,639,396 → 34,328,724 requests; 111,085,643 → 109,774,971 frees).
Direct query counts exclude constructor descendants. None of these call counts
are allocated bytes, live objects or optimizing-cleanup totals.

[Twelve native controls](../../../../../src/ir/hot_source_order_carried_perf_wbtest.mbt)
keep the original four-field scratch layout and fresh carried vectors in the
reference. Cold controls include new facts and scratch; warm controls reuse
facts and return a fresh selected row each time. Arena construction is outside
timing. The reference passes its old scratch explicitly, so its helper ABI is
not identical to the former CLI; compiler gains use frozen binaries below.
The controls remain mostly flat and do not establish a helper speedup:

| Carried values | Reference → selected warm mean | Reference → selected cold mean |
| --- | --- | --- |
| 8 | 380.48 → 379.66ns | 1.49 → 1.49µs |
| 128 | 5.40 → 5.44µs | **18.36 → 19.44µs (5.88% cost)** |
| 1024 | 42.21 → 42.32µs | 141.98 → 142.02µs |

A repeated cached native run retains the initial cold cost: 128-value cold
18.06 → 18.18µs, warm 5.35 → 5.43µs; 1024-value cold 140.44 → 141.70µs
and **warm 41.91 → 43.64µs (4.13% cost)**. Both complete twelve-control
logs stay saved. Fewer requests do not guarantee faster dense queries.

Matched V28/V29 compiler medians use CPU 6, one warmup, three accepted
alternating samples and stable leading/trailing reference brackets:

| Workload | Plain median ms (MAD before/after) | Optimizing median ms (MAD before/after) |
| --- | --- | --- |
| Large compiler | 3644.091 → 3634.874 (10.951/20.050; 0.25% gain) | 6551.206 → 6556.749 (29.150/22.673; 0.08% cost) |
| Small compiler | **3.961 → 4.033 (0.066/0.049; 1.82% cost)** | **10.857 → 11.283 (0.007/0.423; 3.92% cost)** |
| Tee | 3.718 → 3.779 (0.021/0.060; 1.64% cost) | 103.783 → 103.037 (1.110/0.111) |
| Joined readers | 18.946 → 18.934 (0.007/0.194) | **28.876 → 29.905 (0.328/0.434; 3.56% cost)** |
| Pure tail | 11.876 → 11.814 (0.072/0.049) | 12.109 → 12.007 (0.037/0.115) |
| Conditional writers | 11.508 → 11.276 (0.243/0.187) | 16.052 → 15.994 (0.112/0.037) |

Seven-sample repeats preserve the initial small/joined costs: small **3.940 →
3.910ms** (MAD 0.032/0.022) / **10.835 → 10.801ms** (0.066/0.052);
joined **19.013 → 19.052ms** (0.134/0.068) / **28.727 → 28.667ms**
(0.060/0.282). Small command CPU medians are 8.302 → 8.334ms /
15.283 → 15.136ms; joined 23.069 → 23.048ms / 32.865 → 32.904ms.
Rejected reference ratios 1.738, 1.878, 2.560, 2.454, 1.157 and 1.837,
including warmups, remain saved. This is a heap-work reduction with modest
compiler timing changes, not evidence that the Binaryen gap is closed.

Whole small-command instructions fall 77,344,251 → 77,237,587 plain and
168,261,163 → 168,149,251 optimizing. Small named allocator requests/frees
fall by 825 plain and 951 optimizing. Three alternating large RSS samples are
plain **259,636 → 255,680KiB**, ranges 258,964–281,368 / 255,212–282,892;
optimizing **292,064 → 293,352KiB (0.44% cost)**, ranges
291,796–292,268 / 292,208–302,424. Ranges overlap; reduced calls do not
prove reduced peak memory. Carried capacity persists only for its existing
facts lifetime, and downstream/high-water costs remain tracked.

All **12,982 bounded default tests**, four focused native guards, 546 IR tests
and twelve native controls pass after `moon info`/`moon fmt`; `.mbti` is unchanged.
Fixed original/before/after/verified-v133 replay validates **126 modules / 1029
observations**, plus three dedicated seven-module controls totaling **98
observations**. There are no observation mismatches or Starshine byte changes.
Traced, untraced, profile and RSS outputs independently validate and preserve
saved bytes. Large canonical optimizing output remains **5,995,920 vs
5,573,450 bytes (+422,470)**; raw remains +383,027. Long fuzz is deferred.

Frozen lean-v29 native SHA-256:
`eb63bbd7b170f33d5b6d2735dea1ee0c6bddf044970ffee9fed5679ba6d9e44d`.
Both fresh-source oracle reports identify production-source digest
`e26fd6977553625c0f2f4aa29cad78249f21296dfbfcfc4a4d23a81d372d18c2`
and the verified release-v133 binary
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
The manifest hashes all 1360 `src` files. Fresh open-world pass-local medians
are small **4.245 / 0.990528ms (4.29×)** and **12.916 / 3.147350ms
(4.10×)**; large **3632.536 / 436.392ms (8.32×)** and
**6880.646 / 1656.100ms (4.15×)**. These are a separate cohort from the
matched gain/cost estimates, not untraced command times.

Local evidence is `.tmp/dae2-lean-20260929/{validation-v29.json,candidate-v29.json,
carried-work-{v28,v29}.json,carried-native-v29.json,oracle-v29-{small,large},
pairs-v29-{small,large,tee},runtime-v29,conditional-writers-v29,joined-readers-v29,
pure-tail-v29,dependency-cost-v29.json,small-instructions-v29,memory-v29,
review-v29-{small,joined},v29-cold-review.log}` and associated drivers/logs.
Remaining comparator closures, source/reader rows, field reads, flow scaling,
read-only flow projection, optimizing cleanup, size-family investigations and
cumulative/final release evidence remain active in the backlog.

## September 29, 2026 checked region fields

Label, body-boundary, region-holder, optional-arm and opcode queries now read
only the required fields after the existing checked live admission. Region count
and selection reuse the admitted holder; selecting a root checks the holder,
body boundary and slot in the original error order without validating the same
holder twice. The private body-boundary helper requires prior live admission.
No query caches a node header or adds retained node-sized storage. Indexed
block inputs and loop branch arguments remain outside the selected body roots.

The actual native work budget is red on frozen V27: **16,005,714 full-header
return calls != 0** from the selected queries in the dependency scope. Both
public and private getter names are included. V28 passes with **zero** calls;
all twelve real generated query definitions, including the private body-boundary
helper, also contain no full-header call. This verifies a removed boundary,
not a renamed getter or an annotation. Four semantic guards are initially green,
not original correctness failures. They compare all current control families,
absent arms, shared roots, indexed block/loop inputs, root regions, incomplete
deletion indexes, node replacement and intentionally invalid holder labels with
[frozen query contracts](../../../../../src/ir/hot_region_fields_reference_wbtest.mbt).
Revision and arena ownership remain unchanged; public interfaces do not change.

[Twelve native controls](../../../../../src/ir/hot_region_fields_perf_wbtest.mbt)
include 4096 queries per timed batch, with arena construction outside timing.
They alternate blocks and loops and keep the complete descendant reference
queries frozen:

| Query | 16 holders, no deletions: header → fields | 4096 holders, 128 deletions: header → fields |
| --- | --- | --- |
| Label | 33.17 → 27.81µs | 39.02 → 33.16µs |
| Body boundary | 52.62 → 43.44µs | 55.67 → 43.62µs |
| Region root selection | 136.77 → 59.37µs | 169.48 → 57.27µs |

Matched V27/V28 compiler medians remain mostly near flat. One warmup, three
accepted samples, alternating order, CPU 6 and leading/trailing reference
brackets are retained with rejected attempts:

| Workload | Plain median ms (MAD before/after) | Optimizing median ms (MAD before/after) |
| --- | --- | --- |
| Large compiler | 3692.572 → 3684.686 (1.012/19.221; 0.21% gain) | 6611.134 → 6556.094 (8.584/11.077; 0.83% gain) |
| Small compiler | 3.979 → 3.959 (0.088/0.002) | **10.997 → 11.773 (0.002/0.363; 7.06% cost)** |
| Tee | 3.706 → 3.735 (0.009/0.021; 0.78% cost) | 108.308 → 103.424 (2.444/0.564; 4.51% gain) |
| Joined readers | **18.955 → 19.310 (0.010/0.449; 1.87% cost)** | **28.223 → 29.216 (0.069/0.626; 3.52% cost)** |
| Pure tail | 11.914 → 11.775 (0.161/0.080) | 12.007 → 12.035 (0.020/0.077; 0.23% cost) |
| Conditional writers | 11.520 → 11.257 (0.014/0.057) | 16.322 → 16.268 (0.154/0.079) |

Seven-sample repeats preserve the initial small/joined costs as evidence rather
than erasing them: small **4.006 → 4.010ms** (MAD 0.039/0.041) /
**11.179 → 11.098ms** (0.026/0.131); joined **19.425 → 19.337ms**
(0.151/0.151) / **29.347 → 29.353ms** (0.140/0.678). Small command CPU
medians are 8.408 → 8.234ms / 15.462 → 15.438ms; joined 23.668 →
23.643ms / 33.528 → 33.772ms. These repeats do not establish a universal
compiler speedup. Rejected reference ratios 2.445, 1.159, 1.230, 2.261 and
1.681 remain saved, including rejected warmups.

Direct shared-consumer controls also preserve bytes and validation. Initial
small SimplifyLocals/Vacuum medians are 5.325 → 5.355ms / **1.672 →
1.797ms (7.48% cost)**; conditional 1.285 → 1.327ms / 3.066 → 3.019ms.
Seven-sample small repeats are 5.383 → 5.334ms (MAD 0.034/0.033) /
1.651 → 1.667ms (0.015/0.045). Conditional SimplifyLocals/Vacuum repeats are
1.335 → 1.356ms (0.010/0.010; 1.57% cost) / 3.119 → 3.026ms
(0.022/0.022; 2.98% gain). Reference ratios 1.160 and 2.441 are rejected
and retained. Original costs stay visible;
these controls alone do not close P12 or its full artifact lanes.

The matched large dependency scope falls **15,509,334,518 →
15,059,317,658 instructions (2.90%)**. Incoming `mi_malloc`/`mi_free`
calls remain **35,639,396 / 111,085,643**: this reduces header/validation
work, not allocation requests. Whole small-command instructions fall
77,714,235 → 77,341,580 plain and 169,301,017 → 168,263,868 optimizing;
small named allocator calls are unchanged. Three alternating large RSS samples
show plain **258,916 → 269,656KiB (4.15% cost)**, ranges 255,484–259,080 /
258,440–270,260; optimizing 292,000 → 292,208KiB, ranges
291,952–292,088 / 291,864–302,624. Ranges overlap and this introduces no
new retained cache, but the measurements do not prove a memory improvement.

All **12,978 bounded default tests**, four focused native guards, 542 IR tests
and twelve native controls pass after `moon info`/`moon fmt`; `.mbti` is unchanged.
The fixed original/before/after/v133 replay validates **126 modules / 1029
observations**, plus three dedicated seven-module controls totaling **98
observations**, with no observation mismatch or Starshine byte change. Traced,
untraced, profile and RSS outputs independently validate and match saved bytes.
Large canonical optimizing output remains **5,995,920 vs 5,573,450 bytes
(+422,470)**; raw remains +383,027. Plain smaller output remains an open
parity classification, not a declared win.

Frozen lean-v28 native SHA-256:
`89c643a8f5c66f1ab3725c98a612f8d873ddc367e4856591b64127551550d3a6`.
Verified release-v133 oracle SHA-256:
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
Fresh-source open-world v133 pass-local medians, a separate cohort from the
matched gain estimates, are small **4.302 / 0.998993ms (4.31×)** and
**13.599 / 3.191740ms (4.26×)**; large **3654.406 / 437.909ms (8.35×)**
and **6907.248 / 1658.680ms (4.16×)**. The candidate manifest hashes all
1357 `src` files; both oracle reports identify the same 265 production compiler
files and production-source digest
`f9bf6d5981e0cc6ea83c05dbf52556c64476ab5de19397b30dfd08165ab1f36e`.

Local evidence is `.tmp/dae2-lean-20260929/{validation-v28.json,candidate-v28.json,
region-fields-work-{v27,v28}.json,region-fields-native-v28.json,oracle-v28-{small,large},
pairs-v28-{small,large,tee},runtime-v28,conditional-writers-v28,joined-readers-v28,
pure-tail-v28,dependency-cost-v28.json,small-instructions-v28,memory-v28,
review-v28-{small,joined},affected-cleanup-v28-{small,conditional},
review-cleanup-v28-{small,conditional}}` and the associated drivers/logs.
Remaining source/local field queries, scratch vectors and repeated flow work,
read-only flow projection, optimizing cleanup setup, size families, cumulative
matched evidence and long aggregate/final release signoff remain open. Long fuzz
is deferred while those performance trials continue.

## September 29, 2026 cached raw signatures

Function admission and raw cleanup previously flattened the complete recursive
type section for each defined-function parameter lookup, even when the existing
HOT module context already owned that table. Shared pipeline state now borrows
the context's flattened subtype row. A replacement type-section object refreshes
the raw table once, independently of the original context; unchanged type
snapshots survive body edits. Lowering already copies the section before
appending types. Lookup still reads the current function declaration and preserves
import offsets, recursive groups, invalid-index boundaries and context fallback.
There is no new node-sized cache or retained per-function HOT graph.

The [five focused guards](../../../../../src/passes/signature_lookup_wbtest.mbt)
first require the missing indexed seam, then the mechanically instrumented
original fails **9 table builds != 1**, existing-context borrowing and unchanged-
snapshot identity. Two semantic guards are initially green, not original
semantic failures. Replacement/append, isolated states, empty sections, mixed
imports and GC declarations match the
[frozen section-only lookup](../../../../../src/passes/signature_lookup_reference_wbtest.mbt).
An adjacent dispatcher guard runs both DAE2 modes and asserts valid live GC
parameters, results and exact helper instructions after removing an unused
scalar parameter. Generated native C confirms that the first cache-hit return
allocates nothing, the disabled work counter is a null pointer, and snapshot
identity compares the underlying RecType-array pointer.

[Twelve native controls](../../../../../src/passes/signature_lookup_perf_wbtest.mbt)
query every function in a validated module. Warm selection borrows the existing
context table; cold selection includes fresh pipeline state and its first table
build. Fixture construction is outside the timed loop:

| Functions/types | Original → selected warm mean | Original → selected cold mean |
| --- | --- | --- |
| 8 | 472.26 → 123.31ns | 503.65 → 195.40ns |
| 128 | 84.51 → 1.87µs | 84.17 → 2.56µs |
| 1024 | 5.23ms → 15.14µs | 5.17ms → 20.11µs |

This eliminates functions-times-types table materialization. A bounded V24b
large optimizing profile scoped to the original section-only lookup collects
**307,868,174 instructions**: object destruction 33.54%, subtype-array push
25.86%, reference-array growth 18.85%, and flattening itself 13.50%. That is
a helper scope, not total optimizer work. The candidate bypasses that wrapper;
comparing its same-symbol toggle would be an unmatched profile, so no such
before/after percentage is claimed.

Matched V26/V27 compiler medians remain near flat: large plain **4156.151 →
4189.225ms (0.80% cost)** and optimizing **7359.567 → 7319.885ms (0.54%
gain)**, MAD 24.948/20.383ms and 5.000/31.758ms. Small 4.177 → 4.142ms /
**11.933 → 12.248ms (2.64% optimizing cost)**, MAD 0.052/0.018ms and
0.137/0.256ms. Tee 3.827 → 3.858ms / 108.063 → 106.887ms, MAD
0.043/0.008ms and 0.381/0.423ms; joined readers 19.811 → 19.437ms /
29.409 → 29.213ms; pure-tail 12.596 → 12.396ms /
**12.271 → 12.765ms (4.03% optimizing cost)**. Small reference brackets
1.166/1.256 and joined brackets 1.577/1.155 are rejected and retained.
The wide helper gain does not establish a comparable compiler gain.

The initial conditional-writer medians are 13.370 → 13.390ms /
**18.168 → 22.292ms (22.70% optimizing cost)**, MAD 0.277/0.111ms and
0.652/2.180ms. A rejected 1.601 reference bracket stays saved. One accepted
candidate command takes 31.390ms wall versus 21.647ms CPU, showing a pause
that stable leading/trailing brackets do not exclude. Seven-sample matched
repeats retain, rather than erase, the initial record:

| Workload | V26 → V27 plain median (MAD before/after) | V26 → V27 optimizing median (MAD before/after) |
| --- | --- | --- |
| Conditional writers | 11.979 → 11.755ms (0.121/0.172ms) | 16.799 → 17.356ms (0.058/0.292ms; **3.32% cost**) |
| Pure tail | 12.093 → 12.412ms (0.048/0.105ms; **2.64% cost**) | 12.196 → 12.404ms (0.050/0.192ms; **1.71% cost**) |
| Small compiler | 4.123 → 4.068ms (0.036/0.069ms) | 11.360 → 11.594ms (0.172/0.247ms; **2.06% cost**) |

Repeated command CPU medians are 15.920 → 15.743ms / 21.069 → 21.673ms,
15.732 → 16.060ms / 15.561 → 16.035ms, and 8.484 → 8.563ms /
16.138 → 16.100ms, respectively. Additional rejected reference brackets
remain in the review manifests. These controls do not prove that each timing
cost is caused by signature lookup; costs remain visible rather than being
dismissed as noise.

Bounded whole-command instruction checks on those controls remain effectively
unchanged: conditional writers **223,839,619 → 223,840,813** plain and
**310,558,096 → 310,558,990** optimizing; pure tail **213,719,472 →
213,716,839** / **214,103,227 → 214,098,515**. These validate unchanged
bytes independently. Near-identical work counts do not establish identical
wall time or dismiss the measured control costs.

Plain dependency-analysis instructions stay near flat at **15,507,706,416 →
15,509,334,518 (0.011% increase)**, with unchanged named incoming malloc/free
calls **35,639,396 / 111,085,643**. This plain-pass scope does not measure
optimizing raw-cleanup table reuse. Small whole-command instructions are
77,710,218 → 77,711,474 / 169,373,687 → 169,306,686. Plain named allocator
calls remain 307,635 / 305,968; optimizing requests/frees fall by **135 each**,
487,682 → 487,547 / 486,015 → 485,880. Counts are incoming calls, not bytes
or net live objects. Three-sample RSS medians are 274,592 → 254,920KiB
plain, ranges 252,828–274,692 / 254,352–273,028; optimizing **289,616 →
290,912KiB (0.45% increase)**, ranges 289,592–289,816 / 290,128–309,764.
Three samples do not establish a causal memory win or regression.

Info, fmt, five native guards, the dispatcher guard, **12,974 default tests**,
release CLI and all controls pass. The fixed 126-module / 1,029-observation
original/v133 replay and active joined/pure/conditional replays match; measured
before/after and traced/untraced bytes stay identical and independently validate.
Public interfaces are unchanged. Local `.tmp/dae2-lean-20260929/` `v27`
records use candidate SHA-256
`679a713e3328d84a17b6cdeb5d3a20037338ab40ff011c787cffc82e25c1c0a1`.
Fresh verified-v133 pass medians are small 4.222/1.009660ms (**4.18×**)
and 13.055/3.181020ms (**4.10×**), MAD 0.074/0.002370ms and
0.502/0.011590ms; large **4001.091/503.817ms (7.94×)** and
**7659.620/1784.100ms (4.29×)**, MAD 18.437/7.730ms and 52.911/13.830ms.
One warmup, three samples and CPU 6 are retained; separate oracle cohorts do
not establish causal before/after gains.
The optimizing canonical size gap stays **422,470 bytes**. This is a quadratic
scaling fix, not closure of the multi-second pass gap; long fuzz remains deferred.

## September 29, 2026 cached dependency minima

The expanded CFG's preceding-dependency collector now consults the existing
per-node minimum cache before walking an operand subtree that cannot itself be
carried. A subtree whose earliest eligible value is at or after the current
source-order bound cannot contribute a preceding value. Direct carried values
keep their earlier fast path; selected value order and consumer bounds remain
unchanged. The cache is filled lazily within the existing immutable facts
snapshot, with no new node-sized storage. An in-progress minimum is conservative
for malformed cyclic query inputs; normal facts construction still requires
acyclic operand graphs.

The [four focused guards](../../../../../src/ir/hot_source_order_minimum_wbtest.mbt)
first expose a missing private kernel, then the instrumented original collector
fails **33 operand queries != 2**. Two semantic guards are initially green;
they are not claimed as original semantic failures. The work budget applies to
collection with a populated minimum cache, excluding the one-time cache fill.
Cold/repeated results match the [frozen V24b collector and query](../../../../../src/ir/hot_source_order_minimum_reference_wbtest.mbt),
including calls, local state, loads/traps, references, typed control and shared
inputs; scratch rows reset between queries.

[Twelve native controls](../../../../../src/ir/hot_source_order_minimum_perf_wbtest.mbt)
separate warm queries from cold facts construction plus the first query:

| Effectful leaves | Original → selected warm mean | Original → selected cold mean |
| --- | --- | --- |
| 8 | 407.40 → 148.25ns | 1.60 → 1.60µs |
| 128 | 4.71µs → 167.72ns | 17.63 → 17.81µs (1.02% cost) |
| 1024 | 39.34µs → 152.45ns | 139.20 → 138.87µs |

Matched V24b/V26 large compiler pass medians improve **4214.100 →
4094.742ms (2.83%)** / **7355.494 → 7215.137ms (1.91%)**, MAD
40.017/12.972ms and 23.468/12.770ms. Small medians are 4.146 → 4.064ms /
11.933 → 11.199ms, MAD 0.013/0.005ms and 0.222/0.141ms. Rejected small
reference brackets 1.337/1.458/1.386 remain saved. Tee plain costs **3.889 →
3.933ms (1.13%)**, MAD 0.032/0.029ms; tee optimizing is 107.362 →
106.651ms, MAD 0.084/0.267ms. Joined readers stay near flat at 19.432 →
19.354ms / 29.512 → 29.559ms. Pure-tail medians are 12.213 → 11.984ms /
13.098 → 13.008ms. Conditional writers are 11.687 → 11.716ms /
**16.618 → 17.014ms (2.38% optimizing cost)**, MAD 0.225/0.019ms and
0.159/0.105ms. These controls remain costs/limits rather than being hidden by
the warm-helper gain.

Dependency-analysis instructions fall **17,113,284,401 → 15,507,706,416
(9.38%)**. Named incoming malloc/free calls fall by **36,784 each**,
35,676,180 → 35,639,396 / 111,122,427 → 111,085,643; these are scoped
calls, not allocation bytes or net live objects. Small whole-command instruction
counts are 78,693,572 → 77,714,999 / 170,356,809 → 169,374,480.
Three-sample RSS medians are 257,852 → 256,616KiB plain and **290,712 →
302,024KiB optimizing (3.89% increase)**. Ranges 256,552–280,756 /
256,228–268,952 and 289,796–302,228 / 290,028–313,304 overlap; this does
not establish a causal memory gain or regression.

Info, fmt, four native guards, **12,968 default tests**, release CLI and all
controls pass. The 126-module / 1,029-observation original/v133 replay, two
active 7-module / 28-observation lanes and conditional 7-module / 42-observation
lane match, with unchanged before/after and traced/untraced bytes plus independent
validation. Fresh verified-v133 medians are small 4.162/1.017660ms and
13.704/3.195640ms; large **4042.251/489.438ms (8.26×)** and
**7554.394/1767.560ms (4.27×)**. One warmup, three samples, CPU 6 and frozen
hashes are retained. Oracle cohorts are not causal before/after experiments.
Optimizing canonical output still adds **422,470 bytes**; neither pass is closed.
Local `.tmp/dae2-lean-20260929/` evidence uses `v26`, candidate SHA-256
`0786d1da42c7fd2e72e23c5d2b575e92a69282ad17993b4fdf8eba7066d46e8a`.
Long fuzz remains deferred; operand/header reads, scratch churn, overlapping
access lists, lift/lower and optimizing cleanup remain active targets.

## September 29, 2026 bounded and linear source union

Admitted reverse-flow actions already have one node-to-block owner. Source
union now uses that existing index and seen workspace after eight source
lanes; the first lanes keep bounded contiguous searches. Each writer block
then contributes once, including a separately tracked query-root loop write.
Completed sources reset writer marks in linear time before ordinary visited
state resets. Entry sources remain disjoint and unique; unadmitted/shared
query callers retain the original general union, while full graph admission
still sends shared actions to sparse flow. No new node/block-sized storage or
public graph field is added. Source order and immutable row borrowing remain.

The nullable owner index is constructed once per build. Initial generated C
showed its constructor increment/decrement around each query; final native C
has **zero constructor increments in the query call branch**. This is
reference-count work, not a heap-box/allocation claim; incoming allocator
calls are unchanged. The automated native guard ran after C regeneration and
is green refinement evidence, not an initial-trial red. Its local mistagged
record was corrected rather than used as baseline evidence.

Seven [bounded guards](../../../../../src/ir/local_graph_source_union_wbtest.mbt)
cover ordered sources, cached-row identity, clean scratch, root loop writes,
parallel/exceptional edges, shared-action fallback and complete graph fields
in both operand modes. Initial zero-search work guards genuinely fail
**22 != 0 / 3 != 0** while semantic guards are green. The first all-marking
trial passes but costs **3.10%/1.65%** on matched compiler pipelines
(4106.148 → 4233.424ms / 7342.394 → 7463.294ms), MAD 27.909/2.743ms and
146.586/53.792ms. Its dependency instructions increase 0.18%; requests/frees
are unchanged. Those results remain historical and do not sign the refinement.

The refined contract uses at most eight-lane searches, with promotion for
wide rows. Tiny-row actual mark-write/reset work fails first, **2 != 0**,
then becomes zero; the wide 16-writer/two-edge guard proves bounded searches
and actual promotion with the exact original row. The earlier zero-search
expectations become bounded-search budgets; source/ownership assertions stay.
Eight [native query controls](../../../../../src/ir/local_graph_source_union_perf_wbtest.mbt)
force fresh rows, preserve indices/scratch and consume the complete result:

| Writers | Original search → bounded/linear mean |
| --- | --- |
| 1 | 90.47 → 89.82ns |
| 8 | 198.89 → 216.56ns (**8.88% cost**) |
| 128 | 6.17 → 2.03µs (**67% gain**) |
| 2048 | 977.16 → 27.24µs (**97% gain**) |

Compiler pipelines stay near flat: **3928.146 → 3910.220ms (0.46%)** /
**6707.366 → 6706.087ms (0.02%)**, MAD 72.691/41.775ms and
43.367/10.613ms. Small 4.152 → 4.159ms / **11.085 → 11.350ms (2.39% cost)**,
MAD 0.016/0.063ms and 0.025/0.242ms; tee 3.743 → 3.757ms /
**104.962 → 106.491ms (1.46% cost)**, MAD 0.005/0.012ms and
0.218/1.030ms. Joined-reader medians are 18.409 → 18.582ms /
27.859 → 27.961ms. Pure-tail **11.435 → 11.941ms (4.43% plain cost)** /
11.823 → 11.836ms, MAD 0.067/0.379ms and 0.162/0.274ms. Rejected brackets
1.184/1.221/1.214 are retained. Conditional-write pipelines are near flat,
11.312 → 11.206ms / 16.381 → 16.194ms, MAD 0.060/0.035ms and
0.170/0.164ms. Keep costs/dispersion; helper gains are not compiler gains.

Dependency instructions increase **17,063,254,721 → 17,113,284,401 (0.29%)**,
while requests/frees stay **35,676,180 / 111,122,427**. Small command
instructions increase 78,678,660 → 78,689,078 / 170,355,450 → 170,361,588,
with unchanged requests/frees. RSS medians are 280,804 → 257,560 KiB,
ranges 256,516–281,476 / 256,068–258,648; optimizing 292,200 → 292,004 KiB,
ranges 292,096–314,712 / 291,928–302,000. Overlap and three samples do not
establish a causal memory win. Retain this slice for bounded/linear scaling,
not as a general compiler or allocation win; small-row costs remain open.

Info/fmt, seven native guards, **12,964 default wasm-gc tests**, release CLI,
eight controls, fixed 126 modules/1,029 observations, two seven-module/
28-observation lanes and conditional seven-module/42-observation replay pass.
All before/after and traced/untraced bytes match and independently validate.
Public interfaces are unchanged. Frozen native SHA-256 is
`ad7f6c03df341abcd1eb325115b1ef084d98c7bf5da3271b6be1a45be56d3660`.

Fresh verified-v133 medians are small 4.588 / 1.027220ms (**4.47×**) and
13.632 / 3.176530ms (**4.29×**); large 3895.690 / 446.419ms (**8.73×**)
and 7325.910 / 1670.670ms (**4.39×**). MADs are 0.005/0.018150ms,
0.845/0.026540ms, 7.389/0.639ms and 52.810/2.360ms. CPU 6, one warmup,
three samples and unchanged canonical sizes retain the **422,470-byte
optimizing gap**. Separate cohorts do not establish causal ratio gains.
Local `.tmp/dae2-lean-20260929/` v24/v24b manifests, red/validation/bench,
fixed/active/conditional/RSS/work/oracle and constructor records own evidence.
Next are unused-local entry preflight, query header work, preceding-dependency
scratch, field reads and optimizing cleanup. Aggregate fuzz remains deferred.

## September 29, 2026 immutable entry reads

Full reverse LocalGraph construction now admits each action once, records
which locals have any write, and resolves never-written reads with one
entry-origin reachability walk. It reuses the existing seen/visited/work and
nearest-write vectors; only two local-count rows are new. Reached immutable
reads share one completed entry row per local. Unknown/unreachable reads stay
empty, including closed cycles and entries with admitted predecessors.
Exceptional-edge filtering and shared-action sparse fallback are unchanged.
All graph fields and source ordering remain complete; this is not a partial
sources-only public API.

Four [bounded guards](../../../../../src/ir/local_graph_entry_reads_wbtest.mbt)
compare every graph field with the frozen preceding builder, including
written definitions, default/parameter/reference locals, both operand modes,
exceptional entry backedges, reachable/unreachable cycles, and shared actions.
The actual per-block cache budget fails first, **67 != 51**, while the three
semantic guards are initially green. Six
[native full-build controls](../../../../../src/ir/local_graph_entry_reads_perf_wbtest.mbt)
include all graph construction and consume the completed result:

| Conditional writes | Original → immutable-entry build |
| --- | --- |
| 8 | 3.53 → 2.62µs |
| 64 | 78.86 → 16.45µs |
| 512 | 4.23ms → 154.94µs |

These improve **26%, 79%, 96%**. The new dedicated 1024-conditional-write
pipeline falls **29.287 → 11.745ms (59.90%)** / **33.833 → 16.797ms
(50.35%)**, MAD 0.060/0.048ms and 0.034/0.020ms. Its seven original/before/
after/v133 modules validate and match all 42 bounded runtime observations.
Input is 16,441 bytes, SHA-256
`d63812884c36c2742a24dd8dae7b8c4a27fb5dcd7e311dbd3545dc7f59960027`.
This is a dedicated performance lane, not an artifact-scale default test.

Three matched large compiler pairs fall **4044.453 → 3918.751ms (3.11%)**
/ **7071.974 → 6895.721ms (2.49%)**, MAD 33.823/41.118ms and
38.932/20.322ms. Small plain costs **4.037 → 4.077ms (0.99%)**, MAD
0.011/0.002ms; optimizing 11.325 → 11.316ms, near flat. Tee medians are
3.781 → 3.715ms / 108.483 → 107.940ms, MAD 0.041/0.017ms and
1.538/0.011ms. Rejected reference brackets 1.228/1.316 remain in evidence.
Joined-reader medians are 19.473 → 19.060ms / 29.753 → 28.947ms;
pure-tail **12.025 → 12.198ms (1.44% plain cost)** / 12.182 → 12.102ms,
MAD 0.056/0.340ms and 0.012/0.056ms. These controls and dispersion remain
limits; separate timing cohorts are not cumulative causal gains.

Dependency-analysis instructions fall **18,176,793,615 → 17,063,254,721
(6.13%)**, and incoming allocator requests/frees by **298,741** each:
35,974,921 → 35,676,180 / 111,421,168 → 111,122,427. Counts are named calls,
not bytes/net objects. Small whole-command instructions fall 78,762,741 →
78,683,467 / 170,418,104 → 170,356,583, with 150 fewer requests/frees in
both modes.

Untraced RSS medians are **281,536 → 282,212 KiB (0.24% plain cost)**,
ranges 281,512–283,280 / 258,060–282,308; optimizing 304,336 → 292,140 KiB,
ranges 292,104–314,440 / 292,020–314,496. Ranges overlap, so these three
samples do not establish a causal memory improvement. Preserve the extra
local-count storage and small/control costs for follow-up.

Info/fmt, four native guards, **12,957 default wasm-gc tests**, release CLI
and six controls pass. Fixed 126-module / 1,029-observation and both previous
seven-module / 28-observation replays match original/v133 results. All
before/after and traced/untraced bytes match and independently validate.
Frozen SHA-256 is
`916b6c74a5eac4d24146de60c0877185fa6b15c327712938349053f92d895ece`.
Public interfaces are unchanged; aggregate fuzz remains deferred.

Fresh verified-v133 medians are small 4.169 / 0.981300ms (**4.25×**) and
12.680 / 3.155730ms (**4.02×**); large 4017.808 / 437.888ms (**9.18×**)
and 7334.642 / 1718.580ms (**4.27×**). MADs are 0.089/0.003427ms,
0.425/0.059750ms, 2.472/0.062ms and 22.521/16.740ms. The input, one warmup,
three samples and CPU 6 are retained. The optimizing canonical size gap is
still **422,470 bytes**; no shape-win classification is inferred.

Evidence is local `.tmp/dae2-lean-20260929/` v23 manifests, red, validation,
bench, fixed/active/conditional-write runtime records, matched compiler,
work/allocator profiles and verified-v133 folders. Next are linear writer
source union, scratch reuse, field reads and optimizing cleanup. The entry
preflight can still walk for a never-read unwritten local; refine that trigger
without changing unknown rows. Buffer lifetime/memory follow-up stays open.

## September 29, 2026 fused writer metadata

Forward, reverse and sparse LocalGraph builders now construct their existing
writer-local and tee fields in one live arena scan. Both scalar vectors have
the known node-count span from allocation, with unchanged deleted/nonwriter
sentinels. The private two-reference value result adds no retained graph
field. Reverse flow borrows the completed local-ID index for predecessor
queries and retains both fields for its final graph; tee storage is therefore
available earlier in that build than in the original separate scans.

Three [bounded guards](../../../../../src/ir/local_graph_write_facts_wbtest.mbt)
cover zero/15-node spans, sets/tees/nonwriters, deletion-index fallback,
revision/free-list ownership and all three builders in both operand modes.
The baseline combines the original helpers and genuinely fails its known-
span work assertion, **16 != 15**, before the fixed-span fused implementation.
Its two semantic guards are green before; no semantic failure is claimed.
Eight [native controls](../../../../../src/ir/local_graph_write_facts_perf_wbtest.mbt)
include allocation of both result vectors and consume their complete rows:

| Roots / writer density | Separate → fused mean |
| --- | --- |
| 128 / sparse | 1.21µs → 421.89ns |
| 128 / dense | 2.70µs → 992.09ns |
| 8192 / sparse | 66.15 → 24.14µs |
| 8192 / dense | 157.90 → 59.79µs |

Helper gains are **62–65%**. Dependency-analysis instructions fall
**18,429,845,490 → 18,176,793,615 (1.37%)**; incoming allocator requests/frees
fall by **89,396** each, 36,064,317 → 35,974,921 /
111,510,564 → 111,421,168. These count named calls, not bytes/net objects.
Small whole-command instructions fall 78,940,083 → 78,751,426 /
170,611,371 → 170,425,152, with 126 fewer requests/frees in both modes.

Three matched compiler pairs are near flat: large **3802.798 → 3783.394ms
(0.51%)**, MAD 1.059/1.018ms; optimizing **6619.884 → 6609.561ms (0.16%)**,
MAD 31.514/50.202ms. Small medians are 3.883 → 3.810ms / 10.672 → 10.664ms;
tee 3.566 → 3.639ms (**2.05% cost**) / 106.013 → 102.011ms. Joined-reader
medians are 20.413 → 19.234ms / 29.388 → 30.724ms (**4.55% optimizing cost**),
MAD 0.851/0.109ms and 0.488/1.564ms. A 1.714 reference-bracket retry is kept;
host visibility and dispersion do not support a causal active-workload gain.
Pure-tail medians are 12.176 → 12.103ms / 12.147 → 12.088ms, near flat.

Untraced RSS medians are **257,288 → 269,580 KiB**, ranges
256,588–282,656 / 269,412–281,312; optimizing 292,044 → 291,896 KiB,
ranges 292,012–292,064 / 291,848–292,236. Preserve the **4.78% plain median
increase** and earlier tee-buffer lifetime; overlapping ranges establish no
causal memory win. Further memory/lifetime work remains open.

The candidate passes info/fmt, native debug, **12,953 default wasm-gc tests**,
release CLI and all eight controls. Fixed 126-module / 1,029-observation and
both seven-module / 28-observation active replays match original/v133 results.
All before/after and traced/untraced bytes match and independently validate.
Public interfaces are unchanged. Frozen SHA-256 is
`5ddc236e0a05eb81f6b4ba31692300a5cb6d0f6dd61b46f2f5f603b343a440de`.

Fresh verified-v133 medians are small 4.356 / 0.937708ms (**4.65×**) and
13.444 / 3.077960ms (**4.37×**); large 3759.060 / 416.509ms (**9.03×**)
and 6949.506 / 1595.020ms (**4.36×**). MADs are 0.051/0.012233ms,
0.160/0.066730ms, 0.934/1.037ms and 1.028/3.940ms. CPU 6, one warmup and
three samples remain; ratios from different cohorts are not causal changes.
Canonical sizes retain the **422,470-byte optimizing parity gap**.

Evidence uses local `.tmp/dae2-lean-20260929/` v22 manifests, actual red,
validation/bench logs, dependency/allocator/instruction profiles, matched
fixed/active/RSS records and oracle folders. Next targets are repeated
never-written-local reaching queries, quadratic source membership and
preceding-dependency working buffers. Preserve exact entry/unreachable
source rows and shared-action fallback; aggregate fuzz remains deferred.

## September 29, 2026 checked input-header fields

Operand-input queries keep the complete checked node-admission contract, then
read the arena header locally. The existing private admission helper has the
same live-index and legacy free-list fallback as `hot_node_get`; no unchecked
read, operand policy, retained cache, revision or public API changes.

The first two [bounded guards](../../../../../src/ir/hot_lower_input_header_wbtest.mbt) pass against the original query: they are
semantic/ownership controls, not claims of a prior semantic failure. They
compare the frozen original complete input query on real CFG control fixtures,
block/if/multivalue loop inputs, duplicate tuple lanes, intentionally supported
temporary absent slots, deletions and an incomplete deletion index, including
copy counts and unchanged revision/free storage. Six [native controls](../../../../../src/ir/hot_lower_input_header_perf_wbtest.mbt) consume
every complete operand query at 8/64/512 control groups outside setup.

The initial `v21` trial called the private full-header reader directly. Its
first native guard observed zero public-name calls, but native inspection
showed **15,921,704** calls to the private header-returning symbol from the
same input query. That renamed boundary did not meet the intended work
contract. The guard now includes both public and private complete-header
readers and fails on both original and initial trial. The initial profile
falls 0.86%, 18,434,089,586 → 18,275,167,806 instructions, with unchanged
36,064,317 requests / 111,510,564 frees. It is retained trial evidence, not
proof of boundary elimination. Initial matched large medians regress
3849.195 → 3889.291ms (1.04%, MAD 1.074/2.554) and optimizing
6653.685 → 6680.301ms (0.40%, MAD 14.018/32.700). Small 3.882 → 3.924ms /
10.961 → 10.863ms, tee 3.576 → 3.545ms / 101.440 → 99.771ms; joined
18.547 → 18.447ms / 28.041 → 28.004ms; pure-tail 11.752 → 11.585ms /
11.758 → 11.549ms. Its RSS ranges overlap, so no causal claim is made.

The refined `v21b` calls checked admission, then reads `func.nodes[id]` in
the query. Unlike the initial trial, the intended native contract is no
complete-header return calls from this reader, regardless of symbol name.
The strengthened guard passes at **zero** full-header return calls; checked
admission still runs, so this is not a reduction in all query/validation work.
Final dependency instructions are nearly flat, **18,434,089,586 →
18,429,845,490 (−0.023%)**. Requests/frees stay **36,064,317 / 111,510,564**.
Small whole-command instructions increase slightly, 78,936,034 → 78,941,581 /
170,584,657 → 170,617,575, with unchanged allocator calls in both modes.

Final complete-query controls at 8/64/512 groups are **1.40 → 1.21µs**,
**11.04 → 9.80µs**, and **88.64 → 78.18µs** (11–14%); setup and arena
allocation are outside timing. Matched large medians improve
**3877.834 → 3834.564ms (1.12%)**, MAD 6.644/3.253ms, while optimizing
**6637.800 → 6620.646ms (0.26%)**, MAD 35.379/9.621ms, is near flat.
Small medians are 4.152 → 4.037ms / 10.719 → 10.669ms; a 1.192 reference
bracket retry is retained. Tee medians are 3.522 → 3.518ms /
101.465 → 103.818ms: preserve the **2.32% optimizing control cost**.

Plain untraced RSS median increases **257,904 → 259,196 KiB**, ranges
257,504–258,336 / 258,624–281,912. Optimizing medians are
292,000 → 291,908 KiB, ranges 291,924–292,292 / 291,848–293,504.
Record the plain increase (0.50%) without a causal claim from three samples;
optimizing ranges overlap. No retained cache or node-array buffer was added.

Final verified-v133 medians are small 4.397 / 0.937713ms (**4.69×**) and
13.295 / 3.044530ms (**4.37×**); large 3776.687 / 421.478ms (**8.96×**)
and 6932.212 / 1600.160ms (**4.33×**). MADs are 0.086/0.004388ms,
0.260/0.006610ms, 2.512/2.657ms and 0.661/11.390ms. Ratios retain CPU 6,
one warmup and three samples, and do not measure a causal ratio change
against older cohorts. Canonical bytes/sizes retain the **422,470-byte
optimizing parity gap**; smaller plain output alone is not a proven win.

Both iterations pass info/fmt, native debug, **12,950 default wasm-gc tests**,
release CLI, six controls and fixed 126-module / 1,029-observation replays.
Byte-exact before/after and traced/untraced output independently validates.
Public interfaces are unchanged. Initial SHA-256 is
`a03464a2316394b2197020f74a20175d1468a5afc313e176ddbabd50533ee657`; final
`f4538c12dd02d6dfa54a94f2829fe8f13fc01f3bb80f5f735646cd6e7810f679`.

Evidence: local `.tmp/dae2-lean-20260929/` v21/v21b manifests, validation and
bench logs, strengthened red/work guards, dependency/allocator/instruction
profiles, fixed/paired/RSS records and verified-v133 oracle folders. Both final
active lanes pass seven modules / 28 matching original/v133 observations, with
identical before/after bytes. Joined-reader medians are 18.587 → 18.474ms /
27.836 → 27.675ms; pure-tail 11.434 → 11.433ms / 11.953 → 11.899ms,
all near flat. Larger targets
are LocalGraph writer scans, quadratic source membership and unused read rows,
and preceding-dependency working buffers. Aggregate fuzz stays deferred.

## September 29, 2026 single core validation

The public all-verifier called the complete core verifier before calling the
control verifier, which starts by calling core again. No mutation or callback
separates those checks. The all-verifier now delegates to the same complete
control entry point once; standalone core/control APIs, their validation
coverage, cache argument behavior and error order remain unchanged. The private
work counter is per verification, not per node; it adds no retained cache.

Two [bounded guards](../../../../../src/ir/hot_verify_core_once_wbtest.mbt)
fail first with **2 != 1** on the original two-call sequence, then check one
complete core walk on empty, ordinary, control and legacy-catch functions.
They compare original all-verifier results, unchanged revisions, both cache
argument types, core-before-control error precedence, malformed exit arity
and orphan catch rejection. The earlier helper-raises compile failure is kept
separate from the actual red work assertion. Eight
[native controls](../../../../../src/ir/hot_verify_core_once_perf_wbtest.mbt)
compare complete validation with and without legacy catches at 128/4096 roots.

The first single-core candidate (`v20`) still boxed an explicitly forwarded
`None` work counter. Generated C identifies the allocation, and a focused
native cost guard fails with **17 != 0** on the small command while its raw
bytes independently validate and equal the matched output. The first guard
attempt used a canonical oracle output path and failed its byte comparison;
that harness failure is retained separately and is not the allocation red.
The final `v20b` default path calls the uncounted complete control entry point
and keeps explicit counters on their instrumented path. The cost guard is
now green at **zero** default-forwarding allocations, with unchanged bytes.
Source-only suspicion of per-query reverse-flow counter boxes is superseded:
its generated C already forwards the nullable pointer directly to the inner
kernel. No change is justified for that suspected allocation.

Final complete-verifier controls:

| Roots / legacy catch | Original duplicate → single mean |
| --- | --- |
| 128 / absent | 3.24 → 1.86µs |
| 4096 / absent | 100.19 → 56.43µs |
| 128 / present | 5.12 → 3.50µs |
| 4096 / present | 135.14 → 90.03µs |

The initial v19→v20 dependency profile removes **9,887** direct core calls;
12,718 core calls from control entry remain. Instructions fall
**19,116,248,490 → 18,436,041,744 (3.56%)** and incoming requests/frees by
**280,661** each (36,354,865 → 36,074,204 / 111,801,112 → 111,520,451).
Small whole-command instructions fall 79,499,491 → 78,939,286 /
171,144,584 → 170,595,337; requests/frees fall by 481 in both modes.
Three matched compiler pairs are near flat: large **3899.809 → 3880.437ms
(−0.50%)**, MAD 14.442/10.174ms; optimizing **6678.827 → 6636.707ms
(−0.63%)**, MAD 20.770/17.782ms. Small medians are 3.963 → 3.875ms /
10.782 → 10.736ms, tee 3.532 → 3.561ms / 100.914 → 103.071ms.
Active joined-reader medians are 18.764 → 19.156ms / 27.858 → 27.618ms;
pure-tail 11.571 → 12.079ms / 12.527 → 12.172ms. Preserve the plain active
and optimizing tee costs and dispersion. Managed visibility does not prove
quiet-host timing. Untraced large RSS medians are 271,816 → 269,588 KiB,
ranges 259,544–281,584 / 255,516–270,484; optimizing 292,076 → 314,440 KiB,
ranges 292,012–294,080 / 292,172–314,536. The optimizing median increase is
recorded; overlapping ranges do not establish a causal memory claim.

The initial current-source v133 renewal gives small medians 4.090 / 0.950781ms
(**4.30×**) and 12.090 / 3.032920ms (**3.99×**); large
3853.517 / 418.791ms (**9.20×**) and 6995.914 / 1601.970ms (**4.37×**).
MADs are 0.023/0.001793ms, 0.274/0.005700ms, 21.610/1.912ms and
10.893/6.670ms. These fresh cohorts do not measure causal ratio changes.
Initial frozen SHA-256 is
`49427761448648d73764a36f88a5179c4e74adaf5a006b7fc5233d6e4e9d975e`;
final `v20b` is
`13312635576e7a89a4e616faea3d50a73057b44973ff21e4e53e6abb7a8e12ca`.
Both pass info/fmt, native debug, all **12,948 default wasm-gc tests**, release
CLI and eight controls. Initial fixed/active replays and the final fixed replay
pass with exact before/after bytes and original/v133 observations; final
measurements are separately owned below rather than silently replacing this
initial control. Public interfaces remain unchanged.

The final v20→v20b refinement removes **9,887** more dependency-window
requests/frees: **36,064,317 / 111,510,564** remain. Instructions fall another
1,952,158 (0.0106%), to **18,434,089,586**. Relative to the original v19 core
sequence, final instructions are down **3.57%** and requests/frees by
**290,548**. These are named call/work counts, not allocation-byte or retained-
object counts. Small requests/frees drop by 17 in both modes; instruction
controls are near flat, 78,932,831 → 78,931,546 /
170,586,274 → 170,590,506, preserving the optimizing cost.

Three refinement pairs give near-flat large medians **3847.115 → 3854.029ms
(+0.18%)**, MAD 13.862/10.605ms, and optimizing **6660.027 → 6617.547ms
(−0.64%)**, MAD 26.241/13.900ms. Small medians are 3.998 → 3.960ms /
10.860 → 10.936ms; tee 3.493 → 3.561ms / 100.850 → 101.048ms; joined
readers 18.418 → 18.400ms / 27.861 → 27.810ms; pure-tail
11.474 → 11.467ms / 11.679 → 11.614ms. Do not multiply gains across these
separate cohorts. Refinement RSS medians are 281,644 → 281,308 KiB,
ranges 258,656–281,980 / 256,968–281,668; optimizing
304,304 → 292,004 KiB, ranges 292,200–314,656 / 291,900–302,116. Overlap
establishes no causal memory gain. Final fixed and both active replays match
all bytes and original/v133 observations, with independent validation.

Final verified-v133 medians are small 4.313 / 0.961476ms (**4.49×**) and
12.425 / 3.113380ms (**3.99×**); large 3869.286 / 422.985ms (**9.15×**)
and 7049.952 / 1605.100ms (**4.39×**). MADs are 0.089/0.027601ms,
0.212/0.058020ms, 6.175/2.496ms and 14.445/1.620ms. They retain CPU 6,
one warmup and three samples; new-cohort ratios are not causal gains over
prior sweeps. The large sweep and queued profile steps were interrupted by
the server restart. Completed validation, small-oracle, fixed replay and
memory records were retained; only unfinished steps were resumed. The partial
large folder/log remains interrupted evidence, and the successful renewal is
`oracle-v20b-large-recovered/`. Canonical sizes are unchanged; the
**422,470-byte optimizing gap remains open**, and smaller plain output alone
is not a proven win.

Local `.tmp/dae2-lean-20260929/` evidence uses `v20` and `v20b`, including
source manifests, red/validation/bench/native-cost logs, fixed/paired/active
replays, `dependency-cost-v20{,b}.json`, small instructions/allocator and RSS
records, and initial/final oracle folders. Both seven-module active lanes
observe 28 matching results; the fixed lane retains 126 modules / 1,029
observations. Final source is frozen before later experiments advance it.
The pinned input/oracle hashes remain below. The next confirmed cost is the
operand-query helper's **15,921,704** public complete-header reads; consider
the existing checked private implementation with native call/instruction
and full pipeline controls. Aggregate fuzz remains deferred by request.

## September 29, 2026 catch-layout preflight

The full control verifier already scans every live HOT node. It now records
whether that scan encounters `Try` or `Catch`; only those operations can affect
the legacy catch-payload layout check. A catch-free function skips the unused
admission vector and two arena walks. Legacy tries and live orphan payloads
still run the original checker; core validation, branch checks, handler checks
and error precedence remain intact. This is a preflight for a vacuous check,
not an unchecked validation entry point or a revision cache.

Two [bounded guards](../../../../../src/ir/hot_verify_catch_layout_wbtest.mbt)
compare the frozen original full control verifier, unchanged revisions,
valid catch payloads, invalid function-exit arity and live orphan payloads.
The valid catch-free work assertion fails first with **1 != 0**, then passes;
valid legacy catches and orphan rejection each still invoke the layout checker
once. Eight [native controls](../../../../../src/ir/hot_verify_catch_layout_perf_wbtest.mbt)
include the complete core/control validation:

| Roots / legacy catch | Original → guarded mean |
| --- | --- |
| 128 / absent | 2.87 → 1.82µs |
| 4096 / absent | 88.62 → 56.50µs |
| 128 / present | 3.56 → 3.57µs |
| 4096 / present | 95.84 → 93.44µs |

Dependency-window instructions fall **19,515,570,507 → 19,116,248,490
(2.05%)**. Incoming allocator requests/frees fall by **38,154** each,
36,393,019 → 36,354,865 / 111,839,266 → 111,801,112. The original layout
checker had 12,718 named calls; the catch-free large profile has none after
the guard. These are named call counts, not byte or retained-object counts.
Small instructions fall 79,872,223 → 79,493,215 / 171,579,405 → 171,144,932;
requests/frees fall by 63 plain and 75 optimizing.

Three alternating v18→v19 large pairs give DAE2 **3982.634 → 3925.734ms
(−1.43%)**, MAD 4.410/4.675ms, and optimizing **6788.859 → 6702.398ms
(−1.27%)**, MAD 7.191/6.543ms. Small medians are 3.957 → 3.924ms /
11.039 → 10.891ms; tee 3.575 → 3.522ms / 101.305 → 102.764ms.
The small optimizing bracket retries reference drift 1.157. Preserve the
optimizing tee cost and dispersion; managed visibility does not prove quiet
host timing. Active joined-reader medians are 19.328 → 18.664ms /
28.353 → 27.974ms; pure-tail 12.280 → 11.736ms / 12.417 → 11.778ms.
Three alternating untraced large RSS samples give plain medians
282,176 → 258,780 KiB, ranges 260,340–282,608 / 257,272–269,344;
optimizing 309,864 → 292,200 KiB, ranges 292,020–314,400 / 292,020–292,216.
Overlapping ranges do not establish a causal memory gain.

Info/fmt, native debug, all **12,946 default wasm-gc tests**, release CLI and
eight controls pass. Exact before/after/traced bytes, independent validation,
126 modules / 1,029 original/v133 observations and both seven-module /
28-observation active replays pass. No public API changes.

The freshly frozen current-source v133 renewal uses CPU 6, one warmup and
three samples. Small pass-local medians are 4.331 / 0.966971ms (**4.48×**) and
12.265 / 3.135380ms (**3.91×**); large 3888.417 / 423.069ms (**9.19×**)
and 7048.657 / 1607.030ms (**4.39×**). MADs are 0.080/0.000742ms,
0.327/0.108670ms, 12.981/0.328ms and 10.373/0.380ms. These fresh cohorts
are not paired ratio gains over v18. Canonical sizes retain the values below;
the **422,470-byte optimizing gap remains open**, and smaller plain output
alone does not prove a Starshine win.

Local `.tmp/dae2-lean-20260929/` evidence uses `v19`: source manifest,
red/validation/bench logs, fixed/paired/active replays, `dependency-cost-v19.json`,
small instruction/allocator and RSS records, and `oracle-v19-{small,large}/`.
Frozen candidate SHA-256 is
`9fafad5c41d229a788a04e43646a518e38c0549e526c099e4e78704bea00afcb`;
before is v18 `3fef08348d42db75886acb76d0acf548f2dad245ba32996213ad0045e3332155`.
Pinned input/oracle hashes remain below. Source inspection/profile attribution
also confirms the all-verifier's duplicate core call: 9,887 direct calls in
addition to 12,718 control-entry core calls. That separate work remains open
at this checkpoint. Aggregate fuzz remains deferred by request.

## September 29, 2026 empty continuation-query guard

The CFG builder already scans every live node for continuation instructions.
When that scan leaves its continuation cache empty, segmentation now uses a
Boolean query that returns false directly and block processing skips the empty
target loop. Nonempty caches retain the original target aggregation, ordering
and branch-edge construction. No extra retained buffer or public API is added.

Three [bounded guards](../../../../../src/ir/cfg_continuation_guard_wbtest.mbt)
cover published-row ownership/order, empty and cold caches, frozen original
segmentation, complete partial-CFG/root maps and both operand modes. Published
rows are opaque cache facts, not a new runtime continuation fixture. The initial
red compile lacks the new private helper; it establishes the new work/API
contract rather than a preexisting semantic failure. Eight
[native controls](../../../../../src/ir/cfg_continuation_guard_perf_wbtest.mbt)
include fresh builder/source-fact construction:

| Workload | List queries → guarded mean |
| --- | --- |
| 128 empty queries | 1.74µs → 717.54ns |
| 8192 empty queries | 109.51 → 45.20µs |
| Region, 64 groups | 43.58 → 41.71µs |
| Region, 512 groups | 347.47 → 333.60µs |

Dependency-window instructions fall **20,041,432,123 → 19,515,570,507
(2.62%)**. Incoming allocator requests fall **40,733,403 → 36,393,019**:
**4,340,384 fewer (10.66%)**. Frees fall by the same count,
116,179,650 → 111,839,266. These are named call counts, not byte or retained-
object measurements. Small command instructions fall 80,271,379 → 79,877,693 /
171,954,261 → 171,561,201; each removes 3,241 requests and frees.

Three alternating v17→v18 large pairs give DAE2 **4259.192 → 4218.427ms
(−0.96%)**, MAD 13.736/37.014ms, and optimizing **7317.563 → 7211.068ms
(−1.46%)**, MAD 128.740/11.458ms. Small medians are 4.219 → 4.245ms /
11.372 → 11.398ms; tee 3.846 → 3.859ms / 103.396 → 105.478ms. Active
joined-reader medians are 20.785 → 20.016ms / 30.023 → 30.248ms; pure-tail
13.184 → 13.175ms / 13.428 → 13.223ms. Preserve the optimizing tee/control
costs and reference-drift retries (1.205 small and 1.199 pure-tail). Managed
process visibility does not prove quiet-host timing. Three alternating untraced
RSS samples have plain medians 257,676 → 257,544 KiB, ranges
257,608–280,724 / 257,176–282,056; optimizing 292,148 → 292,296 KiB,
ranges 292,016–314,300 / 291,852–304,340. Overlap establishes no memory gain.

Info/fmt, native debug, all **12,944 default wasm-gc tests**, release CLI and
eight controls pass. Exact before/after/traced bytes, independent validation,
126 modules / 1,029 original/v133 observations and both seven-module /
28-observation active replays pass. The current-source verified-v133 renewal
uses CPU 6, one warmup and three samples: small medians 4.364 / 0.998475ms
(**4.37×**) and 13.103 / 3.275570ms (**4.00×**); large
4170.494 / 446.723ms (**9.34×**) and 7586.644 / 1626.730ms (**4.66×**).
MADs are 0.022/0.017834ms, 0.364/0.103740ms, 33.291/4.613ms and
7.916/3.890ms. These fresh cohorts do not measure a causal ratio change over
v17. Canonical large sizes remain unchanged; the **422,470-byte optimizing
gap remains open**, and smaller plain output alone is not a proven win.

Local `.tmp/dae2-lean-20260929/` evidence uses `v18`: source manifest,
validation/bench logs, fixed/paired/active replays, `dependency-cost-v18.json`,
small instruction/allocator and RSS records, and `oracle-v18-{small,large}/`.
Frozen candidate SHA-256 is
`3fef08348d42db75886acb76d0acf548f2dad245ba32996213ad0045e3332155`;
before is v17 `e7b6149bbea19956d8adb8dcbdbef2a5857b0b30b806371ba33f8f8bbc66060c`.
Pinned input/oracle hashes are preserved below. Aggregate fuzz remains deferred
at the user's request; these bounded checks do not renew generated signoff.

## September 29, 2026 shared own-effect results

The operand-order walk already computes each node's own effects for its first
external-effect order. It now writes those contributions into the mask buffer
that all-child effect aggregation will consume. Aggregation ORs descendant
contributions in place instead of querying node flags/exact payloads again.
The operand-order and all-child walks still use their original distinct edge
sets; control-region effects cannot contaminate operand first-effect orders.
No additional node-sized array is retained, and standalone effect construction
keeps its original computation when no owned buffer is supplied.

Three [bounded guards](../../../../../src/ir/hot_source_order_own_masks_wbtest.mbt)
check exact own contributions, pointer reuse, all-child masks and operand
orders against frozen original walks. Cases cover division traps, memory and
GC reads, imported effects, control inputs, source-ordered local writes,
shared operand DAGs, deleted IDs and empty arenas. New private fields/arguments
are absent at the initial red compile; this is an API/work contract addition,
not a preexisting semantic parity failure. Ten [native controls](../../../../../src/ir/hot_source_order_own_masks_perf_wbtest.mbt)
include all fresh fact allocation and four standalone-builder comparisons:

| Construction | Original → reused mean |
| --- | --- |
| Facts, 8 roots | 15.93 → 13.33µs |
| Facts, 64 roots | 125.61 → 105.74µs |
| Facts, 128 roots | 251.16 → 209.91µs |
| Standalone masks, 8 roots | 6.47 → 6.48µs |
| Standalone masks, 128 roots | 102.91 → 102.78µs |

Dependency-window instructions fall **20,241,185,629 → 20,041,432,123
(0.99%)**. Recorded named own-effect call edges fall **7,410,967 → 3,704,362**;
the operand-order visitor retains its 3,704,362 calls. These are Callgrind
function edges, not a guarantee that every inlined evaluation appears as a
named call. Large allocator requests/frees remain 40,733,403 / 116,179,650;
small command counts also remain unchanged. Small instructions fall
80,491,061 → 80,271,203 / 172,211,670 → 171,957,006.

Three alternating v16→v17 pairs give near-flat compiler medians: large DAE2
**4270.513 → 4249.844ms (−0.48%)**, MAD 8.519/15.334ms; optimizing
**7186.294 → 7217.688ms (+0.44%)**, MAD 14.279/98.167ms. Small medians
are 4.192 → 4.173ms / 11.145 → 11.232ms; tee medians are
3.724 → 3.672ms / 105.400 → 105.614ms. Active joined-reader medians
are 20.614 → 20.275ms / 30.133 → 29.853ms; pure-tail medians are
13.441 → 13.407ms / 13.889 → 13.765ms. Preserve control costs and dispersion;
no compiler-wide timing gain is established. Managed visibility does not
establish quiet-host timing. Three alternating untraced large RSS samples give
plain medians 259,928 → 280,724 KiB (ranges 259,688–281,736 /
259,376–281,912) and optimizing 292,292 → 293,496 KiB (ranges
292,276–314,332 / 292,144–304,528). The median increases remain recorded;
overlapping ranges do not establish a causal memory increase or gain.

Info/fmt, all **12,941 default wasm-gc tests**, native debug, release CLI,
ten controls and README/API sync pass. Exact before/after/traced bytes,
independent validation, 126 modules / 1,029 original/v133 observations and
both seven-module / 28-observation active replays pass. No public API change.

The current-source oracle renewal passes with verified v133, CPU 6, one warmup
and three samples. Small pass-local medians are 4.277 / 0.999788ms (**4.28×**)
and optimizing 13.144 / 3.13785ms (**4.19×**); large are
4432.497 / 494.776ms (**8.96×**) and 7732.823 / 1763.390ms (**4.39×**).
MADs are 0.051/0.029676ms, 0.231/0.046850ms, 122.378/5.498ms and
201.165/10.210ms. These are fresh comparison cohorts, not paired ratio gains
over earlier sweeps. Canonical sizes retain the v15 values below; the
**422,470-byte optimizing gap remains open** and smaller plain output alone
is not a proven win. The rejected v16 freshness attempt remains failed evidence.

Local `.tmp/dae2-lean-20260929/` evidence uses `v17`, including its source
manifest, validation/bench/API logs, paired/fixed/active replay folders,
`dependency-cost-v17.json`, small instruction/allocator and memory records,
and `oracle-v17-{small,large}/`. Frozen candidate SHA-256 is
`e7b6149bbea19956d8adb8dcbdbef2a5857b0b30b806371ba33f8f8bbc66060c`;
before is v16 `56ecbd2857cec1234dd72015284e6c2100748d5f72221d17996d1a923171dc3d`.
The pinned large input and verified v133 oracle retain the hashes below.
Aggregate fuzz remains deferred at the user's request.

## September 29, 2026 fixed-size CFG workspaces

CFG node-to-block and label-to-target maps now allocate their known lengths
once rather than growing by repeated pushes. The node arena span includes
deleted IDs; the existing live continuation scan and exception/source facts
are unchanged. Two [bounded guards](../../../../../src/ir/cfg_fixed_workspace_wbtest.mbt)
check complete sentinel maps, exact fixed spans, dead nodes, independent
builder ownership, empty arenas and both operand modes. The first regression
fails before implementation with capacity **16 instead of 15**; both now pass.

Eight [native controls](../../../../../src/ir/cfg_fixed_workspace_perf_wbtest.mbt)
include fresh builder allocation and, in expanded mode, all source facts.
Inputs have 129/8193 scalar roots plus three labeled blocks:

| Builder | Grown → sized mean |
| --- | --- |
| 129, compact | 845.29 → 667.45ns |
| 8193, compact | 41.02 → 36.64µs |
| 129, expanded | 5.24 → 5.64µs (cost retained) |
| 8193, expanded | 302.02 → 287.62µs |

The 8193 compact selected standard deviation is 4.38µs; do not treat its mean
alone as a firm speedup. Three alternating v15→v16 compiler pairs give large
DAE2 **4558.923 → 4607.221ms (+1.06%)**, MAD 34.938/79.508ms, and
optimizing **7863.144 → 7735.328ms (−1.63%)**, MAD 158.383/78.134ms.
Small medians are 4.379 → 4.376ms / 11.689 → 11.605ms; tee medians
are 3.890 → 3.794ms / 105.939 → 105.024ms. Active joined-reader medians
are 20.799 → 21.204ms / 30.847 → 30.979ms; pure-tail medians are
13.799 → 13.671ms / 14.197 → 13.941ms. Preserve control costs and the
tee optimizing reference-drift retries. These do not establish compiler-wide
speedups; managed process visibility still does not establish quiet timing.

Dependency-window incoming allocator requests/frees each fall by **63,326**:
requests 40,796,729 → 40,733,403; frees 116,242,976 → 116,179,650.
Instructions fall **20,310,625,985 → 20,241,185,629 (0.34%)**.
Small command instructions fall 80,556,565 → 80,489,707 /
172,271,280 → 172,212,041, with 78 fewer allocator requests/frees per command.
Retain the simpler fixed-span construction for growth/work reduction without
claiming an RSS benefit. Allocator calls are not allocation bytes or live objects.

Info/fmt, all **12,938 default wasm-gc tests**, native debug, native CLI build,
eight controls, exact before/after/traced bytes and independent validation
pass. The 126-module / 1,029-observation replay and both seven-module /
28-observation active replays match original and verified v133. No API diff.
A queued v16 oracle sweep is rejected by the source-freshness guard after the
next prototype advances the worktree; retain that failed attempt, rather than
claiming a current-source sweep. The accepted v15 oracle below remains its
own historical cohort; renew against the next frozen current-source candidate.

Local `.tmp/dae2-lean-20260929/` evidence uses `v16`, including its source
manifest, `validation-v16.json`, bench/paired logs, fixed runtime and active
replays, `small-instructions-v16/` and `dependency-cost-v16.json`. Frozen
candidate SHA-256 is `56ecbd2857cec1234dd72015284e6c2100748d5f72221d17996d1a923171dc3d`;
before is v15 `7c48e6c9c62c2d3ad5278008cb05f42f73813094d5195519914466ed68b9493e`.
The large input and verified v133 oracle retain the hashes below. Fuzz is deferred.

## September 29, 2026 packed CFG segment storage

Private CFG segment metadata now occupies three consecutive integers per row
instead of one heap record per segment. A value record decodes rows only when
all fields are needed; the next-block and entry queries read just the block ID.
Public CFG blocks, root mappings, source ordering and segmentation decisions
are unchanged. The primitive backing array also avoids the previously rejected
native debug compiler limitation for arrays of custom value records.

The [three bounded guards](../../../../../src/ir/cfg_segment_storage_wbtest.mbt)
cover empty/growing storage, exact ordered fields and complete block/root
mappings against a frozen boxed reference in both operand modes. The initial
arena/API tests fail to compile before the implementation because the private
API is absent; this is not a preexisting semantic failure. The structural
comparison passes before and after. Eight [native controls](../../../../../src/ir/cfg_segment_storage_perf_wbtest.mbt)
include growth/consumption or fresh builder/source-fact/segment construction:

| Control | Boxed → packed mean |
| --- | --- |
| 128 metadata rows | 1.14µs → 488.32ns |
| 1024 metadata rows | 8.74 → 3.12µs |
| 64 segments, region construction | 48.30 → 47.11µs |
| 512 segments, region construction | 389.75 → 374.13µs |

Three alternating v13→v15 pairs give near-flat compiler timings: large DAE2
**4510.768 → 4542.607ms (+0.71%)**, MAD 25.722/20.813ms; optimizing
**7585.983 → 7544.887ms (−0.54%)**, MAD 11.476/12.469ms. Small medians
are 4.264 → 4.278ms / 11.470 → 11.418ms; tee medians are
3.866 → 3.864ms / 106.370 → 105.713ms. Active joined-reader medians
are 20.772 → 21.071ms / 31.773 → 31.361ms; pure-tail medians are
14.080 → 14.276ms / 13.786 → 14.121ms. Preserve those control costs and
the pure-tail reference-drift retry; no full-pass speedup is established.
Managed process visibility does not establish quiet-host timing.

The reason to retain this slice is measured heap churn: dependency-only
incoming `mi_malloc` calls fall **41,287,576 → 40,796,729 (490,847 fewer,
1.19%)** and `mi_free` calls fall by the same count. Instructions fall
20,329,087,979 → 20,310,625,985 (0.09%). Small whole-command allocator
requests/frees fall by 248 in each pass; instructions change
80,558,748 → 80,550,362 / 172,281,532 → 172,289,872. These scopes count
calls, not allocation bytes or net live objects. Three alternating untraced
large RSS samples give plain medians 272,216 → 253,328 KiB (ranges
252,140–273,244 / 251,280–273,772) and optimizing 292,024 → 299,264 KiB
(ranges 289,788–313,424 / 292,144–300,008). Preserve the latter cost;
overlapping ranges do not prove a memory gain or regression.

Info/fmt, all **12,936 default wasm-gc tests**, native debug guards, release CLI
build and eight controls pass. The frozen binaries preserve every measured
output byte and pass independent validation, the 126-module / 1,029-observation
replay and both seven-module / 28-observation active replays against original
and verified v133. No public interface changes.

Fresh verified-v133 pass-local medians (one warmup, three samples) remain gaps:
small DAE2 4.653 / 1.02914ms (**4.52×**), optimizing 13.213 / 3.20605ms
(**4.12×**); large DAE2 4507.166 / 523.992ms (**8.60×**), optimizing
8534.009 / 1764.800ms (**4.84×**). MADs are 0.119/0.01865ms,
0.459/0.01736ms, 17.027/1.136ms and 52.358/5.520ms respectively.
These are a new oracle cohort, not a causal ratio improvement over v13.
Large canonical sizes remain 6,132,389 / 6,232,586 bytes for plain DAE2 and
5,995,920 / 5,573,450 for optimizing; the **422,470-byte optimizing parity
gap remains open**, and smaller plain output alone is not a proven win.

Local evidence under `.tmp/dae2-lean-20260929/` uses `v15`, including the
source manifest, validation/bench logs, `pairs-v15-*`, active replay folders,
`dependency-cost-v15.json`, `small-instructions-v15/`, `memory-v15/` and
`oracle-v15-{small,large}/`. Frozen candidate SHA-256 is
`7c48e6c9c62c2d3ad5278008cb05f42f73813094d5195519914466ed68b9493e`;
before is accepted v13 `a367397e0045ee3db4cc3711135edab4b1449cca2647cb0f202f684fc14360ab`.
The oracle is verified `wasm-opt version 133 (version_133)`, SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`;
the pinned large input remains `98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
Long aggregate fuzz remains deferred at the user's request.

## September 29, 2026 rejected predecessor-row reuse

Two single-predecessor query trials are removed from production. The first
borrows a completed predecessor's immutable source row when it has no write
to the queried local. The revised version also resolves a sole preceding write
directly and avoids processing its first edge twice on the fallback path.
Both preserve exact source order, overwrite boundaries, exceptional policy,
entry-reaching loops and closed cycles. No retained cache is added.

The [candidate guards](../../../../../src/ir/local_graph_predecessor_cache_wbtest.mbt)
retain the frozen v13 reference and the rejected revised algorithm in white-box
code. Sharing and known-write workspace regressions fail before their respective
implementations; the boundary guard compares both locals and exceptional
policies. The [eight native controls](../../../../../src/ir/local_graph_predecessor_cache_perf_wbtest.mbt)
include cold cache/index/scratch allocation, query each block once and exclude
CFG/fact construction equally. The revised installed candidate measures:

| Query chain | Original → candidate |
| --- | --- |
| 64 read-only blocks | 10.43 → 3.90µs |
| 512 read-only blocks | 83.53 → 29.91µs |
| 64 overwriting blocks | 5.09 → 4.49µs |
| 512 overwriting blocks | 39.87 → 34.09µs |

The first trial's overwrite controls regress 4.90 → 5.82µs / 37.87 → 44.79µs;
the revision removes that helper cost, but neither trial improves the compiler
pipelines. Three alternating v13→v14b pairs measure large DAE2 **4248.864 →
4351.417ms (+2.41%)**, MAD 0.004/18.881ms, and optimizing **7296.766 →
7425.941ms (+1.77%)**, MAD 8.655/67.920ms. The first trial also records
large costs of +1.61%/+0.78%. Preserve those timing observations without
claiming every difference is causal: dependency-only instructions fall only
20,329,087,979 → 20,299,338,150 (−0.15%), and counted allocator requests/frees
fall by only 343 in that window. Active joined-reader and pure-tail pipelines
are near flat for the revision; helper wins do not establish a full-pass win.

Small revised medians are 4.968 → 4.485ms / 11.750 → 11.806ms; tee medians
are 3.706 → 3.728ms / 104.978 → 104.549ms. Small instructions fall
80,559,242 → 80,546,335 / 172,282,363 → 172,264,765, with two fewer allocator
requests/frees in each command. Reference-drift retries and the identical-binary
calibration limit small timing claims. Managed process visibility still does
not establish quiet-host timing. Counts are incoming allocator calls, not
allocated bytes, net live objects or RSS.

Installed v14/v14b prototypes pass 12,932/12,933 default tests, info/fmt,
native build, eight controls and the 126-module / 1,029-observation replay.
Each also passes the two seven-module / 28-observation active replays against
original and verified v133. All measured before/after bytes, traced/untraced
outputs and independent validation match. The production query is restored
exactly to v13; candidate implementations remain confined to dedicated tests.
Rejected binary SHA-256 values are
`092a57cd4f5bcc2870451d4649b5599a7fdfa37fcac2d2d083af0cec48e8c05b`
and `b52ea87e0602f61285f21b21a0f2928a8b8806e227c8001efbf8f94a1b0b3dd1`.
Local evidence under `.tmp/dae2-lean-20260929/` uses `v14`, `v14b`,
`rejected-v14/`, `rejected-v14b/` and `dependency-cost-v14b.json`.
Current production oracle evidence remains the accepted v13 sweep below.
Fuzz remains deferred.

After restoring production, info/fmt, all 12,933 default tests, native build
and the eight candidate-only controls pass. The rebuilt CLI is byte-identical
to v13, so its accepted oracle and runtime evidence still describe production.
Renewed control means are retained in `v14-controls-bench.log`; they do not
alter the installed-prototype pipeline results above.

Direct allocation attribution identifies larger targets: v13 dependency
analysis records 4,927,673 calls from CFG region segmentation to `mi_malloc`,
3,092,437 from preceding-dependency queries, and 1,914,225 from block creation.
The initially recorded “proposal-feature array” interpretation is superseded:
the 5,982,618 calls reach an int-sized generic allocation specialization named
for `ProposalFeature`, but 5,980,331 originate in `Array[Int]` reallocation.
The specialization name does not identify proposal metadata construction.
Upstream growth edges include 979,607 from CFG segmentation, 830,456 from
operand collection variants, and 472,703 from reverse entry-source queries.
These are call edges with potentially folded generic implementations and
wrapper layers, not independent allocation totals. Inspect buffer lifetimes
before adding another cache. Evidence is `allocation-callers-v13.json` and
`array-growth-callers-v13.json`.

## September 29, 2026 pure-subtree dependency pruning

The shared preceding-value collector and indexed minimum query stop at a pure
subtree. Effect masks already include every live child, while these dependency
queries follow subsets of those operands. A zero subtree mask therefore cannot
contain a value with nonzero effects that needs carrying across a statement.
The collector leaves its scratch arrays untouched; the minimum query caches
only the root's no-dependency sentinel. Calls, local-state reads, loads and
numeric traps still follow the existing traversal. No retained cache or new
allocation is introduced.

Two [work-invariant regressions](../../../../../src/ir/hot_source_order_pure_wbtest.mbt)
fail before the change: the old minimum query fills a pure leaf's cache slot,
and collection records all 33 nodes in its touched workspace. Both now pass,
with an additional effect/trap guard matching the original query reference.
Eight [native controls](../../../../../src/ir/hot_source_order_pure_perf_wbtest.mbt)
exclude fact construction and compare balanced 64/512-leaf trees. Collection
improves 2.45µs → 19.67ns / 19.74µs → 19.49ns; minimum queries, including
fresh cache-vector initialization, improve 2.40µs → 51.96ns /
19.37µs → 254.87ns. These are helper controls, not compiler-wide speedups.

Three alternating v11→v13 pairs, with CPU 6 affinity and the independent
precompute-reference bracket, measure the following pipeline medians:

| Input | DAE2 before → after | DAE2-O before → after |
| --- | --- | --- |
| Large compiler | 4683.480 → 4615.983ms (−1.44%) | 8061.194 → 8024.433ms (−0.46%) |
| Small compiler | 4.418 → 4.346ms (−1.63%) | 11.536 → 11.448ms (−0.76%) |
| Active tee | 4.055 → 4.161ms (+2.61%) | 106.419 → 107.161ms (+0.70%) |

Large before/after MADs are 21.715/41.907ms and 57.195/27.438ms. Optimizing
compiler timing is near flat; small/control changes remain limited by the
identical-binary calibration. Managed-sandbox process visibility limits foreign
CPU observation, so empty observations do not establish a quiet host.
Dependency-only Callgrind instructions fall 20,486,620,723 → 20,329,087,979
(−0.77%). Small whole-command instructions fall 80,724,625 → 80,565,783 /
172,455,037 → 172,284,529; allocator request/free calls fall by only 7/9.
Do not interpret those request counts as allocated bytes or peak RSS.

The fresh verified-v133 sweep uses one warmup and three samples:

| Input / pass | Starshine | Binaryen 133 | Ratio |
| --- | ---: | ---: | ---: |
| Small DAE2 | 4.749ms | 0.999ms | 4.75× |
| Small DAE2-O | 14.283ms | 3.295ms | 4.33× |
| Large DAE2 | 4297.268ms | 451.817ms | 9.51× |
| Large DAE2-O | 7739.332ms | 1684.540ms | 4.59× |

Large Starshine/Binaryen MADs are 37.034/6.357ms and 42.177/0.870ms.
These separate cohorts are not a paired v11→v13 oracle-ratio improvement.
Canonical sizes remain 6,132,389/6,232,586 and 5,995,920/5,573,450 bytes;
the optimizing 422,470-byte gap and plain output-shape classification stay open.
The oracle/input hashes are the same verified v133 hashes recorded below;
new oracle evidence is `oracle-v13-{small,large}/`.

Info, fmt, all 12,929 default tests, native CLI build and all eight controls
pass. The fixed replay validates 126 modules with 1,029 matching
original/v133 observations; all measured before/after bytes and traced/untraced
outputs match. Candidate v13 SHA-256 is
`a367397e0045ee3db4cc3711135edab4b1449cca2647cb0f202f684fc14360ab`.
Evidence under `.tmp/dae2-lean-20260929/` uses `pairs-v13-*`,
`callgrind-v13-dependencies`, `small-instructions-v13/`,
`allocator-calls-v13.json`, `pure-red.log` and `validation-v13.json`.
The cumulative section below preserves the earlier directly measured checkpoint;
do not multiply its gains by this cohort's percentages. Fuzz remains deferred.

## September 29, 2026 active pure-tail pipeline benchmark

The [permanent full-pass workload](../../../../../src/passes_perf_long/dae2_pure_tail_perf_test.mbt)
has a private helper with one removable argument, a conditional local write,
32 calls that increment an exported global, and a balanced dropped numeric
tail. Fewer than 64 statement roots exercise direct future-dependency scanning:
previously every preceding call rediscovered the pure tail's operands. The
conditional reaching definitions and actual signature change keep DAE2 analysis
and rewriting active. Balanced trees avoid conflating that repeated work with
deep-stack stress.

The bounded eight-leaf test validates both pass outputs, checks argument removal
and confirms input ownership. All four dedicated native benchmarks pass at
512/8192 leaves: DAE2 means 961.23µs/13.59ms, optimizing means 1.01ms/13.57ms.
Setup validates the output and requires argument removal outside timing; these
standalone means are not before/after improvement percentages. Info/fmt and
the focused default guard pass after the 12,929-test full run recorded above.

A matching 8192-leaf CLI fixture, one warmup and three alternating v11/v13
pairs with the independent reference bracket, measures DAE2 **24.764 →
13.431ms (−45.76%)** and DAE2-O **25.466 → 13.921ms (−45.33%)**. Before/after
MADs are 0.038/0.060ms and 0.091/0.002ms. Before/after bytes, traced/untraced
outputs and validation match. Original, both frozen Starshine binaries and
verified v133 return identical results and exactly 32 writes for four inputs:
seven modules and 28 runtime observations. This scaling gain does not establish
a compiler-artifact speedup; the compiler results remain separately recorded.

Local evidence is `.tmp/dae2-lean-20260929/pure-tail-v13/`,
`pure-tail-{controls,bench,test}.log` and `pure-tail.wat`. Input SHA-256 is
`1ce3aa502916d19fec1f9740965806afa2fb4e633acf9e8105d0eda5a69966f0`.
Both frozen binary and verified oracle hashes are recorded in the surrounding
checkpoints. Production code is unchanged by this benchmark addition; no
aggregate fuzz runs.

## September 29, 2026 cumulative lean checkpoint

A fresh matched comparison uses v1 (the reverse-flow repair) as its baseline,
not the earlier correctness-broken V18 or the roughly 39-second dense solver.
Three alternating pairs, pinned to CPU 6 with an independent frozen precompute
reference, give the following pipeline medians:

| Input | DAE2 before → v11 | DAE2-O before → v11 |
| --- | --- | --- |
| Large compiler | 5403.347 → 4553.645ms (−15.73%) | 8689.363 → 8006.475ms (−7.86%) |
| Small compiler | 4.800 → 4.654ms (−3.04%) | 12.057 → 11.639ms (−3.47%) |
| Active tee | 3.885 → 3.930ms (+1.16%) | 111.039 → 106.728ms (−3.88%) |

Large before/after MADs are 0.851/183.876ms and 165.795/184.159ms.
All measured bytes match, traced/untraced outputs agree, and outputs validate.
Reference-drift retries are retained. Eleven of twelve accepted large runs
record foreign Chrome/kernel CPU activity, so this is not a quiet-host signoff;
the small differences also remain limited by the identical-binary calibration.
These cumulative figures are measured directly, not products of percentages from separate optimization cohorts.

A separate fresh **verified Binaryen 133** sweep, one warmup and three samples,
uses the same frozen v11 binary. Its pass-local pipeline medians are:

| Input / pass | Starshine | Binaryen 133 | Ratio |
| --- | ---: | ---: | ---: |
| Small DAE2 | 4.827ms | 1.036ms | 4.66× |
| Small DAE2-O | 14.155ms | 3.315ms | 4.27× |
| Large DAE2 | 4671.195ms | 458.548ms | 10.19× |
| Large DAE2-O | 8281.950ms | 1802.110ms | 4.60× |

Starshine/Binaryen large MADs are 38.016/5.873ms and 26.839/67.390ms.
The compiler performance target remains open. Canonical large output sizes are
6,132,389/6,232,586 bytes for DAE2 and 5,995,920/5,573,450 bytes for DAE2-O.
The optimizing size gap is 422,470 bytes; the smaller plain output alone does
not prove a Starshine win or close the output-shape parity investigation.
No output-shape difference is newly accepted by these performance measurements.

Local evidence is `.tmp/dae2-lean-20260929/cumulative-v11-{small,large,tee}/`
and `oracle-v11-{small,large}/`. V1 SHA-256 is
`a612ebefc2f7d54085530d22d88d2565861d26e4753b64e9660b282999a18fc3`;
v11 SHA-256 is
`c43278a2cf8ced917ccdcc21d3d2cfd216c75d182ac336126fb6b9e10482248b`.
The oracle is `wasm-opt version 133 (version_133)`, SHA-256
`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.
The large input SHA-256 remains
`98189860f95b4eb8464794eb9fab5f9fd8d16942c63a6e31ed9175e7e791cbbd`.
The dependency-only Callgrind profile falls from **26,495,753,239 instructions
at v2 to 20,486,620,723 at v11 (−22.68%)**, with byte-identical validated output.
This baseline already includes the direct tuple-opcode improvement; it differs
from the v1 timing baseline above. It counts the analysis dependency function,
not the whole compiler command. Remaining nonrecursive inclusive costs are
CFG construction 62.12% and LocalGraph 23.94%; source-order dependency
queries account for 19.04% inside CFG construction. These nested percentages
must not be added. Largest self costs include HOT node reads 13.35%, reverse
entry queries 7.06%, object destruction 6.61% and liveness reads 3.96%.
The source-order query total is essentially unchanged from v2, making repeated
region scans a useful next target. Profiles are `profile-v11-{self,inclusive}.txt`
and `callgrind-v11-dependencies`; v2 retains the earlier equivalent scope.

Whole-command small-input Callgrind controls compare v1/v11. DAE2 instructions
fall 85,690,018 → 80,721,030 (−5.80%); optimizing instructions fall
178,863,157 → 172,466,407 (−3.58%). Counted calls into `mi_malloc` fall
325,973 → 312,090 and 512,453 → 492,159 (13,883 and 20,294 fewer requests).
The corresponding frees fall by the same counts. These are native allocator
call counts, not allocated bytes or a claim about peak memory.

Three alternating large-input RSS samples overlap: DAE2 median 282,308 →
281,308 KiB, ranges 255,884–283,288 / 259,160–281,808; DAE2-O median
292,356 → 302,336 KiB, ranges 292,024–314,784 / 291,804–304,696. Retain the
higher optimizing median without claiming a proven memory regression or win.
The initial RSS launcher found no `/usr/bin/time`; its setup error is preserved,
and completed samples use a fresh Python child wrapper's Linux `ru_maxrss`.
Evidence is `memory-v11/`, `small-instructions-v11/` and `allocator-calls-v11.json`.
All corresponding outputs validate and retain exact before/after bytes.

This is bounded performance/correctness evidence; aggregate fuzz remains
explicitly deferred until the performance trials finish.

## September 29, 2026 rejected smaller-region index threshold

A 64 → 32 root-index threshold trial is removed. The existing index algorithm
is valid on small regions, but the measured compiler inputs show no pipeline
benefit. Three alternating pairs measure large DAE2/O 4349.487 → 4404.810ms
(+1.27%) / 7460.982 → 7517.513ms (+0.76%). Small medians are 4.241 →
4.870ms (+14.83%) / 11.727 → 11.892ms (+1.41%); active tee medians are
3.924 → 3.928ms / 108.375 → 107.433ms. Preserve these timing observations
without claiming all differences are causal: small instruction and allocator
counts are essentially identical, and prior calibration demonstrates timing
variation. Small instructions are 80,724,150 → 80,722,900 /
172,465,174 → 172,463,564; allocator request counts are unchanged.

The [suffix-query controls](../../../../../src/ir/hot_source_order_threshold_perf_wbtest.mbt)
include facts/index construction and compare direct/indexed queries at 4/16/32
roots. Their repeated-barrier pattern is a kernel workload. The additional
[region controls](../../../../../src/ir/hot_source_order_region_perf_wbtest.mbt)
query each actual effectful root once, with the real changing cutoff and suffix.
At 32 roots sparse regions improve 13.25 → 7.58µs, but dense regions cost
16.74 → 17.64µs (+5.38%). At 16 roots they measure 4.38 → 3.51µs and
5.72 → 6.12µs. These synthetic tradeoffs do not establish a compiler win.

The [bounded index guards](../../../../../src/ir/hot_source_order_threshold_wbtest.mbt)
retain equality across every suffix for sparse/dense 4/16/32-root regions, and
check the 32-root candidate set directly. The prototype's threshold-admission
regression was red first; after rejection its admission assertion becomes a
direct index-algorithm guard. The shipping threshold remains 64. No existing
feature or supported index algorithm is removed.

While the prototype was installed, info/fmt, 12,926 default tests, native build,
12 kernel controls, eight actual-region controls, and the 126-module /
1,029-observation original/v133 replay pass with identical output bytes.
The interrupted paired run was resumed by checking binary/input/reference
hashes and completed sample artifacts, retaining partial evidence and avoiding
re-measurement of completed pairs. Later managed-sandbox process visibility
limits foreign-CPU detection; an empty observation does not prove a quiet host.
Local evidence uses `v12`, `region-*`, `threshold-*` and `rejected-v12/` under
`.tmp/dae2-lean-20260929/`. Rejected candidate SHA-256 is
`6c698eb8a86eb8fa250a0562944ad547fe3c7f8e547fa879f0c255de6adc2798`.
Its completed v133 sweep remains saved under `oracle-v12-{small,large}/`;
the accepted production oracle at that checkpoint was v11, now superseded
by the v13 sweep above.
Fuzz remains deferred.

## September 29, 2026 fuse source-order operand walks

Source-order facts now compute maximum value order and first external-effect
order in one operand traversal. The two existing result arrays retain their
sentinels and discovery order; no cache is added. The standalone first-effect
query remains separate for consumers that need only that summary. The old
value-only traversal survives only as a test reference.

The [bounded guard](../../../../../src/ir/hot_source_order_fused_wbtest.mbt)
compares both arrays before and after on calls, stacked writes, indexed control,
loads and deleted nodes. Six [native controls](../../../../../src/ir/hot_source_order_fused_perf_wbtest.mbt)
compare full fact construction with the original two-walk reference. A repeated
low-variance cohort measures 8/64/128 roots at 19.58 → 15.79µs /
153.10 → 124.40µs / 340.18 → 246.32µs. The first noisy timing cohort is
preserved, but does not support the helper claim.

Three alternating pairs measure large DAE2 **4779.348 → 4589.724ms (−3.97%)**,
MAD 61.700/67.940ms, and DAE2-O **7924.408 → 7826.148ms (−1.24%)**,
MAD 19.823/44.409ms. Ten of twelve accepted large runs record foreign CPU
activity; preserve that limit alongside the helper and instruction evidence.
Small medians are 4.736 → 4.541ms /
12.252 → 12.391ms; active tee medians are 3.778 → 3.888ms /
106.876 → 105.483ms. Small changes remain subject to the calibration limits;
these results do not establish Binaryen competitiveness.

Info, fmt, 12,923 default tests, native build and all six controls pass. The
126-module / 1,029-observation original/v133 replay and before/after artifact
bytes match. Candidate SHA-256 is
`c43278a2cf8ced917ccdcc21d3d2cfd216c75d182ac336126fb6b9e10482248b`.
Local evidence under `.tmp/dae2-lean-20260929/` uses `v11`; the repeated
controls are in `controls-order-repeat.log`. No aggregate fuzz ran.

## September 29, 2026 borrow completed reverse-query rows

Reverse-flow query cache entries are immutable after collection. Cache insertion
and lookup now share the completed source row instead of copying it. Unique
reverse recording borrows the row; iterative recording keeps its existing
copy-on-write merge. Public owned queries still return independent arrays.
The [ownership regression](../../../../../src/ir/local_graph_source_cache_wbtest.mbt)
first failed because the returned row differed physically from the cache; it
now checks both cache sharing and isolation of a later merge.

The [full graph controls](../../../../../src/ir/local_graph_source_cache_perf_wbtest.mbt)
measure repeated entry-source reads in one block. At 128/512/2048 reads they
improve 13.06 → 10.94µs / 49.33 → 41.23µs / 194.82 → 162.59µs (about 16.5%).
Paired large DAE2 is flat at 4736.866 → 4732.602ms, MAD 16.009/13.716ms;
DAE2-O measures 7938.411 → 7812.697ms (−1.58%), MAD 92.021/1.483ms.
Small medians are 4.362 → 4.422ms / 11.594 → 11.633ms; active tee medians
are 4.582 → 3.963ms / 106.764 → 109.645ms. Preserve the +2.70% optimizing
tee observation and the timing-calibration limits rather than claiming a win
on every input.

Info, fmt, 12,923 default tests, native build, three cache benchmarks and six
next-stage order controls pass. The 126-module / 1,029-observation original/v133
replay and artifact byte checks pass. Candidate SHA-256 is
`0ca046728397956793707c6e2de24d672bc4ea3bd1ba164c832e8f15a6819fe3`;
local evidence uses `v10` and `cache-borrow-red.log`. The suite includes the
fused-order guard before that optimization. No aggregate fuzz ran.

## September 29, 2026 append unique reverse-flow readers

Reverse flow records each get once with a deduplicated source row. Its recorder
now assigns that row directly and appends each write influence without searching
all earlier readers. Dense/sparse iterative recording retains its merge and
deduplication logic. This removes quadratic reader-list searches and the unused
copy-on-write recorder on the reverse path, without adding an index or cache.

The [bounded guards](../../../../../src/ir/local_graph_unique_reads_wbtest.mbt)
pass before and after for ordered readers, branch-joined writes and shared-read
fallback. [Full graph controls](../../../../../src/ir/local_graph_unique_reads_perf_wbtest.mbt)
at 128/512/2048 readers improve 11.50 → 9.57µs / 68.77 → 32.84µs /
611.87 → 128.49µs. The high-count case is 4.76× faster and scaling is now
approximately linear. This is a graph-construction gain, not a compiler-wide
speedup claim.

An additional active DAE2 workload joins two writes (7 or 9) and consumes the
local 8,192 times in a balanced addition tree. Its private helper also has an
unused argument, which DAE2 removes. The v7/v9 paired full pipelines improve
**51.781 → 22.058ms (−57.40%)** and **64.182 → 32.221ms (−49.80%)** for
DAE2/O, with MADs 0.094/0.035ms and 0.551/0.467ms. Seven original/before/after/
v133 modules validate and return identical values in 28 observations; before/
after bytes match. This is a deliberate scalability workload, separate from the
compiler artifact below. The permanent [active pipeline benchmarks](../../../../../src/passes_perf_long/dae2_joined_readers_perf_test.mbt)
cover 512/8192 readers for both passes, with a bounded default guard proving
argument removal and input ownership. All four native controls and that guard
pass. Final v11 benchmark means are 1.33/21.28ms (DAE2) and 2.05/31.18ms
(DAE2-O); these are standalone controls, not matched improvement estimates.
The subsequent cache-borrowing change is flat on the active 8192-reader input:
21.871 → 22.012ms / 31.555 → 31.495ms, with seven validated modules and 28
matching observations. Local `joined-readers-v9/`, `joined-readers-v10/`, `joined-readers.wat` and
`joined-readers.py` retain it; input SHA-256 is
`60935ce550d11451d4dce59ff319d6ed58633b645496ecf9eac3fdcc62079f86`.

Independent-reference paired medians retain a large DAE2 cost:
4623.318 → 4697.854ms (+1.61%; MAD 78.203/38.001ms). DAE2-O is nearly
flat at 7955.797 → 7918.754ms, MAD 21.181/66.549ms. Small medians are
4.379 → 4.388ms / 11.641 → 11.566ms; active tee medians are
3.819 → 3.788ms / 107.230 → 107.812ms. Preserve the observed costs; the
asymptotic improvement does not close the compiler-artifact gap.

Seven-pair identical-binary controls with the separate reference measure small
DAE2/O variation of −1.08%/−2.61% and tee variation of −0.84%/−0.10%.
The new bracket removes asymmetric reference invocation, but timing noise
remains. These controls limit claims from small differences in later trials.

Info, fmt, 12,921 tests, native build, three reader benchmarks and three next-stage
cache controls pass. The 126-module / 1,029-observation original/v133 replay and
all output byte checks pass. Candidate SHA-256 is
`61a7017554e3ba466f22538b40c7fa90f9629c6c2e3e70ea7239f9b04efb2484`;
local evidence uses `v9` and `calibration-independent-{small,tee}/`. A corrected
runner-path argument error is preserved in `evidence-v9-harness-error.log`;
completed runtime evidence was hash-checked and reused before the successful
paired run. Fuzz remains deferred.

## September 29, 2026 rejected native getter annotation

Adding `#inline` to `hot_node_get` produced an **identical native binary** to
v7: SHA-256 `eeadc7c3e87fdb0a56b31aaf27721f92e97a718cea28ccf5ad6b8ac6ecf20763`,
14,352,728 bytes. The annotation was removed. All 12,921 tests, native build,
12 existing field-query controls and three next-stage reader controls pass;
no native performance benefit can be attributed to this source annotation.

The identical-binary v8 comparison is also a timing calibration: small DAE2/O
appeared +9.85%/+2.50%, large +0.75%/+0.58%, and active tee −0.40%/−2.97%.
These are measurement variation, not code regressions or wins. Preserve earlier
small/control timings as observations, but do not infer a causal improvement
from similarly small differences. Native helper scaling, fixed output/runtime
checks and large gains have separate evidence; sub-percent artifact changes
were already classified as near flat.

The earlier bracket ran `precompute` through the before binary. Subsequent
trials use a separate frozen reference executable for both brackets so neither
candidate receives that asymmetric code-cache warmup. An independent-reference
identical-binary calibration is recorded with subsequent results; this setup
change alone is not proof that all timing noise is eliminated. Local evidence
uses `v8`, `machine-v8.json` and `affinity-pairs-independent.py`. Fuzz remains
deferred.

## September 29, 2026 bounded SSA source summaries

LocalGraph's SSA flag needs only one distinct reaching source and agreement
with every write. It now records unseen/singleton/multiple identities in two
flat local-indexed arrays during one arena scan. This replaces growing unions
with linear membership searches, one heap array per local and a second arena
scan. Finalized nonnegative source IDs remain distinct from the private summary
sentinels; unused writes still invalidate singleton reads when identities differ.

The [bounded guards](../../../../../src/ir/local_graph_ssa_summary_wbtest.mbt)
cover entry values, singleton/multiple writes and unread conflicting writes;
they pass before and after. The [native controls](../../../../../src/ir/local_graph_ssa_summary_perf_wbtest.mbt)
compare the original union with the summary: 16/128/512 writes take
0.643 → 0.266µs / 6.22 → 1.68µs / 48.72 → 6.47µs. This removes the
quadratic union on that workload without claiming a large compiler gain.

Paired large DAE2/O medians are effectively flat at
4553.674 → 4562.817ms / 7615.647 → 7540.545ms; respective MADs are
33.512/51.085ms and 157.977/39.231ms. Small medians are
4.723 → 4.334ms / 11.619 → 11.747ms; active tee medians are
3.791 → 3.985ms (+5.12%) / 106.828 → 106.876ms. Preserve these noisy control
costs. Separate whole-command Callgrind counts on the small input fall
81,849,693 → 81,523,967 / 173,674,540 → 173,343,909 instructions
(−0.40%/−0.19%); active tee counts are essentially unchanged
102,629,320 → 102,633,080 / 2,049,641,510 → 2,049,674,565. Instruction
counts do not establish wall-time improvements or erase the observed costs.

Info, fmt, 12,919 default tests, native build, six controls and the fixed
126-module / 1,029-observation original/v133 replay pass with identical output
bytes. Local evidence has the `v7` suffix, plus `small-instructions-v7/` and
`tee-instructions-v7/`; candidate SHA-256 is
`eeadc7c3e87fdb0a56b31aaf27721f92e97a718cea28ccf5ad6b8ac6ecf20763`.
No aggregate fuzz ran.

## September 29, 2026 reuse CFG region-root snapshots

Expanded CFG construction already snapshots each region's roots for source
ordering. It now reuses that array when visiting roots and registering operand
blocks, removing repeated region/label/type lookups. Root-only construction
registers its already-known roots directly. This adds no cache or allocation.
The [bounded guard](../../../../../src/ir/cfg_root_snapshot_wbtest.mbt) checks
indexed inputs and exact body slots in both modes; it passes before and after.
The [native controls](../../../../../src/ir/cfg_root_snapshot_perf_wbtest.mbt)
measure full CFG construction: 8/64 expanded roots improve 82.75 → 72.05µs /
510.40 → 444.74µs, and 64 root-only roots 148.16 → 141.56µs.

Three alternating large-input pairs measure DAE2 **4663.759 → 4476.399ms
(−4.02%)**, MAD 5.624/7.962ms; DAE2-O is nearly flat at
7496.749 → 7452.244ms (−0.59%), MAD 72.745/17.440ms. Small medians are
4.507 → 4.402ms / 11.804 → 12.231ms; active tee medians are
3.743 → 3.813ms / 106.230 → 107.506ms. Small/control costs and rejected
reference-drift attempts remain recorded; this is chiefly a large DAE2 gain.
Do not combine absolute times from different cohorts as a matched comparison.

Info, fmt, 12,919 default tests, native build and three controls pass. The fixed
126-module / 1,029-observation original/v133 lane has zero behavioral or
before/after byte differences. Local evidence uses the `v6` suffix under
`.tmp/dae2-lean-20260929/`; candidate SHA-256 is
`c14847b66efd69ab8b8be8b7b20b1cb70ff37e270666b9c74ef0dc3506a339a1`.
The suite includes the next SSA trial's guards before its implementation.
Aggregate fuzz remains deferred.

## September 29, 2026 rejected source-order cache trials

Two cache prototypes are **not in production**. A lazy write-presence cache
avoided access-list materialization for read-only carried expressions. It reduced
the 128-deep one-direction control 250.33 → 22.27µs, but the reverse write/read
query still materialized the same trees: a bidirectional control remained
277.07 → 264.98µs. Its large DAE2/O medians were effectively flat
4607.042 → 4614.436ms / 7620.928 → 7566.612ms, with small/tee control costs.

A second prototype cached compact uniform-local identities and earliest-access /
latest-write orders, retaining the original mixed-local scan. It reduced the
bidirectional 128-deep control 279.23 → 26.78µs, but regressed paired small DAE2
4.421 → 4.672ms (+5.68%) and large DAE2 4600.324 → 4673.942ms (+1.60%).
Large DAE2-O was flat at 7659.031 → 7664.762ms; active tee medians were
3.797 → 3.784ms / 106.223 → 105.765ms. These synthetic wins do not justify
keeping the additional per-function cache and real-input costs. Both prototypes
were removed; the accepted production baseline remains v4 at this checkpoint.

The [read-only/dead-tail guards](../../../../../src/ir/hot_source_order_write_free_wbtest.mbt),
[bidirectional/order-bound guards](../../../../../src/ir/hot_source_order_uniform_wbtest.mbt)
and their [one-direction](../../../../../src/ir/hot_source_order_write_free_perf_wbtest.mbt)
/ [bidirectional](../../../../../src/ir/hot_source_order_uniform_perf_wbtest.mbt)
benchmarks remain useful controls. The selected benchmark path always measures
the current implementation; the reference retains the original scan. The
quadratic overlapping-access-list family remains open rather than being hidden
by a helper-only success claim.

The second prototype passed 12,918 default tests, native build and four controls;
both passed the 126-module / 1,029-observation fixed replay with unchanged bytes.
Local `.tmp/dae2-lean-20260929/` evidence uses `v5` and `v5b`; rejected v5b source
is preserved in `rejected-v5b/`. Binary hashes are
`2ad9d25559765dc54f191fb194ba807b8faa4f72d7b97f3996c2028bab13d912` and
`05a93a72a031a2996e3e273720945aeddf4c6d8c2335aeb6a944c67a29c1b5fe`.
This is experimental evidence, not accepted performance or aggregate signoff.

## September 29, 2026 reuse the write-local index

Reverse-flow construction now builds its required node-to-write-local vector
before queries and reuses it for short write scans, lazy block indexes and
transparent-chain admission. It retains the same vector in the finished graph;
there is no additional persistent index. This removes repeated complete HOT
node reads in predecessor queries. The
[bounded lookup guard](../../../../../src/ir/local_graph_write_index_wbtest.mbt)
passes before/after for reads, sets, tees, absent locals and prefix limits;
[native controls](../../../../../src/ir/local_graph_write_index_perf_wbtest.mbt)
compare the old scan and the indexed lookup on the same function. A 512-query
batch improves 6.31 → 3.70µs (−41.36%).

The enclosing effect is modest: three paired large medians are
4324.275 → 4293.496ms for DAE2 (−0.71%; MAD 3.134/13.836ms) and
7115.667 → 7094.366ms for DAE2-O (−0.30%; MAD 35.662/5.471ms).
Small medians are 4.261 → 4.151ms / 11.095 → 11.091ms; active tee medians
are 3.680 → 3.693ms / 103.460 → 102.506ms. These near-flat artifact controls
must not be presented as a major pipeline win. All bytes match; info, fmt,
12,914 default tests, native build, both controls and the fixed 126-module /
1,029-observation original/v133 lane pass. Candidate SHA-256 is
`df13c59e51ff5d011a90083dfd623f6a01d4e9aa473fb631bc1a4519702e5c04`;
local evidence has the `v4` suffix. The additional source-order tests present
in this validation are guards for the following trial, not yet its implementation.
No aggregate fuzz or new competitiveness claim is made.

## September 29, 2026 read-only predecessor chains

Reverse local-flow queries previously walked every intervening read-only block
again for each local. A linear prepass now resolves single-predecessor chains,
stopping at writes and joins. Closed read-only cycles retain one representative;
exceptional-edge selection follows the query policy. The
[bounded graph fixture](../../../../../src/ir/local_graph_transparent_wbtest.mbt)
compares sources with dense flow across chains, joins, reachable loops,
disconnected cycles and exception edges. Source sets pass before and after;
post-change assertions also check the compressed predecessor map.

The existing expanded-flow benchmarks now take 13.69/53.08/102.54µs at
32/128/256 reads, versus 25.92/279.86/1040µs in the earlier v1 cohort. These
helper cohorts differ; the current same-process dense controls are
66.56/867.01/3220µs. Scaling is now approximately linear on this fixture.
Three alternating artifact pairs give large DAE2 4558.704 → 4331.999ms
(−4.97%; MAD 2.407/14.058ms) and DAE2-O 7342.827 → 7083.803ms
(−3.53%; MAD 14.866/18.654ms). Small controls are 4.242 → 4.331ms and
11.376 → 11.057ms; active tee controls are 3.544 → 3.504ms and
104.067 → 106.056ms. Preserve the observed +2.10% small DAE2 and +1.91%
active optimizing costs; this does not establish a win for every workload.

All output bytes match. Full 12,911-test validation, native build, six native
benchmarks and the 126-module / 1,029-observation fixed replay lane pass.
Candidate SHA-256 is
`888b45565e826f0d7cabc51e8a7042fa889b29328302f51ebb6f8136b757e327`;
artifacts use `.tmp/dae2-lean-20260929/` and the `v3` suffix. Fuzz remains deferred.

A fresh dependency-only Callgrind profile of the preceding **v2** binary records
26,495,753,239 instructions with validated, byte-identical large output. Its
nonrecursive inclusive CFG and LocalGraph owners account for 56.38% and 32.81%;
self costs include HOT node reads 15.46%, reverse entry traversal 12.20%, indexed
last-write lookup 5.72%, and object destruction 5.44%. Recursive inclusive
attribution overlaps and must not be added. This is not a whole-command profile
or a timing comparison with v9. The next trials target repeated node decoding
in write lookup and source-order subtree scans; local `profile-v2-{self,inclusive}.txt`
and `callgrind-v2-dependencies` preserve the attribution.

## September 29, 2026 tuple preparation without opcode strings

Shared HOT lowering now tests `HotOp::TupleMake` directly and reads result
metadata only for tuple nodes. Previously it formatted every live opcode into
a temporary string merely to identify that one opcode. The
[bounded type/IR guard](../../../../../src/passes/tuple_prepare_opcode_wbtest.mbt)
passes before and after the change, preserving zero/scalar/multivalue handling,
node counts, type interning and valid HOT output. This is a performance change,
not a newly implemented semantic behavior.

[Native controls](../../../../../src/passes/tuple_prepare_opcode_perf_wbtest.mbt)
compare the original string scan with opcode matching, including fresh function
construction and active multivalue promotion each iteration. At 64/1024 roots,
means fall 31.45 → 6.15µs and 480.45 → 76.75µs; lowered IR and resulting type
sections match the reference. Full validation passes 12,910 default tests,
interface generation, formatting, native CLI build and all four benchmarks.
Frozen binary SHA-256 is
`cb4d1d0054ff4c54d08f95dd2bdc9a4c4c5987e05ac8fad626e1a1f92c1aa385`;
local artifacts use `.tmp/dae2-lean-20260929/` with the `v2` suffix.
Three alternating CPU-affined pairs after a warmup preserve all output bytes:
small DAE2/O medians 4.310 → 4.205ms / 11.295 → 10.921ms; large medians
4752.195 → 4567.170ms / 7575.284 → 7355.966ms (−3.89%/−2.90%). Large
MADs are 1.404/14.403ms and 25.654/17.601ms, respectively. Active tee DAE2
is flat (3.545 → 3.555ms), while DAE2-O improves 109.851 → 104.022ms
(−5.31%). The 126-module fixed runtime lane again validates 1,029 observations
with zero behavioral or byte differences. Rejected reference-drift warmup and
foreign CPU observations remain in local evidence; no aggregate fuzz ran.

## September 29, 2026 expanded-flow performance repair

Expanded operand CFGs now use the existing reverse reaching-definition solver.
Their nodes already represent evaluation order, so action extraction records
local reads/writes directly rather than recursively expanding operands again.
Root-only CFG admission and shared-expression fallback remain intact. The
[red-first regression](../../../../../src/ir/local_graph_expanded_reverse_wbtest.mbt)
first observed duplicate actions `[0,0,1,2,2]` instead of `[0,1,2]`; six bounded
fixtures compare source sets with the dense solver across stacked reads,
loop-carried writes, branches and indexed inputs. The
[native benchmark](../../../../../src/ir/local_graph_expanded_reverse_perf_wbtest.mbt)
compares both solvers at 32/128/256 reads and 128/512/1024 locals.

Three alternating, CPU-affined samples after one warmup give these pipeline
medians in milliseconds (identical before/after wasm bytes, validated outputs):

| Input | DAE2 before → after | DAE2-O before → after |
| --- | ---: | ---: |
| Small | 5.181 → 4.654 | 12.703 → 12.704 |
| Large compiler | 39136.021 → 5092.202 | 38973.233 → 7936.136 |
| Active tee | 3.723 → 3.801 | 106.362 → 106.250 |

Large reductions are 86.99%/79.64%; median absolute deviations are
30.347/73.633ms for DAE2 and 43.095/102.208ms for DAE2-O (before/after).
These repair the dense-flow regression introduced by the source-order
correctness fix: **they are not improvements of that magnitude over historical
V18's 4.17s/7.54s**, whose newly exposed semantic failures remain documented.
A traced large sample reduces dependency analysis 36317.052 → 2074.588ms;
rewrite/lower/validation costs remain. Native 128-read graph construction is
932.16 → 279.86µs, and 256-read construction 3.79 → 1.04ms. Residual scaling
and multi-second artifact costs remain active performance gaps.

`moon info`, `moon fmt`, all 12,909 default tests, native CLI build and six
native benchmarks pass. Eighteen fixed runtime fixtures validate 126 modules
and 1,029 result/effect/trap observations against original inputs and verified
Binaryen v133, with zero mismatches or before/after output changes. This bounded
lane is not aggregate fuzz signoff. Baseline binary SHA-256 is
`5c03b6a93d19e8c90403b7b691f87ebfc94c42eb670052506bfa7cad50a2fbf8`;
candidate is `a612ebefc2f7d54085530d22d88d2565861d26e4753b64e9660b282999a18fc3`.
Local reproducibility artifacts are `.tmp/dae2-lean-20260929/`: source manifests,
`validation-v1.json`, `runtime-v1/result.json`, and `pairs-v1-{small,large,tee}/`.
The pair runner retains rejected reference-drift attempts and foreign CPU
observations; no new v133 timing ratio or memory improvement is claimed.
Fuzz renewal is explicitly deferred until performance work is complete.

## September 29, 2026 branchless scalar blocks and source-order flow

The next candidate admits input-free void/scalar blocks with no branches,
early returns, indexed signatures or other structured control. An iterative
walk flattens their ordered children for the existing symbolic scalar analysis
and direct mutation. Flat analysis retains its original shared instruction row;
block output matches the full-HOT reference exactly. Indexed, tuple, branched,
loop, exception and continuation families retain their complete fallback.
[Red-first block fixtures](../../../../../src/passes/dae2_raw_branchless_blocks_wbtest.mbt)
cover nested results, global effects, writes, load tees, import results, traps
and recursive forwarding in both world modes, with zero analysis/rewrite lifts.
[Native controls](../../../../../src/passes/dae2_raw_branchless_blocks_perf_wbtest.mbt)
compare complete HOT/direct DAE2 at tiny/wide sizes and depths 1/16.

The trials exposed a correctness error in the previous HOT fallback: a read
already on the operand stack could be assigned the definition from a later
block write because the root-only CFG visits its consuming parent later.
An entry read lost its parameter; a read after an earlier write lost that
write. A first-write entry-edge experiment fixed only the former and is
superseded. Demanded LocalGraph now uses expanded operand control, preserving
both actual source families and loop-carried writes. Read-only and proved
entry-write admission still avoid the graph.
[Dependency regressions](../../../../../src/passes/dae2_stacked_block_entry_wbtest.mbt)
first fail on the lost entry parameter and earlier write, then require exact
signatures, retained writes, valid output and owned input. The
[dispatcher](../../../../../src/cmd/dae2_raw_branchless_blocks_wbtest.mbt) checks
both modes. Nineteen focused checks pass; full/native, bounded execution and
artifact cost/size evidence remain under way. Keep this as a release blocker
until runtime replays and final affected aggregate renewal complete.

## September 29, 2026 scalar tees and solved graph transfer

V13 tracks a tee's stack value separately from its local write. Demanded writes
keep their ordered tee/drop shape; unread captures for removed parameters
vanish. The first V13 projection incorrectly retained unread original
body-local tees: the large DAE2 input grew 316 bytes across 86 functions.
V14 projects retention from surviving local.get instructions, matching
`hot_lower_impl_prune_dead_local_tees_in_body` even for reads preceding a later
write. [Red-first capture fixtures](../../../../../src/passes/dae2_raw_tee_captures_wbtest.mbt)
cover unread body locals, earlier reads, overwrites and removed parameters;
the dispatcher fixture also failed before the repair. [Tee fixtures](../../../../../src/passes/dae2_raw_tee_wbtest.mbt) compare
exact full-HOT bytes for stacked entry reads, overwritten definitions, mandatory
loads/calls, removed results and f32/f64 reinterpretation. Both
[dispatcher modes](../../../../../src/cmd/dae2_raw_tee_wbtest.mbt) retain discarded
import effects. The initial two tests failed with a second rewrite lift; the
combined tee/storage slice now passes seventeen focused checks.

V12 drops solved module adjacency before rewrite but requires mutable graph
fields. V13 instead transfers the same solved bitvector into a fresh empty
graph, so the owned analysis graph dies without adding mutable-field reference
work to every edge. [Transfer tests](../../../../../src/passes/dae2_solved_transfer_wbtest.mbt)
require shared solved values, zero new edge capacity and unchanged borrowed
storage. [Matched graph controls](../../../../../src/passes/dae2_graph_fields_perf_wbtest.mbt)
compare the frozen V12 mutable graph with immutable fields. V14 completes
12,853 default and 86 focused native tests, 46 benchmarks and 4,056 matching
bounded observations. Large DAE2/O bytes match V12. Small DAE2/O pipelines
improve 62.47%/40.67%; active tee pipelines improve 91.89%/18.29%. Large costs
remain multi-second with contended small movements; RSS ranges overlap, and
quiet GC/entry/pure costs remain. The [complete V14 report](../../../tooling/tracing-playbook.md#v14-complete-checkpoint-and-next-cleanup-targets)
records hashes, oracle ratios, size gaps and the SL stack-order hotspot.

## September 29, 2026 scalar direct mutation

V11 qualifies scalar flat bodies for mutation without a second HOT arena.
A body-local dependency graph demands stack values and the last local write
feeding each read. Calls demand only retained arguments; mandatory producers
still execute in original order and drop unused retained results at production.
Removed results, explicit returns and kept-result calls follow solved module
boundary liveness. Local slots and names use the existing reverse removed-param
placement and capture compaction map. Complete final-module validation remains.

[Exact HOT comparisons](../../../../../src/passes/dae2_raw_rewrite_wbtest.mbt)
cover writes beneath stacked reads, traps, effects, recursion, grouped locals,
names and 130 parameters. Tuple results and indirect calls retain HOT mutation at this checkpoint;
V13/V14 subsequently admit scalar tees under the contract above. The [dispatcher](../../../../../src/cmd/dae2_raw_rewrite_wbtest.mbt)
checks both modes. The initial eight-fixture test failed with two rewrite lifts
before implementation; the final focused slice passes fifteen checks. V11
passes 12,840 default and 73 focused native tests and 52 native benchmarks.
The 741-module bounded matrix has 3,380 matching runtime observations and
identical V10/V11 outputs. Direct-only mutation controls improve 38.62 →
12.98 µs at tiny scale and 8.44 → 1.52 ms at 32 bodies/128 operations.
Enclosing active flat DAE2/O improve 81.45%/66.02% and GC 89.71%/56.97%.
Large compiler DAE2/O remain 3.89/7.07 seconds at 9.19×/4.39× v133.
The [priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
records the initial active O regression, its quiet renewal, RSS variation and
remaining size gaps. V12 completes releasing solved module adjacency before rewrite;
[storage and active rewrite checks](../../../../../src/passes/dae2_solved_storage_wbtest.mbt)
require zero retained edge capacity and unchanged solved liveness/output.

## September 29, 2026 mandatory producers and replay reset

V10 qualifies flat scalar loads, trapping numeric operations and selected GC,
reference, table and growth producers without the first HOT arena. All inputs
are observed even for a dropped result, preserving possible traps and effects;
struct field counts use the existing module subtype context. Changed functions
still replay and mutate through HOT. The
[direct opcode and exact-HOT fixtures](../../../../../src/passes/dae2_raw_producers_wbtest.mbt)
include array operations missing from the text reader, and the
[dispatcher](../../../../../src/cmd/dae2_raw_producers_wbtest.mbt) covers both modes.

Bulk replay reset preserves the retained-capacity and immutable-boundary
contracts, restoring the wide helper after V9's 7.18% regression. Fresh/reused
64-body controls measure 720.37/629.66 µs at 8,192 boundaries. V10 passes
12,830 default tests, 61 focused native tests and 2,808 bounded runtime
observations. Quiet active GC DAE2/O improve 7.53%/2.79%; large passes remain
four/seven seconds with a contended O increase requiring renewal. The
[priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
owns exact hashes, RSS dispersion and fresh verified-v133 ratios.

## September 29, 2026 flat writes and rewrite allocation

V9 extends the symbolic stack with one current dependency per local. A flat
`local.set` replaces that symbol; `local.tee` replaces it while preserving the
stack value. Values already on the stack retain their earlier symbol across a
later write. Validation still precedes graph commitment, and structured writes
retain full HOT/LocalGraph analysis. The
[assignment fixtures](../../../../../src/passes/dae2_raw_assignments_wbtest.mbt)
compare exact full-HOT bytes for overwrites, tees, stacked entry reads and a
body-local carrier, with no initial lifts.

Changed raw bodies now share one module-scoped replay workspace. Reset clears
all expression edges, work and observed state, then reseeds the immutable solved
boundary prefix. Capacity is bounded by that prefix and the largest replayed
body; no HOT arena is retained. [Reset and multi-body tests](../../../../../src/passes/dae2_replay_workspace_wbtest.mbt)
prove old edges cannot affect a smaller next body or mutate module liveness.
[Native controls](../../../../../src/passes/dae2_replay_workspace_perf_wbtest.mbt)
compare fresh and reused replay allocation at 128/8,192 boundaries.

The rewrite walk reads checked child slots until a child ID changes, allocating
one owned parent snapshot at the first replacement. Unchanged ordinary nodes
return directly; calls retain the old producer IDs required for tuple grouping.
[Ownership fixtures](../../../../../src/passes/dae2_lazy_children_wbtest.mbt)
assert unchanged encoded expressions/revisions and independent changed snapshots;
[controls](../../../../../src/passes/dae2_lazy_children_perf_wbtest.mbt) compare
the former owned-map path against lazy snapshots. The expanded focused suite
passes 451 tests and V9 passes 12,819 default, 50 focused native and 479
native IR tests plus 64 native benchmark cases. Its 2,444 bounded runtime
observations match. Child controls improve 72.51 → 36.61 ns and
290.10 → 136.65 µs; replay improves 66.59 → 44.79 µs at 128 boundaries,
but regresses 765.67 → 820.62 µs at 8,192. The wide reset needs another
trial, completed by V10 above. The priority report records completed V9
enclosing, repeated memory and fresh oracle evidence; V8's historical costs
remain visible.

## September 29, 2026 symbolic flat-body analysis

An active flat body can record parameter and whole-result dependencies without
its initial HOT arena. Constants and default-initialized locals contribute no
dependency; readonly parameter reads alias their boundary location. Pure scalar
operators merge distinct dependencies through compact integer joins. Call
arguments depend on the callee's parameter locations, returned lanes alias its
whole-result location, and indirect/reference targets are observed. Stores
observe their operands. Recursive forwarding therefore retains the same least
fixed point without a fixed parameter-count limit.

Qualification completes before committing graph edges and every admitted body
is validated. Assignments, structured control, tail calls, intrinsic targets,
trapping producers and unsupported SIMD/GC operations retain full HOT analysis.
Only bodies needing a rewrite are lifted; their expression liveness is replayed
in a fresh graph seeded with the solved boundary prefix. No solved module edges
are mutated. A newly observed boundary triggers a complete HOT reanalysis of
the original module. The private reference switch enables exact encoded-output
comparisons; it is not a public optimizer option.

[Red-first tests](../../../../../src/passes/dae2_raw_analysis_wbtest.mbt)
cover stores, dropped expressions/results, final returns, multiple result lanes,
recursion, indirect/reference families, 96 parameters, input ownership and invalid
types. [Both command modes](../../../../../src/cmd/dae2_raw_analysis_wbtest.mbt)
retain live store operands while pruning an unused argument. Dedicated
[benchmarks](../../../../../src/passes/dae2_raw_analysis_perf_wbtest.mbt)
compare full HOT and raw analysis with active rewriting at tiny and wide sizes,
then measure complete plain and optimizing pipelines. V8 passes 12,812 default
and 43 focused native tests; 2,184 bounded runtime observations and exact
HOT-reference output controls match. Three quiet flat-body pairs improve
DAE2/O 10.37%/27.68%, while large DAE2 remains about four seconds. Five
V7b/V8 RSS pairs add median 15,796/6,060 KiB for DAE2/O with wide variation.
The compiler and memory gaps remain open; the priority report owns exact hashes,
MAD and host contention.

## September 29, 2026 readonly observable boundaries

Flat private void bodies can establish readonly parameter liveness before HOT
lifting. Qualification scans the whole body first and marks a parameter only
when a direct leaf read supplies an observable store or pinned call operand.
Parameter assignments, unsupported control and unknown arities retain the
complete analysis. Newly pinned boundaries use the same validated first-lift
admission as exposed functions; every call/control family must also be pinned,
and intrinsic calls retain HOT target analysis. Invalid bodies still reject.

[Pass and ownership regressions](../../../../../src/passes/dae2_observed_entry_wbtest.mbt)
and [both dispatcher modes](../../../../../src/cmd/dae2_observed_entry_wbtest.mbt)
preserve stores and live arguments while removing an unrelated dead parameter.
The V6 checkpoint passes 12,795 default tests and 1,716 bounded runtime
observations. Three quiet pairs improve the 128-wrapper/128-store pipeline
57.26% in DAE2 and 30.68% in DAE2-O with identical bytes. Full compiler costs
remain near their prior four/seven-second levels; this does not close P03.
The [priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls)
owns exact hashes, native controls, MAD, memory uncertainty and pending renewal.

## September 28, 2026 compact locations and early admission

Node locations now occupy one contiguous range per analyzed function. The
function snapshot stores its base and count instead of an additional node-ID
array. Bulk graph growth retains spare capacity across neighboring bodies;
dependency IDs, negative sentinels and insertion order are unchanged. V3 fused
call metadata and intrinsic target pins into dependency analysis. V4 records
all six call forms during the existing raw control scan, including legacy
bodies/catches, and avoids collecting the same metadata again in HOT.

A body whose boundary, callees and indexed control families are fully pinned
may avoid its first HOT lift. Public type-family seeds count as pins before
fixed-point propagation; private direct boundaries stay independent. The
original body still undergoes function-body validation against a reusable
module environment. Each validation owns its local, label, operand and
initialization state; no sibling state is retained. Intrinsic calls retain
HOT analysis to pin their literal `ref.func` targets. Legacy/unknown controls,
invalid family IDs and unpinned boundaries retain the full path. Metadata still
drives rewrite admission after solving.

For a local with exactly one unconditional top-level `local.set`, root-order
analysis can resolve reads to entry or that write without building CFG and
LocalGraph. Operand reads precede completion of the write. Shared reads seen
on both sides, detached reads, conditional/repeated writes, shared writes and
handler/continuation bodies retain the complete flow/unknown fallback. The
proof does not mutate HOT and dies with the analyzed function.

The initial v2 proof expanded shared HOT subtrees repeatedly and stalled on the
large compiler input. That prototype is rejected: its small runtime controls
and faster graph-allocation benchmarks did not establish enclosing performance.
A sixteen-node regression subsequently failed its traversal-work bound while
preserving the expected cross-write unknown read. V3 caches non-read visits in
the source scratch, invalidating them after each admitted root write. This
fixes exponential expansion but can revisit a shared subtree after every
unrelated write. V4's red-first many-write DAG regression exposed that remaining
cost. Unique postorder plus one reverse propagation computes each node's first
and last reaching root ordinal. A read entirely before its sole write is an
entry read, a read entirely after is a write read, and a crossing interval is
unknown. Operands within the write root precede its completion. A write used
under another root, or repeated as a root, requires full flow. The work is
linear in nodes, child edges and roots; scratch remains function-scoped.

V4's one-write native controls regress, so V5 uses a separate single-write
proof with only two visit epochs and a scalar completion flag. It avoids the
interval/postorder arrays while preserving linear work. The multi-write proof
still uses root intervals; shared or repeatedly executed writes require full
flow. Indexed LocalGraph queries now return a scalar readonly source record
for DAE2, avoiding an enum allocation per source. Owned-array and enum queries
remain available, with identical source order and checked bounds.

V3 also keeps retained leaf rewrites scalar, classifies dependency-node effects
once per operand loop, and appends private function signatures in one owned type
workspace. The outer source group vector is copied once; original definitions
remain unchanged. Lowering may replace the workspace after adding control
types, at which point its flattened count is recomputed. Private appends update
that count directly, preserving metadata and allocation order. Family rewriting,
canonicalization, name remaps and full final validation remain unchanged.

Red-first controls exposed extra lifts, exact-capacity bulk growth, missing call
metadata, unnecessary local flow and repeated DAG traversal. V5 passes 12,788
default wasm-gc tests, 477 native IR tests and nineteen focused native tests.
The bounded runtime matrix validates 325 modules with 1,560 matching results,
effects and traps against original/baseline/candidate/verified-v133 behavior.
V4 pinned-call sibling pipelines improve DAE2/O 51.33%/18.88%, and V5
conditional-write DAE2 improves 3.99% over V4. The fresh V5 large pass-local
comparison remains 3,976.588 ms at 9.34× v133 for DAE2 and 7,213.857 ms at
4.44× for DAE2-O. DAE2-O also remains larger than the oracle by 382,584 raw
bytes. These improvements do not close the large compiler or output-quality
gaps. Exact hashes, dispersion and controls are in the
[priority report](../../../tooling/tracing-playbook.md#dae-priority-scan-and-source-query-controls).
Dedicated aggregate renewal remains deferred
during performance iteration; these changes do not inherit earlier signoff.

Sources: [implementation](../../../../../src/passes/dead_argument_elimination2.mbt),
[range invariants](../../../../../src/passes/dae2_compact_locations_wbtest.mbt),
[first-lift controls](../../../../../src/passes/dae2_first_lift_wbtest.mbt),
[raw call metadata](../../../../../src/passes/dae2_raw_calls_wbtest.mbt),
[pinned-call benchmarks](../../../../../src/passes/dae2_pinned_calls_perf_wbtest.mbt),
[entry-write behavior](../../../../../src/passes/dae2_entry_write_wbtest.mbt),
[source-order checks](../../../../../src/passes/dae2_entry_sources_wbtest.mbt),
[DAG interval benchmarks](../../../../../src/passes/dae2_entry_interval_perf_wbtest.mbt),
[scalar source ownership](../../../../../src/ir/local_graph_scalar_sources_wbtest.mbt),
[scalar query benchmarks](../../../../../src/ir/local_graph_scalar_sources_perf_wbtest.mbt),
[native controls](../../../../../src/passes/dae2_priority_perf_wbtest.mbt),
[leaf rewrites](../../../../../src/passes/dae2_rewrite_leaf_wbtest.mbt),
[type workspace](../../../../../src/passes/dae2_type_workspace_wbtest.mbt),
[allocation controls](../../../../../src/passes/dae2_rewrite_allocation_perf_wbtest.mbt),
[dispatcher](../../../../../src/cmd/dae2_entry_write_wbtest.mbt), and
[validation ownership](../../../../../src/ir/hot_validation_env_wbtest.mbt).

## September 27 follow-up allocation campaign renewal

The [final follow-up campaign](../../../tooling/tracing-playbook.md#september-27-2026-follow-up-pass-allocation-campaign)
supersedes pending-renewal notes for its allocation changes below. The frozen
source passes 12,583 default tests. Its 220,000 comparisons across 22 affected
lanes report no validation, generator, property-counter, command or observed
Starshine/original semantic failures. The report retains exact tool identities,
all artifact timings, active fixtures, residual/size replays and runtime limits.
Per-change measurements are historical isolated pairs, not additive gains.
Remaining timing, output-quality and runtime-coverage gaps stay open; rejected
prototypes remain rejected.

This page describes the implemented Binaryen 132 port, superseding the earlier
proposal to leave `dae2` unknown or to add only parameter forwarding.

The module pass owns a short-lived usage graph. Each function parameter and
whole result tuple has a location; HOT expression values have locations too.
Type-family locations connect referenced functions to indirect calls. Observable
uses seed the graph, and a queue visits each live location at most once.

## September 27, 2026 flat dependency storage

DAE2's parameter, result, and expression-value graph stores actual dependencies
in flat source/next arrays, with first/last edge indices for each location.
Creating a location no longer allocates an empty heap array. Appending through
the last edge preserves insertion order and therefore the existing observation
queue order. Duplicate dependencies remain harmless; unobserved cycles remain
unused, and a later observation resumes the same monotone fixed point.

The sparse-location regression first failed with 64 edge rows for an edgeless
64-location graph. It now requires no edge entries until a dependency is added,
then verifies exact live locations, duplicates, disconnected cycles, negative
sentinel inputs, insertion order, and repeated solving. The existing unrepresented
read test still checks both parameter-entry and write dependencies. The command
fixture verifies dead-argument removal while keeping a live forwarded parameter
in both DAE2 modes.

Sources: [graph implementation](../../../../../src/passes/dead_argument_elimination2.mbt),
[invariants](../../../../../src/passes/dae2_sparse_edges_wbtest.mbt),
[sparse and dense controls](../../../../../src/passes/dae2_sparse_edges_perf_wbtest.mbt),
[dispatcher fixture](../../../../../src/cmd/dae2_sparse_edges_wbtest.mbt).
All six focused regressions pass. Native construction/solve benchmarks compare
the original row algorithm and flat storage in the same binary: **114.69 →
32.27 µs** for 8,192 sparse locations, **454.05 → 127.55 µs** for 32,768, and
**117.19 → 79.24 µs** for a denser 4,096-location control. These isolate graph
storage and solving; they do not establish a whole-pass speedup. Final artifact
and generated evidence belongs to the
[tracing playbook](../../../tooling/tracing-playbook.md).

## September 26, 2026 sparse local-flow query storage

Reverse reaching-definition queries now allocate cache entries only for queried
block/local pairs. They reuse visited-block and worklist storage and index a
predecessor's last local writes lazily; blocks with at most four actions retain
the direct scan. The sparse control-flow fallback also reuses traversal storage.
Caches remain scoped to one immutable function/CFG, preserve source ordering,
and publish results only after completing the predecessor closure.

Bounded tests first failed on dense cache capacity and eight query-workspace
allocations instead of one. They retain exact reaching writes across separate
blocks. Existing join, loop and handler fixtures compare sparse results with
the converged reference solver. Command coverage checks real unused-argument
pruning while preserving a cross-block local value.

Focused native graph-construction benchmarks improve `749.80 → 401.22 µs` for
128 cross-block reads and `2.81 → 1.47 ms` for 256; each fixture declares four
times as many locals as it reads. These measurements establish the targeted
analysis gain, not a whole-DAE2 speedup. Evidence:
`src/ir/local_graph_query{,_perf}_wbtest.mbt`,
`src/cmd/perf_local_flow_wbtest.mbt`, and
`.tmp/pass-perf-work-20260926/local-query-{before,after}.log`.
Final aggregate results and runtime limits are in the [shared renewal](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal).

## September 26, 2026 shared source-order index

The [CoalesceLocals source-order renewal](../coalesce-locals/starshine-strategy.md#september-26-2026-source-order-local-access-index) also improves large-input DAE2: seven isolated alternating pairs give pipeline `7,633.494ms → 6,438.548ms` (**15.7% faster**), with byte-identical outputs. Unlike the lazy-flow fixture gain below, this is a confirmed compiler-artifact improvement. The shared ordering proof and strict bounds remain unchanged; the linked page owns hashes, tests, the small DAEO tradeoff and signoff evidence. Initial lifting and required local-flow solving remain open targets.

## September 26, 2026 lazy local-flow analysis

LocalGraph/CFG construction now waits for the first live local read. The conservative all-writes index waits for the first read whose reaching sources are unknown. Both snapshots are function-local and built at most once; unknown reads still depend on the entry parameter and every possible write, including unrepresented nodes. This follows the demand-driven `LazyLocalGraph` queries in [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp); Starshine also needs dependencies through body locals.

Two bounded regressions failed with two unnecessary builds each. Final tests cover real signature pruning, retained parameter reads, deliberately unrepresented reads with conservative dependencies, and command dispatch. The focused suite passes 77 tests; `moon info`/`moon fmt` succeed with no public API change.

Native `0925e7e8ae15e1e06d4fa171fdcf5b251e42f68f627ef7955a10bf032570748f` versus baseline `b084365e0bd4b2bc98457da7eb8773504b5cf2720665dea7ae5b961d30c41a06`, isolated alternating samples after one warmup:

- 1,000 store-heavy functions requiring signature rewrites: seven-pair pipeline `359.096ms → 322.358ms` (**10.2% faster**).
- 1,000 unchanged store-heavy functions: three-pair pipeline `114.711ms → 81.794ms` (**28.7% faster**).
- Small compiler: seven-pair `19.742ms → 19.508ms`, a small difference.
- Large compiler: an apparent three-pair `8,292.333ms → 8,176.763ms` gain did **not** repeat. Seven pairs give `8,200.787ms → 8,222.452ms`, with mixed per-pair deltas. This establishes no meaningful large-artifact speedup.

Every paired raw output is identical. Evidence: `.tmp/dae2-lazy-flow-paired-<fixture>-final-20260926/`, `.tmp/dae2-lazy-flow-confirm-large/result.json`, and the [fuzzing page](./fuzzing.md). Source/tests: [`dead_argument_elimination2.mbt`](../../../../../src/passes/dead_argument_elimination2.mbt), [`dae2_lazy_flow_wbtest.mbt`](../../../../../src/passes/dae2_lazy_flow_wbtest.mbt), and [command fixture](../../../../../src/cmd/dae2_lazy_flow_wbtest.mbt). Initial lifting and actual local-flow solving remain performance targets.

## September 26, 2026 skip unchanged rewrite lifts

The rewrite phase now reuses the first analysis phase's complete direct/indirect call summary. It rebuilds HOT only when a function or one of its callees changes signature, or when indexed control types require the existing preservation path. Legacy `Try` also retains that path. The rewrite decision is computed once; type-family identity, new function-type selection, names, final cleanup and validation still run. The bounded preflight leaves all analysis and fixed-point edges intact. [Binaryen 133's DAE2 optimizer](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp) works on its retained IR and gates signature/local reconstruction on removed parameters or results; this change avoids Starshine's additional reconstruction of unaffected bodies.

A regression first failed with three rewrite lifts instead of two while successfully pruning the sibling's unused parameter. Two pass fixtures and one active command fixture verify the skip, retained indexed-control preparation, unchanged input/body preservation and the optimized call signature. All 74 focused DAE2 tests pass; `moon info` and `moon fmt` succeed without a public API change. The full wasm-gc suite passes 12466 tests with zero failures.

Fresh native `b084365e0bd4b2bc98457da7eb8773504b5cf2720665dea7ae5b961d30c41a06` is compared with baseline `8b7d8d8aa8de9342cf6148de10350ca9104217e18d2317cf92b2be7e7d08e0a1`. Isolated alternating pairs after one warmup preserve exact raw output on every fixture:

| Fixture | Samples | Before pipeline | After pipeline |
| --- | ---: | ---: | ---: |
| Small compiler | 7 | 19.135ms | 18.362ms |
| Large compiler | 3 | 8,394.226ms | 7,704.931ms |
| 100 unchanged functions | 3 | 14.341ms | 10.454ms |
| 500 unchanged functions | 3 | 73.810ms | 51.734ms |
| 1,000 unchanged functions | 3 | 152.037ms | 107.030ms |
| 1,000 functions requiring rewrites | 7 | 331.541ms | 335.645ms |

The large compiler improves **8.2%**, with command median `9,411.505ms → 8,622.409ms`. The 1,000-unchanged-function fixture improves **29.6%**. The all-changing synthetic fixture regresses **1.2% (4.104ms)**; this is a measured tradeoff, not a universal speedup. A preliminary implementation retained a duplicate rewrite check and was replaced before signoff; its interrupted oracle run does not establish final evidence.

Fresh v133 pass-local medians remain `18.699ms` versus `1.131ms` on the small compiler and `7,578.025ms` versus `396.714ms` on the large compiler. The remaining DAE2 performance gap stays open.

Evidence: `.tmp/dae2-relift-paired-{small,large,functions-1000,unchanged-100,unchanged-500,unchanged-1000}-final-20260926/`, `.tmp/dae2-relift-inputs/manifest.json`, and the [fuzzing renewal](./fuzzing.md). Source and fixtures: [`dead_argument_elimination2.mbt`](../../../../../src/passes/dead_argument_elimination2.mbt), [`dead_argument_elimination2_types.mbt`](../../../../../src/passes/dead_argument_elimination2_types.mbt), [`dae2_relift_wbtest.mbt`](../../../../../src/passes/dae2_relift_wbtest.mbt), and [command test](../../../../../src/cmd/dae2_relift_wbtest.mbt).

## September 26, 2026 catch-payload analysis preflight

DAE2 invokes ordered catch-payload repair on each lifted function. The repair planner previously built its complete node-use graph before checking whether the function contained typed catch payloads. It now performs the existing live-node preflight first and returns the same empty plan when there are no payloads. Catch-all markers still reject; real typed payloads still build the graph and use the original complete, atomic repair plan. Public repairability and mutation results are unchanged. This follows the lazy-analysis principle in [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp), whose parameter-use visitor queries `LazyLocalGraph` only after confirming a read targets a parameter; Starshine's catch repair remains its own representation bridge.

The bounded regression first failed because a payload-free function built one use graph. It now preserves the original lowered body and revision with zero graph constructions. A positive typed-payload regression still builds one graph, inserts a typed capture and local read, and validates control. All 969 IR, DAE2 and Flatten tests pass on wasm-gc. The preceding 1,000-helper instruction profile attributed 6.40% of total instructions to catch-repair planning, including 5.36% in use-graph construction; these are instruction counts, not timings.

Paired native measurements retain identical output bytes on every sample:

| Fixture | Before pipeline | After pipeline | Sampling |
| --- | ---: | ---: | --- |
| Small compiler | 20.446ms | 19.107ms | One warmup, seven alternating pairs |
| 1,000 store-heavy helpers | 353.583ms | 333.762ms | One warmup, three alternating pairs |
| Large compiler | 8,731.602ms | 8,317.893ms | One warmup, three alternating pairs |

These are 6.5%, 5.6% and 4.7% pipeline reductions respectively. Large command median changes `9,759.045ms → 9,315.220ms`. Paired artifacts are `.tmp/catch-preflight-paired-{small,functions-1000,large}-20260926/`. Baseline native SHA-256 is `30dc535a657e2467aaf55d765ee9393e742144f97186b862c517c30e6a513a4c`; updated is `a6385c90382a7a2925d0b4e049a5bcd5ccac3fc8d4f473e7cf41a0411a5943ea`. `moon info`, formatting and native release build pass; no public API changes.

Fresh verified-v133 sweeps measure small pass-local medians `19.130ms` versus `1.130ms` and large medians `8,260.168ms` versus `400.926ms`; the substantial remaining oracle performance gap is still open. Artifacts: `.tmp/pass-sweep-v133-catch-preflight-{small,large}-20260926/`.

The explicit-native `dae2` aggregate renewal uses verified v133, seed `0x5eed`, eight subprocesses, both debris normalizers and Node-v2. Each world compares 10,000 cases: open has 2,879 normalized, 667 cleanup-normalized and 6,454 residuals; closed has zero normalized, 100 cleanup-normalized and 9,900 residuals, including 706 canonical size losses. Each world has 9,312 runtime matches, 688 original-runtime-blocked continuation cases and zero semantic mismatches. Both have zero validation/property/generator/command failures. Counts match the preceding module-environment signoff.

Flatten also calls the repair planner, so its `flatten-all` aggregate runs 10,000 cases with all three documented debris normalizers: 837 normalized, 5,057 cleanup-normalized and 4,106 residuals, zero canonical size losses and zero validation/property/generator/command failures. Runtime execution was not enabled for Flatten. Agent judgment keeps current residuals open as parity gaps, including closed DAE2's size-losing cases; no historical Flatten cleanup-win classification is extended to v133 here. All 60 saved raw residual outputs replay identically against the pre-change compiler. Artifacts: `.tmp/pass-fuzz-dae2-catch-preflight-{open,closed}-v133-10000-20260926/`, `.tmp/pass-fuzz-flatten-catch-preflight-v133-10000-20260926/`, and `.tmp/catch-preflight-replay.json`. The 12,456-test full default suite passed immediately before this unit; its current focused suite passes 969 tests.

## September 26, 2026 shared cleanup module facts

The final branchless-block cleanup built a complete validation environment for every defined function. It now builds one environment after signatures, control types and local-throw folding are finalized, then supplies it to each cleanup. The helper only reads module block-type facts; the candidate's declarations stay unchanged throughout this map. Existing callers retain their original environment construction when no shared snapshot is supplied. [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp) likewise keeps one module object across analysis and rewriting and caches shared public-type facts.

The bounded regression prunes i32/i64 parameters, flattens typed result wrappers, preserves two live calls and their result, and limits cleanup environment construction to at most one. It first failed with three constructions; all 73 DAE2/shared-cleanup tests now pass on wasm-gc. `moon info`, formatting and the native release build pass; this unit adds no public API.

| Fixture | Before pipeline | After pipeline | Sampling |
| --- | ---: | ---: | --- |
| 100 helpers, 64 ordered stores each | 35.626ms | 33.593ms | One warmup, three alternating pairs |
| 500 helpers, 64 ordered stores each | 227.985ms | 172.662ms | One warmup, three alternating pairs |
| 1,000 helpers, 64 ordered stores each | 566.952ms | 357.659ms | One warmup, three alternating pairs |
| 6,211,596-byte compiler fixture | 350,398.025ms | 8,849.366ms | **One pair, no warmup** |

The single large pair is a 39.6x pipeline improvement, with command time `351,398.852ms → 9,841.313ms`. Its limited sample count is explicit; it is not a three-sample median. Output remains exactly 6,114,805 bytes, SHA-256 `2b9031cbfa2fce3ed29abf783daef2774688941baea42d00499db575d0321696`. Every repeated synthetic pair is also byte-identical. The 192,893-byte compiler fixture changes only `20.755ms → 20.393ms`, which is not claimed as a material gain.

Paired artifacts are `.tmp/dae2-module-env-paired-{small,functions-100,functions-500,functions-1000,large}-20260926/`; synthetic inputs and their hashes are in `.tmp/dae2-module-env-inputs/manifest.json`. Baseline native SHA-256 is `3063c88915ccf04bdcbc8d85d4b134bc3860f24d3a19775336a411c9de416278`; updated SHA-256 is `a9bc998439325ef23dec3af201619d4e86991cfe46fc8bde920b5e8aaa159475`. New oracle measurements use verified Binaryen 133; older v132 port evidence below retains its historical scope.

Fresh verified-v133 sweeps (one warmup, three samples) put current pass-local time at `21.162ms` versus `1.155ms` on the small compiler fixture, `8,892.905ms` versus `397.330ms` on the large fixture, and `353.336ms` versus `8.039ms` on the 1,000-helper input. Large command medians are `9,806.644ms` versus `856.742ms`. This removes the repeated module construction but leaves a substantial DAE2 performance gap. Sweep artifacts are `.tmp/pass-sweep-v133-dae2-module-env-{small,large,functions-1000}-20260926/`.

The renewed aggregate `dae2` profile uses seed `0x5eed`, explicit prebuilt native binaries, eight subprocesses, both cleanup normalizers, and Node-v2. Each world completes 10,000 comparisons: open has 2,879 normalized matches, 667 cleanup-normalized matches and 6,454 residuals; closed has zero normalized matches, 100 cleanup-normalized matches and 9,900 residuals, including 706 canonical size losses. Each world has 9,312 runtime matches and 688 original-runtime-blocked continuation cases, with zero semantic mismatches, validation, property, generator or command failures. Counts match the preceding nearest-write signoff; all 40 saved raw residual outputs are byte-identical to the pre-change compiler. Residuals remain agent-classified open parity gaps, including the closed-world size-losing family; runtime sampling does not establish complete transform parity. Artifacts: `.tmp/pass-fuzz-dae2-module-env-{open,closed}-v133-10000-20260926/`. The previous full default suite passed 12,451 tests before this unit; this unit's focused suite passes 73.

## September 25, 2026 nearest-write indexing

The shared reverse-flow LocalGraph builder now records each get's nearest within-block write during its existing action walk. It resets only written local slots at block boundaries and retains the same predecessor/exception closure when no within-block write exists. This removes repeated backward prefix scans without changing reaching-definition facts. The [dedicated native benchmark](../../../../../src/passes_perf_long/dae2_local_graph_perf_test.mbt) improved from `4.15ms` to `403.57µs` at 1,024 distant reads and from `14.95ms` to `795.21µs` at 2,048; [bounded tests](../../../../../src/ir/local_graph_reverse_wbtest.mbt) cover overwrites and sibling-block isolation. All 407 IR tests and 70 DAE2 tests pass on wasm-gc. `moon info` and formatting pass with no public API change from this unit.

On the 189 KB fixture, DAE2 pass-local median improved from `25.862ms` to `23.189ms` (10.3%), with identical raw output SHA-256 `f8b4d5e5c7b6372ad8d6a2193df5f2db61ec4ce2462b40095a762dfe226a35f7`. Verified Binaryen 133 measured `1.347ms` in the new sweep, so the pass still loses by `17.21x`. [Binaryen 133 DAE2](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/DeadArgumentElimination2.cpp) queries `LazyLocalGraph` only for parameter gets; Starshine still eagerly builds broader local liveness to support its expression-removal graph. That larger analysis difference remains an optimization target. Artifacts are `.tmp/dae2-localgraph-bench-{before,after}.log` and `.tmp/pass-sweep-v133-{dae2-localgraph-before,localgraph-after-small}-20260925/`.

The fresh open-world `dae2` aggregate compares 10,000 cases against verified v133 with the explicit native binary and eight subprocesses: 2,879 normalized matches, 667 cleanup-normalized matches, and 6,454 residual output differences. Node-v2 observes equal original/Starshine/Binaryen results in 9,312 cases; all 688 continuation cases remain blocked by the original runtime. There are no semantic mismatches or validation/property/generator/command failures. All residuals are canonically smaller, but size alone does not close parity: reviewed unused-local removal is an exact cleanup benefit; the remaining families remain parity gaps or runtime-blocked uncertainty. Evidence: `.tmp/pass-fuzz-dae2-localgraph-open-v133-10000/result.json` and its persisted diffs/runtime observations.

The closed-world companion also completes 10,000 cases: 100 cleanup-normalized matches and 9,900 residual differences, with the same 9,312 runtime matches, 688 runtime-blocked continuations, and zero semantic/validation/property/generator/command failures. Its 706 canonically larger indirect-call cases remain size-losing parity gaps: Starshine retains the indirect type family's parameter and dropped result where Binaryen removes them (saved case 5 is 83 versus 82 canonical bytes). The other residual families remain open unless individually justified. Both lanes use native SHA-256 `72b55be2e092167030dccf79d6e48f646d338c16791852a9a9171d73b41b9894`; closed-world evidence is `.tmp/pass-fuzz-dae2-localgraph-closed-v133-10000/result.json`. These results validate the indexing change without claiming complete DAE2 parity.

## September 24, 2026 repeated-solve measurement

Type-identity conflict handling can observe more graph locations and call `solve` again. The graph now retains its queue cursor between solves, so earlier locations are not scanned again; edges must be complete before the first solve. The native release white-box benchmark in [`dae2_repeated_solve_perf_wbtest.mbt`](../../../../../src/passes/dae2_repeated_solve_perf_wbtest.mbt) measured 128 incremental observations/solves at `10.11 → 2.29 µs` (4.41×) and 256 at `34.80 → 4.43 µs` (7.86×). A second-solve propagation test and 64 existing DAE2 tests pass. This isolates graph behavior; pass-level impact on real identity conflicts remains unmeasured.

Direct call arguments depend on the corresponding callee parameter. A used call
value depends on the callee result. Returns connect to the enclosing result.
Tail calls connect caller and callee result liveness in both directions. Local
flow distinguishes entry parameters from overwritten locals; branch payloads
and the result types of their targets remain valid.

Each HOT body is released after analysis. A second lift is limited to changed
function/call signatures or indexed-control preservation; other bodies are
reused directly. LocalGraph
uses symbolic block-entry sources and sparse changed-local summaries when a
linear reverse scan cannot represent nested control. It resolves complete
predecessor closures before caching, preserving loops and exception paths.
The new solver matches the converged forward reference on 5,000 GenValid modules.

After solving, the pass builds new signatures, preserves argument evaluation
order with typed temporary locals when necessary, removes unused pure values,
and keeps their effectful or trapping descendants. It rewrites functions,
call sites, returns and eligible type families as one candidate module, verifies
HOT and validates the completed module. The dispatcher rebuilds module analyses.

Referenced type families retain subtype/recursion metadata. Open-world type
exposure pins signatures; a private unreferenced sibling can receive a distinct
signature even when its former type also describes a continuation or export.
The intrinsic `binaryen-intrinsics` / `call.without.effects` pins its target's
signature. Ordinary DAE remains available for independent comparison.

Legacy catch payloads are captured at handler entry before call-argument wrappers
can change their stack position. Multiple handlers are represented through
`try_table` with explicit handler labels. Ordinary catches retain only payloads;
functions with a rethrow use `catch_ref` and capture exception identity, including
rethrows that target an outer handler. A handler executes outside its protected body, so a throw
inside one handler is not accidentally caught by its sibling.

This is implementation evidence, not a claim that every upstream output shape
or every proposal already matches. The [validation page](starshine-port-readiness-and-validation.md)
and [upgrade ledger](../../version-132-upgrade.md) track the remaining signoff.

## September 27, 2026: retain identical child spans during rewriting

**Timing supersession:** the [nested-timer correction](../../../tooling/tracing-playbook.md#september-27-2026-nested-timing-scope-correction)
reparses the same saved traces and supersedes the optimizing pipeline totals
below: small **26.037 → 25.455 ms**, large **8,517.890 → 8,502.036 ms**,
and active wide fixture **60.813 → 58.127 ms (4.4%)**. The previous totals
included nested cleanup twice. Plain DAE2, exact-byte checks, active signature
changes and runtime evidence are unchanged; large optimizing performance
remains open.

DAE2 compares replacement children with the node's current span and skips the
write when their order and count are identical. Calls and control rewrites can
reset a span before this point, so comparing against the originally captured
children would be incorrect. Real changes still use the shared mutation API;
unchanged spans avoid copying old children, appending duplicate arena storage
and invalidating revisions. Tuple memoization, ordering and signature rules
remain unchanged.

The unchanged-span test failed before implementation. Both bounded storage/order
invariants, the active kept/discarded call fixture and 86 other focused DAE2
checks pass (89 total), including tuples and handlers. Native batches improve
**3.12 → 1.40 µs** for 64 repeated writes and **37.76 → 11.54 µs** for 1,024.
Both controls create a fresh small function per batch because the former write
appends arena storage; setup is included equally and storage cannot accumulate
across benchmark iterations.

Compiler pipeline medians are effectively flat: large DAE2 **5,172.277 →
5,199.715 ms**, large DAE2-optimizing **11,435.083 → 11,431.747 ms**; small
DAE2 17.493 → 17.614 ms and optimizing 33.900 → 32.941 ms. These large
budgets remain open. A new 50,413-byte fixture with 64 private helpers, two
parameters and 256 live additions each measures an active rewrite: the unused
second argument disappears from every helper signature. DAE2 is 51.720 →
51.196 ms and optimizing improves **68.743 → 64.668 ms (5.9%)**. This is a
dedicated workload, not a claimed compiler-artifact gain.

All six one-warmup/three-pair comparisons retain exact before/after bytes,
traced/untraced agreement and independent validation. Original and both pass
outputs from both binaries return identical values at five inputs including
32-bit overflow boundaries. Final aggregate renewal remains pending.

Evidence: `.tmp/pass-perf-next-20260927/dae2-child-{checks.json,bench-1.log}`,
`dae2-child-pairs-{small,large,wide}/result.json`, and
`dae2-child-wide-{input,runtime,signatures}.json`. The first benchmark round
was rejected for foreign CPU contention. Native SHA-256: `928989c8aaf2b1a390fb5493571d8b746ac7536ab750d295be5cc7990b30bb08`.
Sources: [rewriter](../../../../../src/passes/dead_argument_elimination2.mbt),
[span invariants](../../../../../src/passes/dae2_child_rewrite_wbtest.mbt),
[native controls](../../../../../src/passes/dae2_child_rewrite_perf_wbtest.mbt),
and [dispatcher fixture](../../../../../src/cmd/perf_dae2_child_rewrite_wbtest.mbt).

## September 27, 2026: reject retained analysis bodies

Retaining analyzed HOT bodies until rewrite avoided a second lift and improved
the dedicated 64-function benchmark from 792.82 to 624.50 µs. It did not
improve the large compiler workload: one warmup and three alternating pairs
measured plain DAE2 **5,489.948 → 5,695.433 ms (+3.7%)** and optimizing DAE2
**9,154.678 → 9,429.039 ms (+3.0%)**. Peak resident memory increased from
302,124 to 394,520 KiB (+30.6%). All four small/large paired comparisons
retained identical bytes, traced/untraced agreement and independent validation.

A smaller 32,768-node cache also regressed large plain DAE2, **5,459.205 →
5,584.159 ms (+2.3%)**. That variant's remaining optimizing measurements were
stopped after rejection; they do not constitute a completed matrix. Production
retention code was removed. A later attempt must reduce live memory or shorten
retention lifetime, rather than assume fewer lifts imply faster full passes.

The bounded [fixture test](../../../../../src/passes/dae2_retention_wbtest.mbt)
checks active rewriting and source reuse. The retained [native benchmarks](../../../../../src/passes/dae2_retention_perf_wbtest.mbt)
measure the current uncached implementation at 64 and 1,024 functions; they
are controls for future work, not a shipped retention optimization. Local
evidence is under `.tmp/pass-perf-reuse-20260927/`: `dae2-retention-pairs-*`,
`dae2-retention-memory.json`, `dae2-retention-small-cache-pairs-*`, and rejected
source snapshots. The initial ownership/work regression failed before the
prototype; 74 focused checks passed before its performance rejection.

## September 28, 2026 performance reuse contracts

Compact indexed-control family summaries let unchanged functions avoid a second lift when every referenced signature family is unchanged; unresolved families retain the conservative rewrite path. Handler admission avoids rebuilding handler-free bodies and preserves untouched sibling bodies. Legacy adaptation still canonicalizes grouped local declarations when another function changes, preserving the original encoded output. Whole-HOT retention remains rejected.

Tests and native controls: [dae2_control_summary_wbtest.mbt](../../../../../src/passes/dae2_control_summary_wbtest.mbt), [dae2_control_summary_perf_wbtest.mbt](../../../../../src/passes/dae2_control_summary_perf_wbtest.mbt), [dae2_handler_admission_wbtest.mbt](../../../../../src/passes/dae2_handler_admission_wbtest.mbt), [dae2_handler_admission_perf_wbtest.mbt](../../../../../src/passes/dae2_handler_admission_perf_wbtest.mbt). The [campaign report](../../../tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign) owns frozen-binary artifact timings, verified-v133 evidence and final correctness outcomes; helper timings alone do not close the remaining pipeline or parity gaps.


## September 28, 2026 shared follow-up controls

Shared initialization ownership and HOT result queries retain their semantic
contracts in the [IR ownership rules](../../../ir2/architecture-rules.md#performance-reuse-ownership-contracts).
The [follow-up report](../../../tooling/tracing-playbook.md#september-28-2026-follow-up-performance-campaign)
separates new helper evidence from this pass's enclosing timings and final
aggregate status. Prior signoff does not automatically cover the new sources;
guarded paths and remaining size/parity gaps retain their existing limits.

The V21 expansion validates 3,172 modules and records 13,776 observations.
DAE2/O now agree with original and v133 on both old stacked-read witnesses;
V18 incorrectly returned 11. SL full/nostructure still return 22, so shared
cleanup signoff remains blocked. The V24 shared source-order repair is under
full/native/runtime confirmation; see the [failure and repair trial](../../../tooling/tracing-playbook.md#v21-stacked-block-runtime-failure-and-v24-repair-trial).
Historical 79-fixture V18 evidence does not cover these new witnesses.

## October 1, 2026: immutable statement query seeds

V61 removes repeated initialized-local mask construction from balanced flat
SimplifyLocals statement queries. A private seed belongs to one immutable body
and environment; each query owns a new stack and borrows the all-true initialized
mask. Typechecking initialization writes only false bits and copies before
changing them; escape/control updates remain isolated. Allocate the seed only
on the second actual query with at least 128 locals. The fallback owns its
empty stack directly. No public API or transform shape changes.

The physical-mask-sharing regression fails before implementation. Five bounded
pass tests cover stack ownership, reset after invalid/escaping prefixes, separate
environments, indexed GC/control/type boundaries, and exact balanced cleanup.
A dispatcher fixture preserves ordered imported calls across nine consumers.
`moon info`, `moon fmt`, all **13,176** default wasm-gc tests, **16** native release
benchmark rows and the native release CLI build pass. No `.mbti` changes.

Native repeated-query controls improve **4.95 → 3.84 µs** at 128 locals and
**7.36 → 4.06 µs** at 8,192 locals. Full balanced-cleanup functions improve
**6.97 → 6.62 µs (5.0%)** and **9.47 → 7.23 µs (23.7%)** respectively. These
are component measurements, not compiler pass-local speedups. Tiny and
single-query controls retain their allocation admission. Generated C confirms
that the fresh query uses the existing owned-stack fork without rebuilding masks.

The frozen post-integration predecessor and candidate produce identical raw
bytes on small/large compiler and active-tee fixtures. Three-pair CPU-6 enclosing
cohorts (one warmup, reference bracket ≤1.15) are flat on large plain/O
(**−0.02% / −0.08%**), small O (**+0.10%**), and tee plain (**−2.17%**, noisy).
Initial small plain costs **+1.27%**; an independent seven-pair repeat gives
**−0.77%**, while small O repeat is **−0.71%**. Initial tee O costs **+4.85%**;
a seven-pair repeat is **+0.002%**. Preserve both cohorts and rejected brackets;
no enclosing speed or RSS win is established.

Original-primary fixed replay validates **80 modules / 160 observations**,
covering i32/i64/f64 negative zero/externref identity, independent side-effecting
calls, default reads and a later memory trap. All before/after consumer outputs
are identical; four verified v133 outputs also preserve runtime observations.
This is bounded fixture evidence, not aggregate fuzz or general signoff.

Artifacts: `.tmp/dae2-query-seed-20260930/` contains red/green logs, final native
rows, full source manifests, matched cohorts/repeats and runtime evidence.
Candidate SHA-256 is `fd6015e29ccc40a274b8b3b98ec37978151cdc622adc9aaeed6c93334d1135e4`.
The V59 oracle speed/size table predates correctness integration and remains
historical; V61 does not renew it. Compound suffix queries, broader ownership,
whole-pipeline costs and the byte gap remain open. The next size trial targets
immutable sole-reader reverse copies whose eliminated writer pays for bounded
index widening; the three largest inspected functions contain no motivating
multiwritten-source or top-level partial-copy family.

## October 1, 2026: profitable sole-reader reverse copies

V62 extends final-index alias admission with a strict instruction-byte budget.
The existing nonwidening path remains first. A width-changing target must have
at most one read; the source retains the existing immutable-root and lexical
dominance proof. The eliminated get+set saves at least four bytes, or tee alone
saves at least two. Require worst-case read-index growth to be strictly smaller
than that saving, using the existing source upper/target lower final-index
bounds. No new body walk, graph, scratch array or rollback is added.

If the sole read precedes or escapes the alias scope, none is forwarded and
the writer stays. A forwarded sole read retires the writer. Roots cannot gain
reads from an incoming admitted alias: ordinary established definitions and
flattening keep alias writers out of the root set. Multi-reader width-changing
partial copies remain intentionally unsupported. Source order, effects, traps,
loop-iteration dominance, reference identity and protected slots retain their
previous contracts. The legacy no-body benchmark still rejects wider copies.

The regression first needs a nested read: an adjacent sole-read set/get was
already eliminated by capture cleanup. The nested fixture fails at target
retirement (`127 != -1`) before implementation. Three bounded pass tests cover
i32/i64/f64/externref/indexed nullable GC, set/tee, all LEB width bands, nested
reads, loop dominance, earlier defaults, out-of-scope/sibling reads and future/
multiple root writes. A dispatcher test checks retirement and complete ordered
calls through retained blocks. `moon info/fmt`, all **13,180** default wasm-gc
tests, **12** native rows, release CLI build and README/API sync pass; no API diff.

The frozen compiler output saves **7,968 raw / 8,146 canonical bytes** across
**151 functions**, with no function-size regressions or non-code semantic
section changes in either encoding. Small/active-tee outputs stay identical.
Function 10435 saves 137 bytes; 7292 and 7293 remain unchanged, so simple static
copy counts do not prove dominating alias coverage on the largest gaps. The
new size trial is a measured byte win under the immutable-copy contract, not
a general classification of the remaining shape differences.

CPU-6 matched enclosing medians (one warmup/three pairs) are **10.413 → 10.373
ms** small and **7,812.703 → 7,796.849 ms** large, effectively flat. Tee costs
**102.234 → 103.838 ms (+1.57%)**; a separate seven-pair repeat is
**104.235 → 105.698 ms (+1.40%)**. Retain rejected reference brackets and both
cohorts. Native short controls stay flat, while wide discovery costs roughly
0.6–2.5%, including the multi-reader rejection control. These costs remain open;
there is no enclosing speed or RSS win. The extra admission wrapper on the
existing cheap nonwidening path is a focused follow-up target.

Current v133 size projection uses the merged harness's bounded fixed-point
writer (eight rounds, first-valid fallback). Large canonical sizes are
**5,797,596 Starshine / 5,587,437 v133**, a **210,159-byte** gap; raw sizes are
**5,668,915 / 5,573,450**, a **95,465-byte** gap. Under this same projection the
predecessor canonical gap is 218,305 bytes. Only 8,146 bytes are saved by V62;
the other 13,987-byte difference from the historical V59 gap reflects renewed
oracle writer projection. Preserve V59's original 232,292-byte scope.

Fresh Starshine pass-local medians extracted from the candidate matched cohort
are **10.338 ms** small / **7,768.290 ms** large; a separate verified v133 cohort
(one warmup/three samples) is **3.145 / 1,864.780 ms**, about **3.29× / 4.17×**.
These descriptive ratios are not paired causal improvements over V59. An
initial oracle command incorrectly disabled compact-import parsing on the
compiler input; reject that failure and use all features for artifact evidence.

Original-primary fixed runtime replay passes **128 modules / 256 observations**
across four scalar/reference types, set/tee, conditional reads, earlier default
reads, a later memory trap, and two loop iterations with changed producers.
Validate every output independently. Node 26 cannot instantiate compact imports;
only the oracle outputs of these flat-import fixtures use
`--disable-compact-imports` for engine replay. The compact oracle artifacts and
failed engine attempt remain saved; artifact-size evidence uses all features.
This bounded lane is not aggregate fuzz or full release signoff.

Artifacts: `.tmp/dae2-profitable-alias-20261001/` holds red/green logs, native
controls, matched/repeated cohorts, full source manifests, per-function quality
rows and runtime observations. Candidate SHA-256 is
`cbe32154a6eabec7795423ce16fd6e5d166e2d2e7b1e0e5f94f83fd81b0a6917`.
Remaining byte families, the reproduced tee cost, source-query/header churn
and all speed/aggregate/release gaps stay open.

## October 1, 2026: cheap alias admission at discovery

V63 checks the existing pure nonwidening predicate at the discovery call site
before calling the larger profitable-admission method. This is the same boolean
admission: the latter already returns true for that predicate, without changing
facts. Retain every wide/final-bound/profitable case. Native code had already
inlined the small check inside the method, but its six-register prologue still
ran before checking cheap copies; duplicating it inside the method would not
address the cost. Discovery now bypasses that frame entirely.

A bounded actual dispatcher work guard fails before the change: one cheap copy
calls the profitable helper. Afterward the same active transform produces exact
predecessor bytes and zero helper calls. Preserve unprofiled/debugger equality
and independent validation; debugger wall time is not benchmark evidence.
All **13,180** default wasm-gc tests, focused pass/dispatcher checks, info/fmt,
release native build and README/API sync pass. No API changes.

CPU-6 matched enclosing medians are **9.691 → 9.753 ms (+0.64%)** small
(MAD 0.057/0.114), **6,140.699 → 6,087.850 ms (−0.86%)** large
(MAD 1.578/19.955), and **103.453 → 101.589 ms (−1.80%)** active tee
(MAD 1.511/0.345; seven pairs). Retain rejected reference brackets. The small
control is effectively flat; the tee result addresses the preceding wrapper
cost. The large absolute times differ materially from V62 even for the same
predecessor executable: do not call the cross-cohort difference a speedup or
combine this cohort with V62 oracle timings to invent a new ratio.

All small/large/tee artifact outputs remain byte-identical to V62. Replay
**32 fresh candidate outputs / 96 retained reference modules**, comparing exact
predecessor bytes and **256** fresh original-primary runtime observations.
Defaults, effects, traps, reference identity and changed loop producers agree.
The 210,159-byte canonical gap is retained under V62's explicit projection;
wide/rejection native costs and broader speed/size parity remain open.

Artifacts: `.tmp/dae2-alias-cheap-20261001/` contains the red/green work guard,
full source manifest, validation, matched cohorts and replay. Candidate SHA-256
is `4817c213a214f545c38039acc42f5311d244c3d9d291edfc0868122765ef2d0a`.

### Raw versus projected copy attribution

The V62 raw and projected artifact review changes the next byte target. In
function 7292, projection adds **762 local.get / local.set pairs**; 7293 adds
**227** and 10435 **458**. Binaryen's own raw-to-projected operation counts stay
unchanged in all three. Starshine raw function 10435 contains **no adjacent
get→set/tee copies**, although its projected output contains 432. Raw and
projected call/control counts remain equal within each Starshine function.
These writer-added copies cannot be removed by broadening a raw alias matcher.

Raw output still has more get/set operations and fewer tees than v133: 7292
is **8,186/2,666/602** get/set/tee versus **7,182/1,662/1,228**, and 10435
is **11,380/2,281/2,092** versus **10,838/1,739/2,498**. Thus both raw cleanup
and writer-origin stack/control shapes need work. Inspect raw witnesses first,
then compare downstream cleanup and projected deltas; statement-spanning stack
values and control-result/tee formation are hypotheses to reduce, not proven
transform classifications. Do not treat the larger canonical copy counts as
raw immutable-alias coverage. Extracted functions/counts are saved under
`.tmp/dae2-profitable-alias-20261001/writer-review/`.

## October 1, 2026: reuse reverse-flow admission tags

V64 uses the validated nearest-write/read tags during final read projection,
instead of decoding every live arena header twice again. Positive tags recover
the local from the existing writer index; negative tags retain the local and
immutable-entry reachability marker. Writer node zero remains valid; nonreads,
orphan reads and deleted nodes keep the nonread sentinel. Whole-arena writer
metadata remains intact. Immutable-entry traversal now requires an observed
never-written read in the compact action rows, rather than an unused local.
No new persistent facts or scratch arrays are introduced.

Two focused admission regressions fail first. Four bounded IR tests compare
complete read rows, writer facts, influence order and finished graphs against
the frozen V63 reference, with both metadata and operand modes, scalar/GC,
loops, unreachable code, shared-action fallback, orphan/deleted nodes and
revision ownership. A dispatcher regression validates parameter removal through
a loop for both passes and scalar/indexed-GC unused parameters. Info/fmt,
**13,185** default wasm-gc tests, **26** native controls and release CLI build
pass; no public API changes. Generated native reverse-row code contains **two**
complete-header calls instead of **four**, removing the final-loop boundaries.

Native solver-row timings include scratch/cache construction but exclude CFG
construction and final SSA/defaultability finishing. Eight-branch unused-local
rows improve **3.30 → 2.95µs (10.6%)**; full metadata improves
**3.63 → 3.26µs (10.2%)**. At 256 real immutable-entry reads, **59.10 →
49.07µs (17.0%)**; a repeat gives **52.23 → 48.83µs (6.5%)**. The 256-branch
written-selector case stays flat (**807.06 → 805.60µs**), retaining repeated
writer-source traversal as a target. Shared fallback stays flat. Cold setup
initially costs **9.38 → 9.77µs (+4.16%)**, while the independent repeat gives
**9.23 → 8.96µs (−2.93%)**; preserve both, with no general cold/RSS claim.

CPU-6 enclosing cohorts use one warmup, alternating pairs and reference-drift
rejection. Artifact bytes remain exact predecessors for both passes:

| Input | Plain before → after ms | Optimizing before → after ms |
| --- | ---: | ---: |
| Small, three pairs | 3.367 → 3.998 | 9.828 → 9.723 |
| Small, seven-pair repeat | 3.438 → 3.537 | 9.766 → 9.687 |
| Large, three pairs | 3,434.435 → 3,441.126 | 6,096.471 → 6,200.555 |
| Active tee, three pairs | 2.826 → 6.810 | 103.079 → 102.583 |
| Active tee, seven-pair repeat | 2.799 → 2.774 | 103.947 → 105.208 |

Small plain repeat costs 2.88% with MAD 0.070/0.136ms; large optimizing costs
1.71% with MAD 2.397/61.716ms. Keep these costs open: component gains do not
establish an enclosing speed win. Plain tee uses raw analysis with zero HOT
lift and the first large cost does not repeat; record both rather than claiming
a causal LocalGraph regression or discarding that cohort. Small plain whole-
command instructions fall **69,208,839 → 69,124,771 (0.12%)** with exact bytes;
this is not pass-scoped allocation or RSS evidence.

Fixed replay renews **32 candidate outputs / 96 retained reference modules /
256 original-primary observations** for optimizing. An additional focused
scalar/indexed-GC loop lane validates **14 modules / 28 observations** across
original, predecessor, candidate and verified v133, both passes; result zero
and ordered tick events `[2, 1]` agree. No aggregate fuzz is claimed. The current
**210,159 canonical / 95,465 raw byte** gap retains V62's projection and stays
open. Remaining headers, source ordering, overlapping queries, optimizing setup
and broader pass gaps remain active.

Artifacts: `.tmp/dae2-flow-tags-20261001/` retains red/green logs, native controls
and repeat, matched cohorts/repeats, source manifests, generated-header budgets,
small instruction counts and runtime evidence. Candidate SHA-256:
`57f1d7986dc84888e1ea48d03b3157643d6216fb6d6b9221fcc816ed5318cf3c`.

## October 1, 2026: avoid trivial dependency-row sorting

V65 sorts the carried dependency row only when it has more than one value.
Empty/singleton rows already have exact source order. This avoids constructing
and releasing a native comparator closure and its retained facts for those
queries. Wider rows keep the original sorting and all dependency,
effect/local-state bounds, selected-row ownership and scratch reset rules.
No comparator cache or facts backpointer is added.

The bounded actual dispatcher work guard fails on V64: seven dependency calls
perform three empty-row sorts. The same active optimizing fixture afterward
performs seven queries and zero trivial sorts, with exact validated unprofiled
bytes. Generated C places callback allocation and the public/private sort call
inside the length guard. This establishes removed work, not debugger timing or
net allocated-byte/RSS savings. A new IR test compares empty/singleton/eight-value
rows with the frozen V64 query, including reversed discovery, shared consumers,
held result ownership and cleared reused scratch. A dispatcher test preserves
producer/barrier/consumer order while removing a private loop parameter.
Info/fmt, **13,187** default tests, **12** native controls and release CLI build
pass; there is no API change.

Native query means (reference → guarded) are **51.24 → 36.91ns (28.0%)**
empty/warm and **122.88 → 111.09ns (9.6%)** singleton/warm. Cold facts/scratch
setup controls are **393.83 → 368.23ns (6.5%)** empty and **645.34 → 632.25ns
(2.0%)** singleton. Eight-value controls stay near flat: warm **448.24 →
440.87ns**, cold **1.66 → 1.67µs**. All selection work is measured, rather than
sorting an isolated already-built vector.

CPU-6 matched enclosing medians (one warmup, three alternating accepted pairs,
reference bracket ≤1.15) are:

| Input | Plain before → after ms | Optimizing before → after ms |
| --- | ---: | ---: |
| Small | 3.420 → 3.354 | 9.691 → 9.635 |
| Large | 3,417.969 → 3,405.664 | 6,071.154 → 6,089.483 |
| Active tee | 2.811 → 2.739 | 104.171 → 103.739 |

Small plain improves 1.93%, optimizing 0.58%; tee plain improves 2.56%.
Large optimizing costs 0.30% with MAD 6.087/21.942ms, effectively flat;
plain improves 0.36% with MAD 2.964/5.281ms. Preserve rejected brackets and
control dispersion, with no claim of closing the compiler speed or RSS gap.
All both-pass artifact bytes remain exact predecessors. Fixed optimizing replay
renews **32 candidate outputs / 96 retained reference modules / 256**
original-primary observations. Long fuzz remains deferred.

### Reduced raw byte witnesses

Fresh load-order and changing-counter copy reductions already optimize fully
on V64 and V65. Under a verified v133 writer/strip-debug projection, Starshine
is **58 versus 60 bytes** for load order and **74 versus 76** for counter copy.
The instruction sequences match; Starshine omits an unused declaration, saving
two bytes in each. Original/predecessor/candidate/v133 replay matches **eight
modules / 20 observations**, including load traps and ordered loop consumers.
These reduced shape differences are measured Starshine wins, not open alias
parity failures. The counter's initial raw 93 versus 76 bytes includes preserved
name metadata; do not misclassify it as a transform deficit. This single-writer
reduced scope does not renew the full compiler's bounded eight-round projection.

The large raw witnesses still require structural context and raw admission
attribution. Giant structured functions can follow raw carrier cleanup or a
protected no-op; absence from HOT function traces alone does not identify which
route ran. Do not assume raw adjacent-copy counts or a small reduction proves
that missing giant cleanup is merely alias admission. The **210,159 canonical /
95,465 raw byte** compiler gap and all broader performance owners remain open.

Artifacts: `.tmp/dae2-trivial-sort-20261001/` contains red/green actual work
counts, compiled guard evidence, native controls, complete source manifests,
matched cohorts and runtime/byte probes. Candidate SHA-256:
`b1aca9be204186628e491a828853bb95d75984e5c41eb004ae00aa12131f3123`.

## October 1, 2026: checked local-access fields

V66 replaces two full HOT node-header reads with the existing checked opcode
getter: local-state child counting and source-order local-access enumeration.
Child counting still runs first, and block/loop dead-tail rules, cache ownership,
shared-node deduplication and deletion admission remain unchanged. No public API
changes. Frozen-reference IR controls and both-pass dispatcher call-order tests
pass. The actual native dispatcher guard fails before implementation (two
scoped full-header calls in seven dependency queries) and passes afterward
(zero), with exact unprofiled bytes. Compiled child counting has zero full-header
calls and retains the checked opcode getter. This proves removed header work,
not net heap or RSS savings.

Info/fmt, **13,190** default tests, eight native benchmark controls and the
release CLI build pass. Shallow/deep cold query means are **1.46 → 1.45µs**
and **20.20 → 19.66µs**; 64 repeated fresh enumerations are **21.18 → 20.19µs**
and **322.12 → 300.79µs** (4.7% and 6.6%). Repeated controls include one facts
construction per 64 queries; cold controls include construction per query.

CPU-6 matched enclosing medians, one warmup and three alternating accepted
pairs with reference brackets ≤1.15, are:

| Input | Plain before → after ms | Optimizing before → after ms |
| --- | ---: | ---: |
| Small | 3.348 → 3.440 | 9.610 → 9.666 |
| Large | 3,410.762 → 3,421.493 | 6,042.275 → 6,040.771 |
| Active tee | 3.040 → 2.750 | 104.966 → 105.193 |

Large optimizing is flat (−0.02%); plain costs 0.31%. Small plain costs
2.75% (MAD 0.017/0.065ms), optimizing 0.58%; retain these controls. Tee plain
falls 9.54% with noisy predecessor MAD 0.293ms; this raw path does not establish
a causal HOT-field gain. Rejected reference-drift brackets are retained. Both
passes preserve all artifact bytes. Fixed optimizing replay renews **32 fresh
candidate outputs / 96 retained references / 256 original-primary observations**,
without mismatches. No enclosing compiler speed win, RSS gain or fuzz signoff
is claimed. The **210,159 canonical / 95,465 raw byte** gap stays open.

The built-in giant reduction lane also exposes an extraction blocker:
`--extract-functions=7318` on validated V65 compiler output fails final validation
with `elem.funcs: invalid function index`. Neither a reduced active-table-read
fixture nor a passive `table.init` fixture reproduces it; both extract validly.
The suspected final reference-only keep-set loss remains an unconfirmed
hypothesis. Preserve table/element and compact-import remapping and final
validation while reducing the failure; do not apply a speculative fix.

Artifacts: `.tmp/dae2-access-fields-20261001/` retains native work guards, compiled
budgets, frozen source manifests, validation, matched cohorts and runtime
evidence. Candidate SHA-256:
`2732b45c7eeefb59d6fa50f33d0a09d9892a65ead03f12151ca4fd2e7462c37c`.
Extraction evidence is in `.tmp/dae2-trivial-sort-20261001/giant-probe/`.

## October 1, 2026: unblock rooted compiler byte reductions

The [extraction repair](../remove-unused-module-elements/starshine-hot-ir-strategy.md#october-1-2026-reference-only-extraction-remapping)
supersedes V66's unconfirmed keep-set hypothesis: a mixed-signature indirect-call
reduction fails first, and the actual large remapping probe finds three lost
reference-only element functions only in the final rewrite. Merging existing
used/reference keep sets repairs extraction without bypassing validation. All
13,192 default tests pass; three modules match nine fixed result/trap
observations against original and verified v133 RUME.

The large rooted module still retains a broad closure; its exported root is
function 24. Stopping at that first selected body avoids the failed artifact-wide
conditional-breakpoint campaign. Its raw SimplifyLocals result is unchanged with
reason **`call-argument-structured-release-simplify-locals-noop`**, rather than
the previously suspected giant-local or giant-carrier gate. Investigate exact
raw cleanup admission around this gate while preserving structured release
lifetimes. The 210,159 canonical / 95,465 raw byte gap stays open.

Native sampling attempts collected zero samples and provide no profile evidence;
the ordinary optimizing command completed with exact predecessor bytes. Use the
bounded admission result, not those unsuccessful sampling attempts, to target
the next byte trial. Evidence: `.tmp/dae2-extraction-20261001/`.

## October 1, 2026: index repeated singleton conflicts

V68 closes a quadratic source-order conflict family: each singleton writer
previously scanned every access of the same wide consumer, even though a
minimum-access index already existed for multiwriter queries. A scalar marker
in the immutable facts owner records the last qualifying wide consumer. Its
first singleton query retains the allocation-free scan; a repeated consumer
with more than eight accesses uses the existing minimum index. Completed
indexes remain reusable across intervening roots. Multiwriter admission keeps
its original threshold; consumers of at most eight accesses keep singleton
scans. No function backpointer, public API or cross-snapshot cache is added.

The two regressions fail first: 32 singleton writers exceed a 64-access work
bound, and the repeated consumer never acquires its index. Afterward decisions
match the frozen predicate, the repeated work is bounded by twice the consumer
width, cold/filtered writers do not allocate an index, strict minimum bounds
remain unchanged, and sibling snapshots stay independent. A third tiny-row
control retains allocation-free scans. Info/fmt, all **13,195** default tests,
ten native benchmark controls and the release CLI build pass.

Native full-query means (reference → indexed) are:

| Consumer / queries | Reference | Indexed | Change |
| --- | ---: | ---: | ---: |
| 8 / 8, cold facts | 1.76µs | 1.73µs | −1.7% |
| 64 / 64, cold facts | 20.45µs | 13.20µs | −35.5% |
| 512 / 512, cold facts | 665.20µs | 105.26µs | −84.2% |
| 64 / 64, warm facts | 10.92µs | 1.62µs | −85.2% |
| 512 / 1, cold facts | 55.38µs | 55.26µs | flat |

Cold controls include facts construction and query materialization. The initial
prototype promoted consumers above four accesses and cost **5.6%** on the
eight-access cold row (1.78 → 1.88µs). Its remaining suite/build validation was
cancelled before any candidate freeze. The refined threshold removes that
setup cost; preserve the rejected trial, rather than claiming its wider gains
justify the tiny regression.

CPU-6 matched enclosing medians, one warmup and three accepted alternating
pairs with reference brackets ≤1.15, are:

| Input | Plain before → after ms | Optimizing before → after ms |
| --- | ---: | ---: |
| Small | 3.402 → 3.398 | 9.612 → 9.705 |
| Large | 3,383.919 → 3,391.326 | 6,046.161 → 6,038.485 |
| Active tee | 2.742 → 2.758 | 102.519 → 102.132 |

Large pipelines remain flat (plain +0.22%, optimizing −0.13%). Initial small
optimizing costs 0.97%; a seven-pair repeat is **9.947 → 9.595ms (−3.54%)**,
with MAD 0.361/0.089ms and two rejected reference brackets. Preserve both
cohorts and do not infer a compiler speed win from the native scaling result.
All both-pass artifact bytes match predecessors; optimizing replay renews
**32 fresh candidate outputs / 96 retained references / 256 original-primary
observations**, without mismatches. Long fuzz stays deferred.

Whole untraced command peak RSS, CPU 6 and Linux per-process `wait4`, does not
establish a memory win. Initial plain pairs are before **266,600 / 245,428KiB**
and after **266,948 / 267,060KiB**. Three fresh plain pairs are before
**246,720 / 245,936 / 266,576KiB** and after **245,916 / 267,284 / 245,636KiB**:
both sides occupy overlapping bands, so preserve the initial high candidate
cohort without attributing a sustained increase. Optimizing is flat: before
**290,308 / 290,116KiB**, after **290,124 / 290,328KiB**. This is whole-command
peak memory, not scoped allocation bytes or proof about individual map costs.

A reduced structural-release module now reproduces an actual raw byte gap:
Starshine keeps `load; set; get-param; get-temp; compare`, while verified v133
sinks the load after the pure parameter read and removes the temporary pair.
Unlike the earlier unconstrained load reduction, this body hits the confirmed
structured-release guard. Trial bounded raw cleanup while preserving the
existing HOT lifetime guard. The full **210,159 canonical / 95,465 raw byte**
gap stays open. An additional bounded baseline sampler again records zero
samples and is not usable profile evidence.

Artifacts: `.tmp/dae2-single-writer-index-20261001/` retains red/green work tests,
rejected/refined native controls, frozen manifests, matched cohorts/repeat and
runtime evidence. Candidate SHA-256:
`974062884e5275beaef0b04da50b07e0e3cc7d5dd616f1a20a1f346c9a77127f`.


## October 1, 2026: effectful cleanup beside structured releases

V69 reduces the confirmed rooted compiler gate without removing its HOT
lifetime protection. Normal SimplifyLocals runs the existing three-round raw
effectful-suffix cleanup before returning the structured-release no-op. The
shared skipped-carrier helper accepts an effectful-only mode; other routes
retain their original cleanup sequence and the no-structure variants retain
their guard. Later reads retain a tee; crossed prefixes remain pure, with
checked, closed i32 leaves admitting nontrapping signed/unsigned i64 extension.
The generic zero-input pure-leaf classifier is unchanged.

Red-first scalar/reference/GC and dispatcher tests remove the load capture while
preserving ordered calls and distinct releases. Two additional valid reductions
expose pre-existing safety holes: nested producer reads were absent from source
facts, and legacy try/catch writes were absent from writer facts. Recursive
source collection and legacy writer collection repair both before broadening
admission; their raw relocation tests fail first and then preserve the barriers.
Direct fields/opcodes and input bytes are asserted. Info/fmt, **13,200** default
tests, three native full-module benchmark controls and the release build pass.
No public API changes or aggregate fuzz signoff are claimed.

The same verified v133 oracle/input and bounded eight-round, first-valid writer
projection as V62 produce:

| Large compiler DAE2-O | Before | After | v133 |
| --- | ---: | ---: | ---: |
| Raw bytes | 5,668,915 | 5,643,243 | 5,573,450 |
| Canonical bytes | 5,797,596 | 5,771,033 | 5,587,437 |

This saves **25,672 raw / 26,563 canonical bytes**. All **291** changed functions
shrink; no function grows and non-code sections match exactly. Code-body savings
are 25,668 bytes, including 2,817 in code index 7292 and 2,510 in 7293. The
remaining deficit is **183,596 canonical / 69,793 raw bytes**. Historical V59
and V62 projections/checkpoints remain historical; this saving does not include
writer-scope drift. Oracle canonical SHA-256:
`639d0e044fe7663b056f8f254a3376c2ee5fc4fa841f71b7ef5e572d35802ff8`.

CPU-6 matched medians, one warmup/three accepted alternating pairs with reference
brackets ≤1.15, preserve a material quality cost:

| Input | Plain before → after ms | Optimizing before → after ms |
| --- | ---: | ---: |
| Small | 3.272 → 3.322 | 9.495 → 9.580 |
| Large | 3,449.205 → 3,412.478 | 6,049.080 → 6,673.766 |
| Active tee | 2.786 → 2.791 | 103.444 → 101.485 |

Large optimizing costs **10.33%** (MAD 0.407/29.257ms). This is a size improvement,
not a speed win. Large plain's −1.06% has material spread (MAD 76.969/33.249ms).
Small plain/optimizing cost 1.53%/0.90%; tee plain is flat. Native parsed-module
cleanup scales at 16.01µs / 88.43µs / 868.58µs for 1/32/256 independent load
captures, including real full-pipeline setup; these are candidate-only costs,
not before/after gains. Target repeated compound suffix initialized-local setup,
future-read scans and recursive reconstruction next without losing these bytes.
Wide recursive source/writer deduplication also needs measured admission controls.

The retained replay lane renews **32 fresh outputs / 96 references / 256
original-primary observations**, with exact predecessor bytes. Six additional
scalar, externref, indexed-GC, nested-read and legacy-write fixtures cover
**24 modules / 480 original-primary observations**, including ordered imported
side effects, load and import traps, reference identity and release traps;
there are no mismatches. Canonical reduced i32 matches v133 at 123 bytes;
i64 and externref are two bytes smaller (124 vs 126 and 147 vs 149). Indexed-GC
is unchanged by this candidate and remains five bytes smaller (153 vs 158).
Nested-read remains a six-byte parity gap (128 vs 122); legacy-write matches at
131 bytes. Node observations and inspected relocation barriers support these
reduced wins, not universal semantic equivalence or giant compiler execution.
The runtime tool fixture needs flat legacy try and validation with all features;
earlier fixture parsing/feature failures are not optimizer failures.

Artifacts: `.tmp/dae2-release-carrier-20261001/` retains red/green tests, frozen
manifests, native costs, pairs, runtime replay and per-function byte attribution.
Candidate SHA-256:
`53c86df5492d4fc7977e4328e87873e7cf646c2854bbe2b0d3e2a5c4400bdc18`.

A corrected bounded GDB sampler records **305 samples in 7.687s**, unlike the
zero-sample earlier attempts. Putting `stop` last in the signal handler restores
stopping after `noprint`. This is descriptive whole-command sampling, not pass
wall time. The recursive effectful cleanup appears in 32 recorded frames,
compound suffix typing in three and future reads in two; allocator/drop work
and `oc_contains_local` also appear prominently. The 12-frame truncation and
single run prevent precise attribution. Retain `samples-after.json` and use
focused query controls before adopting caches.


## October 1, 2026: compact cleanup live-out membership and legacy reads

V70 replaces quadratic ordered-array deduplication in exact SimplifyLocals
cleanup with a private read-set owner. Encounter order stays in the existing
array. Rows of at most eight reads keep linear scans; wider rows cache their
first 64-local word and use sparse bitmap words for other indices. Continuations
are copied before suffix/loop accumulation, preserving original sibling reads
and next-iteration observations. Visiting one instruction no longer builds a
one-element array. No function backpointer or public API is added. A bounded
32-read regression fails at **496** comparisons before implementation and then
passes its 64-step membership bound. This counter counts comparisons/lookups,
not index construction; cold native controls include that construction.

The map-per-local prototype is rejected: cold 64 reads cost 644.63ns → 2.28µs
although 512 reads improve 33.98 → 16.99µs. Its remaining validation is cancelled
before freezing a candidate. Compact bitmap membership removes that moderate
row regression. Final reference → compact means are:

| Cold collector width | Reference | Compact |
| --- | ---: | ---: |
| 1 | 30.19ns | 43.59ns |
| 8 | 51.54ns | 81.63ns |
| 64 | 653.21ns | 435.32ns |
| 512 | 30.28µs | 11.16µs |

Wide rows improve **33–63%**. Tiny cold ownership costs **13/30ns** remain;
there is no claim of a universal cold-query win. Parsed full-module release
cleanup measures 15.70µs / 81.70µs / 779.75µs for widths 1/32/256; these are
candidate costs rather than a matched whole-module gain. Ordered uniqueness,
sparse/sign-bit/word boundaries, independent copies, original sibling reads and
loop isolation have direct field/opcode/encoded-byte tests.

A focused handler reduction exposes a real V69 admission defect: original and
v133 return **100**, while the newly enabled raw release cleanup returns **1**.
A local initialized to 99 is read only inside legacy `try`; omitted handler
read facts let exact cleanup delete that store. V70 adds legacy bodies/catches
to continuation collection, get counts and local-index bounds, and to shared
raw future read/write queries. The shared legacy access helper avoids duplicated
read-query logic. Direct top-level write predicates retain their existing
contract. Six tests fail first, including the active dispatcher; no cleanup
feature is disabled. **This supersedes any broad correctness interpretation of
V69's narrower passing replay.** The earlier unconstrained legacy reduction did
not reproduce the bug; the release context is necessary.

Info/fmt, all **13,211** default tests, eleven native controls and the release
build pass. The final replay renews 32 outputs/96 references/256 observations;
nine reduced fixtures add **36 modules / 720 original-primary observations**.
Current Starshine and v133 have zero mismatches. The frozen predecessor's
**27** legacy body/tagged-catch/catch-all result failures are retained and
classified as true semantic mismatches, rather than discarded. Tests preserve
side effects, release/produce/load traps, reference identity and input ownership.
Long fuzz remains deferred; this is not aggregate parity signoff.

Final CPU-6 matched enclosing medians, one warmup and three accepted alternating
pairs with Precompute brackets ≤1.15, are:

| Input | Plain before → after ms | Optimizing before → after ms |
| --- | ---: | ---: |
| Small | 3.287 → 3.277 | 9.724 → 9.485 |
| Large | 3,335.259 → 3,340.416 | 6,534.931 → 6,218.452 |
| Active tee | 2.783 → 2.832 | 101.192 → 103.222 |

Large optimizing improves **4.84%**, saving 316ms (MAD 4.993/0.097ms);
plain is flat (+0.15%). Small optimizing improves 2.46%; tee costs 1.76% plain
and **2.01% optimizing**, which stay open. All both-pass compiler/tee bytes
match the predecessor. The 183,596 canonical / 69,793 raw byte deficit remains;
all V69 savings are retained. The compiler input has **zero legacy try opcodes**,
so those matched workloads do not exercise the broken predecessor family.
Do not use the predecessor as a correctness baseline on handler modules.

The fully measured pre-handler-fix bitmap candidate is preserved separately:
large optimizing 6,733.663 → 6,344.130ms (−5.78%). Its initial noisy small
optimizing cohort costs 14.89% (MAD 1.292/3.230ms); a seven-pair repeat is
9.756 → 9.615ms (−1.45%). Tee optimizing changes −1.39% initially and +2.00%
on repeat; plain tee costs +3.05% on repeat. Preserve rejected brackets and
these control costs. That candidate fails the targeted handler fixture and
is not the final signoff source.

Contemporaneous verified v133 medians are descriptive, collected separately
with CPU 6, one warmup/three samples and the same reference bracket bound;
Starshine pass timers below exclude its outer command pipeline timer:

| Pass | Small Starshine / v133 ms | Ratio | Large Starshine / v133 ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| `dae2` | 3.249 / 0.900 | 3.61× | 3,323.086 / 420.700 | 7.90× |
| `dae2-optimizing` | 9.457 / 2.966 | 3.19× | 6,200.991 / 1,601.650 | 3.87× |

These are current gaps, not alternating oracle causal comparisons or speed
parity. The added V69 quality cost is only partly recovered; a same-cohort
cumulative comparison is still required. Whole-command peak RSS via per-process
Linux `wait4` is before 294,264/294,384KiB and after 304,564/294,236KiB. One
candidate run enters the higher historical band; this does not prove a sustained
memory gain or regression. An earlier bitmap cohort has the opposite high
outlier (before 304,468/294,308, after 294,384/293,956KiB).

A bounded native probe on a valid non-legacy release fixture observes **275
successful scoped UInt64 map lookups**; generated C allocates an optional box
for each. This is a remaining allocation target, not an allocation-free map
claim. Trial unboxed overflow words and reduce tiny owner overhead next, while
preserving the wide wins and legacy repair. Repeated ancestor/subtree scans,
compound suffix mask setup, dependency/lift/lower and validation still remain.

Final artifacts: `.tmp/dae2-liveout-membership-legacy-20261001/`.
Rejected/provisional evidence and the allocation probe:
`.tmp/dae2-liveout-membership-20261001/`. Final candidate SHA-256:
`459db6d64486a20a5037cccc4ecee9d7ec0d2ec46c55de9a669f1497715d1826`.


## October 1, 2026: unboxed cleanup overflow membership

V71 keeps the first cached 64-local word and changes only sparse overflow to
32-bit `UInt` words. Native `Option[UInt]` returns unboxed; the former
`Option[UInt64]` allocated a `Some` for each successful lookup. A bounded native
probe on the same valid release fixture fails its zero-box guard on V70 with
**275** successful boxed lookups. The frozen candidate records **zero boxed /
275 unboxed** scoped lookups; the boxed getter is absent from the binary and
the generated unboxed getter has no allocation. This proves removal of this
specific option allocation, not an allocation-free cleanup or map. More overflow
buckets can be retained, so map construction and whole-command RSS remain costs.

The new regression fails first at a 32-bit overflow boundary. Direct fields and
ordered reads cover bit 31, bucket boundaries, sparse positive/negative ids and
absent neighbours. Info/fmt, **13,212** default tests, eleven native controls and
the release build pass. All 256 retained plus 720 reduced original-primary
observations match, including legacy handlers. Compiler/tee outputs are exact
predecessor bytes; all code bodies and non-code sections remain identical.
The **183,596 canonical / 69,793 raw** byte gap is unchanged.

Cold native 512-read collection is **7.54µs**, against the frozen quadratic
reference's 30.54µs. The previous compact candidate measured 11.16µs in a
separate cohort; that is not an alternating causal comparison. The 64-read
candidate is 451.03ns versus the preceding cohort's 435.32ns. Parsed module
widths 1/32/256 cost 15.84/82.43/783.48µs. Tiny ownership costs remain open.

Initial three-pair enclosing cohorts are small plain/O +5.87%/+2.09%, large
plain/O +1.66%/−1.05%, tee plain/O +1.21%/−7.74%. Preserve those results rather
than selecting the attractive tee cohort. Focused repeats use seven accepted
pairs on small/tee and three on large, CPU 6, alternating order, one warmup and
Precompute brackets ≤1.15:

| Input | Plain before → after ms | Optimizing before → after ms |
| --- | ---: | ---: |
| Small | 3.283 → 3.286 | 9.510 → 9.653 |
| Large | 3,342.036 → 3,324.937 | 6,242.090 → 6,191.777 |
| Active tee | 2.794 → 2.832 | 102.481 → 103.718 |

Large optimizing improves **0.81%** (MAD 3.924/20.068ms), confirming a modest
benefit alongside the scoped allocation removal. Small/tee optimizing cost
**1.50%/1.21%**, plain tee costs 1.36%; those control gaps stay active. There is
no whole-pipeline speed-parity claim. Per-process `wait4` large untraced peaks
are before 294,220/294,416KiB and after 294,188/294,324KiB, effectively flat.

Frozen local artifacts are `.tmp/dae2-unboxed-overflow-20261001/`, including
red-first native/field logs, generated-C proof, allocation counters, both timing
cohorts, rejected brackets, replay, exact function bytes and RSS. Candidate SHA256
is `ef10a376429a074af6649782b3b6e0be57844863d17b673d05be2d9ec006d87b`.
Long fuzz remains deferred. Repeated ancestor scans, compound suffix typing,
dependency planning/lift/lower, validation and byte cleanup remain active.


## October 1, 2026: demand only unresolved DAE2 read sources

V72 extends `local_graph_build_read_sources` with an optional arena-sized
`selected_gets` mask. DAE2 already resolves unwritten locals and proven entry or
sole-write reads independently; it now requests LocalGraph rows only for its
remaining unresolved reads. Complete action/write admission, CFG joins,
exceptional edges and writer facts stay intact. Unselected rows publish empty
unknown results. Shared-action/hidden-control fallback still solves complete
forward joins before projecting rows. Default full read-source and full graph
APIs retain their complete facts. The mask is borrowed during construction and
never mutated or retained; analysis uses one immutable HOT snapshot. Unknown
selected reads retain the original conservative parameter/all-writes fallback.

The red-first ordered-row regression fails **2 != 0** before selection. Tests
compare every selected source with the complete solver in both operand modes,
cover loops, reference writes, exceptional joins and shared-action fallback,
and preserve masks/revisions. A DAE2 fixture selects one unresolved read while
excluding proven selectors; dispatcher tests retain both required parameters
and remove the third argument. The `.mbti` diff adds only the optional mask.
Info/fmt, **13,216** default tests, eight native controls and the release build
pass. Existing 256 observations plus ten reduced fixtures / 40 modules / 800
original-primary observations match current Starshine and verified v133.
Compiler/tee bytes match the predecessor; every code body and non-code section
is exact. No transformation is skipped to obtain the gain.

Cold native controls include selection construction and all solver scratch;
CFG/HOT construction is excluded equally:

| Resolved selector reads | Complete sources | Selected sources |
| --- | ---: | ---: |
| 1 | 794.66ns | 753.75ns |
| 32 | 23.05µs | 5.87µs |
| 256 | 1.11ms | 41.67µs |
| 32, all requested | 22.95µs | 23.23µs |

Resolved-heavy rows improve **75–96%**; the all-requested control costs 1.22%.
These are solver/query controls, not compiler-wide speedups. A bounded native
probe on the first 64 large-compiler mask builds records **7,162 arena read
nodes / 5,992 selected reads**, 16.3% fewer selected rows. Arena reads include
unrepresented nodes, so this is not an exact removed-predecessor-query count or
a whole-module density claim. An attempted full-command debugger count hits
its 40-second cap; retain that failure and use the bounded prefix instead.

CPU-6 matched enclosing medians, one warmup, alternating pairs and Precompute
brackets ≤1.15, are:

| Input | Initial plain/O before → after ms | Repeat plain/O before → after ms |
| --- | ---: | ---: |
| Small | 3.265 → 3.296 / 9.431 → 9.489 | 4.502 → 4.427 / 13.742 → 13.370 |
| Large | 3,327.323 → 3,247.192 / 9,018.616 → 8,886.199 | 3,805.958 → 3,665.336 / 9,137.385 → 9,020.818 |
| Active tee | 2.949 → 2.962 / 105.154 → 103.784 | 2.944 → 2.969 / 104.859 → 106.606 |

Initial cohorts use three accepted pairs; repeats use seven on small/tee and
three on large. Large plain improves **2.41%**, repeated **3.69%**; optimizing
improves **1.47%**, repeated **1.28%**. Host bands and optimizing spread are
higher than V71 (initial optimizing MAD 216.050/356.265ms; repeat 61.861/86.999ms),
so do not compare their absolute times causally across commits. Small cohorts
change sign (+0.95%/+0.61% initially, −1.67%/−2.71% on repeat); tee optimizing
changes −1.30% initially to **+1.67%** on repeat, which remains an open control
cost. Preserve all rejected reference brackets. Per-process `wait4` untraced
peaks are before 294,276/294,208KiB and after 294,212/304,472KiB: one higher
candidate band, no established sustained RSS gain/regression.

Canonical byte attribution now confirms 183,470 of the **183,596** module-byte
deficit is in code bodies. Largest remaining deficits are code indices 7292
(**5,517 bytes**), 10435 (4,565), 4101 (2,292) and 7294 (2,193). This is the same
bounded eight-round first-valid writer projection and verified oracle, with
12,904 matching function indices. Raw deficit remains **69,793**. Reduce the
six-byte nested-read witness and writer-added captures next; overall speed,
output quality and other pass gaps remain open. Long fuzz stays deferred.

Frozen local evidence is `.tmp/dae2-selected-flow-20261001/`, including red,
validation, cold controls, both matched cohorts, density cap/retry, replay,
function bytes, canonical attribution and RSS. Candidate SHA256 is
`71d5810cfa49bfacdc5cc023eea37cccdb57d95cc8877f1f5e527727c30bb486`.


## October 1, 2026: sink constant stores beside structured releases

V73 closes the six-byte nested-read failure in the guarded release cleanup:
Starshine retained a parameter snapshot before assigning a constant, while
v133 compared the original parameter first and used a constant tee at the
later call argument. Three red-first helper/pass/dispatcher assertions fail
before implementation (missing rewrite and wrong initial local read).

The effectful raw cleanup now sinks i32/i64/f32/f64 constant stores to their
first flat read, retaining the assignment as a tee for later reads. One forward
scan tracks pending stores; writes invalidate the target, and calls, traps,
throws and structured control invalidate the prefix with an O(1) instruction
index epoch. No per-store suffix search or repeated map clear is used. Nested
block/loop/if/try-table bodies are handled independently; legacy handlers stay
opaque. The HOT release-lifetime guard remains. Only this guarded raw lane
changes; unrelated cleanup admission is unchanged. Lazy records use unboxed
8-byte value elements, and native Int map lookups do not allocate Option boxes.
Unchanged bodies retain their original arrays.

Tests cover all four numeric scalar types, repeated reads, target clobbers,
independent siblings, intentionally blocking calls/division/load/truncation,
control/unreachable, linear scan visits, source ownership and module validity.
Info/fmt, **13,222** default tests, eleven focused native rows and release build
pass. Existing replay contributes 256 observations; fourteen reduced fixtures /
56 modules contribute another 1,120 original-primary observations, including
observable calls and traps. Current Starshine and verified v133 match originals.
This bounded evidence does not replace the deferred aggregate GenValid signoff.

| Reduced canonical bytes | V72 | V73 | v133 |
| --- | ---: | ---: | ---: |
| Nested release read | 128 | 122 | 122 |
| Observed i32 constant | 135 | 129 | 129 |
| Observed i64 constant | 141 | 133 | 135 |
| Observed f32 constant | 144 | 136 | 138 |
| Observed f64 constant | 148 | 140 | 142 |
| Legacy release body | 135 | 135 | 131 |

Three scalar reductions win two canonical bytes; the legacy body retains a
four-byte parity gap. An equal-size unused-local declaration difference is
not independently established as a performance win. On the compiler, 105
functions shrink with no growth or non-code changes. Raw bytes fall from
5,643,243 to **5,639,963**; bounded eight-round first-valid canonical projection
falls from 5,771,033 to **5,767,581**. Against the unchanged verified-v133 oracle,
the remaining deficit is **180,144 canonical / 66,513 raw bytes**. Largest raw
savings include function 7292 (1,470 bytes), 7293 (525) and 7294 (459).

Native cold controls compare two implementations of this new feature, not
shipped-predecessor performance: the test-only reference performs naive
per-store suffix search. Parsing is excluded; pending storage and rewrite
allocation are included. Eight pending stores cost 320.30 → 474.77ns; 32
improve 2.50 → 1.82µs; 512 improve 465.87 → 29.61µs. A blocked 32-store row
costs 1.09 → 1.75µs. Tiny/barrier scratch costs remain active next targets.
Parsed whole-module widths 1/32/256 cost 16.56/84.21/821.66µs; comparisons
against earlier nonalternating benchmark cohorts are not causal.

CPU-6 enclosing pairs use one warmup, alternating order and reference
Precompute brackets ≤1.15. Initial cohorts have three accepted pairs:

| Input | Plain before → after ms | Optimizing before → after ms |
| --- | ---: | ---: |
| Small | 3.413 → 3.413 | 9.759 → 9.735 |
| Large | 3,347.070 → 3,336.522 | 6,278.684 → 6,310.901 |
| Active tee | 2.790 → 2.774 | 102.195 → 105.410 |

The large optimizing +0.51% quality cost remains open (MAD 18.694/2.670ms).
The seven-pair tee repeat is plain 2.868 → 2.825ms and optimizing
103.757 → 104.542ms (+0.76%, MAD 1.577/1.461ms), much less than the initial
+3.15% and inside its spread. A bounded complete-command native probe counts
**zero constant-sink helper calls on active tee**; its valid output exactly
matches the frozen measured output. Therefore tee's timing difference is not
attributed to pending-map work; code layout/host effects remain uncertain.
Retain both cohorts and rejected reference brackets. Per-process wait4 large
peaks are before 294,456/294,204KiB and after 304,604/294,284KiB, one higher
band with no established sustained RSS change.

Frozen local evidence is `.tmp/dae2-constant-tee-20261001/`, including red-first
logs, field/encoded-byte fixtures, native layout, both timing cohorts, complete
tee call count, runtime replay, per-function bytes, canonical projection and
RSS. Candidate SHA256 is
`2665b582cf027fb8253a3398ae5da3d2e718c84da235d7fe460ff2f130d3db97`.
Overall speed/byte parity and all other pass owners remain open; long fuzz stays
deferred while performance work continues.


## October 1, 2026: bounded primitive constant-store pending rows

V74 removes dense pending-map construction while retaining every V73 constant
tee. A cheap candidate-only census returns unchanged bodies immediately when
there are no stores. Dense rows use one Int array, bounded by 4,096 slots and
eight slots per candidate; sparse/high-index rows retain the map. This storage
choice never limits transformation coverage. A current-candidate count skips
read/write lookup and operand classification after all candidates are consumed
or invalidated. Barriers still invalidate a complete prefix in O(1) via its
instruction index, without clearing retained buckets.

A native reduced-release allocation guard first fails with **one pending map**,
then passes with **zero**, across three flat helper calls. Operand classifier
calls fall six → one; probe outputs are valid and byte-identical. Initial
constructor-wrapper probes incorrectly counted zero because native inlining
removed those calls. Disassembly identifies the surviving `new_map` and raw
operand-classifier boundaries; the corrected red baseline is retained. These
are bounded scoped counts, not whole-command allocation or timing claims.

Focused tests compare sparse/high-index writes, repeated clobbers, inactive
prefixes and reactivation with the frozen shipped V73 map implementation. They
preserve later reads, original arrays/encoded bytes and valid rewritten modules.
The existing linear work guard now includes the census: two body walks on
blocked rows and three including output emission on transforming rows.
Info/fmt, **13,224** default tests, nineteen native rows and release build pass.
All **1,376** original-primary fixed observations pass; all 32 retained replay
outputs and compiler/tee outputs match the predecessor exactly. Canonical
compiler deficit remains **180,144 bytes**, raw **66,513 bytes**.

Cold native controls include all census/storage/rewrite allocation and compare
the frozen shipped V73 implementation, unlike V73's naive new-feature prototype:

| Pending stores | V73 map | V74 adaptive |
| --- | ---: | ---: |
| 1 | 134.30ns | 107.46ns |
| 8 | 479.13ns | 327.71ns |
| 32 | 1.78µs | 1.16µs |
| 512 | 30.19µs | 15.99µs |
| 32, blocked | 1.80µs | 648.27ns |
| 32, sparse | 2.00µs | 2.17µs |
| No-work, 8 arithmetic groups | 71.62ns | 44.76ns |
| No-work, 512 groups | 3.51µs | 1.86µs |

Dense rows improve **20–47%**, blocked **64%**, no-work **38–47%**. Sparse
control costs **8.5%** and remains active; further changes must preserve sparse
coverage and the bounded dense capacity. Parsed whole-module controls measure
16.60/91.54/896.26µs at widths 1/32/256; prior nonalternating cohorts are not
causal comparisons.

CPU-6 enclosing cohorts use one warmup, alternating pairs and Precompute
brackets ≤1.15. Initial three-pair results and seven-pair small/tee repeats are:

| Input | Initial plain/O before → after ms | Repeat plain/O before → after ms |
| --- | ---: | ---: |
| Small | 3.494 → 3.579 / 10.881 → 10.085 | 3.493 → 3.525 / 10.301 → 9.953 |
| Large | 4,755.853 → 4,851.182 / 6,927.918 → 7,020.972 | Not repeated |
| Active tee | 3.739 → 4.132 / 158.835 → 157.972 | 3.017 → 3.272 / 104.730 → 104.584 |

Small optimizing improves **3.38%** on repeat. Large optimizing costs **1.34%**,
with MAD 88.464/103.673ms and materially higher host bands; no compiler speedup
is established. Repeated plain tee costs **8.45%** with MAD 0.129/0.323ms,
while optimizing stays flat (−0.14%). This helper is not called by plain DAE2
or active tee, so those controls cannot be attributed to its pending-row work;
code layout/host effects remain unresolved. Retain both cohorts and rejected
brackets. Per-process wait4 large untraced peaks are before
294,364/294,292KiB and after 294,156/294,500KiB, effectively flat despite
widely varying wall times.

Frozen local evidence is `.tmp/dae2-dense-constant-pending-20261001/`, including
corrected red/green allocation probes, exact-output validation, native controls,
both timing cohorts, runtime replay, canonical bytes and RSS. Candidate SHA256:
`80ee89f8d441afb39dfe3a478d26220ab14ec74597220b24206830f43a50b3d4`.
Unchanged continuation-array/control reconstruction, compound suffix typing,
HOT dependency/lift/lower and remaining byte families stay active. Long fuzz
remains deferred; this is not overall speed/size parity signoff.


## October 1, 2026: borrow unchanged continuation-cleanup storage

V75 removes unconditional array and control-shell reconstruction from
`sl_cleanup_drop_dead_pairs_with_reads`. A child returns its original body when
unchanged; its block/loop/if/try-table shell is then retained. Parents copy once
at the first changed child, and the flat output is allocated only at an actual
tee/drop or set/get rewrite. Original continuation reads, independent loop
facts, normalized later-read checks and all active rewrites remain unchanged.
The two production callers treat results as read-only: raw admission wraps a
changed body, and exact cleanup builds fresh downstream output. No pass or
candidate is skipped to obtain the gain.

Two red-first ownership assertions fail on the predecessor: unchanged bodies
are copied, and an unchanged sibling shell is rebuilt. Tests cover scalar/GC
bodies, block/loop/if/try-table, changed-parent ownership, source encoded bytes,
NaN payloads and signed zero. Existing loop/original-sibling/legacy regressions
pass. Dispatcher checks preserve the result and remove dead nested captures
in DAE2-O and SimplifyLocals. Its first expectation incorrectly required
Vacuum's complete dropped-constant cleanup from standalone SimplifyLocals;
predecessor replay confirms the distinct contract, and direct field assertions
replace that expectation. This is not a newly implemented cleanup family.
Info/fmt, **13,228** default tests, twelve native rows and the release build pass.
All **1,376** original-primary observations match current/v133/original results,
events and traps. Every compiler body, non-code section and canonical byte is
identical to V74; the **180,144 canonical / 66,513 raw** deficit remains.

Cold controls include all helper scratch and output allocation, with parsing
excluded equally. The reference is the frozen shipped V74 implementation:

| Body | Rebuild | Borrow |
| --- | ---: | ---: |
| One unchanged flat group | 96.89ns | 47.30ns |
| 256 unchanged flat groups | 9.45µs | 3.75µs |
| 32 unchanged blocks | 3.41µs | 1.22µs |
| 32 unchanged chains, depth 16 | 83.85µs | 56.60µs |
| 32 actively changed blocks | 3.77µs | 2.82µs |
| 32 active distinct flat captures | 3.44µs | 3.48µs |

Unchanged rows improve **51–64%**, deep chains 32%, active blocks 25%. Active
flat captures remain flat within spread and still perform repeated suffix
queries; they are the next quadratic-work target. The ownership optimization
does not close ancestor/subtree rescans or compound suffix typing.

CPU-6 enclosing pairs use one warmup, alternating order and reference brackets
≤1.15. Initial three-pair cohorts and repeats (seven small/tee, three large):

| Input | Initial plain/O before → after ms | Repeat plain/O before → after ms |
| --- | ---: | ---: |
| Small | 4.040 → 3.564 / 10.306 → 10.079 | 3.887 → 4.125 / 11.852 → 11.490 |
| Large | 3,694.509 → 3,587.106 / 6,765.026 → 6,945.417 | 4,138.310 → 4,039.284 / 7,633.275 → 7,402.170 |
| Active tee | 2.949 → 3.008 / 105.752 → 108.036 | 3.170 → 3.219 / 113.769 → 115.308 |

Large plain improves **2.91%**, repeated **2.39%**. Optimizing changes from an
initial +2.67% to repeated **−3.03%**, with higher host bands and candidate MAD
149.435ms; retain both rather than presenting a universal compiler speedup.
Small plain changes sign and its repeat has substantial spread; small
optimizing repeats −3.05%. Tee optimizing still costs **1.35%** on repeat
(MAD 1.109/0.239ms), and stays active. Preserve rejected reference brackets.
Per-process wait4 large untraced peaks are before 304,464/294,232KiB and after
294,344/293,928KiB. One higher predecessor band is not a general RSS win.

Frozen evidence is `.tmp/dae2-cleanup-borrow-20261001/`, including red ownership
failures, caller/dispatcher review, exact byte fixtures, native controls, both
matched cohorts, runtime replay, canonical projection and RSS. Candidate SHA256:
`a6b51665ea38ac7537f6e8b7e4e956766c27869c3f7f15ea6a880ba566da8804`.
All broader speed/output and other-pass gaps remain open; long fuzz is deferred.


## October 1, 2026: bound repeated normalized future-read queries

V76 replaces repeated suffix searches in adjacent-capture cleanup with private
facts for one immutable normalized body. Up to eight actual eligible queries
retain the previous Boolean search. A repeated wide body publishes one reverse
Boolean mask only when the queries include a dropped tee or distinct local IDs.
The threshold controls scratch, never rewrite eligibility. Tiny bodies and
bodies without candidates retain the original path.

Repeated root-get queries for the same local stay on that original path: each
search stops at the next queried get or an earlier read/terminator. Their search
intervals are disjoint, so their total work is linear even when the local has
many writes. A tee is a write, not a read, and does not have this proof. Mixed
queries can spend eight complete input traversals before mask publication; the
mask adds one reverse root traversal and independent nested-prefix collection.
The flat fixture requires at most twelve times its input length. Ancestor and
subtree revisits across separate cleanup owners remain open.

The predecessor-style helper fails the final bounds with **2,016 visits** for
32 distinct captures and **1,488 visits** for 32 dropped tees of one local.
`gated-red.log` confirms both failures before the final implementation. Every
fixture also checks exact transforms against frozen V75, validates rewritten
modules, and checks original encoded bytes. Same-local gets retain a tighter
two-times-input guard. Direct and masked query controls cover direct/nested
terminators, independent if arms, loops, legacy bodies and both catch forms,
scalar locals and a non-null GC parameter. Held-mask/source ownership and the
active dispatcher retain their behavior. The mask identity control was already
green; it is not a claimed new boxing failure.

Mask construction collects reachable prefixes independently, preserving direct
terminator segments and unreachable debris after them. The broader original
continuation collector is unchanged, including loop-carried and legacy reads.
Facts never outlive the immutable normalized body; output splices do not mutate
it. The production query returns a Boolean and retains no budget/value owner;
recursive work accounting is used only by the optional focused-test counter.

Rejected first prototype:
`.tmp/dae2-future-read-mask-20261001/`, SHA
`f54b46ba0fd0e6d8348f7ce330ed3056169403c2f4ff1b250772dbea706cdbee`.
It passes 13,231 tests, twelve native rows and 1,376 observations with exact
bytes. Distinct 32/512 captures improve 3.32 → 2.30 µs /
597.71 → 40.20 µs, but reused 32 captures cost 1.30 → 1.44 µs.
Tiny/unchanged controls cost 2.15 ns / 140 ns. Three-pair compiler plain/O
costs 2.19%/2.58%, small O 2.69%; tee O improves .88%. Peak RSS is
295,788/294,288 KiB before versus 294,336/294,180 after. These costs prevent
acceptance based on the wide microbenchmark alone.

Rejected value-counter prototype:
`.tmp/dae2-value-future-read-20261001/`, SHA
`6818b116ff326085b246841b477c442960da919b390e3a50f0cbf167ee7db1fb`.
Value records remove both heap budget objects, and the generated constructors
allocate neither record. It passes 13,232 tests, twelve native rows and 1,376
observations with exact bytes. Distinct 32/512 captures improve
3.39 → 2.32 µs / 713.07 → 45.10 µs, reused 32 costs 70 ns;
small O costs 1.50%, large plain/O 7.05%/1.44%, tee plain/O 5.40%/2.37%.
The contended host cohorts and rejected samples remain intact. A complete native
compiler probe observes only three mask builds (52/36/67 roots, 155 total),
with exact measured output. That is a mask-boundary count, not total query work
or whole-pass attribution. It supports removing recurring counter/result work
from ordinary queries, rather than attributing the artifact cost to large masks.

Final V76 evidence is under `.tmp/dae2-gated-future-read-20261001/`, SHA
`8d9d3491c2e29b58c9c49602b362b8531e4e8beda77473cd4af2d0d37ce11a96`.
`moon info`, formatting, focused/default wasm-gc tests, release CLI and all
fourteen native rows pass: **13,233 default tests and 1,376 fixed observations**.
Public `.mbti` files are unchanged. Raw/canonical bytes, every code body and
non-code sections remain exact V75. The deficit stays **180,144 canonical /
66,513 raw** against the same hash-verified v133 oracle and large input.

Native rows include complete cold fact construction and held-input validation;
parsing is outside both timed implementations. The reference is frozen V75:

| Shape | Predecessor | V76 | Interpretation |
| --- | ---: | ---: | --- |
| 1 distinct capture | 78.56 ns | 85.23 ns | +6.67 ns remains open |
| 32 distinct captures | 3.26 µs | 2.77 µs | −15.0% |
| 512 distinct captures | 609.94 µs | 48.70 µs | −92.0% |
| 32 same-local captures | 1.33 µs | 1.36 µs | +30 ns remains open |
| 512 same-local captures | 19.69 µs | 20.50 µs | +810 ns remains open |
| 512-width single query | 4.94 µs | 5.17 µs | +230 ns; σ .148/.218 µs |
| 512 unchanged expressions | 7.51 µs | 7.68 µs | +170 ns remains open |

The first matched three-pair compiler plain/O medians are
3,661.001 → 3,766.130 ms / 6,849.027 → 7,003.186 ms (+2.87%/+2.25%).
Small plain/O improves .93%/1.89%, tee plain improves 7.70%, tee O costs .40%.
The repeated three-large/seven-small/seven-tee cohort retains the initial costs:
large plain/O is 4,307.866 → 4,331.162 / 8,234.145 → 8,334.516 ms
(+.54%/+1.22%), with MADs 21.012/129.955 and 41.072/115.411 ms.
Small plain improves 1.91%, O stays flat (−.21%); tee plain costs 2.41%
with MAD .030/.071 ms, O stays +.40% with MAD 1.232/1.288 ms.
Different host bands and all drift-rejected samples remain in the evidence.
These are enclosing `cmd:main-pipeline` medians, not pass-only v133 ratios.
The wide query mechanism is closed; cumulative compiler/control speed is not.

The final complete native mask-boundary probe observes **zero builds** on the
large optimizing artifact, with exact measured output. This cannot attribute
its timings to indexed masks, and does not count all query work. The initial
probe wait cap expired before evidence completed; its retried thirty-second
probe completes. Peak RSS is 294,232/304,384 KiB before and
294,472/294,440 after; one predecessor band is higher, not a universal RSS win.

A semantic-only predecessor stage inspection under
`.tmp/dae2-legacy-stages-20261001/` retains the four-byte quality target:
after SimplifyLocals, the numeric assignment is `const 99; tee 5; drop` and its
later read is still inside legacy try. Final Vacuum exposes the remaining
root get/set copy. Constant/sole-writer cleanup must preserve legacy reads and
caught traps; this remains separate from the byte-identical V76 change.
Long fuzz and full parity signoff remain deferred until performance work is lean.


## October 1, 2026: admit only needed root cleanup scans

V77 replaces the child-only callback admission scan with one direct root scan
for child controls and local writes. Neither present means the adjacent-pair
helper returns its original body immediately. Flat bodies with writes retain
all pairing and suffix queries but omit the no-op normalization traversal.
Bodies with children retain the original reverse normalization and original
continuation facts. Root-control shells remain control shells after child
cleanup, so a body without root sets/tees can return its normalized child
rewrites without an additional flat scan. No eligible rewrite is removed.

The red regression records **384 root visits for 128 unchanged instructions**
and fails a one-pass bound. The fixture validates modules, checks source
encoded-byte ownership, compares exact transforms to frozen V76, and also
covers unchanged children and 32 independently active nested captures. Additional
controls retain imported effects, GC reads, legacy scopes and active dispatcher
results. The counter counts actual root traversal work for its owner, not all
recursive descendants or whole-pass instruction counts.

Frozen evidence lives under `.tmp/dae2-no-write-cleanup-20261001/`;
V77 native SHA-256 is
`97660e9b050c2d0dd5b26137985d3e8166847ae042711fb41e1f5d29bab3cf16`.
`moon info`, formatting, focused tests, all **13,236** default tests, native
release and twelve native benchmark rows pass. The original-primary runtime
checks cover 1,376 observations with no mismatches. Compiler raw/canonical
bytes, individual function bodies and non-code sections are exactly V76;
the v133 deficit remains **180,144 canonical / 66,513 raw bytes**.

| Native control | V76 → V77, repeated mean | Change |
| --- | ---: | ---: |
| Flat unchanged width 1 | 43.59 → 34.10 ns | −22% |
| Flat unchanged width 256 | 3.76 → 1.50 µs | −60% |
| Unchanged width 32 depth 1 | 1.25 → .908 µs | −27% |
| Unchanged width 32 depth 16 | 58.16 → 56.53 µs | −2.8% |
| Active width 32 depth 1 | 2.80 → 2.71 µs | −3.2% |
| Active flat width 32 | 2.67 → 2.52 µs | −5.6% |

Retain the initial depth-16 **56.04 → 59.82 µs (+6.7%)** alongside its repeat;
that deep control is dispersed, not a proved speed win. Initial three-pair
small plain/O medians are 3.713 → 3.599 / 10.312 → 10.474 ms
(−3.07% / +1.57%); large 4,383.388 → 4,439.762 /
8,301.410 → 8,363.515 ms (+1.29% / +.75%); tee
3.197 → 3.145 / 104.025 → 105.184 ms (−1.63% / +1.11%).
Repeat seven small/tee and three large pairs: small
3.821 → 3.786 / 10.337 → 10.493 ms (−.92% / +1.51%);
large 4,502.593 → 4,468.987 / 8,405.524 → 8,188.942 ms
(−.75% / −2.58%); tee 3.078 → 3.150 / 103.782 → 103.407 ms
(+2.34% / −.36%). All drift-rejected samples and the differing host bands
remain preserved. These are enclosing pipeline timings, not v133 pass-local
ratios. Small optimizing, plain tee, deep controls and cumulative performance
remain open. Per-child peak RSS is 304,640/294,256 KiB before and
294,216/294,048 after; this is not a universal allocation/RSS win.

The redundant root traversals are closed, while ancestor continuation scans,
remaining query admission costs and byte parity remain active. Long fuzz
remains deferred under the user's focused-performance instruction.


## October 1, 2026: propagate sole root numeric captures

V78 adds numeric-literal propagation to the already-admitted effectful raw
SimplifyLocals carrier lane, after its existing exact cleanup. It recognizes
root literal/set and literal/tee/drop, including exact void blocks containing
only those instructions. One complete census includes unreachable tails,
loops, both arms, try-table bodies and all legacy handlers. A candidate needs
exactly one static writer; only reads in later root instructions are replaced.
The root writer dominates those instructions, including their descendants.
Earlier reads keep parameter/default values. Literals have no effects or
traps, and other instructions retain order. Reference producers are excluded.

Reuse original literal objects to retain precise NaN payloads and signed zero.
Candidate-size budgets use signed LEB widths for integers, fixed float widths,
unsigned local-index widths and exact removed block/tee/drop overhead. Reject
encoded growth; saturating small budgets cannot overflow with many reads.
Candidate storage is lazy and proportional to candidates, with no dense
high-local-index row. Rewriting borrows unchanged arrays and control shells.
No broader release lifetime guard is relaxed and plain DAE2 is unchanged.

Red-first helper tests fail on nested scalar/legacy/loop reads; the dispatcher
still starts with a block containing the captured 99. Focused tests cover all
numeric types, imported effects, loads, earlier reads, legacy body/tagged and
catch-all reads, nested loops/arms, exact float representations, signed/unsigned
LEB boundaries, try-table descendants, clobbers (including unreachable writes),
reference exclusion and intentional size-growth rejection. The existing legacy
read regression now asserts the retained 99 directly in the try body rather
than requiring its obsolete source-local location.

Frozen evidence lives under `.tmp/dae2-root-constants-20261001/`, native SHA-256
`15fb136e0105e4166ec1ce5857050e73ddee978feb4d3fc71356a1d01b6200d0`.
Info, formatting, 27 focused checks, all **13,248** default tests, native release,
seven native benchmark rows and 1,376 original-primary observations pass.
Remote CI test repairs were merged before this suite; no public API changes.
Compiler raw bytes **5,639,963 → 5,639,081**, canonical
**5,767,581 → 5,766,650**: save **882 raw / 931 canonical bytes** in
**87 shrinking functions**, no growing functions or non-code section changes.
The remaining verified-v133 deficit is **179,213 canonical / 65,631 raw bytes**.

The legacy body witness closes **135 → 131** canonical bytes against v133's
131. Tagged-catch **150 → 146** and catch-all **149 → 145** beat v133 by
four bytes each. This is a measured Starshine size win: root dominance plus
one complete static-writer proof preserve literal values through every handler;
fixed replay matches original and v133 results, trap behavior and events.
Validation or smaller bytes alone would not establish that conclusion.

| Native helper control | Mean |
| --- | ---: |
| No candidates, width 1 / 256 | 15.32 ns / 1.66 µs |
| Active width 1 / 32 / 256 | .317 / 4.03 / 33.35 µs |
| Sparse local 8192 | .279 µs |
| Rejected float growth | .186 µs |

These are new work costs, not predecessor speedups. Generated native C stores
candidate records by value and cold admission initializes owner pointers to
null; it creates no temporary candidate tuple. This does not count all pipeline
allocations. Initial matched three-pair small plain/O medians are
3.325 → 4.844 / 9.594 → 9.955 ms (+45.68% / +3.76%); plain has
1.567 ms after MAD and never calls this helper. Retain that dispersed control.
Large is **3,314.544 → 3,300.903 / 6,188.633 → 6,189.203 ms**
(−.41% / +.01%): size savings with flat optimizing time. Tee is
2.744 → 2.754 / 100.358 → 102.129 ms (+.36% / +1.76%).
Seven-pair small/tee repeats: small 3.361 → 3.363 /
9.925 → 9.604 ms (+.06% / −3.23%); tee 2.758 → 2.799 /
102.122 → 102.635 ms (+1.49% / +.50%). Small/O repeat MADs are
.010/.040 and .362/.078 ms; tee .044/.009 and .452/.765 ms.
Keep every drift rejection and differing host band. These are enclosing
pipeline measurements, not pass-local v133 ratios. Tee and cumulative
performance costs remain active; large flat time is not speed parity.
Per-child peak RSS is 294,224/294,368 KiB before and 298,752/294,572 after;
retain the higher first candidate sample rather than claiming a memory win.
Long fuzz and final signoff remain deferred.


## October 1, 2026: share immutable write admission facts

V79 replaces the first-read Boolean written-local row with one lazy immutable
sole-writer row: -1 unwritten, -2 multiple live writers, otherwise the sole node.
A value record also captures excluded Try/TryTable/Continuation families.
Analysis scans once on its first LocalGet, uses the same row for unwritten-read
admission, root entry-source admission and unresolved LocalGraph selection.
No-read functions never scan; no-write functions allocate no local row. Only
actual writer nodes need full immediate fields; other census nodes use checked
opcodes. Rows remain scoped to the immutable analysis snapshot.

The standalone entry helper retains its root-write preflight and first-opaque
census return. Full analysis completes its census across opaque families so
later unrepresented writes cannot disappear. Both single-write and interval
source algorithms, repeated/shared-root rejection, complete CFG and conservative
fallback writer index remain intact. The fallback still includes its historical
all-node writer set, separate from the live-node sole-writer facts. No public
IR getter or API is added.

The red regression observes **ten census visits for five nodes** and fails the
one-arena bound. Frozen V78 comparisons check exact ordered edge/link arrays,
used bits, worklist and cursor plus unchanged HOT revision/lowering. Controls
cover immutable/default reads, single/multiple writes, branches, loops,
try-table, repeated/shared write roots, intentionally detached reads and GC
parameters. The dispatcher preserves exported mutable parameter results.
Twelve native controls compare complete analysis/solve and graph construction,
including tiny/wide immutable, single-writer, distinct-root and opaque bodies.
Frozen evidence lives under `.tmp/dae2-shared-write-facts-20261001/`;
native SHA-256 `eda53564604ffd1a397ba93d55eebabfead9ca58c22cabd90cf23a453ec0b1b3`. Info, formatting, 28 focused checks,
all **13,253** default tests, native release, twelve native rows and 1,376
original-primary observations pass. Compiler raw/canonical and individual
function bytes/non-code sections remain exactly V78. The v133 deficit stays
**179,213 canonical / 65,631 raw bytes**.

| Complete native analysis control | Pinned repeat V78 → V79 | Change |
| --- | ---: | ---: |
| Immutable tiny | 329.13 → 320.17 ns | −2.7% |
| Immutable width 512 | 11.10 → 10.33 µs | −6.9% |
| Single writer tiny | 599.84 → 607.56 ns | +1.3% |
| Single writer width 512 | 27.16 → 24.32 µs | −10.5% |
| Distinct roots width 32 | 6.11 → 5.81 µs | −4.9% |
| Opaque width 512 | 193.88 → 184.23 µs | −5.0% |

Keep initial rows: immutable tiny +6.2%, immutable wide −3.4%, single tiny
−8.4%, single wide −10.9%, distinct −4.9%, opaque −8.4%. Tiny results disagree;
the small-path overhead remains open. Initial enclosing small plain/O is
4.028 → 3.648 / 10.890 → 10.849 ms (−9.43% / −.38%); large
3,840.543 → 3,930.860 / 8,599.279 → 7,482.425 ms (+2.35% / −12.99%);
tee 3.205 → 4.838 / 113.360 → 113.961 ms (+50.95% / +.53%).
The optimizing large MAD is 1,328.069/449.651 ms: its first apparent gain
is dispersed, not a proved compiler win. Repeat seven small/tee and three
large pairs: small 3.895 → 4.126 / 10.176 → 10.164 ms (+5.93% / −.12%);
large 3,623.962 → 3,559.814 / 6,731.979 → 6,857.952 ms
(−1.77% / +1.87%); tee 2.987 → 2.993 / 115.517 → 108.997 ms
(+.20% / −5.64%). Repeat large MADs are 106.982/.056 and 31.988/132.104 ms;
small plain .317/.517 and optimizing .095/.075; tee plain .051/.013 and
optimizing 2.266/.824. All drift rejections/host bands remain preserved.
These are enclosing pipeline medians. Large optimizing and small/common
costs remain active. Peak RSS before 304,480/294,204 KiB and after
304,492/294,392 is essentially flat.

A fresh verified-v133 oracle has one warmup, three accepted measured samples,
CPU 6 and matching Precompute brackets. The table uses accepted V79 repeat
**pass timers**, excluding warmups/rejected pairs. Oracle and Starshine were
measured separately, so these are descriptive ratios across host bands,
not alternating causal speedups or final signoff:

| Pass | Small Starshine / v133 ms | Ratio | Large Starshine / v133 ms | Ratio |
| --- | ---: | ---: | ---: | ---: |
| DAE2 | 4.082 / .979141 | 4.17× | 3,540.689 / 454.559 | 7.79× |
| DAE2 optimizing | 10.128 / 3.103510 | 3.26× | 6,834.087 / 1,706.630 | 4.00× |

A bounded V78 compiler stack sample completes with **256 stacks** and exact
saved output. Top frames include drop/free/allocation (27/15/22), descriptor
body scans (9), typechecking, node/child access and LocalGraph reverse/source
work. This is descriptive interrupted sampling, not an instruction count or
per-phase allocation measurement. Three earlier sampler attempts completed
exact output but collected zero stacks; they provide no hotspot evidence.
The corrected sampler sends SIGSTOP to the inferior with stop configured
last, suppresses delivery and retains its logs. These findings prioritize
larger allocation/validation/CFG owners beyond the closed duplicate census.

The V79 full local-index entry row still materializes for zero/one admitted writer;
V80 below supersedes that scratch requirement without changing fallbacks.
Long fuzz and final signoff remain deferred.


## October 1, 2026: keep singleton entry proofs scalar

V80 keeps the one admitted local/node pair in scalar fields and materializes the
local-index entry row only on a second distinct admitted writer. Failed and
singleton admission allocate no entry row. The singleton source traversal now
compares that exact local and node directly; its epochs, shared-read markers,
source order and repeated/shared write rejection are unchanged. Multiple
admission retains the original interval algorithm and local-index rows.
The root-write list remains a separate future scratch target.

The red regression allocates 64 local-index slots for a sole writer and fails
its zero-row assertion after matching the original source vector and full
LocalGraph flow. Tests retain revision/lowering ownership and multiple/
repeated-root cases. Frozen V79 entry/single traversal controls compare tiny,
64-local and 4096-local cached-fact queries with parsing outside timed work.
The prior V78 analysis reference now freezes its own unchanged single traversal
so historical baseline evidence retains its original implementation.
Frozen evidence is saved under `.tmp/dae2-single-entry-row-20261001/`;
candidate SHA-256 is
`e9db0d8da3a2213e3736b7cd4d917993109ed55146b03758bc63e7304b80fbe6`.
`moon info`, formatting, focused tests, all **13,255 default tests**, native
release build and six native benchmark rows pass. All 1,376 original-primary
fixed observations match. Compiler functions/non-code sections and raw /
canonical output are exact V79 bytes; the v133 deficit remains **179,213
canonical / 65,631 raw bytes**.

| Cached-fact singleton query | V79 → V80 | Change |
| --- | ---: | ---: |
| One local | 172.03 → 151.68 ns | −11.8% |
| 64 locals | 191.76 → 154.51 ns | −19.4% |
| 4096 locals | 1.16 µs → 157.17 ns | −86.5% |

Parsing and immutable write facts are outside these timed queries; query
allocations remain inside. Three accepted alternating pairs, one warmup,
CPU 6 and Precompute bracket ratio ≤1.15 give enclosing small plain/O
3.530 → 3.552 / 10.489 → 10.182 ms (+.62% / −2.93%); large
3,627.527 → 3,659.809 / 6,795.658 → 6,872.532 ms (+.89% / +1.13%);
tee 2.987 → 2.928 / 106.127 → 107.407 ms (−1.98% / +1.21%).
Large MADs are 48.851/57.348 and 2.999/39.172 ms; retain rejected host bands.
These rows do not prove compiler parity or a large-artifact speedup. Peak RSS
before 294,152/294,548 KiB and after 294,216/294,140 is flat. Remaining root
list, traversal, allocation and enclosing costs stay open; long fuzz and
final signoff remain deferred.


## October 1, 2026: reuse compound suffix initialization facts

V81 extends the existing private immutable statement-type seed to compound
value-suffix queries in the pure, balanced and effectful raw cleanup scans.
The original body/environment remain fixed throughout each scan. The first
compound query retains fresh setup; a repeated compound query with at least
128 locals admits one seed. Scalar/local leaves still use their exact fast
path. Balanced statement and suffix queries share the same admitted seed.
Each query owns a fresh stack and starts with fresh reachability/escape facts;
full operand/control typing and unknown-opcode fallback remain unchanged.
Both existing `make_state` and `make_state_owned` use the same all-initialized
local policy in the current validator; this does not change that policy.

The focused red counter reports three fresh state builds despite a supplied
seed, then passes with zero redundant builds. Frozen V80 suffix controls test
scalar/GC values, trapping division, multivalue arity, If/Block/TryTable,
terminal and intentionally invalid expressions, changed local environments,
input ownership and seed isolation. Dispatcher coverage retains dependent
compound division/addition with 128 local slots. Native batch controls include
admission and seed allocation inside timed work, plus tiny/single-query and
leaf-only controls. Evidence is pending under
`.tmp/dae2-compound-suffix-seed-20261001/` for the first candidate and
`.tmp/dae2-compound-suffix-seed-refined-20261001/` for refinement.
The first candidate passes all 13,259 default tests, ten native rows and 1,376
fixed observations, with exact compiler bytes and flat optimizing large
6,775.812 → 6,770.302 ms (−.08%). Its wide 32-query batches improve 7.9% at
128 locals and 37.0% at 8192 locals, including seed setup. However, tiny eight-
local single queries cost 18.63 ns and 32 leaf queries grow .734 → 1.14 µs;
retain those costs. Numerous host-drift rejections accompany small plain/O
5.627 → 6.036 / 16.970 → 15.952 ms, large plain
3,607.087 → 3,712.231 ms, and tee plain/O
3.136 → 3.413 / 108.531 → 108.978 ms. No enclosing speedup is established.
The reduced replay initially fails because its local fixture was not copied;
restoring that fixture and rerunning only unfinished stages passes. The
refinement inlines the existing leaf classifier and checks the wide-environment
threshold before cache classification. Its evidence is pending; no final
acceptance claim precedes measurement. Long fuzz/signoff remain deferred.

A focused frozen V80 / verified-v133 loop replay under
`.tmp/dae2-loop-capture-probe-20261001/` refreshes the historical imported-call
witness: canonical **235 vs 215 bytes**. Raw 325 vs 215 includes name metadata;
that is a separate encoding scope. Mutable counter snapshots into 11/16, dead
tees 10/12, set/get versus tee 18 and load-result capture 9 remain. Fewer locals
alone does not prove a win. The gap stays open pending bounded original-primary
semantic replay and a proved transform. The simpler field-copy probe already
forwards captures in Starshine, so it is not evidence of a missing root-copy
transform.

The first refinement keeps the same exact bytes and all 13,259 tests / 1,376
observations pass, but its pinned leaf control grows 528.59 → 956.36 ns per
32 queries. Generated C identifies the cause: explicitly forwarding the
nullable optional seed creates a boxed outer `Some(None)` on every query.
The next candidate uses a required private nullable-seed argument, preserving
the old optional test/wrapper entry separately. It caches the immutable
wide-environment decision once per scan. Evidence is pending under
`.tmp/dae2-compound-suffix-seed-required-20261001/`; retain both prior artifacts.

A bounded exact-output V80 compiler call-count probe under
`.tmp/dae2-graph-counts-20261001/` completes in 10.04 seconds with 8,354 HOT
dependency functions, 8,187 entry-proof attempts and 7,926 read-source graph
builds. These are descriptive GDB counts, not wall-time percentages; remaining
CFG/source work is a larger target than singleton admission alone.

The required-argument candidate also uses `make_state_owned` for its freshly
created empty query stack, avoiding an unnecessary empty-stack copy. Full
query ownership and initialization policy are unchanged. The optional wrapper
remains for existing test instrumentation; production scans call the required
private seed boundary directly.

The final required-boundary candidate SHA-256 is
`81763eb0722b9c2641374a6a6179df7a8203b90f2087d6779ca3dc3d05a109ae`.
All **13,259 default tests**, twelve focused tests, ten native rows, native
release build and 1,376 original-primary fixed observations pass. Compiler
function/non-code sections and raw/canonical bytes are exact V80. The verified
v133 deficit remains **179,213 canonical / 65,631 raw bytes**. Generated C at
all three production suffix call sites passes nullable pointers directly,
removing the per-query boxed optional-seed argument.

| Final pinned batch control | V80 → V81 | Change |
| --- | ---: | ---: |
| 8 locals, one compound query | 191.60 → 194.61 ns | +1.6% / +3.01 ns |
| 128 locals, one compound query | 190.10 → 188.31 ns | −.9% |
| 128 locals, 32 compound queries | 5.75 → 4.61 µs | −19.8% |
| 8192 locals, 32 compound queries | 8.37 → 4.76 µs | −43.1% |
| 8192 locals, 32 leaf queries | 522.32 → 571.98 ns | +9.5% / +49.66 ns |

Admission and seed setup remain inside timed batches; the predecessor excludes
new admission work. Retain the final tiny/leaf costs as active, rather than
reporting the closed boxed-argument mechanism as universal speedup.
Three accepted alternating pairs, one warmup, CPU 6 and Precompute bracket
ratio ≤1.15 give enclosing small plain/O 3.640 → 3.573 / 10.220 → 10.277 ms
(−1.84% / +.56%); large 3,518.751 → 3,533.601 /
6,720.714 → 7,054.372 ms (+.42% / +4.96%); tee
2.959 → 3.032 / 107.023 → 103.679 ms (+2.47% / −3.12%).
Large MADs are 54.714/37.712 and 169.824/91.296 ms; retain all drift rejections.
A bounded three-pair large optimizing repeat gives
6,580.304 → 6,660.163 ms (**+1.21%**), MAD 8.374/56.095 ms.
The compiler cost remains open; these focused gains do not establish pass
parity. RSS before 294,416/293,956 KiB and after 304,728/294,400 is dispersed,
not a demonstrated memory win. First-query unknown suffix candidates still
build fresh facts per attempted suffix; cross-owner reuse also remains open.
Long fuzz and final signoff remain deferred.

## October 1, 2026: lazy legacy adaptation setup

V82's cold regression first observes three unnecessary owners (full environment,
lowering state and rewritten body vector). Preparation now computes a linear
primitive function-arity table and allocates those owners only for an admitted
legacy handler. The table preserves recursive-group lookup and omission of
unresolved signatures; missing-signature errors remain unchanged. An active
adaptation canonicalizes untouched prefix and suffix declaration groups exactly
as before. Cold modules retain original identity. No public API changes.

Focused imported/grouped types, invalid lookup, GC command dispatch and grouped
sibling tests compare direct fields, original ownership and frozen V81 encoded
bytes. Native cold 1/64/4096-function and active 64-function controls include
complete preparation inside timing. Red: owner counts `[1, 1, 1]` fail the required `[0, 0, 0]` on a cold
module. Green: `moon info`, `moon fmt`, 11 focused tests, all 13,265 bounded
default tests, the release native build and all eight native controls pass.
Frozen candidate SHA-256 is
`8a36711a0605327835138815578ebf0b272d00400d2775c1bc96ad7b46942204`.
The 1,376 fixed original-primary/v133 observations match; compiler raw, canonical,
per-function and non-code bytes are exact V81. No public `.mbti` changes.

| Complete preparation control | V81 | V82 | Change |
| --- | ---: | ---: | ---: |
| Cold, one function | 609.01 ns | 81.60 ns | −86.6% |
| Cold, 64 functions | 6.07 µs | 1.69 µs | −72.2% |
| Cold, 4,096 functions | 483.44 µs | 106.26 µs | −78.0% |
| Active, 64 functions | 111.22 µs | 109.45 µs | −1.6% |

Three matched enclosing pairs, CPU 6, one warm-up and Precompute brackets at
most 1.15 retain rejected drift samples. Small plain/O medians are
3.547→3.588 ms (+1.16%) / 10.102→10.241 ms (+1.38%). Large plain/O are
3,658.506→3,533.290 ms (−3.42%) / 6,641.167→6,619.757 ms (−0.32%);
large MADs are 37.003/19.001 and 89.876/7.093 ms. Tee plain/O are
2.962→2.905 ms (−1.92%) / 105.313→104.774 ms (−0.51%). These are
command pipelines, not isolated pass times; optimizing remains approximately
flat and the small costs remain open. Optimizing RSS is also flat:
294,324/294,140 KiB before and 294,468/294,260 KiB after.

Artifacts are `.tmp/dae2-lazy-legacy-setup-20261001/`, including the frozen
predecessor, failing regression, native controls, source hashes, matched
cohorts and validation/runtime/byte reports. The verified v133 deficit remains
179,213 canonical / 65,631 raw bytes. Larger CFG/source work, mutable-source
copies, unread tees and global speed/size parity remain active. Fuzz is deferred.

## October 1, 2026: retire unread optimizing body writes

V83's focused command loop retains unread load/counter tees and three locals
where one is required; the direct compactor also retains unread numeric,
reference and non-null GC producer tees. Six behavior regressions fail before
implementation, while live-handler/other-arm and original/plain boundaries pass.

Optimizing capture admission now includes zero-read writes, reusing the existing
complete nested/legacy read census. After capture/alias demand adjustment, only
eligible zero-read body locals retire. An unaliased retired tee disappears while
its value stays on the stack; a retired set becomes a drop at the same point.
Proved alias writers keep their established producer-removal rule before this
fallback. No evaluation moves, new census or public API is introduced. Ordinary
lowering preserves its original-local boundary; optimizing cleanup deliberately
uses an empty boundary to compact every body local. Parameters retain indices.

Direct fixtures assert instructions/maps/ownership/encoded size for scalar/ref/GC,
side-effecting multi-value producers, nested loops, live catch/other-arm reads,
original/plain boundaries and alias replay. The initial prototype in `.tmp/dae2-unread-writes-20261001/` passes 13,273
bounded tests but fails the compiler fixture: the alias remapper leaves an
unaliased retired set at index −1. A new regression fails with
`LocalSet(4294967295) != Drop` before correcting that second remapper. The
refined implementation also caches read/write census values and skips alias
discovery when no local reads remain. Compiler smoke/validation precede native
benchmarking; no invalid prototype is committed.

Final `moon info`, `moon fmt`, 29 focused tests, all 13,274 bounded tests,
the release native build, compiler smoke/validation and ten native controls
pass. Frozen candidate SHA-256 is
`485d74b5234f05e9091adcd30dc0aa1c29834a40d9ddc713a39c72accde90c35`.
All 1,524 fixed original-primary/v133 observations match. The final two-loop
replay initially cannot decode v133 compact imports in Node 26; its separate
runtime oracle disables compact imports, preserving the original size evidence.
No public `.mbti` changes.

| Full compaction control | V82 | V83 | Interpretation |
| --- | ---: | ---: | --- |
| Cold, one live local | 90.60 ns | 90.37 ns | Flat |
| Cold, 64 live locals | 1.08 µs | 1.09 µs | +.01 µs remains open |
| 64 unread tees | 709.19 ns | 1.64 µs | +.931 µs for new cleanup |
| 64 unread sets | 535.08 ns | 1.28 µs | +.745 µs for new cleanup |
| 16 live-handler locals | 606.20 ns | 599.99 ns | Approximately flat |

Refining the initial census/remap draft brings active tee/set controls from
1.87/1.40 µs to 1.64/1.28 µs. Cold 64 improves from the initial 1.27 µs to
1.09 µs. This comparison spans separate native cohorts; the final matched
predecessor controls above are the causal comparison. Added active work remains
a target rather than an assumed free transform.

Three matched enclosing pairs, CPU 6, one warm-up, Precompute brackets ≤1.15
and retained rejected samples measure small plain/O 3.547→3.492 ms (−1.55%) /
10.182→10.129 ms (−.52%); large 3,721.189→3,611.613 ms (−2.94%) /
6,953.939→6,872.133 ms (−1.18%); tee 3.241→3.187 ms (−1.67%) /
115.730→117.756 ms (+1.75%). Large MADs are 149.842/.679 and
66.279/20.717 ms. One bounded tee-only repeat is 108.374→108.801 ms
(+.39%, MAD .883/.308 ms), still an open cost. These are enclosing command
pipelines rather than pass-local attribution. RSS is flat: 294,124/294,572 KiB
before and 294,288/294,124 KiB after.

Compiler raw bytes fall **5,639,081→5,563,501 (−75,580)** and bounded canonical
bytes **5,766,650→5,686,688 (−79,962)**. All **4,968** changed functions shrink,
with no growth; code bodies save 75,525 bytes and non-code sections are exact.
Against the same verified v133 oracle, raw output now wins **9,949 bytes**,
while canonical output still loses **99,251 bytes** (previously 179,213).
This is a measured byte win; it does not establish overall speed/size parity.

The focused load/counter command loop drops from 97 to **93 canonical bytes**,
matching v133's 93. The larger imported-call loop falls 235→**231**, versus
v133's 215: unread tees 10/12 close, while mutable counter snapshots 11/16,
set/get-versus-tee 18 and load capture 9 remain active. Results, ordered calls,
injected exceptions and load traps match original/v133 in 148 observations.

Artifacts are `.tmp/dae2-unread-writes-fixed-20261001/`: red logs are retained
in the initial root, final source hashes, native controls, compiler smoke,
matched cohorts/repeat, per-function/non-code bytes and original-primary replays
are in the fixed root. Larger flow/lift/lower, cleanup costs, mutable-source
snapshots and global canonical/speed parity remain active. Fuzz is deferred.


## October 2, 2026: prove empty CFG ordering demand before constructing facts

The large dependency-analysis profile collects only the nonrecursive
`dae2_analyze_function` wrapper. Of 12,454,268,953 instructions, its direct CFG
child costs 7,770,097,432 (62.39%) and read-source child 2,017,338,851 (16.20%).
Source-order construction costs 1,862,981,602 **inside CFG**; these inclusive
costs must not be added. This identifies redundant ordering setup, rather than
proving that discovery or fixed-point solving is the dominant remaining cost.

[CFG segmentation](../../../../../src/ir/cfg.mbt) retains all operand expansion,
blocks, edges, root mappings and full verification. A builder owns lazy
source-order facts and a single bounded operand-minimum row. A region with at
most one root has no future ordering demand. For other regions, every selected
carried value must satisfy `value_order < current_order`; source-order summaries
start at the node's own order and take maxima over the same operand edges.
Therefore, if every later operand's minimum own order is at least all earlier
roots' `min(root_id, root.order)`, the selected dependency row is provably empty.
Regions with old/shared/carried values retain complete facts and selection.
Nested regions receive their own checks; no control edge or optimization work
is omitted. Minima are memoized once per operand in an immutable builder, never
shared across revisions; invalid/cyclic operands conservatively demand facts.

The frozen candidate is
`f33c222b4f38df32d1be72cce8513cfc39500c3769c646347bd355a2b18dcfa5`,
against CL checkpoint `199d293ba755f14cd0e94b82f8d018cb8dc4ed71ee63c87432e906d53023efe1`.
The original factory-only lazy trial was inconclusive: large plain paired
+1.00%, optimizing −.66%. It does not independently establish a compiler win.
The operand proof supersedes that trial.

| Large 6,211,596-byte input | Before CLI ms | After CLI ms | Paired change | Binaryen 133 CLI ms |
| --- | ---: | ---: | ---: | ---: |
| DAE2 | 4612.107 ± 32.589 | 4493.978 ± 51.241 | −2.56% | 1221.608 ± 7.661 |
| DAE2 optimizing | 7876.453 ± 52.457 | 7750.352 ± 95.202 | −1.40% | 2547.295 ± 24.754 |

These are medians ± MAD, five alternating same-host fresh-process samples after
one warmup, CPU 6, native release; builds are excluded. All rows observe foreign
CPU work. Optimizing's late samples and separate traced cohort overlap a Java
gametest using over six cores, so those wall times remain **diagnostic**, not a
clean causal estimate. Plain's three separate traced pairs reduce dependency
work 1037.438→887.144 ms and inclusive analysis 1792.942→1638.117 ms;
inner pass 3733.270→3663.895 ms has wide candidate MAD (115.321 ms).
Do not mix scopes, sum parent/child timers, or add gains from prior cohorts.
Binaryen optimizing uses `--dae2 --simplify-locals --vacuum`, all features;
Starshine uses its canonical `--dae2-optimizing` dispatcher.

A second exact-wrapper Callgrind run independently reduces analyzed instructions
12,454,268,953→10,013,628,335 (−19.60%). CFG falls to 5,328,564,736 instructions
(−31.42%); read-source work stays 2,018,300,839. All 8,354 analyzed functions and
7,926 CFG/read-source builds remain. Source-order factories fall 7,926→411;
the conservative proof costs 478,937,128 instructions, already included in the
candidate total. Both profile outputs independently validate and match exact hashes.

**Profiler-scope correction:** the initially recorded allocator-call totals
30,810,544→29,907,661 come from shared call sites in the collected call graph;
they do **not** establish a scoped 2.93% allocation reduction. Callgrind keeps
call counts while collection is off: a four-call retained `malloc` probe, with
only two calls inside the toggled wrapper, reports `calls=4` and instructions
for two calls. The instruction totals above remain correctly scoped. Use a
full-command profile for global allocation totals, or a directly toggled worker
whose allocation site cannot execute outside collection. See the
[profiling rule](../../../tooling/tracing-playbook.md#callgrind-collection-scope-and-allocation-counters).
This explicitly supersedes the initial allocation-scope claim; allocator call
counts are also not allocated bytes or peak live objects.

[Red-first regressions](../../../../../src/ir/cfg_lazy_source_order_wbtest.mbt)
cover no-future and forward regions, real carried reads across writes, shared-DAG
work bounds, snapshot ownership and mutation. Retained original segmentation
references explicitly retain eager initialization. The command dispatcher tests
both DAE2 modes with mutable finite loops and imported effects. `moon info`,
`moon fmt`, all 13,295 bounded wasm-gc tests, `moon check` and native release
build pass; no public API changed.

All twelve [native controls](../../../../../src/ir/cfg_lazy_source_order_perf_wbtest.mbt)
pass, ten batches, mean times: single-root widths 8/128 improve
1.73→.581 / 18.88→4.01 µs; forward widths 8/64 improve
6.00→3.40 / 42.60→25.45 µs. The carried width-8 fallback costs
1.97→2.28 µs; width 128 is noisy (16.26→15.57 µs), not a gain claim.
The extra owned integer row is bounded by arena length and absent on
single-root/no-expansion paths. Its remaining tiny/fallback setup cost is open.

Large raw outputs remain exact: DAE2 6,115,221 B and optimizing 5,563,501 B.
V83's raw win and 99,251-byte symmetric canonical deficit remain unchanged.
Artifacts: `.tmp/large-pass-hotspots-20261001/`, forward manifests, per-mode
`*-pairs/result.json`, twelve-case benchmark, exact-wrapper profiles and parser.
Both-mode fixed execution matrices validate 56 modules and compare 168
original/before/after/v133 observations without mismatch, including mutable
loops, imported effects, global state, memory, GC siblings and trap occurrence.
Two alternating per-process `wait4` RSS observations per side (KiB) are plain
[264840, 246144]→[267388, 245036] and optimizing [304532, 294460]→[294100, 294260]. Their large spread does not establish a memory gain
or a confidence interval; the one-row arena bound is the storage invariant.
Aggregate fuzz, coverage and the full release gate remain deferred at the user's
request; local source/diff review is available, independent review is not.
Remaining priorities are full CFG/read-source construction, repeated lift/lower,
optimizing cleanup, precise final guards and the canonical quality gap.

## October 2, 2026: exact-sized owned CFG segment copies

`cfg_builder_region_segments` knows each segment extent before copying node IDs.
It now allocates one exact-sized owned primitive row instead of growing an empty
array with per-node pushes. A singleton uses an array literal: the first generic
slice-copy trial made that common control slower (33.38→51.81 ns) and was not
accepted. The final helper retains independent segment/source ownership and
all node order, block/edge fields, operand expansion and verification.

[Focused regressions](../../../../../src/ir/cfg_segment_copy_wbtest.mbt) cover
exact ranges, empty/full/tail and singleton copies, capacity, source/sibling
mutation isolation, complete graph fields in both operand modes, and revision
stability against the retained original segmentation reference. `moon info`,
`moon fmt`, all 13,299 default wasm-gc tests, `moon check` and the native release
build pass. The final binary SHA-256 is
`8ed642e1ded338acf9ad07d4b013e5097bc8aac4b0b97828ac28e75b59f84ba5`.

Eight [native controls](../../../../../src/ir/cfg_segment_copy_perf_wbtest.mbt)
pass, ten batches, mean±sigma: singleton 37.10±2.34→27.41±4.42 ns;
8 nodes 39.70±6.01→29.51±.17 ns; 128 nodes
176.49±2.56→36.57±1.18 ns; 2,048 nodes
1.92±.165 µs→106.02±1.02 ns. These compare the frozen push algorithm to the
new copy helper, outside fixture setup; they are not full-pass timings.

A complete large DAE2 profile toggles the exact nonrecursive segmentation
wrapper on every invocation. Collected instructions fall
3,075,064,059→2,972,151,065 (−3.35%, segmentation only); output hashes match
and `wasm-tools validate --features all` passes. Shared allocator call totals
are **not** exclusive scoped allocation evidence. No allocated-byte or RSS
improvement is claimed.

Full-command benefit remains unproved. Five alternating large DAE2 pairs on
CPU 6 give before 4671.442±116.936 / after 5190.276±605.866 ms (median±MAD),
paired +13.99%; v133 1287.204±6.001 ms. A second distinct CPU-2 cohort gives
5692.497±395.075 / 4869.940±294.147 ms, paired −.05%; v133
1366.726±115.678 ms. Every row flags foreign CPU work; the second cohort's
traced medians also remain noisy. Preserve both cohorts and the first trial,
rather than using the lower candidate median as a command improvement. Renew
quiet enclosing measurements and memory controls before closing the release
performance item. The scoped instruction and helper improvements justify this
small storage change; they do not establish Binaryen speed parity.

Both DAE2 modes and CoalesceLocals pass 84 validated fixed modules and 252
original/before/after/v133 execution observations with exact before/after
bytes. Fixtures exercise mutable loops, shared/carried reads, imports, traps,
global/memory state, conditional arms and GC siblings. Large plain output stays
6,115,221 B. Optimizing byte improvements and the 99,251-byte symmetric
canonical deficit remain unchanged. No public API changes. Aggregate fuzz,
coverage/full release gates and independent review remain deferred; local
source/staged-diff review is available.

Local artifacts: `.tmp/large-pass-hotspots-20261001/`, `cfg-copy-v2-*` manifest,
eight-case benchmark, three-mode runtime matrices, validated exact-wrapper
profile, CPU-6 and CPU-2 pair cohorts. The directory name predates these runs.

## October 2, 2026: avoid provably empty leaf conditional cleanup

The optimizing dispatcher benefits from SimplifyLocals' already-computed
complete current-body census: with zero ifs its leaf conditional rewrite now
returns without constructing unused cloned arrays. Possible candidates keep
all owned recursive work, transforms and final verification. See the
[implementation, red regression and evidence](../simplify-locals/starshine-hot-ir-strategy.md#october-2-2026-reuse-the-current-census-for-absent-leaf-conditionals).
All 13,304 bounded tests and 168 fixed execution observations pass with exact
bytes. Native no-if controls improve 86.07→16.85 ns (tiny) and
22.39 µs→20.89 ns (nested), but matched large optimizing command remains flat
(paired +.16%, all host-contended): this does not close P03e or establish speed
parity. Broader cleanup scans, recurrence storage and validation remain targets.

## October 2, 2026: complete optimizing cleanup instruction attribution

A bounded complete native profile of the 6,211,596-byte compiler fixture now
captures all `run_hot_pipeline_func` calls in the optimizing SL/Vacuum suffix.
The frozen predecessor is `8ed642e1…` (exact-sized CFG, before the leaf census
guard). Its 26,744,494,316 collected instructions split at the nonrecursive
wrapper's direct child boundaries as follows:

| Owner | Collected instructions | Scope |
| --- | ---: | --- |
| Raw SimplifyLocals entry | 18,260,234,664 | inclusive child, 68.28% of wrapper |
| Raw Vacuum preclean | 5,694,289,310 | inclusive child, 21.29% |
| Other children and wrapper self work | 2,789,970,342 | remaining 10.43% |

These direct root children are disjoint. Their nested children must not be
added: the raw SL entry includes 9,192,415,199 instructions in skipped-effectful
carrier rewriting, and that contains balanced cleanup and exact cleanup.
Across exact statement-prefix helper entry calls, 4,168,237,590 instructions
include 4,060,312,174 in instruction typechecking. These are instruction costs,
not wall milliseconds or exclusive allocation counts. Recursive incoming edges
can exceed the root total through repeated inclusive accounting; do not turn
them into percentages or add them. Shared allocator-call totals remain mixed.

Source inspection finds balanced forwarding typechecks a candidate statement
before rejecting any statement containing its existing structured-control or
terminal predicates. This performs unnecessary recursive validation and may
render discarded error context. The validator's
[`Expr` error context](../../../../../src/validate/typecheck.mbt) formats full
instructions only on errors; public diagnostic behavior must remain intact.
Large string-construction costs motivate this source-backed investigation,
without attributing every string event to this one probe. The early-rejection
pilot retains complete typechecking for eligible statements and every other
prefix client, and leaves mandatory function/module verification unchanged.
Its enclosing before/after measurements and acceptance are tracked separately.

The earlier instrumentation-on-at-start profile exceeded its six-minute bound
under host contention; no partial totals were accepted. The successful run
starts Callgrind instrumentation in the enclosing hot-pass dispatcher before
its first function call, then toggles collection only at the exact nonrecursive
function wrapper. A four-call/two-scope C control matches the original 254
collected instructions; enabling instrumentation inside the target incorrectly
misses its first scope (127), and those probe variants are retained as rejected.
No production instrumentation or policy/settings change is needed. Final
output independently validates and matches the frozen predecessor hash.

Artifacts: `.tmp/large-pass-hotspots-20261001/dae2-cleanup-delayed-*`, GDB/driver,
exact-wrapper and exact-child parsers, complete profile/manifest, and the
`vgdb-parent-probe.*` control. This phase attribution is a new complete cohort,
not the saved October 1 report and not a full-command benchmark. Continue with
verified single-change wall/byte evidence; remaining Vacuum unreachable/control
rescans and recurrent raw array construction are independently visible owners.


## October 2, 2026: current large dependency cost after checked lift reads

Current source main ddd0053b9, native e57d9b45…; fixed6,211,596 B compiler
SHA98189860… and verified v133 remain as documented in the
[checked lift checkpoint](../coalesce-locals/starshine-strategy.md#october-2-2026-checked-arena-reads-for-lift-local-conflicts).
A single bounded180s delayed Callgrind capture collects all nonrecursive
`dae2_analyze_function` wrappers, CPU6, normal process exit. Output validates
and matches exact current plain DAE2 SHA7c07b51c…. This is a current attribution
snapshot, not a before/after claim for the lift change. Analysis lifting,
raw-plan lanes, solving, rewriting and final validation are outside collection.
Shared-site off-scope call counts are not allocation evidence.

| Source owner / edge | Instructions | Scope |
| --- | ---: | --- |
| Dependency wrappers | 9,908,757,394 | Complete collected root |
| Analyze→CFG construction | 5,224,349,718 | Inclusive direct child, 52.72% root |
| Analyze→reaching-read sources | 2,018,098,328 | Inclusive direct child, 20.37% root |
| Analyze→entry-read proof | 789,531,719 | Inclusive direct child, 7.97% root |
| CFG→region construction | 3,741,538,561 | Nested inclusive child |
| CFG→HOT verification | 971,059,439 | Nested inclusive child; mandatory |
| CFG→CFG verification | 279,575,044 | Nested inclusive child; mandatory |
| Read rows→reverse predecessor queries | 914,660,870 | Nested inclusive child |
| Getter | 1,064,427,470 | Exclusive across collected consumers |
| Object destruction | 896,326,963 | Exclusive; not allocated bytes or RSS |

Do not add nested edges to their parents or exclusive getter/destruction to
the direct-child totals. These are instructions, not phase milliseconds.
[DAE2 analysis](../../../../../src/passes/dead_argument_elimination2.mbt),
[CFG](../../../../../src/ir/cfg.mbt) and
[read-source rows](../../../../../src/ir/local_graph.mbt) support this breakdown.
LocalGraph's transparent-predecessor compression already resolves each functional
chain once; its existence is not a new quadratic issue. Tiny last-write searches
are bounded at four actions; long rows already use a lazy index. Do not duplicate
those fixes or replace them with speculative retained caches.

Next experiments, before implementation:

- Attribute selected-read/action/last-write query density and scratch lifetimes
  within the reverse-query entry. Preserve exact source ordering, exceptional
  edges, loop-root writes, unknown closed cycles and full sparse fallback.
- Measure CFG region root/operand/control row construction and object destruction;
  prefer eliminating unchanged temporary storage over retaining entire arenas.
  Keep complete public CFG fields, verification, source-order and result ownership.
- CFG verification's reciprocal edge checks scan neighbor rows. Source confirms
  potentially quadratic work on high-degree joins/switches, but this profile does
  not prove those shapes dominate the compiler. Use a bounded dedicated wide-edge
  benchmark plus small invalid/asymmetric/duplicate-kind behavior regressions,
  then measure compiler degree distribution before choosing a lazy index.
  Any index must retain all checks and original error admission, avoid adding
  heap maps to ordinary sparse graphs, and demonstrate enclosing gain.
- Remaining full-node boundary work spans many consumers; target the actual
  caller and generated code, rather than assuming getter self cost is free or
  widening admission. Largest getter edge here is entry-read proof152,379,880;
  it is nested in that proof's789,531,719 and must not be counted twice.

No further production change is justified by attribution alone. Larger shared
pipeline/optimizing cleanup setup and OI command envelope remain release owners;
canonical gaps, memory modes and final aggregate/CI/coverage remain open.
Exact commands, source/binary/output identities, normal-exit logs, parsed exclusive
and inclusive costs: `.tmp/large-pass-hotspots-20261001/current-dae2-dependencies-current-*`
and `current-dae2-dependency-costs.json`. No long fuzz campaign.


## October 3, 2026: inline scalar CFG edge storage

[CfgEdge](../../../../../src/ir/cfg.mbt) gains only `#valtype`: its immutable
kind/block fields remain unchanged. Native array slots now hold contiguous
8-byte records rather than pointers to separately allocated records. Owned
successor/predecessor queries and explicit borrowed edge rows retain their
contracts; ordering, duplicate policy, exceptional edges and every CFG/HOT
verification check remain. Generated .mbti has no diff (this compiler also
omits existing HotNode's value annotation); native C representation changes,
and all package consumers are rebuilt.

Freeze main3631c1d0c/nativedbbaefbe…→43feef6e… against verified133 and the same
6,211,596-byte/12,904-function input. Performance TDD checks the actual native
builder: two direct16-byte record requests become zero, with backing-array
growth retained. Complete DAE2/CL factory counts remain729,911/479,079,
removing1,459,822/958,158 record requests (23,357,152/15,330,528 requested bytes).
These are isolated native record requests, excluding allocator overhead/reuse,
backing arrays and net whole-module allocation/RSS evidence.

Complete normally exited, hash-matched DAE2 work34,609,136,479→34,301,861,068
(−.887845%); CL40,822,716,968→40,482,682,526 (−.832954%). DAE2 dependency
owner becomes9.573b; nested CFG5.103b, read sources1.976b, entry proof.790b.
All7,926 CFG/source builds remain. Lift11.401b (10,422 calls), rewrite lower
4.647b (2,468 calls) and mandatory validation remain larger costs. Inclusive
children overlap their parents and are not summed. Constructor/native layout
and complete-consumer work support reduced allocation/traversal overhead;
counts alone would not establish the cause or clock gain.

CPU6 fresh-process/warm-filesystem normal n5 alternating after one warmup,
build excluded, median±MAD milliseconds:

| Pass | Before CLI | After CLI | B133 CLI | After/B |
| --- | ---: | ---: | ---: | ---: |
| DAE2 | 4259.442±53.494 | 4437.228±267.521 | 1382.867±140.725 | 3.209× |
| DAE2-O | 9328.056±2234.735 | 7184.540±270.244 | 2567.837±43.839 | 2.798× |
| CL | 4375.941±34.693 | 4311.431±54.395 | 1947.387±23.953 | 2.214× |
| OI | 2443.104±23.258 | 2424.382±13.781 | 981.942±9.450 | 2.469× |

All rows flag foreign activity. Paired−1.940/−22.979/−1.157/−.263%; OO before
11.142/14.075s outliers prevent attributing its apparent23% gain to this fix.
D2 median regresses while paired samples improve. No quiet-host1× or universal
command win. PeakRSS D2 median266736→256252KiB has overlapping ranges/modes;
OO/CL/OI medians294352→294392/244828→244644/156496→157684KiB do not establish
a general RSS win. Native controls (mean): construct1/32/512 edges72.31→54.95ns,
572.93→194.04ns,8.36→1.90µs; read512234.46→136.89ns. Empty-row30.48→31.23ns
adds.75ns. Retain spread/ranges and the small tradeoff in local evidence.

[IR storage tests](../../../../../src/ir/cfg_edge_value_wbtest.mbt) cover every
kind, growth, held snapshots, owned/borrowed rows and reciprocal verification.
[DAE2](../../../../../src/passes/dead_argument_elimination2.mbt) and
[dispatcher](../../../../../src/cmd/cmd.mbt) prove active pruning through GC,
loops, calls and caught tags; default suite13,395/10 dedicated native controls
pass with info/fmt/check/build/API sync. Four original/before/after/133 execution
lanes pass756 validated modules/2208 fixed observations (results, effects,
state, memory, trap occurrence; runtime-only compact-import normalization stays
separate). All four large raw hashes are exact: output quality/V83 savings and
canonical deficits remain unchanged, without claiming renewed normalization.

Next measured candidates: typed-pop boxed success results and checked-node
return boundaries, before speculative arena retention. Canonical gaps, memory
modes, optimizing cleanup/OI envelope and full CI/coverage/10000 GenValid gates
remain open; long fuzz is deferred under the user's focused campaign direction.
Manual source/native review is recorded; no independent agent review was run.
Exact commands/source/tool/input/binary identities, all samples, red/green,
requests/layout, control spreads, profiles and runtime evidence:
`.tmp/large-pass-hotspots-20261001/main-cfg-edge-value-performance-20261003.md`.


Fresh named diagnostics for this binary are recorded in the
[tracing checkpoint](../../../tooling/tracing-playbook.md#october-3-2026-main-inline-cfg-edge-checkpoint):
DAE23275.024/B502.812ms, OO6107.553/B explicit stage-sum1828.087,
CL3335.802/B1278.750, OI94.693/B262.355 (n3/warmup1). Different verification
and pipeline scopes remain explicit; these do not replace the normal CLI table.


## October 3, 2026: indexed reverse signature validation

[Typed signature consumers](../../../../../src/validate/typecheck.mbt) replace
both reverse iterators with descending index loops. Stack order, first-error
partial consumption, subtyping, concrete/unreachable values and all verification
remain. Array.rev_iter constructs an ArrayView iterator with a captured mutable
index (Moon core builtin/arrayview.mbt:909); native factory/callback calls now
vanish. No cache, new allocation, admission shortcut or public API change.

Baseline main 3d46f7e52/native 43feef6e…→8bfe3761…; same 6,211,596-byte input,
12,904 functions, verified133, release native O2/mimalloc/CPU6. Complete normally
exited, hash-matched DAE2 instructions 34,301,861,068→33,591,502,988 (−2.070902%);
CL 40,482,682,526→40,006,461,795 (−1.176357%). Direct mi_malloc calls fall exactly
5,634,510/4,331,346, matching the removed iterator-factory requests. Typed-pop
checks remain5,654,980/4,146,538. These are scoped allocation-call reductions,
not net bytes or peak RSS; nested costs are not added. The executable shrinks
14,629,992→14,629,704 bytes.

Normal fresh-process/warm-filesystem CLI, alternating n5 after warmup1, build
excluded, median±MAD milliseconds; **every row flags foreign CPU activity**:

| Pass | Before CLI (ms) | After CLI (ms) | B133 CLI (ms) | After/B |
| --- | ---: | ---: | ---: | ---: |
| DAE2 | 8454.112±790.078 | 10046.601±1881.049 | 2302.340±37.439 | 4.364× |
| DAE2-O | 12296.591±714.418 | 12274.750±584.269 | 3953.546±449.402 | 3.105× |
| CL | 5300.039±357.333 | 5348.326±288.166 | 2323.327±173.602 | 2.302× |
| OI | 2849.863±8.979 | 2890.100±23.164 | 1156.685±21.116 | 2.499× |

The DAE2 initial after range7402.959–12442.790ms and pinned reference-control
regression prompted one bounded repeat, not replacement of the first cohort.
OI's first paired+1.732% also warranted a repeat. Same binaries/options/CPU6,
n3 after warmup1, still flagged foreign activity:

| Pass | Before CLI (ms) | After CLI (ms) | B133 CLI (ms) | After/B |
| --- | ---: | ---: | ---: | ---: |
| DAE2 | 4748.599±16.029 | 4762.781±26.670 | 1425.710±14.176 | 3.341× |
| OI | 2857.043±11.592 | 2825.212±17.848 | 1151.825±10.469 | 2.453× |

Repeat paired changes+.430/−1.874% do not establish a universal CLI speedup.
Initial paired DAE2/O/CL/OI+8.680/−6.411/+1.371/+1.732% remain recorded. Repeat
D2 RSS medians255756→255892KiB have overlapping255288–265612/255584–264924
ranges. First D2 RSS median255040→265276KiB shifts modes; OO294144→294352,
CL244524→244032 and OI158008→157368 do not prove a general peak-memory win.
Ten native controls retain the exact former loop. Initial reference mean
242.08±45.89→279.85±132.44ns worsens; repeat94.11±12.74→57.53±2.54ns improves.
Other initial control means: empty135.91→43.51ns, scalar109.00→55.78ns,
width 32 1.25→1.14µs, invalid653.65→329.67ns, with large spread retained locally.

Performance guard fails before/passes after for the actual native iterator and
callback. [Signature regressions](../../../../../src/validate/tc_reverse_types_wbtest.mbt)
and [operand regressions](../../../../../src/validate/tc_matched_pop_wbtest.mbt)
retain error order, reference subtyping and virtual bottoms; implementing/CLI
fixtures prove active DAE2 pruning through scalar/SIMD/GC-table operations.
13,403 default tests,3 focused native tests,10 controls (+2 repeated controls),
info/fmt/check/native build/API sync pass. Four runtime lanes pass 772 module
validations/2256 fixed result/effect/state/memory/trap observations against
original/before/after/133. Runtime-only compact-import expansion remains
separate from raw size/timing. All four raw output hashes remain exact, preserving
V83 and the99,251-byte canonical OO deficit; no new normalization is claimed.

The preceding pop_expect annotation-only trial passed tests but retained both
boxed-result boundaries; removing its unused optional counter also failed to
remove them. Both production edits were reverted. The optional wrapper was a
hypothesis, not a confirmed cause. Next: declaration-walker success boxes
(4,948,080 DAE2 direct allocation calls across all recursion contexts, zero in
this CL module-pass scope), lift shape tuples and actual command envelopes.
Canonical quality, memory modes,1× target and full CI/coverage/10000 GenValid
release gates stay open; long fuzz remains deferred. Manual source/native review
completed; no independent review of this patch. A separate baseline audit
reproduces validator, DAE and OI failures on both frozen binaries; these remain
[release blockers](../../../tooling/validation-gates.md#october-3-2026-reproduced-baseline-correctness-blockers).
Exact commands, versions/CPU/input/source hashes, dirty state, all samples and
spreads, complete profiles and rejection evidence:
`.tmp/large-pass-hotspots-20261001/main-reverse-types-performance-20261003.md`.


## October 3, 2026: allocation-free declaration scan success

The private recursive [reference-declaration worker](../../../../../src/validate/validate.mbt)
returns a nullable error instead of allocating Result.Ok(unit) at every successful
instruction. The expression/module Result APIs, every declaration and index
check, traversal order and first error remain unchanged. This is independent of
P00's unresolved control-frame validation defects; no verification is removed.

Frozen native 8bfe3761…→20ffcd71… on main 6f1bbff76,
release O2/mimalloc, Ryzen 7 8845HS/CPU 6, same 6,211,596-byte input and verified
Binaryen 133. Actual generated C success allocation sites go **6→0**, failing the
native guard before and passing afterward. Complete DAE2 instruction work is
**33,591,502,988→33,335,245,043 (-0.762865%)**;
direct allocator calls **104,676,351→99,728,271**,
including worker **4,948,080→0**.
These totals cover every recursive worker context, not just the largest one.
Worker invocations remain 4,948,080→4,948,080;
full traversal is retained.
Complete OI command work is **21,312,562,509→20,801,699,479
(-2.397004%)**, with direct allocator calls
**86,798,264→81,761,870** (worker
5,036,394→0). Both profiles exit normally and reproduce
measured output hashes. OI includes startup, parsing, validation, encoding and
teardown; it is not its narrow pass timer. This worker has zero allocation calls
inside the earlier CL module-pass scope; no CL-inner improvement is inferred.
Allocation requests are not allocated bytes or peak RSS; nested costs are not added.

Normal fresh-process/warm-filesystem CLI, alternating n=5 after one warmup,
build excluded; milliseconds median±MAD. Foreign activity is flagged in all
cohorts; retain every sample and do not compare causally with earlier host bands.

| Pass | Before CLI (ms) | After CLI (ms) | B133 CLI (ms) | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| DAE2 | 3634.517±11.463 | 3586.333±36.645 | 1124.879±12.804 | 3.188× | -1.636% |
| DAE2-O | 6134.001±13.262 | 6063.896±13.679 | 2308.920±5.633 | 2.626× | -0.845% |
| CL | 5566.959±13.272 | 5301.057±229.196 | 1778.561±28.860 | 2.981× | -1.317% |
| OI | 2150.872±8.404 | 2104.223±4.268 | 917.756±5.662 | 2.293× | -2.367% |

RSS distributions and separate n1 traced diagnostics remain in the local report;
no general peak-memory or 1× claim. The native executable remains
14,629,704 bytes.
Ten native controls retain the original recursive Result worker. Empty, flat128,
declared-reference128, nested16/128 and late-error128 cases include setup and
answer checks outside timing; full means, standard deviations and ranges are
retained in ref-decl-bench.log alongside the earlier unpinned pilot. Current
pinned means: empty 13.37→13.13ns, flat 888.06→295.14ns, references 1.08µs→439.35ns,
nested 1.02µs→367.89ns and late error 1.10µs→399.65ns. The earlier empty
15.37→15.72ns small cost is retained rather than replaced by this cohort.
DAE2 RSS median 255848→265924KiB is higher, with overlapping
247812–270048/245656–268668 ranges; optimizing 294264→294260, CL 244768→244724
and OI 156332→156140 do not establish a universal memory win. CL's clock ranges
3880.366–5580.230/3842.292–5530.252ms are especially broad.

[Three focused tests](../../../../../src/validate/ref_declaration_results_wbtest.mbt)
pass before/after: first error through every control/handler, changed declaration
membership and invalid-index rejection by the mandatory module validator. New
implementing and dispatcher fixtures preserve reference calls while actively
pruning a DAE2 argument. 13,408 default wasm-gc tests, info/fmt/check,
native release build, ten controls and README API sync pass; no public API diff.
Four fixed original/before/after/133 lanes validate 788 modules and compare
2304 result/effect/state/memory/trap observations. Runtime-only Binaryen compact-import
expansion is separate from timing and raw size. All four large raw hashes remain
identical, retaining V83 and the 99,251-byte canonical DAE2-O gap; normalization
was not rerun. Existing audit failures remain release blockers, not covered by
this positive cohort. Full CI/coverage/10,000 GenValid signoff remains outstanding;
long fuzz is deferred by user direction. Manual source/native review completed;
no independent review of this patch is claimed.

Exact commands, CPU/tools/input/source/binary hashes, dirty state, all samples,
spreads, profiles, native guard and tests:
`.tmp/large-pass-hotspots-20261001/main-ref-decl-performance-20261003.md`.


## October 3, 2026: inline private lift node shapes

The two private shape factories in [HOT lifting](../../../../../src/ir/hot_lift.mbt)
return one four-scalar `#valtype` record instead of heap tuples. All ten callers
immediately consume those fields. Type interning, constant/call-signature/memory/
instruction payload construction and operand order stay unchanged; no public API,
cache, validation or optimization-admission change. Both factories share the same
private record. Required payload allocation remains.

Frozen native 20ffcd71…→6c0783bd… on cbb68ea91, same release native
O2/mimalloc, Ryzen 7 8845HS/CPU 6, 6,211,596-byte compiler input and verified Binaryen 133.
Actual native CLI factory return-tuple sites go **22/5→0/0**; the record returns
inline. Complete normally exited, output-matched profiles:

| Scope | Before instructions | After instructions | Change | Removed allocator calls |
| --- | ---: | ---: | ---: | ---: |
| DAE2 module pass | 33,335,245,043 | 33,077,462,265 | -0.773304% | 2,827,170 |
| CL module pass | 40,007,028,213 | 39,883,336,242 | -0.309176% | 1,350,276 |

Direct/exact factory calls remain 2,320,525/506,645 in DAE2 and
1,096,576/253,700 in CL. The total allocation reduction is exactly one request
per factory call. Direct DAE2 payload requests remain 392,628 and exact 749,293;
the old 2,713,153 direct-factory requests were not all removable tuples. These
are allocation counts, not net bytes or peak RSS; inclusive nested costs are not added.

Normal fresh-process CLI with warm filesystem, rotating before/after/133 order,
n=5 after one warmup, milliseconds median±MAD; all rows flag foreign activity:

| Pass | Before CLI (ms) | After CLI (ms) | B133 CLI (ms) | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| DAE2 | 3564.684±14.868 | 3533.282±29.494 | 1115.990±9.002 | 3.166× | -0.466% |
| DAE2-O | 6111.902±61.623 | 6032.188±44.023 | 2354.697±49.686 | 2.562× | -0.779% |
| CL | 3830.191±12.153 | 3848.662±27.805 | 1775.686±1.656 | 2.167× | +0.824% |
| OI | 2094.510±4.850 | 2092.284±2.212 | 915.218±4.061 | 2.286× | -0.106% |

CL's initial clock cost (+0.824%) prompted one retained n=3 repeat with the same
binaries/options/CPU, also after one warmup: 3851.585±38.221
→3846.790±26.032 ms, Binaryen
1785.227±23.414 ms; paired
-0.840%. This does not replace the first cohort.
Do not claim a universal command-time win from helper or instruction counts.
Initial RSS medians (KiB) are DAE2 266176→265636, optimizing 294448→294332,
CL 249276→244784 and OI 156192→156488. Distributions overlap and allocator modes
remain unresolved; all ranges/MAD are retained locally. Native executable size is
14,629,704→14,629,776 bytes.

Twelve pinned native controls preserve the original factory bodies and compare
fields/payloads outside timing, with bounded payload storage per iteration.
128-item means: indices 1.56µs→929.33ns, constants 2.41→1.77µs, signatures 2.85→2.17µs,
memory 3.87→3.07µs and exact opcode 2.57→1.85µs; empty 9.61→9.96ns is noisy.
Full standard deviations/ranges are in lift-shape-native-pilot.log. A guard first
inspected a stale release/test C file; the corrected release/bench artifact and
fresh CLI artifact both prove zero tuple sites. Stale output is not signoff evidence.

[Three field/payload tests](../../../../../src/ir/hot_lift_shape_value_wbtest.mbt)
pass before/after. New implementing/dispatcher fixtures preserve memory and
indirect calls with active DAE2 argument removal. 13,413 default wasm-gc tests,
info/fmt/check/native build/API sync and twelve controls pass; no .mbti change.
Four runtime lanes validate 804 modules and compare 2352 original/before/after/133
observations. All four large raw hashes are identical, preserving V83 and all
known canonical gaps; no new normalization is claimed. The separate P00 DAE
control-operand repair is not part of this performance snapshot. Existing audit
failures and full CI/coverage/10,000 GenValid gates remain; long fuzz is deferred.
Manual source/native review only, no independent patch review.

Current complete DAE2 attribution: lift 10,756,411,581 instructions/10,422 calls;
dependency analysis 9,568,879,881/8,354, including CFG 5,101,044,999/7,926,
read sources 1,974,341,007/7,926 and entry proof 789,524,430/8,187. Lowering remains
4,645,667,526/2,468, final module validation 3,088,822,166/1. These are inclusive
instruction scopes, not elapsed milliseconds; do not sum nested owners. Next
priorities remain lifting/typechecking result/array churn, dependency CFG/source
work, optimizing cleanup, CL lowering and OI command validation. Every mandatory
check and the corrected control-operand model must remain.

Exact source/binary/input/tool hashes, commands, all samples/spreads, native guards,
complete profiles and runtime artifacts:
`.tmp/large-pass-hotspots-20261001/main-lift-shape-performance-20261003.md`.


## October 3, 2026: inline private lift data results

[The data-instruction checker](../../../../../src/ir/hot_lift.mbt) now returns
one private `#valtype HotLiftDataCheck` with state, pop count, owned pushed types
and nullable error. The single production consumer checks the error first.
This replaces the private tuple plus outer success box; public Result contracts,
all type/arity/underflow checks, generic replay, stack ownership and owned result
arrays are unchanged. Native return storage is 32 bytes. Cold failure uses one
empty-array object in place of its old error-wrapper object; no invalid-input
throughput improvement is claimed.

A native allocation guard failed before the change (three tuple and three
success allocation sites), and passes after it (zero of each). An annotation-only
trial retained all six sites and was rejected before finishing C compilation;
do not retry that annotation as a proven improvement. Actual native benchmark
reference bodies retain the boxed boundaries. Two ownership/mixed-result/error/
polymorphic tests pass before/after, and implementing/dispatcher fixtures require
active DAE2 argument pruning while preserving mixed call results. Existing stack
reuse assertions are retained through a test-only adapter. Sources:
[focused tests](../../../../../src/ir/hot_lift_data_result_wbtest.mbt),
[six native controls](../../../../../src/ir/hot_lift_data_result_perf_wbtest.mbt),
[DAE2](../../../../../src/passes/dead_argument_elimination2.mbt) and
[dispatcher](../../../../../src/cmd/cmd.mbt).

Complete, normally exited DAE2 module-pass profiles on frozen native
**de85d92e…→e84e9ce8…**, base **859df3181**, retain output hashes:

- Instructions **33,079,096,728→32,786,518,187 (−0.884482%)**.
- Allocation requests **96,901,101→91,244,831**, exactly **5,656,270 fewer**.
- Data-check calls remain **2,828,135**; direct helper requests
  **8,478,961→2,822,691**, exactly two removed per call. Remaining pushed-type
  storage and typechecking work are required, not counted as eliminated.
- This is allocation frequency, not allocated bytes, retained memory or RSS.

Normal fresh-process warm-filesystem CLI, n=5 after one warmup, rotating
before/after/v133, release native O2/mimalloc, Ryzen 7 8845HS/CPU 6,
6,211,596-byte compiler input. Milliseconds median±MAD; all cohorts flag foreign
activity. Separate traced diagnostics are excluded from these samples.

| Pass | Before CLI (ms) | After CLI (ms) | v133 CLI (ms) | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3524.430±16.371 | 3533.632±28.974 | 1110.311±1.031 | 3.183× | -1.226% |
| dae2-optimizing | 6036.762±23.389 | 6028.618±23.550 | 2359.435±49.714 | 2.555× | -0.135% |
| coalesce-locals | 3812.488±2.788 | 3815.997±18.325 | 1773.719±10.120 | 2.151× | +0.092% |
| optimize-instructions | 2092.184±11.596 | 2106.633±5.772 | 938.518±22.487 | 2.245× | +0.649% |

DAE2's median and paired statistic disagree within broad outliers; retain both.
No universal wall-clock or peak-memory win is established. DAE2 RSS median
increases 258,080→266,000 KiB, with overlapping ranges 245,132–266,012 and
247,952–266,636 KiB; fewer allocation requests do not establish lower peak memory.
The native executable grows by 160 bytes. Six native controls
(ten batches) are scalar 145.31±8.46→146.62±0.46 ns, prefix32
204.72±4.87→205.90±1.07 ns, and polymorphic 220.54±0.79→225.79±1.90 ns
(mean±standard deviation). The roughly 5 ns polymorphic cost is retained;
whole-consumer instruction/allocation savings do not erase that tradeoff.

13,423 default wasm-gc tests, info/fmt/check/native build/API sync and six controls
pass; no .mbti changes. Four fixed runtime lanes validate 804 artifacts
and compare 2352 original/before/after/verified133 observations, including
GC, mixed tuples, effects, exceptions, memory and traps. All four large raw hashes
are exact. V83 and canonical gaps remain: DAE2-O still wins 9,949 raw bytes but
loses 99,251 bounded canonical bytes. No new normalization claim is made.

Current DAE2 inclusive ownership: lift 10.463b instructions/10,422 calls;
dependency analysis 9.571b/8,354 including CFG 5.103b/7,926 and read sources
1.975b/7,926; lowering 4.646b/2,468 and final module validation 3.089b/1.
These are inclusive instructions, not milliseconds; nested scopes cannot be
summed. Next work remains checked node access, CFG/source work, remaining
2,925,466 private typecheck wrapper allocations and 2,822,691 pushed-container
requests. Ownership and validation invariants remain mandatory.

Manual source/native review only; no independent patch review. Full CI/coverage
and long GenValid campaigns remain deferred during focused performance work.
Validator/merge-blocks/OI ordering and untriaged audit failures still block release;
this performance slice closes none of those defects or the 1× target.
Exact commands, source/tool/input hashes, samples/spreads and runtime/profile
artifacts: `.tmp/large-pass-hotspots-20261001/main-lift-data-performance-20261003.md`.

## October 3, 2026: Borrow scalar lift result storage

The known-arity data checker was allocating an owned result row for every
instruction, including empty and single-value results. A lazy private row now
belongs to each `HotLiftLabelFrames` function owner. The checker clears it at
entry (also on errors), uses it only for empty/scalar known-arity results, and
retains owned rows for multi-value results and the generic fallback.

This is a storage change, not an admission shortcut. Every prior typecheck,
underflow, trap and reachability rule still runs. The row is disjoint from the
validation stack and consumed before the next data check. Scalar interning and
concrete-stack insertion copy its type; multi-result interning retains the
input array and therefore must never receive this borrowed row. Nested control
is lifted separately before data checking; it cannot reenter lifting with an
outstanding borrowed result. Default standalone calls still return owned rows.
Sources: [implementation](../../../../../src/ir/hot_lift.mbt),
[ownership/error/tuple regressions](../../../../../src/ir/hot_lift_scalar_results_wbtest.mbt),
[native controls](../../../../../src/ir/hot_lift_scalar_results_perf_wbtest.mbt),
[DAE2](../../../../../src/passes/dead_argument_elimination2.mbt) and
[dispatcher](../../../../../src/cmd/cmd.mbt).

The focused tests first fail 2/3 on scratch identity/content and clearing, then
pass 3/3. The tuple test proves interned multi-result types survive subsequent
scratch reuse. Implementing/dispatcher regressions require actual argument
pruning through nested GC tuple arms in both DAE2 modes. The native controls
retain the owned-result baseline and compare equal errors, stacks, types,
reachability and pop counts outside timing.

Ten native controls, ten batches of 100,000, mean±SD nanoseconds:
empty 132.13±0.64→126.65±0.43; scalar 163.14±0.57→144.66±0.70;
multi 165.16±0.79→168.70±0.83; polymorphic 236.52±1.57→235.88±1.23;
invalid underflow 188.73±0.86→201.30±6.05. Retain the multi/error costs;
the helper does not establish a universal gain. These controls exclude the
production lazy-owner lookup, which is included in complete-pass measurements.

Complete normally exited DAE2 profiles on base **8e2106157**, frozen native
**e84e9ce8…→e49a80b5…**, preserve exact raw bytes:

- Instructions **32,786,518,187→31,593,019,927 (−3.640210%)**.
- Allocation requests **91,244,831→86,233,646**, **5,011,185 fewer**.
- Data-check calls stay **2,828,135**. Direct result-row allocations fall
  **2,822,691→1,315**; the new lazy owner allocates **10,422** rows.
  Remaining savings include backing storage, not eliminated checking work.
- Inclusive lift falls **10,462,826,364→9,268,390,416** instructions with
  **10,422** calls. Required lowering remains **2,468** calls and final module
  validation **one**. Inclusive scopes are not additive or milliseconds.
- Generated native C uses nullable pointers for optional scratch, adding no
  Some allocation per instruction. The executable grows **88 bytes**.
  Counts measure requests, not allocated bytes, retained memory or RSS.

Normal fresh-process warm-filesystem commands use release native O2/mimalloc,
Ryzen 7 8845HS/CPU6, fixed 6,211,596-byte input, verified v133, one warmup and
five rotating before/after/oracle samples. Build, Callgrind and traced probes
are outside normal timing. All cohorts flag foreign activity. DAE2-O's oracle
work is explicitly `--dae2 --simplify-locals --vacuum`.

| Pass | Before CLI ms median±MAD [min,max] | After CLI ms median±MAD [min,max] | Binaryen133 ms median±MAD [min,max] | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3783.525±5.818 [3777.708,3972.200] | 3729.058±15.841 [3689.949,3793.261] | 1207.932±18.182 [1189.319,1257.112] | 3.087× | -1.288% |
| dae2-optimizing | 6547.408±50.960 [6420.809,6598.368] | 6432.517±25.225 [6407.291,6584.904] | 2443.735±12.309 [2414.993,2456.165] | 2.632× | -1.397% |
| coalesce-locals | 4110.753±31.319 [4079.433,4187.426] | 4082.557±62.386 [4020.171,4216.255] | 1923.753±13.087 [1900.254,1952.705] | 2.122× | -0.003% |
| optimize-instructions | 2279.020±25.456 [2253.564,2372.876] | 2272.608±14.873 [2257.735,2347.967] | 1002.980±3.014 [983.134,1005.994] | 2.266× | +0.252% |

Separate traced inner diagnostics (n1, ms; not normal CLI samples):
dae2: before 3065.561, after 2976.012
dae2-optimizing: before 5654.091, after 5799.173
coalesce-locals: before 3171.163, after 3252.704
optimize-instructions: before 86.775, after 84.472

Peak RSS KiB:
dae2: before {'median': 265592, 'mad': 336, 'min': 245860, 'max': 265928, 'samples': 5}, after {'median': 265744, 'mad': 496, 'min': 255360, 'max': 268332, 'samples': 5}
dae2-optimizing: before {'median': 294408, 'mad': 24, 'min': 294384, 'max': 294624, 'samples': 5}, after {'median': 294228, 'mad': 128, 'min': 292252, 'max': 294356, 'samples': 5}
coalesce-locals: before {'median': 244676, 'mad': 60, 'min': 244144, 'max': 244776, 'samples': 5}, after {'median': 244636, 'mad': 32, 'min': 244400, 'max': 244668, 'samples': 5}
optimize-instructions: before {'median': 156148, 'mad': 96, 'min': 155800, 'max': 157560, 'samples': 5}, after {'median': 156428, 'mad': 64, 'min': 156364, 'max': 158144, 'samples': 5}

DAE2/DAE2-O paired normal commands improve about 1.3/1.4%; CL is flat and OI
has a +0.25% paired movement despite a slightly lower median. Traced n1 OO/CL
samples move oppositely to the normal medians; do not infer a universal speedup.
RSS ranges overlap; no peak-memory win is established. No CL-specific allocation
profile was run, and DAE2 counts must not be attributed to CL.

13,428 default wasm-gc tests, info/fmt/check/native release build/API sync and
ten controls pass with no .mbti changes. Four fixed 50-fixture runtime lanes
validate 820 artifacts and compare 2400 original/before/after/v133 observations,
including nested GC tuples, effects, memory, exceptions and traps. All four
large raw hashes are unchanged. V83's 79,962-byte saving and canonical gaps are
preserved, not remeasured: DAE2-O +99,251 B despite −9,949 raw B; CL +78,800 B,
SL +373,507 B and OI +33,497 B remain open.

Next work targets remaining typed-pop success wrappers and dependency/CFG
scans. Generic/multi-result storage remains owned; do not widen scratch reuse
across retention boundaries. Manual source/native review only; independent
patch review, full CI/coverage and long GenValid signoff remain outstanding.
The known validator/merge-blocks/OI ordering defects still block release.
The 1× target is not met. Exact manifests, commands and samples:
`.tmp/large-pass-hotspots-20261001/main-lift-scalar-performance-20261003.md`.

## October 3, 2026: Keep validation state across typed operand pops

`TcState::pop_expect` already mutates the owned stack and returns the identical
state on success; it never replaces environment, reachability, escape state or
local initialization. Its private `pop_expect_error` worker now returns only a
nullable error. Existing Result consumers retain an adapter. Reverse signature
pops and unary/binary typechecks keep their state and call the worker directly,
removing intermediate success wrappers while retaining final Result contracts.
Every original underflow/subtype/bottom test, pop order and first-error exit
remains. This is not the previously rejected inlining/unused-parameter trial.
Source: [typecheck](../../../../../src/validate/typecheck.mbt).

The native boundary regression fails before implementation: reverse pops,
unary and binary consumers call the boxed pop once/once/twice. Correctness
regressions preserve state identity, untouched environment/control/local
metadata, prefix ownership, partial consumption on mismatch/underflow, virtual
bottom versus concrete unreachable operands, and GC subtype matching. Three
new contracts and three existing reverse-pop tests pass before/after; the
initial expected error capitalization was corrected to the existing uppercase
format before applying the implementation, not classified as a product defect.
Sources: [contracts](../../../../../src/validate/typed_pop_wbtest.mbt),
[reverse-pop coverage](../../../../../src/validate/tc_reverse_types_wbtest.mbt)
and [ten native controls](../../../../../src/validate/typed_pop_perf_wbtest.mbt).

Ten native controls (ten batches×100000), mean±SD nanoseconds:
empty14.97±.07→14.69±.04; width32 338.14±.73→223.86±1.13;
two GC references50.43±.16→42.34±.21; invalid124.12±.33→118.72±2.50;
two scalars34.86±.26→27.15±.12. Both reference and current paths refill the
same-sized stacks in timing. Frozen reference retains the old Result boundary;
error text, stack and reachability are compared outside timing. Empty overhead
is effectively flat; these controls do not establish whole-pass gains.

Complete normally exited DAE2 module-pass profiles on base **394256e08**,
frozen native **e49a80b5…→a167be6a…**, retain the same output hash:

- Instructions **31,593,019,927→31,455,066,883 (−0.436657%)**.
- Allocations **86,233,646→83,304,937**, **2,928,709 fewer**.
- All **5,654,980** typed operand checks remain. The direct consumers account
  for **1,571,807** reverse-signature, **1,340,003** binary and **30,102** unary
  worker calls; the remaining adapter still receives **2,713,068** calls.
- Old pop adapter allocator requests **5,641,787→2,713,068**; the new error
  worker has **10** attributed allocations on error paths. The difference is
  not inferred from invocation counts. Native C has no direct worker allocator
  site and returns nullable `moonbit_string_t`; error formatting can allocate.
- Inclusive lift instructions **9,268,390,416→9,194,916,767**, **10,422** calls.
  Counts are requests, not allocation bytes or RSS. The executable shrinks48B.

Normal timing uses release native O2/mimalloc, CPU6/Ryzen7 8845HS,
6,211,596-byte input, verified v133, n5 after one warmup, rotating
before/after/oracle commands. Commands start fresh with a warm filesystem;
no build/profile/tracing time is mixed into these milliseconds. Foreign
activity is present throughout. OO's oracle is `--dae2 --simplify-locals --vacuum`.

| Pass | Before CLI ms median±MAD [min,max] | After CLI ms median±MAD [min,max] | Binaryen133 ms median±MAD [min,max] | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3806.707±81.646 [3716.323,3905.095] | 3714.480±20.465 [3677.913,3817.478] | 1226.664±38.299 [1183.663,1286.450] | 3.028× | -2.244% |
| dae2-optimizing | 6378.697±9.104 [6364.815,6546.889] | 6446.464±64.843 [6311.428,6511.307] | 2424.103±2.495 [2409.052,2463.202] | 2.659× | +1.062% |
| coalesce-locals | 4076.733±18.430 [4058.302,4277.824] | 4104.785±52.452 [4016.339,4201.829] | 1923.455±15.406 [1904.696,1943.073] | 2.134× | -0.116% |
| optimize-instructions | 2273.506±8.423 [2263.946,2304.261] | 2288.174±36.049 [2252.125,2424.081] | 973.694±8.860 [964.834,990.172] | 2.350× | +0.581% |

Separate traced inner diagnostics (n1, ms; not normal CLI samples):
dae2: before 2931.191, after 2950.523
dae2-optimizing: before 5799.438, after 5615.831
coalesce-locals: before 3092.17, after 3081.568
optimize-instructions: before 86.473, after 84.05

Peak RSS KiB:
dae2: before {'median': 266780, 'mad': 604, 'min': 266136, 'max': 267776, 'samples': 5}, after {'median': 265584, 'mad': 832, 'min': 246244, 'max': 266416, 'samples': 5}
dae2-optimizing: before {'median': 294392, 'mad': 100, 'min': 294180, 'max': 294528, 'samples': 5}, after {'median': 294324, 'mad': 152, 'min': 294172, 'max': 294520, 'samples': 5}
coalesce-locals: before {'median': 244648, 'mad': 200, 'min': 243996, 'max': 244920, 'samples': 5}, after {'median': 244624, 'mad': 204, 'min': 244108, 'max': 244828, 'samples': 5}
optimize-instructions: before {'median': 157864, 'mad': 1024, 'min': 156272, 'max': 158888, 'samples': 5}, after {'median': 157224, 'mad': 1040, 'min': 155664, 'max': 158672, 'samples': 5}

DAE2 paired CLI improves2.244%, OO regresses1.062%, CL is flat(-.116%) and
OI moves+.581%. DAE2/OO's single traced samples move oppositely. This proves
lower work/allocation cost, not a consistent command-time win; the OO/OI
clock movements remain open rather than being discarded or resampled away.
RSS ranges overlap and do not establish a peak-memory improvement. DAE2 work
counts are not new CL/OI allocation measurements.

13,431 default wasm-gc tests, info/fmt/check/native release build/API sync,
six focused contracts and ten controls pass; no .mbti changes. Four fixed
50-fixture lanes validate820 artifacts and match2400 original/before/after/v133
observations with all four large raw hashes exact. The runtime driver initially
referenced a renamed fixture file; it was corrected to the existing fixture and
resumed without rerunning completed timing. Both initial and resumed logs are
retained. This was a harness path failure, not a runtime mismatch.

Raw and bounded canonical sizes are preserved, not renormalized: OO+99,251B
canonical despite−9,949B raw; CL/SL/OI deficits78,800/373,507/33,497B remain.
Next work is the measured private lift adapter and remaining typed-pop consumers,
then larger CFG/source analysis owners. No tests, checks, coverage thresholds or
optimization work were removed. Manual review only; independent review, full
CI/coverage and long GenValid signoff remain outstanding. Known validator,
merge-blocks and OI ordering failures still block release; 1× is not met.
Exact evidence: `.tmp/large-pass-hotspots-20261001/main-typed-pop-performance-20261003.md`.

## October 3, 2026: Inline the private lift validation adapter

The private lift adapter rewrapped every validator success into another Result.
It now returns a private16-byte `HotLiftTypecheck` value with state and nullable
error. All14 production consumers check the error before taking the state.
The original boxed helper lives only in white-box test support, preserving
existing benchmark references and error/state comparisons. Underlying validation,
message construction, stack ownership, ordering and fallback remain unchanged.
Sources: [lift](../../../../../src/ir/hot_lift.mbt),
[contracts/frozen adapter](../../../../../src/ir/hot_lift_typecheck_result_wbtest.mbt),
[six native controls](../../../../../src/ir/hot_lift_typecheck_result_perf_wbtest.mbt).

The generated-C regression first finds a success allocation in the old adapter;
afterward the production boxed helper is absent and the new adapter returns an
inline record with zero direct allocator sites. Seven focused tests cover state
identity/replacement, metadata, partial failure, owned stacks and mixed GC call
results. A constructor spelling in the new test was corrected before its seven
passing checks; that compilation mistake is not classified as a product failure.
Native controls (ten batches×100000), mean±SD ns: empty59.25±3.24→54.38±1.29,
scalar81.32±.48→75.91±.87, invalid121.52±1.44→116.94±.60. Underlying typechecking
and fresh state creation are present on both sides.

Complete DAE2 profiles on base **e1b1b231b**, native **a167be6a…→c4b08d28…**:

- Instructions **31,455,066,883→31,294,759,765 (−.509638%)**.
- Allocations **83,304,937→80,379,471**, exactly **2,925,466 fewer**.
- All **2,925,466** adapter calls remain; one success allocation disappears per
  call on this valid fixture. This does not count retained validation work as
  eliminated, or confuse allocation requests with bytes/peak memory.
- Normally exited, exact validated output; public API unchanged. Executable+160B.

Normal command evidence uses CPU6/Ryzen7 8845HS, release native O2/mimalloc,
6,211,596-byte input, verified v133, n5 after one warmup and rotating
before/after/oracle order. Build/profile/tracing are excluded; foreign activity
is recorded. OO's oracle work is `--dae2 --simplify-locals --vacuum`.

| Pass | Before CLI ms median±MAD [min,max] | After CLI ms median±MAD [min,max] | Binaryen133 ms median±MAD [min,max] | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3788.901±13.987 [3665.076,3812.826] | 3764.677±33.171 [3638.326,3797.848] | 1184.931±8.928 [1176.003,1235.951] | 3.177× | -0.550% |
| dae2-optimizing | 6731.294±149.610 [6564.157,6968.796] | 6529.919±103.678 [6426.241,6786.176] | 2481.562±41.096 [2435.128,2668.325] | 2.631× | -2.625% |
| coalesce-locals | 4277.978±153.791 [4123.974,4438.892] | 4253.110±136.577 [4111.358,4466.431] | 1980.969±59.332 [1919.117,2092.915] | 2.147× | +0.782% |
| optimize-instructions | 2334.202±41.024 [2244.318,2404.330] | 2344.358±20.633 [2304.710,2364.991] | 988.914±4.683 [968.705,1026.239] | 2.371× | -0.816% |

Separate traced inner diagnostics (n1, ms; not normal CLI samples):
dae2: before 2959.376, after 2977.508
dae2-optimizing: before 5660.357, after 5706.357
coalesce-locals: before 3409.575, after 3125.322
optimize-instructions: before 87.964, after 91.058

Peak RSS KiB:
dae2: before {'median': 266208, 'mad': 188, 'min': 255348, 'max': 266396, 'samples': 5}, after {'median': 266408, 'mad': 1084, 'min': 246168, 'max': 268860, 'samples': 5}
dae2-optimizing: before {'median': 294340, 'mad': 56, 'min': 294284, 'max': 294596, 'samples': 5}, after {'median': 294368, 'mad': 8, 'min': 292384, 'max': 294460, 'samples': 5}
coalesce-locals: before {'median': 244724, 'mad': 20, 'min': 243892, 'max': 244884, 'samples': 5}, after {'median': 244568, 'mad': 156, 'min': 243868, 'max': 244748, 'samples': 5}
optimize-instructions: before {'median': 157480, 'mad': 1116, 'min': 156192, 'max': 158684, 'samples': 5}, after {'median': 156436, 'mad': 400, 'min': 156036, 'max': 157832, 'samples': 5}

Paired DAE2/OO CLI changes are−.550/−2.625%; CL/OI+.782/−.816% have median
movements of the opposite sign. Single traced diagnostics remain separate;
foreign activity, broad spreads and overlapping RSS prohibit a universal clock
or peak-memory claim. DAE2 allocation counts do not measure CL/OI allocations.

13,433 default wasm-gc tests, info/fmt/check/native release/API sync, seven focused
contracts and six native controls pass. Four50-fixture runtime lanes validate820
artifacts and match2400 original/before/after/v133 observations; all four large
raw hashes and .mbti files are unchanged. Prior V83 savings and canonical gaps
are preserved, not newly normalized: OO+99,251B despite−9,949 raw B;
CL/SL/OI+78,800/+373,507/+33,497B remain open.

Next work is continuation-presence scanning in CFG setup and empty child-array
construction in zero-operand node building. Validation cannot simply be shared:
DAE2 performs type cleanup after its internal validate call, while CLI final-module checking sees that later result. Extra post-encode
decode/validation is **debug-serial-only**, not active in these normal commands.
Keep existing checks in their enabled modes. See [DAE2 finalization](../../../../../src/passes/dead_argument_elimination2.mbt)
and [post-encode checking](../../../../../src/cmd/cmd.mbt).

Manual source/native review only; independent review, full CI/coverage and long
GenValid signoff are outstanding. Known validator/merge-blocks/OI ordering
failures and the1× target remain open. Exact manifests, commands and samples:
`.tmp/large-pass-hotspots-20261001/main-lift-check-performance-20261003.md`.

Validation-scope clarification: the earlier adapter note described the optional
post-encode checker without its guard. `should_validate_encoded_module_after_encode`
returns `debug_serial_passes`; normal commands do not execute that decoder/checker.
A nonzero `cmd:post-encode-validate` timer alone does not prove it ran. The normal
final-module validator remains active, and DAE2's intervening type cleanup still
prevents simply transferring its earlier validation result. No checks were removed.


## October 3, 2026: prove absent CFG continuations from verified side tables

Main2af3566fa, native c4b08d28…→62e79f73…; same6,211,596B compiler
fixture (SHA98189860…), verified Binaryen133 (SHA8f25e9fd…), GCC14.2/O2/
mimalloc, Ryzen8845HS and CPU6. Full manifests retain dirty state and commands.

`cfg_build` verifies all HOT nodes before `cfg_builder_new`. Both `Continuation`
and `BrTable` require a branch-table side entry (`hot_side_tables.mbt`,
`hot_verify_core.mbt`). An empty branch-table arena therefore proves there is
no live continuation, even when handlers would be empty. Skip only that initial
presence scan. Nonempty arenas, including unused/deleted entries and br_table,
retain the complete live-node scan. No cache, allocation or verification change;
both operand-expanded and conservative graphs retain exact fields/edge order.

The native regression first lacks the metadata read and then guards the typed
side-arena read plus retained fallback. The initial green checker used field
names that native C lowers to positional fields; it was corrected before
measurements, with the failed build-driver log preserved. Two field/whole-graph
regressions cover branch mutation, br_table, resume handlers, deleted nodes,
unused tables and independent storage; existing continuation/workspace tests
also pass.13,435 bounded default tests and README/API sync pass. Twelve native
controls retain both absent and fallback cases. Empty83.83→86.01ns; absent
32/512 nodes210.92→91.65ns and1.93µs→108.76ns; unused table196.87→209.88ns
and1.86→2.09µs; resume169.60→176.50ns. The earlier trial without an empty-node
guard remains recorded; tiny/fallback regressions are not hidden.

Complete normally exited DAE2 instruction profile31,294,759,765→31,143,999,404
(−.481743%); direct allocator requests unchanged80,379,471. Constructor incoming
cost190,511,541→37,120,472 (7,926 calls unchanged), exclusive46,553,193→7,681,695.
Outgoing live/getter checks each2,524,643→363,354:2,161,289 node probes avoided;
the retained363,354 prove the conservative fallback executes. Dependency owner
9,570,125,580→9,418,524,479 instructions/8,354 calls. These are nested inclusive
owners, never additive times. Public verification remains before/after CFG;
mandatory module validation remains one call. No native executable-size change.

Normal CLI, one warmup/n5 alternating fresh processes with warm filesystem;
median±MAD milliseconds (build/profile excluded):

| Pass | Before | After | Binaryen133 | S/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3855.883±68.303 | 3787.851±113.847 | 1229.090±17.222 | 3.082× | -1.764% |
| dae2-optimizing | 6581.130±52.625 | 6486.703±24.644 | 2489.494±31.941 | 2.606× | -1.435% |
| coalesce-locals | 4078.572±23.496 | 4079.786±69.745 | 1910.801±13.077 | 2.135× | +0.030% |
| optimize-instructions | 2301.117±29.198 | 2270.293±25.726 | 964.935±3.357 | 2.353× | -0.016% |

Every normal row flags foreign CPU activity; DAE2 traced n1 inner3038.446→
3067.618ms contradicts its normal improvement, CL/OI medians and paired results
also differ. Independent OO/CL/OI traced inner5662.848→5618.358,
3178.939→3121.230,87.947→85.027ms are diagnostics, not refreshed matched B
pass-local evidence. All n5 ranges/RSS modes are retained; DAE2 RSS median
257408→265976KiB and overlapping ranges are not a memory win. Four raw output
hashes are exact, with820 fixture validations/2400 runtime observations passing.
The separate resume fixture validates and has exact before/after130B bytes;
Binaryen writes81B. This remains an output-shape parity gap, not a demonstrated
Starshine win or a continuation runtime-equivalence proof. No continuation
runtime-engine oracle is claimed. Canonical gaps/V83 savings stay
unchanged, not newly normalized. Aggregate/full CI/coverage/independent review
and1× remain open; no long fuzz ran.

A complete OI command profile on62e79f73… executes20,611,236,125 instructions.
The module encoding-cleanup owner accounts for5,826,414,859 inclusive instructions:
simple type cleanup3,938,411,003, numeric local grouping1,142,372,070 and control
cleanup658,858,137. Two full module validations together5,058,030,295 are nested
inside cleanup and final command scopes, not extra additive costs. This confirms
material work outside the narrow OI timer, including validation and destruction;
it does not identify an invalidation-safe shortcut. Type-remapping arrays still
allocate capacity before any actual change; investigate lazy storage before
broad validation reuse. Descriptor bridges already have revision-index guards;
do not propose an absent-descriptor scan shortcut that is already implemented.

**Validation-scope clarification:** normal commands run final-module validation.
Extra post-encode decode/validation is enabled only by debug serial passes
(`cmd.mbt:should_validate_encoded_module_after_encode`). A timer named
`cmd:post-encode-validate` alone does not prove the branch ran. This supersedes
the prior log's unqualified post-encode wording; intervening DAE2 type cleanup
still prevents assuming its earlier validation applies to the final result.

Exact sources, hashes, RED/GREEN logs, microcontrols, command samples/spreads,
runtime rows and complete profiles:
`.tmp/large-pass-hotspots-20261001/main-cfg-presence-performance-20261003.md`.


## October 3, 2026: build zero-operand lift nodes without a default child row

Main435239e72, native62e79f73…→6c31b0ca…; same6,211,596B fixture SHA98189860…,
verified133 SHA8f25e9fd…, GCC14.2/O2/mimalloc, Ryzen8845HS and CPU6.
`hot_build_node` allocates its optional default empty Array[NodeId] even when no
child exists. New private `hot_build_node0` matches that branch's exact header,
flags, type/span checks, append order and revision through the same
`hot_alloc_node`. Only the direct lift family's zero-child case uses it. Other
fixed arities, exact/generic families and public builder contracts stay intact.
No mutable analysis reuse, admission or validation change; no new heap storage.

Native RED records one default-row allocation; GREEN records no direct worker
allocation and the actual production caller. Native emits `_inner` after
optional-argument wrapper optimization: the first checker expected a different
symbol, failed, and was corrected before measurement. The initial profile
waiter exceeded its build-freeze deadline, then was resumed after freeze; its
failed log is preserved. A fixture initially used a nonexistent reference
constructor and was corrected, not counted as a product regression. Two focused
field/payload/revision tests compare valid Nop, Const and nullable-reference
nodes and append behavior after a deleted child span, including whole HOT
verification.13,437 default tests/API sync pass. Six native controls (same
capacity reset on both paths, no unbounded node growth): Nop37.42±.46→30.53±.20ns;
Const37.09±.48→30.64±.24ns; RefNull38.68±.44→30.49±.19ns,10 batches each.

Complete normally exited DAE2 work31,143,999,404→30,806,104,978 instructions
(−1.084942%); direct allocation requests80,379,471→78,986,098 (−1,393,373).
Public default-row requests1,635,530→242,157, exactly matching the eliminated
production calls; remaining exact/generic/public sites still allocate. Checked
node allocation and transformation activity remain. Native executable+80B.
A separate whole OI command capture20,611,236,125→20,603,177,806 instructions
(−.039097%) establishes that DAE2's gain cannot be extrapolated to OI.

Normal fresh-process CLI/warm filesystem, build/profile excluded, one warmup/n5
alternating same-host median±MAD milliseconds:

| Pass | Before | After | Binaryen133 | S/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3687.765±26.796 | 3658.377±57.878 | 1191.762±6.590 | 3.070× | -1.652% |
| dae2-optimizing | 6482.809±57.867 | 6483.375±44.209 | 2491.149±24.871 | 2.603× | +0.742% |
| coalesce-locals | 4047.625±39.032 | 4066.139±73.039 | 1920.410±7.932 | 2.117× | +0.097% |
| optimize-instructions | 2284.702±40.845 | 2278.996±27.146 | 964.601±7.998 | 2.363× | -0.627% |

All normal rows flag foreign CPU activity. OO paired+.742% and CL+.097% remain
costs, not hidden by DAE2's−1.652%. Independent traced n1 inner DAE22919.221→
2927.553, OO5588.429→5722.324, CL3062.307→3019.794, OI84.767→85.470ms are
separate diagnostics, not refreshed matched Binaryen inner evidence. DAE2 RSS
median257760→248056KiB with overlapping255784–267428/245404–266264 ranges;
OO/CL/OI effectively flat. No consistent peak-memory or universal clock win.
Four large raw hashes, V83 and canonical gaps remain exact;820 fixed validations
and2400 runtime observations pass, API unchanged. Full CI/coverage/aggregate/
independent review and1× remain open; long fuzz remains deferred.

The current OI whole-command profile attributes6,011,833 direct allocation
requests to unsigned LEB encoding,975,957 to signed encoding and3,852,088 to
`RawOiTopLevelRootFact::from_instr` (including inlined children). The private
root and five-boolean flow records have no mutation or identity use found.
Next experiments: nullable-error LEB workers for measured immediate consumers,
then inline immutable OI records with native/layout/full-consumer proof. These
are hypotheses for improvements, not accepted changes or allocated-byte/RSS
claims. Lazy unchanged type-remap output storage is the current independent
unit; do not duplicate it. Ordinary Block/Loop/If lift processes children once;
only guarded legacy Try has a separate full typecheck, so repeated common
control validation is not established as the dominant source.

Exact commands, source/binary/input hashes, initial failures, controls,
normal/traced samples/spreads/RSS, runtime rows and full profiles:
`.tmp/large-pass-hotspots-20261001/main-node-zero-performance-20261003.md`.


### Continuation probe follow-up

The earlier raw-only130/81B classification now has matched normalization
 evidence:46B of Starshine's output is the retained `name` section and the
remaining raw84/81B core differs by an untargeted nested block and nominal
versus bottom continuation-null spelling. A single verified133 `--all-features
--strip-debug` no-optimizer writer maps both outputs to exactly81B/SHAf7e68dc8…,
with both externally validated. This is canonical byte equality for this small
fixture, not a renewed large canonical protocol or a continuation execution
oracle. The raw3B writer-shape reduction remains a quality lead with no measured
Starshine benefit; keep it separate from name metadata and the99,251B large gap.
Exact sections and commands: `cfg-presence-continuation-oracle/section-comparison.json`
and `matched-strip-debug.json` under the local campaign directory.


## October 3, 2026: renew optimizing cleanup priorities

The [fresh complete cleanup capture and Vacuum predicate repair](../vacuum/starshine-hot-ir-strategy.md#october-3-2026-reject-mismatched-vacuum-prefixes-before-recursive-scans)
uses main15255efd6/nativefd2af4bd… and the unchanged compiler input. Raw
SimplifyLocals and raw Vacuum own62.18%/25.07% of the19.663b cleanup instruction
root. The pure-copy flat worker is1.230b nested inside SimplifyLocals, so its
synthetic quadratic control alone does not justify priority over larger owners.
Three Vacuum predicates spend1.033b instructions on descendant scans before
fixed-prefix rejection; their exact conjunctions permit cheaper query ordering.

Next investigate `run_hot_pipeline_simplify_locals_cleanup_exact_func`: its
three nonrecursive incoming edges total3.067b instructions. Its disjoint direct
children include dead adjacent-pair cleanup1.177b, reachable local-get counting
.947b and body cleanup.754b. Counting recursively visits child bodies and then
calls branch-aware fallthrough predicates (`pass_manager.mbt`); repeated control
queries are a source-backed experiment, not a proven saving. Preserve label
owner depths, reachable reads after owner branches, handlers, traps and fixed-point
termination (including bitwise NaN/signed-zero comparison). Do not simply drop
fallthrough checks or sum recursive inclusive edges. The larger DAE2 dependency,
lift/lower, canonical-size and correctness blockers remain active.


## October 4, 2026: inline instruction-lift state and error

Baseline main `b34c4d0a4`, native `ec2a0ed4…` → `5132736f…`; verified
Binaryen133 `8f25e9fd…`, fixed 6,211,596B / 12,904-function compiler input
`98189860…`. The private instruction worker in
[`hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt) now returns the existing
inline state/error record. Its region caller consumes the same state or first
error immediately. Control lifting retains its Result adapter; typechecking,
source-access reservation, mutation ordering, validation and public APIs stay
intact. This removes success wrappers without retaining module-wide analyses.

Resource RED: 7,456,597 direct allocator requests in the instruction worker
exceeded the preselected 5,000,000 bound. Candidate 4,531,131 passes: **2,925,466
fewer requests**, with all 3,167,623 worker calls retained. Both complete DAE2
captures exited normally and preserved exact validated output. Scoped work
30,804,342,359 → 30,636,451,403 instructions (−0.545%). Disjoint analysis/rewrite
lift children 6,486,960,691 / 2,419,958,675 → 6,366,168,682 / 2,372,428,903;
dependency work remains about 9.417b, lower 4.647b, mandatory validation 3.032b.
These are instruction counts, not elapsed time or allocated bytes; nested scopes
are not additive. Parsing, final CLI validation and encoding are outside this
DAE2 profile.

Fresh-process CLI, warm filesystem, CPU6, one warmup / five rotating
before-after-oracle samples; build and instrumentation excluded. All values below
are **milliseconds**, median±MAD. OO's oracle is `--dae2 --simplify-locals
--vacuum --all-features`, not DAE/O. No transformations or features are omitted.

| Pass | Before | After | Binaryen133 | S/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3854.884±74.764 | 3839.607±51.388 | 1252.725±2.362 | 3.065× | +0.440% |
| dae2-optimizing | 6785.956±125.994 | 6688.206±89.721 | 2626.305±35.897 | 2.547× | +1.580% |
| coalesce-locals | 4348.877±204.266 | 4238.988±43.593 | 2027.743±58.606 | 2.090× | -5.872% |
| optimize-instructions | 2338.271±86.010 | 2503.762±157.348 | 1146.393±91.841 | 2.184× | +0.358% |

All normal rows flag foreign CPU activity. Paired DAE2/OO/OI results disagree
with changes in cohort medians; CL's reduction is not established as causal.
No reliable universal wall-time or RSS win is claimed. Candidate DAE2 RSS
267020±716KiB versus 266064±560 before; ranges overlap. Raw output hashes for
all four remain exact, retaining prior canonical quality and its unresolved gaps.
Independent n1 traced inner timers are diagnostics only, not matched Binaryen
pass-local evidence. The 1× target remains open for every pass.

Three new behavior controls passed before the representation change (not a
semantic RED). [`hot_lift_step_wbtest.mbt`](../../../../../src/ir/hot_lift_step_wbtest.mbt)
covers ordered local provenance including unreachable missing writes, first
concrete errors, references, tuples, branches and tail calls. Dispatcher coverage
in [`cmd.mbt`](../../../../../src/cmd/cmd.mbt) exercises all four consumers and
actual dead-argument removal. Six whole-lift wasm-gc release controls isolate
scalar/structured widths 1/64/1024; mean before→after µs: scalar 1.79→1.81,
37.76→36.94,580.37→593.96; structured 2.75→2.91,98.08→94.55,1860→1960.
These nonalternating controls have overlapping spreads and retain their costs;
they do not prove a wasm-gc speedup.

`moon info`, `moon fmt`, `moon check`, 13,451 wasm-gc tests, native release build
and README/API sync pass. Four fixed runtime lanes validate 820 artifacts and
compare 2,400 observations against original execution (values, ordered host
calls, state/memory and trap outcome); before/after bytes match. For five inputs
per lane, the Binaryen oracle is rewritten through its no-pass text writer and
wasm-tools parser to execute compact import encoding in Node. This is an
encoding adaptation, not an additional optimization. No independent review was
available; manual source/diff review completed. Full CI, coverage, long aggregate
fuzz and final release signoff remain outstanding; fuzz stays deferred as requested.

Next prioritize repeated DAE2-O cleanup traversal and remaining dependency/lift/
lower work. Transient local-access option tuples and remaining typed-pop adapters
are smaller allocation leads. OI's prior complete command profile attributes
5.352b instructions to module encoding cleanup, including 2.529b mandatory
validation and .873b exact encoding-size comparison inside DFE type cleanup;
do not mistake its narrow inner timer for the whole command or remove checks.

Local reproducible commands, environment and dirty-state/source/binary/input
hashes, raw normal/traced samples and spreads, profiles and runtime observations:
`.tmp/large-pass-hotspots-20261001/main-dae2-core-performance-20261004.md` and
`dae2-core-*` artifacts. This checkpoint supersedes earlier timing rows only for
this frozen source and host cohort; historical evidence retains its own scope.


## October 4, 2026: count reachable cleanup reads in one traversal

Main `fdee5e2b0`, native `5132736f…` → `c972d0ba…`, same verified133 oracle
and fixed 6.21MB compiler input as the preceding checkpoint. The private cleanup
read counter in [`pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
previously counted descendants and then rescanned them to establish control
fallthrough and branches to enclosing labels. A single walk now computes both,
using one temporary boolean stack sized by structured depth. No per-node cache,
retained analysis or weaker validation is introduced.

Preserve the exact conservative contract: stop counting after the first
nonfallthrough instruction, still observe syntactic branch targets in dead
suffixes, treat loop self-branches as backedges, include both if arms, retain
TryTable behavior, and isolate legacy Try/handler branch facts with a barrier.
The original shared DCE queries remain unchanged for other callers. Fixed-point
rounds use fresh state; instruction/branch-table visits are linear in body size.

Resource RED: the cleanup_exact → reachable-read edge used946,611,019 instructions,
failing the preselected500m budget. Candidate35,148,954 at the same4561 calls;
the wrapper inlines and stack setup now lives in the caller, so use the complete
cleanup total for inclusive costs: **18,623,004,024→17,705,751,580 (−4.9254%)**.
All25,802 per-function pipeline calls remain. Both captures exit normally with
exact validated output. This scope excludes initial DAE2, parsing, final CLI
verification and encoding. One small stack per count query adds allocations;
complete totals include their construction/growth/destruction. Counts are not
allocated bytes or elapsed time, and nested scopes are not summed.

Five wasm-gc release controls (ten batches) mean before→after µs: flat1.19→.778,
nested16 11.02→.872, nested64 47.79→1.22, nested128 119.07→1.66,
branching64 70.41→1.23. Module/body preparation is outside timing. These show
removal of repeated traversal; they do not establish a whole-command speedup.

Normal fresh-process commands, warm filesystem, CPU6, one warmup/n5 rotating
before/after/verified133, median±MAD **milliseconds**:

| Pass | Before | After | Binaryen133 | S/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3691.583±42.996 | 3671.821±21.550 | 1203.695±26.309 | 3.050× | -0.281% |
| dae2-optimizing | 6187.637±117.675 | 6291.698±157.740 | 2425.232±34.607 | 2.594× | -0.243% |
| coalesce-locals | 3997.735±19.120 | 4010.688±16.859 | 1915.291±16.899 | 2.094× | +0.826% |
| optimize-instructions | 2201.471±50.772 | 2174.979±18.727 | 1002.350±9.602 | 2.170× | -1.203% |

All rows flag foreign CPU. OO's cohort median worsens while its paired median
slightly improves; both are within spread. CL's+.826% paired observation stays
visible. No universal normal-command or RSS gain is claimed. OO peakRSS
291816±520→293796±564KiB has overlapping291296–294304/290872–294360 ranges.
All four raw output hashes remain exact; V83 and canonical gaps are preserved.

Separate n3 alternating traced diagnostics (one warmup), Star inner / pipeline /
Binaryen inner medians in ms: DAE2 2844.130 /2862.076 /455.075;
DAE2-O 5317.023 /5334.959 /1724.986 (per-sample sum of133 DAE2, SL and Vacuum);
CL3090.017 /3111.265 /1256.690; OI89.921 /1679.221 /249.915.
OI's narrow timer excludes raw and module cleanup and is not equivalent to a
complete Binaryen pass. Binaryen debug mode adds verification outside its timers;
never compare its debug command wall time with normal CLI. All traced rows also
flag foreign load. None of the four complete-work1× targets is closed.

Eight branch/read-count cases plus three TryTable/legacy-handler cases passed
before implementation; the resource budget is the RED, not a semantic failure.
A dispatcher case retains ordered imported calls after an enclosing branch exit
and verifies actual dead-parameter removal. Info/fmt/check,13454 wasm-gc tests,
five release controls, native release build and README/API sync pass; no public
API diff. Four fixed runtime lanes validate852 artifacts and compare2496
observations against original execution, including new owner-exit/effect/trap
cases; before/after bytes match. The existing compact-import oracle encoding
adaptation remains documented in the preceding checkpoint. Manual source review
found balanced frame lifetimes and unchanged handler/unknown-opcode policy;
independent review was unavailable. Full CI/coverage/aggregate fuzz and known
correctness/quality release blockers remain open; long fuzz stays deferred.

Next: discarded speculative typecheck diagnostics (Expr renders failed
instructions while the suffix caller discards Err); original-read recollection
in adjacent-pair cleanup; and the smaller quadratic nop-hoist run scan. The nop
worker rescans a homogeneous unchanged run after advancing by one instruction;
its two direct incoming edges total216m instructions. Avoid duplicating previous
read-set copying, future-mask and rejected statement-cache experiments.
Commands, all hashes/dirty state, raw spreads/RSS, profiles and runtime evidence:
`.tmp/large-pass-hotspots-20261001/main-cleanup-flow-performance-20261004.md` and
`cleanup-flow-*` artifacts. Historical rows retain their source and scope.


### Bounded normal-clock repeat

One reversed-order n5 OO repeat retains the first cohort: before6149.065±57.934,
after6182.957±89.559, verified1332491.699±14.323ms (2.481×); paired−.905%.
All rows still flag foreign CPU and median/paired directions disagree within
spread. RSS292048→291300KiB overlaps290472–293696/290888–294452. Thus the
algorithmic and native-work reduction is confirmed, but a reliable enclosing
clock or peak-memory gain is not established. No further repeat was run.

## October 4, 2026: omit discarded speculative diagnostics

Baseline main322ce0236/nativec972d0ba… → native8675a6c2…. Suffix probing
performed169,849 expression checks, discarding failure diagnostics. Its inclusive
checker edge cost1.410b instructions, including an outer Instruction rendering
edge459m. The shared expression loop now accepts a private diagnostic-context
flag; normal Typecheck retains full errors, while `typecheck_expr_for_probe`
omits only the unused outer wrapper. All checks, first error, successful state,
local initialization ownership and nested diagnostics remain. Only suffix
probing adopts this API; no validation or transformation is bypassed.

Two diagnostic regressions failed before implementation. State, typed-block
suffix and dispatcher fixtures preserve behavior; five wasm-gc release controls
include valid and rejected expressions. Failed width1024 falls15.40→4.80µs;
valid width1024 is4.65→4.52µs. Tiny valid spreads overlap. Mechanical source
review confirms the old loop is identical after reverting only the input binding
and wrapper branch. See the [diagnostic contract](../../../validate/diagnostics-and-invalid-repro.md#speculative-expression-checks)
and [implementation/tests](../../../../../src/validate/typecheck.mbt).

Complete per-function DAE2-O cleanup17,705,751,580→16,969,069,128 instructions
(−4.1607%); all25,802 pipeline calls remain. Raw SL11.316b→10.580b; the same
169,849 suffix checks cost660m. Recursive formatting edges move into one shared
worker and cannot be treated as additive phase or allocation totals. Initial
DAE2, parse, CLI validation and encoding are outside this collected scope.
Normal exit and exact externally validated output are required.

CPU6 normal fresh-process/warm-filesystem CLI, warmup1/n5, milliseconds:

| Pass | Before ms ± MAD | After ms ± MAD | Binaryen133 ms ± MAD | After / B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3619.516 ± 13.068 | 3624.575 ± 26.058 | 1178.950 ± 5.046 | 3.074× | +0.140% |
| dae2-optimizing | 6270.785 ± 22.417 | 6199.276 ± 26.283 | 2506.915 ± 38.875 | 2.473× | -1.112% |
| coalesce-locals | 4035.289 ± 13.612 | 3989.640 ± 47.455 | 1936.849 ± 2.816 | 2.060× | -1.131% |
| optimize-instructions | 2168.047 ± 9.862 | 2168.451 ± 38.167 | 955.649 ± 5.298 | 2.269× | -0.434% |

All rows flag foreign CPU. OO saves71.509ms at the median in this cohort;
plain/OI remain within spread and CL movement lacks a CL-specific attribution.
RSS ranges overlap. Separate single-run Starshine traces are diagnostic, not
matched Binaryen inner comparisons; prior n3 pass diagnostics retain their
source/date. All four exact raw hashes remain; canonical gaps are preserved,
not re-normalized. None of the complete-work1× targets is closed.

Info/fmt/check,13,458 tests, five controls, native release and API sync pass.
55 fixed fixtures×four modes give896 validations/2624 available observations;
54 fixtures complete four-way execution per DAE2 mode and55 per CL/OI. The
multivalue failure below is explicitly excluded from passed Starshine execution
counts, while its Binaryen/original observations are recorded. Full CI, coverage,
aggregate fuzz and independent review remain outstanding. Commands, hashes,
spreads and local report: `.tmp/large-pass-hotspots-20261001/probe-context-*`
and `main-probe-context-performance-20261004.md` in that directory.

## October 4, 2026: existing multivalue block rewrite failure

A valid indexed block with two i32 inputs is rejected by both frozen c972d0ba
and8675a6c2 under DAE2 and DAE2-O. Their rewritten-module errors are identical:
operand producers appear inside a block still requiring external parameters,
causing stack underflow. Exact failing source:

```wat
(module
 (import "host" "f" (func (param i32) (result i32)))
 (global (export "state") (mut i32) (i32.const 0))
 (func $callee (param i32 i32) (result i32) (local i32)
  i32.const 17 global.set 0 i32.const 19 call 0 local.get 0
  block (param i32 i32) (result i32) i32.div_s end
  local.set 2 local.get 2 call 0)
 (func (export "run") (param i32) (result i32)
  local.get 0 i32.const 99 call $callee))
```

`wasm-tools parse` and `validate --features all` accept the input;
verified133 `--all-features --dae2 --simplify-locals --vacuum` emits a valid
executable module. Both Starshine versions fail before optimizing cleanup.
Original/Binaryen execution agrees on values, ordered calls, state and traps.
The diagnostic is a lowering/entry-signature lead, not a completed diagnosis.
Keep this as a release blocker, add a failing reduced regression before repair,
and check typed operands, source effects, trap order and signature remapping.
Full error/status evidence is retained in the probe-context runtime directories;
the harness keeps nonzero status for blocked lanes instead of classifying them
as matches. The single-param trap control passes all four execution oracles.

## October 4, 2026: consume homogeneous nop-hoist runs once

Baseline mainc75030549/native8675a6c2… → natived9bdc7b0…. The nop-hoist
worker scanned an entire homogeneous run, copied one instruction, and rescanned
the suffix. It now copies that already-scanned run once, or one barrier when
there is no run. Mixed-run ordering, changed flags, array ownership and every
instruction are preserved. No cache, new allocation, type/admission shortcut or
validation change. Default tests cover independent output ownership, exact
barrier/constant order, idempotent changed flags and ordered dispatcher calls.

Dedicated wasm-gc release benchmark means, ten batches:

| Shape | Before µs | After µs |
| --- | ---: | ---: |
| Tiny four values | .04335 | .03463 |
| 128 nops | 13.46 | .61520 |
| 1024 nops | 723.20 | 4.40 |
| 128 constants | 13.40 | .57490 |
| 1024 constants | 814.95 | 4.40 |
| Mixed1024 | 5.62 | 5.81 |

The preselected resource bound allows at most16× time for8× width. Baseline
ratios53.73×/60.82× fail; candidate7.15×/7.65× pass. Characterization tests pass
before implementation, so this is a resource RED, not a claimed semantic RED.
The unchanged mixed path's small cost and overlapping ranges remain visible;
no extra rerun was used to seek a favorable result.

Complete per-function DAE2-O cleanup capture16,969,069,128→16,942,034,386
instructions (−.1593%), retaining all25,802 calls and exact validated output.
The two direct nop-worker edges sum216,404,516→214,504,018 instructions at
145,485 calls; worker exclusive work123,510,770→121,630,064 (−1.5227%). Its
allocation-request counts remain unchanged. Most of the larger root movement
appears in unchanged hash-map probe code (get/set exclusive−23.368m), so do
not attribute the entire root delta to this change. Generated closure names
also shift; renamed functions must not be counted as eliminated work. This is
a clear wide-run scaling repair, with no established enclosing clock/RSS win.
Both frozen executable files are14,625,848B.

CPU6 normal fresh-process CLI, warm filesystem, warmup1/n5, build and profiling
excluded; verified133, same input/features/flags as the previous checkpoint:

| Pass | Before ms ± MAD | After ms ± MAD | Binaryen133 ms ± MAD | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3628.202 ± 50.428 | 3635.326 ± 10.535 | 1186.903 ± 10.638 | 3.063× | +0.309% |
| dae2-optimizing | 6159.731 ± 29.979 | 6155.410 ± 33.600 | 2528.096 ± 92.268 | 2.435× | -0.674% |
| coalesce-locals | 4005.740 ± 37.262 | 4074.843 ± 159.333 | 1934.340 ± 31.551 | 2.107× | +0.872% |
| optimize-instructions | 2169.857 ± 12.550 | 2178.843 ± 11.444 | 958.248 ± 10.947 | 2.274× | +1.139% |

All rows flag foreign CPU. Timing shifts are within spread or disagree between
paired and cohort comparisons; retain adverse CL/OI/plain movements. Exact
large raw bytes/hashes remain unchanged, preserving prior quality gains and
canonical gaps without claiming a fresh normalization run. All four complete
commands remain above2s and every1× speed target remains open.

Info/fmt/check,13,461 default tests, six controls, native release and API sync
pass.57 fixed fixtures×four modes give928 validations and2720 available runtime
observations.56 fixtures complete four-way execution in each DAE2 mode,57 in
CL/OI; the existing multivalue failure remains two explicitly blocked Starshine
rows. No new failure or output drift. Long fuzz/full CI/coverage and independent
review remain outstanding. Source/index hashes match the frozen native build;
next subtree-read tests are separate unstaged work. Evidence and local report:
`.tmp/large-pass-hotspots-20261001/nop-run-*` and
`main-nop-run-performance-20261004.md` in that directory.

## October 4, 2026: reuse original subtree reads during adjacent-pair cleanup

Main `33db55ad6`, native `d9bdc7b0…` → `e9f225ec…`. The recursive
adjacent-pair cleanup previously recollected each original descendant subtree
at every ancestor. Its private value result now returns the existing owned
read array and the inherited-prefix length alongside the rewritten body.
Parents merge only new original reads. Flat bodies retain their original
collector fallback; both if arms finish before either read set is merged;
loops still seed next-iteration reads and merge that original seed. Legacy
handlers remain opaque to rewriting but visible to read collection.

No new retained tree index or heap result record is introduced. Internal read
insertion order can change the membership index's cached word, but production
consumers use membership/copy operations, and caller-owned ordered rows stay
unchanged. Original reads removed by a child rewrite still constrain siblings.
Default regressions check those dependencies, sibling isolation, loop self
reads, legacy/TryTable handlers, wide membership, input bytes and dispatcher
dead-argument activity. Existing frozen-reference controls remain exact.

Dedicated wasm-gc release controls (mean, ten batches):

| Shape | Before µs | After µs |
| --- | ---: | ---: |
| Tiny active | .06519 | .06029 |
| Depth16 active | 1.16 | .644 |
| Depth64 active | 12.47 | 3.15 |
| Width32/depth16 active | 51.04 | 35.80 |
| Width32/depth16 unchanged | 29.25 | 11.71 |
| Width256 flat unchanged | 1.56 | 1.62 |

The preselected ≤8× time bound for 4× depth fails before (10.75×) and passes
after (4.89×). This is resource RED; the three original characterization tests
passed before implementation. The initial depth128 benchmark hit MoonRun stack
overflow before the timing report; setup/reference/worker attribution remains
unresolved, so the retained bounded control uses depth64. A fixture-scope compile
error was corrected separately and is not counted as RED. Flat unchanged cost
increases about 60ns; distinct-local unions and nested loop prewalks can still
scale with depth. This is not a universal linearity claim.

Complete per-function DAE2-O cleanup work falls **16,942,034,386 →
16,293,599,405 instructions (−3.827%)**. All 25,802 raw SL pipeline calls remain;
raw SL work is 10,553,484,813 → 9,906,711,422. The adjacent-pair worker's 4,574
root calls fall **1,166,219,705 → 519,052,928 (−55.493%)**. Nested values are
not additive. Only 1,268,204 instructions of the root delta lie outside that
worker, giving source-backed attribution unlike the preceding nop-run trial.

Read-set copies remain 52,801. Collected native malloc requests increase
53,858,927 → 53,860,380 (+1,453); this is not a heap-saving claim. Reordered
membership and extended array lifetimes retain a small allocation tradeoff.
Executable size increases 288B to 14,626,136B. RSS ranges overlap; no peak-memory
win is established. Output hashes and raw byte sizes match the predecessor on
all four passes, retaining the previously measured canonical gains and gaps.

CPU6, same 6,211,596B input, verified Binaryen133, native GCC O2/mimalloc,
warm filesystem with fresh CLI processes, warmup1/n5 alternating rotations;
builds, separate tracing and Callgrind are excluded from these clocks:

| Pass | Before ms ± MAD | After ms ± MAD | Binaryen 133 ms ± MAD | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3778.378 ± 12.536 | 3749.040 ± 22.214 | 1252.634 ± 5.767 | 2.993× | -0.647% |
| dae2-optimizing | 6482.148 ± 52.287 | 6284.585 ± 116.036 | 2471.363 ± 38.660 | 2.543× | -0.338% |
| coalesce-locals | 4133.339 ± 50.164 | 4115.988 ± 38.103 | 2038.311 ± 12.525 | 2.019× | +0.439% |
| optimize-instructions | 2209.890 ± 22.889 | 2239.130 ± 20.814 | 993.775 ± 6.846 | 2.253× | +2.384% |

Every timing row flags foreign CPU. DAE2-O cohort medians improve 197.6ms but
the paired median is only −.338% and ranges overlap substantially; do not claim
a reliable enclosing clock gain. Retain the adverse OI/CL paired movements.
OI's narrow inner timer excludes most cleanup, so it cannot establish whole-pass
parity. All four full commands remain above 2s and every 1× target stays open.

Info/fmt/check, 13,466 default tests, six controls, native release and README/API
sync pass; no public API diff. The 59-fixture/four-mode corpus records 960
validations and 2,816 available observations: 58 full four-way fixtures per DAE2
mode and 59 for CL/OI. The existing valid multivalue failure remains explicitly
blocked in both DAE2 modes; no new failure or byte drift. Long fuzz/full CI,
coverage and independent review remain release gates. Ownership/source review
is recorded locally; no independent reviewer ran in this unit.

Evidence: `.tmp/large-pass-hotspots-20261001/subtree-reads-*`, distinct build
and profile manifests, `subtree-reads-environment-full.json`, and local report
`main-subtree-reads-performance-20261004.md`. The earlier nop-run full environment
note carried stale inherited top-level labels: its authoritative build/per-pass
hashes were correct. `nop-run-provenance-correction.json` records the corrected
cohort without deleting the original note. This run has a fresh self-contained
manifest. New type-section tests are separate unstaged work: two prefix copies
per group cause a measured 70.60× time increase for 8× groups; an owned private
validation buffer is the next experiment, with full incremental scope retained.

## October 4, 2026: own the incremental type-validation prefix

Main `3fd003483`, frozen native `e9f225ec…` → `6b65daad…`.
`validate_typesec` previously copied growing global-type and recursive-scope
prefixes twice per group. It now copies the caller's rows once, appends the
current raw group, runs every existing group check, then normalizes only its
new global slots. Original scopes remain intact; later groups stay invisible.
Only the final environment escapes. Failure preserves the caller and the
original first error. Other immutable Env APIs retain their contracts.

The [validator contract](../../../validate/type-section-and-subtyping.md) and
[prefix regressions](../../../../../src/validate/type_section_storage_wbtest.mbt)
cover ownership, failure atomicity, forward/in-group references, recursive
supertypes, descriptor pairs and continuation references. Four characterization
tests passed before implementation. Dedicated wasm-gc release means:

| Groups × width | Before µs | After µs |
| --- | ---: | ---: |
| 1 × 1 | .15380 | .09973 |
| 128 × 1 | 75.21 | 9.05 |
| 1024 × 1 | 5310 | 80.67 |
| 256 × 4 | 833.32 | 53.37 |

The preselected ≤16× time bound for8× groups fails before (70.60×) and passes
after (8.91×): resource RED/GREEN, not a semantic bug claim. Recursive matching
keeps its own costs; this does not prove all type validation linear.

Fresh complete DAE2 work is **30,630,968,553 → 30,099,120,246
instructions (-1.736%)**. Its two type-section validations fall
537,879,714 → 4,848,734
(-99.099%); all2,137 group validations/normalizations
remain. Direct native malloc requests change 76,060,632 →
76,024,366. Work outside the type-section edges increases
1,182,673 instructions, so helper savings are not
presented as identical to the enclosing delta. No allocation-byte claim.

The remaining complete DAE2 source-backed costs are distinct root-call edges
in `dae2_run_module_pass` ([implementation](../../../../../src/passes/dead_argument_elimination2.mbt)):

| Root-call owner | Instructions, billions |
| --- | ---: |
| `dae2_analyze_function` dependencies | 9.418 |
| Initial `dae2_lift_for_analysis` | 6.366 |
| Rewrite `dae2_lift_for_analysis` | 2.372 |
| `hot_lower_func_unverified` | 4.647 |
| Final `validate_module` | 2.495 |
| `dae2_rewrite_node` | .843 |
| Graph solve | .107 |

These do not exhaust the complete owner; nested CFG/read-source costs belong
inside dependencies. Temporary profiling is excluded from the release clocks.

Complete OI command work changes **19,599,369,595 →
19,577,086,974 (-0.114%)**. Its five type validations are
25,060,552 → 2,556,858;
requests 70,166,419 → 70,152,948.
These are inclusive edges within complete owners; nested totals are not added.

Normal fresh-process CLI, warm filesystem, CPU6, warmup1/n5 rotating
before/after/verified Binaryen133, same6,211,596B input and native GCC O2/mimalloc;
builds, profiling and tracing excluded (all times milliseconds):

| Pass | Before ms ± MAD | After ms ± MAD | Binaryen 133 ms ± MAD | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3610.592 ± 56.466 | 3593.812 ± 30.367 | 1189.526 ± 9.250 | 3.021× | -0.675% |
| dae2-optimizing | 6039.491 ± 30.149 | 5932.306 ± 106.577 | 2433.266 ± 25.990 | 2.438× | -1.228% |
| coalesce-locals | 3933.106 ± 6.831 | 3976.437 ± 4.162 | 1916.517 ± 38.645 | 2.075× | +0.966% |
| optimize-instructions | 2164.822 ± 9.844 | 2135.276 ± 12.732 | 953.532 ± 1.581 | 2.239× | -1.365% |

Foreign-load flags occur on56/60 timed normal rows. Preserve paired
changes, spread and the saved ranges/RSS; these short cohorts are not a universal
clock or peak-memory claim. CL's +.966% paired command movement remains an
adverse observation requiring follow-up. DAE2 peak RSS median rises252,936 →
262,864KiB (+9,928KiB); ranges252,588–254,720 →252,280–264,644 overlap but
most candidate samples are higher. The cause is unproved; fewer allocation
requests do not establish lower live memory. OO/CL/OI RSS ranges overlap.
The binary shrinks192B to14,625,944B. Current matched n3 traced diagnostics,
separate from the normal commands:

| Pass | Starshine inner ms ± MAD | Starshine pipeline ms ± MAD | Binaryen measured work ms ± MAD |
| --- | ---: | ---: | ---: |
| dae2 | 2850.907 ± 2.797 | 2871.283 ± 1.485 | 456.208 ± 0.840 |
| dae2-optimizing | 5154.722 ± 2.889 | 5172.959 ± 2.861 | 1745.761 ± 22.469 |
| coalesce-locals | 2944.246 ± 3.821 | 2962.737 ± 3.911 | 1213.050 ± 8.890 |
| optimize-instructions | 84.359 ± 4.129 | 1605.259 ± 47.679 | 249.278 ± 3.167 |

Binaryen debug1 serializes function passes and validates outside its timers;
OO totals are summed per sample before the median. Starshine OI's narrow inner
timer omits most raw cleanup; use its pipeline and normal command for that work.
All four1× targets remain open.

Info/fmt/check, **13,471 default tests**, four controls, native release and
README/API sync pass; no public API change. A new dispatcher fixture exercises
recursive GC types and actual dead-argument removal in both DAE2 modes. The
60-fixture/four-mode corpus records **976 validations /2,864 available execution
observations**, including ordered effects, exported state/memory and trap status.
The existing typed two-parameter result-block failure still blocks one fixture
in each DAE2 mode; it is not a passing semantic comparison. Original/before/after/
Binaryen complete four-way rows are59 for each DAE2 mode,60 for CL/OI.

All four large raw hashes/sizes match the predecessor exactly, preserving prior
quality gains without claiming a fresh canonical signoff. OO still has the
99,251B bounded canonical deficit despite its9,949B raw advantage. Long aggregate
fuzz, full CI/coverage and independent review remain pending; no Why3/solver is
configured for the optional-host proof gate. No release or parity completion.

Local evidence `.tmp/large-pass-hotspots-20261001/typesec-prefix-*` records exact
input/tool/source/binary hashes, commands, dirty state, profiles, all samples,
RSS, execution cases and first-error/reference controls. Build and profile
manifests are separate. The following live-control trial has independent files
and binaries and is not included in this unit's timings or13,471-test claim.

## October 4, 2026: keep unchanged live-control child storage

Frozen native `6b65daad…` (now main `225477e16`) → `e04ee14f…`.
`dae2_rewrite_node` now returns a live Block/Loop/If after recursively rewriting
all descendants when their IDs are unchanged. The old branch could only copy
and compare that same span. In-place child mutations remain visible; dead-control
result demotion, call/signature changes and repeated-producer handling remain.
No new arrays, cache, public API or representation change.

[Focused regressions](../../../../../src/passes/dae2_live_controls_wbtest.mbt)
check complete visitation, unchanged bodies/revisions and retained child cleanup;
two baseline characterizations passed before implementation. The [dispatcher
fixture](../../../../../src/cmd/dae2_live_controls_wbtest.mbt) checks real pruning
inside effectful controls in both modes. [Dedicated controls](../../../../../src/passes/dae2_live_controls_perf_wbtest.mbt)
reset the memo each iteration: depth1/8/32 wasm-gc means335.59ns/2.80µs/12.00µs
become152.97ns/1.26µs/5.35µs. Resource RED was redundant unchanged-control child
storage; these are storage-only tests, not a newly introduced semantic failure.

Complete DAE2 instructions **30,099,120,246 → 30,049,564,045
(-0.165%)**. The36,215 rewrite-root calls cost
**842,959,024 → 793,561,072
(-5.860%)**. All973,347 recursive/root rewrite calls
remain. Remove60,971 child snapshots and the same number of redundant child-span
comparisons; changed-child snapshots stay intact. Direct native malloc requests
**76,024,366 → 75,900,967** (123,399 fewer). Work outside the root rewrite
changes-158,249 instructions. Recursive inclusive
edges are not summed as phase totals; allocator requests are not bytes.

CPU6, same6,211,596B fixture/verified133, native GCC O2/mimalloc, warm filesystem,
fresh untraced CLI, warmup1/n5 rotating order; build/profile work excluded:

| Pass | Before ms ± MAD | After ms ± MAD | Binaryen133 ms ± MAD | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3715.910 ± 8.902 | 3698.567 ± 13.827 | 1228.600 ± 10.218 | 3.010× | -0.267% |
| dae2-optimizing | 6154.388 ± 86.872 | 6095.044 ± 80.815 | 2527.605 ± 55.246 | 2.411× | -0.964% |

All30 normal rows flag foreign CPU, and ranges overlap; retain the modest paired
changes without promoting the55% synthetic gain to complete-pass speed. DAE2
RSS median263,176→254,392KiB and OO291,140→290,932KiB have overlapping ranges;
no reliable peak-memory win is established. Binary size stays14,625,944B. Both
large raw outputs/hashes are exact; canonical gains and remaining gaps persist.
CL/OI code paths are unaffected and were not redundantly timed; their last matched
n5 rows and the separate n3 inner scopes are in the preceding prefix checkpoint.
All four1× targets remain open.

Info/fmt/check,13,474 default tests,three controls,native release and README/API
sync pass.64 execution fixtures per DAE2 mode record518 validations/1,520
available observations, with63 complete original/before/after/Binaryen rows each.
New cases cover nested effectful/scalar/GC arms, traps and an in-place call losing
all arguments. The known two-parameter result-block validation failure remains
blocked in both modes; it is not a semantic pass. Full CI/coverage,long fuzz and
independent review are pending. Source ownership review is local self-review.

Local `live-controls-*` files hold exact build/source/binary hashes, profile,
all clocks/RSS and runtime rows. The build manifest records HEAD3fd003483 while
the preceding type-prefix unit was pending; its baseline is explicitly frozen
6b65daad, not bare3fd003483. After225477e16, only this live-control implementation
and its tests differ from that baseline. Next: finalize entry-source rows during
the existing DAG propagation after proving saved intervals are no longer read.

## October 4, 2026: finalize entry sources during propagation

Main `9b7847a24`, native `e04ee14f…` → `c98ffbbf…`. In
`dae2_entry_read_sources`, finalize each source row immediately after propagating
its complete root interval to its children. Reversed unique DAG postorder already
places every parent before its children, and all root seeds are installed first;
no later node can read a finalized parent's interval. This removes the separate
whole-arena finalization scan without new storage, admission shortcuts or skipped
validation. Detached rows retain −2; shared writes and repeated roots retain the
original full-flow fallback. The single-write worker is unchanged.

[Three baseline characterization tests](../../../../../src/passes/dae2_entry_finalization_wbtest.mbt)
compare complete rows to the frozen algorithm, including shared/cross-write reads,
write operands, detached nodes, mutation invalidation and unsupported nested-write
fallback. [Dispatcher coverage](../../../../../src/cmd/dae2_entry_finalization_wbtest.mbt)
checks actual signature pruning inside effectful loops in both modes. These passed
before the storage-only optimization; resource RED was 4,915,480 complete-header
reads exceeding a preselected 4,000,000 budget. Candidate reads are 3,314,976,
with the same 8,187 entry-source queries and all mandatory checks retained.

Complete DAE2 instructions **30,049,564,045 → 29,987,153,791 (−0.208%)**;
entry-source owner **789,497,548 → 725,869,513 (−8.059%)**. Eliminate 1,600,504
header reads and liveness queries. Direct native malloc requests stay 75,900,967;
work outside this owner changes +1,217,781 instructions. Do not sum inclusive
child edges or interpret instruction counts as elapsed time.

[Four dedicated controls](../../../../../src/passes/dae2_entry_finalization_perf_wbtest.mbt)
retain complete result assertions and fixture setup outside timing. Two-write
depths 0/32/128: 718.88ns/2.45µs/6.56µs → 632.88ns/2.11µs/6.07µs.
Unchanged single-write depth32: 1.89µs ±11.55ns → 1.94µs ±36.45ns; ranges
overlap. Preserve this adverse control rather than claim universal speedup.

CPU6, same 6,211,596B input and verified 133, native GCC O2/mimalloc,
warm filesystem/fresh untraced CLI, one warmup and five rotating samples:

| Pass | Before ms ± MAD | After ms ± MAD | Binaryen 133 ms ± MAD | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3647.932 ± 31.866 | 3647.877 ± 24.033 | 1212.245 ± 13.555 | 3.009× | -0.283% |
| dae2-optimizing | 5993.056 ± 69.772 | 5939.125 ± 44.676 | 2402.493 ± 31.818 | 2.472× | -1.420% |

28/30 normal rows flag foreign CPU. DAE2 medians are essentially unchanged;
OO shows a modest paired improvement with overlapping ranges. Peak RSS medians
253,212→255,512KiB (DAE2), 291,068→291,064KiB (OO), also overlapping. No peak-memory
win is established. The single diagnostic OO sample moved adversely
5738.745→6288.732ms inner (both contended); it is not a repeated inner-speed
claim and does not supersede the preceding matched n3 cohort. All raw bytes and
hashes are exact. The +99,251B canonical OO gap and all four 1× targets remain.
CL/OI were not retimed for this private DAE2 change; their preceding cohort stays
under its original native version.

Info/fmt/check, **13,478 default tests**, four controls, native release and README/API
sync pass; no API diff. The 65-fixture corpus per mode records **526 validations /
1,544 available observations**, with 64 complete original/before/after/133 rows
per mode. The existing typed two-input/result-block failure remains blocked in
both modes, not passed. Self-review covers immutable DAG order, private partial
rows on fallback and caller ownership. Independent review, full CI/coverage and
long aggregate fuzz remain pending. Exact commands, hashes, clock/RSS samples,
profiles and runtime evidence are local `entry-finalization-*` artifacts.

Next larger owners are analysis CFG, local flow, lift/lower and optimizing
cleanup. A fresh complete CoalesceLocals profile is queued; do not extrapolate
this private DAE2 change to CL/OI or duplicate completed storage optimizations.

## October 4, 2026: scalar lift source reservations

Main `8ea5ade8e`, native `c98ffbbf…` → `c06f4a76…`. The instruction lift worker
keeps the temporary source-access index and write/get flag in scalar locals,
instead of constructing a private `(Bool, Int)` reservation tuple. The same
public get/write row is reserved before validation and filled on the same
successful path. Unmaterializable unreachable accesses retain −1; nested control
invocations, original local count, capture exclusion and revision invalidation
are unchanged. No admission, typecheck or capture operation is removed.

[Source-order characterization](../../../../../src/ir/hot_lift_step_wbtest.mbt)
adds mixed scalar/reference local indices, captures, nested regions and unreachable
writes. [Four-pass dispatcher coverage](../../../../../src/cmd/lift_source_reservation_wbtest.mbt)
asserts real signature pruning, local removal and constant folding. Both passed
before implementation; the resource RED was 3,872,247 recursive instruction-worker
malloc requests exceeding a preselected 3,500,000 budget. Candidate count is
2,581,844. Generated C confirms scalar locals and no temporary reservation tuple.

| Complete native scope | Instructions before → after | Change | Malloc requests removed |
| --- | ---: | ---: | ---: |
| DAE2 pass | 29,987,153,791 → 29,850,398,485 | -0.456% | 1,510,033 |
| CoalesceLocals pass | 38,650,912,125 → 38,582,564,678 | -0.177% | 729,950 |
| OptimizeInstructions command | 19,576,764,460 → 19,576,413,076 | -0.002% | 19,232 |

Each allocation reduction is exactly the removed instruction-worker requests;
allocation count outside that owner is unchanged. Data-typecheck calls remain
2,828,135 / 1,350,923 / 48,023 respectively, capture calls
1,510,027 / 729,944 / 19,232. Allocator requests are not bytes or peak memory.
Recursive inclusive costs are not added to these complete scopes.

Same 6,211,596B input, verified Binaryen133, native GCC O2/mimalloc, CPU6,
one warmup and five rotating fresh-process/warm-filesystem untraced CLI samples:

| Pass | Before ms ± MAD | After ms ± MAD | Binaryen133 ms ± MAD | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| DAE2 | 3634.526 ± 13.386 | 3638.085 ± 22.156 | 1228.261 ± 6.163 | 2.962× | -0.269% |
| DAE2-O | 6168.017 ± 77.923 | 6156.193 ± 87.675 | 2508.656 ± 15.024 | 2.454× | +0.712% |
| CoalesceLocals | 4036.335 ± 56.668 | 4000.320 ± 13.321 | 2052.441 ± 38.684 | 1.949× | -0.984% |
| OptimizeInstructions | 2206.412 ± 12.980 | 2176.892 ± 37.299 | 995.620 ± 37.707 | 2.186× | -0.754% |

All60 normal rows flag foreign CPU, before/after ranges overlap, and DAE2-O's
paired change is adverse despite its lower median. No universal clock gain is
established. Single diagnostic inner samples (not a repeated comparison) are
DAE2 2857.565→2888.078ms, OO5222.792→5919.564ms, CL3058.226→3066.872ms and
OI86.985→86.578ms; OI's narrow timer omits most pipeline cleanup. Peak RSS medians
are 262940→255480 / 291112→291144 / 243360→243380 / 156136→156364KiB,
with overlapping ranges. No peak-memory win is claimed.

The six existing complete-lift wasm-gc controls retain adverse results: scalar
1/64/1024 operations 1.71→1.79µs,35.11→36.29µs,557.05→564.59µs; structured
1/64/1024 operations 2.64→2.68µs,86.88→88.92µs,1.61→1.65ms. This small private
change is accepted for proven native instruction/allocation savings, not a
universal backend speedup. All control distributions remain in local evidence.

Info/fmt/check, **13,480 default tests**, six controls, native release and README/API
sync pass; no API diff. The 67-fixture corpus across four passes records
**1,088 validations / 3,200 available runtime observations**. Original/before/after/
133 values, ordered effects, memory/globals and trap status match on supported
rows. The existing typed-block failure remains blocked in both DAE2 modes;
66 fixtures fully compare per DAE2 mode and67 each for CL/OI. All four large raw
hashes are exact; this preserves, rather than closes, the canonical size gaps.

Local `lift-reservation-*` artifacts contain exact environment/source/oracle hashes,
commands, samples/ranges, profile scopes, resource RED and ownership self-review.
Independent review, full CI/coverage and deferred aggregate fuzz remain pending.
All four1× goals remain open. Next: CoalesceLocals branch-row storage (baseline
characterizations pass), and the larger DAE2 dependency/lift/lower/cleanup owners.

## October 4, 2026: keep local-write validation success unboxed

Main `1512cee96`, native `923a4908…` → `42af3b7f…`. Local set/tee now call
`TcState.pop_expect_error` directly. Its existing Result adapter returned the
exact input state on success; only the owned operand stack changes. Local
lookup still precedes pop, initialization follows successful pop, and the
initialization owner/copy-on-write mask and tee declared result type remain.
No checks, public API, admission, optimization work or final Result changes.

Three [state/ownership/error characterizations](../../../../../src/validate/local_write_pop_wbtest.mbt) and one [active four-pass dispatcher](../../../../../src/cmd/local_write_pop_wbtest.mbt)
pass before implementation. Resource RED: 1,336,814 local-write calls through the
boxed pop adapter exceed the zero-call budget. Candidate zero, with exactly 735,180
set and 601,634 tee checks retained. Source and emitted native code agree.

| Complete collected native scope | Before instructions | After instructions | Change |
| --- | ---: | ---: | ---: |
| DAE2 pass | 29,852,266,706 | 29,763,125,430 | -0.2986% |
| CoalesceLocals pass | 38,403,763,531 | 38,351,794,803 | -0.1353% |
| OptimizeInstructions whole process | 19,577,090,343 | 19,475,877,961 | -0.5170% |

The scoped profiles continue counting calls after collection stops; their global
allocator deltas 1,336,814/829,558 are **not** pass-only allocation measurements.
The complete OI process removes 1,073,389 allocator requests. Requests do not
establish bytes or peak memory. Inclusive edges are not added to complete costs.

Four [wasm-gc controls](../../../../../src/validate/local_write_pop_perf_wbtest.mbt), mean±SD: numeric set 30.90±.24→28.13±.56ns;
numeric tee 32.50±.26→29.25±.12ns; GC-subtype tee 37.83±.23→35.25±.24ns;
invalid-concrete set 125.70±4.68→116.16±2.21ns. Ten batches of 100,000 each.

Same 6,211,596 B input SHA 98189860…, verified Binaryen 133 SHA 8f25e9fd…,
Ryzen 7 8845HS CPU 6, Moon 0.1.20260920/moonc 0.10.14, GCC 14.2 O2/mimalloc.
Build excluded; fresh normal processes with warm filesystem, one warmup and
five rotating samples. Median±MAD milliseconds [min,max]:

| Pass | Before | After | Binaryen133 | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3510.071±16.016 [3464.324,3587.117] | 3544.465±17.137 [3513.438,3561.602] | 1170.002±11.251 [1158.752,1193.054] | 3.029× | +1.418% |
| dae2-optimizing | 5829.475±53.204 [5774.236,5977.301] | 5811.789±12.553 [5799.236,5880.941] | 2407.866±26.769 [2365.591,2441.146] | 2.414× | -0.217% |
| coalesce-locals | 3898.672±16.287 [3882.385,4154.210] | 3928.280±50.372 [3875.513,3983.713] | 1858.622±11.633 [1808.428,1898.653] | 2.114× | -0.189% |
| optimize-instructions | 2169.962±8.618 [2161.344,2291.574] | 2164.870±19.234 [2104.600,2217.198] | 981.185±11.615 [969.570,1007.463] | 2.206× | -1.523% |

Retain overlapping ranges, adverse rows and observed foreign CPU; this does
not establish a universal wall-clock or RSS win. No slower-oracle cohort is
credited as a Starshine implementation gain. Separate n1 traced diagnostics:

- dae2: inner 2725.977→2835.280ms; pipeline 2744.397→2857.117ms. RSS before/after medians 265,488/265,548KiB; foreign rows before/after/oracle 3/2/0. Full RSS ranges in local JSON.
- dae2-optimizing: inner 5015.138→5257.423ms; pipeline 5033.095→5283.176ms. RSS before/after medians 294,328/294,288KiB; foreign rows before/after/oracle 3/2/2. Full RSS ranges in local JSON.
- coalesce-locals: inner 2944.801→2928.246ms; pipeline 2963.295→2951.839ms. RSS before/after medians 249,228/248,764KiB; foreign rows before/after/oracle 5/4/4. Full RSS ranges in local JSON.
- optimize-instructions: inner 82.445→83.208ms; pipeline 1598.655→1588.297ms. RSS before/after medians 156,348/155,556KiB; foreign rows before/after/oracle 5/5/5. Full RSS ranges in local JSON.

OI’s narrow inner timer omits most cleanup. Do not use it as a complete pass
or command speed comparison. All four 1× targets remain open.

Info/fmt/check, **13,487 default tests**, four controls, native release and
README/API sync pass; no .mbti diff. **1,104 validations and 3,248 available runtime
observations** cover 68 fixtures per pass and exercise
original/before/after/133 outputs, ordered calls, globals/memory, values and
permitted trap status. The existing DAE2/OO typed-block rewrite failure remains
blocked, not passed. All available runtime observations and before/after bytes
match; exact large raw hashes retain earlier canonical sizes, not fresh
canonical signoff. OO+99,251B, CL+78,800B and OI+33,497B canonical gaps remain.

Ownership self-review is complete; independent review, full CI/coverage and
deferred aggregate fuzz remain pending. Local `local-write-pop-*` artifacts
contain exact commands, hashes, source manifests, profiles, clocks/RSS and
runtime rows. Next: private unsigned decoder return packaging; then larger
DAE2 dependency/lift/lower and optimizing-cleanup owners. No release signoff.

Disk exhaustion interrupted the first CL runtime attempt. That partial run is
retained separately; the complete rerun above supplies the evidence. Duplicate
sealed outputs were hard-linked by verified SHA, preserving every path/byte.

## October 4, 2026: unbox private unsigned decoding results

Native `42af3b7f…` → `f129b57b…`, on main before `b5327ad47` committed the
preceding local-write change. [The decoder](../../../../../src/binary/decode.mbt)
returns a private value/offset/error record and boxes only the public typed
Decode result. The normalized parser body is identical: width guard, EOF before
byte-count guard, range before terminal-bit checks, padding and offsets remain.
Signed decoding and public API are unchanged; the private Result adapter remains
for bit-width tests. This is a parsing/full-command improvement, not pass-local.

Three [primitive/index regressions](../../../../../src/binary/unsigned_decode_value_wbtest.mbt)
and an [active four-pass dispatcher](../../../../../src/cmd/unsigned_decode_dispatch_wbtest.mbt)
passed before implementation. Resource RED was 4,402,894 worker allocations
against zero; after implementation zero. All 2,201,447 unsigned decodes remain,
including 197,492 U64 calls inlined by GCC. Complete OI instructions decrease
**19,475,877,961 → 19,112,351,168 (−1.8665%)**, allocator requests
**69,060,327 → 64,657,433 (−4,402,894)**. No allocation-byte or RSS saving follows
from request counts. Emitted C and U64 assembly confirm the representation change.

Six [wasm-gc controls](../../../../../src/binary/unsigned_decode_value_perf_wbtest.mbt),
mean±SD ns before→after: single-byte15.10±.45→13.97±.71;
max-U32 18.40±.28→15.82±.17; padded-zero18.43±.28→15.85±.14;
max-U64 23.55±.28→20.13±.23; truncated13.69±.22→12.77±.13;
invalid-terminal21.15±.33→19.29±.10.

Same 6,211,596 B input SHA98189860…, verified Binaryen133 SHA8f25e9fd…,
Ryzen7 8845HS CPU6, Moon0.1.20260920/moonc0.10.14, GCC14.2 O2/mimalloc.
Build excluded. Fresh processes/warm filesystem, one warmup, five alternating
samples; normal CLI median±MAD ms [min,max]:

| Pass | Before | After | Binaryen133 | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3638.148±74.777 [3562.938,3721.856] | 3546.630±14.712 [3512.349,3569.240] | 1213.566±13.399 [1200.168,1262.418] | 2.922× | -2.737% |
| dae2-optimizing | 6084.623±122.413 [5962.210,6265.648] | 6010.820±36.599 [5926.423,6056.458] | 2457.104±26.492 [2403.981,2692.387] | 2.446× | -0.974% |
| coalesce-locals | 3946.961±19.944 [3892.646,3966.904] | 3928.516±55.718 [3872.798,4070.368] | 2119.350±86.840 [1986.169,2266.227] | 1.854× | -0.314% |
| optimize-instructions | 2111.045±6.406 [2102.960,2143.505] | 2038.846±10.034 [2028.812,2089.042] | 957.072±5.410 [951.662,987.862] | 2.130× | -3.526% |

Overlapping ranges and recorded foreign CPU limit wall-clock attribution. RSS
medians before→after (KiB): DAE2 262904→264324; OO291008→291172;
CL243804→243336; OI155912→157036. No general peak-memory win.

Separate matched n3 traced pass medians±MAD ms:

| Scope | Starshine | Binaryen133 |
| --- | ---: | ---: |
| DAE2 inner | 2821.038±23.674 | 455.027±5.244 |
| DAE2-O inner | 5192.361±28.299 | DAE2 460.852±1.530 + SL1107.390±9.300 + Vacuum145.489±.034 |
| CoalesceLocals inner | 3123.636±30.674 | 1290.960±1.970 |
| OptimizeInstructions pipeline / narrow inner | 1594.733±25.319 / 90.006±1.108 | 256.022±.699 |

The OI narrow timer excludes most cleanup and cannot close its speed target.
Binaryen debug mode adds verification outside pass timers: its traced CLI times
are not comparable to normal CLI. OO oracle commands include `--dae2
--simplify-locals --vacuum --all-features`; component medians are not a paired
sum distribution. All four 1× targets remain open.

Info/fmt/check, **13,491 default tests**, six controls, native release and README/API
sync pass; no API diff. **1,124 validations / 3,296 available runtime observations**
cover69 fixtures per pass. DAE2/OO each68 fully compare plus the known typed-block
rewrite failure; CL/OI each69 fully compare. Values, ordered imports, globals,
memory and permitted trap status match for supported original/before/after/133
rows. Binaryen compact-import bytes0x7e/0x7f unsupported by Node26 use the existing
no-pass Binaryen-text/wasm-tools adapter only for runtime; original/Starshine raw
bytes execute directly. All large before/after raw hashes match. Canonical
OO+99,251B/CL+78,800B/OI+33,497B gaps remain; exact raw hashes preserve previous
quality, not fresh canonical signoff.

The ENOSPC-interrupted CL cohort and initial compact-import runtime attempt are
retained separately and excluded. Local `unsigned-decode-*` artifacts contain
source/build/environment hashes, exact commands, timer distributions, profiles,
resource RED and ownership self-review. Independent review, full CI/coverage and
deferred aggregate fuzz remain pending. Next: structured-frame storage and
explicit DAE2/CL lift-provenance demand; no release or speed-parity signoff.

## October 4, 2026: reuse structured decode frames

Native `f129b57b…` → `38ef809d…`. The private
[`structured_frame_push_instruction`](../../../../../src/binary/decode.mbt)
already appends to its owned active-body array. It now returns the original
frame instead of reconstructing identical type/depth/body/catch/delegate fields
for every instruction. Else, catch, catch-all, delegate, header and end transitions
remain in the decoder loop. No parser check, error, public API or traversal changes.

Three [frame/encoding/error regressions](../../../../../src/binary/structured_frame_storage_wbtest.mbt)
and one [active nested-control dispatcher](../../../../../src/cmd/structured_frame_dispatch_wbtest.mbt)
pass before implementation. Tests preserve sibling/catch bodies and frame
metadata, nested/legacy-EH/try-table structure and exact encoded offsets, and
first errors for intentionally malformed delimiters. Resource RED:2,120,809
frame-wrapper requests against zero. After: zero requests with the same2,120,809
helper calls. Complete OI native work **19,112,351,168 →18,585,524,926 (−2.7565%)**.
This is parsing/full-command work, not a pass-local saving. Request counts are
not allocation bytes or peak RSS. No instrumentation is in release timing.

Four [wasm-gc controls](../../../../../src/binary/structured_frame_storage_perf_wbtest.mbt),
mean±SD before→after: single54.84±.36→50.20±.35ns;
wide1024 15.65±.210→12.32±.274µs; nested128 4.72±.068→4.45±.094µs;
legacy32 1.32±.007→1.16±.009µs.

Same 6,211,596B SHA98189860… input and verified Binaryen133 SHA8f25e9fd…;
Ryzen7 8845HS CPU6, Moon0.1.20260920/moonc0.10.14, GCC14.2 O2/mimalloc.
Build excluded. One warmup/five alternating fresh-process, warm-filesystem
normal CLI samples. Median±MAD ms [min,max]:

| Pass | Before | After | Binaryen133 | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3453.374±16.190 [3437.183,3513.623] | 3429.006±73.519 [3266.523,3507.568] | 1166.586±3.159 [1163.427,1240.439] | 2.939× | -0.706% |
| dae2-optimizing | 5970.744±97.401 [5870.779,6253.796] | 5969.131±26.056 [5844.107,5999.891] | 2457.535±29.021 [2428.514,2663.261] | 2.429× | -0.454% |
| coalesce-locals | 3992.643±31.767 [3931.329,4079.542] | 3973.029±49.654 [3876.285,4107.859] | 2035.729±20.111 [2015.618,2081.376] | 1.952× | -0.202% |
| optimize-instructions | 2105.159±9.443 [2095.716,2193.550] | 2011.235±22.401 [1988.835,2043.907] | 1063.979±16.312 [1019.428,1080.291] | 1.890× | -4.824% |

All60 normal rows record foreign CPU. Before/after ranges overlap except OI;
slower oracle cohorts are not credited as Starshine improvements. RSS medians
before→after KiB: DAE2 263520→265208; OO291060→291188; CL243316→243044;
OI156516→156504. No general RSS win. Separate n1 diagnostic inner before→after
ms: DAE2 2799.732→2818.017; OO5336.099→5296.038; CL2980.499→2995.431;
OI100.619→84.837. OI pipeline1800.118→1501.805ms contains most cleanup omitted
by its narrow timer. These single diagnostics do not establish repeated
pass-local wins or supersede the preceding n3 scope comparison.

Info/fmt/check, **13,495 default tests**, four controls, native release and README/API
sync pass; no API change. **1,140 validations /3,344 available runtime observations**
cover70 fixtures per pass: DAE2/OO each69 fully compared plus the existing blocked
typed-block rewrite, CL/OI each70 fully compared. Original/before/after/133 values,
ordered effects, globals/memory and permitted traps agree on supported rows.
Compact-import oracle runtime uses the documented no-pass text adapter where
Node26 rejects valid raw encodings. All four large raw hashes remain exact;
canonical OO+99,251B/CL+78,800B/OI+33,497B gaps stay open.

Local `structured-frame-*` evidence retains commands, manifests, profiles, clocks,
resource RED and ownership review. Interrupted ENOSPC controls are preserved
and excluded; the successful rerun supplies signoff. Independent review, full
CI/coverage and deferred aggregate fuzz remain pending. All four1× goals and
correctness gates remain open. Next: explicit DAE2/CL lift source-map demand;
then larger dependency/lower/cleanup owners, including OI lazy output storage.

## October 4, 2026: record lift provenance only for consumers

Native `38ef809d…` → `b1ef48ca…`. The
[lift API](../../../../../src/ir/hot_lift.mbt) adds optional
`record_local_accesses: Bool = true`. DAE2 production analysis/relift and CL loop
CFG opt out only when they have no original-source-map consumer. DAE2 write
provenance forces recording; the private helper default also remains true for
reference/tool callers. SSA-nomerge and every existing public caller preserve
the default. The getter still rejects absent/stale metadata. Reviewed `.mbti`
diff: exactly one source-compatible optional parameter.

Only source get/write tuple recording and map attachment are skipped. Captures,
conflict masks, typechecking, materialization, graph nodes/children/revisions,
verification, source ordering and lowering remain unchanged. One private Bool
adds no per-node array or retained cache. The absent map cannot be read through
the getter; its diagnostic states recording is required.

Three [API/graph/error tests](../../../../../src/ir/hot_lift_provenance_demand_wbtest.mbt)
were written first. An ignored flag produced the required absent-map failure;
implementation passes. They compare default/disabled HOT nodes, child edges,
revisions and lowered bodies across captures, references, multivalue and trapping
loads, plus intentionally malformed first errors and default source-order/dead
write placeholders. An [active four-pass carried-loop dispatcher](../../../../../src/cmd/lift_provenance_demand_wbtest.mbt)
preserves input bytes, validates results and requires real transformations.
The first full suite caught nine reference-helper readers: restoring the helper's
recording default fixed them; no tests or verification gates were weakened.

| Complete native scope | Before instructions | After instructions | Change |
| --- | ---: | ---: | ---: |
| DAE2 pass | 29,759,583,835 | 29,318,367,678 | −1.4826% |
| CoalesceLocals pass | 38,353,626,407 | 38,096,319,378 | −0.6709% |

Global allocator request deltas are −2,560,176/−1,500,381; call counting continues
after scoped instruction collection, so these are not pass-only allocation
measurements or byte/RSS savings. Direct lift-record requests fall
3,021,098→527,780 (DAE2) and1,460,220→326 (CL); required default/provenance paths
remain. Recursive inclusive edges are not added to complete totals.

Four [wasm-gc controls](../../../../../src/ir/hot_lift_provenance_demand_perf_wbtest.mbt),
mean±SD µs before→after: width8 default3.97±.056→3.86±.038;
width8 disabled3.91±.032→3.65±.053; width512 default172.57±2.71→168.85±1.89;
width512 disabled174.34±.748→158.26±1.90. The before flag was deliberately ignored.

Same 6,211,596 B SHA98189860… input; verified Binaryen133 SHA8f25e9fd…;
Ryzen7 8845HS CPU6, Moon0.1.20260920/moonc0.10.14, GCC14.2 O2/mimalloc.
Build excluded; one warmup/five alternating fresh-process, warm-filesystem
normal CLI samples, median±MAD ms [min,max]:

| Pass | Before | After | Binaryen133 | After/B | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3396.469±25.807 [3370.662,3613.128] | 3371.093±36.276 [3334.817,3480.724] | 1195.674±5.305 [1184.726,1209.099] | 2.819× | -1.815% |
| dae2-optimizing | 6055.411±129.688 [5911.138,7900.646] | 5950.823±20.095 [5804.863,7185.998] | 2511.450±14.239 [2495.698,3527.312] | 2.369× | -1.798% |
| coalesce-locals | 3936.592±28.097 [3908.495,4014.419] | 3886.165±10.651 [3776.635,3896.816] | 1960.111±10.922 [1895.700,1982.460] | 1.983× | -2.302% |
| optimize-instructions | 2030.078±5.710 [1960.375,2048.993] | 2035.806±15.915 [1957.328,2124.408] | 1054.108±10.480 [1004.446,1086.382] | 1.931× | +0.282% |

Keep ranges and adverse/contended rows visible; no universal clock or peak-memory
claim follows from instruction counts. Separate n1 traced diagnostics:

- dae2: RSS before/after median 262,420/247,356 KiB; foreign rows before/after/oracle 5/5/5. Diagnostic inner 2867.696→2726.023 ms; pipeline 2883.246→2741.486 ms.
- dae2-optimizing: RSS before/after median 290,940/290,932 KiB; foreign rows before/after/oracle 5/5/5. Diagnostic inner 5242.339→5088.594 ms; pipeline 5262.415→5104.597 ms.
- coalesce-locals: RSS before/after median 243,424/243,712 KiB; foreign rows before/after/oracle 5/5/5. Diagnostic inner 3020.966→2993.479 ms; pipeline 3036.579→3009.069 ms.
- optimize-instructions: RSS before/after median 156,624/156,340 KiB; foreign rows before/after/oracle 5/5/5. Diagnostic inner 85.395→83.788 ms; pipeline 1504.384→1496.635 ms.

OI's narrow timer excludes most cleanup. These diagnostics do not supersede the
preceding n3 matched pass-scope comparison or establish pass-local 1× parity.

The default-path OI complete-process control is 18,585,524,926→18,584,960,830 instructions (-0.0030%).

Info/fmt/check, **13,499 default tests**, four controls, native release and README/API
sync pass. **1,156 validations / 3,392 available runtime observations**
cover71 fixtures per pass. DAE2/OO each70 fully compare plus the existing blocked
typed-block rewrite; CL/OI each71 fully compare. Original/before/after/133 values,
ordered calls, globals/memory and permitted trap status agree on supported rows.
The documented no-pass text adapter is used only for Binaryen compact-import
encodings unsupported by Node26. All four large before/after raw hashes remain
exact. Canonical OO+99,251B/CL+78,800B/OI+33,497B gaps remain; no fresh canonical
or full release signoff is claimed.

Local `lift-provenance-*` artifacts retain source/build hashes, exact commands,
profiles, clock distributions, resource RED and ownership review. The interrupted
ENOSPC suite and the initial nine-test helper-contract failure are retained
separately; only the successful rerun counts. Independent review, full CI/coverage
and deferred aggregate fuzz remain pending. All four1× goals remain open. Next:
OI lazy directization output, then larger dependency/lower/cleanup costs with
complete consumer measurements.

## October 4, 2026: copy directization output only after a rewrite

[OI-only follow-up](../optimize-instructions/starshine-strategy.md#october-4-2026-copy-directization-output-only-after-a-rewrite) removes340,195 requests and0.8188% of complete OI native work while retaining all discovery and bytes. N5 command timing is adverse+0.650%; no command win or1× claim. The preceding DAE2/O/CL matrix remains current;13,503 tests and all-four bounded runtime controls pass supported rows.

## October 4, 2026: inline lower stack without optional discard boxes

The private [lower stack](../../../../../src/ir/hot_lower.mbt) now stores immutable
node/type records inline. Discarding consumed lanes uses saturating truncate/clear;
a checked last-slot read avoids constructing an optional record. Nonpositive
counts, terminal clearing, actual value-consuming pops, typed operands, effects,
verification and output selection retain their previous behavior. Copies own their
slots and immutable reference type payloads retain references.

The annotation-only first trial was rejected: complete DAE2/CL instruction work
increased .2403%/.3274% because optional pop/last results reboxed inline values.
The accepted combined change removes those hot discard/peek boxes. Native
`4c20bc54…`→`66f924ab…`, base main `b5cd1efa3`, complete DAE2 work
29,319,259,841→29,240,765,707 instructions (−.2677%); CL
38,095,458,081→37,981,021,244 (−.3004%). Whole-profile allocator requests
fall627,084/1,033,180 respectively; these are requests, not bytes or pass-only
allocation totals. Complete OI work18,432,354,285→18,432,328,939 is effectively
unchanged. Mandatory work and large output hashes remain exact.

Same6,211,596 B compiler SHA98189860…, verified Binaryen133 SHA8f25e9fd…,
Ryzen7 8845HS CPU6, GCC14.2 O2/mimalloc. Build excluded; one warmup and five
rotating alternating fresh-process/warm-filesystem CLI samples per tool.
Milliseconds median±MAD [min,max]:

| Pass | Before | After | Binaryen133 | After /133 | Paired change |
| --- | ---: | ---: | ---: | ---: | ---: |
| dae2 | 3575.049±36.165 [3412.186,3611.214] | 3614.478±80.312 [3412.254,3694.790] | 1199.432±10.082 [1189.350,1281.820] | 3.013× | +1.103% |
| dae2-optimizing | 6107.454±74.203 [5891.184,6181.657] | 5996.174±67.171 [5929.002,6212.346] | 2544.625±31.877 [2497.234,2607.713] | 2.356× | +0.159% |
| coalesce-locals | 3988.858±18.635 [3970.223,4063.117] | 3989.440±3.639 [3980.053,4074.328] | 2093.050±20.700 [2018.033,2113.750] | 1.906× | +0.230% |
| optimize-instructions | 1990.524±4.399 [1940.395,2010.671] | 2021.635±21.061 [1980.607,2190.861] | 981.109±9.474 [962.097,1165.510] | 2.061× | +2.072% |

All15 rows per pass flag foreign CPU activity; paired changes are adverse.
This is a small native-work/allocation reduction, not an established command-time
or RSS win. Separate traced n1 diagnostics are retained locally, never substituted
for normal CLI or matched Binaryen inner timings. OI's narrow timer omits cleanup.

Three [ownership, scalar/reference and typed-branch regressions](../../../../../src/ir/hot_lower_stack_value_wbtest.mbt)
pass before/after. Native resource inspection supplies the failing-before
allocation condition; no transform behavior gap is claimed. Six bounded
[stack](../../../../../src/ir/hot_lower_stack_value_perf_wbtest.mbt) and
[actual-update](../../../../../src/ir/hot_lower_stack_update_perf_wbtest.mbt)
controls pass. Compared with the rejected inline-only trial, consume2/64 means
36.16±1.02→32.97±.13 ns and450.35±8.27→404.46±5.05 ns. Generic stack-control
variation is retained separately and is not attributed to unrelated update code.
Info/fmt/check,13,509 workspace tests (including one pending CL characterization),
native release and README/API sync pass; public `.mbti` is unchanged.
Existing active scalar/GC dispatcher tests and75 runtime fixtures per pass give
1,220 validations/3,584 supported original/before/after/133 observations of values,
ordered effects, globals, memory and traps. DAE2/O each74 fully compare plus the
existing `probe-typed-block-trap` command failure; CL/OI each75 fully compare.
This known failure remains a release blocker, not a passing comparison.

Raw DAE2/O/CL/OI bytes remain6,115,221/5,563,501/5,706,503/6,205,995.
V83 savings and prior bounded canonical deficits are unchanged; no new
normalization is claimed. Local `lower-stack-queries-*` manifests, commands,
samples, profiles, native excerpts and manual review retain exact provenance.
Independent review, full CI/coverage, deferred aggregate fuzz and all four1×
targets remain open. Next: packed CL liveness and exact repeated mixed-band lift
queries, then the larger DAE2 dependency and optimizing-cleanup owners.

## October 4, 2026: mixed-band conflict consumer check

[The complete shared-lift trial](../coalesce-locals/starshine-strategy.md#october-4-2026-memoize-exact-mixed-band-lift-conflicts)
saves7.5544% complete CL instructions but increases DAE2 work.0175%.
Keep this negative control explicit. The fresh all-four command matrix remains
2.774×/2.450×/1.908×/2.115× for DAE2/O/CL/OI, with all rows contended;
no extrapolated DAE2 gain or1× signoff. The source-backed next DAE2 owners are
complete expanded CFG construction and dependency analysis. Temporary function
diagnostics distinguish7,954 initial analyses from400 rewrite replay calls;
focused profiles must precede changes to those algorithms.
