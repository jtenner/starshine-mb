---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-minify-imports-port-readiness-primary-sources.md
  - ../../../raw/research/0424-2026-04-27-minify-imports-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md
  - ../../../raw/research/0387-2026-04-26-minify-imports-source-correction.md
related:
  - ./index.md
  - ./env-wasi-json-map-and-module-merge.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../minify-imports-and-exports/binaryen-strategy.md
---

# Binaryen strategy for `minify-imports`

## Corrected source-backed contract

Binaryen implements `minify-imports` in `src/passes/MinifyImportsAndExports.cpp`, the same owner as `minify-imports-and-exports` and `minify-imports-and-exports-and-modules`.[^raw]

The plain public pass is the shared pass with both optional expansion flags disabled:

- `minifyExports = false`;
- `minifyModules = false`.

That means the pass does three visible things:

1. walks module imports;
2. rewrites qualifying import base names to generated short names;
3. prints a JSON mapping so external tooling can follow the ABI change.

This corrects the stale teaching that the plain pass is non-mutating imported-function-only map output.

## Import traversal and plain-mode gate

The owner uses a generic import walk, not a function-only helper. In plain mode, an import is eligible only when its module string is:

- exactly `env`; or
- prefixed with `wasi_`.

This gate is deliberate. A custom module such as `"host"` stays unchanged under `--minify-imports`, even if its base name is long. The `-and-modules` sibling changes that rule by minifying all import bases and then making every import use one short module name.

## Name generation and map keys

Binaryen uses `Names::MinifiedNameGenerator` for generated names. The import-side mapping is keyed by old module plus old base name, not only by base name. That matters when two different modules import the same base string.

After choosing the new base name, the pass mutates the import's base-name field. It then updates module maps after mutations so later lookups reflect the declaration-string changes.

## JSON output

The pass emits a JSON-shaped map instead of one `old:new` text line. In the corrected source contract, import entries are row arrays containing old module, old base, and new base values. For the two export-minifying siblings, export rows are populated too.

The exact key order, row ordering, escaping, and generated names belong to Binaryen's writer in the targeted revision. Starshine should not bake explanatory examples into conformance oracles.

## Sibling strategy split

The three public names are one implementation with different flags:

- `minify-imports`: eligible import base names only;
- `minify-imports-and-exports`: same import-base rule plus export-name rewriting;
- `minify-imports-and-exports-and-modules`: all import base names plus export-name rewriting plus import module-name merge to one short module.

The split is not cosmetic. Plain `minify-imports` is already mutating, but it is narrower than the module-merging sibling.

## Why the pass is ABI-sensitive

Import module/base strings are link-time names. Renaming them is safe only if host glue, generated JS, loaders, or downstream packagers apply the emitted map consistently.

This pass is therefore unlike internal cleanup passes such as local simplification. It may shrink names while breaking any consumer that still expects the old import strings.

## Test caveat

The reviewed official pass-test surface did not include a dedicated plain-`minify-imports.wast` / expected-output pair. The contract above is source-backed by the shared owner, factory registration, and current-main recheck. A future Starshine port should use direct Binaryen oracle comparisons for the plain mode and follow the local staging plan in [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).

[^raw]: [`../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md`](../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md) records the exact official sources and the superseded 2026-04-25 claims.
