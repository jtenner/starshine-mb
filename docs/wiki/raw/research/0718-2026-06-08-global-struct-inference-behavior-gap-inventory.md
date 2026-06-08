---
kind: research
status: current
last_reviewed: 2026-06-08
sources:
  - ../../../../agent-todo.md
  - ../../binaryen/passes/global-struct-inference/binaryen-strategy.md
  - ../../binaryen/passes/global-struct-inference/closed-world-analysis-and-unnesting.md
  - ../../binaryen/passes/global-struct-inference/parity.md
  - ../../binaryen/passes/global-struct-inference/starshine-hot-ir-strategy.md
  - ../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md
  - ../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../../src/passes/global_struct_inference.mbt
  - ../../../../src/passes/global_struct_inference_test.mbt
related:
  - ../../binaryen/passes/global-struct-inference/index.md
  - ../../binaryen/passes/global-struct-inference-desc-cast/index.md
  - ./0714-2026-06-07-o4z-behavior-parity-inventory.md
---

# `global-struct-inference` behavior-gap inventory

## Scope

This note picks up `[O4Z-AUDIT-GSI]` from `agent-todo.md`. The target is Binaryen behavior parity for the ordinary `global-struct-inference` / `gsi` pass, not byte-for-byte output parity. The sibling `global-struct-inference-desc-cast` pass is listed separately because Binaryen exposes it as a distinct pass surface, even though it shares much of the owner file.

## Behavior already covered locally

Starshine already has focused coverage and prior green direct-compare evidence for these ordinary-GSI families:

- open-world direct immutable-global `struct.get*` and `struct.atomic.get*` folds;
- nullable-trap preservation with `ref.as_non_null` + `drop`;
- top-level `struct.new`, `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` global initializers;
- packed signed/unsigned repair for literal and un-nested immutable-global payloads;
- closed-world exact and subtype-propagated local/param one-global origin rewrites;
- closed-world exact and subtype-propagated one-value folds;
- closed-world exact and subtype-propagated two-value singleton-group `select(ref.eq(...))` rewrites;
- selected small-module non-constant un-nesting for numeric constants, immutable `global.get`, string/ref constants, integer arithmetic/bitwise/shift/rotate, integer sign extension, unary numeric ops, float arithmetic/min/max/copysign, float sqrt, and float rounding;
- `ref.get_desc` direct, block-carried direct, and closed-world local reads;
- negative coverage for mutable fields/globals, imported globals, unsafe broad declarations, poisoned allocation types, and multi-candidate ambiguity.

## Full known behavior gap list

| Gap | Binaryen behavior | Current Starshine behavior | Evidence / test status |
| --- | --- | --- | --- |
| Artificial un-nesting size gate | Binaryen records un-nesting work during the function walk and adds fresh immutable globals after the parallel phase; the documented source contract is not limited to tiny modules. | Fixed in this slice: `gsi_extra_surfaces_allowed` no longer blocks un-nesting or descriptor-value collection by defined-global/function/body-size thresholds. | Green tests cover many-global and many-function direct-global un-nesting plus many-global and many-function closed-world local-select un-nesting in `src/passes/global_struct_inference_test.mbt`. |
| Nested aggregate field operands | Binaryen's un-nesting story covers non-constant field operands, including lit/source surfaces for nested `struct.new` values that become fresh globals before field reads are folded. | Fixed in this slice for struct constructors: Starshine's un-nestable vocabulary now accepts `struct.new`, `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` result typing/operand counts. | Green tests cover nested `struct.new` field-value un-nesting and nullable-trap preservation. |
| Broader `PossibleConstantValues` / un-nesting vocabulary | Binaryen routes field values through `PossibleConstantValues` and the general un-nesting mechanism, so immutable-global values and non-constant operands are handled through the same work-item story. | Starshine explicitly whitelists a compact instruction vocabulary and therefore misses Binaryen-positive aggregate allocation families outside that list. | Added red tests for `array.new_fixed`, `array.new_default`, and closed-world array-field select un-nesting in `src/passes/global_struct_inference_test.mbt`. |
| Arbitrary / cast-aware read carriers | Binaryen's ordinary `gsi` direct fast path is narrower than the earlier watchpoint wording implied; a local `wasm-opt --all-features --gsi` probe on `ref.cast(global.get)` did not fold. | Starshine mostly rewrites adjacent stack pairs, plus one-instruction block-carried direct globals. It does not implement a general expression-carrier walker. | No positive test added; this needs a source/lit-backed ordinary-GSI positive before it should become a red test. Sibling descriptor-cast behavior remains separate. |
| Binaryen-style refinalization | Binaryen uses `ReFinalize` after rewrites that may refine/narrow expression types; the lit/docs include a null-result refinement shape. | Starshine constructs validation-preserving replacement types for its current subset and has no general refinalization machinery. | Added `global-struct-inference refinalizes null-result local folds`; it is currently green, so no remaining red ordinary-GSI refinalization trigger is known from this focused shape. |
| `gsi-desc-cast` sibling pass | Binaryen exposes a distinct `gsi-desc-cast` pass that rewrites eligible descriptor casts using shared GSI facts and descriptor-singleton gates. | Starshine keeps `global-struct-inference-desc-cast` boundary-only/rejected. Plain GSI covers descriptor reads, not cast rewrites. | Track under the sibling dossier, not as an ordinary-GSI direct-pass test. |
| Aggregate/array atomic breadth | Binaryen's GSI proof includes immutable-field `StructAtomicGet*`; broader atomic aggregate surfaces remain easy to conflate with generic atomic effects. | Starshine now covers immutable-field `StructAtomicGet*`, but generic pass/effect modeling remains conservative and no broader aggregate atomic GSI surface is implemented. | Inventory watchpoint; add source-backed tests only for concrete Binaryen-positive opcodes beyond current `StructAtomicGet*`. |
| Exact current upstream version | The repo's source dossier is anchored in `version_129` with a current-main recheck; local tooling now reports `wasm-opt version_130`. | Starshine docs and backlog use the older detailed source map plus June follow-ups. | Before final closeout, refresh the precise `version_130` source/lit contract and compare it to this list. |

## Red tests added in this slice

The new tests are intentionally Binaryen-positive and Starshine-red under the current implementation:

1. `global-struct-inference un-nests nested struct field values`
   - Covers non-constant aggregate field operand un-nesting.
   - Expected behavior: `struct.get` disappears from the function and a fresh global is added for the nested value.
2. `global-struct-inference preserves nullable traps when un-nesting nested struct fields`
   - Covers the same nested aggregate un-nesting family with nullable trap preservation.
   - Expected behavior: `struct.get` disappears, `ref.as_non_null` / `drop` remain, and a fresh global is added.
3. `global-struct-inference un-nests direct-global fields in modules with many globals`
   - Covers the artificial `globals.length() > 4` local gate for direct-global reads.
   - Expected behavior: direct-global non-constant field fold still happens and the fresh global raises the defined-global count from 5 to 6.
4. `global-struct-inference un-nests direct-global fields in modules with many functions`
   - Covers the artificial `funcs.length() > 2` local gate for direct-global reads.
   - Expected behavior: direct-global non-constant field fold still happens in the third function and a fresh global is added.
5. `global-struct-inference un-nests closed-world local select fields in modules with many globals`
   - Covers the artificial global-count gate for closed-world typed-read select rewrites.
   - Expected behavior: the local `struct.get` becomes a singleton `select(ref.eq(...))` after un-nesting the non-constant candidate field.
6. `global-struct-inference un-nests closed-world local select fields in modules with many functions`
   - Covers the artificial function-count gate for closed-world typed-read select rewrites.
   - Expected behavior: the local `struct.get` becomes a singleton `select(ref.eq(...))` in the third function and a fresh global is added.

Focused red verification run:

- Command: `moon test --package jtenner/starshine/passes --file global_struct_inference_test.mbt`
- Result before implementation: red as intended, `45` passed / `6` failed.
- Failed tests: the six tests listed above.

Implementation green evidence:

- `moon info`: reproduced the known Moon tool panic (`index out of bounds: the len is 36 but the index is 8329485`).
- `moon test --package jtenner/starshine/passes --file global_struct_inference_test.mbt`: `51` passed / `0` failed.
- `moon fmt`: passed.
- `moon test src/passes`: `1996` passed / `0` failed.
- `moon test`: `5188` passed / `0` failed.
- `moon build --target native --release src/cmd`: passed; the final rerun after cleanup was up to date, while the earlier build showed pre-existing `pass_manager.mbt` unused-function warnings.
- Direct compare: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --out-dir .tmp/pass-fuzz-global-struct-inference-gsi-gaps-10000-final --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - compared: `7604 / 10000`
  - normalized matches: `7604`
  - mismatches: `0`
  - validation/property/generator failures: `0`
  - command failures: `20`

These tests protect missing optimization behavior rather than runtime correctness bugs: the pre-fix module remains semantically valid, but Starshine had not matched Binaryen's optimization behavior. The covered nested-aggregate and un-nesting-size-gate families are now implemented and direct-compare green on the standard 10000-case lane.

## Follow-up red tests for remaining gaps

The next requested red phase added tests for the remaining source-backed ordinary-GSI gaps:

1. `global-struct-inference un-nests direct array.new_fixed field values`
   - Covers aggregate allocation un-nesting beyond struct constructors.
   - Binaryen proof: `wasm-opt --all-features --gsi` splits `array.new_fixed` into a fresh immutable global and folds the direct field read.
2. `global-struct-inference un-nests direct array.new_default field values`
   - Covers the zero-element/default aggregate allocation family.
   - Binaryen proof: `wasm-opt --all-features --gsi` splits `array.new_default` into a fresh immutable global and folds the direct field read.
3. `global-struct-inference un-nests closed-world array field select values`
   - Covers aggregate allocation un-nesting feeding the closed-world two-value singleton-select path.
   - Binaryen proof: `wasm-opt --all-features --closed-world --gsi` emits a `select(ref.eq(...))` over a fresh array global and `ref.null`.
4. `global-struct-inference refinalizes null-result local folds`
   - Covers the documented null-result refinalization shape.
   - Current Starshine already passes this focused shape, so it is coverage, not a red gap.

Focused verification after these tests:

- Command: `moon test --package jtenner/starshine/passes --file global_struct_inference_test.mbt`
- Result before implementation: red as intended for aggregate array un-nesting, `52` passed / `3` failed.
- Failed tests: the three array un-nesting tests listed above.

Aggregate array un-nesting implementation evidence:

- Change: `gsi_unnestable_stack_operand_count` / `gsi_unnestable_instr_result_type` now admit `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, and `array.new_elem` as un-nestable aggregate constructors with exact non-null array result types.
- `moon info`: reproduced the known Moon tool panic (`index out of bounds: the len is 36 but the index is 8329485`).
- `moon test --package jtenner/starshine/passes --file global_struct_inference_test.mbt`: `55` passed / `0` failed.
- `moon fmt`: passed.
- `moon test src/passes`: `2000` passed / `0` failed.
- `moon test`: `5192` passed / `0` failed.
- `moon build --target native --release src/cmd`: passed with pre-existing `pass_manager.mbt` unused-function warnings.
- Direct compare: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --out-dir .tmp/pass-fuzz-global-struct-inference-array-unnesting-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - compared: `7608 / 10000`
  - normalized matches: `7608`
  - mismatches: `0`
  - validation/property/generator failures: `0`
  - command failures: `20`

Final-style 100000-case signoff attempt requested by the user:

- Command: `moon build --target native --release src/cmd && bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass global-struct-inference --out-dir .tmp/pass-fuzz-global-struct-inference-final-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
- `moon build --target native --release src/cmd`: no work to do.
- Compared: `99751 / 100000`.
- Normalized matches: `99748`.
- Mismatches: `3`.
- Validation/property/generator failures: `0`.
- Command failures: `249`; command failures did not count toward max failures. Classes: `219` `binaryen-rec-group-zero`, `12` `binaryen-bad-section-size`, `11` `binaryen-command-failed`, `6` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`.
- `maxFailuresHit`: `false`.
- Agent mismatch classification: all three observed mismatches were semantic-safe dropped-unreachable debris that Binaryen removes and Starshine preserved before a hard `unreachable`, not GSI-specific semantic drift:
  - `case-023083-wasm-smith`: Starshine kept `(drop (unreachable))` before `unreachable`.
  - `case-046375-wasm-smith`: Starshine kept nested `(drop (drop (unreachable)))` before `unreachable`.
  - `case-082547-wasm-smith`: Starshine kept `(drop (unreachable))` before `unreachable` inside the same hard-unreachable tail family.
- This was not a clean zero-mismatch final closeout under the strict template, but it was behavior-green by agent classification for the inspected mismatch family.

Debris-cleanup follow-up:

- Shapes identified and tested in `src/passes/global_struct_inference_test.mbt`:
  - direct `(drop (unreachable)); unreachable`;
  - nested `(drop (drop (unreachable))); unreachable`;
  - dropped-unreachable debris inside nested control before hard `unreachable`.
- Change: direct `global-struct-inference` now applies the shared `pass_raw_remove_dropped_unreachable_debris(...)` cleanup before candidate analysis, so even no-candidate modules receive the same Binaryen-style dead-unreachable-debris normalization used by recent cleanup slices.
- Evidence:
  - `moon fmt`: passed.
  - `moon test --package jtenner/starshine/passes --file global_struct_inference_test.mbt`: `58` passed / `0` failed.
  - `moon test src/passes`: `2003` passed / `0` failed.
  - `moon test`: `5195` passed / `0` failed.
  - `moon build --target native --release src/cmd`: passed with pre-existing `pass_manager.mbt` unused-function warnings.
  - Direct 10000-case compare: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --out-dir .tmp/pass-fuzz-global-struct-inference-debris-cleanup-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
    - compared: `7609 / 10000`;
    - normalized matches: `7609`;
    - mismatches: `0`;
    - validation/property/generator failures: `0`;
    - command failures: `20`.
- Per user request, the 100000-case lane was not rerun for this simple shared cleanup follow-up.

## Suggested next implementation order

1. Widen un-nestable operand splitting to array allocation constructors (`array.new`, `array.new_default`, `array.new_fixed`, and source-backed data/elem variants if local const-expression validation supports them), preserving exact non-null array result types and operand counts.
2. Refresh the Binaryen `version_130` source/lit surface before expanding beyond these tests, especially for any ordinary-GSI carrier behavior.
3. Keep `global-struct-inference-desc-cast` as a separate pass audit unless the user explicitly widens this slice to the sibling pass.
4. Add source-backed tests before claiming arbitrary/cast-aware carrier parity.
