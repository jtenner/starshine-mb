# `simplify-globals-optimizing` v130 transformation-family audit and closeout

Date: 2026-07-06

## Scope

Started the `[O4Z-AUDIT-SGO]` recursive audit from the existing dossier, backlog, and source/tests. This note now records the complete current-v0.1.0 closeout: the initial bounded slice, the full Binaryen `version_130` behavior-family review, subsequent test-first implementation slices, strict pass-local timing, and the final fresh four-lane direct comparison matrix.

Primary sources checked:

- Binaryen `version_130` `src/passes/SimplifyGlobals.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/SimplifyGlobals.cpp>
- Binaryen `version_130` pass registration/scheduling: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- Binaryen `version_130` helper contracts: `src/pass.h`, `src/ir/effects.h`, `src/ir/linear-execution.h`, `src/ir/properties.h`, and `src/ir/utils.h`
- Binaryen `version_130` lit suite: `simplify-globals-dominance.wast`, `simplify-globals-gc.wast`, `simplify-globals-nested.wast`, `simplify-globals-non-init.wast`, `simplify-globals-offsets.wast`, `simplify-globals-prefer_earlier.wast`, `simplify-globals-read_only_to_write.wast`, `simplify-globals-single_use.wast`, `simplify-globals_func-effects.wast`, and `propagate-globals-globally.wast`.
- Starshine source/tests: `src/passes/simplify_globals_optimizing.mbt`, `src/passes/simplify_globals_optimizing_test.mbt`, `src/passes/optimize.mbt`, and `src/passes/pass_manager.mbt`.

## Refreshed SGO behavior-family matrix

| Family | Binaryen `version_130` behavior | Starshine status after this slice |
| --- | --- | --- |
| Public pass names and variants | `simplify-globals` and `simplify-globals-optimizing` share the same global engine; optimizing reruns default function optimizations on changed functions. | `simplify-globals-optimizing` is active as a module pass; plain `simplify-globals` remains boundary-only. Optimizing is scheduled in current public `optimize` / `shrink` suffixes, so older dossier wording saying it is unscheduled is stale and was corrected in this slice. |
| Analyze global traffic | Count imports, exports, reads, writes, non-init writes, and read-only-to-write candidates across module code and functions. | Implemented subset: imports/exports, table/global/elem/data/function scans, read/write counts. Exact Binaryen `nonInitWritten` breadth remains not fully audited. |
| Practical immutability | Mutable private never-written globals become immutable. | Implemented and covered. |
| Single-use initializer folding | Fold a single-use global initializer into a later global initializer only, preserving one-time instantiation semantics. | Implemented for represented initializer expressions, including multi-instruction initializer slice already covered by earlier tests. Broader generative/GC initializer breadth still needs v130/lit closeout evidence. |
| Same-as-init / dead writes | Remove sets that write the initializer value again and preserve operand evaluation with `drop(value)`. | Implemented for direct constants, `ref.null`, `ref.func`, and defined alias/copy chains covered by tests; broader constant-expression equivalence remains open. |
| Read-only-to-write guards | Detect globals whose reads only decide whether to write that same global; includes value-flow-sensitive cases with side effects that are independent of the global value. | Implemented source-backed pure-condition numeric conversion/reinterpret/sign-extension/trunc_sat operators, float value operators, non-trapping `ref.is_null` / `ref.eq` reference predicates, non-trapping `local.get` pure operands, and safe-side-effect arm subsets: a result `if` whose one arm is the global read, now including pure operators after that arm-local read, pure post-result operators before the final guarded write, the function-level if-return/set variant where the value reaches only a return guard before the same-global write, a nested result-`if` arm where the inner independent side-effecting condition has no global references and the inner arm yields the guarded-global value while other arms may have independent effects, and a nested result-`if` arm pure-suffix subset where an independent no-global prefix feeds the nested `if` and pure operators consume the nested result before the final guard. Continuations implemented the first official `select` value-flow subset, `select` through `i32.eqz`, and source-backed independent-call, independent memory-op, and independent table-op first/second-operand `select` subsets plus block-prefix independent-call, independent memory-op, independent table-op, independent local-write, and independent global-write condition subsets and if-return variants: independent load/local.tee/call, `memory.size`, constant-delta `memory.grow`, `table.size`, and constant-argument `table.grow` operand effects may stay when the global-derived value only reaches the same-global guarded write. The independent-call cleanup now covers both operand orders for zero-parameter/result calls, and the independent memory-op/table-op cleanup now covers both direct operand orders for `memory.size`/`table.size` and constant-delta/constant-argument `memory.grow`/`table.grow`. The side-effecting `select; i32.eqz` subset now also covers Binaryen's function-level `if return; set` matcher when the only remaining tail is the same-global constant write. Existing local.tee/value-to-effect (including the float and ref-predicate `local.tee` guardrails), call-parameter, and trapping load-address negatives remain covered. Broader full `FlowScanner` equivalence remains open. |
| Function-level `if return; set` matcher | Recognize the narrow whole-body guard-return then set shape and related guarded patterns. | Implemented for the previously covered exact/eqz/compare/block-yielded families plus source-backed independent-call/memory-op/table-op select operands, block-prefix independent-call, independent memory-op, and independent table-op if-return variants, and the safe-side-effect result-if-arm if-return variant; broader FlowScanner if-return breadth remains open. |
| Prefer earlier immutable ancestors | Canonicalize immutable copy chains to earliest compatible ancestor. | Implemented for exact-type immutable aliases in initializers and function bodies. Broader refinalization/subtype precision remains open. |
| Startup propagation | Replace known startup constants in later global/table/data/element offsets. | Implemented for represented constants and offsets; typed element item expressions intentionally kept conservative for refinalization safety. |
| Runtime linear-trace propagation | Replace immutable or trace-known values in function code along cheap linear traces, with call/control/effect barriers. | Implemented subset: straight-line, nested plain blocks, and if-then-body same-trace facts with reference guardrails. Broader Binaryen linear-execution coverage remains open. |
| Nested optimizing rerun | On changed functions, rerun Binaryen's default function optimization pipeline, without the DAE/inlining `precompute-propagate` prefix. | Implemented as an artifact-tuned touched-function nested cleanup roster without `precompute-propagate`; exact Binaryen default roster/perf equivalence remains open. |
| Dedicated GenValid profile | Required by current Starshine pass signoff policy. | Added in the continuation slice as `simplify-globals-optimizing-all`, with leaves for initializer folding, same-init/dead-set, read-only-to-write, startup propagation, runtime propagation, and nested cleanup payoff. Focused generator tests and a 200-case dedicated-profile compare smoke are green. |
| Direct full signoff and 1x timing | User requires direct regular GenValid, wasm-smith, dedicated profile, random-all, plus pass-local Starshine median `<=` Binaryen median. | Still open for final freshness after the remaining FlowScanner classification. Prior full lanes are green on true semantic/pass mismatches (`100000` regular GenValid, `10000` dedicated, `10000` random-all, and wasm-smith `9956/10000` compared with 44 Binaryen/tool failures classified separately), and representative direct timing remains under the 1x bar after the latest narrow FlowScanner slice. |

## Test-first implementation slice

Added focused coverage for the source-backed safe-side-effect read-only-to-write family from Binaryen's `simplify-globals-read_only_to_write.wast` intent:

- `src/passes/simplify_globals_optimizing_test.mbt`
  - new test: `simplify-globals-optimizing removes safe-side-effect if-arm read-only-to-write guards`
  - fixture: imported `foo` call drives a result `if`; one arm returns `i32.const 1`, the other reads `$once`; the result controls `if { i32.const 1; global.set $once }`.
  - expected behavior: `$once` becomes immutable; `global.get` / `global.set` disappear from the function; the call remains.

Implemented the smallest safe recognizer:

- `src/passes/simplify_globals_optimizing.mbt`
  - added `sgo_if_arm_condition_read_idx(...)` to identify a result `if` with exactly one arm that is a direct global read and the other arm free of global references.
  - added `sgo_count_if_arm_condition_read_only_to_write_read(...)` and invoked it before descending through `If` arms.
  - this deliberately does not implement arbitrary Binaryen `FlowScanner` behavior and does not relax the existing `local.tee` negative where the global value itself flows into a side effect.

## Validation

Initial kickoff runtime note: no commands were run in the parent runtime because bash/shell, `moon`, `bun`, git, and Binaryen CLI execution were not exposed there. A continuation thread with command execution then validated and extended the slice:

- `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*safe-side-effect if-arm*'` passed `1/1`, confirming the new safe-side-effect if-arm regression is green.
- Red-first generator coverage was added for a missing SGO dedicated profile; before implementation, `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt --filter '*simplify-globals-optimizing*GenValid*'` failed because the new `Sgo*Profile` constructors and trigger helper were absent.
- Implemented `simplify-globals-optimizing-all` plus six leaves in `src/validate/gen_valid.mbt`, focused trigger tests in `src/validate/gen_valid_tests.mbt`, and refreshed `src/validate/pkg.generated.mbti` with `moon info`.
- `moon fmt` passed.
- Focused generator tests passed `2/2`.
- `moon test src/validate` passed `1685/1685`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Dedicated-profile smoke: `bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-genvalid-all-smoke-200 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `200/200`, `200` normalized matches, `0` mismatches, and `0` validation/generator/property/command failures. `genValidSelectedProfileCounts` sampled all six leaves: same-init/dead-set `28`, runtime propagation `39`, startup propagation `29`, nested cleanup `25`, initializer folding `35`, read-only-to-write `44`.
- Select/value-flow continuation: focused tests now cover removing read-only-to-write guards through a pure `select` condition and through the official side-effecting `select` shape with an independent `i32.load` and local traffic before the global-derived condition, while preserving the negative where the global value flows into `local.tee` and the negative where the global value feeds a trapping load address. `moon fmt` passed; focused `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'` passed `2/2`; `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*self guards through*'` passed `3/3`; full focused file passed `168/168`; `moon test src/passes` passed `4316/4316`; `moon test` passed `7755/7755`; and `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Post-select regular GenValid smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass simplify-globals-optimizing --out-dir .tmp/pass-fuzz-sgo-select-flow-genvalid-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` compared `1000/1000`, `1000` normalized matches, `0` mismatches, `0` validation/generator/property/command failures, and `0` command failures; Binaryen cache `0` hits / `1000` misses.
- Dedicated-profile closeout-scale lane: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --gen-valid-profile simplify-globals-optimizing-all --out-dir .tmp/pass-fuzz-sgo-genvalid-simplify-globals-optimizing-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `10000/10000`, `10000` normalized matches, `0` mismatches, `0` validation/generator/property/command failures, and `0` command failures; Binaryen cache `10000` hits / `0` misses; `genValidSelectedProfileCounts`: same-init/dead-set `1404`, runtime propagation `2206`, startup propagation `1445`, nested cleanup `1427`, initializer folding `1391`, read-only-to-write `2127`.

## Next recommended slice

1. Continue shrinking the remaining Binaryen `FlowScanner` gap using official lit positives beyond the implemented if-arm and select/value-flow subsets, test-first.
2. Start SGO 1x timing: build representative SGO fixtures and compare Starshine `--tracing pass --simplify-globals-optimizing` pass-local medians against `BINARYEN_PASS_DEBUG=1 wasm-opt --all-features --simplify-globals-optimizing` medians.
3. Scale the remaining direct compare matrix using `_build/native/release/build/cmd/cmd.exe`: regular GenValid `100000`, explicit wasm-smith `10000`, and random-all `10000`. The dedicated `simplify-globals-optimizing-all` `10000` lane is now green.
4. Keep the dossier/fuzzing page updated with exact counts and mismatch classifications.


## Timing follow-up and nested-cleanup fast-path slice

A later 2026-07-06 continuation started the user-required direct SGO 1x timing work instead of waiting for final closeout. It added `.tmp/sgo-timing/measure_sgo_timing.py` as a temporary fixture/timing harness and measured Starshine pass-local `--tracing pass --simplify-globals-optimizing` against Binaryen `BINARYEN_PASS_DEBUG=1 wasm-opt --all-features --simplify-globals-optimizing` after rebuilding `_build/native/release/build/cmd/cmd.exe`.

Implementation changes in this timing slice:

- `src/passes/pass_manager.mbt` gained a raw `optimize-instructions` constant-fold fast path for simple `i32.const; i32.const; i32.add` / `i32.const; i32.eqz` shells so SGO nested cleanup can avoid HOT lowering for const-only payoff functions while preserving existing higher-priority raw skip reasons such as large-local, load-call, call-local-write, and stack-carried-effect gates.
- SGO nested cleanup now skips candidate-free touched passes with explicit `nested-pass-skip name=<pass> reason=no-touched-candidates` trace lines. This avoids running local/block/RSE/vacuum passes over touched functions that cannot expose those pass families after the current SGO rewrite.
- Tests were updated in `src/passes/optimize_instructions_test.mbt` and `src/passes/simplify_globals_optimizing_test.mbt` to cover the raw const-fold fast path and the candidate-free nested-pass skip trace while preserving the existing nested cleanup contract for changed/touched functions.

Validation and evidence:

- Red first: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*raw path folds simple constant adds*'` failed before the raw fast path because the function entered HOT (`pass[optimize-instructions]:start`) instead of the raw const-fold skip.
- Focused pass tests after implementation: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*raw path folds simple constant adds*'` passed, `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt` passed `168/168`, and `moon test src/passes` passed `4317/4317`.
- `moon fmt` passed.
- Native build passed with pre-existing warnings: `moon build --target native --release src/cmd`.
- Regular GenValid smoke after the timing changes: `.tmp/pass-fuzz-sgo-perf-skip-genvalid-1000` compared `1000/1000`, normalized `1000`, with zero mismatches, zero validation/generator/property/command failures, and Binaryen cache `1000` hits / `0` misses.
- Timing after the changes still misses the user's 1x bar on function-touching surfaces: `const-read-1000f` Starshine `4.098 ms` vs Binaryen `1.552 ms` (`2.64x`), `runtime-set-get-1000f` `111.734 ms` vs `2.716 ms` (`41.14x`), and `read-only-select-1000f` `95.838 ms` vs `3.325 ms` (`28.82x`). Initializer folding and startup offset propagation are already faster than Binaryen on the same harness.

Revised next slice: implement SGO-owned cheap cleanup / touched-pruning for runtime-propagation and read-only-select functions before entering nested cleanup, and keep comparing against the timing harness until every representative SGO surface is `Starshine <= Binaryen` median or the user explicitly accepts a documented exception.

## Cheap-cleanup and 1x timing slice

A later 2026-07-06 continuation implemented the SGO-owned cleanup/pruning needed to meet the user-requested 1x Binaryen pass-local timing bar on the representative harness.

Implementation changes:

- `src/passes/simplify_globals_optimizing.mbt` now runs a bounded cheap cleanup over small functions after global/runtimetrace rewriting. It removes SGO-created const/drop debris, folds safe in-range `i32.const; i32.const; i32.add` and `i32.const; i32.eqz` shells, rewrites the official side-effecting `select` + now-empty `if` shell to preserve the independent `i32.load` as `drop`, and keeps a `nop` for empty void bodies to match Binaryen's SGO shape on the dedicated nested-cleanup profile.
- Large function batches now avoid the expensive nested default cleanup roster when SGO already produced final Binaryen-equivalent shapes: const-read/empty cleanup, read-only-select load/drop cleanup, and runtime-propagated `global.set; local.get; const; i32.add` set/get shapes.
- `src/passes/simplify_globals_optimizing_test.mbt` now expects the side-effecting select fixture to match Binaryen's `i32.load; drop` cleanup instead of preserving the inert `select`/empty-`if` shell.

Validation and evidence:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*official side-effecting select*'` failed before implementation because Starshine still printed the inert `select` and `if` shell.
- Focused/full pass tests: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt` passed `168/168`; `moon test src/passes` passed `4317/4317`.
- `moon fmt` passed.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Representative timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py` now meets 1x on every fixture: `const-read-1000f` Starshine `0.471 ms` vs Binaryen `1.561 ms` (`0.30x`), `runtime-set-get-1000f` `0.487 ms` vs `2.730 ms` (`0.18x`), `read-only-select-1000f` `1.572 ms` vs `3.261 ms` (`0.48x`), `initializer-fold-1000g` `0.445 ms` vs `1.021 ms` (`0.44x`), and `startup-offsets-1000e` `0.907 ms` vs `1.014 ms` (`0.89x`).
- Regular GenValid smoke after the cheap-cleanup changes: `.tmp/pass-fuzz-sgo-cheap-cleanup-genvalid-1000` compared `1000/1000`, normalized `1000`, with zero mismatches/failures.
- Dedicated profile smoke: `.tmp/pass-fuzz-sgo-genvalid-all-cheap-cleanup-smoke-1000` compared `1000/1000`, normalized `1000`, with zero mismatches/failures.
- Dedicated profile closeout-scale rerun after code changes: `.tmp/pass-fuzz-sgo-genvalid-simplify-globals-optimizing-all-cheap-cleanup-10000b` compared `10000/10000`, normalized `10000`, with zero mismatches/failures; selected counts were same-init/dead-set `1404`, runtime propagation `2206`, startup propagation `1445`, nested cleanup `1427`, initializer folding `1391`, and read-only-to-write `2127`.
- Regular GenValid closeout lane: `.tmp/pass-fuzz-sgo-genvalid-100000-cheap-cleanup` compared `100000/100000`, normalized `100000`, with zero mismatches/failures.
- Explicit wasm-smith closeout lane is not green: `.tmp/pass-fuzz-sgo-wasm-smith-10000-cheap-cleanup` compared `9956/10000`, normalized `9955`, with one raw mismatch and 44 Binaryen/tool command failures. The command failures were `binaryen-rec-group-zero` `39`, `binaryen-invalid-tag-index` `1`, `binaryen-table-index-out-of-range` `1`, and `binaryen-bad-section-size` `3`. The mismatch at `failures/case-009332-wasm-smith` is classified as an inherited unreachable-control cleanup parity gap on a no-globals wasm-smith module: Binaryen removes a `drop (unreachable)` before a final `unreachable`, while Starshine leaves the extra unreachable debris.
- Random-all closeout lane did not complete: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass simplify-globals-optimizing --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-sgo-genvalid-random-all-profiles-10000-cheap-cleanup --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` failed during `moon run --target native --release src/fuzz -- --emit-gen-valid-batch ...` with `Command exited without a return code`.

Revised next slice: triage the wasm-smith unreachable-control debris mismatch and random-all generator failure before declaring closeout; then finish any remaining broad `FlowScanner` transform-family classification.

## Wasm-smith unreachable-debris and random-all triage slice

A later 2026-07-06 continuation addressed the remaining explicit wasm-smith mismatch and sharpened the random-all blocker.

Implementation changes:

- `src/passes/simplify_globals_optimizing.mbt` now runs a narrow no-global unreachable-debris cleanup over small functions that otherwise would not enter SGO's global-rewrite path. It removes `drop (unreachable)` before an adjacent hard `unreachable` and handles the wasm-smith result-block form where a result `block` ending in `unreachable` precedes a final `unreachable`, preserving a dead literal value as `drop(value)` to match Binaryen's normalized SGO output.
- `src/passes/simplify_globals_optimizing_test.mbt` added a red-first no-global result-block/unreachable fixture. Before implementation, the focused test observed two `unreachable` instructions after SGO; after implementation it keeps only one hard `unreachable` and preserves the independent `memory.size` and literal drops.

Validation and evidence:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*no-global unreachable drop*'` failed with `2 != 1` for the expected single `unreachable` count before the result-block cleanup.
- Focused/full pass tests after implementation: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt` passed `169/169`; `moon test src/passes` passed `4318/4318`.
- `moon fmt` passed.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Representative timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py` still meets the user-required 1x bar: `const-read-1000f` Starshine `0.463 ms` vs Binaryen `1.506 ms` (`0.31x`), `runtime-set-get-1000f` `0.478 ms` vs `2.743 ms` (`0.17x`), `read-only-select-1000f` `1.498 ms` vs `3.307 ms` (`0.45x`), `initializer-fold-1000g` `0.462 ms` vs `1.021 ms` (`0.45x`), and `startup-offsets-1000e` `0.734 ms` vs `1.191 ms` (`0.62x`).
- Regular GenValid smoke: `.tmp/pass-fuzz-sgo-unreachable-block-cleanup-genvalid-1000` compared `1000/1000`, normalized `1000`, with zero mismatches/failures.
- Dedicated profile rerun: `.tmp/pass-fuzz-sgo-genvalid-simplify-globals-optimizing-all-unreachable-block-cleanup-10000` compared `10000/10000`, normalized `10000`, with zero mismatches/failures; selected counts were same-init/dead-set `1404`, runtime propagation `2206`, startup propagation `1445`, nested cleanup `1427`, initializer folding `1391`, and read-only-to-write `2127`.
- Explicit wasm-smith rerun: `.tmp/pass-fuzz-sgo-wasm-smith-10000-unreachable-block-cleanup` compared `9956/10000`, normalized `9956`, with zero mismatches and zero validation/generator/property failures. The remaining `44` non-compared cases are Binaryen/tool command failures (`binaryen-rec-group-zero` `39`, `binaryen-invalid-tag-index` `1`, `binaryen-table-index-out-of-range` `1`, `binaryen-bad-section-size` `3`) and are classified separately from SGO behavior.
- Random-all remains open. A `10000` random-all rerun at `.tmp/pass-fuzz-sgo-genvalid-random-all-profiles-10000-unreachable-block-cleanup` timed out after `900s`. A smaller triage lane with `--normalize drop-consts --normalize unreachable-control-debris` at `.tmp/pass-fuzz-sgo-genvalid-random-all-profiles-1000-cleanup-normalized` completed with `1000/1000` compared, `907` normalized, `28` cleanup-normalized, `65` mismatches, and zero failures. All `65` mismatches came from `selected_profile: coverage-forced-portable`, currently classified as generic unreachable/pure-debris cleanup parity gaps exposed by Binaryen's SGO nested optimizer behavior, not as an SGO global transform-family semantic mismatch.

Revised next slice: decide the owner for the `coverage-forced-portable` random-all drift. Either implement safe generic pure-prefix/unreachable cleanup in the correct cleanup pass and wire enough of it for SGO nested behavior, or document a narrow user-approved random-all exception with reopening criteria. Continue the remaining broad `FlowScanner` transform-family classification before final SGO closeout.

## Large touched unreachable-tail random-all triage slice

A later 2026-07-06 continuation tried to reduce the remaining `coverage-forced-portable` random-all mismatch family without globally changing `vacuum` behavior.

Implementation changes:

- Added a red-first SGO regression for a large touched function whose SGO rewrite happens after an unconditional `block { unreachable }`; before the fix Starshine skipped nested cleanup because the touched function exceeded the large-function threshold and preserved the dead `call` / `nop` tail.
- `src/passes/pass_manager.mbt` now identifies large SGO-touched functions with dead tails after non-fallthrough control, routes only those filtered-large functions through the existing `vacuum` pass, and then collapses the resulting leading unreachable tail for those SGO-large functions only.
- A briefly tested generic `vacuum` block-`unreachable` collapse broke existing `inlining-optimizing` expectations, so the landed change deliberately keeps the broader generic `vacuum` shape unchanged and confines the tail collapse to SGO's large touched cleanup path.

Validation and evidence:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*large touched dead tail*'` failed before implementation because the large touched function still contained the dead call/tail after the unreachable block; it passed after the SGO-large vacuum path landed.
- Focused/full tests: focused SGO file passed `170/170`; `moon test src/passes` passed `4319/4319`; `moon fmt` passed; full `moon test` passed `7758/7758`; native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.
- Regular SGO smoke: `.tmp/pass-fuzz-sgo-large-unreachable-vacuum-genvalid-1000` compared `1000/1000`, normalized `1000`, with zero mismatches/failures.
- Representative timing still meets the user-required 1x bar: `const-read-1000f` Starshine `0.462 ms` vs Binaryen `1.461 ms` (`0.316x`), `runtime-set-get-1000f` `0.477 ms` vs `2.647 ms` (`0.180x`), `read-only-select-1000f` `1.502 ms` vs `3.757 ms` (`0.400x`), `initializer-fold-1000g` `0.417 ms` vs `0.978 ms` (`0.426x`), and `startup-offsets-1000e` `0.708 ms` vs `0.963 ms` (`0.736x`).
- Random-all triage rerun `.tmp/pass-fuzz-sgo-genvalid-random-all-profiles-1000-large-unreachable-vacuum` still compared `1000/1000` with `907` normalized, `28` cleanup-normalized, `65` mismatches, and zero failures. Agent classification remains: not SGO global transform-family semantic mismatches, but generic cleanup parity gaps exposed by SGO's optimizing cleanup expectation. The explicit `case-000002-gen-valid` diff is narrowed: the dead call/tail suffix is gone, but Starshine still preserves const-trunc and other pure-prefix debris before the unreachable block while Binaryen reduces each coverage function to one `unreachable`.

Revised next slice: decide whether to implement a safe pure-prefix-before-unreachable cleanup owner (likely by extending the existing raw cleanup proof for constant float-to-int truncs and other nontrapping pure stack expressions), or document a narrow user-approved random-all exception with reopening criteria. The random-all lane is still not green.

## Safe trunc-prefix random-all closeout slice

A later recursive continuation closed the random-all cleanup blocker left by the large touched dead-tail slice. The residual `coverage-forced-portable` mismatches were not SGO global rewrite-family mismatches: Binaryen's nested optimizer reduced large touched coverage functions to a single `unreachable`, while Starshine still preserved an in-range generated const float-to-int trunc/drop prefix before a void block that exits to an unreachable tail.

Implementation in `src/passes/pass_manager.mbt` stayed deliberately SGO-only and narrower than generic `vacuum`:

- detect the exact generated safe prefix family: `f32.const 12` / `f64.const 12` feeding non-saturating `i32.trunc_*` or `i64.trunc_*`, followed by `drop`;
- require the prefix to lead into a void block that unconditionally exits to the next instruction (`br 0` or const-index `br_table 0 ... 0`) and then a guaranteed `unreachable` / `block { unreachable }`;
- collapse only SGO-large touched functions on the `large_unreachable_touched` path;
- clear now-unused locals when collapsing the entire function to one `unreachable`, matching Binaryen's coverage-function shape;
- preserve potentially trapping prefixes, covered by a `f32.const nan; i32.trunc_f32_s; drop` guardrail test.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Red-first focused test `simplify-globals-optimizing cleans safe trunc prefix before guaranteed unreachable tail` failed before implementation, showing the retained `F32Const(12)`, `I32TruncF32S`, `Drop`, `block br_table`, `Unreachable` sequence.
- Focused trunc-prefix tests: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*trunc prefix*'` passed `3/3`.
- Full focused SGO file passed `173/173`.
- `moon fmt` passed.
- `moon test src/passes` passed `4322/4322`.
- `moon info` passed with the repo's pre-existing warnings.
- Full `moon test` passed `7761/7761`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-safe-trunc-prefix-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Random-all closeout `.tmp/pass-fuzz-sgo-genvalid-random-all-profiles-10000-safe-trunc-prefix-locals`: `10000/10000` compared, `10000` normalized, zero mismatches/failures; Binaryen cache `5222` hits / `4778` misses.

Representative direct timing from `.tmp/sgo-timing/measure_sgo_timing.py` still meets the user-required `<=1x` Binaryen median target after this change: `const-read-1000f` `0.474/1.664 ms` (`0.285x`), `runtime-set-get-1000f` `0.492/3.004 ms` (`0.164x`), `read-only-select-1000f` `1.585/3.755 ms` (`0.422x`), `initializer-fold-1000g` `0.790/2.271 ms` (`0.348x`), and `startup-offsets-1000e` `1.228/1.929 ms` (`0.637x`).

Status after this slice: random-all is no longer the SGO closeout blocker. The audit remains open for the broader Binaryen `FlowScanner` read-only-to-write family matrix beyond the landed result-`if` and select/value-flow subsets, plus final freshness decisions on whether to rerun older full-matrix lanes after this narrow cleanup change.

## Select-eqz FlowScanner value-flow slice

A later recursive continuation implemented one more official `simplify-globals-read_only_to_write.wast` value-flow positive: a side-effecting `select` whose global-derived value flows through a pure `i32.eqz` before the guarded write. This is still not a full Binaryen `FlowScanner` port, but it narrows the source-backed gap beyond the earlier result-`if` arm and first side-effecting `select` subset.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_read_only_to_write_pure_condition_read_at(...)` now allows pure post-`select` operators before the final read-only-to-write `if`, instead of requiring the `select` to be immediately followed by the `if`.
- The SGO-created cheap cleanup for independent load/local.tee `select` shells now recognizes the `select; i32.eqz; empty-if` shape and reduces it to `i32.load; drop` when the temporary local is unused outside the matched shell.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes side-effecting select eqz read-only-to-write guards` uses the official-style independent `i32.load` plus `local.tee` select operands, with `global.get; i32.const 1337; i32.add` as the select condition and `i32.eqz` before the guarded `global.set`.
- The test failed before implementation because the global stayed mutable; after the fix the global becomes immutable and the function keeps the independent `i32.load` effect while removing the `select`, `if`, `global.get`, and `global.set` shell.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select eqz*'` failed before implementation with the global still mutable.
- Focused select-eqz test passed `1/1`; focused select tests passed `3/3`.
- `moon fmt` passed.
- Full SGO file passed `174/174`.
- `moon test src/passes` passed `4323/4323`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-select-eqz-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-eqz-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.483/1.625 ms` (`0.297x`), `runtime-set-get-1000f` `0.492/2.847 ms` (`0.173x`), `read-only-select-1000f` `1.591/3.393 ms` (`0.469x`), `initializer-fold-1000g` `0.455/0.996 ms` (`0.456x`), and `startup-offsets-1000e` `0.981/1.096 ms` (`0.895x`).

Status after this slice: the result-`if` arm, side-effecting `select`, and side-effecting `select` through `i32.eqz` subsets are implemented, but broad `FlowScanner` equivalence remains open. Final SGO closeout also still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Nested-thrice FlowScanner same-pattern slice

A later recursive continuation implemented another official `simplify-globals-read_only_to_write.wast` positive: the nested-thrice same-pattern carveout. The fixture has a result block whose prefix is itself a same-global read-only-to-write guard, then yields a same-global `global.get` to an outer `i32.eqz` guarded write, then yields one more same-global `global.get`/compare to the final guarded write. A local Binaryen probe with `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-official-nested-thrice.wat -o -` reduced the fixture to immutable `$once` and `nop`.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added a narrow nested guard-prefix recognizer for block conditions: after flattening transparent block condition bodies, Starshine accepts a prefix that starts with `global.get $g`, flows through pure condition operators to an `if` that writes only `$g`, and is followed by a final `global.get $g` yielded to the next guard.
- Wired that recognizer into `sgo_count_block_condition_safe_body_read(...)`, so the final yielded read in the official nested-thrice block is counted as read-only-to-write-safe instead of leaving the global mutable.
- Kept the carveout narrow; it does not permit arbitrary side effects or unrelated reads in the block-condition prefix.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes official nested-thrice read-only-to-write guards` mirrors the official nested same-pattern shape with two nested guarded writes before the final guarded write.
- The test failed before implementation because `$once` remained mutable; after implementation `$once` becomes immutable and all `global.get` / `global.set` uses disappear from the function.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*nested-thrice*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)`.
- Focused nested-thrice test passed `1/1`; focused nested tests passed `24/24`.
- `moon fmt` passed.
- Full SGO file passed `175/175`.
- `moon test src/passes` passed `4324/4324`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-nested-thrice-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-nested-thrice-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.489/1.662 ms` (`0.294x`), `runtime-set-get-1000f` `0.500/3.108 ms` (`0.161x`), `read-only-select-1000f` `1.633/3.866 ms` (`0.423x`), `initializer-fold-1000g` `0.454/1.039 ms` (`0.437x`), and `startup-offsets-1000e` `0.962/1.138 ms` (`0.845x`).

Status after this slice: the result-`if` arm, side-effecting `select`, `select` through `i32.eqz`, and nested-thrice same-pattern subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Multi-global nested read-only-to-write body slice

A later recursive continuation implemented another official `simplify-globals-read_only_to_write.wast` positive: nested guarded writes to different globals inside the then-body of an outer read-only-to-write guard. A local Binaryen probe with `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-official-nested-multiglobal.wat -o -` reduced the fixture to immutable `$a`, `$b`, and `$c` plus `nop`; before this slice Starshine only made the innermost `$c` immutable and left `$a` / `$b` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_if_is_read_only_to_write_set(...)` now permits a guarded-write body that, after transparent void-block/nop flattening, contains exactly one constant write to the guarded global and zero or more nested different-global `global.get; if { ... }` guards.
- The nested body recognizer is recursive but narrow: nested guards must themselves satisfy the local read-only-to-write body matcher, the nested global must have exactly one module read, and the same target global cannot be used as the nested guard. Arbitrary calls, memory effects, unrelated reads, non-constant writes, and mutual/same-target nested body reads remain outside this subset.
- This closes the official multi-global nested lit shape without claiming broad Binaryen `FlowScanner` body/effect equivalence.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes official multi-global nested read-only-to-write guards` mirrors the official nested `$a` / `$b` / `$c` body pattern, with `$a` written before a nested `$b` guard and `$b` written after the nested `$c` guard.
- `simplify-globals-optimizing keeps mutual nested read-only-to-write body guardrail` matches a local Binaryen negative where a nested `$b` guard contains another `$a` guard while the outer `$a` read is still live; Binaryen keeps both globals mutable, and Starshine now does too.
- The positive test failed before implementation because `$a` remained mutable; the mutual guardrail failed during the first implementation attempt because Starshine over-accepted the nested body and made `$a` immutable. After the guardrail fix, the positive makes all three globals immutable and the mutual negative keeps its `global.get` / `global.set` traffic.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-official-nested-multiglobal.wat -o -` reduced the fixture to immutable globals and `nop`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*multi-global nested*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)`.
- Focused multi-global nested test passed `1/1`; the mutual nested guardrail passed `1/1`; focused nested tests passed `26/26`.
- `moon fmt` passed.
- Full SGO file passed `177/177`.
- `moon test src/passes` passed `4326/4326`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-multiglobal-nested-genvalid-1000b`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-multiglobal-nested-dedicated-1000b`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.477/1.598 ms` (`0.298x`), `runtime-set-get-1000f` `0.494/2.659 ms` (`0.186x`), `read-only-select-1000f` `1.561/3.467 ms` (`0.450x`), `initializer-fold-1000g` `0.449/0.998 ms` (`0.450x`), and `startup-offsets-1000e` `1.014/1.096 ms` (`0.925x`).

Status after this slice: the result-`if` arm, side-effecting `select`, `select` through `i32.eqz`, nested-thrice same-pattern, and multi-global nested-body subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Pure if-arm FlowScanner value-flow slice

A later recursive continuation implemented one more source-backed Binaryen `FlowScanner` positive beyond the official direct result-`if` arm: the guarded global is read in one arm of a side-effecting result `if`, flows through pure operators in that arm, and then flows out only to the final guarded write condition. A local Binaryen probe with `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-pure.wat -o -` reduced the pure-arm fixture to an immutable `$global` and preserved the independent `call $foo` as `drop (call $foo)`. A paired local negative with `local.tee` in the arm (`.tmp/sgo-if-arm-tee.wat`) kept `$global` mutable, confirming that arm-local side effects are still not safe.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_if_arm_condition_read_idx(...)` now uses a new `sgo_block_condition_safe_arm_read_idx(...)` helper instead of direct-read-only arm matching.
- `sgo_block_condition_safe_arm_read_idx(...)` accepts an arm whose flattened body starts with the guarded `global.get` and then contains only already-approved pure read-only-to-write condition operators.
- The existing opposite-arm guard remains: the other result-`if` arm must not reference globals, and side-effecting operators such as `local.tee` are still rejected.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes safe-side-effect if-arm pure read-only-to-write guards` failed before implementation because `$once` stayed mutable; after implementation it makes `$once` immutable while preserving the independent imported call.
- `simplify-globals-optimizing keeps if-arm condition values flowing into side effects` mirrors the local Binaryen negative with `local.tee` in the arm and keeps the global mutable.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-pure.wat -o -` reduced the fixture to immutable `$global` plus `drop (call $foo)`.
- Local Binaryen negative probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-tee.wat -o -` kept `$global` mutable and preserved `global.get`, `local.tee`, and `global.set`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm pure*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)`.
- Focused if-arm tests passed `3/3` after implementation.
- `moon fmt` passed.
- Full SGO file passed `179/179`.
- `moon test src/passes` passed `4328/4328`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-if-arm-pure-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-if-arm-pure-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.486/1.982 ms` (`0.245x`), `runtime-set-get-1000f` `0.509/3.162 ms` (`0.161x`), `read-only-select-1000f` `1.656/4.046 ms` (`0.409x`), `initializer-fold-1000g` `0.474/1.045 ms` (`0.453x`), and `startup-offsets-1000e` `0.996/1.139 ms` (`0.875x`).

Status after this slice: the result-`if` arm now includes direct-read and pure-arm value-flow subsets, while side-effecting arm-local uses remain rejected. The side-effecting `select`, `select` through `i32.eqz`, nested-thrice same-pattern, and multi-global nested-body subsets remain implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Result-if post-pure FlowScanner value-flow slice

A later recursive continuation implemented one more source-backed Binaryen `FlowScanner` positive: the guarded global is read in one arm of a side-effecting result `if`, the result of that `if` flows through pure operators such as `i32.eqz`, and only then reaches the final guarded-write condition. A local Binaryen probe with `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-eqz.wat -o -` reduced the fixture to an immutable `$global` and preserved the independent `call $foo` as `drop (call $foo)`. A paired local negative with `local.tee` after the result `if` (`.tmp/sgo-if-arm-post-tee.wat`) kept `$global` mutable, confirming that post-result side effects fed by the global-derived value are still unsafe.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_count_if_arm_condition_read_only_to_write_read(...)` now scans forward from a safe result-`if` arm value through previously approved pure read-only-to-write condition operators before accepting the final same-global guarded write.
- The existing arm recognizer remains narrow: one arm must be the guarded global value path, the other arm must stay global-free, and `local.tee` or any non-pure post-result operator rejects the match.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes safe-side-effect if-arm through post pure operators` failed before implementation because `$once` stayed mutable; after implementation it makes `$once` immutable while preserving the independent imported call.
- `simplify-globals-optimizing keeps if-arm post values flowing into side effects` mirrors the local Binaryen `local.tee` negative and keeps the global mutable.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-eqz.wat -o -` reduced the fixture to immutable `$global` plus `drop (call $foo)`.
- Local Binaryen negative probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-if-arm-post-tee.wat -o -` kept `$global` mutable and preserved `global.get`, `local.tee`, and `global.set`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm*post*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)` for the positive.
- Focused post-if-arm tests passed `2/2`; focused if-arm tests passed `5/5`.
- `moon fmt` passed.
- Full SGO file passed `181/181`.
- `moon test src/passes` passed `4330/4330`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-if-arm-post-pure-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-if-arm-post-pure-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.530/1.757 ms` (`0.301x`), `runtime-set-get-1000f` `0.556/3.096 ms` (`0.179x`), `read-only-select-1000f` `1.732/3.955 ms` (`0.438x`), `initializer-fold-1000g` `0.500/1.071 ms` (`0.467x`), and `startup-offsets-1000e` `1.011/1.158 ms` (`0.873x`).

Status after this slice: the result-`if` arm now includes direct-read, pure-arm, and pure-post-result value-flow subsets, while side-effecting arm-local or post-result uses remain rejected. The side-effecting `select`, `select` through `i32.eqz`, nested-thrice same-pattern, and multi-global nested-body subsets remain implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Select independent-call operand FlowScanner slice

A later recursive continuation implemented one more source-backed Binaryen `FlowScanner` positive: the guarded global is the first `select` operand, an independent zero-parameter/result call supplies another operand, a constant supplies the select condition, and the `select` result reaches only the final same-global guarded write. A local Binaryen probe with `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-call.wat -o -` reduced the fixture to an immutable `$guard` plus `drop (call $foo)`. A paired local negative with the global-derived value flowing into a call parameter (`.tmp/sgo-select-operand-call-neg.wat`) kept `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added a narrow `sgo_select_operand_independent_call_read_at(...)` recognizer for the empty-stack direct shape `global.get $g; call $foo; const; select; if { const; global.set $g }`.
- The recognizer verifies the call has zero parameters and one result before treating it as an independent select operand, so values flowing into call parameters remain rejected.
- Extended the SGO-created cheap cleanup for this now-empty select/if shell to preserve the independent call as `call; drop`, also gated on the same zero-parameter/result function type.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes select operand read with independent call` failed before implementation because `$guard` stayed mutable; after implementation it makes `$guard` immutable and preserves the independent call as a dropped result.
- `simplify-globals-optimizing keeps select operand values flowing into calls` mirrors the local Binaryen negative and keeps `$guard` mutable.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-call.wat -o -` reduced the fixture to immutable `$guard` plus `drop (call $foo)`.
- Local Binaryen negative probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-call-neg.wat -o -` kept `$guard` mutable and preserved `global.get`, `call $sink`, and `global.set`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select operand*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)` for the positive.
- Focused select-operand tests passed `2/2`; focused select tests passed `5/5`.
- `moon fmt` passed.
- Full SGO file passed `183/183`.
- `moon test src/passes` passed `4332/4332`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-select-call-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-call-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.569/2.090 ms` (`0.272x`), `runtime-set-get-1000f` `0.591/4.171 ms` (`0.142x`), `read-only-select-1000f` `2.669/4.780 ms` (`0.558x`), `initializer-fold-1000g` `0.581/1.133 ms` (`0.513x`), and `startup-offsets-1000e` `0.907/1.214 ms` (`0.747x`).

Status after this slice: the result-`if` arm includes direct-read, pure-arm, pure-post-result, and function-level if-return value-flow subsets. The side-effecting `select`, `select` through `i32.eqz`, independent-call select operand, nested-thrice same-pattern, and multi-global nested-body subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Select independent-memory operand FlowScanner slice

A later recursive continuation implemented one more source-backed Binaryen `FlowScanner` positive family: the guarded global is a `select` operand while an independent memory operation supplies the other operand, and the selected value only reaches the final same-global guarded write. Local Binaryen probes reduced `global.get $guard; memory.size; const; select; if { const; global.set $guard }` to immutable `$guard` plus `nop`, and reduced `global.get $guard; const; memory.grow; const; select; if { const; global.set $guard }` to immutable `$guard` plus `drop (memory.grow (i32.const 0))`. A paired negative where `$guard` flows into the `memory.grow` delta kept `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_select_operand_independent_memory_read_at(...)`, deliberately narrow to the empty-stack direct `select` operand shape.
- Accepted `memory.size` as an independent removable operand and constant-delta `memory.grow` as an independent side-effecting operand; values flowing into `memory.grow` remain rejected.
- Extended SGO cheap cleanup for the now-empty select/if shell: `memory.size` is removed with the shell, while `memory.grow` is preserved as `memory.grow; drop`.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes select operand read with independent memory ops` failed before implementation because `$guard` stayed mutable; after implementation it makes `$guard` immutable, removes the independent `memory.size` shell, and preserves constant-delta `memory.grow` as a dropped side effect.
- `simplify-globals-optimizing keeps select operand values flowing into memory.grow` mirrors the local Binaryen negative and keeps `$guard` mutable when the global-derived value is consumed by `memory.grow`.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probes: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-size.wat -o -` reduced to immutable `$guard` plus `nop`; `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-grow.wat -o -` reduced to immutable `$guard` plus `drop (memory.grow (i32.const 0))`.
- Local Binaryen negative probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-grow-neg.wat -o -` kept `$guard` mutable.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select operand*memory*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)` for the positive, then passed `2/2`.
- Focused select tests passed `7/7`.
- `moon fmt` passed.
- Full SGO file passed `185/185`.
- `moon test src/passes` passed `4334/4334`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-select-memory-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-memory-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.522/1.855 ms` (`0.281x`), `runtime-set-get-1000f` `0.531/3.326 ms` (`0.160x`), `read-only-select-1000f` `1.830/4.279 ms` (`0.428x`), `initializer-fold-1000g` `0.519/1.069 ms` (`0.485x`), and `startup-offsets-1000e` `0.873/1.183 ms` (`0.738x`).

Status after this slice: the result-`if` arm includes direct-read, pure-arm, pure-post-result, and function-level if-return value-flow subsets. The side-effecting `select`, `select` through `i32.eqz`, independent-call select operand, independent memory-op select operand, nested-thrice same-pattern, and multi-global nested-body subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Select second-operand independent-call cleanup slice

A later recursive continuation covered the symmetric independent-call select operand order: a zero-parameter/result call supplies the first `select` operand, the guarded global supplies the second operand, a constant supplies the select condition, and the selected value reaches only the final same-global guarded write. Local Binaryen reduced `call $foo; global.get $guard; const; select; if { const; global.set $guard }` to immutable `$guard` plus `drop (call $foo)`.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- The existing generic post-read `select` scan already counted this read as safe once the global appeared as the second select operand.
- Added SGO cheap cleanup for the SGO-created shell `call; i32.const <init>; const; select; empty-if`, preserving the independent call as `call; drop` when the call has zero parameters and one result.
- Kept the existing call-parameter negative: values flowing into `call $sink` remain rejected by the source-backed guardrail.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes select second operand read with independent call` failed red before cleanup because the global became immutable but the effect-preserving `drop` was missing and an inert empty `if` shell remained.
- After implementation, the function preserves the independent call as a dropped result and removes the `select`, empty `if`, `global.get`, and `global.set` traffic.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-call-second.wat -o -` reduced the fixture to immutable `$guard` plus `drop (call $foo)`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select second operand*'` failed before implementation because `drop` was missing; after implementation it passed `1/1`.
- Focused select tests passed `8/8`.
- `moon fmt` passed.
- Full SGO file passed `186/186`.
- `moon test src/passes` passed `4335/4335`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-select-second-call-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-second-call-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.512/1.692 ms` (`0.303x`), `runtime-set-get-1000f` `0.524/3.091 ms` (`0.169x`), `read-only-select-1000f` `1.723/4.230 ms` (`0.407x`), `initializer-fold-1000g` `0.480/1.057 ms` (`0.455x`), and `startup-offsets-1000e` `0.782/1.120 ms` (`0.698x`).

Status after this slice: the result-`if` arm includes direct-read, pure-arm, pure-post-result, and function-level if-return value-flow subsets. The side-effecting `select`, `select` through `i32.eqz`, independent-call select operands in both direct operand orders, independent memory-op select operand, nested-thrice same-pattern, and multi-global nested-body subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Select second-operand independent-memory cleanup slice

A later recursive continuation covered the symmetric independent memory-op select operand order: `memory.size` or constant-delta `memory.grow` supplies the first `select` operand, the guarded global supplies the second operand, a constant supplies the select condition, and the selected value reaches only the final same-global guarded write. Local Binaryen reduced `memory.size; global.get $guard; const; select; if { const; global.set $guard }` to immutable `$guard` plus `nop`, and reduced `const; memory.grow; global.get $guard; const; select; if { const; global.set $guard }` to immutable `$guard` plus `drop (memory.grow (i32.const 0))`.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- The existing generic post-read `select` scan already counted these reads as safe once the global appeared as the second select operand.
- Added SGO cheap cleanup for the SGO-created shells `memory.size; i32.const <init>; const; select; empty-if` and `const; memory.grow; i32.const <init>; const; select; empty-if`.
- The cleanup removes independent `memory.size` and preserves constant-delta `memory.grow` as `memory.grow; drop`, matching local Binaryen output while keeping the existing global-to-`memory.grow` negative guardrail.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes select second operand read with independent memory ops` failed red before cleanup because `memory.size` and an empty `if` shell remained.
- After implementation, the `memory.size` variant removes `memory.size`, `select`, `global.get`, and `global.set`; the `memory.grow` variant preserves the grow effect as a dropped result and removes the select/if/global shell.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probes: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-size-second.wat -o -` reduced to immutable `$guard` plus `nop`; `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-operand-memory-grow-second.wat -o -` reduced to immutable `$guard` plus `drop (memory.grow (i32.const 0))`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select second operand*memory*'` failed before implementation with leftover `memory.size` / empty `if`, then passed `1/1`.
- Focused select tests passed `9/9`.
- `moon fmt` passed.
- Full SGO file passed `187/187`.
- `moon test src/passes` passed `4336/4336`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-select-second-memory-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-second-memory-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.496/1.515 ms` (`0.327x`), `runtime-set-get-1000f` `0.518/2.665 ms` (`0.194x`), `read-only-select-1000f` `1.664/3.625 ms` (`0.459x`), `initializer-fold-1000g` `0.440/1.012 ms` (`0.434x`), and `startup-offsets-1000e` `0.779/1.164 ms` (`0.669x`).

Status after this slice: the result-`if` arm includes direct-read, pure-arm, pure-post-result, and function-level if-return value-flow subsets. The side-effecting `select`, `select` through `i32.eqz`, independent-call and independent memory-op select operands in both direct operand orders, the block-prefix independent-call condition subset, nested-thrice same-pattern, and multi-global nested-body subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Block-prefix independent-call FlowScanner slice

A later recursive continuation implemented another source-backed Binaryen `FlowScanner` positive: a result block condition evaluates an independent zero-parameter/result call, drops it, then yields the guarded `global.get`; that yielded value reaches only the final same-global guarded write. A local Binaryen probe with `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-block-independent-call-before-get.wat -o -` reduced the fixture to immutable `$g` plus `drop (call $foo)`. A paired negative with the global-derived value flowing into a call parameter before the final read (`.tmp/sgo-block-prefix-call-neg.wat`) kept `$g` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added a narrow block-condition recognizer for `block (result i32) { call $foo; drop; global.get $g }` followed by `if { const; global.set $g }`, gated on the call having zero parameters and one result.
- Added SGO cheap cleanup for the resulting `block { call; drop; const } ; empty-if` shell, preserving the independent call as `call; drop`.
- Kept flow-into-call guardrails: values passed to call parameters remain rejected and keep the global mutable.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes block prefix independent call read-only-to-write guards` failed before implementation because `$once` stayed mutable; after implementation it makes `$once` immutable and preserves only the independent `call; drop` effect.
- `simplify-globals-optimizing keeps block prefix values flowing into calls` mirrors the local Binaryen negative and keeps `$once` mutable when the global-derived value is consumed by a call parameter.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-block-independent-call-before-get.wat -o -` reduced to immutable `$g` plus `drop (call $foo)`.
- Local Binaryen negative probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-block-prefix-call-neg.wat -o -` kept `$g` mutable.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix independent call*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)`.
- Focused block-prefix tests passed `2/2` after implementation.
- `moon fmt` passed.
- Full SGO file passed `189/189`.
- `moon test src/passes` passed `4338/4338`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-call-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-call-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.882/2.115 ms` (`0.417x`), `runtime-set-get-1000f` `0.930/4.035 ms` (`0.231x`), `read-only-select-1000f` `3.018/4.773 ms` (`0.632x`), `initializer-fold-1000g` `0.661/1.439 ms` (`0.459x`), and `startup-offsets-1000e` `0.871/1.399 ms` (`0.622x`).

Status after this slice: the result-`if` arm includes direct-read, pure-arm, pure-post-result, and function-level if-return value-flow subsets. The side-effecting `select`, `select` through `i32.eqz`, independent-call and independent memory-op select operands in both direct operand orders, block-prefix independent-call condition subset and if-return variant, nested-thrice same-pattern, and multi-global nested-body subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.


## If-return block-prefix independent-call FlowScanner slice

A later recursive continuation extended the block-prefix independent-call subset into Binaryen's function-level `if return; set` matcher. Because Binaryen calls the same `readsGlobalOnlyToWriteIt` helper from both `visitIf` and `visitFunction`, a condition shaped as `block (result i32) { call $foo; drop; global.get $once }` is safe when the call has zero parameters and one result, the yielded global value only controls `if { return }`, and the function tail is the final same-global constant write. Local Binaryen reduced `.tmp/sgo-ifreturn-block-prefix-call.wat` to immutable `$once` plus `drop (call $foo)`. The paired `.tmp/sgo-ifreturn-block-prefix-call-neg.wat` kept `$once` mutable when the global-derived value was passed to a call parameter.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added a narrow if-return recognizer for `block { call; drop; global.get }; if return; const; global.set`, gated on the call having zero parameters and one result and the tail being the same-global constant write.
- Added SGO cheap cleanup for the resulting `block { call; drop; const }; if return; const; drop` shell, preserving the independent call as `call; drop`.
- Kept the call-parameter guardrail: values consumed by a call parameter remain unsafe and keep the global mutable.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes if-return block prefix independent call guards` failed red before implementation because `$once` stayed mutable; after implementation it makes `$once` immutable and leaves only `call; drop`.
- `simplify-globals-optimizing keeps if-return block prefix values flowing into calls` mirrors the local Binaryen negative and keeps `$once` mutable.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-ifreturn-block-prefix-call.wat -o -` reduced to immutable `$once` plus `drop (call $foo)`.
- Local Binaryen negative probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-ifreturn-block-prefix-call-neg.wat -o -` kept `$once` mutable.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-return block prefix*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)`, then passed `2/2` after implementation.
- Focused block-prefix tests passed `4/4`.
- `moon fmt` passed.
- Full SGO file passed `191/191`.
- `moon test src/passes` passed `4340/4340`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-ifreturn-block-prefix-call-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-ifreturn-block-prefix-call-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.498/1.517 ms` (`0.328x`), `runtime-set-get-1000f` `0.517/2.719 ms` (`0.190x`), `read-only-select-1000f` `1.694/3.452 ms` (`0.491x`), `initializer-fold-1000g` `0.437/0.981 ms` (`0.445x`), and `startup-offsets-1000e` `0.804/1.087 ms` (`0.740x`).

Status after this slice: the result-`if` arm includes direct-read, pure-arm, pure-post-result, and function-level if-return value-flow subsets. The side-effecting `select`, `select` through `i32.eqz`, independent-call and independent memory-op select operands in both direct operand orders, block-prefix independent-call condition subset and if-return variant, nested-thrice same-pattern, and multi-global nested-body subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Result-if-arm if-return FlowScanner slice

A later recursive continuation extended the source-backed safe-side-effect result-`if` arm subset into Binaryen's function-level `if return; set` matcher. Because Binaryen's `visitFunction` calls the same `readsGlobalOnlyToWriteIt` helper as the ordinary guarded-write `visitIf` path, a condition shaped as a side-effecting result `if` is safe when the guarded global is read in one arm, the other arm's side effects are independent of that global value, the result reaches only the return guard, and the function tail is the final same-global constant write. Local Binaryen reduced `.tmp/sgo-ifarm-ifreturn.wat` to immutable `$once` plus `drop (call $foo)`. The paired `.tmp/sgo-ifarm-ifreturn-neg.wat` kept `$once` mutable when the result flowed into `local.tee` before the return guard.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_count_if_arm_condition_if_return_read(...)`, reusing the existing result-if-arm safe-read recognizer and requiring only pure post-result operators before the return guard.
- Reused `sgo_if_return_tail_matches(...)` so the accepted tail remains exactly the existing same-global constant write or block-wrapped constant write forms.
- Kept arbitrary post-result side effects rejected; the new focused negative keeps `local.tee` unsafe.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes safe-side-effect if-arm if-return guards` failed red before implementation because `$once` stayed mutable; after implementation it makes `$once` immutable and removes the global get/set traffic while preserving the independent call.
- `simplify-globals-optimizing keeps if-arm if-return values flowing into side effects` mirrors the local Binaryen negative and keeps `$once` mutable when the global-derived result flows into `local.tee`.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-ifarm-ifreturn.wat -o -` reduced to immutable `$once` plus `drop (call $foo)`.
- Local Binaryen negative probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-ifarm-ifreturn-neg.wat -o -` kept `$once` mutable.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm if-return*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)`, then passed `2/2` after implementation.
- Focused if-arm tests passed `7/7`.
- `moon fmt` passed.
- Full SGO file passed `193/193`.
- `moon test src/passes` passed `4342/4342`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-ifarm-ifreturn-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-ifarm-ifreturn-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.512/1.564 ms` (`0.327x`), `runtime-set-get-1000f` `0.522/2.877 ms` (`0.181x`), `read-only-select-1000f` `1.703/3.606 ms` (`0.472x`), `initializer-fold-1000g` `0.461/1.049 ms` (`0.439x`), and `startup-offsets-1000e` `0.839/1.190 ms` (`0.706x`).

Status after this slice: the result-`if` arm includes direct-read, pure-arm, pure-post-result, and function-level if-return value-flow subsets. The side-effecting `select`, `select` through `i32.eqz`, independent-call and independent memory-op select operands in both direct operand orders, block-prefix independent-call condition subset and if-return variant, nested-thrice same-pattern, and multi-global nested-body subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Nested result-if-arm FlowScanner slice

A later recursive continuation implemented one more source-backed Binaryen `FlowScanner` positive beyond the direct result-`if` arm subset: an outer side-effecting result `if` whose value-producing arm is itself a side-effecting result `if`, where the inner side-effecting condition is independent of globals and the guarded-global value is yielded only from one inner arm to the final same-global guarded write. A local Binaryen probe with `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-nested-ifarm.wat -o -` reduced the fixture to immutable `$once` plus preserved independent calls.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Extended `sgo_block_condition_safe_arm_read_idx(...)` so a result-if arm may end in one nested result `if` after a prefix with no global references.
- Reused the existing `sgo_if_arm_condition_read_idx(...)` arm-local safe-read recognizer for the nested result `if`, keeping arbitrary global-dependent prefixes and value-flow into side-effecting parents rejected.
- Kept the subset deliberately narrow; it does not claim full Binaryen `FlowScanner` equivalence for arbitrary nesting, unrelated global reads, or side-effecting parents that consume the guarded-global value.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes nested safe-side-effect if-arm read-only-to-write guards` failed red before implementation because `$once` stayed mutable; after implementation `$once` becomes immutable and all `$once` `global.get` / `global.set` traffic disappears while independent calls remain.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positive probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-nested-ifarm.wat -o -` reduced to immutable `$once` plus preserved independent calls.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*nested safe-side-effect if-arm*'` failed before implementation with `GlobalType(..., true) != GlobalType(..., false)`, then passed `1/1` after implementation.
- Focused if-arm tests passed `8/8`.
- `moon fmt` passed.
- Full SGO file passed `194/194`.
- `moon test src/passes` passed `4343/4343`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-nested-ifarm-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-nested-ifarm-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.522/1.606 ms` (`0.325x`), `runtime-set-get-1000f` `0.519/2.823 ms` (`0.184x`), `read-only-select-1000f` `1.678/3.499 ms` (`0.479x`), `initializer-fold-1000g` `0.443/1.026 ms` (`0.432x`), and `startup-offsets-1000e` `0.861/0.996 ms` (`0.864x`).

Status after this slice: the result-`if` arm includes direct-read, pure-arm, pure-post-result, function-level if-return, nested result-if-arm value-flow, and nested result-if-arm pure-suffix subsets. The side-effecting `select`, `select` through `i32.eqz`, independent-call and independent memory-op select operands in both direct operand orders, block-prefix independent-call condition subset and if-return variant, nested-thrice same-pattern, and multi-global nested-body subsets are implemented. Broad `FlowScanner` equivalence still remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Nested result-if-arm pure-suffix FlowScanner slice

A later recursive continuation widened the narrow nested result-if-arm subset. A local Binaryen `version_130` probe reduced `.tmp/sgo-probe2.wat`, where an outer side-effecting result `if` has an arm that runs an independent no-global prefix (`call $bar`), evaluates a nested result `if` whose selected arm yields `$once`, then applies pure suffix operators (`i32.const 4; i32.add`) before the final same-global guarded write. Binaryen made `$once` immutable and preserved the independent effects.

Implementation changes:

- `src/passes/simplify_globals_optimizing.mbt`
  - `sgo_block_condition_safe_arm_read_idx(...)` now looks for a nested result `if` after a prefix with no global references and allows pure suffix operators after the nested result before returning the guarded-global read index.
  - The shape remains intentionally narrow: prefixes that reference globals, value flow into `local.tee`, calls, `memory.grow` deltas, trapping-load addresses, or other side-effecting suffix consumers remain outside this subset and keep the broader `FlowScanner` gap open.
- `src/passes/simplify_globals_optimizing_test.mbt`
  - added `simplify-globals-optimizing removes nested if-arm values through pure operators`; it failed before implementation because `$once` stayed mutable, then passed after the recognizer change.

Validation and evidence:

- Local Binaryen positive: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe2.wat -o -` reduced `$once` to immutable state while preserving independent effects.
- Focused red/green: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*nested if-arm values through pure operators*'` failed before implementation and passed after it.
- `moon fmt` passed.
- Focused if-arm tests: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*if-arm*'` passed `9/9`.
- Full SGO test file: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt` passed `195/195`.
- `moon test src/passes` passed `4344/4344`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` unused-function warnings.
- Regular GenValid smoke `.tmp/pass-fuzz-sgo-nested-ifarm-pure-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-nested-ifarm-pure-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.544/1.728 ms` (`0.315x`), `runtime-set-get-1000f` `0.556/3.269 ms` (`0.170x`), `read-only-select-1000f` `1.800/3.850 ms` (`0.467x`), `initializer-fold-1000g` `0.512/1.161 ms` (`0.441x`), and `startup-offsets-1000e` `1.408/1.544 ms` (`0.912x`).

Status after this slice: implemented FlowScanner/body subsets now include safe-side-effect result-`if` arm direct-read, pure-arm, pure-post-result, function-level if-return, nested result-if-arm, and nested result-if-arm pure-suffix subsets; side-effecting `select`, `select` through `i32.eqz`, independent-call and independent memory-op `select` operands in both direct operand orders; block-prefix independent-call guarded-write and if-return variants; nested-thrice same-pattern; and multi-global nested-body subsets. Broad generic Binaryen `FlowScanner` equivalence remains open, and final closeout still needs a freshness decision or rerun for the older full four-lane matrix after the latest narrow additions.

## Select-eqz if-return FlowScanner slice

A later recursive continuation extended the official side-effecting `select; i32.eqz` FlowScanner subset into Binaryen's function-level `if return; set` matcher. A local Binaryen `version_130` probe reduced `.tmp/sgo-select-ifreturn.wat`, where an independent `i32.load` / unused `local.tee` supplies a `select` operand and the guarded-global value flows only through the `select` condition, `i32.eqz`, and a return guard before the final same-global constant write. Binaryen made `$guard` immutable and preserved the independent load as `drop (i32.load ...)`.

Implementation changes:

- `src/passes/simplify_globals_optimizing.mbt`
  - added `sgo_read_only_to_write_if_return_value_read_at(...)` so a global-derived value can flow through pure operators and a `select` to a return guard when the remaining tail is exactly the existing same-global constant-write form;
  - extended SGO cheap cleanup for the resulting `select; i32.eqz; if return` shell, reducing the accepted independent load/local.tee form to `i32.load; drop` only when the matched shell reaches the end of the function after the fake write is removed.
- `src/passes/simplify_globals_optimizing_test.mbt`
  - added `simplify-globals-optimizing removes side-effecting select eqz if-return guards`; it failed before implementation because `$guard` stayed mutable, then passed after the recognizer and cleanup changes.

Validation and evidence:

- Local Binaryen positive: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-select-ifreturn.wat -o -` reduced `$guard` to immutable state and preserved `drop (i32.load (i32.const 2))`.
- Focused red/green: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select eqz if-return*'` failed before implementation and passed after it.
- `moon fmt` passed.
- Focused select tests: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select*'` passed `10/10`.
- Full SGO test file: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt` passed `196/196`.
- `moon test src/passes` passed `4345/4345`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` unused-function warnings.
- Regular GenValid smoke `.tmp/pass-fuzz-sgo-select-ifreturn-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-select-ifreturn-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.501/1.568 ms` (`0.319x`), `runtime-set-get-1000f` `0.518/2.960 ms` (`0.175x`), `read-only-select-1000f` `1.719/3.537 ms` (`0.486x`), `initializer-fold-1000g` `0.437/1.001 ms` (`0.437x`), and `startup-offsets-1000e` `0.751/1.069 ms` (`0.703x`).

Status after this slice: implemented FlowScanner/body subsets now include safe-side-effect result-`if` arm direct-read, pure-arm, pure-post-result, function-level if-return, nested result-if-arm, and nested result-if-arm pure-suffix subsets; side-effecting `select`, `select` through `i32.eqz` for guarded-write and if-return tails; independent-call and independent memory-op `select` operands in both direct operand orders; block-prefix independent-call guarded-write and if-return variants; nested-thrice same-pattern; and multi-global nested-body subsets. Broad generic Binaryen `FlowScanner` equivalence remains open, and final closeout still needs a freshness decision or rerun for the older full four-lane matrix after the latest narrow additions.

## Select independent-call and memory-op if-return FlowScanner slices

A later recursive continuation implemented two more source-backed Binaryen `FlowScanner` positives in the function-level `if return; set` matcher:

- independent zero-parameter/result call as the non-global `select` operand: local Binaryen reduced `.tmp/sgo-select-call-ifreturn.wat` to immutable `$guard` plus `drop (call $foo)`;
- independent memory op as the non-global `select` operand: local Binaryen reduced `.tmp/sgo-select-memory-ifreturn.wat` for first/second operand `memory.size` and constant-delta `memory.grow` forms to immutable `$guard`, deleting `memory.size` shells and preserving `memory.grow` as `drop (memory.grow (i32.const 0))`.

Implementation changes:

- `src/passes/simplify_globals_optimizing.mbt` now lets the narrow first-operand independent-call and independent-memory `select` recognizers accept `select; if { return }; const; global.set` tails using the existing same-global return-tail matcher.
- SGO cheap cleanup now rewrites the resulting call shell to `call; drop`, removes the `memory.size` shell, and preserves constant-delta `memory.grow` as `memory.grow; drop` for first/second direct operand orders.
- Existing negatives for values flowing into call parameters and global-derived `memory.grow` deltas remain the guardrails; this is still not broad arbitrary Binaryen `FlowScanner` equivalence.

Validation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select operand if-return read with independent call*'` failed before implementation because `$guard` stayed mutable; after implementation it passed.
- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*select operand if-return read with independent memory ops*'` failed before implementation because `$guard` stayed mutable; after implementation it passed.
- `moon fmt` passed.
- Focused select tests passed `12/12` after both slices.
- Full SGO tests passed `198/198`.
- `moon test src/passes` passed `4347/4347`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-select-call-ifreturn-genvalid-1000`: `1000/1000` compared and normalized, zero mismatches/failures.
- Dedicated SGO smoke `.tmp/pass-fuzz-sgo-select-call-ifreturn-dedicated-1000`: `1000/1000` compared and normalized, zero mismatches/failures.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-select-memory-ifreturn-genvalid-1000`: `1000/1000` compared and normalized, zero mismatches/failures.
- Dedicated SGO smoke `.tmp/pass-fuzz-sgo-select-memory-ifreturn-dedicated-1000`: `1000/1000` compared and normalized, zero mismatches/failures.
- Representative timing remains under the user-required 1x Binaryen bar after the memory-op if-return slice: `const-read-1000f` `0.516/1.655 ms` (`0.312x`), `runtime-set-get-1000f` `0.544/2.813 ms` (`0.193x`), `read-only-select-1000f` `1.724/3.868 ms` (`0.446x`), `initializer-fold-1000g` `0.433/0.990 ms` (`0.437x`), and `startup-offsets-1000e` `0.766/1.057 ms` (`0.725x`).

Status after this slice: the implemented FlowScanner/body subsets now include the independent-call and independent memory-op `select` operand if-return variants, in addition to the previously listed result-if-arm, select, select-eqz, block-prefix, nested-thrice, and multi-global nested-body subsets. Broad generic FlowScanner equivalence and final full-matrix freshness remain open.

## Direct side-effecting select if-return cleanup slice

A later continuation implemented the no-`i32.eqz` function-level if-return variant of the side-effecting independent-load `select` shape. Local Binaryen reduced `.tmp/sgo-select-load-ifreturn.wat`, where an independent `i32.load` / unused local shell supplies a `select` operand and the selected value reaches only `if { return }` before the same-global constant write, to immutable `$guard` plus `drop (i32.load (i32.const 2))`.

Implementation changes:

- `src/passes/simplify_globals_optimizing.mbt` keeps the already-safe value-flow recognition and extends SGO cheap cleanup for the direct `select; if return` load shell, including the pre-nested local shell and the nested-cleanup residual without the local shell.
- The subset remains narrow: it preserves only independent load effects with constant addresses from the generated/Binaryen-probed shape, and existing trapping load-address plus local-side-effect guardrails remain intact.

Validation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*side-effecting select if-return guards*'` failed before implementation because the final function still contained `select; if return`.
- After implementation, the focused test passed `1/1`.
- `moon fmt` passed.
- Focused select tests passed `13/13`.
- Full SGO tests passed `199/199`.
- `moon test src/passes` passed `4348/4348`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-select-load-ifreturn-genvalid-1000`: `1000/1000` compared and normalized, zero mismatches/failures.
- Dedicated SGO smoke `.tmp/pass-fuzz-sgo-select-load-ifreturn-dedicated-1000`: `1000/1000` compared and normalized, zero mismatches/failures.
- Representative timing remains under the user-required 1x Binaryen bar: `const-read-1000f` `0.802/2.764 ms` (`0.290x`), `runtime-set-get-1000f` `0.977/4.412 ms` (`0.221x`), `read-only-select-1000f` `1.865/4.876 ms` (`0.382x`), `initializer-fold-1000g` `0.508/1.165 ms` (`0.436x`), and `startup-offsets-1000e` `1.090/1.557 ms` (`0.700x`).

## Block-prefix independent memory-op FlowScanner slice

A later recursive continuation extended the source-backed block-prefix independent-effect condition subset from calls to memory operations. A local Binaryen probe with `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-block-prefix-memory.wat -o -` reduced both guarded-write and function-level if-return variants to immutable `$guard`; `memory.size` shells disappeared and constant-delta `memory.grow` was preserved as `drop (memory.grow (i32.const 0))`.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- added a narrow block-condition recognizer for `memory.size; drop; global.get $g` and `const; memory.grow; drop; global.get $g` result blocks;
- counted those reads as read-only-to-write-safe for both `if { global.set $g const }` and `if { return }; const; global.set $g` tails;
- extended SGO cheap cleanup to remove the resulting `memory.size` / empty-if shell and preserve constant-delta `memory.grow` as `memory.grow; drop`;
- kept global-derived `memory.grow` deltas rejected with a focused guardrail.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes block prefix independent memory guards` failed red before implementation because `$once` stayed mutable, then passed after the guarded-write recognizer and cleanup landed.
- `simplify-globals-optimizing removes if-return block prefix independent memory guards` failed red before implementation because `$once` stayed mutable, then passed after the return-tail variant landed.
- `simplify-globals-optimizing keeps block prefix values flowing into memory.grow` keeps the global mutable when the guarded-global value is consumed as the `memory.grow` delta.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Focused block-prefix memory tests passed `3/3`.
- Focused block-prefix tests passed `7/7`.
- `moon fmt` passed.
- Full SGO test file passed `202/202`.
- `moon test src/passes` passed `4351/4351`.
- Native `src/cmd` build passed with pre-existing `src/passes/pass_manager.mbt` unused-function warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-memory-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-memory-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Representative direct timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.550/1.962 ms` (`0.281x`), `runtime-set-get-1000f` `0.589/3.460 ms` (`0.170x`), `read-only-select-1000f` `2.061/4.349 ms` (`0.474x`), `initializer-fold-1000g` `0.520/1.146 ms` (`0.454x`), and `startup-offsets-1000e` `0.859/1.380 ms` (`0.622x`).

Status after this slice: block-prefix independent calls and memory ops are covered for guarded-write and if-return tails, while broad generic `FlowScanner` parent/child equivalence remains open. Final closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow FlowScanner additions.

## Block-prefix independent local-write FlowScanner slice

A later recursive continuation extended the source-backed block-prefix independent-effect condition subset from calls and memory ops to local writes. Local Binaryen accepted `const; local.set; global.get $guard` result-block conditions for both guarded-write and function-level `if return; set` tails, reducing `$guard` to immutable state; it rejected the paired negative where `$guard` flows into the local write before the final same-global read.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- added a narrow block-condition recognizer for `const; local.set; global.get $g` and `const; local.tee; drop; global.get $g` result blocks;
- counted those reads as read-only-to-write-safe for both `if { const; global.set $g }` and `if { return }; const; global.set $g` tails;
- extended SGO cheap cleanup to delete the fake global guard shell while preserving the independent local write as `const; local.set`;
- kept global-derived local writes rejected with a focused guardrail.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes block prefix independent local writes` failed red before implementation because `$once` stayed mutable, then passed after the guarded-write recognizer and cleanup landed.
- `simplify-globals-optimizing removes if-return block prefix independent local writes` failed red before implementation because `$once` stayed mutable, then passed after the return-tail variant landed.
- `simplify-globals-optimizing keeps block prefix values flowing into local writes` keeps the global mutable when the guarded-global value is consumed by `local.set`.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Focused block-prefix local tests passed `3/3`.
- Focused block-prefix tests passed `10/10`.
- `moon fmt` passed.
- Full SGO test file passed `205/205`.
- `moon test src/passes` passed `4354/4354`.
- Native `src/cmd` build passed with pre-existing `src/passes/pass_manager.mbt` unused-function warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-local-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-local-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Representative direct timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.504/1.532 ms` (`0.329x`), `runtime-set-get-1000f` `0.532/2.764 ms` (`0.193x`), `read-only-select-1000f` `1.729/3.285 ms` (`0.526x`), `initializer-fold-1000g` `0.452/1.008 ms` (`0.448x`), and `startup-offsets-1000e` `0.742/1.066 ms` (`0.697x`).

Status after this slice: block-prefix independent calls, memory ops, and local writes are covered for guarded-write and if-return tails, while broad generic `FlowScanner` parent/child equivalence remains open. Final closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow FlowScanner additions.

## Block-prefix independent global-write FlowScanner slice

A later recursive continuation extended the source-backed block-prefix independent-effect condition subset from calls, memory ops, and local writes to independent global writes. Local Binaryen accepted `block { i32.const 7; global.set $other; global.get $guard }; if { const; global.set $guard }` when `$other` was exported and observable, preserving the `$other` write while reducing `$guard` to immutable state. It accepted the equivalent function-level `if { return }; const; global.set $guard` tail and rejected the paired negative where `$guard` flowed into `global.set $other` before the final same-global read.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- added a narrow block-condition recognizer for `const; global.set $other; global.get $guard`, requiring `$other != $guard` and a constant stored value;
- counted that read as read-only-to-write-safe for both direct guarded-write and function-level if-return tails;
- extended SGO cheap cleanup to delete the fake guard shell while preserving the independent `global.set $other` write;
- kept global-derived values flowing into the independent global write rejected with focused coverage.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes block prefix independent global writes` failed red before implementation because `$once` stayed mutable, then passed after the guarded-write recognizer and cleanup landed.
- `simplify-globals-optimizing removes if-return block prefix independent global writes` failed red before implementation because `$once` stayed mutable, then passed after the return-tail variant landed.
- `simplify-globals-optimizing keeps block prefix values flowing into global writes` keeps the global mutable when the guarded-global value is consumed by `global.set $other`.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Focused block-prefix global tests passed `3/3`.
- Focused block-prefix tests passed `13/13`.
- `moon fmt` passed.
- Full SGO test file passed `208/208`.
- `moon test src/passes` passed `4357/4357`.
- Native `src/cmd` build passed with pre-existing `src/passes/pass_manager.mbt` unused-function warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-global-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-global-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Representative direct timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.542/1.842 ms` (`0.295x`), `runtime-set-get-1000f` `0.571/3.160 ms` (`0.181x`), `read-only-select-1000f` `1.857/4.093 ms` (`0.454x`), `initializer-fold-1000g` `0.471/1.038 ms` (`0.454x`), and `startup-offsets-1000e` `0.798/1.143 ms` (`0.698x`).

Status after this slice: block-prefix independent calls, memory ops, local writes, and global writes are covered for guarded-write and if-return tails before the later table-op slice, while broad generic `FlowScanner` parent/child equivalence remains open. Final closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow FlowScanner additions.

## Block-prefix independent table-op FlowScanner slice

A later 2026-07-06 recursive continuation extended the source-backed block-prefix independent-effect condition subset from calls, memory ops, local writes, and global writes to table operations.

Local Binaryen `version_130` behavior probes:

- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tablesize.wat -o -` reduced `block { table.size; drop; global.get $guard }; if { const; global.set $guard }` to immutable `$guard` and removed the pure `table.size` shell.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tablegrow.wat -o -` reduced the exported-table `table.grow` variant to immutable `$guard` while preserving `drop (table.grow (ref.null func) (i32.const 0))`.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-ifreturn-block-prefix-tablegrow.wat -o -` reduced the function-level `if return; set` variant similarly.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tablegrow-neg.wat -o -` kept `$guard` mutable when `$guard` flowed into the `table.grow` delta.

Implementation changes:

- `src/passes/simplify_globals_optimizing.mbt` now counts the narrow `table.size; drop; global.get $guard` and `ref/null-or-const; const; table.grow; drop; global.get $guard` result-block condition forms as read-only-to-write-safe for direct guarded-write and function-level if-return tails.
- SGO cheap cleanup deletes the generated `table.size` shell and preserves independent `table.grow` as `ref.null; const; table.grow; drop` after the fake guard is removed.
- The recognizer stays deliberately narrow and does not accept guarded-global-derived `table.grow` operands.

Validation:

- Red-first focused positives failed before implementation because `$once` stayed mutable; after implementation `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*block prefix*table*'` passed `3/3`.
- `moon fmt` passed.
- Focused block-prefix tests passed `16/16`; full SGO file passed `211/211`.
- `moon test src/passes` passed `4360/4360`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular smoke `.tmp/pass-fuzz-sgo-block-prefix-table-genvalid-1000`: `1000/1000` compared and normalized, zero failures/mismatches.
- Dedicated smoke `.tmp/pass-fuzz-sgo-block-prefix-table-dedicated-1000`: `1000/1000` compared and normalized, zero failures/mismatches.
- Representative timing remains under the user-required 1x Binaryen bar: `const-read-1000f` `0.528/1.603 ms` (`0.329x`), `runtime-set-get-1000f` `0.539/2.835 ms` (`0.190x`), `read-only-select-1000f` `1.758/3.953 ms` (`0.445x`), `initializer-fold-1000g` `0.464/1.027 ms` (`0.452x`), and `startup-offsets-1000e` `0.756/1.090 ms` (`0.693x`).

Status after this slice: the block-prefix independent table-op subset is implemented and guarded. Broad generic Binaryen `FlowScanner` equivalence remains open, as do final freshness decisions for the older full-matrix lanes after these narrow FlowScanner additions.

## Block-prefix table.fill/table.copy FlowScanner slice

A later recursive continuation extended the block-prefix independent table-op subset beyond `table.size` and `table.grow` to constant-argument `table.fill` and `table.copy` forms. Local Binaryen `version_130` probes showed the following:

- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tablefill.wat -o -` reduces `block { i32.const 0; ref.func/ref.null; i32.const 1; table.fill; global.get $guard }; if { const; global.set $guard }` to immutable `$guard` while preserving `table.fill`.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tablecopy.wat -o -` reduces `block { const dest; const src; const len; table.copy; global.get $guard }; if { const; global.set $guard }` to immutable `$guard` while preserving `table.copy`.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-ifreturn-block-prefix-tablefill.wat -o -` and `.tmp/sgo-probe-ifreturn-block-prefix-tablecopy.wat` reduce the function-level `if return; set` variants the same way.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tablefill-neg.wat -o -` keeps `$guard` mutable when `$guard` flows into the `table.fill` destination.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_block_condition_independent_table_final_read_idx(...)` now accepts only constant-argument `table.fill` and `table.copy` block-condition prefixes before the final guarded-global read.
- SGO cheap cleanup preserves independent `table.fill` and `table.copy` operations while deleting the now-empty guarded-write or if-return shell.
- The existing `table.grow` value-flow guardrail remains, and the new `table.fill` guardrail prevents global-derived table arguments from being counted as safe.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes block prefix independent table fill and copy guards`
- `simplify-globals-optimizing removes if-return block prefix independent table fill and copy guards`
- `simplify-globals-optimizing keeps block prefix values flowing into table.fill`

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Red-first focused positives: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*table fill*'` failed before implementation with `$once` still mutable, then passed `2/2` after implementation.
- `moon fmt` passed.
- Focused table tests passed `11/11`.
- Full SGO file passed `214/214`.
- `moon test src/passes` passed `4363/4363`.
- Native `src/cmd` build passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-tablefill-copy-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-tablefill-copy-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.506/1.606 ms` (`0.315x`), `runtime-set-get-1000f` `0.530/3.013 ms` (`0.176x`), `read-only-select-1000f` `1.735/3.526 ms` (`0.492x`), `initializer-fold-1000g` `0.455/1.088 ms` (`0.418x`), and `startup-offsets-1000e` `0.992/1.193 ms` (`0.832x`).

Status after this slice: block-prefix independent table-op coverage included `table.size`, `table.grow`, constant-argument `table.fill`, and constant-argument `table.copy` for guarded-write and if-return tails. This snapshot was superseded later in this note by the table.set/table.init/elem.drop slice. Broader arbitrary `FlowScanner` parent/child value-flow equivalence, non-constant table arguments, and table arguments derived from the guarded global remained open. Final SGO closeout still needed the broader transform-family classification plus freshness decisions for older full-matrix lanes after the narrow FlowScanner additions.

## Block-prefix table.set/table.init/elem.drop FlowScanner slice

A later recursive continuation extended the block-prefix independent table-op subset beyond `table.size`, `table.grow`, constant-argument `table.fill`, and constant-argument `table.copy` to the remaining source-backed independent table/element mutation forms that local Binaryen accepts when all stack operands are constants.

Local Binaryen `version_130` probes showed the following:

- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tableset.wat -o -` reduces `block { const dest; ref.null func; table.set; global.get $guard }; if { const; global.set $guard }` to immutable `$guard` while preserving `table.set`.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-ifreturn-block-prefix-tableset.wat -o -` reduces the function-level `if return; set` variant the same way.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tableset-neg.wat -o -` keeps `$guard` mutable when `$guard` flows into the `table.set` destination.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tableinit.wat -o -` reduces `block { const dest; const src; const len; table.init; global.get $guard }; if { const; global.set $guard }` to immutable `$guard` while preserving `table.init`.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-elemdrop.wat -o -` reduces `block { elem.drop; global.get $guard }; if { const; global.set $guard }` to immutable `$guard` while preserving `elem.drop`.
- `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probe-block-prefix-tableinit-neg.wat -o -` keeps `$guard` mutable when `$guard` flows into the `table.init` destination.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_block_condition_independent_table_final_read_idx(...)` now accepts only constant-argument `table.set` and `table.init` prefixes plus argument-free `elem.drop` before the final guarded-global read.
- SGO cheap cleanup preserves independent `table.set`, `table.init`, and `elem.drop` operations while deleting the now-empty guarded-write or if-return shell.
- Existing value-flow guardrails stay narrow: guarded-global values flowing into table operation stack operands keep the guarded global mutable.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes block prefix independent table.set guards`
- `simplify-globals-optimizing removes if-return block prefix independent table.set guards`
- `simplify-globals-optimizing keeps block prefix values flowing into table.set`
- `simplify-globals-optimizing removes block prefix independent table.init and elem.drop guards`
- `simplify-globals-optimizing removes if-return block prefix independent table.init and elem.drop guards`
- `simplify-globals-optimizing keeps block prefix values flowing into table.init`

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Red-first focused positives: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*table.set*'` failed before implementation with `$once` still mutable, then passed `3/3` after implementation.
- Red-first focused table.init/elem.drop positives failed before implementation with `$once` still mutable; after implementation `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*table.init*'` passed `3/3`.
- `moon fmt` passed.
- Focused table tests passed `17/17`.
- Full SGO file passed `220/220`.
- `moon test src/passes` passed `4369/4369`.
- Native `src/cmd` build passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-block-prefix-tableset-init-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-block-prefix-tableset-init-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.516/1.593 ms` (`0.324x`), `runtime-set-get-1000f` `0.530/2.749 ms` (`0.193x`), `read-only-select-1000f` `1.737/3.437 ms` (`0.505x`), `initializer-fold-1000g` `0.450/1.044 ms` (`0.431x`), and `startup-offsets-1000e` `0.784/1.100 ms` (`0.712x`).

Status after this slice: block-prefix independent table-op coverage now includes `table.size`, `table.grow`, constant-argument `table.set`, `table.fill`, `table.copy`, `table.init`, and `elem.drop` for guarded-write and if-return tails. Broader arbitrary `FlowScanner` parent/child value-flow equivalence, non-constant table arguments, and table arguments derived from the guarded global remain open unless source probes, focused red/negative tests, and safety proof justify them. Final SGO closeout still needs broader transform-family classification plus freshness decisions for older full-matrix lanes after the narrow FlowScanner additions.

## Independent-call compare FlowScanner slice

A later recursive continuation implemented another source-backed `FlowScanner` subset: an independent zero-parameter/result call may supply the other operand of an `i32.eq` / `i32.ne` comparison with the guarded global, and the comparison result may reach only the same-global guarded write or the function-level `if return; set` tail. This follows Binaryen's parent/child value-flow contract: the guarded global's value reaches the pure comparison, not the call itself.

Local Binaryen probes:

- `.tmp/sgo-probe-independent-call-compare.wat`: `global.get $guard; call $foo; i32.eq; if { const; global.set $guard }` reduces to immutable `$guard` plus `drop (call $foo)`.
- `.tmp/sgo-probe-independent-call-compare-reverse.wat`: `call $foo; global.get $guard; i32.eq/i32.ne; if { const; global.set $guard }` reduces the same way.
- `.tmp/sgo-probe-independent-call-compare-ifreturn.wat`: `global.get $guard; call $foo; i32.ne; if { return }; const; global.set $guard` reduces the same way.
- `.tmp/sgo-probe-call-arg-neg.wat`: `global.get $guard; call $foo(param i32); if { const; global.set $guard }` keeps `$guard` mutable because the guarded value flows into the call's side effect/result.

Implementation changes:

- `src/passes/simplify_globals_optimizing.mbt` now counts the narrow independent-call compare operand forms as read-only-to-write-safe when the call has zero parameters and one result, for both direct guarded-write and `if return; set` tails.
- SGO cheap cleanup now reduces the generated `const; call; compare; empty-if` and `const; call; compare; if-return; const; drop` shells to `call; drop`, preserving the independent call while deleting the dead compare/guard shell.
- `src/passes/simplify_globals_optimizing_test.mbt` added red-first direct/reverse compare positives, an if-return positive, and a call-argument negative.

Validation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*independent call compare*'` failed before implementation because `$guard` stayed mutable in both positives.
- Focused independent-call compare tests passed `2/2`; call-argument negative passed `1/1`; call-focused SGO tests passed `23/23`; full SGO tests passed `223/223`.
- `moon fmt` passed.
- `moon test src/passes` passed `4372/4372`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-call-compare-genvalid-1000`: `1000/1000` normalized, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-call-compare-dedicated-1000`: `1000/1000` normalized, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- Bounded random-all smoke `.tmp/pass-fuzz-sgo-call-compare-random-all-1000`: `1000/1000` normalized, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required 1x bar: `const-read-1000f` `0.532/1.604 ms` (`0.332x`), `runtime-set-get-1000f` `0.554/2.753 ms` (`0.201x`), `read-only-select-1000f` `1.843/3.528 ms` (`0.522x`), `initializer-fold-1000g` `0.460/1.029 ms` (`0.446x`), and `startup-offsets-1000e` `0.779/1.172 ms` (`0.665x`).

Status after this slice: independent-call compare operands are implemented narrowly, but broad generic `FlowScanner` parent/child equivalence remains open. Final SGO closeout still needs source-family classification for the remaining safe independent-effect compare/memory/table/control shapes and a freshness decision on rerunning older full-matrix lanes after the narrow FlowScanner additions.

## Independent memory-op compare FlowScanner slice

A later recursive continuation extended the source-backed compare-operand FlowScanner subset from independent calls to independent memory operations. Local Binaryen probes reduced `global.get $guard; memory.size; i32.eq; if { const; global.set $guard }`, the reverse `memory.size; global.get $guard; i32.ne` order, `global.get $guard; i32.const 0; memory.grow; i32.ne; if { return }; const; global.set $guard`, and the reverse constant-delta `memory.grow` order to immutable `$guard`; `memory.size` shells disappear, while constant-delta `memory.grow` is preserved as `drop (memory.grow (i32.const 0))`. The paired negative where `$guard` flows into the `memory.grow` delta kept `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_compare_operand_independent_memory_read_at(...)`, deliberately narrow to direct compare operand forms where the non-global operand is `memory.size` or constant-delta `memory.grow`.
- Extended SGO cheap cleanup for the generated compare/empty-if and compare/if-return shells: `memory.size` is removed with the shell, while `memory.grow` is preserved as `memory.grow; drop`.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes independent memory compare read-only-to-write guards` failed before implementation because `$guard` stayed mutable; after implementation it covers direct and reverse `memory.size` plus direct and reverse constant-delta `memory.grow` compare operands.
- `simplify-globals-optimizing removes independent memory compare if-return guards` failed before implementation because `$guard` stayed mutable; after implementation it covers the function-level `if return; set` matcher.
- `simplify-globals-optimizing keeps values flowing into memory grow compare guards` keeps `$guard` mutable when the guarded-global value is consumed by `memory.grow`.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Focused independent-memory compare positives: `2/2` after the red-first failure.
- Memory.grow-delta negative: `1/1`.
- Memory-focused SGO tests: `11/11`.
- Full SGO tests: `226/226`.
- `moon test src/passes`: `4375/4375`.
- Native `src/cmd` build passed with the pre-existing `pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-memory-compare-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated SGO smoke `.tmp/pass-fuzz-sgo-memory-compare-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Bounded random-all smoke `.tmp/pass-fuzz-sgo-memory-compare-random-all-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- `moon info && git diff --check && moon test`: `moon info` passed with pre-existing warnings, `git diff --check` clean, and full `moon test` passed `7814/7814`.
- Representative timing remains under the user-required 1x Binaryen bar after this slice: `const-read-1000f` `0.553/2.002 ms` (`0.276x`), `runtime-set-get-1000f` `0.567/3.140 ms` (`0.180x`), `read-only-select-1000f` `1.994/4.037 ms` (`0.494x`), `initializer-fold-1000g` `0.480/1.075 ms` (`0.447x`), and `startup-offsets-1000e` `0.798/1.382 ms` (`0.578x`).

Status after this slice: implemented FlowScanner/body subsets now include independent-call and independent memory-op compare operands in guarded-write and if-return forms, in addition to the previously listed result-if-arm, select, select-eqz, block-prefix, nested-thrice, and multi-global nested-body subsets. The later independent table-op compare slice below supersedes this list by adding table compare operands too. Broad generic FlowScanner equivalence and final full-matrix freshness remain open.

## Independent table-op compare FlowScanner slice

A later recursive continuation implemented one more source-backed Binaryen `FlowScanner` family: independent table operations may supply one side of an `i32.eq` / `i32.ne` comparison while the guarded global supplies the other side, and the compare result reaches only the final same-global guarded write or function-level `if return; set` tail.

Local Binaryen `version_130` probes reduced direct and reverse `table.size` compare operands to immutable `$guard` with the table query shell removed. Direct and reverse constant-argument `table.grow` compare operands also reduce to immutable `$guard`, preserving the grow as `drop (table.grow (ref.null func) (i32.const 0))`. The paired negative keeps `$guard` mutable when the guarded value flows into the `table.grow` delta.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_compare_operand_independent_table_read_at(...)` recognizes only direct `table.size` and constant-ref/constant-delta `table.grow` compare operands in both first/second operand orders.
- The matcher accepts both the guarded-write and `if return; const; global.set` tails through the existing same-global tail predicates.
- `sgo_cheap_cleanup_compare_if_shell(...)` now deletes generated `table.size` compare/empty-if and compare/if-return shells, and preserves generated constant-argument `table.grow` shells as `table.grow; drop`.
- The implementation deliberately does not accept arbitrary table effects, non-constant `table.grow` arguments, or any shape where the guarded value flows into the table operation.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes independent table compare read-only-to-write guards` failed before implementation because `$guard` stayed mutable, then passed after the narrow recognizer and cleanup landed. It covers direct/reverse `table.size` and direct/reverse constant-argument `table.grow` guarded-write forms.
- `simplify-globals-optimizing removes independent table compare if-return guards` failed before implementation because `$guard` stayed mutable, then passed after implementation. It covers the function-level if-return variants.
- `simplify-globals-optimizing keeps values flowing into table grow compare guards` keeps the value-to-`table.grow` delta negative aligned with local Binaryen.

Validation:

- `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*independent table compare*'` failed red before implementation (`0/2`), then passed after implementation (`2/2`).
- `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*table grow compare*'`: `1/1`.
- `moon fmt && moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*table*'`: formatter passed; table-focused tests `20/20`.
- `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt`: `229/229`.
- `moon test src/passes && moon build --target native --release src/cmd`: pass tests `4378/4378`; native build passed with pre-existing `pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-table-compare-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-table-compare-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Bounded random-all smoke `.tmp/pass-fuzz-sgo-table-compare-random-all-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative direct timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.566/1.797 ms` (`0.315x`), `runtime-set-get-1000f` `0.585/3.151 ms` (`0.185x`), `read-only-select-1000f` `2.114/4.029 ms` (`0.525x`), `initializer-fold-1000g` `0.492/1.283 ms` (`0.384x`), and `startup-offsets-1000e` `0.808/1.199 ms` (`0.674x`).

Status after this slice: independent table-op compare operands now match the already landed independent-call and independent memory-op compare subsets for both guarded writes and if-return tails. Broad generic Binaryen `FlowScanner` equivalence remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Independent table-op `select` operand FlowScanner slice

A later 2026-07-06 recursive continuation extended the source-backed independent table-op value-flow family from compare operands to `select` operands. Local Binaryen `version_130` probes in `.tmp/sgo-next-table-select-probes/` reduce direct and reverse `table.size` select operands to immutable `$guard` with no residual table query, and reduce direct and reverse constant-argument `table.grow` select operands to immutable `$guard` while preserving the grow as `drop (table.grow (ref.null func) (i32.const 0))`. A valid paired negative where `$guard` flows into the `table.grow` delta while another guarded read feeds the `select` keeps `$guard` mutable, as does an extra-read `table.size` negative.

Implementation stayed deliberately narrow in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_select_operand_independent_table_read_at(...)` recognizes only `table.size` or constant-ref/constant-delta `table.grow` as the independent `select` operand, in first/second operand orders, and only when the selected value reaches the same-global guarded write or the function-level `if return; set` tail.
- `sgo_cheap_cleanup_select_if_shell(...)` removes the generated `table.size`/`select`/empty-if and if-return shells, and preserves generated constant-argument `table.grow` shells as `table.grow; drop`.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes independent table select read-only-to-write guards`
- `simplify-globals-optimizing removes independent table select if-return guards`
- `simplify-globals-optimizing keeps values flowing into table grow select guards`

Validation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*independent table select*'` failed before implementation because `$guard` stayed mutable in both positive tests.
- After implementation: focused independent table-select positives `2/2`, table.grow-select guardrail `1/1`, table-focused tests `23/23`, full SGO file `232/232`, `moon test src/passes` `4381/4381`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-table-select-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Dedicated SGO smoke `.tmp/pass-fuzz-sgo-table-select-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; selected counts were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Bounded random-all smoke `.tmp/pass-fuzz-sgo-table-select-random-all-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Representative direct timing still met the user-required 1x bar: `const-read-1000f` `0.544/1.622 ms` (`0.335x`), `runtime-set-get-1000f` `0.568/2.993 ms` (`0.190x`), `read-only-select-1000f` `1.963/3.451 ms` (`0.569x`), `initializer-fold-1000g` `0.456/1.021 ms` (`0.446x`), and `startup-offsets-1000e` `0.762/1.033 ms` (`0.738x`).

Status after this slice: the independent table-op `select` family is classified implemented for the narrow source-backed `table.size` / constant-argument `table.grow` direct and reverse operand orders, including the function-level if-return tail. Broader generic `FlowScanner` equivalence remains open.

## Independent constant local-tee select operand FlowScanner slice

A later recursive continuation probed and implemented another source-backed Binaryen `FlowScanner` subset: independent constant `local.tee` select operands where the guarded-global value supplies the other select operand and reaches only the final same-global guarded write or Binaryen's function-level `if return; set` matcher.

Local Binaryen probes in `.tmp/sgo-next-local-select-probes/` showed:

- `localtee-select-direct.wat`, `localtee-select-reverse.wat`, and `localtee-select-ifreturn.wat` reduce `$guard` to immutable state.
- `localtee-select-neg-flow.wat` keeps `$guard` mutable when the guarded value flows into the `local.tee` value.
- `localtee-select-neg-extra-read.wat` keeps `$guard` mutable when a separate extra guarded read remains after the select shell.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_select_operand_independent_local_tee_read_at(...)` for the narrow `const; local.tee` direct/reverse select operand shapes, including guarded-write and if-return tails.
- Extended `sgo_cheap_cleanup_select_if_shell(...)` to remove the generated unused-local `local.tee; select; empty-if` and `local.tee; select; if-return; drop` shells only when the local is not referenced outside the matched region.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes select operand read with independent local tee` covers direct and reverse guarded-write positives.
- `simplify-globals-optimizing removes select operand if-return read with independent local tee` covers direct and reverse if-return positives.
- `simplify-globals-optimizing keeps values flowing into local tee select guards` protects the value-to-local-tee negative.
- `simplify-globals-optimizing keeps extra reads after local tee select guards` protects the read-count negative.

Validation:

- Red-first focused positives failed before implementation because `$guard` stayed mutable.
- After implementation: focused independent-local-tee positives `2/2`, local-tee select guardrails `2/2`, `moon fmt`, select-focused tests `20/20`, full SGO tests `236/236`, `moon test src/passes` `4385/4385`, and native `src/cmd` build passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-localtee-select-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated profile smoke `.tmp/pass-fuzz-sgo-localtee-select-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; selected counts were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Bounded random-all smoke `.tmp/pass-fuzz-sgo-localtee-select-random-all-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures.
- Representative direct timing still met the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.556/1.769 ms` (`0.315x`), `runtime-set-get-1000f` `0.585/3.200 ms` (`0.183x`), `read-only-select-1000f` `1.962/3.883 ms` (`0.505x`), `initializer-fold-1000g` `0.463/1.060 ms` (`0.437x`), and `startup-offsets-1000e` `0.780/1.152 ms` (`0.677x`).

Status after this slice: the result-`if` arm, side-effecting `select`, select-through-`i32.eqz`, nested-thrice same-pattern, multi-global nested-body, independent-call/memory-op/table-op select and compare operands, block-prefix independent-effect subsets, and independent constant-local-tee select operands are implemented. Broad generic Binaryen `FlowScanner` equivalence still remains open, and final SGO closeout still needs freshness decisions on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## 2026-07-06 continuation: non-trapping float value pure-condition subset

Local Binaryen `version_130` probes under `.tmp/sgo-float-value-probes/` show that `wasm-opt --all-features --simplify-globals` promotes same-global read-only-to-write guards when a mutable `f32` or `f64` global flows only through non-trapping float value operators before the final float compare. The guarded-write probe covers `f32.add; f32.abs; f32.gt` and `f64.div; f64.sqrt; f64.ne`; the function-level `if return; set` probe covers `f32.mul; f32.ceil; f32.lt` and `f64.min; f64.floor; f64.ge`. In both probes Binaryen rewrites the globals as immutable. A Starshine guardrail keeps a float global mutable when the global-derived value flows into `local.tee` before the final compare, matching the existing FlowScanner side-effect rule.

Starshine now includes non-trapping `f32` / `f64` unary and binary value operators (`abs`, `neg`, `ceil`, `floor`, `trunc`, `nearest`, `sqrt`, `add`, `sub`, `mul`, `div`, `min`, `max`, `copysign`) in the read-only-to-write pure-condition whitelist. Red-first tests in `src/passes/simplify_globals_optimizing_test.mbt` failed before the implementation for guarded-write and `if return; set` positives, then passed after updating `src/passes/simplify_globals_optimizing.mbt`; the float `local.tee` negative also passes.

Validation for this slice: focused float tests `4/4`, full SGO test file `239/239`, `moon test src/passes` `4388/4388`, native `src/cmd` build with pre-existing `pass_manager.mbt` unused-function warnings, regular SGO smoke `.tmp/pass-fuzz-sgo-float-value-genvalid-1000` `1000/1000` normalized with zero failures, and dedicated smoke `.tmp/pass-fuzz-sgo-float-value-dedicated-1000` `1000/1000` normalized with all six leaves sampled (same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`). Representative direct timing after the recognizer widening still meets the user-required 1x Binaryen bar: `const-read-1000f` `0.567/1.895 ms` (`0.299x`), `runtime-set-get-1000f` `0.597/3.583 ms` (`0.167x`), `read-only-select-1000f` `2.048/4.349 ms` (`0.471x`), `initializer-fold-1000g` `0.461/1.055 ms` (`0.437x`), and `startup-offsets-1000e` `0.827/1.186 ms` (`0.697x`). Broad generic FlowScanner parent/child equivalence remains open.

## 2026-07-06 continuation: non-trapping numeric conversion pure-condition subset

Local Binaryen `version_130` probes under `.tmp/sgo-conversion-probes/` show that `wasm-opt --all-features --simplify-globals-optimizing` promotes same-global read-only-to-write guards when the guarded global flows only through non-trapping numeric conversions, reinterpretations, sign-extension, or saturating float-to-int conversion before the final condition. Positive probes covered `i32.wrap_i64`, `i64.extend_i32_s`, `f64.convert_i32_s`, `f64.promote_f32`, `f32.demote_f64`, `i32.reinterpret_f32`, `f64.reinterpret_i64`, `i32.extend8_s`, and `i32.trunc_sat_f32_s`; all reduced the involved globals to immutable. A paired trapping `i32.trunc_f32_s` probe kept the global mutable, so trapping float-to-int conversions remain excluded.

Starshine now treats the source-backed non-trapping conversion set as pure read-only-to-write condition flow: `i32.wrap_i64`, `i64.extend_i32_s/u`, numeric int-to-float converts, `f32.demote_f64`, `f64.promote_f32`, four reinterpret ops, sign-extension ops, and `i32` / `i64` `trunc_sat` from `f32` / `f64`. The ordinary trapping `i32.trunc_f*` / `i64.trunc_f*` instructions remain outside the whitelist, and a conversion result flowing into `local.tee` before the final compare keeps the global mutable.

Focused red-first tests in `src/passes/simplify_globals_optimizing_test.mbt` failed before implementation for both guarded-write and function-level `if return; set` positives, then passed after adding `sgo_is_numeric_conversion_condition_instr(...)` to `src/passes/simplify_globals_optimizing.mbt`. Guardrails for trapping conversion and conversion-to-`local.tee` side effects also pass.

Validation for this slice: focused conversion pure-condition tests `3/3`, focused conversion side-effect guardrail `1/1`, full SGO test file `243/243`, `moon fmt`, `moon test src/passes` `4392/4392`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` unused-function warnings. Regular SGO smoke `.tmp/pass-fuzz-sgo-conversion-genvalid-1000` compared `1000/1000`, normalized `1000`, and had zero mismatches/failures; dedicated smoke `.tmp/pass-fuzz-sgo-conversion-dedicated-1000` also compared and normalized `1000/1000` with all six leaves sampled (same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`). Representative direct timing after the recognizer widening still meets the user-required 1x Binaryen bar: `const-read-1000f` `0.563/1.789 ms` (`0.315x`), `runtime-set-get-1000f` `0.608/3.158 ms` (`0.193x`), `read-only-select-1000f` `1.994/3.497 ms` (`0.570x`), `initializer-fold-1000g` `0.464/1.033 ms` (`0.449x`), and `startup-offsets-1000e` `0.765/1.132 ms` (`0.676x`). Broad generic FlowScanner parent/child equivalence remains open.

## Ref-predicate pure-condition FlowScanner slice

A later 2026-07-06 recursive continuation implemented the next source-backed pure-condition family: non-trapping reference predicates. Local Binaryen `version_130` probes under `.tmp/sgo-ref-probes/` showed:

- `funcref` guarded-write conditions flowing through `ref.is_null` reduce to immutable globals while preserving the declared function/element metadata.
- `eqref` guarded-write conditions flowing through `ref.eq` reduce to immutable globals when the write is a single-instruction reference constant such as `ref.null i31`.
- The same `ref.is_null` and `ref.eq` chains reduce in the function-level `if return; set` matcher.
- A `funcref` value flowing into `local.tee` before `ref.is_null` keeps the global mutable, matching Binaryen's value-flow guardrail when the write is not merely same-as-init.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_is_ref_condition_instr(...)` and wired it into `sgo_is_read_only_to_write_pure_condition_instr(...)`.
- The recognizer includes `RefIsNull`, `RefEq`, and represented IR-level `RefTest` / `RefTestDesc` as non-trapping reference predicates. Focused textual coverage is for `ref.is_null` / `ref.eq`; the current Starshine WAT parser does not expose an easy `ref.test` fixture in this file.
- Trapping reference casts and `ref.as_non_null` remain outside the pure-condition whitelist.

Focused red-first coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes nontrapping ref pure-condition self guards` failed before implementation because the guarded globals remained mutable, then passed after the recognizer was added.
- `simplify-globals-optimizing removes nontrapping ref pure-condition if-return guards` failed before implementation for the function-level matcher, then passed.
- `simplify-globals-optimizing keeps ref condition values flowing into local tee` protects the source-backed value-flow guardrail.

Validation for this slice:

- `wasm-opt --all-features --simplify-globals-optimizing -S` on `.tmp/sgo-ref-probes/ref-pure-func.wat`, `ref-eq-null-i31.wat`, and `ref-ifreturn.wat` reduced the guarded globals to immutable; `.tmp/sgo-ref-probes/ref-localtee-func.wat` kept the guarded global mutable.
- Red-first focused `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*ref pure-condition*'` failed before implementation and passed after implementation.
- `moon fmt`, focused `*ref*condition*` (`3/3`), full SGO tests (`246/246`), `moon test src/passes` (`4395/4395`), and `moon build --target native --release src/cmd` passed with only pre-existing `pass_manager.mbt` unused-function warnings.
- Regular smoke `.tmp/pass-fuzz-sgo-ref-pure-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated smoke `.tmp/pass-fuzz-sgo-ref-pure-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative direct timing remains within the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.578/1.748 ms` (`0.331x`), `runtime-set-get-1000f` `0.597/3.215 ms` (`0.186x`), `read-only-select-1000f` `2.067/4.081 ms` (`0.506x`), `initializer-fold-1000g` `0.484/1.128 ms` (`0.429x`), and `startup-offsets-1000e` `0.794/1.158 ms` (`0.686x`).

Status after this slice: the pure-condition subset now includes non-trapping reference predicates in addition to numeric and float operators. Broad generic Binaryen `FlowScanner` equivalence remains open, and final SGO closeout still needs source-family freshness decisions and any required full-matrix reruns after the remaining narrow additions.

## Local-get pure-condition FlowScanner slice

A later recursive continuation implemented another source-backed pure-condition subset from Binaryen's generic `FlowScanner` contract: a non-trapping `local.get` may supply an independent sibling operand while the guarded global value flows through pure arithmetic to the final same-global guarded write. Local Binaryen `version_130` probe `.tmp/sgo-probes-current/local-get-pure.wat` reduced `global.get $g; local.get $x; i32.add; if { i32.const 1; global.set $g }` to immutable `$g` plus `nop`; before this slice Starshine left `$g` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_is_read_only_to_write_pure_condition_instr(...)` now treats `LocalGet(_)` as non-trapping pure read-only-to-write condition flow.
- This does not admit `local.tee` or `local.set`; the existing value-flow guardrails still reject guarded values flowing into local writes or tees.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes local get pure-condition self guards` failed red before implementation because `$g` remained mutable.
- After implementation, the test proves `$g` becomes immutable and the function loses both `global.get` and `global.set`.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen probe: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-probes-current/local-get-pure.wat -o -` reduced the guard to immutable `$g` plus `nop`.
- Red-first focused test failed before implementation; after implementation, focused local-get pure-condition test passed `1/1`.
- `moon fmt` passed.
- Focused pure-condition tests passed `28/28`.
- Full SGO file passed `247/247`.
- `moon test src/passes` passed `4396/4396`.
- `moon build --target native --release src/cmd` passed with pre-existing `src/passes/pass_manager.mbt` unused-function warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-localget-pure-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated SGO profile smoke `.tmp/pass-fuzz-sgo-localget-pure-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.550/1.690 ms` (`0.325x`), `runtime-set-get-1000f` `0.585/2.899 ms` (`0.202x`), `read-only-select-1000f` `1.992/3.472 ms` (`0.574x`), `initializer-fold-1000g` `0.456/1.008 ms` (`0.453x`), and `startup-offsets-1000e` `0.770/1.106 ms` (`0.696x`).

Status after this slice: the pure-condition subset now includes `local.get` siblings, but broad generic `FlowScanner` equivalence remains open. Final SGO closeout still needs a freshness decision on rerunning the full four-lane matrix after the latest narrow FlowScanner additions.

## Block-prefix void-call FlowScanner slice

A later recursive continuation extended the already-landed block-prefix independent-call subset from zero-parameter/one-result calls followed by `drop` to zero-parameter/zero-result calls. Local Binaryen `version_130` probes under `.tmp/sgo-void-call-probes/` showed that both guarded-write and function-level `if return; set` forms reduce to immutable `$g` while preserving the independent void call, and that a paired negative keeps `$g` mutable when the guarded value flows into a call parameter before the final read.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added a `sgo_call_has_no_params_no_results(...)` type predicate.
- `sgo_block_condition_independent_call_final_read_idx(...)` now accepts the narrow `call $foo; global.get $g` result-block condition only when the call has no parameters and no results.
- `sgo_cheap_cleanup_block_if_shell(...)` now reduces the SGO-created `block { call; const }; empty-if` and `block { call; const }; if-return; const; drop` shells to the preserved void `call`.
- The existing call-argument and flow-into-call negatives remain unchanged.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes block prefix independent void call guards`
- `simplify-globals-optimizing removes if-return block prefix independent void call guards`

Validation:

- Local Binaryen positive probes: `wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-void-call-probes/block-prefix-void-call.wat -o -` and `.tmp/sgo-void-call-probes/ifreturn-void-call.wat` reduced `$g` to immutable and preserved `call $foo`.
- Local Binaryen negative probe: `.tmp/sgo-void-call-probes/block-prefix-void-call-neg.wat` kept `$g` mutable when `$g` fed a call parameter.
- Red-first focused tests failed before implementation because `$once` stayed mutable; after implementation `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*void call guards*'` passed `2/2`.
- `moon fmt` passed.
- Focused block-prefix call tests passed `6/6`.
- Full SGO file passed `249/249`.
- `moon test src/passes` passed `4398/4398`.
- Native `src/cmd` build passed with pre-existing `src/passes/pass_manager.mbt` warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-void-call-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-void-call-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses; selected counts were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Representative direct timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.555/1.767 ms` (`0.314x`), `runtime-set-get-1000f` `0.582/2.866 ms` (`0.203x`), `read-only-select-1000f` `2.061/3.929 ms` (`0.524x`), `initializer-fold-1000g` `0.459/1.056 ms` (`0.434x`), and `startup-offsets-1000e` `0.975/1.033 ms` (`0.944x`).

Status after this slice: the block-prefix independent-call subset now covers zero-parameter/one-result `call; drop; global.get` and zero-parameter/zero-result `call; global.get` forms for guarded-write and if-return tails. Broad generic Binaryen `FlowScanner` equivalence remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow FlowScanner additions.

## Independent constant `local.tee` compare operand FlowScanner slice

A later 2026-07-06 recursive continuation extended the independent constant `local.tee` operand family from `select` to direct integer comparisons. Local Binaryen `version_130` probes under `.tmp/sgo-next-localtee-compare-probes/` showed:

- `localtee-compare.wat` and `localtee-compare-reverse.wat` reduce direct/reverse `global.get $guard` plus `local.tee $tmp (i32.const 0)` operands flowing through `i32.eq` / `i32.ne` into a guarded write to immutable `$guard`.
- `localtee-compare-ifreturn.wat` reduces the same family through Binaryen's function-level `if return; set` matcher.
- `localtee-compare-neg-flow.wat` keeps `$guard` mutable when the guarded value itself flows into the `local.tee` value.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_compare_operand_independent_local_tee_read_at(...)` for narrow constant `local.tee` compare operands in both operand orders, including guarded-write and if-return tails.
- Extended `sgo_cheap_cleanup_compare_if_shell(...)` so generated `const; local.tee; compare; empty-if` and `const; local.tee; compare; if-return; const; drop` shells are removed only when the local is not referenced outside the matched shell.
- Kept the value-flow guardrail: a guarded-global value flowing into the `local.tee` itself remains unsafe and leaves the guarded global mutable.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes compare operand read with independent local tee`
- `simplify-globals-optimizing removes compare operand if-return read with independent local tee`
- `simplify-globals-optimizing keeps values flowing into local tee compare guards`

Validation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*compare operand*local tee*'` failed before implementation because `$guard` stayed mutable in the guarded-write positive and the if-return shell still remained.
- After implementation: focused compare-local-tee positives `2/2`, compare-local-tee guardrail `1/1`, all local-tee focused SGO tests `8/8`, full SGO file `252/252`, `moon fmt`, `moon test src/passes` `4401/4401`, and native `src/cmd` build passed with the pre-existing `src/passes/pass_manager.mbt` unused-function warnings.
- Regular SGO smoke `.tmp/pass-fuzz-sgo-localtee-compare-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-localtee-compare-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses; selected counts were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Representative direct timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.896/2.555 ms` (`0.351x`), `runtime-set-get-1000f` `1.001/5.974 ms` (`0.168x`), `read-only-select-1000f` `3.967/6.520 ms` (`0.608x`), `initializer-fold-1000g` `0.781/1.602 ms` (`0.488x`), and `startup-offsets-1000e` `1.332/1.466 ms` (`0.908x`).

Status after this slice: independent constant `local.tee` compare operands now match the already landed independent constant `local.tee` select operands for guarded-write and if-return tails. Broad generic Binaryen `FlowScanner` equivalence remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the narrow cleanup and FlowScanner changes.

## Independent constant `local.set` compare-operand FlowScanner slice

A later recursive continuation implemented one more source-backed Binaryen `FlowScanner` positive: a block condition may perform an independent constant `local.set`, then compare the guarded global with that local via `i32.eq` / `i32.ne`, and use the result only for the same-global guarded write or function-level `if return; set` tail. Local Binaryen `version_130` probes under `.tmp/sgo-next-localset-compare-probes/` reduced the direct, reverse, and if-return shapes to immutable `$guard`, while the paired negative where `$guard` flows into the `local.set` kept `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_block_condition_independent_local_compare_read_matches(...)` and wired it into block-condition safe-read counting for guarded-write and if-return tails.
- Kept the recognizer narrow: the local write value must be a constant, the following `local.get` must read the same local, and the guarded value may not flow into the local write.
- Extended SGO cheap cleanup for generated `block { const; local.set; const/local.get; compare }; empty-if` and terminal `if-return` shells, preserving the independent `local.set` while removing inert compare/control debris.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes compare operand read with independent local set` covers direct and reverse compare operand order.
- `simplify-globals-optimizing removes compare operand if-return read with independent local set` covers the function-level `if return; set` variant.
- `simplify-globals-optimizing keeps values flowing into local set compare guards` preserves the Binaryen negative where the guarded value is written into the local.

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Local Binaryen positives: `localset-compare.wat`, `localset-compare-reverse.wat`, and `localset-compare-ifreturn.wat` reduce `$guard` to immutable; local Binaryen negative `localset-compare-neg-flow.wat` keeps `$guard` mutable.
- Red-first focused positives: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*compare operand*local set*'` failed `0/2` before implementation because `$guard` stayed mutable.
- After implementation: focused local-set compare positives `2/2`, local-set compare guardrail `1/1`, focused `*local set*` tests `3/3`, `moon fmt`, full SGO tests `255/255`, `moon test src/passes` `4404/4404`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.
- Regular GenValid smoke `.tmp/pass-fuzz-sgo-localset-compare-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-localset-compare-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses. Selected counts: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Representative timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.544/1.778 ms` (`0.306x`), `runtime-set-get-1000f` `0.656/3.084 ms` (`0.213x`), `read-only-select-1000f` `2.275/4.107 ms` (`0.554x`), `initializer-fold-1000g` `0.506/1.103 ms` (`0.459x`), and `startup-offsets-1000e` `0.849/1.114 ms` (`0.763x`).

Status after this slice: independent constant `local.set` compare operands now join the implemented local-write prefix and independent constant `local.tee` select/compare operand subsets. Broad generic Binaryen `FlowScanner` equivalence remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the latest narrow FlowScanner changes.

## Independent global-set compare-operand FlowScanner slice

A later recursive continuation implemented another source-backed Binaryen `FlowScanner` subset: an independent constant `global.set` to a different observable global may occur inside a result-block compare operand while the guarded global supplies the other compare operand. The guarded value reaches only the pure `i32.eq` / `i32.ne` and then the same-global guarded write or Binaryen's function-level `if return; set` tail, so the independent write's manner is not determined by the guarded value.

Local Binaryen `version_130` probes under `.tmp/sgo-next-global-compare-probes/` showed:

- `globalset-compare.wat` and `globalset-compare-reverse.wat` reduce direct/reverse `global.get $guard` plus `block { i32.const 7; global.set $other; i32.const 0 }` compare operands flowing into guarded-write tails to immutable `$guard`, preserving the `$other` write.
- `globalset-compare-ifreturn.wat` reduces the function-level `if return; set` variant the same way.
- `globalset-compare-neg-flow.wat` keeps `$guard` mutable when the guarded value flows into `global.set $other` before the final compare read.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_compare_operand_independent_global_set_read_at(...)` for narrow constant global-set result-block compare operands in both operand orders, including guarded-write and if-return tails.
- Required the independent write to target a different global and to store a constant value, so guarded-value-to-global-write flow remains rejected.
- Extended `sgo_cheap_cleanup_compare_if_shell(...)` to preserve the independent `global.set $other` while removing generated compare/empty-if or compare/if-return debris.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes compare operand read with independent global set`
- `simplify-globals-optimizing removes compare operand if-return read with independent global set`
- `simplify-globals-optimizing keeps values flowing into global set compare guards`

Validation after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- Red-first focused positives: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*compare operand*global set*'` failed `0/2` before implementation because `$guard` stayed mutable.
- After implementation: focused compare-global-set positives `2/2`, global-set compare guardrail `1/1`, focused `*global*` SGO tests `258/258`, full SGO tests `258/258`, `moon fmt`, `moon test src/passes` `4407/4407`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.
- Regular GenValid smoke `.tmp/pass-fuzz-sgo-globalset-compare-genvalid-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses.
- Dedicated-profile smoke `.tmp/pass-fuzz-sgo-globalset-compare-dedicated-1000`: `1000/1000` compared, `1000` normalized, zero mismatches/failures; Binaryen cache `1000` hits / `0` misses. Selected counts: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Representative direct timing still meets the user-required `<=1x` Binaryen median target: `const-read-1000f` `0.543/1.603 ms` (`0.339x`), `runtime-set-get-1000f` `0.587/2.767 ms` (`0.212x`), `read-only-select-1000f` `2.058/3.533 ms` (`0.583x`), `initializer-fold-1000g` `0.444/0.998 ms` (`0.444x`), and `startup-offsets-1000e` `0.762/1.092 ms` (`0.698x`).

Status after this slice: independent constant global-set compare operands now join the block-prefix independent-global-write condition subset for guarded-write and if-return tails. Broad generic Binaryen `FlowScanner` equivalence remains open, and final SGO closeout still needs a freshness decision on rerunning older full-matrix lanes after the latest narrow FlowScanner changes.

## Independent memory-store compare FlowScanner slice

A later 2026-07-06 continuation implemented another narrow Binaryen `FlowScanner` positive: an independent constant memory store inside a result-block compare operand. Local Binaryen `version_130` probes under `.tmp/sgo-next-store-compare-probes/` showed:

- `memorystore-compare.wat`: `global.get $guard; block { i32.const 0; i32.const 7; i32.store; i32.const 0 }; i32.eq; guarded write` reduces `$guard` to immutable and preserves the store.
- `memorystore-compare-reverse.wat`: reverse compare operand order also reduces `$guard` to immutable.
- `memorystore-compare-ifreturn.wat`: the function-level `if return; set` tail reduces `$guard` to immutable and preserves the store.
- `memorystore-compare-neg-flow.wat`: guarded value flowing into the `i32.store` value keeps `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- added a narrow independent memory-store result-block matcher for constant address/value operands;
- wired `sgo_compare_operand_independent_memory_store_read_at(...)` into read-only-to-write safe-read counting;
- extended SGO cheap cleanup for generated compare/empty-if and compare/if-return shells so the independent store is preserved while inert guard debris is removed.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes compare operand read with independent memory store`
- `simplify-globals-optimizing removes compare operand if-return read with independent memory store`
- `simplify-globals-optimizing keeps values flowing into memory store compare guards`

Red-first command `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*compare operand*memory store*'` failed `0/2` before implementation because `$guard` stayed mutable. After implementation, focused memory-store positives passed `2/2`, the guardrail passed `1/1`, `moon fmt` passed, full SGO tests passed `261/261`, `moon test src/passes` passed `4410/4410`, native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings, `moon info` passed with pre-existing warnings, `git diff --check` passed, and full `moon test` passed `7849/7849`.

Direct compare evidence after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- `.tmp/pass-fuzz-sgo-memstore-compare-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- `.tmp/pass-fuzz-sgo-memstore-compare-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses; selected counts same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.

Representative direct timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py` still meets the user-required `<=1x` Binaryen median target: `const-read` `0.562/1.586 ms` (`0.354x`), runtime propagation `0.617/2.985 ms` (`0.207x`), read-only-select `2.128/3.535 ms` (`0.602x`), initializer-folding `0.469/1.043 ms` (`0.449x`), and startup-offsets `0.804/1.121 ms` (`0.717x`).

Status after this slice: the independent constant memory-store compare subset is implemented for direct/reverse guarded-write and if-return forms, with the value-to-store negative covered. Broad generic Binaryen `FlowScanner` parent/child equivalence remains open, including arbitrary effectful siblings and non-constant memory/table/global/local writes unless source-backed by the already landed narrow subsets.

## Local-fed memory-store compare FlowScanner slice

A later 2026-07-06 continuation widened that exact memory-store compare subset from constant-only store operands to locally supplied store address/value operands that are still independent of the guarded global. This remains deliberately narrower than generic Binaryen `FlowScanner`: the result block must still be `addr; value; store; const`, and `addr` / `value` may only be constants or `local.get`s.

Local Binaryen `version_130` probes under `.tmp/sgo-next-nonconst-effect-probes/` showed:

- `memorystore-local-compare.wat`: `global.get $guard; block { local.get $addr; local.get $val; i32.store; i32.const 0 }; i32.eq; guarded write` reduces `$guard` to immutable and preserves the store.
- `memorystore-local-compare-reverse.wat`: reverse compare operand order also reduces `$guard` to immutable.
- `memorystore-local-compare-ifreturn.wat`: the function-level `if return; set` tail reduces `$guard` to immutable and preserves the store.
- `memorystore-local-compare-neg-flow-addr.wat`: guarded value flowing into the `i32.store` address keeps `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- added `sgo_memory_store_result_block_operand_is_independent(...)`;
- allowed constant or `local.get` store address/value operands in the independent memory-store result-block matcher;
- reused the existing compare/if-return cleanup preservation path so the local-fed store remains observable while the inert guard debris is removed.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes compare operand read with local-fed memory store` covers direct and reverse compare operand order.
- `simplify-globals-optimizing removes compare operand if-return read with local-fed memory store` covers the function-level `if return; set` tail.
- The existing `simplify-globals-optimizing keeps values flowing into memory store compare guards` guardrail continues to cover guarded value-to-store flow.

Red-first command `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*local-fed memory store*'` failed `0/2` before implementation because `$guard` stayed mutable. After implementation, focused local-fed memory-store positives passed `2/2`, focused `*memory store*` tests passed `5/5`, `moon fmt` passed, full SGO tests passed `263/263`, `moon test src/passes` passed `4412/4412`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.

Direct compare evidence after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- `.tmp/pass-fuzz-sgo-local-memstore-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- `.tmp/pass-fuzz-sgo-local-memstore-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses; selected counts same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.

Representative direct timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py` still meets the user-required `<=1x` Binaryen median target: `const-read` `0.544/1.586 ms` (`0.343x`), runtime propagation `0.615/2.649 ms` (`0.232x`), read-only-select `2.064/3.577 ms` (`0.577x`), initializer-folding `0.455/1.044 ms` (`0.435x`), and startup-offsets `0.750/1.128 ms` (`0.665x`).

Status after this slice: independent memory-store compare operands now cover constants and local-fed operands for direct/reverse guarded-write and if-return forms, while guarded-value-to-store flow remains excluded. Broad generic Binaryen `FlowScanner` parent/child equivalence remains open, including arbitrary effectful siblings, additional non-constant side-effect operands beyond `local.get`, extra guarded reads, and unprobed source/lit families.

## Local-fed global-set compare FlowScanner slice

A later 2026-07-06 continuation widened the exact independent `global.set` compare subset from constant-only stored values to locally supplied values that are still independent of the guarded global. This remains deliberately narrower than generic Binaryen `FlowScanner`: the result block must still be `value; global.set $other; const`, `$other` must differ from the guarded global, and `value` may only be a constant or `local.get`.

Local Binaryen `version_130` probes under `.tmp/sgo-next-globalset-local-probes/` showed:

- `globalset-local-compare.wat`: `global.get $guard; block { local.get $v; global.set $other; i32.const 0 }; i32.eq; guarded write` reduces `$guard` to immutable and preserves the `$other` write.
- `globalset-local-compare-reverse.wat`: reverse compare operand order also reduces `$guard` to immutable and preserves the `$other` write.
- `globalset-local-compare-ifreturn.wat`: the function-level `if return; set` tail reduces `$guard` to immutable and preserves the `$other` write.
- `globalset-local-neg-flow-value.wat`: guarded value flowing into the `$other` write keeps `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- added `sgo_global_set_result_block_value_is_independent(...)`;
- allowed constant or `local.get` values in the independent `global.set` result-block matcher while keeping `$other != $guard`;
- widened the SGO-created compare/if-return cleanup preservation path so the local-fed `$other` write remains observable while inert guard debris is removed.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes compare operand read with local-fed global set` covers direct and reverse compare operand order.
- `simplify-globals-optimizing removes compare operand if-return read with local-fed global set` covers the function-level `if return; set` tail.
- The existing `simplify-globals-optimizing keeps values flowing into global set compare guards` guardrail continues to cover guarded value-to-`global.set` flow.

Red-first command `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*local-fed global set*'` failed `0/2` before implementation because `$guard` stayed mutable. After implementation, focused local-fed global-set positives passed `2/2`, focused `*global set*` tests passed `5/5`, `moon fmt` passed, full SGO tests passed `265/265`, `moon test src/passes` passed `4414/4414`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.

Direct compare evidence after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- `.tmp/pass-fuzz-sgo-local-globalset-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- `.tmp/pass-fuzz-sgo-local-globalset-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses; selected counts same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.

Representative direct timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py` still meets the user-required `<=1x` Binaryen median target: `const-read` `0.569/1.831 ms` (`0.311x`), runtime propagation `0.621/3.272 ms` (`0.190x`), read-only-select `2.136/3.914 ms` (`0.546x`), initializer-folding `0.473/1.082 ms` (`0.437x`), and startup-offsets `0.788/1.155 ms` (`0.682x`).

Status after this slice: independent `global.set` compare operands now cover constants and local-fed values for direct/reverse guarded-write and if-return forms, while guarded-value-to-`global.set` flow remains excluded. Broad generic Binaryen `FlowScanner` parent/child equivalence remains open, including arbitrary effectful siblings, additional non-constant side-effect operands beyond `local.get`, extra guarded reads, and unprobed source/lit families.

## Local-fed local-write compare FlowScanner slice

A later 2026-07-06 continuation widened the exact independent local-write compare subsets from constant-only local values to locally supplied values that are still independent of the guarded global. This remains deliberately narrower than generic Binaryen `FlowScanner`: the direct `local.tee` form must still feed only the compare shell, and the `local.set` form must still write a local inside the block condition and read it back as the other compare operand. The stored value may only be a constant or `local.get`; guarded-value-to-local-write flow remains excluded.

Local Binaryen `version_130` probes under `.tmp/sgo-next-localset-local-probes/` showed:

- `localset-local-compare.wat`: `block { local.get $v; local.set $tmp; global.get $guard; local.get $tmp; i32.eq }; guarded write` reduces `$guard` to immutable.
- `localset-local-compare-reverse.wat`: reverse compare operand order also reduces `$guard` to immutable.
- `localset-local-ifreturn.wat`: the function-level `if return; set` tail reduces `$guard` to immutable.
- `localset-local-neg-flow-value.wat`: guarded value flowing into the `local.set` keeps `$guard` mutable.
- `localtee-local-compare.wat` and `localtee-local-ifreturn.wat`: direct local-fed `local.tee` compare operands reduce `$guard` to immutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- added `sgo_local_effect_value_is_independent(...)` for constant-or-`local.get` local-write values;
- widened the direct `local.tee` compare matcher and the block `local.set` compare matcher to accept local-fed independent values;
- widened the SGO-created cleanup shells for the same direct/reverse guarded-write and if-return forms so the inert guard debris is removed after the guarded global becomes immutable.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes compare operand read with local-fed local tee` covers direct and reverse compare operand order.
- `simplify-globals-optimizing removes compare operand if-return read with local-fed local tee` covers the function-level `if return; set` tail.
- `simplify-globals-optimizing removes compare operand read with local-fed local set` covers direct and reverse block compare operand order.
- `simplify-globals-optimizing removes compare operand if-return read with local-fed local set` covers the block-condition function-level `if return; set` tail.
- Existing local-write guardrails still cover guarded value-to-local-write flow.

Red-first commands failed before implementation because `$guard` stayed mutable: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*local-fed local set*'` failed `0/2`, and `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*local-fed local tee*'` failed `0/2`. After implementation, focused local-fed local-write positives passed `4/4`, focused `*local*` SGO tests passed `26/26`, `moon fmt` passed, full SGO tests passed `269/269`, `moon test src/passes` passed `4418/4418`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.

Direct compare evidence after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- `.tmp/pass-fuzz-sgo-local-localwrite-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- `.tmp/pass-fuzz-sgo-local-localwrite-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.

Representative direct timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py` still meets the user-required `<=1x` Binaryen median target: `const-read` `0.557/1.662 ms` (`0.335x`), runtime propagation `0.607/3.080 ms` (`0.197x`), read-only-select `2.133/3.535 ms` (`0.603x`), initializer-folding `0.476/1.054 ms` (`0.452x`), and startup-offsets `0.797/1.124 ms` (`0.709x`).

Status after this slice: independent local-write compare operands now cover constants and local-fed values for direct/reverse guarded-write and if-return forms, while guarded-value-to-local-write flow remains excluded. Broad generic Binaryen `FlowScanner` parent/child equivalence remains open, including arbitrary effectful siblings, additional non-constant side-effect operands beyond `local.get`, extra guarded reads, and unprobed source/lit families.

## Local-fed table-grow compare FlowScanner slice

A later 2026-07-06 continuation widened the exact independent `table.grow` compare subset from constant-only ref/delta operands to locally supplied operands that are still independent of the guarded global. This remains deliberately narrower than generic Binaryen `FlowScanner`: the compared side-effect must still be `table.grow` feeding an integer compare, the ref and delta operands may only be constants or `local.get`s, and guarded-value-to-`table.grow` flow remains excluded.

Local Binaryen `version_130` probes under `.tmp/sgo-next-table-local-probes/` showed:

- `tablegrow-local-compare.wat`: `global.get $guard; local.get $r; local.get $n; table.grow 0; i32.eq; guarded write` reduces `$guard` to immutable while preserving the table growth.
- `tablegrow-local-compare-reverse.wat`: reverse compare operand order also reduces `$guard` to immutable.
- `tablegrow-local-ifreturn.wat`: the function-level `if return; set` tail reduces `$guard` to immutable.
- `tablegrow-local-neg-flow-delta.wat`: guarded value flowing into the `table.grow` delta keeps `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- added `sgo_table_grow_arg_is_independent(...)` for constant-or-`local.get` table-growth operands;
- widened the direct/reverse independent `table.grow` compare matcher to accept local-fed ref/delta operands;
- widened the SGO-created compare/empty-if and compare/if-return cleanup shells so independent local-fed table growth is preserved as `table.grow; drop` after the guarded global becomes immutable.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes local-fed table grow compare read-only-to-write guards` covers direct and reverse compare operand order.
- `simplify-globals-optimizing removes local-fed table grow compare if-return guards` covers the function-level `if return; set` tail.
- The existing `simplify-globals-optimizing keeps values flowing into table grow compare guards` guardrail continues to cover guarded value-to-`table.grow` flow.

Red-first command `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*local-fed table grow compare*'` failed `0/2` before implementation because `$guard` stayed mutable. After implementation, focused local-fed table-grow positives passed `2/2`, focused `*table*` SGO tests passed `25/25`, `moon fmt` passed, full SGO tests passed `271/271`, `moon test src/passes` passed `4420/4420`, `moon info` passed with pre-existing warnings, full `moon test` passed `7859/7859`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.

Direct compare evidence after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- `.tmp/pass-fuzz-sgo-local-tablegrow-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- `.tmp/pass-fuzz-sgo-local-tablegrow-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.

Representative direct timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py` still meets the user-required `<=1x` Binaryen median target: `const-read` `0.571/1.596 ms` (`0.358x`), runtime propagation `0.609/2.805 ms` (`0.217x`), read-only-select `2.140/3.554 ms` (`0.602x`), initializer-folding `0.460/1.061 ms` (`0.434x`), and startup-offsets `0.757/1.031 ms` (`0.734x`).

Status after this slice: independent `table.grow` compare operands now cover constants and local-fed ref/delta operands for direct/reverse guarded-write and if-return forms, while guarded-value-to-`table.grow` flow remains excluded. Broad generic Binaryen `FlowScanner` parent/child equivalence remains open, including arbitrary effectful siblings, additional non-constant side-effect operands beyond `local.get`, extra guarded reads, and unprobed source/lit families.

## Local-fed memory-grow compare/select FlowScanner slice

A later 2026-07-06 continuation widened the exact independent `memory.grow` compare and select subsets from constant-only deltas to locally supplied deltas that are still independent of the guarded global. This remains deliberately narrower than generic Binaryen `FlowScanner`: the side effect must still be `memory.grow` feeding the known compare/select guard shell, the delta may only be a constant or `local.get`, and guarded-value-to-`memory.grow` delta flow remains excluded.

Local Binaryen `version_130` probes under `.tmp/sgo-next-memory-local-probes/` showed:

- `memgrow-param-compare.wat`: `global.get $guard; local.get $n; memory.grow; i32.ne; guarded write` reduces `$guard` to immutable while preserving the memory growth.
- `memgrow-param-compare-reverse.wat`: reverse compare operand order also reduces `$guard` to immutable.
- `memgrow-param-ifreturn.wat`: the function-level `if return; set` tail reduces `$guard` to immutable.
- `memgrow-param-select.wat` and `memgrow-param-select-second.wat`: local-fed `memory.grow` may supply either select value operand while the guarded global controls the select, and `$guard` still becomes immutable.
- `memgrow-param-select-ifreturn.wat`: the local-fed `memory.grow` select shell also reduces in the function-level `if return; set` form.
- `memgrow-local-neg-flow-delta.wat` / `memgrow-param-select-neg-flow.wat`: guarded value flowing into the `memory.grow` delta keeps `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- added `sgo_memory_grow_arg_is_independent(...)` for constant-or-`local.get` memory-growth deltas;
- widened the direct/reverse independent `memory.grow` compare matcher to accept local-fed deltas;
- widened independent `memory.grow` select matching to accept local-fed deltas;
- widened the SGO-created compare/select empty-if and if-return cleanup shells so independent local-fed memory growth is preserved as `memory.grow; drop` after the guarded global becomes immutable.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes local-fed memory grow compare read-only-to-write guards` covers direct and reverse compare operand order.
- `simplify-globals-optimizing removes local-fed memory grow compare if-return guards` covers the compare function-level `if return; set` tail.
- `simplify-globals-optimizing removes local-fed memory grow select guards` covers direct and second select operand forms.
- `simplify-globals-optimizing removes local-fed memory grow select if-return guards` covers the select function-level `if return; set` tail.
- Existing memory.grow guardrails continue to cover guarded value-to-`memory.grow` compare/select flow.

Red-first commands failed before implementation because `$guard` stayed mutable: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*local-fed memory grow compare*'` failed `0/2`, and `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*local-fed memory grow select*'` failed `0/2`. After implementation, focused local-fed memory-grow compare tests passed `2/2`, focused local-fed memory-grow select tests passed `2/2`, focused `*memory grow*` tests passed `5/5`, focused `*memory*` tests passed `20/20`, `moon fmt` passed, full SGO tests passed `275/275`, `moon test src/passes` passed `4424/4424`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.

Direct compare evidence after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- `.tmp/pass-fuzz-sgo-local-memgrow-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- `.tmp/pass-fuzz-sgo-local-memgrow-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.

Representative direct timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py` still meets the user-required `<=1x` Binaryen median target: `const-read` `0.546/1.532 ms` (`0.357x`), runtime propagation `0.623/3.006 ms` (`0.207x`), read-only-select `2.133/3.471 ms` (`0.615x`), initializer-folding `0.463/1.043 ms` (`0.444x`), and startup-offsets `0.750/1.126 ms` (`0.666x`).

Status after this slice: independent `memory.grow` compare/select operands now cover constants and local-fed deltas for direct/reverse guarded-write and if-return forms, while guarded-value-to-`memory.grow` flow remains excluded. Broad generic Binaryen `FlowScanner` parent/child equivalence remains open, including arbitrary effectful siblings, side-effect operands beyond constant/`local.get`, broader value-flow into side-effect parents, extra guarded reads, and unprobed source/lit families.


## Local-fed table-grow select FlowScanner slice

A later 2026-07-06 continuation widened the exact independent `table.grow` select subset from constant-only ref/delta operands to locally supplied operands that are still independent of the guarded global. This remains deliberately narrower than generic Binaryen `FlowScanner`: the side effect must still be `table.grow` feeding the known select guard shell, the ref and delta operands may only be constants or `local.get`s, and guarded-value-to-`table.grow` delta flow remains excluded.

Local Binaryen `version_130` probes under `.tmp/sgo-table-local-select-probes/` showed:

- `tablegrow-param-select.wat`: local-fed `table.grow` may supply a select value operand while the guarded global supplies the other operand/condition, and `$guard` becomes immutable while the table growth is preserved.
- `tablegrow-param-select-second.wat`: the reverse select value operand order also reduces `$guard` to immutable.
- `tablegrow-param-select-ifreturn.wat`: the local-fed table-grow select shell also reduces in the function-level `if return; set` form.
- `tablegrow-param-select-neg-flow.wat`: guarded value flowing into the `table.grow` delta keeps `$guard` mutable.

Implementation changes in `src/passes/simplify_globals_optimizing.mbt`:

- widened independent `table.grow` select matching to use the existing constant-or-`local.get` operand independence helper;
- widened the SGO-created select empty-if and if-return cleanup shells so independent local-fed table growth is preserved as `table.grow; drop` after the guarded global becomes immutable.

Focused coverage in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes local-fed table grow select guards` covers direct and second select operand forms.
- `simplify-globals-optimizing removes local-fed table grow select if-return guards` covers the select function-level `if return; set` tail.
- The existing `simplify-globals-optimizing keeps values flowing into table grow select guards` guardrail continues to cover guarded value-to-`table.grow` flow.

Red-first command `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*local-fed table grow select*'` failed `0/2` before implementation because `$guard` stayed mutable. After implementation, focused local-fed table-grow select tests passed `2/2`, focused `*table grow*` tests passed `6/6`, focused `*table*` tests passed `27/27`, `moon fmt` passed, full SGO tests passed `277/277`, `moon test src/passes` passed `4426/4426`, and native `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.

Direct compare evidence after rebuilding `_build/native/release/build/cmd/cmd.exe`:

- `.tmp/pass-fuzz-sgo-local-tablegrow-select-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- `.tmp/pass-fuzz-sgo-local-tablegrow-select-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses; selected counts were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.

Representative direct timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py` still meets the user-required `<=1x` Binaryen median target: `const-read` `0.565/1.528 ms` (`0.370x`), runtime propagation `0.637/2.724 ms` (`0.234x`), read-only-select `2.157/3.349 ms` (`0.644x`), initializer-folding `0.457/1.012 ms` (`0.451x`), and startup-offsets `1.014/1.220 ms` (`0.832x`).

Status after this slice: independent `table.grow` select operands now cover constants and local-fed ref/delta operands for direct/second guarded-write and if-return forms, while guarded-value-to-`table.grow` flow remains excluded. Broad generic Binaryen `FlowScanner` parent/child equivalence remains open, including arbitrary effectful siblings, side-effect operands beyond constant/`local.get`, broader value-flow into side-effect parents, extra guarded reads, and unprobed source/lit families.

## Pure-add grow select operand FlowScanner slice

A later 2026-07-06 recursive continuation probed another narrow source-backed `FlowScanner` family: independent `memory.grow` / `table.grow` select operands whose grow delta is a nontrapping `i32.add` over constants or `local.get`s, while the guarded global supplies only the other `select` operand / condition for the same-global guarded write.

Local Binaryen `version_130` probes under `.tmp/sgo-pure-arg-probes/` showed:

- `memgrow-add-select.wat`: Binaryen makes `$guard` immutable and preserves `drop (memory.grow (i32.add (local.get ...)))`.
- `tablegrow-add-select.wat`: Binaryen makes `$guard` immutable and preserves `drop (table.grow (local.get ...) (i32.add (local.get ...)))`.
- Compare-form probes `memgrow-add-compare.wat` and `tablegrow-add-compare.wat` also reduce in Binaryen, but this implementation slice deliberately landed only the select operand subset; compare-form pure-add grow operands were implemented by the later 2026-07-07 slice below.

Implementation changes:

- Added red-first coverage in `src/passes/simplify_globals_optimizing_test.mbt` for `simplify-globals-optimizing removes pure-add grow select guards`; it failed before implementation because `$guard` stayed mutable.
- Added a narrow `i32.add` independent-grow-argument predicate in `src/passes/simplify_globals_optimizing.mbt` for constant / `local.get` operands only.
- Widened the read-only-to-write select matcher for direct `memory.grow` and `table.grow` operands using that pure-add delta.
- Widened SGO-created cheap cleanup shells so the removed guard leaves the independent grow as `memory.grow; drop` or `table.grow; drop` while preserving the `i32.add` delta computation.

Validation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*pure-add grow select*'` failed `0/1` before implementation with `$guard` still mutable.
- Focused after implementation: `*pure-add grow select*` passed `1/1`; `*grow select*` passed `6/6`; `*memory*` passed `20/20`; `*table*` passed `27/27`.
- `moon fmt` passed.
- Full SGO file passed `278/278`.
- `moon test src/passes` passed `4427/4427`.
- `moon build --target native --release src/cmd` passed with pre-existing `pass_manager.mbt` warnings.
- Regular compare `.tmp/pass-fuzz-sgo-pure-add-grow-select-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- Dedicated compare `.tmp/pass-fuzz-sgo-pure-add-grow-select-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses; selected counts same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.
- Timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py`: `const-read` `0.557/1.620 ms` (`0.344x`), runtime propagation `0.621/2.728 ms` (`0.228x`), read-only-select `2.131/3.342 ms` (`0.638x`), initializer-folding `0.450/1.016 ms` (`0.443x`), startup-offsets `0.780/1.104 ms` (`0.706x`).

Status after this slice: SGO remains active. Broad generic Binaryen `FlowScanner` equivalence is not complete. The direct follow-up from this probe was to implement the corresponding pure-add `memory.grow` / `table.grow` compare-operand and if-return subsets; that follow-up is recorded in the 2026-07-07 section below.


## Pure-add grow compare operand FlowScanner slice

A 2026-07-07 recursive continuation implemented the follow-up source-backed positive left open by the pure-add select slice: independent `memory.grow` / `table.grow` compare operands whose grow delta is a nontrapping `i32.add` over constants or `local.get`s. The guarded global supplies only the other compare operand before the same-global guarded write, or the compare feeds a function-level `if return; set` tail.

Local Binaryen `version_130` probes under `.tmp/sgo-pure-arg-probes/` showed:

- `memgrow-add-compare.wat`: Binaryen makes `$guard` immutable and preserves `drop (memory.grow (i32.add (local.get ...) (i32.const 1)))`.
- `tablegrow-add-compare.wat`: Binaryen makes `$guard` immutable and preserves `drop (table.grow (local.get ...) (i32.add (local.get ...) (i32.const 1)))`.
- Added if-return probes `memgrow-add-compare-if-return.wat` and `tablegrow-add-compare-if-return.wat`; local `wasm-opt version 130 (version_130)` also makes `$guard` immutable while preserving the grow as a dropped effect.

Implementation changes:

- Added red-first coverage in `src/passes/simplify_globals_optimizing_test.mbt` for `simplify-globals-optimizing removes pure-add grow compare guards`, covering direct guarded-write and function-level if-return forms for both memory and table grows; it failed before implementation because `$guard` stayed mutable.
- Widened `sgo_compare_operand_independent_memory_read_at` and `sgo_compare_operand_independent_table_read_at` to accept the same narrow pure-add grow delta already used by the select subset.
- Widened SGO-created cheap compare cleanup shells so removed guard shells preserve the independent pure-add grow as `memory.grow; drop` or `table.grow; drop` in both empty-if and if-return cleanup forms.

Validation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*pure-add grow compare*'` failed `0/1` before implementation with `$guard` still mutable.
- Focused after implementation: `*pure-add grow compare*` passed `1/1`; `*grow compare*` passed `7/7`; `*memory*` passed `20/20`; `*table*` passed `27/27`; full SGO file passed `279/279`.
- `moon fmt` passed.
- `moon test src/passes` passed `4428/4428`.
- `moon build --target native --release src/cmd` passed with pre-existing `pass_manager.mbt` warnings.
- Regular compare `.tmp/pass-fuzz-sgo-pure-add-grow-compare-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- Dedicated compare `.tmp/pass-fuzz-sgo-pure-add-grow-compare-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses; selected counts same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.
- Timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py`: `const-read` `0.452/1.116 ms` (`0.405x`), runtime propagation `0.525/1.809 ms` (`0.290x`), read-only-select `1.832/2.278 ms` (`0.804x`), initializer-folding `0.432/0.972 ms` (`0.444x`), startup-offsets `0.632/0.849 ms` (`0.744x`).
- `moon info` passed with pre-existing warnings, full `moon test` passed `7867/7867`, and `git diff --check` passed.

Status after this slice: SGO remains active. Broad generic Binaryen `FlowScanner` equivalence is not complete. Pure-add grow select and compare operands are now covered for the narrow constant/`local.get` `i32.add` delta family, including function-level if-return tails, but arbitrary effectful siblings, broader value-flow into side-effect parents, extra guarded reads, and unprobed source/lit families remain open.

## Reverse pure-add grow select operand FlowScanner slice

A later 2026-07-07 recursive continuation closed the explicitly unprobed reverse/second-operand pure-add grow select shape. Local Binaryen `version_130` probes under `.tmp/sgo-pure-arg-probes/` showed that `memory.grow` / `table.grow` may appear as the first select value, followed by `global.get $guard` as the other select value and an independent constant condition, with the grow delta still limited to nontrapping `i32.add` over constants or `local.get`s. Binaryen makes `$guard` immutable for both guarded-write and function-level `if return; set` tails while preserving the grow as a dropped effect.

Local probe files:

- `memgrow-add-select-reverse.wat`
- `memgrow-add-select-reverse-if-return.wat`
- `tablegrow-add-select-reverse.wat`
- `tablegrow-add-select-reverse-if-return.wat`

Implementation changes:

- Added red-first coverage in `src/passes/simplify_globals_optimizing_test.mbt` for `simplify-globals-optimizing removes reverse pure-add grow select guards`, covering memory/table direct guarded-write and function-level if-return forms. Before implementation, the focused test failed because `$guard` stayed mutable.
- Widened `sgo_select_operand_independent_memory_read_at` and `sgo_select_operand_independent_table_read_at` to accept only this reverse pure-add grow operand order when the guarded global is not used by the grow ref/delta and reaches only the final same-global guard.
- Widened SGO-created select cleanup shells so the reverse pure-add grow is preserved as `grow; drop` in both empty-if and if-return forms.

Validation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*reverse pure-add grow select*'` failed `0/1` before implementation with `$guard` still mutable.
- Focused after implementation: `*reverse pure-add grow select*` passed `1/1`; `*pure-add grow select*` passed `2/2`; `*grow select*` passed `7/7`; full SGO file passed `280/280`.
- `moon fmt` passed.
- `moon test src/passes` passed `4429/4429`.
- `moon build --target native --release src/cmd` passed with pre-existing `pass_manager.mbt` warnings.
- Regular compare `.tmp/pass-fuzz-sgo-reverse-pure-add-grow-select-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- Dedicated compare `.tmp/pass-fuzz-sgo-reverse-pure-add-grow-select-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses; selected counts same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.
- Timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py`: `const-read` `0.465/1.092 ms` (`0.426x`), runtime propagation `0.512/1.947 ms` (`0.263x`), read-only-select `1.879/2.455 ms` (`0.765x`), initializer-folding `0.379/0.863 ms` (`0.439x`), startup-offsets `0.637/0.889 ms` (`0.717x`).
- `moon info` passed with pre-existing warnings, full `moon test` passed `7868/7868`, and `git diff --check` passed.

Status after this slice: SGO remains active. Pure-add grow select/compare now covers both operand orders that have been locally probed and source-backed for this narrow family, including if-return tails. This still does **not** implement arbitrary Binaryen `FlowScanner` parent/child equivalence, guarded-value-to-grow-delta flow, arbitrary side-effect parents, extra guarded reads, or unprobed source/lit families.

## Independent call `i32.add` operand FlowScanner slice

A later 2026-07-07 recursive continuation moved from grow-specific follow-ups to a broader parent/child `FlowScanner` classification slice. Local Binaryen `version_130` probes showed that an independent zero-parameter/result call may be the sibling operand of the guarded global under a pure `i32.add` parent. The call is an unremovable side effect in the condition, but the guarded global value does not determine the call's behavior; it only reaches the pure add and final same-global guarded write or function-level `if return; set` tail.

Local probe files under `.tmp/sgo-flowscanner-probes/`:

- `call-sibling-add-direct.wat`
- `call-sibling-add-if-return.wat`
- `call-sibling-add-reverse-direct.wat`
- `call-sibling-add-reverse-if-return.wat`

Local `wasm-opt version 130 (version_130)` reduced all four to immutable `$guard` while preserving the independent call as `drop (call $imp)`.

Implementation changes:

- Added red-first focused coverage in `src/passes/simplify_globals_optimizing_test.mbt` for `simplify-globals-optimizing removes independent call add guards`, covering direct and reverse operand orders for guarded-write and function-level if-return forms. Before implementation, the focused test failed because `$guard` stayed mutable.
- Added a narrow `sgo_pure_i32_add_operand_independent_call_read_at(...)` matcher in `src/passes/simplify_globals_optimizing.mbt`. It accepts only zero-parameter/result calls that supply the other `i32.add` operand; the guarded global must not feed the call and must reach only the final same-global guarded write or if-return tail.
- Widened SGO-created compare-style cleanup shells to treat this `i32.add` parent like the already-preserved independent-call compare shells, rewriting removed guard debris to `call; drop` in empty-if and if-return forms.

Validation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*independent call add guards*'` failed `0/1` before implementation with `$guard` still mutable.
- Focused after implementation: `*independent call add guards*` passed `1/1`; `*call*guards*` passed `8/8`; full SGO file passed `282/282`.
- `moon fmt` passed.
- `moon test src/passes` passed `4431/4431`.
- `moon build --target native --release src/cmd` passed with pre-existing `pass_manager.mbt` warnings.
- Regular compare `.tmp/pass-fuzz-sgo-call-add-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- Dedicated compare `.tmp/pass-fuzz-sgo-call-add-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses; selected counts same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.
- Timing with `SGO_TIMING_REPEATS=15 SGO_TIMING_WARMUP=3 python3 .tmp/sgo-timing/measure_sgo_timing.py`: `const-read` `0.478/1.121 ms` (`0.426x`), runtime propagation `0.556/1.895 ms` (`0.293x`), read-only-select `1.858/2.281 ms` (`0.815x`), initializer-folding `0.373/0.826 ms` (`0.452x`), startup-offsets `0.628/0.875 ms` (`0.718x`).
- `moon info` passed with pre-existing warnings, and full `moon test` passed `7870/7870`.

Status after this slice: SGO remains active. This is a broader source-backed parent/child FlowScanner subset than the previous grow-only follow-ups, but it is still intentionally narrow: it does not allow guarded-value-to-call-argument flow, arbitrary side-effect parents, non-`i32.add` effectful sibling parents without probes/tests, extra guarded reads, or generic Binaryen `FlowScanner` equivalence.


## 2026-07-07 independent call nontrapping `i32` binary FlowScanner slice

A later recursive continuation broadened the preceding independent-call `i32.add` parent/child slice. Local Binaryen `version_130` probes under `.tmp/sgo-flowscanner-probes/` showed that `wasm-opt --all-features --simplify-globals-optimizing -S` reduces direct and reverse sibling-call forms for nontrapping pure `i32` binary operators (`i32.sub`, `i32.mul`, `i32.and`, `i32.or`, `i32.xor`, `i32.shl`, `i32.shr_s`, `i32.shr_u`, `i32.rotl`, `i32.rotr`, with `i32.add` already covered) to an immutable `$guard` while preserving the independent call as `call; drop`. Paired trapping probes using `i32.div_s` and `i32.rem_u` kept `$guard` mutable, so div/rem remain explicitly excluded.

Implementation stayed narrow in `src/passes/simplify_globals_optimizing.mbt`: `sgo_is_nontrapping_i32_binary_flow_instr(...)` enumerates only the accepted nontrapping operators, the read classifier still requires a zero-parameter/one-result independent call and same-global guarded-write or function-level `if return; set` tail, and the SGO-created cleanup shells preserve the call as `call; drop`. Guarded-value-to-call-argument flow and arbitrary side-effect parents remain outside this subset.

Test-first evidence: `simplify-globals-optimizing removes independent call nontrapping i32 binary guards` failed before implementation because `$guard` stayed mutable; after implementation, that focused test passed, including a trapping `i32.div_s` negative that keeps `$guard` mutable. Follow-up validation passed focused call-guard tests `9/9`, full SGO file `283/283`, `moon fmt`, `moon test src/passes` `4432/4432`, and native `src/cmd` build with pre-existing `pass_manager.mbt` warnings. Direct compare smokes `.tmp/pass-fuzz-sgo-call-binary-genvalid-1000` and `.tmp/pass-fuzz-sgo-call-binary-dedicated-1000` each requested/compared `1000/1000`, normalized `1000`, and had zero mismatches/failures; the dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`. Representative pass-local timing remained under the user-required `<=1x` Binaryen median: `const-read` `0.473/1.113 ms` (`0.425x`), runtime propagation `0.540/1.810 ms` (`0.298x`), read-only-select `1.893/2.168 ms` (`0.873x`), initializer-folding `0.373/0.879 ms` (`0.425x`), and startup-offsets `0.610/0.883 ms` (`0.691x`). Broad generic `FlowScanner` equivalence is still open.

## 2026-07-07 independent call nontrapping `i32` binary `i32.eqz` suffix FlowScanner slice

A later recursive continuation probed the next pure-parent chain above the independent-call binary sibling family. Local Binaryen `version_130` accepts conditions where `global.get $guard` and an independent zero-parameter/one-result call feed a nontrapping pure `i32` binary operator, and that binary result then flows through `i32.eqz` before the final same-global guarded write or Binaryen's function-level `if return; set` matcher. Direct/reverse `i32.mul`-style probes and an if-return probe reduced `$guard` to immutable while preserving the independent call as `call; drop`; the paired trapping `i32.div_s; i32.eqz` probe kept `$guard` mutable.

Local probe files under `.tmp/sgo-flowscanner-probes/`:

- `call-sibling-i32-mul-eqz-direct.wat`
- `call-sibling-i32-mul-eqz-reverse.wat`
- `call-sibling-i32-mul-eqz-if-return.wat`
- `call-sibling-i32-div-eqz-direct.wat`

Implementation stayed deliberately narrow in `src/passes/simplify_globals_optimizing.mbt`: after the existing nontrapping `i32` binary call sibling matcher, Starshine now permits only an `i32.eqz` pure suffix before the guarded-write / if-return tail. Broader pure suffix chains, const-fed compares, arbitrary side-effect parents, guarded-value-to-call-argument flow, extra guarded reads, and trapping div/rem parents remain excluded until separately probed and tested. SGO-created cleanup shells now reduce the generated `const; call; nontrapping-binary; i32.eqz; empty-if` and if-return/drop forms to `call; drop`, preserving the independent call.

Test-first evidence: `simplify-globals-optimizing removes independent call binary pure suffix guards` failed before implementation because `$guard` stayed mutable. After implementation, focused coverage passed including direct guarded-write, reverse if-return, and trapping `i32.div_s; i32.eqz` negative shapes. Follow-up validation passed focused call-guard tests `10/10`, full SGO file `284/284`, `moon fmt`, `moon test src/passes` `4433/4433`, and native `src/cmd` build with pre-existing `pass_manager.mbt` warnings. Direct compare smokes `.tmp/pass-fuzz-sgo-call-binary-eqz-genvalid-1000` and `.tmp/pass-fuzz-sgo-call-binary-eqz-dedicated-1000` each requested/compared `1000/1000`, normalized `1000`, and had zero mismatches/failures; the dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`. Representative pass-local timing remained under the user-required `<=1x` Binaryen median: `const-read` `0.522/1.213 ms` (`0.430x`), runtime propagation `0.594/1.996 ms` (`0.298x`), read-only-select `2.057/2.550 ms` (`0.807x`), initializer-folding `0.399/0.919 ms` (`0.433x`), and startup-offsets `0.647/0.908 ms` (`0.713x`). Broad generic `FlowScanner` equivalence remains open.

## Independent-call binary unary-suffix FlowScanner slice

A later 2026-07-07 recursive continuation probed one more pure-parent step after the independent-call/nontrapping-`i32` binary sibling family. Local Binaryen `version_130` accepts `i32.clz`, `i32.ctz`, and `i32.popcnt` as a single pure suffix above the nontrapping binary result before the same-global guarded write or function-level `if return; set` tail:

- `.tmp/sgo-flowscanner-probes/call-sibling-i32-mul-clz-direct.wat`
- `.tmp/sgo-flowscanner-probes/call-sibling-i32-mul-ctz-reverse.wat`
- `.tmp/sgo-flowscanner-probes/call-sibling-i32-xor-popcnt-if-return.wat`

`wasm-opt --all-features --simplify-globals-optimizing -S` reduced those probes to immutable `$guard` and preserved the independent zero-parameter/one-result call as `call $imp; drop`. The paired `.tmp/sgo-flowscanner-probes/call-sibling-i32-div-clz-direct.wat` kept `$guard` mutable, so trapping div/rem parents remain excluded even when followed by a nontrapping unary suffix.

Test-first implementation:

- Red first: `moon test --package jtenner/starshine/passes --file simplify_globals_optimizing_test.mbt --filter '*binary pure suffix guards*'` failed `0/1` before implementation because the `i32.clz` direct case kept `$guard` mutable.
- `src/passes/simplify_globals_optimizing_test.mbt` extends `simplify-globals-optimizing removes independent call binary pure suffix guards` with direct `i32.mul; i32.clz`, reverse `i32.mul; i32.ctz`, if-return `i32.xor; i32.popcnt`, and a trapping `i32.div_s; i32.clz` negative.
- `src/passes/simplify_globals_optimizing.mbt` now admits exactly one source-backed pure suffix from `i32.eqz`, `i32.clz`, `i32.ctz`, or `i32.popcnt` above the existing independent-call/nontrapping-`i32` binary matcher, and uses the same limit in SGO-created empty-if / if-return cleanup shells.

Validation after implementation:

- Focused `*binary pure suffix guards*` passed `1/1`.
- Focused `*call*guards*` SGO tests passed `10/10`.
- Full SGO focused file passed `284/284`.
- `moon fmt` passed.
- `moon test src/passes` passed `4433/4433`.
- `moon build --target native --release src/cmd` passed with pre-existing `pass_manager.mbt` warnings.
- Regular smoke `.tmp/pass-fuzz-sgo-call-binary-unary-suffix-genvalid-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses.
- Dedicated smoke `.tmp/pass-fuzz-sgo-call-binary-unary-suffix-dedicated-1000`: requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000` hits / `0` misses; selected leaves were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Representative timing remains under the user-required `<=1x` Binaryen median target: `const-read` `0.469/1.096 ms` (`0.428x`), runtime propagation `0.526/1.925 ms` (`0.273x`), read-only-select `1.941/2.298 ms` (`0.845x`), initializer-folding `0.379/0.862 ms` (`0.439x`), and startup-offsets `0.621/1.048 ms` (`0.593x`).

Status after this slice: this is still a narrow source-backed parent-chain slice, not generic `FlowScanner` equivalence. It does not admit const-fed comparisons, multiple or arbitrary pure suffix chains, non-`i32` call-result parent chains, guarded-value-to-call-argument flow, arbitrary side-effect parents, extra guarded reads, or trapping binary parents.

## Independent-call binary constant-fed comparison FlowScanner slice

A later 2026-07-07 recursive continuation probed constant-fed equality parents above the independent-call/nontrapping-`i32` binary family. Local Binaryen `version_130` reduced direct `i32.mul; i32.const 0; i32.eq`, constant-first reverse `i32.const 0; call; global.get; i32.mul; i32.ne`, and if-return `i32.xor; i32.const 1; i32.eq` probes to immutable `$guard`, preserving the independent call as `call; drop`. The paired `i32.div_s; i32.const 0; i32.eq` probe kept `$guard` mutable.

Starshine now admits exactly one constant-fed `i32.eq` / `i32.ne` comparison around the existing nontrapping binary result, in either comparison operand order and with either call/binary operand order, before the same-global guarded write or function-level `if return; set` tail. Cleanup preserves the call as `call; drop`. This does not generalize to relational comparisons, multiple suffixes, non-`i32` call results, trapping binary parents, guarded-value-to-call-argument flow, arbitrary side-effect parents, or generic `FlowScanner` equivalence.

Test-first evidence: focused `*binary pure suffix guards*` failed `0/1` before implementation because `$guard` stayed mutable, then passed `1/1`; focused call-guard tests passed `10/10`, full SGO passed `284/284`, `moon fmt`, `moon test src/passes` passed `4433/4433`, and native `src/cmd` build passed with pre-existing warnings. Regular `.tmp/pass-fuzz-sgo-call-binary-compare-const-genvalid-1000` and dedicated `.tmp/pass-fuzz-sgo-call-binary-compare-const-dedicated-1000` each compared/normalized `1000/1000` with zero failures; the dedicated lane selected same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`. Timing remained under the required 1x Binaryen median: `0.446x`, `0.308x`, `0.857x`, `0.471x`, and `0.714x` across the representative fixtures.

## Independent `i64` call binary suffix FlowScanner slice

A later 2026-07-07 recursive continuation classified the first non-`i32` independent-call parent chains. Local Binaryen `version_130` probes under `.tmp/sgo-flowscanner-probes/` showed:

- `call-sibling-i64-add-eqz-direct.wat`: immutable `$guard`, preserving `call $imp; drop`.
- `call-sibling-i64-mul-eq-const-reverse.wat`: immutable `$guard` for constant-first reverse equality, preserving the call.
- `call-sibling-i64-xor-eqz-if-return.wat`: immutable `$guard` through the function-level if-return matcher.
- `call-sibling-i64-div-eqz-direct.wat`: trapping `i64.div_s` keeps `$guard` mutable.
- `call-sibling-f32-add-lt-direct.wat` and `call-sibling-f64-mul-ne-reverse.wat`: float call-result arithmetic/comparison chains are also Binaryen-positive, but were deliberately left for the next bounded slice.

Test-first implementation added `simplify-globals-optimizing removes independent i64 call binary suffix guards`. The focused command failed `0/1` before implementation because `$guard` remained mutable. Starshine now enumerates nontrapping `i64` integer binary parents and admits exactly one `i64.eqz` or one constant-fed `i64.eq` / `i64.ne` suffix, covering direct/reverse call operands, constant-first comparison, and guarded-write / if-return tails. SGO-created cleanup preserves the independent call as `call; drop`. Trapping div/rem, relational comparisons, deeper chains, float call-result chains, arbitrary calls/effect parents, call-argument flow, and extra guarded reads remain excluded.

Validation after implementation:

- Focused `*independent i64 call binary suffix guards*`: `1/1`.
- Focused `*call*guards*`: `11/11`.
- Full SGO file: `285/285`.
- `moon fmt`, `moon info`, and native release build passed; build retained pre-existing `pass_manager.mbt` warnings.
- `moon test src/passes`: `4434/4434`; full `moon test`: `7873/7873`.
- Final regular `.tmp/pass-fuzz-sgo-call-i64-binary-suffix-genvalid-1000-final` and dedicated `.tmp/pass-fuzz-sgo-call-i64-binary-suffix-dedicated-1000-final`: each requested/compared `1000/1000`, normalized `1000`, zero mismatches/failures, Binaryen cache `1000/0`. Dedicated selections were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Final post-fix timing: const-read `0.419x`, runtime propagation `0.287x`, read-only-select `0.839x`, initializer folding `0.481x`, startup offsets `0.803x`.
- `git diff --check` passed before documentation updates.

Status: SGO remains active. Float independent-call parent chains are now source/probe-classified as positive and are the next high-value implementation slice. Broad generic `FlowScanner` equivalence and final full-matrix freshness remain open.

## Independent float call binary-comparison FlowScanner slice

A later 2026-07-07 recursive continuation implemented the Binaryen-positive `f32` / `f64` parent chain left by the `i64` slice. Local `version_130` probes under `.tmp/sgo-flowscanner-probes/` established that an independent zero-parameter/one-result float call and guarded same-typed float global may feed one IEEE float binary parent, followed by exactly one same-typed float comparison with a constant, before either a same-global guarded write or Binaryen's function-level `if return; set` tail.

Positive probes covered direct and reverse binary operands, result-first and constant-first comparison order, guarded-write and if-return tails, IEEE `f32.div`, `f32.min` with NaN, and `f64.copysign`. Binaryen made `$guard` immutable and preserved the independent call as `call; drop` for:

- `call-sibling-f32-add-lt-direct.wat`
- `call-sibling-f64-mul-ne-reverse.wat`
- `call-sibling-f32-div-ge-reverse-if-return.wat`
- `call-sibling-f64-copysign-le-direct.wat`
- `call-sibling-f32-min-nan-eq-direct.wat`
- `call-sibling-f64-add-gt-const-first.wat`

Paired negatives `call-sibling-f32-flow-into-call-negative.wat` and `call-sibling-f64-extra-read-negative.wat` kept `$guard` mutable when the guarded value flowed into a call argument or when an extra guarded read escaped the admitted chain.

Test-first implementation added `simplify-globals-optimizing removes independent float call binary comparison guards`. The focused command failed `0/1` before implementation because the first `f32` guard remained mutable. `src/passes/simplify_globals_optimizing.mbt` now enumerates `f32` / `f64` `add`, `sub`, `mul`, `div`, `min`, `max`, and `copysign`, requires one same-typed `eq`, `ne`, `lt`, `gt`, `le`, or `ge` comparison with a float constant, supports both binary and comparison operand orders, and cleans generated empty-if / if-return shells to `call; drop`. It does not admit guarded-value-to-call-argument flow, extra guarded reads, deeper or multiple pure suffixes, arbitrary calls/effectful parents, or generic parent-stack equivalence.

Validation after implementation:

- Focused float parent-chain test: `1/1`.
- Focused `*call*guards*`: `12/12`.
- Full SGO file: `286/286`.
- `moon fmt`, `moon info`, and native release build passed with pre-existing warnings.
- `moon test src/passes`: `4435/4435`; full `moon test`: `7874/7874`.
- Regular `.tmp/pass-fuzz-sgo-call-float-binary-compare-genvalid-1000` and dedicated `.tmp/pass-fuzz-sgo-call-float-binary-compare-dedicated-1000`: each requested/compared `1000/1000`, normalized `1000`, zero mismatches or failures, Binaryen cache `1000` hits / `0` misses. Dedicated selections were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Representative timing remained below the user-required `1x` Binaryen median: const-read `0.480/1.070 ms` (`0.448x`), runtime propagation `0.568/1.869 ms` (`0.304x`), read-only-select `2.265/3.314 ms` (`0.684x`), initializer folding `0.441/0.963 ms` (`0.458x`), and startup offsets `0.752/0.981 ms` (`0.766x`).

Status after this slice: the known typed independent-call chains now include narrow `i32`, `i64`, `f32`, and `f64` families. Broad generic `FlowScanner` parent/child equivalence remains open, especially arbitrary effectful siblings, deeper pure chains, broader value flow into side-effect parents, extra reads, and any unprobed source/lit families. Final closeout also still requires a freshness decision and likely rerun of the full four-lane matrix after these narrow additions.

## Generic scalar straight-line parent-chain slice

A later 2026-07-07 recursive continuation replaced the one-suffix ceiling for the independent-call scalar family with a reusable typed straight-line provenance parser. Local Binaryen `version_130` probes confirmed that all of the following keep the call independent, make `$guard` immutable, and preserve `call $imp; drop`:

- `.tmp/sgo-flowscanner-probes/call-sibling-i32-deep-unary.wat`: `i32.add; i32.clz; i32.eqz`.
- `.tmp/sgo-flowscanner-probes/call-sibling-i32-relational.wat`: `i32.add; i32.const 7; i32.lt_s`.
- `.tmp/sgo-flowscanner-probes/call-sibling-f32-unary-compare.wat`: `f32.add; f32.abs; f32.const 0; f32.lt`.
- `.tmp/sgo-flowscanner-probes/call-sibling-f32-promote-f64-compare-if-return.wat`: `f32.add; f64.promote_f32; f64.const 0; f64.ge` through the function-level if-return tail.
- `.tmp/sgo-flowscanner-probes/call-sibling-i32-sibling-unary-before-parent.wat`: an independent `call; i32.clz` sibling before the guarded-value `i32.add` parent.

The paired `.tmp/sgo-flowscanner-probes/call-sibling-i32-trapping-param-suffix-negative.wat` kept `$guard` mutable when a parameter-fed `i32.div_s` parent could trap based on the guarded-derived numerator. A constant-one division probe optimized because that particular denominator makes the probed operation nontrapping; it is not evidence for admitting generic integer div/rem.

Test-first evidence: `simplify-globals-optimizing removes generic scalar call parent chains` failed `0/1` before implementation on the first deep-`i32` guard, then passed `1/1`. `src/passes/simplify_globals_optimizing.mbt` now tracks scalar `i32` / `i64` / `f32` / `f64` value kind through arbitrary result-first nontrapping unary/conversion and constant-fed binary/comparison parents after the first independent-call/global parent. It also accepts a same-type pure unary chain on the global-first independent call result before that first parent. Generated empty-if and if-return shells use the same parser and collapse to `call; drop`. The parser deliberately excludes trapping float-to-int truncations and integer div/rem.

Validation after implementation:

- Focused generic scalar test `1/1`; focused `*call*guards*` `12/12`.
- Full SGO file `287/287`; `moon test src/passes` `4436/4436`; full `moon test` `7875/7875`.
- `moon fmt`, `moon info`, and native release build passed with pre-existing warnings.
- Regular `.tmp/pass-fuzz-sgo-generic-scalar-parent-chain-genvalid-1000` and dedicated `.tmp/pass-fuzz-sgo-generic-scalar-parent-chain-dedicated-1000` each compared/normalized `1000/1000` with zero mismatches or failures and Binaryen cache `1000/0`. Dedicated selections were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Representative timing remained within the user-required `<=1x` Binaryen median: const-read `0.497/1.138 ms` (`0.437x`), runtime propagation `0.601/1.870 ms` (`0.321x`), read-only-select `2.126/2.233 ms` (`0.952x`), initializer folding `0.405/0.896 ms` (`0.451x`), and startup offsets `0.667/0.874 ms` (`0.762x`).

Status after this slice: straight-line scalar parent depth is no longer artificially capped for the implemented result-first constant-fed model, but full Binaryen `FlowScanner` equivalence remains open. Important remaining discriminators include reverse call-result unary chains before the first parent, constant-first operands at arbitrary later depths, generic independent loads/grows/writes/calls represented as siblings rather than the existing enumerated shells, structured result parents, and a general proof that dependent values never reach unremovable effects. Final full-matrix freshness remains outstanding.

## Multiple constant-first scalar parent-depth slice

A later 2026-07-07 continuation probed the remaining constant-first discriminator with local Binaryen `version_130`. Both `.tmp/sgo-flowscanner-probes/call-sibling-i32-multiple-constant-first-parents.wat` and the reverse-first-parent variant became immutable and reduced to `call $imp; drop`. Their flat condition shape keeps `i32.const 9` and `i32.const 7` below the guarded expression; after `global.get/call/i32.add`, `7` is consumed by `i32.mul` and `9` by `i32.lt_s`.

Strict TDD evidence: `simplify-globals-optimizing removes multiple constant-first scalar call parents` failed `0/1` before implementation because the first `$guard` remained mutable. `src/passes/simplify_globals_optimizing.mbt` now records a contiguous typed constant prefix and consumes it in LIFO order while parsing later pure parents. The cleanup prefix parser distinguishes `constants; global-const; call; parent` from `constants; call; global-const; parent`, passes the remaining prefix bounds into the same suffix grammar, and emits `call; drop` only after every prefix constant is consumed.

Validation after implementation:

- Focused new test `1/1`; generic scalar test `1/1`; call-guard tests `12/12`; full SGO `288/288`.
- `moon fmt`, `moon info`, `moon test src/passes` (`4437/4437`), full `moon test` (`7876/7876`), and native release build passed with pre-existing warnings.
- Regular `.tmp/pass-fuzz-sgo-constant-first-parent-depth-genvalid-1000` and dedicated `.tmp/pass-fuzz-sgo-constant-first-parent-depth-dedicated-1000` each requested/compared/normalized `1000/1000` with zero mismatches or failures and Binaryen cache `1000/0`. Dedicated selections: same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, read-only-to-write `227`.
- Representative timing stayed within the required `<=1x` median: const-read `0.514/1.116 ms` (`0.461x`), runtime propagation `0.661/2.015 ms` (`0.328x`), read-only-select `2.271/2.455 ms` (`0.925x`), initializer folding `0.428/0.917 ms` (`0.467x`), startup offsets `0.673/0.975 ms` (`0.690x`).

Status after this slice: the contiguous constant-first scalar parent-depth gap is closed for the independent-call grammar. Reverse pre-parent unary cleanup, generic independent-effect siblings, structured parents, and final full four-lane freshness remain open.

## Reverse pre-parent independent scalar fragment cleanup slice

A later 2026-07-07 continuation converted the three reverse-order probes into focused cleanup tests. Local Binaryen `version_130` reduced all three to immutable `$guard` while preserving only the independent computation required by effects:

- `.tmp/sgo-flowscanner-probes/call-sibling-i32-reverse-preparent-unary.wat` -> `call; drop`.
- `.tmp/sgo-flowscanner-probes/call-sibling-conversion-reverse-preparent-unary.wat` -> `call; drop`.
- `.tmp/sgo-flowscanner-probes/call-sibling-i32-reverse-preparent-trapping-unary.wat` -> `call; i32.trunc_f32_s; drop`.

The same-type `i32.clz` test was already green in the inherited worktree. Strict red-first evidence came from the type-changing nontrapping conversion and trapping conversion tests: each failed `0/1` before implementation because Starshine left the pure guard shell after making the global immutable. `src/passes/simplify_globals_optimizing.mbt` now parses a bounded independent scalar fragment after the call. Nontrapping scalar unary/conversion instructions are removable; trapping float-to-int truncations are recorded and replayed in original order before the final `drop`. The guarded-dependent scalar grammar still excludes trapping instructions, so this widening applies only to the independent sibling fragment.

Validation after implementation:

- Focused reverse pre-parent tests: `3/3`; full SGO file: `291/291`.
- `moon fmt` and `moon info` passed with pre-existing warnings.
- `moon test src/passes`: `4440/4440`; full `moon test`: `7879/7879`.
- Native release `src/cmd` build passed with pre-existing `pass_manager.mbt` warnings.
- Regular `.tmp/pass-fuzz-sgo-reverse-preparent-unary-genvalid-1000` and dedicated `.tmp/pass-fuzz-sgo-reverse-preparent-unary-dedicated-1000` each requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures; Binaryen cache was `1000/0`. Dedicated selections were same-init/dead-set `132`, runtime propagation `210`, startup propagation `129`, nested cleanup `148`, initializer folding `154`, and read-only-to-write `227`.
- Representative direct timing remained within the user-required `<=1x` Binaryen median: const-read `0.512/1.143 ms` (`0.448x`), runtime propagation `0.617/1.937 ms` (`0.318x`), read-only-select `2.274/2.328 ms` (`0.977x`), initializer folding `0.423/0.893 ms` (`0.473x`), and startup offsets `0.693/0.890 ms` (`0.778x`).

Status after this slice: reverse independent-call pre-parent scalar cleanup is closed for removable unary/conversion fragments and replayed trapping float-to-int truncations. Generic independent-effect producers, structured result parents, complete source/lit family classification, and a fresh final four-lane matrix remain open.

## 2026-07-07 generic independent scalar producer slice

Local Binaryen `version_130` probes extended the flat parent/child classification from zero-parameter scalar calls to two additional producer classes: removable `memory.size` and trap-capable constant-address scalar loads. Direct `global.get; memory.size; i32.clz; i32.add` and reverse `memory.size; f64.convert_i32_s; global.get; f64.add` guards reduce completely after `$guard` becomes immutable. A constant-address `i32.load` sibling also permits the guard removal, but Binaryen preserves the potentially trapping load as `i32.const; i32.load; drop`. A guarded value used as the load address remains mutable.

Strict TDD evidence: the direct memory-size unary, reverse memory-size conversion, and independent-load trap tests failed `0/3` before implementation; the guarded-load-address negative was already green. `SgoScalarIndependentFragment` now shares producer result kind, instruction bounds, and replay policy between detection and cleanup. The admitted producer set is deliberately bounded to zero-parameter scalar calls, `memory.size`, and constant-address scalar loads; pure producer-local unary/conversion instructions disappear, trap-capable float-to-int conversions replay in order, and the dependent guarded path still excludes traps/effects.

After rebasing the dirty worktree onto local `main` at `c24acc74a`, conflicts were resolved by retaining newer main OI/index work while combining the inherited SGO/INL changes. Validation then passed: focused pre-parent `6/6`, full SGO `295/295`, `moon info`, `moon fmt`, `moon test src/passes` `5086/5086`, full `moon test` `8529/8529`, and native release build. Direct Binaryen/Starshine probe WAT matched for all four positive/negative fixtures. Regular and dedicated `.tmp/pass-fuzz-sgo-generic-scalar-producer-post-rebase-{genvalid,dedicated}-1000` lanes each requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures; Binaryen cache was `1000/0`, and dedicated selections remained `132/210/129/148/154/227` across the six leaves.

The final 15-repeat post-rebase timing run remained within the strict `<=1x` target, but with narrow headroom: const-read `0.549/1.182 ms` (`0.465x`), runtime propagation `0.637/2.028 ms` (`0.314x`), read-only-select `2.417/2.465 ms` (`0.981x`), initializer folding `0.415/0.893 ms` (`0.465x`), and startup offsets `0.875/0.877 ms` (`0.997x`).

## 2026-07-07 bounded structured scalar producer slice

Local Binaryen v130 probes under `.tmp/sgo-structured-probes/` classified five structured cases. A direct pure result block, reverse result block containing a constant-address load, a pure result `if`, and a call-conditioned result `if` all permit the guarded global to become immutable. Binaryen removes pure envelopes, preserves the load as `load; drop`, and preserves the condition call as `call; drop`. When the guarded global itself is the result-`if` condition selecting an observable call arm, Binaryen keeps the global mutable.

Strict TDD added four focused tests. Before implementation, the direct block and call-conditioned `if` left the global mutable; the reverse load block made the global immutable but retained the structured guard debris. The guarded-condition negative was already green. `SgoScalarIndependentFragment` now records explicit replay bounds and a nested-block replay flag. The bounded grammar admits only single-result numeric `ValTypeBlockType` blocks and result `if`s with pure constant/unary arms; conditions are removable local/constant values or zero-parameter i32 calls. It does not admit arbitrary control, branches, loops, effectful arms, type-index/multivalue blocks, or guarded-value-to-condition flow.

Validation: focused structured tests are green; full SGO passes `300/300`; `moon test src/passes` passes `5091/5091`; `moon fmt` and native release build pass with existing warnings. All five direct Binaryen/Starshine probe outputs match except generated symbol names. Regular and dedicated `.tmp/pass-fuzz-sgo-structured-producers-{genvalid,dedicated}-1000` lanes each requested/compared/normalized `1000/1000`, with zero mismatches or failures and Binaryen cache `1000/0`; dedicated selections are `132/210/129/148/154/227`. Fifteen-repeat timing remains within 1x: `0.433x`, `0.327x`, `0.990x`, `0.438x`, and `0.930x` across the five representative fixtures.

Status after this slice: bounded structured result producers are no longer the immediate blocker. Broader independent grows/writes or source-backed exclusions, complete Binaryen v130 source/lit classification, and final fresh regular `100000`, wasm-smith `10000`, dedicated `10000`, and random-all `10000` lanes remain open.

## 2026-07-07 structured `memory.grow` producer slice

Local Binaryen v130 probes under `.tmp/sgo-structured-effect-probes/` classified the next bounded effectful result-block family. Direct and reverse blocks that execute an independent `memory.grow` before yielding a scalar allow the guarded global to become immutable; Binaryen preserves the grow as `delta; memory.grow; drop`. The same is true when the delta is the nontrapping `local.get/const/i32.add` family already accepted by the flat grow matcher. A guarded global used as the grow delta remains mutable. Existing direct store and different-global-set result blocks already matched Binaryen; an observable local-set block remains a separate cleanup/parity gap.

Strict TDD added two positive grow tests and one guarded-delta negative. Before implementation both positives failed because the global remained mutable; the negative was green. `sgo_scalar_result_block_effect_prefix(...)` now recognizes only the probed constant/local delta and pure-add delta forms, and `SgoScalarIndependentFragment` replays the grow-producing prefix while the existing cleanup adds the required drop. It does not admit arbitrary block effects, guarded operands, table grows, local/global writes, branches, loops, type-index blocks, or multivalue blocks.

Validation: focused structured-grow tests pass `3/3`; full SGO passes `303/303`; `moon test src/passes` passes `5094/5094`; full `moon test` passes `8537/8537`; `moon info`, `moon fmt`, native release build, and `git diff --check` pass with pre-existing warnings. Direct Binaryen/Starshine probe WAT differs only in generated names. Regular and dedicated `.tmp/pass-fuzz-sgo-structured-grow-{genvalid,dedicated}-1000` lanes each requested/compared/normalized `1000/1000`, with zero mismatches or failures and Binaryen cache `1000/0`; dedicated selections are `132/210/129/148/154/227`. Fifteen-repeat timing remains within 1x: const-read `0.521/1.135 ms` (`0.459x`), runtime propagation `0.629/1.939 ms` (`0.324x`), read-only-select `2.331/2.425 ms` (`0.961x`), initializer folding `0.388/0.850 ms` (`0.456x`), and startup offsets `0.855/0.982 ms` (`0.870x`).

Status after this slice: structured independent memory growth is covered for the bounded source-probed forms. Observable local-write result blocks, table-grow structured producers, branchful/type-index/multivalue control, complete source/lit inventory, and the final fresh four-lane matrix remain open.

## 2026-07-07 structured observable local-write and `table.grow` slice

Local Binaryen `version_130` probes under `.tmp/sgo-structured-effect-probes/` showed that direct/reverse constant `local.set`, direct `local.tee; drop`, and parameter-fed local writes inside a scalar result block all permit the guarded global to become immutable. When the local has one observable use after the guard, Binaryen returns the constant/parameter directly. With two later reads, Binaryen keeps the assignment but folds the reads to constants; this remains a separate Starshine cleanup gap. A guarded global used as the local-write value remains unsafe. Independent `ref.null/local-or-const delta/table.grow/drop/result-const` blocks are also accepted and preserve `table.grow; drop`; a guarded-global delta remains negative.

Strict TDD added three local-write positives, one local-write negative, one table-grow positive, and one guarded-delta negative. The positives failed before implementation because direct local/table forms left the global mutable and reverse local-set retained size-losing local traffic; negatives passed. `sgo_scalar_result_block_effect_prefix(...)` now admits only exact independent local-set/local-tee and table-grow prefixes. Local replay uses `local.tee` so the existing discarded-result drop remains stack-valid; a narrow cleanup folds `value; local.tee; drop; local.get` only when no other target-local reference exists. Table replay retains ref, delta, and `table.grow`, with the shared cleanup adding the final drop.

Validation after implementation: focused local result-block `4/4`, focused table-grow `2/2`, full SGO `309/309`, `moon test src/passes` `5100/5100`, full `moon test` `8543/8543`, `moon info`, `moon fmt`, native release build, and `git diff --check` passed with pre-existing warnings. Direct probe instruction streams match Binaryen; the remaining one-use output difference is Starshine's unused local declaration. Regular and dedicated `.tmp/pass-fuzz-sgo-structured-local-table-{genvalid,dedicated}-1000` lanes each requested/compared/normalized `1000/1000`, with zero mismatches/failures and Binaryen cache `1000/0`; dedicated selections were `132/210/129/148/154/227`.

The first 15-repeat timing sample put read-only-select at `1.013x`, so it was not accepted. An immediate 31-repeat/5-warmup rerun met the strict `<=1x` bar: const-read `0.516/1.177 ms` (`0.438x`), runtime propagation `0.625/1.930 ms` (`0.324x`), read-only-select `2.342/2.357 ms` (`0.993x`), initializer folding `0.384/0.891 ms` (`0.431x`), and startup offsets `0.839/0.925 ms` (`0.907x`).

Status after this slice: the single-observable-use local-write and independent table-grow result-block families are implemented. Multiple local reads and unused-local declaration cleanup remain output-size parity gaps; branchful/type-index/multivalue structured families, complete source/lit classification, and the final fresh four-lane matrix remain open.

## 2026-07-07 repeated-local and structured-control slice

Local Binaryen v130 probes under `.tmp/sgo-current-audit/` refined the remaining structured inventory:

- constant local writes followed by two reads and `i32.add` retain Binaryen's assignment but fold the result to `i32.const 84`; parameter-fed cases already reduce to repeated parameter reads, and reassignment folds from the later value;
- single-result type-index blocks are positive and were already handled by Starshine's exact block cleanup;
- independent scalar `loop` and branchful scalar result-block producers are positive;
- a result `if` with an independent effectful call arm and guarded read in the other arm is positive and Starshine already makes the global immutable, though its cleanup shape remains slightly weaker;
- a true two-result type-index block remains mutable in Binaryen, so multivalue is a source-backed exclusion rather than a parity gap;
- guarded reads flowing from inside a scalar loop or branchful result block are positive in Binaryen and remain active Starshine gaps.

Strict TDD captured the implementation gaps. The repeated-local focused test failed `0/1`, and the independent loop/branchful tests failed `0/2`, before implementation. The cheap cleanup now folds only the exact no-overflow constant two-read add tail when the target local has no other references. The scalar fragment classifier now replays scalar loops and otherwise-unclassified scalar result blocks only when their bodies contain no global references, preserving the structured producer and dropping its unused result.

Validation passed: repeated-local `1/1`, structured-control `2/2`, full SGO `312/312`, `moon test src/passes` `5103/5103`, full `moon test` `8546/8546`, `moon info`, `moon fmt`, native release build, and `git diff --check`, with existing warnings only. Regular and dedicated `.tmp/pass-fuzz-sgo-structured-control-{genvalid,dedicated}-1000` lanes each requested/compared/normalized `1000/1000`, with zero mismatches or failures and Binaryen cache `1000/0`; dedicated selections remained `132/210/129/148/154/227`.

The local cleanup is a measured Starshine win rather than unproven drift: stripped pass-local output is `47` bytes versus Binaryen's `51`, and shared `wasm-opt --all-features -Oz --strip-debug` produces byte-identical `37`-byte outputs. The accepted 31-repeat timing run remains within the strict 1x target: const-read `0.423x`, runtime propagation `0.298x`, read-only-select `0.906x`, initializer folding `0.480x`, and startup offsets `0.966x`.

Status after this slice: independent branchful blocks and loops are implemented conservatively, and true multivalue is explicitly excluded by Binaryen behavior. Guarded-value flow inside loops/branchful blocks, final source/lit inventory, unused-local declaration classification, and the fresh final four-lane matrix remain open.

## 2026-07-07 guarded structured value-flow slice

Local Binaryen v130 probes under `.tmp/sgo-current-audit/guarded-structured-slice/` confirm that a guarded global value may flow out of an exact scalar result `loop`, or through the value arm of an exact branchful scalar result block, and then through the existing pure scalar suffix to either the same-global guarded write or the whole-function `if return; set` tail. The paired dangerous structured condition fixture, where the global selects an observable call arm, remains mutable.

Strict TDD added direct/reverse loop and guarded-write/if-return branchful tests. The two positive tests failed `0/2` before implementation because both globals stayed mutable; the dangerous-flow guardrail was green. `sgo_structured_guarded_scalar_read(...)` now recognizes only an exact `loop (result scalar) { global.get }` or the probed `global.get; local.get; br_if; drop; scalar.const` block. It reuses the existing typed pure-suffix matcher and does not admit arbitrary structured effects or nested conditions.

Validation passed: focused guarded structured tests `2/2`, guardrail `1/1`, full SGO `315/315`, pass tests `5106/5106`, full tests `8549/8549`, `moon info`, `moon fmt`, native release build, and `git diff --check`, with pre-existing warnings only. Regular and dedicated `.tmp/pass-fuzz-sgo-guarded-structured-{genvalid,dedicated}-1000` lanes each requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures; Binaryen cache was `1000/0`. Dedicated selections were `132/210/129/148/154/227` across the six leaves.

The accepted 51-repeat/10-warmup timing run remains within the strict 1x target: const-read `0.470x`, runtime propagation `0.340x`, read-only-select `0.977x`, initializer folding `0.450x`, and startup offsets `0.932x`. Two earlier 31-repeat samples put read-only-select at `1.022x` and `1.011x`; the larger accepted sample is retained to make the noise-sensitive decision explicit.

Two residual output-shape gaps were measured, not accepted as safe drift. The one-use local case is `46` bytes stripped for Starshine versus Binaryen `44`, converging to identical `36`-byte downstream `-Oz` output. The effectful result-if arm cleanup was initially `65` versus `63` stripped, converging to identical `34`-byte downstream output. A trial local-declaration removal was reverted because it invalidated local-name indices on the timing fixture; any future fix must update names/annotations consistently. Final full-count matrix freshness remains open.

## 2026-07-07 effectful result-if cleanup and explicit source-family inventory

The measured effectful result-if cleanup gap is now closed test-first. The new focused fixture leaves an independent result `if` after SGO replaces the guarded read and removes the same-global write. Before implementation, Starshine retained `result-if; empty void if`; the red test observed that exact shell. The cheap cleanup now rewrites only `i32` result-`if` followed immediately by an empty void `if` to `result-if; drop`, preserving the condition, arm effects, traps, and result evaluation. Starshine and Binaryen now produce identical stripped `63`-byte output on `.tmp/sgo-current-audit/residual-local-slice/effectful-result-if.wat`.

Validation after the change: focused cleanup `1/1`, focused side-effecting-select guardrails `4/4`, full SGO `316/316`, and `moon test src/passes` `5107/5107`; `moon info`, `moon fmt`, native release build, and `git diff --check` passed with pre-existing warnings. Regular and dedicated `.tmp/pass-fuzz-sgo-effectful-result-if-{genvalid,dedicated}-1000` lanes each compared and normalized `1000/1000` with zero mismatches or failures and Binaryen cache `1000/0`; dedicated selections were same-init/dead-set `132`, runtime `210`, startup `129`, nested cleanup `148`, initializer `154`, and read-only-to-write `227`.

The v130 source/lit inventory is semantic rather than an opcode checklist:

| Binaryen owner family | Source/lit contract | Current audit classification |
| --- | --- | --- |
| Analysis and practical immutability | imports/exports, concrete gets/sets, non-init writes, and read-only-to-write counts; private never-written globals become immutable | Implemented for the represented module surfaces; broad transform evidence is covered by focused tests and dedicated profiles. |
| Single-use initializer folding | only one concrete read, no writes/export, and use in module initialization rather than repeatable function execution | Implemented; function-use, multi-use, import/export, and generative/reference guardrails remain covered. |
| Remove unneeded writes | never-read, only-init-written, or all reads classified read-only-to-write; preserve value evaluation as `drop` and iterate after read-only-to-write removal | Implemented for audited constant/reference and read-only-to-write families; fixpoint/nested official shapes are covered. |
| Earlier immutable-copy preference | follow copy chains to the earliest ancestor only when the replacement global type exactly matches | Implemented exact-type behavior. Subtype/refinalization widening is a source-backed non-feature in v130 because the source retains an explicit TODO. |
| Startup propagation | propagate known earlier constants through later globals and active element/data offsets | Implemented for represented constant expressions; typed element item expressions remain conservative where Starshine lacks refinalization proof. |
| Runtime linear trace | immutable and prior-set constants propagate until calls, relevant writes, or nonlinear control invalidate facts | Implemented audited straight-line/block/if subsets with call/control/reference guardrails; broader `LinearExecutionWalker` carrier breadth remains an audit item, not an accepted exclusion. |
| Optimizing wrapper | rerun default function optimization on functions changed by constant application or set removal, without the DAE/inlining precompute prefix | Implemented through the documented touched-function cleanup roster and SGO-owned exact cleanup fast paths. |
| `FlowScanner` safe value flow | for each guarded `global.get`, walk every parent/child pair; reject a parent with unremovable effects; reject use as a nested `if` condition unless that nested `if` is itself the same read-only-to-write pattern; otherwise the value may flow through arbitrary removable parents even when independent sibling effects exist | Many flat, independent-effect, bounded structured, and exact guarded structured families are implemented. **Generic arbitrary structured parent/child reconstruction remains open**; it cannot be closed by enumerating opcodes because the source contract is path/parent based. |
| Source/lit negatives | if-else outer guard, extra unmatched reads, body effects beyond the one target write, effect-summary-only calls without concrete get/set nodes, guarded value into call/local write/store/grow operands, dangerous nested condition, inexact whole-function shape, imported/exported target, and true multivalue probe | Explicitly negative or conservatively guarded. True multivalue is additionally confirmed Binaryen-negative by local v130 probe. |

This table closes the top-level `SimplifyGlobals.cpp` family inventory, but not the broad `FlowScanner` implementation criterion. Remaining work is now narrower and explicit: either implement a general index-aware parent/child flow record for arbitrary single-result structured carriers, or probe and document each remaining structured class as Binaryen-negative/source-excluded. The metadata-aware unused-local declaration gap also remains open.

Timing is currently a blocker rather than accepted evidence. Three unpinned 51-repeat/10-warmup runs after the cleanup measured read-only-select at `1.055x`, `1.075x`, and `1.031x`; the last run improved after moving the new matcher behind existing specialized shells, but still missed the strict `<=1x` decision. CPU-affinity experiments distorted Binaryen's internally parallel function scan and are not accepted. The earlier accepted `0.977x` run remains historical evidence, not a fresh post-change signoff. Final full-count matrix freshness also remains open.

## 2026-07-07 pure structured-parent and timing recovery slice

Local Binaryen `version_130` probes under `.tmp/sgo-current-audit/structured-parent-next/` closed three remaining single-result structured carrier discriminators. Binaryen makes the guarded global immutable when it flows through a pure scalar result `loop`, through nested pure result `block` / `loop` parents, or through a pure result `try_table` wrapped by its result block. The paired loop fixture where the guarded value controls a nested observable `if` remains mutable, matching the source-level dangerous-condition rule.

Strict TDD captured the gaps: `promotes guarded values through pure result-loop parents`, `promotes guarded values through nested pure structured parents`, and `promotes guarded values through pure try-table parents` each failed with a mutable global before implementation. The guarded scalar carrier recognizer now walks a bounded recursive producer chain across single-result `block`, `loop`, and `try_table` nodes and accepts only typed nontrapping scalar unary plus constant-fed binary/comparison parents. Existing result-`if`, exact branchful block, independent-effect, nested same-pattern, and dangerous-condition rules remain separate and unchanged. True multivalue remains Binaryen-negative.

The fresh timing blocker was fixed independently. The read-only-select fixture's post-SGO body has one common whole-function shape: constant select arm, constant-address `i32.load`, dead `local.tee`, constant-foldable guarded condition, `select`, and a now-dead `const; drop` if body. A first attempted generic whole-select precheck was rejected after a 51-repeat run regressed to `1.106x`. The accepted fast path recognizes only that exact already-proven shell before recursive cleanup, preserves `i32.load; drop`, and avoids the broad matcher/fixed-point roster. Fresh unpinned 51-repeat/10-warmup medians in `.tmp/sgo-current-audit/structured-parent-next/timing-final-51x.txt` are: const-read `0.534/1.219 ms` (`0.438x`), runtime propagation `0.639/1.955 ms` (`0.327x`), read-only-select `1.035/2.409 ms` (`0.430x`), initializer folding `0.386/0.870 ms` (`0.444x`), and startup offsets `0.843/0.922 ms` (`0.915x`). This restores substantial honest headroom without CPU affinity.

Validation after the final changes: focused SGO `319/319`, pass tests `5110/5110`, full repo `8553/8553`, `moon info`, `moon fmt`, and native release build passed with pre-existing warnings. Final development smokes `.tmp/pass-fuzz-sgo-structured-parent-final-{genvalid,dedicated}-1000` each requested/compared/normalized `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures and Binaryen cache `1000/0`; dedicated selections were `132/210/129/148/154/227`.

Status after this slice: pure single-result structured carrier classes are now covered across `block`, `loop`, `if` (earlier result-if slices), and `try_table`, with dangerous nested conditions, guarded values entering effects, and true multivalue explicitly negative. Remaining closeout work is the metadata-aware one-use local declaration gap and the fresh final four-lane matrix. Before running the expensive matrix, one final source/probe review should confirm that no type-index single-result or independent-effect structured carrier shape falls outside the already documented exact handlers.

## 2026-07-07 final structured review and metadata-safe local cleanup

The final source/probe review under `.tmp/sgo-current-audit/final-source-probes/` checked single-result type-index `block`, `loop`, and result-`if` carriers against local Binaryen `version_130` and rebuilt Starshine. All three make the guarded globals immutable in both tools. Starshine reaches these forms through the existing exact type-index block/effect handlers and result/control matchers; no new broad recursive arm was added, avoiding the previously observed duplicate safe-read counting. The already documented independent-effect structured handlers cover calls, memory/table queries and growth, local/global writes, stores, table writes/copies/init/fill, and element drops under exact operand-independence rules. True multivalue, dangerous nested conditions, and guarded values entering effect operands remain source/probe-backed negatives. This closes the broad `FlowScanner` structured-family classification for the current v130 audit without claiming byte-for-byte cleanup shape parity.

The remaining one-use local declaration gap was fixed test-first through the existing `reorder-locals` remapping implementation. Adding a zero-local assertion to `simplify-globals-optimizing folds observable result-block local set` failed red with `1 != 0`. SGO nested cleanup had skipped `reorder-locals` after earlier cleanup removed the last local instruction, because candidate detection inspected only body uses. The candidate check now also sees declarations on touched functions. The touched-only reorder runner records each function's `old_to_new` map and rewrites structured local-name metadata with the shared reorder-locals name remapper instead of clearing declarations directly or retaining stale indices. Function annotations are function-indexed and remain unchanged. The focused test is green, and the stripped one-use fixture now matches Binaryen at `44` bytes instead of `46`.

Validation after the fix: focused SGO `319/319`, pass tests `5110/5110`, full repo `8553/8553`, `moon info`, `moon fmt`, native release build, and `git diff --check` passed with pre-existing warnings. Fresh regular and dedicated development lanes `.tmp/pass-fuzz-sgo-localfix-{genvalid,dedicated}-1000` each requested/compared/normalized `1000/1000`, with zero mismatches, validation/generator/property failures, or command failures and Binaryen cache `1000/0`. Fresh unpinned 51-repeat/10-warmup timing in `.tmp/sgo-current-audit/final-source-probes/timing-after-localfix-51x.txt` remains below the strict 1x bar: const-read `0.474x`, runtime propagation `0.328x`, read-only-select `0.429x`, initializer folding `0.430x`, and startup offsets `0.879x`.

Status after this slice: the source-family review and local declaration parity blockers are closed.

## 2026-07-07 final fresh four-lane closeout

The rebuilt `_build/native/release/build/cmd/cmd.exe` completed the required direct pass matrix without compare normalizers:

- Regular GenValid: `.tmp/pass-fuzz-sgo-final-genvalid-100000`, seed `0x5eed`, requested/compared/normalized `100000/100000/100000`, zero cleanup-normalized matches, mismatches, validation/generator/property failures, or command failures. Binaryen cache: `100000` hits / `0` misses; selected profile `binaryen-oracle-portable: 100000`.
- Dedicated `simplify-globals-optimizing-all`: `.tmp/pass-fuzz-sgo-final-dedicated-10000`, seed `0x5eed`, requested/compared/normalized `10000/10000/10000`, zero cleanup-normalized matches, mismatches, or failures. Binaryen cache: `10000/0`. Selected leaves: same-init/dead-set `1404`, runtime propagation `2206`, startup propagation `1445`, nested cleanup `1427`, initializer folding `1391`, and read-only-to-write `2127`.
- Explicit wasm-smith: `.tmp/pass-fuzz-sgo-final-wasm-smith-10000`, seed `0x5eed`, requested `10000`, compared/normalized `9956/9956`, zero cleanup-normalized matches, mismatches, validation/generator/property failures, and `44` command failures. Cache: wasm-smith `10000/0`, Binaryen successes `9956/0`, Binaryen failures `44/0`. Agent classification: all non-compares are Binaryen/tool failures, not SGO mismatches: `binaryen-rec-group-zero` `39`, `binaryen-invalid-tag-index` `1`, `binaryen-table-index-out-of-range` `1`, and `binaryen-bad-section-size` `3`.
- Random all-profiles: `.tmp/pass-fuzz-sgo-final-random-all-10000`, seed `0x5555`, requested/compared/normalized `10000/10000/10000`, zero cleanup-normalized matches, mismatches, or failures. Binaryen cache: `10000/0`. All 15 selected leaves were sampled: `binaryen-oracle-portable` `1148`, `coverage-forced-portable` `1102`, `pass-fuzz-stress` `1117`, `ssa-nomerge-parity` `1126`, `ssa-nomerge-smoke` `1154`, `local-subtyping-straight-line` `551`, `local-subtyping-structured` `549`, `coalesce-locals-straight-line` `438`, `coalesce-locals-structured` `322`, `coalesce-locals-loop-copy-through` `332`, `heap2local-array` `295`, `heap2local-ref` `308`, `heap2local-struct` `484`, `duplicate-import-elimination-functions` `800`, and `duplicate-import-elimination-nonfunction` `274`.

Final classification: zero true semantic mismatches, zero raw output mismatches, zero Starshine validation or command failures, and no unclassified transform family. The source-backed exclusions remain true multivalue, dangerous guarded-value nested conditions, and guarded values entering effect operands. The latest strict 51-repeat timing remains `<=1x` Binaryen on every representative fixture (`0.474x`, `0.328x`, `0.429x`, `0.430x`, `0.879x`). `[O4Z-AUDIT-SGO]` is complete for the current Binaryen v130 / Starshine v0.1.0 scope; plain `simplify-globals` remains a separate boundary-only pass.
