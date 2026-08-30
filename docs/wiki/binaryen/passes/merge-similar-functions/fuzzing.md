---
kind: workflow
status: supported
last_reviewed: 2026-08-29
sources:
  - ../../../../../src/validate/gen_valid_merge_similar_functions.mbt
  - ../../../../../src/validate/gen_valid_merge_similar_functions_wbtest.mbt
  - ../../../../../src/passes/merge_similar_functions_test.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ../../../tooling/pass-fuzz-compare.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `merge-similar-functions` fuzzing

## Dedicated aggregate

Use:

```text
--gen-valid-profile merge-similar-functions-all
```

Aliases include `merge-similar-functions`, `merge-similar-functions-closeout`, and `msf`.

The aggregate deterministically samples eight leaves and records each selected leaf in `manifest.json`:

- `merge-similar-functions-literals`
- `merge-similar-functions-repeated-diff`
- `merge-similar-functions-exact-duplicates`
- `merge-similar-functions-duplicate-types`
- `merge-similar-functions-locals`
- `merge-similar-functions-nested`
- `merge-similar-functions-call-targets`
- `merge-similar-functions-tail-calls`

Every leaf emits at least one profitable near-duplicate class. Seeds vary class size, filler length, differing literal vectors, local counts, nested control shape, and direct call targets.

## Normalizers

Ordinary broad lanes use:

```text
--normalize local-cleanup-debris
--normalize unreachable-control-debris
```

These are not MSF parity normalizers. They cover pre-existing command-level differences:

- Starshine strips standalone `nop` debris during final encoding
- Starshine and Binaryen can encode equivalent `drop(unreachable); unreachable` tails differently

The dedicated aggregate needs neither normalizer and is exact.

## Final commands

Build once:

```sh
moon build --target native --release src/cmd
moon build --target native --release src/fuzz
```

Regular:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed \
  --pass merge-similar-functions \
  --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe \
  --normalize local-cleanup-debris \
  --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-merge-similar-functions-regular-final-100000 \
  --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/toolchains/binaryen-version_131/bin/wasm-opt \
  --require-binaryen-version 131
```

Dedicated:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass merge-similar-functions \
  --gen-valid-profile merge-similar-functions-all \
  --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe \
  --out-dir .tmp/pass-fuzz-merge-similar-functions-dedicated-10000 \
  --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/toolchains/binaryen-version_131/bin/wasm-opt \
  --require-binaryen-version 131
```

Use the same pinned tool flags for the 10,000-case `--wasm-smith` lane and the 10,000-case `random-all-profiles` lane at seed `0x5555`.

## Final results

- regular: 100,000/100,000; 96,352 ordinary plus 3,648 cleanup-normalized; zero residuals/failures
- dedicated: 10,000/10,000 exact normalized; zero failures
- wasm-smith optimization rerun: 9,949 comparable exact canonical matches; zero residuals; 51 Binaryen/tool failures
- random-all: 10,000/10,000; 9,854 ordinary plus 46 cleanup-normalized; 100 inspected 8-12-byte canonical Starshine wins from unrelated pre-existing local/block encoding; zero Starshine failures
- semantic v2: 100/100 all-equal on the final dedicated aggregate
- determinism/codec/idempotence: 100/100 each

## Performance rewrite

The retained optimization was measured on the same 5,261,119-byte pre-MSF Starshine artifact used for initial signoff. One warmup plus five alternating direct runs produced:

- Starshine before: 1.226 seconds median
- Starshine after: 0.945 seconds median
- pinned Binaryen 131: 0.603 seconds median
- improvement: 0.282 seconds / 22.96%
- final Starshine/Binaryen ratio: 1.567x

The exact 5,113,549-byte output and SHA-256 `ba3d9af87f5293b498601d277768e22a0be0b41144d7be8d59d9ddfb5f54cfab` are unchanged.

A final traced run attributes:

- fused function analysis: 68.333ms
- exact class splitting: 5.032ms
- parameter planning and rewrite: 6.176ms
- append-only candidate validation: 44.482ms

The replaced full candidate scan took 333.195ms on the same artifact. The incremental proof checks untouched section identity, type/function/element append-only prefixes, the complete candidate environment, and every changed or new function before accepting output.

Full O4z remains host-noisy near wall parity. Across seven alternating pairs, independent medians are 25.508s for Starshine and 24.984s for Binaryen (`1.021x`), but the median paired difference is 0.010s in Starshine's favor. Starshine uses 33.402s median user CPU versus Binaryen's 194.593s and remains 30,513 bytes smaller.
