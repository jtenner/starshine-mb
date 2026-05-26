# DAE004 type-liveness coverage

Date: 2026-05-26

## Scope

Close `[DAE004-G]` by adding focused coverage for DAE's unused-simple-function-type pruning when simple function types are referenced outside function-section signatures.

## Evidence

The existing implementation in `src/passes/dead_argument_elimination.mbt` already marks and rewrites simple function type references from table types, global types and global initializers, element segment reference types and expressions, code locals, and instruction-level ref/type operations before pruning unused simple function types.

This slice adds the missing focused regression in `src/passes/dae_optimizing_test.mbt`:

- existing coverage already kept simple function types referenced by table and global refs;
- new coverage keeps a simple function type referenced by a typed element segment, a local declaration, and `ref.null` body/element expressions;
- both input and DAE output are validated with `@validate.validate_module`.

No optimizer behavior changed. The task is coverage/closure for the documented type-liveness guardrail.

## Validation

- `moon test src/passes` passed (`1392` tests).

## Backlog result

`[DAE004-G]` is closed. `[DAE]004` remains open on `[DAE004-D]`, `[DAE004-H]`, and `[DAE004-I]`: selected fallback removal still needs artifact tracing, validation, timing, direct compare evidence, and mismatch classification proving no remaining dropped-result scheduling gap.
