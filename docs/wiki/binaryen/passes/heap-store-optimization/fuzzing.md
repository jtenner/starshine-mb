---
kind: workflow
status: working
last_reviewed: 2026-06-24
sources:
  - ../../../raw/research/1023-2026-06-24-heap-store-optimization-genvalid-profile.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt
---

# `heap-store-optimization` Fuzzing Profile

Recommended ordinary mixed-generator smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: `heap-store-optimization` (alias: `hso`). It emits valid GC modules with deterministic HSO-owned opportunities:

- block-local `local.set(struct.new)` followed by same-local `struct.set`;
- immediate `local.tee(struct.new)` stores;
- repeated same-field stores where the final value wins.

Recommended dedicated-profile smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-profile-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Use `--normalize local-cleanup-debris` for this profile while Starshine removes folded-store `nop` roots that Binaryen retains. Research note `1023` classified the initial 20-case raw mismatch family as a Starshine-win cleanup drift: Binaryen output kept `(nop)` placeholders after HSO folds, while Starshine emitted smaller validated output without those dead roots.

Manifest triage fields:

- `config_label`: `heap-store-optimization` for direct requests;
- `selected_profile`: `heap-store-optimization` because this is currently a leaf profile;
- `facts.has_gc_constructors` and `facts.has_gc_accessors`: expected true for emitted profile cases.

If future HSO work adds descriptor/control-flow/store-barrier generators, either extend this profile or introduce a composite `heap-store-optimization-all` profile and update the closeout command here.
