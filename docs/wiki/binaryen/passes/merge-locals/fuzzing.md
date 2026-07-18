---
kind: workflow
status: supported
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeLocals.cpp
  - ../../../raw/research/1574-2026-07-18-merge-locals-v131-parity-closeout.md
  - ../../../../../src/validate/gen_valid.mbt
---

# `merge-locals` fuzzing profiles

Use `merge-locals-all` for the dedicated closeout lane. It deterministically samples seven family-owned leaves and records each selected leaf plus a case label in the manifest.

| Profile | Family |
| --- | --- |
| `merge-locals-forward` | source uses retarget to the copy destination |
| `merge-locals-reverse` | destination uses retarget to the source after forward orientation is blocked by a merge |
| `merge-locals-control` | CFG influence through block, if, and loop shapes |
| `merge-locals-tee` | `local.tee` copy candidates |
| `merge-locals-merge-boundary` | multi-source/phi rejection and post-check behavior |
| `merge-locals-type-boundary` | exact type equality with a GC strict-subtype negative |
| `merge-locals-rollback` | target clobber detected by the post graph |

Dedicated signoff:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass merge-locals \
  --gen-valid-profile merge-locals-all \
  --out-dir .tmp/pass-fuzz-merge-locals-profiles-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The 2026-07-18 v131 closeout completed `10000/10000` dedicated cases and selected every leaf with zero mismatches or failures. Regular GenValid completed `100000/100000`; random all profiles completed `10000/10000`.

The wasm-smith lane compared `9956/10000`, with `44` Binaryen/tool command failures and one no-copy codec-baseline mismatch. Starshine no-pass and `--merge-locals` bytes are identical for that case, so it belongs to `[TOOL]001`, not pass behavior. See research note `1574` for the exact hash and classification.
