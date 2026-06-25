---
kind: research
status: supported
date: 2026-06-25
sources:
  - ../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
---

# Code-pushing `br_on_non_null` loop-label boundary

## Question

Can the bounded one-result `br_on_non_null` movement added for block labels be widened to loop labels during `[O4Z-AUDIT-CP]`?

## Binaryen v130 probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe file: `.tmp/o4z-audit-cp-z/br-on-non-null-loop.wat`.

Command:

```sh
wasm-opt --all-features .tmp/o4z-audit-cp-z/br-on-non-null-loop.wat --code-pushing -S -o .tmp/o4z-audit-cp-z/br-on-non-null-loop.opt.wat
```

The reduced loop-label shape validates and Binaryen rewrites the loop-carried reference through a scratch/control wrapper, but it keeps the pure `local.set $x (i32.const 7)` before the `br_on_non_null` rather than sinking it after the loop-target branch. This differs from the earlier one-result block-label `br_on_non_null` probes, which moved the same kind of set after the branch.

## Starshine decision

Starshine should keep one-result loop-label `br_on_non_null` as a stationary boundary for now. This is a narrow, source-backed acceptance criterion, not a broad `br_on_*` closeout:

- block-label `br_on_non_null` movement remains implemented and covered;
- loop-label `br_on_non_null` movement is not enabled because the Binaryen v130 reduced probe did not move it;
- broader `br_on_*` loop-label, prefix-payload, and reference-carrying variants remain open unless separately probed.

## In-tree coverage

`src/passes/code_pushing_test.mbt` adds `code-pushing keeps loop-label br_on_non_null window stationary`, a HOT-level fixture that builds a one-result loop label and asserts the SFA `local.set` remains before `BrOnNonNull` after `code-pushing`.

Focused validation:

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*loop-label br_on_non_null*'
```

Result: `1/1` passed.

## Follow-up

Do not generalize this boundary to all loop-label `br_on_*` or prefix-payload forms. Probe each shape independently; the earlier `.tmp/o4z-audit-cp-y/br-on-non-null-prefix.wat` attempt hit a Binaryen transformed-output validation issue and is not source evidence for prefix-payload behavior.
