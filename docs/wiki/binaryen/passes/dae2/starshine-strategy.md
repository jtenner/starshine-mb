---
kind: entity
status: working
last_reviewed: 2026-10-01
sources:
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
  - ../../../../../src/passes/dae2_stack_suffix_rewrite.mbt
  - ../../../../../src/passes/dae2_parameter_aliases.mbt
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
  - ../../../../../src/passes/lower_capture_cleanup.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/pull/8903
  - https://github.com/WebAssembly/binaryen/pull/8994
  - ../../../../../src/passes/dead_argument_elimination2.mbt
  - ../../../../../src/passes/dae2_repeated_solve_perf_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_types.mbt
  - ../../../../../src/passes/dead_argument_elimination2_legacy.mbt
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
