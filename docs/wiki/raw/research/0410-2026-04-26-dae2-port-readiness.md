# `dae2` Starshine port-readiness bridge

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages

## Question

The `dae2` dossier already had overview, Binaryen strategy, implementation/test-map, WAT-shape, focused mechanics, and Starshine status coverage. It still lacked the newer standard bridge that tells a future Starshine implementer where to start, which code surfaces to read, and how to validate a partial port without overclaiming Binaryen parity.

## Local overlap check

Before creating the bridge, I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/dae2/`
- neighboring `dead-argument-elimination` and `dae-optimizing` pages
- `docs/wiki/raw/research/`

No existing `dae2/starshine-port-readiness-and-validation.md` page existed, and the existing `starshine-strategy.md` page mixed status with a high-level roadmap rather than a concrete slice/validation ladder.

## Primary-source recheck

Added `docs/wiki/raw/binaryen/2026-04-26-dae2-port-readiness-primary-sources.md` after rechecking official Binaryen current-main and tagged `version_129` sources:

- `DeadArgumentElimination2.cpp`
- `pass.cpp`
- `passes.h`
- `test/lit/passes/dae2.wast`

No teaching-relevant drift was found from the 2026-04-25 dossier. The pass is still a public experimental upstream pass built around backward used/forwarded-parameter fixed-point analysis with a closed-world+GC referenced-type rewrite mode.

## Starshine source recheck

Rechecked local surfaces:

- `src/passes/optimize.mbt`: `dae2` absent from active, boundary-only, removed, and preset registries; current behavior is unknown-pass.
- `src/passes/pass_manager.mbt`: no module dispatcher case for DAE/DAE2 signature rewriting.
- `src/lib/types.mbt`: prerequisites exist for function types, direct/indirect/reference calls, and `ref.func`.
- `src/validate/typecheck.mbt` / `src/validate/validate.mbt`: validation surfaces exist for the affected call/reference/type families.
- `src/wast/`: fixture prerequisites exist for many but not necessarily all reference-call/type-tree cases.
- `agent-todo.md`: no dedicated `dae2` slice.

## Durable wiki changes

- Added `docs/wiki/binaryen/passes/dae2/starshine-port-readiness-and-validation.md`.
- Refreshed `dae2` overview, Binaryen strategy, focused mechanics, WAT-shape, and Starshine strategy pages so the new bridge is linked from every relevant pass-family page.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Recommended future implementation sequence

1. Make an explicit name/status decision for `dae2`; do not alias it silently to plain DAE.
2. Add a no-rewrite analyzer that reports private function params, real-use seeds, and forwarded edges.
3. Implement the private direct-call scalar subset with effect-preserving operand removal.
4. Add direct recursion/mutual-recursion fixed-point handling.
5. Only then attempt `call_ref` / `call_indirect` referenced root function-type-tree rewriting.
6. Keep official `--dae2 --closed-world` Binaryen oracle comparison scoped to the implemented slice until full type-tree repair lands.

## Caveats

- `dae2` remains explicitly incomplete upstream for result removal, constant actual propagation, and type propagation.
- A private direct-call Starshine subset would be useful but should not be advertised as full Binaryen `dae2` parity.
- Full parity likely requires shared closed-world module/type-graph rewrite infrastructure also useful to signature and type passes.
