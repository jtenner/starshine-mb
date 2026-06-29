---
kind: concept
status: working
last_reviewed: 2026-06-29
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

The hot-pipeline writeback path also has a `vacuum`-specific empty-function canonicalization shim: if an otherwise unchanged or lowered `vacuum` body is empty, Starshine emits Binaryen's single `nop` function body rather than serializing an empty expression list. The local-only void-body cleanup intentionally feeds that canonicalization shape for functions where local writes, tees, and local-control flow have no observable effect.

Then, if the current root owns nested regions, the helper recurses into them. For small functions it also traverses nested value-expression children so RSE-exposed pure debris and empty-arm shapes inside value-producing controls are cleaned before lowering.

For large lowered functions, `src/passes/pass_manager.mbt` now runs a raw `vacuum` precleaner before HOT lift when the lowered instruction count exceeds the nested-child cleanup budget. That precleaner recursively removes lowered `nop`s and pure dropped stack expressions, including scalar/ref constants, local/global reads, `memory.size`, `table.size`, nontrapping unary/binary/compare/select expressions, sign-extension operators, nontrapping conversions, and constant-denominator integer div/rem cases that cannot trap. It also collapses void `if` scaffolds with an immediately preceding constant `i32` condition when the selected lowered arm does not branch to the removed `if` label or an outer label that would need depth rebasing. The same raw cleanup now runs for guarded call/local-set stack hazards before the HOT lift, so Starshine can still remove Binaryen-style pure debris without re-enabling the HOT lowering reassociation family that `[JSON-AS]002` exposed. Small functions also take the raw preclean path only when a terminal `unreachable` has immediately preceding scalar/nop/empty-try_table/typed-block-unreachable debris that HOT lowering would otherwise preserve; the cleanup deliberately leaves SIMD expression chains before `unreachable` alone until there is a source-backed Binaryen parity case for that wider surface. This keeps candidate-free functions on the existing `no-vacuum-candidates` raw skip path while letting large RSE-produced pure debris, generated branch scaffolds, guarded call/local-set hazard functions, and wasm-smith terminal-unreachable debris shrink without paying for broad HOT child traversal.

The HOT recursion surface is explicit and limited:

- `Block` and `Loop` body regions
- `If` then and optional else regions
- `Try` body and optional catch regions
- `TryTable` body and catch-list regions

The dispatch arm then reports:

- `HotPassResult::changed()` if any explicit `nop` entry was removed
- `HotPassResult::unchanged()` otherwise

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
