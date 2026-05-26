# SGO startup and copy-chain closeout

## Scope

`[SGO]003G` follow-up for `simplify-globals-optimizing` startup-only propagation, single-use initializer folding, immutable copy-chain canonicalization, and segment/table initializer handling.

This slice does not broaden optimizer behavior. It audits the currently landed source-backed startup/copy-chain surface after `[SGO]003A` fact-table alignment and `[SGO]003F` typed element work, then closes the remaining `[SGO]003G` queue as accepted / evidence-gated for v0.1.0.

## Sources checked

- Active backlog: `agent-todo.md` `[SGO]003G`.
- SGO parity matrix startup, single-use, copy-chain, typed element, and nested-cleanup rows: `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`.
- Binaryen strategy and validation notes for startup propagation and single-use/copy-chain families:
  - `docs/wiki/binaryen/passes/simplify-globals-optimizing/binaryen-strategy.md`
  - `docs/wiki/binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md`
- Prior source-backed evidence:
  - `0580` active data/element offset propagation guardrails;
  - `0581` prefer-earlier immutable copy-chain lit regression;
  - `0582` nested GC initializer propagation;
  - `0584` through `0589` single-use GC initializer positives and negatives;
  - `0675` unified fact-table audit, including table/global/active data/active element/element-item read accounting;
  - `0696` exact-type typed element item-expression replacement;
  - `0697` typed element broadening guardrail closeout.
- Implementation and focused tests:
  - `src/passes/simplify_globals_optimizing.mbt`
  - `src/passes/simplify_globals_optimizing_test.mbt`

## Decision

Close `[SGO]003G` as accepted / evidence-gated for the currently source-backed v0.1.0 startup and copy-chain surface.

The supported surface is:

- startup constants propagate through later global initializers, active data offsets, active element offsets, and table initializer expressions using the module-startup constant table;
- passive data segments remain passive and are not rewritten as active offsets;
- imported global initializer provenance remains conservative;
- single-use global initializers fold only into later global initializer expressions, including the landed GC `struct.new(ref.i31(...))` lit families;
- second global use, function-code second use, imported source, and function-code-only single-use candidates remain conservative;
- immutable copy chains canonicalize to the earliest exact-type compatible ancestor in later global initializers and function bodies;
- subtype/refinalization-sensitive copy-chain widening remains conservative;
- exact-type typed element item expressions may rewrite only under the narrow `[SGO]003F` contract from `0696`/`0697`;
- startup-only rewrites do not mark functions touched and do not trigger the optimizing nested cleanup scheduler.

No fresh exact Binaryen-positive startup/copy-chain fixture remains in the active evidence set. Further broadening should require a new child slice with a specific Binaryen-positive fixture and paired guardrails, especially for subtype/refinalization-sensitive aliases, object-identity-sensitive GC initializers, descriptor-sensitive element expressions, or any startup rewrite that would imply function-body cleanup.

## Existing tests treated as closeout evidence

The closeout relies on already-landed focused tests in `src/passes/simplify_globals_optimizing_test.mbt`, including:

- `simplify-globals-optimizing propagates startup globals into data offsets without cleaning untouched functions`;
- `simplify-globals-optimizing follows Binaryen offsets lit for active segments`;
- `simplify-globals-optimizing follows Binaryen nested GC initializer lit`;
- `simplify-globals-optimizing canonicalizes immutable global copy chains`;
- `simplify-globals-optimizing follows Binaryen prefer-earlier copy-chain lit`;
- the single-use GC initializer positive and negative lit regressions;
- the exact typed element positives and refinalization/object-identity guardrails from `[SGO]003F`.

The implementation audit matched those tests to the current startup/copy-chain code paths:

- `sgo_rewrite_global_sec(...)` builds startup constants, rewrites later global initializers, records exact-type immutable aliases, and records single-use initializer inlines;
- `sgo_rewrite_table_sec(...)`, `sgo_rewrite_elem_sec(...)`, and `sgo_rewrite_data_sec(...)` apply startup constants to table initializers, active element offsets / exact typed element items, and active data offsets respectively;
- passive data modes and non-active element modes are preserved by construction;
- startup section rewrites happen before touched-function cleanup and do not add touched functions.

## Validation

No optimizer behavior or test expectation changed in this slice. No Moon or fuzz validation was required for the docs/backlog-only closeout.

Latest behavior-bearing validation for this surface remains the prior startup/copy-chain and typed-element lanes, including:

- `0580` through `0589` focused startup/single-use/copy-chain regression validation;
- `0696` full Moon validation and direct SGO fuzz with `0` mismatches and `0` Starshine validation failures;
- `0697` `moon test src/passes` and direct SGO fuzz at `.tmp/pass-fuzz-sgo-typed-element-guardrails-0697-10000`, with `0` mismatches and `0` Starshine validation failures.

## Remaining SGO boundary

`[SGO]003G` no longer carries an implicit active queue. Broader startup, copy-chain, and segment behavior is evidence-gated and should reopen only with exact Binaryen-positive evidence plus paired guardrails.

Still broader SGO work remains in `[SGO]003H`, `[SGO]004`, and `[SGO]005`.
