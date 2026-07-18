---
kind: workflow
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ./index.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./index.md
  - ./parity.md
---

# `pick-load-signs` fuzzing profile

Dedicated GenValid profile: `pick-load-signs-all`.

The aggregate is replayable: manifests retain `config_label: "pick-load-signs-all"` and record the selected leaf in `selected_profile`.

## Profile leaves

- `pick-load-signs-signed-extend`: upstream-common i32 direct signed-extension rewrite.
- `pick-load-signs-signed-shift`: upstream-common i32 signed shift-pair rewrite.
- `pick-load-signs-unsigned-mask`: five functions covering the upstream right-hand i32 mask, the retained commuted i32 mask, and i64 mask widths 8/16/32.
- `pick-load-signs-unsigned-shift`: five mutating functions covering i32 widths 8/16 and i64 widths 8/16/32. Each begins with a signed load so the pass must flip it and remove the redundant unsigned shift pair.
- `pick-load-signs-i64-watch`: six mutating functions covering i64 direct signed extensions and signed shift pairs at widths 8/16/32.
- `pick-load-signs-unknown-use-boundary`: equality use that blocks rewriting.
- `pick-load-signs-mixed-width-boundary`: conflicting evidence widths.
- `pick-load-signs-width-mismatch-boundary`: use width differs from load width.
- `pick-load-signs-tee-boundary`: deliberately unsupported `local.tee` producer.
- `pick-load-signs-no-memory-boundary`: module-level no-memory skip.
- `pick-load-signs-imported-memory`: imported-memory positive candidate.

The former profile blind spots are gone: unsigned shifts are mutating, i64 cases are mutating and width-complete, and commuted-mask breadth is directly generated.

## Generator tests

`src/validate/gen_valid_tests.mbt` proves:

- profile and alias resolution;
- aggregate sampling of all 11 leaves;
- validation of every generated module;
- all five unsigned-shift regression shapes;
- right-hand/commuted i32 masks and i64 mask widths 8/16/32;
- i64 direct and signed-shift widths 8/16/32;
- deliberate skip/bailout surfaces.

## Expected compare behavior

The aggregate intentionally contains retained Starshine wins, so a fully green raw output comparison is not expected.

Final v131 dedicated lane:

- requested/compared: `10000/10000`;
- exact normalized matches: `6452`;
- measured Starshine-win mismatches: `3548`;
- validation/generator/property/command failures: `0`;
- Binaryen cache: `9987` hits / `13` misses.

The `3548` mismatches equal the selected counts of the three behavior-revealing leaves exactly:

- unsigned mask: `1762`;
- unsigned shift: `1225`;
- i64 watch: `561`.

Their representative generated modules are smaller after Starshine PLS:

- unsigned mask aggregate: `109` vs Binaryen `129` canonical bytes;
- unsigned shift aggregate: `105` vs `135`;
- i64 watch aggregate: `116` vs `137`.

Classify those mismatches as measured Starshine wins, not generic representation drift.

## Final lane commands

Use a current native release build and the official v131 executable:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass pick-load-signs --out-dir .tmp/pass-fuzz-pick-load-signs-v131-fix-genvalid-100000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin <binaryen-v131>/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass pick-load-signs --out-dir .tmp/pass-fuzz-pick-load-signs-v131-fix-wasm-smith-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin <binaryen-v131>/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass pick-load-signs --gen-valid-profile pick-load-signs-all --out-dir .tmp/pass-fuzz-pick-load-signs-v131-fix-profile-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin <binaryen-v131>/bin/wasm-opt --max-failures 10000 --no-reduce-mismatches --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass pick-load-signs --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-pick-load-signs-v131-fix-random-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin <binaryen-v131>/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

The saved wasm-smith mismatch should replay as cleanup-normalized with `--normalize unreachable-control-debris`; it has no PLS candidate pattern.
