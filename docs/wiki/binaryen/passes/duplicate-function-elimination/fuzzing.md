---
kind: workflow
status: working
last_reviewed: 2026-08-26
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `duplicate-function-elimination` Fuzzing Profile

Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --out-dir .tmp/pass-fuzz-duplicate-function-elimination --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: none documented for this pass yet.

## 2026-08-21 final16 transitive type-remap development lane

After repairing recursive indexed references inside retained compacted function types, the authoritative pinned-v131 command was:

```sh
bun fuzz compare-pass --pass duplicate-function-elimination --count 10000 --seed 0x5eed --max-failures 2000 --keep-going-after-command-failures --jobs auto --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/dfe-transitive-type-remap-v131-10000-20260821
```

Results:

- requested / compared: 10,000 / 10,000
- normalized matches: 9,942
- raw mismatches: 58
- validation failures: 0
- property failures: 0
- generator failures: 0
- command failures: 0
- Binaryen cache: 2 hits / 9,998 misses

All 58 raw mismatch inputs replay as raw mismatches with the exact final14-era baseline binary in `.tmp/dfe-transitive-type-remap-final14-mismatch-replay-20260821/`. They therefore predate the transitive kept-type repair. This replay classifies only introduction provenance; the current raw residual families remain open until inspected and must not be called semantically safe merely because both outputs validate.

The lane is development evidence, not a fresh full four-lane DFE closeout. DFE still has no dedicated pass-owned GenValid profile for transitive duplicate-type/reference chains.

## 2026-08-26 fixed-partition performance checkpoint

The accepted serial DFE checkpoint renewed the pinned-v131 ordinary lane with bounded host pressure:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --out-dir .tmp/pass-fuzz-dfe-fixed-partition-regular-10000 --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Results:

- requested / compared: 10,000 / 10,000
- normalized matches: 9,942
- raw mismatches: 58
- validation, property, generator, and command failures: 0
- canonical sizes: 42,076,533 Starshine bytes versus 42,076,677 Binaryen bytes
- canonical smaller / equal / larger: 58 / 9,942 / 0
- mismatch artifacts: 20 persisted and 38 suppressed under the explicit cap

The counts and canonical-smaller-only residual family match the documented August 21 baseline, so this performance slice introduces no new parity or size-loss family.

The runtime-callable self-semantic lane used the same seed and explicit subprocess/artifact caps under `.tmp/pass-fuzz-dfe-fixed-partition-runtime-100`:

- checked / matched: 100 / 100
- blocked / mismatching: 0 / 0
- validation, property, generator, and command failures: 0
- canonical sizes: exactly equal on all 100 cases

DFE still has no dedicated pass-owned GenValid profile. If a future audit adds one, update this page with the profile name, intended smoke/closeout count, required features or normalizers, and the manifest fields needed for replay triage.
