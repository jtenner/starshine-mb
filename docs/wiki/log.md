# Wasm Knowledge Base Log

Append new entries; do not rewrite prior history except to fix obvious formatting mistakes or redact sensitive data.

## [2026-04-18] maintain | record named natural and coverage-forced `gen_invalid` seed helpers

- Reviewed the already-modified invalid-generation files `src/validate/gen_invalid.mbt`, `src/validate/gen_invalid_tests.mbt`, `src/fuzz/invalid_binary.mbt`, `src/fuzz/invalid_binary_wbtest.mbt`, and the generated package signatures `src/validate/pkg.generated.mbti` plus `src/fuzz/pkg.generated.mbti` to capture one more durable public-API refinement: callers now have explicit `natural_seed(...)` and `coverage_forced_seed(...)` helpers in addition to the earlier `minimal_seed(...)` helper, instead of having to pass the matching `GenValidConfig` defaults manually.
- Updated `docs/wiki/validate/fuzz-hardening.md` and `docs/wiki/index.md` so the living docs now describe the AST and binary `gen_invalid` surfaces in terms of those three named seed families: natural, coverage-forced, and minimal.
- Reran a repo-local markdown-link and living-orphan health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the ingest.

## [2026-04-18] maintain | record public invalid-fuzz report builders for all source kinds

- Reviewed the already-modified fuzz invalid-repro files `src/fuzz/invalid_repro.mbt`, `src/fuzz/invalid_repro_wbtest.mbt`, and `src/fuzz/pkg.generated.mbti` to capture the durable follow-up after the first `gen_invalid` API pass: the shared repro surface now exports report builders not only for AST and binary invalid cases but also for inline text and spec-seed cases, so downstream callers can construct checked `InvalidFuzzFailureReport` values from stable ids across all four source kinds.
- Updated `docs/wiki/validate/fuzz-hardening.md` and `docs/wiki/index.md` so the living docs now say explicitly that AST/binary reports preserve both the invalid artifact and the valid seed artifact, while text/spec-seed reports now also have first-class stable-id builders on the same shared repro surface.
- Reran a repo-local markdown-link and living-orphan health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the ingest.

## [2026-04-18] maintain | record public `gen_invalid` seed/mutation surfaces

- Reviewed the already-modified validator fuzz files `src/validate/gen_invalid.mbt`, `src/validate/gen_invalid_tests.mbt`, `src/fuzz/gen_invalid_wbtest.mbt`, `src/validate/invalid_fuzzer.mbt`, `src/fuzz/invalid_binary.mbt`, `src/fuzz/invalid_binary_wbtest.mbt`, and the generated public interfaces `src/validate/pkg.generated.mbti` plus `src/fuzz/pkg.generated.mbti` to confirm one durable wiki-worthy change: the AST-invalid and binary-invalid helpers are now supported package surfaces, not only internal fuzz-runner implementation details.
- Updated `docs/wiki/validate/fuzz-hardening.md` and `docs/wiki/index.md` so the living docs now say explicitly that downstream packages can call `gen_invalid_ast_seed_config`, `gen_invalid_ast_seed_module`, `gen_invalid_ast_generate`, `gen_invalid_binary_seed_config`, `gen_invalid_binary_seed_module`, and `gen_invalid_binary_generate` through exported params/generated structs, with checked-in coverage for stable-id lookup plus both random-valid-seed and minimal-valid-seed modes.
- Reran a repo-local markdown-link and living-orphan health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the ingest.

## [2026-04-18] maintain | turn late ordered-audit note IDs into direct wiki links

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` and `docs/wiki/binaryen/passes/remove-unused-brs/parity.md` so the living wiki now links the active ordered `-O4z` blocker notes (`0099`, `0100`) and same-day retirement notes (`0102` through `0107`) directly instead of mentioning those raw-research IDs only as plain text.
- This maintenance pass did not change the underlying blocker story; it tightened source-of-truth hygiene by making the exact raw evidence reachable from the living summaries without an extra manual search step.
- Reran a repo-local markdown-link and living-orphan health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the cross-link refresh.

## [2026-04-18] fix | retry successful-but-no-output `moon run` fuzz launcher churn

- Updated `docs/wiki/binaryen/passes/tuple-optimization/parity.md` and `docs/wiki/binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md` so the historical `2124 / 10000` long-lane stop at `/tmp/pass-fuzz-tuple-gen-valid-10000-emptysummary-2026-04-10` is now documented as an old `pass-fuzz-compare` launcher artifact rather than a standing workflow requirement to prefer `--starshine-bin` for every very long lane.
- The living tuple docs now record the narrower outcome: the harness retries a successful default `moon run` invocation that fails to materialize `starshine.raw.wasm`, so the earlier failure remains useful evidence about launcher churn without implying a current tuple-opt semantic mismatch or a permanent native-binary-only workaround.
- Updated `agent-todo.md` to remove the retired long-lane launcher-workaround bullet from the tuple backlog.

## [2026-04-18] maintain | record docs.rs Binaryen pass-coverage contradiction

- Ran another Binaryen primary-source/source-of-truth sweep against the official GitHub release horizon, the official GitHub `main` changelog, the Chromium mirror refs/changelog trail, and the current docs.rs `wasm_opt` pages before editing the wiki.
- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/heap-store-optimization/index.md`, and `docs/wiki/index.md` so the living docs now record one sharper package-surface caution explicitly: as of `2026-04-18`, the docs.rs crate overview says `Pass` represents or exposes all Binaryen optimization passes, but the linked enum page still omits `HeapStoreOptimization`, `MinimizeRecGroups`, and `StringLowering`. The wiki now treats docs.rs as self-contradictory completeness evidence and keeps official GitHub release pages plus the Debian manpage as the stronger terminology/release-horizon sources.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the wording refresh.

## [2026-04-18] fix | retire `[O4Z]005` generated slot-33 `vacuum` corruption

- Added `docs/wiki/raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md` to capture the shifted symptom relative to `0098`: the saved slot-33 predecessor no longer died in Starshine's final validator, but it still emitted invalid typed-`if` output that `wasm-tools` rejected until the validator/typechecker escape fix and guarded `vacuum` writeback landed.
- Updated `docs/wiki/binaryen/passes/vacuum/index.md`, `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` so the living wiki no longer treats slot `33` as an active `vacuum` blocker; the ordered generated-artifact blocker set is now down to two slots overall (`remove-unused-brs` `40` and `optimize-instructions` `44`), and the durable explanation for the retired `vacuum` slot is the validator/writeback boundary rather than a new pass-local cleanup rule.
- Updated `agent-todo.md` so `[O4Z]005` is retired by `0107` and the remaining active generated `-O4z` blockers now start at `[O4Z]006`.

## [2026-04-18] maintain | repair stale precompute blocker wording in pass folder map

- Ran another Binaryen primary-source spot check against the official GitHub release surface plus the current `main` changelog before editing the wiki; this maintenance pass still did not find a documented `version_130` release page or a newer changelog-advertised optimization-pass addition beyond the already tracked horizon through `version_129`.
- Updated `docs/wiki/binaryen/passes/index.md` so the precompute catalog entry now matches the living `precompute` pass page and late-pipeline summary: slot `19` `func 108` is retired by `0105`, so the folder map no longer incorrectly describes it as an active blocker.
- Reran a repo-local markdown-link health check over `docs/wiki/**/*.md`; there were `0` broken relative links after the wording repair.

## [2026-04-18] maintain | correct late-pass blocker-count wording after slot-19 and slot-23 retirements

- Rechecked the current Binaryen public-source hierarchy against the official GitHub `main` changelog and tagged release pages through `version_129`, plus the Chromium mirror commits already cited by the late-pass pages; this maintenance pass did not find a newer documented optimization-pass addition or rename affecting Starshine's current folder map.
- Updated `docs/wiki/index.md` and `docs/wiki/binaryen/passes/index.md` so their summaries no longer say the late `-O4z` audit still has `five` remaining blockers; after the `0105` and `0106` retirements, the living late-pass summary correctly narrows the open generated-artifact blocker set to `three`: `vacuum` slot `33`, `remove-unused-brs` slot `40`, and `optimize-instructions` slot `44`.
- Reran a repo-local markdown-link health check over `docs/wiki/**/*.md`; there were still `0` broken relative links after the wording correction.

## [2026-04-18] fix | retire `[O4Z]004` generated slot-23 `vacuum` corruption

- Added `docs/wiki/raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md` to record that the saved slot-23 predecessor from `0097` now replays cleanly on the current tree, the extracted `Func 652` replay also validates, and the Binaryen compare reports normalized-WAT plus canonical-function equality.
- Updated `docs/wiki/binaryen/passes/vacuum/index.md`, `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` so the living wiki no longer treats slot `23` as an active `vacuum` blocker; the remaining live `vacuum` blocker is slot `33`, and the durable inference is that slot `23` was fallout from the earlier HOT-lower carrier-wrapper fix in `0103`, not a pass-local `vacuum` mutation bug.
- Added cmd-level native regressions in `src/cmd/cmd_wbtest.mbt` for both the full saved slot-23 predecessor and the extracted `Func 652` replay, and updated `agent-todo.md` so the generated `-O4z` active blocker list now starts at `[O4Z]005`.

## [2026-04-18] fix | retire `[O4Z]003` generated slot-19 `precompute` corruption

- Added `docs/wiki/raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md` to record that the saved slot-19 predecessor from `0096` now replays cleanly on the current tree, stays `wasm-tools validate` clean, and matches Binaryen at normalized-WAT / canonical-function granularity.
- Updated `docs/wiki/binaryen/passes/precompute/index.md` and `docs/wiki/index.md` so the living wiki no longer describes slot `19` `func 108` raw-result loss as an active blocker; the durable frontier is back to parity/runtime work plus future lower-shape follow-ups, not this retired invalid-output witness.
- Added cmd-level native regressions in `src/cmd/cmd_wbtest.mbt` for both the full saved slot-19 predecessor and the extracted `Func 108` replay, and updated `agent-todo.md` so the generated `-O4z` active blocker list now starts at `[O4Z]004`.

## [2026-04-18] maintain | promote official GitHub release pages in Binaryen source-of-truth guidance

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/global-refining/index.md`, `docs/wiki/binaryen/passes/memory-packing/index.md`, `docs/wiki/binaryen/passes/once-reduction/index.md`, `docs/wiki/binaryen/passes/dead-code-elimination/index.md`, `docs/wiki/binaryen/passes/heap2local/index.md`, `docs/wiki/binaryen/passes/remove-unused-brs/index.md`, and `docs/wiki/index.md` after a fresh Binaryen source sweep.
- Tightened the public-source hierarchy again instead of changing the substantive pass claims: official GitHub release pages for `version_127` (`2026-03-10`), `version_128` (`2026-03-13`), and `version_129` (`2026-04-01`) are now recorded as the primary public release-horizon baseline, while the Chromium refs/release-note mirror remains corroborating evidence and the GitHub `main` changelog remains only a narrow post-tag drift watch.
- Replaced stale living-page wording that still said `non-GitHub` terminology checks on the stub landing pages and pass catalog, so the wiki now consistently reflects the maintenance lane's current rule: GitHub is allowed as a documentation source of truth for Binaryen pass names, release notes, and trunk drift, even though workflow operations still stay out of scope.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the refresh.

## [2026-04-18] maintain | switch Binaryen source-of-truth wording from non-GitHub-only to official-source hierarchy

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/heap-store-optimization/index.md`, and `docs/wiki/index.md` after a fresh Binaryen source sweep to remove stale wording that implied this maintenance lane had to avoid GitHub as a documentation source.
- Tightened the source-of-truth guidance instead of broadening claims: keep Chromium refs plus tagged release-note pages as the release-horizon baseline through `version_129`, keep Debian/docs.rs/README as incomplete package-surface corroboration, and use the official GitHub `main` changelog as the stronger current-trunk drift watch. The living wiki now records that Chromium and GitHub currently agree on the same `Current Trunk` lead item (`MemorySegment` -> `DataSegment` API renames) and still do not document a newer optimization-pass addition relevant to Starshine's pass catalog.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the wording refresh.

## [2026-04-18] maintain | tighten docs.rs pass-enum source-of-truth wording

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/heap-store-optimization/index.md`, and `docs/wiki/index.md` after a fresh non-GitHub Binaryen source sweep to record one useful docs.rs nuance explicitly: the published `wasm_opt::Pass` page says its exposed enum variants follow the command-line pass names with Rust capitalization conventions.
- Kept the conservative conclusion unchanged: that positive naming rule helps for entries the page does expose such as `RemoveUnusedBrs`, but the same page still omits `HeapStoreOptimization`, `MinimizeRecGroups`, and `StringLowering`, so those absences remain wrapper-surface lag evidence rather than proof of upstream renames or removals.
- Reran a repo-local markdown-link health check over `docs/wiki/**/*.md`; there were still `0` broken relative links after the wording refresh.

## [2026-04-18] maintain | narrow the late-pass blocker roster after slot-14 and slot-16 retirements

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/precompute/index.md`, `docs/wiki/binaryen/passes/vacuum/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` so the living wiki no longer describes the 2026-04-18 generated `cmd.wasm` ordered `-O4z` fallout as only a broad failing-pass cluster.
- The refreshed living summary now names the exact five remaining blockers explicitly: `remove-unused-brs` slot `40`, `precompute` slot `19`, `vacuum` slots `23` and `33`, and `optimize-instructions` slot `44`, while also calling out that slot `14` (`RUB`) and slot `16` (`optimize-instructions`) are already retired by `0102`, `0103`, and `0104`.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the ingest.

## [2026-04-18] maintain | record README typo in Binaryen pass-name evidence ladder

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` after another non-GitHub Binaryen source sweep because the bundled Binaryen README overview mirrored through `wasm-opt-sys` currently misspells `RemoveUnusedBrs` as `RemoveUnsedBrs`.
- Tightened the source-of-truth guidance accordingly: keep using the Debian `wasm-opt` manpage and Chromium-hosted release-note trail as stronger public spelling evidence, and treat the README overview as broad context rather than a canonical pass-name oracle.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the wording refresh.

## [2026-04-18] maintain | correct docs.rs heap-store terminology caveat

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/heap-store-optimization/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` after a fresh non-GitHub source check because the published `wasm_opt::Pass` enum page does **not** currently expose `HeapStoreOptimization`, even though the Debian experimental `wasm-opt` `122` manpage still lists `--heap-store-optimization`.
- Tightened the source-of-truth guidance accordingly: for this pass name, treat the Debian CLI manpage as the stronger public terminology source and treat docs.rs as negative evidence of Rust-wrapper surface lag, not as evidence that upstream Binaryen renamed or dropped the pass.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the correction.

## [2026-04-18] fix | retire `[O4Z]002` slot-16 `optimize-instructions` after the `Func 1818` follow-up

- Added `docs/wiki/raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md` to capture the remaining slot-16 `Func 1818` root cause: `hot_lower_impl_try_pack_split_parent_exit_payload(...)` was inserting a new typed carrier around a split parent-exit payload even when nested child branches still targeted the wrapper label one level out.
- Updated `docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/binaryen/passes/vacuum/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` so the living wiki now says the complete slot-16 story accurately: `Func 652` was fixed by `0103`, `Func 1818` was fixed by `0104`, the only remaining `optimize-instructions` ordered blocker is the later slot-44 replay, and the `vacuum` landing page no longer treats the retired slot-16 failures as evidence of a still-shared live blocker family.
- Updated `agent-todo.md` so `[O4Z]002` is now checked off and the active generated-artifact corruption list starts at `[O4Z]003`.

## [2026-04-18] maintain | refresh current-trunk Binaryen changelog lead note

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` after a fresh non-GitHub Binaryen source sweep because the Chromium-mirror `main` `CHANGELOG.md` no longer leads with the earlier worker-threading note; the current `Current Trunk` lead item is now the `MemorySegment` -> `DataSegment` API rename work.
- Kept the wiki's conservative conclusion unchanged: this is still only a freshness check, and the reachable `main` changelog still does not document a newer optimization-pass addition beyond the already tracked release-note horizon through `version_129`.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the wording refresh.

## [2026-04-18] maintain | anchor Binaryen release horizon with Chromium refs plus main changelog

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` after another non-GitHub Binaryen source sweep so the living wiki now cites the Chromium refs listing directly as the anchor for the current reachable release horizon: `refs/heads/main` is present, and `version_129` is still the newest directly reachable release tag in that mirror listing.
- Recorded the matching current-trunk caution explicitly: the Chromium-mirror `main` `CHANGELOG.md` currently leads with a C API worker-threading note rather than a newer optimization-pass addition, which is useful as a freshness check but still not strong enough to replace the tagged release-note pages as the source-of-truth boundary for pass-addition claims.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the wording refresh.

## [2026-04-18] maintain | refine Binaryen package-surface lag notes

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` after another non-GitHub Binaryen source sweep so the living wiki now says explicitly that the Debian `wasm-opt` manpage and the published `wasm_opt::Pass` enum are both incomplete in different directions: Debian already exposes some upstream-only passes such as `--minimize-rec-groups` / `--string-lowering`, while docs.rs still exposes older names like `RemoveUnusedTypes` without surfacing those newer additions.
- Tightened the source-of-truth guidance around late-pass upkeep: use the Debian manpage and docs.rs enum as terminology lower bounds, but keep the Chromium-hosted release-note trail through `version_129` as the safer public baseline when reconciling newer upstream-only pass additions or absences.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the wording refresh.

## [2026-04-18] maintain | extend non-GitHub Binaryen release-note coverage through version_129

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` after another Chromium-hosted Binaryen check so the living wiki now says explicitly that the directly reachable non-GitHub release-note horizon extends through `version_129`, not just the earlier `version_126` lower bound.
- Recorded the precise conservative takeaway from those newer public changelog sections: the already tracked upstream-only pass additions are still the latest ones visible in reachable release notes (`version_119`, `version_124`, `version_125`, `version_126`), while `version_127` / `version_128` / `version_129` do not surface another optimization-pass addition relevant to Starshine's implemented folder map.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the catalog refresh.

## [2026-04-18] fix | retire the extracted slot-16 `Func 652` carrier-wrapper failure and surface the remaining blocker

- Added `docs/wiki/raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md` to capture the resolved part of `[O4Z]002`: the extracted slot-16 `Func 652` replay was failing because `hot_lower_impl_stackify_wrapped_struct_set_prefixes(...)` inserted a new `block (result i32)` in front of a wrapped `local.set` carrier even though child branches still targeted the parent exit label.
- Updated `docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` so the living wiki now records the retired `Func 652` blocker explicitly and no longer describes slot 16 as only the old paired `Func 652` / `Func 1818` suspicion. The current landing-page truth is that the extracted `Func 652` witness is fixed, while the full slot-16 replay now advances to the still-open shared `Func 1818` family.
- Updated `agent-todo.md` so `[O4Z]002` stays active but now points at the narrowed state accurately: the old `Func 652` sub-bug is retired by `0103`, and the remaining direct replay failure for slot 16 is the newly surfaced `Func 1818` underflow.

## [2026-04-18] maintain | widen Binaryen upstream-only pass boundary notes again

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` after a fresh non-GitHub Binaryen release-note pass so the living wiki now records one more upstream-only addition that was missing from the earlier lower-bound catalog: `ReorderTypes` is already called out by Chromium-hosted `version_125`, between the previously tracked `version_124` and `version_126` additions.
- Kept the wording conservative and explicit about evidence quality: the reachable non-GitHub sources still provide a lower-bound public catalog rather than a full historical Binaryen pass audit, and this update only records the newly confirmed `version_125` gap instead of implying that the full upstream pass history has now been exhaustively reconciled.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the catalog refresh.

## [2026-04-18] maintain | ingest ordered-audit notes for DCE and heap2local

- Updated `docs/wiki/binaryen/passes/dead-code-elimination/index.md` and `docs/wiki/binaryen/passes/heap2local/index.md` so the living pass stubs now absorb one durable takeaway from the 2026-04-18 generated `cmd.wasm` ordered `-O4z` audit: both passes are currently in the expensive-but-successful cluster rather than the hard-corruption cluster.
- Refreshed `docs/wiki/binaryen/passes/index.md` and `docs/wiki/index.md` so the human catalogs no longer make those two landing pages look like terminology-only stubs; they now also call out the ordered-audit status and, for `heap2local`, the current non-GitHub `Heap2Local` naming sanity check.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the ingest.

## [2026-04-18] maintain | widen Binaryen upstream-only pass boundary notes

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` after another non-GitHub Binaryen release-note pass so the living wiki now records that upstream-only pass additions visible in reachable primary sources start earlier than the previously tracked `version_126` pair: `--minimize-rec-groups` is already present by `version_119`, `--string-lifting` and `TypeRefiningGUFA` are present by `version_124`, and `--remove-relaxed-simd` / `--strip-toolchain-annotations` remain the newer `version_126` additions.
- Kept the wording conservative and explicit about uncertainty: the repo still tracks Starshine's implemented pass subset, while this non-GitHub source sweep should be treated as a lower-bound public catalog rather than a full Binaryen pass-history audit.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the catalog refresh.

## [2026-04-18] maintain | record newer Precompute multibyte-array no-fold drift

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`, `docs/wiki/binaryen/passes/precompute/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` after a fresh non-GitHub upstream check so the living wiki now records the 2026-03-26 Chromium-mirror `Precompute` follow-up for multibyte array access: current trunk intentionally keeps `array.load` in `NONCONSTANT_FLOW` instead of folding it like an ordinary constant read.
- Kept the earlier child-retention, GC-write, and GC-atomic drift notes intact and explicit, so the newer multibyte-array behavior is filed as an additional upstream drift item rather than silently replacing the older chronology.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the refresh.

## [2026-04-18] maintain | tighten Binaryen upstream-catalog boundary and precompute drift notes

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` after a fresh non-GitHub upstream check so the terminology section now records two additional source-of-truth facts: Binaryen `version_126` added the newer upstream-only passes `--remove-relaxed-simd` and `--strip-toolchain-annotations`, and `Precompute` had an extra 2026-03-23 GC-write/effects-model fix before the already-tracked 2026-03-25 GC-atomic no-fold change.
- Updated `docs/wiki/binaryen/passes/precompute/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` so the living wiki now distinguishes Starshine's implemented Binaryen pass subset from newer upstream-only additions instead of letting the older Debian `122` manpage lag read like an implicit deprecation signal.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still `0` broken relative links and `0` living orphan pages after the catalog refresh.


## [2026-04-18] maintain | refresh RUB wiki metadata and slot-14 ingest links

- Updated `docs/wiki/binaryen/passes/remove-unused-brs/index.md` so its frontmatter `last_reviewed` stamp and source list now match the already-ingested 2026-04-18 ordered-audit and slot-14 guard evidence, instead of implying the landing page stopped at the 2026-04-13 perf-only state.
- Updated `docs/wiki/binaryen/passes/remove-unused-brs/branch-exit-and-payload-rewrites.md` so the one-armed `if br` section now has matching 2026-04-18 review metadata plus direct links to the slot-14 guard note and the external-validation cmd wbtest coverage.
- Refreshed `docs/wiki/binaryen/passes/index.md` and `docs/wiki/index.md` so both human catalogs mention the retired slot-14 large-condition guard on the RUB landing page.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were still no broken relative links and no living orphan pages after the metadata refresh.

## [2026-04-18] research | retire `[O4Z]001` slot-14 `remove-unused-brs` corruption

- Added `docs/wiki/raw/research/0102-2026-04-18-generated-o4z-rub-slot14-if-br-large-condition-guard.md` to capture the resolved slot-14 path: the invalid raw output came from `remove_unused_brs_try_rewrite_if_br(...)` rewriting a large non-reorder-safe plain-`br` condition, while oracle Binaryen kept a valid block-plus-branch shape on the extracted `Func 1354` replay.
- Updated `docs/wiki/binaryen/passes/remove-unused-brs/branch-exit-and-payload-rewrites.md`, `docs/wiki/binaryen/passes/remove-unused-brs/parity.md`, and `docs/wiki/index.md` so the living wiki now records the landed large-condition guard, the retired slot-14 blocker, and the fact that slot `40` is now the remaining ordered RUB corruption.
- The checked-in cmd regression in `src/cmd/cmd_wbtest.mbt` now validates the extracted slot-14 replay with external `wasm-tools validate`, so the wiki points at a durable external-validity lock instead of the older in-process-only green surface.

## [2026-04-18] maintain | record newer Precompute GC heap-effect drift

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` and `docs/wiki/binaryen/passes/precompute/index.md` after a fresh non-GitHub upstream check to record the newer Chromium-mirror `2026-03-25` `Precompute` change that stops folding GC `struct` / `array` atomic RMW and `cmpxchg` ops because they read and write heap state, alongside the already-tracked `2025-08-27` child-retention rewrite.
- Refreshed `docs/wiki/index.md` and `docs/wiki/binaryen/passes/index.md` so both human catalogs mention the broader `precompute` drift note instead of only the older child-retention change.
- Reran a repo-local markdown-link health check over `docs/wiki/**/*.md`; there were still no broken relative links after the refresh.

## [2026-04-18] maintain | tighten Binaryen terminology evidence for late-pass stubs

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` so the 2026-04-18 non-GitHub terminology check now explicitly records direct Debian manpage confirmation for `--heap-store-optimization` and `--remove-unused-brs`, instead of implying that only the Rust bindings carried those names.
- Updated `docs/wiki/binaryen/passes/heap-store-optimization/index.md` so the landing page cites both the Debian experimental `wasm-opt` manpage and the current `wasm_opt::Pass` docs for the still-current `HeapStoreOptimization` name.
- Refreshed `docs/wiki/index.md` and `docs/wiki/binaryen/passes/index.md` so the human catalogs describe the stronger direct-source terminology evidence.
- Reran a repo-local markdown-link and orphan-page health check over `docs/wiki/**/*.md`; there were no broken relative links and no living orphan pages after the refresh.

## [2026-04-18] maintain | record newer Binaryen trunk drift without renaming pass pages

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` so the current non-GitHub Binaryen check now distinguishes stable pass names from newer trunk behavior drift, using Chromium-hosted mirror commits for the 2025-08-27 `Precompute` child-retention rewrite plus the 2026-02-27 `RemoveUnusedBrs` branches-to-traps and `Vacuum` unreachable-preservation changes.
- Updated the living pass pages for `precompute`, `vacuum`, and `remove-unused-brs` so they now say explicitly that the repo's older `version_129` Binaryen oracle is a tagged source baseline, not a claim that current Binaryen trunk internals are unchanged.
- Refreshed `docs/wiki/index.md` and `docs/wiki/binaryen/passes/index.md` so the human catalogs mention the new drift notes instead of implying the older summaries are the latest upstream behavior.
- Reran a repo-local markdown-link health check over `docs/wiki/**/*.md` and confirmed there are still no broken relative links after the drift-note ingest.

## [2026-04-18] maintain | refresh late-pass stub terminology checks

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` so the current non-GitHub Binaryen terminology check now explicitly includes `HeapStoreOptimization` alongside the already-tracked `GlobalRefining`, `MemoryPacking`, `OnceReduction`, `OptimizeInstructions`, `Precompute`, `PrecomputePropagate`, and `Vacuum` surfaces.
- Refreshed the stub landing pages for `global-refining`, `memory-packing`, `once-reduction`, and `heap-store-optimization` so each page now records the current non-GitHub naming evidence and says explicitly that this maintenance run found no rename or deprecation signal in the available primary-ish sources.
- Updated `docs/wiki/index.md` and `docs/wiki/binaryen/passes/index.md` so both catalogs describe the refreshed terminology-check coverage instead of the older generic stub wording.
- Reran a repo-local markdown-link health check over `docs/wiki/**/*.md` and confirmed there are still no broken relative links after the refresh.

## [2026-04-18] research | narrow `[O4Z]001` to a native/source divergence blocker

- Added `docs/wiki/raw/research/0101-2026-04-18-generated-o4z-rub-slot14-native-source-divergence.md` to capture the current slot-14 blocker split: rebuilt native `cmd.exe` still emits invalid raw output on the saved predecessor from `0094`, while new in-process `run_cmd` / `run_cmd_with_adapter` wbtests on the same bytes stay green.
- Updated `docs/wiki/binaryen/passes/remove-unused-brs/parity.md`, `docs/wiki/index.md`, and `agent-todo.md` so the living docs now record the narrower blocker explicitly instead of treating slot 14 as an undifferentiated RUB corruption.
- Added focused cmd wbtests in `src/cmd/cmd_wbtest.mbt` for the saved slot-13 predecessor fixture so the repo now keeps the source-path behavior and the still-failing built-native behavior separate.

## [2026-04-18] maintain | record non-GitHub Binaryen source lag and paired late-pass blockers

- Updated `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` so the living wiki now says explicitly that the non-GitHub Binaryen discovery surfaces available to this maintenance run lag the repo's older GitHub-sourced `version_129` source oracle, and that the older Debian/docs.rs package versions should be treated as source-availability lag rather than as evidence of upstream pass-name removal or reversion.
- Updated `docs/wiki/binaryen/passes/optimize-instructions/index.md` and `docs/wiki/binaryen/passes/vacuum/index.md` so those landing pages now carry the durable ordered-audit conclusion that the current `Func 652` and `Func 1818` failures are paired `optimize-instructions` / `vacuum` ordered-prefix blockers, not yet isolated pass-only regressions.
- Reran a repo-local markdown-link health check over `docs/wiki/**/*.md` and confirmed there are still no broken relative links after the wording refresh.

## [2026-04-18] maintain | reconcile Binaryen pass terminology and repair wiki links

- Ran a non-GitHub Binaryen terminology check against the Debian experimental `wasm-opt` `122` manpage plus the current `wasm_opt` Rust docs/README mirrors, and recorded in `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` that the current upstream-facing names still align with the wiki's late-pass folder map.
- Updated `docs/wiki/binaryen/passes/precompute/index.md`, `docs/wiki/binaryen/passes/dead-code-elimination/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/index.md` so the living wiki now records the explicit `Dce` and `precompute-propagate` alias boundaries instead of leaving those names implicit.
- Repaired broken relative links in `docs/wiki/binaryen/passes/late-pipeline-dispatch.md` and the archived RUME follow-up notes `0090` / `0091`, then reran a repo-local markdown-link scan to confirm `docs/wiki/` has no remaining broken relative links.

## [2026-04-18] maintain | tighten late-pass landing pages and cross-links

- Reworded the stub landing pages for `global-refining`, `memory-packing`, `once-reduction`, `heap-store-optimization`, `dead-code-elimination`, `optimize-instructions`, `precompute`, and `vacuum`, and shortened the root wiki catalogs in `docs/wiki/index.md` and `docs/wiki/binaryen/passes/index.md`, so they point at `late-pipeline-dispatch.md` instead of repeating the generic “being authored” boilerplate.
- Kept the cross-links self-referential by adding the late-pipeline dispatch note to each page's `related` list.

## [2026-04-18] research | capture generated `cmd.wasm` ordered `-O4z` corruption blockers

- Added `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md` plus the seven per-slot corruption notes `0094` through `0100` to capture the ordered self-opt audit on `_build/wasm/debug/build/cmd/cmd.wasm`, the saved `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/` replay root, and the exact direct reproduce commands for every hard corruption slot.
- Updated `agent-todo.md` so the new `[O4Z]001` through `[O4Z]007` blockers sit at the top of the active backlog with saved predecessor inputs, direct replay commands, and raw-doc references for each corruption.
- Updated `docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/binaryen/passes/precompute/index.md`, `docs/wiki/binaryen/passes/vacuum/index.md`, `docs/wiki/binaryen/passes/remove-unused-brs/parity.md`, and `docs/wiki/index.md` so the living wiki now points at the generated-artifact ordered-prefix corruption follow-up instead of treating those passes as stub-only or purely parity-drift work.

## [2026-04-16] maintain | align fuzz runner wrapper and truth surfaces

- Updated `scripts/lib/fuzz-task.ts` and `scripts/test/task-family-commands.ts` so `bun fuzz run` now forwards the same discovery commands plus `--emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir>` that `src/fuzz/main.mbt` already exposes, instead of carrying a narrower wrapper-only contract.
- Updated `src/fuzz/main.mbt` so the top-level `validate-valid` suite now reuses `validate_valid_run_config(...)` for the shared profile ladder and only layers the text-companion checks on top of `run_validate_valid_fuzz(...)` instead of keeping another copy of the profile normalization logic.
- Updated `tooling/fuzz-runner.md`, `validate/fuzz-hardening.md`, `docs/wiki/index.md`, `docs/0089-2026-04-15-fuzz-stack-hardening-execution-plan.md`, and `agent-todo.md` so the validator-fuzz handoff now records `[FUZ]010` as complete and no longer describes wrapper/docs alignment as unfinished fuzz-stack work.

## [2026-04-16] fix | persist validator invalid repros and replay helpers

- Added `src/fuzz/invalid_repro.mbt` plus `src/fuzz/invalid_repro_wbtest.mbt` with one shared invalid-failure report surface, stable `fuzz-corpus/invalid/<suite>/<strategy>/seed-<seed>-attempt-<attempt>/` persistence, metadata parse/load roundtrips, bounded shrink helpers, and direct replay helpers across AST, binary, text, and spec-seed artifacts.
- Updated `src/validate/invalid_fuzzer.mbt`, `src/fuzz/invalid_binary.mbt`, and `src/fuzz/invalid_text.mbt` so each current invalid source kind now exposes a deterministic minimal replay/reduction surface instead of requiring the original random run to reconstruct a failing case.
- Updated `validate/fuzz-hardening.md`, `tooling/fuzz-runner.md`, `docs/wiki/index.md`, `docs/0089-2026-04-15-fuzz-stack-hardening-execution-plan.md`, and `agent-todo.md` so the validator-fuzz handoff now records `[FUZ]009` as complete and points the next unfinished slice at `[FUZ]010` wrapper/docs alignment.

## [2026-04-16] fix | restore the validator text and spec-seed invalid fuzz lanes

- Added `src/fuzz/invalid_text.mbt` plus `src/fuzz/invalid_text_wbtest.mbt` with two deterministic stage-aware fuzz lanes: inline text invalidation and selected `tests/spec` invalid/malformed/unlinkable seed replay.
- Updated `src/wast/spec_harness.mbt` to export shared static-assertion evaluation helpers so the spec harness and the new fuzz runners now reuse one interpretation of `assert_malformed`, `assert_invalid`, and `assert_unlinkable`.
- Updated `tooling/fuzz-runner.md`, `validate/fuzz-hardening.md`, `docs/wiki/index.md`, `docs/0089-2026-04-15-fuzz-stack-hardening-execution-plan.md`, and `agent-todo.md` so the validator-fuzz handoff now records `[FUZ]008` as complete, the active suite inventory includes `validate-invalid-text` and `validate-invalid-spec-seed`, and the next unfinished slice is `[FUZ]009`.

## [2026-04-16] fix | restore the validator binary invalid fuzz lane

- Added `src/fuzz/invalid_binary.mbt` plus `src/fuzz/invalid_binary_wbtest.mbt` with a checked-in byte-corruption registry, deterministic smoke/ci/stress profile resolution, and stage-aware per-strategy stats for `attempted` / `applicable` / `mutated` / `decode_rejected` / `validate_rejected` / `rejected_expected` / `accepted`.
- Promoted `validate-invalid-binary` to a live `src/fuzz` suite and updated the fuzz runner truth surfaces in `tooling/fuzz-runner.md` so only `validate-invalid-text` and `validate-invalid-spec-seed` remain reserved.
- Updated `validate/fuzz-hardening.md`, `docs/wiki/index.md`, `docs/0089-2026-04-15-fuzz-stack-hardening-execution-plan.md`, and `agent-todo.md` so the validator-fuzz handoff now records `[FUZ]007` as complete and points the next unfinished slice at `[FUZ]008`.

## [2026-04-16] fix | restore the validator AST invalid fuzz lane

- Added `src/validate/invalid_fuzzer.mbt` with a checked-in AST invalid strategy registry, deterministic smoke/ci/stress profile resolution, expected `ValidationIssueFamily` accounting, and per-strategy `attempted` / `applicable` / `mutated` / `rejected` / `rejected_expected` stats.
- Restored `validate-invalid-ast` as a live `src/fuzz` suite and updated the fuzz runner truth surfaces in `tooling/fuzz-runner.md` so only the still-missing binary/text/spec-seed lanes remain reserved.
- Updated `validate/fuzz-hardening.md`, `docs/wiki/index.md`, `docs/0089-2026-04-15-fuzz-stack-hardening-execution-plan.md`, and `agent-todo.md` so the validator-fuzz handoff now records `[FUZ]006` as complete and points the next unfinished slice at `[FUZ]007`.

## [2026-04-16] fix | close the gen-valid-exposed RUME no-op start-section family

- Updated `src/passes/remove_unused_module_elements.mbt` so `RUME` now matches the proved Binaryen no-op `start` rule for defined single-`nop` start targets: it skips `start`-rooted liveness for that exact family, drops `start_sec` during rewrite, and still preserves the nearby empty-body negative boundary.
- Added focused regressions in `src/passes/remove_unused_module_elements_test.mbt` for exported/elem-linked single-`nop` start targets, the same family with locals still present, the empty-body negative boundary, and the start-only single-`nop` case that should disappear entirely once `start` stops rooting it.
- Updated `docs/0089-2026-04-15-fuzz-stack-hardening-execution-plan.md`, `agent-todo.md`, `validate/fuzz-hardening.md`, `docs/wiki/index.md`, and `raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md` so the validator-fuzz handoff now records `[FUZ]003B` as complete, the exact kept rule is documented, and the next unfinished fuzz slice is `[FUZ]004`.

## [2026-04-16] research | capture the next gen-valid-exposed RUME start-section family

- Added `raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md` to capture the two saved `gen-valid` `remove-unused-module-elements` mismatches that remain after the imported-function fix, including the exact `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000002-gen-valid/` and `case-000020-gen-valid/` repro folders plus the current uncertainty about Binaryen's precise no-op `start`-section pruning rule.
- Updated `docs/0089-2026-04-15-fuzz-stack-hardening-execution-plan.md` and `agent-todo.md` so the next unfinished validator-fuzz slice is now the explicit `[FUZ]003B` start-section follow-up instead of jumping straight to broader body widening.
- Updated `validate/fuzz-hardening.md` and `docs/wiki/index.md` so the living validator-fuzz summary now points at the newly documented `RUME` no-op `start`-section family.

## [2026-04-16] fix | close the gen-valid-exposed RUME imported-function family

- Updated `src/passes/remove_unused_module_elements.mbt` so module-pass `RUME` now drops unused function imports, remaps surviving function indices through the real used-function bitset, and compacts dead simple function types after imported-function removal.
- Added a focused imported-function regression in `src/passes/remove_unused_module_elements_test.mbt` that keeps a live exported/start/elem-defined function while requiring the unused imported function and its dead type to disappear.
- Refreshed `docs/0089-2026-04-15-fuzz-stack-hardening-execution-plan.md`, `agent-todo.md`, `validate/fuzz-hardening.md`, and research note `raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md` so the validator-fuzz handoff now records the landed imported-function closure and the new distinct no-op start-section pruning follow-up revealed by the rerun.

## [2026-04-16] research | capture gen-valid-exposed RUME imported-function parity case

- Added `raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md` to capture the exact `gen-valid`-seeded `remove-unused-module-elements` mismatch exposed after `[FUZ]003`, including the reproducer command, the `5/5` mismatch summary, and the saved `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/` artifact paths.
- Updated `validate/fuzz-hardening.md` so the living validator-fuzz summary now records the active downstream parity follow-up exposed by widened `coverage-forced` generation instead of treating the topology widening as an isolated generator-only concern.
- Updated `docs/wiki/index.md` so the validator fuzz entry now calls out the active `gen-valid` / `RUME` imported-function follow-up.

## [2026-04-16] maintain | record fuzz runner suite inventory reconciliation

- Updated `tooling/fuzz-runner.md` so the living wiki now records the current active fuzz suites, the reserved future invalid-lane ids, and the `active` / `reserved` `--list-suites` output contract.
- Updated `validate/fuzz-hardening.md` so the validator-fuzz summary now reflects the current live valid-only surface, the reserved invalid suite ids, and the new hardening order instead of describing the removed old invalid lane as if it were still checked in.
- Updated `docs/wiki/index.md` so the catalog descriptions now mention the active-vs-reserved suite inventory boundary and the refreshed validator-fuzz hardening summary.

## [2026-04-15] maintain | record simplify-locals helper no-op raw skips

- Updated the living `simplify-locals` raw-lane and performance frontier pages so the new `branch-dense-structured-call-heavy-noop`, `block-rich-structured-call-heavy-noop`, `call-dense-structured-walker-noop`, and `low-local-decision-ladder-noop` contracts are part of the durable wiki instead of only the code and perf tests.
- Recorded that these families exist to retire unchanged helper-shaped hot work before lift, while the remaining open simplify-locals debt is still runtime budget and raw wasm/text equality versus Binaryen.

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
- Rechecked correctness on the kept tree: `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` is `44 / 44`, `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*tuple-optimization*'` is `15 / 15`, `moon test --package jtenner/starshine/cmd --file cmd_wbtest.mbt --filter '*tuple-optimization*'` is `7 / 7`, `/tmp/pass-fuzz-tuple-cleaned-genvalid-1000-2026-04-10` is `1000 / 1000`, and `/tmp/pass-fuzz-tuple-cleaned-smith-200-2026-04-10` is `199 / 200` with the same Binaryen-only `binaryen-rec-group-zero` command failure.
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

## [2026-04-10] ingest | crystallize simplify-locals research into the pass folder

- Moved the branch-local `simplify-locals` research note into `docs/wiki/raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md` because archive serial `0073` is already assigned in the shared wiki history.
- Expanded `binaryen/passes/simplify-locals/` with a real landing page plus `binaryen-strategy.md` and `starshine-hot-ir-strategy.md`.
- Recorded the staged Binaryen sink and cleanup model, the repo's no-structure-first HOT-IR port strategy, and the fact that the archived note is a historical source while living Binaryen pass pages now track the shared `version_129` oracle.
- Updated `docs/wiki/index.md` and `docs/wiki/binaryen/passes/index.md` so the new simplify-locals pages are discoverable.

## [2026-04-10] expand | turn simplify-locals into a full pass dossier

- Expanded `binaryen/passes/simplify-locals/` beyond the initial landing page into a full pass folder with `wat-shapes.md`, `implementation-map.md`, `effect-ordering-and-barriers.md`, `raw-lane-and-writeback.md`, `validation-and-signoff.md`, `performance-and-artifact-frontiers.md`, and `parity.md`.
- Rewrote `binaryen-strategy.md` and `starshine-hot-ir-strategy.md` into detailed maintenance pages instead of short orientation notes.
- Captured the exact WAT families, the actual helper ownership map in `simplify_locals.mbt` and `pass_manager.mbt`, the raw skip-reason taxonomy, and the dated artifact hotspot/frontier status that had previously only lived in backlog notes.
- Updated the pass-folder catalog and root wiki index so the full simplify-locals dossier is discoverable from the shared wiki entrypoints.

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

## [2026-04-14] maintain | split slow simplify-locals multivalue perf stress out of the default package lane

- Moved the slowest synthetic `simplify-locals` multivalue perf witnesses into a dedicated package lane at `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt` so `moon test src/passes` stays a fast default edit-loop command.
- Trimmed the default `src/passes/perf_test.mbt` multivalue ladder sizes down to the smaller witnesses needed for the normal raw-skip / no-lift assertions and removed the irreducibly slow flat-dense stress case from that default package file.
- Updated the simplify-locals validation, implementation-map, and performance-frontier wiki pages so the docs now distinguish between the lean default package lane and the explicit opt-in command `moon test src/passes_perf_long`.

## [2026-04-14] validate | rerun simplify-locals native parity lanes after test cleanup

- Repaired the current simplify-locals branch surface until `moon test src/passes`, `moon test src/cmd`, and `moon test src/passes_perf_long` all passed again, including the simplify-locals raw-lane hookup, lowered nop preservation, dead control-owner rehoming, and the stale tuple / HSO / precompute expectation updates needed for the current kept outputs.
- Reran the native-binary simplify-locals compare-pass lane at `.tmp/pass-fuzz-sl-current-2026-04-14`; it finished at `10000/10000` compared cases with `10000` normalized matches and `0` mismatches.
- Reran the native-binary debug-artifact self-opt compare at `.tmp/self-opt-sl-current-2026-04-14`; it is now canonically green on the checked-in artifact (`normalizedWatEqual=true`, `canonicalFuncPrettyEqual=true`, no differing function indices) while still recording a large runtime gap and raw text / wasm inequality versus Binaryen.
- Updated the simplify-locals parity, validation, and performance-frontier pages so the wiki now treats the old `Func 71` first-diff story as historical context and the current live debt as runtime plus raw artifact canonicalization.

## [2026-04-18] maintain | compact wiki entrypoints and ingest current O4z plus CLI startup audits

- Added `binaryen/passes/late-pipeline-dispatch.md` from archived audits `0080` and `0093` as the compact current note for the `-O4z` / `shrink` tail roster, the module-vs-hot split, and the latest ordered `cmd.wasm` audit summary.
- Threaded the 2026-04-18 ordered-audit follow-up into `docs/wiki/binaryen/passes/remove-unused-brs/parity.md`, `docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/binaryen/passes/precompute/index.md`, and `docs/wiki/binaryen/passes/vacuum/index.md`, plus the matching active slice in `agent-todo.md`, so the slot-specific corruption notes and cleanup checklist stay surfaced in the living docs.
- Added `tooling/cli-startup-path.md` from `0092` as the compact startup-path note, explicitly marking the older registry/help/config concerns as superseded while keeping path normalization and bucketed glob scanning as the live follow-up surface.
- Shortened the root wiki catalog entries in `docs/wiki/index.md` and the Binaryen pass-folder map in `docs/wiki/binaryen/passes/index.md` so the entrypoints point at the detailed pages instead of re-listing their full rosters.
