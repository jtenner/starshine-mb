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

Recommended dedicated GenValid closeout lane: `--gen-valid-profile ssa-nomerge-all` at `100000` requested cases for final closeout.

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
