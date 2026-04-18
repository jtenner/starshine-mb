# 0093 - Generated `cmd.wasm` ordered `-O4z` pass audit

## Status

- Date: 2026-04-18
- Type: One-off raw investigation
- Scope: Ordered self-opt compare on the generated `_build/wasm/debug/build/cmd/cmd.wasm` artifact, using Binaryen `-O4 --shrink-level 4 --all-features --debug` to observe the real top-level pass path and replay only the slots Starshine actually implements.

## Saved artifacts

- Audit root: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/`
- Human summary: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- Machine summary: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- Observed Binaryen debug log: `.artifacts/o4z-wasm-opt-debug.log`

## Baseline regeneration

1. Build the generated wasm artifact and the native optimizer binary:
   - `moon build --target wasm`
   - `moon build --target native --release --package jtenner/starshine/cmd`
2. Confirm the generated artifact is a valid input baseline:
   - `wasm-tools validate _build/wasm/debug/build/cmd/cmd.wasm`
3. Re-observe Binaryen's top-level ordered path on that generated artifact:
   - `wasm-opt _build/wasm/debug/build/cmd/cmd.wasm -O4 --shrink-level 4 --all-features --debug -o .artifacts/o4z-wasm-opt-debug-out.wasm > .artifacts/o4z-wasm-opt-debug.log 2>&1`
4. Replay implemented slots one at a time with the compare harness, always advancing the next input to the prior slot's `binaryen.wasm` output:
   - `bun scripts/self-optimize-compare.ts <input> --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir <slot-dir> --<pass>`

The saved audit root already contains the concrete predecessor `binaryen.wasm` for every hard-failure slot, so later debugging can jump straight to the failing state without rerunning the whole chain first.

## Observed top-level facts

- Binaryen top-level slots observed: `56`
- Implemented Starshine slots replayed: `34`
- Hard corruption slots: `7`
- Meaningful-equal successful slots: `27 / 34`
- Exact byte-equal successful slots: `14 / 34`
- Average wall time on successful compares:
  - Starshine: `3639.272 ms`
  - Binaryen: `253.334 ms`
- Average pass time on successful compares:
  - Starshine: `574.953 ms`
  - Binaryen: `59.495 ms`

## Hard corruption matrix

| Audit ordinal | Binaryen slot | Observed Binaryen pass | Starshine pass | Input artifact | Failure kind |
| --- | ---: | --- | --- | --- | --- |
| 11 | 14 | `remove-unused-brs` | `remove-unused-brs` | `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm` | Starshine exits `0`, but emitted raw wasm is invalid; `wasm-opt --strip-debug` dies with `popping from empty stack`, and `wasm-tools validate` reports missing `i32` in `func 1354`. |
| 13 | 16 | `optimize-instructions` | `optimize-instructions` | `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm` | Starshine command exits nonzero with `final module validate: stack underflow` in `Func 652`. |
| 16 | 19 | `precompute-propagate` | `precompute` | `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm` | Starshine exits `0`, but emitted raw wasm is invalid; `wasm-opt --strip-debug` dies with `popping from empty stack`, and `wasm-tools validate` reports missing `i32` in `func 108`. |
| 18 | 23 | `vacuum` | `vacuum` | `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm` | Starshine command exits nonzero with `final module validate: stack underflow` in `Func 652`. |
| 23 | 33 | `vacuum` | `vacuum` | `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm` | Starshine command exits nonzero with `final module validate: stack underflow` in `Func 1818`. |
| 27 | 40 | `remove-unused-brs` | `remove-unused-brs` | `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/26-slot37-vacuum/binaryen.wasm` | Starshine exits `0`, but emitted raw wasm is invalid; `wasm-opt --strip-debug` reports an `if-else` true-arm type error in function `1958`, and `wasm-tools validate` reports a stack leak in `func 1979`. |
| 30 | 44 | `optimize-instructions` | `optimize-instructions` | `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm` | Starshine command exits nonzero with `final module validate: stack underflow` in `Func 1818`. |

## Repeated offender notes

- `Func 652` is the common final-validation blocker for the early `optimize-instructions` slot and the following `vacuum` slot. That suggests the bad state survives the `optimize-instructions` rewrite boundary instead of being introduced by only one of the two later commands.
- `Func 1818` is the common final-validation blocker for the later `vacuum` slot and the later `optimize-instructions` slot after the successful `simplify-locals` and `precompute` replays.
- The two `remove-unused-brs` failures are not the same family:
  - slot `14` is a missing-result / empty-stack failure in `func 1354`
  - slot `40` is a later block-stack leak with a second validator symptom around an `if-else` true-arm type mismatch
- The early `precompute` failure at slot `19` does not prove every `precompute` slot is broken: the later slot `43` completed with meaningful equality before the next `optimize-instructions` corruption.

## Successful but expensive slots worth preserving while debugging

The successful slots with the worst wall-time ratios against Binaryen were:

1. `simplify-locals`: `79.95x` wall ratio, `13.63x` pass ratio
2. `dead-code-elimination`: `29.01x` wall ratio, `55.89x` pass ratio
3. `tuple-optimization`: `27.96x` wall ratio, `333.90x` pass ratio
4. `ssa-nomerge`: `20.74x` wall ratio, `4.69x` pass ratio
5. `heap2local`: `17.00x` wall ratio, `3.66x` pass ratio

That perf debt is separate from the hard corruption slots below; do not blur the two categories while reducing the wrong-code / invalid-output blockers.

## Immediate follow-up docs

- [0094 - slot 14 early remove-unused-brs invalid raw output](./0094-2026-04-18-generated-o4z-rub-slot14-missing-i32-result.md)
- [0095 - slot 16 early optimize-instructions final-validate underflow](./0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md)
- [0096 - slot 19 early precompute invalid raw output](./0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md)
- [0097 - slot 23 vacuum final-validate underflow after tuple-opt](./0097-2026-04-18-generated-o4z-vacuum-slot23-func652-stack-underflow.md)
- [0098 - slot 33 vacuum final-validate underflow after simplify-locals](./0098-2026-04-18-generated-o4z-vacuum-slot33-func1818-stack-underflow.md)
- [0099 - slot 40 later remove-unused-brs invalid block stack state](./0099-2026-04-18-generated-o4z-rub-slot40-block-stack-leak.md)
- [0100 - slot 44 later optimize-instructions final-validate underflow](./0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md)

