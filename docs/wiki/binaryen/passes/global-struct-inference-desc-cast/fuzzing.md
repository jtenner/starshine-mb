---
kind: workflow
status: working
last_reviewed: 2026-06-20
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ./starshine-strategy.md
---

# `global-struct-inference-desc-cast` Fuzzing Profile

Recommended smoke lane: run the ordinary mixed-generator compare-pass lane for the public pass spelling after building native Starshine:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-global-struct-inference-desc-cast --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Current ordinary lane evidence from 2026-06-20:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-global-struct-inference-desc-cast-10000-rerun --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result: `7602/10000` compared, `7602` normalized matches, `0` mismatches, `20` Binaryen/tool command failures.

Operand-breadth and unreachable-bailout follow-up ordinary lane from 2026-06-20:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-global-struct-inference-desc-cast-operand-breadth-unreachable-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: `10000/10000` compared, `10000` normalized matches, `0` mismatches, `0` validation/generator/property failures, and `0` command failures. Earlier attempts using `.tmp/pass-fuzz-global-struct-inference-desc-cast-operand-breadth-10000` and `.tmp/pass-fuzz-global-struct-inference-desc-cast-operand-breadth-10000-rerun` were superseded by the final unreachable-bailout rerun; the first failed before comparison while emitting the GenValid batch.

Interpretation: these remain useful direct-pass smoke/signoff lanes for the public pass spelling and inherited non-closed-world ordinary-GSI behavior. The dedicated profile below now carries the positive descriptor-cast fuzz burden.

## Dedicated GenValid profile

Profile name: `gsi-desc-cast`.

Aliases: `global-struct-inference-desc-cast` and `gsi-desc-cast-all` resolve to the aggregate profile. Singleton leaves are:

- `gsi-desc-cast-positive` — emits closed-world singleton descriptor globals plus immediate and structured `ref.cast` operands that should rewrite to `ref.cast_desc_eq`, including nullable and exact target casts.
- `gsi-desc-cast-strict-subtype` — emits a strict subtype topology with both a non-exact bailout cast and an exact-target positive cast.
- `gsi-desc-cast-zero-boundary` — emits the no-descriptor-global bailout.
- `gsi-desc-cast-multi-boundary` — emits the multiple-descriptor-global bailout.
- `gsi-desc-cast-unreachable-boundary` — emits Binaryen's unreachable-input bailout.

The aggregate is deterministic and records `selected_profile` in `inputs/gen-valid/manifest.json` for replay triage. No extra `--normalize` flags or feature floors are required.

Dedicated profile signoff from 2026-06-20:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --gen-valid-profile gsi-desc-cast --out-dir .tmp/pass-fuzz-gsi-desc-cast-genvalid-gsi-desc-cast-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: `10000/10000` compared, `10000` normalized matches, `0` cleanup-normalized matches, `0` raw mismatches, `0` validation/generator/property failures, and `0` command failures. Cache counters: wasm-smith `0/0`, Binaryen `10000` hits / `0` misses, Binaryen failures `0/0`. Selected profile counts: `gsi-desc-cast-positive=5045`, `gsi-desc-cast-strict-subtype=1944`, `gsi-desc-cast-zero-boundary=1021`, `gsi-desc-cast-unreachable-boundary=1006`, `gsi-desc-cast-multi-boundary=984`.

## Final closeout matrix (2026-06-20)

The direct `global-struct-inference-desc-cast` / Binaryen `--gsi-desc-cast` audit is closed for current behavior parity. The local GenValid catalog does not currently expose a literal `all-profiles` profile; for this audit the selected repo-standard broad named profile is `pass-fuzz-stress`, the named form of the default Binaryen-oracle portable compare-pass batch config documented in [`../../../tooling/fuzz-runner.md`](../../../tooling/fuzz-runner.md).

Final lanes:

- Regular GenValid: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-gsi-desc-cast-genvalid-100000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `100000/100000`; normalized `100000`; cleanup-normalized `0`; raw mismatches `0`; validation, generator, property, and command failures `0`.
  - Cache: wasm-smith `0/0`; Binaryen `10313` hits / `89687` misses; Binaryen failures `0/0`.
  - Selected profile counts: `binaryen-oracle-portable=100000`.
- Explicit wasm-smith: `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --out-dir .tmp/pass-fuzz-gsi-desc-cast-wasm-smith-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `9956/10000`; normalized `9956`; cleanup-normalized `0`; raw mismatches `0`; validation, generator, and property failures `0`; command failures `44`.
  - Command classes: `binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`.
  - Cache: wasm-smith `3811` hits / `6189` misses; Binaryen `3870` hits / `6086` misses; Binaryen failures `20` hits / `24` misses.
- Dedicated desc-cast GenValid: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference-desc-cast --gen-valid-profile gsi-desc-cast --out-dir .tmp/pass-fuzz-gsi-desc-cast-genvalid-gsi-desc-cast-final-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `10000/10000`; normalized `10000`; cleanup-normalized `0`; raw mismatches `0`; validation, generator, property, and command failures `0`.
  - Cache: Binaryen `10000` hits / `0` misses; Binaryen failures `0/0`.
  - Selected profile counts: `gsi-desc-cast-positive=5045`, `gsi-desc-cast-strict-subtype=1944`, `gsi-desc-cast-zero-boundary=1021`, `gsi-desc-cast-unreachable-boundary=1006`, `gsi-desc-cast-multi-boundary=984`.
- Broad named GenValid profile: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass global-struct-inference-desc-cast --gen-valid-profile pass-fuzz-stress --out-dir .tmp/pass-fuzz-gsi-desc-cast-genvalid-pass-fuzz-stress-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`.
  - Compared `10000/10000`; normalized `10000`; cleanup-normalized `0`; raw mismatches `0`; validation, generator, property, and command failures `0`.
  - Cache: Binaryen `157` hits / `9843` misses; Binaryen failures `0/0`.
  - Selected profile counts: `pass-fuzz-stress=10000`.

Agent classification: zero Starshine semantic mismatches, zero Starshine validation failures, and zero Starshine-specific command failures were observed. The wasm-smith residuals are Binaryen/oracle tool classes. Keep reopening criteria in [`./starshine-strategy.md`](./starshine-strategy.md); singleton profiles remain available for targeted repro, but ordinary final closeout should cite this matrix.
