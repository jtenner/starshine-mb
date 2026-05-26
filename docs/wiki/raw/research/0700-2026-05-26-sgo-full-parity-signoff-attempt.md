# SGO full parity signoff attempt

Date: 2026-05-26
Slice: `[SGO]005` full v0.1.0 self-optimization and 10k fuzzer signoff

## Context

This cron run selected `[SGO]005` because `[SGO]003A` through `[SGO]003H` and `[SGO]004` are already accepted / evidence-gated, and `agent-todo.md` lists final SGO signoff as the remaining active SGO slice.

No optimizer behavior changed in this run. The run regenerated the ignored local debug WASI fixture from the current workspace with:

```sh
moon build --target wasm src/cmd
cp _build/wasm/debug/build/cmd/cmd.wasm tests/node/dist/starshine-debug-wasi.wasm
```

`tests/node/dist/starshine-debug-wasi.wasm` is ignored and was not committed.

## Validation that passed

- `moon info` passed with the existing DAE unused warnings.
- `moon fmt` passed.
- `moon test` passed: `3723/3723`.
- Direct SGO fuzz passed:

```sh
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-full-parity-10000
```

Result: `6759/10000` compared before the configured command-failure stop, `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, `0` generator failures, and `20` Binaryen/tool command failures.

- Ordered late-tail fuzz passed:

```sh
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --pass remove-unused-module-elements --pass string-gathering --pass reorder-globals --pass directize --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-late-tail-full-parity-10000
```

Result: `6597/10000` compared before the configured command-failure stop, `6597` normalized matches, `0` mismatches, `0` Starshine validation failures, `0` generator failures, and `20` Binaryen/tool command failures.

## Direct artifact result

Command:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-globals-optimizing --out-dir .tmp/sgo-full-parity-direct-artifact-native --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result:

- Starshine raw wasm: `2,955,090` bytes.
- Binaryen raw wasm: `2,950,689` bytes.
- Canonical wasm equal: no.
- Normalized WAT equal: no.
- Canonical function compare equal: no.
- First differing function: `defined=55 abs=76`.
- Starshine runtime: `619.584ms`; Binaryen runtime: `498.583ms`.
- Starshine pass runtime: `249.120ms`; Binaryen pass runtime: `115.912ms`.
- Starshine pass runtime is over the repo 2x floor (`249.120ms > 231.824ms`). A repeat at `.tmp/sgo-full-parity-direct-artifact-native-repeat` reported `257.074ms` Starshine vs `112.087ms` Binaryen and confirmed the gap.
- `wasm-tools validate` accepted both `.tmp/sgo-full-parity-direct-artifact-native/starshine.wasm` and `.tmp/sgo-full-parity-direct-artifact-native/starshine.raw.wasm`.

### Mismatch classification

The first diff is classified as **representation-only default-local / carrier shape drift**, not a semantic mismatch. In `func-defined55-abs76`, Binaryen explicitly initializes local `$0` to `0` and uses `local.tee $1 (i32.const 195808)` as the `if` condition; Starshine relies on the WebAssembly default `i32` local value for `$0`, sets `$1` to the same constant before the `if`, and then uses the same call operands. The output validates, and the difference is the same family as the earlier accepted default-local initialization drift, but the current artifact compare is not green and the pass-local timing is not within the 2x floor.

## Ordered late-tail artifact result

Command:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-globals-optimizing --remove-unused-module-elements --string-gathering --reorder-globals --directize --out-dir .tmp/sgo-full-parity-late-tail-artifact --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result:

- Canonical wasm equal: no.
- Normalized WAT equal: no.
- Canonical function compare equal: no.
- First differing function: `defined=55 abs=76`.
- Starshine runtime: `737.497ms`; Binaryen runtime: `594.568ms`.
- Starshine pass runtime: `376.989ms`; Binaryen pass runtime: `176.568ms`.
- Starshine pass runtime is over the repo 2x floor (`376.989ms > 353.136ms`). A repeat at `.tmp/sgo-full-parity-late-tail-artifact-repeat` reported `385.680ms` Starshine vs `177.497ms` Binaryen and confirmed the gap.

## Full optimize/self-optimization blocker

The current self-optimize comparison helper still rejects preset flags:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --optimize --out-dir .tmp/sgo-full-parity-optimize-artifact --starshine-bin _build/native/release/build/cmd/cmd.exe
```

failed with:

```text
unsupported preset flag for self-optimize compare: --optimize
```

This means `[SGO]005` cannot be closed as a full optimize-path comparison from the helper in this run. The existing `[WALL]001` note about explicit full-preset attempts timing out remains relevant for the broader optimize-path comparison, but this run did not reach that path because the helper rejected `--optimize` before execution.

## Required follow-up

`[SGO]005` remains active. The next run should not start a new SGO behavior slice. It should first choose one of these signoff blockers:

1. bring direct SGO and late-tail artifact pass-local timing back within the 2x floor, or document an accepted attribution if the floor is waived;
2. decide whether the `defined=55 abs=76` default-local / carrier drift can be accepted for final SGO signoff, or add a compare-normalization / cosmetic parity task if exact artifact equality is required;
3. add self-optimize helper support for preset flags or provide the explicit-pass equivalent needed for the v0.1.0 optimize-path comparison, then rerun or document the existing full-preset runtime blocker under `[WALL]001`.
