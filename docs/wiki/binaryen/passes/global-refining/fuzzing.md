---
kind: workflow
status: working
last_reviewed: 2026-08-20
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `global-refining` Fuzzing Profile

## 2026-08-20 ref.func indexed-type correction

Native SHA-256 `b536e6105356d6b51dc10c7954047c933159dd46809b7c47566f979198a91093` corrects the local ref.func fact model. Pinned Binaryen v131 and `wasm-tools` treat `ref.func` as a non-null indexed function reference `(ref $type)`, not `(ref (exact $type))`. The former exact initializer/write facts could refine a mutable global to an exact type while its initializer or later `global.set` still produced a non-exact reference, yielding an externally invalid module. Initializer seeding and HOT `global.set` collection now share the same non-exact indexed fact helper; GC allocation constructors remain exact.

The direct `ref_func.1` replay now validates externally. A validated O4z continuation `global-refining -> optimize-instructions -> precompute -> duplicate-function-elimination` folds the resulting non-null `ref.is_null` function and reduces 231 → 225 bytes, byte-identical to Binaryen. Fresh-instance mutation and indirect-call probes preserve all `is_null`, `set-f`, `set-g`, `call-f`, `call-g`, and `call-v` behavior.

Renewed ordinary GenValid artifact `.tmp/pass-fuzz-global-refining-ref-func-indexed-10000` uses explicit `.tmp/binaryen-version-131-bin/bin/wasm-opt`: 10,000/10,000 compared, 10,000 normalized matches, zero mismatches, and zero validation/property/generator/command failures. Binaryen cache counters are 2 hits / 9,998 misses. This remains repair evidence rather than a complete four-lane closeout because no pass-owned dedicated profile exists yet.

Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-refining --out-dir .tmp/pass-fuzz-global-refining --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The 2026-08-20 nominal sibling-join repair used `.tmp/pass-fuzz-global-refining-sibling-join-10000` with this command shape: 10,000/10,000 compared, 10,000 normalized matches, zero mismatches, zero validation/property/generator/command failures, and Binaryen cache 2 hits/9,998 misses.

Dedicated GenValid profile: none documented for this pass yet. This repair did not declare final pass closeout; a future closeout still needs a pass-owned profile that deliberately generates declared sibling subtype joins, plus the full four-lane matrix.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage.
