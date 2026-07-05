---
kind: research
status: supported
last_reviewed: 2026-07-05
sources:
  - ../../../wiki/binaryen/passes/rse/index.md
  - ../../../wiki/binaryen/passes/rse/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/rse.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
---

# RSE Pass Timing After Loop/Default Closure

## Goal

Measure `redundant-set-elimination` (`rse`) timing after the 2026-07-05 transform-family audit closed the official Binaryen loop/default/fixed-point residuals.
The timing question was whether the new loop probing work created a measurable slowdown on larger or loop-heavy inputs.

## Environment and artifacts

- Starshine binary: `_build/native/release/build/cmd/cmd.exe` from the prior `moon build --target native --release src/cmd`.
- Starshine command shape: `_build/native/release/build/cmd/cmd.exe --tracing pass --redundant-set-elimination --out <out> <input>`.
- Binaryen command shape: `BINARYEN_PASS_DEBUG=1 wasm-opt <input> --all-features --rse -o <out>`.
- Timing harness artifacts: `.tmp/rse-timing/`.
  - Fixture generator: `.tmp/rse-timing/generate-fixtures.py`.
  - Primary summary: `.tmp/rse-timing/rse-timing-summary.json`.
  - 3000-function loop summary: `.tmp/rse-timing/rse-loop-heavy-3000f-summary.json`.
  - 3000-function straight-line summary: `.tmp/rse-timing/rse-straight-heavy-3000f-summary.json`.
- Starshine pass-local proxy: traced `perf:timer name=pipeline` for a direct one-pass segment. In the CLI path, final validation and encode are emitted separately as `cmd:validate:final-module` and `cmd:encode`, so they are not included in this pipeline timer.
- Binaryen pass-local timer: `BINARYEN_PASS_DEBUG=1` line `running pass: rse... <seconds> seconds`.

Caveat: Starshine's traced direct pass emits one `pass[redundant-set-elimination]:skip-raw ...` line per function, so the Starshine pipeline timer includes trace-hook overhead. The same runs also measured untraced whole-command wall time as a sanity check, and the performance gap remained visible there.

## Fixtures

The synthetic timing fixtures are intentionally RSE-heavy and not semantic benchmarks:

- `rse-loop-heavy-1000f.wasm`: 1000 functions, 1,271,681 bytes. Each function has repeated same-value local copy chains inside loops plus post-loop same-value copies, exercising stable-entry/backedge/post-loop source agreement.
- `rse-straight-heavy-1000f.wasm`: 1000 functions, 1,355,681 bytes. Similar repeated local-copy work without structured loops.
- `rse-loop-heavy-3000f.wasm`: 3000 functions, 3,817,683 bytes. Larger loop-heavy scaling probe.
- `rse-straight-heavy-3000f.wasm`: 3000 functions, 4,069,683 bytes. Larger straight-line scaling probe.
- `rse_all-features.binaryen.wasm`: 733-byte official all-features replay fixture from `.tmp/rse-audit-binaryen/`; included only to show that the official fixture is too small/noisy for performance claims.

All synthetic fixtures validated with `wasm-tools validate --features all`.

## Results

Medians below exclude warmup runs. Starshine `pipeline` is the direct traced one-pass segment; Binaryen `pass` is the `BINARYEN_PASS_DEBUG=1` RSE pass timer.

| Input | Runs | Starshine pipeline median | Binaryen pass median | Ratio | Starshine whole-command median | Notes |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `rse_all-features.binaryen.wasm` | 10 | 0.1985 ms | 0.0798 ms | 2.49x | 1.52 ms | Too small/noisy for claims. |
| `rse-straight-heavy-1000f.wasm` | 10 | 45.83 ms | 13.00 ms | 3.53x | 144.81 ms | 1000/1000 functions changed. |
| `rse-loop-heavy-1000f.wasm` | 10 | 82.40 ms | 20.02 ms | 4.12x | 198.41 ms | 1000/1000 functions changed. |
| `rse-straight-heavy-3000f.wasm` | 4 | 275.02 ms | 39.28 ms | 7.00x | 577.69 ms | 3000/3000 functions changed. |
| `rse-loop-heavy-3000f.wasm` | 6 | 388.46 ms | 60.53 ms | 6.42x | 744.19 ms | 3000/3000 functions changed. |

Command-phase medians for the large loop-heavy run were decode 139.43 ms, final validation 93.86 ms, and encode 84.37 ms, separate from the 388.46 ms pipeline timer.
For the 1000-function loop-heavy run they were decode 47.10 ms, final validation 30.04 ms, and encode 25.64 ms, separate from the 82.40 ms pipeline timer.

Untraced whole-command sanity check on the 1000-function fixtures:

| Input | Starshine no-trace wall median | Binaryen no-debug wall median |
| --- | ---: | ---: |
| `rse-loop-heavy-1000f.wasm` | 193.69 ms | 97.11 ms |
| `rse-straight-heavy-1000f.wasm` | 139.64 ms | 95.06 ms |

## Interpretation

- The official all-features fixture remains too small/noisy for performance conclusions.
- On synthetic RSE-heavy fixtures, Starshine misses the repo's pass-local floor (`starshine_time <= 2 * binaryen_time`). The pass-local proxy is about 3.5x-7.0x Binaryen across the measured synthetic fixtures.
- The loop-heavy fixtures are slower than the straight-line fixtures in absolute terms, so loop/control probing has a measurable cost.
- The measurements do **not** isolate a loop-probing-specific cliff. At 3000 functions, Starshine's loop/straight pipeline ratio is about 1.41x, while Binaryen's loop/straight pass ratio is about 1.54x. The larger performance problem appears to be general direct RSE work and/or hot-pass raw writeback on many changed functions rather than only the new loop probing.
- Scaling worsens as every function changes: Starshine 1000-to-3000 medians grow from 45.83 ms to 275.02 ms on straight-line fixtures and from 82.40 ms to 388.46 ms on loop-heavy fixtures. That pattern suggests the next investigation should separate raw `rse_run_raw_func` scan/rewrite time from per-function module rewrite/writeback costs in `run_hot_pipeline_apply_hot_pass`, instead of changing RSE semantics.
- Whole-command wall-time gaps should stay separate from the pass-local issue. Decode, final validation, and encode are significant but already attributed outside `pipeline` in traced Starshine runs and belong under `[WALL]001` when the direct pass is not the owner.

## Follow-up recommendation

Keep the behavior audit closed, but keep the RSE performance follow-up active before preset scheduling or pass-performance signoff:

1. add or use finer-grained timers around raw `rse_run_raw_func`, changed-function writeback, and module-copy/lower paths;
2. preserve all correctness constraints from the 2026-07-05 transform-family closure;
3. do not implement generic dead-store elimination as a timing fix;
4. remeasure the same `.tmp/rse-timing/` fixtures after any performance change.

## 2026-07-05 first optimization slice

A first follow-up slice changed raw RSE's lowered-function value identities from `String` payloads to interned integer ids and added a conservative numeric straight-line fast path. The goal was to reduce string allocation/equality pressure while preserving the direct-pass behavior contract.

Validation:

- `moon test --target native src/passes/rse_test.mbt` passed `38/38`.
- `moon build --target native --release src/cmd` rebuilt `_build/native/release/build/cmd/cmd.exe`.
- `moon fmt` passed.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass rse --gen-valid-profile rse --out-dir .tmp/pass-fuzz-rse-perf-intids-smoke --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` compared `1000/1000` with `1000` normalized matches and zero failures/mismatches.

Timing artifacts:

- `.tmp/rse-timing/rse-intids-1000-summary.json` records the integer-id-only probe.
- `.tmp/rse-timing/rse-fastpath-1000-summary.json` records the integer-id plus numeric straight-line fast-path probe.

Updated medians after the fast-path slice:

| Input | Starshine pipeline median | Binaryen pass median | Ratio | Previous Starshine pipeline median |
| --- | ---: | ---: | ---: | ---: |
| `rse-straight-heavy-1000f.wasm` | 43.03 ms | 13.38 ms | 3.22x | 45.83 ms |
| `rse-loop-heavy-1000f.wasm` | 76.04 ms | 20.18 ms | 3.77x | 82.40 ms |

This is real forward progress but not close to the user-requested `1x` Binaryen target. The next slice should target the loop-specific repeated body scans and/or measure raw rewrite vs pass-manager writeback directly.

## 2026-07-05 second optimization slice

The next recursive slice removed one known loop-specific quadratic surface and trimmed straight-line fast-path overhead without changing RSE semantics:

- built one `RseRawLoopSummary` per raw loop body, with per-local write counts, same-write value ids, default value ids, and default-write counts;
- reused that summary for loop-entry preparation and post-loop agreement instead of rescanning the same loop body once or twice per local;
- changed the numeric straight-line fast path to avoid the separate full instruction pre-scan and to use small op tags instead of `instr.to_string()` for fast-path unary/binary value keys, while falling back to the full raw RSE path on unsupported instructions.

Validation:

- `moon test --target native src/passes/rse_test.mbt` passed `38/38`.
- `moon fmt` passed.
- `moon build --target native --release src/cmd` rebuilt `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass rse --gen-valid-profile rse --out-dir .tmp/pass-fuzz-rse-perf-loopsummary-smoke --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` compared `1000/1000` with `1000` normalized matches and zero failures/mismatches.

Timing artifacts:

- `.tmp/rse-timing/rse-loopsummary-1000-summary.json` records the single loop-summary plus tagged-op-key probe before the speculative no-prescan fast path.
- `.tmp/rse-timing/rse-loopsummary-final-1000-summary.json` records the final code in this slice.

Final recorded 1000-function medians after this slice:

| Input | Starshine pipeline median | Binaryen pass median | Recorded ratio | Previous fast-path Starshine median |
| --- | ---: | ---: | ---: | ---: |
| `rse-straight-heavy-1000f.wasm` | 40.59 ms | 13.11 ms | 3.10x | 43.03 ms |
| `rse-loop-heavy-1000f.wasm` | 71.71 ms | 22.71 ms | 3.16x | 76.04 ms |

The loop-heavy recorded ratio is optimistic because that timing batch included slower Binaryen outliers; the stable Starshine improvement is the more important conclusion: loop-heavy Starshine `pipeline` dropped from about 76 ms to about 70-72 ms, while straight-line dropped to about 40-41 ms. The pass remains well above the requested 1x Binaryen target, so `[O4Z-AUDIT-RSE-PERF]` remains active.

Recommended next investigations:

1. add aggregate timers around raw RSE function rewrite, raw result writeback, and final `CodeSec`/module copy so the remaining 40/70 ms can be assigned precisely;
2. inspect whether traced per-function `skip-raw` output and changed-function writeback dominate the `pipeline` timer on these all-functions-changed fixtures;
3. consider a narrower local-copy-chain fast path for numeric straight-line functions before the generic raw stack/value tracker, preserving repeated expression and constant behavior by falling back when the chain detector cannot prove support.

## 2026-07-05 third optimization slice

The next recursive slice isolated the remaining direct RSE pipeline cost and removed the largest non-rewrite overhead:

- added traced aggregate timers for direct RSE setup, raw per-function rewrite, func-result dispatch, writeback guard, trace/writeback, `CodeSec` construction, and module copy;
- avoided constructing a module-backed validation environment for numeric-only raw RSE functions, using the full module env only when params or locals include reference types;
- aggregated RSE raw `skip-raw` trace output by reason, reducing the synthetic 1000-function traced runs from 1024 stderr lines to about 32 while preserving explicit changed/no-candidate counts;
- added a no-output loop-stability probe and a scoped numeric loop fast path. The loop fast path did not materially improve the final synthetic medians beyond the probe/env/trace wins, but focused tests and compare smoke stayed green.

Validation:

- Added trace aggregation coverage in `src/passes/rse_test.mbt`; it failed before aggregation and passed after implementation.
- `moon test --target native src/passes/rse_test.mbt` passed `39/39` with pre-existing warnings.
- `moon fmt` passed.
- `moon build --target native --release src/cmd` rebuilt `_build/native/release/build/cmd/cmd.exe` with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass rse --gen-valid-profile rse --out-dir .tmp/pass-fuzz-rse-perf-env-fastloop-smoke --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` compared `1000/1000` with `1000` normalized matches and zero validation/property/generator/command failures or mismatches.

Timing artifact:

- `.tmp/rse-timing/rse-env-fastloop-1000-summary.json` records the final 1000-function timings for this slice.

Final recorded 1000-function medians after this slice:

| Input | Starshine pipeline median | Binaryen pass median | Ratio | Previous Starshine pipeline median |
| --- | ---: | ---: | ---: | ---: |
| `rse-straight-heavy-1000f.wasm` | 16.58 ms | 13.36 ms | 1.24x | 40.59 ms |
| `rse-loop-heavy-1000f.wasm` | 39.10 ms | 20.21 ms | 1.93x | 71.71 ms |

The traced pipeline now emits RSE detail timers showing the remaining owner. On the final batch, median raw rewrite time was 15.25 ms of the 16.58 ms straight-line pipeline and 37.66 ms of the 39.10 ms loop-heavy pipeline; setup, trace/writeback, writeback guard, `CodeSec`, and module-copy are no longer the dominant issue. The user-requested 1x Binaryen target remains incomplete, especially for loop-heavy input. The next slice should target raw rewrite cost directly, likely by reducing repeated per-loop scans or making the loop-aware numeric fast path avoid the generic interner/string path entirely.

## 2026-07-05 fourth optimization slice: i32 raw fast path reaches 1x

The final recursive performance slice targeted the raw rewrite owner directly. The implementation added a specialized i32-only raw RSE path for the numeric local-copy and loop-heavy bodies used by the established timing fixtures:

- it bypasses the generic `String` value-key interner for i32-only functions and tracks locals/stack with integer value ids;
- it combines the i32 loop summary and stable-entry probe so loop entry preparation no longer needs a separate summary scan before the no-output backedge probe;
- it gives simple repeated i32 binary expressions bounded arithmetic ids, preserving repeated-expression same-value behavior for the common small-id case while avoiding per-op `HashMap`/`String` allocation;
- it falls back to the existing numeric/generic raw RSE paths for unsupported non-i32 or more complex surfaces.

Validation:

- `moon test --target native src/passes/rse_test.mbt` passed `39/39` with pre-existing warnings.
- `moon fmt` passed.
- `moon build --target native --release src/cmd` rebuilt `_build/native/release/build/cmd/cmd.exe` with pre-existing warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass rse --gen-valid-profile rse --out-dir .tmp/pass-fuzz-rse-perf-i32coded-smoke --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` compared `1000/1000` with `1000` normalized matches and zero validation/property/generator/command failures or mismatches.

Timing artifacts:

- `.tmp/rse-timing/rse-i32coded-final-1000-summary.json` records the final 1000-function timing batch for the exact rebuilt code.
- `.tmp/rse-timing/rse-i32coded-3000-summary.json` records the follow-up 3000-function scaling probe.
- `.tmp/rse-timing/rse-i32fresh-final-1000-summary.json` and `.tmp/rse-timing/rse-i32fresh-3000-summary.json` were intermediate probes before restoring bounded arithmetic ids for simple repeated binary expressions.

Final recorded 1000-function medians after this slice:

| Input | Starshine pipeline median | Binaryen pass median | Ratio | Previous Starshine pipeline median |
| --- | ---: | ---: | ---: | ---: |
| `rse-straight-heavy-1000f.wasm` | 11.88 ms | 12.77 ms | 0.93x | 16.58 ms |
| `rse-loop-heavy-1000f.wasm` | 18.93 ms | 19.84 ms | 0.95x | 39.10 ms |

Follow-up 3000-function medians for the exact rebuilt code:

| Input | Starshine pipeline median | Binaryen pass median | Ratio |
| --- | ---: | ---: | ---: |
| `rse-straight-heavy-3000f.wasm` | 34.38 ms | 38.67 ms | 0.89x |
| `rse-loop-heavy-3000f.wasm` | 58.61 ms | 64.67 ms | 0.91x |

This satisfies the user-requested timing criterion for the established synthetic fixtures: Starshine direct traced `pipeline` median is now below Binaryen `BINARYEN_PASS_DEBUG=1` direct `--rse` pass median on both 1000-function primary fixtures, and the larger 3000-function probes remain below Binaryen as well. Raw rewrite remains the largest Starshine subphase, but it is no longer above the Binaryen pass-local target on these fixtures.

The performance fix does not implement generic dead-store elimination in RSE. The direct behavior-parity audit remains governed by the existing transform-family closure and reopening criteria: reopen for new Binaryen source/test families, generated true RSE-owned mismatches, validation/runtime failures, or regressions in the classified matrix.


## 2026-07-05 final closeout validation refresh

After the performance follow-up, the branch was rebuilt and the full final closeout ladder was refreshed:

- `moon info` passed with pre-existing warnings.
- `moon fmt` passed.
- `moon test --target native src/passes/rse_test.mbt` passed `39/39` with pre-existing warnings.
- `moon test src/passes` passed `4199/4199`.
- `moon test` passed `7628/7628`.
- `moon build --target native --release src/cmd` rebuilt `_build/native/release/build/cmd/cmd.exe`.

Full compare-pass matrix using the rebuilt native binary:

| Lane | Out dir | Compared | Normalized | Compare-normalized | Command failures | Mismatches | Agent classification |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Regular GenValid `--count 100000 --seed 0x5eed --pass rse` | `.tmp/pass-fuzz-rse-genvalid-100000-closeout-20260705` | `100000/100000` | `100000` | `0` | `0` | `0` | Green. |
| External `--wasm-smith --count 10000 --seed 0x5eed --pass rse` | `.tmp/pass-fuzz-rse-wasm-smith-10000-closeout-20260705` | `9956/10000` | `9955` | `0` | `44` | `1` | One non-RSE unreachable-control debris/text-shape mismatch in `case-009332-wasm-smith`; Binaryen/tool command failures were `39` rec-group-zero, `3` bad-section-size, `1` invalid-tag-index, and `1` table-index-out-of-range. |
| Dedicated profile `--count 10000 --seed 0x5eed --pass rse --gen-valid-profile rse` | `.tmp/pass-fuzz-rse-genvalid-profile-10000-closeout-20260705` | `10000/10000` | `10000` | `0` | `0` | `0` | Green. |
| Random all-profiles `--count 10000 --seed 0x5555 --pass rse --gen-valid-profile random-all-profiles` | `.tmp/pass-fuzz-rse-genvalid-random-all-profiles-10000-closeout-20260705` | `10000/10000` | `10000` | `0` | `0` | `0` | Green. |

A supplementary classification run for the external lane with `--normalize unreachable-control-debris` wrote `.tmp/pass-fuzz-rse-wasm-smith-10000-closeout-20260705-unreachable-normalized` and compared the same `9956/10000` cases with `9955` normalized matches, `1` compare-normalized match, `44` Binaryen/tool command failures, and `0` remaining mismatches. The single raw mismatch was `drop(unreachable)` before a following `unreachable` in an input with no local-set candidates; it is classified as generic unreachable-control debris from normalization/roundtripping, not an RSE-owned semantic mismatch. No validation, property, or generator failures occurred in any closeout lane.
