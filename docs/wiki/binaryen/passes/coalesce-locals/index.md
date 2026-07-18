---
kind: entity
status: strong
starshine_status: active
last_reviewed: 2026-07-18
sources:
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./interference-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../local-subtyping/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
  - ../simplify-locals/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `coalesce-locals`

## Role

- `coalesce-locals` is an upstream Binaryen late local-cleanup pass.
- It is now an active Starshine module pass implemented in [`../../../../../src/passes/coalesce_locals.mbt`](../../../../../src/passes/coalesce_locals.mbt) and wired through the registry, dispatcher, CLI, and pass-fuzz harness.
- Despite the broad CLI name, Binaryen `version_129` uses it for a narrower and more structured job: compute which locals can safely reuse the same storage slot, then renumber the function so those locals share indices and redundant copies disappear.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `coalesce-locals` **twice**:
  - first in the GC/local cleanup cluster after `local-subtyping`
  - then again after `local-cse`, `simplify-locals`, `vacuum`, and `reorder-locals`
- The saved generated-artifact `-O4z` audit records both real skipped top-level upstream slots:
  - top-level slot `30`
  - top-level slot `35`
- The saved Binaryen debug log also shows many later reruns of the same local-cleanup neighborhood, which matches the nested rerun story from `opt-utils.h`.
- The ordered-slot replay that used to live under slice `CL` is now closed: `src/passes/coalesce_locals_test.mbt` covers both exact neighborhoods, and research note 0550 records the current-head proof.
- The first `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` slot is now explicitly proven in-tree and remains the public `optimize` / `shrink` cluster.
- The second `reorder-locals -> coalesce-locals -> reorder-locals` slot is now replayable as a focused neighborhood, compares green on the checked-in debug artifact, and is now reflected in public `optimize` / `shrink` scheduling via the 2026-07-12 reorder-locals preset update.

## Beginner summary

A safe beginner mental model is:

- think of locals as storage slots,
- see which locals are never simultaneously live with **different** values,
- keep only one slot for those compatible locals,
- then delete the copies and dead stores that became pointless.

That is narrower than “merge any locals that look unused.”

## Current durable takeaways

- Starshine's current direct-pass validation is green on focused tests, CLI coverage, full `moon test`, the refreshed 2026-07-04 regular GenValid direct parity lane after structured-scalar slot-order cleanup (`.tmp/pass-fuzz-coalesce-locals-genvalid-100000-structured-scalar-order-final-20260704`: `100000/100000` normalized), the dedicated `coalesce-locals-all` profile lane (`.tmp/pass-fuzz-coalesce-locals-profile-10000-structured-scalar-order-final-20260704`: `10000/10000` normalized, zero failures), the required `random-all-profiles` lane (`.tmp/pass-fuzz-coalesce-locals-random-all-profiles-10000-structured-scalar-order-final-20260704`: `10000/10000` normalized, zero failures), the explicit wasm-smith lane with the documented `unreachable-control-debris` normalizer (`9956/10000` compared, `9955` normalized, `1` compare-normalized, `0` mismatches), the preceding loop adjacent/unread-local lanes, the effective-copy weighting / copy-connected coloring lane, the prior structured-liveness lane, the path-disjoint branch-result lane, the source-write/destination-read guard lane, the destination-read guard lane, the earlier dense-guard lane, the older 2026-05-08 mixed-generator direct parity lane, earlier 10k `gen-valid` Binaryen compare, mixed-generator comparable cases, and compatible Binaryen 128 self-opt artifact compare on both rebuilt debug and optimized WASI artifacts.
- The exact `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` and `reorder-locals -> coalesce-locals -> reorder-locals` neighborhoods are now both regression-covered in `src/passes/coalesce_locals_test.mbt`.
- The debug-artifact `reorder-locals -> coalesce-locals -> reorder-locals` replay at `.tmp/self-opt-cl-reorder-sandwich-20260508` is green on normalized WAT and canonical-function equality.
- The pass header explicitly says the algorithm is **nonlinear in the number of locals**, so Binaryen schedules it late after earlier local-cleanup passes have already reduced the local set. Starshine now bounds its dense non-loop coloring path at `4096` flattened locals and leaves larger non-loop functions unchanged until a sparse interference representation lands.
- Exact local type equality is mandatory while coalescing. This pass does **not** use subtype compatibility.
- Two locals can overlap in liveness and still share a slot if Binaryen can prove they hold the same current value.
- The first 2026-07-04 direct refresh fixed a current GenValid parity gap where Starshine over-preserved structured/loop locals: structured body locals may reuse dead fixed param slots, and loop functions now coalesce syntactically unused locals, same-typed write-only/unread locals into dead scratch slots, and adjacent/non-adjacent single-use copy-through chains while keeping other read loop locals conservative. A later closeout-matrix slice added the pass-owned `coalesce-locals-all` GenValid aggregate over straight-line, structured, and loop copy-through leaves; that dedicated lane is green at the required 10k size.
- The second 2026-07-04 ordered O4z replay fixed another CL-owned subset: non-loop structured `local.tee` functions are no longer skipped wholesale, structured self-copy debris is cleaned after coalescing, bounded structured branch copy chains and derived branch-carrier consume-forwarding can forward into dead exact-typed slots, structured ineffective writes now use Binaryen-shaped `drop`/`nop` cleanup, consume-forwarding now rejects destination reads after a source write could clobber that destination slot, the coloring step restores interference for source-write/destination-read clobber hazards after copy/consume relaxation while ignoring ineffective dead writes for safe tail param reuse, path-disjoint branch-result slot reuse removes plain-liveness edges only when same-path source/destination clobber reads are absent, branch-aware structured effective-write marking keeps mutually exclusive arm writes from being dropped by flattened cleanup, effective-copy weighting plus copy-connected coloring order keeps live branch-carrier copy chains from being displaced by ineffective copy traffic, the loop fallback coalesces adjacent/non-adjacent single-use copy-through chains, immediate `nop; drop` debris after ineffective tee rewrites is cleaned, nested nonlocal block escapes no longer let dead tail writes kill live branch-carrier writes, structured branch liveness now treats `return`, `br`, `br_if`, and `br_table` as reaching their actual continuation/terminal live sets for rewrite cleanup, and structured-scalar coloring order gives branch-condition/tee scratch locals the Binaryen-shaped lower body slot before unrelated simple scratch locals. The checked startup-map prefix drift improved from `+317/+319` through `+19/+21` to a current Starshine raw/code-body size win (`-20` at `+ coalesce-locals`, `-18` at `+ local-cse` raw bytes). Exact normalized/canonical text equality is still not claimed; first diff remains `defined=3`, and function `18` remains a smaller local code-body loser (`+20`) inside an aggregate Starshine-smaller code section. The broad `random-all-profiles` closeout is now green at 10k after the sampled `heap2local-struct` and `ssa-nomerge-smoke` residuals were fixed.
- A later 2026-07-04 hardening slice bounded the dense non-loop interference/copy-weight matrices with an intentional `>4096` flattened-local skip, covered by a 4097-local boundary test. This is a documented performance/GC-churn guard, not a Binaryen output-parity claim for huge functions.
- Implicit local zero-initialization and fixed param ordering are part of the correctness story.
- Loop backedge copies get extra priority because removing them can avoid branch-only copy work.
- Binaryen tries two greedy orders by default and has a separate `coalesce-locals-learning` variant, but the default optimize pipeline uses the normal greedy pass.
- Post-coloring cleanup is part of the contract: redundant copies are deleted, dead sets are removed, and some dead tee rewrites require `ReFinalize()`.
- A focused 2026-05-05 current-`main` recheck found no teaching-relevant drift on `CoalesceLocals.cpp`, `pass.cpp`, `opt-utils.h`, or `coalesce-locals.wast`; treat that as a narrow freshness bridge, not proof that every helper detail is byte-identical to `version_129`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: helper dependencies, liveness/value-number interference, greedy coloring, rewrite cleanup, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner-file and test-map page covering `CoalesceLocals.cpp`, helper headers, registration/scheduler files, the dedicated lit test, and the exact local Starshine status/prerequisite surfaces.
- [`./interference-and-ordering.md`](./interference-and-ordering.md)
  Dedicated guide to the easiest parts of the pass to misunderstand: why equal values can overlap without interfering, why zero-init matters, why greedy order matters, and how backedge weighting changes outcomes.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and active-pass map: registry/dispatcher/CLI wiring, backlog slice `CL`, honest scheduler/preset story, and the exact neighboring MoonBit declaration-rewrite and cleanup files the pass composes with.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness and validation matrix for the active direct pass: current registry/dispatcher/preset/backlog state, reusable Starshine local-index and cleanup substrates, focused tests, and parity signoff ladder.

## Current maintenance rule

- Treat this folder as the canonical home for future `coalesce-locals` research, direct-pass validation, and ordered-pipeline follow-up.
- Keep the Starshine pages aligned with the active implementation in `src/passes/coalesce_locals.mbt` and record any future divergence from Binaryen as explicit parity debt.
- The tagged `version_129` release/source/test URLs are retained directly in this page's Sources section; the focused 2026-05-05 recheck preserves the later current-`main` provenance.
- The retained 2026-05-05 research recheck is the narrow historical current-`main` freshness bridge; direct `version_129` and current-main source URLs below remain the durable upstream evidence.
- Broad `random-all-profiles` is closed for the current direct CL surface: the first full 10k run timed out, the first 1k diagnostic exposed `ssa-nomerge-smoke=125` and `heap2local-struct=38`, concrete-ref direct-`struct.get` packing plus preferred-first GC-ref ordering closed the sampled `heap2local-struct` subfamily, and later immediate tee/drop, nested block-escape, label-aware branch-liveness, tail-param-reuse, and structured-scalar slot-order fixes normalized the sampled `ssa-nomerge-smoke` family. Replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-structured-scalar-order-final-20260704` normalized the previous `125/125` failures, and the required `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-10000-structured-scalar-order-final-20260704` lane compared/normalized `10000/10000` with zero failures.
- New `coalesce-locals` findings should update the Binaryen strategy page, the implementation/test map, the interference/order page, the Starshine strategy page, and the port-readiness matrix together so the algorithm explanation, example catalog, source map, local status story, and future validation ladder stay aligned.

## Sources

- research note 0473
- research note 0352
- research note 0264
- research note 0118
- research note 1443
- research note 1442
- research note 0550
- research note 0518
- research note 0372
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CoalesceLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/coalesce-locals.wast>
