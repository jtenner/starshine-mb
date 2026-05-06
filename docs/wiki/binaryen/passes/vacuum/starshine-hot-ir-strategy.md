---
kind: concept
status: working
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-04-22-vacuum-primary-sources.md
  - ../../../raw/research/0249-2026-04-22-vacuum-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md
  - ../../../raw/research/0210-2026-04-21-vacuum-source-confirmation-followup.md
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
The real rewrite logic is one recursive HOT helper in `src/passes/pass_manager.mbt`:

- `hot_pass_remove_region_nops(ctx, func, region_ref)`

That helper walks a region root list and now does four things:

1. if the current root is `HotOp::Nop`, it splices that root out of the region and deletes the detached node
2. if the current root is `drop` of a removable nontrapping pure scalar/ref/tuple expression, it removes the dropped expression while preserving potentially trapping conversions such as non-saturating float-to-int truncations
3. if the current root is an empty `block` with zero result arity, it removes the block while preserving typed/result blocks
4. if the current root is a `block` whose only payload is `unreachable`, it unwraps the block to the payload `unreachable`

Then, if the current root owns nested regions, the helper recurses into them.

The recursion surface is explicit and limited:

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
- `vacuum removes empty void blocks`
  - proves empty zero-result block residue is deleted and the resulting module still validates
- `vacuum unwraps block that only contains unreachable`
  - proves the block-only-`unreachable` cleanup shape Binaryen emits on the generated scalar corpus
- `vacuum cleans simplify-locals structured return residue in the late cleanup pair`
  - proves that explicit `nop` cleanup helps a real late local-cleanup pipeline shape
- `vacuum roundtrips dead simd prefixes before unreachable`
  - proves the pass does not corrupt a prefix that should remain visible before `unreachable`
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
- **Starshine `vacuum`:** recursive explicit-`nop` trimming, empty zero-result block removal, dropped nontrapping pure-result pruning, block-only `unreachable` unwrapping, and pipeline-level validation/writeback hygiene around those rewrites

Direct oracle evidence for the current slice:

- `.tmp/pass-fuzz-vacuum-gen-valid`: `10000/10000` direct `gen-valid` normalized matches, `0` mismatches, `0` validation failures, `0` command failures after the empty-void-block cleanup landed
- `.tmp/pass-fuzz-vacuum`: mixed-generator replay reached `6464/10000` comparable cases with `6459` normalized matches, `5` known broader wasm-smith mismatches, and `15` Binaryen/parser command failures; those mismatches are outside the completed empty-structure audit slice and remain part of future broader `vacuum` parity work
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --vacuum`: normalized WAT and canonical function compare equal; raw/canonical wasm bytes still differ, while Starshine pass time was `99.859ms` versus Binaryen pass time `222.616ms`

Current Starshine does **not** yet model upstream behaviors such as:

- generalized effect-aware dropped-wrapper elimination beyond the current nontrapping pure scalar/ref/tuple subset
- multi-child effect preservation through dropped-child rebuilding
- constant or unreachable `if` collapse
- branch-hint flips when an `if` is inverted
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

1. keep the current recursive `nop`, empty-void-block, dropped-pure-result, and block-only-`unreachable` slice green
2. move the pass into a dedicated owner file once the helper surface grows further
3. broaden effect-aware dropped-wrapper elimination
4. add the remaining easy structural cases
   - constant / unreachable `if`
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

- **what it does today:** remove explicit HOT `nop` region entries, remove empty zero-result blocks, remove dropped nontrapping pure scalar/ref/tuple results, unwrap block-only `unreachable`, and keep the pipeline safe
- **what it does not do yet:** the broader Binaryen `vacuum` rewrite family
