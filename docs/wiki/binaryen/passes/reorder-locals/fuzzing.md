---
kind: workflow
status: supported
last_reviewed: 2026-07-28
sources:
  - ./index.md
  - ./parity.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
---

# `reorder-locals` Fuzzing Profile

Dedicated GenValid aggregate: `reorder-locals-all`. It selects among ten transform-family leaves:

- `reorder-locals-hot-sort` for high-index hot locals, unequal repeated access counts, parameter stability, and tee coverage;
- `reorder-locals-permutation-only` for pure same-type index permutation with every body local live and no declaration-count change;
- `reorder-locals-first-use-ties` for equal nonzero access counts encountered in an order different from the original local indices;
- `reorder-locals-mixed-types` for cross-type declaration rebuilding and grouped-run changes;
- `reorder-locals-reference-types` for nullable and non-nullable GC reference locals, including Binaryen's no-fixup boundary;
- `reorder-locals-unused-trim` for unused suffix trimming plus write-only/accessed local survival;
- `reorder-locals-structured` for nested blocks, loops, and `if` arms;
- `reorder-locals-legacy-eh` for decoded legacy `try`, typed catches, catch-all bodies, and delegates;
- `reorder-locals-multi-function` for imported/defined function indexing and different parameter arities;
- `reorder-locals-name-repair` for local-name remap and stale raw-name-payload invalidation.

The permutation-only leaf is a regression guard for the 2026-07-27 copy-on-write repair. Before that repair, a pure same-type remap could mutate the input module's shared instruction arrays. The CLI's unchanged-module fast path would then compare the optimized module equal to the mutated input module and reuse the original wasm bytes, silently losing the pass result. The leaf keeps local declarations byte-shape-stable so only a correctly encoded index remap can match Binaryen.

The 2026-07-28 audit split first-use ordering into its own leaf after noticing that the old hot-sort template had only unequal body-local counts. The focused leaf gives three live locals exactly two accesses each, first touches them in `17 -> 2 -> 9` order, and therefore requires a visible tie-driven permutation rather than inferring tie coverage from an unrelated legacy-EH fixture.

Recommended direct lane:

```sh
bun fuzz compare-pass \
  --count 10000 --seed 0x5eed --pass reorder-locals \
  --gen-valid-profile reorder-locals-all \
  --out-dir .tmp/pass-fuzz-reorder-locals-genvalid-10000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin <official-version-131-wasm-opt> \
  --no-reduce-mismatches
```

## Binaryen v131 Closeout

The refreshed native Starshine artifact is SHA-256 `e90aad59cc6e1f43e4304906b6364c8a57b3cb25d1de915b08043dd8ac085bd4`, compared against explicit `wasm-opt version 131 (version_131)` from Binaryen source commit `1f903c14babf829745b421b92ff0f286e93e4209`.

| Lane | Result |
| --- | --- |
| First-use-tie singleton | `1000/1000` normalized matches; zero failures. |
| Regular GenValid | `100000/100000` normalized matches; zero failures; Binaryen cache `100000/0` hits/misses. |
| Dedicated ten-leaf `reorder-locals-all` | `10000/10000` normalized matches; zero failures; Binaryen cache `3087/6913`. Every leaf was selected: hot-sort `1507`, permutation-only `1041`, first-use-ties `999`, mixed-types `983`, reference-types `1006`, unused-trim `1019`, structured `985`, legacy-EH `945`, multi-function `1022`, and name-repair `493`. |
| Dedicated idempotence | `10000/10000` normalized matches and `10000/10000` idempotence matches; zero property failures; Binaryen cache `10000/0`. |
| `random-all-profiles` GenValid | `9375` normalized matches plus `625` classified Starshine wins; zero validation, generator, command, or property failures; Binaryen cache `5874/4126`. |
| External `wasm-smith` with `--normalize unreachable-control-debris` | `9956/10000` comparable: `9955` direct normalized matches plus `1` compare-normalized unreachable/control-debris case; `44` Binaryen-only command failures; zero remaining mismatches. Cache: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`. |

The `625` random-all residuals all came from `remove-unused-brs-control`, not a pass-owned sorter family. Binaryen's parser/IR builder lowers type-indexed multivalue blocks into a different scratch-local/control shape before `ReorderLocals.cpp`; Starshine preserves the smaller direct block representation. Across all `625` cases, Starshine's canonical output was exactly `8` bytes smaller per case (`-5000` bytes total). A fresh `1000`-case replay with `wasm-tools` validation and Node runtime execution produced `775` equal results, `225` equal traps, and zero semantic mismatches; Starshine was again exactly `8` canonical bytes smaller in every case (`-8000` total). Keep this family classified as a measured Starshine win, not as a raw-output parity failure.

The external raw residual remains the previously known unreachable/control-debris family, where Binaryen removes debris unrelated to local frequency sorting. The normalized lane is the signoff record for that generator family.

## Replay And Triage Notes

- Use manifest `config_label` and `selected_profile` fields for dedicated aggregate repros.
- No `--require-feature` floor is required; each leaf directly constructs its target local-table/control shape.
- Do not accept a pure same-type permutation as covered merely because in-memory module equality changes. Confirm the encoded wasm bytes carry the remapped local indices.
- Preserve the explicit v131 oracle path. Bare `wasm-opt` may resolve to TinyGo's older Binaryen build.
- Classify random-all multivalue lowering drift with canonical size and runtime evidence; do not call it safe solely because both outputs validate.
