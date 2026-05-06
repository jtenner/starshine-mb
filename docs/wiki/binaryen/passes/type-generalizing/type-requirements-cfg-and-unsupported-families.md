---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-04-27-type-generalizing-primary-source-correction.md
  - ../../../raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md
  - ../../../raw/binaryen/2026-05-05-type-generalizing-current-main-recheck.md
  - ../../../raw/research/0479-2026-05-05-type-generalizing-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-type-generalizing-current-main-recheck.md
  - ../../../raw/research/0497-2026-05-06-type-generalizing-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
supersedes:
  - ./local-flow-type-floor-and-boundaries.md
---

# Type requirements, CFG analysis, and unsupported families in `type-generalizing`

## Why this page exists

The hard part of Binaryen `experimental-type-generalizing` is not a single WAT rewrite. It is the proof that a local declaration can become more general while every use still accepts the new type. A 2026-05-06 current-main recheck left that contract unchanged on the reviewed surfaces.

The 2026-04-24 page `local-flow-type-floor-and-boundaries.md` framed the pass as local-set/local-tee evidence plus a drop-plus-zero `local.get` workaround. That model is superseded. The source-correct model is backward type-requirement analysis over a function CFG.

## Requirement model

Think of each use as asking for a minimum type requirement:

- a function return asks for the declared result type;
- a call asks for the callee's parameter types;
- a global set asks for the global's declared value type;
- a struct set asks for the field's declared type;
- a table set asks for the table element type;
- a `ref.cast` / `ref.test` asks for the cast/test operand shape needed for the operation.

The solver propagates those requirements backward through the CFG to the locals and stack values that feed the uses.

## Why CFG matters

Straight-line local evidence is not enough because a local may be set on one path and used on another. The pass therefore builds a function CFG and solves requirements across block edges.

At control-flow joins, the solver must conservatively combine requirements from every successor. A local can only be generalized if all paths allow the generalized type.

## Entry and exit anchors

Entry and exit prevent the analysis from floating everything to top:

- Params are anchored to their original declared types at function entry.
- Non-reference locals are anchored to original types.
- Function results are anchored to the declared result type at exit.
- Reference locals can be generalized only within the constraints that uses impose.

This is why the pass changes local declarations but not function signatures.

## `ContentOracle` role

Some type requirements depend on possible runtime contents, not only the static instruction syntax. The owner file uses `ContentOracle`-style facts for families such as calls, globals, tables, refs, and GC aggregate operations.

This does not make the pass a broad `gufa` clone. The output is still local declaration and local get/tee type repair. But the analysis is oracle-assisted, and the old “no oracle” model is wrong.

## Important transfer families

| Family | What it constrains |
| --- | --- |
| `local.get` | the local must satisfy the type required at this use |
| `local.set` | the set value must satisfy the local's later requirements |
| `local.tee` | both a set and a value-producing use; its expression result must be repaired if the local type changes |
| direct `call` | arguments must satisfy callee parameter types; results feed caller stack requirements |
| `call_ref` | target and arguments must satisfy compatible function-reference signature requirements |
| globals | gets/sets tie local flow to global declaration types |
| tables | table get/set/copy/fill/init/grow/size impose element, index, and value constraints |
| `select` / `drop` | stack requirement propagation through ordinary expression consumers |
| ref ops | nullability, cast/test, `ref.func`, and reference equality constraints |
| struct ops | object, descriptor, field read/write, constructor, and related GC aggregate constraints |
| array ops | element type, index, length, copy/fill/init/new, and aggregate constraints |

## Unsupported and risky families

The official source contains explicit TODO or unreachable handling for multiple features. The important teaching rule is: do not infer support just because Starshine or Binaryen supports the instruction elsewhere, and do not assume a transfer rule for one instruction family implies the same treatment for neighboring GC or control-flow forms.

Treat these as blockers for a faithful Starshine port unless the upstream source changes or the local port deliberately defines a narrower subset:

- exception handling forms;
- tuple forms;
- string forms;
- continuation/stack-switching forms;
- some branch-on and stack-pop paths;
- atomic struct/array operations and wait/notify/RMW/cmpxchg families.

Because upstream itself marks the pass not-yet-sound, Starshine should prefer explicit skips and tests over optimistic handling.

## Rewrite boundary

After solving requirements, the pass writes generalized types to non-param local declarations. It does not directly rewrite every instruction that contributed a requirement.

The visible expression repair is narrow:

- update `local.get` result types to match changed local declarations;
- update `local.tee` result types to match changed local declarations;
- run refinalization when those expression result types changed.

## Beginner trap checklist

Avoid these common mistakes:

- **Mistake:** “`local.set` evidence alone decides the new type.”  
  **Correction:** uses impose requirements backward through the CFG.
- **Mistake:** “`local.get` is replaced by drop-plus-zero.”  
  **Correction:** source retags local get/tee result types after declaration changes.
- **Mistake:** “No `call_ref` / GC surface.”  
  **Correction:** `call_ref`, struct, and array families are explicit transfer surfaces.
- **Mistake:** “Hidden test pass means safe but undocumented.”  
  **Correction:** upstream labels it not yet sound; unsupported families are correctness hazards.

## Starshine implication

A future Starshine port should begin with an analyzer that can produce proposed local type requirements and explain unsupported-family skips. Mutation should come later, after local declaration rewriting, local-use repair, refinalization/validation, and Binaryen comparison fixtures are in place.
