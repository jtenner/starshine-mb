# DAE003 structured carrier closeout

Date: 2026-05-26

## Scope

Close `[DAE003-F]` for the current v0.1.0 DAE surface after the structured-carrier sequence in notes `0644`, `0646`, `0647`, and `0649` through `0658`.

## Evidence

The current implementation accepts only structured constant carriers that are syntactically guaranteed to evaluate to the same materializable leaf without trapping or effectful/control-sensitive prefixes:

- single-leaf typed `block` carriers;
- equal-arm `if` carriers with identical materializable leaves, including dropped materializable prefixes and nested structured leaves;
- branch-free `loop` carriers with a materializable leaf, dropped materializable prefixes, or nested structured leaves;
- `try_table` bodies with a guaranteed materializable final leaf and only dropped materializable prefixes;
- recursively nested dropped-prefix carriers for `block`, `loop`, and `try_table` through the shared structured resolver.

The focused tests in `src/passes/dae_optimizing_test.mbt` cover the positive families above and the conservative guards for multi-instruction computed blocks, `local.tee`, earlier reads, multiple writes, trapping producers, effectful producers, self-recursive/escaped callees, and throwing-prefix `try_table` bodies.

## Decision

Treat `[DAE003-F]` as closed for v0.1.0. The remaining branchy/computed multi-instruction positives, broader throwing/control-sensitive `try` / `try_table` shapes, and unequal/control-sensitive `if` policies are not current DAE completion blockers. Reopen them only from a new artifact/fuzz frontier or semantic/validation repro that attributes a miss to one of those structured-carrier families.

This is a classification/docs closeout; no pass behavior changed in this note.

## Validation

Run in this recovery slice:

- `git diff --check` passed
- `moon info` passed
- `moon fmt` passed
- `moon test` passed (`3487` tests)

