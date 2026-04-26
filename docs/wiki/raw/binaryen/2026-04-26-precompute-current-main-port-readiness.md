# Binaryen `precompute` current-main / Starshine-readiness capture

_Capture date:_ 2026-04-26  
_Status:_ immutable primary-source bridge for `docs/wiki/binaryen/passes/precompute/`

## Scope

This file captures a focused re-read of official Binaryen primary sources for the plain `precompute` pass and compares them with Starshine's current HOT implementation surfaces. The purpose is not to replace the older `version_129` dossier; it is to make the current implementation-readiness gap explicit for future Starshine work.

Durable framing:

- Binaryen's `precompute` remains a broad interpreter-driven computation pass, not a small arithmetic peephole.
- Starshine's active `precompute` remains a deliberately narrower HOT pass: scalar integer folds, immutable defined-global constants, constant-`if` selection, pure-drop cleanup, and HOT/writeback hygiene.
- Binaryen current `main` has drifted beyond the reviewed `version_129` implementation in child-retention and GC/atomic details already recorded in the living page, so the future local parity plan should validate against the installed oracle while reading current upstream as drift context.

## Primary sources consulted

### Official Binaryen source files

- `src/passes/Precompute.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Precompute.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Precompute.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Precompute.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Important helper surfaces used by the pass family:
  - `src/wasm-interpreter.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
  - `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `src/ir/local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - `src/ir/effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>

### Official Binaryen tests

- `test/passes/precompute.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/precompute.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/precompute.wast>
- `test/passes/precompute-propagate.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/precompute-propagate.wast>
- `test/passes/precompute-string.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/precompute-string.wast>
- `test/lit/passes/precompute-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc.wast>

## Durable observations

- Binaryen owns the plain and propagate variants in one `Precompute.cpp` implementation. The public split is a mode choice: plain `precompute` runs the computation pass without the local-propagation add-on; `precompute-propagate` enables the local-flow phase and reruns the main computation walk once after propagation.
- The Binaryen pass runs over functions and uses `ConstantExpressionRunner` / interpreter-like execution to learn concrete values and flow, rather than matching only syntactic `Const` children.
- Replacement legality is a separate step from knowledge. Binaryen may know a value but decline to emit it when the result cannot be represented safely as an expression, when required side effects would be lost, or when GC/string/atomic behavior is too subtle.
- The full upstream strategy includes child-retention for local/global writes, `Flow` handling for returns/breaks, partial precompute through selected parents such as `select`, GC identity caching, and refinalization. Those are outside Starshine's current implemented subset.
- Starshine currently implements active `precompute` in `src/passes/precompute.mbt` and dispatches it through `src/passes/pass_manager.mbt`. The local implementation is a HOT fixpoint over direct constant recognizers plus structural cleanup, not a small interpreter.
- Starshine's local validation story is already unusually important for this pass: precompute-specific writeback validation and escape-carrier guards in `src/passes/pass_manager.mbt` are part of the current contract because old generated-artifact failures were lower/writeback hazards, not simple arithmetic-folding mistakes.
- The current safe local expansion sequence is therefore: keep registry and preset behavior stable, widen scalar fold coverage only where wasm semantics are trap-free, add direct tests for each new source shape, then add any interpreter/flow-like feature only after it has a Binaryen-oracle comparison lane and full-module validation coverage.

## Current-main drift note

The existing living `precompute` overview already records several newer-than-`version_129` upstream changes from Chromium/GitHub mirrors, including child-retention rewrites and GC atomic/read-write safety fixes. This capture does not supersede those notes. It makes them more actionable: future local work should treat `version_129` as the source-backed teaching baseline and current `main` as drift context until a deliberate oracle bump happens.

## Starshine code locations confirmed during this capture

- `src/passes/precompute.mbt:1-14` - pass descriptor and analysis invalidation set.
- `src/passes/precompute.mbt:16-18` - current narrow public summary.
- `src/passes/precompute.mbt:20-91` - literal and immutable-global constant recognizers.
- `src/passes/precompute.mbt:93-653` - i32/i64 unary/binary rewrite helpers and trap-averse scalar fold surface.
- `src/passes/precompute.mbt:656-720` - constant-`if` arm selection and block rebuild.
- `src/passes/precompute.mbt:722-784` - discardable-value and pure-drop cleanup rules.
- `src/passes/precompute.mbt:786-1158` - region/root cleanup and HOT fixpoint driver.
- `src/passes/optimize.mbt:207-215` - active registry entry.
- `src/passes/optimize.mbt:254-276` and `src/passes/optimize.mbt:394-417` - optimize/shrink preset placement with two `precompute` slots.
- `src/passes/pass_manager.mbt:8185-8299` - precompute-specific writeback validation and skip-invalid-lower reasons.
- `src/passes/pass_manager.mbt:8310-8484` - escape-carrier shape guards reused by precompute-sensitive passes.
- `src/passes/pass_manager.mbt:8734` - HOT dispatcher case.
- `src/passes/precompute_test.mbt:1-342` - current local proof surface for arithmetic, shifts, comparisons, immutable globals, constant-if cleanup, pure-drop cleanup, root-nop hygiene, structured branch-exit validity, and full-module call-target validation.
