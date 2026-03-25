# 0068 - Global Struct Inference

## Scope

- Narrow the current `GSI - Global Struct Inference` backlog entry to the actual Binaryen behavior that matters for the MoonBit debug artifact.
- Record the first safe Starshine slice before any code lands.
- Make the closed-world dependency explicit so later agents do not over-port an unsafe approximation.

## Current Binaryen Shape

- Binaryen's `GlobalStructInference` is not a broad "infer struct facts everywhere" analysis.
- The pass is a closed-world GC rewrite that looks for immutable globals initialized with top-level `struct.new*` expressions.
- It then rewrites eligible `struct.get*` users based on the set of possible globals for the observed struct type.
- The useful cases are:
  - one constant field value across all candidate globals: replace `struct.get*` with the constant while preserving the null trap on the input reference
  - one candidate global: replace the reference input with that global while preserving the null trap
  - two candidate values: replace with a `select` keyed by `ref.eq`
- The pass also marks types unoptimizable when function bodies allocate additional instances or global initializers embed nested allocations that break the simple global-instance model.

## Why It Matters Here

- The default no-DWARF Binaryen path runs `global-refining`, then `remove-unused-module-elements`, then `global-struct-inference`.
- `global-refining` makes the later GC pass more useful by narrowing private global types first.
- On the MoonBit debug artifact, this means `GSI` is an early module-level precision pass, not a late generic cleanup pass.

## Starshine Constraints

- Starshine already has the needed instruction surface:
  - boundary IR supports `struct.new*`, `struct.get*`, `ref.eq`, and `ref.as_non_null`
  - hot IR preserves heap operations as exact `HotOp::Heap` nodes with instruction payloads
- A direct boundary-form port would be awkward because `struct.get*` operands are stack-based.
- A hot-IR rewrite is the more natural first implementation path because the operand is explicit as a child node and can be wrapped in a value-producing `block`.

## Closed-World Constraint

- Binaryen gates this pass behind closed-world assumptions.
- Starshine already carries `OptimizeOptions.closed_world`, but the current pass pipeline does not thread that option into module-pass execution.
- Until that state is plumbed through, a faithful unrestricted port would be unsafe for exported boundaries or imported producers of internal struct refs.

## First Safe Slice

- Keep the first Starshine slice narrower than full Binaryen parity:
  - require closed-world mode to be available to the pass, or conservatively restrict optimization to provably internal-only exact-type cases
  - start with immutable globals whose top-level initializers are `struct.new`, `struct.new_default`, `struct.new_desc`, or `struct.new_default_desc`
  - only optimize immutable fields
  - first target the constant-field case, because it avoids needing to synthesize `global.get`-based identity comparisons before the pass scaffolding is proven out
- Preserve the observable null trap with `ref.as_non_null` before returning a folded constant or rewritten value.

## Landed Slice

- The first landed Starshine slice now exists.
- `OptimizeOptions.closed_world` is threaded through the CLI/config/env path and into `HotPipelineOptions`.
- The live `global-struct-inference` pass currently rewrites only direct `global.get -> struct.get*` chains backed by immutable top-level `struct.new*` globals.
- Nullable direct-global reads still preserve the null trap with `ref.as_non_null`; non-null direct-global reads fold to `global.get`, `drop`, and the constant field value.
- Broader type-wide inference across arbitrary ref producers is still deferred until compare evidence says the conservative direct-global slice is insufficient.

## Validation Plan

- Focused pass tests beside the implementation should cover:
  - one immutable global with a constant immutable field folded through `struct.get`
  - exported or externally visible shapes that must not be rewritten without closed-world proof
  - nested or function-local `struct.new*` allocations that force bailout
  - descriptor-bearing struct initializers if the first slice claims support for them
- Required repo checks before signoff:
  - `moon test --package jtenner/starshine/passes`
  - `moon info`
  - `moon fmt`
  - `moon test`
- Compare checks once the pass is real:
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --global-struct-inference`
  - ordered prefix replay through `GSI`

## Validation Results

- The compare-harness replay is complete.
- Default mode results:
  - `--global-struct-inference` had canonical wasm parity and normalized WAT parity, with Starshine at about `59.3%` of Binaryen wall time (`2285.985 ms` vs `1354.544 ms`) and Starshine pass time effectively zero because the pass is gated off without closed-world mode.
  - the ordered `DFE -> RUME -> MP -> OR -> GR -> GSI` prefix had canonical wasm parity and normalized WAT parity, but landed just under the current wall-time target across repeated runs at about `49.9%`, `47.4%`, and `47.6%` of Binaryen wall time.
- Closed-world results:
  - `--closed-world --global-struct-inference` had canonical wasm parity and normalized WAT parity, with Starshine at about `65.2%` of Binaryen wall time (`2272.068 ms` vs `1481.496 ms`).
  - isolated closed-world pass time stayed cheap at `1.855 ms` for Starshine versus `14.436 ms` for Binaryen.
  - the ordered closed-world prefix also kept canonical parity, but still missed the current wall-time target at about `48.7%` of Binaryen wall time (`3829.473 ms` vs `1866.356 ms`).
- A traced Starshine closed-world prefix run showed the budget issue is upstream of `GSI`: `duplicate-function-elimination` was about `433 ms`, `remove-unused-module-elements` about `154 ms`, `memory-packing` about `18 ms`, `once-reduction` about `36 ms`, `global-refining` about `1.7 ms`, `global-struct-inference` about `1.4 ms`, and final module validation about `1002 ms`.
- Decision:
  - keep the current direct-global closed-world slice
  - do not widen to broader type-wide inference yet
  - treat the remaining prefix budget gap as earlier-pass or pipeline overhead, not a `GSI` problem

## Performance Notes

- The pass should stay cheap relative to `DFE` and `RUME`.
- The main cost centers to watch are:
  - whole-module scans that repeatedly re-resolve struct field metadata
  - per-function hot lifting if done for every function instead of only functions that contain `struct.get*`
  - rebuilding exact heap nodes and wrapper blocks for every candidate access
- The first Starshine version should prefilter functions before hot lifting and cache candidate-global facts per type.

## Open Questions

- Whether the first landed slice should wait for pass-layer closed-world plumbing or temporarily restrict itself to internal-only exact-type cases.
- Whether descriptor-bearing struct globals should be in the first implementation slice or deferred until the non-descriptor path is stable.
- How much of Binaryen's two-value `select(ref.eq ...)` case is worth landing before later GC passes exist.
