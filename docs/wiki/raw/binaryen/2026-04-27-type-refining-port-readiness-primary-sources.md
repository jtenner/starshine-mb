# Binaryen `type-refining` port-readiness primary-source recheck

_Capture date:_ 2026-04-27  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/type-refining/` port-readiness bridge

## Scope

This file captures the primary online sources rechecked while deepening the `type-refining` dossier from source-correct status coverage to implementation-readiness guidance.
It does not replace the earlier tagged-source manifest in [`2026-04-24-type-refining-primary-sources.md`](2026-04-24-type-refining-primary-sources.md); it narrows the current-main recheck to the pass owner, registration/scheduler surface, and official lit proof files needed for a future Starshine first slice.

Living pages that consume this manifest:

- `docs/wiki/binaryen/passes/type-refining/index.md`
- `docs/wiki/binaryen/passes/type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-refining/normal-vs-gufa-and-fixups.md`
- `docs/wiki/binaryen/passes/type-refining/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-refining/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-refining/starshine-port-readiness-and-validation.md`

## Official sources rechecked

### Binaryen current-main source

- `TypeRefining.cpp`
  - browser URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeRefining.cpp>
  - raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeRefining.cpp>
- `pass.cpp`
  - browser URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>

### Binaryen current-main tests

- `type-refining.wast`
  - browser URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining.wast>
  - raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining.wast>
- `type-refining-gufa.wast`
  - browser URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining-gufa.wast>
  - raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa.wast>
- `type-refining-gufa-exact.wast`
  - browser URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining-gufa-exact.wast>
  - raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-exact.wast>
- `type-refining-gufa-rmw.wast`
  - browser URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining-gufa-rmw.wast>
  - raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-rmw.wast>

## Durable observations from the 2026-04-27 recheck

- Current `main` still teaches the same high-level contract captured on 2026-04-24: `type-refining` is a GC-only, closed-world struct-field declaration refiner with a normal scanner mode and a `type-refining-gufa` whole-program inference sibling.
- `TypeRefining.cpp` still says arrays are a TODO, so a future Starshine first slice should keep the scope to struct fields and reject or leave arrays unchanged.
- The pass still hard-fails without `--closed-world`; this should stay visible in local planning because Starshine currently has only a boundary-only pass name, not a closed-world option surface for this transform.
- The normal path still scans `struct.new` and `struct.set` / `struct.get` traffic through `StructUtils::StructScanner`, propagates constructor evidence upward, propagates set/get evidence through both super- and subtype directions, then merges both into `finalInfos`.
- The GUFA sibling still uses `ContentOracle` and then adds extra global-initializer constraints because later write repair can operate in function bodies, not arbitrary global initializer expressions.
- The pass still preserves public heap types by leaving them out of private declaration rewrites.
- The read-repair step still happens before type rewriting: impossible or newly invalid `struct.get` shapes become `drop(ref); unreachable`, while valid reads get the refined field result type directly.
- The type rewrite is still driven by `GlobalTypeRewriter`, followed by `ReFinalize` and a separate write-repair walk over `struct.new`, `struct.set`, RMW, and cmpxchg value operands.
- `pass.cpp` still registers both `type-refining` and `type-refining-gufa`, and the closed-world GC prepass cluster still schedules `type-refining`, then `signature-pruning`, then `signature-refining`, before `global-refining`.
- The checked current-main lit files remain the direct oracle surfaces for a future Starshine port: base struct-field refinement, GUFA-only inference wins, exactness/custom-descriptor limits, and RMW/cmpxchg repair behavior.

## Starshine-specific conclusions from this source recheck

- Starshine should keep `type-refining` boundary-only until it has a real module/type-section rewrite path; a no-op implementation would contradict the upstream source contract.
- The first useful local slice is not a HOT rewrite. It should be a no-rewrite analyzer that can collect candidate private struct fields and explain why each candidate is or is not safe.
- The first mutating slice should likely stay to closed-world, private, non-exported struct fields with direct `struct.new` / `struct.set` evidence, no GUFA, no arrays, no descriptor repair beyond existing type validation, and no global-initializer writes that would need casts.
- `type-refining-gufa` should remain an explicit naming question until Starshine has either a boundary-only sibling entry or shared GUFA/ContentOracle-style infrastructure.

## Uncertainties and non-claims

- This was a focused pass-owner and lit-surface recheck, not a full Binaryen repository audit.
- This file does not claim there is no current-main drift in helper internals such as `StructUtils`, `ContentOracle`, `GlobalTypeRewriter`, or validation; use it only for the teaching-relevant pass contract above.
- This file does not claim Starshine has a hidden implementation. The local status remains boundary-only and unimplemented as recorded in the living Starshine pages.
