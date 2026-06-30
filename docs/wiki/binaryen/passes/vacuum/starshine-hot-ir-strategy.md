---
kind: concept
status: working
last_reviewed: 2026-06-30
sources:
  - ../../../raw/binaryen/2026-04-22-vacuum-primary-sources.md
  - ../../../raw/research/0249-2026-04-22-vacuum-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md
  - ../../../raw/research/0210-2026-04-21-vacuum-source-confirmation-followup.md
  - ../../../raw/research/0520-2026-05-06-vacuum-direct-revalidation.md
  - ../../../raw/research/0097-2026-04-18-generated-o4z-vacuum-slot23-func652-stack-underflow.md
  - ../../../raw/research/0098-2026-04-18-generated-o4z-vacuum-slot33-func1818-stack-underflow.md
  - ../../../raw/research/0106-2026-04-18-generated-o4z-vacuum-slot23-retired-by-carrier-wrapper-guard.md
  - ../../../raw/research/0107-2026-04-18-generated-o4z-vacuum-slot33-retired-by-validator-escape-fix.md
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/trace_golden_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./effect-pruning-and-traps-never-happen.md
  - ./wat-shapes.md
---

# Starshine HOT-IR Strategy For `vacuum`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-vacuum-primary-sources.md`](../../../raw/binaryen/2026-04-22-vacuum-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show exactly where the current MoonBit implementation lives and how the local HOT-plus-pipeline split is wired today.

## Exact local code map

The fastest read-along path through the current Starshine implementation is:

- registry descriptor, summary, and preset visibility in `src/passes/optimize.mbt`
  - hot-pass registration for `vacuum`
  - summary text: `Remove \`nop\` roots and region entries through hot IR cleanup.`
  - invalidated analyses list on the `HotPassDescriptor`
- main hot-pass dispatch in `src/passes/pass_manager.mbt`
  - the `"vacuum"` dispatch arm in the hot-pass runner
  - `hot_pass_remove_region_nops(...)`, which is the whole current rewrite engine
- writeback and debug-pipeline support in `src/passes/pass_manager.mbt`
  - the `descriptor_name == "vacuum"` writeback-validation guard path
  - the `run_hot_pipeline_debug_dump_enabled(...)` special-case target for traced debug dumps on the saved artifact hotspot function
- focused local proof surfaces
  - `src/passes/optimize_test.mbt` for the reduced semantic locks
  - `src/passes/trace_golden_test.mbt` for deterministic trace output
  - `src/passes/perf_test.mbt` for perf timer and unchanged-pass behavior
  - `src/passes/pass_manager_wbtest.mbt` for registry-copy safety and traced debug-dump routing
  - `src/cmd/cmd.mbt` for pass-note and flag-limit plumbing
  - `src/cmd/cmd_wbtest.mbt` for CLI flag resolution plus saved generated-artifact replay lanes

That exact code map is the main practical addition in this refresh: readers can now jump directly from the strategy summary to the owning files and evidence surfaces.

## Current local implementation

The current in-tree `vacuum` implementation is intentionally much smaller than upstream Binaryen, but it now includes the first Binaryen-parity cleanup slice beyond `nop` sweeping.
The rewrite logic is currently centered on two HOT helpers in `src/passes/pass_manager.mbt`:

- `hot_pass_vacuum_remove_local_only_void_body(ctx, func)`, which can canonicalize an otherwise side-effect-free/local-only void function body to Binaryen's single `nop` body when the body contains local-only tee/write/control debris and no calls, memory/table mutation, throwing/trapping operations, or externally observable state changes
- `hot_pass_remove_region_nops(ctx, func, region_ref)`, which handles the ordinary recursive region cleanup

The recursive region helper walks a region root list and now handles these cleanup families:

1. if the current root is `HotOp::Nop`, it splices that root out of the region and deletes the detached node
2. if the current root is `drop` of a removable nontrapping pure scalar/ref/tuple expression, it removes the dropped expression while preserving potentially trapping conversions such as non-saturating float-to-int truncations
3. if the current root is an empty `block` with zero result arity, it removes the block while preserving typed/result blocks
4. if the current root is a `block` whose only payload is `unreachable`, it unwraps the block to the payload `unreachable`
5. if the current root is a void `if` with a constant `i32.const` condition and the selected arm can be spliced without branches to the removed `if` label, it replaces the `if` with the selected arm
6. if the current root is a void `if` with an empty then arm and a live else arm, it moves the else payload into a one-armed then arm and wraps the condition in `i32.eqz`
7. if the current root is a label-unused void block whose only HOT root is an `if`, it unwraps the block and splices the `if` into the parent region

The hot-pipeline writeback path also has a `vacuum`-specific empty-function canonicalization shim: if an otherwise unchanged or lowered `vacuum` body is empty, Starshine emits Binaryen's single `nop` function body rather than serializing an empty expression list. The local-only void-body cleanup intentionally feeds that canonicalization shape for functions where local writes, tees, and local-control flow have no observable effect.

Then, if the current root owns nested regions, the helper recurses into them. For small functions it also traverses nested value-expression children so RSE-exposed pure debris and empty-arm shapes inside value-producing controls are cleaned before lowering.

For large lowered functions, `src/passes/pass_manager.mbt` now runs a raw `vacuum` precleaner before HOT lift when the lowered instruction count exceeds the nested-child cleanup budget. That precleaner recursively removes lowered `nop`s and pure dropped stack expressions, including scalar/ref constants, local/global reads, `memory.size`, `table.size`, nontrapping unary/binary/compare/select expressions, sign-extension operators, nontrapping conversions, and constant-denominator integer div/rem cases that cannot trap. It also collapses void `if` scaffolds with an immediately preceding constant `i32` condition when the selected lowered arm does not branch to the removed `if` label or an outer label that would need depth rebasing. The raw precleaner now also unwraps void blocks whose lowered body is an `if` wrapper; it refuses exact wrapper-label targets, rebases branches that target outer labels after the removed block, and leaves unreachable-containing wrappers alone so terminal-unreachable cleanup does not accidentally erase suffix calls that other pass tests intentionally preserve. The same raw cleanup now runs for guarded call/local-set stack hazards before the HOT lift, so Starshine can still remove Binaryen-style pure debris without re-enabling the HOT lowering reassociation family that `[JSON-AS]002` exposed. Small functions also take the raw preclean path when they contain dense `nop` debris or branchy structured-write `nop` debris, avoiding pathological HOT-region per-`nop` mutation on current generated `-O4z` slot predecessors. Small terminal-`unreachable` functions take the raw path when a hard `unreachable` has immediately preceding scalar/nop/empty-try_table/typed-block-unreachable debris that HOT lowering would otherwise preserve; the cleanup deliberately leaves SIMD expression chains before `unreachable` alone until there is a source-backed Binaryen parity case for that wider surface. This keeps candidate-free functions on the existing `no-vacuum-candidates` raw skip path while letting large RSE-produced pure debris, generated branch scaffolds, guarded call/local-set hazard functions, wasm-smith terminal-unreachable debris, ordered-prefix `nop` debris, ordered if-wrapper debris, and the narrow singleton-parent call-prefix/`if` wrapper shrink without paying for broad HOT child traversal. A 2026-06-30 source-backed probe confirmed Binaryen sometimes flattens a structural wrapper around a call/local-set prefix and trailing `if`, but a broad raw implementation was rejected because it made current slot23 mismatch earlier (`defined=15 abs=42`) and size-losing. A later parent-context attempt also failed: one version advanced past `defined=840 abs=867` but over-unwrapped the same family in `defined=854 abs=881`, and the tightened singleton-parent version again regressed to `defined=15 abs=42`. The landed rule is narrower than those reverted attempts: it only splices a void lowered wrapper that is the sole instruction in its parent, begins with a void prefix block, ends in an `if`, contains no `unreachable`, and has no exact wrapper-label target; residual structural-wrapper cleanup still needs a stronger control-shape model than broad top-level or immediate-parent flattening.

The HOT recursion surface is explicit and limited:

- `Block` and `Loop` body regions
- `If` then and optional else regions
- `Try` body and optional catch regions
- `TryTable` body and catch-list regions

The dispatch arm then reports:

- `HotPassResult::changed()` if any explicit `nop` entry was removed
- `HotPassResult::unchanged()` otherwise

Perf tracing now also makes the slot-level cost boundary explicit: the hot pipeline emits an aggregate `pipeline` timer, `vacuum` raw preclean/no-candidate probes emit `raw:vacuum-*` timers, and `vacuum` writeback validation emits either `guard:vacuum-writeback-batch` or per-function `guard:vacuum-writeback:*` fallback timers. The current default collects changed candidate bodies, validates them under one module environment with `validate_defined_funcs_against_module`, and repairs invalid functions by restoring their originals in one batch; the older per-function guard remains as a fallback if changed-function validation cannot classify the repair locally. Repeated `vacuum` raw-skip trace lines for `no-vacuum-candidates` and `raw-vacuum-preclean` are batched into reason/count summaries so traced artifact replays do not print thousands of identical skip records. The raw preclean/no-candidate perf probes also batch per-function elapsed time into one `raw:vacuum-preclean` timing event and one `raw:vacuum-no-candidates` timing event per pass, so traced artifact replays keep raw attribution without formatting or emitting thousands of per-function raw timer lines. HOT mutation tracing for `vacuum` is similarly batched in two layers: helpers still invalidate analyses on each mutation, direct hot-pass application first suppresses per-region revision lines to a function-local count and then emits one pass-level `pass[vacuum]:mutated funcs=<n>` line instead of one mutation summary per changed function. The ordinary HOT lifecycle trace is now also batched for `vacuum`: traced runs emit one `pass[vacuum]:funcs count=<n> changed=<m>` summary instead of per-function `pass[vacuum]:func`, `pass[vacuum]:start`, and `pass[vacuum]:done` lines. The remaining HOT per-function perf events are batched too: direct `vacuum` runs emit one aggregate `lift`, one aggregate `pass:vacuum`, and one aggregate `lower` timer line per pass instead of one line per HOT function, while preserving the same timer names for existing compare parsers. Under the default final-module-only policy, HOT-function verification checkpoints now skip timer/checkpoint emission entirely instead of reporting `verify:before:<pass>` / `verify:after:<pass>` no-op timing lines for every changed function; after the 2026-06-30 `mutation-func-batch` replay, the slot23 `vacuum` trace contains zero `verify:before:vacuum` / `verify:after:vacuum` timer lines, zero per-function `pass[vacuum]:mutated count=` lines, and one `pass[vacuum]:mutated funcs=713` summary. These timers, repairs, and trace summaries protect writeback validity and attribution; they do not add a hidden cleanup phase.

There is still no hidden second-phase cleanup engine for this pass in-tree today.

## What Starshine already does well

The current local strategy is small, but it is not useless.
It already gives the repo a few concrete wins:

- cheap cleanup of explicit HOT `nop` residue after other hot passes
- Binaryen-aligned removal of dropped nontrapping pure scalar expressions
- removal of empty void block residue without deleting typed/result-producing blocks
- a straightforward fit with the `HotFunc` / region-reference ownership model
- honest invalidation of broad HOT analyses after mutation
- stable tracing and perf observability in the main hot pipeline
- a practical replay boundary for validation/writeback issues found during generated-artifact audits
- Binaryen-style cleanup of constant-condition void `if` scaffolds and the empty-then/live-else `if` family without waiting for `remove-unused-brs`

So the right teaching stance is not “this pass is fake.”
It is:

- the current Starshine pass is real and useful
- but its semantic scope is much narrower than Binaryen's `vacuum`

## Current proof surface in this repository

The local tests are small but meaningful.

### Reduced semantic locks

`src/passes/optimize_test.mbt` currently gives the cleanest direct pass-local proof points:

- `vacuum removes dropped pure scalar expressions`
  - proves the effect-aware dropped-result slice removes pure arithmetic while preserving local writes
- `vacuum removes pure drops in root local set call hazards`, `vacuum removes raw nontrapping int division and sign extends in call hazards`, and `vacuum raw-cleans root stack/local-set call hazards`
  - prove the raw guarded cleanup can remove Binaryen-style pure dropped stack expressions around call/local-set hazards while preserving calls, local writes, and the prior HOT-lowering safety boundary
- `vacuum preserves allocation barrier visit roots while cleaning debris`
  - covers the `[JSON-AS]002` runtime-corruption boundary with an allocation-shaped fixture: pure `const; drop` and `i32.add; drop` debris is removed while allocator calls, a field store, a write-barrier call, and a GC-visit call remain present and validating
- `vacuum removes empty void blocks`
  - proves empty zero-result block residue is deleted and the resulting module still validates
- `vacuum flips empty then with live else`
  - proves the Binaryen-style empty-then/live-else void `if` inversion and validates the lowered double-`eqz` form
- `vacuum collapses constant void if to taken arm`, `vacuum collapses constant void if with nested block-local branch`, `vacuum collapses generated branch scaffold constant if`, and `vacuum collapses large generated branch scaffold constant if`
  - prove the 2026-06-29 constant-condition void-`if` parity fix for both ordinary HOT cleanup and generated large-function scaffold shapes
- `vacuum unwraps block that only contains unreachable`
  - proves the block-only-`unreachable` cleanup shape Binaryen emits on the generated scalar corpus
- `vacuum matches Binaryen empty function nop canonicalization`
  - proves direct `vacuum` keeps Binaryen's single-`nop` canonical form for otherwise empty function bodies
- `vacuum removes nested value-expression debris in large functions`
  - proves the raw large-function precleaner removes nested lowered pure `const`/`drop` and `nop` debris even when the HOT nested-child cleanup budget would otherwise skip that function
- `vacuum cleans simplify-locals structured return residue in the late cleanup pair`
  - proves that explicit `nop` cleanup helps a real late local-cleanup pipeline shape
- `vacuum removes pure scalar stack debris before root unreachable`, `vacuum removes pure scalar typed block debris before root unreachable`, and `vacuum removes empty try_table debris before root unreachable`
  - prove the raw terminal-`unreachable` precleaner removes the wasm-smith debris families where Binaryen drops scalar/nop prefixes, typed blocks that only become `unreachable`, and empty nonthrowing `try_table` wrappers before a hard `unreachable`
- `vacuum roundtrips dead simd prefixes before unreachable`
  - proves the terminal-`unreachable` cleanup does not widen to SIMD expression prefixes without source-backed evidence
- `vacuum roundtrips top-level try_table catches that target the implicit function label`
  - proves the recursive region walk keeps an important top-level EH/control shape valid

### Trace and perf locks

`src/passes/trace_golden_test.mbt` locks the deterministic traced mutation shape for a tiny `nop`-removal example.

`src/passes/perf_test.mbt` locks that:

- traced/perf pipelines record `pass:vacuum`
- unchanged `vacuum` runs skip lower/writeback work when possible
- the pass composes correctly with verify-policy timing checkpoints

### Pipeline and registry locks

`src/passes/pass_manager_wbtest.mbt` proves that:

- the pass registry lookup for `vacuum` returns a detached descriptor copy
- repeated `vacuum` no-candidate raw-skip trace lines are batched into one counted summary
- the traced debug-dump target logic includes the saved artifact hotspot function only for `vacuum`

`src/cmd/cmd.mbt` and `src/cmd/cmd_wbtest.mbt` prove that:

- `--vacuum` is a real CLI-visible pass flag
- resolved-pass summaries report it correctly
- replaying saved generated-artifact inputs through the CLI still stays wasm-tools-valid

### Saved artifact replay lanes

The most specific local replay evidence in `src/cmd/cmd_wbtest.mbt` is important because it documents the old failure visibility honestly.
The saved generated `-O4z` slot-23 predecessor and extracted function replay lanes now validate under `--vacuum`.
That is the concrete proof surface behind the older artifact notes that retired the slot-23 and slot-33 failures.

## Current local-vs-upstream split

The safest one-line contrast is:

- **Binaryen `vacuum`:** effect-aware unused-result pruning plus structural cleanup, TNH handling, and mandatory refinalization
- **Starshine `vacuum`:** recursive explicit-`nop` trimming, empty zero-result block removal, dropped nontrapping pure-result pruning, block-only `unreachable` unwrapping, constant-condition void-`if` collapse, empty-then/live-else `if` inversion, Binaryen-style empty-function single-`nop` canonicalization, and pipeline-level validation/writeback hygiene around those rewrites

Direct oracle evidence for the current slice:

- `.tmp/pass-fuzz-vacuum-genvalid-100000-after-case003694-classification`: after classifying the remaining wasm-smith output-shape residual, the required regular GenValid closeout lane compared `100000/100000` cases with `100000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, and Binaryen cache `10332` hits / `89668` misses.
- `.tmp/pass-fuzz-vacuum-audit-after-const-if-10000-current`: after the 2026-06-29 constant-condition void-`if` fix, direct GenValid `vacuum` replay compared `10000/10000` cases with `10000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, and Binaryen cache `1002` hits / `8998` misses. The command used `_build/native/release/build/cmd/cmd.exe` because the stale `target/native/...` copy did not refresh in this worktree.
- `.tmp/pass-fuzz-vacuum-genvalid-vacuum-10000-after-local-only-safe-binary`: after adding the dedicated `vacuum` GenValid profile and the local-only void-body cleanup slice, the dedicated profile lane compared `10000/10000` cases with `10000` normalized matches, `0` cleanup-normalized matches, `0` mismatches/failures, Binaryen cache `10000` hits / `0` misses, and manifest selected-profile count `vacuum=10000`.
- `.tmp/pass-fuzz-vacuum-random-all-profiles-10000-after-terminal-debris`: after adding raw terminal-`unreachable` debris cleanup, broad random all-profiles GenValid compared `10000/10000` cases with `10000` normalized matches, `0` cleanup-normalized matches, and `0` mismatches/failures. Selected subprofiles were `binaryen-oracle-portable=1958`, `ssa-nomerge-smoke=1973`, `coverage-forced-portable=2037`, `ssa-nomerge-parity=1970`, and `pass-fuzz-stress=2062`.
- `.tmp/pass-fuzz-vacuum-wasm-smith-10000-case003694-classified`: refreshed explicit wasm-smith compared `9956/10000` cases with `9955` normalized matches, `1` classified mismatch, and `44` Binaryen/tool parser/canonicalization failures (`binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`). The three terminal-unreachable scratch mismatches `case-009332`, `case-009390`, and `case-009956` now normalize. The remaining `case-003694` is classified as a non-pass Binaryen parser/IR materialization artifact plus a narrow Starshine size win: Binaryen's no-pass load of the input already introduces the scratch `f64` local needed to represent a loop-carried stack value before a trailing `nop`, and `--vacuum` only removes that `nop`; Starshine removes the `nop` without adding the local. The original case has smaller Starshine normalized/canonical wasm (`67` vs `73` bytes) but raw Starshine is larger due unrelated type/elem encoding (`76` vs `73`); the reduced `.tmp/vacuum-case003694-reduced.wat` removes that noise and shows Starshine `40` bytes vs Binaryen `46` bytes after direct `--vacuum`.
- `.tmp/vacuum-current-o4z-neighborhood`: current-head reconstruction of the old generated `-O4z` `VQ` neighborhoods rebuilt `_build/wasm/debug/build/cmd/cmd.wasm`, regenerated Binaryen predecessors for top-level slots `23`, `33`, `37`, and `47`, and directly replayed Starshine `--vacuum`. All four Starshine outputs now exit `0` and validate, so the old `0097`/`0098` validation blockers remain retired without the missing `.artifacts` inputs. The first slot23 ordered-neighborhood parity slice exposed `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-after`, which differed at `defined=840 abs=867` with Starshine retaining an extra block wrapper around a large nested branch cascade; traced slot23 pass-local time was faster than Binaryen (`19.685ms` vs `143.193ms`), but whole-command Starshine remained slower (`5154.218ms` vs `550.468ms`) with most time untraced. The follow-up `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-ifwrapper-final` added if-wrapper cleanup and moved the first diff later in the same function (`1689` to `5688` in the extracted normalized WAT), improved raw Starshine size to `3104585` bytes vs Binaryen `3113007`, and kept pass-local Starshine faster (`20.485ms` vs `155.442ms`). A later structural-wrapper raw experiment, captured in `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-structwrapper-parent2`, was reverted because it made the first difference earlier (`defined=15 abs=42`) and raw size-losing (`3116607` vs `3113007`). A second parent-context attempt was also reverted: `...-callprefix-narrow3` advanced the first diff to `defined=854 abs=881` but over-unwrapped a Binaryen-preserved call-prefix wrapper there, while `...-callprefix-narrow4` returned to the `defined=15 abs=42` regression. The remaining local-set/call block-wrapper disparity is still an open parity gap, not a Starshine-win classification. The timing-only attribution replay `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-attribution-final` identifies the whole-command hotspot as the `guard:vacuum-writeback` validation boundary (`5297.058ms` of the `6629.091ms` traced pipeline), while raw `vacuum` cleanup itself is `89.292ms` and direct pass-local work remains faster than Binaryen (`26.364ms` vs `160.004ms`).
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-batch-repair-final`: after replacing the default per-function `vacuum` writeback guard with batch validation plus function-local repair, the current slot23 timing-only replay dropped Starshine whole-command time from the attribution baseline `7162.576ms` to `2207.677ms` while preserving the same seven invalid-lower skips (`Func 883`, `1810`, `1829`, `1830`, `2711`, `3692`, and `5366`). `guard:vacuum-writeback-batch` was `992.963ms` instead of the old grouped per-function guard `5297.058ms`; raw `vacuum` was `94.525ms`, Starshine/Binaryen pass-local was `27.643ms/218.179ms`, and whole-command Starshine/Binaryen was `2207.677ms/814.248ms`. The residual ordered-neighborhood local-set/call wrapper gap remains open, and direct smoke `.tmp/pass-fuzz-vacuum-1000-after-batch-writeback-repair` compared `1000/1000` with `1000` normalized and `0` mismatches/failures.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-func-batch-final`: after changing batch repair to validate only changed candidate bodies under one reused module environment, the slot23 timing-only replay dropped Starshine whole-command time further to `916.276ms` vs Binaryen `580.744ms`, while preserving the same seven invalid-lower skips. `guard:vacuum-writeback-batch` is now `113.338ms`, aggregate `pipeline` is `460.791ms`, raw `vacuum` is `69.378ms`, Starshine/Binaryen pass-local is `23.454ms/153.775ms`, and self-compare canonicalized Starshine/Binaryen size remains `3119563/3113007` and the emitted Starshine raw file is `3104585` bytes. The ordered-neighborhood local-set/call wrapper gap remains open; direct smoke `.tmp/pass-fuzz-vacuum-1000-after-func-batch-writeback` compared `1000/1000` with `1000` normalized and `0` mismatches/failures.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-skip-trace-batch`: after batching repeated traced `vacuum` raw-skip reasons, the slot23 timing-only replay reported Starshine/Binaryen whole-command `875.122ms/541.529ms`, Starshine/Binaryen pass-local `19.325ms/142.650ms`, raw `vacuum` `68.550ms`, aggregate `pipeline` `421.195ms`, and `guard:vacuum-writeback-batch` `112.145ms`. The trace records one `reason=no-vacuum-candidates count=484` line and one `reason=raw-vacuum-preclean count=6211` line instead of thousands of repeated skip lines. This reduces traced replay overhead without changing direct `vacuum` output; canonical wasm still differs and the ordered-neighborhood local-set/call wrapper gap remains open.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-raw-timer-aggregate`: after replacing per-function raw timer names with aggregate `raw:vacuum-preclean` and `raw:vacuum-no-candidates` names, the slot23 timing-only replay reported Starshine/Binaryen whole-command `703.228ms/545.988ms`, Starshine/Binaryen pass-local `18.912ms/144.886ms`, raw `vacuum` `63.015ms`, other traced `523.518ms`, and untraced/runtime overhead `97.783ms`. Red-first `src/passes/perf_test.mbt` coverage rejects `raw:vacuum-*:func` names. This is a timing/trace overhead reduction only; canonical wasm still differs and the ordered-neighborhood local-set/call wrapper gap remains open.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-raw-timer-event-batch-final`: after batching raw `vacuum` timer events themselves, the slot23 timing-only replay reported Starshine/Binaryen whole-command `663.776ms/533.042ms`, Starshine/Binaryen pass-local `21.824ms/138.529ms`, raw `vacuum` `58.386ms`, other traced `511.979ms`, and untraced/runtime overhead `71.587ms`. Red-first `src/passes/perf_test.mbt` coverage now requires exactly one raw-preclean and one no-candidate timer line for a three-function no-candidate module. Trace line count dropped to `11770`; skip counts remain `484` no-candidates and `6211` raw-preclean. This is another timing/trace overhead reduction only; canonical wasm still differs and the ordered-neighborhood local-set/call wrapper gap remains open.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-mutation-trace-batch-final`: after batching per-mutation `vacuum` trace lines, the slot23 timing-only replay reported Starshine/Binaryen whole-command `629.524ms/535.756ms`, Starshine/Binaryen pass-local `1.896ms/141.506ms`, raw `vacuum` `56.843ms`, other traced `500.277ms`, and untraced/runtime overhead `70.508ms`. Red-first `src/passes/trace_golden_test.mbt` coverage now expects one aggregate mutation line per changed function. Trace line count dropped to `6468`; per-mutation revision lines dropped to `0`, aggregate mutation-count lines are `713`, raw timer events remain batched, and skip counts remain `484` no-candidates plus `6211` raw-preclean. This is another timing/trace overhead reduction only; canonical wasm still differs and the ordered-neighborhood local-set/call wrapper gap remains open. Direct smoke `.tmp/pass-fuzz-vacuum-1000-after-mutation-trace-batch-final` compared `1000/1000`, normalized `1000`, with `0` mismatches/failures.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-lifecycle-trace-batch-final`: after batching `vacuum` HOT lifecycle traces, the slot23 timing-only replay reported Starshine/Binaryen whole-command `632.986ms/541.272ms`, Starshine/Binaryen pass-local `1.918ms/144.994ms`, raw `vacuum` `58.214ms`, other traced `509.076ms`, and untraced/runtime overhead `63.778ms`; a repeat reported `634.384ms/537.173ms`. Red-first trace coverage expects no per-function `func`/`start`/`done` lines for `vacuum` and one aggregate `pass[vacuum]:funcs count=<n> changed=<m>` line. Trace line count dropped to `4325`; aggregate mutation-count lines remain `713`. This reduces trace volume but did not measurably close the remaining whole-command gap in the sampled runs; canonical wasm still differs and the ordered-neighborhood local-set/call wrapper gap remains open. Direct smoke `.tmp/pass-fuzz-vacuum-1000-after-lifecycle-trace-batch-final` compared `1000/1000`, normalized `1000`, with `0` mismatches/failures.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-hot-timer-batch-final`: after batching the remaining HOT per-function `lift`, `pass:vacuum`, and `lower` timing events, the slot23 timing-only replay reported Starshine/Binaryen whole-command `634.275ms/548.956ms`, Starshine/Binaryen pass-local `1.971ms/142.775ms`, raw `vacuum` `56.874ms`, other traced `515.660ms`, and untraced/runtime overhead `59.770ms`; a repeat reported `616.325ms/550.907ms`, pass-local `1.891ms/141.626ms`, raw `57.553ms`, other traced `499.652ms`, and untraced/runtime `57.229ms`. Red-first perf coverage expects exactly one timing line for each of `lift`, `pass:vacuum`, and `lower` across a three-function changed `vacuum` module. Trace line count dropped to `2184`; raw timer events and aggregate mutation-count lines remain batched. This reduces trace volume but did not measurably close the sampled whole-command gap; canonical wasm still differs and the ordered-neighborhood local-set/call wrapper gap remains open. Direct smoke `.tmp/pass-fuzz-vacuum-1000-after-hot-timer-batch-final2` compared `1000/1000`, normalized `1000`, with `0` mismatches/failures.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-verify-noop-skip-final`: after skipping no-op HOT-function verification timers under final-module-only policy, the slot23 timing-only replay reported Starshine/Binaryen whole-command `629.843ms/584.316ms`, Starshine/Binaryen pass-local `2.054ms/152.369ms`, raw `vacuum` `58.286ms`, other traced `513.336ms`, and untraced/runtime overhead `56.167ms`; a repeat reported `618.719ms/583.147ms`, pass-local `1.955ms/159.285ms`, raw `56.655ms`, other traced `504.912ms`, and untraced/runtime `55.197ms`. Red-first perf coverage now rejects `verify:before:vacuum` and `verify:after:vacuum` timers when final-module-only validation is active. Trace line count dropped to `754`, with zero per-function verify timer lines and the same `713` aggregate mutation-count lines. This reduces trace volume but did not materially close the sampled whole-command gap; canonical wasm still differs and the ordered-neighborhood local-set/call wrapper gap remains open. Direct smoke `.tmp/pass-fuzz-vacuum-1000-after-verify-noop-skip` compared `1000/1000`, normalized `1000`, with `0` mismatches/failures.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-mutation-func-batch-final`: after batching the remaining per-function `vacuum` mutation-count summaries into one pass-level line, the slot23 timing-only replay reported Starshine/Binaryen whole-command `623.617ms/540.657ms`, Starshine/Binaryen pass-local `1.916ms/145.407ms`, raw `vacuum` `58.927ms`, other traced `510.535ms`, and untraced/runtime overhead `52.239ms`; a repeat reported `634.730ms/565.452ms`, pass-local `1.887ms/147.442ms`, raw `60.010ms`, other traced `517.266ms`, and untraced/runtime `55.567ms`. Red-first trace coverage rejects per-function `pass[vacuum]:mutated count=` lines and expects one `pass[vacuum]:mutated funcs=<n>` summary. Trace line count dropped to `42`, with zero per-function mutation-count lines and one `pass[vacuum]:mutated funcs=713` line. This reduces trace volume but did not materially close the sampled whole-command gap; canonical wasm still differs and the ordered-neighborhood local-set/call wrapper gap remains open. Direct smoke `.tmp/pass-fuzz-vacuum-1000-after-mutation-func-batch` compared `1000/1000`, normalized `1000`, with `0` mismatches/failures. Size reporting for this lane should distinguish the canonicalized `starshine.wasm` compare artifact (`3119563` bytes) from the emitted raw Starshine output (`3104585` bytes); `self-optimize-compare` now records both raw and canonical size fields.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-size-fields-final`: after adding raw/canonicalized size fields to `self-optimize-compare`, the timing-only slot23 replay reported Starshine/Binaryen whole-command `609.636ms/555.346ms`, Starshine/Binaryen pass-local `1.850ms/169.594ms`, raw `vacuum` `57.849ms`, other traced `498.933ms`, and untraced/runtime `51.004ms`; emitted raw sizes are Starshine/Binaryen `3104585/3113007`, while canonicalized compare artifacts are `3119563/3113007`. This is reporting/attribution only; the slot23 local-set/call wrapper parity gap remains open.
- `.tmp/vacuum-current-o4z-neighborhood/slot23-pre22-vacuum-compare-callprefix-singleton-final`: after adding the narrow singleton-parent call-prefix/`if` raw cleanup, the full slot23 replay reported Starshine/Binaryen whole-command `630.252ms/543.370ms`, pass-local `1.963ms/143.280ms`, raw `vacuum` `59.163ms`, other traced `517.147ms`, and untraced/runtime `51.979ms`; emitted raw sizes are `3104054/3113007`, while canonicalized compare artifacts are `3119032/3113007`. The focused red-first fixture failed before the raw rule because Starshine kept the extra singleton wrapper and unre-based outer branch depth. Direct smoke `.tmp/pass-fuzz-vacuum-1000-after-callprefix-singleton` compared `1000/1000`, normalized `1000`, with `0` mismatches/failures. The ordered slot remains open: canonical wasm still differs and the full compare reports first differing function `defined=15 abs=42`, so this is a reduction step, not a classified Starshine win.
- `.tmp/pass-fuzz-vacuum-profile-smoke-100-ref`: after adding the dedicated `vacuum` GenValid profile, the profile smoke compared `100/100` cases with `100` normalized matches, `0` cleanup-normalized matches, `0` mismatches/failures, Binaryen cache `100` hits / `0` misses, and manifest selected-profile count `vacuum=100`. A traced sample recorded Starshine `pass:vacuum` total `924us` across the small and larger profile functions.
- `.tmp/pass-fuzz-vacuum-large-nested-preclean`: after the 2026-05-11 large-function raw precleaner, mixed-generator direct `vacuum` replay reached `6759/10000` comparable cases with `6759` normalized matches, `0` mismatches, `0` validation failures, and `20` Binaryen/tool command failures
- `.tmp/pass-fuzz-vacuum-empty-then-final`: after the 2026-05-10 empty-then/live-else inversion, mixed-generator replay reached `6759/10000` comparable cases with `6759` normalized matches, `0` mismatches, `0` validation failures, and `20` Binaryen empty-recursion-group parser/canonicalization command failures
- `.tmp/pass-fuzz-vacuum-gen-valid`: `10000/10000` direct `gen-valid` normalized matches, `0` mismatches, `0` validation failures, `0` command failures after the empty-void-block cleanup landed
- `.tmp/vacuum-perf-case003694-classified`: five broad random all-profiles inputs all had equal raw wasm or normalized WAT after direct `--vacuum`. Pass-local Starshine/Binaryen timing pairs were `5.539/0.124`, `0.037/0.037`, `0/0.185`, `5.517/0.134`, and `6.943/0.129` ms; median Starshine pass-local time was `5.517ms` vs Binaryen `0.129ms`. This meets the repo `<1s` pass-local target but not the `>=50%` Binaryen-speed target.
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --redundant-set-elimination --vacuum --out-dir .tmp/vacuum-large-nested-rse-debris`: the combined replay still has the inherited first differing function at `defined=208 abs=225`, but the real large-function size gap is mostly closed. Starshine normalized wasm is `3,145,318` bytes vs Binaryen `3,139,705`; `defined=518` shrinks to `497,292` body bytes vs Binaryen `495,884`, and Starshine pass-local time is `174.413ms` vs Binaryen `35,265.000ms`.

Current Starshine does **not** yet model upstream behaviors such as:

- generalized effect-aware dropped-wrapper elimination beyond the current nontrapping pure scalar/ref/tuple subset, local-only void-body pruning, lowered large-function pure leaf precleaner, and narrow terminal-`unreachable` scalar/empty-wrapper cleanup
- multi-child effect preservation through dropped-child rebuilding
- non-void and label-carried constant `if` collapse plus unreachable-condition `if` collapse
- branch-hint metadata updates when an `if` is inverted
- `drop(local.tee(...)) -> local.set(...)`
- block-result popping with label-safety checks
- non-throwing `try` / `try_table` collapse
- TNH trap-path cleanup
- whole-function `nop` cleanup based on side effects
- explicit-`unreachable` preservation logic as a first-class rewrite rule
- Binaryen-style post-edit refinalization

That boundary should stay explicit in every future edit.

## Why the local implementation lives in `pass_manager.mbt`

Unlike several other hot passes in this repo, `vacuum` does not currently have its own dedicated `src/passes/vacuum.mbt` file.
The small current scope made it reasonable to keep the implementation close to the hot-pass runner itself:

- the rewrite is tiny
- it depends directly on core region-splice and detached-node cleanup helpers
- the pass-specific writeback-validation guard also lives in the pipeline manager

If the pass grows toward Binaryen parity, it will probably become worth moving into its own dedicated file.
Right now the code map is still small enough that keeping the exact `pass_manager.mbt` ownership visible is more helpful than pretending there is a larger local subsystem.

## Boundary lesson from the retired artifact failures

The saved generated-artifact notes remain important context.
They showed that `vacuum` was sometimes the place where invalid output became visible, but not necessarily the place where the real semantic bug originated.

The retired slot-23 and slot-33 notes now support a stable lesson:

- some earlier failures surfaced during `vacuum` replay
- the durable fixes lived in writeback / carrier / validation hygiene around the hot pipeline
- future parity work should port real Binaryen `vacuum` semantics instead of turning local `vacuum` into an ad hoc repair bucket

That is why this page treats the writeback guard and CLI replay lanes as part of the strategy story.
For the current implementation, they are part of the honest contract.

## Honest future port shape

If Starshine wants closer Binaryen parity, the likely path is still staged:

1. keep the current recursive `nop`, empty-void-block, dropped-pure-result, block-only-`unreachable`, constant-condition void-`if`, empty-then/live-else `if` inversion, and large lowered-function pure leaf precleaning slice green
2. move the pass into a dedicated owner file once the helper surface grows further
3. broaden effect-aware dropped-wrapper elimination
4. add the remaining easy structural cases
   - non-void / label-carried constant `if` and unreachable-condition `if`
   - drop-of-tee to set
   - trivial block and loop cleanup beyond block-only `unreachable`
5. add branch-result-aware and EH-aware cleanup only with explicit legality proofs
6. add whatever HOT writeback or refinalization-equivalent discipline is needed for broader GC and EH-sensitive rewrites

The important rule is that future work should grow from the current exact code map, not from a fuzzy idea that `vacuum` already means Binaryen parity.

## Bottom line

Current Starshine `vacuum` is a tiny but useful hot pass.
Its exact local implementation is now easy to follow:

- registration in `src/passes/optimize.mbt`
- recursion, dispatch, and writeback guards in `src/passes/pass_manager.mbt`
- semantic, trace, perf, registry, and CLI evidence in the focused test files

That makes the local subset easy to teach honestly:

- **what it does today:** remove explicit HOT `nop` region entries, remove empty zero-result blocks, remove dropped nontrapping pure scalar/ref/tuple results, canonicalize side-effect-free/local-only void function bodies with tee/write/control debris to one `nop`, unwrap block-only `unreachable`, collapse constant-condition void `if`s when branch-label safety is local, flip empty-then/live-else void `if`s, preclean large lowered functions with pure leaf `const`/`drop`, constant void-`if`, plus `nop` debris, and keep the pipeline safe
- **what it does not do yet:** the broader Binaryen `vacuum` rewrite family
