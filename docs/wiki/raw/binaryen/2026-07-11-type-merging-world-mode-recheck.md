---
kind: raw-source
status: current
last_reviewed: 2026-07-11
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/TypeMerging.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeMerging.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-merging.wast
related:
  - ../../binaryen/passes/type-merging/index.md
  - ../../binaryen/passes/type-merging/binaryen-strategy.md
  - ../../binaryen/passes/type-merging/implementation-structure-and-tests.md
  - ../../binaryen/passes/type-merging/starshine-strategy.md
  - ../../binaryen/passes/type-merging/starshine-port-readiness-and-validation.md
---

# Binaryen `type-merging` world-mode recheck (2026-07-11)

## Scope

This immutable source bridge corrects the older 2026-05-05 claim that current Binaryen `main` differed from `version_129` only by a comment typo. It compares the reviewed owner-file contract at `version_129`, `version_130`, and current `main`, then records the local Starshine consequence. Use the living [`type-merging` dossier](../../binaryen/passes/type-merging/index.md) for explanations and port planning.

## Official sources checked

- Owner: [`TypeMerging.cpp` at `version_129`](https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp), [`version_130`](https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/TypeMerging.cpp), and [`main`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeMerging.cpp).
- Public registration: [`pass.cpp` on `main`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp).
- World-sensitive candidate and rewrite helpers: [`module-utils.h` on `main`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h) and [`type-updating.h` on `main`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h).
- Official proof surface: [`type-merging.wast` on `main`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-merging.wast).

## Durable correction

`version_129` used one Boolean gate:

```text
if (!getPassOptions().closedWorld) {
  Fatal() << "Type merging requires --closed-world";
}
```

The reviewed `version_130` and current-`main` owner instead carry `PassOptions::worldMode` through all three relevant layers:

```text
WorldMode worldMode = getPassOptions().worldMode;
if (worldMode == WorldMode::Open) {
  Fatal() << "Type merging requires a non-open world";
}
privateTypes = ModuleUtils::getPrivateHeapTypes(*module, worldMode);
// ...
TypeMapper(*module, replacements, worldMode).map();
```

The same `worldMode` reaches the owner-file debug consistency check for private heap types. The public pass spelling and dedicated lit file remain present.

## What did and did not change

- **Changed:** world assumptions are no longer a Boolean entry precondition isolated at the pass boundary. The selected non-open `WorldMode` participates in private-type classification and the module-wide rewrite helper.
- **Unchanged on the reviewed owner/test surface:** GC gating, cast observability, descriptor-chain treatment, supertype-then-sibling partition refinement, `TypeMapper`-based rewriting, refinalization, public pass name, and dedicated lit coverage.
- **Not concluded here:** this source inspection does not establish the behavioral relationship among every non-open `WorldMode` value. Do not summarize it as a blanket relaxation or widening without reviewing the `WorldMode` definitions and targeted tests.

## Starshine consequence

A future Starshine port must make one explicit world/visibility policy flow consistently through:

1. the admission gate;
2. private-versus-public candidate classification; and
3. every type-remapping/writeback operation.

A Boolean `closed_world` guard copied only at entry is no longer sufficient evidence of current Binaryen parity. Future fixtures must test every Starshine world mode it exposes, including the rejected open-world path.

## Supersession

This capture supersedes only the **freshness conclusion** in [`2026-05-05-type-merging-current-main-recheck.md`](2026-05-05-type-merging-current-main-recheck.md): its broader algorithm summary remains historical provenance, but its “comment typo only” statement is stale.
