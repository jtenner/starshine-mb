# Tuple Optimization Residual Scalar Spelling Classification

Date: 2026-06-29
Status: working evidence; not a final TO closeout

## Sources

- Binaryen current-main `src/passes/TupleOptimization.cpp`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TupleOptimization.cpp>
- Binaryen current-main lit test `test/lit/passes/tuple-optimization.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/tuple-optimization.wast>
- Starshine implementation: `src/passes/tuple_optimization.mbt`
- Starshine focused coverage: `src/passes/tuple_optimization_wbtest.mbt`
- Dedicated profile docs/evidence: `docs/wiki/raw/research/1358-2026-06-29-tuple-optimization-genvalid-profile.md`, `1359-2026-06-29-tuple-optimization-typeidx-spill-scalarization.md`, `1360-2026-06-29-tuple-optimization-typeidx-tee-scalarization.md`, `1361-2026-06-29-tuple-optimization-drop-only-typeidx-lanes.md`
- Smoke artifacts: `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-drop-only-split`

## Slice Goal

Inspect and classify the remaining `tuple-optimization-all` count-30 residuals after the simple type-indexed spill, tee, and drop-only source-lane slices. The question was whether the residuals are still raw tuple/block carrier parity gaps, Binaryen scalar-temp spelling gaps to align, or a narrow Starshine-win family that can remain red in raw compare output until a stronger normalizer/classification path exists.

## Binaryen Contract Used For Classification

The refreshed Binaryen surface remains the same narrow tuple-local scalarizer recorded in `1358`: eligible tuple locals are those written from `tuple.make` or good tuple-local copies and read only by `tuple.extract` or good tuple-local copies. Bad/escaping reads poison the local and propagate through copy edges. Good tuple locals are split into scalar locals; Binaryen's current implementation favors preserving scalar local spelling for the original tuple-local lanes and copy-chain lanes.

That contract requires semantic tuple-local scalarization and removal of raw tuple carriers for eligible locals. It does not require Starshine to preserve Binaryen's exact scratch-local count or copy ladder when the only remaining consumers are drops of pure, no-trap scalar values and the Starshine ladder is strictly smaller.

## Residual Inspection

Re-inspected representative failure dirs from `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-drop-only-split`:

- `case-000001-gen-valid` (`tuple-optimization:spill`)
- `case-000002-gen-valid` (`tuple-optimization:tee`)
- `case-000007-gen-valid` (`tuple-optimization:copy-chain`)

All three are validating type-indexed `i32, i64` multivalue block carriers with constant payloads, no calls, no memory/table/global mutation, no exceptions, no atomics, no unreachable, and no trapping facts in the harness metadata. Binaryen and Starshine both eliminate raw tuple/block carrier spelling. The remaining diff is only scalar-local spelling:

- Binaryen keeps extra original-lane and scratch-lane copies.
- Starshine uses fewer locals and fewer scalar operations, and after the drop-only lane slice also emits fewer raw bytes in every sampled family.
- For spill and tee, Starshine drops default original-lane locals after preserving simple payload evaluation in dedicated split locals; this is behavior-preserving because the only forwarded lane uses are drops and the payloads are pure constants/local gets in this generated slice.
- For copy-chain, Starshine still uses a six-set scalar ladder rather than the stricter four-set ladder attempted during this slice, but it is already strictly smaller than Binaryen's copy spelling.

A focused documentation guard was added for the copy-chain surface: `tuple-optimization keeps simple type-indexed drop-only copy chains as a six-set compact scalar ladder`. A stricter four-`local.set` expectation was tried first and failed on the current raw pipeline output, so this slice does not claim terminal copy-chain copyback omission; it only documents the current compact six-set ladder and keeps further reduction as optional future work.

## Count-30 Measurements

A local per-case measurement over all failure dirs confirmed the sampled deltas are uniform by profile family:

| profile family | cases | Starshine raw wasm delta | Starshine normalized wasm delta | Starshine local decl delta | Starshine effective WAT op delta |
| --- | ---: | ---: | ---: | ---: | ---: |
| spill | 12 | `-3` each | `-11` each | `-2` each | `-5` each |
| tee | 4 | `-4` each | `-12` each | `-2` each | `-6` each |
| copy-chain | 14 | `-4` each | `-20` each | `-6` each | `-10` each |

Harness result summary remains unchanged:

- requested/compared: `30 / 30`
- normalized matches: `0`
- raw mismatches: `30`
- validation/generator/command/property failures: `0`
- selected profiles: spill `12`, tee `4`, copy-chain `14`
- profile labels: `tuple-optimization:spill` `12`, `tuple-optimization:tee` `4`, `tuple-optimization:copy-chain` `14`
- Binaryen cache hits/misses: `30 / 0`

## Agent Classification

Classify this exact count-30 residual surface as a **narrow measured Starshine-win scalar spelling family**, not a true semantic mismatch and not a final TO closeout:

- The Binaryen semantic family is implemented for these cases: the tuple-local carrier is scalarized and no raw tuple/block carrier remains.
- The generated payloads are pure constants/local gets with no trap/effect facts, and remaining non-observable values are only dropped.
- Starshine is smaller on raw wasm, normalized wasm, local declarations, and effective WAT operations for every sampled residual.
- The classification is limited to the simple type-indexed `i32, i64` dedicated-profile cases inspected here.

## Reopening Criteria

Reopen this classification as a parity gap or implementation slice if any of these occur:

- A residual in this family has side effects, traps, calls, memory/table/global mutation, exceptions, atomics, or an escaping/non-drop observable lane use.
- Starshine leaves a raw tuple/block carrier or `tuple.extract` in a locally representable eligible tuple-local family.
- Starshine becomes raw-size, normalized-size, local-count, or op-count losing against Binaryen for this simple generated surface.
- A broader type/lane-count/copy-chain family shows the same spelling without the pure/drop-only proof used here.
- Runtime execution or a stronger semantic oracle reports a Starshine/Binaryen behavioral difference.
- Binaryen source changes the tuple-local scalarization contract in a way that makes the extra scalar copy ladder semantically meaningful.

## Validation

- Red/tighter probe: `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*type-indexed*'` failed when the new copy-chain guard expected four `local.set` operations; current raw pipeline output has six `local.set` operations.
- Adjusted classification guard: `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*type-indexed*'` passed `3 / 3` after documenting the current six-set compact scalar ladder.

This slice intentionally did not rerun the count-30 compare because it did not change pass behavior. TO remains open for broader tee/copy-chain triage, pass-local performance, general lanes, full 100k closeout, and exact-slot/neighborhood evidence.
