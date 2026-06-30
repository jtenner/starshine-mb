---
kind: comparison
status: working
last_reviewed: 2026-06-30
sources:
  - ../../../raw/research/1384-2026-06-30-tuple-optimization-root-elision-fast-path.md
  - ../../../raw/research/1383-2026-06-30-tuple-optimization-no-copy-payload-fast-path.md
  - ../../../raw/research/1382-2026-06-30-tuple-optimization-no-scalar-forward-fast-path.md
  - ../../../raw/research/1381-2026-06-29-tuple-optimization-no-result-link-fast-path.md
  - ../../../raw/research/1380-2026-06-29-tuple-optimization-local-set-root-fast-path.md
  - ../../../raw/research/1379-2026-06-29-tuple-optimization-no-scalarized-prescan-performance.md
  - ../../../raw/research/1378-2026-06-29-tuple-optimization-no-new-local-cleanup-performance.md
  - ../../../raw/research/1377-2026-06-29-tuple-optimization-no-tee-cleanup-performance.md
  - ../../../raw/research/1376-2026-06-29-tuple-optimization-payload-facts-performance.md
  - ../../../raw/research/1375-2026-06-29-tuple-optimization-source-fast-path-performance.md
  - ../../../raw/research/1374-2026-06-29-tuple-optimization-elision-mask-performance.md
  - ../../../raw/research/1373-2026-06-29-tuple-optimization-targeted-root-removal.md
  - ../../../raw/research/1372-2026-06-29-tuple-optimization-use-def-reuse.md
  - ../../../raw/research/1371-2026-06-29-tuple-optimization-batched-root-removal.md
  - ../../../raw/research/1370-2026-06-29-tuple-optimization-aggregate-rewrite-timers.md
  - ../../../raw/research/1369-2026-06-29-tuple-optimization-scalarized-cleanup-fast-skip.md
  - ../../../raw/research/1358-2026-06-29-tuple-optimization-genvalid-profile.md
  - ../../../raw/research/1360-2026-06-29-tuple-optimization-typeidx-tee-scalarization.md
  - ../../../raw/research/1361-2026-06-29-tuple-optimization-drop-only-typeidx-lanes.md
  - ../../../raw/research/1362-2026-06-29-tuple-optimization-residual-scalar-spelling.md
  - ../../../raw/research/1363-2026-06-29-tuple-optimization-broader-profile-and-performance.md
  - ../../../raw/research/1368-2026-06-29-tuple-optimization-root-removal-rejected.md
  - ../../../raw/research/1367-2026-06-29-tuple-optimization-detached-delete-performance.md
  - ../../../raw/research/1366-2026-06-29-tuple-optimization-drop-only-elision-performance.md
  - ../../../raw/research/1365-2026-06-29-tuple-optimization-root-slot-lookup.md
  - ../../../raw/research/1364-2026-06-29-tuple-optimization-performance-attribution.md
  - ../../../raw/research/0546-2026-05-06-tuple-optimization-gen-valid-rerun.md
  - ../../../raw/research/0542-2026-05-06-tuple-optimization-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0434-2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./scheduler-and-gates.md
  - ./reduced-repros-and-evidence.md
  - ../../no-dwarf-default-optimize-path.md
---

# `tuple-optimization` Binaryen Parity

## Durable Conclusions

- Starshine's tuple-opt should be judged first against Binaryen, not against a home-grown notion of "reasonable multivalue cleanup."
- The explicit pass surface is real and useful today, and the exact in-tree preset slot is now scheduled in `optimize` and `shrink`.
- The isolated pass has fresh direct parity evidence under the 2026-05-09 refreshed `pass-fuzz-compare` harness.
- The old white-box exact-shape reds were stale expectation debt and are now rebaselined to the current Binaryen-backed scalarization contract; full exact-slot artifact parity is still not signed off.
- The 2026-06-29 source refresh keeps Binaryen's pass surface focused on tuple-local scalarization: tuple locals are eligible when written by `tuple.make` or good tuple-local copies and read only by tuple extracts or copies; bad/escaping tuple reads propagate badness through copy edges. Binaryen still leaves direct `tuple.make`/`tuple.extract` without a local and block-produced tuple values outside this pass.
- A new dedicated `tuple-optimization-all` GenValid profile now hits spill/copy-chain/tee carrier families directly. Its count-30 smokes validate generation but still expose `30 / 30` normalized mismatches, so the current profile is a parity-gap discovery lane rather than signoff evidence. The latest simple type-indexed drop-only slices move every sampled residual family to a raw-size/op win for Starshine, and the residual-spelling inspection classifies this pure/drop-only surface as a narrow measured Starshine win with reopening criteria. A count-100 follow-up stayed inside that same narrow family, with zero effect/trap facts, no raw Starshine tuple/block carrier debris, and uniform wins by profile family. Candidate-heavy performance attribution points the active speed blocker at TO rewrite mutation work. Follow-up performance slices reduced the 100/500/1000 independent two-lane spill fixtures from pass-local `4.132ms`, `41.643ms`, and `153.200ms` first to `2.944ms`, `31.320ms`, and `116.342ms` via use-def-bounded root-slot lookup, then to `1.916ms`, `21.425ms`, and `73.728ms` via pure drop-only source elision. A detached replacement-delete slice then reduced the larger candidate-heavy fixtures to `16.288ms`, `45.108ms`, and `113.093ms` at 500/1000/2000 pairs by avoiding full unreferenced scans for freshly-built replacement nodes; the 100-pair timing is noisy under the new subphase timers. A follow-up per-group root-removal experiment was rejected: removing local.set roots directly reduced later `prune-nops` work but moved more cost into repeated root splices, regressing 500/1000/2000 pair timings to `20.504ms`, `53.376ms`, and `135.664ms` in the better contiguous-batch attempt. The scalarized tuple-local cleanup fast-skip then removed that cleanup phase from pure/drop-only candidate-heavy fixtures, with cleaner rerun pass times `2.766ms`, `17.776ms`, `36.571ms`, and `100.860ms` for 100/500/1000/2000 pairs versus Binaryen `0.041ms`, `0.162ms`, `0.318ms`, and `0.879ms`. The aggregate rewrite-timer slice then stopped emitting source/simple-drop-only sub-timer lines once per group, reducing representative candidate-heavy times to `1.170ms`, `7.932ms`, `24.379ms`, and `78.062ms` versus Binaryen `0.042ms`, `0.241ms`, `0.295ms`, and `0.938ms`. The pass-level batched root-removal slice then stopped rewriting pure/drop-only root source `local.set`s to per-group temporary `nop`s, removed those roots in one cleanup traversal, and skipped per-group mutation marking for deferred-only groups; candidate-heavy times moved to `0.845ms`, `7.000ms`, `19.080ms`, and `70.095ms` versus Binaryen `0.033ms`, `0.163ms`, `0.300ms`, and `0.912ms`. The rewrite use-def reuse slice then removed the duplicate pre-rewrite use-def build by threading the already-valid analysis use-def into rewrite; candidate-heavy times moved again to `0.505ms`, `4.132ms`, `14.528ms`, and `49.278ms` versus Binaryen `0.055ms`, `0.156ms`, `0.330ms`, and `0.647ms`. The targeted root-removal / fast root-region replacement slice then limited pure/drop-only root cleanup to known affected regions when safe, preserved the full scan for generated or pre-existing nops, and optimized root-region body replacement in HOT; candidate-heavy times moved again to `0.454ms`, `2.907ms`, `8.606ms`, and `30.561ms` versus Binaryen `0.032ms`, `0.152ms`, `0.345ms`, and `0.880ms`. The elision-mask performance slice then precomputed the narrow pure/drop-only source-elision decision once per rewrite pass, reused it during split-local preparation, and avoided the duplicate per-group rewrite `can-elide` scan; candidate-heavy times moved again to `0.408ms`, `2.285ms`, `7.097ms`, and `21.286ms` versus Binaryen `0.038ms`, `0.152ms`, `0.292ms`, and `0.618ms`. The source-only/no-copy fast-path slice then avoided per-group source timer/copy-consumer scans for all-elided source rewrite orders and skipped copy-family rewrite-mask suppression scans for no-copy groups; candidate-heavy times moved again to `0.344ms`, `1.183ms`, `2.605ms`, and `4.498ms` versus Binaryen `0.052ms`, `0.148ms`, `0.280ms`, and `0.608ms`. The payload-facts slice then reused payload lanes already proven by the drop-only elision precompute, removing the rewrite-time payload subphase from the source-only fast path and reducing the 1000-pair rewrite timer from `0.562ms` to `0.351ms`; noisy candidate-heavy pass timings were `0.386ms`, `1.274ms`, `2.595ms`, and `4.710ms` on the first 100/500/1000/2000 run, with 1000-pair spot reruns down to `2.187ms` / `2.205ms`. The no-tee cleanup slice then carried an analysis fact proving there were no original `local.tee` definitions into cleanup, skipping the dropped-tee cleanup scan on no-tee source-only elision paths. First candidate-heavy timings were `0.313ms`, `1.160ms`, `2.136ms`, and `5.375ms` versus Binaryen `0.031ms`, `0.144ms`, `0.295ms`, and `0.905ms`, with 1000-pair spot reruns `2.063-2.156ms` and 2000-pair spot reruns `4.017-4.153ms`. The no-new-local cleanup slice then skipped the unused-body-local cleanup scan when rewrite appended no locals; the fast-path timer fires, but pass-local timings are still noisy and outside target (`0.347/0.052`, `1.485/0.225`, `2.713/0.347`, `5.987/0.665` ms first run, with 1000-pair spots `2.197-2.476ms` and 2000-pair spots `4.036-4.498ms`). The no-scalarized-prescan cleanup slice then reused query-summary facts to skip the scalarized tuple-local cleanup pre-scan when analysis saw no `local.set (tuple.make ...)` candidate; it fires the new fast-path timer and removes the ordinary pre-scan from the candidate-heavy fixture, but timings remained noisy and outside target (`0.407/0.047`, `1.244/0.149`, `3.088/0.435`, `5.344/0.630` ms first run; 1000-pair spots `2.148-2.529ms`, 2000-pair spots `4.518-5.047ms`). The local-set root fast-path slice then avoided the generic replacement/root-slot path for pure/drop-only source-only groups whose definitions are all live root `local.set`s, replacing the old `replace-defs` timer with `elide-simple-drop-only-source:local-set-root-fast-path` on that fixture. It reduced the 1000-pair source-only rewrite subphase in the kept trace from about `0.607ms` to `0.404ms`, but overall candidate-heavy timings remained outside target (`0.394/0.040`, `1.111/0.212`, `2.693/0.308`, `5.702/0.882` ms first run; 1000-pair spots `2.106-3.267ms`, 2000-pair spots `5.037-5.252ms`). The no-result-link fast-path slice then recorded whether query-summary construction saw any live one-result `block`, skipped `link-result-block-copy-groups` plus its immediate local-group rebuild when no such carrier exists, and replaced that timer with `link-result-block-copy-groups:no-single-result-block-fast-path` on the pure/drop-only candidate-heavy fixture. First-run candidate-heavy timings improved to `0.324/0.043`, `1.212/0.168`, `2.197/0.299`, and `4.428/0.786` ms at 100/500/1000/2000 pairs, with spot reruns at 1000 pairs `2.099-2.522ms` and 2000 pairs `4.496-4.688ms`. The no-scalar-forward fast-path slice then recorded whether query-summary construction found any scalar-forward copy candidate, skipped `link-scalar-forward-copy-groups` plus its immediate local-group rebuild when no such candidate exists, and replaced that timer with `link-scalar-forward-copy-groups:no-scalar-forward-fast-path` on the pure/drop-only candidate-heavy fixture. First-run candidate-heavy timings were `0.301/0.039`, `1.050/0.151`, `3.728/0.371`, and `4.625/0.679` ms at 100/500/1000/2000 pairs, with spot reruns at 1000 pairs `2.246-2.951ms` and 2000 pairs `4.468-4.753ms`. The no-copy-payload fast-path slice then recorded whether any seed group has a trailing block payload shaped like `local.get` / `local.tee(local.get)` lane copies, skipped `link-copy-groups` when no exact-copy payload candidate exists, and replaced the generic timer with `link-copy-groups:no-copy-payload-fast-path` on the source-only fixture. The kept cheap precheck first-run timings were `0.349/0.046`, `1.114/0.238`, `2.242/0.311`, and `4.507/0.673` ms at 100/500/1000/2000 pairs, with spot reruns at 1000 pairs `1.980-2.111ms` and 2000 pairs `4.196-4.290ms`. The simple drop-only root-elision fast-path slice then recognized the exact source-only/no-host/local-set/drop-only fixture before full TO analysis, skipped query-summary/copy-link/rewrite-mask/drop-only-precompute/split/generic-rewrite work, and removed the eligible source `local.set` roots through the existing cleanup plan. First-run timings improved to `0.165/0.040`, `0.676/0.192`, `1.522/0.316`, and `2.933/0.762` ms at 100/500/1000/2000 pairs. This remains outside the pass-local target but narrows remaining owners to seed collection, fast-path validation/root-region lookup, targeted root cleanup, and untraced pass overhead. This is still not final closeout: broader type/lane-count/effect/non-drop surfaces, general lanes, candidate-heavy pass-local performance fix, exact-slot evidence, and the full 100k closeout remain open.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt).
- Focused white-box coverage lives in [`../../../../../src/passes/tuple_optimization_wbtest.mbt`](../../../../../src/passes/tuple_optimization_wbtest.mbt).
- CLI and emitted-module shape checks live in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).
- Direct native Binaryen comparison lives in [`../../../../../src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt).
- Preset placement now lives in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt): `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> heap2local`.

## Current Direct Test Evidence

Fresh direct revalidation taken for this doc update on `2026-05-09`:

- `moon test src/passes`
  - result: `806 / 806` passed after the preset-slot scheduling tests were updated
- `moon test src/cmd`
  - result: `130 / 130` passed
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-optimization-slot`
  - result: `6759 / 10000` compared, `6759` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `20` command failures
  - command-failure classification: `binaryen-rec-group-zero` (`17`), `binaryen-bad-section-size` (`1`), `binaryen-table-index-out-of-range` (`1`), `binaryen-invalid-tag-index` (`1`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 --seed 0x5eed --generator gen-valid --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-optimization-gen-valid-slot`
  - result: `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures

Previous direct revalidation taken on `2026-05-06`:

- `moon info`
  - result: completed with existing warnings only
- `moon fmt`
  - result: completed, no formatting work needed
- `moon test`
  - result: `2820 / 2820` passed
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization`
  - result: `6759 / 10000` compared, `6759` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `20` command failures
  - command-failure classification: the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs with empty recursion groups, not a Starshine/Binaryen semantic mismatch
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-gen-valid-10000-20260506`
  - result: `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures

Older focused local checks taken on `2026-04-10`:

- `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*tuple-optimization*'`
  - result: `15 / 15` passed
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - result: `42 / 42` passed
- `moon test --package jtenner/starshine/cmd --file cmd_wbtest.mbt --filter '*tuple-optimization*'`
  - result: `7 / 7` passed

Interpretation:

- the direct native Binaryen-compare lane is green again on every committed tuple-opt regression in that file
- the black-box command-surface tuple lane is also green again
- the white-box tuple file is green again after rebasing stale temp-local shape checks onto stable scalarization and copyback invariants
- the remaining open work is preset placement plus the larger artifact/runtime proof gap, not direct explicit-pass parity

## Current Green Surface

The branch is already in good shape on these fronts:

- explicit pass registration and CLI execution
- scalar-only explicit no-op behavior
- reduced direct spill, copy-chain, host-tee, mixed scalar-forward, nested no-host, nested scalar-result, terminal host-drop, and chained `tail-live0` parity families in the native compare suite
- black-box lowered-module checks for all committed tuple-opt command regressions
- white-box rewrite and analysis coverage for all committed tuple-opt reduced regressions
- historical and fresh isolated fuzz lanes with zero semantic mismatches on comparable cases

## Current Red Surface

Direct explicit-pass parity was signed off under the refreshed 2026-05-09 generic GenValid harness, and the public preset slot is enabled. The new 2026-06-29 TO-specific profile deliberately reopens reduced carrier parity work by generating hotter tuple-local carrier shapes:

- `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30` generated/validated `30 / 30`, with zero validation/generator/command/property failures, but all 30 cases were normalized mismatches.
- profile distribution: spill `12`, copy-chain `14`, tee `4`.
- `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-6-post-label` generated/validated `6 / 6` after manifest plumbing and recorded profile-case counts (`tuple-optimization:spill` `4`, `tuple-optimization:tee` `2`), with the same `6 / 6` normalized-mismatch status.
- first inspected mismatch was a validating type-indexed multivalue block carrier whose lanes are scalarized by Binaryen into a different local/block shape than Starshine. The 2026-06-29 type-indexed spill and tee slices now remove raw tuple/block carriers from simple no-host spill and host-tee payloads, and the follow-up drop-only lane slice avoids copying simple `i32, i64` type-indexed source lanes back into original locals when those lanes only feed drops. The dedicated profile remains raw-red because Starshine emits different scalar temp/tee/copy spelling from Binaryen. The post-tee count-30 measurement at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-host-tee-simple-payload` found spill `+2` Starshine raw bytes but `-2` locals / `-3` effective WAT ops per case, tee `+1` raw byte but `-2` locals / `-4` ops, and copy-chain `-4` raw bytes / `-6` locals / `-10` ops. The count-30 measurement at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-drop-only-split` keeps `30 / 30` raw mismatches with zero failures but improves the sampled residuals to spill `-3` Starshine raw bytes / `-2` locals / `-5` ops each, tee `-4` raw bytes / `-2` locals / `-6` ops each, and copy-chain `-4` raw bytes / `-6` locals / `-10` ops each. Agent classification in [`../../../raw/research/1362-2026-06-29-tuple-optimization-residual-scalar-spelling.md`](../../../raw/research/1362-2026-06-29-tuple-optimization-residual-scalar-spelling.md): this exact simple, pure, drop-only count-30 residual surface is a narrow measured Starshine-win scalar spelling family.
- `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-100-broader-bin` broadens that classification at the same seed: `100 / 100` compared, zero failures, `100` raw mismatches, profile distribution spill `41`, tee `15`, copy-chain `44`, no effect/trap facts, no raw Starshine tuple/block carrier debris, and uniform Starshine wins by family (spill `-3` raw / `-11` normalized / `-2` locals / `-5` ops, tee `-4` / `-12` / `-2` / `-6`, copy-chain `-4` / `-20` / `-6` / `-10`). Reopen on side effects/traps/non-drop uses, raw tuple/block carriers, size/local/op regressions, broader unproven type or lane-count shapes, runtime semantic differences, or Binaryen source drift. This classification is not final pass closeout and does not classify broader TO residuals.
- Candidate-heavy performance attribution in `.tmp/to-passlocal-candidate-heavy-{100,500,1000}-20260629-detail` kept the TO pass-local speed blocker open and narrowed the dominant owner to `detail:tuple-optimization:rewrite-group-defs`: `3.057ms` of `4.132ms` at 100 pairs, `31.378ms` of `41.643ms` at 500, and `118.803ms` of `153.200ms` at 1000. The use-def-bounded root-slot lookup slice in `.tmp/to-passlocal-candidate-heavy-{100,500,1000}-20260629-root-slot-hint` reduced Starshine pass times to `2.944ms`, `31.320ms`, and `116.342ms` and reduced `rewrite-group-defs` to `2.070ms`, `23.919ms`, and `92.264ms`. The pure drop-only elision slice in `.tmp/to-passlocal-candidate-heavy-{100,500,1000,2000}-20260629-drop-only-elide-batched-mark` reduced pass times to `1.916ms`, `21.425ms`, `73.728ms`, and `291.755ms` versus Binaryen `0.038ms`, `0.143ms`, `0.263ms`, and `0.557ms`; `rewrite-group-defs` remained dominant at `1.402ms`, `16.835ms`, `65.410ms`, and `250.428ms`. The detached replacement-delete slice added subphase timers and identified `rewrite-group-defs:elide-simple-drop-only-source:replace-defs` as a full-delete-scan owner; switching freshly-built replacement cleanup to `hot_delete_detached_node(...)` and reusing one nop replacement per group reduced larger candidate-heavy pass times to `16.288ms`, `45.108ms`, and `113.093ms` at 500/1000/2000 pairs versus Binaryen `0.147ms`, `0.295ms`, and `0.770ms`. The scalarized tuple-local cleanup fast-skip then avoids the cleanup use-def build/local scan when the rewritten function has no live `local.set (tuple.make ...)` candidate; cleaner rerun pass times were `2.766ms`, `17.776ms`, `36.571ms`, and `100.860ms` for 100/500/1000/2000 pairs versus Binaryen `0.041ms`, `0.162ms`, `0.318ms`, and `0.879ms`, with scalarized-local cleanup reduced to about `0.080ms` at 1000 pairs and `0.100ms` at 2000. The aggregate rewrite-timer slice then made per-group source/simple-drop-only sub-timers accumulate quietly and emit once after the hot loop; candidate-heavy 100/500/1000/2000 timings improved to `1.170ms / 0.042ms`, `7.932ms / 0.241ms`, `24.379ms / 0.295ms`, and `78.062ms / 0.938ms`. The pass-level batched root-removal slice then recorded pure/drop-only source `local.set` roots, removed them in one post-rewrite traversal, and avoided per-group mutation markers when all source work was deferred. Candidate-heavy 100/500/1000/2000 timings improved again to `0.845ms / 0.033ms`, `7.000ms / 0.163ms`, `19.080ms / 0.300ms`, and `70.095ms / 0.912ms`. The rewrite use-def reuse slice then threaded the already-valid analysis use-def through rewrite instead of rebuilding it, removing the `rewrite-use-def-build` timer and improving candidate-heavy timings to `0.505ms / 0.055ms`, `4.132ms / 0.156ms`, `14.528ms / 0.330ms`, and `49.278ms / 0.647ms`. The targeted root-removal / fast root-region replacement slice then recorded the exact regions containing deferred removable roots, kept the full scan for generated or pre-existing nops, optimized HOT root-region body replacement, and improved candidate-heavy timings to `0.454ms / 0.032ms`, `2.907ms / 0.152ms`, `8.606ms / 0.345ms`, and `30.561ms / 0.880ms`. The elision-mask performance slice then precomputed simple pure/drop-only source elision once per rewrite order and reused that bitset in split-local preparation and source rewrite, improving the same fixtures to `0.408ms / 0.038ms`, `2.285ms / 0.152ms`, `7.097ms / 0.292ms`, and `21.286ms / 0.618ms`. The source-only/no-copy fast-path slice then improved the same fixtures to `0.344ms / 0.052ms`, `1.183ms / 0.148ms`, `2.605ms / 0.280ms`, and `4.498ms / 0.608ms`. The payload-facts slice removed the rewrite-time payload subphase by carrying precomputed payload lanes with the elision mask; first candidate-heavy timings were `0.386ms / 0.037ms`, `1.274ms / 0.151ms`, `2.595ms / 0.334ms`, and `4.710ms / 0.704ms`, with spot reruns at 1000 pairs down to `2.205ms`, `2.444ms`, and `2.187ms`. The local-set-root fast-path detail trace showed `rewrite-group-defs:elide-simple-drop-only-source:local-set-root-fast-path` at `0.336ms`, source-only rewrite at `0.404ms`, targeted root cleanup at `0.213ms`, and `pass:tuple-optimization` `2.693ms`. The no-result-link fast-path slice then skipped result-block copy linking when query summary saw no live one-result blocks; the 1000-pair detail trace records `link-result-block-copy-groups:no-single-result-block-fast-path` at `0.000ms`, source-only rewrite `0.292ms`, targeted root cleanup `0.193ms`, and `pass:tuple-optimization` `2.197ms`, with 100/500/1000/2000 first-run pass times `0.324/0.043`, `1.212/0.168`, `2.197/0.299`, and `4.428/0.786` ms. The no-scalar-forward fast-path slice then skipped scalar-forward copy linking and its rebuild when query summary saw no scalar-forward candidate; the 1000-pair first-run detail trace records `link-scalar-forward-copy-groups:no-scalar-forward-fast-path` at `0.000ms`, source-only rewrite `0.905ms`, targeted root cleanup `0.646ms`, and `pass:tuple-optimization` `3.728ms`, with 100/500/1000/2000 first-run pass times `0.301/0.039`, `1.050/0.151`, `3.728/0.371`, and `4.625/0.679` ms. The no-copy-payload fast-path slice then skipped exact block-payload copy linking when seed collection saw no source-read payload candidate; the 1000-pair kept cheap-precheck trace records `link-copy-groups:no-copy-payload-fast-path` at `0.000ms`, source-only rewrite `0.298ms`, targeted root cleanup `0.201ms`, and `pass:tuple-optimization` `2.242ms`, with 100/500/1000/2000 first-run pass times `0.349/0.046`, `1.114/0.238`, `2.242/0.311`, and `4.507/0.673` ms. The simple drop-only root-elision fast-path slice then skipped full analysis/rewrite for exact source-only/no-host/local-set/drop-only groups. The 1000-pair trace records `collect-seed-groups` `0.468ms`, `simple-drop-only-root-elision-fast-path` `0.723ms`, targeted root cleanup `0.220ms`, and `pass:tuple-optimization` `1.522ms`; first-run pass times were `0.165/0.040`, `0.676/0.192`, `1.522/0.316`, and `2.933/0.762` ms. Remaining detail owners are seed collection, fast-path validation/root-region lookup, targeted root cleanup, and untraced pass overhead. This is not a closeout: TO still misses the pass-local target.
- exact-slot debug-artifact replay is still canonically red in `.tmp/to-exact-slot-artifact`
- the initial `defined=0 abs=17` `select`/`if` temporary-local representation drift is now classified in the compare tool, along with follow-on pure dropped-add, global-get alias, tail-return lowering, and simple trap-if inversion shapes
- the current first differing function in that replay is `defined=29 abs=46`; the actual Starshine output now avoids the tail `return` + trailing `unreachable` and empty-then `if` inversions, so the remaining byte-efficiency/code-quality gap is the extra block-result local materialization before `local.set $2`
- feature-off preset coverage is still pending explicit Starshine feature options
- full debug-artifact replay and tuple-only runtime remain active TO005 debt

## 2026-04-11 Health Rerun

- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 200 --seed 0x5eed --max-failures 30 --out-dir /tmp/health-tuple-200-2026-04-11-smoke`:
  - `199 / 199` compared, `199` normalized matches, `0` mismatches, `1` command failure (`binaryen-rec-group-zero`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 200 --seed 0x5eed --out-dir /tmp/health-tuple-200-genvalid-2026-04-11-smoke`:
  - `200 / 200` compared, `200` normalized matches, `0` mismatches
- This keeps tuple-optimization classified as direct-clean in this smoke band, with no semantic mismatches introduced since the prior check.

## Current Reduced Host-Copy Status

As of the current `2026-04-10` working tree:

- the reduced `terminal drop-only host copy groups` and `chained host-copy tail-live0` native compare regressions are green again
- the lowered command-surface repro for `tail-live0` is green again at `7 / 7` tuple cmd tests
- the remaining debt in that family is now performance/shape debt rather than a direct Binaryen mismatch:
  - raw rewritten HOT still retains one live `TupleMake`
  - pass-manager lowering hides that node by promoting it before `hot_lower`
  - the reduced self-opt compare is still red and slow even though the reduced native parity lane is green

## Standing Fuzz Evidence

Fresh current-head evidence:

- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 10000 --seed 0x5eed --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-gen-valid-10000-20260506`
  - result: `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification: `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-visitmarks-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-visitmarks-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is unchanged: `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-forwardcache-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-forwardcache-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is still `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-emptysummary-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-emptysummary-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is still `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-bincurrent-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-bincurrent-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is still `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator gen-valid --count 1000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-wbrefresh-2026-04-10`
  - result: `1000 / 1000` compared, `1000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-smith-wbrefresh-2026-04-10`
  - result: `199 / 200` compared, `199` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `1` command failure
  - current failure classification is still `binaryen-rec-group-zero` at case `29` (`Recursion groups of size zero not supported`)
- `bun scripts/pass-fuzz-compare.ts --starshine-bin _build/native/release/build/cmd/cmd.exe --pass tuple-optimization --generator gen-valid --count 10000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-10000-bin-sharedmarks-2026-04-10`
  - result: `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures

Standing larger evidence now includes the fresh current-head `10000 / 10000` `gen-valid` lane plus the older direct-native `10000 / 10000` lane.

These results are still not enough for final signoff because:

- they cover the explicit pass in isolation
- they do not substitute for exact preset-slot proof
- they do not close the remaining artifact/runtime family
- the current kept performance state is broader than visit-buffer reuse alone:
  - stamped visit-buffer reuse was parity-safe but did not materially move the reduced runtime gap
  - direct-use summary construction alone regressed the reduced pass timing
  - the current kept combination of forwarded-use memoization plus no-group summary skipping recovered that regression and moved reduced pass time to `0.511 ms`, but it still does not close the much larger Binaryen gap
- the long `gen-valid` parity lane also exposed an infrastructure distinction:
  - historical `moon run`-backed `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 10000 --max-failures 20 --out-dir /tmp/pass-fuzz-tuple-gen-valid-10000-emptysummary-2026-04-10` stopped after `2124` matches with `20` repeated missing-output validation failures
  - direct replay of the first recorded input still writes valid output
  - the same `10000`-case lane is clean when the harness calls the built native binary directly via `--starshine-bin _build/native/release/build/cmd/cmd.exe`
  - `pass-fuzz-compare` now retries that narrow successful-but-no-output `moon run` launcher churn, so the historical stop remains launcher evidence rather than a standing tuple-opt workaround or semantic mismatch

## Preset And Scheduler Status

The pass is now present in `optimize` and `shrink`.

Current scheduled neighborhood:

- `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> heap2local`

This intentionally matches Binaryen's local no-DWARF slot rather than an approximate placement. The remaining scheduler gap is no longer pass availability; it is exact-slot artifact proof plus feature-off coverage.

## Artifact And Performance Gap

Candidate-heavy direct-pass performance probes on `2026-06-29` and `2026-06-30` use synthetic fixtures with `100`, `500`, `1000`, and `2000` independent two-lane type-indexed block spills. The initial timing-only direct `--tuple-optimization` probe reported Starshine/Binaryen pass-local times of `3.107ms / 0.031ms`, `42.212ms / 0.145ms`, `152.870ms / 0.287ms`, and `590.101ms / 0.713ms`. Successive kept slices reduced those fixtures through use-def-bounded root-slot lookup, pure drop-only source elision, detached replacement deletes, scalarized tuple-local cleanup fast-skip, aggregate rewrite timers, pass-level batched root removal, rewrite use-def reuse, targeted removable-root cleanup with fast root-region replacement, precomputed pure/drop-only elision masks, source-only elision rewrite, no-copy rewrite-mask construction, precomputed payload facts for source-only elision, cleanup fast-skips, local-set root elision, no-single-result-block result-link skipping, and no-scalar-forward link/rebuild skipping. The latest first-run candidate-heavy timings are `0.301ms / 0.039ms`, `1.050ms / 0.151ms`, `3.728ms / 0.371ms`, and `4.625ms / 0.679ms` at 100/500/1000/2000 pairs, with spot reruns at 1000 pairs `2.246ms` and `2.951ms` and at 2000 pairs `4.468ms` and `4.753ms`. The latest 1000-pair detail trace shows `collect-seed-groups` `0.358ms`, `build-query-summary` `0.334ms`, `link-copy-groups` `0.154ms`, `link-result-block-copy-groups:no-single-result-block-fast-path` `0.000ms`, `link-scalar-forward-copy-groups:no-scalar-forward-fast-path` `0.000ms`, `precompute-drop-only-elision-mask` `0.291ms`, `rewrite-group-defs` `1.213ms`, `cleanup-post-rewrite:remove-elided-drop-only-roots:targeted-regions` `0.646ms`, and `cleanup-post-rewrite` `0.740ms`. Rewrite-mask construction, rewrite-time payload extraction, dropped-tee cleanup scanning, unused-local cleanup scanning, scalarized-local cleanup pre-scanning, generic root-`local.set` replacement, no-candidate result-block copy linking, and no-candidate scalar-forward copy linking/rebuild are no longer owners on this fixture; remaining owners are seed collection, query-summary construction, copy-linking, drop-only precompute, targeted root cleanup, and untraced pass overhead. TO still misses the pass-local target by a wide margin. Treat this as an active TO closeout blocker and a focused pass-performance slice, not as whole-command `[WALL]001` attribution. Evidence: [`../../../raw/research/1363-2026-06-29-tuple-optimization-broader-profile-and-performance.md`](../../../raw/research/1363-2026-06-29-tuple-optimization-broader-profile-and-performance.md), [`../../../raw/research/1364-2026-06-29-tuple-optimization-performance-attribution.md`](../../../raw/research/1364-2026-06-29-tuple-optimization-performance-attribution.md), [`../../../raw/research/1365-2026-06-29-tuple-optimization-root-slot-lookup.md`](../../../raw/research/1365-2026-06-29-tuple-optimization-root-slot-lookup.md), [`../../../raw/research/1366-2026-06-29-tuple-optimization-drop-only-elision-performance.md`](../../../raw/research/1366-2026-06-29-tuple-optimization-drop-only-elision-performance.md), [`../../../raw/research/1367-2026-06-29-tuple-optimization-detached-delete-performance.md`](../../../raw/research/1367-2026-06-29-tuple-optimization-detached-delete-performance.md), [`../../../raw/research/1368-2026-06-29-tuple-optimization-root-removal-rejected.md`](../../../raw/research/1368-2026-06-29-tuple-optimization-root-removal-rejected.md), [`../../../raw/research/1369-2026-06-29-tuple-optimization-scalarized-cleanup-fast-skip.md`](../../../raw/research/1369-2026-06-29-tuple-optimization-scalarized-cleanup-fast-skip.md), [`../../../raw/research/1370-2026-06-29-tuple-optimization-aggregate-rewrite-timers.md`](../../../raw/research/1370-2026-06-29-tuple-optimization-aggregate-rewrite-timers.md), [`../../../raw/research/1371-2026-06-29-tuple-optimization-batched-root-removal.md`](../../../raw/research/1371-2026-06-29-tuple-optimization-batched-root-removal.md), [`../../../raw/research/1372-2026-06-29-tuple-optimization-use-def-reuse.md`](../../../raw/research/1372-2026-06-29-tuple-optimization-use-def-reuse.md), [`../../../raw/research/1373-2026-06-29-tuple-optimization-targeted-root-removal.md`](../../../raw/research/1373-2026-06-29-tuple-optimization-targeted-root-removal.md), [`../../../raw/research/1374-2026-06-29-tuple-optimization-elision-mask-performance.md`](../../../raw/research/1374-2026-06-29-tuple-optimization-elision-mask-performance.md), [`../../../raw/research/1375-2026-06-29-tuple-optimization-source-fast-path-performance.md`](../../../raw/research/1375-2026-06-29-tuple-optimization-source-fast-path-performance.md), [`../../../raw/research/1376-2026-06-29-tuple-optimization-payload-facts-performance.md`](../../../raw/research/1376-2026-06-29-tuple-optimization-payload-facts-performance.md), [`../../../raw/research/1377-2026-06-29-tuple-optimization-no-tee-cleanup-performance.md`](../../../raw/research/1377-2026-06-29-tuple-optimization-no-tee-cleanup-performance.md), [`../../../raw/research/1378-2026-06-29-tuple-optimization-no-new-local-cleanup-performance.md`](../../../raw/research/1378-2026-06-29-tuple-optimization-no-new-local-cleanup-performance.md), [`../../../raw/research/1379-2026-06-29-tuple-optimization-no-scalarized-prescan-performance.md`](../../../raw/research/1379-2026-06-29-tuple-optimization-no-scalarized-prescan-performance.md), [`../../../raw/research/1380-2026-06-29-tuple-optimization-local-set-root-fast-path.md`](../../../raw/research/1380-2026-06-29-tuple-optimization-local-set-root-fast-path.md), [`../../../raw/research/1381-2026-06-29-tuple-optimization-no-result-link-fast-path.md`](../../../raw/research/1381-2026-06-29-tuple-optimization-no-result-link-fast-path.md), and [`../../../raw/research/1382-2026-06-30-tuple-optimization-no-scalar-forward-fast-path.md`](../../../raw/research/1382-2026-06-30-tuple-optimization-no-scalar-forward-fast-path.md).

Fresh exact-slot artifact evidence on `2026-05-09`:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --code-pushing --tuple-optimization --simplify-locals-nostructure --vacuum --reorder-locals --remove-unused-brs --out-dir .tmp/to-exact-slot-artifact`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Normalized WAT equal: no`
  - `Canonical function compare equal: no`
  - first differing function before this compare-tool normalization slice: `defined=0 abs=17`
  - `Starshine pass runtime (ms): 2485.260`
  - `Binaryen pass runtime (ms): 488565.000`
  - `Starshine pass at least as fast: yes`
- Follow-up exact-slot artifact evidence after fixing actual output code-quality gaps on `2026-05-09`:
  - command: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --code-pushing --tuple-optimization --simplify-locals-nostructure --vacuum --reorder-locals --remove-unused-brs --out-dir .tmp/to-exact-slot-artifact`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Normalized WAT equal: no`
  - `Canonical function compare equal: no`
  - current first differing function: `defined=29 abs=46`
  - `Starshine pass runtime (ms): 2618.045`
  - `Binaryen pass runtime (ms): 482170.000`
  - `Starshine pass at least as fast: yes`
- The original first differing function was representation drift in the `select`/`if` family after the `code-pushing` + no-structure cleanup neighborhood. The latest pass work fixed the real byte-efficiency issues around tail fallthrough and empty-then inversion in Starshine output. TO005 remains open because the same function still has a real extra-local materialization gap: Binaryen lowers the block result directly into `$2`, while Starshine still routes it through an extra local before copying to `$2`.

The older backlog entry that treated `/tmp/self-opt-tuple-current` as a tuple-pass blocker is now retired as a parity blocker.

What changed:

- the saved raw normalized-WAT hunk still begins at printed WAT `func $3639`
- that label is the defined-function ordinal in the `wasm-opt -S` text, not the absolute CLI function index
- on the saved compare pair there are `21` imported funcs ahead of it, so printed `func $3639` maps to absolute `Func[3660]`
- `starshine --print-func 3660 /tmp/self-opt-tuple-current/starshine.wasm` and the same command on `binaryen.wasm` match exactly on the project’s decoded canonical pretty-print surface
- the old red status was therefore a compare-surface bug, not a proven tuple rewrite bug

The compare tool now reflects that conclusion:

- `scripts/lib/self-optimize-compare-task.ts` still records whether raw normalized WAT text matches
- when raw normalized WAT differs, it now falls back to per-function canonical comparison through `--print-func`
- that fallback ports the same body-local alpha-normalization and scalar-ladder reordering logic already used by the native tuple parity tests
- when it does find a real function-level mismatch, it now records unambiguous artifacts as `func-definedN-absM.*` instead of the older ambiguous `func3639.*` style

Current interpretation:

- full tuple-only self-opt parity is no longer blocked by a known `func $3639` tuple rewrite bug
- the full tuple-only self-opt compare has now been rerun end-to-end with the upgraded canonical fallback
- raw normalized WAT text is still not a usable tuple parity oracle on the full artifact, but canonical per-function comparison is now green on current head
- tuple-only runtime is still materially slower than Binaryen, so performance work remains real even though the old raw WAT hunk is no longer a correctness blocker

Fresh full-artifact evidence on `2026-04-10`:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-canonical-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5328.045`
  - `Binaryen runtime (ms): 334.375`
  - `Starshine pass runtime (ms): 966.501`
  - `Binaryen pass runtime (ms): 4.331`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-smalllocals-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5295.675`
  - `Binaryen runtime (ms): 317.250`
  - `Starshine pass runtime (ms): 965.752`
  - `Binaryen pass runtime (ms): 2.666`

Fresh kept-tree pass-trace diagnosis on the same artifact:

- `cmd.exe --tracing pass --debug-serial-passes --tuple-optimization ...`
  - `4462` functions visited
  - `18` functions changed
  - total tuple pass time `277790 us`
  - the previous unchanged-function hot quartet (`Func 3612`, `1553`, `1525`, `1673`) is no longer the main story after the shared seed-scan plus stamped duplicate-lane slices
  - the current hot functions are:
    - `Func 1673`: `101831 us`
    - `Func 148`: `14719 us`
    - `Func 2389`: `10152 us`
    - `Func 1905`: `6557 us`
    - `Func 3660`: `5725 us`

Fresh current-tree full-artifact reruns after the candidate-filter rewrite:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-candidatefilter-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5634.347`
  - `Binaryen runtime (ms): 406.502`
  - `Starshine pass runtime (ms): 361.452`
  - `Binaryen pass runtime (ms): 3.711`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir /tmp/self-opt-tuple-full-candidatefilter-rerun-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT text equal: no`
  - `Canonical function compare equal: yes`
  - `Normalized WAT equal: yes`
  - `Starshine runtime (ms): 5114.578`
  - `Binaryen runtime (ms): 377.363`
  - `Starshine pass runtime (ms): 325.221`
  - `Binaryen pass runtime (ms): 3.741`

Fresh reduced performance evidence taken on `2026-04-10`:

- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 32.204`
  - `Binaryen runtime (ms): 3.066`
  - `Starshine pass runtime (ms): 0.515`
  - `Binaryen pass runtime (ms): 0.015`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-visitmarks-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 31.959`
  - `Binaryen runtime (ms): 3.220`
  - `Starshine pass runtime (ms): 0.547`
  - `Binaryen pass runtime (ms): 0.017`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-querysummary-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 43.497`
  - `Binaryen runtime (ms): 3.938`
  - `Starshine pass runtime (ms): 0.757`
  - `Binaryen pass runtime (ms): 0.020`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-forwardcache-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 33.691`
  - `Binaryen runtime (ms): 3.097`
  - `Starshine pass runtime (ms): 0.601`
  - `Binaryen pass runtime (ms): 0.016`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-emptysummary-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 35.406`
  - `Binaryen runtime (ms): 2.993`
  - `Starshine pass runtime (ms): 0.511`
  - `Binaryen pass runtime (ms): 0.014`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-sharedmarks-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 36.952`
  - `Binaryen runtime (ms): 3.674`
  - `Starshine pass runtime (ms): 0.547`
  - `Binaryen pass runtime (ms): 0.016`
- `bun scripts/self-optimize-compare.ts /tmp/tuple-host-tail-live0.wasm --out-dir /tmp/self-opt-tuple-tail-live0-cleanupfast-2026-04-10 --tuple-optimization`
  - `Canonical wasm equal: no`
  - `Normalized WAT equal: no`
  - `Starshine runtime (ms): 42.026`
  - `Binaryen runtime (ms): 3.471`
  - `Starshine pass runtime (ms): 0.565`
  - `Binaryen pass runtime (ms): 0.017`

Accuracy notes:

- this doc update did rerun the reduced self-opt compare on the committed `tail-live0` repro
- this doc update also reran the isolated fuzz lanes after the newer direct-use summary, forwarded-use memoization, no-group summary-skip, and small-locals analysis slices
- this doc update did rerun the full `tests/node/dist/starshine-debug-wasi.wasm --tuple-optimization` pipeline with the upgraded canonical fallback, and the full-artifact parity claim above now comes from that fresh rerun rather than only from the saved pair replay
- this doc update also reran the full artifact after replacing the weak no-op screen plus duplicated seed walk with a shared precise seed scan
- this doc update reran the direct debug-artifact tuple pass trace on the cleaned kept tree after backing out the child-index, incremental local-group-id, and prescan experiments
- the reduced timing ladder now has a clearer shape:
  - stamped visit-buffer reuse was parity-safe but did not materially improve the reduced timing gap
  - direct-use summary construction alone regressed the reduced timing repro
  - forwarded-use memoization recovered most of that regression
  - skipping summary construction for no-group functions brought reduced pass time down further to `0.511 ms`, slightly better than the earlier visit-buffer-only `0.547 ms`
- the later shared-mark and cleanup-fast-path experiments did not improve the reduced repro beyond that `0.511 ms` checkpoint
- the newer candidate-filter slice did materially improve the full artifact:
  - full tuple pass time dropped from roughly `966 ms` to a `325-361 ms` band on repeated reruns
  - the key code change was structural, not heuristic: tuple-opt now performs one shared precise seed scan instead of a weak whole-function screen plus a second weak screen plus a second seed walk, and seed discovery now uses stamped local marks instead of per-producer linear duplicate-local checks plus reverse-array rebuilding
  - the old unchanged-function hot quartet mostly disappeared from the pass trace, which is strong evidence that the earlier runtime debt really was candidate-screen churn rather than later rewrite work
- the later stamped duplicate-lane work in result-block and scalar-forward collectors is also kept:
  - the cleaned direct pass trace now totals `277790 us` across `4462` visited functions with `18` changed
  - that is lower than the earlier `340626 us` candidate-filter trace and consistent with the saved full-artifact self-opt win
- the next performance slice should therefore target candidate-heavy query-summary and copy-link work inside the remaining outlier `Func 1673`, not more no-group screening or scratch-array cleanup alone
- the current kept-tree trace keeps the same diagnosis:
  - `Func 1673` remains the real tuple-pass bottleneck at `101831 us`
  - the heaviest `analysis:use-def` functions are different (`3612`, `1553`, `1525`), which matters for total pipeline wall time but not for the tuple pass timer that self-opt compare reports
- the full-artifact claims above and the reduced timing numbers are both fresh local measurements from this round

## Signoff Rule

Do not call tuple-opt done until all of these are true:

- the explicit pass remains green on reduced native Binaryen comparison
- the remaining exact-shape white-box failures are resolved or intentionally rebaselined
- the pass lands in the real Binaryen slot with feature-off coverage
- `moon build --target native --release src/cmd` followed by `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` is acceptable on current head
- the full debug-artifact compare stays canonically green enough to remain out of the active parity-blocker backlog

## Sources

- Archived note: [`../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md`](../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md)
- Follow-up health rerun: [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- Active backlog: [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Recent checkpoint record: [`../../../../../CHANGELOG.md`](../../../../../CHANGELOG.md)
- Implementation: [`../../../../../src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt)
