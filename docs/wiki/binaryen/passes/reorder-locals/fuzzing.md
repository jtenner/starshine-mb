---
kind: workflow
status: supported
last_reviewed: 2026-07-27
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

Dedicated GenValid aggregate: `reorder-locals-all`. It selects among nine transform-family leaves:

- `reorder-locals-hot-sort` for high-index hot locals, repeated access counts, first-use ties, and tee coverage;
- `reorder-locals-permutation-only` for pure same-type index permutation with every body local live and no declaration-count change;
- `reorder-locals-mixed-types` for cross-type declaration rebuilding and grouped-run changes;
- `reorder-locals-reference-types` for nullable and non-nullable GC reference locals, including Binaryen's no-fixup boundary;
- `reorder-locals-unused-trim` for unused suffix trimming plus write-only/accessed local survival;
- `reorder-locals-structured` for nested blocks, loops, and `if` arms;
- `reorder-locals-legacy-eh` for decoded legacy `try`, typed catches, catch-all bodies, and delegates;
- `reorder-locals-multi-function` for imported/defined function indexing and different parameter arities;
- `reorder-locals-name-repair` for local-name remap and stale raw-name-payload invalidation.

The permutation-only leaf is a regression guard for the 2026-07-27 copy-on-write repair. Before that repair, a pure same-type remap could mutate the input module's shared instruction arrays. The CLI's unchanged-module fast path would then compare the optimized module equal to the mutated input module and reuse the original wasm bytes, silently losing the pass result. The leaf keeps local declarations byte-shape-stable so only a correctly encoded index remap can match Binaryen.

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

The final native Starshine artifact was SHA-256 `23fc1d30ef2db126e2690e610ad44b4af8f28da435cab6ebe845b6ec058f96c1`, compared against explicit `wasm-opt version 131 (version_131)`.

| Lane | Result |
| --- | --- |
| Regular GenValid | `100000/100000` normalized matches; zero failures. |
| Dedicated nine-leaf `reorder-locals-all` | `10000/10000` normalized matches; zero failures. Every leaf was selected, including `1101` permutation-only and `1124` legacy-EH cases. |
| Dedicated idempotence | `10000/10000` normalized matches and `10000/10000` idempotence matches; zero property failures. |
| `random-all-profiles` GenValid | `9375` normalized matches plus `625` classified Starshine wins; zero validation, generator, command, or property failures. |
| External `wasm-smith` with `--normalize unreachable-control-debris` | `9956/10000` comparable: `9955` direct normalized matches plus `1` compare-normalized unreachable/control-debris case; `44` Binaryen-only command failures; zero remaining mismatches. |

The `625` random-all residuals all came from `remove-unused-brs-control`, not a pass-owned sorter family. Binaryen's parser/IR builder lowers type-indexed multivalue blocks into a different scratch-local/control shape before `ReorderLocals.cpp`; Starshine preserves the smaller direct block representation. Across all `625` cases, Starshine's canonical output was exactly `8` bytes smaller per case (`-5000` bytes total). A separate `1000`-case replay with `wasm-tools` validation and Node runtime execution produced `757` equal results, `243` equal traps, and zero semantic mismatches; Starshine was again exactly `8` canonical bytes smaller in every case (`-8000` total). Keep this family classified as a measured Starshine win, not as a raw-output parity failure.

The external raw residual remains the previously known unreachable/control-debris family, where Binaryen removes debris unrelated to local frequency sorting. The normalized lane is the signoff record for that generator family.

## Replay And Triage Notes

- Use manifest `config_label` and `selected_profile` fields for dedicated aggregate repros.
- No `--require-feature` floor is required; each leaf directly constructs its target local-table/control shape.
- Do not accept a pure same-type permutation as covered merely because in-memory module equality changes. Confirm the encoded wasm bytes carry the remapped local indices.
- Preserve the explicit v131 oracle path. Bare `wasm-opt` may resolve to TinyGo's older Binaryen build.
- Classify random-all multivalue lowering drift with canonical size and runtime evidence; do not call it safe solely because both outputs validate.
