---
kind: comparison
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md
  - ../../../raw/research/0529-2026-05-06-global-struct-inference-direct-revalidation.md
  - ../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0068-2026-03-25-global-struct-inference.md
  - ../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md
  - ../../../raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md
related:
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
---

# `global-struct-inference` Binaryen parity

## Durable conclusions

- Binaryen's `global-struct-inference` is broader than the older local wiki summary implied.
  - it is **not** just a closed-world pass
  - it still has an open-world direct immutable-global optimization layer
- The full official contract is much broader than the current local MoonBit implementation.
  - Binaryen handles open-world direct-global reads, closed-world candidate-global reasoning over locals and params, subtype propagation, one-vs-two-unique-value selection, non-constant un-nesting, packed fields, atomic gets, `ref.get_desc`, and the sibling `gsi-desc-cast` surface
- The current local Starshine implementation is still a deliberately small subset, but the 2026-06-03 O4z audit removed the old closed-world-only restriction for the direct-global layer:
  - direct `global.get -> struct.get*` pairs now fold in open world, matching Binaryen's direct immutable-global fast path
  - top-level immutable `struct.new*`, `struct.new_default*`, `struct.new_desc`, and `struct.new_default_desc` globals are covered
  - packed i8/i16 signed and unsigned reads are repaired for direct literal payloads
  - a closed-world fact table now records immutable top-level candidate globals, mutable/too-broad global exclusions, function-local allocation poisoning, nested global-initializer allocation poisoning, poisoned-child-to-parent propagation, and child-candidate-to-parent propagation
  - exact single-candidate local/param origins now rewrite in closed world when the exact type has one safe direct candidate and no propagated subtype ambiguity
  - no multi-candidate value grouping/selects, no supertype/subtype-propagated rewrites, no un-nesting, no atomic/`ref.get_desc`/descriptor-cast surface
- The saved generated-artifact `-O4z` slot is still exactly green, which strongly suggests the artifact does not exercise the missing official surfaces.

## Current in-tree status

- The implementation lives in [`../../../../../src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt).
- The dedicated source/test/code-map page lives at [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
- The dedicated local status page now lives at [`./starshine-strategy.md`](./starshine-strategy.md), with the implementation-detail page at [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).
- The focused public-pipeline suite lives in [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt); the closed-world analysis fact coverage lives in [`../../../../../src/passes/global_struct_inference_wbtest.mbt`](../../../../../src/passes/global_struct_inference_wbtest.mbt).
- Registry and preset coverage live in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), with module-pass dispatch in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
- The pass is active in-tree and is scheduled in the early module cluster after `global-refining`.

## 2026-06-03 exact single-candidate local/param follow-up

The exact single-candidate local/param follow-up added the first rewrite consumer for closed-world facts. It rewrites only adjacent `local.get` / `struct.get*` pairs whose local type exactly matches the read struct type and whose exact type has one safe direct candidate global after poison checks; propagated subtype candidate ambiguity blocks the rewrite in this slice.

The final direct compare ran:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-global-struct-inference-gsi001b-final-10000`

Result:

- compared cases: 9975 / 10000
- normalized matches: 9975
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 25

Command-failure classes from `summary.json`:

- `22` `binaryen-rec-group-zero`
- `1` `binaryen-bad-section-size`
- `1` `binaryen-table-index-out-of-range`
- `1` `binaryen-invalid-tag-index`

The debug artifact timing replay used:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-gsi001b-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `364.701 ms`
- Binaryen runtime: `488.318 ms`
- Starshine pass runtime: `0.371 ms`
- Binaryen pass runtime: `5.017 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for the exact single-candidate local/param slice only. It is not evidence that multi-candidate value grouping, supertype-origin rewrites, selects, or un-nesting are implemented.

## 2026-06-03 subtype-propagated closed-world facts follow-up

The subtype-propagated closed-world facts follow-up added analysis-only child-to-parent poison and candidate propagation, kept the fact table analysis-only, and ran:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-global-struct-inference-subtype-facts-final-10000`

Result:

- compared cases: 9975 / 10000
- normalized matches: 9975
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 25

Command-failure classes from `summary.json`:

- `22` `binaryen-rec-group-zero`
- `1` `binaryen-bad-section-size`
- `1` `binaryen-table-index-out-of-range`
- `1` `binaryen-invalid-tag-index`

The debug artifact timing replay used:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-subtype-facts-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `321.381 ms`
- Binaryen runtime: `445.806 ms`
- Starshine pass runtime: `0.345 ms`
- Binaryen pass runtime: `2.970 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for preserving the already-active direct pass behavior while adding subtype propagation to the closed-world fact builder. It predates the exact single-candidate local/param consumer and is not evidence that multi-candidate, select, or un-nesting rewrites are implemented.

## 2026-06-03 O4z audit direct-pass revalidation

The O4z audit upgrade ran:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-global-struct-inference-audit-open-world-10000`

Result:

- compared cases: 9975 / 10000
- normalized matches: 9975
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 25

Command-failure classes from `summary.json`:

- `22` `binaryen-rec-group-zero`
- `1` `binaryen-bad-section-size`
- `1` `binaryen-table-index-out-of-range`
- `1` `binaryen-invalid-tag-index`

The audit also measured the debug artifact with:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-audit-open-world`

Result:

- canonical wasm equal: yes
- Starshine runtime: `311.057 ms`
- Binaryen runtime: `398.201 ms`
- Starshine pass runtime: `0.349 ms`
- Binaryen pass runtime: `2.815 ms`
- Starshine pass skipped raw: no

This is evidence that the upgraded direct-global subset is semantically green on the direct fuzz lane and materially faster than Binaryen pass-local on the audited debug artifact. It is not evidence that the still-missing closed-world candidate-map/select/un-nesting families are implemented.

## 2026-05-06 direct-pass revalidation

The post-fuzzer-change direct signoff lane ran:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --out-dir .tmp/pass-fuzz-global-struct-inference`

Result:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures are the known Binaryen empty-recursion-group parser/canonicalization failure class, not Starshine-vs-Binaryen semantic mismatches. This removes `global-struct-inference` from the AUD002 stale-evidence queue while preserving the broader capability gaps below.

## Saved generated-artifact evidence

The saved generated-artifact `-O4z` audit shows slot `7` (`gsi` / `global-struct-inference`) as:

- exact wasm equal: `yes`
- normalized WAT equal: `yes`
- Starshine wall/runtime: `410.401 ms`
- Binaryen wall/runtime: `197.827 ms`
- Starshine in-pass time: `0.002 ms`
- Binaryen in-pass time: `2.008 ms`
- both outputs valid: `yes`

That is strong evidence that the current local pass behaves compatibly on the saved artifact.
It is **not** proof that the current pass covers all important Binaryen shapes.

## Earlier compare-harness evidence still worth keeping

The older `0068` note recorded:

- default-mode `--global-struct-inference` compare parity stayed green
- closed-world `--global-struct-inference` compare parity also stayed green
- ordered-prefix parity stayed green too
- the remaining wall-time gap was upstream of `gsi`

Those results still matter, but the interpretation needs refinement now that the official source has been re-audited more carefully:

- green default-mode parity does **not** mean upstream `gsi` is a no-op in open world
- it more likely means the tested artifact did not contain the open-world direct-global shapes that upstream `gsi` can optimize

That is an inference from the official source plus the green runs, not a direct quoted Binaryen statement.

## Current local coverage

The focused local tests now cover the direct-global O4z audit subset plus closed-world fact-table invariants:

- open-world direct `global.get -> struct.get*` folding on immutable globals, including exported immutable globals
- nullable direct-global trap preservation with `ref.as_non_null` and `drop`
- packed i8/i16 signed and unsigned read repair
- `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` field extraction, including nullable-ref defaults
- mutable-field, mutable-global, and imported-global negatives
- preserving ordinary non-global ref producers unchanged in open world
- exact single-candidate param and body-local origin rewrites in closed world, preserving null traps with `ref.as_non_null` plus `drop`
- local-origin negatives for multiple candidates, subtype-propagated ambiguity, poisoned exact types, mutable fields/globals, and `anyref`/too-broad global declarations
- closed-world facts for immutable top-level candidates, mutable-global exclusion, `anyref`/too-broad declaration exclusion, function-local allocation poisoning, nested global-initializer allocation poisoning, poisoned-child-to-parent propagation including no-global-section poison propagation, and child-candidate-to-parent propagation

That is a stronger local floor for the current subset.
It is still far smaller than the official Binaryen lit surface.

## Main remaining divergences from official Binaryen

## 1. Closed-world `typeGlobals` consumption is still narrow

Current local behavior after the 2026-06-03 follow-up:

- `global_struct_inference_run_module_pass` no longer returns unchanged when `closed_world` is false; it scans immutable defined globals and applies the direct-global fold in open world
- when `closed_world` is true, it builds a conservative candidate/poison fact table for top-level immutable global origins and allocation poison sources, then rewrites only exact-type local/param reads with one safe direct candidate and no propagated subtype ambiguity

Official Binaryen `version_129` behavior:

- closed world enables the broader `typeGlobals` analysis
- but `optimize(module)` still runs afterwards in **all** modes
- direct immutable-global reads can still optimize in open world

This former conceptual gap is closed for the direct immutable-global fast path, and the first exact local/param closed-world fact consumer now exists. `closed_world` still does not add Binaryen's broader multi-candidate local/param candidate-origin rewrites, supertype rewrites, value grouping, or un-nesting locally.

## 2. The local pass only matches immediate instruction pairs

Current local behavior:

- look for immediate `GlobalGet` followed by immediate `StructGet` / `StructGetS` / `StructGetU`

Official Binaryen behavior:

- optimize direct immutable-global reads
- but also, in closed world, reason about arbitrary read operands such as params, locals, and supertypes using the type-to-global map

So the local pass still misses Binaryen shapes like:

- `struct.get` of a parameter known to be one of two immutable globals
- parent-typed reads whose only trusted origins are child globals
- non-adjacent or nested reference producers

## 3. Subtype propagation exists but is not consumed by rewrites

Official Binaryen uses `SubTypes` to:

- poison supertypes when child allocations happen in functions or nested global positions
- propagate candidate child globals upward to parent reads

Current local pass now mirrors that in the fact table, including deterministic candidate ordering. The exact single-candidate local/param slice deliberately treats propagated child candidates as ambiguity and bails; no parent-typed rewrite consumes subtype-aware candidate propagation yet.

## 4. No local one-vs-two-unique-values grouping

Official Binaryen can:

- collapse many globals into one constant value
- or emit a `select(ref.eq(...))` when there are two unique values and one singleton-tested group

Current local pass does neither.
It only folds a field value from the exact global being read directly.

## 5. No local un-nesting of non-constant operands

Official Binaryen can split a nested non-constant field operand into a fresh immutable global and continue the optimization.

Current local pass:

- has no fresh-global emission path
- has no nested `reorder-globals-always` cleanup path

## 6. No local `PossibleConstantValues` equivalent

Official Binaryen treats immutable `global.get`s as constant materializable values.
That matters for official positive shapes where field values are not literals but are still stable immutable globals.

Current local pass has a smaller local materialization surface.

## 7. No local atomic-get or descriptor-facing coverage

Official Binaryen source and lit tests cover:

- packed fields
- atomic gets on immutable fields
- `ref.get_desc`
- sibling `gsi-desc-cast`

Current local pass handles only ordinary `struct.get*` forms.

## 8. Representation-specific type repair differs locally

Official Binaryen explicitly refinalizes changed functions.
Current local boundary IR pass does not mirror that exact mechanism because it works in a different representation.

That is likely fine for the current subset, but it is still a real architectural divergence from the source oracle.

## Why the saved audit can still be exactly green

The most plausible explanation is:

- the saved artifact either does not hit many direct-global shapes or those shapes now normalize the same after the 2026-06-03 upgrade
- it still does not rely on the richer closed-world candidate-global, subtype, atomic, or un-nesting surfaces
- the local subset is therefore enough for that particular slot

Again, that is an inference from the green audit plus the visible local-vs-upstream source differences.

## Practical rule for future work

- Keep the current local subset described honestly as a subset.
- Do **not** describe it as “what Binaryen `gsi` does.”
- If future parity work targets the full Binaryen contract, the next missing surfaces to implement are, in value order:
  1. add one-value multi-candidate folding for materializable equal values
  2. one-vs-two-unique-values select synthesis
  3. un-nesting of non-constant operands
  4. atomic / `ref.get_desc` / descriptor-cast coverage
- If local code remains intentionally narrower, keep the green artifact evidence explicit so readers do not confuse “narrow but enough for this artifact” with “full upstream parity.”

## Sources

- Raw primary-source manifest: [`../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md`](../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md)
- Current-main recheck: [`../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md)
- Current follow-up note: [`../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md`](../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md)
- Older follow-up note: [`../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md`](../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md)
- Direct revalidation note: [`../../../raw/research/0529-2026-05-06-global-struct-inference-direct-revalidation.md`](../../../raw/research/0529-2026-05-06-global-struct-inference-direct-revalidation.md)
- Archived earlier note: [`../../../raw/research/0068-2026-03-25-global-struct-inference.md`](../../../raw/research/0068-2026-03-25-global-struct-inference.md)
- Updated research note: [`../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md`](../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md)
- Implementation: [`../../../../../src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt)
- Focused tests: [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt)
- Dispatch/options surface: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- Registry/preset surface: [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Saved artifact audit: [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
