# SGO exact typed element replacement

## Scope

`[SGO]003F` child slice for `simplify-globals-optimizing` reference / GC / typed-element breadth.

This slice widens the previously conservative typed element item-expression behavior only for exact-type immutable global constants. It does not implement broad type-changing element rewrites, less-refined aliases, object-identity-sensitive GC duplication, descriptor operations, or module-wide retagging-sensitive replacements.

## Sources checked

- Active backlog: `agent-todo.md` `[SGO]003F`.
- Prior parser/refinalization prerequisite: `docs/wiki/raw/research/0695-2026-05-25-sgo-ref-cast-parser-and-fixture.md`.
- Parity matrix rows for reference replacements and typed element item-expression preservation: `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`.
- Implementation and tests:
  - `src/passes/simplify_globals_optimizing.mbt`
  - `src/passes/simplify_globals_optimizing_test.mbt`

## Change

- Added a narrow typed element item-expression rewrite helper.
- The helper rewrites only single-instruction typed element expressions of the form `global.get <idx>`.
- The target global must have a value type exactly equal to the typed element segment's `RefType` (`ValType::ref_type(elem_rt)`).
- The replacement must already be available as a startup constant after global-initializer rewriting, so exact immutable aliases rewritten to constants are covered.
- All non-exact ref types, non-constant globals, nested expressions, and broader element expressions remain unchanged.
- Element rewrites are startup/module rewrites only and do not mark touched functions or trigger nested cleanup.

## Tests

Updated the existing conservative typed-element tests into exact-type positives:

- `simplify-globals-optimizing rewrites exact ref-func typed element item expressions`
- `simplify-globals-optimizing rewrites exact ref-func typed element aliases`

The older non-exact reference item-expression guardrail remains unchanged and still preserves a `global.get` when the global type and element item type differ.

## TDD evidence

Before implementation, `moon test src/passes` failed the two updated positives:

- expected `RefFunc(FuncIdx(0))` but got `GlobalGet(GlobalIdx(0))` for the direct exact ref-func typed element item;
- expected `RefFunc(FuncIdx(0))` but got `GlobalGet(GlobalIdx(1))` for the exact alias item.

After implementation:

- `moon test src/passes` passed: `1642/1642` with only existing DAE/pass-manager unused warnings.
- `moon fmt` passed.
- `moon info` passed with existing DAE unused warnings.
- Full `moon test` passed: `3718/3718`.
- Direct SGO fuzz passed the slice criteria at `.tmp/pass-fuzz-sgo-typed-elem-exact-0696-10000`: `6759/10000` compared before the configured 20 Binaryen/tool command-failure stop, `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, `0` generator failures, and `20` Binaryen/tool command failures.

## Mismatch classification

The direct SGO fuzz lane reported no mismatches and no Starshine validation failures. The 20 command failures are classified as tool/Binaryen failures under the existing compare-pass lane because comparison stopped at the configured command-failure limit without a Starshine output validation failure or semantic mismatch.

## Remaining `[SGO]003F` boundary

Still open:

- broader typed element replacement where the replacement is a subtype or otherwise requires type/refinalization proof;
- less-refined alias widening;
- object-identity-sensitive GC allocation duplication;
- descriptor operations;
- `struct.new_default` duplication;
- subtype changes needing module-wide retagging;
- any replacement that would invalidate element/table/global types.
