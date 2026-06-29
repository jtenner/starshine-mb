# RemoveUnusedBrs dedicated validation unblocked

Date: 2026-06-29

## Scope

Continuation of `[O4Z-AUDIT-RUB-Q]` after note `1388`. The immediate blocker was the dedicated `remove-unused-brs-all` GenValid aggregate reporting `1000/1000` Starshine validation failures after `--remove-unused-brs` removed required value-producing suffix roots following a void structured block with a stack-form multi-value `return`.

This slice confirms that the validation blocker is now cleared in the current source and shifts the remaining dedicated-profile work from malformed output to output-shape mismatch classification/reduction.

## Important correction to prior evidence

The stale command path in note `1388` used `target/native/release/build/cmd/cmd.exe`. In this workspace, the current native release build is at `_build/native/release/build/cmd/cmd.exe`; `target/native/release/build/cmd/cmd.exe` was stale from 2026-06-25 and continued to reproduce the old invalid output. Replaying with `_build/native/release/build/cmd/cmd.exe` preserves the suffix and validates.

Reduced replay:

```sh
moon build --target native --release src/cmd
_build/native/release/build/cmd/cmd.exe \
  .tmp/rub-public-regression.wasm \
  --remove-unused-brs \
  --dump=.tmp/rub-current-after-revert.wat \
  -o .tmp/rub-current-after-revert.wasm
wasm-tools validate .tmp/rub-current-after-revert.wasm
grep -n "local.get" .tmp/rub-current-after-revert.wat
```

Result: wasm-tools validation passed, and the dump still contains the two trailing suffix roots:

```text
11:    local.get 0
12:    local.get 1
```

## Regression coverage

`src/passes/remove_unused_brs_test.mbt` now has a public binary-decode pipeline guard:

- `remove-unused-brs public pipeline keeps result suffix after void nonfallthrough block`

The test uses the reduced binary bytes for the suffix-loss shape, runs `run_hot_pipeline(..., ["remove-unused-brs"])` with default final validation enabled, and asserts the optimized function still contains `Local 0` and `Local 1` reads. This guards the command-path/lifted-binary shape rather than only the WAT helper path.

Focused command:

```sh
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
```

Result: `214/214` passed.

## Dedicated profile status after the validation fix

A current `remove-unused-brs-all` smoke no longer reports validation failures.

Command:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 50 \
  --seed 0x5eed \
  --pass remove-unused-brs \
  --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-loop-current-50-after-revert \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile remove-unused-brs-all \
  --normalize drop-consts \
  --normalize unreachable-control-debris \
  --normalize local-cleanup-debris \
  --max-failures 50
```

Result:

- compared: `50/50`
- validation failures: `0`
- generator/property/command failures: `0`
- normalized matches: `0`
- mismatches: `50`

A smaller runtime-checked lane provides semantic smoke evidence for the mismatch family:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 20 \
  --seed 0x5eed \
  --pass remove-unused-brs \
  --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-loop-current-20-runtime-after-revert \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile remove-unused-brs-all \
  --normalize drop-consts \
  --normalize unreachable-control-debris \
  --normalize local-cleanup-debris \
  --runtime-execution node \
  --max-failures 20
```

Result: `20/20` compared, `0` validation/generator/property/command failures, `20` shape mismatches, and runtime execution outcome `all-equal` (`16` equal results, `4` equal traps, `0` semantic mismatches).

## Mismatch classification evidence

The first current mismatch remains `case-000001-gen-valid` from the `remove-unused-brs-control` leaf. It is no longer a validation failure. The family is broad output-shape drift where both engines perform different mixtures of cleanup, local materialization, and structured-control rewriting.

Measured over `.tmp/pass-fuzz-remove-unused-brs-rub-loop-current-50-after-revert/failures`:

- Raw wasm size: Starshine is `<=` Binaryen in `20/50` cases; total raw delta is `+456` bytes.
- Normalized wasm size: Starshine is `<=` Binaryen in `50/50` cases; total normalized delta is `-5575` bytes.

Agent judgment: treat the current smoke mismatch family as a likely Starshine-size-win candidate, not as a correctness blocker, but do not close RUB-Q on this alone. The evidence is only a count-20 runtime smoke plus size measurements; the full dedicated `1000` and `10000` lanes still need either green normalized comparison, stronger semantic/runtime evidence, or a documented accepted-drift decision tied to specific diff families.

## Current status

The previous `1000/1000` Starshine validation blocker is superseded in current source. Remaining RUB-Q closeout work is now:

1. Rerun `remove-unused-brs-all` at `1000` with the current `_build/native/release/build/cmd/cmd.exe` (or refresh/copy the documented `target/...` binary path) and no stale binary.
2. Classify the current all-mismatch dedicated smoke: either reduce/fix missing Binaryen-shape families if they are parity gaps, or document accepted Starshine-win drift with size/runtime/semantic evidence.
3. Only after the `1000` lane has zero validation failures and a settled mismatch classification, run the `10000` dedicated lane for closeout.
