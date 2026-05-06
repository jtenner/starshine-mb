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
  - ../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./type-requirements-cfg-and-unsupported-families.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
supersedes:
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
---

# Upstream implementation structure and test map for `type-generalizing`

## Why this page exists

This page maps the corrected source contract to concrete Binaryen files. A 2026-05-06 current-main recheck kept the same reviewed surface contract, and the map still intentionally calls out the 2026-04-24 miscorrection so future readers do not reintroduce either stale model.

## Main upstream files

### `src/passes/TypeGeneralizing.cpp`

Sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeGeneralizing.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeGeneralizing.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeGeneralizing.cpp>

This is the owner file. It defines the experimental function pass and owns:

- nested DCE before analysis;
- CFG construction and skip-on-failure behavior;
- requirement lattice/state for locals and value-stack positions;
- dependency tracking between locals and basic blocks;
- backward monotone transfer over instructions;
- `ContentOracle`-assisted type reasoning;
- direct-call and `call_ref` requirement propagation;
- global, table, reference, struct, array, and conversion constraints;
- explicit unsupported/TODO families;
- local declaration rewriting;
- `local.get` and `local.tee` result-type repair;
- conditional `ReFinalize`.

If you only read one file for mechanics, read this one.

### `src/passes/pass.cpp`

Sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>

This file proves the pass identity and status:

- upstream name: `experimental-type-generalizing`;
- registration kind: `registerTestPass(...)`;
- status warning: not yet sound.

That registration is why the wiki treats the pass as a hidden experimental Binaryen surface and not as a normal public optimizer.

### Helper concepts used by the owner file

The owner file depends on Binaryen infrastructure rather than a separate pass-specific helper module:

- function CFG construction;
- monotone CFG analysis;
- type lattice operations;
- `ContentOracle` facts;
- nested pass execution for `dce`;
- `ReFinalize` after type repair.

The exact helper ownership may drift in Binaryen, but the 2026-04-27 current-main check did not find a teaching-relevant strategy change from `version_129`.

## Dedicated lit test

### `test/lit/passes/type-generalizing.wast`

Sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-generalizing.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-generalizing.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-generalizing.wast>

This is the official shape catalog. It covers:

- unconstrained reference local generalization to top types;
- implicit-return and function-result constraints;
- local get/set/tee propagation;
- direct-call and `call_ref` constraints;
- global and table constraints;
- `select`, `drop`, and reference-op constraints;
- struct and array operation constraints;
- unsupported/no-op boundaries.

## What each real file proves

| File | What it proves |
| --- | --- |
| `TypeGeneralizing.cpp` | algorithm, CFG/dataflow state, oracle use, transfer rules, local rewrite, refinalization, unsupported families |
| `pass.cpp` | hidden/test registration, upstream spelling, not-yet-sound warning |
| `type-generalizing.wast` | official positive and no-op module/function shapes |

## Superseded file/test claims

| Superseded claim | Corrected file-map fact |
| --- | --- |
| No `ContentOracle` | Owner file uses oracle-style contents facts |
| No `call_ref` surface | Owner file and lit test include `call_ref` constraints |
| No `struct.get` / `struct.set` surface | Owner file and lit test include GC struct/array families |
| `local.get` rewrite is drop-plus-zero | Owner file rewrites local declarations, then retags `local.get` / `local.tee` result types |
| No nested cleanup | Owner file runs nested `dce` before analysis |
| No refinalization | Owner file conditionally runs `ReFinalize` |
| Tiny local evidence pass | Owner file is a CFG/backward-analysis pass over local and stack type requirements |

## Test map by behavior family

### Generalize unconstrained refs

Best source: `type-generalizing.wast`.

Teaches: a local with only permissive reference uses can move toward a top/reference-supertype declaration.

### Preserve result and parameter requirements

Best sources: `TypeGeneralizing.cpp` entry/exit seeding plus `type-generalizing.wast` result cases.

Teaches: function ABI still constrains locals and stack values; the pass is not arbitrary erasure.

### Propagate call and `call_ref` requirements

Best sources: owner transfer rules and lit call/call_ref cases.

Teaches: call signatures are use constraints. `call_ref` is a real part of the pass, not a neighboring-pass myth.

### Global, table, ref, struct, and array constraints

Best sources: owner transfer rules plus lit families.

Teaches: `ContentOracle` and typed instruction semantics decide how far local declarations may be generalized.

### Unsupported families

Best source: explicit TODO/unreachable markers in `TypeGeneralizing.cpp`.

Teaches: not-yet-sound status is real. Future ports should skip or reject unsupported families deliberately.

## Practical reading order

1. `pass.cpp` to see the hidden/test registration and warning.
2. `TypeGeneralizing.cpp` top-level pass flow: nested DCE, CFG build, analysis, rewrite, refinalize.
3. `TypeGeneralizing.cpp` transfer functions for specific instruction families.
4. `type-generalizing.wast` to map source mechanics to visible WAT examples.
5. Starshine pages only after the upstream shape is clear; Starshine does not implement this today.
