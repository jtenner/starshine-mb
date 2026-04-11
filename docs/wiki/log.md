# Wasm Knowledge Base Log

Append new entries; do not rewrite prior history except to fix obvious formatting mistakes or redact sensitive data.

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
