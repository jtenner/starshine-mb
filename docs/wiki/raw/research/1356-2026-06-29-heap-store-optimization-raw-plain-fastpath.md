---
kind: research
status: current
last_reviewed: 2026-06-29
sources:
  - ./1355-2026-06-29-heap-store-optimization-tiny-plain-fastpath.md
  - ./1354-2026-06-29-heap-store-optimization-hot-candidate-speed-rerun.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../src/passes/heap_store_optimization.mbt
---

# HSO raw plain-struct.new fast path reaches hot candidate target

## Question

Can direct `heap-store-optimization` meet the `0.95x` Binaryen pass-local target on `.tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat` without weakening HSO safety behavior?

## Result

Yes for this hot fixture. This slice adds a raw/lowered fast path for the exact plain constructor chain:

```wat
CONST...
struct.new $S
local.set $x
local.get $x
CONST_OR_REF_NULL
struct.set $S i
local.get $x
CONST_OR_REF_NULL
struct.set $S j
```

The fast path folds the simple stores into the `struct.new` operands before the ordinary HOT lift. It is deliberately narrow: it only handles plain `struct.new`, same-local consecutive `struct.set` roots, childless raw constants/ref.null values, at least two consumed stores, and modules where the rewrite removes all remaining HSO candidates from that lowered function. Everything else falls back to the existing raw default-chain helper or HOT HSO path.

Seven fresh `self-optimize-compare` samples now have Starshine median `0.781ms` versus Binaryen median `1.366ms`. Starshine is `0.572x` Binaryen time (`1.749x` Binaryen speed) and meets the `0.95x` target. All seven samples kept `Starshine pass skipped raw: no`, `Normalized WAT equal: yes`, and `Canonical function compare equal: yes`.

## Implementation rationale

Binaryen's `HeapStoreOptimization.cpp` is cheap on this shape because it scans block-local action pointers and mutates the small expression list directly; it does not pay per-function HOT lift, analysis, mutation, and lower costs for the simple consecutive-root case. Starshine's previous tiny HOT fast path proved the same local safety property but still paid those per-function HOT costs across 2000 functions. The new pass-manager raw lane applies the same proof before HOT lift, then reports it as a real pass path rather than a raw skip.

The path is behavior-equivalent for the accepted shape because the only moved values are raw constants or `ref.null`, which do not trap, call, read/write local/global/memory/table state, or interact with catch/control ordering. The receiver is the same local immediately assigned from the constructor, and the stores are consecutive, same-type, same-local writes. Repeated field stores use the later value, matching the existing HOT chain behavior.

## Changed files

- `src/passes/pass_manager.mbt`
  - added `run_hot_pipeline_raw_heap_store_optimization_plain_struct_new_chain(...)`;
  - routes `heap-store-optimization` through that raw fast path before HOT lift;
  - returns `trace_skip_raw=false` and emits `perf:timer name=pass:heap-store-optimization`, so `self-optimize-compare` reports `Starshine pass skipped raw: no`.
- `src/passes/perf_test.mbt`
  - added a regression proving the raw plain fast path removes `struct.set`, emits a pass timer, avoids lift/lower timers, and does not report `skip-raw`.

## Timing evidence

Fixture: `.tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat`.

Build:

```sh
moon build --target native --release src/cmd
```

Command shape:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-hot-plain-struct-new-candidates-2000-20260625.wat \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-hot-plain-struct-new-rawfast-20260629/run-$n \
  --heap-store-optimization
```

| Run | Starshine pass ms | Binaryen pass ms | Raw skipped | Normalized WAT equal | Canonical function compare equal |
|---:|---:|---:|---|---|---|
| 1 | 0.730 | 1.052 | no | yes | yes |
| 2 | 0.858 | 1.134 | no | yes | yes |
| 3 | 0.830 | 1.726 | no | yes | yes |
| 4 | 0.781 | 1.676 | no | yes | yes |
| 5 | 0.778 | 1.677 | no | yes | yes |
| 6 | 0.862 | 1.366 | no | yes | yes |
| 7 | 0.703 | 1.062 | no | yes | yes |

Medians:

- Starshine: `0.781ms`
- Binaryen: `1.366ms`
- Starshine/Binaryen time ratio: `0.572x`
- Binaryen-speed fraction: `1.749x`
- `0.95x` target at this Binaryen median: Starshine `<=1.438ms`

This also beats the previous slice's absolute target of about `<=1.168ms` from Binaryen median `1.110ms`.

## Validation

- `moon fmt` — passed.
- `moon test --package jtenner/starshine/passes --file perf_test.mbt` — passed, `105/105`; the new test failed before implementation because HOT lift/lower was still used.
- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed, `417/417`.
- `moon test --package jtenner/starshine/passes --file registry_test.mbt` — passed, `7/7`.
- `moon test src/passes` — passed, `3576/3576`.
- `moon build --target native --release src/cmd` — passed with existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-hso-raw-plain-fastpath-100-20260629 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20` — compared `100/100`, normalized matches `100`, mismatches `0`, validation/generator/property/command failures `0`.
- Seven `self-optimize-compare` runs above — all normalized-equal, canonical-function-equal, raw-skipped `no`.

## Remaining risks

- The speed target is closed for the named hot plain-`struct.new` fixture, not for every possible HSO candidate family.
- The raw fast path intentionally removes `struct.set` roots instead of leaving Binaryen-style nops; normalized WAT and canonical function compare remain green, and this matches the prior HOT fast-path output policy.
- The raw lane is narrow and must stay narrow unless future slices add equivalent effect/order proofs for broader values, nested control, default constructors, descriptors, arrays, branches, or catch/throw surfaces.
- Existing HSO final closeout evidence remains useful but should be refreshed separately if maintainers want to re-close the entire `[O4Z-AUDIT-HSO]` audit after this speed fix.
