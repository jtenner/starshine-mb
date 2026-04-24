---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../binaryen/passes/monomorphize/index.md
  - ../../binaryen/passes/monomorphize/binaryen-strategy.md
  - ../../binaryen/passes/monomorphize/implementation-structure-and-tests.md
  - ../../binaryen/passes/monomorphize/call-context-benefit-and-boundaries.md
  - ../../binaryen/passes/monomorphize/clone-construction-signature-rebuild-and-dropped-call-rewrites.md
  - ../../binaryen/passes/monomorphize/wat-shapes.md
  - ../../binaryen/passes/monomorphize/starshine-strategy.md
  - ../../binaryen/passes/monomorphize-always/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cmd/cmd.mbt
  - ../../../../src/cli/cli.mbt
  - ../../../../src/cli/cli_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
  - ../../binaryen/passes/tracker.md
---

# `monomorphize` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `monomorphize` dossier already had a landing page, Binaryen strategy page, implementation/test map, call-context safety page, clone-construction page, and transformed-shape catalog.
It still had two durable gaps:

- no immutable raw primary-source manifest for the official Binaryen release/source/test URLs rechecked after the dossier was deepened
- no dedicated Starshine strategy/status page tying the upstream contract to exact current local code locations

This follow-up closes those gaps without creating a duplicate Binaryen explanation.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-24-monomorphize-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `Monomorphize.cpp` on `version_129` and `main`
- `pass.cpp`
- the helper headers used by the implementation: `cost.h`, `effects.h`, `find_all.h`, `manipulation.h`, `module-utils.h`, `names.h`, `properties.h`, `return-utils.h`, `type-updating.h`, `utils.h`, and `wasm-limits.h`
- the official lit roster: `monomorphize-benefit`, `consts`, `context`, `drop`, `limits`, `mvp`, `types`, and `no-inline-monomorphize-inlining`

The checked official `version_129` release page showed publish timestamp **2026-04-01 14:31** when reviewed on 2026-04-24.
The narrow current-`main` spot check did not surface teaching-relevant drift from the living dossier's current claims.

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `src/cmd/cmd.mbt`
- `src/cli/cli.mbt`
- `src/cli/cli_test.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/tracker.md`
- neighboring `inlining`, `inline-main`, `inlining-optimizing`, `duplicate-function-elimination`, and `monomorphize-always` dossiers

## Durable findings

### 1. The upstream dossier needed provenance, not another algorithm rewrite

The existing living pages already teach the upstream contract well:

- direct-call candidate scanning over original defined functions
- effect-safe call-context extraction
- trivial-context rejection
- specialized clone construction and local remapping
- dropped-result return removal and caller-side drop repair
- nested optimization and cost-gated usefulness
- the split from `monomorphize-always`

This run added the immutable raw manifest and refreshed the source pointers so future readers can cite one stable provenance document instead of relying only on older research notes and inline GitHub URLs.

### 2. Current Starshine has pass-name tracking and option plumbing, but no transform

The honest current local status is:

- `monomorphize` and `monomorphize-always` are preserved as boundary-only names in `src/passes/optimize.mbt`
- explicit pass requests are rejected with the standard boundary-only message
- `--monomorphize-min-benefit` is parsed, stored, summarized, and passed through `OptimizeOptions`
- no `src/passes/monomorphize.mbt` owner file exists
- no active module dispatcher or HOT pass descriptor implements the transform
- `agent-todo.md` still has no dedicated `monomorphize` slice

That combination matters because it can otherwise look contradictory: Starshine has a real monomorphize option knob, but the pass itself is not implemented.
The new Starshine page teaches this as compatibility/config surface plus boundary-only strategy, not as a hidden implementation.

### 3. A faithful future port belongs in a boundary/module layer

`monomorphize` is not a HOT peephole.
A faithful local port would need at least:

1. whole-module direct-call collection over original defined functions
2. a call-context builder with effect-order movement checks
3. clone construction with signature rebuild from surviving dynamic inputs
4. local/name/type repair after param-to-local conversion
5. dropped-result return removal plus caller-side wrapper repair
6. a nested optimization runner and cost comparison tied to `monomorphize_min_benefit`
7. validation that the ordinary pass and `monomorphize-always` sibling keep the same safety gates but differ on usefulness rejection

The current local code has pieces adjacent to those needs, especially pass registry status, CLI/config plumbing, and neighboring module-pass dossiers, but not the core transform.

### 4. The main local teaching caveat is the option knob

Many unimplemented boundary-only passes have only a registry spelling.
`monomorphize` is different because Starshine already accepts and transports the `monomorphize_min_benefit` option for compatibility with Binaryen-style optimize options.

The durable caveat is:

- the option is real config/API surface today
- it does not cause the pass to run today
- it should become the usefulness threshold input if and when a real local port lands

Keeping that caveat explicit prevents future docs from either ignoring the existing option plumbing or overstating it as pass support.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-24-monomorphize-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0302-2026-04-24-monomorphize-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/monomorphize/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/monomorphize/index.md`
- `docs/wiki/binaryen/passes/monomorphize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/monomorphize/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/monomorphize/call-context-benefit-and-boundaries.md`
- `docs/wiki/binaryen/passes/monomorphize/clone-construction-signature-rebuild-and-dropped-call-rewrites.md`
- `docs/wiki/binaryen/passes/monomorphize/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `monomorphize` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-24-monomorphize-primary-sources.md`
2. `docs/wiki/binaryen/passes/monomorphize/index.md`
3. `docs/wiki/binaryen/passes/monomorphize/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/monomorphize/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/monomorphize/call-context-benefit-and-boundaries.md`
6. `docs/wiki/binaryen/passes/monomorphize/clone-construction-signature-rebuild-and-dropped-call-rewrites.md`
7. `docs/wiki/binaryen/passes/monomorphize/wat-shapes.md`
8. `docs/wiki/binaryen/passes/monomorphize/starshine-strategy.md`
9. `src/passes/optimize.mbt`
10. `src/cmd/cmd.mbt`
11. `src/cli/cli.mbt`
12. `agent-todo.md`
13. `docs/wiki/binaryen/passes/monomorphize-always/index.md`
14. `docs/wiki/binaryen/passes/inlining/index.md`
15. `docs/wiki/binaryen/passes/inline-main/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to exact current Starshine status and the practical landing zone for a future whole-module specialization pass.
