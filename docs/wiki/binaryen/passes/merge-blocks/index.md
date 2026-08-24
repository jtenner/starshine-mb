---
kind: entity
status: supported
last_reviewed: 2026-08-12
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeBlocks.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-blocks.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-blocks-atomics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-blocks-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/ir/effects_test.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/pass_common_wbtest.mbt
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes_perf_long/merge_blocks_perf_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
supersedes:
---

# `merge-blocks`

## 2026-07-31 correctness and performance reclose

A post-closeout review found two direct-owner defects. Expression-child lifting could move a later trapping prefix before an earlier distinct trap, changing which trap is observed first. Multivalue root candidates also performed a full live-node/drop-child scan per block, producing `O(blocks × nodes)` behavior. Starshine now classifies exact integer division/remainder and non-saturating float-to-int conversions as trapping in shared HOT effects, routes lifting through a shared conservative effect-mask predicate that forbids trap/trap crossings, and lazily builds at most one drop-parent bitset for a function that actually reaches a zero-parameter multivalue root hazard.

The review is **reclosed** on native SHA-256 `11322ff39e52cef842f0fdf263fc3d35ec3b823ab84f0540ff5984f8a8806174` against official Binaryen v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`. Focused runtime proves the original/current Starshine outputs trap first on the out-of-bounds load while the pre-fix Starshine and Binaryen-v131 outputs trap first on division by zero; this is an intentional Starshine correctness win because WebAssembly evaluates the earlier call operand first. Full Moon passes `10174/10174`. The required matrix is regular `100000/100000` exact, dedicated `10000/10000` exact, wasm-smith `9956/9956` comparable exact with the established 44 Binaryen-only failures, and random-all `9827` exact plus the same 173 strictly smaller neighboring-profile Starshine outputs totaling `-1130` bytes. The valid native-release 4,000-block call-backed partial-drop benchmark spreads the load across four 1,000-result functions and reports exactly one scan per function (`6000` live nodes and `1000` drop-child slots each; `24000` / `4000` aggregate per run), aggregate pass-local median `42905us`, and pipeline median `73010us`. On the 13,118,096-byte debug artifact, five-run pass-local medians are `258.437ms` Starshine versus `670.026ms` Binaryen (`0.386x`, about `2.59x` Binaryen throughput); lazy construction improves the first eager-index draft by `13.4%` and is `0.7%` faster than pre-review HEAD. Scheduler and ordered-neighborhood placement remain unchanged.

## Role

`merge-blocks` is an active implemented **hot pass** in Starshine and a late structural cleanup pass in Binaryen.

Current upstream Binaryen has two complementary rewrite layers:

- merge eligible nested child blocks into parent block lists and loop tails; and
- extract a legal prefix from a block-valued expression child while leaving that block's tail as the child.

The generic non-control rule covers ordinary operands such as `i32.store`; dedicated `visitDrop(...)`, `visitIf(...)`, and `visitThrow(...)` routes cover their special surfaces. None is arbitrary flattening. Current Starshine has a narrower HOT analogue in addition to its region-root flattening.

## 2026-07-11 current-source correction

Older local prose correctly rejected named-block retargeting as the main story, but still taught the current owner as a few special `drop`, `if`, and `throw` helpers and described Starshine as root-only flattening. Both descriptions were incomplete.

The source-backed current contract is:

- Binaryen merges safe child blocks and loop tails;
- its generic expression visitor can move a legal **block prefix** before a non-control parent expression while retaining the final block item as that expression child;
- dedicated drop/if-condition/throw visitors coexist with that generic route; `i32.store` is a representative ordinary-child shape;
- unnamed/multi-item/result-tail shape and `EffectAnalyzer::orderedBefore(...)` constrain the move;
- Starshine has a guarded HOT counterpart with live-label, type, loop, branch-prefix, and effect gates.

The July 11, 2026 source review supersedes the prior *current-source interpretation*; its durable facts are retained here and grounded in Binaryen's current [`MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp), [`pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp), and [`merge-blocks.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast). Older retained research stays as historical provenance.

## 2026-07-25 Binaryen-v131 renewal

The explicit `version_131` owner and lit fixtures do not introduce a new `MergeBlocks.cpp` transform family beyond the already documented structural merge, dropped-block, condition/throw, and generic child-prefix routes. The v130-to-v131 release-impact audit did not classify `merge-blocks` as a direct owner-file reopen.

The relevant v131 shared-helper change is atomic ordering, especially acquire/release and sequentially consistent barriers in `EffectAnalyzer::orderedBefore(...)`. Binaryen's `merge-blocks-atomics.wast` proves the asymmetric rule: a shared read may move before a release store, but may not move from after to before an acquire load; sequentially consistent operations remain barriers in both directions.

Starshine still treats general represented atomic nodes conservatively because its boundary IR does not preserve every regular memory-atomic or `atomic.fence` order as an `AtomicOrder`. The closeout adds a narrow raw-stack bridge for the exact official v131 acquire/release call fixture, making that fixture byte-identical without broadening HOT effect motion. Reopen broader atomic extraction only when decode, IR, encode, and HOT effects preserve the required order generically.

## 2026-07-26 executable renewal

The historical post-repair audit was closed for the then-represented surface. Red-first work added the `merge-blocks-all` GenValid aggregate, removed safe branch-free untyped loop/block wrappers, broadened HOT effect reordering only for proved-disjoint categories, and added a narrow raw-boundary bridge for flat two-argument direct calls whose later operand contains a context-free `global.set` prefix. The raw bridge allows pure and disjoint `memory.grow` predecessors, but retains order across trapping loads, global dependencies, and local-dependent prefix values.

That matrix remains historical evidence. The broader July 31 renewal supersedes it with additional branch-value, lowered-reference, ordered-EH, and O4z-neighborhood coverage; see the closeout below and [`./fuzzing.md`](./fuzzing.md).

## Historical 2026-07-31 parity and ordered-neighborhood closeout

A complete v131 owner/fixture re-audit added the missing represented families: branch-free loop roots, dropped self-target branch payloads including nested wrappers, dropped literal multivalue results, stack-safe multi-parameter calls, the official acquire/release fixture, lowered scalar spill cleanup, bottom-reference result refinalization, and unused `catch_ref` / `catch_all_ref` payload removal.

The direct matrix is green against explicit `wasm-opt version 131 (version_131)`: regular GenValid is exact at `100000/100000`; `merge-blocks-all` is exact at `10000/10000`; wasm-smith matches all `9956` comparable cases with the established 44 Binaryen parser/tool failures; and random-all has `9827` exact matches plus `173` classified Starshine wins. Every random-all residual comes from neighboring `local-subtyping-*` or `remove-unused-brs-*` profiles, is `1..18` canonical bytes smaller, and totals `-1130` bytes. There are no ties, size losses, validation failures, Starshine command failures, or unclassified differences.

The post-`code-folding` O4z neighborhood is also closed. With levels `4/4` and final `strip-debug`, the block-exit fixture is `41` bytes versus Binaryen's `43`, while the EH fixture is byte-identical at `74` bytes. The retained slot-42 regression validates, the official atomic fixture is byte-identical at `93` bytes, and the official main/EH fixtures are smaller on Starshine by `6` and `28` bytes respectively.

## Beginner summary

**Binaryen:** merge safe structural blocks; when a block supplies a value to another expression, move only a safe prefix out and keep its tail in the operand slot.

**Starshine:** flatten guarded dead-label HOT roots and branch-free loop/block wrappers, clean dropped branch values, lift guarded expression-child prefixes while retaining their tails, and use narrow raw/lowered bridges for stack-form call, ordered-atomic, bottom-reference, and unused EH-payload shapes that HOT cannot preserve canonically by itself.

## Inputs, outputs, and correctness

| | Binaryen | Starshine |
| --- | --- | --- |
| Input | Function-local expression AST; child blocks, loops, and expression operands. | Decoded function bodies plus lifted `HotFunc` regions, ordered child slots, whole-function label use, and type context. |
| Output | Fewer structural wrappers; simpler eligible expression operands; refinalized AST. | Reordered exact flat-call prefixes, flattened guarded roots/wrappers, and lifted guarded prefixes; HOT lowering/writeback remains valid. |
| Core safety | Preserve branch/result behavior and left-to-right operand effects. | Preserve live labels, typed carriers, branch-free prefixes, loop boundaries, effects, and dead-before-`unreachable` values. |

Do not infer a rewrite merely because the output validates. In particular, moving a prefix past an earlier effectful operand changes WebAssembly execution order and is invalid.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) — current upstream structural merging plus generic expression-child prefix extraction.
- [`./wat-shapes.md`](./wat-shapes.md) — beginner-safe before/after shapes for block/loop, special drop/if/throw routes, generic store-shaped extraction, and effect-order negatives.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) — source owner/test map and exact Starshine locations.
- [`./starshine-strategy.md`](./starshine-strategy.md) — local rules, intentionally narrower boundaries, and historical validation evidence.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) — exact HOT helper, traversal, registry, dispatch, and test map.

## Current local status

- `merge-blocks` is registered, dispatched, and accepted by the CLI.
- Both public presets run it twice in the late cleanup cluster around `simplify-locals`, `remove-unused-brs`, and `remove-unused-names`.
- `src/passes/merge_blocks.mbt` implements region-root flattening, branch-free loop/block-wrapper removal, dropped self-target branch cleanup, expression-child prefix lifting, category-aware effect reordering, and the O4z-only redundant self-`br_if` wrapper cleanup.
- `src/passes/pass_manager.mbt` owns narrow raw/lowered bridges for flat calls, the official ordered-atomic shape, dropped multivalue literals, nested dropped branch payloads, scalar spill/local compaction, bottom-reference refinalization, and unused reference-catch payloads.
- `src/passes/merge_blocks_test.mbt`, `src/passes/pass_manager_wbtest.mbt`, and `src/passes/code_folding_test.mbt` cover the direct transform families, negative effect/type guards, official v131 fixtures, and post-`code-folding` block-exit/EH neighborhoods.
- `src/validate/gen_valid.mbt` and `src/validate/gen_valid_merge_blocks_tests.mbt` own the stable four-family `merge-blocks-all` aggregate.
- The refreshed review matrix is exact for regular, dedicated, and every comparable wasm-smith case; all 173 random-all residuals are the unchanged strictly smaller Starshine neighboring-profile representations totaling `-1130` bytes. Focused runtime and the retained native-release benchmark reclose the trap-order and drop-parent-index review.

## Validation guidance

For documentation work, cross-read the current raw capture, the upstream strategy, local strategy, and exact test map.

For behavior changes:

1. add a focused `merge_blocks_test.mbt` case first;
2. run relevant `src/passes` and `src/cmd` tests;
3. build a fresh native CLI; and
4. run pass-targeted Binaryen comparison with `_build/native/release/build/cmd/cmd.exe` and classify any residual difference from source and replay evidence.

The review reclose matrix uses native Starshine SHA-256 `11322ff39e52cef842f0fdf263fc3d35ec3b823ab84f0540ff5984f8a8806174` and explicit Binaryen-v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`. See [`./fuzzing.md`](./fuzzing.md) for commands, counts, and residual classification. Older matrices remain provenance only.

## 2026-08-09 production O4z guard

After the corresponding slot-38 `code-folding` repair, cumulative O4z replay exposed the same `14`-body-local parser at slot 39. `merge-blocks` preserved validation while changing a reused digit local from `loaded - 48` to the raw loaded value, affecting later reads. The structured load/local-write fail-closed boundary in `src/passes/pass_manager.mbt` and `src/passes/merge_blocks_test.mbt` now starts at `14` locals. Current cumulative prefixes 1–57, direct O4z production execution, all `105` `json-as` report-protocol runs, and the full Moon suite are green.

## 2026-08-12 SGO final-suffix placement and stack-carried-local repair

A bounded experiment inserted `merge-blocks` after SGO's final `precompute-propagate` stage. The initial candidate externally validated all `105/105` `json-as` outputs and reduced aggregate size by `2,061` bytes, but exact no-cache WIPC failed `custom.spec.wasm` in all three modes. Function isolation reduced the failure to one changed function and then to a direct pass fixture: a `local.get` remained stack-carried while the same local was overwritten before a later call, and HOT lowering reconstructed the call operands from the overwritten value. The validating output therefore changed observable arguments.

`run_hot_pipeline_raw_size_cleanup_skip(...)` now reuses the established recursive stack-carried-overwritten-local detector and fails closed with `stack-carried-overwritten-local-merge-blocks-noop`. A red-first direct regression requires unchanged output and the trace reason. The direct `merge-blocks-all` aggregate against explicit Binaryen v131 is renewed at `.tmp/pass-fuzz-merge-blocks-stack-carried-fix-dedicated-10000-v131-20260812`: `10000/10000` normalized, zero mismatches or failures, Binaryen cache `10000/0`.

With that narrow ownership guard, the SGO-owned placement is retained. Native SHA-256 `15804fd785eada79e95fcfc783cc026c5bab86f71fa80e24d1c176a923e7c86e` reduces the signed corpus from `20,278,432` to `20,276,497` bytes (`-1,935`): 75 artifacts shrink, 30 are unchanged, none grow, and optimize/external validation plus exact no-cache WIPC are both `105/105`. The direct pass remains behavior-closed on its generated v131 matrix, but the reduced stack-carried shape is intentionally fail-closed in Starshine until HOT stack/local reconstruction can model it directly.

## 2026-08-24 AssemblyScript dispatcher performance repair

The current WAGO correctness repair added a source-order dependency check for stack-carried local reads across sibling writes. The first implementation recursively visited a structured block through both its region body and its generic child edges. Deep AssemblyScript dispatchers therefore revisited the same nested subtree exponentially; the pinned `json-as` `naive/bool.spec.wasm` stopped in the second cumulative `merge-blocks` slot at absolute function 186, whose body is a roughly 60-level nested `br_table` dispatcher.

The collectors now return after traversing `block` and `loop` region bodies, and the sibling dependency query scans roots in reverse while retaining one minimum source-node id per local. This preserves the exact unsafe relation—an earlier sibling write crossing a source-older read in a later sibling—without rescanning every later root for every write. The focused 60-level dispatcher regression and all 76 MergeBlocks tests pass; the isolated function-186 replay completes immediately and validates.

A current-native targeted AssemblyScript matrix then ran `merge-blocks -> merge-locals -> optimize-instructions -> remove-unused-brs -> ssa-nomerge -> simplify-locals -> coalesce-locals` over all 105 pinned naive/SWAR/SIMD modules. Optimization and independent `wasm-tools validate --features all` are `105/105`, and the exact four-worker no-cache `as-test` report-protocol replay is `105/105` with zero failures or timeouts. Evidence is under `.tmp/json-as-smoke-20260824/`.

The apparent late `inlining-optimizing` stall was superseded by pass-boundary profiling. Inlining completed; the first real owner was the no-structure SimplifyLocals control-embedded-tee probe, which double-traversed structured region children. After that repair, `coalesce-locals-cfg` exposed independent quadratic copied-destination and impossible-pair scans. Those owners are documented in the SimplifyLocals and CoalesceLocals dossiers.

Current native SHA-256 `eeec65559f823541a313b139a621ecaefee96729fe062f07153337cf7fa8a8da` completes production O4z on all 105 pinned artifacts and independently validates `105/105`, with zero optimizer failures or timeouts. The size portfolio now excludes decodable but structurally invalid encoded candidates before size selection. Exact no-cache `as-test` remains a separate open semantic gate: `9/105` pass and `96/105` fail, with representative `naive/bool` trapping on an out-of-bounds memory access. Do not infer semantic signoff from the green structural matrix.

## Sources

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>; registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>; fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast>
- research note 0720
- research note 0514
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
