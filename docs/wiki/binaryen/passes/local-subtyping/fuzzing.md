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

Current closeout-scale evidence after adding the unreachable-tail leaf:

- Regular GenValid lane `.tmp/pass-fuzz-local-subtyping-genvalid-100000-20260703` used seed `0x5eed`, requested/compared `100000/100000`, normalized `100000`, had zero cleanup-normalized matches, mismatches, validation failures, generator failures, property failures, or command failures, and used Binaryen cache `1326` hits / `98674` misses.
- Explicit wasm-smith lane `.tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260703` used seed `0x5eed`, requested `10000`, compared `9956`, normalized `9955`, had zero validation/generator/property failures, `44` Binaryen/tool command failures, and one raw mismatch. The command failures classified as Binaryen rec-group-zero `39`, invalid tag index `1`, table index out of range `1`, and bad section size `3`. The sole raw mismatch, `case-009332-wasm-smith`, is agent-classified as pass-independent unreachable-control cleanup debris: Binaryen removes `drop(unreachable)` before a final `unreachable`, while Starshine leaves it, producing a size-losing Starshine artifact (`79` bytes versus Binaryen `77`). It is not an LS semantic mismatch or Starshine win.
- Cleanup-normalized wasm-smith replay `.tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260703-unreachable-normalized` used the same seed and added `--normalize unreachable-control-debris`; it requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized the one debris case, had zero mismatches, zero validation/generator/property failures, and the same `44` Binaryen/tool command failures. Treat the debris case as a precise shared cleanup/normalizer blocker with LS reopening criteria: reopen under LS only if a reduced case shows the drift depends on LS local narrowing, get/tee retagging, dominance, or refinalization.
- Dedicated LS profile lane `.tmp/pass-fuzz-local-subtyping-genvalid-all-10000-unreachable-profile` used seed `0x5eed`, requested/compared `10000/10000`, normalized `10000`, had zero compare-normalized matches, mismatches, validation failures, generator failures, property failures, or command failures, and used Binaryen cache `9984` hits / `16` misses. Selected profiles were `local-subtyping-straight-line=5030`, `local-subtyping-structured=3296`, and `local-subtyping-unreachable-tail=1674`.
- Broad random-all-profiles lane `.tmp/pass-fuzz-local-subtyping-random-all-profiles-10000-unreachable-profile` used seed `0x5555`, requested/compared `10000/10000`, normalized `10000`, had zero compare-normalized matches, mismatches, validation failures, generator failures, property failures, or command failures, and used Binaryen cache `3218` hits / `6782` misses. Selected profiles were `coverage-forced-portable=1446`, `binaryen-oracle-portable=1423`, `pass-fuzz-stress=1425`, `heap2local-array=1400`, `local-subtyping-straight-line=714`, `local-subtyping-structured=466`, `local-subtyping-unreachable-tail=219`, `ssa-nomerge-smoke=1447`, and `ssa-nomerge-parity=1460`.
- Ordered GC/local neighborhood attempt `.tmp/pass-fuzz-local-subtyping-gc-local-neighborhood-10000-20260703` ran `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` at seed `0x5eed`, but timed out after 3600s before summary emission. The partial manifest had `200` cases, `18` matches, and `182` mismatches. A sampled mismatch shows downstream local declaration/count drift after the multi-pass neighborhood rather than direct LS narrowing behavior, so ordered-neighborhood closeout remains blocked on a smaller neighborhood strategy or downstream local-cleanup parity/performance.
