---
kind: research
status: current
last_reviewed: 2026-05-19
sources:
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/remove-unused-module-elements/parity.md
  - ../../binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/reorder-globals/index.md
  - ../../binaryen/passes/directize/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/reorder_globals_test.mbt
  - ../../../../agent-todo.md
related:
  - ./0549-2026-05-08-late-tail-triple-replay-for-reorder-globals-and-directize.md
---

# Late-tail five-pass neighborhood baseline

## Question

After accepting the remaining direct `simplify-globals-optimizing` artifact drift, can Starshine replay the next Binaryen late-tail neighborhood before widening public `optimize` / `shrink` presets?

Target sequence:

```text
simplify-globals-optimizing
-> remove-unused-module-elements
-> string-gathering
-> reorder-globals
-> directize
```

## Local surface check

The active registry / CLI surface already exposes all five pass spellings:

- `simplify-globals-optimizing`
- `remove-unused-module-elements`
- `string-gathering`
- `reorder-globals`
- `directize`

`bun scripts/pass-fuzz-compare.ts --list-passes` lists all five, and `src/passes/pass_manager.mbt` routes them through active module-pass dispatch.

## Focused regression

Added `test "sgo rume prefix preserves rooted late-tail replay module"` in `src/passes/reorder_globals_test.mbt`.

The fixture reuses the earlier late-tail shape and now also exports the `$run` function so `remove-unused-module-elements` cannot legitimately prune the body before the later string/global/direct-call passes. The new five-pass test validates the resulting module and checks that the expected global and function exports survive the full ordered neighborhood. The earlier `string-gathering -> reorder-globals -> directize` regression still checks the stronger local order effects: no residual `string.const`, no residual `call_indirect`, a direct call remains, and the hot global moved to a small index.

TDD note: the first version intentionally left `$run` unexported and failed under the five-pass prefix because `remove-unused-module-elements` pruned the unrooted body. Exporting `$run` made the fixture a valid neighborhood regression instead of a liveness-pruning test.

Validation:

```sh
moon test src/passes
```

Result: `1260/1260` passed.

## Direct artifact baseline

Command:

```sh
bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --simplify-globals-optimizing \
  --remove-unused-module-elements \
  --string-gathering \
  --reorder-globals \
  --directize \
  --out-dir .tmp/sg-tail-neighborhood-baseline \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result:

- Starshine output validates with `wasm-tools validate --features all`.
- Binaryen output validates with `wasm-tools validate --features all`.
- Starshine size: `2,856,748` bytes.
- Binaryen size: `2,861,120` bytes.
- Starshine pass-local runtime: `310.078ms`.
- Binaryen pass-local runtime: `183.544ms`.
- First canonical function diff: `defined=39 abs=60`.
- First-diff shape: Starshine calls the corresponding callee at a lower function index while Binaryen keeps additional functions, so the normalized text differs by numeric function-index layout after the `remove-unused-module-elements` boundary.

Prefix runs showed the same first diff already appears at `simplify-globals-optimizing -> remove-unused-module-elements` and stays unchanged after adding `string-gathering`, `reorder-globals`, and `directize`:

- `.tmp/sg-tail-sgo-rume`: first diff `defined=39 abs=60`.
- `.tmp/sg-tail-sgo-rume-sg`: first diff `defined=39 abs=60`.
- `.tmp/sg-tail-sgo-rume-sg-rg`: first diff `defined=39 abs=60`.
- `.tmp/sg-tail-neighborhood-baseline`: first diff `defined=39 abs=60`.

This attributes the artifact frontier to the SGO-fed RUME function-retention / function-index layout boundary, not to the later `string-gathering -> reorder-globals -> directize` triple.

## Same-input RUME isolation

The `defined=39 abs=60` frontier is not a same-input RUME mismatch.

Commands:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/sgo-direct-debug-artifact-nested-pruned/starshine.raw.wasm \
  --remove-unused-module-elements \
  --out-dir .tmp/rume-cross-sgo/self-compare-star-sgo-rume \
  --starshine-bin _build/native/release/build/cmd/cmd.exe

bun scripts/self-optimize-compare.ts \
  .tmp/sgo-direct-debug-artifact-nested-pruned/binaryen.raw.wasm \
  --remove-unused-module-elements \
  --out-dir .tmp/rume-cross-sgo/self-compare-bin-sgo-rume \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Results:

- Starshine-SGO input through RUME: canonical wasm equal `yes`, normalized WAT equal `yes`.
- Binaryen-SGO input through RUME: canonical wasm equal `yes`, normalized WAT equal `yes`.

Function-count cross-check:

- Starshine SGO output after either RUME implementation: `6305` defined functions.
- Binaryen SGO output after either RUME implementation: `6311` defined functions.

This means both RUME implementations agree on each concrete SGO-side input. The debug-artifact frontier comes from applying RUME to two already-representationally-different SGO outputs, not from Starshine RUME making a different keep/drop decision on the same module.

## Ordered-neighborhood fuzz signoff

Smoke command:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass simplify-globals-optimizing \
  --pass remove-unused-module-elements \
  --pass string-gathering \
  --pass reorder-globals \
  --pass directize \
  --max-failures 20 \
  --keep-going-after-command-failures \
  --out-dir .tmp/pass-fuzz-sg-tail-neighborhood-1000 \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result: `998/1000` compared, `998` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `2` Binaryen/tool command failures.

Standard command:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass simplify-globals-optimizing \
  --pass remove-unused-module-elements \
  --pass string-gathering \
  --pass reorder-globals \
  --pass directize \
  --max-failures 20 \
  --keep-going-after-command-failures \
  --jobs auto \
  --out-dir .tmp/pass-fuzz-sg-tail-neighborhood-10k \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result: `9972/10000` compared, `9972` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `28` Binaryen/tool command failures.

## Conclusion

The five-pass late-tail neighborhood is executable, validates on the debug artifact, and has standard 10k ordered-neighborhood fuzz parity. The remaining debug-artifact canonical diff is inherited from accepted SGO representation drift feeding RUME: same-input RUME comparisons are green on both the Starshine-SGO and Binaryen-SGO artifacts, but the two SGO-side inputs have different reachable helper/function-layout frontiers after RUME. The later `string-gathering -> reorder-globals -> directize` tail carries that frontier forward unchanged.

This is enough to treat the direct ordered neighborhood as oracle-proven for v0.1.0 scheduling purposes. Public `optimize` / `shrink` widening should still be a separate preset change with preset-order tests and its own artifact evidence, rather than being folded into this classification commit.
