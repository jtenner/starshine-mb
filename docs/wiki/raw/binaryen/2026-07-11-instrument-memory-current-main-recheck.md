# Binaryen `instrument-memory` current-main recheck

Capture date: 2026-07-11  
Status: immutable primary-source manifest for the living [`instrument-memory`](../../binaryen/passes/instrument-memory/index.md) dossier.

## Purpose and scope

This is a focused current-`main` freshness read, not a full Binaryen history audit or a Starshine implementation change. It refreshes the dossier's 2026-04-26 current-main claim against the public `version_130` release horizon documented in [`../../binaryen/release-horizon-and-oracles.md`](../../binaryen/release-horizon-and-oracles.md).

Read the living pages for explanation and future-port guidance:

- [`../../binaryen/passes/instrument-memory/index.md`](../../binaryen/passes/instrument-memory/index.md)
- [`../../binaryen/passes/instrument-memory/binaryen-strategy.md`](../../binaryen/passes/instrument-memory/binaryen-strategy.md)
- [`../../binaryen/passes/instrument-memory/implementation-structure-and-tests.md`](../../binaryen/passes/instrument-memory/implementation-structure-and-tests.md)
- [`../../binaryen/passes/instrument-memory/helper-import-roster-filters-and-unsupported-types.md`](../../binaryen/passes/instrument-memory/helper-import-roster-filters-and-unsupported-types.md)
- [`../../binaryen/passes/instrument-memory/wat-shapes.md`](../../binaryen/passes/instrument-memory/wat-shapes.md)
- [`../../binaryen/passes/instrument-memory/starshine-strategy.md`](../../binaryen/passes/instrument-memory/starshine-strategy.md)
- [`../../binaryen/passes/instrument-memory/starshine-port-readiness-and-validation.md`](../../binaryen/passes/instrument-memory/starshine-port-readiness-and-validation.md)

## Official sources rechecked

### Binaryen owner, registration, and factory

- current `main` owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/InstrumentMemory.cpp>
- `version_130` owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/InstrumentMemory.cpp>
- current `main` registration: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- current `main` factory declaration: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/passes.h>
- owner-file history endpoint inspected for recency: <https://api.github.com/repos/WebAssembly/binaryen/commits?path=src/passes/InstrumentMemory.cpp&sha=main&per_page=1>

### Dedicated official lit fixtures

- current `main` scalar fixtures: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-memory.wast>
- current `main` filter fixtures: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-memory-filter.wast>
- current `main` GC fixtures: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-memory-gc.wast>
- current `main` memory64 fixtures: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-memory64.wast>

## Findings

### Upstream contract remains current on the inspected surfaces

No behavior-bearing drift was found between the reviewed `version_130` owner/fixture contract and current `main`:

- `instrument-memory` remains a public standalone pass, not a default optimization-preset member.
- `InstrumentMemory.cpp` remains a postwalk transform that injects imported helpers, rewrites scalar `load` / `store` pointer or value children, wraps `memory.grow` with pre/post helpers, and extends to scalar GC `struct.get` / `struct.set` / `array.get` / `array.set` plus array-index hooks.
- The exact filter keys remain `load`, `store`, `memory.grow`, `struct.get`, `struct.set`, `array.get`, and `array.set`.
- Scalar helper imports remain broader than the selected filtered rewrite set; GC helper imports remain feature-conditional.
- Memory64 still widens pointer-side and grow-side helper arguments while scalar value hooks remain payload-typed.
- The pass still declares `addsEffects()`, and the reviewed unsupported boundaries remain: no generic bulk-memory, atomic RMW/cmpxchg, SIMD-payload, or general reference-payload instrumentation.

The owner-file history endpoint returned a latest owner-file-touching commit dated 2025-08-18. That is useful freshness context, not a substitute for the direct current-source read above.

### Starshine reconciliation

Focused repository inspection confirms the local status remains unchanged:

- [`src/passes/optimize.mbt`](../../../src/passes/optimize.mbt) has no `instrument-memory` active, boundary-only, or removed registry spelling.
- [`src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt) has no compatibility expectation for it.
- No owner implementation or behavior test exists under `src/`.

Therefore an explicit request remains a local unknown-pass failure. This recheck does **not** justify adding a Starshine spelling, a compare-pass command, or an implementation backlog slice.

## Uncertainty and supersession

This capture supersedes the **freshness claim** in [`2026-04-26-instrument-memory-current-main-port-readiness.md`](2026-04-26-instrument-memory-current-main-port-readiness.md), not its historical port-readiness reasoning. Both captures are deliberately focused owner/registration/fixture reviews rather than exhaustive history audits. If a future Binaryen change lands outside the inspected surfaces, refresh the living dossier from a new direct source read instead of inferring unchanged behavior from this note.

## Consumability rule

Cite this capture for current-main `instrument-memory` contract freshness as of 2026-07-11. Cite the 2026-04-26 capture for its historical first-slice port-readiness analysis, and cite the living pages for beginner-to-advanced explanation.
