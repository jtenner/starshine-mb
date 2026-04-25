---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../binaryen/passes/code-folding/index.md
  - ../../binaryen/passes/code-folding/binaryen-strategy.md
  - ../../binaryen/passes/code-folding/implementation-structure-and-tests.md
  - ../../binaryen/passes/code-folding/terminating-tails.md
  - ../../binaryen/passes/code-folding/wat-shapes.md
  - ../../binaryen/passes/code-folding/starshine-strategy.md
  - ../../binaryen/passes/code-folding/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/ir/hot_builders.mbt
  - ../../../../src/ir/hot_region_edit.mbt
  - ../../../../src/ir/hot_query.mbt
  - ../../../../src/ir/hot_side_tables.mbt
  - ../../../../src/ir/hot_labels.mbt
  - ../../../../src/ir/hot_verify.mbt
  - ../../../../src/cli/cli_test.mbt
  - ../../../../agent-todo.md
---

# `code-folding` port-readiness bridge

## Why this follow-up exists

The `code-folding` dossier already had the standard overview, shape catalog, Binaryen strategy, implementation/test-map page, terminating-tail guide, and Starshine status page.

The remaining durable gap was not another upstream algorithm page. It was the implementer bridge: how to start a faithful local port without accidentally broadening Binaryen's source-backed contract or hiding the current Starshine prerequisites across many files.

This follow-up adds:

- `docs/wiki/raw/binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md`
- `docs/wiki/binaryen/passes/code-folding/starshine-port-readiness-and-validation.md`

## Primary source rechecked

The focused source manifest rechecked official Binaryen current-main and tagged `version_129` sources for:

- `src/passes/CodeFolding.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/passes/passes.h`
- `test/lit/passes/code-folding.wast`

No teaching-relevant current-main drift was found. The source-backed contract remains the same two-algorithm late tail-sharing pass already described in the living dossier.

## Durable Starshine takeaways

### 1. The first local port should be narrower than the whole upstream pass

The safest initial Starshine implementation target is expression-exit tail sharing for the lowest-risk `if` / named-block families, with explicit bailouts for:

- unsupported branch forms beyond plain `br`
- labels whose full target scope cannot be proven safe
- EH-sensitive motion
- helper structures whose profitability is unclear

Terminating-tail sharing deserves a second slice because it needs fresh helper labels near the function end, old-body fallthrough prevention, and a different subset/deeper-suffix search.

### 2. The local prerequisite map is now explicit

The new living page ties upstream mechanics to exact local surfaces:

- removed-name registry and request guard in `src/passes/optimize.mbt`
- dispatcher gap in `src/passes/pass_manager.mbt`
- HOT block / branch / return / `if` builders in `src/ir/hot_builders.mbt`
- HOT region mutation APIs in `src/ir/hot_region_edit.mbt`
- label and branch query helpers in `src/ir/hot_query.mbt`, `src/ir/hot_side_tables.mbt`, and `src/ir/hot_labels.mbt`
- branch-target and arity verification in `src/ir/hot_verify.mbt`
- CLI spelling preservation in `src/cli/cli_test.mbt`
- `CF` backlog slice in `agent-todo.md`

### 3. The validation ladder should be official-test-family-first

The first reduced local tests should mirror the dedicated Binaryen `code-folding.wast` families before any large artifact replay:

1. unnamed `if` arm positives
2. named block branch-value positives
3. branch-plus-fallthrough positives
4. unsupported-branch poison negatives
5. outside-target bailout negatives
6. refined-result typing checks
7. only then, function-ending `return` / `return_call*` / `unreachable` helper-label positives

This avoids a common failure mode: implementing a broad “duplicate region” optimizer that passes a few happy paths but misses Binaryen's movement-safety and scheduler-neighbor contract.

## Supersession

This note does not supersede the 2026-04-22 or earlier 2026-04-25 `code-folding` source notes.
It extends them with a port-readiness bridge and keeps the existing algorithm and implementation/test-map pages as the canonical detailed source explanations.
