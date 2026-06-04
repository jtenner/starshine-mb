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
  - subtype-propagated single-candidate parent/supertype origins now rewrite in closed world when the candidate global's declared reference heap type is a subtype of the read type; broad `eqref` declarations still bail to avoid invalid replacements
  - exact and subtype-propagated multi-candidate local/param reads now fold in closed world when all safe candidates expose one equal materializable value
  - exact and subtype-propagated multi-candidate local/param reads now synthesize typed `select(ref.eq(...))` rewrites in closed world when two materializable values have one singleton candidate group
  - no sibling descriptor-cast implementation, no local atomic-get opcode surface, and arithmetic/bitwise/shift-rotate/unary-numeric un-nesting plus `ref.get_desc` are guarded to small modules
- The saved generated-artifact `-O4z` slot is still exactly green, which strongly suggests the artifact does not exercise the missing official surfaces.

## Current in-tree status

- The implementation lives in [`../../../../../src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt).
- The dedicated source/test/code-map page lives at [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
- The dedicated local status page now lives at [`./starshine-strategy.md`](./starshine-strategy.md), with the implementation-detail page at [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).
- The focused public-pipeline suite lives in [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt); the closed-world analysis fact coverage lives in [`../../../../../src/passes/global_struct_inference_wbtest.mbt`](../../../../../src/passes/global_struct_inference_wbtest.mbt).
- Registry and preset coverage live in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), with module-pass dispatch in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).
- The pass is active in-tree and is scheduled in the early module cluster after `global-refining`.

## 2026-06-03 closed-world packed un-nesting repair

The closed-world packed un-nesting repair lets packed fresh-global repair expressions participate in local/param one-value and two-value grouping. Starshine now recognizes the repaired signed/unsigned expression shapes as `i32`, so a candidate set can fold or synthesize `select(ref.eq(...))` even when one candidate's packed payload was first split into a fresh immutable global. The focused public-pipeline test covers packed `i8` signed and `i16` unsigned singleton-select shapes.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-packed-closed-world-unnest-final-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-packed-closed-world-unnest-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `340.030 ms`
- Binaryen runtime: `500.633 ms`
- Starshine pass runtime: `0.413 ms`
- Binaryen pass runtime: `3.211 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for closed-world packed fresh-global value grouping only. It does not change the large-module gate, sibling descriptor-cast scope, atomic-get blocker, or explicit refinalization status.

## 2026-06-03 packed direct-global un-nesting repair

The packed direct-global un-nesting repair lets fresh immutable globals produced by the guarded small-module un-nesting path participate in `struct.get_s` / `struct.get_u` folds. Starshine now records un-nested packed payloads as materializable `i32` `global.get` values, then rebuilds signed reads with `i32.extend8s` / `i32.extend16s` and unsigned reads with `i32.and` masks. The focused public-pipeline test covers direct-global packed `i8` signed and `i16` unsigned operands that split into fresh globals and then fold the field read.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-packed-direct-unnest-final-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-packed-direct-unnest-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `345.354 ms`
- Binaryen runtime: `458.676 ms`
- Starshine pass runtime: `0.418 ms`
- Binaryen pass runtime: `3.199 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for packed direct-global fresh-global repair only. It does not change the large-module gate, sibling descriptor-cast scope, atomic-get blocker, or explicit refinalization status.

## 2026-06-03 subtype-propagated parent/supertype origin follow-up

The GSI001-I follow-up consumes subtype-propagated one-candidate facts for parent/supertype local/param origins. When a parent-typed `local.get -> struct.get*` pair has exactly one safe propagated candidate, Starshine now rewrites the reference operand to a trap-preserving block that drops the original local and yields the candidate global, leaving the `struct.get*` in place. The rewrite additionally checks the candidate global's declared reference heap type against the read type, so too-broad declarations like `eqref` remain unchanged instead of creating invalid `struct.get*` operands. This closes the local origin-only supertype gap for the one-candidate, validation-safe shape while keeping arbitrary operands, descriptor-cast, atomic-get, and broader refinalization work out of scope.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-propagated-origin-final-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-propagated-origin-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `313.941 ms`
- Binaryen runtime: `415.377 ms`
- Starshine pass runtime: `0.356 ms`
- Binaryen pass runtime: `2.827 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for validation-safe subtype-propagated one-candidate origin rewrites only. It is not evidence that the sibling descriptor-cast pass, atomic get opcodes, unbounded un-nesting, or a full refinalization layer are implemented.

## 2026-06-03 small-module shift/rotate un-nesting follow-up

The GSI001-K follow-up broadened the guarded small-module non-constant un-nesting vocabulary again to include pure integer shift and rotate operands (`i32.shl`, `i32.shr_s`, `i32.shr_u`, `i32.rotl`, `i32.rotr`, and the matching `i64` family). The large-module gate and read-gated request filter remain unchanged: Starshine only splits operands that are actually read by direct or closed-world local/param GSI sites, then repairs the struct initializer to use a fresh immutable global and forces `reorder-globals` repair. The focused public-pipeline test covers direct-global `i32.shl` and `i64.rotl` operands.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-unnest-shift-rotate-final-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-unnest-shift-rotate-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `306.490 ms`
- Binaryen runtime: `406.889 ms`
- Starshine pass runtime: `0.359 ms`
- Binaryen pass runtime: `3.028 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for the small-module shift/rotate un-nesting extension only. It does not change the large-module gate, sibling descriptor-cast scope, atomic-get blocker, or explicit refinalization status.

## 2026-06-03 small-module unary numeric un-nesting follow-up

The GSI001-L follow-up broadened the guarded small-module non-constant un-nesting vocabulary again to include pure non-trapping unary numeric operands: integer `eqz`/`clz`/`ctz`/`popcnt` and floating-point `abs`/`neg`. The large-module gate and read-gated request filter remain unchanged: Starshine only splits operands that are actually read by direct or closed-world local/param GSI sites, then repairs the struct initializer to use a fresh immutable global and forces `reorder-globals` repair. The focused public-pipeline test covers direct-global `i32.popcnt`, `i64.eqz`, and `f64.neg` operands.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-unnest-unary-numeric-final-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-unnest-unary-numeric-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `309.583 ms`
- Binaryen runtime: `424.580 ms`
- Starshine pass runtime: `0.434 ms`
- Binaryen pass runtime: `3.674 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for the small-module unary numeric un-nesting extension only. It does not change the large-module gate, sibling descriptor-cast scope, atomic-get blocker, or explicit refinalization status.

## 2026-06-03 small-module bitwise un-nesting follow-up

The GSI001-J follow-up broadened the guarded small-module non-constant un-nesting vocabulary from arithmetic add/sub/mul to include pure integer bitwise `and` / `or` / `xor` field operands. The large-module gate and read-gated request filter are unchanged: Starshine only splits operands that are actually read by direct or closed-world local/param GSI sites, then repairs the struct initializer to use a fresh immutable global and forces `reorder-globals` repair. The focused public-pipeline test covers direct-global `i32.and` and `i64.xor` operands.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-unnest-bitwise-final-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-unnest-bitwise-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `316.220 ms`
- Binaryen runtime: `457.262 ms`
- Starshine pass runtime: `0.369 ms`
- Binaryen pass runtime: `3.121 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for the small-module bitwise un-nesting extension only. It does not change the large-module gate, sibling descriptor-cast scope, atomic-get blocker, or explicit refinalization status.

## 2026-06-03 small-module un-nesting and `ref.get_desc` follow-up

The GSI001-G/H follow-up added a guarded local version of Binaryen's non-constant operand un-nesting and the plain-GSI `ref.get_desc` read surface. For small modules, pure arithmetic/bitwise/shift-rotate/unary-numeric non-constant field operands that are actually read by direct or closed-world local/param GSI sites are split into fresh immutable globals; the original struct initializer is repaired to `global.get` the fresh global, and a forced `reorder-globals` repair makes the fresh global precede dependent globals. The later GSI001-J/K/L follow-ups added pure integer bitwise, shift/rotate, and unary numeric operands to the same guarded vocabulary. The same trusted candidate machinery now folds direct `ref.get_desc` reads and closed-world local/param `ref.get_desc` reads when all candidate descriptor values match, with the two-value singleton-select helper available for differing descriptor globals. Large modules keep the previous materializable-only behavior to preserve pass-local runtime on the debug artifact. Atomic immutable-field gets remain an upstream-only documented surface because Starshine has no local struct atomic-get instruction form yet.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-gsi001gh-final3-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-gsi001gh-final8`

Result:

- canonical wasm equal: yes
- Starshine runtime: `319.303 ms`
- Binaryen runtime: `419.881 ms`
- Starshine pass runtime: `0.377 ms`
- Binaryen pass runtime: `3.017 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for the guarded un-nesting and `ref.get_desc` surfaces. It predates the subtype-propagated origin follow-up and is not evidence that the sibling descriptor-cast pass or atomic get opcodes are implemented.

## 2026-06-03 subtype-propagated parent one/two-value follow-up

The subtype-propagated parent one/two-value follow-up consumes the child-to-parent candidate facts added earlier. Parent-typed local/param `struct.get*` reads now fold to one trap-preserving value when all propagated safe candidates expose the same materializable field value, or synthesize the same typed `select(ref.eq(...))` shape when exactly two materializable values exist and one value group has one candidate global. The rewrite verifies candidate-created types are subtypes of the read type, checks materialized values against the parent field result type, preserves nullable traps, and keeps origin-only supertype rewrites, un-nesting, atomic gets, and `ref.get_desc` out of scope; the later GSI001-I slice adds validation-safe one-candidate origin rewrites.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-gsi001f-final2-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-gsi001f-final2`

Result:

- canonical wasm equal: yes
- Starshine runtime: `356.701 ms`
- Binaryen runtime: `582.130 ms`
- Starshine pass runtime: `0.384 ms`
- Binaryen pass runtime: `2.965 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for subtype-propagated parent one-value and singleton-tested two-value local/param rewrites only. It predates the subtype-propagated origin and guarded un-nesting/`ref.get_desc` follow-ups.

## 2026-06-03 two-value singleton-group local/param follow-up

The two-value singleton-group local/param follow-up added the next exact closed-world fact consumer. It rewrites only adjacent exact-type `local.get` / `struct.get*` pairs when the exact type has multiple safe direct candidate globals, the propagated fact list exactly matches those direct candidates, the requested immutable field materializes to exactly two values, and one value group has exactly one candidate global. The replacement is a result-typed block containing the two materialized values plus `ref.eq` between the original local reference and the singleton candidate global; nullable locals use `ref.as_non_null` on the condition path to preserve the original null trap. It deliberately keeps subtype/supertype rewrites, un-nesting, and larger decision trees out of scope.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-gsi001d-final-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-gsi001d-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `333.630 ms`
- Binaryen runtime: `480.875 ms`
- Starshine pass runtime: `0.695 ms`
- Binaryen pass runtime: `3.087 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for the exact two-value singleton-group local/param slice only. It is not evidence that supertype-origin rewrites, un-nesting, atomic gets, or `ref.get_desc` are implemented.

## 2026-06-03 one-value multi-candidate local/param follow-up

The one-value multi-candidate local/param follow-up added the next closed-world fact consumer. It rewrites only adjacent exact-type `local.get` / `struct.get*` pairs when the exact type has multiple safe direct candidate globals, the propagated fact list exactly matches those direct candidates, and every candidate materializes the same field value after packed-field repair. It deliberately keeps non-constant expression equivalence, subtype/supertype rewrites, two-value `select` synthesis, and un-nesting out of scope.

The final direct compare ran with a prebuilt native Starshine binary and automatic parallel workers:

- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --keep-going-after-command-failures --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --out-dir .tmp/pass-fuzz-global-struct-inference-gsi001c-final-10000`

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

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference --timing-only --out-dir .tmp/gsi-debug-artifact-timing-gsi001c-final`

Result:

- canonical wasm equal: yes
- Starshine runtime: `354.856 ms`
- Binaryen runtime: `529.859 ms`
- Starshine pass runtime: `0.440 ms`
- Binaryen pass runtime: `3.275 ms`
- Starshine pass skipped raw: no

This is semantic smoke and performance evidence for the exact one-value multi-candidate local/param slice only. It predates the exact two-value singleton-group follow-up and is not evidence that supertype-origin rewrites or un-nesting are implemented.

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
- exact and subtype-propagated single-candidate param and body-local origin rewrites in closed world, preserving null traps with `ref.as_non_null` plus `drop`, with broad global-declaration negatives guarding invalid replacement types
- exact and subtype-propagated multi-candidate one-value local/param folds in closed world, including equal literals, immutable `global.get`s, body locals, packed-field repair, child-only parent reads, and mixed parent/child candidate order
- exact and subtype-propagated multi-candidate two-value local/param selects in closed world, including two-global, three-global singleton-group, child-only parent, and mixed parent/child positives
- local-origin negatives for open world, more than two materializable values, two equal value pairs, non-materializable equal-looking expressions, poisoned exact/child types, mutable fields/globals, and `anyref`/too-broad global declarations
- closed-world facts for immutable top-level candidates, mutable-global exclusion, `anyref`/too-broad declaration exclusion, function-local allocation poisoning, nested global-initializer allocation poisoning, poisoned-child-to-parent propagation including no-global-section poison propagation, and child-candidate-to-parent propagation

That is a stronger local floor for the current subset.
It is still far smaller than the official Binaryen lit surface.

## Main remaining divergences from official Binaryen

## 1. Closed-world `typeGlobals` consumption is still narrow

Current local behavior after the 2026-06-03 follow-ups:

- `global_struct_inference_run_module_pass` no longer returns unchanged when `closed_world` is false; it scans immutable defined globals and applies the direct-global fold in open world
- when `closed_world` is true, it builds a conservative candidate/poison fact table for top-level immutable global origins and allocation poison sources, then rewrites exact or subtype-propagated local/param origins for one safe validation-typed candidate, or rewrites exact/subtype-propagated local/param reads for one materializable field value or exactly two materializable values where one value group has one candidate global

Official Binaryen `version_129` behavior:

- closed world enables the broader `typeGlobals` analysis
- but `optimize(module)` still runs afterwards in **all** modes
- direct immutable-global reads can still optimize in open world

This former conceptual gap is closed for the direct immutable-global fast path, and exact/subtype-propagated local/param one-global plus exact/subtype-propagated one-value and two-value singleton-group closed-world fact consumers now exist. `closed_world` still does not add arbitrary Binaryen operand reasoning or unbounded un-nesting; un-nesting exists only for small modules and selected pure arithmetic/bitwise/shift-rotate/unary-numeric scalar field operands.

## 2. The local pass only matches immediate instruction pairs

Current local behavior:

- look for immediate `GlobalGet` followed by immediate `StructGet` / `StructGetS` / `StructGetU`

Official Binaryen behavior:

- optimize direct immutable-global reads
- but also, in closed world, reason about arbitrary read operands such as params, locals, and supertypes using the type-to-global map

So the local pass still misses Binaryen shapes like:

- non-adjacent or nested reference producers
- large-module or unsupported non-constant field operands that would require fresh-global un-nesting

## 3. Subtype propagation is consumed only by local/param origin and value rewrites

Official Binaryen uses `SubTypes` to:

- poison supertypes when child allocations happen in functions or nested global positions
- propagate candidate child globals upward to parent reads

Current local pass now mirrors that in the fact table, including deterministic candidate ordering. Propagated child candidates now feed parent-typed one-candidate origin rewrites, one-value folds, and singleton-tested two-value selects. Origin rewrites additionally require the candidate global's declared reference heap type to be validation-safe for the read type, so broad declarations like `eqref` still bail out.

## 4. Local one-value grouping and two-value selects exist, but still stay one-compare only

Official Binaryen can:

- collapse many globals into one constant value
- or emit a `select(ref.eq(...))` when there are two unique values and one singleton-tested group

Current local pass now handles those cases for adjacent exact or subtype-propagated local/param reads whose safe candidates materialize values matching the read result type. It still does not synthesize larger decision trees.

## 5. Local un-nesting is small-module guarded

Official Binaryen can split a nested non-constant field operand into a fresh immutable global and continue the optimization.

Current local pass:

- has a fresh-global emission path for small-module pure arithmetic/bitwise/shift-rotate/unary-numeric scalar field operands that are actually read by direct or closed-world local/param GSI sites
- repairs original struct initializers to use the fresh immutable global and then invokes forced `reorder-globals` repair so dependencies precede uses
- deliberately skips this extra surface on larger modules to keep pass-local artifact timing within budget

## 6. Local materialization is still narrower than `PossibleConstantValues`

Official Binaryen treats immutable `global.get`s as constant materializable values and can combine that with un-nesting for non-constant operands.
That matters for official positive shapes where field values are not literals but are still stable immutable globals.

Current local pass does treat direct immutable `global.get` field payloads as materializable for exact and subtype-propagated local/param grouping, and now has a small-module fresh-global un-nesting path for pure arithmetic/bitwise/shift-rotate/unary-numeric scalar field operands that are actually read by direct or closed-world local/param GSI sites. It still has a smaller materialization surface than Binaryen and deliberately skips un-nesting on larger modules for pass-local runtime.

## 7. Descriptor coverage exists locally; atomic gets remain unavailable

Official Binaryen source and lit tests cover:

- packed fields
- atomic gets on immutable fields
- `ref.get_desc`
- sibling `gsi-desc-cast`

Current local pass now handles small-module direct and closed-world local/param `ref.get_desc` folds/selects over descriptor-constructor globals. It still handles no atomic gets because the local instruction set does not expose a struct atomic-get opcode, and the sibling descriptor-cast pass remains boundary-only.

A 2026-06-03 local opcode search refreshed that blocker. The `src/lib` instruction enum and constructors expose ordinary `StructGet`, `StructGetS`, `StructGetU`, array gets, and `RefGetDesc`, but no `StructGetAtomic` or `struct.atomic.get` spelling. Focused greps for `struct.atomic`, `atomic.get`, `StructGetAtomic`, and `Struct.*Atomic` found no matches in `src/wast` or `src/validate`. So atomic-get parity is blocked on adding or discovering a real local opcode surface, not on GSI rewrite logic alone.

## 8. Representation-specific type repair differs locally

Official Binaryen explicitly refinalizes changed functions.
Current local boundary IR pass does not mirror that exact mechanism because it works in a different representation.

That is likely fine for the current subset, but it is still a real architectural divergence from the source oracle.

## Why the saved audit can still be exactly green

The most plausible explanation is:

- the saved artifact either does not hit many direct-global shapes or those shapes now normalize the same after the 2026-06-03 upgrade
- it still does not rely on the richer descriptor-cast, atomic, full-refinalization, or unbounded un-nesting surfaces
- the local subset is therefore enough for that particular slot

Again, that is an inference from the green audit plus the visible local-vs-upstream source differences.

## Practical rule for future work

- Keep the current local subset described honestly as a subset.
- Do **not** describe it as “what Binaryen `gsi` does.”
- If future parity work targets the full Binaryen contract, the next missing surfaces to implement are, in value order:
  1. unbounded or more Binaryen-complete un-nesting of non-constant operands, only with pass-local runtime evidence
  2. atomic get support once a local struct atomic-get opcode exists
  3. the sibling descriptor-cast pass when explicitly scheduled
  4. explicit type-repair/refinalization if a future rewrite needs more than validation-preserving replacement typing
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
