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
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
  - ../minify-imports-and-exports/index.md
---

# `minify-imports`: `env` / `wasi_` gate, JSON map, and module-merge sibling

## Why this page exists

The pass name sounds broad, but Binaryen's plain `minify-imports` mode has a narrow import-module gate. Most implementation mistakes will come from one of three confusions:

1. assuming all import modules are eligible in the plain pass;
2. assuming the pass only reports a map and leaves declarations unchanged;
3. copying the `-and-modules` sibling's module-name merge into the plain pass.

## Plain-mode eligibility

Plain `--minify-imports` considers an import-base rename only when the old module string is:

```text
env
```

or begins with:

```text
wasi_
```

Positive examples:

```wat
(import "env" "very_long_func" (func $f))
(import "wasi_snapshot_preview1" "fd_write" (func $fd_write))
```

Negative example in plain mode:

```wat
(import "host" "very_long_func" (func $f))
```

The negative custom-module import is not a parser or validation issue; it is a Binaryen pass-policy boundary.

## All import kinds, not only functions

The shared owner walks imports generally. When the module string passes the gate, the base-name rewrite can apply to any import kind the module representation carries:

```wat
(import "env" "long_func" (func $f))
(import "env" "long_table" (table 1 funcref))
(import "env" "long_memory" (memory 1))
(import "env" "long_global" (global i32))
```

A faithful Starshine implementation must not accidentally restrict the plain pass to function imports just because some external glue systems mostly care about imported functions.

## JSON map shape

Binaryen prints a map so boundary tooling can translate between old and new names. In the corrected source contract, import entries are row arrays carrying old module, old base, and new base values.

Important caveats:

- exact row ordering and escaping should be copied from the target Binaryen revision;
- generated short names should come from Binaryen's minified-name generator;
- stdout handling matters because Starshine usually writes optimized wasm/WAT as its primary output.

## `-and-modules` sibling behavior

`minify-imports-and-exports-and-modules` has different import rules:

- it can minify import bases regardless of original module name;
- it rewrites import module strings to one short module name;
- it also has export-name mutation because it is an `-and-exports` sibling.

That means this sibling can turn:

```wat
(import "host" "long_func" (func $f))
(import "other" "long_memory" (memory 1))
```

into a shape conceptually like:

```wat
(import "a" "b" (func $f))
(import "a" "c" (memory 1))
```

Plain `minify-imports` must not do this.

## Starshine implementation consequence

The future local port should follow the detailed ladder in [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) and split work into testable slices:

1. parse and preserve import module/base strings through existing `@lib.Import` records;
2. implement plain-mode `env` / `wasi_` base rewrites and JSON map output;
3. update module maps and binary roundtrip tests;
4. add export-name mutation for `minify-imports-and-exports`;
5. add all-module import-base eligibility plus singleton module rewrite for `minify-imports-and-exports-and-modules`.

Keeping the gate and sibling split separate makes oracle mismatches easier to diagnose.
