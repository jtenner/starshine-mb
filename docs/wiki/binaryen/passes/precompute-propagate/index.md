---
kind: entity
status: supported
last_reviewed: 2026-08-30
sources:
  - ../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md
  - ../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md
  - ../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md
  - ../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md
  - ../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md
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

## Current maintenance rule

- Treat this folder as the canonical home for maintained `precompute-propagate` implementation and parity evidence.
- Keep it marked active while the public descriptor, registry, dispatcher, dedicated profile, and scheduler wiring remain present.
- Keep the relationship to plain `precompute` explicit:
  - shared implementation core
  - different public pass name
  - different scheduler usage
  - different reachable fixed points because of the extra propagation phase
- Treat the retained 2026-04-24 follow-up research [`../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md`](../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md) and direct tagged URLs as the source provenance anchor, and its retained research mirror [`../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md`](../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md) as the current-main freshness anchor.
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
- [`../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md`](../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md)
- [`../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md`](../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md)
- [`../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md`](../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md`](../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md)
- [`../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md`](../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md)
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
