---
kind: workflow
status: supported
last_reviewed: 2026-07-17
sources:
  - ../../../raw/research/1646-2026-07-17-ssa-nomerge-batch-writeback.md
  - ../../../raw/moonbit/2026-07-10-native-build-output-path-policy.md
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

Ordinary pass signoff starts with the direct GenValid lane for `--pass ssa-nomerge`; final closeout uses a `1000000`-case broad GenValid lane plus a `100000`-case `ssa-nomerge-all` dedicated GenValid lane. Run wasm-smith only as a separately requested external-generator lane. Use singleton profiles only when narrowing a family, reproducing a manifest row's `selected_profile`, or keeping a lane intentionally focused.

Final dedicated profile command shape:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x551a --pass ssa-nomerge --generator gen-valid --gen-valid-profile ssa-nomerge-all --out-dir .tmp/pass-fuzz-ssa-nomerge-genvalid-all-final-100000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Final broad GenValid command shape:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000000 --seed 0x5eed --pass ssa-nomerge --out-dir .tmp/pass-fuzz-ssa-nomerge-final-1000000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

## Native binary path note

The `target/native/...` paths in the historical 2026-06-16 result records below document the executable actually used at that time; do not reuse them as current commands. Under the current policy, build with `moon build --target native --release src/cmd` and pass `_build/native/release/build/cmd/cmd.exe`. A legacy `target/native/...` binary is acceptable only when its hash or timestamp proves it is the freshly built executable. See [`../../../AGENTS.md`](../../../AGENTS.md) and [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md) and [`../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

## 2026-07-17 Batch-writeback refresh

After replacing repeated per-changed-function current-artifact validation with one rollback-capable changed-function batch, `.tmp/pass-fuzz-ssa-nomerge-batch-writeback-100000-20260717` reran the required dedicated aggregate with explicit Binaryen v130, `--jobs auto`, and `_build/native/release/build/cmd/cmd.exe` at SHA-256 `34a21a0bfba0c86520635429047ef8fb4cc0d32f50b0ff060b5d10327d04d680`. It requested/compared `100000/100000`, normalized all `100000`, and had zero cleanup-normalized matches, mismatches, validation/generator/property/command failures; Binaryen cache was `21055/78945`. The direct current artifact completes in deterministic valid byte-identical `43.846s` / `44.954s` wall repeats instead of timing out after `600s`. This is behavior-preserving runtime evidence, not a reopened transform-family audit.

## 2026-06-16 Final Lane Results

- Dedicated aggregate command: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x551a --pass ssa-nomerge --generator gen-valid --gen-valid-profile ssa-nomerge-all --out-dir .tmp/pass-fuzz-ssa-nomerge-genvalid-all-final-default-fallback-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `100000/100000`; normalized matches `100000`; cleanup-normalized `0`; raw mismatches `0`; validation, generator, and command failures `0`.
  - Cache: wasm-smith `0/0`; Binaryen `100000` hits / `0` misses; Binaryen failures `0/0`.
  - `genValidSelectedProfileCounts`: `ssa-nomerge-parity=37500`, `ssa-nomerge-smoke=25000`, `ssa-nomerge-coverage=25000`, `ssa-nomerge-stress=12500`.
  - Harness note: the first 100k attempt exposed a batch artifact gap: retaining all generated artifacts/manifest rows in `src/fuzz` was killed after writing the wasm files but before `manifest.json`. The emitter now streams artifacts to disk and writes a compact manifest that still preserves `selected_profile` for compare triage.
- Broad GenValid command: `bun scripts/pass-fuzz-compare.ts --count 1000000 --seed 0x5eed --pass ssa-nomerge --out-dir .tmp/pass-fuzz-ssa-nomerge-final-default-fallback-1000000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `997560/1000000`; normalized matches `997551`; cleanup-normalized `0`; raw mismatches `9`; validation/generator failures `0`; command failures `2440`.
  - Command failure classes: `binaryen-rec-group-zero=2126`, `binaryen-bad-section-size=132`, `binaryen-command-failed=104`, `binaryen-table-index-out-of-range=38`, `binaryen-invalid-tag-index=15`, `binaryen-invalid-type-index=11`, `starshine-command-failed=14`.
  - Cache: wasm-smith `500000` hits / `0` misses; Binaryen `997560` hits / `0` misses; Binaryen failures `2426` hits / `0` misses.
  - Remaining mismatch case indices: `103231`, `332901`, `394789`, `395085`, `488637`, `502867`, `555621`, `577037`, `782997`. Agent classification: unresolved output-shape parity gaps, not semantic-closeout evidence yet; see `parity.md` for family notes and reopening/fix criteria.

## 2026-06-16 Follow-up Replays

- Mismatch replay after zero-SIMD default shaping and straight-line pre-write default materialization: `bun scripts/pass-fuzz-compare.ts --pass ssa-nomerge --replay-failures-from .tmp/pass-fuzz-ssa-nomerge-final-default-fallback-1000000 --failure-status mismatch --out-dir .tmp/replay-ssanm-final-after-command-classification --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --keep-going-after-command-failures`.
  - Compared `9/9`; normalized matches `3`; cleanup-normalized `0`; raw mismatches `6`; validation/property/generator/command failures `0`.
  - Cache: wasm-smith `0/0`; Binaryen `9` hits / `0` misses; Binaryen failures `0/0`.
  - Fixed mismatch cases: `103231`, `488637`, and `502867`. Remaining unresolved cases: `332901` (param/drop traffic around unreachable after `atomic.fence`), `394789` (EH local-declaration delta), `395085` / `555621` / `577037` (tuple/multivalue spill shaping where Starshine is smaller but not yet accepted), and `782997` (non-exported no-write/default read still printed as `local.get`).
- Mismatch replay after typed-unreachable-block param/result spill fix: `bun scripts/pass-fuzz-compare.ts --pass ssa-nomerge --replay-failures-from .tmp/pass-fuzz-ssa-nomerge-final-default-fallback-1000000 --failure-status mismatch --out-dir .tmp/replay-ssanm-final-next-mismatch-fix --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --keep-going-after-command-failures`.
  - Compared `9/9`; normalized matches `4`; cleanup-normalized `0`; raw mismatches `5`; validation/property/generator/command failures `0`.
  - Cache: wasm-smith `0/0`; Binaryen `9` hits / `0` misses; Binaryen failures `0/0`.
  - Fixed mismatch case: `332901`. Remaining unresolved cases: `394789` (EH local-declaration delta), `395085` / `555621` / `577037` (tuple/multivalue spill shaping where Starshine is smaller but not yet accepted), and `782997` (non-exported no-write/default read still printed as `local.get`).
- Mismatch replay after EH local-preservation, imported-function default-read, and multivalue dead-stack fixes: `bun scripts/pass-fuzz-compare.ts --pass ssa-nomerge --replay-failures-from .tmp/pass-fuzz-ssa-nomerge-final-default-fallback-1000000 --failure-status mismatch --out-dir .tmp/replay-ssanm-final-tuple-gap-fix --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --keep-going-after-command-failures`.
  - Compared `9/9`; normalized matches `9`; cleanup-normalized `0`; raw mismatches `0`; validation/property/generator/command failures `0`.
  - Cache: wasm-smith `0/0`; Binaryen `9` hits / `0` misses; Binaryen failures `0/0`.
  - Fixed mismatch cases: `394789` (EH unreachable-debris local declaration budget), `782997` (defined-function params resolved from the function section after imports so no-write defaults materialize as `f32.const 0`), and `395085` / `555621` / `577037` (no-write multivalue call/loop dead stack now drains through explicit Binaryen-shaped `drop`s before the trailing `unreachable`). Agent classification: these were output-shape parity gaps, not accepted Starshine drift.
- Fresh broad rerun after saved mismatch fixes, first attempt: `bun scripts/pass-fuzz-compare.ts --count 1000000 --seed 0x5eed --pass ssa-nomerge --out-dir .tmp/pass-fuzz-ssa-nomerge-final-rerun-1000000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `997568/1000000`; normalized matches `997567`; cleanup-normalized `0`; raw mismatches `1`; validation/property/generator failures `0`; command failures `2432`.
  - Cache: wasm-smith `500000/0`; Binaryen `997568/0`; Binaryen failures `2427/0`. Command failure classes: `binaryen-rec-group-zero=2126`, `binaryen-bad-section-size=132`, `binaryen-command-failed=105`, `binaryen-table-index-out-of-range=38`, `binaryen-invalid-tag-index=15`, `binaryen-invalid-type-index=11`, `starshine-atomic-unshared-memory-validator=2`, `starshine-unreachable-ref-validator=3`.
  - The lone mismatch, case `967225`, was a no-write dead-stack zero-`v128.const` shape. Binaryen preserved an existing dropped `v128.const 0` while using `i32.const 0; i32x4.splat` only for materialized v128 defaults. Starshine had expanded both. This was fixed as an output-shape parity gap by expanding zero-v128 defaults only when they replace `local.get`, and by dropping existing zero-v128 stack debris before `unreachable`.
- Focused replay for case `967225`: `bun scripts/pass-fuzz-compare.ts --pass ssa-nomerge --replay-failures-from .tmp/pass-fuzz-ssa-nomerge-final-rerun-1000000 --failure-status mismatch --out-dir .tmp/replay-ssanm-final-rerun-mismatch-fix --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --keep-going-after-command-failures`.
  - Compared `1/1`; normalized matches `1`; cleanup-normalized `0`; raw mismatches `0`; validation/property/generator/command failures `0`; cache wasm-smith `0/0`; Binaryen `1/0`; Binaryen failures `0/0`.
- Fresh broad rerun after the case `967225` fix: `bun scripts/pass-fuzz-compare.ts --count 1000000 --seed 0x5eed --pass ssa-nomerge --out-dir .tmp/pass-fuzz-ssa-nomerge-final-rerun2-1000000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `997568/1000000`; normalized matches `997568`; cleanup-normalized `0`; raw mismatches `0`; validation/property/generator failures `0`; command failures `2432`.
  - Cache: wasm-smith `500000/0`; Binaryen `997568/0`; Binaryen failures `2427/0`. Command failure classes: `binaryen-rec-group-zero=2126`, `binaryen-bad-section-size=132`, `binaryen-command-failed=105`, `binaryen-table-index-out-of-range=38`, `binaryen-invalid-tag-index=15`, `binaryen-invalid-type-index=11`, `starshine-atomic-unshared-memory-validator=2`, `starshine-unreachable-ref-validator=3`.
  - Agent classification: the fresh broad direct lane is green for semantic/output-shape comparison. The remaining Starshine-specific command classes were validator acceptance gaps, not `ssa-nomerge` transform mismatches, and were fixed in the next validator follow-up.
- Validator command-failure follow-up after accepting unshared-memory atomics and unreachable/ref polymorphism: focused atomic replay `.tmp/replay-ssanm-final-atomic-validator-accept` compared `2/2`, normalized `2`, mismatches `0`, command failures `0`; focused unreachable/ref replay `.tmp/replay-ssanm-final-unreachable-ref-validator-accept` compared `3/3`, normalized `3`, mismatches `0`, command failures `0`.
- Fresh broad rerun after validator acceptance fixes: `bun scripts/pass-fuzz-compare.ts --count 1000000 --seed 0x5eed --pass ssa-nomerge --out-dir .tmp/pass-fuzz-ssa-nomerge-final-rerun3-validator-1000000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `997573/1000000`; normalized matches `997573`; cleanup-normalized `0`; raw mismatches `0`; validation/property/generator failures `0`; command failures `2427`.
  - Cache: wasm-smith `500000/0`; Binaryen `997573/0`; Binaryen failures `2427/0`. Command failure classes: `binaryen-rec-group-zero=2126`, `binaryen-bad-section-size=132`, `binaryen-command-failed=105`, `binaryen-table-index-out-of-range=38`, `binaryen-invalid-tag-index=15`, `binaryen-invalid-type-index=11`.
  - Agent classification: broad direct `ssa-nomerge` is green for output/semantic mismatches; residual command failures are Binaryen/oracle tool boundaries only.
- Starshine command-failure replay after fail-closed HOT-lift/verification guards and harness classification (superseded by the validator follow-up above): `bun scripts/pass-fuzz-compare.ts --pass ssa-nomerge --replay-failures-from .tmp/pass-fuzz-ssa-nomerge-final-default-fallback-1000000 --failure-status command-failure --failure-class starshine-command-failed --out-dir .tmp/replay-ssanm-starshine-command-failures-classified --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --keep-going-after-command-failures`.
  - Compared `8/14`; normalized matches `8`; cleanup-normalized `0`; raw mismatches `0`; validation/property/generator failures `0`; command failures `6`.
  - Command failure classes: `starshine-unreachable-ref-validator=3`, `starshine-atomic-unshared-memory-validator=2`, `binaryen-command-failed=1`; no residual generic `starshine-command-failed` cases in this replay.
  - Cache: wasm-smith `0/0`; Binaryen `8` hits / `0` misses; Binaryen failures `1` hit / `0` misses.
  - Agent classification: the repaired `starshine-command-failed` abort family was pass-pipeline fail-closed coverage, not a semantic `ssa-nomerge` mismatch. The remaining Starshine-specific classes are validator feature/polymorphic-unreachable policy gaps surfaced by wasm-smith inputs that `wasm-tools --features all` and Binaryen accept; keep them separate from pass semantics until the validator policy is changed or the harness excludes those inputs.
