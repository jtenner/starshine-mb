# 0107 - Generated `-O4z` slot 33 `vacuum` replay retired by the validator escape fix and guarded writeback

## Status

- Date: 2026-04-18
- Type: One-off raw investigation
- Resolves: [0098 - slot 33 `vacuum` `Func 1818` stack underflow](./0098-2026-04-18-generated-o4z-vacuum-slot33-func1818-stack-underflow.md)
- Shared audit note: [0093 - Generated `cmd.wasm` ordered `-O4z` pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Saved audit root: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/`

## Scope

- Binaryen slot: `33`
- Observed Binaryen pass: `vacuum`
- Starshine pass: `--vacuum`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm`
- Saved compare directory after the fix: `.artifacts/o4z005-slot33-compare/`

## Binaryen oracle

- Official Binaryen source oracle: `src/passes/Vacuum.cpp` in the upstream `version_129` tag - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Vacuum.cpp>
- Current-trunk drift note already tracked on the living pass page: the 2026-02-27 Chromium mirror change stopped rewriting explicit `unreachable` to `nop`, reinforcing that `Vacuum` is still a cleanup pass and not a place to synthesize fresh typed carriers - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9ee4a25ee15ab53e796cb0b3f320cafa2622c407%5E%21/>
- Direct oracle replay on the saved predecessor stays valid:
  - `wasm-opt .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm --all-features --vacuum -o .artifacts/tmp-binaryen-vacuum-slot33.wasm`
  - `wasm-tools validate .artifacts/tmp-binaryen-vacuum-slot33.wasm`

## What changed since `0098`

The old symptom from `0098` no longer reproduced exactly on the current tree. The native replay stopped dying in final module validation and instead exited `0` while emitting invalid wasm that `wasm-tools` rejected.

- Old saved symptom from `0098`: Starshine exited nonzero with `final module validate: stack underflow` on `Func 1818`.
- Current pre-fix symptom on this tree:
  - `_build/native/release/build/cmd/cmd.exe --vacuum --out .artifacts/tmp-direct-vacuum-after-sl.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm`
  - `wasm-tools validate .artifacts/tmp-direct-vacuum-after-sl.wasm`
  - `wasm-tools` reported `func 4142 failed to validate` with `type mismatch: expected i64, found i32`.

So the active corruption was still real, but the exact failure boundary had moved from the in-repo final validator to post-encode external validation.

## Root cause findings

### 1. The invalidity was already present in Starshine's dumped optimized module

The native cmd dump of the optimized extracted replay showed the same invalid structure that `wasm-tools` later rejected from the encoded bytes.

- Repro:
  - `_build/native/release/build/cmd/cmd.exe --extract-functions=4142 --vacuum --dump /tmp/o4z005-dump.wat --out /tmp/o4z005-dump.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm`
- The dumped function already contained a typed outer `if (result i64)` whose then arm ended with an `if (result i32)` and no final `i64` producer before the outer `else`.
- That means this was not only an external encoding or `wasm-tools` parsing issue; Starshine's own optimized module shape was invalid.

### 2. The in-repo validator had a blind spot around terminal blocks with reachable `br_if` escapes

A much smaller invalid module reproduced the validator bug without the large artifact:

- `wasm-tools parse /tmp/o4z005-min.wat -o /tmp/o4z005-min.wasm`
- `wasm-tools validate /tmp/o4z005-min.wasm` failed with the expected typed-`if` result mismatch.
- Before the fix, `_build/native/release/build/cmd/cmd.exe --out /tmp/o4z005-min-copy.wasm /tmp/o4z005-min.wasm` exited `0`, proving Starshine's own decode/validate path accepted the same invalid shape.

The reduced shape was:

- outer `if (result i64)`
- then arm begins with a `block` whose body contains a `loop` with `br_if 1` and then `unreachable`
- after that block, the then arm leaves an `i32` on the stack instead of an `i64`

Durable inference: the validator normalization for block / if exits was treating the terminal `unreachable` path as decisive and missing the fact that a reachable `br_if` to the enclosing label still let control reach the merge. That allowed later stack junk or wrong-typed values to hide behind the terminal block.

### 3. `vacuum` needed a guarded writeback boundary once the validator became strong enough

Even after isolating the validator bug, the conservative fix for the pass boundary was still important: when `vacuum` produces a rewritten function that fails post-pass per-function validation against the module environment, Starshine should keep the original function body instead of writing an invalid cleanup result.

## Fix summary

Two changes landed together:

1. `src/validate/typecheck.mbt`
   - taught block / if validation to treat reachable conditional escapes to the enclosing label as merge-reaching when normalizing body exits
   - this closes the minimal typed-`if` blind spot and makes the in-repo validator reject the reduced invalid module
2. `src/passes/pass_manager.mbt`
   - extended the existing writeback-validation skip path to `vacuum`
   - once validation became strong enough to see the bad rewritten body, `vacuum` kept the original function instead of committing the invalid rewrite

The in-tree regression coverage is:

- `src/validate/validate.mbt`
  - `validate_module rejects typed if branch result mismatch hidden behind terminal block after br_if`
- `src/cmd/cmd_wbtest.mbt`
  - `run_cmd_with_adapter validates vacuum on generated O4z slot33 predecessor`
  - `run_cmd_with_adapter keeps extracted generated O4z slot33 vacuum func4142 output wasm-tools-valid`

## Post-fix evidence

### Direct replay

- `_build/native/release/build/cmd/cmd.exe --vacuum --out .artifacts/tmp-direct-vacuum-after-sl.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm`
- `wasm-tools validate .artifacts/tmp-direct-vacuum-after-sl.wasm`
- Result: exit `0`, external validation passes

### Extracted focused replay

- `_build/native/release/build/cmd/cmd.exe --extract-functions=4142 --vacuum --out .artifacts/tmp-slot33-extract4142-vacuum.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm`
- `wasm-tools validate .artifacts/tmp-slot33-extract4142-vacuum.wasm`
- Result: exit `0`, external validation passes

### Binaryen compare

- `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/o4z005-slot33-compare --vacuum`
- Result summary:
  - `Normalized WAT equal: yes`
  - `Canonical function compare equal: yes`
  - `Canonical wasm equal: no`

The byte-level drift remains acceptable here because the corruption blocker was about invalid output. The stronger signoff is that the replay now stays valid and canonically matches Binaryen at normalized-WAT and per-function granularity.

## Durable takeaway

`[O4Z]005` was not best explained as a surviving `vacuum`-local semantic rule mismatch with Binaryen. The saved slot-33 witness exposed a validator blind spot plus a missing guarded writeback boundary:

- the invalid typed-`if` result mismatch was already present in Starshine's optimized module dump
- the in-repo validator incorrectly accepted that family until the conditional-escape normalization fix
- once validation was fixed, a conservative `vacuum` writeback guard was enough to retire the slot-33 corruption while preserving Binaryen-equal normalized output on the saved predecessor

## Follow-up boundary

- This retires the only remaining active `vacuum` corruption slot from the generated ordered `-O4z` audit.
- The later `Func 1818` family is still alive one slot later under `optimize-instructions` slot `44`, but slot `33` is no longer a live `vacuum` blocker.
