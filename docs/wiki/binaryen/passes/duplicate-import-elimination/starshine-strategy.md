---
kind: concept
status: strong
last_reviewed: 2026-07-28
sources:
  - ../../../raw/binaryen/2026-07-28-duplicate-import-elimination-v131-refresh.md
  - ./index.md
  - ./fuzzing.md
  - ../../../../../src/passes/duplicate_import_elimination.mbt
  - ../../../../../src/passes/duplicate_import_elimination_test.mbt
  - ../../../../../src/passes/legacy_eh_audit_wbtest.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/fuzz/main.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ./fuzzing.md
  - ../duplicate-function-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine strategy for `duplicate-import-elimination`

## Status

`duplicate-import-elimination` is an active Starshine module pass and is closed for direct Binaryen `version_131` behavior parity. The 2026-07-28 renewal was required after legacy-`try` decoding and raw-name invalidation repairs; it found no remaining pass-owned mismatch.

Current source evidence is especially strong:

- Binaryen v131's owner, `OptUtils::replaceFunctions` helper, and dedicated input fixture are byte-identical to the retained v130 versions.
- Starshine's refreshed five-leaf GenValid aggregate covers every released detection, rewrite, removal, EH, module-code, metadata, and non-function boundary family.
- The required v131 matrix completed regular `100000`, dedicated `10000`, random-all `10000`, and wasm-smith `10000` requests.
- Every dedicated family normalized exactly to Binaryen.

## Local code map

- transform owner: [`src/passes/duplicate_import_elimination.mbt`](../../../../../src/passes/duplicate_import_elimination.mbt)
- focused and generated-family tests: [`src/passes/duplicate_import_elimination_test.mbt`](../../../../../src/passes/duplicate_import_elimination_test.mbt)
- decoded legacy-EH recursive rewrite test: [`src/passes/legacy_eh_audit_wbtest.mbt`](../../../../../src/passes/legacy_eh_audit_wbtest.mbt)
- registry and public preset references: [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- module-pass dispatch: [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- family generators and aggregate: [`src/validate/gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt)
- generator assertions: [`src/validate/gen_valid_tests.mbt`](../../../../../src/validate/gen_valid_tests.mbt)
- manifest family labels: [`src/fuzz/main.mbt`](../../../../../src/fuzz/main.mbt)
- manifest coverage test: [`src/fuzz/main_wbtest.mbt`](../../../../../src/fuzz/main_wbtest.mbt)

## Transform-family analysis

| Family | Binaryen v131 contract | Starshine implementation and evidence | Verdict |
| --- | --- | --- | --- |
| imported-function scope | iterate `ImportInfo.importedFunctions` only | scan only `FuncExternType` imports; duplicate globals/tables/memories/tags aggregate leaf remains byte-for-byte unchanged | exact match |
| identity bucket | exact `(module, base)` strings | NUL-delimited exact string key; different-module and different-base variants preserve imports | exact match |
| exact type gate | compare current representative `Function::type` | resolve each `TypeIdx` to `FuncType`; equal structural types under distinct type indices merge | exact match |
| representative reset | type mismatch replaces the current bucket representative | mixed `(i32), (), ()` family keeps the first two and merges the third into the second | exact match |
| direct body references | rewrite `Call.target` and `RefFunc.func` | rewrites `call`, `return_call`, and `ref.func` recursively through root, block, loop, and both `if` arms | exact match; `return_call` is the numeric-IR counterpart of Binaryen's direct-call family |
| legacy EH | Binaryen walker reaches decoded expression children | recursively rewrites protected bodies, typed catches, catch-all bodies, and delegate-bearing nested `try` while preserving tags, catch order, catch-all form, block type, and delegate target | exact match in every dedicated EH label |
| `try_table` | walker reaches the protected body; catch descriptors contain no function names | rewrites the body and preserves all catch descriptors | exact match |
| module code | `runOnModuleCode` rewrites `call`/`ref.func` expression trees | rewrites global/table initializers, element expressions, function-index element payloads, and active offset expressions where function refs are representable | exact match in the module-code leaf |
| start and exports | rewrite `module.start` and function exports | remap numeric `FuncIdx` targets; preserve external export names | exact match |
| duplicate removal | remove every later duplicate after retargeting | remove duplicate function imports and shift all later defined function indices | exact match |
| names | Binaryen updates internal names through its named IR | remap structured function/local/label name owners and clear stale raw name bytes on the changed path | representation-preserving Starshine requirement; no size regression retained |
| function annotations | Binaryen stores annotations on named functions | drop removed alias entries and shift surviving defined-function annotation owners | representation-preserving Starshine requirement |
| unchanged path | no replacement map means no mutation | return the original module directly, preserving raw bytes and metadata | exact no-op behavior |
| idempotence | second run finds no later duplicate | generated-family test requires second Starshine run to equal the first result | exact fixed point |

No pass-owned family is classified as a Starshine-only representation win. Matching Binaryen's output shape is preferred here because the upstream transform is already small and canonical. Starshine-specific work is limited to preserving the same semantics in a numeric-index IR and maintaining metadata that Binaryen's named in-memory IR does not expose in the same form.

## Correctness invariants

The pass must preserve:

- import order for every surviving declaration;
- current-representative semantics after a type mismatch;
- exact function signatures;
- defined-function declaration/code alignment;
- every absolute `FuncIdx` after imported-prefix shrinkage;
- start target and function export targets;
- element order, mode, reference type, and payload shape;
- legacy protected/catch structure, tag order, catch-all form, delegate target, and block type;
- `try_table` catch descriptors;
- structured name and function-annotation ownership;
- unchanged-path raw binary reuse.

## Profile and matrix result

The refreshed aggregate has leaves for body references, identity, module code, legacy EH, and non-function negatives. The 10,000-case dedicated lane selected every leaf and every case label and normalized `10000/10000` with zero failures.

The complete matrix is in [`fuzzing.md`](./fuzzing.md). Its only raw residuals are pass-independent:

- 625 random-all `remove-unused-brs-control` modules with no imports and an already-owned one-byte local-run canonicalization loss;
- one wasm-smith module with no function imports and unreachable-control debris, confirmed by the existing normalizer;
- 44 Binaryen/tool command failures, with zero Starshine command or validation failures.

These residuals do not justify a DIE representation divergence and do not hide a DIE opportunity.

## Performance

The implementation owner did not change during this renewal. Retained direct timing fixtures remain faster than Binaryen:

- import-heavy: `0.447 ms` Starshine versus `2.00646 ms` Binaryen (`0.223x`)
- user-heavy: `0.2835 ms` Starshine versus `0.946297 ms` Binaryen (`0.300x`)

Re-run timing if the planner, recursive rewrite, or metadata repair complexity changes.

## Scheduler boundary

Direct behavior is closed. Exact O4z late-preset reconciliation remains owned by `[O4Z-PRESET]001`, not by this pass. The canonical neighborhood remains:

`duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements`

Do not reopen direct DIE merely because a broader neighborhood has an independently owned shape difference.

## Reopening criteria

Reopen direct DIE if:

- Binaryen begins deduplicating a non-function import kind;
- upstream changes the bucket/type/representative rule;
- any pass-owned dedicated family stops normalizing exactly;
- a duplicate function-import case fails validation or retains an unclassified shape difference;
- legacy EH, `try_table`, module-code, metadata, start/export, or defined-index remapping regresses;
- the unchanged path mutates bytes or metadata;
- pass-local performance exceeds Binaryen under the retained fixture method.
