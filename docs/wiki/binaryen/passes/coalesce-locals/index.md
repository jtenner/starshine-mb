---
kind: entity
status: strong
starshine_status: active
last_reviewed: 2026-08-14
sources:
  - ../../../raw/research/1651-2026-07-19-daeo-block-fallthrough-validation-and-local-cleanup.md
  - ../../../raw/research/1650-2026-07-18-daeo-broad-boundary-and-uniform-constant-parity.md
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

- A 2026-08-14 loop-coalescing slice adds a CFG-backed path for defaultable functions within the existing 512-local safety boundary. It lifts the function to HOT IR, uses real basic-block live-in/live-out sets, reconstructs local actions in evaluation order, and greedily colors exact-typed locals from a conservative interference matrix. All simultaneously live entry values interfere; every executing write, including an ineffective one, interferes with currently live locals so dead writes cannot become clobbers after coloring. The implementation deliberately omits Binaryen's equal-value overlap relaxation. Raw/HOT local-action counts must agree or the path fails closed, and changed functions retain the existing validation/rollback protocol. The public `coalesce-locals-cfg` spelling owns an explicit post-`strip-debug` O4z convergence suffix, leaving the earlier Binaryen-v131-compatible `coalesce-locals` slots unchanged. A late `simplify-locals-nostructure` wave now precedes CFG coalescing, followed by `reorder-locals -> vacuum`. On BLAKE3 SIMD, dominant function 8 falls from 339 body locals to 52 and validated O4z falls from 44,017 to 43,016 bytes (`-1,001`); json-as `bool/naive` reaches 114,498 bytes (`-175`) and BLAKE3 SWAR reaches 22,252 bytes (`-154`). Verified Binaryen v131 remains smaller at 39,484 bytes, leaving 3,532 bytes / 8.9%. Regular GenValid is exact at `10000/10000`; the dedicated aggregate reproduces the established `8125` exact matches plus `1875` three-byte Starshine cleanup wins (`-5625` aggregate), with zero validation/property/generator/command failures.
- A 2026-08-13 mutation-accounting repair removed structural `Func` equality from the module-pass commit signal. Float NaNs are not reflexively equal, so a no-op function containing `f32.const nan` could appear changed, trigger a module rebuild, and lose local names despite no coalescing mutation. Coalescing now returns immediately when no rewrite reports `changed`, validation returns explicit committed code indices after per-function rollback, and module/name rebuilding occurs only when at least one candidate actually commits. The same explicit commit signal is used by touched-function coalescing in the hot pipeline. Rebuilt native SHA-256 `659a002fec66e17d76cae02a24bb854a77ae844a970acef767527daf5ca209fe` refreshed the `coalesce-locals-all` dedicated lane at exact `10000/10000`, with zero mismatches or failures.
- A 2026-08-11 O4z size-recovery slice replaced the optimization-level dispatcher that selected only `>50000`-local definitions with bounded function-local admission: ordinary modules below `2000` definitions may coalesce defaultable functions with at most `512` body locals, while production-scale artifacts retain only the prior oversized fast path. Dense-tee structured functions in that bounded lane now use conservative lexical interval coloring instead of the general path-sensitive approximation: only nonoverlapping locals whose first write dominates the remaining sequence may reuse a slot, branch-skipped implicit-default reads remain distinct, and every original tee is retained. Changed candidates are batch-validated and individually rolled back; structured rewrites deep-copy nested instruction arrays so the original liveness reference is not mutated, and an ineffective `local.tee` remains when its original local is read later in the same sequence. Experimental admission above `512` locals is still fail-closed: a `1488`-local switch body collapsed to four slots and validated, but exact WIPC failed in `arbitrary`, `containers-runtime`, `json-runtime`, and `typedarray`. Native SHA-256 `9ea22fb8c00ca903b1d58ee8e100169c95a7a090730b84dde7f0c1039158859f` optimizes and externally validates `105/105` `json-as` modules, and exact no-cache WIPC execution passes all `105/105`, `1,284` suites, and `10,656` tests. Aggregate O4z output falls from `21,392,772` to `21,140,906` bytes (`-251,866`), but remains `5,495,782` bytes / `35.13%` larger than verified Binaryen v131, so `[SIZE]001` remains open. The refreshed `coalesce-locals-all` 10k lane has `8125` exact normalized matches plus `1875` measured three-byte Starshine cleanup wins (`-5625` aggregate), all byte-identical after common verified-v131 `-Oz --strip-debug --all-features`; validation, property, generator, and command failures are zero. The full debug-artifact native/self-optimized-Wasm comparison stays byte-identical at `5,013,853` bytes.
- A 2026-07-30 post-closeout correctness review found two path-sensitivity gaps in the conservative legacy-EH and loop fallback paths. Legacy copy aliases now require a definite-assignment proof from the unique copy to every destination read across `if` and legacy-`try` joins; catch entry deliberately inherits only pre-`try` facts, so a protected-body throw, a bypassing arm, or a sibling catch cannot observe an aliased source value. Loop copy-through now rejects any earlier backedge that can skip the final copy and treats every represented branch/control-transfer family, including GC `br_on_*`, as a barrier. Focused regressions cover false-arm bypass, reads before assignment, protected-body throws, sibling catches, skipped tail copies, and all represented GC branch families. Rebuilt native SHA-256 `84bcf115d3ce400923aa7b239c94d20f278eb1bd6455bb031c87b284f12006fd` preserves exact Binaryen-v131 parity in fresh regular `100000/100000` and eleven-leaf dedicated `10000/10000` lanes; focused tests pass `62/62`, and a Node runtime fixture returns the expected implicit-default, copied, and loop-exit values.
- A 2026-07-21 Binaryen-v131 random-all audit repaired deterministic copy orientation. When an exact-type copy destination remains live across a later source overwrite, or a concrete-reference copy crosses an exact-type boundary and therefore cannot coalesce, the destination now wins the earlier body slot on otherwise equal colorings. `cl_color_with_order` still requires exact `ValType` equality, so this tie-break never merges a base reference local with its subtype. Reduced tests cover both the retained scalar copy and the concrete subtype-boundary near miss; all five discovery cases (`000027`, `000034`, `000049`, `000054`, `000075`) replay exactly with rebuilt native SHA-256 `f5d84bb880d03780d21efdc939915bff94f6ae8e5e67d2002f9c1e0ebf2807e9` against official Binaryen `version_131`.
- The 2026-07-30 closeout repairs the remaining local-branch dead-tail hazard, `_memcpy` loop-body wrappers, loop-backedge copy preference, same-source inter-block fanout coloring, and linear-copy-chain performance path. Explicit-v131 evidence is complete: regular `100000/100000` exact, expanded eleven-leaf dedicated `10000/10000` exact with idempotence, cleanup-normalized wasm-smith green across all `9956` comparable cases, and random-all `8750` exact plus `1250` inspected cleanup-shape differences that all converge byte-for-byte under common `-Oz --strip-debug`. The official v131 lit input is `1972` bytes Starshine versus `1994` Binaryen; its seven differing function-body sizes are all Starshine wins totaling `-22` bytes, and remaining text drift is equal-size numbering. The retained 1000-function copy-chain workload is byte-identical and now measures `1.481ms` Starshine versus `8.77995ms` Binaryen. `[COALESCE-LOCALS]001` is closed.

- The 2026-07-19 DAEO follow-up rejected generic loop-aware dense coloring. Early candidates passed Starshine validation but failed external definite initialization (`uninitialized local: 2`); a nondefaultable-local barrier made the standalone pass valid and `42,505` bytes smaller, but integrated DAEO became `+432` raw / `+806` canonical larger than the accepted artifact, increased canonical gross-positive bodies by `916` bytes, and added about `794.501s` pass-local time. The widening was reverted. Future loop coloring needs exact initialization state, per-family profitability, and bounded scheduling rather than a module-wide generic replay.
- The 2026-07-18 DAEO Func-`41` audit exposed and reduced an exact structured terminal-dead-write family. For a void block ending in `unreachable`, `coalesce-locals` may flatten the block only when no `br`, `br_if`, `br_table`, or GC branch targets its label; the never-read local write becomes `drop`, and only the newly exposed terminal suffix is truncated. The focused 625-byte reducer now matches Binaryen v130 byte-for-byte. Non-`unreachable` terminal blocks and branch-targeted blocks remain unchanged. Fresh dedicated `coalesce-locals-all` and regular GenValid count-1000 smokes each normalize `1000/1000` with zero failures. See research note [`1650`](../../../raw/research/1650-2026-07-18-daeo-broad-boundary-and-uniform-constant-parity.md).
- Starshine's current direct-pass validation is green on focused tests, CLI coverage, full `moon test`, the refreshed 2026-07-04 regular GenValid direct parity lane after structured-scalar slot-order cleanup (`.tmp/pass-fuzz-coalesce-locals-genvalid-100000-structured-scalar-order-final-20260704`: `100000/100000` normalized), the dedicated `coalesce-locals-all` profile lane (`.tmp/pass-fuzz-coalesce-locals-profile-10000-structured-scalar-order-final-20260704`: `10000/10000` normalized, zero failures), the required `random-all-profiles` lane (`.tmp/pass-fuzz-coalesce-locals-random-all-profiles-10000-structured-scalar-order-final-20260704`: `10000/10000` normalized, zero failures), the explicit wasm-smith lane with the documented `unreachable-control-debris` normalizer (`9956/10000` compared, `9955` normalized, `1` compare-normalized, `0` mismatches), the preceding loop adjacent/unread-local lanes, the effective-copy weighting / copy-connected coloring lane, the prior structured-liveness lane, the path-disjoint branch-result lane, the source-write/destination-read guard lane, the destination-read guard lane, the earlier dense-guard lane, the older 2026-05-08 mixed-generator direct parity lane, earlier 10k `gen-valid` Binaryen compare, mixed-generator comparable cases, and compatible Binaryen 128 self-opt artifact compare on both rebuilt debug and optimized WASI artifacts.
- The exact `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` and `reorder-locals -> coalesce-locals -> reorder-locals` neighborhoods are now both regression-covered in `src/passes/coalesce_locals_test.mbt`.
- The debug-artifact `reorder-locals -> coalesce-locals -> reorder-locals` replay at `.tmp/self-opt-cl-reorder-sandwich-20260508` is green on normalized WAT and canonical-function equality.
- The pass header explicitly says the algorithm is **nonlinear in the number of locals**, so Binaryen schedules it late after earlier local-cleanup passes have already reduced the local set. Starshine bounds dense non-loop coloring at `4096` flattened locals, but now uses a linear all-unused declaration compactor above that boundary; other large non-loop functions still wait for sparse interference coloring.
- Exact local type equality is mandatory while coalescing. This pass does **not** use subtype compatibility.
- Two locals can overlap in liveness and still share a slot if Binaryen can prove they hold the same current value.
- The first 2026-07-04 direct refresh fixed a current GenValid parity gap where Starshine over-preserved structured/loop locals: structured body locals may reuse dead fixed param slots, and loop functions now coalesce syntactically unused locals, same-typed write-only/unread locals into dead scratch slots, and adjacent/non-adjacent single-use copy-through chains while keeping other read loop locals conservative. A later closeout-matrix slice added the pass-owned `coalesce-locals-all` GenValid aggregate over straight-line, structured, and loop copy-through leaves; that dedicated lane is green at the required 10k size.
- The second 2026-07-04 ordered O4z replay fixed another CL-owned subset: non-loop structured `local.tee` functions are no longer skipped wholesale, structured self-copy debris is cleaned after coalescing, bounded structured branch copy chains and derived branch-carrier consume-forwarding can forward into dead exact-typed slots, structured ineffective writes now use Binaryen-shaped `drop`/`nop` cleanup, consume-forwarding now rejects destination reads after a source write could clobber that destination slot, the coloring step restores interference for source-write/destination-read clobber hazards after copy/consume relaxation while ignoring ineffective dead writes for safe tail param reuse, path-disjoint branch-result slot reuse removes plain-liveness edges only when same-path source/destination clobber reads are absent, branch-aware structured effective-write marking keeps mutually exclusive arm writes from being dropped by flattened cleanup, effective-copy weighting plus copy-connected coloring order keeps live branch-carrier copy chains from being displaced by ineffective copy traffic, the loop fallback coalesces adjacent/non-adjacent single-use copy-through chains, immediate `nop; drop` debris after ineffective tee rewrites is cleaned, nested nonlocal block escapes no longer let dead tail writes kill live branch-carrier writes, structured branch liveness now treats `return`, `br`, `br_if`, and `br_table` as reaching their actual continuation/terminal live sets for rewrite cleanup, and structured-scalar coloring order gives branch-condition/tee scratch locals the Binaryen-shaped lower body slot before unrelated simple scratch locals. The checked startup-map prefix drift improved from `+317/+319` through `+19/+21` to a current Starshine raw/code-body size win (`-20` at `+ coalesce-locals`, `-18` at `+ local-cse` raw bytes). Exact normalized/canonical text equality is still not claimed; first diff remains `defined=3`, and function `18` remains a smaller local code-body loser (`+20`) inside an aggregate Starshine-smaller code section. The broad `random-all-profiles` closeout is now green at 10k after the sampled `heap2local-struct` and `ssa-nomerge-smoke` residuals were fixed.
- A later 2026-07-04 hardening slice bounded the dense non-loop interference/copy-weight matrices with an intentional `>4096` flattened-local skip, covered by a 4097-local boundary test. This is a documented performance/GC-churn guard, not a Binaryen output-parity claim for huge functions.
- A 2026-08-12 production suffix reruns the same bounded/defaultable/validated O4z policy after guarded plain optimizing-inlining, but only when the rewritten module has fewer than 1,000 defined functions. This second wave targets local slots exposed by fallback inlining without admitting the artifact-scale self-optimized CLI. A red-first 286-definition public-pipeline fixture retains two body locals without the wave and zero with it. Across the 105 `json-as` artifacts, the wave reduces `20,409,974 -> 20,354,587` bytes (`-55,387`), with 105 smaller, zero unchanged, zero larger; optimize/external validation and exact no-cache WIPC are both `105/105`.
- The same bounded policy is also the local-slot stage of SGO's transactional final suffix. It runs only after SGO changes the module and only below 1,000 defined functions, after `precompute-propagate`, safe `merge-blocks`, and `remove-unused-brs`; SGO final cleanup is rerun afterward. Validation and encoded-size comparison govern writeback, so equality, growth, encoding failure, or invalid output retains the already-cleaned module. The final coalescing regression also requires the `final-cleanup-suffix accepted=true` trace. With the repaired structured operand-block SSA model and the merge-blocks stack-carried-local guard, native SHA-256 `15804fd785eada79e95fcfc783cc026c5bab86f71fa80e24d1c176a923e7c86e` signs the complete suffix at `20,276,497` corpus bytes and exact WIPC `105/105`.
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
