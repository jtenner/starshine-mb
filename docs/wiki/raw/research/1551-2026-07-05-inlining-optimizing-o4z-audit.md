---
kind: research
status: active
last_reviewed: 2026-07-05
sources:
  - ../../binaryen/passes/inlining-optimizing/index.md
  - ../../binaryen/passes/inlining-optimizing/binaryen-strategy.md
  - ../../binaryen/passes/inlining-optimizing/starshine-strategy.md
  - ../../binaryen/passes/inlining-optimizing/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/inlining-optimizing/fuzzing.md
  - ../../binaryen/passes/inlining-optimizing/deferred-inl005-inl006-work.md
  - ../../binaryen/passes/inlining/index.md
  - ../../binaryen/passes/inlining/implementation-structure-and-tests.md
  - ../../tooling/pass-fuzz-compare.md
  - ../../../../src/passes/inlining.mbt
  - ../../../../src/passes/inlining_test.mbt
  - ../../../../src/passes/inlining_wbtest.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
---

# `inlining-optimizing` O4z Audit Slice

## Executive finding

`inlining-optimizing` remains an active partial Starshine module pass with meaningful coverage for the v0.1.0-supported direct-call surface. This audit did not find evidence that deferred `[INL]005` partial splitting or residual `[INL]006` name/annotation repair should be reopened for v0.1.0. The original evidence-hygiene gap around a dedicated GenValid aggregate and stale native binary path is now addressed. The current regular GenValid 100000 lane is complete with cleanup-normalized no-call evidence; the random-all raw local-allocation/renumbering families are now exhaustively downstream-classified as accepted cleanup/representation drift, with reopening criteria below rather than treated as unknown mismatches.

One small profile-tooling fix landed after the initial audit: `PassInliningProfile` is now a scalar direct-call smoke profile that disables stringref/GC-ref surfaces which the compare harness validates poorly through `wasm-tools --features all`. A naive structural `inlining-optimizing-all` aggregate was tested locally and deliberately not kept: mixing existing `pass-inlining`, `precompute-*`, `pass-cleanup`, and `simplify-locals-nostructure-*` leaves produced generator failures and direct-pass mismatches that do not form a trustworthy closeout lane for `inlining-optimizing`.

The immediate seed-`0x1e11e` direct mismatch from `.tmp/pass-fuzz-inlining-optimizing-pass-inlining-1-refsafe` is now classified, not fixed as a parity bug: Starshine performs a stronger cleanup of pure dropped expression trees and unreachable tail debris after all direct calls disappear, while Binaryen leaves the same no-effect prelude in `--inlining-optimizing` output. Evidence: both raw/normalized outputs validate; a `--runtime-execution node` replay reports one checked export with equal traps and zero semantic mismatches; Binaryen's output reduced with additional cleanup converges to function bodies that are just `unreachable` plus local-declaration drift; and a shared Binaryen `-Oz --strip-debug` pass over both outputs produces identical 59-byte wasm with an empty WAT diff. Classification: Starshine-win / accepted cleanup drift for this single case, not a true semantic mismatch and not `[INL]005`/`[INL]006` reopening evidence.

A first real `inlining-optimizing-all` GenValid aggregate now exists. It has four focused leaves (`direct-wrapper`, `param-spill`, `return-call`, and `cleanup-payoff`) that generate small private-helper modules where `inlining-optimizing` can inline first and then expose touched-function cleanup. Emit-batch smoke generated eight validating inputs with aggregate `config_label`, selected-profile leaves, and non-null profile-case labels; compare-pass reached `20/20`, `1000/1000`, and then the required pass-specific `10000/10000` lane with zero generator/validation/property/command failures and zero mismatches. This satisfies the dedicated-profile portion of the signoff ladder, but it is not final closeout: broader regular direct compare, random-all, and final closeout validation remain open.

A smaller ordinary default GenValid triage lane is now available after the non-evidence 1000-case timeout. `.tmp/pass-fuzz-inlining-optimizing-ordinary-20-20260705-triage` completed `20/20` and all `20` mismatches came from `binaryen-oracle-portable` no-call/unreachable inputs. Agent classification for the sampled family: Starshine-win / accepted cleanup drift, not an inlining semantic or parity bug. Binaryen's `--inlining-optimizing` leaves large no-effect dropped-expression debris when no callsites are present; Starshine's no-change path prunes that debris while preserving the reachable trapping/control tail. Evidence: manifest facts have no calls and no memory/table/global/exception/atomic effects, all sampled artifacts validate, case 1 runtime replay under Node is equal-trap with zero semantic mismatches, sampled Starshine outputs are much smaller, and shared downstream Binaryen `-Oz --strip-debug` converges sampled cases 1-5 to identical WAT. This small sampled classification does not replace the ordinary `100000` final signoff lane, but it explains why the current broad default profile is a poor closeout profile for inline-then-cleanup behavior. After `--no-reduce-mismatches` landed, `.tmp/pass-fuzz-inlining-optimizing-ordinary-1000-noreduce-allnorm-20260705` completed `1000/1000` with `1000` raw mismatches, zero cleanup-normalized matches even with all then-current cleanup normalizers, and zero generator/validation/property/command failures; its feature facts were still no-call/no-side-effect plus `hasUnreachable=1000` and `mayTrap=1000`. A targeted normalizer slice then added narrow tests and support for pure dropped float/signed-conversion numeric debris and standalone empty `if (i32.const 0|1) (then) (else)` debris, while preserving potentially trapping `trunc_*_s` drops. With that normalizer set, `.tmp/pass-fuzz-inlining-optimizing-ordinary-1000-allnorm-purefloat-20260705` reached `1000/1000` cleanup-normalized, and `.tmp/pass-fuzz-inlining-optimizing-ordinary-10000-allnorm-purefloat-20260705` reached `10000/10000` cleanup-normalized with `0` mismatches and zero generator/validation/property/command failures. The current regular GenValid 100000 lane `.tmp/pass-fuzz-inlining-optimizing-ordinary-100000-allnorm-tailguard-20260705` is now complete for the refreshed native binary: `100000/100000` compared, `0` normalized matches, `100000` cleanup-normalized matches, `0` mismatches, zero generator/validation/property/command failures, selected profile `binaryen-oracle-portable=100000`, and Binaryen cache `100000` hits / `0` misses. This satisfies the regular GenValid count, while still primarily proving no-call cleanup-drift classification rather than inline-then-cleanup behavior.

The explicit wasm-smith `10000` signoff lane is now current after the tail-call cleanup guard. `.tmp/pass-fuzz-inlining-optimizing-wasm-smith-10000-tailguard-20260705` requested `10000` cases and compared `9956`: `9953` normalized matches, `3` raw mismatches, no generator/validation/property failures, and `44` Binaryen/oracle command failures (`39` rec-group-zero, `3` bad-section-size, `1` table-index-out-of-range, `1` invalid-tag-index). Cache was fully warm: wasm-smith `10000/0`, Binaryen `9956/0`, and Binaryen-failure `44/0` hits/misses. The three raw mismatches are the same cases as before (`003694`, `009332`, `009726`) and remain classified as Starshine-win / accepted cleanup drift: their inputs have no calls or side effects, all sampled Binaryen/Starshine raw/canonical artifacts validate, the visible diffs are no-effect local-set/get, pure const-drop, `nop`, or dead local-declaration cleanup, and shared downstream `wasm-opt --all-features -Oz --strip-debug` converges each pair to identical 8-byte wasm in `.tmp/io-wasm-smith-tailguard-downstream-oz-20260705`. Two of the three are raw-smaller for Starshine and one is raw-size equal, so this classification is based on no-effect cleanup plus downstream convergence, not on size alone. A supplemental normalized replay with `drop-consts` and `local-cleanup-debris` classified two of the three as cleanup-normalized and left only the local-set/get const-return form raw.

The broad random-all lane is now classified rather than unknown. The full `--gen-valid-profile random-all-profiles --count 10000 --seed 0x5555` attempt initially timed out after `2400s` with only `101` case records and no summary/result, and smaller normalized/capped triage attempts also timed out because every GenValid mismatch spent time in the byte-slice reducer. A tooling slice added compare-pass `--no-reduce-mismatches` for broad triage, and the first completed 1000-case random-all triage found a true Starshine command-failure bug: four `coverage-forced-portable` cases aborted in final `reorder-locals` cleanup after an earlier cleanup candidate left stale local declarations. `reorder-locals` now fails closed on out-of-range local accesses instead of aborting, allowing inlining's validate-or-fallback path to discard the invalid cleanup candidate; the four saved cases replay with exit `0` and validating output. The refreshed triage lane `.tmp/pass-fuzz-inlining-optimizing-random-all-profiles-1000-noreduce-allnorm-fixed1-20260705` completed `1000/1000`: `7` normalized matches, `105` cleanup-normalized matches, `888` raw mismatches, and zero generator/validation/property/command failures. Follow-up representative sampling found only no-effect cleanup/representation debris across the then-raw profile families. The pure-float/conversion and empty-const-if normalizer tightening improved the 1000-case random-all lane to `.tmp/pass-fuzz-inlining-optimizing-random-all-profiles-1000-allnorm-purefloat-20260705`: `7` normalized matches, `473` cleanup-normalized matches, `520` raw mismatches, and zero failures. The first full-count all-normalizer random-all attempt before the tail guard, `.tmp/pass-fuzz-inlining-optimizing-random-all-profiles-10000-allnorm-purefloat-fullmax-20260705`, completed `9999/10000` but found one true validation failure: `coverage-forced-portable case-004369` produced an invalid `return_call` operand stack (`expected f32, found i64`) after nested/local cleanup. The red replay `.tmp/pass-fuzz-inlining-optimizing-random-all-case-004369-validation-replay-fixed-20260705` preserved that failure. Starshine now skips nested/final local cleanup for modules containing tail calls until that cleanup/remap interaction has a narrower type-aware repair; `.tmp/pass-fuzz-inlining-optimizing-random-all-case-004369-validation-replay-tailguard-20260705` replays the saved case as `1/1` normalized with zero failures.

The current random-all full-count lane `.tmp/pass-fuzz-inlining-optimizing-random-all-profiles-10000-allnorm-tailguard-20260705` completed `10000/10000` with `1250` normalized matches, `3490` cleanup-normalized matches, `5260` raw mismatches, zero generator/validation/property/command failures, and Binaryen cache `10000` hits / `0` misses. Remaining raw profiles were local-allocation/renumbering families: `ssa-nomerge-parity=1250`, `ssa-nomerge-smoke=1250`, `local-subtyping-straight-line=689`, `coalesce-locals-straight-line=545`, `heap2local-struct=455`, `local-subtyping-structured=366`, `coalesce-locals-structured=355`, and `coalesce-locals-loop-copy-through=350`. A first 400-case downstream sample was all convergent; then `.tmp/io-random-all-tailguard-downstream-oz-all-20260705` exhaustively checked all `5260` raw mismatches by running both Binaryen and Starshine raw outputs through shared `wasm-opt --all-features -Oz --strip-debug`. All `5260/5260` pairs converged to identical downstream wasm. Per-profile convergence was complete: `ssa-nomerge-parity 1250/1250`, `ssa-nomerge-smoke 1250/1250`, `local-subtyping-straight-line 689/689`, `coalesce-locals-straight-line 545/545`, `heap2local-struct 455/455`, `local-subtyping-structured 366/366`, `coalesce-locals-structured 355/355`, and `coalesce-locals-loop-copy-through 350/350`. Downstream wasm sizes were stable at `35` bytes for `ssa-nomerge-*` and `34` bytes for the other six profiles, with zero downstream byte deltas in every case. Most raw pairs are Starshine-smaller, but `207` local-subtyping cases (`129` straight-line, `78` structured) are raw-size-losing before downstream cleanup (`-20` bytes, all `hasException`/`mayTrap`); size is therefore not the acceptance rationale. Six size-losing local-subtyping replays (`case-000085`, `000101`, `000205`, `000229`, `000237`, and `000253`) all ran under Node with `outcome="all-equal"` and zero semantic mismatches. Agent classification for the random-all raw family is accepted cleanup/representation drift: the lane has no validation/generator/property/command failures, all raw pairs are downstream-convergent under the same optimizer, representative effectful/trapping size-losing cases replay equal, and the visible diff family is local-allocation/renumbering/dead-temp cleanup rather than a missed inlining behavior. Reopen if a raw random-all mismatch fails validation, fails downstream `-Oz --strip-debug` convergence, produces a runtime semantic mismatch, loses size without downstream convergence or another measured win, introduces calls/memory/table/global/atomic side effects into the residual family, or reduces to a concrete inlining/touched-cleanup transform gap.

## Performance addendum: direct-pass 1x requirement reopened and fixed for the synthetic IO timing fixture

A follow-up performance slice corrected this audit's closeout bar: user requirement is Starshine direct pass-local time **at least 1x Binaryen** (`Starshine pass:inlining-optimizing <= Binaryen BINARYEN_PASS_DEBUG pass-local time`), not merely the repo default `<=2x`. Behavior/fuzz signoff above remains strong/current, but performance closeout was reopened until the direct-pass timing fixture below was measured and repaired.

Durable local measurement method now lives in `.tmp/io-perf-20260705/measure_io_perf.py`. It generates inline-heavy WAT fixtures under `.tmp/io-perf-20260705/measurements/inline-heavy-{N}.wat`: `N` private one-argument helpers each compute `local.get 0; i32.const 1; i32.add`, and exported `main` chains the helpers through one accumulator local. Starshine is run as `_build/native/release/build/cmd/cmd.exe --tracing pass --inlining-optimizing <fixture.wasm> -o <out.wasm>` and parses `perf:timer name=pass:inlining-optimizing ... total_us=...`; Binaryen is run as `BINARYEN_PASS_DEBUG=1 wasm-opt --all-features --inlining-optimizing <fixture.wasm> -o <out.wasm>` and parses `[PassRunner] running pass: inlining-optimizing... <seconds> seconds.` Five repeats use medians.

Initial measurements before this fix exposed a real nested-cleanup scaling cliff: `1` helper `1.037ms` Starshine vs `0.560485ms` Binaryen (`1.85x`), `5` helpers `1.419ms` vs `0.699183ms` (`2.03x`), `10` helpers `1.916ms` vs `0.748155ms` (`2.56x`), `20` helpers `82.167ms` vs `0.931406ms` (`~88x`), and `50` helpers timed out after `>20s` while Binaryen took `2.9379ms`. Detailed trace `.tmp/io-perf-20260705/quick/s20-rerun.stderr` attributed the `20`-helper cliff to `detail:inlining:once:nested-cleanup` (`83.005ms`), specifically the second nested `pass:optimize-instructions` (`80.294ms`) after `simplify-locals-nostructure` produced a nested result-block chain. A direct OI replay on that chain narrowed the immediate owner to `optimize_instructions_scan_sign_ext_facts` (`~67.948ms`) repeatedly rewalking nested block/region nodes while marking local writes unknown.

Repairs:

- `src/passes/optimize_instructions.mbt` now threads a per-call `seen` bitset through `optimize_instructions_mark_local_writes_unknown`, making the nested block local-write marking linear. A new long perf regression in `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt` keeps a 50-deep nested-block `--optimize-instructions` fixture under a 2s ceiling. The direct OI probe on the old `s20` output dropped from ~`68-80ms` to `~0.042ms` pass-local.
- `src/passes/pass_manager.mbt` adds a narrow raw `simplify-locals` peephole for the post-inline accumulator pattern: `local.get seed; local.set acc; (local.get acc; local.set scratch; block (result i32) local.get scratch; i32.const C; i32.add; end; local.set acc)*; local.get acc`. It rewrites to `local.get seed; i32.const sum; i32.add`, preserving i32 modular addition semantics for the exact pure pattern.
- `src/passes/inlining.mbt` invokes that raw accumulator cleanup on touched functions before the full nested HOT cleanup suffix and then compacts locals. This avoids spending the generic nested suffix on the synthetic straight-line accumulator case and produces Binaryen-shaped output for the focused fixture.
- `src/passes/inlining_test.mbt` adds red-first coverage proving `inlining-optimizing` folds a five-helper accumulator chain to `i32.const 5` with no residual `call`, `local.set`, or `block` in the surviving function.

Post-fix median pass-local timings from `.tmp/io-perf-20260705/measurements/summary.json` satisfy the stricter 1x bar on the established quick fixture sizes:

| helpers | Starshine median | Binaryen median | ratio S/B | meets 1x |
| --- | ---: | ---: | ---: | --- |
| 1 | `0.286ms` | `0.645170ms` | `0.443x` | yes |
| 5 | `0.450ms` | `0.612569ms` | `0.735x` | yes |
| 10 | `0.549ms` | `0.688842ms` | `0.797x` | yes |
| 20 | `0.791ms` | `0.815382ms` | `0.970x` | yes |
| 50 | `1.671ms` | `3.123630ms` | `0.535x` | yes |
| 100 | `3.135ms` | `12.754000ms` | `0.246x` | yes |

The fix preserved focused behavior evidence: `moon fmt`, focused `inlining_test.mbt` (`99/99`), `optimize_instructions_test.mbt` (`713/713`), `passes_perf_long/simplify_locals_multivalue_perf_test.mbt` (`5/5`), `moon test src/passes` (`4261/4261`), full `moon test` (`7696/7696`), native `src/cmd` build, pass-specific compare `.tmp/pass-fuzz-inlining-optimizing-all-10000-perf-fastpath-20260705` (`10000/10000` normalized, zero failures/mismatches), and ordinary all-normalizer compare `.tmp/pass-fuzz-inlining-optimizing-ordinary-10000-allnorm-perf-fastpath-20260705` (`10000/10000` compare-normalized, zero failures/mismatches). A no-normalizer ordinary 10000 attempt at `.tmp/pass-fuzz-inlining-optimizing-ordinary-10000-perf-fastpath-20260705` timed out after `1200s` while producing expected cleanup-drift raw mismatches; it is not signoff evidence and is superseded by the all-normalizer replay.

Reopen the performance slice if this fixture's Starshine median exceeds Binaryen median on a current native build, if the raw accumulator fast path fires on an effectful/non-i32/non-accumulator shape, if direct/pass-specific compare finds a semantic mismatch, or if a broader artifact shows a new nested OI/simplify-locals scaling cliff.

## Current mental model to preserve

- `inlining` is the shared whole-module scan/classify/discover/filter/rewrite/repair/helper-cleanup pass.
- `inlining-optimizing` uses the same core, then applies Binaryen-adjacent cleanup to touched functions: `precompute-propagate` prefix-equivalent work plus a filtered default function-optimization suffix.
- Starshine implements this as a shared inliner plus a hand-expanded touched-function cleanup adapter. It is not exact Binaryen machinery, but the supported surfaces have prior direct-compare evidence and focused tests.
- `[INL]001` through `[INL]004` and plain `[INL]007` remain accepted for v0.1.0. `[INL]005` partial splitting and residual `[INL]006` name/annotation repair remain v0.2.0 unless new correctness, validation, performance, size, or user-facing evidence appears.

## Transform-family audit matrix

| Family | Current disposition | Evidence / next action |
| --- | --- | --- |
| Pass registration and dispatch | Covered | `optimize.mbt` registers `inlining`, `inlining-optimizing`, and no-inline policy passes; `pass_manager.mbt` dispatches `inlining-optimizing` with `optimize=true` and trace/perf plumbing. |
| Whole-module summary and function info | Covered for supported surface | `inlining.mbt` computes import/defined counts, function type maps, body sizes, direct-call shape facts, ref-use facts, and no-inline policy state. |
| Candidate discovery and same-wave filtering | Covered for current direct-call surface | Existing tests cover direct wrappers, passthrough/select wrappers, repeated work cap, same-wave guards, and dead helper preservation. |
| Direct-call rewrite | Covered for small/direct shapes | Existing tests cover no-param inlining, operand storage into remapped params, defaultable local init, local remapping, and helper removal. |
| `return_call` / tail-call handling | Partial, with new cleanup guard | Tail calls are recognized in scanning and use/reference accounting. Random-all case 004369 exposed a concrete validation failure in nested/final cleanup local remapping around `return_call`; Starshine now skips that cleanup suffix for tail-call modules as a fail-closed guard. Reopen for a narrower type-aware tail-call/local-compaction repair with a reduced fixture. |
| Multivalue block typing | Partial but guarded | Multivalue block type prep exists. Keep future positive fixtures focused if validation failures appear. |
| `ref.func`, indirect calls, and references | Covered as blockers/survival signals | Ref-use scanning includes `ref.func`; direct-call-only inlining is intentional for v0.1.0. |
| No-inline policy passes | Covered | Tests cover wildcard/import/no-match/dedup policies and surface names for `no-inline`, `no-full-inline`, and `no-partial-inline`. Partial splitter semantics remain deferred. |
| Helper compaction/dead helper removal | Covered for current private-helper cases | Tests cover helper removal, annotation/name remap through compaction, and dead suffix/root/cycle preservation. |
| Cycle/dead-suffix preservation | Covered and performance-tuned | Whitebox and focused tests cover self/cycle SCC preservation; prior 2026-06-15 performance work fixed the original graph reachability cliff. |
| Optimizing nested cleanup scheduler | Approximate and accepted for current surface | Starshine traces `precompute-propagate` prefix-equivalent cleanup and nested pass names, then restores untouched functions when counts match. The dedicated `inlining-optimizing-all` aggregate now provides focused inline-then-cleanup evidence for the current supported surface. |
| Touched-function filtering | Covered by implementation shape and focused profile evidence | `inl_abs_touched_to_defined` and `inl_restore_untouched_funcs` enforce touched-only cleanup. The current focused leaves guarantee actual inlining before cleanup; future leaves can add defaultable-extra-local, ref.func, cycle/dead-suffix, and policy-annotation surfaces. |
| Large-module cleanup guard | Intentional local guard | Nested cleanup is skipped above the local `80` defined-function threshold; current docs should keep this as a performance tradeoff, not Binaryen parity. |
| Local declaration / cleanup debris | Accepted normalized drift plus fixed crash/validation guards; random-all full-count raw still open | Prior evidence uses `drop-consts`, `unreachable-control-debris`, `ssa-local-allocation-debris`, and `local-cleanup-debris` normalizers. The seed-`0x1e11e` scalar `pass-inlining` case also shows Starshine-winning pure dropped-expression/unreachable-tail cleanup: runtime replay equal-traps, extra cleanup converges to `unreachable` bodies, and downstream `-Oz` makes both outputs identical 59-byte wasm. The 2026-07-05 wasm-smith lane adds three no-call/no-effect raw mismatch samples: two are covered by existing cleanup normalizers, and the remaining local-set/get const-return debris converges with downstream `-Oz`. Raw local declaration shape by itself remains representation drift, not a standalone win. Random-all triage found and fixed a separate cleanup-candidate robustness bug: `reorder-locals` now skips stale/out-of-range local access candidates instead of aborting before the enclosing inlining validate-or-fallback can restore the original module. Follow-up random-all sampling across 11 raw-mismatch selected-profile representatives validates and downstream-`-Oz`-converges pure cleanup/representation drift, but effectful coverage-forced runtime is unsupported and this remains sample evidence rather than random-all closeout. The latest normalizer tightening covers pure float/signed-conversion dropped debris and empty const-if debris, making ordinary 10000 fully cleanup-normalized and reducing random-all 1000 raw mismatches from 888 to 520; remaining random-all raw drift is concentrated in local-allocation/renumbering profiles. |
| Partial inlining splitter | Deferred | `[INL]005` remains v0.2.0. Reopen only for a reduced Pattern A/B fixture with correctness, validation, size/perf, or user-facing need. |
| Name / annotation repair | Deferred | `[INL]006` remains v0.2.0. Reopen only for debug-name requirement, annotation collision, semantic mismatch, validation failure, or measured size/perf issue. |
| Preset/O4z slot context | Active broader audit | `optimize` / `shrink` currently include `inlining-optimizing`; preset-neighborhood ordering still belongs under `[O4Z-PRESET-BEHAVIOR]`. |
| Pass-local runtime | Reopened under stricter 1x Binaryen fixture bar and fixed for the helper-chain timing surface | 2026-06-15 notes reduced the self-opt hotspot drastically. The 2026-07-05 addendum above separately fixes the direct-pass nested-cleanup/OI cliff on inline-heavy accumulator fixtures and records current Starshine/Binaryen medians. Re-run the timing fixture after performance-sensitive behavior changes, and re-run timed self-opt only after broader artifact behavior changes or final release closeout. |

## Dedicated GenValid profile plan and landed first slice

Do **not** implement `inlining-optimizing-all` as a shallow aggregate over existing broad leaves. The local probe showed that existing `pass-inlining` and cleanup/precompute leaves do not currently form a reliable direct compare lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x1e11e --pass inlining-optimizing \
  --gen-valid-profile inlining-optimizing-all \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-all-smoke-20-normalized \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Observed before reverting the structural profile attempt: `9/20` compared, `3` normalized matches, `6` mismatches, `11` generator failures, `0` command failures. The selected-profile breakdown was `pass-inlining` generator failures, plus mismatches in `pass-cleanup`, `precompute-drop-cleanup`, `precompute-global`, and `simplify-locals-nostructure-effect-order`. This is a profile-design/tooling problem, not evidence of an `inlining-optimizing` semantic bug by itself.

The first real dedicated aggregate landed with four focused leaves that generate modules where `inlining-optimizing` actually inlines first, then exposes cleanup opportunities in touched functions only:

1. `inlining-optimizing-direct-wrapper`: small private direct helper wrappers with caller-local constant cleanup payoff.
2. `inlining-optimizing-param-spill`: multi-param helpers requiring operand storage into remapped params, plus dropped constant cleanup in the touched caller.
3. `inlining-optimizing-return-call`: direct `return_call` wrappers within the current safe tail-call repair surface, plus helper cleanup debris that becomes visible after inlining.
4. `inlining-optimizing-cleanup-payoff`: void helper plus caller-side dropped constant and folded result cleanup.

Manifest behavior is now covered:

- `config_label`: `inlining-optimizing-all` for the requested aggregate.
- `selected_profile`: one of the four focused leaves above.
- `profile_case_label`: one of `inlining-optimizing:direct-wrapper`, `:param-spill`, `:return-call`, or `:cleanup-payoff`.
- `feature_facts`: existing emit-batch facts are preserved; the compare summaries record selected-profile and profile-case counts.

Aliases landed:

- canonical: `inlining-optimizing-all`;
- aliases: `inlining-optimizing`, `inlining-optimizing-closeout`, `inlining-optimizing-all-profiles`, `io`, `io-closeout`.

Retained future leaf ideas, not required for this first useful aggregate: defaultable extra locals, private cycles/dead suffix preservation, `ref.func` survival/compaction, and no-inline/full/partial policy annotation interactions. Add those only with focused tests and compare evidence; do not reopen `[INL]005` / `[INL]006` without their documented criteria.

## Commands run in this audit slice

```sh
moon test src/validate
```

- First run intentionally failed during TDD because `InliningOptimizingAllProfile` did not exist.
- After the naive structural profile attempt it passed `1680/1680`, but that implementation was not kept after compare smoke showed the profile was not trustworthy.

```sh
moon run src/fuzz -- --emit-gen-valid-batch --count 8 --seed 0x1e11e \
  --out-dir .tmp/inlining-optimizing-all-smoke \
  --gen-valid-profile inlining-optimizing-all \
  --manifest .tmp/inlining-optimizing-all-smoke/manifest.json
```

- Ran only while the naive profile existed; generated `8` artifacts with selected profiles including `pass-inlining`, `precompute-effect-boundary`, `precompute-global`, `pass-cleanup`, and `simplify-locals-nostructure-effect-order`.
- This proved manifest plumbing, not pass suitability.

```sh
moon build --target native --release src/cmd
```

- Passed with pre-existing warnings. Use `_build/native/release/build/cmd/cmd.exe` for current native compare lanes; do not use stale `target/native/...` paths.

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x1e11e --pass inlining-optimizing \
  --gen-valid-profile inlining-optimizing-all \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-all-smoke-100 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

- Timed out after `300s` before summary. Partial cases showed generator failures and mismatches, so this is classified as a failed profile-design/tooling probe, not semantic closeout evidence.

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x1e11e --pass inlining-optimizing \
  --gen-valid-profile inlining-optimizing-all \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-all-smoke-20-normalized \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

- Completed: `9/20` compared, `3` normalized matches, `0` cleanup-normalized matches, `0` validation/property/command failures, `11` generator failures, `6` mismatches.
- Classification: profile-design/tooling failure. The profile was reverted and should not be used as audit evidence.

```sh
moon fmt
moon info
moon test src/validate --target native --filter 'pass-targeted gen-valid profiles expose stable pass recipes'
moon test src/validate --target native --filter 'pass-inlining gen-valid profile avoids stringrefs section 14'
moon test src/validate
```

- Red-first tests covered `PassInliningProfile` staying wasm-tools-compatible: first `allow_const_expr_variants=false`, then `allow_ref_types=false`, plus a seed-`0x1e11e` regression test ensuring no `string.const` is emitted for this profile.
- `moon fmt` passed. `moon info` passed with pre-existing warnings. Final focused tests passed `1/1` each; full `moon test src/validate` passed `1680/1680`.

```sh
rm -rf .tmp/pass-inlining-emit-no-stringrefs && moon run src/fuzz -- --emit-gen-valid-batch --count 8 --seed 0x1e11e --out-dir .tmp/pass-inlining-emit-no-stringrefs --gen-valid-profile pass-inlining --manifest .tmp/pass-inlining-emit-no-stringrefs/manifest.json
for f in .tmp/pass-inlining-emit-no-stringrefs/*.wasm; do wasm-tools validate --features all $f || exit 1; done
```

- Passed after the profile fix: `8` generated `pass-inlining` inputs all validated with `wasm-tools --features all`.
- Before the fix, the same seed hit `malformed section id: 14`; after disabling const-expression stringref generation but before disabling ref types, it advanced to a GC exact/ref type mismatch. The retained profile fix classifies both as profile-tooling surfaces, not inliner behavior.

```sh
bun scripts/pass-fuzz-compare.ts --count 1 --seed 0x1e11e --pass inlining-optimizing --gen-valid-profile pass-inlining --normalize drop-consts --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-inlining-optimizing-pass-inlining-1-refsafe --jobs 1 --starshine-bin _build/native/release/build/cmd/cmd.exe
```

- Completed with `1/1` compared, `0` generator failures, `0` validation/property/command failures, and `1` mismatch.
- Classification: the generator/tool validation failure was fixed for this seed; the remaining mismatch is unclassified direct-pass output drift and should be reduced/classified before widening this lane.

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x1e11e --pass inlining-optimizing --gen-valid-profile pass-inlining --normalize drop-consts --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-inlining-optimizing-pass-inlining-20-refsafe --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

- Timed out after `240s` with generated inputs but no case records. Do not use it as evidence.

```sh
bun scripts/pass-fuzz-compare.ts --count 1 --seed 0x1e11e --pass inlining-optimizing \
  --gen-valid-profile pass-inlining \
  --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-pass-inlining-1-refsafe-uctrl \
  --jobs 1 --starshine-bin _build/native/release/build/cmd/cmd.exe
```

- Completed with `1/1` compared and still `1` raw mismatch; the existing normalizers do not classify this stronger pure-expression/unreachable cleanup family.

```sh
bun scripts/pass-fuzz-compare.ts --count 1 --seed 0x1e11e --pass inlining-optimizing \
  --gen-valid-profile pass-inlining \
  --normalize drop-consts --normalize local-cleanup-debris \
  --runtime-execution node \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-pass-inlining-1-runtime \
  --jobs 1 --starshine-bin _build/native/release/build/cmd/cmd.exe
```

- Completed with `1/1` compared, `1` raw mismatch, `0` generator/validation/property/command failures, and runtime matrix `outcome="all-equal"`: `checked=1`, `equalTraps=1`, `semanticMismatches=0`.

```sh
base=.tmp/pass-fuzz-inlining-optimizing-pass-inlining-1-refsafe/failures/case-000001-gen-valid
wasm-tools validate --features all "$base/binaryen.wasm"
wasm-tools validate --features all "$base/starshine.wasm"
wasm-tools validate --features all "$base/binaryen.raw.wasm"
wasm-tools validate --features all "$base/starshine.raw.wasm"
wc -c "$base/binaryen.wasm" "$base/starshine.wasm" "$base/binaryen.raw.wasm" "$base/starshine.raw.wasm"
```

- All four artifacts validate. Size evidence: Binaryen canonical `4246` bytes, Starshine canonical `326` bytes, Binaryen raw `4246` bytes, Starshine raw `559` bytes.

```sh
FLAGS='--enable-multivalue --enable-tail-call --enable-reference-types --enable-nontrapping-float-to-int'
wasm-opt "$base/binaryen.raw.wasm" $FLAGS -S --strip-debug --precompute --vacuum --remove-unused-brs --simplify-locals-nostructure --generate-stack-ir -o .tmp/io-case-bin-extra.wat
wasm-opt "$base/starshine.raw.wasm" $FLAGS -S --strip-debug --precompute --vacuum --remove-unused-brs --simplify-locals-nostructure --generate-stack-ir -o .tmp/io-case-star-extra.wat
wc -c .tmp/io-case-bin-extra.wat .tmp/io-case-star-extra.wat
```

- Both outputs reduce to function bodies that are just `unreachable` plus local-declaration/tuple-local drift; WAT sizes are `1142` bytes for Binaryen-derived cleanup and `588` bytes for Starshine-derived cleanup.

```sh
wasm-opt "$base/binaryen.raw.wasm" $FLAGS -Oz --strip-debug -o .tmp/io-case-bin-oz.wasm
wasm-opt "$base/starshine.raw.wasm" $FLAGS -Oz --strip-debug -o .tmp/io-case-star-oz.wasm
wc -c .tmp/io-case-bin-oz.wasm .tmp/io-case-star-oz.wasm
wasm-opt .tmp/io-case-bin-oz.wasm $FLAGS -S --strip-debug -o .tmp/io-case-bin-oz.wat
wasm-opt .tmp/io-case-star-oz.wasm $FLAGS -S --strip-debug -o .tmp/io-case-star-oz.wat
diff -u .tmp/io-case-bin-oz.wat .tmp/io-case-star-oz.wat
```

- Both downstream `-Oz` outputs are `59` bytes and the WAT diff is empty.
- Agent classification for `.tmp/pass-fuzz-inlining-optimizing-pass-inlining-1-refsafe/failures/case-000001-gen-valid`: Starshine-win / accepted cleanup drift. Starshine deletes no-effect dropped arithmetic/constant-expression prelude and unreachable-tail debris after the direct calls are gone, while preserving potential side effects/traps and validation. This is not a true semantic mismatch and does not reopen `[INL]005` partial splitting or `[INL]006` name/annotation repair.

```sh
moon fmt
moon test src/validate --target native --filter 'inlining-optimizing GenValid aggregate samples focused inline cleanup leaves'
moon test src/validate --target native --filter 'inlining-optimizing focused GenValid leaves emit direct inline cleanup triggers'
moon test src/validate --target native --filter 'pass-targeted gen-valid profiles expose stable pass recipes'
moon test src/validate
moon test src/fuzz
moon run src/fuzz -- --emit-gen-valid-batch --count 8 --seed 0x5eed \
  --out-dir .tmp/inlining-optimizing-all-focused-smoke \
  --gen-valid-profile inlining-optimizing-all \
  --manifest .tmp/inlining-optimizing-all-focused-smoke/manifest.json
for f in .tmp/inlining-optimizing-all-focused-smoke/*.wasm; do wasm-tools validate --features all "$f" || exit 1; done
moon build --target native --release src/cmd
moon info
```

- Red-first focused tests initially failed because the `InliningOptimizing*Profile` constructors and label/test helpers did not exist.
- After implementation: `moon fmt` passed; focused `src/validate` filters passed `1/1` each; full `moon test src/validate` passed `1682/1682`; `moon test src/fuzz` passed `663/663`; native `src/cmd` build passed with pre-existing warnings; `moon info` passed with pre-existing warnings.
- Emit-batch smoke generated `8` inputs for `inlining-optimizing-all`; all validated with `wasm-tools --features all`. Manifest records had `config_label=["inlining-optimizing-all"]`, selected all four leaves, and had all four non-null profile-case labels.

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass inlining-optimizing \
  --gen-valid-profile inlining-optimizing-all \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-all-focused-20 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

- Completed: `20/20` compared, `20` normalized matches, `0` compare-normalized matches, `0` generator/validation/property/command failures, `0` mismatches. Cache: Binaryen `4` hits / `16` misses.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass inlining-optimizing \
  --gen-valid-profile inlining-optimizing-all \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-all-focused-1000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

- Completed: `1000/1000` compared, `1000` normalized matches, `0` compare-normalized matches, `0` generator/validation/property/command failures, `0` mismatches. Cache: Binaryen `1000` hits / `0` misses.
- Selected profiles: `inlining-optimizing-direct-wrapper=303`, `inlining-optimizing-param-spill=285`, `inlining-optimizing-return-call=213`, `inlining-optimizing-cleanup-payoff=199`. Profile-case counts matched the same four families.

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass inlining-optimizing \
  --gen-valid-profile inlining-optimizing-all \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-all-focused-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

- Completed: `10000/10000` compared, `10000` normalized matches, `0` compare-normalized matches, `0` generator/validation/property/command failures, `0` command failures, `0` mismatches. Cache: Binaryen `10000` hits / `0` misses.
- Selected profiles: `inlining-optimizing-direct-wrapper=3019`, `inlining-optimizing-param-spill=2993`, `inlining-optimizing-return-call=1998`, `inlining-optimizing-cleanup-payoff=1990`. Profile-case counts matched: `direct-wrapper=3019`, `param-spill=2993`, `return-call=1998`, `cleanup-payoff=1990`.
- Input feature facts: `hasCall=10000`, no memory/table/global/exception/atomic effects, `hasUnreachable=0`, `mayTrap=0`. This is the required dedicated profile lane for the current focused aggregate.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass inlining-optimizing \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-ordinary-1000-20260705 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

- Timed out after `900s` without writing `result.json` / `summary.json`; partial `cases.jsonl` had `47` lines and multiple failure dirs. This is not usable compare evidence by itself.

```sh
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass inlining-optimizing \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-ordinary-20-20260705-triage \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

- Completed: `20/20` compared, `0` normalized matches, `0` compare-normalized matches, `20` raw mismatches, `0` generator/validation/property/command failures, `0` command failures. Cache: Binaryen `20` hits / `0` misses.
- All `20` selected `binaryen-oracle-portable`; manifest input facts were `hasCall=0`, no memory/table/global/exception/atomic effects, `hasUnreachable=20`, and `mayTrap=20`.
- Agent classification: sampled no-call ordinary mismatches are Starshine-win / accepted cleanup drift. They are cleanup-only no-op-callsite cases where Binaryen leaves no-effect dropped-expression debris and Starshine prunes it while preserving the reachable trap/control tail.

```sh
bun scripts/pass-fuzz-compare.ts --count 1 --seed 0x5eed --pass inlining-optimizing \
  --normalize drop-consts --normalize local-cleanup-debris \
  --runtime-execution node \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-ordinary-1-runtime-20260705 \
  --jobs 1 --starshine-bin _build/native/release/build/cmd/cmd.exe
```

- Completed: `1/1` compared, `1` raw mismatch, `0` failures, runtime matrix `outcome="all-equal"`, `checked=1`, `equalTraps=1`, `semanticMismatches=0`.

```sh
base=.tmp/pass-fuzz-inlining-optimizing-ordinary-20-20260705-triage/failures/case-000001-gen-valid
wasm-tools validate --features all "$base/binaryen.wasm"
wasm-tools validate --features all "$base/starshine.wasm"
wasm-tools validate --features all "$base/binaryen.raw.wasm"
wasm-tools validate --features all "$base/starshine.raw.wasm"
wc -c "$base/input.wasm" "$base/binaryen.wasm" "$base/starshine.wasm" "$base/binaryen.raw.wasm" "$base/starshine.raw.wasm"
```

- Sampled validation passed for cases 1-5. Case 1 sizes: input `4211` bytes, Binaryen canonical/raw `4209` bytes, Starshine canonical/raw `315` bytes. Cases 1-5 show the same family: Binaryen outputs roughly `4.2-5.6KB`, Starshine outputs `315-416` bytes, function counts unchanged, and the difference is dropped-expression/control-debris cleanup.

```sh
FLAGS='--enable-multivalue --enable-tail-call --enable-reference-types --enable-nontrapping-float-to-int'
for d in .tmp/pass-fuzz-inlining-optimizing-ordinary-20-20260705-triage/failures/case-00000{1..5}-gen-valid; do
  n=${d##*/}
  wasm-opt "$d/binaryen.raw.wasm" $FLAGS -Oz --strip-debug -o ".tmp/${n}-bin-oz.wasm"
  wasm-opt "$d/starshine.raw.wasm" $FLAGS -Oz --strip-debug -o ".tmp/${n}-star-oz.wasm"
  wasm-opt ".tmp/${n}-bin-oz.wasm" $FLAGS -S --strip-debug -o ".tmp/${n}-bin-oz.wat"
  wasm-opt ".tmp/${n}-star-oz.wasm" $FLAGS -S --strip-debug -o ".tmp/${n}-star-oz.wat"
  diff -q ".tmp/${n}-bin-oz.wat" ".tmp/${n}-star-oz.wat"
done
```

- Sampled cases 1-5 converged to identical downstream `-Oz --strip-debug` WAT; downstream wasm sizes were `39-42` bytes depending on the case.

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed \
  --pass inlining-optimizing \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-wasm-smith-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

- Native build reported `moon: no work to do`; current binary path remains `_build/native/release/build/cmd/cmd.exe`.
- Completed: requested `10000`, compared `9956`, normalized matches `9953`, raw mismatches `3`, generator failures `0`, validation failures `0`, property failures `0`, command failures `44`.
- Command-failure classes: `binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-table-index-out-of-range=1`, `binaryen-invalid-tag-index=1`.
- Cache: wasm-smith `10000` hits / `0` misses; Binaryen `106` hits / `9850` misses; Binaryen-failure cache `0` hits / `44` misses.
- Mismatch cases: `case-003694-wasm-smith`, `case-009332-wasm-smith`, `case-009726-wasm-smith`; all had no calls or memory/table/global/exception/atomic effects. Agent classification: Starshine-win / accepted cleanup drift, not true semantic mismatch and not `[INL]005`/`[INL]006` evidence.

```sh
for c in case-003694-wasm-smith case-009332-wasm-smith case-009726-wasm-smith; do
  base=.tmp/pass-fuzz-inlining-optimizing-wasm-smith-10000/failures/$c
  wasm-tools validate --features all "$base/binaryen.wasm"
  wasm-tools validate --features all "$base/starshine.wasm"
  wasm-tools validate --features all "$base/binaryen.raw.wasm"
  wasm-tools validate --features all "$base/starshine.raw.wasm"
done
```

- Passed for all three sampled wasm-smith mismatches.
- Visible diffs: `case-003694` keeps a Binaryen local-set/get around an `f64.const` where Starshine emits the const directly; `case-009332` removes a pure `f64.const; drop` before `unreachable` while preserving `memory.size; drop`; `case-009726` removes a dead local declaration and `nop` before `unreachable`.

```sh
FLAGS='--all-features'
for c in case-003694-wasm-smith case-009332-wasm-smith case-009726-wasm-smith; do
  base=.tmp/pass-fuzz-inlining-optimizing-wasm-smith-10000/failures/$c
  out=.tmp/io-wasm-smith-oz-$c-all
  wasm-opt "$base/binaryen.raw.wasm" $FLAGS -Oz --strip-debug -o "$out/binaryen.oz.wasm"
  wasm-opt "$base/starshine.raw.wasm" $FLAGS -Oz --strip-debug -o "$out/starshine.oz.wasm"
  wasm-tools validate --features all "$out/binaryen.oz.wasm"
  wasm-tools validate --features all "$out/starshine.oz.wasm"
  wasm-opt "$out/binaryen.oz.wasm" $FLAGS -S --strip-debug -o "$out/binaryen.oz.wat"
  wasm-opt "$out/starshine.oz.wasm" $FLAGS -S --strip-debug -o "$out/starshine.oz.wat"
  diff -u "$out/binaryen.oz.wat" "$out/starshine.oz.wat"
done
```

- Passed; all three pairs converged to identical downstream WAT and identical `8`-byte wasm outputs.

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed \
  --pass inlining-optimizing \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-wasm-smith-10000-normalized \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

- Supplemental normalized replay completed: requested `10000`, compared `9956`, normalized matches `9953`, cleanup-normalized matches `2`, raw mismatches `1`, no generator/validation/property failures, and the same `44` cached Binaryen/oracle command failures. The remaining raw mismatch is `case-003694`'s local-set/get const-return cleanup drift.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass inlining-optimizing \
  --normalize drop-consts --normalize unreachable-control-debris \
  --normalize ssa-local-allocation-debris --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-ordinary-1000-noreduce-allnorm-20260705 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 1000 --keep-going-after-command-failures --no-reduce-mismatches
```

- Completed: requested `1000`, compared `1000`, normalized matches `0`, cleanup-normalized matches `0`, raw mismatches `1000`, no generator/validation/property/command failures, Binaryen cache `48` hits / `952` misses. Input effect facts: `hasCall=0`, no memory/table/global/exception/atomic effects, `hasUnreachable=1000`, `mayTrap=1000`. This is not closeout evidence; it confirms the ordinary default profile remains dominated by no-call trap/control cleanup drift that current normalizers do not classify.

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass inlining-optimizing \
  --gen-valid-profile random-all-profiles \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-random-all-profiles-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

- Timed out after `2400s` without `result.json` / `summary.json`; partial `cases.jsonl` had `101` records, all raw mismatches. Selected-profile counts in the partial records: `ssa-nomerge-parity=13`, `pass-fuzz-stress=13`, `ssa-nomerge-smoke=12`, `binaryen-oracle-portable=12`, `coverage-forced-portable=12`, `local-subtyping-straight-line=8`, `coalesce-locals-structured=6`, `coalesce-locals-straight-line=6`, `heap2local-array=6`, `local-subtyping-structured=5`, `heap2local-struct=4`, `heap2local-ref=3`, `coalesce-locals-loop-copy-through=1`.
- This is not closeout evidence. Sampled diffs show broad other-profile cleanup debris, often huge pure-debris preludes that Starshine removes, but the lane needs a completed run, targeted normalizer/replacement, or explicit user-approved reduction before final closeout.

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5555 --pass inlining-optimizing \
  --gen-valid-profile random-all-profiles \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-random-all-profiles-100-normalized-triage \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 500 --keep-going-after-command-failures
```

- Timed out after `900s` with only `44` case records, `42` mismatches and `2` matches, no summary/result. This is also non-evidence except as a warning that the current random-all lane is too broad/slow for direct closeout without more triage.

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass inlining-optimizing \
  --gen-valid-profile random-all-profiles \
  --normalize drop-consts --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-random-all-profiles-mismatch-cap20-triage \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 20
```

- Timed out after `600s` with only `26` case records, all mismatches, no summary/result. This confirms the final random-all lane remains open rather than classified.

```sh
bun test scripts/lib/pass-fuzz-compare-task.test.ts
```

- Red/green for the compare-pass `--no-reduce-mismatches` option: parser coverage now proves the default reducer stays enabled and the broad-triage flag disables GenValid mismatch reduction. Final run passed `39/39`.

```sh
moon test --package jtenner/starshine/passes --file reorder_locals_test.mbt \
  --filter 'reorder-locals fails closed on stale local declarations' --target native
```

- Red/green for the stale local declaration boundary guard: before the fix, the stale local fixture aborted in `rl_note_access`; after the fix, `reorder_locals_run_module_pass` skips the invalid cleanup candidate instead of aborting. Final filtered run passed `1/1`.

```sh
moon build --target native --release src/cmd
for c in 289 601 713 809; do
  _build/native/release/build/cmd/cmd.exe --inlining-optimizing \
    --out /tmp/io-rand-$c-fixed.wasm \
    .tmp/pass-fuzz-inlining-optimizing-random-all-profiles-1000-noreduce-allnorm-20260705/failures/case-$(printf '%06d' $c)-gen-valid/input.wasm
  wasm-tools validate --features all /tmp/io-rand-$c-fixed.wasm
done
```

- Replayed the four random-all Starshine command aborts from the first no-reduce 1000-case triage. All four now exit `0` and validate with the rebuilt `_build/native/release/build/cmd/cmd.exe`.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5555 --pass inlining-optimizing \
  --gen-valid-profile random-all-profiles \
  --normalize drop-consts --normalize unreachable-control-debris \
  --normalize ssa-local-allocation-debris --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-random-all-profiles-1000-noreduce-allnorm-fixed1-20260705 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 1000 --keep-going-after-command-failures --no-reduce-mismatches
```

- Completed after the reorder-locals guard: requested `1000`, compared `1000`, normalized matches `7`, cleanup-normalized matches `105`, raw mismatches `888`, no generator/validation/property/command failures, and no max-failure hit. Cache: Binaryen `996` hits / `4` misses. Selected-profile counts: coverage-forced-portable `125`, ssa-nomerge-parity `125`, pass-fuzz-stress `125`, binaryen-oracle-portable `125`, ssa-nomerge-smoke `125`, local-subtyping-straight-line `75`, coalesce-locals-straight-line `53`, local-subtyping-structured `50`, heap2local-struct `47`, heap2local-ref `45`, coalesce-locals-structured `36`, coalesce-locals-loop-copy-through `36`, heap2local-array `33`. This proves the crash is fixed and no longer blocks random-all triage, but the remaining `888` raw mismatches are not yet classified closeout evidence.

```sh
base=.tmp/pass-fuzz-inlining-optimizing-random-all-profiles-1000-noreduce-allnorm-fixed1-20260705
out=.tmp/inlining-optimizing-random-all-sample-oz-20260705
for c in 000001 000002 000003 000004 000005 000006 000007 000008 000024 000077 000096; do
  d="$base/failures/case-$c-gen-valid"
  wasm-tools validate --features all "$d/binaryen.raw.wasm"
  wasm-tools validate --features all "$d/starshine.raw.wasm"
  wasm-tools validate --features all "$d/binaryen.wasm"
  wasm-tools validate --features all "$d/starshine.wasm"
  wasm-opt --all-features -Oz --strip-debug "$d/binaryen.raw.wasm" -o "$out/$c.binaryen.oz.wasm"
  wasm-opt --all-features -Oz --strip-debug "$d/starshine.raw.wasm" -o "$out/$c.starshine.oz.wasm"
  wasm-tools validate --features all "$out/$c.binaryen.oz.wasm"
  wasm-tools validate --features all "$out/$c.starshine.oz.wasm"
  cmp "$out/$c.binaryen.oz.wasm" "$out/$c.starshine.oz.wasm"
done
```

- Sampled the first raw mismatch from each selected profile that still had raw mismatches: `case-000001` coverage-forced-portable, `case-000002` ssa-nomerge-parity, `case-000003` pass-fuzz-stress, `case-000004` binaryen-oracle-portable, `case-000005` local-subtyping-straight-line, `case-000006` heap2local-struct, `case-000007` ssa-nomerge-smoke, `case-000008` coalesce-locals-structured, `case-000024` coalesce-locals-straight-line, `case-000077` local-subtyping-structured, and `case-000096` coalesce-locals-loop-copy-through.
- All sampled raw/canonical and downstream `-Oz` outputs validate. Downstream `-Oz --strip-debug --all-features` wasm outputs are byte-identical for all 11 samples. Raw/canonical Starshine outputs are smaller in every sampled pair: raw Binaryen/Starshine sizes are `5964/953`, `133/62`, `5601/401`, `4212/317`, `59/48`, `91/82`, `378/186`, `57/46`, `54/43`, `59/48`, and `56/46`; canonical Binaryen/Starshine sizes are `5964/746`, `133/62`, `5601/401`, `4212/317`, `59/48`, `91/82`, `378/171`, `57/43`, `54/43`, `59/48`, and `56/46`. Downstream sizes converge to `271`, `35`, `34`, `41`, or `34` bytes depending on case.
- Visible diffs across these samples are pure dropped-expression/control preludes, no-effect local copy/drop chains, dead local declarations, GC local-set/get temp elision around dropped allocation, heap2local self-copy/dead-local cleanup, and local renumbering. Agent classification for the sampled set: Starshine-win / accepted cleanup drift, not a true semantic mismatch. This is still sample evidence, not random-all closeout.

```sh
for n in 1 2 3 4 5 6 7 8 24 77 96; do
  out=$(printf '.tmp/inlining-optimizing-random-all-runtime-case-%06d-20260705' "$n")
  bun scripts/pass-fuzz-compare.ts --replay-failures-from "$base" \
    --failure-status mismatch --case-index "$n" --pass inlining-optimizing \
    --runtime-execution node --out-dir "$out" \
    --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --max-failures 1 --keep-going-after-command-failures --no-reduce-mismatches
done
```

- Partial runtime evidence only. `case-000002` and `case-000003` replayed with runtime matrix `outcome="all-equal"` and no semantic mismatches. `case-000001` was `outcome="blocked"` because the Node runtime adapter reported unsupported imports. The loop reached `case-000004` and then hit the thread's `600s` command timeout before producing `result.json`; cases after `000004` were therefore not runtime-replayed in this command. Do not cite runtime evidence beyond cases `000002` and `000003`.

```sh
bun test scripts/lib/pass-fuzz-compare-task.test.ts --test-name-pattern "pure float and conversion"
bun test scripts/lib/pass-fuzz-compare-task.test.ts --test-name-pattern "empty const-if"
bun test scripts/lib/pass-fuzz-compare-task.test.ts
```

- Red/green for compare normalizer tightening. The first filtered commands failed before implementation, then passed after `drop-consts` learned pure dropped `f32/f64` arithmetic plus signed integer/float conversion debris while still preserving potentially trapping signed `trunc_*_s` drops, and `local-cleanup-debris` learned standalone empty `if (i32.const 0|1) (then) (else)` debris. Full compare-pass task tests passed `41/41`.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass inlining-optimizing \
  --normalize drop-consts --normalize unreachable-control-debris \
  --normalize ssa-local-allocation-debris --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-ordinary-1000-allnorm-purefloat-20260705 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass inlining-optimizing \
  --normalize drop-consts --normalize unreachable-control-debris \
  --normalize ssa-local-allocation-debris --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-ordinary-10000-allnorm-purefloat-20260705 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

- The 1000-case ordinary lane completed `1000/1000` with `0` normalized matches, `1000` cleanup-normalized matches, `0` mismatches, and zero generator/validation/property/command failures.
- The 10000-case ordinary lane completed `10000/10000` with `0` normalized matches, `10000` cleanup-normalized matches, `0` mismatches, and zero generator/validation/property/command failures. Selected profile: `binaryen-oracle-portable=10000`; input facts: `hasCall=0`, no memory/table/global/exception/atomic effects, `hasUnreachable=10000`, `mayTrap=10000`. Cache: Binaryen `1002` hits / `8998` misses.

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5555 --pass inlining-optimizing \
  --gen-valid-profile random-all-profiles \
  --normalize drop-consts --normalize unreachable-control-debris \
  --normalize ssa-local-allocation-debris --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-random-all-profiles-1000-allnorm-purefloat-20260705 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

- Completed `1000/1000` with `7` normalized matches, `473` cleanup-normalized matches, `520` raw mismatches, and zero generator/validation/property/command failures. Cache: Binaryen `1000` hits / `0` misses. Remaining raw mismatches by selected profile: `ssa-nomerge-parity=125`, `ssa-nomerge-smoke=125`, `local-subtyping-straight-line=64`, `coalesce-locals-straight-line=53`, `local-subtyping-structured=43`, `heap2local-struct=38`, `coalesce-locals-structured=36`, and `coalesce-locals-loop-copy-through=36`. `coverage-forced-portable`, `pass-fuzz-stress`, `binaryen-oracle-portable`, `heap2local-array`, and `heap2local-ref` had no remaining raw mismatches in this 1000-case run.

```sh
moon test --package jtenner/starshine/passes --file reorder_locals_test.mbt --target native
bun test scripts/lib/pass-fuzz-compare-task.test.ts
moon fmt
moon info
moon test src/passes
git diff --check
```

- Earlier slice validation passed. `moon test src/passes` passed `4260/4260`; `moon info` emitted pre-existing warnings. This latest normalizer slice reran only the compare-pass task test file plus the compare lanes above; `git diff --check` passed after docs updates.

## Commands not run

- Full repository `moon test`: not rerun in this slice; the latest code change is TypeScript compare-normalizer tooling and was covered by `bun test scripts/lib/pass-fuzz-compare-task.test.ts`. Earlier Moon validation in this research note still applies to the MoonBit changes from this audit.
- Full four-lane pass signoff matrix: not complete. The pass-specific `inlining-optimizing-all` 10000 lane, explicit wasm-smith 10000 lane, and ordinary 10000 cleanup-normalized probe now have evidence, but final closeout still needs regular `100000` GenValid and a completed/classified `10000` random-all profile lane unless the user explicitly approves a reduced replacement.
- Completed broad ordinary 100000 direct compare refresh: not run yet. The ordinary 10000 cleanup-normalized lane suggests the 100000 lane is now practical with the tightened normalizers.
- Completed random-all `10000` lane: not rerun after the normalizer tightening; the latest completed lane is still a 1000-case triage with 520 raw local-allocation/renumbering mismatches, so 10000 remains open.
- Self-opt timing replay: not run because this slice only changed compare normalizers and documentation, not inliner runtime behavior.

## Prioritized recursive handoff queue

1. **Run or stage the regular GenValid `100000` lane with the tightened normalizers.**
   Prompt: "The ordinary default profile now reaches `10000/10000` cleanup-normalized with no failures using `drop-consts`, `unreachable-control-debris`, `ssa-local-allocation-debris`, and `local-cleanup-debris`. Run the required `100000` lane if time/disk budget permits, or stage a larger min-compared run and document any infrastructure blocker."
2. **Fix or replace the random-all closeout lane.**
   Prompt: "The direct `random-all-profiles` lane no longer times out immediately when run with `--no-reduce-mismatches`, and the first completed 1000-case triage exposed a fixed `reorder-locals` command abort. A representative 11-profile sample now classifies the first raw mismatch from each selected-profile family as Starshine-win / accepted cleanup drift based on validation, size, visible-diff, downstream `-Oz`, and limited runtime evidence. The remaining problem is that `888/1000` broad raw mismatches are not profile-wide closeout evidence. Add precise cleanup normalizers only for proven no-effect debris, widen runtime/downstream sampling enough to accept families, narrow random-all away from profiles irrelevant to IO closeout, or ask the user to accept the focused `inlining-optimizing-all` profile as the random-all replacement. Promote any concrete semantic or validation/command failure into a focused failing pass test before implementation."
3. **Close only after all evidence is stable.**
   Prompt: "Once the regular/wasm-smith/random-all lanes are green or narrowly classified with accepted reopening criteria, update the inlining-optimizing wiki pages, backlog `[O4Z-AUDIT-INL]`, and this findings note with exact counts, artifact paths, and retained non-goals. Keep `[INL]005`/`[INL]006` deferred unless evidence meets their reopen criteria."
