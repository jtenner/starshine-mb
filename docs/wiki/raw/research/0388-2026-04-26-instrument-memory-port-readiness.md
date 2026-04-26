---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-instrument-memory-current-main-port-readiness.md
  - ../binaryen/2026-04-24-instrument-memory-primary-sources.md
  - ../../binaryen/passes/instrument-memory/index.md
related:
  - ../../binaryen/passes/instrument-memory/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/instrument-memory/starshine-strategy.md
  - ../../binaryen/passes/instrument-memory/binaryen-strategy.md
---

# `instrument-memory` port-readiness follow-up

## Question

The existing `instrument-memory` dossier was source-correct, but the future-Starshine story still made implementers infer the first safe slice from the general status page. This follow-up asks:

- Did Binaryen current `main` drift from the tagged `version_129` contract?
- What exact Starshine code surfaces are prerequisites rather than evidence of partial support?
- What implementation order would keep a future port faithful without accidentally advertising instrumentation in current builds?

## Local overlap scan

Before adding this note, the run re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/instrument-memory/`
- `docs/wiki/raw/research/`

The closest existing source was `0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md`; it remains valid for source provenance and local status. This note adds the current-main no-drift bridge and a dedicated Starshine first-slice / validation ladder rather than replacing the earlier source capture.

## Findings

### 1. Current Binaryen `main` still teaches the same pass

The 2026-04-26 primary-source recheck found no teaching-relevant drift in the official Binaryen owner, registration, factory, and four dedicated lit files.

The maintained contract remains:

- public pass name: `instrument-memory`
- owner file: `src/passes/InstrumentMemory.cpp`
- effectful helper-import instrumentation, not optimization
- scalar load/store pointer hooks and scalar value hooks
- `memory.grow` pre/post hooks
- GC `struct.*` and `array.*` scalar hooks when GC is enabled
- exact filter keys: `load`, `store`, `memory.grow`, `struct.get`, `struct.set`, `array.get`, `array.set`
- memory64-sensitive address-side helper signatures
- preserved unsupported surfaces: bulk memory, atomic RMW/cmpxchg, ref-valued GC payloads, SIMD payloads

### 2. Starshine still has no local pass identity

The local pass registry still has no `instrument-memory` active, boundary-only, or removed entry. Existing memory and GC instruction support only means Starshine can parse, represent, validate, lift/lower, encode, and decode relevant instructions. It does not mean Starshine can synthesize Binaryen's instrumentation helper imports or helper-call wrappers.

### 3. The pass should be planned as module work

A faithful port cannot be a standalone HOT peephole because the observable output includes helper imports and helper signature decisions. HOT infrastructure can help find and rebuild instruction shapes, but the port owner must also synthesize imports, choose names and types, preserve ABI, track helper IDs, parse filters, and invalidate effect-sensitive assumptions.

### 4. The first safe local slice should stay narrow

A practical Starshine order is:

1. registry status decision and tests,
2. helper-import synthesis for the scalar linear-memory/grow ABI,
3. scalar load/store/grow rewrites without filters,
4. unsupported-family preservation tests,
5. exact filter parsing,
6. memory64 address widening,
7. GC scalar field/array hooks,
8. effect-composition tests with the local `global-effects` / `vacuum` story if those passes are composed.

This order keeps the earliest slice useful while avoiding accidental claims about GC, filters, or memory64 before they are tested.

## Durable wiki changes made from this research

- Added raw primary-source capture `docs/wiki/raw/binaryen/2026-04-26-instrument-memory-current-main-port-readiness.md`.
- Added living page `docs/wiki/binaryen/passes/instrument-memory/starshine-port-readiness-and-validation.md`.
- Refreshed the `instrument-memory` landing, Binaryen strategy, implementation/test map, Starshine status, pass catalog, tracker, index, and log to point to the new bridge.
- Promoted the tracker wording from a generic `dossier` row to a deep dossier with an explicit implementation-readiness bridge.

## Uncertainties

- This was a focused source recheck, not a whole upstream history audit.
- The Starshine helper-ABI policy is still unmade: a future implementation may deliberately diverge, but that must be documented as local behavior instead of attributed to Binaryen.
- Effect-cache invalidation is an architecture decision for future Starshine work. The Binaryen fact is only that the pass declares `addsEffects()` and injects imported calls.
