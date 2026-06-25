---
kind: research-note
status: supported
created: 2026-06-24
pass: code-pushing
slice: O4Z-AUDIT-CP-S
sources:
  - ../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp
  - ../../../binaryen/passes/code-pushing/index.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
---

# Code-pushing branch-value `br_if` slice

## Scope

`[O4Z-AUDIT-CP-S]` widens Starshine's conditional-branch segment movement by one source-backed family: a single pure SFA `local.set` may move after a `br_if` to a value-producing block label when the branch payload and condition do not read or write the moved local, and all reads of the moved local are in the same block suffix after the branch.

This is deliberately narrower than general branch-value or `br_on_*` movement. Ordered multi-set movement continues to use the previous no-branch-value `br_if` helper, so this slice does not implicitly widen multi-set branch-value cases.

## Binaryen v130 probe evidence

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Positive probe:

```wat
(module
  (func (param $cond i32) (result i32)
    (local $tmp i32)
    (block $exit (result i32)
      i32.const 7
      local.set $tmp
      i32.const 42
      local.get $cond
      br_if $exit
      local.get $tmp
      return)))
```

`wasm-opt --all-features --code-pushing -S` moves the `local.set $tmp` after the value-carrying `br_if`, while the branch payload remains before the branch.

Boundary probe:

```wat
(module
  (func (param $cond i32) (result i32)
    (local $tmp i32)
    (block $exit (result i32)
      i32.const 7
      local.set $tmp
      local.get $tmp
      local.get $cond
      br_if $exit
      local.get $tmp)))
```

Binaryen keeps the set before the `br_if` because the branch payload reads the moved local.

## Starshine implementation

Changes:

- split the previous no-branch-value `br_if` support predicate into:
  - direct no-branch-value support for ordered multi-set movement; and
  - single-set support that also admits one branch payload to a block label;
- accepted `candidate:dropped-conditional-branch` for single-set segment movement because Starshine's WAT/HOT surface may represent value-carrying `br_if` under a dropped wrapper;
- retained the existing local-use and suffix-read proof so branch payloads or conditions that read the moved local remain stationary;
- added a targeted `code-pushing-br-if-value` GenValid profile, but kept it out of the ordinary `code-pushing-all` aggregate because the generated value-`br_if` surface exposes a HOT-lowering representation gap (Starshine materializes the false-path `br_if` value through a temporary local while Binaryen leaves `drop (br_if ...)` directly).

## Tests and validation

Red-first focused pass tests were added before implementation:

- `code-pushing moves pure SFA set after dropped br_if with branch value` failed before the helper split because Starshine left the set before the branch.
- `code-pushing keeps pure SFA set before dropped br_if branch value that reads it` protects the source-local boundary.

Focused validation run:

```sh
moon test src/passes/code_pushing_test.mbt --target native -f '*dropped br_if*'
# Total tests: 2, passed: 2, failed: 0.
```

Generator validation after adding the targeted profile leaf:

```sh
moon test src/validate/gen_valid_tests.mbt --target native -f '*code-pushing*'
# Total tests: 3, passed: 3, failed: 0.
```

Targeted compare caveat:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-if-value-profile-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

This accidental aggregate run while `code-pushing-br-if-value` was included compared `650/1000` before the mismatch cap: `229` normalized matches, `370` cleanup-normalized matches, `51` raw mismatches, `0` validation/generator/property/command failures. All inspected mismatches came from selected `code-pushing-br-if-value` cases and show Starshine lowering the value-carrying `br_if` false-path result through a temporary local while Binaryen emits direct `drop (br_if ...)`. Agent classification: representation/size-losing lowering gap outside the code-pushing movement proof. The leaf is therefore targeted-only until lowering or compare normalization handles that shape.

After removing `code-pushing-br-if-value` from `code-pushing-all`, the ordinary aggregate lane is green again:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-post-br-if-value-aggregate-1000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures
```

Result: compared `1000/1000`, normalized matches `375`, cleanup-normalized matches `625`, raw mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, selected subprofiles `code-pushing-multi-set-local-copy: 75`, `code-pushing-multi-set: 77`, `code-pushing-multi-set-local-get-window: 89`, `code-pushing-multi-set-global-get-window: 67`, `code-pushing-multi-set-br-if: 69`, `code-pushing-if-arm: 90`, `code-pushing-br-if: 83`, `code-pushing-dropped-if: 83`, `code-pushing-multi-set-dropped-if: 64`, `code-pushing-multi-set-nop-window: 72`, `code-pushing-multi-set-drop-window: 73`, `code-pushing-after-if: 82`, `code-pushing-loop-br-if: 76`, cache `Binaryen 1000 hits/0 misses`.

Full focused code-pushing file:

```sh
moon test src/passes/code_pushing_test.mbt --target native
# Total tests: 58, passed: 58, failed: 0.
```

Broader pass package test remains blocked by the pre-existing missing debug-WASI artifact:

```sh
moon test src/passes --target native
# failed in pass_manager_wbtest.mbt: expected artifact read success, got read_file_bytes failed for tests/node/dist/starshine-debug-wasi.wasm: IOError(No such file or directory)
```

This is the known local artifact blocker, not a code-pushing regression.

## Remaining boundaries

Still open:

- ordered multi-set branch-value `br_if` movement;
- loop-label branch payloads;
- `br_on_*` and other conditional branch forms;
- switch/`br_table` positives beyond the protected simple no-branch-value boundary;
- general Binaryen `Effects::orderedBefore`, broader GC/EH/trap-option behavior, and final closeout matrix.
