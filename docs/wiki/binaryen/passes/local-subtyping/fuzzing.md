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

`local-subtyping-all` is a small aggregate dedicated profile for LS closeout and development smokes. It deterministically samples three leaf profiles:

- `local-subtyping-straight-line` (weight 3): emits a nullable `anyref` body local, non-null `struct.new_default` writes through `local.set` and `local.tee`, and dominated straight-line `local.get` reads that should let `local-subtyping` narrow the body-local declaration.
- `local-subtyping-structured` (weight 2): emits the same nullable body local and non-null write, then reads it inside branch-free `block`, `loop`, and `if` regions plus an outer dominated get. This exercises the source-backed structured dominance subsets without catch/ref EH, branch-carried post-state, direct-return validator-boundary, or broad join propagation.
- `local-subtyping-unreachable-tail` (weight 1): emits a dominating non-null write, a dominated read, a root `return`, and a later syntactic read in unreachable tail code. This makes the root return/unreachable-tail subset visible in generated closeout lanes without widening to direct block-return validator-boundary cases or tail-call/table setup.

Aliases: `local-subtyping`, `local-subtyping-closeout`, `local-subtyping-all-profiles`, `ls`, and `ls-closeout` resolve to `local-subtyping-all`.

Ordinary dedicated-profile lane for final LS closeout:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-subtyping --gen-valid-profile local-subtyping-all --out-dir .tmp/pass-fuzz-local-subtyping-genvalid-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

The compare manifest records `selected_profile` for aggregate cases; report selected counts for `local-subtyping-straight-line`, `local-subtyping-structured`, and `local-subtyping-unreachable-tail` separately when using this lane.

Current evidence after adding the unreachable-tail leaf:

- Dedicated LS profile lane `.tmp/pass-fuzz-local-subtyping-genvalid-all-10000-unreachable-profile` used seed `0x5eed`, requested/compared `10000/10000`, normalized `10000`, had zero compare-normalized matches, mismatches, validation failures, generator failures, property failures, or command failures, and used Binaryen cache `9984` hits / `16` misses. Selected profiles were `local-subtyping-straight-line=5030`, `local-subtyping-structured=3296`, and `local-subtyping-unreachable-tail=1674`.
- Broad random-all-profiles lane `.tmp/pass-fuzz-local-subtyping-random-all-profiles-10000-unreachable-profile` used seed `0x5555`, requested/compared `10000/10000`, normalized `10000`, had zero compare-normalized matches, mismatches, validation failures, generator failures, property failures, or command failures, and used Binaryen cache `3218` hits / `6782` misses. Selected profiles were `coverage-forced-portable=1446`, `binaryen-oracle-portable=1423`, `pass-fuzz-stress=1425`, `heap2local-array=1400`, `local-subtyping-straight-line=714`, `local-subtyping-structured=466`, `local-subtyping-unreachable-tail=219`, `ssa-nomerge-smoke=1447`, and `ssa-nomerge-parity=1460`.
