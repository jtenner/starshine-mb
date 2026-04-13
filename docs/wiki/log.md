# Wasm Knowledge Base Log

Append new entries; do not rewrite prior history except to fix obvious formatting mistakes or redact sensitive data.

## [2026-04-13] maintain | record RUB call-heavy mixed-if mesh hot skip

- Added `raw/research/0087-2026-04-13-remove-unused-brs-call-heavy-mixed-if-mesh-hot-skip.md` to capture the newly retired lifted call-heavy mixed-if mesh family, the canonical extracted-function calibration, and the latest interleaved self-opt plus fuzz evidence.
- Updated the living `remove-unused-brs` hub, parity, HOT strategy, bailout notes, and pattern catalog so the new `call-heavy-mixed-if-mesh-noop` hot skip and its retired artifact funcs are part of the durable wiki.
- Updated `docs/wiki/index.md` so the RUB catalog now describes the later call-heavy mixed-if mesh retirement alongside the earlier medium-branchy lifted slice.

## [2026-04-13] maintain | record RUB medium branchy hot skip

- Added `raw/research/0086-2026-04-13-remove-unused-brs-medium-branchy-hot-skip.md` to capture the newly retired medium branchy lifted family, the extracted canonical-function calibration, and the latest self-opt plus fuzz evidence.
- Updated the living `remove-unused-brs` hub, parity, HOT strategy, bailout notes, and pattern catalog so the new `medium-branchy-block-ladder-noop` hot skip and its retired artifact funcs are part of the durable wiki.
- Updated `docs/wiki/index.md` so the RUB catalog now describes the later medium branchy lifted retirement alongside the earlier large `br_table`, tagged-prefix, and typed-encoder slices.

## [2026-04-10] maintain | calibrate RUB drop-heavy raw local-set floor

- Added `raw/research/0085-2026-04-10-remove-unused-brs-drop-heavy-local-set-floor.md` to capture the first reduced-only miss, the traced `Func 145` raw counts, the verified false HOT-only guards, and the landed `local_set >= 200` floor.
- Updated the living `remove-unused-brs` hub, parity, pattern-catalog, visit-order, and HOT-strategy pages so the new `large-drop-heavy-branch-ladder-noop` retirement, its artifact-calibrated floor, and the latest hotspot order are part of the durable wiki.
- Updated `docs/wiki/index.md` so the RUB catalog now describes the later drop-heavy `Func 145` raw retirement alongside the earlier `Func 828` and `Func 1482` raw slices.

## [2026-04-10] maintain | record RUB `br_table` one-arm payload parity guard

- Added `raw/research/0084-2026-04-10-remove-unused-brs-brtable-one-arm-payload-parity.md` to capture the reduced `Func 3771` parity failure, the Binaryen-side negative boundary for direct one-arm payload branches inside `br_table` functions, the rejected `hot_lower` detour, and the piggyback runtime recovery.
- Updated the living `remove-unused-brs` hub, parity, branch-exit/payload, visit-order, pattern-catalog, and HOT-strategy pages so the new direct one-arm payload `br_table` guard and the "piggyback broad guards onto an existing scan" lesson are part of the durable wiki.
- Updated `docs/wiki/index.md` so the RUB catalog now describes the new `Func 3771` parity boundary and the scan-reuse maintenance rule alongside the earlier `br_table` slices.

## [2026-04-10] maintain | record RUB large typed `br_table` encoder raw skip

- Added `raw/research/0083-2026-04-10-remove-unused-brs-large-typed-brtable-encoder-raw-skip.md` to capture the retired `Func 1482` family, the reduced perf lock, and the decoded-shell detector lesson from the first reduced-only draft that missed the real artifact body.
- Updated the living `remove-unused-brs` hub, parity, pattern-catalog, carried-guards/result-blocks, visit-order, and HOT-strategy pages so the new `large-typed-br-table-encoder-ladder-noop` raw skip, its `leading_any_block_chain_depth(...)` cheap prefilter, and the remaining `Func 1382` hotspot are part of the durable wiki.
- Updated `docs/wiki/index.md` so the RUB catalog now describes the typed `br_table` encoder raw skip and the current single-hotspot follow-up state.

## [2026-04-10] maintain | record RUB large tagged result-prefix hot skip

- Added `raw/research/0082-2026-04-10-remove-unused-brs-large-tagged-result-prefix-hot-skip.md` to capture the retired `Func 356` family, the reduced perf lock, the first detector-overhead draft, and the landed fastguard follow-up.
- Updated the living `remove-unused-brs` hub, parity, visit-order, pattern-catalog, carried-guards/result-blocks, and HOT-strategy pages so the new `large-tagged-result-prefix-ladder-noop` lifted skip and the detector-cost lesson are part of the durable wiki.
- Updated `docs/wiki/index.md` so the RUB catalog now describes the lifted tagged result-prefix slice and the new `Func 1382` / `Func 1482` hotspot order.

## [2026-04-10] maintain | record RUB large value-`if` / branch raw skip

- Added `raw/research/0081-2026-04-10-remove-unused-brs-large-value-if-branch-raw-skip.md` to capture the retired `Func 828` family, the reduced perf lock, and the updated fuzz plus artifact evidence.
- Updated the living `remove-unused-brs` hub, parity, visit-order, pattern-catalog, and HOT-strategy pages so the new `large-value-if-branch-ladder-noop` raw skip and the updated hotspot order are part of the durable wiki.
- Updated `docs/wiki/index.md` so the RUB catalog now describes the later raw value-`if` / branch skip alongside the earlier raw large-dispatch and lifted large-`br_table` slices.

## [2026-04-10] maintain | record RUB large `br_table` hot skip

- Added `raw/research/0080-2026-04-10-remove-unused-brs-large-brtable-hot-skip.md` to capture the new lifted no-op family, the reduced perf lock, and the updated artifact plus fuzz evidence.
- Updated the living `remove-unused-brs` hub, parity, visit-order, pattern-catalog, and HOT-strategy pages so the new `large-br-table-return-ladder-noop` skip and the retired `Func 1058` / `Func 1150` pair are part of the durable wiki.
- Updated `docs/wiki/index.md` so the RUB catalog now describes the later lifted `br_table` / return hot skip alongside the earlier raw large-dispatch and tee-floor slices.

## [2026-04-10] maintain | record RUB mid-band unique tee-floor correction

- Added `raw/research/0079-2026-04-10-remove-unused-brs-mid-unique-tee-floor.md` to capture the sixteen-tee unique-loop/select classifier change, the corrected `Func 1171` versus `Func 1150` artifact mapping, and the latest parity plus trace evidence.
- Updated the living `remove-unused-brs` hub, parity, visit-order, pattern-catalog, and HOT-strategy pages so the wider unique skip boundary and the corrected hotspot attribution are part of the durable wiki instead of a transient trace note.
- Updated `docs/wiki/index.md` so the RUB catalog entries describe the tee-floor correction as part of the current bailout and parity story.

## [2026-04-10] maintain | record RUB large result `br_table` raw skip

- Added `raw/research/0077-2026-04-10-remove-unused-brs-large-result-br-table-noop-skip.md` and `raw/research/0078-2026-04-10-remove-unused-brs-false-prefix-guard-raw-skip.md` to capture the large-dispatch no-op family, the false-prefix fix, and the kept perf evidence.
- Updated the living `remove-unused-brs` hub, parity, pattern-catalog, carried-guards/result-blocks, visit-order, and HOT-strategy pages so the large-dispatch no-op skip, the raw false-prefix guard, and the next artifact hotspot order are part of the durable wiki.
- Updated `docs/wiki/index.md` so the RUB catalog now describes the carried-wrapper plus large-dispatch artifact status instead of the stale early `Func 50` summary.

## [2026-04-09] bootstrap | initialize wasm knowledge base

- Added `docs/README.md` as the canonical docs and wiki schema.
- Added `docs/wiki/index.md` and `docs/wiki/log.md` as the initial catalog and audit trail.
- Added `docs/wiki/raw/README.md` to define committed raw-source handling.
- Updated `AGENTS.md` so wiki and knowledge-base work starts from `docs/README.md`.

## [2026-04-09] schema | tighten AGENTS wiki contract

- Rewrote `AGENTS.md` to split general work rules from docs and wiki rules.
- Made the numbered docs vs. living wiki distinction explicit.
- Added clear requirements for keeping `docs/wiki/index.md` and `docs/wiki/log.md` current on wiki schema and maintenance changes.
- Mirrored the same operational summary in `docs/README.md`.

## [2026-04-09] ingest | crystallize recent numbered docs into wiki pages

- Added `heap2local-binaryen-parity.md` from `0075` as the living summary of the current Binaryen transform surface, in-tree coverage, and remaining refinalization gap.
- Added `reorder-locals-binaryen-parity.md` from `0073` as the living summary of the exact ordering rule, module-pass scope, and current signoff boundary.
- Added `reorder-locals-multivalue-call-scope.md` from `0074` as the current scope decision for multivalue-call writeback parity.
- Added `binaryen-invalid-tag-index-parser-gap.md` from `0072` as the standing oracle parser-gap rule for `remove-unused-names` compare failures.
- Updated `docs/wiki/index.md` so the new decision and comparison pages are discoverable from the wiki catalog.

## [2026-04-09] organize | namespace Binaryen pass pages

- Moved the new pass-focused wiki pages under `docs/wiki/binaryen/passes/<pass>/...` so future Binaryen pass notes have one stable home.
- Kept `heap2local` parity under `binaryen/passes/heap2local/parity.md`.
- Kept `reorder-locals` parity and multivalue-call scope notes together under `binaryen/passes/reorder-locals/`.
- Moved the `remove-unused-names` parser-gap note under `binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md`.
- Updated `docs/wiki/index.md` and intra-page links to point at the new namespace layout.

## [2026-04-09] ingest | crystallize four more recent pass docs

- Added `binaryen/passes/remove-unused-brs/parity.md` from `0070` as the living summary of Binaryen phase structure, current MoonBit coverage, and the remaining late-shape gap for `remove-unused-brs`.
- Added `binaryen/passes/remove-unused-brs/returned-ladder-hot-shapes.md` from `0071` as the standing HOT-shape note for returned-ladder families that do not look like their printed WAT form after lift.
- Added `binaryen/passes/pick-load-signs/parity.md` from `0069` as the living summary of the active rewrite surface, signoff state, and fast-skip behavior for `pick-load-signs`.
- Added `binaryen/passes/global-struct-inference/parity.md` from `0068` as the living summary of the current closed-world direct-global slice and its present scope limit.
- Updated `docs/wiki/index.md` so the new Binaryen pass pages are discoverable under concepts and comparisons.

## [2026-04-09] ingest | crystallize four more docs into Binaryen and IR2 wiki pages

- Added `binaryen/passes/duplicate-function-elimination/parity.md` from `0067` as the living summary of the module-wide merge contract, full `FuncIdx` rewrite surface, and the remaining direct artifact parity gap for `duplicate-function-elimination`.
- Added `binaryen/no-dwarf-default-optimize-path.md` from `0066` as the living summary of the real no-DWARF `-O` / `-Os` phase split, ordered pass path, and nested rerun rules for the MoonBit debug artifact.
- Added `ir2/execution-plan.md` from `0065` as the current IR2 handoff page covering the active registry surface, pipeline contract, and preferred next slice order.
- Added `ir2/test-matrix.md` from `0064` as the standing shared-helper and golden-fixture matrix for deterministic IR2 lift, analysis, lower, and pass-trace coverage.
- Updated `docs/wiki/index.md` so the new Binaryen and IR2 pages are discoverable under concepts and comparisons.

## [2026-04-09] ingest | crystallize four more IR2 handoff docs into wiki pages

- Added `ir2/registry-map.md` from `0063` as the living summary of the current registry categories, preset composition, and the now-partially-stale parts of the March batch map.
- Added `ir2/pass-porting-checklist.md` from `0062` as the standing helper and validation checklist for future IR2 pass ports.
- Added `ir2/local-ssa-policy.md` from `0061` as the current locals-only SSA policy page covering entry defs, overlay-only phis, rename policy, and predecessor-copy destruction.
- Added `ir2/cfg-contract.md` from `0060` as the normative CFG boundary and explicit-edge policy page for `HotFunc`.
- Updated `docs/wiki/index.md` so the new IR2 concept and decision pages are discoverable from the catalog.

## [2026-04-09] organize | reserve root docs for normative material

- Updated `AGENTS.md`, `docs/README.md`, and `docs/wiki/raw/README.md` so `docs/` is now the home for normative docs only, while numbered one-off investigations live under `docs/wiki/raw/research/`.
- Added `docs/wiki/raw/research/README.md` to define the absorbed-research archive rules.
- Moved the non-normative numbered docs out of root `docs/` into `docs/wiki/raw/research/`.
- Repointed `agent-todo.md`, `CHANGELOG.md`, and the Binaryen wiki pages so live references and archived sources still resolve after the move.
- Updated `docs/wiki/index.md` so the research archive rules are discoverable from the catalog.

## [2026-04-09] ingest | crystallize IR2 and validator tooling docs into wiki pages

- Added `ir2/architecture-rules.md` from `0059` as the living digest of the single-owned `HotFunc` contract, overlay model, and module-split rule.
- Added `tooling/fuzz-runner.md` from `0003` as the standing workflow page for keeping heavy randomized work in `src/fuzz` with reproducible suite, profile, and seed entrypoints.
- Added `tooling/tracing-playbook.md` from `0001` as the shared pass and validator trace contract for `key=value` logs, timing helpers, hotspot summaries, and indirect testing.
- Added `validate/trace-benchmark-baseline.md` from `0010` as the committed baseline page for validator trace corpora, phase totals, helper totals, and hotspot interpretation.
- Added `validate/fuzz-hardening.md` from `0058` as the current hardening plan for validator fuzz trust, generator breadth, diagnostic matching, and repro ergonomics.
- Updated `docs/wiki/index.md` so the new IR2, tooling, and validator pages are discoverable from the catalog.

## [2026-04-09] ingest | crystallize GC text, descriptor, and string docs into wiki pages

- Added `wast/gc-type-authoring.md` from `0018`, `0019`, `0020`, and `0026` as the standing higher-level WAST rule page for GC type defs, `rec` groups, descriptor metadata, and flat type indexing.
- Added `custom-descriptors/static-fixtures.md` from `0021` and `0032` as the harness-policy page for the native static `descriptors.wast` and `exact.wast` fixtures.
- Added `custom-descriptors/ref-get-desc-fixture-path.md` from `0022` through `0028` as the full-stack compatibility page for `ref.get_desc`, legacy GC aliases, exact `ref.null`, bottom-null operands, and the mixed-runtime fixture path.
- Added `custom-descriptors/exact-reference-equivalence.md` from `0029`, `0030`, and `0031` as the rule page for passive typed empty `elem` surface plus structural exact-reference matching for structs and functions.
- Added `strings/string-const-surface.md` from `0052` as the living page for the public `string.const` surface, binary string-literal section, constant-expression rule, and IR payload handling.
- Updated `docs/wiki/index.md` so the new WAST, custom-descriptor, and string pages are discoverable from the catalog.

## [2026-04-09] refresh | resync IR2 root contracts with current hot-IR code

- Updated `docs/0059-2026-03-24-ir2-architecture-rules.md` and `ir2/architecture-rules.md` so the architecture contract reflects the current split `src/ir` module map, the live post-dominance overlay, and `hot.mbt`'s current role as facade glue instead of an in-progress monolith.
- Updated `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` and `ir2/registry-map.md` so the canonical registry surface now matches code for active `precompute`, `heap2local`, `reorder-locals`, and the real preset expansion.
- Updated `docs/0065-2026-03-24-ir2-execution-plan.md` and `ir2/execution-plan.md` so the handoff plan matches the current active pass surface and the real `optimize` / `shrink` sequence.

## [2026-04-09] refresh | switch living Binaryen oracle references to version_129

- Updated the living Binaryen no-DWARF orientation page and active backlog to use Binaryen `version_129` as the upstream source oracle for new pass research.
- Confirmed from upstream `version_129` source that the open-world no-DWARF `-O` / `-Os` path for the MoonBit debug artifact still matches the archived `version_125` top-level shape used by the current wiki.
- Marked the saved `heap2local` and `reorder-locals` compare evidence as historical `version_125` command output until the local `wasm-opt` toolchain is upgraded.

## [2026-04-09] organize | scaffold pass-folder indexes and expand duplicate-function-elimination

- Added `docs/wiki/binaryen/passes/index.md` as the namespace catalog for active implemented pass folders.
- Added pass-folder landing pages for every currently implemented active pass so each pass now has a stable wiki home even where detailed subpages are still pending.
- Expanded `duplicate-function-elimination` into a multi-entry folder with `index.md`, `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and `type-compaction-and-metadata.md`.
- Refreshed `duplicate-function-elimination/parity.md` to distinguish direct explicit-pass behavior from the larger option-dependent iteration budget Binaryen uses inside `-O` / `-Os`.

## [2026-04-09] maintain | expand remove-unused-module-elements into a real pass folder

- Expanded `remove-unused-module-elements` from a stub landing page into a multi-entry folder with `index.md`, `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, `retention-and-index-rewrites.md`, and `parity.md`.
- Documented RUME's imported-parent retention rules, explicit module-index rewrite surface, and the current in-tree coverage for empty active data, no-op active elem segments, and imported survivor remaps.
- Updated the root wiki catalog and pass-folder catalog so the expanded RUME pages are discoverable.

## [2026-04-10] investigate | record the current ssa-nomerge artifact parity blocker

- Added `binaryen/passes/ssa-nomerge/parity.md` plus raw research note `0076-2026-04-10-ssa-nomerge-parity-investigation.md` for the current `ssa-nomerge` evidence.
- Recorded that the checked-in debug CLI artifact now validates as input, Binaryen `--ssa-nomerge` succeeds on it, but direct Starshine `--ssa-nomerge` still fails final module validation at `Func 523`.
- Recorded that the seeded random compare rerun stayed semantically clean and only hit a Binaryen `binaryen-rec-group-zero` parser-gap case, so direct artifact replay remains mandatory for `ssa-nomerge` signoff.
- Updated the root wiki catalog and the Binaryen pass-folder catalog so the new parity page is discoverable.

## [2026-04-10] refresh | record the safe-fail ssa-nomerge replay fix

- Updated `binaryen/passes/ssa-nomerge/parity.md` and raw research note `0076-2026-04-10-ssa-nomerge-parity-investigation.md` after the current source build stopped letting the `Func 523` invalid writeback survive to final module validation.
- Recorded the new source-mode artifact replay evidence: `Func 523` now fails closed as `writeback-validate:type mismatch`, `Func 3773` is also visible as `writeback-validate:stack underflow`, and final module validation completes.

## [2026-04-10] fix | close the current ssa-nomerge dead-param parity family

- Updated `binaryen/passes/ssa-nomerge/parity.md`, `binaryen/passes/ssa-nomerge/index.md`, and raw research note `0076-2026-04-10-ssa-nomerge-parity-investigation.md` after current source `ssa-nomerge` was brought back into output parity with Binaryen for the dead-param write family.
- Recorded the new signoff evidence at `/tmp/ssa-pass-fuzz-rebased-2026-04-10-rerun3`, `/tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff`, `/tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff-gen-valid`, `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2`, and `/tmp/ssa-nomerge-final.log`.
- Updated the root wiki catalog and Binaryen pass-folder catalog so the parity page now points at the fixed output-facing state and the remaining trace-level raw-lowering caveat instead of the retired final-validation blocker.

## [2026-04-10] refresh | reprove ssa-nomerge parity after the tuple merge

- Updated `binaryen/passes/ssa-nomerge/parity.md`, `binaryen/passes/ssa-nomerge/index.md`, and raw research note `0076-2026-04-10-ssa-nomerge-parity-investigation.md` after rerunning `ssa-nomerge` parity lanes on the merged tree.
- Recorded the new post-merge evidence at `/tmp/ssa-pass-fuzz-postcommit-mixed-seed51a`, `/tmp/ssa-pass-fuzz-postcommit-genvalid-seed51a`, `/tmp/starshine-self-optimize-compare-starshine-debug-wasi-2`, and `/tmp/ssa-nomerge-postcommit.log`.
- Narrowed the traced remaining gap from the earlier two writeback-validate families down to `Func 523` plus `228` `suspicious-escape-carrier` skips, and updated the root wiki catalogs to match.
- Updated `agent-todo.md` so the shared post-SSA blocker note no longer claims `ssa-nomerge` safety without the newer per-function writeback-validation evidence.

## [2026-04-10] expand | turn tuple-optimization into a full pass folder

- Added `binaryen/passes/tuple-optimization/index.md` as the canonical landing page for tuple-opt documentation.
- Added `tuple-optimization/wat-shapes.md`, `binaryen-strategy.md`, and `starshine-hot-ir-strategy.md` to split the old monolithic `0076` note into concrete transform families, upstream strategy, and current HOT-native implementation strategy.
- Added `tuple-optimization/scheduler-and-gates.md` to separate explicit-pass correctness from still-pending preset-slot parity.
- Added `tuple-optimization/reduced-repros-and-evidence.md` and `tuple-optimization/parity.md` to capture the current direct native-compare status, the still-red exact-shape families, and the standing artifact/runtime gap.
- Updated `docs/wiki/index.md` and `docs/wiki/binaryen/passes/index.md` so the new tuple-opt folder is discoverable from the main wiki catalog and pass namespace catalog.

## [2026-04-10] maintain | narrow chained host-copy tail-live0 parity drift

- Updated `tuple-optimization/parity.md` and `tuple-optimization/reduced-repros-and-evidence.md` with the current anchored host-copy split: the middle group wants the specialized intermediate host-result carrier path again, while the terminal group is still the remaining exact-shape blocker.

## [2026-04-10] maintain | preserve terminal host tees through tuple cleanup and lowering

- Updated the tuple-opt backlog and wiki after confirming that one remaining `tail-live0` parity bug was not the rewrite root itself, but Starshine collapsing preserved `drop(local.tee ...)` host tails into `local.set`.
- Recorded the new guarded behavior in `src/passes/tuple_optimization.mbt` and `src/ir/hot_lower.mbt`: preserved host tees that still feed later non-drop reads now survive tuple cleanup and lowerer canonicalization.
- Narrowed the remaining `tail-live0` gap again: the final `local.tee 0` plus tail drops are now preserved, and the remaining deterministic diff is the anchored host-copy staging order and temp layout immediately before that tail.
- Updated `agent-todo.md` so the active tuple backlog now records the current deterministic tail-live0 blocker in that more specific form instead of treating the whole family as one undifferentiated drift.

## [2026-04-10] maintain | refresh tuple-opt parity and reduced performance evidence

## [2026-04-10] maintain | collapse tuple seed screening into one precise scan and cut full-artifact pass time

- Reworked `src/passes/tuple_optimization.mbt` so tuple-opt no longer runs a weak whole-function no-op screen in `run`, repeats that same weak screen in `analyze`, and then pays a second seed walk anyway. The pass now builds or reuses `use-def`, performs one precise seed-group scan, bails out immediately when that scan is empty, and reuses the collected groups for the rest of analysis.
- Tightened the seed, result-block, and scalar-forward collectors themselves to avoid the old per-candidate GC churn: they now use stamped local marks for duplicate-lane detection and write lane order directly instead of building temporary reverse arrays and calling `tuple_optimization_seen_local(...)` linearly on every lane.
- Added focused white-box invariants in `src/passes/tuple_optimization_wbtest.mbt` proving that duplicate lane locals in both seed groups and result-block copy groups are still rejected under the new stamped-mark collectors.
- Rechecked correctness on the kept tree: `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` is `44 / 44`, `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*tuple-optimization*'` is `15 / 15`, `moon test --package jtenner/starshine/cmd --file cmd_test.mbt --filter '*tuple-optimization*'` is `7 / 7`, `/tmp/pass-fuzz-tuple-cleaned-genvalid-1000-2026-04-10` is `1000 / 1000`, and `/tmp/pass-fuzz-tuple-cleaned-smith-200-2026-04-10` is `199 / 200` with the same Binaryen-only `binaryen-rec-group-zero` command failure.
- The full-artifact runtime moved materially, not just the reduced repros. `/tmp/self-opt-tuple-full-candidatefilter-2026-04-10` and `/tmp/self-opt-tuple-full-candidatefilter-rerun-2026-04-10` are both canonically green (`Canonical function compare equal: yes`, `Normalized WAT equal: yes`) while Starshine tuple-pass time dropped into a `325.221-361.452 ms` band from the earlier `~966 ms` band.
- Fresh pass-trace evidence explains why the improvement is real: tuple-opt still visits `4462` functions but now changes only `18`, and total pass time on the cleaned kept tree is `277790 us` instead of `960971 us`, so the old unchanged-function hot quartet is gone and the remaining runtime debt is concentrated in `Func 1673` plus a smaller tail of candidate-heavy functions.
- The current kept-tree split is now sharper too: `Func 1673` (`_M0FP37jtenner9starshine4wast17wt__lower__module`) is still the main tuple-pass outlier at `101831 us`, followed by a much smaller tail (`148`, `2389`, `1905`, `3660`, `147`), while the biggest `analysis:use-def` costs are still in different functions (`3612`, `1553`, `1525`). That means the next tuple-runtime slice should target `Func 1673`-style candidate/query work, while any wall-time reduction beyond the reported tuple pass timer will need separate use-def or pipeline work.

## [2026-04-10] maintain | rerun full tuple self-opt compare and reframe the remaining work as unchanged-function runtime debt

- Reran the full tuple-only debug-artifact compare through the upgraded canonical fallback at `/tmp/self-opt-tuple-full-canonical-2026-04-10` and `/tmp/self-opt-tuple-full-smalllocals-2026-04-10`; raw normalized WAT text is still different, but canonical per-function comparison is green on both runs, so full tuple parity is now freshly re-proven on current head instead of inferred only from the saved `/tmp/self-opt-tuple-current` pair.
- Landed a low-risk tuple analysis cleanup in `src/passes/tuple_optimization.mbt`: alias resolution now reuses precomputed single-write locals plus stamped visit marks, and the seed / copy-group collectors no longer allocate `local_count`-sized duplicate-check arrays for every multi-value candidate lane walk.
- Rechecked parity on the kept pass body: `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*tuple-optimization*'` is still `15 / 15`, `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` is still `42 / 42`, `/tmp/pass-fuzz-tuple-genvalid-smalllocals-1000-2026-04-10` is `1000 / 1000`, and `/tmp/pass-fuzz-tuple-smith-smalllocals-2026-04-10` is `199 / 200` with the same Binaryen-only `binaryen-rec-group-zero` command failure.
- Added one more full-artifact performance diagnosis pass trace: tuple-opt currently visits `4462` functions and changes only `27`, with the runtime dominated by unchanged giant functions (`Func 3612`, `1553`, `1525`, `1673`) while the old parity focal point `Func 3660` is only a small fraction of the total. The pass therefore remains correctness-green, but this slice is effectively performance-neutral on the full artifact and the next real optimization target is unchanged-function candidate analysis rather than more local scratch cleanup.

- Updated the tuple-opt parity and reduced-repro pages after rerunning current-head coverage: direct native tuple compare is now `14 / 14`, black-box tuple cmd coverage is `7 / 7`, and the remaining in-tree red surface is down to six white-box exact-shape tests at `35 / 41`.
- Recorded fresh isolated fuzz evidence at `/tmp/pass-fuzz-tuple-gen-valid-2026-04-10` (`1000 / 1000` matches) and `/tmp/pass-fuzz-tuple-smith-2026-04-10` (`199 / 199` comparable matches plus one Binaryen `binaryen-rec-group-zero` parser failure).
- Added the fresh reduced self-opt timing baseline `/tmp/self-opt-tuple-tail-live0-2026-04-10`, which confirms that the reduced `tail-live0` parity lane is green while runtime and pass time are still materially slower than Binaryen.
- Rebased the tuple backlog from “red reduced native parity family” to the current open work: pre-lower `TupleMake` carrier debt in raw `tail-live0` HOT, six white-box exact-shape expectations, the full artifact gap at `func $3639`, and the remaining tuple-opt performance budget.

## [2026-04-10] maintain | retire the tuple `func $3639` blocker as a compare-surface bug

- Added one more reduced tuple regression family: a two-lane exact-copy chain past an unrelated multivalue block is now checked in both `src/passes/tuple_optimization_wbtest.mbt` and `src/cmd/cmd_native_wbtest.mbt`.
- That reduced probe was the key diagnostic: raw `wasm-opt -S --strip-debug` WAT still differs on the probe, but the white-box pass surface stays scalar and direct native Binaryen parity stays green, proving raw normalized WAT is too strict to serve as the only tuple oracle.
- Upgraded `scripts/lib/self-optimize-compare-task.ts` so self-opt compare now falls back to canonical per-function pretty output through `--print-func` when raw normalized WAT differs, ports the native tuple helper’s local alpha-normalization and scalar-ladder reordering into TypeScript, and records real mismatches as `func-definedN-absM.*`.
- Resolved the old saved `/tmp/self-opt-tuple-current` numbering confusion: the raw hunk at printed WAT `func $3639` is defined-function ordinal `3639`, which maps to absolute `Func[3660]` after the module’s `21` imported funcs; the canonical CLI function printer matches on that saved pair, so the old `func $3639` blocker is no longer treated as a proven tuple rewrite bug.

## [2026-04-10] maintain | retire stale tuple-opt white-box exact-shape reds

- Updated `src/passes/tuple_optimization_wbtest.mbt` so the six old white-box red cases now check stable scalarization and copyback invariants instead of temp-local numbering or transient carrier scaffolding; the full tuple white-box file is now `41 / 41`.
- Rechecked the surrounding tuple surface on the kept pass implementation: native direct Binaryen compare is still `14 / 14`, black-box tuple cmd coverage is still `7 / 7`, `/tmp/pass-fuzz-tuple-gen-valid-wbrefresh-2026-04-10` is `1000 / 1000`, and `/tmp/pass-fuzz-tuple-smith-wbrefresh-2026-04-10` is `199 / 200` with the same lone Binaryen `binaryen-rec-group-zero` parser failure at case `29`.
- Updated the tuple parity and reduced-repro wiki pages plus `agent-todo.md` so the docs now treat the white-box red surface as resolved expectation debt, not as an active parity blocker.
- Tried and rejected one more cleanup-path perf slice locally: the cleanup-query experiment did not produce a stable win on the reduced `tail-live0` repro, so the kept pass code stays on the earlier `0.511 ms` checkpointed implementation.

## [2026-04-10] maintain | prove stamped visit-buffer reuse is parity-safe but not yet a real tuple-opt speedup

- Updated the tuple-opt parity and reduced-repro pages after landing stamped visit-buffer reuse in forwarded-use analysis inside `src/passes/tuple_optimization.mbt`.
- Recorded fresh post-refactor compare-pass evidence at `/tmp/pass-fuzz-tuple-gen-valid-visitmarks-2026-04-10` (`1000 / 1000` matches) and `/tmp/pass-fuzz-tuple-smith-visitmarks-2026-04-10` (`199 / 199` comparable matches plus the same Binaryen-only `binaryen-rec-group-zero` parser failure at case `29`).
- Added the fresh reduced self-opt timing rerun `/tmp/self-opt-tuple-tail-live0-visitmarks-2026-04-10`, which shows the refactor kept parity but left runtime and pass time effectively unchanged on the reduced `tail-live0` repro.
- Updated the active tuple backlog so the next performance slice is explicitly about caching direct-use and forwarded-query answers, not just reusing traversal scratch arrays.

## [2026-04-10] maintain | keep tuple-opt parity green while adding cached forwarded-use answers

- Updated the tuple-opt parity and reduced-repro pages after landing per-local forwarded-use memoization and the no-group query-summary fast path in `src/passes/tuple_optimization.mbt`.
- Recorded fresh compare-pass evidence at `/tmp/pass-fuzz-tuple-gen-valid-forwardcache-2026-04-10`, `/tmp/pass-fuzz-tuple-smith-forwardcache-2026-04-10`, `/tmp/pass-fuzz-tuple-gen-valid-emptysummary-2026-04-10`, and `/tmp/pass-fuzz-tuple-smith-emptysummary-2026-04-10`; all comparable cases still match Binaryen, and the only continuing fuzz command failure is the same Binaryen `binaryen-rec-group-zero` parser limit at smith case `29`.
- Added the reduced timing ladder entries `/tmp/self-opt-tuple-tail-live0-querysummary-2026-04-10`, `/tmp/self-opt-tuple-tail-live0-forwardcache-2026-04-10`, and `/tmp/self-opt-tuple-tail-live0-emptysummary-2026-04-10` so the wiki captures the actual performance progression instead of only the best-looking point.
- Updated the tuple backlog to reflect the new conclusion: cached forwarded-use answers plus skipping summaries on no-group functions recovered the reduced-case regression and brought tuple-pass time down to `0.511 ms`, but candidate-heavy query-summary cost, six white-box exact-shape failures, and the full artifact gap at `func $3639` are still open.

## [2026-04-10] maintain | separate tuple-opt parity from launcher churn on long fuzz lanes

- Updated the tuple-opt parity and reduced-repro pages after rerunning the current tree through the direct native cmd binary and pushing the `gen-valid` lane back out to `10000` comparisons.
- Recorded fresh current-tree direct-binary fuzz evidence at `/tmp/pass-fuzz-tuple-gen-valid-bincurrent-2026-04-10` (`1000 / 1000`), `/tmp/pass-fuzz-tuple-smith-bincurrent-2026-04-10` (`199 / 199` comparable matches plus the same Binaryen-only `binaryen-rec-group-zero` parser failure), and `/tmp/pass-fuzz-tuple-gen-valid-10000-bin-sharedmarks-2026-04-10` (`10000 / 10000` clean).
- Recorded that the earlier `moon run`-backed long lane `/tmp/pass-fuzz-tuple-gen-valid-10000-emptysummary-2026-04-10` stopped after `2124` matches with repeated missing-output validation failures, while direct replay of the first recorded input still writes valid output, so the current evidence points at launcher churn rather than a tuple-opt semantic regression.
- Added the later reduced timing ladder entries `/tmp/self-opt-tuple-tail-live0-sharedmarks-2026-04-10` and `/tmp/self-opt-tuple-tail-live0-cleanupfast-2026-04-10`, which show that the newer shared traversal-mark reuse and cleanup fast-path experiments did not beat the earlier `0.511 ms` reduced pass checkpoint.

## [2026-04-10] research | map MoonBit formal proof rollout

- Added archived research note `docs/wiki/raw/research/0077-2026-04-10-moonbit-prove-strategy.md` covering the current official `moon prove` workflow, local CLI/toolchain evidence, proof-model constraints, and a Starshine target matrix.
- Added `docs/wiki/validation/moonbit-prove-strategy.md` as the living rollout plan for bootstrap, `src/validate`-first proof adoption, and deferred proof surfaces.
- Updated `docs/wiki/index.md` so the new validation page is discoverable from the wiki catalog.

## [2026-04-10] implement | land first proved helper and record current package-boundary blocker

- Added active proof package `src/validate_proof` with a proved `label_stack_storage_index` helper and package-local `moon prove src/validate_proof` entrypoint.
- Rewired `src/validate/env.mbt` to use the proved helper for `Env::get_label_types`, and added direct `LabelStack` plus helper regression tests beside the validator code.
- Updated the live proof strategy page and archived research note to record the current blocker on proving `src/validate` directly: the generated WhyML for `jtenner/starshine/lib` currently fails with `unbound type symbol 'name'`.

## [2026-04-11] implement | extend the proof kernel through code-body diagnostics and keep the wiki current

- Added proved `defined_body_func_index` to `src/validate_proof`, bringing the active sidecar helper kernel to `8` proved goals.
- Rewired the remaining code-body diagnostic paths in `src/validate/validate.mbt` to use proved body-to-function index helpers for bulk-memory data-count errors and `ref.func` declaration diagnostics.
- Added imported-prefix validator regressions so those diagnostics now explicitly pin `FuncIdx(1)` behavior when one imported function precedes the failing defined body.
- Updated `docs/wiki/validation/moonbit-prove-strategy.md`, archived research note `0077-2026-04-10-moonbit-prove-strategy.md`, and `docs/wiki/index.md` so the living docs reflect the current helper inventory, usage surface, and `8`-goal proof-kernel state.

## [2026-04-11] implement | prove suffix-base recovery and document the virtual-group rule

- Added proved `suffix_start_index` to `src/validate_proof`, bringing the active sidecar helper kernel to `9` proved goals.
- Rewired `validate_codesec_diag` to recover the imported-function prefix through the proved suffix helper instead of open-coding `total - defined`.
- Rewired descriptor-metadata validation to use the same helper and documented the real rule: the current rectype group may already be appended to `env`, or it may still be a virtual suffix immediately after the existing type space during standalone `RecType` validation.
- Updated `docs/wiki/validation/moonbit-prove-strategy.md`, archived research note `0077-2026-04-10-moonbit-prove-strategy.md`, and `docs/wiki/index.md` so the living docs reflect the new helper and the current `9`-goal kernel state.

## [2026-04-11] maintain | extend bounded-index reuse through remaining name-section checks

- Rewired the remaining name-section bounds checks in `src/validate/validate.mbt` so local, label, and struct-field name indices now all flow through the proved `bounded_index` helper instead of open-coded `idx >= total` comparisons.
- Kept the proof kernel shape unchanged at `9` goals while widening the validator surface that now relies on the existing helper inventory.
- Updated `docs/wiki/validation/moonbit-prove-strategy.md` and archived research note `0077-2026-04-10-moonbit-prove-strategy.md` so the living proof docs reflect that broader `bounded_index` usage.

## [2026-04-11] fix | preserve branch-local `LabelStack` semantics while reusing proved reverse-index arithmetic

- Rewired `LabelStack::get` in `src/validate/env.mbt` to compute its reverse offset through the proved `label_stack_storage_index` helper while still traversing `head` / `parents`, instead of indexing the shared `values` backing array directly.
- Added a divergent-copy regression in `src/validate/env_tests.mbt` proving that `LabelStack.copy` branches can push different tails and still preserve each branch's logical declaration-order lookup.
- Updated `docs/wiki/validation/moonbit-prove-strategy.md`, archived research note `0077-2026-04-10-moonbit-prove-strategy.md`, and `agent-todo.md` so the proof rollout docs now treat persistent branch semantics as an explicit invariant of the `Env` / `LabelStack` slice.

## [2026-04-11] maintain | widen proved flat-index reuse across the remaining name-section spaces

- Rewired the remaining flat name-section bounds checks in `src/validate/validate.mbt` so function, type, table, memory, global, elem, data, and tag name indices now all flow through the proved `bounded_index` helper instead of bespoke per-space lookups.
- Added focused validator regressions for out-of-range function-name and type-name entries so the widened helper reuse is locked by executable diagnostics, not just by the refactor itself.
- Updated `docs/wiki/validation/moonbit-prove-strategy.md` and archived research note `0077-2026-04-10-moonbit-prove-strategy.md` so the living proof docs now describe `bounded_index` as the flat name-section index gate across all current validator spaces.

## [2026-04-11] maintain | widen latest-index proof-helper reuse into typecheck branch-label tails

- Rewired the `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` helper paths in `src/validate/typecheck.mbt` to recover the trailing label slot through the proved `latest_stack_index` helper instead of open-coding `label_ts.length() - 1`.
- Added focused typechecker regressions for the empty-label-payload error surface on those three branch helpers so the refactor stays pinned by exact observable errors.
- Updated `docs/wiki/validation/moonbit-prove-strategy.md` and archived research note `0077-2026-04-10-moonbit-prove-strategy.md` so the living proof docs now treat `latest_stack_index` as active in the first typecheck helper slice as well as `env`.

## [2026-04-11] maintain | widen latest-index proof-helper reuse into core typecheck stack-top recovery

- Rewired `check_pop_types_from_top` in `src/validate/typecheck.mbt` to recover the current stack-top index through the proved `latest_stack_index` helper instead of open-coding `st.stack.length() - 1`.
- Added direct wrapper-level regressions for `tc_state_validate_end_stack` so reachable empty-stack underflow and unreachable virtual-bottom suffixes are both locked before wider `PRV004` helper extraction.
- Updated `docs/wiki/validation/moonbit-prove-strategy.md`, archived research note `0077-2026-04-10-moonbit-prove-strategy.md`, and `agent-todo.md` so the current proof rollout now records `latest_stack_index` as active in both branch-label tails and the core typecheck stack walk.

## [2026-04-11] maintain | reduce the `ssa-nomerge` `Func 523` follow-up into executable regressions

- Updated `binaryen/passes/ssa-nomerge/parity.md`, `binaryen/passes/ssa-nomerge/index.md`, archived research note `0076-2026-04-10-ssa-nomerge-parity-investigation.md`, `docs/wiki/index.md`, and `agent-todo.md` after reducing one unreachable compare-carrier slice from the traced `Func 523` family into checked-in lift and pass regressions.
- Recorded the new focused evidence in `src/ir/hot_lift_test.mbt` and `src/passes/ssa_nomerge_test.mbt`, plus the supporting concrete-pop-count follow-up in `src/ir/hot_lift.mbt`.
- Recorded that fresh direct artifact replay at `/tmp/ssa-nomerge-func523-followup.log` still exits zero and validates its output module, but still logs the same `skip-invalid-lower func=(Func 523) reason=writeback-validate:type mismatch` plus `228` `suspicious-escape-carrier` skips, so the reduced follow-up narrowed the family without yet closing the remaining artifact-only gap.

## [2026-04-11] health | refresh pass smoke evidence for `reorder-locals`, `heap2local`, and `remove-unused-module-elements`

- Added a new research node `docs/wiki/raw/research/0078-2026-04-11-parity-smoke-rerun.md` to archive the fresh 200-case smoke rerun matrix and mismatch classification.
- Updated `binaryen/no-dwarf-default-optimize-path.md` metadata to reflect current `version_129` toolchain parity context (`last_reviewed`, command-availability note).
- Reran compare health checks on current `version_129`:
  - `reorder-locals` (`both`): `199 / 200` compared, `198` normalized matches, `1` mismatch, `1` `binaryen-rec-group-zero` command failure (`case-000029-wasm-smith`).
  - `reorder-locals` (`gen-valid`): `199 / 200` compared, `199` normalized matches, `0` command failures, `1` mismatch (`case-000150-gen-valid`).
  - `heap2local`: `199 / 200` compared, `199` normalized matches, `0` mismatches, `1` `binaryen-rec-group-zero` command failure (`case-000029-wasm-smith`).
  - `remove-unused-module-elements`: `199 / 200` compared, `199` normalized matches, `0` mismatches, `1` `binaryen-rec-group-zero` command failure (`case-000029-wasm-smith`).
- Updated `reorder-locals`, `heap2local`, and `remove-unused-module-elements` parity pages to cite this health note and pin the command-failure classification to artifacts currently on disk.
- Verified the persistent `reorder-locals` mismatch remains behavioral-noise compatible by executing both failing outputs with `wasmtime --invoke main` (`exit 0` on both).

## [2026-04-11] health | rerun focused Binaryen health checks for DFE, pick-load-signs, RUB, tuple

- Added `docs/wiki/raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md` to archive a second focused smoke batch for:
  - `duplicate-function-elimination`
  - `pick-load-signs`
  - `remove-unused-brs`
  - `tuple-optimization`
- Updated parity pages for all four passes to carry the fresh `2026-04-11` evidence and command-failure/mismatch classification.
- Notably, this rerun raised `remove-unused-brs` as the current open mismatch surface in this band:
  - mixed: `199 / 199` compared, `175` normalized matches, `24` mismatches
  - gen-valid: `114 / 114` compared, `84` matches, `30` mismatches, `maxFailuresHit: true`
- `duplicate-function-elimination`, `pick-load-signs`, and `tuple-optimization` remain clean in this 200-case smoke band (with one known `binaryen-rec-group-zero` command-failure class on mixed runs).

## [2026-04-11] maintain | expand wiki catalog coverage for active pass folder landing pages

- Updated `docs/wiki/index.md` so all currently active Binaryen pass landing pages under `docs/wiki/binaryen/passes/` are discoverable from the human-readable catalog (`binaryen/passes/index.md` remains the module namespace hub).
- The index lint now shows no missing non-raw, non-log living pages under `docs/wiki/`.
- This change does not alter pass semantics; it closes the knowledge-map maintenance gap for scaffolded and active pass folders alike.

## [2026-04-11] maintain | clarify proof rollout gates and active kernel slice list in moonbit proof docs

- Updated `validation/moonbit-prove-strategy.md` to reflect current `moonbit` proof gating (`src/validate` is not proof-enabled by default) and to make `moon prove src/validate*` commands explicitly conditional on enabling `"proof-enabled": true` in `src/validate/moon.pkg`.
- Added `src/validate_proof/suffix_index.mbt` to the staged proof-slice rollout and expanded source citations in the proof strategy page to include both `src/validate/moon.pkg` and `src/validate_proof/moon.pkg` package boundaries.
- Kept the archived `0077-2026-04-10-moonbit-prove-strategy.md` failure history as historical context while clarifying the present rollout sequence.

## [2026-04-11] maintain | audit late `-O4z` tail-pass wiring and stub-coverage wording

- Re-checked `-O4z` pathing and pass scheduling in `src/cmd/cli.mbt`, `src/cmd/cmd.mbt`, and `src/passes/optimize.mbt`:
  - `-O4z` maps to `optimize_level=4`, `shrink_level=4`; with no explicit pass flags this resolves to `shrink`.
  - `shrink` expands to the hot/module tail sequence including `global-refining`, `memory-packing`, `once-reduction`, `dead-code-elimination`, `optimize-instructions`, `heap-store-optimization`, `precompute`, `simplify-locals`, plus supporting module neighbors.
- Confirmed each inspected late pass is implemented/dispatched in-tree today:
  - module-path passes: `global-refining`, `memory-packing`, `once-reduction`
  - hot-path passes: `dead-code-elimination`, `optimize-instructions`, `heap-store-optimization`, `precompute`, `simplify-locals`
  - `vacuum` dispatch lives in `optimize.mbt` + `pass_manager.mbt` (hot path, no dedicated `src/passes/vacuum.mbt`).
- Updated `docs/wiki/binaryen/passes/index.md` and late-pass landing pages to reflect implemented status while keeping `status: stub` where parity/shape deep docs are still pending.
- Added `docs/wiki/raw/research/0080-2026-04-11-late-pipeline-pass-dispatch-audit.md` to preserve this pass-wiring and wiki-health audit.
