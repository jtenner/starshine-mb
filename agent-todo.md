# Agent Tasks

## Scope
- Keep only unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Keep each slice actionable enough to implement directly without re-deriving the architecture.
- Move completed work to `CHANGELOG.md`.

## v0.1.0 Active Slice

### Binaryen no-DWARF default optimize pathway parity (`version_129`, `-O` / `-Os`)

Goal
- Rebuild the full Binaryen no-DWARF default optimize path used by `tests/node/dist/starshine-debug-wasi.wasm`, including the nested rerun shape inside optimizing global passes.

Why
- The current public Starshine optimize preset is materially smaller than Binaryen's real no-DWARF path for the MoonBit debug artifact. Without an explicit per-pass backlog, pass work can land out of order and still miss preset parity.

Deliverables
- Keep the living no-DWARF pathway page in [docs/wiki/binaryen/no-dwarf-default-optimize-path.md](/home/jtenner/Projects/starshine-mb/docs/wiki/binaryen/no-dwarf-default-optimize-path.md#L1) as the canonical orientation document, and use the archived research note [0066](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L40) for detailed line-anchored pass notes until dedicated per-pass docs exist.
- Use Binaryen `version_129` source as the current upstream oracle for new pass research; the local workspace `wasm-opt` binary is still `version_125`, so command-based parity runs must be labeled accordingly until the toolchain is upgraded.
- Land every unique pass in the observed pathway and replay repeated cleanup slots where Binaryen repeats them.
- Add edge-case and regression coverage beside each implementing file and parity checks against Binaryen's MoonBit debug artifact output.

Required APIs
- Public `src/passes` registry and preset expansion.
- `src/cmd/cmd.mbt` dispatcher coverage for new pass flags or preset behavior.
- `scripts/self-optimize-compare.ts` for debug-artifact parity checks.
- `tests/node/dist/starshine-debug-wasi.wasm` as the canonical compare input.

Invariants
- Preserve the pre/function/post phase split from [0066#L40](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L40).
- Preserve nested reruns from [0066#L97](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L97).
- Preserve GC, multivalue, and string feature gates for this artifact.
- Do not collapse repeated cleanup slots into one occurrence unless the divergence is documented first.

Dependencies
- [0066 scope and current behavior](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L1)
- [0066 source anchors](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L23)

Exit Criteria
- Every unique pass below has research, implementation slices, edge/regression coverage, and MoonBit debug-artifact parity evidence.
- The public optimize preset can replay the top-level no-DWARF order for the MoonBit debug artifact.
- Nested reruns inside `dae-optimizing`, `inlining-optimizing`, and `simplify-globals-optimizing` are modeled or left as explicit blockers.

Suggested Tests
- `wasm-opt tests/node/dist/starshine-debug-wasi.wasm -O --all-features --debug`
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>`
- `moon test`
- `moon info && moon fmt`

Observed unique-pass order
- `DFE -> RUME -> MP -> OR -> GR -> GSI -> SSA -> DCE -> RUN -> RUB -> OI -> HSO -> PLS -> PC -> CP -> TO -> SLNS -> VQ -> RL -> H2L -> OC -> LS -> CL -> LCSE -> SL -> CF -> MB -> RSE -> DAE -> INL -> DIE -> SGO -> SG -> RG -> DIR`
- Canonical ordered path and nested-shape notes live at [0066#L42](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L42) and [0066#L97](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L97).

#### RUME - Remove Unused Module Elements
1. Canonical correctness landed.
   - [RUME]003 - Oracle-stable fast-path pass completed - Direct pass execution, CLI flag and registry wiring, focused section/index rewrite coverage, explicit memarg-index rewrites, and canonical compare-harness artifact parity are in place; `remove-unused-module-elements` is now canonically correct against the oracle on the debug artifact.
     - Deliverables: replay `remove-unused-module-elements` on `tests/node/dist/starshine-debug-wasi.wasm`; keep canonical compare parity green while tracking pass-time and wall-time trends; continue replaying ordered no-DWARF slots when preset ordering is available.
     - Current blocker: the initial targeted run `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --count 300 --max-failures 5 --out-dir .tmp/pass-fuzz-rume` found two `wasm-smith` parity mismatches before the old harness aborted on a thrown command failure, while the clean `gen-valid` sweep `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator gen-valid --count 500 --max-failures 5 --out-dir .tmp/pass-fuzz-rume-genvalid` was `500/500` normalized matches with no validation or generator failures. After fixing the harness to accumulate command failures, the rerun `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --count 300 --max-failures 20 --out-dir .tmp/pass-fuzz-rume-rerun` reached the cutoff with `85` compared cases, `79` normalized matches, `6` mismatches, `14` command failures, `0` validation failures, and `0` generator failures.
     - Mismatch classification from `.tmp/pass-fuzz-rume-rerun`: five `wasm-smith` mismatches are unused imported-module-element retention where Binaryen drops imports that Starshine preserves because `import_sec` is still copied through unchanged. The saved repros are `.tmp/pass-fuzz-rume-rerun/failures/case-000001-wasm-smith` (unused imported globals + memory + table), `.tmp/pass-fuzz-rume-rerun/failures/case-000005-wasm-smith` (unused imported memory), `.tmp/pass-fuzz-rume-rerun/failures/case-000019-wasm-smith` (unused imported funcref table), `.tmp/pass-fuzz-rume-rerun/failures/case-000061-wasm-smith` (unused imported arrayref table), and `.tmp/pass-fuzz-rume-rerun/failures/case-000097-wasm-smith` (unused imported eqref table). The sixth mismatch is `.tmp/pass-fuzz-rume-rerun/failures/case-000077-wasm-smith`, where Starshine preserves an empty active data segment that Binaryen removes.
     - Command-failure classification from `.tmp/pass-fuzz-rume-rerun`: Starshine decode/validation failures accounted for `5/14` cases, split into four `DecodeAt(InvalidLimits, ...)` cases (`000007`, `000055`, `000091`, `000099`) and one final-module validation failure `Invalid range for limits` (`000073`). Binaryen parser failures accounted for `9/14` cases, split into six `invalid type index` cases (`000009`, `000021`, `000031`, `000047`, `000079`, `000095`), one `Recursion groups of size zero not supported` case (`000029`), and two `invalid wasm type: -64` cases (`000081`, `000083`). These are fuzz-coverage blockers rather than RUME semantic mismatches, but they now persist cleanly for follow-up instead of aborting the run.
     - Post-fix replay status: the saved imported-element mismatch corpus and `.tmp/pass-fuzz-rume-rerun/failures/case-000077-wasm-smith` now match Binaryen under the rebuilt native `cmd` binary. Fresh post-fix compare evidence is `500/500` normalized matches on `.tmp/pass-fuzz-rume-postfix-genvalid` and `71/71` normalized matches with `0` mismatches on `.tmp/pass-fuzz-rume-postfix-smith-rerun` before the run hit `20` command failures.
     - Remaining blocker after semantic cleanup: the post-fix `wasm-smith` command-failure corpus is now coverage-only work. After landing explicit shared-memory support, the memory64 validator fix, extended-const arithmetic validation, the imported-table `nullref` elem cleanup, and the live-table `nullfuncref` retention fix, `.tmp/pass-fuzz-rume-live-nullfuncref-rerun` reached `165/165` normalized matches with `0` mismatches before the `20`-failure cutoff. Starshine contributes no command failures in that slice. The remaining `20/20` failure slots are Binaryen-side parser or canonicalization blockers: fourteen `invalid type index` cases (`000009`, `000021`, `000024`, `000031`, `000047`, `000050`, `000052`, `000054`, `000056`, `000079`, `000095`, `000124`, `000141`, `000143`), one `Recursion groups of size zero not supported` case (`000029`), two `invalid wasm type: -64` cases (`000081`, `000083`), and three later parser failures at `000162`, `000167`, and `000185`.
     - Doc: [0066#L148](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L148)
2. Do work.
   - Keep the landed direct pass stable while tightening Binaryen parity; do not widen the public preset order until the exact replay slots are available.
   - Imported module-element removal is now fixed: RUME drops unused imported memories, tables, globals, and tags, keeps imported parents only when active elem/data segments still initialize them, and remaps surviving imports through exports and name sections instead of preserving `import_sec` verbatim.
   - Empty-active-data parity is now fixed: RUME drops zero-byte active data segments on both defined and imported memories, matching Binaryen on `.tmp/pass-fuzz-rume-rerun/failures/case-000077-wasm-smith` and the later imported-memory repro from `.tmp/pass-fuzz-rume-postfix-smith/failures/case-000032-wasm-smith`.
   - The remaining post-fix work is no longer semantic RUME cleanup; it is Binaryen parser-compatibility coverage work outside Starshine pass behavior.
3. Test against binaryen.
   - Keep `moon test src/passes` and `moon test src/cmd` green while replaying the compare harness.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-module-elements` and any required ordered-prefix replay.
   - The saved imported-element mismatch repros under `.tmp/pass-fuzz-rume-rerun/failures/case-000001-wasm-smith`, `.tmp/pass-fuzz-rume-rerun/failures/case-000005-wasm-smith`, `.tmp/pass-fuzz-rume-rerun/failures/case-000019-wasm-smith`, `.tmp/pass-fuzz-rume-rerun/failures/case-000061-wasm-smith`, and `.tmp/pass-fuzz-rume-rerun/failures/case-000097-wasm-smith` now replay cleanly, and the targeted post-fix harness evidence is `.tmp/pass-fuzz-rume-postfix-genvalid` (`500/500`), `.tmp/pass-fuzz-rume-postfix-smith-rerun` (`71/71`, `0` mismatches), and the later shared-memory follow-up `.tmp/pass-fuzz-rume-sharedmem-rerun` (`121/121`, `0` mismatches, `20` command failures).
   - `.tmp/pass-fuzz-rume-rerun/failures/case-000077-wasm-smith` is now a focused regression in `src/passes/remove_unused_module_elements_test.mbt`; the later imported-memory variant from `.tmp/pass-fuzz-rume-postfix-smith/failures/case-000032-wasm-smith` is covered too.
   - Keep the accumulated command-failure corpus visible while fuzzing RUME so Starshine decoder/validator coverage (`000007`, `000055`, `000073`, `000091`, `000099`) and Binaryen parser-compatibility coverage (`000009`, `000021`, `000029`, `000031`, `000047`, `000079`, `000081`, `000083`, `000095`) can be replayed separately from semantic mismatch reduction.

#### DCE - Dead Code Elimination
0. Shared blocker on canonical artifact parity.
  - [HOT]001 - Post-SSA Hot-Pipeline Replay Hardening - The large-artifact `DFE -> RUME -> MP -> OR -> GR -> GSI -> SSA` prefix now completes, validates, and canonicalizes under Binaryen, and DCE itself no longer emits the invalid lowered output that previously blocked the chain on final dead-result control. The remaining ordered full-chain work is now downstream of that fix: rerun the exact post-SSA cleanup replay on a valid baseline artifact, refresh any remaining later-pass re-lift failures on the rebased branch, and keep the serial hot batch workable until the worker-queue slice is safe.
     - Deliverables: isolate the minimal post-DCE/post-vacuum artifact shape that still triggers any later `hot_lift_func` or cleanup replay abort; add red/green regression coverage for that exact replay shape; keep the ordered post-SSA cleanup chain (`DCE -> VQ -> OI -> SL`) re-liftable, Binaryen-parseable, and ready for the remaining parity and runtime budget work; cut large-artifact hot-pass wall time from the remaining hot-lift setup and GC churn so post-SSA replay is no longer dominated by lift overhead.
     - Current blocker: the currently-modeled cleanup prefix is now artifact-backed in-tree: native `cmd` regressions replay both `dead-code-elimination -> vacuum -> optimize-instructions -> simplify-locals` and the fuller modeled post-SSA cleanup prefix `dead-code-elimination -> remove-unused-names -> remove-unused-brs -> remove-unused-names -> vacuum -> remove-unused-brs -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> simplify-locals` on `tests/node/dist/starshine-debug-wasi.wasm`, and both validate the in-memory output module. The remaining hot-pipeline gap is therefore later ordered-prefix proof and runtime budget, not this cleanup segment. Large-artifact replay still remains over budget, but the old RUN no-op hotspot is now retired: fresh native `--remove-unused-names --debug-serial-passes` replay at `.tmp/run-artifact-rawskip` reports `skip-raw reason=no-remove-unused-names-candidates count=9746`, so the earlier giant if-only `Func 545` family no longer pays hot lift at all. The remaining wall-time concentration is further downstream in a much smaller set of very large functions, centered on a `br`-heavy nested `block` / `if` cluster plus one loop / `br_table` outlier. The earlier note that the normal self-opt compare entrypoint was blocked because `tests/node/dist/starshine-debug-wasi.wasm` failed baseline validation is now stale: a fresh `2026-04-10` rerun of `wasm-tools validate tests/node/dist/starshine-debug-wasi.wasm` succeeds, so direct artifact compare can now reach `ssa-nomerge`. `ssa-nomerge` no longer aborts during debug-artifact replay once synthetic continuation CFG blocks carry concrete insertion spans, and the current source build now restores artifact safety by fail-closing any rewritten function that fails module-aware writeback validation, but exact SSA parity is still open: the current traced replay `moon run src/cmd --target native -- --debug-serial-passes --tracing pass --ssa-nomerge --out /tmp/ssa-nomerge-current.wasm tests/node/dist/starshine-debug-wasi.wasm` records `skip-invalid-lower func=(Func 523) reason=writeback-validate:type mismatch` and also exposes `Func 3773` as `writeback-validate:stack underflow`, while Binaryen `wasm-opt --all-features --ssa-nomerge` succeeds on the same input. So SSA replay remains an active blocker that needs reduced repros plus renewed artifact signoff before DCE can be treated as the first downstream failure. The next downstream blocker after restoring SSA artifact safety remains `dead-code-elimination`: the debug artifact currently reduces to invalid `Func 1730`, `Func 544`, and local-limit `Func 545` lowering families, while the reduced split-payload wrapper repro now bails earlier as a safe no-op (`reason=trimmed-unreachable-split-wrapper`) instead of mutating into `skip-invalid-lower`. So the pass is still temporarily keeping originals on suspicious carrier shapes, rewritten single-function writebacks that fail validation against the module environment, or lowered local counts above the in-tree `50000` limit while those exact families are reduced into targeted regressions and real fixes.
     - Doc: [0066#L124](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L124)
  - [HOT]002 - Native Parallel Hot-Batch Queue - Add a native-only worker queue for the existing hot-function batch so large modules can amortize hot-lift and analysis setup across cores before the Node package port lands.
     - Deliverables: use the current hot batch boundary (`ssa-nomerge -> dead-code-elimination -> vacuum -> optimize-instructions -> simplify-locals`) as the worker payload; introduce an atomic queue over eligible defined functions; keep module passes and final merge deterministic; gate the worker path behind an explicit native-only option until the replay and perf story is stable.
     - Required APIs: `src/passes/pass_manager.mbt` scheduler surface; a native-only threading adapter built from `mizchi/threads`; stable per-function result handoff that does not share mutable MoonBit heap state across workers.
     - Invariants: do not reorder the public pass queue; keep final output byte-stable for unchanged function order; preserve current final-module validation behavior; keep worker-local IR state isolated and merge only serialized function results back on the main thread.
     - Dependencies: [HOT]001 replay hardening must stay green because the worker payload is the same hot batch and still depends on re-liftable post-pass output.
     - Exit Criteria: the native path can drain a queue of defined functions through the full hot batch without correctness regressions, has focused coverage for deterministic output and empty/single-function modules, and is ready for debug-artifact perf measurement against the current serial baseline.
     - Suggested Tests: `moon test src/passes`, `moon test src/cmd`, targeted perf coverage in `src/passes/perf_test.mbt`, and native debug-artifact replay with the worker path both on and off.
  - [IR2]001 - Hot Lower Payload-Forwarder Repair - Restore the canonical hot-lower behavior for typed payload-forwarder and returned-if shapes before landing more cleanup rewrites on top.
     - Deliverables: fix hot lowering for flattened parent-exit payloads, return-fed value-`if` forwarders, split `local.set` carry blocks, and nested branch-payload wrappers; preserve the expected `unreachable` materialization and avoid introducing extra result blocks around parent-exit payloads.
     - Current blocker: the full repo test suite is green again (`moon test` => `1929/1929`), so this is no longer an active red-test blocker. The remaining work is to refresh exact artifact-backed evidence for the still-risky payload-forwarder families and only reopen this slice if new ordered-prefix replay or focused `hot_lower` regressions show those shapes drifting from the intended typed-block and `unreachable` contracts. The latest stack-fix slice is now in-tree too: hot lowering no longer under-emits repeated shared operand nodes, with focused live repros for both the minimal shared-operand underflow and a loop-carried nested value-`if` / later-`drop` shape. The remaining work is replay proof on the large artifact, not another known reduced hot-lower red test.
     - Required APIs: `src/ir/hot_lower.mbt` payload packing and label-depth remap logic, `src/ir/hot_query.mbt` / `src/ir/hot_region_edit.mbt` helpers where needed for canonical shape detection, and pass tests that assert lowered WAT rather than only HOT structure.
     - Invariants: preserve explicit `unreachable` when a value-typed wrapper is voidified after a non-fallthrough inner exit; do not wrap parent-exit payloads in extra typed blocks; keep branch label targets stable when peeling nested payload blocks; do not regress the currently-green IR2 analysis overlays or lift/verify contracts.
     - Dependencies: [0059 architecture rules](/home/jtenner/Projects/starshine-mb/docs/0059-2026-03-24-ir2-architecture-rules.md), [0060 CFG contract](/home/jtenner/Projects/starshine-mb/docs/0060-2026-03-24-cfg-contract-and-block-boundary-rules.md), [0065 IR2 execution plan](/home/jtenner/Projects/starshine-mb/docs/0065-2026-03-24-ir2-execution-plan.md), and the returned-ladder shape research in [0070](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md) and [0071](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md).
     - Exit Criteria: the 6 current `src/ir/hot_lower_test.mbt` failures are green, no extra `moon test` regressions are introduced in `src/passes`, and the lowered forms for the listed fixtures match the intended typed-block / `unreachable` contracts.
     - Suggested Tests: `moon test src/ir`, `moon test src/passes`, and full `moon test`.
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L178](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L178)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [DCE]001 - Binaryen-Shape Cleanup Hardening - Close the remaining parity gaps in the existing DCE pass so it matches Binaryen's structured dead-result and unreachable cleanup rules.
     - Deliverables: audit current Starshine behavior against the documented Binaryen shape; fix any trap, type, or structured-region mismatches; keep mutation invalidation honest.
     - Doc: [0066#L178](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L178)
   - [DCE]002 - Prefix Regression and Artifact Replay - Lock the corrected DCE behavior into focused tests and rerun the MoonBit debug-artifact compare harness.
     - Deliverables: add red/green regressions for dead results, unreachable tails, and imported calls; replay `--dce` parity on the artifact; document any intentional remaining divergence.
    - Status: focused DCE regressions plus the earlier hot-lift/effects fixes are landed, and the suite is green again (`moon test` => `1929/1929`). A HOT-based live repro still locks the reduced typed-loop carrier hazard in DCE, and the later lowering-side stack bug behind the stale `Func 1730` checkpoint is now fixed in `hot_lower`: shared HOT operands are re-emitted correctly instead of being skipped by `node_id` reuse. The exact artifact path is now covered too by a native `cmd` regression that runs `--dead-code-elimination` on `tests/node/dist/starshine-debug-wasi.wasm` through `run_cmd_with_adapter` and validates the output module in-memory. The pure-drop oracle family is fixed, and the refreshed pass-fuzz evidence is now green at both `.tmp/pass-fuzz-dce-genvalid-50-after-pure-drop-fix` (`50/50`) and `.tmp/pass-fuzz-dce-genvalid-1000-after-pure-drop-fix` (`1000/1000`), both with `0` mismatches, `0` command failures, and `0` validation failures. Repo-side DCE correctness is no longer blocked on saved `gen-valid` mismatches; the remaining DCE work is runtime budget and valid-baseline ordered-prefix proof in `[DCE]003`.
    - Reproduce the refreshed corpus: `bun scripts/pass-fuzz-compare.ts --pass dead-code-elimination --generator gen-valid --count 1000 --max-failures 20 --out-dir .tmp/pass-fuzz-dce-genvalid-1000-after-pure-drop-fix`
     - Doc: [0066#L178](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L178)
   - [DCE]003 - Runtime Budget and Oracle Refresh - Close the remaining DCE speed gap and refresh parity evidence on a valid baseline/oracle path.
     - Deliverables: rerun single-pass and ordered-prefix DCE parity on a valid baseline artifact or refreshed oracle; measure Starshine and Binaryen on the same artifact after the final-tail fix; remove the remaining quadratic / GC-heavy work in final-root cleanup and post-SSA replay until DCE is at least `>= 50%` of Binaryen wall time.
     - Current blocker: the old baseline-validation note is stale. `moon run src/cmd -- --dead-code-elimination --out /tmp/dce-self-opt-out.wasm tests/node/dist/starshine-debug-wasi.wasm` now exits `0`, so the checked-in artifact itself is a valid baseline for DCE replay. The current blocker is native-path divergence: `_build/native/release/build/cmd/cmd.exe --dead-code-elimination --out /tmp/dce-self-opt-release-out.wasm tests/node/dist/starshine-debug-wasi.wasm` fails final validation with `stack underflow` in `(Func 1730)`, which is the same failure now tripping `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --dead-code-elimination` before Binaryen runs. Native embedded callers were also missing the stack-soft-limit raise that `main` already had; sharing that runtime prep through `run_cmd_with_adapter` removes the earlier native decode `SIGSEGV` and turns the new direct native-default-I/O artifact regression into the same clean `OptimizeFailed("final module validate ... (Func 1730)")` blocker. The dump artifacts now exist on that path too, and `/tmp/starshine-invalid-final-func.txt` is written as UTF-8 instead of UTF-16-with-NULs. The repo-side correctness gate is green in source-mode and fuzz-mode; the remaining blocker is reducing and fixing the dumped native DCE / lowering divergence before meaningful runtime or ordered-prefix parity numbers can be trusted.
     - Reproduce source-mode success: `moon run src/cmd -- --dead-code-elimination --out /tmp/dce-self-opt-out.wasm tests/node/dist/starshine-debug-wasi.wasm`
     - Reproduce native-release validator failure: `_build/native/release/build/cmd/cmd.exe --dead-code-elimination --out /tmp/dce-self-opt-release-out.wasm tests/node/dist/starshine-debug-wasi.wasm`
     - Reproduce compare-harness failure: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --dead-code-elimination`
     - Reproduce the native-default-I/O blocker directly in-test: `moon test --target native --package jtenner/starshine/cmd --file cmd_test.mbt --filter 'run_cmd reports dead-code-elimination native default-io blocker on debug artifact'`
     - Reproduce broader native-release instability: `moon test --target native --release --package jtenner/starshine/cmd --file cmd_test.mbt`
     - Inspect the dumped invalid module after a native failure: `wasm-tools validate /tmp/starshine-invalid-final.wasm` and `wasm-tools print /tmp/starshine-invalid-final.wasm`
     - Doc: [0066#L178](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L178)
   - [BIN]001 - Iterative Expr Decoder - Replace the current recursive binary expression decoder with an explicit worklist / stack machine so deeply nested valid wasm does not depend on native call-stack budget.
     - Goal: make `decode_expr_with_depth` and the instruction decoder robust on large artifact inputs without requiring `setrlimit`-style runtime setup.
     - Why: native `run_cmd` originally crashed in recursive `decode_instruction_with_depth` / `decode_expr_with_depth` frames on the checked-in DCE artifact until the CLI started raising the process stack limit before decode. That workaround unblocks current investigation, but the decoder strategy is still fragile and should not rely on platform stack size.
     - Deliverables: design and land an iterative decode path for nested expressions / control instructions; preserve exact decode errors and offsets; add large-depth regressions that exercise native `run_cmd` without extra runtime stack prep assumptions.
     - Exit criteria: large nested modules decode successfully under native callers without stack-limit hacks, and the recursive decoder no longer appears in the active native blocker path.
     - Reproduce the old failure shape: `gdb -batch -ex run -ex 'thread apply all bt' --args _build/native/release/test/cmd/cmd.blackbox_test.exe 'cmd_test.mbt:87-88'`
     - Relevant code: [`decode.mbt`](/home/jtenner/Projects/starshine-mb/src/binary/decode.mbt)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.
   - For reduced or artifact-backed stable-boundary signoff, prefer `--binaryen-nop-until-stable <max> --require-binaryen-nop-converged`; documented non-converging multivalue-call writeback from [0074](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0074-2026-04-02-binaryen-multivalue-call-local-disparity.md) is not a `reorder-locals` sorter blocker.

#### RUB - Remove Unused Brs
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L188](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L188)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [RUB]001 - Branch Liveness and Structured Repair - Port the branch-pruning logic that removes dead branch traffic while preserving valid structured control flow.
     - Deliverables: compute dead target edges and forwarding opportunities; repair block signatures and branch values; preserve trap and effect ordering.
     - Doc: [0066#L188](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L188)
   - [RUB]002 - Multi-Slot Cleanup and Artifact Compare - Replay the pass in each Binaryen slot and confirm later `merge-blocks` opportunities match the reference output.
     - Deliverables: add early, mid, and late slot coverage; write regressions for branch-value and typed-block cases; compare the pass on the MoonBit debug artifact.
     - Current blocker: the top-level scheduler gap is now fixed: `optimize` and `shrink` both replay `remove-unused-brs` in three modeled slots, focused preset tests cover those trace counts, and the old `Func 24`, `Func 299`, `Func 1329`, and `Func 7756` serial verifier failures are fixed in-source. `Func 7756` was a multi-value branch-payload rewrite bug: RUB now refuses to collapse a branch-payload `if` when the surviving payload side would be forwarded as fewer branch slots than the original `br` carried. The old single-pass artifact gate at `Func 807` is no longer red either: a native `cmd` regression now replays `--remove-unused-brs` on `tests/node/dist/starshine-debug-wasi.wasm` through `run_cmd_with_adapter` and validates the output module in-memory. The first two saved oracle families are fixed too: Binaryen-style explicit `nop` bodies in trivial `if` arms are preserved in-source, and lone explicit root `nop`s are preserved only when they were the whole body instead of leaving a stray `nop` behind after multi-root trimming. Fresh `gen-valid` oracle evidence is now green at `.tmp/pass-fuzz-rub-genvalid-100-after-root-nop-count-fix` (`100/100`), `.tmp/pass-fuzz-rub-genvalid-1000-rerun` (`1000/1000`), and `.tmp/pass-fuzz-rub-genvalid-10000` (`10000/10000` compared, `10000/10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures) under the `--min-compared 10000` guard. The old early ordered-prefix abort is now retired: the explicit native prefix `memory-packing -> once-reduction -> global-refining -> global-struct-inference -> ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-brs` now completes and validates on `tests/node/dist/starshine-debug-wasi.wasm`, and the stale native `cmd` regression has been flipped to a green validation replay. The reduced fix is now locked in-source too: `src/ir/hot_lower_test.mbt` covers the mixed-depth stack-style `if ... return` carrier shape, `src/passes/remove_unused_brs_test.mbt` covers the same shape through the pass pipeline, `src/passes/simplify_locals_test.mbt` covers dead-tee control-label rehoming, and `src/ir/ssa_local_test.mbt` now guards the nested unreachable-sentinel SSA case by filtering unreachable predecessors out of phi-input sorting. With those fixes in place, the full native replay `moon run src/cmd --target native -- --optimize -O4z --out /tmp/o4z-full-after-ssa-fix.wasm tests/node/dist/starshine-debug-wasi.wasm` now completes and writes a valid output artifact. The next real step is no longer crash reduction inside the schedule; it is parity/perf work. The compare harness still cannot accept preset flags like `--optimize`, but the expanded 19-pass replay is saved at `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-84254` and is still red: canonical wasm and normalized WAT differ, Starshine is far over budget (`125505.903 ms` wall / `94367.953 ms` pass with `skip-raw=yes`) versus Binaryen (`2018.340 ms` wall / `1557.040 ms` pass), and the first visible normalized-WAT drift starts in real function bodies near line `1108`, not just in type ordering. Follow-up should therefore start from that artifact diff instead of revisiting the retired `simplify-locals` crash.
     - Saved mismatch cases: `000002`, `000004`, `000005`, `000006`, `000007`, `000010`, `000011`, `000012`, `000013`, `000019`, `000020`, `000021`, `000022`, `000023`, `000024`, `000025`, `000026`, `000027`, `000028`, `000031` under `.tmp/pass-fuzz-rub-genvalid-1000/failures/case-000XXX-gen-valid`.
     - Reproduce the corpus: `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-10000`
     - The old sampled mismatch `case-000002-gen-valid` is now fixed: Binaryen preserves explicit `nop` bodies in trivial `if` arms and Starshine now does too. The focused lock is `src/passes/remove_unused_brs_test.mbt` test `remove-unused-brs preserves explicit nop-only if arms`.
     - The next sampled root-`nop` family is also fixed: the intermediate spot-check `.tmp/pass-fuzz-rub-genvalid-100-after-if-arm-nop-fix` retired `case-000021-gen-valid`, `case-000050-gen-valid`, and `case-000066-gen-valid`, while the follow-on spot-check `.tmp/pass-fuzz-rub-genvalid-100-after-root-nop-count-fix` reaches `100/100` and retires the transient `case-000054-gen-valid`, `case-000074-gen-valid`, and `case-000084-gen-valid` families too.
     - Reproduce the latest green spot-check: `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 100 --max-failures 5 --out-dir .tmp/pass-fuzz-rub-genvalid-100-after-root-nop-count-fix`
     - The larger `gen-valid` reruns are now green too: `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 1000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-1000-rerun` => `1000/1000` normalized matches, `0` mismatches, `0` command failures, and `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-10000` => `10000/10000` compared cases, `10000/10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures.
     - Next oracle step: broaden non-`gen-valid` coverage or ordered-prefix proof instead of spending more budget on the now-green `gen-valid` lane.
     - Doc: [0066#L188](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L188)
   - [IR]003 - Lifted Label Ownership Repro for RUB Artifact Gate - Reduce `Func 24` from the MoonBit debug artifact to a standalone `hot_lift`/verify repro so RUB artifact compare can resume.
     - Deliverables: add a focused IR repro test or fixture for `InvalidLabelOwner(4, 16)`, fix the lifted label-owner corruption, and re-run the debug-artifact `remove-unused-brs` compare with serial verification enabled.
     - Status: the in-tree repros now cover both the malloc-shaped `Func 24` case and the loop string-reader `Func 299` case in `src/passes/remove_unused_brs_test.mbt`. The label-owner corruption is fixed for value-`if` select rewrites, one-armed `if br` rewrites, and exit-only value-`if` voidification by preserving the original label owner instead of replacing labeled `If` nodes in place. RUB now also refuses to voidify exit-only result `if`s once their single-use chain escapes the safe `local.tee` / holder-root ladder into a regular value op, which keeps wrapped shapes typed and green under `after_each_pass` verification instead of mutating them into later invalid control/value mixtures. The later `Func 7756` branch-arity failure is also fixed with focused regressions for multi-slot payload ladders and multi-value branch-payload `if` arms, and the stale `Func 807` single-pass stack-underflow gate is now covered green by a native `cmd` artifact replay test. The remaining work is later ordered-prefix evidence, not replaying the already-fixed label-owner, branch-arity, single-pass validate, or exit-only use-chain cases.
     - Required APIs / invariants: every lifted control label must keep `hot_control_node_label(func, label.owner) == label_id`, region labels must stay attached to `Block` owners, and pre-pass verification must succeed before any RUB pass work starts.
     - Suggested tests: `moon test src/ir`, `moon test src/passes`, `STARSHINE_DEBUG_SERIAL_PASSES=1 _build/native/release/build/cmd/cmd.exe --remove-unused-brs --out .tmp/rub-artifact-serial.wasm tests/node/dist/starshine-debug-wasi.wasm`.
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### PC - Precompute
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L208](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L208)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [PC]001 - Constant Folding Surface - Audit the exact constant, tuple, and local-evaluable fragments Binaryen folds in the top-level `precompute` slots for `-O` / `-Os`.
     - Deliverables: map foldable op families; preserve trap behavior and feature typing; note the difference between top-level `precompute` and nested `precompute-propagate`.
     - Status: initial exact-const integer fold core now includes constant-`if` folding, `precompute` is wired as an active hot pass in both modeled slots, guarded writeback still skips the known invalid carry-wrapper lower shape instead of emitting bad wasm, the repaired `gen-valid` lane is green through `.tmp/pass-fuzz-pc-genvalid-10000` (`10000/10000`, `0` mismatches), native `cmd` has a checked-in debug-artifact replay regression for `--precompute`, and the old false `writeback-validate:invalid function index` wall is fixed by validating rewritten bodies against the full module environment instead of isolating them from their real call targets.
     - Current blocker: direct compare still differs on the debug artifact, but the remaining gap is now much narrower and looks real. Fresh evidence is `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-459440`: canonical wasm and normalized WAT still differ, Starshine remains over budget (`12304.719 ms` wall, `2164.450 ms` pass) versus Binaryen (`601.615 ms` wall, `116.189 ms` pass), and traced native `--precompute --debug-serial-passes` replay is down to `14` skipped functions instead of the old `1189` false-invalid-index skips. The remaining skip set is concentrated in one `stack underflow` case (`Func 1950`) plus the existing `invalid-escape-carrier` family (`Func 1882`, `Func 2132`-`2145`), so follow-up work should reduce those real lower-shape blockers rather than revisiting module-context validation.
     - Doc: [0066#L208](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L208)
   - [PC]002 - Early/Late Slot Regression and Artifact Parity - Harden the pass for both top-level slots and compare the resulting folds against Binaryen on the debug artifact.
     - Deliverables: add regressions for early and late folding opportunities; verify interaction with surrounding cleanup passes; replay `--precompute` parity on the artifact.
     - Current focus: keep the new native debug-artifact replay regression green, use `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-459440` plus traced native `--precompute` runs to reduce the remaining `stack underflow` / `invalid-escape-carrier` skips, and then revisit runtime once canonical parity is closer; the fuzz parity gate for `precompute` itself is already green.
     - Doc: [0066#L208](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L208)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### CP - Code Pushing
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L213](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L213)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [CP]001 - Motion Safety Rules - Port Binaryen's code-motion rules for pushing work deeper into control flow without duplicating invalid side effects.
     - Deliverables: encode effect and trap guards for movable expressions; preserve control dependence and size heuristics; define the bailout cases clearly.
     - Doc: [0066#L213](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L213)
   - [CP]002 - Rewrite Coverage and Artifact Validation - Implement the move and test it against branchy, trap-sensitive fixtures plus the MoonBit debug artifact.
     - Deliverables: add regressions for duplicated work, traps, and branch-local constants; wire the pass into the early slot; compare Starshine and Binaryen pass output.
     - Doc: [0066#L213](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L213)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### TO - Tuple Optimization
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0076#L1](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md#L1)
   - Current conclusion: Binaryen's pass is a conservative tuple-local lowering pass, but the first Starshine port should be HOT-native because current HOT lift already models most relevant raw-wasm shapes as shared multi-result producers plus scalar spill locals instead of explicit tuple AST nodes.
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [TO]005 - Exact Slot Gate And Oracle Proof - Keep `tuple-optimization` active on the explicit hot-pass surface, but finish the Binaryen-matching preset slot, feature gate, and parity proof in a follow-up slice.
     - Goal: prove the pass in the intended early Binaryen slot without perturbing the preserved preset order until the exact slot is available.
     - Why: the explicit pass surface is now landed, but the implementation is still incomplete until the optimizer presets can schedule the pass behind the correct multivalue gate between the documented neighboring phases.
     - Deliverables: place the pass after `code-pushing` and before `simplify-locals-nostructure` once that slot exists in-tree; add feature-off preset coverage; prove the landed HOT-native rewrite against Binaryen with pass-fuzz compare and debug-artifact compare.
    - Current blocker: the explicit pass surface is ready, but the surrounding Binaryen neighbors are still not representable in the preserved public preset order, so the next keepable work is proof and exact-slot preparation rather than approximate scheduling. The tuple pass itself now recognizes one-hop scalar-forward copy bridges from direct non-`Block` multivalue spill producers, reduced chained mixed scalar-forward bridges from synthetic groups that still retain a source lane, the compare-shaped host-`local.tee` seed bridge, the raw decoded one-hop carrier shape, the narrowed no-host root-carrier family, the overlap-aware exact-copy family where a copy group writes back into one of its source lane locals, the newer non-canonical synthetic root-carrier copy groups whose destination lane locals are not strictly increasing, the reduced nested branch-exit source-root family that now stages through dedicated split locals plus a typed multivalue carrier instead of the older direct root block shortcut, the reduced root-local.set exact-copy family where canonical destination lanes now still route through a typed carrier when the payload source lanes are scrambled, the reduced source-host-copy passthrough family where staged init roots now rematerialize the old non-host lanes and host-only tail-live0 exact-copy groups no longer add a redundant second carrier, the newer terminal host-lane exact-copy family where drop-only tail lanes no longer keep the copy group rewrite alive once only one forwarded non-drop lane survives, and the newer upstream no-host exact-copy family where a copy group now stays scalarized when its only downstream consumer is a terminal drop-only child copy. A new anchor-host exact-copy rewrite slice now also stages chained tail-live0 host-copy lanes through explicit intermediate host carriers instead of the older direct scalar rematerialization path, and a new scalar-result exact-copy collector now recognizes nested copy groups whose HOT carrier body is expressed as prefix `local.set`s plus a final scalar value root instead of the older trailing-payload layout. Focused cmd/native regressions were rebaselined to that narrower scalarized contract instead of the earlier speculative full-Binaryen equality probes. New focused regressions in `src/ir/hot_lower_test.mbt`, `src/ir/hot_lift_test.mbt`, `src/passes/tuple_optimization_wbtest.mbt`, `src/passes/optimize_test.mbt`, `src/cmd/cmd_test.mbt`, and `src/cmd/cmd_native_wbtest.mbt` now prove that explicit branch-exit temp copy chains already roundtrip through `hot_lower` unchanged, that the reduced nested branch-exit tuple case is fixed at the tuple pipeline boundary, that the root-local.set exact-copy repro now lowers through a typed multivalue carrier instead of the older direct scalar block, that the reduced compare-shape, tail-live0, drop-only host-lane, chained no-host dead-tail, and nested scalar-result exact-copy lowered cmd outputs keep the old source lanes or direct scalar tail shape instead of rebuilding redundant copy carriers, that a reduced nested outer-block spill bridge still lifts with all scalar lane writes intact, and that tuple-optimization now suppresses all rewrites in functions that contain a nested rootslot host-copy wrapper group so the checked-in debug artifact no longer loses the old `local.set 68` / `local.set 67` lane materialization in the native replay. The latest kept-tree debug-artifact compare is `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-364403`, and it is still red: canonical wasm and normalized WAT differ, Starshine is still over budget (`5429.361 ms` wall, `934.878 ms` pass) versus Binaryen (`353.061 ms` wall, `3.456 ms` pass). The native debug-artifact regression retires the old missing-lane `func $1930` bug and the new scalar-result carrier collector fixes the reduced nested exact-copy carrier family in-source, but full Binaryen parity is still not proven; the current head hunk is now still later in `func $3598`, where Binaryen keeps a second staged copy group after the tuple call and Starshine still scalarizes that family differently.
     - Current proof status: `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-10000` is `10000/10000` normalized matches with `0` mismatches, `0` validation failures, `0` generator failures, and `0` command failures. The earlier clean runs `.tmp/pass-fuzz-tuple-optimization-genvalid-2000` and `.tmp/pass-fuzz-tuple-optimization-genvalid-500` were also `2000/2000` and `500/500`. The smith-only run `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --generator wasm-smith --count 200 --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-optimization-smith-200` reached `165/165` normalized matches with `0` mismatches before stopping on `20` Binaryen-side parser failures: `17` `invalid type index`, `1` `Recursion groups of size zero not supported`, and `2` `invalid wasm type: -64`. The saved failure cases are `000009`, `000021`, `000024`, `000029`, `000031`, `000047`, `000050`, `000052`, `000054`, `000056`, `000079`, `000081`, `000083`, `000095`, `000124`, `000141`, `000143`, `000162`, `000167`, and `000185` under `.tmp/pass-fuzz-tuple-optimization-smith-200/failures/`. Focused reduced pipeline regressions are now also in-tree for direct scalar-forward seed bridges, nested scalar-result carriers, the imported-call host-`local.tee` bridge, the reduced no-host direct-spill / exact-copy root-carrier repros, and the new overlap-aware exact-copy copyback repro. The remaining proof gap is still the red debug-artifact compare above, not missing tuple-pass coverage on the earlier reduced families.
     - Current feature-off coverage: the explicit pass surface now has a focused scalar-only no-op regression in `src/passes/optimize_test.mbt`; preset-level multivalue gate coverage is still pending the exact slot.
     - Required APIs: `src/passes/optimize.mbt` preset surface; `bun scripts/pass-fuzz-compare.ts`; `bun scripts/self-optimize-compare.ts`.
     - Invariants: preserve Binaryen's multivalue-only gate; preserve the exact early slot ordering; do not bundle explicit HOT tuple pseudo-op roundtrip support into this slice unless the HOT-native port proves insufficient first.
     - Dependencies: the landed explicit pass surface plus the candidate-analysis and good-component rewrite helpers in `src/passes/tuple_optimization.mbt`; [0076#L36](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md#L36), [0076#L212](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md#L212), [0076#L255](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md#L255)
     - Exit criteria: the pass reaches the real preset slot with feature-off tests green, `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 ...` is acceptable, and artifact compare evidence exists for `--tuple-optimization`.
     - Suggested tests: `moon test src/passes`, `moon test src/cmd`, `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-tuple-optimization`, and `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --tuple-optimization`.
     - Doc: [0076#L255](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md#L255)
3. Do work.
   - Continue in dependency order from the landed local-growth helper, candidate analysis, good-component rewrite, and explicit pass activation: exact-slot scheduling and parity proof are next.
   - Keep the first keepable implementation HOT-native; do not widen the scope to explicit HOT tuple pseudo-op lift/lower support unless the HOT-native rewrite proves insufficient on real parity cases.
   - Do not perturb the preserved preset ordering until the exact Binaryen slot can be represented directly in-tree.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/pass-fuzz-compare.ts --pass tuple-optimization --count 10000 ...` and `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --tuple-optimization`.
   - If a parity gap only appears in explicit HOT tuple pseudo-op unit coverage, slice that follow-up separately instead of bundling it into the first HOT-native port.

#### SLNS - Simplify Locals No-Structure
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L223](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L223)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [SLNS]001 - Early Local Simplification Core - Port the local-traffic reductions Binaryen runs before it is willing to reshape structure.
     - Deliverables: simplify sets, gets, and dead locals without creating new structured returns; preserve later coalescing opportunities; integrate with current local analyses.
     - Doc: [0066#L223](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L223)
   - [SLNS]002 - Early-Slot Regression and Artifact Proof - Lock the no-structure contract into tests and compare the early local-cleanup prefix against Binaryen.
     - Deliverables: add regressions for tee-like traffic and tuple scratch locals; confirm structure is intentionally preserved; replay parity for the pass on the debug artifact.
     - Doc: [0066#L223](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L223)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### VQ - Vacuum
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L228](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L228)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [VQ]001 - Cleanup Semantics Audit - Audit the existing vacuum pass against Binaryen's repeated garbage-collection role after earlier rewrites.
     - Deliverables: confirm which empty blocks, nops, and detached residue Binaryen drops; preserve typed block correctness; tighten any mismatches in the current pass.
     - Doc: [0066#L228](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L228)
   - [VQ]002 - Repeated-Slot Regression Matrix - Add pipeline coverage that proves all four vacuum slots remain valid as surrounding passes land.
     - Deliverables: write regressions around empty structures and detached nodes; verify slot ordering in the public preset; replay pass parity against Binaryen on the artifact.
     - Doc: [0066#L228](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L228)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### RL - Reorder Locals
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0073](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [RL]001 - Exact Access Counter and Remap Core - Port Binaryen's frequency-based local reindexer as a module pass over defined functions.
     - Deliverables: count `local.get`, `local.set`, and `local.tee` exactly like Binaryen; keep parameters fixed; sort body locals by descending access count with first-access tie-breaks; drop only zero-access body locals; prepare reusable old-to-new and new-to-old remap helpers.
     - Doc: [0073](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md)
   - [RL]002 - Boundary Metadata Rewrite and Validation - Apply the remap to Starshine's boundary function form and keep encoded metadata correct.
     - Deliverables: rewrite nested `Expr` local indices; rebuild grouped body-local runs; rewrite `NameSec.local_names` for changed defined functions only; preserve imported-function local-name entries; clear stale `raw_name_sec_payload`; add focused regressions for no-op preservation, name rewriting, and dead-write-only locals staying live for this pass.
     - Doc: [0073](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md)
   - [RL]003 - Registry Wiring, Honest Slot Placement, and Artifact Compare - Expose the pass publicly and only add Binaryen-aligned scheduler slots when surrounding pass availability makes that truthful.
     - Deliverables: move `reorder-locals` from boundary-only to module-pass status; add CLI and pipeline coverage for the explicit pass flag; decide which current preset slot wiring is honest before `simplify-locals-nostructure`, `local-subtyping`, and `coalesce-locals` land; compare `--reorder-locals` output and any later ordered replay against Binaryen on the debug artifact.
     - Doc: [0073](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md)
    - Status: RL001 and RL002 are now landed in-tree, and the explicit-pass portion of RL003 is landed too: `src/passes/reorder_locals.mbt` exists, the registry classifies `reorder-locals` as an active module pass, focused pipeline/CLI coverage is in place, `scripts/lib/pass-fuzz-compare-task.ts` now accepts `--reorder-locals`, preset exclusion is now locked by regression coverage so the current partial `optimize` / `shrink` pipelines do not claim Binaryen-adjacent `reorder-locals` slots before `simplify-locals-nostructure`, `local-subtyping`, and `coalesce-locals` land, and `scripts/lib/self-optimize-compare-task.ts` now supports explicit Binaryen no-pass preprocessing via `--binaryen-nop-roundtrips <n>`, `--binaryen-nop-until-stable <max>`, and the new `--require-binaryen-nop-converged` signoff guard. Fresh parity evidence is green on the full `gen-valid` lane at `.tmp/pass-fuzz-reorder-locals-genvalid-10000` (`10000/10000` compared, `10000/10000` normalized matches, `0` mismatches, `0` validation failures, `0` command failures). The mixed-generator lane at `.tmp/pass-fuzz-reorder-locals-10000` currently stops at the `20`-failure cap after `289` successful matches, but all `20` failures are Binaryen-side command failures (`17` `invalid type index`, `1` `Recursion groups of size zero not supported`, `2` `invalid wasm type: -64`), not Starshine mismatches. The current blocker is no longer the raw sorter: Binaryen `version_129/src/passes/ReorderLocals.cpp` matches the Starshine access-count/first-use algorithm, and in-tree regression coverage now includes a Binaryen-materialized carrier fixture plus the trailing-dead-local no-rewrite regression to lock that raw behavior. The sorter itself also picked up a larger hot-path win before any deeper boundary work: defined-function params are cached from raw module metadata, only accessed body locals are sorted, the scan records touched body locals directly, stable accessed-index bodies skip recursive rewrite, name-map rewrites skip their resort when the remap stays monotonic, nested `Expr` rewrites now mutate instruction arrays in place instead of allocating replacement arrays, rebuilt locals now emit `LocalRun`s directly instead of bouncing through a transient reordered type array, the remaining array-build helpers are preallocated where the capacity is known, and local flattening now expands runs directly instead of going through the iterator adapter. On repeated full-artifact replays with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --binaryen-nop-until-stable 5 --reorder-locals`, Starshine's pass-time moved from the earlier `176.364 ms` sample down first into a `166.266-173.189 ms` range, then into a roughly `151.211-155.709 ms` range, then into a `140.078-150.027 ms` range, then into a roughly `131.081-139.564 ms` range, and now into a roughly `121.286-133.330 ms` range. The remaining red artifact compare is a representation boundary problem, and [0074](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0074-2026-04-02-binaryen-multivalue-call-local-disparity.md) now pins the exact cause in Binaryen source: the extra locals come from multivalue call packaging in `wasm-ir-builder.cpp` plus tuple/scratch-local expansion in `wasm-stack.cpp`, not from `ReorderLocals.cpp`. Even the tiny multivalue repro is rewritten by `wasm-opt` with no passes from `14` to `19` body locals before `reorder-locals` runs, Binaryen emits `24` locals when `--reorder-locals` writes that `19`-local fixture back out, and rerunning Binaryen on its own output grows the same repro again to `29` locals. The blocker is now narrower than "multivalue generally": the triple-result block-only fixture now has an explicit measured stable boundary through the compare tool itself (`bun scripts/self-optimize-compare.ts /tmp/rl-grow-block3.wasm --binaryen-nop-until-stable 5 --require-binaryen-nop-converged --reorder-locals` => `Binaryen no-pass roundtrips: 3`, `converged: yes`, canonical and normalized parity both green), but triple-result calls still do not converge. Both `bun scripts/self-optimize-compare.ts /tmp/rl-grow-call3.wasm --binaryen-nop-until-stable 5 --reorder-locals` and `bun scripts/self-optimize-compare.ts /tmp/rl-grow-internal-call3.wasm --binaryen-nop-until-stable 5 --reorder-locals` stop at the max with `Binaryen no-pass converged: no`, and both remain canonically and normalized red even after starting from the fifth Binaryen no-pass writeback. The full debug artifact now shows the same thing with the real pipeline: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --binaryen-nop-until-stable 5 --reorder-locals` reports `Binaryen no-pass roundtrips: 5`, `converged: no`, and both canonical and normalized parity still red, while the guarded signoff form with `--require-binaryen-nop-converged` fails immediately before compare. That makes the remaining question mostly a policy one: port Binaryen's multivalue call writeback/materialization layer as a broader compatibility goal, or stop treating that boundary layer as required `reorder-locals` work.
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### H2L - Heap2Local
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0075](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [H2L]001 - Escape and Alias Eligibility - Build the GC-localization analysis that proves heap traffic can be rewritten into locals without alias leaks.
     - Deliverables: track allocation lifetimes, reads, writes, and escaping refs; preserve aliasing correctness; document unsupported object shapes explicitly.
    - Status: the active slice now covers exclusive struct-localization through direct owners, local-copy chains, direct `local.tee` owners, simple block-result flow, `ref.as_non_null`, successful `ref.cast` through widened tee-backed locals, direct `ref.eq` folds against fresh struct allocations, descriptor-bearing `ref.get_desc` consumes on fresh `struct.new_desc` / `struct.new_default_desc`, constant-size array lowering for `array.new_default`, `array.new`, and `array.new_fixed`, direct array `ref.test`, and the parameter-backed mixed-provenance bailout. The primary parity suite in `src/passes/heap2local_primary_test.mbt` from [0075](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md) is now fully green in-tree.
     - Doc: [0075](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md)
    - [H2L]002 - Localization Rewrite and Artifact Validation - Rewrite eligible heap accesses to locals and validate the result on focused GC fixtures and the debug artifact.
      - Deliverables: add regressions for escaping objects and partial field coverage; prove the pass only runs in the GC mid-function slot; compare against Binaryen output.
    - Current blocker: the in-tree parity suite is green, `heap2local` now matches Binaryen on a `10000`-case `gen-valid` compare run, and a `1000`-case mixed-generator sample found no mismatches or Starshine validation failures but did hit Binaryen wasm-smith parser rejects. Remaining follow-up is Binaryen's non-nullable-local / refinalization fixups plus the wider missing-pass neighborhood (`optimize-casts`, `local-subtyping`, `coalesce-locals`, `local-cse`) needed for full no-DWARF parity.
      - Doc: [0075](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### OC - Optimize Casts
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L243](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L243)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [OC]001 - Cast Tightening Rules - Port the GC cast simplifications Binaryen runs after `heap2local` when subtype facts are strongest.
     - Deliverables: encode ref.cast, ref.test, nullability, and subtype simplifications; preserve trap and exact-type semantics; integrate with current type helpers.
     - Doc: [0066#L243](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L243)
   - [OC]002 - GC Regression Matrix and Artifact Compare - Add focused GC cast regressions and verify the pass output matches Binaryen on the MoonBit artifact.
     - Deliverables: cover exact refs, nullability, and escaping values; confirm the pass stays after `heap2local`; run `--optimize-casts` parity against Binaryen.
     - Doc: [0066#L243](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L243)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### LS - Local Subtyping
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L248](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L248)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [LS]001 - Local Type Narrowing Core - Port the local-subtyping rewrite that narrows GC local types before coalescing widens them again.
     - Deliverables: compute safe narrower local types from uses and defs; preserve multivalue and tuple-local behavior; keep later coalescing constraints explicit.
     - Doc: [0066#L248](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L248)
   - [LS]002 - Ordering Tests and Artifact Proof - Lock the required `optimize-casts -> local-subtyping -> coalesce-locals` order into tests and compare the pass against Binaryen.
     - Deliverables: add regressions for local narrowing before coalescing; verify scheduler order; replay `--local-subtyping` parity on the MoonBit artifact.
     - Doc: [0066#L248](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L248)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### CL - Coalesce Locals
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L253](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L253)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [CL]001 - Compatibility and Lifetime Analysis - Port Binaryen's local-coalescing compatibility test so only safe local lifetimes are merged.
     - Deliverables: compute live-range overlap and type compatibility; preserve tuple scratch and GC subtype constraints; define which locals are never coalesced.
     - Doc: [0066#L253](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L253)
   - [CL]002 - Dual-Slot Rewrite, Reorder Interaction, and Artifact Parity - Implement the merge, keep `reorder-locals` interactions stable, and compare the pass output against Binaryen.
     - Deliverables: add regressions for double-slot coalescing and reordered indices; validate with surrounding `simplify-locals` and `reorder-locals`; replay parity on the debug artifact.
     - Doc: [0066#L253](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L253)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### LCSE - Local CSE
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L258](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L258)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [LCSE]001 - Local Expression Equivalence - Port the expression-equivalence rules Binaryen uses to reuse local computations after coalescing has simplified traffic.
     - Deliverables: define effect-safe equivalence classes for local computations; preserve trap ordering and GC side effects; integrate with current effects analysis.
     - Doc: [0066#L258](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L258)
   - [LCSE]002 - Mid-Pipeline Regression and Artifact Compare - Add focused CSE regressions and confirm the pass output matches Binaryen on the MoonBit artifact.
     - Deliverables: cover repeated loads, locals, and effect barriers; verify the pass stays in the mid-function slot; replay `--local-cse` parity against Binaryen.
     - Doc: [0066#L258](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L258)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### SL - Simplify Locals
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L263](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L263)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [SL]001 - Full Local Simplification Audit - Harden the existing simplify-locals pass so the late local cleanup exactly matches Binaryen's post-coalescing behavior.
     - Deliverables: diff the current Starshine pass against Binaryen's late slot semantics; close any remaining copy, tee, or dead-local gaps; preserve typed structure and tuple locals.
     - Doc: [0066#L263](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L263)
   - [SL]002 - Slot Validation and Artifact Replay - Lock the corrected pass into scheduler tests and replay the MoonBit debug-artifact compare harness.
     - Deliverables: add focused regressions for late-slot local cleanup; verify surrounding `vacuum` and `reorder-locals` behavior; run `--simplify-locals` parity against Binaryen.
     - Doc: [0066#L263](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L263)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### CF - Code Folding
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L268](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L268)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [CF]001 - Region Equivalence and Fold Safety - Port the region-merging rules Binaryen uses to fold duplicate code late in the function pipeline.
     - Deliverables: define structural equality for candidate code regions; preserve labels, branch targets, and tuple typing; reject folds that would disturb later cleanup.
     - Doc: [0066#L268](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L268)
   - [CF]002 - Late-Slot Regression and Artifact Compare - Add duplicate-region regressions and confirm the folded output matches Binaryen on the MoonBit artifact.
     - Deliverables: cover repeated blocks, typed values, and branchy regions; verify the pass remains late in the pipeline; replay `--code-folding` parity against Binaryen.
     - Doc: [0066#L268](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L268)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### MB - Merge Blocks
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L273](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L273)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [MB]001 - Typed Block Merge Rules - Port Binaryen's block-flattening rules that merge nested blocks without breaking branch or result typing.
     - Deliverables: encode which block nesting patterns can collapse; preserve branch values and typed block signatures; keep the pass compatible with repeated late cleanup.
     - Doc: [0066#L273](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L273)
   - [MB]002 - Dual-Slot Replay and Artifact Validation - Run the pass in both Binaryen slots and validate the resulting branch-cleanup opportunities against the reference output.
     - Deliverables: add regressions for typed block merging and repeated-slot cleanup; verify order with `remove-unused-brs`; replay `--merge-blocks` parity on the debug artifact.
     - Doc: [0066#L273](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L273)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### RSE - Redundant Set Elimination
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L278](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L278)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [RSE]001 - Redundant Write Detection - Port the late-pipeline write-elimination logic that removes provably redundant sets after coalescing and peephole cleanup.
     - Deliverables: identify overwritten sets with no intervening observable read; preserve traps and side effects; integrate with current liveness and effects helpers.
     - Doc: [0066#L278](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L278)
   - [RSE]002 - Final-Cleanup Regression and Artifact Proof - Add focused set-elimination regressions and confirm the pass output matches Binaryen before the final `vacuum`.
     - Deliverables: cover locals, globals, and GC field writes where applicable; verify scheduler order with the final cleanup slot; compare `--rse` output against Binaryen on the artifact.
     - Doc: [0066#L278](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L278)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### DAE - Dead Argument Elimination Optimizing
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L283](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L283)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [DAE]001 - Call-Graph Pruning and Touched-Function Tracking - Port Binaryen's optimizing dead-argument elimination and record exactly which functions need nested cleanup reruns.
     - Deliverables: remove dead call parameters safely across direct users; localize call targets where Binaryen does; track the touched-function set for the nested rerun helper.
     - Doc: [0066#L283](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L283)
   - [DAE]002 - Nested Post-Inlining Cleanup and Artifact Compare - Recreate the `optimizeAfterInlining` subpipeline and validate both the top-level and nested output against Binaryen.
     - Deliverables: prepend `precompute-propagate` before rerunning the default function pipeline on touched functions; add nested-run scheduler tests; compare `--dae-optimizing` output on the debug artifact.
     - Doc: [0066#L283](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L283)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### INL - Inlining Optimizing
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L288](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L288)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [INL]001 - Heuristics, Rewrite, and Touched-Function Set - Port Binaryen's optimizing inliner and keep the touched-function filter that drives nested cleanup reruns.
     - Deliverables: implement Binaryen-like inlining heuristics for `-O` / `-Os`; rewrite callsites and remove now-dead functions; capture the exact set of mutated functions for the nested runner.
     - Doc: [0066#L288](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L288)
   - [INL]002 - Nested Useful-Passes Replay and Artifact Parity - Recreate `addUsefulPassesAfterInlining` and prove both the inline rewrite and nested cleanup match Binaryen on the debug artifact.
     - Deliverables: prepend `precompute-propagate`, rerun the default function pipeline on touched functions, and add nested-run tests; compare `--inlining-optimizing` output against Binaryen.
     - Doc: [0066#L288](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L288)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### DIE - Duplicate Import Elimination
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L293](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L293)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [DIE]001 - Import Identity and Merge Safety - Define the exact module/name/type identity checks required before duplicate imports can be merged.
     - Deliverables: compare import module, field, and external type exactly; preserve externally observable ordering where required; build a replacement map for merged import indices.
     - Doc: [0066#L293](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L293)
   - [DIE]002 - Index Rewrite and Artifact Validation - Rewrite all users of merged imports and validate the late post-pass cleanup result against Binaryen.
     - Deliverables: patch function/table/global/memory import users consistently; add regressions for import-boundary corner cases; compare `--duplicate-import-elimination` output on the artifact.
     - Doc: [0066#L293](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L293)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### SGO - Simplify Globals Optimizing
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L298](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L298)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [SGO]001 - Constant-Global Rewrite and Mutation Tracking - Port the constant-global replacement and dead `global.set` removal flow while tracking every mutated function.
     - Deliverables: replace constant global reads safely; remove dead writes without violating ordering; maintain the exact touched-function set for nested reruns.
     - Doc: [0066#L298](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L298)
   - [SGO]002 - Nested Default-Function Rerun and Artifact Compare - Recreate the per-function rerun of `addDefaultFunctionOptimizationPasses()` and validate the result against Binaryen.
     - Deliverables: rerun the default function pipeline without the `precompute-propagate` prefix; add nested-run scheduler tests; compare `--simplify-globals-optimizing` output on the debug artifact.
     - Doc: [0066#L298](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L298)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### SG - String Gathering
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L303](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L303)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [SG]001 - String Collection and Canonicalization Rules - Port the string-gathering transformation that runs immediately before `reorder-globals` on string-enabled modules.
     - Deliverables: collect the string data Binaryen hoists or canonicalizes; preserve string feature semantics and global users; define unsupported string layouts explicitly.
     - Doc: [0066#L303](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L303)
   - [SG]002 - Feature Gate, Global Order, and Artifact Parity - Validate the pass only runs when strings are enabled and confirm the resulting global layout matches Binaryen.
     - Deliverables: add feature-gated scheduler tests and focused string regressions; verify interaction with `reorder-globals`; compare `--string-gathering` output on the debug artifact.
     - Doc: [0066#L303](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L303)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### RG - Reorder Globals
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L308](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L308)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [RG]001 - Global Cost Model and Reindexing - Port Binaryen's global reordering criteria and compute a safe remap after late global cleanup and string gathering.
     - Deliverables: define the reordering cost model; preserve externally visible boundaries and section invariants; prepare a reusable global-index remapper.
     - Doc: [0066#L308](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L308)
   - [RG]002 - Late-Postpass Validation and Artifact Compare - Apply the global reorder, lock the resulting section rewrites into tests, and compare the output against Binaryen.
     - Deliverables: add regressions for reordered globals with string users and exports; verify the pass stays after `string-gathering`; replay `--reorder-globals` parity on the artifact.
     - Doc: [0066#L308](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L308)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.

#### DIR - Directize
1. Research exact functionality in document.
   - Research exactly how it works with a document: [0066#L313](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L313)
2. Slice gameplan in `agent-todo.md` and determine deliverables.
   - [DIR]001 - Indirect-to-Direct Eligibility - Port Binaryen's final-pass logic for converting eligible indirect calls into direct calls without violating table behavior.
     - Deliverables: identify call targets that are uniquely resolvable; preserve table semantics, imports, and dynamic behavior; document the bailout cases that remain indirect.
     - Doc: [0066#L313](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L313)
   - [DIR]002 - Call Rewrite, Boundary Regressions, and Artifact Proof - Rewrite eligible callsites, test boundary cases, and confirm the final pass output matches Binaryen on the debug artifact.
     - Deliverables: patch call instructions and dependent signatures safely; add regressions for mixed direct/indirect call tables; compare `--directize` output on the artifact.
     - Doc: [0066#L313](/home/jtenner/Projects/starshine-mb/docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md#L313)
3. Do work.
   - Land the slices above in dependency order in the implementing file(s) and any required scheduler, preset, or dispatcher surfaces.
   - Wire the pass into the exact top-level slot(s) and nested rerun sites documented in the research doc before calling the work done.
4. Test against binaryen.
   - Add edge-case and regression tests beside the implementing file and any scheduler or dispatcher coverage needed for the pass.
   - Compare Starshine vs Binaryen with `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --<pass>` and any required ordered-prefix replay.
## v0.2.0 Backlog

- [HOT]003 - Node-Package Worker Queue Port - Reuse the native hot-batch queue contract in the shipped Node package with `worker_threads` rather than WASI threads.
  - Deliverables: port the native scheduler contract to a Node host queue backed by `SharedArrayBuffer` and `Atomics`; instantiate one WasmGC module per worker; keep WasmGC refs and MoonBit heap objects worker-local; merge serialized per-function results back on the parent thread in stable function order.
  - Dependencies: [HOT]002 native queue contract, worker-local function serialization hooks, and package-host integration work under the future Node package rebuild.
  - Exit Criteria: the Node package can opt into the same per-function hot batch worker queue without changing optimizer semantics, and the host/runtime contract is documented clearly enough to preserve native and Node behavior parity.
