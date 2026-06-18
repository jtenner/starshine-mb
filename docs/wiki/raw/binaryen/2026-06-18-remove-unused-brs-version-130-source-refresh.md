# Binaryen `remove-unused-brs` version_130 source refresh

Date: 2026-06-18

Purpose: source-refresh for Starshine backlog slice `[O4Z-AUDIT-RUB-A]`.

## Local oracle

- Local command: `wasm-opt --version`
- Observed output: `wasm-opt version 130 (version_130)`
- Local executable: `/usr/local/bin/wasm-opt`

For this audit, treat Binaryen `version_130` as the release oracle that matches the local tool. Keep `main` / trunk drift separate from this release baseline.

## User feature-gate instruction

For this RUB audit, assume WebAssembly 3.0 baseline features are enabled by default. In particular, do **not** model GC as an optional gated feature in the Starshine behavior matrix unless a local parser/tool limitation forces a clearly documented blocker.

Binaryen's C++ source still guards `optimizeGC(...)` with `getModule()->features.hasGC()`, but that is a Binaryen feature-bit implementation detail. Under this audit's framing, GC BrOn cleanup is a baseline RUB behavior surface for Starshine, not an optional stretch goal.

## Primary sources re-read

Versioned official source URLs:

- `src/passes/RemoveUnusedBrs.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/RemoveUnusedBrs.cpp>
- `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- `src/ir/branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/branch-utils.h>
- `src/ir/branch-hints.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/branch-hints.h>
- `src/ir/cost.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/cost.h>
- `src/ir/drop.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/drop.h>
- `src/ir/effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/effects.h>
- `src/ir/gc-type-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/gc-type-utils.h>
- `src/ir/localize.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/localize.h>
- `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/properties.h>

Official `remove-unused-brs*` lit roster at `version_130`:

- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-desc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-exact.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-exact-only.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-eh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs-intrinsics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_branch-hints.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_branch-hints-shrink.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_enable-multivalue.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_levels.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_shrink-level=1.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/remove-unused-brs_trap.wast>

## Version and drift findings

- `version_130` `RemoveUnusedBrs.cpp` differs from the older `version_129` source in the already-known JumpThreader area: the one-child named-block redirection no longer requires the child block type to equal the parent block type. A spelling comment also changed from `simplicitly` to `simplicity`.
- The branch-to-trap rewrite is part of the local `version_130` source and lit baseline. It is no longer only a trunk-drift watch for this repo's current local oracle.
- Fresh `version_130` versus `main` check on the requested source files found no source-code drift in `RemoveUnusedBrs.cpp` or the helper headers listed above. `pass.cpp` differs on `main`, but the local `version_130` source still registers `remove-unused-brs` and schedules the pass in the same three no-DWARF optimize slots documented by the dossier.
- Fresh `version_130` versus `main` check on the official `remove-unused-brs*` lit roster found only `remove-unused-brs_enable-multivalue.wast` expectation-text drift: several expected `local.tee` lines on `version_130` are expected as `local.set` on `main`. The RUB C++ source did not differ on this check.

## Shape matrix owner

The living matrix for this refresh is filed in:

- `docs/wiki/binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md`

That page now maps Binaryen phases/helpers/lit evidence to current Starshine coverage and owning follow-up slices `[O4Z-AUDIT-RUB-B]` through `[O4Z-AUDIT-RUB-N]`.
