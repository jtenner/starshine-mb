---
kind: research
status: working
created: 2026-07-02
sources:
  - ../../binaryen/passes/heap2local/fuzzing.md
  - ../../binaryen/passes/heap2local/parity.md
  - ../../binaryen/passes/heap2local/index.md
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/Heap2Local.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap2local.wast
---

# `heap2local` GenValid profile start

## Goal

Start `[O4Z-AUDIT-H2L]` by adding a pass-specific GenValid surface that intentionally emits `heap2local` candidates instead of relying only on ordinary mixed GenValid traffic.

## Source-backed transformation families

The current audit target remains Binaryen `version_130` `Heap2Local.cpp` plus the dedicated `heap2local.wast` lit surface. The pass families to keep sampled are:

1. Exclusive nonescaping struct allocation scalarization: fresh `struct.new` / `struct.new_default` values stored in locals and used only by compatible `struct.get` / `struct.set` traffic.
2. Local-owner flow-through: owner locals, exclusive copy chains, direct `local.tee`, and simple structured result carriers are eligible when provenance stays exact.
3. Fresh-reference folds: operations whose result follows from the fresh allocation identity, including `ref.as_non_null`, null/equality/test/cast cases, and descriptor reads where the descriptor-bearing allocation is exact.
4. Small fixed-size array lowering: constant-size arrays with constant indexed `array.get` / `array.set` traffic can be lowered through the array-to-struct path before scalarization.
5. Bailout families: escapes through returns/calls, mixed provenance, ambiguous branch/select joins, nonconstant array sizes/indexes, and validator-surface repair cases that Starshine still cannot accept before the pass runs.

## Changes made in this slice

- Added GenValid leaves:
  - `heap2local-struct`
  - `heap2local-array`
  - `heap2local-ref`
- Added aggregate profile:
  - `heap2local-all`
  - Aliases: `heap2local`, `heap-to-local`, `h2l`, `heap2local-closeout`, `heap2local-all-profiles`.
- Added a dedicated body generator toggle and slice for H2L candidates:
  - struct owner/set/get and copy-chain-like local traffic
  - constant-size array new/default/fixed with local-held get/set traffic
  - direct fresh-reference folds via `ref.as_non_null`, `ref.eq`, and `ref.test`
- Added GenValid tests that check profile resolution, aggregate leaf sampling, validation of generated modules, and presence of the intended struct/array/ref candidate families.

## Validation status

Commands run after shell access was restored:

- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` initially failed because `heap2local-array` and `heap2local-ref` configs compared equal to `heap2local-struct`; fixed by making profile configs distinct and by making `Heap2LocalAllProfile` use its own aggregate config.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` passed (`116/116`).
- `moon info` passed with pre-existing warnings.
- `moon test src/validate` passed (`1652/1652`).
- `moon build --target native --release src/cmd` passed with pre-existing warnings; the usable binary path is `_build/native/release/build/cmd/cmd.exe` in this worktree.

Profile smoke results:

- Incorrect binary-path probe: `.tmp/pass-fuzz-heap2local-genvalid-all-1000` used `target/native/release/build/cmd/cmd.exe` and produced `1000` Starshine command failures (`ENOENT`), so it is tooling/path noise only.
- Aggregate after config fix: `.tmp/pass-fuzz-heap2local-genvalid-all-1000-aggregate-config-fix` compared `278/1000`, normalized `67`, mismatches `211`, command/validation/generator/property failures `0`, Binaryen cache `267/11`, and hit the mismatch cap. Selected profiles: `heap2local-struct=131`, `heap2local-array=75`, `heap2local-ref=72` before cap.
- Leaf probes, `30` cases each:
  - `.tmp/pass-fuzz-heap2local-struct-30`: `30/30` compared, `5` normalized, `25` mismatches.
  - `.tmp/pass-fuzz-heap2local-array-30`: `30/30` compared, `17` normalized, `13` mismatches.
  - `.tmp/pass-fuzz-heap2local-ref-30`: `30/30` compared, `2` normalized, `28` mismatches.

Agent classification: these are **open H2L behavior-parity gaps**, not accepted safe drift. The first inspected struct case shows Binaryen scalarizing repeated fresh struct/default allocations through the same owner local plus fresh-reference folds, while Starshine leaves most of that traffic as GC operations. The dedicated profile is therefore doing its job by exposing under-sampled H2L families, but the pass is not closeout-ready.

## Follow-up: repeated same-owner struct allocations

A second 2026-07-02 slice reduced the first aggregate mismatch, `.tmp/pass-fuzz-heap2local-genvalid-all-1000-aggregate-config-fix/failures/case-000001-gen-valid`, to repeated writes of fresh `struct.new` / `struct.new_default` into the same owner local, including a `local.set $owner (local.get $owner)` self-copy. Binaryen scalarizes both allocation epochs. Starshine previously required exactly one write to the owner local, so it left all GC operations in place.

The fix adds a bounded straight-line sequential-owner path in `src/passes/heap2local.mbt`: when all writes to a non-param owner local are root-level fresh struct allocation writes or no-op self-copy writes, each allocation epoch is analyzed separately and lowered with the existing scalar-field rewrite. The focused regression `heap2local scalarizes repeated same-owner fresh struct allocations` in `src/passes/heap2local_test.mbt` failed before the implementation and now passes.

Validation and smokes for this slice:

- `moon test --package jtenner/starshine/passes --file heap2local_test.mbt` passed (`15/15`).
- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file heap2local_primary_test.mbt` passed (`16/16`).
- `moon test src/passes` passed (`3812/3812`).
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Replay `.tmp/pass-fuzz-heap2local-case000001-after-sequential-owner` compared `1/1` with one residual mismatch and zero failures. Agent classification: the original true GC-scalarization parity gap is fixed for this family; residual output differs because Binaryen preserves extra scalar local/default/drop debris while Starshine emits a smaller scalarized form after omitting pure/nontrapping unused initialization debris.
- `--normalize local-cleanup-debris` did not normalize that replay.
- Struct leaf smoke `.tmp/pass-fuzz-heap2local-struct-100-after-sequential-owner` compared `100/100`: `18` normalized, `82` mismatches, zero command/validation/generator/property failures. Every saved Starshine mismatch had no residual `struct.new`, `struct.get`, or `struct.set`, so the remaining struct mismatches are now output-shape/local-debris classification work rather than the original missed scalarization family.
- Aggregate smoke `.tmp/pass-fuzz-heap2local-all-100-after-sequential-owner` compared `100/100`: `22` normalized, `78` mismatches, zero failures, selected profiles `heap2local-struct=49`, `heap2local-array=22`, `heap2local-ref=29`.

## Next audit slice

1. Classify residual struct mismatches from `.tmp/pass-fuzz-heap2local-struct-100-after-sequential-owner` as Binaryen-local-debris/output-shape drift versus any remaining missed scalarization, and decide whether to add a H2L-specific compare normalizer or align output shape.
2. Reduce the highest-value array or direct-ref mismatch from `.tmp/pass-fuzz-heap2local-all-100-after-sequential-owner` into a focused failing test.
3. Implement the smallest safe parity fix or document a narrow blocker with reopening criteria, then rerun focused H2L tests and small leaf/aggregate lanes before scaling.
