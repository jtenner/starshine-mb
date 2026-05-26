# SGO typed element guardrail closeout

## Scope

`[SGO]003F` follow-up for `simplify-globals-optimizing` reference / GC / typed-element breadth.

This slice does not broaden optimizer behavior. It audits the remaining typed element item-expression edge cases after the exact-type replacement slice in [`0696`](./0696-2026-05-26-sgo-exact-typed-element-replacement.md) and pins the conservative boundary with focused guardrails.

## Sources checked

- Active backlog: `agent-todo.md` `[SGO]003F`.
- Prior exact typed element implementation: `docs/wiki/raw/research/0696-2026-05-26-sgo-exact-typed-element-replacement.md`.
- SGO parity matrix typed element and GC/refinalization rows: `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`.
- Implementation and tests:
  - `src/passes/simplify_globals_optimizing.mbt`
  - `src/passes/simplify_globals_optimizing_test.mbt`

## Decision

Keep the `[SGO]003F` typed element boundary narrow for v0.1.0:

- rewrite only single-instruction typed element item expressions of the form `global.get <idx>`;
- require the replacement to be a startup constant for an immutable global;
- require exact value-type equality between the global value type and the typed element segment `RefType`;
- preserve nested/refinalization-sensitive item expressions such as `global.get; ref.as_non_null`;
- preserve object-identity-sensitive GC values such as `struct.new_default` globals;
- preserve less-refined aliases, descriptor-sensitive operations, and module-retagging-sensitive cases until a future exact Binaryen-positive fixture proves the broader rewrite legal.

This keeps typed element rewrites startup/module-only and avoids marking functions touched or triggering nested cleanup for segment-only changes.

## Tests

Added focused guardrails in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing keeps typed element refinalization expressions conservative` pins a typed element item expression where a nullable function global feeds `ref.as_non_null`; function-body reads may still rewrite through normal SGO replacement, but the element expression remains unchanged because it is not a single exact-type item.
- `simplify-globals-optimizing keeps object-identity typed element globals conservative` pins an exact typed element item that reads a `struct.new_default` global; SGO preserves the global read and initializer rather than duplicating object allocation into the element expression.

A small test helper was added to inspect multi-instruction typed element item expressions while preserving the existing single-instruction helper used by exact positives.

## Validation

- `moon test src/passes`: passed, `1644/1644`.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-typed-element-guardrails-0697-10000` reported `6759/10000` compared before the configured command-failure stop, `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, `0` generator failures, and `20` command failures.

## Mismatch classification

The direct SGO fuzz lane reported no mismatches and no Starshine validation failures. The 20 command failures are classified as tool/Binaryen failures under the existing compare-pass lane because comparison stopped at the configured command-failure limit without a Starshine output validation failure or semantic mismatch.

## Remaining `[SGO]003F` boundary

Typed element broadening is now evidence-gated rather than an implicit active queue. Reopen this area only with a fresh exact Binaryen-positive fixture and paired guardrails for the specific type/refinalization or object-identity family being changed.

Still broader SGO work remains in `[SGO]003G`, `[SGO]003H`, `[SGO]004`, and `[SGO]005`.
