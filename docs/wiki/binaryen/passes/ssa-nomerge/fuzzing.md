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

Recommended dedicated GenValid closeout lane: `--gen-valid-profile ssa-nomerge-all`.

`ssa-nomerge-all` is a deterministic composite profile. For each selected case it samples one singleton SSA profile from the same root seed and case index, records the requested `config_label` as `ssa-nomerge-all`, and records the sampled `selected_profile` in the GenValid manifest for replay triage.

Current singleton profiles remain available for targeted reproduction and development:

- `ssa-nomerge-parity`: conservative compare-clean LocalGraph/freshening families.
- `ssa-nomerge-smoke`: quick structured branch/default/freshening smoke coverage.
- `ssa-nomerge-coverage` (`ssa-nomerge` alias): dense SSA coverage and supported/fail-closed boundary facts.
- `ssa-nomerge-stress`: dense pathological/fail-closed lane, currently matching coverage templates.

Ordinary pass signoff still starts with the direct mixed-generator lane for `--pass ssa-nomerge`; use `ssa-nomerge-all` as the dedicated GenValid pass-profile lane when the slice changes SSA generator behavior or is collecting dedicated closeout evidence. Use singleton profiles only when narrowing a family, reproducing a manifest row's `selected_profile`, or keeping a lane intentionally focused.
