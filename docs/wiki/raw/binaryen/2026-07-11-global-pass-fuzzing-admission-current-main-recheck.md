---
kind: raw-source
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderGlobals.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-globals.wast
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ../../binaryen/passes/simplify-globals/index.md
  - ../../binaryen/passes/simplify-globals/fuzzing.md
  - ../../binaryen/passes/reorder-globals-always/index.md
  - ../../binaryen/passes/reorder-globals-always/fuzzing.md
  - ../../tooling/pass-fuzz-compare.md
---

# Binaryen global-pass registration and Starshine fuzz-admission recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source and local-admission refresh for the plain `simplify-globals` and test-oriented `reorder-globals-always` dossiers.

## Scope

This narrow recheck answers two maintenance questions:

1. How does current Binaryen `main` register the two global-pass names?
2. Can Starshine currently execute either name through `compare-pass`?

It does not rederive the shared global-analysis algorithms. Existing dossiers remain the living explanation for `SimplifyGlobals` and `ReorderGlobals` behavior.

## Primary and repository sources reread

### Upstream Binaryen `main`

- Public/default pass registration and test-pass registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Shared global-ordering implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderGlobals.cpp>
- Small-module test-pass fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-globals.wast>

### Current Starshine admission evidence

- Boundary-only registry names and active production `reorder-globals` entry/preset composition: `src/passes/optimize.mbt`
- Compare-pass allowlist and parser admission: `scripts/lib/pass-fuzz-compare-task.ts`
- Four-gate definition: `docs/wiki/tooling/pass-fuzz-compare.md#pass-eligibility-preflight`

## Findings

### `simplify-globals` remains an ordinary Binaryen pass but has no local lane

Current Binaryen `main` registers `simplify-globals` with the normal pass-registration surface and keeps it distinct from the optimizing sibling. Its default optimization pipeline selects plain `simplify-globals` for lower optimization levels and `simplify-globals-optimizing` for stronger optimize/shrink configurations.

Starshine is intentionally different today: `pass_registry_boundary_only_names()` contains `simplify-globals`, while `SUPPORTED_PASS_FLAGS` has no `--simplify-globals`. An explicit compare-pass request therefore fails at harness admission before generation, Starshine execution, or Binaryen execution. The old generic 10,000-case command was not a smoke lane.

### `reorder-globals-always` is test-registered upstream and unavailable locally

Current Binaryen `main` registers production `reorder-globals` with the normal pass-registration surface but registers `reorder-globals-always` with `registerTestPass`. The latter is deliberately used by the official `reorder-globals.wast` fixture to expose the shared algorithm below the production small-module cutoff; it is not the ordinary production optimizer slot.

Starshine's state is again intentionally narrower: `reorder-globals-always` remains boundary-only and is absent from `SUPPORTED_PASS_FLAGS`, while production `reorder-globals` is already an active local module pass and part of the documented late preset tail. Thus an old `compare-pass --pass reorder-globals-always` command cannot test either the local production pass or the Binaryen test-oriented sibling.

## Documentation consequences

- Both affected `fuzzing.md` pages must say **planned-only**, distinguish roster inspection from parity evidence, and state the generator/fixture requirements for a future lane.
- `reorder-globals-always` pages must call the upstream name a **test-registered small-module/internal-fixup sibling**, not an ordinary public production pass.
- Starshine status pages must not say production `reorder-globals` remains boundary-only or absent from `optimize` / `shrink`; those statements became stale once the production module pass and late tail landed.

## Caveats

- The `registerTestPass` observation describes the reviewed current-main registration surface. It does not decide whether a future Starshine compatibility name should be user-facing, internally callable, or both.
- Starshine's boundary-only and harness allowlist status are local implementation facts, not claims about the upstream transform's validity or utility.
- A future lane still needs all four compare-pass admission gates, including a profile that generates meaningful global-ordering or global-rewrite cases and a nonzero `--min-compared` threshold.
