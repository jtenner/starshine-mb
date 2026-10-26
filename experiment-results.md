# DAE gain landing campaign — 2026-10-25

## DONE / OPEN

- DONE: verify the eight recorded GAIN source branches and preserve their original heads; prepare isolated item refs and the conditional item 4/8 integration repair.
- DONE: receive the explicit global lease and carry all 85 benchmark workload rows into this record, with primary numbers beside each landing status.
- DONE: reproduce the shared failure on current master through the exact full native gate entrypoint and isolate launcher-induced Binaryen version drift as **BATCH CONTEXT**.
- DONE: reproduce the separate missing `.tmp` parent failure and its 0/1 → 1/1 correction without source or fixture edits.
- DONE: corrected unwrapped master control is green: **15,487/15,487 native tests and 14/14 CI fuzz suites, 100,775 attempts**, seed `117504144017018061`. All eight native batches and every fuzz stage ran.
- DONE: item 1 landed as `642abea01b8a9348dc10f7dcf777bb879f060d14` after 15,488 native passes and 14 green CI fuzz suites; benchmark medians/RSS are in its landing row.
- OPEN: process **10, 11** sequentially under the corrected procedure; each needs its own green native/fuzz gates and benchmark-bearing merge checkpoint.
- DONE: item 3 landed as `050e89360e7b7be32aa78366f1d35e515b2916b2` after 15,491/15,491 native tests, 14/14 CI fuzz suites, 100,767 attempts, seed 117504304333854712; measured numbers and RSS remain in its landing row.
- DONE: item 4 landed as `eb0a9a2a9ce2278629cd717aca2e2e8e378f5d37` after 15,496/15,496 native tests, 14/14 CI fuzz suites, 100,764 attempts, seed 117504364697794335; measured numbers and RSS remain in its landing row.
- DONE: item 5 landed as `fb1e9cc9da182407813c01adbd3a58adcc2456ca` after 15,501/15,501 native tests, 14/14 CI fuzz suites, 100,779 attempts, seed 117504419113374922; measured numbers and RSS remain in its landing row.
- DONE: item 6 landed as `377c0bd58da20a00c43d1f0addf734a98bec0a26` after 15,504/15,504 native tests, 14/14 CI fuzz suites, 100,765 attempts, seed 117504469504920149; measured numbers and RSS remain in its landing row.
- DONE: item 8 landed as `d3f2307acb491895c28adb78bfb6e043e4a76697` after 15,512/15,512 native tests, 14/14 CI fuzz suites, 100,771 attempts, seed 117504530116234628; measured numbers and RSS remain in its landing row.
- OPEN: audit final outcomes, record final master and explicitly release the lease to the Starshine-versus-Binaryen comparison test.
- EXCLUDED: items 2 and 9 are NEUTRAL; item 12 remains outside this landing set for separate repair/remeasurement; item 7 is outside this assignment.

## Authority and evidence

Joshua directed on 2026-10-25: “If all those items are good make sure they land.”
This campaign lands on `master`. Joshua subsequently authorized **pushes to origin after each landing**, starting with item 1. Record each push result; never force a rejected push.
The overnight tender explicitly granted this campaign the single global lease after thread `mcp:1e53916f-ffaa-4261-8380-34a667d8082f` released it. Lease state: **HELD by this DAE landing campaign**. The Starshine-versus-Binaryen comparison test is next. The grant confirms Joshua accepts item 8's distinct-key peak RSS cost; no approval question remains for that item.

Measurement sources, read before preparation:

- `measure/dae-items-1259` at `b975e3970`: `experiment-results.md` and its `experiment-evidence/` files.
- `measure/dae-items-3468101112` at `c05b30a84`: `experiment-results.md` and its `experiment-evidence/` files.
- Both cohorts measured against `c9f8af8d3d465c39bcabf2cf29b837887d984efa`.

The supplied campaign state file `~/workspace/goals/slipstream-wasm-engine/hidden_files/landing-followup-state.md` is absent on this host. The connected file service reports no online device. The lease holder has been asked for the tender identity and state-file location. This missing input is recorded; it is not replaced with an inferred lease grant.

## Shared gate investigation — BATCH CONTEXT, corrected procedure

**Supersession:** v133 was verified only in the outer shell for the earlier full-gate attempts. The Bun launcher changed PATH; those were **not verified-v133 full-gate runs**. Their original logs and test counts remain below as investigation evidence, but their item-stop decisions and oracle attributions are superseded. No ITEM DEFECT was established. All eight items are reopened for the corrected gates.

### Master reproduction and isolated variable

- Exact full native entrypoint on unchanged master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929` reproduces the carried-guard fixture failure: **1,076/1,077 pass**, exit 1, first batch. Evidence: `investigation-master-full-native.{log,json}`. This supplements the earlier first-batch control; no later batch pass was claimed for the failing run.
- The isolated Moon invocation passes 1/1. Recording wrappers capture the **same 1,460-byte fixture** in isolated and batch invocations, SHA-256 `18983f673c2d51cfde833f4fd81126000894e4dbcda66f98943b7445072817c5`, with the same cwd and arguments apart from fresh temp filenames. Both lowering calls succeed when the wrapper invokes absolute verified v133. The trace is a controlled intervention, not a passive trace of historical failed child resolution.
- `bun` resolves through `/home/dev/.local/share/mise/shims/bun` → `/usr/local/bin/mise`. Its launch rebuilds PATH, removes the explicitly prepended installed-v133 directory and resolves TinyGo's `/home/dev/.local/share/mise/installs/tinygo/0.42.0/tinygo/bin/wasm-opt` (**version 116**). The same incoming PATH with absolute `process.execPath` (`.../bun/bin/bun.native`, ELF) preserves the selected v133. Exact incoming PATH, argv and outputs are retained in `/tmp/dae-gate-investigation/probe-provenance.json`.
- Causal counterfactual on the same captured fixture, fresh child processes and unchanged source: **absolute v133 → resolved v116 → absolute v133 yields exit 0 → 1 → 0**. The two v133 wasm output hashes are identical (`25b4fa9ce540ae2ff292810112b907d38f79ed091466b47bd76f8a7c16b4a4a8`). The v116 stderr matches the original failure. See `oracle-counterfactual.json` and adjacent stdout/stderr. Historical failed runs did not capture child executable identities; v116 attribution is supported by this reproduction and the matching error, not fabricated retrospective traces.
- Classification for the carried-guard failure: **BATCH CONTEXT — launcher-induced Binaryen version drift**. It occurs before Starshine receives the fixture. It is not evidence of a DAE item defect or invalid WAT under v133. No source or fixture was changed.

### Separate clean-worktree scratch precondition

- Forcing absolute v133 in the traced full master run clears batch 1: **1,077/1,077 pass**. Batch 2 then exposes an independent setup failure: the ignored `.tmp` parent is absent in the fresh worktree. The native test cannot create its child output directory.
- Controlled unchanged-source test `emit_gen_valid_batch_to_dir creates the output directory for selected modules`: absent parent **0/1 pass**, exit 2; after `mkdir -p .tmp`, **1/1 pass**, exit 0. Evidence: `investigation-master-tmp-absent` / `investigation-master-tmp-present` logs and JSON. This is a clean-checkout directory precondition, not a compiler source repair. TMPDIR alone would not create that relative parent.

### Corrected procedure and pending validation

1. Preserve the configured post-launch tool PATH, prepend the verified v133 bin directory, and invoke the captured **absolute Bun ELF**. Do not re-enter the mise/Bun package launcher for gate scripts.
2. Use a 64 MiB process stack, `RAYON_NUM_THREADS=1`, `TOKIO_WORKER_THREADS=1`, one Moon build worker and sequential 300-source-file batches. Create the already-ignored worktree `.tmp` parent first. Do not disable tests or fuzz stages.
3. Inside the actual Bun process, preflight resolved `wasm-opt`, version **133** and executable SHA-256 `8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`. Remove the trace-wrapper directory from final validation PATH. Source is clean current master; retain source tree, executable identities, PATH and limits.
4. Run the unchanged repository `runValidateTest` native entrypoint, then all CI native fuzz suites with a recorded seed and JSON report. The procedure wrapper is `/tmp/dae-gate-investigation/native-gate.ts`; it changes setup and checks tool identity, not source or test behavior. `corrected-path.txt`, `actual-bun.txt` and `corrected-master-process-state.json` retain the local launch identity.
5. Corrected unwrapped master validation is running as `corrected-master-native`, then `corrected-master-fuzz` only on native success. A first-batch success is not a full-suite success. After green master control, rerun the eight candidates sequentially with this same procedure and retain each native/fuzz count, source/build identity, benchmark medians/RSS, merge and checkpoint.

Astra independently assessed the causal evidence and agreed with the BATCH CONTEXT classification and corrected procedure, while requiring final unwrapped master validation and the present-parent control. Both limits are tracked here; the present-parent control is now green. The earlier static-invalid-fixture hypothesis is rejected by the captured v133 successes. Temperature, resource pressure, filename collisions and candidate semantics are not needed to explain this observed failure; no claim is made that all possible unrelated risks were exhaustively excluded.

The original DAE benchmark verdicts are not discarded or remeasured. Their pinned records are Starshine-versus-fixed-master measurements with explicit native executable identities, not Binaryen parity signoff. This gate correction does not relabel unverified oracle runs as v133.

## Selected items

All rows have verdict **GAIN**, with the limits below. Measured gains are historical paired evidence, not a new combined-build performance claim.

| Item | Exact source branch | Exact measured head | Verdict recap |
| --- | --- | --- | --- |
| 1 | `dae/item-01-block-liveness` | `8582c26a234d3fd77cb0770e7f755fb992b191f0` | HOT CLI -6.16% / -4.80%; raw controls and RSS broadly neutral; no general memory claim. |
| 5 | `dae/item-05-subtype-trees` | `d20dd9102639d92893f65468d80f26120a6ee403` | Direct dependency discovery -78.67% / -77.87%; measured pass-local gains; limited CLI benefit, RSS broadly neutral. |
| 3 | `dae/item-03-write-buckets` | `eb403d287218b0660865784be6a4cc749245ba13` | Sparse fallback -66.90%; dense fallback costs +2.69%; CLI gain not established. |
| 4 | `dae/item-04-group-base` | `28a5949d314bbad4078a0c8819c76def4f0e6f4f` | Relative lookup -86.47%; batch CLI neutral; non-batch dropped-reference/dae control costs +2.03%. |
| 6 | `dae/item-06-preflight-share` | `4192c02791efd685afc171c93d16a483ccbda698` | Late rejection -49.65%; successful local flow costs +3.76%; CLI neutral. |
| 8 | `dae/item-08-signature-keys` | `5a53e2a90deb275ae3a0adb675a001faaecbc306` | Runtime gain: distinct-wide CLI -4.34% / -5.03%, recursive direct index -63.36%. **Distinct-key direct peak RSS rises 6,744 → 8,816 KiB (+30.78%)**. This accepted trade remains explicit. |
| 10 | `dae/item-10-cleanup-context` | `913de7a89adb2aa1a0d471b5d8a49d06a3aa79af` | Direct cleanup -5.09% to -8.58%; CLI neutral; mixed-import optimizing pass timer costs +1.20%. |
| 11 | `dae/item-11-tag-count` | `4ab0acbd80f7620bd07e24cfe1572b175c6453e5` | Direct fold -38.32%; productive CLI neutral; unchanged-module many-tag dae2 CLI control costs +8.46%. |

No general allocation reduction, production code-size improvement, or controlled compile-time improvement is inferred from these records.

## Required benchmark evidence for every landing

- **DONE:** carry the pinned per-item benchmark tables below into the main landing record before any merge. The final consolidated report must also show each landed item's workload, control median, candidate median, paired percent change and recorded RSS, beside its gates and merge SHA. A landing without its numbers is incomplete.
- **OPEN:** attach the final suite/fuzz counts and merge SHA to each numbered item as it lands or is formally stopped. All benchmark rows below are existing DAE batch measurements; no new timing run is implied.
- Control is the fixed measurement master `c9f8af8d3d465c39bcabf2cf29b837887d984efa`. Each candidate is the exact measured source head in the Selected items table. The columns marked `master → candidate` give the control and candidate medians. Times are milliseconds; direct helper tables are milliseconds per call. Percentages are medians of matched-pair changes and must not be recalculated from separate cohort medians. Negative timing changes mean faster.
- RSS is peak process RSS in KiB, including setup, not pass-only live heap or allocations. Keep all recorded adverse controls. Item 8's **6,744 → 8,816 KiB (+30.78%)** distinct-key memory rise is accepted by Joshua and appears beside its runtime rows below; no approval question remains.

### Item 1 — measured numbers required in its landing record

Source: `measure/dae-items-1259` at `b975e3970c5995614c17f519b70c95f65e5d4f4a`, `experiment-results.md`, item 1.

Enclosing CLI/pass: ms; peak process RSS in KiB. CLI and pass timers are separate cohorts.

| Workload / pass | Untraced CLI master → candidate ms | Paired change | Same-build A/A | Pass timer master → candidate ms | Paired pass change | Peak RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| HOT wide / dae | 184.260 → 172.475 | -6.16% | +0.38% / -0.03% | 353.537 → 339.449 | -3.60% | 20,668 → 20,584 |
| HOT wide / dae-optimizing | 356.740 → 337.624 | -4.80% | -0.33% / +0.01% | 548.636 → 531.800 | -3.07% | 32,980 → 33,036 |
| Raw wide / dae | 113.046 → 114.061 | +1.04% | -2.47% / +0.11% | 270.879 → 274.772 | +0.13% | 17,632 → 17,500 |
| Raw wide / dae-optimizing | 243.517 → 243.406 | -0.19% | -0.06% / -0.49% | 425.101 → 425.900 | +0.08% | 32,876 → 32,956 |
| Tiny HOT / dae | 3.394 → 3.005 | -14.04% | -7.76% / +0.38% | 0.392 → 0.368 | -4.27% | 13,912 → 13,848 |
| Tiny HOT / dae-optimizing | 3.561 → 3.626 | +2.00% | -1.88% / -6.04% | 0.612 → 0.583 | -3.36% | 14,504 → 14,400 |


### Item 3 — measured numbers required in its landing record

Source: `measure/dae-items-3468101112` at `c05b30a8486b637af3d0a2e64337476181896233`, `experiment-results.md`, item 3.

Direct helper: ms per call; peak process RSS in KiB.

| Direct case | Master → candidate ms | Paired change | A/A master / candidate | Peak process RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: |
| dense | 0.482 → 0.495 | +2.69% | +0.44% / +0.49% | 8236.000 → 8220.000 |
| no-fallback | 0.007 → 0.004 | -38.13% | -0.39% / +1.95% | 6224.000 → 6196.000 |
| sparse | 0.169 → 0.056 | -66.90% | +0.81% / +5.83% | 6180.000 → 6212.000 |

Enclosing CLI/pass: ms; peak process RSS in KiB. CLI and pass timers are separate cohorts.

| Workload / pass | CLI master → candidate ms | Paired CLI change | CLI A/A master / candidate | Pass master → candidate ms | Paired pass change | Peak RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dense-control / dae2 | 4.642 → 4.317 | -5.20% | -5.38% / -7.39% | 0.726 → 0.722 | -1.51% | 13900.000 → 14020.000 |
| dense-control / dae2-optimizing | 4.798 → 5.400 | -0.18% | -16.24% / -8.31% | 1.722 → 1.739 | +1.40% | 16832.000 → 16760.000 |
| no-fallback / dae2 | 12.839 → 12.254 | -0.13% | -0.13% / -3.59% | 9.550 → 9.526 | -0.16% | 14484.000 → 14508.000 |
| no-fallback / dae2-optimizing | 14.884 → 15.532 | +1.59% | +0.28% / +0.25% | 11.895 → 11.843 | +0.29% | 15472.000 → 15604.000 |
| sparse-control / dae2 | 3.130 → 3.023 | -3.42% | -19.54% / -4.76% | 0.202 → 0.203 | +3.12% | 11848.000 → 11904.000 |
| sparse-control / dae2-optimizing | 7.307 → 7.335 | -1.47% | -0.52% / -1.19% | 4.288 → 4.388 | +1.22% | 16816.000 → 16776.000 |


### Item 4 — measured numbers required in its landing record

Source: `measure/dae-items-3468101112` at `c05b30a8486b637af3d0a2e64337476181896233`, `experiment-results.md`, item 4.

Direct helper: ms per call; peak process RSS in KiB.

| Direct case | Master → candidate ms | Paired change | A/A master / candidate | Peak process RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: |
| absolute | 1.380 → 1.387 | +0.51% | +0.13% / -0.05% | 5884.000 → 5884.000 |
| numeric | 0.341 → 0.342 | -0.36% | -0.75% / -1.08% | 5896.000 → 5872.000 |
| relative | 10.466 → 1.414 | -86.47% | +0.12% / -0.89% | 5848.000 → 5920.000 |

Enclosing CLI/pass: ms; peak process RSS in KiB. CLI and pass timers are separate cohorts.

| Workload / pass | CLI master → candidate ms | Paired CLI change | CLI A/A master / candidate | Pass master → candidate ms | Paired pass change | Peak RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dropped-numeric / dae | 31.228 → 31.183 | -0.54% | +1.53% / -1.32% | 29.266 → 29.372 | +1.08% | 13408.000 → 13432.000 |
| dropped-numeric / dae-optimizing | 84.803 → 84.186 | -0.60% | +1.04% / +0.41% | 98.633 → 97.994 | -0.65% | 22592.000 → 22548.000 |
| dropped-reference / dae | 31.124 → 31.684 | +2.03% | +0.84% / +0.11% | 29.472 → 29.487 | -0.22% | 13392.000 → 13620.000 |
| dropped-reference / dae-optimizing | 84.767 → 84.299 | -1.14% | +1.73% / -0.03% | 97.687 → 97.880 | -0.31% | 22628.000 → 22604.000 |
| unread-numeric / dae | 48.641 → 47.729 | -1.01% | +0.09% / +1.09% | 45.161 → 45.528 | +0.54% | 13656.000 → 13628.000 |
| unread-numeric / dae-optimizing | 53.344 → 53.419 | -0.18% | +0.51% / +0.08% | 58.302 → 58.084 | -0.89% | 15960.000 → 15864.000 |
| unread-reference / dae | 49.300 → 49.334 | +1.22% | +0.44% / +0.16% | 46.209 → 46.045 | -0.45% | 13716.000 → 13616.000 |
| unread-reference / dae-optimizing | 55.146 → 55.386 | +0.43% | -0.00% / -0.39% | 59.828 → 60.084 | +0.20% | 16052.000 → 15924.000 |
| dropped-batch-reference / dae | 31.362 → 31.814 | +2.86% | -0.33% / -2.02% | 26.697 → 26.809 | -0.11% | 13232.000 → 13140.000 |
| dropped-batch-reference / dae-optimizing | 1271.974 → 1264.762 | -0.60% | +0.03% / -2.80% | 1279.941 → 1276.613 | -0.26% | 24512.000 → 24512.000 |
| unread-batch-reference / dae | 351.293 → 351.467 | -0.42% | -1.61% / +0.56% | 347.584 → 344.091 | -1.00% | 15724.000 → 15696.000 |
| unread-batch-reference / dae-optimizing | 1597.101 → 1591.460 | -0.23% | +0.73% / -0.00% | 1592.572 → 1581.612 | -0.45% | 18128.000 → 18120.000 |


### Item 5 — measured numbers required in its landing record

Source: `measure/dae-items-1259` at `b975e3970c5995614c17f519b70c95f65e5d4f4a`, `experiment-results.md`, item 5.

Direct helper: ms per call; peak process RSS in KiB.

| Direct IR case | Master → candidate ms/call | Paired change | A/A master / candidate | Peak process RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: |
| Recursive GC + descriptors + continuations | 2.708 → 0.580 | -78.67% | +0.35% / +0.20% | 9,944 → 9,968 |
| Same graph + embedded definition | 2.654 → 0.585 | -77.87% | +0.15% / +0.04% | 9,992 → 9,996 |
| Unchanged admission gate | about 0.002 → 0.002 | -0.13% | -0.26% / -0.62% | 10,008 → 10,020 |

Enclosing CLI/pass: ms; peak process RSS in KiB. CLI and pass timers are separate cohorts.

| Workload / pass | CLI master → candidate ms | Paired CLI change | CLI A/A master / candidate | Pass master → candidate ms | Paired pass change | Peak RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Identity collapse / dae2 | 7.783 → 7.690 | -0.62% | +0.22% / -0.87% | 2.658 → 2.283 | -14.10% | 15,788 → 15,756 |
| Identity collapse / dae2-optimizing | 8.996 → 8.524 | -4.51% | -1.14% / +0.01% | 3.889 → 3.591 | -7.65% | 17,192 → 17,072 |
| Identity split / dae2 | 7.419 → 7.419 | -2.78% | -1.17% / -0.41% | 2.592 → 2.244 | -13.32% | 13,712 → 13,720 |
| Identity split / dae2-optimizing | 8.853 → 8.562 | -3.14% | -0.04% / +3.23% | 3.890 → 3.655 | -6.65% | 16,300 → 16,472 |
| Output-unchanged family / dae2 | 7.543 → 7.086 | -1.40% | -3.01% / -1.63% | 2.582 → 2.237 | -12.54% | 13,828 → 13,716 |
| Output-unchanged family / dae2-optimizing | 7.969 → 7.752 | -4.22% | -1.87% / +0.36% | 3.242 → 2.926 | -9.88% | 15,320 → 15,420 |
| Tiny collapse / dae2 | 3.285 → 3.494 | +4.23% | +0.62% / -10.57% | 0.313 → 0.330 | -10.57% | 13,720 → 13,628 |
| Tiny collapse / dae2-optimizing | 3.338 → 3.413 | +3.88% | -0.75% / -6.84% | 0.473 → 0.444 | -15.30% | 15,124 → 15,048 |


### Item 6 — measured numbers required in its landing record

Source: `measure/dae-items-3468101112` at `c05b30a8486b637af3d0a2e64337476181896233`, `experiment-results.md`, item 6.

Direct helper: ms per call; peak process RSS in KiB.

| Direct case | Master → candidate ms | Paired change | A/A master / candidate | Peak process RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: |
| flat-control | 0.013 → 0.011 | -16.22% | +1.71% / -0.76% | 7356.000 → 7376.000 |
| late-rejection | 0.023 → 0.012 | -49.65% | +1.35% / -0.10% | 7316.000 → 7432.000 |
| local-flow-success | 0.025 → 0.026 | +3.76% | +0.00% / +0.21% | 7348.000 → 7356.000 |
| qualified-rejected | 0.063 → 0.063 | -0.89% | +4.17% / +0.08% | 7372.000 → 7384.000 |

Enclosing CLI/pass: ms; peak process RSS in KiB. CLI and pass timers are separate cohorts.

| Workload / pass | CLI master → candidate ms | Paired CLI change | CLI A/A master / candidate | Pass master → candidate ms | Paired pass change | Peak RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| flat-control / dae2 | 5.463 → 5.298 | -0.77% | +0.37% / +3.49% | 1.509 → 1.501 | -1.96% | 14432.000 → 14400.000 |
| flat-control / dae2-optimizing | 5.568 → 5.572 | +0.18% | +1.74% / +5.67% | 1.720 → 1.656 | -2.89% | 15788.000 → 15812.000 |
| late-rejection / dae2 | 17.122 → 17.150 | -0.33% | +2.89% / -1.69% | 10.208 → 10.107 | -0.52% | 21324.000 → 21268.000 |
| late-rejection / dae2-optimizing | 20.927 → 21.029 | -2.04% | +0.70% / -1.84% | 15.682 → 15.518 | -0.87% | 23032.000 → 23008.000 |
| local-flow-success / dae2 | 6.639 → 6.422 | -1.83% | -1.43% / +1.14% | 2.510 → 2.521 | +0.40% | 14880.000 → 14932.000 |
| local-flow-success / dae2-optimizing | 7.367 → 7.377 | +1.75% | -2.88% / +0.06% | 3.430 → 3.366 | -1.63% | 17420.000 → 17480.000 |
| qualified-rejected / dae2 | 5.653 → 5.291 | -7.56% | -6.31% / -2.37% | 1.962 → 1.949 | +0.15% | 12720.000 → 12880.000 |
| qualified-rejected / dae2-optimizing | 10.463 → 10.329 | -1.18% | -0.11% / +2.95% | 7.343 → 7.309 | -2.00% | 15312.000 → 15356.000 |


### Item 8 — measured numbers required in its landing record

Source: `measure/dae-items-3468101112` at `c05b30a8486b637af3d0a2e64337476181896233`, `experiment-results.md`, item 8.

Direct helper: ms per call; peak process RSS in KiB.

| Direct case | Master → candidate ms | Paired change | A/A master / candidate | Peak process RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: |
| distinct-wide | 2.320 → 1.916 | -17.18% | -0.70% / -0.55% | 6744.000 → 8816.000 |
| equivalent-wide | 1.830 → 1.694 | -7.21% | -1.50% / +0.07% | 6752.000 → 6776.000 |
| recursive | 1.599 → 0.584 | -63.36% | +0.02% / -0.95% | 6760.000 → 6708.000 |
| small-scalar | 0.002 → 0.002 | -33.35% | +0.67% / -8.85% | 4668.000 → 4708.000 |

Enclosing CLI/pass: ms; peak process RSS in KiB. CLI and pass timers are separate cohorts.

| Workload / pass | CLI master → candidate ms | Paired CLI change | CLI A/A master / candidate | Pass master → candidate ms | Paired pass change | Peak RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| distinct-wide / dae | 58.888 → 55.983 | -4.34% | -0.28% / +0.47% | 53.082 → 50.854 | -3.73% | 15800.000 → 15660.000 |
| distinct-wide / dae-optimizing | 59.147 → 55.953 | -5.03% | +1.33% / +1.55% | 57.994 → 55.450 | -4.73% | 17108.000 → 16976.000 |
| equivalent-wide / dae | 54.149 → 53.321 | -1.69% | +0.92% / +0.42% | 48.568 → 47.260 | -2.53% | 15784.000 → 15684.000 |
| equivalent-wide / dae-optimizing | 54.059 → 52.921 | -1.58% | +1.18% / -0.14% | 53.810 → 52.207 | -2.42% | 16980.000 → 17048.000 |
| recursive / dae | 14.464 → 14.504 | -1.83% | +0.18% / +1.50% | 10.514 → 10.550 | +0.41% | 13664.000 → 13628.000 |
| recursive / dae-optimizing | 15.390 → 15.463 | +2.21% | -7.34% / -6.78% | 14.386 → 14.524 | +1.02% | 16064.000 → 16088.000 |
| small-scalar / dae | 4.702 → 4.866 | +2.26% | -0.24% / +0.75% | 1.791 → 1.726 | -3.25% | 13608.000 → 13644.000 |
| small-scalar / dae-optimizing | 6.102 → 6.267 | +1.53% | -13.14% / -10.96% | 4.778 → 4.776 | -0.04% | 15964.000 → 15944.000 |

**Accepted memory trade:** distinct-wide direct RSS rises 6,744 → 8,816 KiB, +30.78% paired (interval +29.22% to +32.21%). The distinct-wide CLI time gains and memory rise are one recorded verdict; neither is omitted.


### Item 10 — measured numbers required in its landing record

Source: `measure/dae-items-3468101112` at `c05b30a8486b637af3d0a2e64337476181896233`, `experiment-results.md`, item 10.

Direct helper: ms per call; peak process RSS in KiB.

| Direct case | Master → candidate ms | Paired change | A/A master / candidate | Peak process RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: |
| many-types-functions | 0.505 → 0.472 | -6.26% | -0.31% / +0.40% | 11456.000 → 11504.000 |
| mixed-imports | 0.508 → 0.483 | -5.09% | +1.86% / -2.19% | 11448.000 → 11464.000 |
| no-op-cleanup | 0.318 → 0.293 | -8.58% | +0.07% / +0.76% | 11456.000 → 11432.000 |

Enclosing CLI/pass: ms; peak process RSS in KiB. CLI and pass timers are separate cohorts.

| Workload / pass | CLI master → candidate ms | Paired CLI change | CLI A/A master / candidate | Pass master → candidate ms | Paired pass change | Peak RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| many-types-functions / dae2 | 6.223 → 6.227 | +2.60% | +1.57% / -13.73% | 0.809 → 0.810 | -1.88% | 13488.000 → 13448.000 |
| many-types-functions / dae2-optimizing | 15.041 → 14.904 | -1.02% | +0.56% / -2.60% | 12.432 → 12.372 | -0.23% | 19280.000 → 18976.000 |
| mixed-imports / dae2 | 6.344 → 6.215 | +1.00% | -2.42% / +2.21% | 0.824 → 0.801 | -1.12% | 13516.000 → 13500.000 |
| mixed-imports / dae2-optimizing | 14.966 → 14.757 | -1.15% | +0.81% / +0.38% | 12.415 → 12.600 | +1.20% | 18856.000 → 16916.000 |
| no-op-cleanup / dae2 | 5.976 → 6.123 | +2.17% | -3.08% / +5.06% | 0.788 → 0.805 | +0.88% | 13400.000 → 13384.000 |
| no-op-cleanup / dae2-optimizing | 7.280 → 7.220 | -2.15% | +2.39% / +3.79% | 2.194 → 2.159 | -0.60% | 15044.000 → 15012.000 |


### Item 11 — measured numbers required in its landing record

Source: `measure/dae-items-3468101112` at `c05b30a8486b637af3d0a2e64337476181896233`, `experiment-results.md`, item 11.

Direct helper: ms per call; peak process RSS in KiB.

| Direct case | Master → candidate ms | Paired change | A/A master / candidate | Peak process RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: |
| imported-only | 0.000 → 0.000 | -1.03% | -0.34% / +0.35% | 9344.000 → 9384.000 |
| many-imported-tags | 0.104 → 0.065 | -38.32% | -0.76% / -3.20% | 9376.000 → 9312.000 |
| tagless | 0.000 → 0.000 | +1.05% | -0.72% / +1.06% | 7320.000 → 7328.000 |

Enclosing CLI/pass: ms; peak process RSS in KiB. CLI and pass timers are separate cohorts.

| Workload / pass | CLI master → candidate ms | Paired CLI change | CLI A/A master / candidate | Pass master → candidate ms | Paired pass change | Peak RSS master → candidate KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| imported-only / dae2 | 3.984 → 4.557 | +9.42% | +12.86% / -1.60% | 0.304 → 0.304 | +0.00% | 13788.000 → 13876.000 |
| imported-only / dae2-optimizing | 5.214 → 5.460 | +4.76% | -1.75% / +2.69% | 1.484 → 1.477 | -3.12% | 16560.000 → 16672.000 |
| many-imported-tags / dae2 | 5.498 → 5.970 | +8.46% | +0.43% / +2.24% | 0.327 → 0.328 | -0.31% | 13812.000 → 13768.000 |
| many-imported-tags / dae2-optimizing | 5.654 → 5.469 | +0.98% | +1.74% / +3.63% | 1.465 → 1.451 | +0.07% | 16692.000 → 16456.000 |
| tagless / dae2 | 3.547 → 3.507 | -0.73% | +0.57% / -4.53% | 0.235 → 0.236 | +2.18% | 11416.000 → 11348.000 |
| tagless / dae2-optimizing | 3.865 → 3.896 | -0.42% | +0.75% / -0.09% | 0.706 → 0.693 | -3.82% | 12976.000 → 12992.000 |
| many-imported-tags-productive / dae2 | 5.573 → 5.171 | -1.46% | +7.07% / -12.45% | 1.031 → 1.041 | -4.59% | 14716.000 → 14824.000 |
| many-imported-tags-productive / dae2-optimizing | 6.491 → 6.416 | +0.11% | -10.83% / +5.65% | 2.051 → 2.085 | -4.44% | 16704.000 → 16852.000 |

## Preparation and conflicts

Original source branches remain unchanged. Each staging ref rebases only the item's commits from base `fc9a63546333dd320ae6c862a5620c6d8e62e02d` onto the captured master. Item 8 has three commits; each other selected item has two. Report-only worker commits are excluded from item refs.

- Items 1 and 10 conflict only in `docs/wiki/log.md` when rebased on captured master. The conflicts were reported immediately and saved under `/tmp/dae-landing-prep-items-1-5/` and `/tmp/dae-landing-prep-items-10-11-20261025T210728Z/`. Resolution keeps both independent dated log entries without meaning changes.
- Items 3, 4, 5, 6, 8, and 11 rebase cleanly.
- Item 4 and item 8 require integration: item 8's structural lookup supersedes the active rendered lookup improved by item 4. Its structural lookup must use item 4's checked group-base resolver; four index tests must probe with structural keys. Both sets of bounds, ownership, first-representative and dispatcher coverage must remain.
- The combined 4/8 staging merge also conflicts in the DAE strategy, wiki index, and wiki log. Both independent documentation entries are retained. Evidence is saved under `/tmp/dae-landing-gates-20261025/`.

## Staging refs and worker records

| Item | Isolated staging branch | Rebased head |
| --- | --- | --- |
| 1 | `landing/dae-item-01-prep` | `523b88859eb115a2fe9ce517124e6e6d42693262` |
| 5 | `landing/dae-item-05-prep` | `e1feac2cf7a1fb862eaff98b98dbefa5254904d6` |
| 3 | `landing/dae-item-03-prep` | `b1de596bdccff17c01cf61400252f66c2799f5e2` |
| 4 | `landing/dae-item-04-prep` | `8d57edad34ff20d8b0910cc591123af03aada8a9` |
| 6 | `landing/dae-item-06-prep` | `93c92ea61ad33517e6a3c1a94ce96c81977721e2` |
| 8 | `landing/dae-item-08-prep` | `377a6b035330e995465fbb32c6ed61477455e768` |
| 10 | `landing/dae-item-10-prep` | `d26d7fe5444ca582ba913d71cd36d8ceb354a756` |
| 11 | `landing/dae-item-11-prep` | `482d8c07e8528969da72dfe701eaf8253ceab007` |

Report-only preparation commits (excluded from all item staging refs):

- Items 1/5: `1d5f704dbc4411364f435cc3a5b34b4fb0abd952`, file `dae-landing-prep-items-1-5.md`.
- Items 3/4: `9c0f1e13e3cbef0218851bb54804e5c676d0631d`, file `dae-landing-prep-items-3-4.md`.
- Items 6/8: `9fd5657b993a5d5ecac92bd157b627b0e5b0bccc`, file `dae-landing-prep-items-6-8.md`.
- Items 10/11: `c142f20255c117fcccbc49ac964016492148358f`, file `dae-landing-prep-items-10-11.md`.

The worker records contain exact original commit ranges, changed files, historical qualification counts, conflict evidence and later native test selections. All original production/test blobs match after isolated rebase; item 1/10 differences are confined to the recorded wiki-log merge. All eight item diffs have no public `.mbti` changes. All four worker tasks completed with clean worktrees and no test, build, fuzz or measurement run.

## Item 4/8 integration handoff

- Preparation branch `landing/dae-04-08-integration` combines only the isolated item 4/8 candidates on captured master. The preparation merge is `a9d9d9ff340043c510b1311ef35254394e6e2a90`; it is **not** an item landing and must not be merged to master as a substitute for sequential gates.
- Required repair: `7d7a317a37be4b64f5b0124e35cbfeecc24c0bb1`. Apply this commit to item 8's later gate candidate **if item 4 has landed**. It ports checked group-base resolution into the structural lookup, updates four test probes, and adds three active-index invalid-reference cases. It also reconciles the completed measurement records and active backlog.
- Documentation/comment review corrections: `3e407c1791413c213acb908d8184ed75c2b8fe8d`. Include this with the repair. If item 4 fails its landing gate, item 8 must be prepared and gated independently; do not blindly apply a repair that depends on item 4's helper.
- TDD evidence: the original combined compile returns exit 1 with four String-vs-structural-key errors; the repaired focused release WasmGC run passes **21/21**, plus the separate existing flattened-recursive-group regression **1/1**. These are preparation checks, not native/full/fuzz gate counts. Logs and exact source hashes: `/tmp/dae-landing-gates-20261025/integration-focused-results.json`.
- Scoped independent Claude Opus review returned an assessment with no confirmed source defect. Verified low documentation/comment findings were corrected. Full stdout, stderr, exit status, brief, source patches and manifest are under `/tmp/dae-landing-review-20261025/`. The first attempt used the wrong packet path and was interrupted; only the corrected second attempt is used. The review did not inspect the entire DAE/shared-object implementation, `.mbti` files or pinned measurement records. It ran no commands, tests, builds or measurements.
- Review limits remain: combined runtime/RSS/allocations/compile time are unmeasured; the full native gate must include make-shared-objects. Existing rendered-key collision semantics and unnecessary key construction without an index are separate issues. No unrelated behavior change was added.
- Only formatting was removed from six unrelated baseline source files after `moon fmt`; no unrelated source change remains. Both preparation worktrees are clean after checkpoint commits. No public API change was introduced.
- A gate runner is prepared at `/tmp/dae-landing-gates-20261025/run-stage.py`. It refuses to start without a saved tender grant. It has only been syntax-checked; no full suite, native build, fuzz round or performance process has run in this campaign.

## Review policy correction — 2026-10-25

Joshua's steering removes Claude reviews from this campaign. Any future design
or judgment review uses `gpt-6-astra`. Muse performs its own reviews; this
orchestrator does not launch one. The local Claude process recorded above had
already completed in this landing thread before the correction arrived. It had
no separate thread. Its record is historical evidence, not a required landing
step. No further Claude review will be launched. The remaining workflow is the
eight prepared items followed by an explicit tender grant and sequential gates.

## Gate and landing contract

No full suite or fuzz round starts before the tender grants the lease by message.
Focused preparation checks may run off lease. Each item is gated on top of the then-current local master, one item at a time, with all earlier accepted items included.

The required landing gates are the complete native suite, using bounded sequential source-file batches, plus all repository fuzz suites under the CI profile. Exact commands, build identity, exit status and suite/case counts will be recorded per item. Additional pass comparisons must use a fresh native binary and verified Binaryen v133; no parity completion is inferred from measurement records or ordinary unit tests.

Only a fully green item can merge to local master. Each successful merge must be followed by a checkpoint commit that names its merge SHA. A failed item remains unlanded with the exact failure recorded; the next item can then proceed. No failed gate is waived.

## Landing status

All timings here are the original paired measurements, with the full workload/control tables above. Direct helper timings are per call. Each accepted row must retain these numbers beside its gate and merge result.

| Item | Workload: control → candidate median and paired change | Peak RSS control → candidate KiB | Native suite | Fuzz suites | Master merge |
| --- | --- | --- | --- | --- | --- |
| 1 | HOT wide / dae: **184.260 → 172.475 ms (-6.16%)** | 20,668 → 20,584 | PASS 15,488/15,488; 8 batches | PASS 14/14; 100,772 attempts; seed `117504205198248316` | LANDED `642abea01b8a9348dc10f7dcf777bb879f060d14`; origin push PASS at `6d5d84684ad2ca1d2c3e049a95a6f924552b66a6` |
| 3 | sparse: **0.169 → 0.056 ms (-66.90%)** | 6180.000 → 6212.000 | PASS 15,491/15,491; 8 batches | PASS 14/14; 100,767 attempts; seed `117504304333854712` | LANDED `050e89360e7b7be32aa78366f1d35e515b2916b2`; origin push PASS (exit 0) at `050e89360e7b7be32aa78366f1d35e515b2916b2`; no force |
| 4 | relative: **10.466 → 1.414 ms (-86.47%)** | 5848.000 → 5920.000 | PASS 15,496/15,496; 8 batches | PASS 14/14; 100,764 attempts; seed `117504364697794335` | LANDED `eb0a9a2a9ce2278629cd717aca2e2e8e378f5d37`; origin push PASS (exit 0) at `eb0a9a2a9ce2278629cd717aca2e2e8e378f5d37`; no force |
| 5 | Recursive GC + descriptors + continuations: **2.708 → 0.580 ms (-78.67%)** | 9,944 → 9,968 | PASS 15,501/15,501; 8 batches | PASS 14/14; 100,779 attempts; seed `117504419113374922` | LANDED `fb1e9cc9da182407813c01adbd3a58adcc2456ca`; origin push PASS (exit 0) at `fb1e9cc9da182407813c01adbd3a58adcc2456ca`; no force |
| 6 | late-rejection: **0.023 → 0.012 ms (-49.65%)** | 7316.000 → 7432.000 | PASS 15,504/15,504; 8 batches | PASS 14/14; 100,765 attempts; seed `117504469504920149` | LANDED `377c0bd58da20a00c43d1f0addf734a98bec0a26`; origin push PASS (exit 0) at `377c0bd58da20a00c43d1f0addf734a98bec0a26`; no force |
| 8 | distinct-wide: **2.320 → 1.916 ms (-17.18%)**; CLI distinct-wide/dae **58.888 → 55.983 ms (-4.34%)**, optimizing **59.147 → 55.953 ms (-5.03%)** | 6744.000 → 8816.000 **(+30.78%, accepted)**; CLI 15,800 → 15,660 / 17,108 → 16,976 | PASS 15,512/15,512; 8 batches | PASS 14/14; 100,771 attempts; seed `117504530116234628` | LANDED `d3f2307acb491895c28adb78bfb6e043e4a76697`; origin push PASS (exit 0) at `d3f2307acb491895c28adb78bfb6e043e4a76697`; no force |
| 10 | many-types-functions: **0.505 → 0.472 ms (-6.26%)** | 11456.000 → 11504.000 | Corrected native gate pending; prior procedure superseded | Corrected CI fuzz pending | Pending corrected qualification; no merge |
| 11 | many-imported-tags: **0.104 → 0.065 ms (-38.32%)** | 9376.000 → 9312.000 | Corrected native gate pending; prior procedure superseded | Corrected CI fuzz pending | Pending corrected qualification; no merge |

Latest verified local master code merge: `d3f2307acb491895c28adb78bfb6e043e4a76697`; its documentation checkpoint follows.

The lease starts from the four round-2 landings recorded at `01dc357d4`, `fdae275a1`, `3a31c388f`, and `1f67ff580`. Fix 1 was formally stopped by the previous campaign. All DAE candidates must include this new base before gating.


## Item 1 gate attempt

- Rebased `landing/dae-item-01-prep` onto current master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929` without conflict. Candidate `gate/dae-item-01` is `14f954374bafefac6fd68ae3bd5b89aa25cd5b3d`.
- Full native suite started under the explicit lease, using the repository's bounded sequential source selections with one build worker. Native CI fuzz follows only if that suite passes. Evidence: `/tmp/dae-landing-gates-20261025/01-native.{log,json}` and `01-fuzz.{log,json}`.
- No master merge or push has occurred.

- Initial native invocation exited 1 before any test ran: MoonBit `v0.10.15+943464bfa` reported `Stack overflow` during `moonc link-core` for the command white-box test driver. Zero test results; fuzz was not started. Exact original log/status are retained as `01-native-initial-stack-overflow.{log,json}`.
- Setup retry uses a 64 MiB process stack and process-local PATH selecting verified Binaryen 133 at `/home/dev/.local/share/mise/installs/github-web-assembly-binaryen/ersion_133/bin/wasm-opt`. The default system executable is version 116 and is not used for the corrected gate. No compiler source, test, global tool setting or candidate commit was changed.

### Item 1 — NOT LANDED; formally stopped

- Source `dae/item-01-block-liveness` at `8582c26a234d3fd77cb0770e7f755fb992b191f0`; candidate `14f954374bafefac6fd68ae3bd5b89aa25cd5b3d`; master base `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- Verdict remains GAIN. HOT-wide/dae CLI median **184.260 → 172.475 ms (-6.16% paired)**, RSS **20,668 → 20,584 KiB**; optimizing **356.740 → 337.624 ms (-4.80%)**, RSS **32,980 → 33,036 KiB**. All six original workload rows and limits are carried above.
- Corrected full native invocation exits 1 in the first 300-file batch: **1,077 total, 1,076 passed, 1 failed**. Remaining batches were not reached. Failure: `src/cmd/cmd_wbtest.mbt:7553`, `run_cmd_with_adapter keeps lowered remove-unused-brs carried guard branches valid`, assertion at `:7612–7614`: `expected carried guard wrapper fixture lowering success, got failed to lower wat fixture via wasm-opt`. Verified Binaryen 133 reports `break type must be a subtype of the target block type` while lowering its WAT fixture. The optimizer test cannot proceed past fixture construction.
- No CI fuzz suite ran (0 suites); native failure stops the gate chain. No merge commit exists for this item. No test or fixture is weakened or waived. Candidate remains available on `gate/dae-item-01`.
- This test and its native fixture-lowering helper are unchanged by item 1. A focused current-master control is next to distinguish the shared baseline/tooling problem from this item; this does not reopen the stopped candidate.

- Current-master control `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929` passes the same isolated native test **1/1**, exit 0 (`01-master-control.{log,json}`). Thus an unchanged shared baseline failure is **not established**. The candidate failed in full-batch context; its cause remains unclassified. Item 1 stays formally stopped and is not carried into item 3. No semantic defect in the DAE change is inferred solely from this fixture failure.


## Item 3 gate attempt

- Rebased `landing/dae-item-03-prep` onto unchanged master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`. Candidate `gate/dae-item-03`: `fc971e058571b28c6f77bef96a97405235f4bcf4`.
- A wiki-log conflict in the first test commit was reported immediately and preserved under `/tmp/dae-landing-gates-20261025/03-rebase-conflict/`; both independent atomic and DAE2 ownership entries remain. No production conflict was resolved.
- Native gate uses the corrected 64 MiB stack and verified Binaryen 133 PATH. CI native fuzz runs only if the complete native suite passes. Item 1 is not included.

### Item 3 — NOT LANDED; formally stopped

- Source `dae/item-03-write-buckets` at `eb403d287218b0660865784be6a4cc749245ba13`; candidate `fc971e058571b28c6f77bef96a97405235f4bcf4`; base remains `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- GAIN: sparse direct fallback **0.169 → 0.056 ms/call (-66.90%)**, RSS **6,180 → 6,212 KiB**. Dense direct fallback costs **0.482 → 0.495 ms (+2.69%)**, RSS **8,236 → 8,220 KiB**. All original rows remain above; CLI gains were not established.
- Full native gate exits 1 in its first bounded batch: **1,077 total, 1,076 passed, 1 failed**. The same `cmd_wbtest.mbt:7553` carried-guard fixture-lowering test fails at `:7612–7614`; verified Binaryen 133 rejects its fixture. Evidence: `03-native.{log,json}`. Later native batches and CI fuzz were not reached (**0 fuzz suites**).
- No test was changed or waived. No master merge exists. Candidate remains on `gate/dae-item-03`. The isolated master fixture control previously passed; failure attribution remains full-batch native context, not a proven semantic defect in this item.


## Item 4 gate attempt

- Candidate `gate/dae-item-04`: `2a9e905e31c1ceb15beb6caaa0a9c2e4d27bf146`, rebased from the isolated prep ref onto unchanged master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- Wiki-log conflict reported and saved under `/tmp/dae-landing-gates-20261025/04-rebase-conflict/`; both independent entries retained. No production-source conflict.
- Full native suite starts under the lease; CI native fuzz follows only on success. Stopped items 1 and 3 are excluded.

### Item 4 — NOT LANDED; formally stopped

- Source `dae/item-04-group-base` at `28a5949d314bbad4078a0c8819c76def4f0e6f4f`; candidate `2a9e905e31c1ceb15beb6caaa0a9c2e4d27bf146`; base remains `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- GAIN: direct relative-reference lookup **10.466 → 1.414 ms/call (-86.47%)**, RSS **5,848 → 5,920 KiB**. Absolute/numeric and batch CLI controls are neutral; non-batch dropped-reference/dae costs +2.03%. All original control/candidate medians and RSS rows remain above.
- Full native gate exits 1 in its first bounded batch: **1,077 total, 1,076 passed, 1 failed**, at the same carried-guard fixture-lowering test `cmd_wbtest.mbt:7553`, assertion `:7612–7614`, before optimization of that fixture. Evidence: `04-native.{log,json}`. Remaining native batches and CI fuzz are not reached (**0 fuzz suites**).
- No failed test is waived and no merge exists. Candidate remains `gate/dae-item-04`.
- Item 4 is absent from master, so the conditional item 4/8 integration repair is **not applicable** to item 8's later standalone gate. Item 8 keeps its exact standalone structural lookup and original tests; it does not inherit this stopped item or its typed-key test probes.


## Item 5 gate attempt

- Candidate `gate/dae-item-05`: `32d66fef903915446a06ff030e646b80dabfdb4b`, rebased from the isolated prep ref onto unchanged master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- Conflicts in the DAE2 implementation page and wiki log were reported and saved under `/tmp/dae-landing-gates-20261025/05-rebase-conflict/`. The dependency visitor text remains under its existing identity section, followed by the complete host-type section; both log entries and all frontmatter citations remain. No production-source resolution.
- Full native gate is running under the corrected setup; CI native fuzz follows only if it is green. All earlier stopped items are excluded.

### Item 5 — NOT LANDED; formally stopped

- Source `dae/item-05-subtype-trees` at `d20dd9102639d92893f65468d80f26120a6ee403`; candidate `32d66fef903915446a06ff030e646b80dabfdb4b`; base remains `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- GAIN: recursive GC/descriptor/continuation dependency discovery **2.708 → 0.580 ms/call (-78.67%)**, RSS **9,944 → 9,968 KiB**; embedded-definition control **2.654 → 0.585 ms (-77.87%)**, RSS **9,992 → 9,996 KiB**. Enclosing pass-local gains and limited CLI evidence remain in all eleven original rows above.
- Full native gate exits 1 in the first bounded batch: **1,078 total, 1,077 passed, 1 failed**, again at `cmd_wbtest.mbt:7553`, carried-guard fixture-lowering assertion `:7612–7614`. Evidence: `05-native.{log,json}`. Remaining native batches and CI fuzz were not reached (**0 fuzz suites**).
- Candidate remains on `gate/dae-item-05`; no failed test is waived, no earlier stopped item is included, and no master merge exists.


## Item 6 gate attempt

- Candidate `gate/dae-item-06`: `b84ec85c0c0d8c81b61ed6474396ba23cc239147`, rebased onto unchanged master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- Wiki-log conflict reported and saved under `/tmp/dae-landing-gates-20261025/06-rebase-conflict/`; both independent entries retained. Implementation-page merge reviewed; no production-source conflict.
- Native suite then CI native fuzz, only on success. No earlier stopped item is included.

### Item 6 — NOT LANDED; formally stopped

- Source `dae/item-06-preflight-share` at `4192c02791efd685afc171c93d16a483ccbda698`; candidate `b84ec85c0c0d8c81b61ed6474396ba23cc239147`; base remains `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- GAIN: direct late rejection **0.023 → 0.012 ms/call (-49.65%)**, RSS **7,316 → 7,432 KiB**. Successful local flow costs **0.025 → 0.026 ms (+3.76%)**, RSS **7,348 → 7,356 KiB**; CLI evidence is neutral. All original rows remain above.
- Full native gate exits 1 in its first bounded batch: **1,077 total, 1,076 passed, 1 failed**, at the same `cmd_wbtest.mbt:7553` fixture-lowering test and `:7612–7614` assertion. Evidence: `06-native.{log,json}`. No later native batch or CI fuzz is reached (**0 fuzz suites**).
- No merge exists and no failed test is waived. Candidate remains on `gate/dae-item-06`.
- After five independently stopped candidates, an identical first-batch current-master control is next. The isolated master test already passed; a batch control is needed before calling this a shared baseline failure.

## Shared native baseline control — confirmed batch-context failure

- Current master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929` was tested with the **identical first 300-source-file selection**, verified Binaryen 133 PATH, 64 MiB stack, one build worker and sequential test execution. This is a bounded control, not a complete full-master-suite claim.
- Result: **1,077 total, 1,076 passed, 1 failed**, exit 1, at the same carried-guard WAT fixture-lowering assertion (`cmd_wbtest.mbt:7553`, `:7612–7614`). Exact evidence: `master-native-batch-control.{log,json}` and `master-native-batch-files.json`.
- The isolated master test passes 1/1, but the full first-batch context fails. This establishes a **shared native baseline gate failure in batch context**, rather than evidence that five unrelated DAE optimizations each introduced the same fixture defect. The exact cause remains unresolved.
- This control supersedes the earlier uncertainty about whether current master also fails in batch context. No test is removed, bypassed or weakened. The remaining items will still be processed one at a time with the required gate chain; a failed native gate prevents its fuzz and merge.


## Item 8 gate attempt

- Standalone candidate `gate/dae-item-08`: `1dbaf882b1523a22c414ca80076c446c6fa39b6e`, all three item commits rebased onto unchanged master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`. The conditional 4/8 integration repair is excluded because item 4 did not land.
- Wiki-log conflict reported and saved under `/tmp/dae-landing-gates-20261025/08-rebase-conflict/`; both independent entries retained. No production-source conflict.
- Full native then CI native fuzz on success. Joshua's accepted memory trade is fixed: distinct-wide direct **2.320 → 1.916 ms (-17.18%)**, RSS **6,744 → 8,816 KiB (+30.78%)**; distinct-wide CLI **58.888 → 55.983 ms (-4.34%)** / **59.147 → 55.953 ms (-5.03%)**. This gate tests correctness/integration, not whether that accepted trade is acceptable.

### Item 8 — NOT LANDED; formally stopped on the native gate

- Source `dae/item-08-signature-keys` at `5a53e2a90deb275ae3a0adb675a001faaecbc306`; standalone candidate `1dbaf882b1523a22c414ca80076c446c6fa39b6e`; unchanged base `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`. No item 4 or conditional integration repair is included.
- Accepted GAIN: distinct-wide/dae CLI **58.888 → 55.983 ms (-4.34%)**, RSS **15,800 → 15,660 KiB**; optimizing CLI **59.147 → 55.953 ms (-5.03%)**, RSS **17,108 → 16,976 KiB**. Direct distinct-wide index **2.320 → 1.916 ms/call (-17.18%)** with RSS **6,744 → 8,816 KiB (+30.78%, accepted)**; direct recursive index **1.599 → 0.584 ms (-63.36%)**, RSS **6,760 → 6,708 KiB**. All twelve original rows remain above. Joshua's memory acceptance is not reopened.
- Full native gate exits 1 in the first bounded batch: **1,076 total, 1,075 passed, 1 failed**, at the shared carried-guard WAT fixture-lowering test (`cmd_wbtest.mbt:7553`, assertion `:7612–7614`). Evidence: `08-native.{log,json}`. Current master reproduces this failure in the same batch context. Remaining native batches and CI fuzz are not reached (**0 fuzz suites**).
- Stopped solely because the required native gate is red, **not because of the accepted RSS trade**. No failure is waived and no master merge exists. Candidate remains on `gate/dae-item-08`.


## Item 10 gate attempt

- Candidate `gate/dae-item-10`: `4806d224bd18bbe0111fb6bb24c07dd7f759ff2b`, rebased onto unchanged master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- Wiki-log conflict reported and saved under `/tmp/dae-landing-gates-20261025/10-rebase-conflict/`; both entries remain. Automatic merge of `dead_argument_elimination2_types.mbt` was inspected: only the measured cleanup parameter-table removal and borrowed context lookups differ from current master; its host-type repair remains. No production conflict was resolved by hand.
- Full native then CI native fuzz only on success; no stopped candidate is included.

### Item 10 — NOT LANDED; formally stopped

- Source `dae/item-10-cleanup-context` at `913de7a89adb2aa1a0d471b5d8a49d06a3aa79af`; candidate `4806d224bd18bbe0111fb6bb24c07dd7f759ff2b`; unchanged base `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
- GAIN: many-types/functions direct cleanup **0.505 → 0.472 ms/call (-6.26%)**, RSS **11,456 → 11,504 KiB**; mixed imports **0.508 → 0.483 ms (-5.09%)**, RSS **11,448 → 11,464 KiB**; no-op cleanup **0.318 → 0.293 ms (-8.58%)**, RSS **11,456 → 11,432 KiB**. Full CLI/pass rows above retain the +1.20% mixed-import optimizing pass-timer cost and neutral CLI evidence.
- Full native gate exits 1 in its first bounded batch: **1,077 total, 1,076 passed, 1 failed**, at the master-reproduced fixture-lowering test `cmd_wbtest.mbt:7553`, assertion `:7612–7614`. Evidence: `10-native.{log,json}`. Remaining native batches and CI fuzz were not reached (**0 fuzz suites**).
- No failed test is waived and no merge exists. Candidate remains on `gate/dae-item-10`.


## Shared native gate investigation — active, 2026-10-25

Joshua directed investigation before further landing gates. Item 6 had already
finished (1,076/1,077 passed, shared fixture failure); items 8 and 10 also
finished with that failure before this instruction arrived. Item 11's gate has
**not started**. Its in-progress documentation-only rebase was saved and aborted
without source changes; the gate worktree is back on clean current master.

- OPEN: run current master through the exact full native gate entrypoint,
  supplementing the existing identical first-batch reproduction and isolated
  1/1 pass.
- OPEN: isolate the variable that flips the fixture result: temp/cwd state,
  ordering or fixture pollution, resource pressure, Binaryen/path resolution,
  or prior-item state.
- OPEN: classify with master reproduction as **BATCH CONTEXT** or a proven
  specific **ITEM DEFECT**, and record the mechanism and corrected procedure.
- OPEN: if procedure/environment is the cause, correct it, rerun stopped items
  sequentially under the corrected procedure, and continue remaining items.
  No prior stop is treated as a permanent item defect without this evidence.
- All landing and later-item gates are paused during this investigation. The
  explicit global lease remains held. Benchmark numbers remain attached to
  every item record; item 8's memory trade remains accepted.


### Corrected master control — native full suite green

The unwrapped absolute-Bun procedure on unchanged master
`1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929` passes **15,487/15,487 native tests**,
exit 0, in all eight sequential batches: 1,077 / 1,335 / 1,208 / 955 / 2,789 /
3,967 / 2,017 / 2,139. No default test or stage was disabled. The original
carried-guard fixture and the directory-creation test pass without source edits.
Exact stage: `corrected-master-native.{log,json}`; effective source/tool/limit
state is also retained in `corrected-master-process-state.json`.

The following CI native fuzz stage is running under the same corrected PATH
and absolute Bun ELF as `corrected-master-fuzz`, with its resolved seed and
JSON report retained. No candidate retry has started yet. A complete master
control requires this stage to pass too.


### Corrected master control — complete and green

- Native: **15,487/15,487 passed**, exit 0, all eight batches.
- CI native fuzz: **14/14 suites passed**, **100,775 attempts**, exit 0, seed **117504144017018061**. `corrected-master-fuzz-summary.json` lists each suite's attempts; the complete report and raw log remain retained.
- Source remains clean master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`. The command white-box executable hash is still `bf52b88c585e41c8cb39a35a085c5c4883123baeaa6fda3dfb760989edf0b4a3`, matching the master investigation artifact; no test binary or fixture repair was required to flip the result.
- Actual Bun ELF, resolved v133 executable/hash, configured PATH, 64 MiB stack, one-worker limits, source tree and native artifact hashes are recorded. Trace wrappers are absent. The new full gate is the same bounded procedure with corrected tool resolution and scratch setup, not a reduced replacement.
- The BATCH CONTEXT investigation is complete for the observed failure. All prior item stops are superseded, and the sequential corrected landing run now starts at item 1.


## Corrected sequential landing run

### Item 1 — corrected qualification active

Source `dae/item-01-block-liveness` at
`8582c26a234d3fd77cb0770e7f755fb992b191f0`; clean candidate
`gate/dae-corrected-01` at `14f954374bafefac6fd68ae3bd5b89aa25cd5b3d`,
including current master `1f67ff5800b3b9cdadfbe0b607b0e5d36c40e929`.
No public `.mbti` diff or new source resolution. Corrected full native gate
`corrected-01-native` runs first, followed by all CI native fuzz suites as
`corrected-01-fuzz` only on success. The benchmark-bearing status row retains
HOT-wide CLI **184.260 → 172.475 ms (-6.16%)**, RSS **20,668 → 20,584 KiB**;
optimizing **356.740 → 337.624 ms (-4.80%)**, RSS **32,980 → 33,036 KiB**.
No merge or post-correction failure is claimed yet.


### Item 1 — LANDED under the corrected procedure

- Source `dae/item-01-block-liveness` at `8582c26a234d3fd77cb0770e7f755fb992b191f0`; gated candidate `14f954374bafefac6fd68ae3bd5b89aa25cd5b3d`; local-master merge **`642abea01b8a9348dc10f7dcf777bb879f060d14`**. The merge tree equals the gated candidate tree before its docs-only checkpoint. No push occurred.
- GAIN, HOT-wide/dae CLI: **184.260 → 172.475 ms (-6.16%)**, RSS **20,668 → 20,584 KiB**. HOT-wide/dae-optimizing: **356.740 → 337.624 ms (-4.80%)**, RSS **32,980 → 33,036 KiB**. Raw controls remain near noise, with the recorded +1.04% raw/dae control uncertainty; tiny CLI controls are noisy. No general memory/allocation gain is claimed. All six frozen workload rows remain above.
- Corrected full native suite: **15,488/15,488 pass**, exit 0, all eight batches. CI native fuzz: **14/14 suites pass, 100,772 attempts**, exit 0, seed **117504205198248316**. Actual Bun/133 identity, source tree and native hashes are retained in `corrected-01-native.json` / `corrected-01-fuzz.json`; full fuzz report is adjacent.
- The earlier item 1 stop is superseded by this corrected complete run. No test/fixture was weakened, no stage disabled, and no public API changed. Pass-comparison renewal belongs to the next leased lane.


### Item 3 — corrected qualification active

Candidate `gate/dae-corrected-03` at `5c8260aa8e84d8c5fd0c883e32addcb826800c95` rebases only the two item 3 commits onto current master checkpoint `6d5d84684ad2ca1d2c3e049a95a6f924552b66a6`, which includes landed item 1. The rebase is conflict-free, its diff passes whitespace checks, and no public API snapshot changes. Complete corrected native and CI fuzz gates run sequentially. Item 1's benchmark-bearing docs checkpoint is `6d5d84684ad2ca1d2c3e049a95a6f924552b66a6`. Item 3 retains the sparse fallback **0.169 → 0.056 ms/call (-66.90%)**, RSS **6,180 → 6,212 KiB**, and dense **0.482 → 0.495 ms (+2.69%)** cost, RSS **8,236 → 8,220 KiB**. No new timing is inferred.


### Item 1 — origin push result

Joshua authorized pushes after the original local-only landing. `git push origin master` succeeded (exit 0) at checkpoint **`6d5d84684ad2ca1d2c3e049a95a6f924552b66a6`**, 2026-10-26 00:10:14 UTC. No force option was used. The server reported expected remote status checks were bypassed; the recorded complete native/fuzz gates remain the validation evidence. The HOT-wide **184.260 → 172.475 ms (-6.16%)**, RSS **20,668 → 20,584 KiB** and optimizing **356.740 → 337.624 ms (-4.80%)**, RSS **32,980 → 33,036 KiB**, remain unchanged. Raw push output is retained as `push-01.{log,json}`.


### Item 3 — LANDED under the corrected procedure

- Source `dae/item-03-write-buckets` at `eb403d287218b0660865784be6a4cc749245ba13`; gated candidate `5c8260aa8e84d8c5fd0c883e32addcb826800c95`; local-master merge **`050e89360e7b7be32aa78366f1d35e515b2916b2`**. The merge tree equals the gated candidate tree before this docs-only checkpoint.
- **GAIN:** Sparse fallback **0.169 → 0.056 ms/call (-66.90%)**, peak RSS **6,180 → 6,212 KiB**. Dense fallback costs **0.482 → 0.495 ms (+2.69%)**, RSS **8,236 → 8,220 KiB**. No enclosing CLI gain is established. All original workload/control rows remain above. Times are historical matched-pair medians against the pinned measurement master; process RSS is not allocation or live-heap evidence.
- Corrected gates: **15,491/15,491 native tests**, all 8 batches; **14/14 CI native fuzz suites**, **100,767 attempts**, seed `117504304333854712`; both exit zero. Evidence: `corrected-03-native.json`, `corrected-03-fuzz.json` and adjacent full fuzz report.
- Earlier stop decisions are superseded by this complete corrected run. No test or stage was disabled. No public `.mbti` changes. Origin push: PASS (exit 0) at `050e89360e7b7be32aa78366f1d35e515b2916b2`; no force. Raw result retained in `push-03-merge.json`. This docs-only checkpoint is pushed next.


### Item 4 — LANDED under the corrected procedure

- Source `dae/item-04-group-base` at `28a5949d314bbad4078a0c8819c76def4f0e6f4f`; gated candidate `c0fbb068c4b6718414b0c41c3a0cc2812e01f5bc`; local-master merge **`eb0a9a2a9ce2278629cd717aca2e2e8e378f5d37`**. The merge tree equals the gated candidate tree before this docs-only checkpoint.
- **GAIN:** Relative recursive-group lookup **10.466 → 1.414 ms/call (-86.47%)**, peak RSS **5,848 → 5,920 KiB**. Absolute/numeric and batch CLI controls remain neutral; the non-batch dropped-reference/dae CLI costs **31.124 → 31.684 ms (+2.03%)**, RSS **13,392 → 13,620 KiB**. All original workload/control rows remain above. Times are historical matched-pair medians against the pinned measurement master; process RSS is not allocation or live-heap evidence.
- Corrected gates: **15,496/15,496 native tests**, all 8 batches; **14/14 CI native fuzz suites**, **100,764 attempts**, seed `117504364697794335`; both exit zero. Evidence: `corrected-04-native.json`, `corrected-04-fuzz.json` and adjacent full fuzz report.
- Earlier stop decisions are superseded by this complete corrected run. No test or stage was disabled. No public `.mbti` changes. Origin push: PASS (exit 0) at `eb0a9a2a9ce2278629cd717aca2e2e8e378f5d37`; no force. Raw result retained in `push-04-merge.json`. This docs-only checkpoint is pushed next.


### Item 5 — LANDED under the corrected procedure

- Source `dae/item-05-subtype-trees` at `d20dd9102639d92893f65468d80f26120a6ee403`; gated candidate `518f949c9fb2b5a785705f716b3aa90ab08d7270`; local-master merge **`fb1e9cc9da182407813c01adbd3a58adcc2456ca`**. The merge tree equals the gated candidate tree before this docs-only checkpoint.
- **GAIN:** Recursive GC/descriptor/continuation dependency discovery **2.708 → 0.580 ms/call (-78.67%)**, peak RSS **9,944 → 9,968 KiB**; embedded definition **2.654 → 0.585 ms (-77.87%)**, RSS **9,992 → 9,996 KiB**. Pass-local gains have limited enclosing CLI benefit; no general memory gain. All original workload/control rows remain above. Times are historical matched-pair medians against the pinned measurement master; process RSS is not allocation or live-heap evidence.
- Corrected gates: **15,501/15,501 native tests**, all 8 batches; **14/14 CI native fuzz suites**, **100,779 attempts**, seed `117504419113374922`; both exit zero. Evidence: `corrected-05-native.json`, `corrected-05-fuzz.json` and adjacent full fuzz report.
- Earlier stop decisions are superseded by this complete corrected run. No test or stage was disabled. No public `.mbti` changes. Origin push: PASS (exit 0) at `fb1e9cc9da182407813c01adbd3a58adcc2456ca`; no force. Raw result retained in `push-05-merge.json`. This docs-only checkpoint is pushed next.


### Item 6 — LANDED under the corrected procedure

- Source `dae/item-06-preflight-share` at `4192c02791efd685afc171c93d16a483ccbda698`; gated candidate `faeee882a587ca317bfa5d7355f67688d477b66b`; local-master merge **`377c0bd58da20a00c43d1f0addf734a98bec0a26`**. The merge tree equals the gated candidate tree before this docs-only checkpoint.
- **GAIN:** Late rejection **0.023 → 0.012 ms/call (-49.65%)**, peak RSS **7,316 → 7,432 KiB**. Successful local flow costs **0.025 → 0.026 ms (+3.76%)**, RSS **7,348 → 7,356 KiB**. CLI evidence is neutral. All original workload/control rows remain above. Times are historical matched-pair medians against the pinned measurement master; process RSS is not allocation or live-heap evidence.
- Corrected gates: **15,504/15,504 native tests**, all 8 batches; **14/14 CI native fuzz suites**, **100,765 attempts**, seed `117504469504920149`; both exit zero. Evidence: `corrected-06-native.json`, `corrected-06-fuzz.json` and adjacent full fuzz report.
- Earlier stop decisions are superseded by this complete corrected run. No test or stage was disabled. No public `.mbti` changes. Origin push: PASS (exit 0) at `377c0bd58da20a00c43d1f0addf734a98bec0a26`; no force. Raw result retained in `push-06-merge.json`. This docs-only checkpoint is pushed next.


### Item 8 — LANDED under the corrected procedure

- Source `dae/item-08-signature-keys` at `5a53e2a90deb275ae3a0adb675a001faaecbc306`; gated candidate `42b8b4ab011dfd56a1c2adc811fc9033a3915b1e`; local-master merge **`d3f2307acb491895c28adb78bfb6e043e4a76697`**. The merge tree equals the gated candidate tree before this docs-only checkpoint.
- **GAIN:** Distinct-wide/dae CLI **58.888 → 55.983 ms (-4.34%)**, peak RSS **15,800 → 15,660 KiB**; optimizing CLI **59.147 → 55.953 ms (-5.03%)**, RSS **17,108 → 16,976 KiB**. Direct distinct index **2.320 → 1.916 ms/call (-17.18%)** carries the accepted peak RSS loss **6,744 → 8,816 KiB (+30.78%)**. Recursive index **1.599 → 0.584 ms (-63.36%)**, RSS **6,760 → 6,708 KiB**. All original workload/control rows remain above. Times are historical matched-pair medians against the pinned measurement master; process RSS is not allocation or live-heap evidence.
- Corrected gates: **15,512/15,512 native tests**, all 8 batches; **14/14 CI native fuzz suites**, **100,771 attempts**, seed `117504530116234628`; both exit zero. Evidence: `corrected-08-native.json`, `corrected-08-fuzz.json` and adjacent full fuzz report.
- Earlier stop decisions are superseded by this complete corrected run. No test or stage was disabled. No public `.mbti` changes. Origin push: PASS (exit 0) at `d3f2307acb491895c28adb78bfb6e043e4a76697`; no force. Raw result retained in `push-08-merge.json`. This docs-only checkpoint is pushed next.
- Integration preserves item 4's once-per-group base/length calculation in the structural lookup, adapts four map probes to structural keys and adds three structural-path invalid-reference cases. Original rendered-path cases remain. Repair commit `42b8b4ab011dfd56a1c2adc811fc9033a3915b1e` follows the confirmed four native compile errors; native and release WasmGC each pass **21/21 focused tests plus 1/1 recursive-group regression** before the full gates. No new combined-build performance claim.
