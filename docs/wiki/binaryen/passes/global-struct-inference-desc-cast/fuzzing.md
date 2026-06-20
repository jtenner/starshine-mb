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

Interpretation: this is useful direct-pass smoke/signoff for the public pass spelling and the inherited non-closed-world ordinary-GSI behavior. It is **not** final parity evidence for the positive descriptor-cast surface because the ordinary lane does not force closed-world singleton descriptor-cast shapes.

Dedicated GenValid profile: none documented for this pass yet.

Needed future profile: a closed-world descriptor-cast profile that generates target types with descriptor metadata, singleton / zero / multiple descriptor globals, strict-subtype and no-strict-subtype variants, nullable casts, and exact-target casts.

If a future audit adds that pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage.
