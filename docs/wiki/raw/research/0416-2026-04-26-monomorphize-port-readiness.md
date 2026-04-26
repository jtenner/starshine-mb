---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-monomorphize-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../binaryen/passes/monomorphize/index.md
  - ../../binaryen/passes/monomorphize/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/monomorphize/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cli/cli.mbt
  - ../../../../src/cmd/cmd.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# `monomorphize` port-readiness bridge

## Why this note exists

The `monomorphize` folder already had complete overview, Binaryen strategy, implementation/test-map, WAT-shape, focused mechanics, and Starshine status coverage.
The remaining usability gap was the now-standard first-slice and validation bridge: a future implementer still had to infer how to move from boundary-only Starshine status to a safe first port.

This note adds that bridge without replacing the existing strategy pages.

## Primary-source recheck

Captured in:

- `docs/wiki/raw/binaryen/2026-04-26-monomorphize-port-readiness-primary-sources.md`

The 2026-04-26 recheck covered official Binaryen current `main` and tagged `version_129` surfaces for:

- `src/passes/Monomorphize.cpp`
- `src/passes/pass.cpp`
- the dedicated `monomorphize*` and `no-inline-monomorphize-inlining` lit files

No teaching-relevant drift was found from the 2026-04-24 dossier.
The upstream contract remains callsite-context specialization over direct calls, with effect-safe movement, specialized clone construction, caller-side dropped-result repair, nested optimization, and default usefulness gating.

## Starshine recheck

The local recheck confirmed:

- `src/passes/optimize.mbt` still lists `monomorphize` and `monomorphize-always` as boundary-only names.
- `src/cli/cli.mbt` still accepts `--monomorphize-min-benefit`.
- `src/cmd/cmd.mbt` still accepts config aliases, env/CLI/config merging, a default stored value of `5`, reproduction-note output, and forwarding to `OptimizeOptions`.
- `src/cmd/cmd_wbtest.mbt` still proves a nondefault CLI value reaches the command summary.
- There is still no `src/passes/monomorphize.mbt`, no active module dispatcher case, no preset role, and no dedicated backlog slice.

## Durable findings

### 1. The safest first slice is registry honesty plus a no-rewrite analyzer

Because the pass is boundary-only today, the first implementation step should not be mutation.
It should prove Starshine can parse the request, detect direct-call candidates, reject known unsafe targets, and report deterministic no-change stats without changing output.

That slice should cover:

- original-defined-function snapshotting
- imported-target rejection
- recursive self-call rejection
- unreachable-call rejection if local reachability is available
- direct-call-only classification
- option-flow proof for `monomorphize_min_benefit`

### 2. The first mutating slice should avoid full context movement

The first useful mutation should specialize a direct call whose context is already simple:

- one scalar literal argument, or
- one immediately dropped result, if return-call-sensitive targets are rejected first

This avoids combining clone construction, effect-sensitive operand movement, refined GC types, and nested usefulness measurement in one patch.

### 3. `monomorphize-always` should share all legality code

The sibling should not be a separate shortcut.
The future local implementation should share candidate scanning, context construction, clone building, and repair with `monomorphize`, then switch only the usefulness decision.

### 4. The local option knob is a documentation hazard

Starshine already accepts `--monomorphize-min-benefit`, but the pass does not run.
Docs should keep saying this is option/config plumbing only until a mutating pass consumes it.
A future port must also resolve the semantic mismatch between Binaryen's percent threshold and Starshine's currently inert default value before treating the option as a true oracle-compatible pass parameter.

## Pages updated or added

- Added `docs/wiki/binaryen/passes/monomorphize/starshine-port-readiness-and-validation.md`.
- Refreshed the monomorphize landing page and Starshine strategy page to link the new bridge.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/binaryen/passes/tracker.md` so the new readiness page is discoverable.

## Remaining implementation questions

- Whether the eventual pass lands as a new module-pass dispatcher path or as a narrow temporary module mutation around the current optimizer entrypoint.
- How Starshine should map its existing local default `monomorphize_min_benefit = 5` to Binaryen's current percent default of `95` if the option becomes active.
- How much nested optimization should be required in the first mutating slice; exact Binaryen usefulness parity requires some nested optimization and cost comparison, but a structural first slice may need a test-only or always-mode lane first.
