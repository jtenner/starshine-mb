# Agent Tasks

## Scope
- Keep only active unreleased work or explicitly deferred future work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Move completed work and historical evidence to the relevant docs/wiki page, release notes, or git history.

## Current Parity Focus
- Keep the Binaryen no-DWARF default optimize path as the v0.1.0 parity target.
- Canonical order and nested-shape notes live in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` and `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`.
- Prefer direct-pass semantic parity first, then ordered-neighborhood replay, then preset scheduling.
- Do not widen public `optimize` / `shrink` slots until the surrounding Binaryen neighborhood is representable and oracle-proven.

## v0.1.0 Active Slices

### O4z debug startup recovery

- [O4Z-STARTUP]001 - Reduced Startup Map Init Trap
  - Status: smoke-green on 2026-06-02; keep only follow-up hardening here until a full-suite signoff or smaller artifact-generation fixture replaces the integration-shaped guard.
  - Goal: keep the repaired debug-WASI artifact/reduced fixture and conservative pass guards from regressing while broader self-optimized spec coverage is scheduled.
  - Why: the original stale artifact trap was repaired by regenerating the committed debug-WASI artifact and reduced fixture from the current correct `$moonbit.malloc` shape. Subsequent full self/debug `-O4z` prefix probes exposed optimizer owners that are now guarded conservatively: `ssa-nomerge` nested-control liveness, `optimize-instructions` commutative canonicalization, `simplify-locals-nostructure` local.tee/load sinking, `coalesce-locals` loop/structured-local.tee coalescing, and `vacuum` branchy structured write cleanup.
  - Durable evidence: `docs/wiki/raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`.
  - Remaining follow-ups:
    - [ ] Keep `tests/repros/o4z-debug-startup-map-init-repro.wasm` as the focused repro until a smaller source/build-artifact fixture replaces it.
    - [ ] Recover optimization precision one pass at a time only with focused tests and semantic evidence: nested SSA liveness, safe commutative operand ordering, local.tee-aware simplify-locals sinking, path-sensitive coalesce-locals, and branchy structured vacuum cleanup.
  - Suggested tests: `moon fmt`, `moon test src/passes`, `moon build --target native --release src/cmd`, `bun test scripts/lib/o4z-debug-startup-map.test.ts`, `wasm-tools validate --features all tests/repros/o4z-debug-startup-map-init-repro.wasm`, `wasm-tools validate --features all .tmp/o4z-bench/starshine-o4z-candidate.wasm`, and the self-optimized spec smoke commands listed in the research note.

### json-as debug artifact triage

- [JSON-AS]001 - `remove-unused-brs` corrupts AssemblyScript incremental-GC loop exits
  - Status: fixed for the 2026-06-05/2026-06-06 runtime and direct-compare evidence; keep only artifact/preset follow-ups elsewhere.
  - Goal: make `remove-unused-brs` preserve normal loop fallthrough exits when stripping tail branches/returns from nested regions.
  - Why: a fresh git clone of `JairusSW/json-as` at `f707d68d5ce5136ecfd0c576140421286c9e93a8`, built with AssemblyScript `0.28.17`, produced a valid Starshine output that traps at runtime. Prefix bisection of `medium.bench.incremental.naive.debug.wasm` found the first failing optimize prefix at slot 8: `memory-packing -> once-reduction -> global-refining -> global-struct-inference -> ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-brs`. Prefix 7 ran successfully; prefix 8 trapped in `~lib/rt/itcms/step` / `~lib/rt/itcms/interrupt` / `~lib/rt/itcms/__new` during benchmark startup.
  - Finding: in `~lib/rt/itcms/step`, `remove-unused-brs` rewrote a loop whose `obj == toSpace` arm normally falls out of the loop into a shape where that fallthrough path reaches `unreachable`. This is a true semantic mismatch, not representation drift or a validation issue. 2026-06-05 follow-up added reduced guards for this loop-fallthrough rotation and for HOT stack/local-set writeback hazards found in the same prefix: stack-style tail returns/branches and result/root regions mixing `local.set` with calls or memory copies/fills can be semantically re-associated by HOT lowering after any RUB mutation, so RUB now conservatively skips those shapes. A later follow-up widened the RUB stack/local-set guard to void root regions after `dumpToFile` showed the same HOT lowering reassociation corrupting the file-name string; medium-naive prefixes 8, 9, and 11 now validate and complete the Node runtime smoke.
  - Deliverables:
    - [x] Add a focused regression fixture for the `itcms.step` loop shape: conditional loop body where one arm updates state and branches back, while the other arm falls through normally.
    - [x] Guard `remove_unused_brs_try_strip_tail_if_exits` / `remove_unused_brs_strip_tail_control` so branch-to-loop-tail rewrites do not turn legitimate loop exits into `unreachable`.
    - [x] Replay the `json-as` medium-naive prefix 8 artifact and require it to run under the Node benchmark runner before re-enabling this shape. 2026-06-05 latest replay validates and completes both serialize and deserialize under Node; prefix 9 (`+ remove-unused-names`) and prefix 11 (`+ vacuum + remove-unused-brs`) also completed after the vacuum guard in `[JSON-AS]002`.
    - [x] Refresh direct `--remove-unused-brs` compare evidence and classify any remaining mismatches separately from this artifact trap. 2026-06-06 command `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-branch-heavy-fix2-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `6768/10000`: `3847` normalized matches, `2921` cleanup-normalized matches, `0` mismatches, `20` Binaryen/tool command failures. Agent classification: residual cleanup-normalized branch/unreachable wrappers are semantic-safe/size-winning for Starshine, not the json-as loop-exit corruption family.
  - Suggested tests: focused `src/passes/remove_unused_brs*_test.mbt`, `moon test src/passes`, `moon build --target native --release src/cmd`, direct `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --count 1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`, and a cloned `json-as` replay of the prefix listed above.

- [JSON-AS]002 - `vacuum` after repeated `remove-unused-names` corrupts json-as debug runtime state
  - Status: active correctness blocker found after removing all `remove-unused-brs` slots from the same 2026-06-05 `json-as` preset replay.
  - Goal: identify whether `vacuum`, `remove-unused-names`, or HOT lowering/splice cleanup corrupts stack/object state when `vacuum` cleans the post-`remove-unused-names` artifact.
  - Why: with all `remove-unused-brs` slots removed, `medium.bench.incremental.naive.debug.wasm` still failed. The first failing prefix was `memory-packing -> once-reduction -> global-refining -> global-struct-inference -> ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-names -> vacuum`. Prefix 8 ran repeatedly; prefix 9 serialized once and then failed during GC with `abort: Index out of range in ~lib/rt.ts:21`, followed by an `unreachable` in `~lib/rt/__typeinfo`, reached from `~lib/rt/itcms/Object#get:isPointerfree`, `Object#makeGray`, `__visit`, and `Array<RecentActivity>#__visit`.
  - Finding: the printed prefix-8-to-prefix-9 diff mostly shows removal of `const; drop` debris, but several array constructor / setter / assertion functions also show stack/local traffic moving around stores. The module validates, so the actionable issue is a runtime semantic corruption in cleanup or lowering, not malformed wasm. 2026-06-05 follow-up found the vacuum mutation itself was small, but HOT lowering after vacuum reassociated root stack values across `local.set` / call sequences in array constructors and setters; vacuum now conservatively skips root regions that mix root `local.set` with stack-effecting calls or memory copies/fills. The no-RUB prefix 9 and normal prefix 10 now validate and complete the medium-naive Node smoke.
  - Deliverables:
    - [x] Minimize the no-`remove-unused-brs` prefix-9 failure into a smaller WAT or wasm repro that still reaches the `~lib/rt/__typeinfo` abort. The committed regression is a focused root stack/local-set call-hazard skip; the artifact diff family was array constructor / setter stack reassociation after trivial cleanup.
    - [x] Audit `vacuum` region splicing and dead-root deletion around stack-producing locals and stores; confirm whether the suspicious array constructor / `#__set` reorderings are semantic changes or printer/lowering artifacts. The suspicious `local.set` movement was a HOT lowering semantic change triggered by vacuum mutation, not a validation issue.
    - [ ] Add a focused regression before changing behavior; prefer a fixture that exercises `const; drop` cleanup adjacent to array allocation, write barriers, and GC visits. 2026-06-05 direct `vacuum` refresh attempts (`--count 1000` then `--count 100`, seed `0x5eed`, out dirs `.tmp/pass-fuzz-vacuum-refresh-1000` and `.tmp/pass-fuzz-vacuum-refresh-100`) timed out before summary emission; the shorter run wrote `16` mismatch dirs before a 300s timeout. Sampled case `case-000002-gen-valid` is agent-classified as semantic-safe but size/representation-losing constant-if cleanup (`if (i32.const 1/0)` preserved by Starshine vs Binaryen's simplified block/empty form), not the json-as stack/local-set call-hazard family. The timeout itself remains a harness/pass-performance follow-up.
    - [x] Replay the no-`remove-unused-brs` prefix after the fix and require the medium-naive benchmark to complete. 2026-06-05 replay command validated and completed serialize plus deserialize under Node.
  - Suggested tests: focused `src/passes/vacuum*_test.mbt` or pass-manager prefix fixture, `moon test src/passes`, `moon build --target native --release src/cmd`, and cloned `json-as` prefix replay without `remove-unused-brs` slots.

- [JSON-AS]005 - `simplify-locals-nostructure` corrupts json-as medium-naive after prefix 16
  - Status: fixed for the 2026-06-05 medium-naive prefix-17 replay and covered by the later full O4 smokes.
  - Goal: make the post-`tuple-optimization` `simplify-locals-nostructure` slot preserve string/object state before resuming full O4 smoke.
  - Why: after RUB prefix 8/11 and vacuum prefix 10 were smoke-green, the first failing medium-naive prefix became slot 17: `... -> code-pushing -> tuple-optimization -> simplify-locals-nostructure`. Prefix 16 completed under Node; prefix 17 validated but trapped before benchmark output with `RuntimeError: memory access out of bounds` in `~lib/rt/common/OBJECT#get:rtSize`, called from `~lib/string/String.UTF8.byteLength`, `assembly/__benches__/lib/bench/utf8ByteLength`, and `start:assembly/__benches__/medium.bench`.
  - Finding: the first HOT guard left raw/lowered `simplify-locals-nostructure` cleanup active. That cleanup removed stack-root `local.tee` / local traffic in functions that also contained calls or memory-copy/fill hazards, including the huge benchmark start function. A pass-manager raw/lowered no-structure guard now skips those stack-effect/local-write cleanup families; `prefix-17-fixed1.wasm` validates and completes the Node serialize+deserialize smoke.
  - Deliverables:
    - [x] Minimize the prefix-17 failure to raw/lowered no-structure cleanup preserving stack-root call hazards.
    - [x] Add a focused regression before changing behavior (`pass_manager_wbtest.mbt` lowered cleanup stack-root call hazard).
    - [x] Replay medium-naive prefix 17 under Node after the fix. 2026-06-05 replay completed serialize and deserialize.
    - [x] Resume full O4 smoke for medium-naive, medium-simd, and large-swar after the next `simplify-locals` prefix blocker is fixed. 2026-06-05 rebuilt standard `*.starshine-o4.wasm` artifacts with `--traps-never-happen --closed-world --optimize -O4`; all three validated and completed Node serialize/deserialize smoke.
  - Suggested tests: focused pass-manager/simplify-locals tests, `moon test src/passes`, `moon build --target native --release src/cmd`, and cloned `json-as` prefix/full O4 runtime smokes.

- [JSON-AS]006 - `simplify-locals` corrupts json-as medium-naive after local-cse
  - Status: fixed for the no-HSO prefix-26 replay on 2026-06-05 and covered by the later full O4 smokes.
  - Goal: make the later full `simplify-locals` slot preserve string/object state after `local-cse` so full O4 runtime smoke can proceed.
  - Why: after prefix 17 was fixed, medium-naive prefixes through `local-cse` completed under Node. The next failing no-HSO ordered prefix was slot 26: `... -> coalesce-locals -> local-cse -> simplify-locals`. The first validating output trapped with `RuntimeError: memory access out of bounds` in `~lib/rt/common/OBJECT#get:rtSize`, called from `assembly/index/JSON.__serialize<~lib/string/String>`, `UserPreferences#__SERIALIZE`, `serializeStruct<UserPreferences>`, and the benchmark start function. After the global-delta guard, prefix 26 reached benchmark execution and then trapped during allocation in `~lib/rt/itcms/Object#get:nextWithColor` from `~lib/rt/itcms/__new`.
  - Finding: `simplify-locals` was moving global-derived delta reads across realloc-style calls; a focused regression now keeps `global.get offset` before the call and the pass guards large raw `simplify-locals` functions that mix local writes, stack effects, and global state. A second allocator subfamily came from large local-tee/memory-write functions such as TLSF `removeBlock`: dropping the stack-root tee before a later local read left allocator bitmap state stale. Large `simplify-locals` functions that combine local tees with memory writes now skip the hazardous rewrite family; `prefix-26-fixed4.wasm` validates and completes medium-naive serialize plus deserialize under Node.
  - Deliverables:
    - [x] Diff the initial prefix-25/26 artifacts for stack functions `100`, `105`, `218`, `219`, `220`, and `264`, and isolate the global-delta/realloc ordering issue.
    - [x] Add a focused regression before changing `simplify-locals` behavior (`simplify-locals keeps global delta reads before realloc calls`).
    - [x] Diff the remaining prefix-25/fixed-prefix-26 allocator changes, starting with TLSF/RT functions `12`, `13`, `14`, `19`, `20`, `21`, `22`, `92`, `96`, and `97`.
    - [x] Replay prefix 26 under Node after the allocator subfamily fix, then continue ordered-prefix bisection. 2026-06-05 replay of `prefix-26-fixed4.wasm` completed serialize and deserialize.
  - Suggested tests: focused `src/passes/simplify_locals*_test.mbt` or pass-manager whitebox coverage, `moon test src/passes`, `moon build --target native --release src/cmd`, and cloned `json-as` prefix replay under Node.

- [JSON-AS]007 - `merge-blocks` corrupts json-as medium-naive after prefix 26
  - Status: fixed for the no-HSO prefix-27 replay and full medium/large O4 smokes on 2026-06-05.
  - Goal: make the next no-HSO ordered prefix, `... -> simplify-locals -> merge-blocks`, preserve string serialization state before continuing O4 bisection.
  - Why: `prefix-26-fixed4.wasm` validates and completes the Node benchmark, but adding the next no-HSO pass (`merge-blocks`) produces a validating module that fails the medium benchmark assertion. Serialized strings gain an extra leading quote (for example `"jairus` instead of `jairus`) and then trap at `Expectation#toBe<~lib/string/String>`.
  - Finding: prefix-26/fixed-prefix-27 diffs showed `merge-blocks` flattening the block wrapper around the string serializer loop in `JSON.__serialize<~lib/string/String>` plus similar buffer growth / `heap.realloc` wrappers in serializer helpers. Removing that loop wrapper changed the lowered stack/control shape enough to copy the opening quote into string payload output. `merge-blocks` now conservatively preserves block roots whose body contains a loop; `prefix-27-fixed1.wasm` and all later no-HSO prefixes through directize validate and complete Node smoke.
  - Deliverables:
    - [x] Diff and reduce the prefix-26/fixed-prefix-27 `merge-blocks` changes, starting with functions `101`, `214`, `219`, `223`, and `226`.
    - [x] Add a focused `merge-blocks` regression before changing behavior (`merge-blocks preserves loop wrapper blocks with continue targets`).
    - [x] Replay no-HSO prefix 27 under Node after the fix, then continue ordered-prefix bisection. Prefixes 27 through 37 completed under Node.
  - Suggested tests: focused `src/passes/merge_blocks*_test.mbt`, `moon test src/passes`, `moon build --target native --release src/cmd`, and cloned `json-as` prefix replay under Node.

- [JSON-AS]003 - Optimize preset misses Binaryen O4 function/type cleanup on json-as debug artifacts
  - Status: active optimization-parity gap; do not widen the preset until `[JSON-AS]001` and `[JSON-AS]002` are fixed or safely gated.
  - Goal: close the largest size gaps against standard Binaryen `wasm-opt -O4` for `json-as` debug artifacts after correctness is restored.
  - Why: on `medium.bench.incremental.naive.debug.wasm`, Starshine reduced data and globals but left many functions/types alive. Size and section evidence from the 2026-06-05 replay: debug `222187` bytes / `276` functions / `29` types / `128` globals; fixed Starshine `--optimize -O4` `168807` bytes / `276` functions / `29` types / `38` globals; Binaryen O4 `110359` bytes / `85` functions / `17` types / `36` globals. Starshine matched Binaryen's data-section payload (`25312` bytes) but missed most function/type cleanup; the remaining size includes both live code and separate `StripDebug` custom-section bytes tracked by `[JSON-AS]008`.
  - Finding: 2026-06-05 investigation under `.tmp/json-as/build/starshine-vs-binaryen/investigation-o4-live/` shows `remove-unused-module-elements` is not the primary blocker: rerunning it after the fixed Starshine O4 output leaves medium-naive at `276` functions, and the visible roots are only five function exports plus a two-function active element segment and no start section. `duplicate-function-elimination` is a safe missing preset contributor (`optimize + duplicate-function-elimination + remove-unused-module-elements` passed Node smoke and originally reduced functions to `221` / `224` / `263` for medium-naive / medium-simd / large-swar) but does not reduce types. A 2026-06-05 DFE fixed-point widening, guarded by `duplicate-function-elimination reaches fixed point when callee dedup unlocks more duplicates`, improves that same lane to `211` / `214` / `261` functions with Node smoke and validation, reaching a modest additional code-section win while preserving the larger remaining Binaryen gap; direct `duplicate-function-elimination` 10000-case compare on 2026-06-06 is normalized-green (`6768` compared, `6768` normalized, `0` mismatches, `20` Binaryen/tool command failures). Plain `inlining + remove-unused-module-elements` removes most functions and passed Node smoke, but is size-losing on these artifacts. `inlining-optimizing` and `inlining-optimizing + dae-optimizing + duplicate-function-elimination + remove-unused-module-elements` originally got close to Binaryen function/type counts (`85` / `86` / `80` functions and `19` types in the three-artifact run) but validate-only outputs trapped under the Node runner with memory-access OOB. A 2026-06-05 correctness guard now skips the optimizing nested-cleanup suffix and final local cleanup on large modules (`>80` defined functions), so direct `inlining-optimizing --remove-unused-module-elements` and `--optimize --inlining-optimizing --remove-unused-module-elements` validate and complete Node smoke on medium-naive, medium-simd, and large-swar. This is a conservative correctness recovery, not a full inlining-derived size signoff: medium-naive / medium-simd / large-swar `opt+inlining-optimizing+rume` sizes are `174958` / `177455` / `396110`, with functions `93` / `94` / `85`, and the direct 1000-case compare still stops at the mismatch cap (`52` compared, `26` normalized matches, `26` mismatches, `1` Binaryen rec-group-zero command failure). Sampled mismatches are agent-classified as semantic-safe/size-winning Starshine cleanup of generated `const; drop` and empty-else/nop debris that Binaryen leaves, but they need a focused normalization/classification follow-up before closing `[O4Z-AUDIT-INL]`. The direct `dae-optimizing` medium-naive invalid-local validation failure was fixed on 2026-06-05 by making the selected Func237 raw-debris cleanup use the current function signature when trimming locals; direct `dae-optimizing` now validates and passes Node smoke on medium-naive, medium-simd, and large-swar, with 10000-case compare normalized-green (`6766` compared, `0` mismatches, `20` Binaryen/tool command failures: rec-group-zero/bad-section-size/table-index/tag-index). Do not schedule inlining-derived lanes for size until their direct compare mismatches and skipped large-module cleanup owners are separately closed.
  - Follow-up evidence: 2026-06-05 post-DFE probes found two unscheduled direct hot passes with small but safe-looking json-as size wins; the refreshed 2026-06-06 analysis, commands, section table, and scheduling recommendation are preserved in `docs/wiki/raw/research/0713-2026-06-06-jsonas-dfe-cf-rse-preset-analysis.md`. Summary: `--code-folding --redundant-set-elimination --remove-unused-module-elements` after `optimize + duplicate-function-elimination + remove-unused-module-elements` validated and passed Node smoke on all three artifacts, reducing medium-naive / medium-simd / large-swar sizes to `152271` / `157841` / `357830` and code payloads to `126181` / `132972` / `315404`; 1000-case compare probes for each pass were normalized-green (`998` compared, `0` mismatches, `2` Binaryen rec-group command failures); direct `code-folding` 10000-case compare on 2026-06-06 is also normalized-green (`6761` compared, `6761` normalized, `0` mismatches, `20` Binaryen/tool command failures), and direct `redundant-set-elimination` 10000-case compare is normalized-green after the 2026-06-06 loop-entry default reset fix (`6771` compared, `6771` normalized, `0` mismatches, `20` Binaryen/tool command failures). The fix keeps raw RSE from treating default writes inside loops as redundant when the loop-entry value may differ; it repaired the restored `medium.bench.incremental.simd.wasm` `opt+dfe+rume+rse+rume` and `opt+dfe+rume+cf+rse+rume` Node smoke. A follow-up restored-example lane after the fix validated and Node-smoked `opt+dfe+rume+cf+rse+rume` outputs for `medium.bench.incremental.naive.wasm`, `medium.bench.incremental.simd.wasm`, and `large.lazy.bench.incremental.swar.wasm`; those checked-in example inputs are already optimized, so this evidence is runtime-correctness only, not size-win evidence. `merge-locals` originally validated but trapped under Node on medium-naive in this same suffix position; a 2026-06-05 fix now clears raw local-copy aliases across structured control so copies before loops/blocks cannot retarget later source reads after nested destination writes. The `opt+dfe+rume+merge-locals+rume` lane now validates and completes Node smoke on medium-naive / medium-simd / large-swar (`152693` / `158266` / `358874` bytes; `211` / `214` / `261` functions), and direct `merge-locals` 10000-case compare is normalized-green (`6769` compared, `0` mismatches, `20` Binaryen/tool command failures: rec-group-zero/bad-section-size/table-index/tag-index). `simplify-locals-notee-nostructure` originally validated but trapped under Node on medium-naive in the same suffix position; a 2026-06-05 large-module guard (`>100` defined functions) now skips that direct pass on artifact-sized modules until its precise large-function hazard is reduced. The `opt+dfe+rume+simplify-locals-notee-nostructure+rume` lane now validates and completes Node smoke on medium-naive / medium-simd / large-swar (`152693` / `158266` / `358874` bytes; `211` / `214` / `261` functions), and direct `simplify-locals-notee-nostructure` 10000-case compare is normalized-green (`6764` compared, `0` mismatches, `20` Binaryen/tool command failures: rec-group-zero/bad-section-size/table-index/tag-index). Binaryen no-pass roundtripping of the Starshine `opt+dfe+rume+cf+rse` medium-naive output drops size `152271 -> 150331` and code `126181 -> 124241` without changing function/type counts, indicating a remaining encoder/canonical-structure/codegen-size gap separate from semantic optimization. A traced medium-naive `--optimize` run showed pass-local performance dominated by `simplify-locals` (`356569us` total, mostly `scan-root-region`) plus repeated hot lifting (`283080us`, `2956` lifts), while local Binaryen `wasm-opt --all-features -O4` wall time was faster in a 3-run median (`0.668s` vs Starshine optimize `0.863s`; Starshine optimize plus DFE/CF/RSE `1.165s`). Treat this as evidence for both cautious preset candidates and a hot-pass lifting/simplify-locals performance audit.
  - Current recommendation: `DFE + RUME + CF + RSE + RUME` is runtime-green and direct-pass-green as an incremental suffix candidate, but it should land only in a dedicated preset-widening slice with exact ordering tests, full gate evidence, and a decision about whether DFE's incidental name-section stripping is acceptable before explicit `[JSON-AS]008` `strip-debug`.
  - Deliverables:
    - [ ] Add preset placement for `duplicate-function-elimination`, `code-folding`, and `redundant-set-elimination` with exact-order tests, fresh `json-as` artifact validation/Node smoke, and the section metrics from research note `0713`.
    - [ ] Measure incremental contributions of `inlining`, `inlining-optimizing`, `dae-optimizing`, type cleanup / `remove-unused-types`, and function reordering/removal equivalents against the same `json-as` debug artifacts.
    - [ ] Add preset-order tests for any widened optimize/shrink slots; do not collapse repeated cleanup slots without Binaryen-neighborhood evidence.
    - [ ] Record size deltas by section (`types`, `functions`, `globals`, `code`, `data`) for medium-naive, medium-simd, and large-swar debug artifacts.
  - Suggested tests: `moon test src/passes`, `moon test src/cmd` for preset changes, `moon build --target native --release src/cmd`, direct pass compare for every newly scheduled pass, and cloned `json-as` Starshine-vs-Binaryen artifact size replay.

- [JSON-AS]008 - Implement `StripDebug` module pass for debug custom-section stripping
  - Status: active new-pass backlog item; not implemented yet.
  - Goal: add an explicit `strip-debug` / `StripDebug` module pass and schedule it in size/optimize paths only after direct-pass tests and artifact evidence.
  - Why: 2026-06-05 `json-as` size metrics showed Starshine O4 still carrying non-semantic `name` custom-section bytes in fixed standard artifacts while Binaryen O4 carried no custom sections. Current evidence: `medium.bench.incremental.naive.starshine-o4.wasm` has `14549` total custom-section bytes and `large.bench.incremental.swar.starshine-o4.wasm` has `15743`, all from the `name` custom section; `medium.bench.incremental.simd.starshine-o4.wasm` currently has `0`. This is a deterministic size gap independent of the deeper live-function/type cleanup gap.
  - Deliverables:
    - [ ] Add a TDD fixture that proves `StripDebug` removes structured `name_sec`, `raw_name_sec_payload`, and non-semantic debug custom sections while preserving semantic sections and validation.
    - [ ] Register the pass as a module pass, wire CLI/pass-manager dispatch, and expose the canonical pass spelling expected by Starshine/Binaryen compare tooling.
    - [ ] Decide preset placement after direct pass evidence; likely a late `optimize` / `shrink` slot after passes that may use names for diagnostics or extract helpers.
    - [ ] Re-measure `json-as` custom-section deltas after implementation; expected immediate wins are about `14.5KB` on medium-naive and `15.7KB` on large-swar before addressing remaining function/type cleanup.
  - Suggested tests: focused `src/passes/strip_debug*_test.mbt`, `moon test src/passes`, `moon test src/cmd` if CLI/help changes, `moon build --target native --release src/cmd`, direct `--strip-debug` compare evidence, `wasm-tools validate --features all` on rewritten `json-as` artifacts, and Node runtime smoke for the three fixed `json-as` cases.

- [JSON-AS]004 - Keep a cloned json-as benchmark replay for optimizer artifact signoff
  - Status: active artifact-signoff follow-up; 2026-06-06 full `as-test` suite replay is Starshine-green for the pinned clone but not yet scripted as a durable repo task.
  - Goal: make the `json-as` debug-artifact comparison repeatable without relying on temporary restored wasm files under `examples/`.
  - Why: the restored example wasm files were already heavily optimized and made Starshine look size-regressive. A fresh git clone of `json-as` at `f707d68d5ce5136ecfd0c576140421286c9e93a8`, local `bun install`, `assemblyscript@0.28.17`, and `bun run build:transform` produced debug artifacts where Binaryen O4 runs successfully and Starshine currently validates but traps. The clone path used during triage was `.tmp/json-as`, which is intentionally not durable. On 2026-06-06, the stronger suite replay built all 105 configured `as-test` wasm artifacts (`35` specs across `naive`, `swar`, and `simd`) with a Node WASI runner, optimized them with current Starshine `--traps-never-happen --closed-world --optimize -O4`, validated every output with `wasm-tools validate --features all`, and ran the full suite successfully: `35` files, `1284` suites, `10656` tests, `3` modes, `0` failures. The comparable Binaryen `wasm-opt --all-features --traps-never-happen --closed-world -O4` suite replay also passed. Starshine suite outputs total `57,167,519` bytes versus Binaryen `44,705,784` bytes (`+27.87%`), so correctness is ahead of size parity.
  - Runtime measurement note: without `d8`/`v8` available locally, the 2026-06-06 direct performance pass used the Node WASI test artifact runner as a proxy, not the official `json-as` benchmark harness. Two cold process runs per optimized suite artifact gave summed medians of Starshine `161,962.7ms` vs Binaryen `153,542.5ms` (`+5.48%` Starshine slower overall): `naive` `+17.73%`, `simd` `-0.48%`, `swar` `-0.69%`. Treat these as local artifact-runner timing evidence only; stable benchmark claims still require the real benchmark runtime.
  - Deliverables:
    - [ ] Add a documented, opt-in replay command or task that clones `json-as` into `.tmp/`, pins AssemblyScript `0.28.17`, builds `large` SWAR, `medium` NAIVE, and `medium` SIMD debug artifacts, and emits Starshine/Binaryen outputs without touching committed examples.
    - [x] Keep runtime execution separate from validation: validation alone missed earlier Starshine corruption. 2026-06-06 full-suite replay validated each optimized wasm and then executed the suite under the Node WASI runner.
    - [ ] Prefer the repo's `d8` runner when available; otherwise use a checked-in Node runner equivalent for local smoke comparisons.
    - [x] Capture Binaryen baseline runtime numbers as reference only, not as deterministic CI thresholds, unless a stable benchmark environment is added. 2026-06-06 Node WASI proxy timings are recorded in `.tmp/jsonas-suite-test/wasi-artifact-perf-summary.json` and summarized above.
  - Suggested tests: opt-in script/task dry run, `wasm-tools validate --features all` on all generated outputs, and runtime smoke under Node or `d8` for debug, Binaryen O4, and Starshine outputs.

### Whole-command wall-time budget

- [WALL]001 - Cross-Pass Runtime Budget And Attribution
  - Goal: own whole-command Starshine-vs-Binaryen wall-time measurement outside individual pass parity slices.
  - Why: direct pass slices may be signed off while aggregate preset or no-op command paths still hide parse/emit, validation, HOT lift/lower, cache, or buffering costs.
  - Current known target: isolate or guard `ssa-nomerge` on the large branchy Wast opcode parser function (`Func 2977`, `_M0MP37jtenner9starshine4wast10WastParser26parse__opcode__instruction`) before retrying full preset comparison; previous direct `--ssa-nomerge` artifact attempts timed out while Binaryen direct completed quickly.
  - Deliverables:
    - Separate pass-local runtime, harness/tool startup, parse/emit, validation, HOT lift/lower, analysis cache, and artifact representation costs.
    - Maintain a prioritized list of cross-cutting runtime fixes without blocking pass correctness signoff on aggregate wall time.
    - Evaluate remaining non-pass candidates such as encoder size/backpatch and code-section buffering reduction.
  - Suggested tests: focused timing traces, `moon info`, `moon fmt`, `moon test`, and targeted self-compare commands for any changed pass/tool path.

### O4z Per-Pass Deep Audits

Release gate: complete these before the v0.1.0 release so `-O4z` pass coverage is more comprehensive and pass-local runtime owners are known before publishing.

Use this checklist for every `[O4Z-AUDIT-*]` slice below:
- Start from the pass wiki page and owner source/test files; update docs if findings become durable.
- Run or refresh direct pass oracle evidence by building `src/cmd` once (`moon build --target native --release src/cmd`) and using `bun scripts/pass-fuzz-compare.ts --pass <name> --count 1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` first, then scale to 10000 only when changing behavior or closing the slice.
- Inspect tests for missing positive/negative shapes, add focused test-first fixtures for any bug or missed optimization, and keep validation failures separate from representation drift.
- Capture pass-local timing where available; file whole-command issues under `[WALL]001` unless the pass is clearly the owner.
- Replay the pass's `-O4z` slot/neighborhood when it has saved artifacts or documented generated-audit evidence.
- Close with an agent-classified findings note: bugs found/fixed, missing shapes added, performance owners, deferred risks, exact commands, counts, and artifact paths.

- [O4Z-AUDIT-SSA] - Deep audit `ssa-nomerge`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: HOT SSA construction/lowering without merges, phi copy placement, large branchy function runtime, local-name/type preservation, and Func2977-style wall-time ownership.
  - Deliverables: apply the common checklist; add reduced large-branch stress fixtures if needed; refresh direct compare and early `SSA` slot evidence; file pass-local runtime fixes here and whole-command residuals under `[WALL]001`.

- [O4Z-AUDIT-DCE] - Deep audit `dead-code-elimination`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: unreachable tails, dropped-value safety, structured-control result repair, EH/try_table behavior, writeback guards, raw-skip paths, and repeated cleanup interactions.
  - Deliverables: apply the common checklist; add missing dead-tail/control/EH fixtures; refresh direct compare and `DCE` slot evidence; classify Binaryen-shape differences as semantic, representation, or size tradeoffs.

- [O4Z-AUDIT-RUB] - Deep audit `remove-unused-brs`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: tail branch/return removal, branch-to-trap rewrite, value-if/select lowering, br_table labels, raw gate thresholds, and retired slot14/slot40 corruption families.
  - Deliverables: apply the common checklist; coordinate with `[AUDIT002-B]` through `[AUDIT002-E]`; refresh direct compare and all `RUB` slot evidence; measure pass-local impact of raw skip choices.

- [O4Z-AUDIT-OI] - Deep audit `optimize-instructions`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: exact peepholes, shift/compare/boolean rewrites, effect-aware folds, use-def/effects metadata, raw O4z slot16/slot44 predecessors, and pass-local runtime.
  - Deliverables: apply the common checklist; coordinate descriptor work with `[AUDIT001-A]`/`[AUDIT001-B]`; refresh direct compare and all `OI` slot evidence; classify any missed Binaryen folds by safety/effect reason.

- [O4Z-AUDIT-HSO] - Deep audit `heap-store-optimization`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: struct.new/struct.set folding, local escape analysis, effect ordering, GC descriptor/refinalization shapes, and allocation-heavy performance.
  - Deliverables: apply the common checklist; add missing GC/effect/escape fixtures; refresh direct compare and `HSO` slot evidence; record unsafe fold blockers separately from missed profitable folds.

- [O4Z-AUDIT-PC] - Deep audit `precompute`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit; branch-heavy direct compare blocker cleared on 2026-06-06, but the broader audit still needs the common checklist and O4z slot evidence.
  - Scope: constant folding, trap/effect preservation, raw precleaner/writeback guards, precompute-propagate prefix distinction, GC/array atomic exclusions, and O4z slot19/slot43 history.
  - Latest evidence: `.tmp/pass-fuzz-precompute-branch-heavy-slice4-norm4-10000` with `--normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris` compared `6769/10000`, normalized `3375`, cleanup-normalized `3394`, mismatches `0`, command failures `20` (Binaryen/tool decode classes). Branch-heavy constant-control drift is covered by focused raw cleanup and semantic-safe normalizer tests.
  - Deliverables: apply the common checklist; coordinate descriptor work with `[AUDIT001-E]`/`[AUDIT001-F]`; refresh all `PC` slot evidence; record missed folds versus deliberate trap/effect bailouts.

- [O4Z-AUDIT-CP] - Deep audit `code-pushing`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: safe local/global computation sinking, effect/trap boundaries, if/else arm use analysis, nested control, and tuple/local-cleanup neighborhood effects.
  - Deliverables: apply the common checklist; add missing push/bailout fixtures; refresh direct compare and `CP` slot evidence; classify downstream code-size wins and regressions.

- [O4Z-AUDIT-TO] - Deep audit `tuple-optimization`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: multivalue spill/copy splitting, passthrough chains, branch-exit carriers, local compaction, interaction with SLNS/RL/RUB, and candidate-heavy function runtime.
  - Deliverables: apply the common checklist; add missing tuple carrier fixtures; refresh direct compare and `TO` exact-slot neighborhood evidence; record any host-lane/local-map invariants clearly.

- [O4Z-AUDIT-SLNS] - Deep audit `simplify-locals-nostructure`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: no-structure local sinking, no-tee variant spelling, dead write cleanup, interaction with tuple/reorder/vacuum, and raw gate behavior.
  - Deliverables: apply the common checklist; add missing no-structure/no-tee fixtures; refresh direct compare and `SLNS` slot evidence; keep structure-producing rewrites out unless intentionally scheduled.

- [O4Z-AUDIT-VQ] - Deep audit `vacuum`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: nop/drop cleanup, explicit unreachable preservation, nested value-expression debris, empty if/block rewrites, repeated VQ slots, and retired slot23/slot33 histories.
  - Deliverables: apply the common checklist; add missing pure/nontrapping and control cleanup fixtures; refresh direct compare and all `VQ` slot evidence; measure cleanup value versus HOT traversal cost.

- [O4Z-AUDIT-RL] - Deep audit `reorder-locals`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: access-count sorting, zero-count truncation, parameter stability, local-name repair, multivalue scratch locals, TypeIdx invariant docs, and module-pass runtime.
  - Deliverables: apply the common checklist; coordinate invariant docs with `[AUDIT006-E]`; add missing reorder/name/multivalue fixtures; refresh direct compare and `RL` slot evidence.

- [O4Z-AUDIT-H2L] - Deep audit `heap2local`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: non-escaping struct locals, scalar field locals, null comparisons, GC type/refinalization, primary artifact fixtures, and heap-heavy function runtime.
  - Deliverables: apply the common checklist; add missing escape/null/field fixtures; refresh direct compare and `H2L` slot evidence; record memory and code-size effects.

- [O4Z-AUDIT-OC] - Deep audit `optimize-casts`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: ref.cast/ref.test/br_on_cast folding, descriptor casts, nullability trap preservation, local-subtyping neighborhood, and GC validation.
  - Deliverables: apply the common checklist; add missing cast/descriptor/nullability fixtures; refresh direct compare and `OC` slot evidence; classify any trap-mode-sensitive decisions.

- [O4Z-AUDIT-LS] - Deep audit `local-subtyping`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: local type refinement, write-site and join behavior, GC refs, call_ref and try_table shapes, interaction with optimize-casts/DAE, and validation refinalization.
  - Deliverables: apply the common checklist; add missing local-refinement fixtures; refresh direct compare and `LS` slot evidence; document conservative join/bailout policy.

- [O4Z-AUDIT-CL] - Deep audit `coalesce-locals`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: interference graph/coloring, local remap/name cleanup, TypeIdx invariant docs, copy-pair cleanup, and large-function coloring runtime.
  - Deliverables: apply the common checklist; coordinate invariant docs with `[AUDIT006-D]`; add missing interference/ref/name fixtures; refresh direct compare and `CL` slot evidence.

- [O4Z-AUDIT-LCSE] - Deep audit `local-cse`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit; 2026-06-04 focused audit evidence lives in `docs/wiki/raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md`.
  - Scope: local expression reuse, effect barriers, memory/table/global/call/EH/GC/SIMD shapes, module adapter behavior, and pass-local runtime.
  - Current finding: direct 2026-06-04 post-fix 10000-case compare was semantically green (`6768` normalized matches, `20` Binaryen/tool command failures, `0` mismatches); later return-boundary and `br_table` boundary coverage runs also stayed green (`6771` normalized matches each), the unreachable-boundary run stayed green (`6765` normalized matches), the `struct.new` generative-root run stayed green (`6769` normalized matches), the named-block positive fix stayed green (`6771` normalized matches), the `struct.new_default` generative-root run stayed green (`6764` normalized matches), the annotated idempotent-call fix stayed green (`6770` normalized matches), the `call_indirect` root coverage run stayed green (`6768` normalized matches), the core `call_ref` root coverage run stayed green (`6768` normalized matches), the core `array.new` generative-root run stayed green (`6770` normalized matches), the core `array.new_default` generative-root run stayed green (`6768` normalized matches), the core `array.new_fixed` generative-root run stayed green (`6771` normalized matches), the `try_table` body positive fix stayed green (`6767` normalized matches), and the `try_table` body unreachable-boundary coverage run stayed green (`6769` normalized matches), and the throw-boundary coverage run stayed green (`6769` normalized matches), the `br` boundary coverage run stayed green (`6770` normalized matches), the `return_call_indirect` unreachable-continuation positive fix stayed green (`6765` normalized matches), the `throw_ref` unreachable-continuation positive fix stayed green (`6768` normalized matches), and the core `return_call_ref` unreachable-continuation positive fix stayed green (`6771` normalized matches), the core `array.new_data` generative-root coverage run stayed green (`6767` normalized matches), the core `array.new_elem` generative-root coverage run stayed green (`6763` normalized matches), and the direct `return_call` unreachable-continuation positive fix stayed green (`6766` normalized matches), with `20` Binaryen/tool command failures and `0` mismatches in each run; the `rethrow` hard-boundary deferral lane stayed green (`6770` normalized matches), the `br_on_null` fallthrough-continuation positive fix stayed green (`6764` normalized matches), the `struct.set` local-only reuse fix stayed green (`6769` normalized matches), the `br_on_non_null` fallthrough-continuation positive fix stayed green (`6766` normalized matches), the `array.set` local-only reuse fix stayed green (`6768` normalized matches), and the `array.fill` local-only reuse fix stayed green (`6770` normalized matches), the `array.init_data` local-only reuse fix stayed green (`6769` normalized matches), the `array.init_elem` local-only reuse fix stayed green (`6769` normalized matches), the `memory.copy` local-only reuse fix stayed green (`6762` normalized matches), the `memory.fill` local-only reuse fix stayed green (`6769` normalized matches), the `memory.init` local-only reuse fix stayed green (`6769` normalized matches), the `memory.grow` local-only reuse fix stayed green (`6766` normalized matches), the `memory.size` coverage run stayed green (`6768` normalized matches), the `table.get` local-only reuse fix stayed green (`6764` normalized matches), and table-state invalidation coverage for `table.get` across `table.set` plus `table.size` across `table.grow` stayed green (`6770` normalized matches), and memory-size non-growing-effect precision across `memory.copy` / `memory.fill` / `memory.init` stayed green (`6770` normalized matches), and the pure `ref.eq` operator fix stayed green (`6769` normalized matches) after the intended TDD failure, and the integer comparison pure-operator fix stayed green (`6769` normalized matches) after the intended TDD failure, and the integer bit-operator pure fix stayed green (`6770` normalized matches) after the intended TDD failure, and the float pure-operator fix stayed green (`6772` normalized matches) after the intended TDD failure, and the `select` root coverage run stayed green (`6768` normalized matches), and the `ref.is_null` pure-root fix stayed green (`6772` normalized matches) after the intended TDD failure, and the nontrapping numeric conversion pure-root fix stayed green (`6764` normalized matches) after the intended TDD failure, and the sign-extension pure-root fix stayed green (`6768` normalized matches) after the intended TDD failure, and the narrow-load root fix stayed green (`6770` normalized matches) after the intended TDD failure, and the saturating-trunc pure-root fix stayed green (`6769` normalized matches) after the intended TDD failure, and integer equality/eqz coverage stayed green (`6772` normalized matches), and full-width non-`i32` load coverage stayed green (`6770` normalized matches), and float equality coverage stayed green (`6768` normalized matches), and the integer division/remainder deferral run stayed green (`6769` normalized matches), and the `ref.test` deferral run stayed green (`6768` normalized matches), the `table.copy` local-only reuse fix stayed green (`6771` normalized matches), the `table.fill` local-only reuse fix stayed green (`6766` normalized matches), the `table.init` local-only reuse fix stayed green (`6764` normalized matches), the `table.set` local-only reuse fix stayed green (`6766` normalized matches), the `table.grow` local-only reuse coverage run stayed green (`6767` normalized matches), the `table.size` local-only reuse fix stayed green (`6766` normalized matches), the `global.set` local-only reuse coverage run stayed green (`6768` normalized matches), the `data.drop` local-only reuse fix stayed green (`6768` normalized matches), the `elem.drop` local-only reuse fix stayed green (`6765` normalized matches), and the `br_on_cast` fallthrough-continuation positive fix stayed green (`6769` normalized matches), and the `br_on_cast_fail` fallthrough-continuation positive fix stayed green (`6766` normalized matches), and the `array.copy` local-only reuse fix stayed green (`6770` normalized matches), and unrelated `local.set` / `local.tee` write precision now keeps local-only expressions reusable while preserving write-to-read-local invalidation, and ordinary direct-call barriers now retain only local-only candidates while still excluding call roots and global-dependent expressions; `call_indirect` and `call_ref` local-only reuse remain documented conservative boundaries rather than adding indirect/reference-call effect, table, or callee reasoning. Debug-WASI pass-local timing still cleared the 2x Binaryen budget after the before-`if` into `then` reuse fix.
  - Deliverables: apply the common checklist; keep the covered before-`if`/then, before-block/straight-line-block, before-`try_table`/try-body, and annotated idempotent direct-call positives, ordinary direct-call, `call_indirect`, and `call_ref` root no-ops, after-`if` and else-arm negatives, before-loop/loop-body, return-boundary, throw-boundary, `br`/`br_table` boundaries, top-level unreachable-boundary, and `try_table` body unreachable-boundary negatives, tiny-root repeated-`global.get` no-op, and repeated `struct.new` / `struct.new_default` / `array.new` / `array.new_default` / `array.new_fixed` / `array.new_data` / `array.new_elem` generative-root negatives green; add remaining GC/generative-root variants where local syntax and core fixtures can model Binaryen safely; keep the covered `return_call`, `return_call_indirect`, `return_call_ref`, and `throw_ref` unreachable-continuation positives plus the `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` fallthrough-continuation and `struct.set` / `array.set` / `array.fill` / `array.copy` / `array.init_data` / `array.init_elem` / `memory.copy` / `memory.fill` / `memory.init` / `memory.grow` / `memory.size` including non-growing-effect precision / `table.get` plus table-state mutation no-reuse guards / `table.copy` / `table.fill` / `table.init` / `table.set` / `table.grow` / `table.size` / `global.set` / `data.drop` / `elem.drop` local-only reuse positives green rather than classifying them as hard-boundary negatives; keep integer division/remainder, trap-sensitive trunc conversions, `ref.test`/cast/descriptor reasoning, and broad heap reasoning documented as conservative deferrals unless separately approved; keep the legacy `rethrow` hard-boundary finding documented as a local raw-surface deferral until a distinct `Rethrow` instruction exists; coordinate shape tests with `[AUDIT004-J]`/`[AUDIT004-K]`; classify missed CSE opportunities by barrier type.
  - 2026-06-05 continuation evidence: trap-sensitive scalar trunc conversion roots (`i32.trunc_f32_s`, `i64.trunc_f64_u`), standard `ref.cast` roots, `ref.as_non_null` nullability roots, reference conversion roots (`any.convert_extern` / `extern.convert_any`), descriptor read roots (`ref.get_desc`), repeated `ref.null` roots, repeated `string.const` roots, repeated `ref.func` roots, string new-array roots (`string.new_utf8_array` / `string.new_wtf16_array` / `string.new_lossy_utf8_array` / `string.new_wtf8_array`), string encode-array roots (`string.encode_utf8_array` / `string.encode_wtf16_array` / `string.encode_lossy_utf8_array` / `string.encode_wtf8_array`), `i31.get_s` / `i31.get_u` roots (with `ref.i31` deferred on non-null temp-local safety), repeated `struct.get` / `array.get` heap-read roots, repeated `array.len` roots, packed heap-read roots (`struct.get_s` / `struct.get_u` / `array.get_s` / `array.get_u`), descriptor allocation roots (`struct.new_desc` / `struct.new_default_desc`), linear atomic operations including load width variants, store width variants, RMW op/width variants, wait/notify/fence, cmpxchg roots, and cmpxchg width variants, packed shared-GC atomic roots (`struct.atomic.get_s` / `struct.atomic.get_u`), tiny SIMD pure roots (`v128.not`, `i8x16.eq`) plus wider SIMD arithmetic/logic roots, extended SIMD integer arithmetic roots, SIMD float min/max roots, SIMD comparison roots, SIMD float rounding roots, SIMD widening/narrowing roots, SIMD conversion roots, relaxed SIMD roots, SIMD splat roots, SIMD replace-lane roots, SIMD shuffle/swizzle roots, SIMD any-true/all-true/bitmask roots, and SIMD lane-extract roots, repeated SIMD load roots (`v128.load`), repeated SIMD load-splat/load-zero roots (`v128.load8_splat`, `v128.load16_splat`, `v128.load32_splat`, `v128.load64_splat`, `v128.load32_zero`, `v128.load64_zero`), repeated SIMD load-extend roots (`v128.load8x8_s`, `v128.load8x8_u`, `v128.load16x4_s`, `v128.load16x4_u`, `v128.load32x2_s`, `v128.load32x2_u`), repeated SIMD lane-load roots (`v128.load8_lane`, `v128.load16_lane`, `v128.load32_lane`, `v128.load64_lane`), local-only reuse across SIMD stores (`v128.store`, `v128.store8_lane`, `v128.store16_lane`, `v128.store32_lane`, `v128.store64_lane`), and local-only reuse across `struct.atomic.get` are now covered as conservative documented deferrals after Binaryen spot-checks materialized representative repeats; descriptor `ref.test_desc` / `ref.cast_desc_eq` roots have core-built deferral coverage because the installed external WAT/Binaryen oracle rejected the descriptor text fixture; descriptor allocation roots have core-built deferral coverage because the installed Binaryen oracle asserted on the descriptor allocation text fixture.
  - Remaining closure slices:
    - [ ] `[O4Z-AUDIT-LCSE-CLOSE]001` Final clean-worktree signoff. Goal: rerun the standard LCSE ladder after unrelated inlining/script/example-artifact dirt is either committed elsewhere or absent from the worktree. Commands: `moon info` (record the known panic if it recurs), `moon fmt`, focused `moon test --package jtenner/starshine/passes --file local_cse_test.mbt`, `moon test src/passes`, full `moon test`, `moon build --target native --release src/cmd`, and 10000-case direct `local-cse` compare with `--jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`. Exit criteria: `0` LCSE mismatches; known Binaryen/tool command failures classified separately; unrelated pass failures not counted as LCSE signoff.
    - [ ] `[O4Z-AUDIT-LCSE-CLOSE]002` Closure inventory update. Goal: add a final summary to `docs/wiki/raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md`, `docs/wiki/binaryen/passes/local-cse/starshine-strategy.md`, and `docs/wiki/log.md` that distinguishes implemented positives from accepted conservative deferrals. Include the exact final compare output directory and command-failure classes.
    - [ ] `[O4Z-AUDIT-LCSE-CLOSE]003` Accepted conservative drift record. Goal: keep `rethrow`, `call_indirect` local-only reuse, `call_ref` local-only reuse, trap-sensitive truncs, div/rem, `ref.test`/`ref.cast`/`ref.as_non_null`, reference conversions, descriptor reasoning, `ref.i31`, string roots, heap reads/`array.len`, GC allocation roots, atomics, SIMD roots/loads/stores, arbitrary memory/table/segment GVN, arbitrary call CSE, throwing-root CSE, and CFG-wide GVN explicitly deferred. Do not implement these under LCSE closure without a new approved slice.
    - [ ] `[O4Z-AUDIT-LCSE-CLOSE]004` Remaining-gap grep. Goal: do one last grep across `src/passes/local_cse_test.mbt`, `src/lib/types.mbt`, and parser/typecheck surfaces for genuinely uncovered instruction families. Only add a new focused test if the gap is non-duplicative and safely representable; otherwise record that no further safe LCSE audit slice was found.
    - [ ] `[O4Z-AUDIT-LCSE-CLOSE]005` Mark lane closed or split owner. Goal: after `[O4Z-AUDIT-LCSE-CLOSE]001` through `[O4Z-AUDIT-LCSE-CLOSE]004`, either mark `[O4Z-AUDIT-LCSE]` closed in this backlog or split any remaining non-LCSE-neighborhood work to the owning pass lane, especially `flatten`, `simplify-locals-notee-nostructure`, preset ordering, or whole-command wall-time work.

- [O4Z-AUDIT-CF] - Deep audit and widen `code-folding` to Binaryen behavior parity
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit and implementation track; 2026-06-04 audit evidence lives in `docs/wiki/raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md`.
  - Goal: make Starshine `code-folding` semantically implement Binaryen's `CodeFolding.cpp` transform families, not merely remain a correct narrow subset. Byte-for-byte wasm/text parity is not required, but direct `--pass code-folding` output must be semantically equivalent to Binaryen across the standard compare lane, and remaining representation/code-size differences must be classified with evidence.
  - Scope: expression-exit tail sharing for named block exits and foldable `if` arms; function-ending terminating-tail sharing for `return`, `return_call*`, and `unreachable`; unsupported branch poisoning; branch-target/EH movement safety; helper labels/blocks; profitability/fixpoint behavior; late cleanup neighborhood; and pass-local runtime.
  - Current finding: source/test review found active owner, registry, dispatcher, and CLI coverage in place for a narrowed HOT pass. Focused coverage now includes full-`if` `unreachable` terminal suffix sharing, unsupported `br_on_null` label poisoning, live-label structured suffix bailouts, single-result typed block-exit branch-payload sharing with fallthrough or other plain-`br` payloads, and a source-backed single-result multi-root named-block suffix slice that shares a matching void/effectful root before the final branch/fallthrough value root. This is still not Binaryen behavior parity. Baseline slice `[O4Z-AUDIT-CF-A]` is green: `moon info`, `moon fmt`, `moon test src/passes` (`1590/1590`), native `src/cmd` build at `_build/native/release/build/cmd/cmd.exe`, direct 1000-case compare (`998` normalized matches, `0` mismatches, `2` `binaryen-rec-group-zero` command failures), timing-only debug-WASI replay (`172.276ms` Starshine pass vs `169.576ms` Binaryen pass, within <=2x), and full `moon test` (`4775/4775`). Follow-up `[O4Z-AUDIT-CF-B]` through `[O4Z-AUDIT-CF-D]` evidence is also green: test-first `moon test src/passes` failed the two new multi-root tests before implementation; after implementation `moon test src/passes` passed `1592/1592`, full `moon test` passed `4777/4777`, and `moon info` completed; native direct 1000-case compare at `.tmp/pass-fuzz-code-folding-bd-1000` had `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures; timing-only debug-WASI replay at `.tmp/code-folding-bd-self-compare` was `196.213ms` Starshine pass vs `187.281ms` Binaryen pass, within <=2x. Late-slot replay, 10000-case closeout, and broader Binaryen behavior parity remain open. `[O4Z-AUDIT-CF-E]` has concrete progress after the safe one-block/one-non-block `if` value-suffix slice and now includes a HOT-level unreachable-condition bailout; exact unreachable-condition fixtures remain blocked by local HOT/lower support for bottom-typed conditions. `[O4Z-AUDIT-CF-F]` now has a root-anchored helper-label terminating-tail slice beyond the earlier adjacent no-else `if` case: non-adjacent `return` tails and block-backed `unreachable` tails can share a deeper common suffix through a fresh wrapper label while preserving unique fallthrough prefixes. `[O4Z-AUDIT-CF-G]` has started with the same root-anchored helper-label model for typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` tails. Latest validation: `moon test src/passes` passed `1608/1608`, full `moon test` passed `4793/4793`, `moon info` completed, and native `src/cmd` built at `_build/native/release/build/cmd/cmd.exe` with only existing `pass_manager.mbt` unused-function warnings; native direct 1000-case compare at `.tmp/pass-fuzz-code-folding-hij-1000` had `998` normalized matches, `0` mismatches, and `2` `binaryen-rec-group-zero` command failures; timing-only debug-WASI replay at `.tmp/code-folding-hij-self-compare` was `231.629ms` Starshine pass vs `195.691ms` Binaryen pass, within <=2x. `[O4Z-AUDIT-CF-H]` now has focused `br_table`/outside-target/switch-scope negatives, `[O4Z-AUDIT-CF-I]` now preserves tested `try_table` terminal/block-exit bailout shapes by not descending into EH bodies for this pass, and `[O4Z-AUDIT-CF-J]` now runs the current local root-anchored implementation to an intra-pass fixpoint and has a small late-neighborhood fixture. Full Binaryen parity still remains open for arbitrary non-root terminating-tail subsets, exact helper cost modeling, broad branch/control-bearing movement, EH repairs, 10000-case compare, and generated late-slot evidence.
  - Deliverables:
    - [x] `[O4Z-AUDIT-CF-A]` Baseline the current widened implementation: run `moon info`, `moon fmt`, `moon test src/passes`, build native `src/cmd`, run direct `--pass code-folding --count 1000 --jobs auto --starshine-bin <actual cmd.exe>`, run timing-only `self-optimize-compare ... --code-folding`, and record exact binary path, compared count, command failures, mismatches, and pass-local Starshine/Binaryen timings in the research note.
    - [x] `[O4Z-AUDIT-CF-B]` Build a source-backed Binaryen shape matrix from `CodeFolding.cpp` and `test/lit/passes/code-folding.wast`: rows for named-block exits, `if` arms, terminating returns, terminating `return_call*`, terminating `unreachable`, unsupported-branch poison, outside-target movement bailouts, EH-sensitive bailouts/repair, helper/profitability cases, and fixpoint exposure. Matrix lives in `docs/wiki/raw/research/0713-2026-06-04-code-folding-o4z-pass-audit.md` with local tests, gaps, and next-slice owners.
    - [x] `[O4Z-AUDIT-CF-C]` Finish expression-exit candidate modeling for named block exits: `CodeFoldingValueExitTail` now carries owning region/tail pointer, branch/fallthrough kind, target label, branch payload roots, result arity, movement proof state, selected suffix length, and profitability score; unsupported `br_on_*` / `br_if` / `br_table` / `delegate` target traffic still poisons the fold.
    - [x] `[O4Z-AUDIT-CF-D]` Widen named-block expression-exit folding beyond the current single-result payload-root slice: added failing tests first and implemented the safe single-result multi-root subset for branch-plus-fallthrough payload suffixes and duplicate branch-only tail groups without fallthrough. Multi-value payloads and helper-block/profitability search remain deferred until HOT/lower and source-backed tests justify them.
    - [ ] `[O4Z-AUDIT-CF-E]` Widen `if` expression-exit folding to Binaryen's arm rules: unnamed block/unnamed block suffixes, one-block/one-non-block synthetic wrapping where safe, partial suffix folds, full-arm folds, named-arm negatives, unreachable-condition bailouts, refined-result preservation, and profitability thresholds. Progress: safe value-result one-block/one-non-block wrapping now folds in both then-block and else-block orientations with focused tests and green 1000-case compare/timing evidence; the implementation also now refuses `if` suffix folding when the HOT condition is already an exit and keeps simple full-value non-block arms for `optimize-instructions` instead of folding them in `code-folding`. Remaining caveats: exact named-unused arm negatives are limited by local HOT name preservation, unreachable-condition public fixtures still hit local HOT/lower bottom-condition limits, and broader source-backed negatives should stay open until `[O4Z-AUDIT-CF-H]`/`[O4Z-AUDIT-CF-I]` cover them. Keep live-label and branch-target movement negatives green.
    - [ ] `[O4Z-AUDIT-CF-F]` Implement the function-ending terminating-tail helper-label algorithm for `return` and `unreachable`: collect block-backed and root-level terminators, search deeper common suffixes before shallower ones, choose profitable subsets deterministically, create fresh helper labels, rewrite old tails to branch to the helper label, prevent old-body fallthrough into the shared suffix, and add focused root-level/block-backed/fallthrough-prevention tests. Progress: adjacent no-else `if` then-tail plus immediate fallthrough `return`/`unreachable` tails now share one terminal suffix through a fresh void wrapper block label; the next root-anchored helper-label slice now collects root-level and nested region terminators, selects the deepest profitable common suffix that also includes the function-end tail, rewrites old nested tails to `br` to a fresh wrapper label, and covers non-adjacent `return` plus block-backed `unreachable` positives. Non-root `return` subsets now fold through the same wrapper model, including groups that exclude a different root `return`, a deeper-subset-then-shallow-fixpoint fixture, label-unused structured block/if/loop suffix roots, and narrow alpha-equivalent self-branching block suffixes (including a nested internal-label variant), plus a root-fallthrough guard block for void roots so ordinary fallthrough skips the shared terminal suffix; the same path now has non-root `unreachable` root-fallthrough coverage, including the narrow self-branching block suffix case. Remaining work: broader arbitrary-subset coverage, broader branch-containing suffix movement, exact Binaryen helper-block cost modeling, and full fixpoint behavior.
    - [ ] `[O4Z-AUDIT-CF-G]` Extend terminating-tail sharing to `return_call`, `return_call_indirect`, and `return_call_ref` with the same subset/deeper-suffix/helper-label model; add direct-call, indirect-call, ref-call, typed-result, and unsupported/local-syntax bailout fixtures before implementation. Progress: the root-anchored helper-label model now covers typed-result direct `return_call`, WAT `return_call_indirect`, and a core-built `return_call_ref` fixture using a typed `ref.null`; call-signature side-table equality was added so indirect/ref tail-call roots compare by logical type/table signature instead of allocation id. The non-root subset wrapper path now has direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` coverage with root fallthrough, plus direct `return_call` coverage for the narrow self-branching block suffix case. Remaining work: broader arbitrary-subset coverage, broader movement-safety negatives, and more natural non-null `return_call_ref` text/core fixtures when the local front end can model them cleanly.
    - [ ] `[O4Z-AUDIT-CF-H]` Implement Binaryen-equivalent movement-safety gates: branch targets defined inside the moved-out region must remain in scope, candidate items with external break targets must be rejected, `br_table` / switch-style equal-looking unsafe tails must remain negative, and label alpha-equivalence must not override real target scope. Progress: added focused negatives for `br_table` poisoning of block-exit suffixes, outside-target switch-like return tails, and careful switch target scopes; the existing live-label structured suffix negative remains the label-scope guard. The terminating-tail equality proof now supports a narrow multi-label alpha map for suffix blocks whose branch targets are defined inside the moved suffix, covered by a nested self-branching `return` test. Broader branch/control-bearing terminating-tail movement remains deliberately rejected until Binaryen-equivalent safety proof exists.
    - [ ] `[O4Z-AUDIT-CF-I]` Address EH parity deliberately: either implement Binaryen-equivalent `pop` / throwing-through-`try` movement barriers plus nested-pop repair for block-adding rewrites, or keep exact EH shapes as tested bailouts only if Binaryen also bails out. Progress: chose the conservative bailout path for this batch: `code-folding` no longer descends into `try` / `try_table` bodies, does not treat EH controls as always exiting/fallthrough-preventing for cleanup, and has focused `try_table` terminal-tail and block-exit bailout fixtures. Do not claim Binaryen behavior parity while EH cases Binaryen folds are still unimplemented or unclassified.
    - [ ] `[O4Z-AUDIT-CF-J]` Add fixpoint and neighborhood proof: tests where one fold exposes another, plus `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks` fixtures showing helper structure is consumed safely without changing semantics. Progress: `code_folding_run` now recomputes label use and repeats the local visit/terminating-tail sequence until no local change; a focused root-anchored terminating-tail fixture now proves a second fold exposed by the first, a deeper non-root return subset fixture reaches a second shallow fold, and small late-neighborhood fixtures validate `code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks` on helper-label return-tail and non-root return-subset shapes. Remaining work: official Binaryen `determinism`/arbitrary non-root subset fixpoint parity, exact helper cost modeling, and generated late-slot artifact evidence.
    - [ ] `[O4Z-AUDIT-CF-K]` Refresh oracle signoff after every behavior-widening batch: direct `--pass code-folding --count 1000` first, then `10000` before closing; classify each mismatch as semantic-safe/size-winning, representation-only, size-losing, unknown/risky, validation failure, tool/Binaryen failure, or true semantic mismatch with rationale.
    - [ ] `[O4Z-AUDIT-CF-L]` Measure pass-local performance after the broader implementation: Starshine must stay within the repo floor (`starshine_time <= 2 * binaryen_time`) on the available direct artifact/timing lane, or the slowdown must be attributed to a specific pass-local owner with a follow-up slice rather than hidden under `[WALL]001`.
    - [ ] `[O4Z-AUDIT-CF-M]` Close the audit only after docs/backlog reflect the final parity status: update the code-folding wiki pages, research note, and `docs/wiki/log.md` with exact commands, counts, timings, mismatch classes, late-slot evidence, and any explicitly deferred Binaryen differences.

- [O4Z-AUDIT-MB] - Deep audit `merge-blocks`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: branch-free block flattening, loop-tail merging, drop(block) cleanup, O4z slot42 witness, label/branch safety, and interaction with RUB/RUN.
  - Deliverables: apply the common checklist; add missing merge/bailout fixtures; refresh direct compare and all `MB` slot evidence; measure any large nested-control runtime cost.

- [O4Z-AUDIT-RSE] - Deep audit `redundant-set-elimination`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: same-value set/tee removal, branch/default facts, loop invariants, refined local.get retargeting, GC wrapper/accessor facts, and late-tail preset role.
  - Deliverables: apply the common checklist; add missing CFG/value-flow fixtures; refresh direct compare and `RSE` slot evidence; classify any full fixed-point loop convergence gap.

- [O4Z-AUDIT-DAE] - Deep audit `dae-optimizing`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: dead argument/result removal, nested cleanup scheduler, selected-shape genericization, raw cleanup policy, type liveness, and pass-local runtime.
  - Deliverables: apply the common checklist; coordinate with `[AUDIT003-*]`; refresh DAE-normalized direct compare and late `DAE` slot evidence; keep accepted raw-cleanup drift separate from semantic mismatches.

- [O4Z-AUDIT-INL] - Deep audit `inlining-optimizing`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit. Direct compare is green with documented cleanup normalizers as of 2026-06-05: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass inlining-optimizing --normalize drop-consts --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-inlining-optimizing-local-cleanup-norm1-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` produced 6772 compared, 3376 normalized matches, 3396 cleanup-normalized matches, 0 mismatches, and 20 Binaryen/tool command failures (17 rec-group-zero, 1 bad-section-size, 1 table-index-out-of-range, 1 invalid-tag-index). Agent classification: cleanup-normalized cases are semantic-safe Starshine cleanup of closed dropped constant-expression trees, unused local declarations/local renumbering, and standalone `nop` debris; these are no-effect transforms by the WebAssembly execution model, not evidence inferred from size alone.
  - Scope: direct inlining heuristics, optimizing cleanup scheduler, no-inline policy interaction, helper compaction, tail-call/multivalue surfaces, and local-declaration drift.
  - Deliverables: apply the common checklist; refresh `INL` slot evidence; file partial-inlining/name repair only if new evidence warrants reopening deferred slices.

- [O4Z-AUDIT-DIE] - Deep audit `duplicate-import-elimination`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: duplicate import equivalence, import remapping, call/ref.func/table/export users, nonfunction and signature negatives, and metadata preservation.
  - Deliverables: apply the common checklist; coordinate tests with `[AUDIT004-G]`/`[AUDIT004-H]`; refresh direct compare and `DIE` slot evidence; record any ABI-visible import-order constraints.

- [O4Z-AUDIT-SGO] - Deep audit `simplify-globals-optimizing`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: global value propagation, nested cleanup runtime, late-tail scheduling, closed/open-world boundaries, string/GC/refinalization breadth, and accepted default-local drift.
  - Deliverables: apply the common checklist; refresh direct compare and `SGO` tail evidence; coordinate with `[SGO]003` through `[SGO]005`; keep accepted v0.1.0 signoff separate from new improvement findings.

- [O4Z-AUDIT-SG] - Deep audit `string-gathering`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: string.const gathering, canonical global reuse, data/name/export interactions, late-tail ordering, and string-heavy module code-size impact.
  - Deliverables: apply the common checklist; add missing stringref/global fixtures; refresh direct compare and `SG` tail evidence; document any Binaryen canonical-string reuse gap.

- [O4Z-AUDIT-RG] - Deep audit `reorder-globals`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: dependency-preserving global order, global.get/set remaps, exports/imports/start/elem/data interactions, string global late tail, and names/metadata.
  - Deliverables: apply the common checklist; add missing dependency/remap fixtures; refresh direct compare and `RG` tail evidence; record any order-only representation drift separately from correctness.

- [O4Z-AUDIT-DIR] - Deep audit `directize`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: immutable table facts, holes/traps, type matching/subtyping, select lowering, imported/exported/mutated table negatives, tail calls, and late-tail code-size impact.
  - Deliverables: apply the common checklist; coordinate tests with `[AUDIT004-D]` through `[AUDIT004-F]`; refresh direct compare and final `DIR` tail evidence; document any broader directization opportunities or safety bailouts.

## Deferred Until MoonBit Threading Support

- [HOT]002 - Native Parallel Hot-Batch Queue
  - Status: deferred; MoonBit does not currently support the threading model Starshine needs for a safe native worker queue.
  - Resume when: MoonBit native threading is stable enough to run per-function optimizer workers with deterministic, byte-stable output and explicit runtime gating.
  - Deliverables: add a native-only worker queue over eligible defined functions for the hot batch payload (`ssa-nomerge -> dead-code-elimination -> vacuum -> optimize-instructions -> simplify-locals`); keep final output byte-stable and deterministic; gate behind an explicit native-only option.
  - Dependencies: [HOT]001 replay hardening must stay green.

## v0.1.1 Backlog

### Optimizer Audit Follow-Ups

- [AUDIT]001 - Hot Pass Descriptor Metadata Truthfulness
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: make hot pass `requires` metadata describe every analysis a pass may request through `pass_require_*`, so the registry remains a truthful pass-author contract and future scheduling/perf tooling can trust descriptors.
  - Why: the audit found passes that lazily request analyses without listing them in `requires`; tests currently pass because the helper layer builds analyses on demand, but the metadata contract is stale.
  - Deliverables:
    - [ ] `[AUDIT001-A]` Add focused descriptor tests for `optimize-instructions` requiring `use_def` and `effects`; confirm failure before metadata changes.
    - [ ] `[AUDIT001-B]` Update `optimize-instructions` descriptor metadata to declare `use_def` and `effects`; rerun the focused descriptor test and `moon test src/passes`.
    - [ ] `[AUDIT001-C]` Add focused descriptor test for `remove-unused-brs` requiring `use_def`; confirm failure before metadata changes.
    - [ ] `[AUDIT001-D]` Update `remove-unused-brs` descriptor metadata to declare `use_def`; rerun the focused descriptor test and `moon test src/passes`.
    - [ ] `[AUDIT001-E]` Add a focused descriptor test proving `precompute-propagate-prefix` requires `ssa` and direct `precompute` does not, if direct `precompute` truly never reaches SSA helpers.
    - [ ] `[AUDIT001-F]` If `[AUDIT001-E]` proves direct `precompute` can reach SSA helpers, update direct `precompute` descriptor in its own test-first slice; otherwise leave it unchanged and document why.
    - [ ] `[AUDIT001-G]` Add a lightweight static/registry audit helper or test table for future `pass_require_*` additions so new metadata drift is caught near the implementing pass.
    - [ ] `[AUDIT001-H]` Refresh `docs/wiki/ir2/pass-porting-checklist.md` with the descriptor audit rule and cite the new tests.
  - Suggested tests: `moon test src/passes`, registry/descriptor focused tests, and one small trace/perf smoke proving analysis timers still appear under the expected pass.
  - Exit criteria: every hot descriptor is either mechanically covered by tests or explicitly documented as intentionally lazy; no pass silently depends on undeclared analysis metadata.

- [AUDIT]002 - Pass-Manager Raw Skip And Gate Boundary Coverage
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: protect large-function raw precleaner / skip heuristics from silent coverage holes and performance cliffs.
  - Why: `src/passes/pass_manager.mbt` contains many threshold-shaped gates for `remove-unused-brs`, `simplify-locals`, and related raw adapters. They are performance-motivated, but nearby shapes can miss cleanup or unexpectedly fall back to expensive HOT lowering. The 2026-06-04 `[O4Z-AUDIT-SL]` closeout retired the simplify-locals semantic/direct and generated late-neighborhood audit gate, but intentionally left small structured call-mesh and giant/no-structure raw threshold boundary coverage here under `[AUDIT002-F]` / `[AUDIT002-G]`.
  - Deliverables:
    - [ ] `[AUDIT002-A]` Inventory every `can_skip`, `unchecked`, `giant`, `large`, and threshold-based raw gate in `pass_manager.mbt`, grouping them by owning pass and intended artifact/function family.
    - [ ] `[AUDIT002-B]` Add white-box tests for `remove-unused-brs` large-result `br_table` dispatch ladder gates: exact match, locals/instruction lower-bound miss, block-depth miss, and HOT-only-candidate miss.
    - [ ] `[AUDIT002-C]` Add white-box tests for `remove-unused-brs` large value-if branch ladder gates: locals range, instruction range, call range, return/block range, and drop/select/br_if negatives.
    - [ ] `[AUDIT002-D]` Add white-box tests for `remove-unused-brs` drop-heavy / typed-`br_table` / void-if-return ladder gates, one predicate family per test so boundary failures identify the exact gate.
    - [ ] `[AUDIT002-E]` Add white-box tests for `remove-unused-brs` moderate and unchecked call-mesh gates, including ±1 thresholds around locals, instruction count, if count, and call count.
    - [ ] `[AUDIT002-F]` Add white-box tests for `simplify-locals` small structured call mesh gates: exact match, instruction lower/upper bounds, local-get/call ranges, and exact-tail negative.
    - [ ] `[AUDIT002-G]` Add white-box tests for `simplify-locals` giant validator and no-structure gates, with one fixture per threshold family rather than one mega-fixture.
    - [ ] `[AUDIT002-H]` For each broad skip family touched by `[AUDIT002-B]` through `[AUDIT002-G]`, add one public-pipeline fixture proving the intended cleanup either still runs or intentionally stays skipped with a trace reason.
    - [ ] `[AUDIT002-I]` Add trace strings for currently silent broad skip decisions where a future agent cannot tell whether a function was skipped for safety, performance, or shape mismatch.
    - [ ] `[AUDIT002-J]` Run a focused artifact timing replay for the debug artifact after adding trace/tests; document any gate that exists only to stay within `Starshine <= 2x Binaryen`.
  - Suggested tests: `moon test src/passes`, focused `pass_manager_wbtest`, and a timing-only `self-optimize-compare` replay only after asking if it will be long.
  - Exit criteria: every raw skip/gate family has boundary tests and a documented purpose; no threshold is an unexplained magic number.

- [AUDIT]003 - DAE Selected-Shape De-Artifacting And Genericization
  - Status: active v0.1.1 follow-up; not a v0.1.0 blocker because current DAE direct-pass surfaces are accepted.
  - Goal: convert remaining selected `FuncXXX` artifact lanes into generic, named, semantics-first shape recognizers where practical, while keeping accepted artifact evidence intact.
  - Why: the audit found many selected-function helpers in `dead_argument_elimination.mbt`. They are covered and historically justified, but they are hard to maintain and weak as a general optimizer surface.
  - Deliverables:
    - [ ] `[AUDIT003-A]` Inventory selected-function helpers and tests into a markdown table with columns: helper, selected def(s), fixture/test, transform family, safety guard, artifact reason, and current generic candidate.
    - [ ] `[AUDIT003-B]` Classify Func237 carrier/loop/local-map helpers only; decide which are genericizable and which are intentionally artifact-local.
    - [ ] `[AUDIT003-C]` Classify Func256/Func298 loop-carrier helpers only; decide which are genericizable and which are intentionally artifact-local.
    - [ ] `[AUDIT003-D]` Classify Func287/Func288 setup/switch-carrier helpers only; decide which are genericizable and which are intentionally artifact-local.
    - [ ] `[AUDIT003-E]` Classify Func299 inverted-if, Func311/Func313 terminal-call-arg, and Func408/Func505/Func521 literal/control helpers, one family at a time.
    - [ ] `[AUDIT003-F]` Pick the smallest safe classified family and add a reduced non-artifact fixture that fails without a generic recognizer and does not depend on absolute debug-artifact function indices.
    - [ ] `[AUDIT003-G]` Implement only that one family behind semantic guards, keep the selected artifact fixture as a regression, and remove only the corresponding selected-index gate if artifact/timing/fuzz evidence stays green.
    - [ ] `[AUDIT003-H]` Repeat `[AUDIT003-F]`/`[AUDIT003-G]` for the next smallest family; every repeat gets its own focused test-first commit-sized slice, not a broad DAE rewrite.
    - [ ] `[AUDIT003-I]` For families that remain selected-only, add comments in source and wiki explaining why they are intentionally artifact-local and what evidence would reopen them.
    - [ ] `[AUDIT003-J]` Refresh direct `--dae-optimizing` compare with DAE normalizers and classify any mismatch families by agent judgment, keeping accepted raw-cleanup drift separate from true semantic mismatches.
  - Suggested tests: focused DAE fixtures first, `moon test src/passes`, direct `bun scripts/pass-fuzz-compare.ts --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`, and artifact timing when selected lanes move.
  - Exit criteria: selected-function lanes are either replaced by generic recognizers or explicitly documented as intentionally artifact-local with current evidence.

- [AUDIT]004 - Thin Module-Pass Shape Coverage Expansion
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: add small, public-pipeline tests for module passes whose current direct coverage is thin relative to their implementation breadth.
  - Why: the all-pass fuzz smoke found no validation failures, but several module passes have only a small number of focused tests and are likely places for missing shapes to hide.
  - Deliverables:
    - [ ] `[AUDIT004-D]` `directize` table visibility negatives: add separate imported-table and exported-table tests proving indirect calls remain indirect.
    - [ ] `[AUDIT004-E]` `directize` element coverage: add passive element, declarative element, active nonconstant offset, active out-of-range hole, and type-mismatch-trap tests.
    - [ ] `[AUDIT004-F]` `directize` multi-table and tail-call coverage: add one multi-table partial optimization fixture, one `return_call_indirect` fixture, and one unsupported `call_ref`/reference-call non-interference fixture if WAT support exists.
    - [ ] `[AUDIT004-G]` `duplicate-import-elimination`: add separate tests for same module/name duplicate function imports, different module/name same-signature duplicates, nonfunction-import negatives, and different-signature negatives.
    - [ ] `[AUDIT004-H]` `duplicate-import-elimination` remapping: add separate call, `ref.func`, table element, export/start, and name/custom-section preservation tests.
    - [ ] `[AUDIT004-I]` `merge-locals`: add separate tests for multi-value functions, GC/ref locals with equal types, GC/ref locals with unequal types, dead-tail local traffic, write-interrupted copy chains, effect-interrupted copy chains, and local-name cleanup.
    - [ ] `[AUDIT004-J]` `local-cse` scalar/effect barriers: add separate tests for memory load/store barriers, global get/set barriers, table barriers, ordinary call barriers, and pure duplicate scalar positives.
    - [ ] `[AUDIT004-K]` `local-cse` advanced barriers: add separate tests for exceptions/`try_table`, GC heap operations, atomic operations, and SIMD operations where the current WAT authoring surface supports them; otherwise file the unsupported shape in the wiki.
    - [ ] `[AUDIT004-L]` `once-reduction`: add separate tests for table escape, global escape, `ref.func` escape, export escape, start-function behavior, imported function negative, exported function negative, and multi-use once-positive.
    - [ ] `[AUDIT004-M]` `global-refining`: add separate tests for non-null-to-null negative, incompatible subtype negative, descriptor-bearing type body publicity, and broader stringref expression surfaces where supported; the O4z audit already covered nullable-to-non-null bottom refinements, exported mutability/closed-world guards, subtype-chain joins, `ref.func`, `ref.i31`, `struct.new_default`, and exported exact/private initializer bailouts.
    - [ ] `[AUDIT004-N]` After each pass-family test batch, run the pass-targeted compare smoke with `--count 1000` before moving to the next family; do not batch all behavior changes behind one signoff.
  - Suggested tests: adjacent `*_test.mbt` public-pipeline fixtures, `moon test src/passes`, and pass-targeted compare smoke for each touched pass.
  - Exit criteria: each listed module pass has positive and negative coverage for its most important module shapes, with no new validation failures or unexplained Binaryen mismatches.

- [AUDIT]005 - Standalone No-Inline Pass Contract Tests
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: give `no-inline`, `no-full-inline`, and `no-partial-inline` their own focused module-pass tests instead of relying only on inlining integration tests.
  - Why: `src/passes/no_inline.mbt` has meaningful standalone behavior but no adjacent `no_inline_test.mbt` file.
  - Deliverables:
    - [ ] `[AUDIT005-A]` Add `src/passes/no_inline_test.mbt` with a helper that runs a no-inline module pass and extracts function annotations.
    - [ ] `[AUDIT005-B]` Add wildcard positive coverage for a defined WAT function name.
    - [ ] `[AUDIT005-C]` Add no-match negative coverage proving no annotation section is created.
    - [ ] `[AUDIT005-D]` Add imported function name matching coverage.
    - [ ] `[AUDIT005-E]` Add WAT identifier lowering coverage for defined functions.
    - [ ] `[AUDIT005-F]` Add repeated marker deduplication coverage.
    - [ ] `[AUDIT005-G]` Add metadata-code-inline non-interaction coverage.
    - [ ] `[AUDIT005-H]` Add `no-full-inline` only marker coverage.
    - [ ] `[AUDIT005-I]` Add `no-partial-inline` only marker coverage.
    - [ ] `[AUDIT005-J]` Add combined policy coverage and retain one narrow inlining integration smoke as the end-to-end guard.
  - Suggested tests: `moon test src/passes`, plus a narrow inlining integration smoke after standalone tests are green.
  - Exit criteria: no-inline policy marker semantics are protected independently from the inliner.

- [AUDIT]006 - Function TypeIdx/RecIdx Invariant Documentation
  - Status: active documentation follow-up from user clarification on 2026-05-31.
  - Goal: document clearly that `func_sec` function type references are absolutely invariant as global `TypeIdx` entries, not local recursive `RecIdx` entries; optimizer code may treat `RecIdx` in function-section type-index positions as impossible after valid decode/validation.
  - Why: the audit initially flagged `RecIdx` aborts in locals passes as potential user-input risk. User clarified this shape is a 100% invariant. The issue is documentation clarity, not behavior change.
  - Deliverables:
    - [ ] `[AUDIT006-A]` Add or update a wiki page covering the function-section type-index invariant: module-level function declarations use global `TypeIdx`; `RecIdx` is only meaningful inside a rec-group-local type context.
    - [ ] `[AUDIT006-B]` Cite concrete source anchors in that page: `src/lib/types.mbt`, validation/type-section handling, and at least one optimizer module-pass function-signature cache.
    - [ ] `[AUDIT006-C]` Add inline comment near the `merge-locals` `RecIdx` abort explaining it is an unreachable invariant assertion for function-section type references.
    - [ ] `[AUDIT006-D]` Add inline comment near the `coalesce-locals` `RecIdx` abort explaining the same invariant.
    - [ ] `[AUDIT006-E]` Add inline comment near the `reorder-locals` `RecIdx` abort explaining the same invariant.
    - [ ] `[AUDIT006-F]` Add a pass/helper test or validation test, if practical, demonstrating that valid module-level function declarations resolve through global `TypeIdx`; if no practical test exists, document why the source/validation references are sufficient.
    - [ ] `[AUDIT006-G]` Update `docs/wiki/ir2/pass-porting-checklist.md` or a related architecture page with guidance: do not cargo-cult broad `RecIdx` support into module-pass function-signature caches unless the source is actually inside a rec-group-local type context.
    - [ ] `[AUDIT006-H]` Refresh `docs/wiki/index.md` and `docs/wiki/log.md` for the new/updated invariant documentation.
  - Suggested tests: docs-only changes should still run `moon test src/passes`; if a validation/helper test is added, run the specific package plus `moon test` when practical.
  - Exit criteria: future agents can see that function-section `RecIdx` handling is an invariant assertion and do not spend time trying to support an impossible module shape.

- [AUDIT]007 - Audit Compare Refresh And Mismatch Classification Hygiene
  - Status: active follow-up from the 2026-05-31 optimizer audit.
  - Goal: turn the ad hoc audit smoke into durable, reproducible evidence without treating accepted representation drift as a correctness failure.
  - Why: the 50-case all-pass smoke and 1000-case DAE refresh found no validation failures, but the evidence currently lives only in `.tmp/deep-audit-20260531` and this thread.
  - Deliverables:
    - [ ] `[AUDIT007-A]` File a numbered research note summarizing the exact 2026-05-31 all-pass smoke commands and environment, including `--starshine-bin`, `--jobs auto`, seed, and out dirs.
    - [ ] `[AUDIT007-B]` Add the per-pass count table to that note: compared count, normalized matches, compare-normalized matches, validation failures, command failures, and mismatch count.
    - [ ] `[AUDIT007-C]` Add a lightweight docs recipe for running an all-pass smoke compare with `--jobs auto` and a prebuilt `--starshine-bin`, explicitly not part of normal `moon test`.
    - [ ] `[AUDIT007-D]` Add or update script tests only if the docs recipe requires script behavior changes; keep recipe-only changes docs-only.
    - [ ] `[AUDIT007-E]` Refresh direct `--pass inlining` mismatch classification with a small replay set, explicitly separating local-declaration representation drift from semantic mismatch.
    - [x] `[AUDIT007-F]` Refresh direct `--pass inlining-optimizing` mismatch classification with a small replay set, separately from plain `inlining`. 2026-06-05 replayed `.tmp/pass-fuzz-inlining-optimizing-large-guard1-1000` mismatches with `--normalize drop-consts --normalize local-cleanup-debris` into `.tmp/pass-fuzz-inlining-optimizing-replay-normalized3`: 26/26 cleanup-normalized, 0 mismatches; the follow-up 10000 run is recorded under `[O4Z-AUDIT-INL]`.
    - [ ] `[AUDIT007-G]` Refresh direct `--pass dae-optimizing` classification with documented normalizers and keep generated dropped-constant cleanup drift separate from validation or semantic failures.
    - [ ] `[AUDIT007-H]` Link the research note from the relevant pass wiki pages or the audit/log page so future agents do not rediscover the same smoke results.
  - Suggested tests: no implementation tests unless tooling changes; if tooling/docs recipe changes, run script tests and a small compare replay.
  - Exit criteria: the audit evidence is durable and indexed, with exact commands and agent-classified mismatch families.

### SGO - Follow-Up Improvements

- [SGO]003 - Optional Binaryen `SimplifyGlobals.cpp` Breadth
  - Status: deferred to v0.1.1; not a v0.1.0 blocker.
  - Resume when: a new semantic mismatch, wasm validation failure, targeted artifact/code-size need, or string/GC/refinalization requirement points at SGO breadth.
  - Candidate families: side-effecting-but-safe `read-only-to-write` value-flow positives, broader same-as-init expression matching beyond direct literal / `ref.null` / `ref.func`, broader runtime linear-trace propagation, and additional GC/refinalization-safe replacement surfaces.
  - Deliverables when resumed: add focused shape tests first, rerun direct `--pass simplify-globals-optimizing` oracle fuzz for the new family, and update the SGO wiki pages with the exact accepted subset.

- [SGO]004 - Nested Cleanup Runtime And Exact-Scheduler Experiment
  - Status: deferred to v0.1.1.
  - Resume when: a measured SGO-specific wall-time owner appears, the nested `vacuum` wrapper overhead becomes a concrete runtime target, or an artifact/code-size case demonstrates value from omitted nested default-function slots.
  - Candidate work: reduce nested `vacuum` / lift-lower wrapper cost, add cheaper function-filtered adapters for currently module-shaped cleanup passes, or run a controlled exact-scheduler experiment with artifact and fuzz evidence.
  - Deliverables when resumed: trace before/after nested timers, preserve validation and direct 10k SGO fuzz parity, and document whether the accepted artifact-tuned lane changes.

- [SGO]005 - Default-Local Compare Normalization
  - Status: deferred to v0.1.1 tooling/cosmetic follow-up.
  - Goal: eliminate or normalize the accepted direct SGO artifact diff where Binaryen preserves an explicit default local initialization and Starshine relies on WebAssembly default local zero-initialization.
  - Resume when: exact artifact diffs need to become quieter for release QA or compare-harness work.
  - Deliverables when resumed: either teach the compare helper to ignore explicit default local initialization when semantically equivalent, or add a deliberate Starshine emission/canonicalization option if preserving the explicit set proves more useful.

## v0.2.0 Backlog

### SET - Shared-Everything Threads Proposal Surface

Release stance: proposal-tracking backlog, not a v0.1.0 release gate. Starshine currently has the focused `struct.atomic.get`, `struct.atomic.get_s`, and `struct.atomic.get_u` surface plus conservative optimizer handling. The remaining shared-everything threads surface is intentionally sliced below so future agents can add core/type/binary/WAST/validation/fuzzer/pass support in dependency order instead of treating proposal examples as already-supported syntax.

Common rules for every `[SET-*]` slice:
- Start from `docs/wiki/raw/wasm/2026-06-04-struct-atomic-get-sources.md`, `docs/wiki/wast/gc-aggregate-instruction-authoring.md`, `docs/wiki/wast/atomic-memory-instruction-authoring.md`, and the current shared-everything threads proposal text. Refresh the source snapshot first if the proposal changed.
- Add tests first for the exact surface being widened; do not add parser keywords, binary opcodes, or optimizer rewrites without validator/effect coverage.
- Keep linear-memory atomics (`MemArg` instructions) separate from shared-GC aggregate atomics and proposal shared resource/thread-local features.
- Treat `struct.atomic.get*` as the only already-supported shared-GC aggregate atomic family until a slice below lands.
- Preserve generic optimizer conservatism for any atomic read/write/RMW/cmpxchg/wait operation unless a pass-specific proof documents why rewriting is safe.
- Update `docs/wiki/wast/gc-aggregate-instruction-authoring.md`, `docs/wiki/wast/atomic-memory-instruction-authoring.md`, `docs/wiki/index.md`, `docs/wiki/log.md`, and pass-specific wiki pages when behavior changes.

- [SET-SRC]001 - Refresh shared-everything source manifest and local gap matrix
  - Status: active planning slice; run before implementing any remaining proposal family.
  - Goal: replace the current struct-atomic-get-only source snapshot with a broader proposal tracking manifest and a local implementation matrix.
  - Why: the proposal is moving and the current durable source capture intentionally scoped itself to `struct.atomic.get*`; future implementers need exact opcodes, text spellings, immediates, feature flags, validation rules, and local unsupported surfaces before coding.
  - Deliverables:
    - [ ] Capture the current proposal instruction/type/resource list with date, source URLs, and caveats in `docs/wiki/raw/wasm/` or a numbered research note.
    - [ ] Build a matrix with rows for shared types/resources, thread-local globals, `pause`, `ref.i31_shared`, global atomics, table atomics, struct atomic set/RMW/cmpxchg, array atomic get/set/RMW/cmpxchg, waitqueue operations, aggregate waits, proposal memory waits, and release/acquire ordering.
    - [ ] For each row, record local status across `src/lib`, `src/binary`, `src/wast`, `src/validate`, `src/ir`, `src/passes`, `src/validate/gen_valid`, and docs.
    - [ ] Decide exact local spellings for order operands, including whether compact Binaryen spellings like `seqcst` should remain unsupported or become accepted aliases.
    - [ ] Update the WAST aggregate/atomic pages so they link the new matrix and continue warning that only `struct.atomic.get*` is implemented today.
  - Suggested tests: docs-only unless a source-refresh helper changes; run `bun validate readme-api-sync` if docs references affect README/API sync.
  - Exit criteria: future agents can pick any `[SET-*]` slice without rediscovering proposal scope or conflating shared-GC atomics with linear-memory atomics.

- [SET-TYPE]001 - Sharedness and thread-local resource type model
  - Status: blocked on `[SET-SRC]001` exact rules.
  - Goal: add the type/resource metadata needed by the rest of the proposal before instruction families depend on it.
  - Why: aggregate atomics and shared resource validation require knowing whether heaps, arrays, structs, tables, globals, functions, elements, data, and memories are shared/thread-local where the proposal requires it.
  - Deliverables:
    - [ ] Add focused type/model tests for shared annotations, thread-local globals, and any proposal `bot-share` / shared-heap distinctions selected by `[SET-SRC]001`.
    - [ ] Extend `src/lib/types.mbt` and related constructors only as far as the proposal-backed matrix requires.
    - [ ] Extend binary encode/decode and pretty/show helpers for new type/resource metadata.
    - [ ] Extend WAST parser/printer/lowering for shared/thread-local annotations with round-trip tests.
    - [ ] Extend validation/typecheck with positive and negative sharedness/thread-local tests.
    - [ ] Update arbitrary/module generators only after validation rejects unsupported combinations deterministically.
  - Suggested tests: package-local type/binary/WAST/validate tests, `moon test src/lib`, `moon test src/binary`, `moon test src/wast`, `moon test src/validate`, then `moon test` when the model becomes public.
  - Exit criteria: sharedness/thread-local metadata round-trips and validates independently of the later atomic instruction families.

- [SET-CORE]001 - `pause` and `ref.i31_shared` scalar proposal instructions
  - Status: blocked on `[SET-SRC]001`; independent from aggregate atomic families once exact encodings are confirmed.
  - Goal: implement the smallest non-aggregate proposal instructions as a low-risk proving ground for proposal feature plumbing.
  - Deliverables:
    - [ ] Add core enum/constructor/show/equality/arbitrary coverage for `pause` and `ref.i31_shared` if `[SET-SRC]001` confirms they remain in scope.
    - [ ] Add binary encode/decode tests for exact opcodes and immediates.
    - [ ] Add WAST keyword/parser/printer/lowering tests for text spellings.
    - [ ] Add validation stack/effect tests, including any sharedness restrictions for `ref.i31_shared`.
    - [ ] Lift/lower HOT and model effects conservatively; ensure cleanup passes preserve the instructions unless proved pure/nontrapping by the spec.
  - Suggested tests: `moon test src/lib src/binary src/wast src/validate src/ir src/passes`, then `moon test` after public surface changes.
  - Exit criteria: scalar proposal instructions can parse, encode, validate, lift/lower, print, and survive optimizer passes.

- [SET-GLOBAL]001 - Global atomic get/set/RMW/cmpxchg
  - Status: blocked on `[SET-SRC]001` and any `[SET-TYPE]001` global sharedness model needed.
  - Goal: implement proposal global atomic operations as effectful global/resource operations.
  - Deliverables:
    - [ ] Add instruction enum variants and helpers for `global.atomic.get`, `global.atomic.set`, and `global.atomic.rmw.{add,sub,and,or,xor,xchg,cmpxchg}` or the exact current proposal spellings.
    - [ ] Add binary encode/decode, WAST parse/print/lower, and validation tests for index kind, value type, mutability/sharedness, order operands, stack behavior, and invalid cases.
    - [ ] Model effects as global/resource reads/writes plus trap/order barriers as applicable; HOT lift/lower must not assume `MemArg`.
    - [ ] Update module remapping/liveness passes so global indices and referenced types remain valid after reordering/removal/dedup passes.
    - [ ] Add generic pass guard tests proving DCE/precompute/local-cse/simplify-locals/optimize-instructions do not delete, merge, or move global atomic operations unsafely.
  - Suggested tests: focused core/binary/WAST/validate/IR/pass tests, `moon test src/passes`, and a small all-pass fuzz smoke once generation can emit the family.
  - Exit criteria: global atomic operations are first-class, valid, remapped correctly, and optimizer-conservative.

- [SET-TABLE]001 - Table atomic get/set/RMW/cmpxchg
  - Status: blocked on `[SET-SRC]001` and any `[SET-TYPE]001` table sharedness model needed.
  - Goal: implement proposal table atomic operations as effectful table/resource operations.
  - Deliverables:
    - [ ] Add instruction enum variants/helpers for `table.atomic.get`, `table.atomic.set`, and `table.atomic.rmw.{xchg,cmpxchg}` or exact current proposal spellings.
    - [ ] Add binary/WAST/validation tests for table indices, element reference types, stack behavior, sharedness, order operands, and invalid type/index cases.
    - [ ] Extend HOT/effects without reusing linear-memory `MemArg` assumptions.
    - [ ] Update table-index remapping users in directize, duplicate-import/module-element removal, reorder-like paths, and any table-liveness helpers.
    - [ ] Add pass guard tests proving table atomic operations are barriers for CSE, local sinking, DCE, and instruction folding.
  - Suggested tests: `moon test src/lib src/binary src/wast src/validate src/ir src/passes`, then targeted directize/RUME/DIE tests if remapping changes.
  - Exit criteria: table atomic operations preserve table indices/types through all module passes and remain effect barriers.

- [SET-STRUCT]001 - Struct atomic set/RMW/cmpxchg aggregate families
  - Status: blocked on `[SET-SRC]001`; likely depends on `[SET-TYPE]001` shared-struct metadata.
  - Goal: extend the current `StructAtomicGet*` surface to proposal struct atomic writes and read-modify-write operations.
  - Deliverables:
    - [ ] Add core enum variants/helpers for `struct.atomic.set`, `struct.atomic.rmw.*`, and `struct.atomic.rmw.cmpxchg` or exact current proposal spellings.
    - [ ] Add binary encode/decode tests for opcodes, order operands, type index, field index, and value immediates/operands.
    - [ ] Add WAST parse/print/lower tests using canonical Starshine order spellings and explicit compatibility-alias decisions from `[SET-SRC]001`.
    - [ ] Add validator tests for field mutability, packed-field signedness/width, sharedness, stack behavior, null traps, and invalid field/type indices.
    - [ ] Extend HOT lift/lower/effects as aggregate atomic write/RMW/cmpxchg barriers, not linear-memory atomics.
    - [ ] Update duplicate-function/module-element/dead-argument/type-liveness/remap passes for any referenced type indices.
    - [ ] Add generic pass guard tests proving dropped writes/RMW/cmpxchg are preserved and loads/stores are not moved across them.
    - [ ] Revisit GSI/heap2local/global-type-optimization docs after implementation: writes/RMW/cmpxchg keep fields live/mutable and should block immutable-field assumptions unless the proof explicitly excludes them.
  - Suggested tests: focused core/binary/WAST/validate/IR/pass tests, `moon test src/passes`, direct `--pass global-struct-inference` compare after GSI liveness assumptions are touched.
  - Exit criteria: struct aggregate atomic writes/RMW/cmpxchg are first-class and all optimizer passes treat them as effectful field traffic.

- [SET-ARRAY]001 - Array atomic get/set/RMW/cmpxchg aggregate families
  - Status: blocked on `[SET-SRC]001`; likely depends on broader array WAST/core surface and `[SET-TYPE]001` shared-array metadata.
  - Goal: implement proposal array aggregate atomic operations without confusing them with linear-memory atomics.
  - Deliverables:
    - [ ] Audit current array instruction support and add any missing ordinary array core/WAST prerequisites needed for atomic fixtures.
    - [ ] Add core enum variants/helpers for `array.atomic.get*`, `array.atomic.set`, `array.atomic.rmw.*`, and `array.atomic.rmw.cmpxchg` or exact current proposal spellings.
    - [ ] Add binary/WAST/validation tests for array type index, element index operand, packed signedness, order operands, sharedness, null traps, bounds traps, and invalid element types.
    - [ ] Extend HOT/effects as aggregate atomic operations that may trap and synchronize.
    - [ ] Update type-index/remap/liveness passes for referenced array type indices.
    - [ ] Add pass guard tests for DCE/precompute/local-cse/simplify-locals/optimize-instructions and any array-specific passes once they exist.
  - Suggested tests: focused array package tests plus `moon test src/passes`; add generator coverage only after validation is stable.
  - Exit criteria: array atomic families are implemented as shared-GC aggregate operations with correct traps, signedness, and optimizer barriers.

- [SET-WAIT]001 - Waitqueue and aggregate wait operations
  - Status: blocked on `[SET-SRC]001`, `[SET-TYPE]001`, and likely core shared resource decisions.
  - Goal: implement proposal waitqueue operations and aggregate waits as a separate synchronization surface from existing linear-memory atomics.
  - Deliverables:
    - [ ] Add core resource/type representation for waitqueues if still present in the proposal.
    - [ ] Add instructions such as `waitqueue.new`, `waitqueue.notify`, `struct.wait`, `array.wait`, `global.wait`, `table.wait`, and proposal `memory.wait32` / `memory.wait64` only after `[SET-SRC]001` confirms exact spelling and behavior.
    - [ ] Add binary/WAST/validation tests for waitqueue indices/resources, waited locations, timeout/value operands, sharedness, trap/blocking semantics, and invalid cases.
    - [ ] Model effects as synchronization/blocking barriers; HOT/pass logic must preserve exact order and never precompute/delete waits or notifies.
    - [ ] Update generators cautiously: deterministic validation fixtures first, randomized emission later with clear feature gates.
  - Suggested tests: focused core/binary/WAST/validate/IR/pass guard tests; avoid runtime execution assumptions unless the harness has deterministic wait behavior.
  - Exit criteria: waitqueue/wait operations validate and round-trip, and optimizers treat them as hard synchronization barriers.

- [SET-MEMORD]001 - Proposal release/acquire orderings for memory atomics and fence
  - Status: blocked on `[SET-SRC]001`; separate from existing stable linear-memory atomic opcode support.
  - Goal: widen existing `MemArg`-based atomic memory instructions and `atomic.fence` only where the proposal adds explicit order operands or altered validation.
  - Deliverables:
    - [ ] Compare current `AtomicOrder` modeling against proposal ordering requirements for linear-memory atomics, aggregate atomics, and fences.
    - [ ] Add binary/WAST/validation tests for any new order immediates, default order behavior, aliases, and invalid encodings.
    - [ ] Keep current linear-memory atomic authoring docs accurate: Starshine core/binary/validator/generator support does not imply WAST text support unless keywords/parser/lowering are added.
    - [ ] Extend HOT/effects and pass guard tests only if order operands change instruction identity or barrier strength.
  - Suggested tests: `moon test src/binary src/wast src/validate src/ir src/passes` plus existing atomic-memory fixture tests.
  - Exit criteria: memory-order semantics are represented consistently across linear-memory and shared-GC atomics without regressing existing atomic tests.

- [SET-GEN]001 - Generator, invalid-fuzzer, and compare harness coverage for shared-everything features
  - Status: blocked until at least one `[SET-CORE]`, `[SET-GLOBAL]`, `[SET-TABLE]`, `[SET-STRUCT]`, `[SET-ARRAY]`, or `[SET-WAIT]` implementation slice lands.
  - Goal: move implemented shared-everything features from hand-written fixtures into systematic valid/invalid generation and pass-compare coverage.
  - Deliverables:
    - [ ] Add GenValid feature-gated generation for each implemented family with a ledger row or update to the existing atomics/GC aggregate rows.
    - [ ] Add invalid-AST strategies for sharedness mismatches, order operand mistakes, index-kind errors, packed signedness mistakes, mutability violations, and waitqueue/resource misuse.
    - [ ] Add binary-invalid tests for malformed encodings that cannot be represented in the AST.
    - [ ] Update compare-pass generation profiles only after Binaryen and Starshine agree on the same proposal surface or the harness can gate proposal features explicitly.
    - [ ] File durable mismatch classifications for any Binaryen proposal-syntax drift or unsupported oracle behavior.
  - Suggested tests: `moon test src/validate src/fuzz src/binary`, targeted `bun fuzz run` smokes, and small `bun scripts/pass-fuzz-compare.ts --count 1000 --jobs auto --starshine-bin ...` lanes once generation is enabled.
  - Exit criteria: implemented proposal features are exercised by valid and invalid fuzzing without destabilizing existing pass parity lanes.

- [SET-PASS]001 - Optimizer-wide shared-everything proposal audit after each new family
  - Status: repeat after each `[SET-*]` instruction-family slice.
  - Goal: prevent new shared-everything instructions from bypassing pass invariants, remapping, liveness, effect barriers, or Binaryen parity docs.
  - Deliverables:
    - [ ] For the newly implemented family, grep every active pass for adjacent ordinary/global/table/struct/array/memory handling and add explicit preserve/remap/barrier coverage where needed.
    - [ ] Update `docs/wiki/raw/research/0708-2026-06-04-struct-atomic-get-pass-opportunity-audit.md` or create a successor numbered audit if the scope outgrows struct atomic gets.
    - [ ] Add public-pipeline guard fixtures for DCE, precompute, local-cse, optimize-instructions, simplify-locals, and any module remapping pass touched by the family.
    - [ ] Re-run direct pass compare smokes for any pass whose behavior changes; scale to 10000 only for behavior-changing optimizer rewrites.
    - [ ] Keep GSI/heap2local/global-type-optimization claims conservative unless a family-specific semantic proof supports optimization.
  - Suggested tests: family-specific pass tests, `moon test src/passes`, targeted compare-pass smokes, and docs/wiki log updates.
  - Exit criteria: no newly implemented shared-everything instruction is treated as pure/deletable/remappable-by-accident, and all durable pass decisions are documented.

### INL - Deferred Inliner Breadth

- [INL]005 - Partial Inlining Splitter
  - Status: deferred to v0.2.0; not a v0.1.0 blocker.
  - Resume only if a reduced Pattern A/B fixture demonstrates one of: semantic or validation correctness, a clear pass-local performance win, a downstream size/optimization win that offsets code growth, or a user-facing need for `no-partial-inline` splitter behavior.
  - Deliverables when resumed: implement or explicitly reject/scope out Pattern A and Pattern B splitting, add reduced splitter and helper-cleanup fixtures, define `no-partial-inline` behavior against the splitter, and compare direct `--pass inlining` / `--pass inlining-optimizing` on split-family repros.

- [INL]006 - Residual Name/Annotation Repair
  - Status: deferred to v0.2.0.
  - Resume only with a concrete user-facing debug-name requirement, annotation-collision requirement, semantic mismatch, wasm validation failure, or proven pass-local performance/code-size issue.
  - Deliverables when resumed: add focused repair tests first, then either implement deterministic Binaryen-like local/label name reconstruction and broader annotation collision repair or explicitly document the unsupported surface as rejected.

### Tooling And Runtime Follow-Up

- [TOOL]001 - Self-Optimize Compare Normalization Symmetry
  - Goal: make the exact artifact helper stop reporting harmless raw/debug-only outer-block drift as a pass blocker.
  - Deliverables: either canonicalize Binaryen through the same strip-debug path before canonical-function comparison while preserving `binaryen.raw.wasm`, or teach the canonical-function fallback to ignore transparent unused-label void block wrappers.
  - Acceptance: the exact-slot artifact command no longer reports `defined=200 abs=217` solely because Binaryen raw `--debug` kept an outer block that symmetric normalization removes.

- [HOT]003 - Node-Package Worker Queue Port
  - Status: deferred behind [HOT]002 and future Node package rebuild work.
  - Deliverables: reuse the native hot-batch queue contract in the shipped Node package with `worker_threads`, one WasmGC module per worker, worker-local heap state, and stable-order serialized merge.
  - Dependencies: [HOT]002 native queue contract, worker-local function serialization hooks, and future Node package rebuild work.

### FUZ - Fuzzer Hardening and GenValid Widening

#### Tiny FUZ work-slice board

Use this board as the tracking view for fuzzer work. Each slice should be small enough for one focused TDD loop: add/adjust focused tests, implement one narrow behavior, update docs/wiki counters, and run the targeted fuzz smoke plus `moon test src/fuzz` or the relevant package test. Prefer finishing p1 GenValid/metamorphic slices before p2 infrastructure unless a bug or release need says otherwise.

p1 next-up / active:
- None currently tracked. Prefer adding a new tiny GenValid/metamorphic slice before broad p2 infrastructure work if a release need appears.

p2 invalid/binary/text tiny slices:
- Census note: `[FUZ]1020D1` audited the checked-in invalid-AST registry and wiki history. The registry currently has 265 deterministic AST-invalid strategy specs across all 15 `ValidationIssueFamily` buckets after `[FUZ]1020F3` added packed-field plain-accessor coverage. Already-covered breadth includes the closed `[FUZ]1020A`/`B`/`C`/`D3`/`D4`/`D5`/`E1`/`E2`/`E3`/`E4`/`E5`/`F1`/`F2`/`F3` families: start out-of-range/wrong-kind plus imported-start signature variants, cross-kind duplicate export names, datacount absent/too-small/too-large plus mixed active/passive cardinality mismatch, element function-index/typed-expression/table-index basics plus active element/table ref-type mismatch, table/data/memory bulk operand/index families, atomics non-shared, natural-alignment, and stack/index families, SIMD lane/operand/index families, GC aggregate/input/variance/descriptor basics plus final-supertype policy, descriptor `describes` previous-definition boundary, and packed-field accessor-shape failures, ref/branch payloads including `br_on_null`, `br_on_non_null`, `br_on_cast`, multi-value `br_table` arity, `call_indirect` table element compatibility, `return_call_indirect` table element compatibility, ordinary `try_table` catch payload mismatch, and `try_table` `catch_ref` payload-plus-exnref mismatch, name-map out-of-range indices, and code-section cardinality/imported-body families. Name-section indirect-map ordering/count invalidity was classified by `[FUZ]1020G1` as binary/codec-invalid rather than AST-invalid: `NameMap` and `IndirectNameMap` arrays can be constructed in memory, but `src/binary/encode.mbt` rejects non-increasing indices with `InvalidNameMapOrder`, `src/binary/decode.mbt` rejects malformed ordered/count payloads before validation, and existing binary invalid tests cover the decode/validate split. Do not add an AST-invalid strategy for ordering/count unless the in-memory model gains a representation that bypasses codec ordering invariants and reaches `validate_name_sec(...)`.





p2 oracle/reporting/infrastructure tiny slices:
- None currently tracked. Add a new tiny slice before broad oracle/reporting/infrastructure work.
