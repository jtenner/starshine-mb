---
kind: workflow
status: working
last_reviewed: 2026-09-02
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `propagate-globals-globally` Fuzzing Profile

## Dedicated profiles

Use `propagate-globals-globally-all` for ordinary dedicated signoff. The aliases `propagate-globals-globally`, `propagate-globals-globally-closeout`, `propagate-globals-globally-all-profiles`, `pgg`, and `pgg-closeout` resolve to the same equal-weight aggregate.

| Leaf | Transform family |
| --- | --- |
| `propagate-globals-globally-direct-global` | A later initializer directly reads an earlier literal global. |
| `propagate-globals-globally-compound-global` | An arithmetic constant expression reads an earlier literal; a third global reads that compound result to guard the v131 literal-only fact boundary. |
| `propagate-globals-globally-gc-compound` | A GC `struct.new` constant expression reads two earlier literal globals. |
| `propagate-globals-globally-data-offset` | An active data offset reads a literal global. |
| `propagate-globals-globally-elem-offset` | An active element offset reads a literal global. |

The GC leaf deliberately avoids stringref so the external wasm-tools admission check accepts it. The focused pass test separately covers the equivalent string-constant `struct.new` shape.

## Closeout commands

All 2026-09-02 evidence used native Starshine CLI SHA-256 `e0d4be3a50ddbfeb08080f866fe5e56b77cdc03fcbd8dac6b7ebd9e0f8c47ae4`, GenValid SHA-256 `436bf5f07717225438825ba3896864146173aa5eea5d6d9d954c37a67be5e2a9`, and official Binaryen v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`:

```sh
bun fuzz compare-pass --count 100000 --seed 0x5eed --pass propagate-globals-globally --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe --out-dir .tmp/pass-fuzz-pgg-regular-literal-boundary-100000-20260902 --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --require-binaryen-version 131 --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches

bun fuzz compare-pass --count 10000 --seed 0x5eed --pass propagate-globals-globally --gen-valid-profile propagate-globals-globally-all --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe --out-dir .tmp/pass-fuzz-pgg-dedicated-literal-boundary-10000-20260902 --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --require-binaryen-version 131 --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches

bun fuzz compare-pass --count 10000 --seed 0x5555 --pass propagate-globals-globally --gen-valid-profile random-all-profiles --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe --out-dir .tmp/pass-fuzz-pgg-random-all-literal-boundary-10000-20260902 --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --require-binaryen-version 131 --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

## Results

- Ordinary: `100000/100000` normalized and canonical matches; zero generator, command, validation, property, or mismatch failures.
- Dedicated aggregate: `10000/10000` normalized and canonical matches with the same zero-failure result. The manifest selected direct `1,979`, compound `1,994`, GC compound `2,011`, data offset `1,973`, and element offset `2,043` times.
- Random-all: `9900/10000` normalized matches plus 100 inspected, pass-independent representation parity gaps. Random selection reached direct `103`, compound `77`, GC compound `114`, data offset `94`, and element offset `101` times. All 100 residuals come from `remove-unused-brs-*` profiles and have `globals=false`, `elems=false`, `datas=false`, and `const_expr_variants=false`; therefore PGG is a contract-proved no-op on those inputs. Canonically, 87 Starshine outputs are smaller and 13 are larger, so the family remains open as a non-PGG parity/codec gap rather than being classified as a PGG win.
- Forty directly emitted modules under `.tmp/pgg-profile-*-v5-20260902`, eight from each focused leaf, passed `wasm-tools validate --features all` (`40/40`).

No separate wasm-smith lane was run because that external-generator lane requires an explicit request.
