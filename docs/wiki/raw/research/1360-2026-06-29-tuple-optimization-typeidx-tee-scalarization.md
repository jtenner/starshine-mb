# Tuple Optimization Type-Indexed Tee Scalarization Slice

Date: 2026-06-29
Status: working evidence; not a final TO closeout

## Sources

- Starshine implementation: `src/passes/tuple_optimization.mbt`
- Focused pass coverage: `src/passes/tuple_optimization_wbtest.mbt`
- Focused native command coverage: `src/cmd/cmd_native_wbtest.mbt`
- Prior type-indexed spill slice: `docs/wiki/raw/research/1359-2026-06-29-tuple-optimization-typeidx-spill-scalarization.md`
- Dedicated TO profile artifacts:
  - `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-simple-payload`
  - `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-6-current-thread`
  - `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-6-host-tee-simple-payload`
  - `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-host-tee-simple-payload`

## Question

After the type-indexed spill slice, `tuple-optimization-all` still exposed red `tuple-optimization:tee` cases where a simple type-indexed multivalue block fed a host `local.tee` lane and a non-host scalar lane:

```wat
(module
  (type (;0;) (func))
  (type (;1;) (func (result i32 i64)))
  (func (;0;) (type 0)
    (local i32 i64)
    block (type 1)
      i32.const 17
      i64.const 19
    end
    local.set 1
    local.tee 0
    drop
    local.get 1
    drop))
```

The pre-slice raw Starshine output validated and had no `tuple.extract`, but still preserved a structured scalar carrier around the host lane. Binaryen instead scalarized into scalar locals and `local.tee`/copy traffic.

## Red-First Coverage

A new native regression was added for the raw type-indexed block tee carrier. It failed before the implementation because the emitted wasm still printed a block carrier:

```sh
moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*type-indexed block tee carrier*'
```

Failure excerpt from `wasm-tools print`:

```wat
block
  block (type 1) (result i32 i64)
    i32.const 17
    i64.const 19
  end
  local.set 3
  local.set 2
  local.get 3
  local.set 1
end
```

The adjacent pass-level test also records the intended no-`tuple.extract` / no scalar-result-carrier behavior for the type-indexed tee surface.

## Change

`src/passes/tuple_optimization.mbt` now has a narrow anchor-host source rewrite for source groups with:

- a host lane anchored by a root non-host lane,
- dedicated split locals,
- a simple block payload made only of cloneable constants or `local.get`s.

For that shape the pass inserts scalar split-local initialization before the anchor root, clones the simple block payload directly into those split-local writes, copies non-host lanes from split locals, and replaces the host defining node with scalar `local.tee`/`local.set` from the host split local. This removes the structured carrier rather than wrapping the multivalue producer in a scalar-result block.

This remains intentionally narrower than broad root-control reconstruction: non-simple payloads still fall back to the existing conservative carrier paths.

## Focused Validation

After the implementation:

- `moon fmt`
  - completed.
- `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*type-indexed block tee carrier*'`
  - `1 passed, 0 failed`; pre-existing warnings only.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*type-indexed block tee*'`
  - `1 passed, 0 failed`.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - `47 passed, 0 failed`.
- `moon test --package jtenner/starshine/cmd --file cmd_native_wbtest.mbt --target native --filter '*type-indexed block*'`
  - `2 passed, 0 failed`.
- `moon test src/passes`
  - `3602 passed, 0 failed`.
- `moon build --target native --release src/cmd`
  - completed with pre-existing warnings.

## Dedicated Profile Smoke And Measurement

Current post-slice smoke:

```sh
bun scripts/pass-fuzz-compare.ts --count 30 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-host-tee-simple-payload --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50
```

Result:

- compared: `30 / 30`
- validation/generator/command/property failures: `0`
- normalized mismatches: `30`
- profile distribution: spill `12`, tee `4`, copy-chain `14`
- Binaryen cache: `30` hits, `0` misses

A count-6 smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-6-host-tee-simple-payload` also compared `6 / 6` with zero failures and `6` normalized mismatches. Its first tee case now has no structured carrier in Starshine output:

```wat
(local.set $1 (i32.const 17))
(local.set $3 (i64.const 19))
(local.set $2 (local.get $3))
(local.set $0 (local.get $1))
(drop (local.get $2))
```

The remaining mismatch is scalar temp/tee/copy spelling, not a tuple/block carrier.

Approximate raw-size/local/op deltas measured from the count-30 WAT artifacts (`Starshine - Binaryen`):

| profile label | cases | raw bytes | locals | effective WAT ops |
| --- | ---: | ---: | ---: | ---: |
| `tuple-optimization:spill` | 12 | `+24` total (`+2` each) | `-24` total (`-2` each) | `-36` total (`-3` each) |
| `tuple-optimization:tee` | 4 | `+4` total (`+1` each) | `-8` total (`-2` each) | `-16` total (`-4` each) |
| `tuple-optimization:copy-chain` | 14 | `-56` total (`-4` each) | `-84` total (`-6` each) | `-140` total (`-10` each) |

Interpretation: the simple tee carrier is now reduced to scalar traffic and is smaller in locals/op count but still one raw byte larger than Binaryen in this small sample. The copy-chain sample is a clear raw-size/local/op Starshine win, while the spill and tee samples need broader classification before any final accepted divergence. These are agent measurements from the saved WAT/raw artifacts, not a harness-provided semantic classification.

## Current Classification

This slice closes the structured-carrier part of the simple type-indexed tee family. It does not close `[O4Z-AUDIT-TO]` because the dedicated profile still reports `30 / 30` normalized mismatches and the residual scalar temp/tee/copy spelling has not been accepted as a source-backed Starshine win or aligned to Binaryen.

Next useful work: classify the residual simple spill/tee one-byte-larger scalar spelling and the copy-chain Starshine-shorter family separately, then either document narrow measured wins with reopening criteria or align the scalar temp/tee ladder where Binaryen parity is required.

## Follow-up

The next slice is recorded in [`1361-2026-06-29-tuple-optimization-drop-only-typeidx-lanes.md`](1361-2026-06-29-tuple-optimization-drop-only-typeidx-lanes.md). It keeps the dedicated profile raw-red but changes the simple type-indexed spill/tee residuals from raw-size-larger to sampled raw-size wins by omitting copyback to original drop-only lane locals.
