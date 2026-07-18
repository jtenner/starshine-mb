---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp
  - ./index.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./type-requirements-cfg-and-unsupported-families.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../gufa/index.md
  - ../type-refining/index.md
supersedes:
  - ./index.md
---

# Binaryen `type-generalizing` strategy

## Source rule

Use the 2026-07-11 `version_130` / current-main source recheck as the corrected oracle for this folder. It supersedes the older captures' unsupported `ContentOracle` claim while retaining their CFG/local-rewrite findings:

- [Binaryen current-main `TypeGeneralizing.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp)
- [research note 0421](./index.md)
- [research note 0479](./index.md)

The main official sources are Binaryen `version_129` and current `main`:

- `src/passes/TypeGeneralizing.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-generalizing.wast`

Specific current-main locations that teach the contract:

- [`TypeGeneralizing.cpp#L3733-L3773`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp#L3733-L3773) for nested DCE, CFG build, backward analysis, local rewrite, and refinalization.
- [`TypeGeneralizing.cpp#L3777-L3795`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp#L3777-L3795) for `local.get` and `local.tee` repair.
- [`pass.cpp#L3348-L3352`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L3348-L3352) for the hidden test-pass registration and "not yet sound" description.
- [`type-generalizing.wast#L3803-L3919`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-generalizing.wast#L3803-L3919) for the `call_ref` parameter/result/impossible families.
- [`type-generalizing.wast#L3961-L4017`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-generalizing.wast#L3961-L4017) for struct constructor and struct-read coverage.

The 2026-07-11 recheck found no behavior-bearing divergence between the inspected `version_130` and current-main owner, registration, and fixture surfaces.

The consumed 2026-04-24 source capture is superseded for mechanics. Its historical role explains why the dossier was corrected twice, but current pages must use the retained correction and current-main sources above.

## The pass in one sentence

Binaryen `experimental-type-generalizing` is a hidden, not-yet-sound function pass that runs nested DCE and solves a backward CFG type-requirement problem using local and value-stack requirements derived from typed IR and module declarations, then generalizes non-param reference locals and retags affected `local.get` / `local.tee` expressions with refinalization.

## Visibility and scheduler status

`pass.cpp` registers `experimental-type-generalizing` with `registerTestPass(...)` and describes it as not yet sound. That matters:

- it is not part of Binaryen's normal public optimization roster;
- it should not be treated as a stable shrink pass;
- Starshine should not schedule it by default;
- future Starshine parity work must expect upstream drift because the pass is explicitly experimental.

## High-level algorithm

### 1. Prepare the function

For each function, Binaryen first runs nested `dce`. The owner source explains the reason: unreachable code can otherwise remain in shapes the CFG analysis does not materialize or handle. This pre-cleanup is part of the strategy.

Then the pass builds a function CFG. If CFG construction fails, the pass skips that function instead of pretending it can solve the requirements.

### 2. Define the dataflow state

The backward analysis state records:

- required types for locals;
- required types for the value stack;
- dependencies between basic blocks and locals so local requirement changes can trigger related block reanalysis.

This is why the pass is broader than local-set/local-tee evidence collection. It asks what every use requires and propagates those requirements backward.

### 3. Seed entry and exit requirements

At function exit, returned values must satisfy the declared result type.

At function entry:

- params keep their original declared types;
- non-reference locals keep their original types;
- reference locals may start from the relevant top heap type, then become constrained by uses.

### 4. Transfer instruction requirements backward

The transfer function walks instructions backward and updates the requirement state. Important families include:

- `local.get`, `local.set`, and `local.tee` for local requirement flow;
- direct calls and indirect/reference calls for signature requirements;
- `call_ref`, including bottom-target and signature-supertype behavior;
- global gets/sets;
- table gets/sets and table copy/fill/init/grow/size operations;
- `select`, `drop`, `ref.null`, `ref.is_null`, `ref.as_non_null`, `ref.test`, `ref.cast`, `ref.eq`, `ref.func`, and related ref operations;
- `struct.new`, `struct.get`, `struct.set`, descriptor operations, and array operations;
- conversion and reinterpret operations that constrain scalar types.

The pass does **not** use `ContentOracle` or another interprocedural content analysis. Where runtime-looking operations matter, it derives constraints from the typed instruction plus static declarations: call signatures, global/table types, and heap-type supertypes with struct fields or array elements.

### 5. Join and reanalyze to a fixed point

When multiple control-flow paths meet, the solver combines type requirements conservatively. If a local requirement changes, dependent blocks may need to run again.

The key invariant is user-driven safety: a local may only become more general when every observed use can still type-check.

### 6. Rewrite and refinalize

After the analysis stabilizes, Binaryen rewrites non-param local declarations to the generalized types it computed.

It then updates `local.get` and `local.tee` expression result types so they agree with changed local declarations. If those expression types changed, it runs `ReFinalize` on the function.

This replaces the superseded 2026-04-24 story that `local.get` becomes a drop-plus-zero wrapper.

## Inputs and outputs

Input:

- typed Binaryen functions;
- Binaryen CFGs;
- local declarations and expression result types;
- module-level declared types and heap-type relationships.

Output:

- more-general non-param local declarations where all uses allow it;
- repaired `local.get` / `local.tee` expression types;
- refinalized function bodies when expression types changed;
- no guaranteed body-size shrink and no public-pass stability promise.

## Correctness constraints

A faithful implementation must preserve at least these constraints:

1. Do not generalize params past their declared entry requirements.
2. Do not generalize scalar locals through the reference-type machinery.
3. Do not weaken local declarations unless every use admits the chosen type.
4. Respect call/call_ref signature requirements, including bottom and supertype cases.
5. Respect global, table, struct, array, ref, and descriptor constraints.
6. Treat unsupported TODO families as blockers, not as implicit positives.
7. Run equivalent pre-cleanup or otherwise handle unreachable CFG shapes explicitly.
8. Repair expression result types and refinalize after local declaration changes.

## Main unsupported or risky families

The reviewed source has explicit TODO/unreachable surfaces for several families, including EH, tuple, string, continuation, some branch-on and pop forms, and atomic struct/array operations. Those are not wiki omissions; they are part of the upstream hidden/not-yet-sound status.

## Validation strategy

For upstream comprehension:

- `TypeGeneralizing.cpp` is the owner of the algorithm.
- `pass.cpp` proves hidden/test and not-yet-sound status.
- `type-generalizing.wast` is the official behavior catalog.
- The 2026-07-11 `version_130` / current-main recheck is the current reviewed surface contract.

For future Starshine implementation:

- start with analysis-only tests, not mutation;
- compare proposed local declarations against Binaryen on the official lit shapes;
- only add mutation after local declaration rewriting, local-use retagging, refinalization/validation, and unsupported-family skipping are all explicit.

## Relationship to neighboring passes

- Compared with `gufa`, `type-generalizing` does **not** consume a whole-program `ContentOracle`; it derives intra-function requirements from typed IR and declarations, then writes local declarations rather than arbitrary expressions.
- Compared with `type-refining`, it generalizes local variables from use requirements rather than tightening struct field declarations.
- Compared with `signature-refining`, it does not rewrite function signatures; calls are constraints, not the direct output.
- Compared with `type-merging`, it does not merge heap type declarations.
