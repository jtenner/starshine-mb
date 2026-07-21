---
kind: workflow
status: supported
last_reviewed: 2026-07-21
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/OnceReduction.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/passes/once_reduction_test.mbt
---

# `once-reduction` Fuzzing Profile

Use a freshly built native CLI and the explicit official Binaryen v131 oracle. The PATH `wasm-opt` may be TinyGo's stale Binaryen v116.

## Pass-owned profile

The stable dedicated profile is `once-reduction-tail-calls` (aliases: `once-reduction`, `once-reduction-closeout`, and `once-reduction-all`). Every generated module contains all of these pass-owned trigger families:

- a direct `return_call` wrapper whose caller should inherit the target's once fact;
- a flat once body whose sole payload is a direct tail call;
- an indirect tail call followed by unreachable once-global reads;
- a reference tail call followed by an unreachable noncanonical once-global write; and
- repeated direct calls proving that dead post-tail accesses did not poison candidate discovery.

The profile intentionally keeps indirect/reference targets conservative. Both use a separate inert helper, and a declarative function-index element makes `ref.func` valid without populating the indirect-call table or exposing the once function. The profile exercises terminal scanning and cleanup, not speculative indirect-call resolution. `src/validate/gen_valid_tests.mbt` locks profile resolution, tail-call feature admission, helper isolation, oracle-compatible element encoding, validation, and emitted instruction shapes.

Dedicated signoff command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass once-reduction --gen-valid-profile once-reduction-tail-calls --out-dir .tmp/pass-fuzz-once-reduction-tail-calls-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131/bin/wasm-opt --max-failures 10001 --keep-going-after-command-failures --no-reduce-mismatches
```

## Required direct matrix

Run and report these lanes separately:

1. regular GenValid: `100000` cases, seed `0x5eed`;
2. explicit wasm-smith: `10000` cases, seed `0x5eed`;
3. dedicated `once-reduction-tail-calls`: `10000` cases, seed `0x5eed`; and
4. `random-all-profiles`: `10000` cases, seed `0x5555`.

All commands must pass explicit `--jobs auto`, `_build/native/release/build/cmd/cmd.exe`, and the verified v131 `--wasm-opt-bin` path. Preserve the default persistent cache and report `result.json.cache` counters.

## 2026-07-21 Binaryen-v131 matrix

The final matrix used native SHA-256 `176fa6aea033ab955838a5c6263201c545332ab73ee2e01f481355dbc9d67938` and official Binaryen v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`:

- regular GenValid: requested/compared `100000/100000`, normalized `100000`, zero mismatches or failures; Binaryen cache `100000/0` hits/misses;
- explicit wasm-smith: requested `10000`, compared/normalized `9956/9956`, zero mismatches or Starshine failures; the 44 command failures are Binaryen/tool failures (`39` zero-sized recursion groups, `3` bad section sizes, `1` invalid tag index, and `1` table index out of range); wasm-smith cache `10000/0`, Binaryen cache `9956/0`, failure cache `44/0`;
- dedicated `once-reduction-tail-calls`: requested/compared `10000/10000`, `10000` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `10000/0`; and
- `random-all-profiles`: requested/compared/normalized `10000/10000/10000`, zero mismatches or failures; Binaryen cache `10000/0`.

The dedicated profile is one deterministic pass-owned raw-byte module repeated under the batch contract. All `10000` residuals are the same inspected **Starshine win**, not independent unknown families: raw unreachable reads/writes after indirect/reference tail calls poison Binaryen v131's once discovery, while Starshine recognizes terminal control, removes that debris, and then removes the redundant once guards/calls. The representative canonical output is `125` bytes for Starshine versus `144` for Binaryen, with both outputs valid. Source fixtures assembled through Binaryen can hide this family because `wasm-as` removes unreachable post-tail bytes before `once-reduction`; the raw GenValid encoding deliberately preserves them.

## Deterministic repair fixtures

`src/passes/once_reduction_test.mbt` is the focused source-contract matrix for direct-tail summary propagation, flat and block-wrapped tail payload cleanup, indirect/reference terminal tails, cycle preservation, branch/EH conservatism, and candidate-global legality. The 2026-07-21 tail-call regressions were red before implementation and pass after the repair.
