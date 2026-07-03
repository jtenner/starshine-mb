---
kind: workflow
status: working
last_reviewed: 2026-07-03
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `local-subtyping` Fuzzing Profile

Recommended ordinary mixed-generator smoke lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile: `local-subtyping-all`.

`local-subtyping-all` is a small aggregate dedicated profile for LS closeout and development smokes. It deterministically samples two leaf profiles:

- `local-subtyping-straight-line` (weight 3): emits a nullable `anyref` body local, non-null `struct.new_default` writes through `local.set` and `local.tee`, and dominated straight-line `local.get` reads that should let `local-subtyping` narrow the body-local declaration.
- `local-subtyping-structured` (weight 2): emits the same nullable body local and non-null write, then reads it inside branch-free `block`, `loop`, and `if` regions plus an outer dominated get. This exercises the source-backed structured dominance subsets without catch/ref EH, branch-carried post-state, direct-return validator-boundary, or broad join propagation.

Aliases: `local-subtyping`, `local-subtyping-closeout`, `local-subtyping-all-profiles`, `ls`, and `ls-closeout` resolve to `local-subtyping-all`.

Ordinary dedicated-profile lane for final LS closeout:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-subtyping --gen-valid-profile local-subtyping-all --out-dir .tmp/pass-fuzz-local-subtyping-genvalid-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

The compare manifest records `selected_profile` for aggregate cases; report selected counts for `local-subtyping-straight-line` and `local-subtyping-structured` separately when using this lane.
