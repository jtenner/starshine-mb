---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md
  - ../../../raw/research/0324-2026-04-24-strip-toolchain-annotations-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `strip-toolchain-annotations` implementation structure and tests

## Binaryen owner files

### `src/passes/StripToolchainAnnotations.cpp`

This is the whole implementation owner.
The reviewed `version_129` file defines a small function-parallel walker that:

1. strips function-level toolchain annotations;
2. walks `codeAnnotations` attached to expressions;
3. clears the removable toolchain-specific bits;
4. erases `codeAnnotations` entries whose record becomes empty;
5. leaves all executable expression nodes unchanged.

Important declarations and methods:

- `isFunctionParallel() == true`
  - every function can be processed independently.
- `requiresNonNullableLocalFixups() == false`
  - no expression type or local declaration repair is needed.
- `doWalkFunction(Function*)`
  - owns the function-level annotation strip plus per-expression annotation-map cleanup.
- `remove(CodeAnnotation&)`
  - the central allowlist of removed fields: `removableIfUnused`, `jsCalled`, and `idempotent`.

### `src/passes/pass.cpp`

The public pass registry registers:

- pass name: `strip-toolchain-annotations`
- summary: strip toolchain-specific code annotations
- constructor: `createStripToolchainAnnotationsPass`

This is the source of truth that the pass is public and command-line-addressable in Binaryen.

### `src/passes/passes.h`

The public constructor roster declares:

- `Pass* createStripToolchainAnnotationsPass();`

## Official test file

### `test/lit/passes/strip-toolchain-annotations.wast`

This is the dedicated lit proof surface.
The reviewed file directly proves these families:

- `@binaryen.removable.if.unused` disappears;
- `@binaryen.idempotent` disappears;
- `@metadata.code.inline` remains;
- if a removed annotation and preserved metadata coexist on the same expression, only the Binaryen-owned strip target disappears.

The file is intentionally small because the pass itself is small.
It is still enough to catch the two most likely incorrect ports:

1. stripping too little and leaving Binaryen-owned annotations behind;
2. stripping too much and deleting unrelated `@metadata.code.inline` metadata.

## Release-note surface

Binaryen `CHANGELOG.md` under `version_126` records the introduction of:

- `@binaryen.removable.if.unused`;
- `@binaryen.js.called`;
- `--strip-toolchain-annotations`, framed as a pass for those intrinsics and future similar intrinsics.

That release-note framing explains why the pass is intentionally forward-looking and allowlist-like: it is not a generic metadata vacuum.

## Current-main spot check

The current-`main` source and lit file reviewed on 2026-04-24 still present the same teaching-level contract as the tagged `version_129` sources.
No current-main behavior drift was filed into the living pages in this run.

## Testing gap to remember

`jsCalled` removal is source-backed by `remove(CodeAnnotation&)` and release-note provenance, but the dedicated lit file does not isolate `@binaryen.js.called` in the same direct way it checks `@binaryen.removable.if.unused` and `@binaryen.idempotent`.
A future upstream or Starshine test that isolates `jsCalled` would make the proof surface more beginner-obvious.
