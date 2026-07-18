---
kind: comparison
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/PickLoadSigns.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/pick-load-signs_sign-ext.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./fuzzing.md
---

# `pick-load-signs` Binaryen parity

## Current verdict

`pick-load-signs` is **closed at Binaryen-v131-or-better behavior parity**.

Starshine covers every Binaryen-owned transform and bailout family found in the v131 source audit. It intentionally retains five broader evidence families, but now removes the redundant extension expression whenever every possible value source is a matching rewritten narrow load. Those retained differences are therefore measured direct-pass size wins rather than equal-size, size-losing, or unproven drift.

Cleanup is deliberately fail-closed:

- the local cannot be a parameter;
- every explicit write must be an exact matching candidate load;
- all candidate widths and final signedness must agree with the evidence;
- at least one load must actually change signedness;
- otherwise PLS changes only the eligible load opcode and preserves the extension expression.

## Binaryen v131 contract covered by Starshine

Starshine matches the upstream contract for:

- no-memory skip, including imported-memory admission;
- exact non-tee `local.set(load ...)` candidates;
- i32 direct signed extension for 8 and 16 bits;
- i32 signed equal-constant shift pairs;
- i32 right-hand low masks;
- all-use recognition and unknown-use rejection;
- no-use, mixed-width, load/use-width, and official `br_if` bailouts;
- same-local multiple candidates;
- `signedUses * 2 >= unsignedUses` weighting;
- `local.tee` and atomic-load exclusion.

No Binaryen-owned transform remains missing.

## Retained Starshine wins

| Starshine-only family | Final direct-pass behavior | Canonical size evidence |
| --- | --- | --- |
| commuted i32 low mask | flip to unsigned load and remove the redundant mask | load8 `48` vs Binaryen `52`; load16 `48` vs `53` |
| i32 unsigned shift pair | flip to unsigned load and remove `shl -> shr_u` | load8/load16 `48` vs `54` |
| i64 direct signed extension | flip to signed load and remove `extend{8,16,32}_s` | `48` vs `49` for all widths |
| i64 low mask | flip to unsigned load and remove the mask | load8 `48` vs `52`; load16 `48` vs `53`; load32 `48` vs `55` |
| i64 signed shift pair | flip to signed load and remove the shift pair | `48` vs `54` for 8/16/32 |
| i64 unsigned shift pair | flip to unsigned load and remove the shift pair | `48` vs `54` for 8/16/32 |

The 16-case negative-value runtime matrix matched Binaryen results for every retained width and family. Exact simple shapes also use the raw pass-manager rewrite path, avoiding HOT lift and use-def construction.

## Performance evidence

Native-release whole-command medians over 2,000-function exact-shape modules:

| Workload | Starshine | Binaryen v131 | Result |
| --- | ---: | ---: | --- |
| unsigned shift pairs | `7.36 ms` | `8.18 ms` | Starshine faster |
| commuted/i64 masks | `6.35 ms` | `6.94 ms` | Starshine faster |
| i64 direct/signed-shift evidence | `6.21 ms` | `7.15 ms` | Starshine faster |

These workloads exercise the raw exact-shape path added for the retained wins. More complex control/dataflow shapes continue through the HOT/use-def implementation.

## Final four-lane evidence

All lanes used `_build/native/release/build/cmd/cmd.exe` and the official Binaryen v131 executable.

| Lane | Requested / compared | Result |
| --- | --- | --- |
| regular GenValid, seed `0x5eed` | `100000 / 100000` | `100000` normalized; zero failures/mismatches |
| wasm-smith, seed `0x5eed` | `10000 / 9956` | `9955` normalized; one PLS-unrelated unreachable-control-debris mismatch; `44` Binaryen/tool failures |
| `pick-load-signs-all`, seed `0x5eed` | `10000 / 10000` | `6452` exact normalized; `3548` measured Starshine-win mismatches; zero failures |
| `random-all-profiles`, seed `0x5555` | `10000 / 10000` | `10000` normalized; zero failures/mismatches |

The dedicated mismatch count exactly equals its behavior-revealing selected leaves:

- `pick-load-signs-unsigned-mask`: `1762`;
- `pick-load-signs-unsigned-shift`: `1225`;
- `pick-load-signs-i64-watch`: `561`.

Every saved example from those leaves has the documented redundant-extension deletion and smaller canonical output. All other selected leaves matched Binaryen exactly.

The sole wasm-smith raw mismatch remains case `009332`, an extra `(drop (unreachable))` wrapper in a module with no PLS pattern. Replay with `--normalize unreachable-control-debris` produced one cleanup-normalized match and zero remaining mismatches. Agent classification: codec/HOT writeback debris, not PLS behavior.

## Ordered neighborhood

The actual `pick-load-signs -> precompute` neighborhood completed `10000/10000` dedicated-profile cases with `5300` exact normalized matches, `4700` smaller Starshine outputs, and zero validation/generator/property/command failures. Every mismatch was smaller:

- PLS-owned unsigned-mask, unsigned-shift, and i64-watch wins retained their `-20`, `-30`, and `-21` aggregate deltas;
- neighboring `precompute` additionally cleaned the tee boundary by `8` bytes and the mixed-width boundary by `3` bytes.

No equal-size, size-losing, validation, or semantic regression appeared in the scheduled neighborhood.

## Validation

- `moon info`: passed with existing warnings.
- `moon fmt`: passed.
- `moon test src/passes`: `5857/5857` passed.
- `moon test src/validate`: `1704/1704` passed.
- `moon test`: `9333/9333` passed.
- native release CLI build: passed with existing warnings.
- no Starshine validation, generator, property, or command failure occurred in the final matrix.

## Reopening criteria

Reopen parity if:

- Binaryen expands PLS beyond the v131 i32 helper contract;
- a retained cleanup can remove evidence when a parameter, non-load write, mismatched width, or mismatched final signedness reaches the read;
- any retained family ceases to be smaller after canonicalization;
- the exact-shape raw path becomes slower than the `2x` Binaryen target;
- runtime or fuzz evidence finds a true semantic mismatch.
