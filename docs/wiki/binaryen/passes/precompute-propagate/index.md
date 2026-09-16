---
kind: entity
status: supported
last_reviewed: 2026-09-03
sources:
  - ../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md
  - ../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md
  - binaryen-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../precompute/index.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../precompute/index.md
  - ../dae-optimizing/index.md
  - ../inlining-optimizing/index.md
  - ../simplify-globals-optimizing/index.md
  - ../tracker.md
---

# `precompute-propagate`

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Role

- `precompute-propagate` is an active Starshine **hot/function pass** matching Binaryen's second public precompute spelling.
- It shares its evaluator and cleanup base with [`../precompute/index.md`](../precompute/index.md), then adds one SSA-backed local-consensus solve and one bounded evaluator rerun.
- The exact public name is registered, dispatched, accepted by the compare harness, and covered by focused tests plus the `precompute-propagate-local-facts` GenValid profile.
- Starshine's two aggressive top-level PC slots now use `precompute-propagate`; ordinary plain-`precompute` remains a separately requestable direct pass.
- DAE and inlining nested optimization now use the same public implementation instead of the removed private `precompute-propagate-prefix` semantic fork.
- The shared Binaryen-v131 evaluator contract is closed: strings, general constant control `Flow`, immutable nested heaps and exact identities, ordered multi-effect retention, emitability, deterministic SIMD, descriptor/reference behavior, and exact cast refinalization are covered. The 2026-07-26 renewal also aligns the propagating no-local raw path with plain `precompute`, resolves type-indexed block/loop arities, preserves terminal multivalue branch payloads, reaches nested raw-cleanup fixpoints, and removes dropped exact pure-reference operations. Conservative legacy-EH and stack-switching preservation remains intentional. Propagation itself stays bounded to one SSA local-consensus solve and one evaluator rerun.

## Why this pass matters

- The public family gap had a dedicated `[O4Z-PCP]001` backlog slice; the implementation and propagation-specific signoff are now complete.
- The public-port closeout is [`../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md`](../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md); the shared-evaluator refresh is [`../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md`](../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md).
- The pass is already important in neighboring docs:
  - `dae-optimizing` and `inlining-optimizing` both depend on the `precompute-propagate` nested-rerun rule.
  - `simplify-globals-optimizing` is easier to teach once the contrast is explicit: it reruns the default function pipeline **without** prepending `precompute-propagate`.
- The earlier worklist follow-up closed the dossier's biggest algorithm teaching gap with a dedicated page for the exact `propagateLocals(...)` contract.
- The 2026-04-24 follow-up closed the original provenance and local-follow-along gap with an immutable raw primary-source manifest and a dedicated Starshine status / port-strategy page.
- The 2026-05-04 refresh adds a current-main no-drift manifest and a dedicated Starshine port-readiness bridge, so this folder should be treated as a deep dossier rather than only a landing dossier.

## Beginner summary

A good beginner mental model is:

- Binaryen tries to **execute** some expressions at compile time,
- keeps the rewrite only when the result can be emitted honestly,
- preserves child writes when erasing them would be wrong,
- and in `precompute-propagate` mode it also solves a small local get/set consensus problem to unlock one extra evaluator walk.

So the pass is best taught as:

- **semantic precomputation plus a narrow local worklist**,
- not just “constant folding through locals.”

## Most important durable takeaways

- `precompute-propagate` is a real public pass name in Binaryen `version_131`, not just an internal mode nickname, and Starshine exposes that exact public name.
- It shares the same `Precompute.cpp` core as plain `precompute`, but the propagate variant adds a real extra phase.
- That extra phase uses `LazyLocalGraph` to learn concrete values for some `local.get`s and then reruns the main precompute walk once.
- The propagation step is stricter than the name alone suggests:
  - sets are analyzed through their **fallthrough values**
  - propagated set values must still subtype the original set-value expression type
  - a `local.get` becomes constant only when **all** reaching sets agree on one concrete literal tuple
  - defaultable vars can contribute function-entry zero/default literals, but params and suspicious nondefaultable-local entry reads bail out
- Starshine keeps plain `precompute` available directly while its modeled aggressive optimize/shrink rosters use `precompute-propagate` in both PC slots.
- DAE and inlining nested prefixes use the same public propagating pass; simplify-globals-optimizing remains the contrast path without that extra prefix.
- The pass still depends on the same hard safety boundaries as plain `precompute`:
  - emitability of computed values
  - preservation of child local/global writes
  - bounded loop/depth exploration
  - GC identity and heap-value rules

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation, scheduler placement, helper dependencies, and the propagate-specific extra phase.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./local-worklist-fallthrough-and-merge-boundaries.md`](./local-worklist-fallthrough-and-merge-boundaries.md)
  Focused guide to the exact `propagateLocals(...)` contract: `LazyLocalGraph` worklist edges, fallthrough-value analysis, get-merge consensus, defaultable-versus-param entry behavior, nondefaultable-local bailout, and the one-extra-rerun stopping rule.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, and easy-to-misread `precompute-propagate` families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine implementation map: public descriptor/registry/dispatcher surfaces, SSA-backed consensus, result-`if` phi/direct-condition handling, guarded raw propagation, evaluator breadth, aggressive preset slots, nested-prefix reuse, and signoff evidence.

## 2026-07-26 v131 correctness-repair renewal

Fresh explicit-v131 evidence after the shared raw-control and cleanup repairs keeps the public propagating member closed. Regular `100000` and dedicated `precompute-all` `10000` lanes have zero residual mismatches. Random-all has `2135` source-inspected smaller dead-read/control cleanup wins and `328` intentional reachable-`atomic.fence` preservation differences, for a net `-24,119` canonical bytes. wasm-smith compares `9956` cases with `9954` direct matches, one fence-preservation correctness difference, one seven-byte-smaller exact scratch-local form, and `44` Binaryen-only parser/tool failures. Runtime/idempotence is green at `500/500`; see [`./fuzzing.md`](./fuzzing.md).

## 2026-08-30 batched writeback validation

The dispatcher optimization shared with plain Precompute replaces per-changed-function full-module writeback validation with one complete candidate-module batch while preserving per-function escape-carrier checks, individual rollback, and the old path as a fallback. The focused pass-manager regression covers both public names.

One warmup plus three measured serial pairs give a `1,391.824ms` no-trace command median and `189.088ms` pass-local median versus Binaryen v131 at `1,209.404ms` / `656.085ms`. Starshine is within the repository-wide `2x` gate at `1.151x` command and `0.288x` pass-local; the pass-specific `1.25s` stretch target remains narrowly open. Median batch writeback is `38.481ms`, and raw output remains 4,973,138 bytes. Evidence is under `.tmp/optimization-campaign-20260830/`.

## 2026-09-03 exact changed-definition validation set

The deferred precompute-family writeback guard now receives the exact changed-function bitset already known by the module loop. The lowered code section starts as a copy of the original definitions; in this guarded path only results with `unchanged_original == false` replace a slot, and the same condition marks that slot touched. Batch validation therefore retains the existing changed-definition validation, individual invalid-function rollback, and full fallback while avoiding structural equality checks over every untouched definition. The red-first white-box regression is `precompute batch writeback validates only touched changes` in [`../../../../../src/passes/pass_manager_wbtest.mbt`](../../../../../src/passes/pass_manager_wbtest.mbt).

The benchmark uses the 4,977,401-byte retained artifact (SHA-256 `4acd06537e4466bc372a73c2e37da46f1cd94c3baca1fd62c1aa5fe76b944721`), the pinned before binary SHA-256 `a9e9924b82e983b7f375ce29c0be239966cb613d4289a71fbe258829832836dd`, the measured candidate SHA-256 `a4a26832df96a55b5c31044f43ec098b062540e147e36e72b2c4d017e10bc45d`, and explicit Binaryen v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`. After warmups, five alternating serial before/after comparisons under one heavy-lock hold produced no-trace samples of `1,149.266`, `1,126.706`, `1,132.495`, `1,114.357`, and `1,163.136 ms` before (median `1,132.495 ms`) versus `1,112.240`, `1,086.962`, `1,106.701`, `1,107.441`, and `1,128.695 ms` after (median `1,107.441 ms`). Every paired delta was favorable: `-37.026`, `-39.744`, `-25.794`, `-6.916`, and `-34.441 ms`. Current traced samples were `1,235.091`, `1,230.018`, `1,229.011`, `1,213.157`, and `1,196.076 ms` (median `1,229.011 ms`).

The owned writeback samples moved from `31.238`, `31.106`, `30.978`, `31.133`, and `30.721 ms` (median `31.106 ms`) to `4.988`, `5.050`, `5.481`, `5.239`, and `5.220 ms` (median `5.220 ms`), an `83.2%` median reduction with all paired deltas between `-25.497` and `-26.250 ms`. Other traced medians were noisy in the opposite direction: pre-pass `84.283 -> 90.776 ms`, function-unattributed `130.236 -> 138.995 ms`, outer-loop `39.518 -> 41.662 ms`, and pass-local `170.657 -> 176.450 ms`. The corresponding current Binaryen command and pass-local medians were `1,044.713 ms` and `586.428 ms`, making current Starshine `1.060x` command wall, `0.301x` pass-local wall, and `15.93%` pass-local/command wall. In this paired candidate set, both the no-trace and traced medians clear the strict `<1.25s` target.

All five before and after runs are byte-identical: Starshine raw output is 4,973,138 bytes (SHA-256 `41fe90acc073ce2f840bb35accdcd53401db5a8fc241a635351cca3871d10275`) and canonical output is 5,294,507 bytes (SHA-256 `5cd844c0cf9ee8769f98b4e9e5fb1f2fdc40f656a189951e5e995dd59f1ec19e`). Binaryen raw/canonical output is 5,226,189 bytes (SHA-256 `bcf414a1f9334605b55e7286584fafe9a15eb100f8065c1cad8851917a39deee`). Evidence is `.tmp/perf-expression-sweep-20260903/touched-ab/`. Conditional SSA admission was profiled but not retained: unchanged functions own 62.478 ms of the clean trace's 75.280 ms aggregate SSA time, but a new HOT classifier would need to preserve direct heap/identity folds as well as local facts, and the exact writeback fix already clears the target without narrowing transformation breadth.

After scoping unchanged-slot suppression to the precompute family only, the source-identical final release binary is SHA-256 `d7fb411ed50d6010e6d7d852d191e4293a324db3dfdb6b101fda1456f53081dc`. One warmup plus three serial current-only checks with explicit Binaryen v131 produced no-trace samples `1,185.948`, `1,208.933`, and `1,204.920 ms` (median `1,204.920 ms`), traced samples `1,335.493`, `1,375.981`, and `1,328.839 ms` (median `1,335.493 ms`), pass-local samples `178.568`, `185.045`, and `173.738 ms` (median `178.568 ms`), and writeback samples `5.959`, `6.339`, and `6.839 ms` (median `6.339 ms`). Every traced/no-trace pair is byte-identical and retains the exact raw/canonical hashes above. The source-identical no-trace median therefore confirms the production `<1.25s` target while the five alternating pairs remain the causal before/after evidence. Final-check artifacts are `.tmp/perf-expression-sweep-20260903/final-current/`.

The superseding integrated run is `.tmp/pass-performance-sweep-20260903-final-bracketed/`, using final native SHA-256 `25dadf9167acd7c98dc86e26cae6a2ccd0135c58edd1efcfa7fb33ca5a177d0b`. One warmup plus three source-pinned, reference-bracketed samples report Starshine `1103.214 +/- 5.931 ms` command / `170.884 +/- 2.013 ms` pass-local / `4.973 ms` writeback versus Binaryen v131 `1061.139 +/- 28.983 ms` / `579.647 +/- 3.723 ms` (`1.040x` / `0.295x`). The strict `<1.25s` target is closed. Final `.tmp/pass-fuzz-precompute-propagate-perf-sweep-final-10000/` has 2,766 ordinary and 7,234 cleanup-normalized matches, zero residual mismatches or failures, and canonically smaller aggregate Starshine output (`949,866` versus `959,808` bytes) with no larger cases.

## Current maintenance rule

- Treat this folder as the canonical home for maintained `precompute-propagate` implementation and parity evidence.
- Keep it marked active while the public descriptor, registry, dispatcher, dedicated profile, and scheduler wiring remain present.
- Keep the relationship to plain `precompute` explicit:
  - shared implementation core
  - different public pass name
  - different scheduler usage
  - different reachable fixed points because of the extra propagation phase
- Treat the retained 2026-04-24 follow-up research [`binaryen-strategy.md` (absorbed)](binaryen-strategy.md) and direct tagged URLs as the source provenance anchor, and its retained research mirror [`binaryen-strategy.md` (absorbed)](binaryen-strategy.md) as the current-main freshness anchor.
- Keep the exact local-worklist contract explicit too:
  - not generic SCCP
  - not an unbounded fixed-point loop
  - not a bypass around emitability or GC-identity rules
- Keep the exact Starshine status explicit too:
  - active public descriptor and registry entry today
  - one solve plus one evaluator rerun, not generic unbounded SCCP
  - both aggressive top-level PC slots use the propagating member
  - DAE/inlining nested prefixes reuse the public pass
  - the closed v131 string/Flow/heap-identity/emitability/refinalization contract and conservative EH/stack-switching boundaries remain visible

## 2026-08-09 production O4z hardening

Exact `as-test` WIPC execution found validating, exit-zero wrong-code that process-level smoke missed. Focused raw guards now preserve: call-result locals read after intervening ordinary memory stores; stack-carried locals overwritten before later calls; and global-backed `i32`/`i64` arithmetic locals read more than once before their next write. The latter family had been storing the unadjusted parser value while moving subtraction into only the first use. Red-first coverage lives in `src/passes/precompute_propagate_test.mbt`; the focused suite is `35/35`. Both top-level propagation slots and nested DAE/inlining uses inherit these guards. Current O4z `json-as` execution is green for all `105` mode/module combinations, but the guards remain conservative ownership boundaries rather than new direct parity claims.

## 2026-08-10 self-opt ownership hardening

Self-optimized spec bisection added three more red-first ownership boundaries. Propagation must not move a same-local release ahead of a load, move a `local.set` ahead of the call result it captures, or remove an alias tee and release that alias before an indexed load. The focused reasons are `load-before-release-precompute-propagate-noop`, `call-result-local-reload-precompute-propagate-noop`, and `indexed-load-alias-release-precompute-propagate-noop`; older structured, call-tee, and bulk-memory reasons retain precedence. Isolated production functions were defined `8082`, `10819`, and `10964`. The focused suite is now `38/38`; direct self-opt full spec and all `105` exact `json-as` report-protocol executions are green.

## 2026-08-12 implicit function-label HOT repair

Broad optimizing inlining exposed a generic HOT-analysis abort before the propagation pass ran: valid root branches to the implicit function label lift as `HOT_IMPLICIT_FUNCTION_LABEL` (`-2`), but HOT control verification treated that sentinel as an invalid ordinary label and CFG construction could not resolve it. Verification now accepts the sentinel with branch arity derived from the function body result type, and CFG construction routes it to the synthetic function exit. Focused tests cover void and value-returning root branches, invalid payload arity, direct `precompute-propagate`, and the formerly aborting 285-definition inlining path. A dedicated `precompute-propagate-local-facts` smoke compared `1000/1000` cases with `1000` cleanup-normalized matches and zero mismatches, validation failures, property failures, generator failures, or command failures.

## 2026-08-12 structured operand-block local-state repair

A final SGO-owned `precompute-propagate` wave exposed a validating wrong-code bug in local SSA. A straight-line `block (result i64)` used as an `i64.add` operand wrote `100` to a local and yielded `7`; the following sibling `local.get` should therefore make the result `107`, but the old SSA/use-def traversal treated the operand block as a separate control region and propagated the stale local value, reducing the function to `7`. `ssa_simple_value_block_operand_allowed(...)` now admits only live, parameter-free, branch-free single-result operand blocks, and both use-def scanning and SSA renaming inline-visit their bodies in execution order. Parameterized and nested-control blocks remain fail-closed.

The focused `precompute-propagate` regression now requires the folded `I64(107)` result. SSA local tests are `23/23`, use-def tests `5/5`, propagation tests `43/43`, and SGO tests `332/332`. The dedicated `precompute-propagate-local-facts` lane at `.tmp/pass-fuzz-precompute-propagate-valueblock-fix-dedicated-10000-final-20260812` compared `10000/10000`, all through the reviewed `drop-consts`, `local-cleanup-debris`, and `unreachable-control-debris` normalizers, with zero mismatches or failures. Native SHA-256 `1007a0ac0e944ee8406b9886c3bc54bfbff6ff54120887ba936ac6f34109debc` restores exact `json-as` runtime behavior in all naive/SIMD/SWAR modes: optimize/external validation and exact no-cache WIPC are both `105/105`, aggregate output is `20,278,432` bytes, and the verified Binaryen-v131 gap is `4,633,308` bytes / `29.615%`. The repaired suffix is byte-size-neutral relative to the pre-fix candidate while changing the reduced semantic result from `7` back to `107`.

## Sources

- [`../../../raw/research/1574-2026-07-18-precompute-binaryen-v131-parity-reopen.md`](../../../raw/research/1574-2026-07-18-precompute-binaryen-v131-parity-reopen.md)
- [`binaryen-strategy.md` (absorbed)](binaryen-strategy.md)
- [`binaryen-strategy.md` (absorbed)](binaryen-strategy.md)
- [`binaryen-strategy.md` (absorbed)](binaryen-strategy.md)
- [`binaryen-strategy.md` (absorbed)](binaryen-strategy.md)
- [`binaryen-strategy.md` (absorbed)](binaryen-strategy.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../precompute/index.md`](../precompute/index.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>
