---
kind: research-note
status: working
created: 2026-06-20
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ./0809-2026-06-20-code-pushing-if-segment-movement.md
  - ./0806-2026-06-20-code-pushing-unreachable-arm-post-use.md
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../docs/wiki/binaryen/passes/code-pushing/fuzzing.md
---

# Code-pushing dedicated GenValid profile

## Slice

This slice adds a dedicated `code-pushing-all` GenValid profile for `[O4Z-AUDIT-CP]`. It does not claim final pass closeout.

The profile is a deterministic composite over two currently implemented source-backed Starshine/Binaryen families:

- `code-pushing-if-arm`: a pure `local.set` before a void `if` whose then arm is the only in-`if` user;
- `code-pushing-after-if`: a pure computed `local.set` before an ordinary void `if` that does not read the local, followed by a same-region suffix `local.get`.

Both leaves are small one-function modules with no imports, memories, globals, tables, tags, atomics, GC refs, calls, or trapping arithmetic. The profile is intended to exercise the current positive movement slices, not the remaining switch/br_table, dropped-wrapper, conditional-branch, multi-set, atomics, GC, EH, or trap-policy gaps.

## Implementation

Changed files:

- `src/validate/gen_valid.mbt`
  - Added `CodePushingIfArmProfile`, `CodePushingAfterIfProfile`, and composite `CodePushingAllProfile`.
  - Added stable names `code-pushing-if-arm`, `code-pushing-after-if`, and `code-pushing-all`.
  - Added aliases `code-pushing`, `code-pushing-closeout`, and `code-pushing-all-profiles` to the composite.
  - Added deterministic module builders for the two profile leaves.
- `src/validate/gen_valid_tests.mbt`
  - Added profile resolution / aggregate sampling tests.
  - Added generated-module tests that validate the modules and detect the pass-owned `if` movement candidates.

## Native binary path note

The documented `target/native/release/build/cmd/cmd.exe` path remains absent in this checkout after `moon build --target native --release src/cmd`. The working native build output is:

```text
_build/native/release/build/cmd/cmd.exe
```

The dedicated profile compare lane below used this explicit native binary path with `--jobs auto`.

## Validation

Focused generator tests:

```sh
moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing gen-valid*'
```

Result: `2/2` passed.

```sh
moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing aggregate*'
```

Result: `1/1` passed.

Native build:

```sh
moon build --target native --release src/cmd
```

Result: completed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`; produced `_build/native/release/build/cmd/cmd.exe`.

Dedicated profile raw compare probe:

```sh
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --out-dir .tmp/pass-fuzz-code-pushing-profile-200 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `65/200` before `--max-failures` stopped the run; `65` raw mismatches, `0` validation/generator/property/command failures. The inspected mismatch family is Starshine-local cleanup drift: Starshine removes standalone/empty `nop` debris that Binaryen leaves around the moved set/empty else arm. This is not classified as final pass parity evidence without the normalizer.

Dedicated profile normalized compare probe:

```sh
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-profile-200-local-cleanup --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `200/200`; normalized matches `0`; cleanup-normalized matches `200`; raw mismatches `0`; validation failures `0`; generator failures `0`; property failures `0`; command failures `0`; selected subprofiles `code-pushing-if-arm: 100`, `code-pushing-after-if: 100`; cache `wasm-smith 0 hits/0 misses`, `Binaryen 200 hits/0 misses`, `Binaryen failures 0 hits/0 misses`.

## Boundary and reopening criteria

This slice only provides a dedicated profile for the implemented positive families. `[O4Z-AUDIT-CP]` remains active. Reopen or extend the profile when any of these land:

- dropped-wrapper mutation;
- conditional branch mutation;
- switch/br_table mutation;
- ordered multi-set movement;
- wider `orderedBefore` effect modeling;
- atomics, GC, EH, or trap-option behavior;
- public preset placement or final closeout matrix.

The `local-cleanup-debris` normalizer is required for the current dedicated-profile lane because Starshine intentionally erases standalone `nop` debris in these tiny generated shapes while Binaryen leaves it. Treat this as bounded cleanup-normalized evidence, not final raw-output parity.
