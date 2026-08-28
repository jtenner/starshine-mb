---
kind: workflow
status: supported
last_reviewed: 2026-08-28
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/validate/gen_valid.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ../simplify-locals/fuzzing.md
---

# Binaryen `simplify-locals-notee` fuzzing

## 2026-08-28 performance-change renewal

Final native SHA-256 `58fde6321d2ae50a492f55346047a2d0ba5d0c91e035605046be5cb6e9a1d537` completed the required matrix with bounded eight-worker execution and at most 20 persisted mismatch artifacts:

- regular GenValid, seed `0x5eed`: `100000/100000` normalized matches, zero mismatches or failures, and exact canonical totals of 422,113,416 bytes per tool;
- pass-owned `simplify-locals-notee`, seed `0x5eed`: `10000/10000` established structural differences, all canonically smaller in Starshine (2,273,122 versus 2,374,945 aggregate bytes), with zero validation/property/generator/command failures. Selection was family coverage `3125`, local traffic `1875`, structure result `1875`, flat parent `1250`, effect order `1250`, and stress `625`;
- explicit wasm-smith, seed `0x5eed`: `9956/10000` comparable, `9955` normalized, one two-byte-smaller removal of two effect-free `nop`s from nested result loops, zero Starshine failures, and 44 Binaryen/tool failures (`39` empty recursive groups, `3` bad section sizes, `1` invalid tag index, `1` table index out of range);
- random-all-profiles, seed `0x5555`: `10000/10000`, `7076` normalized and `2924` residuals, zero failures. Canonical directions were 2,731 smaller, 7,076 equal, and 193 larger; these cross-profile residuals remain pre-existing parity evidence rather than being reclassified as safe;
- runtime-callable self semantics: `100/100` exact observable matches, with 74 Binaryen-shape matches and 26 canonically smaller Starshine outputs.

For attribution, current and clean HEAD outputs were byte-identical on every input in the 10,000-case dedicated, random-all, and wasm-smith corpora. That proves the performance change introduces no output family, including the 193 random-profile larger cases. Evidence is under `.tmp/pass-fuzz-slnt-perf-regular-final-100000`, `.tmp/pass-fuzz-slnt-perf-dedicated-final-10000`, `.tmp/pass-fuzz-slnt-perf-wasm-smith-final-10000`, `.tmp/pass-fuzz-slnt-perf-random-all-final-10000`, `.tmp/pass-fuzz-slnt-perf-runtime-final-100`, and `.tmp/slnt-perf-20260828/clean-head-corpus-compare`.

## Binaryen-v131 closeout

The direct lane is active under canonical spelling `simplify-locals-notee`, mapped to Binaryen `--simplify-locals-notee`.

The refreshed aggregate used seed `0x5eed`, official Binaryen v131, and the explicit native Starshine release binary:

```text
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass simplify-locals-notee \
  --gen-valid-profile simplify-locals-notee \
  --out-dir .tmp/pass-fuzz-simplify-locals-notee-v131-refresh-20260727-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt
```

Result:

- compared: `10000/10000`;
- exact normalized matches: `2766`;
- structural differences: `7234`, every one strictly smaller for Starshine by `4–54` canonical wasm bytes;
- validation, property, generator, and command failures: `0`;
- profile leaf coverage: local traffic `3530`, structure result `3557`, effect order `1455`, stress `1458`.

The separate `1000`-case seed-`0x1d3a` idempotence lane is `1000/1000` with zero property failures. The residuals are classified Starshine wins from the documented no-new-tee and cleanup shaping; no parity gap, unknown/risky family, validation failure, or size-losing result remains.
