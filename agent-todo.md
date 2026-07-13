# Agent Tasks

## Scope
- Keep only active unreleased work or explicitly deferred future work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Move completed work and historical evidence to the relevant docs/wiki page, release notes, or git history.

## Current Parity Focus
- Keep the Binaryen no-DWARF default optimize path as the v0.1.0 parity target.
- Canonical order and nested-shape notes live in `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` and `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`.
- Prefer direct-pass Binaryen behavior parity first, then ordered-neighborhood replay, then preset scheduling.
- Behavior parity is not byte-for-byte wasm/text parity: exact helper shape, local numbering, and raw canonical output may differ when semantic evidence proves the same observable behavior. It is also not satisfied by a green fuzz lane if source/docs still list broad unimplemented Binaryen transform families.
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
    - [ ] Recover optimization precision one pass at a time only with focused tests and semantic evidence: nested SSA liveness, safe commutative operand ordering, local.tee-aware simplify-locals sinking, remaining path-sensitive coalesce-locals slot drift, and branchy structured vacuum cleanup.
  - Suggested tests: `moon fmt`, `moon test src/passes`, `moon build --target native --release src/cmd`, `bun test scripts/lib/o4z-debug-startup-map.test.ts`, `wasm-tools validate --features all tests/repros/o4z-debug-startup-map-init-repro.wasm`, `wasm-tools validate --features all .tmp/o4z-bench/starshine-o4z-candidate.wasm`, and the self-optimized spec smoke commands listed in the research note.

### json-as debug artifact triage

- [JSON-AS]002 - `vacuum` after repeated `remove-unused-names` corrupts json-as debug runtime state
  - Status: active correctness blocker found after removing all `remove-unused-brs` slots from the same 2026-06-05 `json-as` preset replay.
  - Goal: identify whether `vacuum`, `remove-unused-names`, or HOT lowering/splice cleanup corrupts stack/object state when `vacuum` cleans the post-`remove-unused-names` artifact.
  - Why: with all `remove-unused-brs` slots removed, `medium.bench.incremental.naive.debug.wasm` still failed. The first failing prefix was `memory-packing -> once-reduction -> global-refining -> global-struct-inference -> ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-names -> vacuum`. Prefix 8 ran repeatedly; prefix 9 serialized once and then failed during GC with `abort: Index out of range in ~lib/rt.ts:21`, followed by an `unreachable` in `~lib/rt/__typeinfo`, reached from `~lib/rt/itcms/Object#get:isPointerfree`, `Object#makeGray`, `__visit`, and `Array<RecentActivity>#__visit`.
  - Finding: the printed prefix-8-to-prefix-9 diff mostly shows removal of `const; drop` debris, but several array constructor / setter / assertion functions also show stack/local traffic moving around stores. The module validates, so the actionable issue is a runtime semantic corruption in cleanup or lowering, not malformed wasm. 2026-06-05 follow-up found the vacuum mutation itself was small, but HOT lowering after vacuum reassociated root stack values across `local.set` / call sequences in array constructors and setters; vacuum now conservatively skips root regions that mix root `local.set` with stack-effecting calls or memory copies/fills. The no-RUB prefix 9 and normal prefix 10 now validate and complete the medium-naive Node smoke.
  - Suggested tests: focused `src/passes/vacuum*_test.mbt` or pass-manager prefix fixture, `moon test src/passes`, `moon build --target native --release src/cmd`, and cloned `json-as` prefix replay without `remove-unused-brs` slots.

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

- [JSON-AS]008 - Schedule and measure `strip-debug` for debug custom-section stripping
  - Status: direct module pass implemented and scheduled as the final public `optimize` / `shrink` preset pass; active artifact measurement follow-up remains. `src/passes/strip_debug.mbt` and `src/passes/strip_debug_test.mbt` register and test `strip-debug`; `bun scripts/pass-fuzz-compare.ts --list-passes` lists it. The old "not implemented yet" wording is superseded by the 2026-06-07 behavior inventory. 2026-06-25 direct evidence in `docs/wiki/raw/research/0908-2026-06-25-strip-debug-custom-section-preservation.md` narrows Starshine to Binaryen-shaped name-section stripping while preserving non-name custom sections. 2026-06-25 preset evidence in `docs/wiki/raw/research/0909-2026-06-25-strip-debug-preset-placement.md` schedules `strip-debug` after `directize` in both presets; remaining work is json-as artifact measurement.
  - Goal: decide whether and where to schedule explicit `strip-debug` / `StripDebug` in size/optimize paths after direct-pass and artifact evidence.
  - Why: 2026-06-05 `json-as` size metrics showed Starshine O4 still carrying non-semantic `name` custom-section bytes in fixed standard artifacts while Binaryen O4 carried no custom sections. Current evidence: `medium.bench.incremental.naive.starshine-o4.wasm` has `14549` total custom-section bytes and `large.bench.incremental.swar.starshine-o4.wasm` has `15743`, all from the `name` custom section; `medium.bench.incremental.simd.starshine-o4.wasm` currently has `0`. This is a deterministic size gap independent of the deeper live-function/type cleanup gap.
  - Deliverables:
    - [ ] Re-measure `json-as` custom-section deltas after scheduling; expected immediate wins are about `14.5KB` on medium-naive and `15.7KB` on large-swar before addressing remaining function/type cleanup.
  - Suggested tests: focused `src/passes/strip_debug*_test.mbt`, `moon test src/passes`, `moon test src/cmd` if CLI/help changes, `moon build --target native --release src/cmd`, direct `--strip-debug` compare evidence, `wasm-tools validate --features all` on rewritten `json-as` artifacts, and Node runtime smoke for the three fixed `json-as` cases.

- [JSON-AS]004 - Keep a cloned json-as benchmark replay for optimizer artifact signoff
  - Status: active artifact-signoff follow-up; 2026-06-06 full `as-test` suite replay is Starshine-green for the pinned clone but not yet scripted as a durable repo task.
  - Goal: make the `json-as` debug-artifact comparison repeatable without relying on temporary restored wasm files under `examples/`.
  - Why: the restored example wasm files were already heavily optimized and made Starshine look size-regressive. A fresh git clone of `json-as` at `f707d68d5ce5136ecfd0c576140421286c9e93a8`, local `bun install`, `assemblyscript@0.28.17`, and `bun run build:transform` produced debug artifacts where Binaryen O4 runs successfully and Starshine currently validates but traps. The clone path used during triage was `.tmp/json-as`, which is intentionally not durable. On 2026-06-06, the stronger suite replay built all 105 configured `as-test` wasm artifacts (`35` specs across `naive`, `swar`, and `simd`) with a Node WASI runner, optimized them with current Starshine `--traps-never-happen --closed-world --optimize -O4`, validated every output with `wasm-tools validate --features all`, and ran the full suite successfully: `35` files, `1284` suites, `10656` tests, `3` modes, `0` failures. The comparable Binaryen `wasm-opt --all-features --traps-never-happen --closed-world -O4` suite replay also passed. Starshine suite outputs total `57,167,519` bytes versus Binaryen `44,705,784` bytes (`+27.87%`), so correctness is ahead of size parity.
  - Runtime measurement note: without `d8`/`v8` available locally, the 2026-06-06 direct performance pass used the Node WASI test artifact runner as a proxy, not the official `json-as` benchmark harness. Two cold process runs per optimized suite artifact gave summed medians of Starshine `161,962.7ms` vs Binaryen `153,542.5ms` (`+5.48%` Starshine slower overall): `naive` `+17.73%`, `simd` `-0.48%`, `swar` `-0.69%`. Treat these as local artifact-runner timing evidence only; stable benchmark claims still require the real benchmark runtime.
  - Deliverables:
    - [ ] Add a documented, opt-in replay command or task that clones `json-as` into `.tmp/`, pins AssemblyScript `0.28.17`, builds `large` SWAR, `medium` NAIVE, and `medium` SIMD debug artifacts, and emits Starshine/Binaryen outputs without touching committed examples.
    - [ ] Prefer the repo's `d8` runner when available; otherwise use a checked-in Node runner equivalent for local smoke comparisons.
  - Suggested tests: opt-in script/task dry run, `wasm-tools validate --features all` on all generated outputs, and runtime smoke under Node or `d8` for debug, Binaryen O4, and Starshine outputs.

### Whole-command wall-time budget

- [WALL]001 - Cross-Pass Runtime Budget And Attribution
  - Goal: own whole-command Starshine-vs-Binaryen wall-time measurement outside individual pass parity slices.
  - Why: direct pass slices may be signed off while aggregate preset or no-op command paths still hide parse/emit, validation, HOT lift/lower, cache, or buffering costs.
  - Current known target: direct `--ssa-nomerge` whole-command replay on `tests/node/dist/starshine-debug-wasi.wasm`; 2026-06-14 attribution shows the wall spike is raw SSANM work, not the parsed `pass:*` timer.
  - Current evidence: `.tmp/self-ssa-nomerge-debug-wasi-walltime-investigation-final-20260614/result.json` recorded Starshine `4564.108ms` wall time, `0.199ms` pass-local time, `1590.243ms` `raw:ssa-nomerge:*` time, `466.093ms` other traced time, and `2507.573ms` untraced overhead vs Binaryen `918.897ms` wall / `431.565ms` pass time. Command-level traced phases were read `5.919ms`, decode `153.825ms`, final validate `154.813ms`, reuse check `1.302ms`, encode `137.987ms`, and output write `5.719ms`. Top raw functions are now small and spread out, led by `Func 499` `_M0FP37jtenner9starshine6passes41dae__instr__is__nontrapping__pure__binary` (`26.630ms`), `Func 3781` `_M0FP37jtenner9starshine6binary32decode__instruction__with__depth` (`9.515ms`), `Func 498` `_M0FP37jtenner9starshine6passes40dae__instr__is__nontrapping__pure__unary` (`8.576ms`), and `Func 3490` `_M0MP37jtenner9starshine4wast12KeywordTable3new` (`8.542ms`). Earlier stale-binary attribution in `.tmp/self-ssa-nomerge-debug-wasi-walltime-investigation-func-fixed-20260614` showed a 59s raw cliff; the current rebuilt binary supersedes it. 2026-06-30 vacuum slot23 trace-batching reduced the direct `--vacuum` trace to `42` lines, but the timing-only repeats still measured Starshine whole-command `623.617ms` / `634.730ms` vs Binaryen `540.657ms` / `565.452ms`; Starshine pass-local stayed faster (`1.916ms` / `1.887ms` vs `145.407ms` / `147.442ms`), leaving residual wall primarily in generic decode/final-validate/encode plus the remaining `guard:vacuum-writeback-batch`, not trace volume.
    - Separate pass-local runtime, raw fast-path runtime, harness/tool startup, parse/emit, validation, HOT lift/lower, analysis cache, and artifact representation costs.
    - Maintain a prioritized list of cross-cutting runtime fixes without blocking pass correctness signoff on aggregate wall time.
    - Evaluate remaining non-pass candidates such as encoder size/backpatch and code-section buffering reduction.
  - Suggested tests: focused timing traces, `moon info`, `moon fmt`, `moon test`, and targeted self-compare commands for any changed pass/tool path.

- [WALL]002 - Self-optimization O4z wall time is dominated by `inlining-optimizing`
  - Status: root cause fixed 2026-06-15; keep active for follow-up sub-hotspot optimization and full self-opt signoff.
  - Goal: reduce or explicitly gate the `inlining-optimizing` whole-module runtime on the Starshine debug CLI artifact before treating self-optimization as practical for routine use.
  - Why: the successful traced run `.tmp/self-opt-after-live-label-fix.stderr` spans about `13m18s` by file timestamps (`03:53:42` to `04:07:00`). Trace timer attribution shows a single `pass:inlining-optimizing` instance taking `676.916s` (`11m16.9s`), about `85%` of the observed wall time. The next largest pass timer is `dae-optimizing` at `1.914s`; cumulative HOT `lift` across `35,631` function-pass lifts is `3.017s`, `merge-blocks` totals `0.424s` across `12,994` calls, and module verification/final validation timers are sub-second per pass. Current inlining trace only reports nested cleanup touched counts (`1932`, `465`, `70`, `6`, `1`) and has no internal phase timers, so the bottleneck is localized to `src/passes/inlining.mbt` / `inlining_run_module_pass` but not yet subdivided between graph analysis, function-info building, call rewriting, helper removal, nested cleanup, and iteration/fixed-point control.
  - Suggested tests: `moon fmt`, focused `src/passes/inlining*_test.mbt`, `moon test`, `moon build --target native --release src/cmd`, timed `bun self-opt optimize`, and any direct `inlining-optimizing` compare lane needed after behavior changes.

### O4z Per-Pass Deep Audits

Release gate: complete these before the v0.1.0 release so `-O4z` pass coverage is more comprehensive and pass-local runtime owners are known before publishing.

Use this checklist for every `[O4Z-AUDIT-*]` slice below:
- Start from the pass wiki page and owner source/test files; update docs if findings become durable.
- Treat the target as Binaryen behavior parity, not output parity. A direct compare lane with `0` mismatches is necessary evidence, but it does not close an audit while docs still say the pass is a narrow subset or list broad missing Binaryen behavior.
- Run or refresh direct pass oracle evidence by building `src/cmd` once (`moon build --target native --release src/cmd`) and using `bun scripts/pass-fuzz-compare.ts --pass <name> --count 1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` first, then scale to 10000 only when changing behavior or closing the slice.
- Inspect tests for missing positive/negative shapes, add focused test-first fixtures for any bug or missed optimization, and keep validation failures separate from representation drift.
- Capture pass-local timing where available; file whole-command issues under `[WALL]001` unless the pass is clearly the owner.
- Replay the pass's `-O4z` slot/neighborhood when it has saved artifacts or documented generated-audit evidence.
- Close with an agent-classified findings note: bugs found/fixed, missing behavior added, representation-only drift, tool/oracle failures, performance owners, deferred risks, exact commands, counts, and artifact paths.
- Do not remove an audit from this backlog unless every remaining Binaryen behavior difference is narrow, evidence-backed, tool-blocked or explicitly accepted as a non-goal, and linked to reopening criteria.

Behavior inventory source: `docs/wiki/raw/research/0714-2026-06-07-o4z-behavior-parity-inventory.md`.

Reopened from prior removed audits because committed docs still list behavior gaps:

- [O4Z-PRESET-BEHAVIOR] - Reconcile documented Binaryen no-DWARF order with Starshine public presets
  - Status: active behavior-inventory slice; do not widen presets until direct pass audits and ordered neighborhoods are green.
  - Current finding: after the DFE audit and the 2026-07-12 public `reorder-locals` scheduling update, public `optimize` / `shrink` include Binaryen-shaped early and late DFE neighborhoods, the public three-slot `reorder-locals` cleanup story, `dae-optimizing`, `inlining-optimizing`, `duplicate-import-elimination`, and one early `remove-unused-module-elements` slot. Remaining documented count/order gaps are now outside DFE and RL scheduling: the second pre-pass `remove-unused-module-elements`, `code-folding`, `redundant-set-elimination`, and the known extra Starshine `remove-unused-brs` slot. Local `wasm-opt --version` now reports `version_130`, so the exact path needs a fresh `version_130` reread before final non-DFE scheduling claims.
  - Deliverables: refresh the no-DWARF path against the current local `version_130` oracle, add exact preset-order tests for any changes, and keep repeated cleanup slots intentional unless an ordered-neighborhood proof justifies divergence.

### Coalesce-locals direct-pass parity

- [COALESCE-LOCALS]001 - Random-all `heap2local-struct` local declaration / renumbering debris
  - Status: active direct-pass parity investigation for `coalesce-locals` against current Binaryen direct `--coalesce-locals`; do not mark closed until a future slice either accepts the normalization boundary with durable evidence or implements safe raw-parity local packing.
  - Shared random-all evidence: direct `--coalesce-locals` compare against Binaryen over the `random-all-profiles` GenValid lane requested/compared `1000/1000`, normalized matches `837`, raw mismatches `163`, validation failures `0`, generator failures `0`, command failures `0`. Mismatch selected-profile breakdown: `heap2local-struct=38`, `ssa-nomerge-smoke=125`, newly added `coalesce-locals-*` profiles `0`. All `652` mismatch artifacts validate with `wasm-tools validate --features all` (`binaryen.raw.wasm`, `starshine.raw.wasm`, `binaryen.wasm`, `starshine.wasm` across all `163` mismatch dirs). Downstream convergence check `wasm-opt -O -all binaryen.raw.wasm -o b.wasm; wasm-opt -O -all starshine.raw.wasm -o s.wasm; cmp b.wasm s.wasm` made all `163` optimized pairs byte-identical; optimized size delta after downstream `-O` is `0` for both mismatch families.
  - Correctness constraints for any fix: use exact local type equality only, never subtype-based coalescing; preserve parameter semantics; preserve implicit zero-initialized local semantics; preserve `local.tee` stack semantics; be conservative around branch/loop/control-flow carriers unless proven safe; do not classify a mismatch as a Starshine win merely because both outputs validate or downstream cleanup erases it.
  - Classification: cleanup-normalized local-declaration / local-renumbering debris. This is not a Starshine win and is not a semantic mismatch based on current validation and downstream convergence evidence. Starshine raw output is larger in all `38` cases (total `+471` bytes, mean `+12.39`); canonical wasm size is equal in all `38`; normalized WAT size is equal in all `38`; the existing `local-cleanup-debris` normalizer accounts for all `38`; downstream `wasm-opt -O` makes each pair byte-identical.
  - Representative shape: input has locals like `(local i32 (ref null 0) (ref null 4))` with the used nullable struct ref local originally at index `2`. Binaryen maps the used nullable struct ref local to an earlier local index. Starshine preserves unused leading declaration debris and leaves the used ref local at a later index. Treat this as local declaration packing / logical-local renumbering, not same-type-slot coalescing.
  - Reduced repro candidate:

    ```wat
    (module
      (type $F (func))
      (type $S (struct (field (mut i32)) (field eqref)))
      (func (export "main")
        (local i32)
        (local (ref null $F))
        (local (ref null $S))

        (local.set 2
          (struct.new $S
            (i32.const 10)
            (ref.null none)
          )
        )

        (struct.set $S 0
          (local.get 2)
          (i32.const 30)
        )

        (drop
          (struct.get $S 0
            (local.get 2)
          )
        )
      )
    )
    ```

  - Suggested action: accept current `local-cleanup-debris` normalization as the narrow boundary unless exact raw parity is required. If exact raw parity is required, implement a safe final local-packing / renumbering step after coalescing: keep params fixed; build final coalesced logical-local groups; mark groups used if referenced by `local.get`, `local.set`, or `local.tee`; assign new non-param indices to used groups first, matching Binaryen's observed ordering if possible; append unused local declarations later; rewrite every local index use consistently; preserve each logical local's exact type; validate after rewriting. This must not be implemented as unsafe same-type slot reuse. Binaryen appears to be renumbering logical locals, not coalescing an `i32` slot with a nullable ref slot.
  - Risk areas: params are not implicit-zero locals; nullable refs are defaultable but nondefaultable refs require preserving set-before-get proof; exact logical-local type must move with the local index.
  - Suggested reduced tests: the GC ref local declaration packing case above; exact-type-only ref test using a base struct and subtype struct to prevent subtype-based coalescing; param/implicit-local-initialization test ensuring a non-param local does not inherit param semantics.
  - Replication: use the existing pass compare harness in direct-pass form, e.g. conceptual lane `bun scripts/pass-fuzz-compare.ts --pass coalesce-locals --gen-valid-profile random-all-profiles ...`, or the equivalent direct `--coalesce-locals` Starshine-vs-Binaryen compare. Expected high-level result from this investigation: `1000` compared, `837` normalized matches, `163` raw mismatches, `38` `heap2local-struct`, `125` `ssa-nomerge-smoke`, `0` validation/generator/command failures. Validate mismatch artifacts with `wasm-tools validate --features all binaryen.raw.wasm`, `wasm-tools validate --features all starshine.raw.wasm`, `wasm-tools validate --features all binaryen.wasm`, and `wasm-tools validate --features all starshine.wasm`. Check downstream convergence with `wasm-opt -O -all binaryen.raw.wasm -o b.wasm; wasm-opt -O -all starshine.raw.wasm -o s.wasm; cmp b.wasm s.wasm`.

- [COALESCE-LOCALS]002 - Random-all `ssa-nomerge-smoke` downstream-equivalent local cleanup drift
  - Status: active direct-pass parity investigation for `coalesce-locals` against current Binaryen direct `--coalesce-locals`; do not mark closed until a future slice either implements a narrow cleanup fix or records a separately named normalization boundary.
  - Shared random-all evidence: same direct `--coalesce-locals` random-all lane as `[COALESCE-LOCALS]001`: requested/compared `1000/1000`, normalized `837`, raw mismatches `163`, failures `0`, selected-profile breakdown `heap2local-struct=38`, `ssa-nomerge-smoke=125`, newly added `coalesce-locals-*` profiles `0`; all raw/canonical mismatch artifacts validate, and downstream `wasm-opt -O` makes all `163` pairs byte-identical with optimized size delta `0` for both families.
  - Correctness constraints for any fix: exact local type equality only; preserve params, implicit-zero non-param locals, `local.tee` stack values, and control-flow carrier semantics; be conservative around branches, loops, block exits, EH/control constructs if present, params, and nondefaultable refs; do not claim a Starshine win from validation alone or downstream convergence alone.
  - Classification: downstream-`-O` equivalent local-cleanup drift; raw-size-losing direct-pass parity gap. This is not currently a Starshine win and is not a semantic mismatch based on current validation and downstream convergence evidence. The existing `local-cleanup-debris` normalizer does not account for these `125` mismatches. Starshine raw output is larger in all `125` cases (total `+1687` bytes, mean `+13.5`); canonical wasm sizes are equal in all `125`; Starshine normalized WAT is consistently larger by `+23` chars per case; downstream `wasm-opt -O` makes all `125` pairs byte-identical.
  - Aggregate opcode/count observation across all `125` cases, computed as Starshine WAT minus Binaryen WAT:

    ```text
    local.set: -500
    local.get: +125
    drop:      +625
    nop:       +125
    ```

  - Interpretation: fewer `local.set`s alone is not enough evidence for a Starshine win. The extra `drop`, `nop`, and `local.get` debris plus consistent raw-size loss means this remains a direct-pass parity gap unless stronger performance evidence is collected. Likely shapes include dead store converted to `drop` in one output but not the other; branch/return path dead local cleanup differences; block/`br_if` carrier liveness differences; final `local.set tmp; nop; drop(local.get tmp)` forwarding missed by Starshine; different cleanup order around coalescing, SSA no-merge stress, and local DCE.
  - Reduced repro candidates:

    ```wat
    ;; 1. Terminal return dead store.
    (module
      (func (export "main") (param $p i32)
        (local $x i32)

        (if (local.get $p)
          (then
            (local.set $x (i32.const 7))
            return
          )
        )

        (local.set $x (i32.const 9))
        (drop (local.get $x))
      )
    )
    ```

    ```wat
    ;; 2. Block branch dead store where local is not read after the block.
    (module
      (func (export "main") (param $p i32)
        (local $x i32)

        (block $exit
          (if (local.get $p)
            (then
              (local.set $x (i32.const 7))
              (br $exit)
            )
          )

          (local.set $x (i32.const 9))
        )

        (drop (i32.const 0))
      )
    )
    ```

    ```wat
    ;; 3. Negative branch carrier case where the local is live after the block.
    (module
      (func (export "main") (param $p i32)
        (local $x i32)

        (block $exit
          (if (local.get $p)
            (then
              (local.set $x (i32.const 7))
              (br $exit)
            )
          )

          (local.set $x (i32.const 9))
        )

        (drop (local.get $x))
      )
    )
    ```

    ```wat
    ;; 4. br_if carrier negative case.
    (module
      (func (export "main") (param $p i32)
        (local $x i32)

        (local.set $x (i32.const 7))

        (block $b
          (br_if $b (local.get $p))
          (local.set $x (i32.const 9))
        )

        (drop (local.get $x))
      )
    )
    ```

    ```wat
    ;; 5. Final forwarding debris shape.
    (module
      (func (export "main")
        (local $tmp i32)

        (local.set $tmp (i32.const 122))
        nop
        (drop (local.get $tmp))
      )
    )
    ```

    ```wat
    ;; 6. local.tee stack semantics guard.
    (module
      (func (export "main")
        (local $x i32)

        (drop
          (i32.add
            (local.tee $x (i32.const 121))
            (i32.const 1)
          )
        )

        (drop (local.get $x))
      )
    )
    ```

  - Suggested action: prefer a narrow Starshine cleanup fix if direct `coalesce-locals` raw parity matters. Candidate cleanup rules: dead `local.set` to `drop` only when the assigned value is not read on any path before overwrite or function exit; `local.tee` write removal only when the local write is dead while preserving the stack value; `local.set tmp; nop*; drop(local.get tmp)` to `drop(expr)` only when the get is the only use of the set value and there are no intervening effects/control-flow hazards. Validate transformed functions. If not fixing now, add/use a narrow explicitly named normalizer such as `dead-local-cleanup-debris`, but keep it reported separately from true direct normalized matches.
  - Evidence required before calling either `[COALESCE-LOCALS]001` or `[COALESCE-LOCALS]002` a Starshine win: raw/code-body size improvement, not regression; or canonical/downstream optimized size improvement; or measured runtime improvement with confidence intervals; or measured engine compile-time or generated-code-size improvement; or correctness/validation advantage over Binaryen. For `ssa-nomerge-smoke`, fewer `local.set`s alone is insufficient because Starshine currently has more `drop`, `nop`, and `local.get` debris and larger raw output. Any win claim must state whether it applies before or after downstream `-O`; after downstream `-O`, all current mismatch pairs converge byte-identically, so there is no remaining post-`-O` win in the current evidence.
  - Replication: use the existing pass compare harness in direct-pass form, e.g. conceptual lane `bun scripts/pass-fuzz-compare.ts --pass coalesce-locals --gen-valid-profile random-all-profiles ...`, or the equivalent direct `--coalesce-locals` Starshine-vs-Binaryen compare. Expected high-level result from this investigation: `1000` compared, `837` normalized matches, `163` raw mismatches, `38` `heap2local-struct`, `125` `ssa-nomerge-smoke`, `0` validation/generator/command failures. Validate mismatch artifacts with `wasm-tools validate --features all binaryen.raw.wasm`, `wasm-tools validate --features all starshine.raw.wasm`, `wasm-tools validate --features all binaryen.wasm`, and `wasm-tools validate --features all starshine.wasm`. Check downstream convergence with `wasm-opt -O -all binaryen.raw.wasm -o b.wasm; wasm-opt -O -all starshine.raw.wasm -o s.wasm; cmp b.wasm s.wasm`.

- [O4Z-AUDIT-SSA-FULL] - Deep audit public full `ssa` sibling
  - Status: active sibling backlog split out of `[O4Z-AUDIT-SSA]` by `[SSANM-007c]` on 2026-06-13. Keep these slices about Binaryen `SSAify(true)` full merge-local behavior; do not count them as `ssa-nomerge` closeout prerequisites except where a contrast test documents the sibling boundary.
  - Scope: direct public `--pass ssa` behavior, including non-merge freshening/default materialization already active in Starshine, plus still-open merge-local materialization, incoming `local.tee`/entry-prepend handling, full-SSA loop/branch/EH/typed-control boundaries, and direct-pass signoff.
  - Current finding: `src/passes/ssa.mbt` registers an active partial full-`ssa` hot pass. It builds an analysis-only merge plan, routes non-merge families through the shared no-merge rewrite, and deliberately leaves merge families fail-closed until the remaining `[SSA-FULL-*]` slices materialize Binaryen-style merge locals.
  - Active `SSA-FULL` work slices:
    - [ ] [SSA-FULL-002D] - Handle entry/default merge inputs and prepend ordering
      - Goal: complete full-SSA merge materialization for parameter-entry and default-entry sources, including function-entry prepends for parameter inputs and default materialization without illegal nondefaultable refs.
      - Deliverables: red-first tests for parameter-entry one-arm merges, default-entry one-arm merges, exact nullable ref defaults, skipped nondefaultable default entries, and deterministic local/prepend ordering.
      - Suggested evidence: focused `src/passes/ssa_test.mbt`, validation of lowered modules, and direct `--pass ssa` compare/fuzz when available.
    - [ ] [SSA-FULL-002E] - Classify loop, branch, EH, and typed-control full-SSA boundaries
      - Goal: decide which loop/backedge, branch-exit, `br_table`, EH, and typed-control families can safely use full-SSA merge materialization and which need fail-closed or dedicated typed/EH helpers.
      - Deliverables: positive or deliberately fail-closed fixtures, source-backed ownership notes, and docs updates that keep full `ssa` behavior separate from `SSANM` no-merge boundaries.
      - Suggested evidence: focused `src/passes/ssa_test.mbt`, direct compare for admitted mutation families, and wiki/backlog updates.
    - [ ] [SSA-FULL-003] - Direct full `ssa` closeout signoff
      - Goal: close the direct public `ssa` pass only after merge-local materialization, entry/default handling, and boundary decisions are implemented or explicitly deferred.
      - Deliverables: final parity/status note in `docs/wiki/binaryen/passes/ssa/`, exact test/fuzz commands and results, remaining accepted boundaries with reopening criteria, and backlog cleanup.
      - Suggested evidence: `moon info`, `moon fmt`, focused `ssa_test.mbt`, `moon test src/passes`, full `moon test`, native build, and a direct `--pass ssa` compare lane if supported.

- [O4Z-AUDIT-DAE] - Deep audit `dae-optimizing`
  - Status: active v0.1.0 release-gating `-O4z` per-pass audit.
  - Scope: dead argument/result removal, nested cleanup scheduler, selected-shape genericization, raw cleanup policy, type liveness, and pass-local runtime.
  - Deliverables: apply the common checklist; coordinate with `[AUDIT003-*]`; refresh DAE-normalized direct compare and late `DAE` slot evidence; keep accepted raw-cleanup drift separate from semantic mismatches.

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
  - Status: active follow-up from the 2026-05-31 optimizer audit. The former `global-refining` thin-coverage item is retired because the 2026-06-18 direct Binaryen behavior audit closed GR-001..GR-006 and published focused coverage plus 100000-case compare evidence.
  - Goal: make hot pass `requires` metadata describe every analysis a pass may request through `pass_require_*`, so the registry remains a truthful pass-author contract and future scheduling/perf tooling can trust descriptors.
  - Why: the audit found passes that lazily request analyses without listing them in `requires`; tests currently pass because the helper layer builds analyses on demand, but the metadata contract is stale.
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
    - [ ] `[AUDIT004-L]` `once-reduction`: add separate tests for table escape, global escape, `ref.func` escape, export escape, start-function behavior, imported function negative, exported function negative, and multi-use once-positive.
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
    - [ ] Add generic pass guard tests proving optimization passes do not delete, merge, or move global atomic operations unsafely.
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
    - [ ] Add pass guard tests for optimization passes and any array-specific passes once they exist.
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
    - [ ] Add public-pipeline guard fixtures for optimization and module-remapping passes touched by the family.
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

## OI-L follow-up blocker (2026-07-03)

Goal: finish OI-L after partial local-receiver implementation.

Current state:
- Aggregate atomic RMW/cmpxchg binaries decode/encode/validate and native probe smoke passes.
- `optimize-instructions` rewrites local-receiver unshared struct RMW/cmpxchg and identity cmpxchg/RMW in the focused OI-L test.
- Array aggregate atomics are intentionally unchanged.

Remaining blocker:
- Global-receiver/native Binaryen-shaped struct probes still expose a HOT lift/lower result-root sentinel issue: mutating them can lower to `unreachable`. The pass is fail-closed to unchanged unless the struct receiver is `local.get`.

Exit criteria:
- Fix HOT lift/root result handling for aggregate atomic result bodies, or add an equivalently safe raw rewrite.
- Widen the receiver gate to at least `global.get` after red-first coverage.
- Confirm struct probes rewrite in native WAT, array probes preserve array atomics, all outputs validate, then update the OI-L matrix row from partial/blocker to the final classification.
