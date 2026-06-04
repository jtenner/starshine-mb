---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../../binaryen/passes/const-hoisting/index.md
  - ../../binaryen/passes/const-hoisting/binaryen-strategy.md
  - ../../binaryen/passes/const-hoisting/implementation-structure-and-tests.md
  - ../../binaryen/passes/const-hoisting/size-model-and-boundaries.md
  - ../../binaryen/passes/const-hoisting/literal-bit-identity-zero-signs-and-nan-payloads.md
  - ../../binaryen/passes/const-hoisting/wat-shapes.md
  - ../../binaryen/passes/const-hoisting/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - 0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
  - ../../binaryen/passes/tracker.md
---

# `const-hoisting` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `const-hoisting` dossier already had the required landing page, Binaryen strategy page, implementation/test map, transformed-shape coverage, and the focused literal-identity and size-model pages.
However, it still had two durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page

This follow-up closes those gaps and refreshes the touched catalogs so the folder now reads cleanly from upstream release/source/test provenance through exact current Starshine status and future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `ConstHoisting.cpp` on `version_129` and `main`
- `literal.h`
- `pass.cpp`
- `insert_ordered.h`
- `wasm-binary.h`
- `wasm-builder.h`
- the dedicated `const-hoisting.wast` lit file

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`
- the neighboring `precompute`, `optimize-added-constants`, and `merge-similar-functions` dossiers
- `docs/wiki/binaryen/passes/tracker.md`

## Durable findings

### 1. The upstream dossier needed provenance and a local bridge, not another Binaryen mechanics page

The existing living pages already taught the main upstream contract correctly:

- exact repeated-`Const` grouping rather than expression equivalence
- byte-based profitability with real integer LEB measurement
- float buckets keyed by exact `Literal` type-plus-bits identity
- stable first-seen ordering through `InsertOrderedMap`
- fresh-local plus entry-prelude rewrite shape
- unsupported `v128`
- the stale `f64` threshold source comment in the official lit file

What was missing was provenance and a single local-status page.
This run added the immutable raw manifest and linked it into the folder so the reviewed release/source/test surface is no longer only implicit in older research notes.

### 2. The main local gap was the missing Starshine page, even though `const-hoisting` is still unimplemented

`const-hoisting` remains unimplemented in Starshine.
There is still no `src/passes/const_hoisting.mbt` owner file today.

But the repo already had a real local strategy surface in the broader status-and-port-planning sense:

- `src/passes/optimize.mbt` keeps `const-hoisting` in the removed registry
- the same file rejects explicit requests with the generic removed-pass error instead of silently pretending the pass exists in the active pipeline
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still records `const-hoisting` in the removed-until-hot-implementation roster
- `agent-todo.md` still has no dedicated `const-hoisting` slice, which is itself a durable planning fact worth making explicit instead of silently inventing nonexistent backlog coverage
- the neighboring `precompute`, `optimize-added-constants`, and `merge-similar-functions` dossiers already define the main local implementation neighborhood

Before this run, those local facts were scattered.
The new Starshine page turns them into one read-along path.

### 3. `const-hoisting` currently has a thinner local planning story than many other removed passes

Unlike passes such as `code-pushing`, `local-cse`, or `rse`, plain `const-hoisting` still has **no dedicated backlog slice** in `agent-todo.md`.

That makes the honest current local summary:

- removed name preserved
- active request rejection preserved
- removed-until-implemented planning bucket preserved
- neighboring size-pass ecosystem documented
- no dedicated implementation file
- no dedicated backlog slice yet

That distinction is useful for future contributors.
A future local `const-hoisting` port would likely be much smaller than other removed passes, but the repo has not yet promoted it from registry-preserved research into an active execution slice.

### 4. The right future local implementation shape is still a small HOT pass, not a boundary/module pass

Re-reading the local registry and the neighboring pass dossiers reinforces a key point:

- Binaryen `const-hoisting` is function-parallel and only rewrites repeated `Const` uses inside one function
- correctness depends on exact byte-size accounting and stable local/prelude insertion, not module-wide global facts or cross-function analysis
- the pass sits conceptually beside size-oriented local neighbors like `precompute`, `optimize-added-constants`, and `merge-similar-functions`, but it is narrower than all of them
- nothing in the reviewed source suggests a need for Starshine boundary/module scheduling here

So the local strategy should be thought of as:

1. preserve the removed registry spelling until a real pass exists
2. land a small HOT rewrite that scans one function for repeated literal nodes
3. keep the grouping key exact, including float bit identity and separate NaN-payload buckets
4. keep the byte-profitability rule exact, including the still-unsupported `v128` boundary
5. preserve deterministic prelude ordering and fresh-local insertion
6. validate against Binaryen in isolated pass mode rather than trying to wire this into the current no-DWARF default preset first

That is a tighter and safer future plan than the vague mental model “add some constant dedup later.”

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0276-2026-04-23-const-hoisting-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/const-hoisting/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/const-hoisting/index.md`
- `docs/wiki/binaryen/passes/const-hoisting/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/const-hoisting/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `const-hoisting` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`
2. `docs/wiki/binaryen/passes/const-hoisting/index.md`
3. `docs/wiki/binaryen/passes/const-hoisting/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/const-hoisting/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/const-hoisting/size-model-and-boundaries.md`
6. `docs/wiki/binaryen/passes/const-hoisting/literal-bit-identity-zero-signs-and-nan-payloads.md`
7. `docs/wiki/binaryen/passes/const-hoisting/wat-shapes.md`
8. `docs/wiki/binaryen/passes/const-hoisting/starshine-strategy.md`
9. `src/passes/optimize.mbt`
10. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
11. `agent-todo.md`
12. `docs/wiki/binaryen/passes/precompute/index.md`
13. `docs/wiki/binaryen/passes/optimize-added-constants/index.md`
14. `docs/wiki/binaryen/passes/merge-similar-functions/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status and the practical local landing zone for a future `const-hoisting` port.
