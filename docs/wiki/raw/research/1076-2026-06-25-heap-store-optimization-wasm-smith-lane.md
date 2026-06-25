---
kind: research
status: active
created: 2026-06-25
sources:
  - ./1071-2026-06-25-heap-store-optimization-direct-o4z-refresh.md
  - ./1073-2026-06-25-heap-store-optimization-dedicated-profile-refresh.md
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../src/validate/gen_valid.mbt
---

# HSO explicit wasm-smith lane refresh

## Question

Can one missing final-matrix lane be advanced after the HSO source/status audits, and what does it show?

## Answer

The explicit `--wasm-smith` lane is now refreshed at the ordinary 10000-case scale. It is mostly green but not closeout-green: `9955/9956` compared cases normalized, with `44` Binaryen/oracle command failures and `1` raw normalized-output mismatch.

The single mismatch is not a heap-store transform family. The input has no GC heap store/constructor opportunity; it is pure unreachable/control debris. Binaryen's HSO command normalizes:

```wat
(drop
  (unreachable))
```

to:

```wat
(unreachable)
```

while Starshine keeps the `drop(unreachable)` wrapper. Both outputs validate and both raw wasm files are 79 bytes in this replay, but this is still an output-shape cleanup parity gap, not a documented Starshine win. Do not use this lane as final HSO closeout until the mismatch is fixed, normalized with an explicitly approved HSO-wide cleanup normalizer, or otherwise accepted under the repo's narrow drift policy.

## Why wasm-smith, not random all-profiles

A bounded source/tooling search during this slice found no checked-in profile named `random-all-profiles` or `all-profiles`. The explicit wasm-smith lane is a known required matrix lane and the environment supported it, so this slice advanced that lane instead of guessing a profile name.

## Commands

The explicit compare binary was refreshed first:

```sh
git status --short
moon build --target-dir target --target native --release src/cmd
```

Result: no uncommitted changes before the lane; Moon reported `Finished. moon: no work to do`.

The lane command was:

```sh
bun scripts/pass-fuzz-compare.ts \
  --wasm-smith \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-wasm-smith-20260625-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

| Metric | Count |
|---|---:|
| Requested | 10000 |
| Compared | 9956 |
| Normalized matches | 9955 |
| Cleanup-normalized matches | 0 |
| Raw mismatches | 1 |
| Validation failures | 0 |
| Property failures | 0 |
| Generator failures | 0 |
| Command failures | 44 |
| Binaryen rec-group-zero failures | 39 |
| Binaryen invalid-tag-index failures | 1 |
| Binaryen table-index-out-of-range failures | 1 |
| Binaryen bad-section-size failures | 3 |
| wasm-smith cache | 5000 hits / 5000 misses |
| Binaryen cache | 5039 hits / 4917 misses |
| Binaryen failure cache | 23 hits / 21 misses |

Input feature/trap facts across the lane:

| Fact | Count |
|---|---:|
| hasCall | 2837 |
| mutatesMemory | 1728 |
| mutatesTable | 227 |
| mutatesGlobal | 250 |
| hasException | 7039 |
| hasAtomics | 170 |
| hasUnreachable | 9981 |
| mayTrap | 9981 |

## Mismatch classification

Mismatch directory:

```text
.tmp/pass-fuzz-heap-store-optimization-wasm-smith-20260625-10000/failures/case-009332-wasm-smith
```

`failure-metadata.json` records `status: "mismatch"`, `detail: "normalized outputs differed"`, generator `wasm-smith`, and input facts `hasUnreachable: true`, `mayTrap: true`, with all call/memory/table/global mutation facts false.

The input function body is effectively:

```wat
memory.size
block (result i64)
  f64.const ...
  unreachable
end
unreachable
```

Normalized Binaryen output:

```wat
(drop
  (memory.size))
(drop
  (f64.const ...))
(unreachable)
```

Normalized Starshine output:

```wat
(drop
  (memory.size))
(drop
  (f64.const ...))
(drop
  (unreachable))
(unreachable)
```

Validation replay:

```sh
wasm-tools validate --features all \
  .tmp/pass-fuzz-heap-store-optimization-wasm-smith-20260625-10000/failures/case-009332-wasm-smith/starshine.raw.wasm
wasm-tools validate --features all \
  .tmp/pass-fuzz-heap-store-optimization-wasm-smith-20260625-10000/failures/case-009332-wasm-smith/binaryen.raw.wasm
wc -c \
  .tmp/pass-fuzz-heap-store-optimization-wasm-smith-20260625-10000/failures/case-009332-wasm-smith/starshine.raw.wasm \
  .tmp/pass-fuzz-heap-store-optimization-wasm-smith-20260625-10000/failures/case-009332-wasm-smith/binaryen.raw.wasm
```

Both validations passed; both raw outputs are 79 bytes, but `cmp` confirms the raw bytes differ.

Agent classification: semantic-equivalent unreachable cleanup drift, but not a Starshine win and not acceptable final output-shape drift under the current pass policy. Treat as an open cleanup parity gap unless a future slice fixes it or explicitly approves an HSO closeout normalizer with reopening criteria.
