# Tuple Optimization Broader Profile Triage And Performance Probe

Date: 2026-06-29
Status: working evidence; TO closeout remains open

## Sources

- Binaryen current-main `src/passes/TupleOptimization.cpp`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TupleOptimization.cpp>
- Binaryen current-main lit test `test/lit/passes/tuple-optimization.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/tuple-optimization.wast>
- Starshine implementation: `src/passes/tuple_optimization.mbt`
- Starshine focused coverage: `src/passes/tuple_optimization_wbtest.mbt`
- Prior residual classification: `docs/wiki/raw/research/1362-2026-06-29-tuple-optimization-residual-scalar-spelling.md`
- Broader profile artifacts: `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-100-broader-bin`
- Failed stale-bin probe artifacts: `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-100-broader`
- Performance artifacts: `.tmp/to-passlocal-candidate-heavy-100-20260629`, `.tmp/to-passlocal-candidate-heavy-500-20260629`, `.tmp/to-passlocal-candidate-heavy-1000-20260629`, `.tmp/to-passlocal-candidate-heavy-2000-20260629`

## Slice Goal

Broaden the post-`1362` residual triage beyond the first 30 dedicated `tuple-optimization-all` cases and start pass-local performance measurement if no new behavior family appears. This is not a final signoff lane; it is a bounded audit-driver slice.

## Broader Dedicated Profile Lane

First attempt:

```sh
moon build --target native --release src/cmd && \
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization \
  --gen-valid-profile tuple-optimization-all \
  --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-100-broader \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 200 --keep-going-after-command-failures
```

Result: `moon` reported no work, but the compare lane had `100` `starshine-command-failed` command failures because this workspace currently has the native command at `_build/native/release/build/cmd/cmd.exe`, not `target/native/release/build/cmd/cmd.exe`. This failed probe is infrastructure/path evidence only; it produced zero compared cases and is not semantic evidence.

Corrected lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization \
  --gen-valid-profile tuple-optimization-all \
  --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-100-broader-bin \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 200 --keep-going-after-command-failures
```

Harness summary:

- requested/compared: `100 / 100`
- normalized matches: `0`
- raw mismatches: `100`
- validation/generator/command/property failures: `0`
- Binaryen cache hits/misses: `100 / 0`
- selected profiles: spill `41`, tee `15`, copy-chain `44`
- profile labels: `tuple-optimization:spill` `41`, `tuple-optimization:tee` `15`, `tuple-optimization:copy-chain` `44`

## Broader Residual Classification

A per-case inspection script checked all 100 failure dirs for effect/trap facts, float payloads, and raw Starshine tuple/block carrier debris. It found no issues:

- every harness `inputEffectTrapFacts` field was false
- no sampled input used `f32` or `f64`
- no Starshine normalized WAT contained `tuple.*`, `(block (type`, or `(block (result` carrier spelling
- every sampled input had exactly two final `drop` consumers and no `call`, global/memory/table instruction, `if`, `loop`, branch, `return`, or `unreachable` spelling
- every sampled case remained the same simple type-indexed `i32, i64`, pure, drop-only generated surface classified in `1362`

Measured deltas were uniform by profile family:

| profile family | cases | Starshine raw wasm delta | Starshine normalized wasm delta | Starshine local decl delta | Starshine effective WAT op delta | Starshine `local.set` delta | Starshine `local.tee` delta | Starshine `local.get` delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| spill | 41 | `-3` each | `-11` each | `-2` each | `-5` each | `-3` each | `-1` each | `-2` each |
| tee | 15 | `-4` each | `-12` each | `-2` each | `-6` each | `-2` each | `-2` each | `-2` each |
| copy-chain | 44 | `-4` each | `-20` each | `-6` each | `-10` each | `-4` each | `-2` each | `-4` each |

Agent classification: this broader count-100 lane stays inside the narrow measured Starshine-win scalar spelling family from `1362`. It is not final closeout evidence and does not classify non-simple payloads, side-effecting/trapping payloads, non-drop lane uses, broader lane counts, non-`i32/i64` lane types, exact-slot neighborhood drift, or future Binaryen source changes.

## Candidate-Heavy Pass-Local Performance Probe

Generated synthetic candidate-heavy WAT fixtures under `.tmp/to-perf/` with `N` independent two-lane type-indexed block spills:

```wat
(module
  (type $pair (func (result i32 i64)))
  (func (export "run")
    ;; N pairs of i32/i64 locals
    block (type $pair) (result i32 i64)
      i32.const ...
      i64.const ...
    end
    local.set $j0
    local.set $i0
    local.get $i0
    drop
    local.get $j0
    drop
    ;; repeated N times
  )
)
```

Commands used `wasm-tools parse` followed by timing-only self-compare:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-<N>.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-<N>-20260629 \
  --timing-only --tuple-optimization
```

Results:

| candidate pairs | Starshine wall ms | Binaryen wall ms | Starshine pass ms | Binaryen pass ms | pass target met? |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 100 | `6.461` | `3.407` | `3.107` | `0.031` | no |
| 500 | `57.069` | `6.432` | `42.212` | `0.145` | no |
| 1000 | `192.114` | `10.043` | `152.870` | `0.287` | no |
| 2000 | `711.970` | `17.773` | `590.101` | `0.713` | no |

Interpretation: candidate-heavy TO currently misses the pass-local performance target by a wide margin on this synthetic surface. The scaling looks superlinear enough to warrant a focused performance slice before final TO closeout. This measurement is not whole-command `[WALL]001` evidence: it uses self-compare timing-only output and the explicit `--tuple-optimization` direct pass, and the reported pass-local bucket is the owner.

## Current Closeout Impact

This slice broadened the residual scalar spelling classification from the exact count-30 surface to the count-100 dedicated profile surface at the same seed. It did not close TO because:

- the dedicated profile remains raw-red by design until the residual spelling is normalized or accepted in final signoff language
- broader payload/type/lane-count/effect/non-drop surfaces are still unproven
- pass-local performance is now a concrete blocker on candidate-heavy fixtures
- general direct lanes, exact-slot/neighborhood evidence, and the required final 100k/10k matrix remain unrun in this slice

## Reopening / Next Work

Keep the `1362` reopening criteria, and add a performance-specific blocker: before final closeout, either optimize candidate-heavy TO enough to satisfy the project target or explicitly document and accept a narrower performance boundary with evidence. A useful next slice is to add fine-grained timing around TO group collection, query-summary construction, copy-linking, scalar-forward/drop-use recursion, mutation, and verification, then rerun the 100/500/1000 candidate-heavy fixtures to identify the dominant phase.
