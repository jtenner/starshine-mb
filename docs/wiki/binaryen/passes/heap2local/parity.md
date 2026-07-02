---
kind: comparison
status: supported
last_reviewed: 2026-07-02
sources:
  - ../../../raw/research/1402-2026-07-02-heap2local-genvalid-profile-start.md
  - ../../../raw/research/0553-2026-05-08-heap2local-backlog-closure.md
  - ../../../raw/research/0531-2026-05-06-heap2local-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md
  - ../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md
  - ../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md
  - ../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md
  - ../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./validation-fixups-and-special-cases.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../../../../../src/passes/heap2local.mbt
  - ../../../../../src/passes/heap2local_test.mbt
  - ../../../../../src/passes/heap2local_primary_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
---

# `heap2local` Binaryen Parity

## Durable Conclusions

- Binaryen `version_129` rewrites exclusive, nonescaping struct allocations and small eligible arrays into scalar locals.
- Arrays only enter the transform when the size is constant and `< 20`, the element type is local-representable, and indexed traffic stays constant.
- Safe flow-through cases include direct local owners, exclusive local-copy chains, direct tees, simple block or loop result flow, `ref.as_non_null`, `ref.eq`, `ref.test`, successful `ref.cast`, and descriptor-bearing `ref.get_desc` cases.
- Immediate Binaryen bailout families include escapes through calls or returns, mixed local provenance, `if`-mediated value mixing, and nonconstant array sizes or indexes. Do **not** list atomic array access as a generic upstream bailout: the source-backed Binaryen contract has atomic/RMW/cmpxchg handling when nonescape and exclusivity are proven, even though current Starshine's direct-array subset is narrower.
- Binaryen runs the array lowering first, then the struct rewrite, and each invocation is intentionally single-iteration.
- A 2026-04-25 current-main/code-map refresh found no teaching-relevant drift beyond the already-recorded narrow array/cmpxchg/unreachable-`ref.test` caveat and added the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## Current In-Tree Status

- The explicit implementation lives in [`../../../../../src/passes/heap2local.mbt`](../../../../../src/passes/heap2local.mbt).
- Focused coverage lives in [`../../../../../src/passes/heap2local_test.mbt`](../../../../../src/passes/heap2local_test.mbt).
- The Binaryen-aligned primary suite lives in [`../../../../../src/passes/heap2local_primary_test.mbt`](../../../../../src/passes/heap2local_primary_test.mbt).
- Preset scheduling coverage lives in [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt).

The current Starshine slice covers the full in-tree primary suite:

- direct exclusive struct owners, repeated same-owner fresh allocations with self-copy writes, local-copy chains, tees, and simple block-result flow
- `ref.as_non_null`, direct `ref.eq`, and successful `ref.cast`
- descriptor-bearing `struct.new_desc` and `struct.new_default_desc` plus `ref.get_desc`
- constant-size `array.new_default`, `array.new`, and `array.new_fixed`
- constant-index `array.get`, `array.get_s`, `array.get_u`, and `array.set`
- direct array `ref.test`
- bailout on parameter-backed mixed provenance

The 2026-07-02 audit start added a dedicated GenValid aggregate, `heap2local-all`, with leaves for struct scalarization (`heap2local-struct`), fixed-size array lowering (`heap2local-array`), and direct fresh-reference folds (`heap2local-ref`). This is profile and documentation progress only until the focused GenValid tests and compare lanes are run in a shell-enabled environment.

## Remaining Gap

- Upstream Binaryen still has a broader nondefaultable-local / refinalization repair story than current Starshine documents locally.
- But that surface is not a current Starshine `heap2local` parity blocker: validator-accepted open-world inputs still reject nondefaultable locals before the pass can run, and the previously-missing no-DWARF neighbor cluster is now proven in-tree.
- Reopen a new cross-cutting task only if Starshine later accepts that local surface.

## Current Evidence

- A `2026-07-02` follow-up fixed the first reduced generated struct family: repeated same-owner fresh allocations plus self-copy writes are now scalarized, and the focused regression lives in `src/passes/heap2local_test.mbt`. Replay `.tmp/pass-fuzz-heap2local-case000001-after-sequential-owner` still mismatches raw compare (`1/1`, zero failures), but Starshine and Binaryen both scalarize the GC traffic; the residual is agent-classified as output-shape/local-debris drift from Binaryen preserving extra local/default/drop scaffolding that Starshine omits after proving the unused initialization is pure/nontrapping. The 100-case struct leaf smoke `.tmp/pass-fuzz-heap2local-struct-100-after-sequential-owner` compared `100/100` with `18` normalized and `82` residual mismatches; a classifier found every saved Starshine mismatch had no residual `struct.new`, `struct.get`, or `struct.set` and all `82/82` Starshine canonical wasm outputs were smaller than Binaryen's.
- A later `2026-07-02` follow-up fixed two more generated families with red-first focused regressions in `src/passes/heap2local_test.mbt`: straight-line repeated same-owner fixed-array allocation epochs now lower through scalar element locals, and direct fresh-struct `ref.test` folds to a constant. Replays `.tmp/pass-fuzz-heap2local-case000015-after-sequential-array` and `.tmp/pass-fuzz-heap2local-case000004-after-direct-struct-reftest` still raw-mismatch but contain no residual generated H2L operations in Starshine output. Aggregate smoke `.tmp/pass-fuzz-heap2local-all-100-after-sequential-array-reftest` compared `100/100` with `22` normalized and `78` residual mismatches, zero failures, selected profiles `struct=49`, `array=22`, `ref=29`; all saved residuals have no `struct`/`array`/`ref.eq`/`ref.test` H2L traffic and `78/78` smaller Starshine canonical wasm.
- The scaled generated lane `.tmp/pass-fuzz-heap2local-all-1000-after-array-reftest` compared `1000/1000` with `244` normalized and `756` residual mismatches, zero failures, selected profiles `struct=423`, `array=276`, `ref=301`, and saved residuals `struct=351`, `array=146`, `ref=259`. Agent classifier found no residual generated H2L ops in any saved Starshine output (`struct.new`/`struct.get`/`struct.set`, array new/get/set variants, `ref.eq`, or `ref.test`) and `756/756` smaller Starshine canonical wasm. Existing compare normalizers did not classify this residual family: both `ssa-local-allocation-debris + local-cleanup-debris` and `drop-consts + ssa-local-allocation-debris + local-cleanup-debris` reruns stayed at `244` normalized, `0` compare-normalized, and `756` mismatches. Current agent judgment for the scaled generated lane: residual output-shape/local-debris wins after Starshine performs the H2L-relevant transforms, not active generated H2L traffic. H2L remains not closeout-ready until the required `10000` dedicated lane and final signoff matrix run, and until the local-debris normalizer/alignment decision is either implemented or explicitly accepted with reopening criteria.
- A `2026-07-02` profile slice added `heap2local-all` and documented the three initial generated transformation families. Focused GenValid validation passed (`116/116` file tests, `1652/1652` `src/validate`), and native `src/cmd` built at `_build/native/release/build/cmd/cmd.exe`. The first aggregate smoke `.tmp/pass-fuzz-heap2local-genvalid-all-1000-aggregate-config-fix` hit the mismatch cap after `278` compared cases (`67` normalized, `211` mismatches, zero command/validation/generator/property failures); leaf probes also showed mismatches. These are open H2L behavior-parity gaps, not accepted drift.
- A `2026-05-08` backlog-closure review confirmed that the old `[H2L]002` wording was stale: the exact `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighborhood is now represented and proven elsewhere in-tree, while nondefaultable-local repair remains outside today's validator-accepted Starshine input surface.
- A `2026-05-06` refreshed direct lane (`bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --out-dir .tmp/pass-fuzz-heap2local`) reports:
  - `6759 / 10000` compared
  - `6759` normalized matches
  - `20` command failures in the known Binaryen empty-recursion-group parser/canonicalization class
  - `0` mismatches
- A `2026-04-11` `--pass heap2local` smoke rerun (200 mixed cases, `seed 0x5eed`) reports:
  - `199 / 200` compared
  - `199` normalized matches
  - `1` command failure (`binaryen-rec-group-zero`, `case-000029-wasm-smith`)
  - `0` mismatches
- The `2026-04-03` `10000`-case `gen-valid` compare remains in `result` form as a historical full-lane benchmark.

## Sources

- GenValid profile start: [`../../../raw/research/1402-2026-07-02-heap2local-genvalid-profile-start.md`](../../../raw/research/1402-2026-07-02-heap2local-genvalid-profile-start.md)
- Backlog-closure review: [`../../../raw/research/0553-2026-05-08-heap2local-backlog-closure.md`](../../../raw/research/0553-2026-05-08-heap2local-backlog-closure.md)
- Refreshed direct revalidation: [`../../../raw/research/0531-2026-05-06-heap2local-direct-revalidation.md`](../../../raw/research/0531-2026-05-06-heap2local-direct-revalidation.md)
- Current source/code-map manifest: [`../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md)
- Current follow-up note: [`../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md)
- Implementation/test-map page: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- Archived research doc: [`../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md`](../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md)
- Supplemental health rerun: [`../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md`](../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Heap2Local.cpp>
- Implementation: [`../../../../../src/passes/heap2local.mbt`](../../../../../src/passes/heap2local.mbt)
- Focused tests: [`../../../../../src/passes/heap2local_test.mbt`](../../../../../src/passes/heap2local_test.mbt)
- Primary parity suite: [`../../../../../src/passes/heap2local_primary_test.mbt`](../../../../../src/passes/heap2local_primary_test.mbt)
