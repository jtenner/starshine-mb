---
kind: workflow
status: supported
last_reviewed: 2026-06-16
sources:
  - ./parity.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/fuzz/main.mbt
---

# `ssa-nomerge` Fuzzing Profile

Recommended dedicated GenValid closeout lane: `--gen-valid-profile ssa-nomerge-all` at `100000` requested cases for final closeout. The 2026-06-16 native final aggregate run is green at that count.

`ssa-nomerge-all` is a deterministic composite profile. For each selected case it samples one singleton SSA profile from the same root seed and case index, records the requested `config_label` as `ssa-nomerge-all`, and records the sampled `selected_profile` in the GenValid manifest for replay triage.

Current singleton profiles remain available for targeted reproduction and development:

- `ssa-nomerge-parity`: conservative compare-clean LocalGraph/freshening families.
- `ssa-nomerge-smoke`: quick structured branch/default/freshening smoke coverage.
- `ssa-nomerge-coverage` (`ssa-nomerge` alias): dense SSA coverage and supported/fail-closed boundary facts.
- `ssa-nomerge-stress`: dense pathological/fail-closed lane, currently matching coverage templates.

Ordinary pass signoff still starts with the direct mixed-generator lane for `--pass ssa-nomerge`; final closeout should use a `1000000`-case mixed-generator lane plus a `100000`-case `ssa-nomerge-all` dedicated GenValid lane. Use singleton profiles only when narrowing a family, reproducing a manifest row's `selected_profile`, or keeping a lane intentionally focused.

Final dedicated profile command shape:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x551a --pass ssa-nomerge --generator gen-valid --gen-valid-profile ssa-nomerge-all --out-dir .tmp/pass-fuzz-ssa-nomerge-genvalid-all-final-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Final broad mixed-generator command shape:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000000 --seed 0x5eed --pass ssa-nomerge --out-dir .tmp/pass-fuzz-ssa-nomerge-final-1000000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

## 2026-06-16 Final Lane Results

- Dedicated aggregate command: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x551a --pass ssa-nomerge --generator gen-valid --gen-valid-profile ssa-nomerge-all --out-dir .tmp/pass-fuzz-ssa-nomerge-genvalid-all-final-default-fallback-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `100000/100000`; normalized matches `100000`; cleanup-normalized `0`; raw mismatches `0`; validation, generator, and command failures `0`.
  - Cache: wasm-smith `0/0`; Binaryen `100000` hits / `0` misses; Binaryen failures `0/0`.
  - `genValidSelectedProfileCounts`: `ssa-nomerge-parity=37500`, `ssa-nomerge-smoke=25000`, `ssa-nomerge-coverage=25000`, `ssa-nomerge-stress=12500`.
  - Harness note: the first 100k attempt exposed a batch artifact gap: retaining all generated artifacts/manifest rows in `src/fuzz` was killed after writing the wasm files but before `manifest.json`. The emitter now streams artifacts to disk and writes a compact manifest that still preserves `selected_profile` for compare triage.
- Broad mixed-generator command: `bun scripts/pass-fuzz-compare.ts --count 1000000 --seed 0x5eed --pass ssa-nomerge --out-dir .tmp/pass-fuzz-ssa-nomerge-final-default-fallback-1000000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `997560/1000000`; normalized matches `997551`; cleanup-normalized `0`; raw mismatches `9`; validation/generator failures `0`; command failures `2440`.
  - Command failure classes: `binaryen-rec-group-zero=2126`, `binaryen-bad-section-size=132`, `binaryen-command-failed=104`, `binaryen-table-index-out-of-range=38`, `binaryen-invalid-tag-index=15`, `binaryen-invalid-type-index=11`, `starshine-command-failed=14`.
  - Cache: wasm-smith `500000` hits / `0` misses; Binaryen `997560` hits / `0` misses; Binaryen failures `2426` hits / `0` misses.
  - Remaining mismatch case indices: `103231`, `332901`, `394789`, `395085`, `488637`, `502867`, `555621`, `577037`, `782997`. Agent classification: unresolved output-shape parity gaps, not semantic-closeout evidence yet; see `parity.md` for family notes and reopening/fix criteria.
