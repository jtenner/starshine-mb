---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeInstructions.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./scheduler-and-gates.md
---

# Upstream implementation structure and test map for `tuple-optimization`

## Why this page exists

The older tuple dossier already explained the broad idea, but it did not have one page that answered these practical questions together:

- which upstream files actually matter
- which helper utilities the pass really depends on
- how small the C++ implementation actually is
- what the dedicated lit file proves
- whether current `main` has drifted from `version_129`

This page is that compact source-map answer.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/TupleOptimization.cpp` | The whole pass implementation | Upstream tuple-opt is a tiny tuple-local splitter, not a heavyweight global analysis pass. |
| `src/passes/pass.cpp` | Registration and scheduler placement | The pass is meaningful partly because of where it runs: after `code-pushing`, before `simplify-locals-nostructure`, and only with multivalue enabled. |
| `src/passes/OptimizeInstructions.cpp` | Earlier tuple peephole | Direct `tuple.extract(tuple.make(...))` simplification belongs there, not in tuple-opt itself. |
| `src/wasm/wasm.cpp` | `TupleMake::finalize()` and `TupleExtract::finalize()` | Tuple-opt is operating over ordinary Binaryen tuple node semantics, not custom pass-local typing rules. |
| `src/wasm/wasm-validator.cpp` | Tuple validation rules | The pass must respect multivalue gating, tuple.make arity, tuple.extract bounds, and extracted-element subtype rules. |
| `test/lit/passes/tuple-optimization.wast` | Dedicated upstream behavior surface | The official tests make the pass's narrow approved surface and conservative bailout rules much clearer than the short implementation file does by itself. |

## The core C++ shape

`TupleOptimization.cpp` defines one pass struct and one nested applier struct.
That is essentially the whole implementation.

### Outer pass: collect, analyze, allocate

The outer pass does these jobs:

1. `doWalkFunction`
   - feature gate on multivalue
   - cheap scan for tuple locals
   - prepare the vectors
   - walk the function
   - call `optimize`
2. `visitLocalGet`
   - count tuple-local reads
3. `visitLocalSet`
   - count tuple-local writes
   - approve only tuple.make or tuple-local copy writers
   - build the symmetric copy graph
4. `visitTupleExtract`
   - approve only tuple-local reads consumed by tuple.extract
5. `optimize`
   - mark bad components
   - choose good tuple locals
   - allocate contiguous scalar replacement locals
   - run `MapApplier`

That is why the pass feels small: there is no second hidden analysis framework behind it.

### Nested pass: rewrite

`MapApplier` does the body rewrite.
Its main responsibilities are:

- recognize whether a set/get refers to a good tuple local
- rewrite tuple writes into scalar local writes
- rewrite tuple extracts into scalar local gets
- preserve tuple-tee semantics through `replacedTees`

In other words:

- the outer pass discovers *what* is safe
- the nested applier performs *how* to rewrite it

## Actual helper dependencies

The most important documentation correction here is that the helper surface is very small.

### Direct helpers the implementation obviously uses

- `PostWalker`
- `Builder`
- `UniqueDeferredQueue`
- ordinary tuple and local AST node classes from `wasm.h`

### Helpers it notably does **not** depend on

The pass does **not** request or use:

- CFG
- dominance
- effects
- liveness
- SSA
- refinalization helpers
- expensive branch or control analyses

That absence is important.
A port that suddenly needs those analyses may still be valid, but it should justify why the host IR cannot express the same tuple-local question as directly as Binaryen can.

## Validation and finalize neighbors

The pass file alone is easy to misread unless you also look at the tuple semantic neighbors.

### `TupleMake::finalize()` in `wasm.cpp`

Durable rule:

- if any operand is unreachable, the whole tuple is unreachable
- otherwise the tuple type is built directly from the operand types

### `TupleExtract::finalize()` in `wasm.cpp`

Durable rule:

- if the tuple operand is unreachable, the extract is unreachable
- otherwise the result type is just the indexed tuple element type

### `visitTupleMake()` in `wasm-validator.cpp`

Durable rules:

- tuples require multivalue
- `tuple.make` must have more than one operand
- the operand types must be a subtype of the tuple's declared result type

### `visitTupleExtract()` in `wasm-validator.cpp`

Durable rules:

- tuples require multivalue
- unreachable tuple operands imply unreachable extract results
- the extract index must be in bounds
- the extracted element type must be a subtype of the extract node's result type

These files explain why tuple-opt can safely rely on tuple element typing and subtyping when it rebuilds scalar gets.

## Why `OptimizeInstructions.cpp` still matters

The tuple-specific `visitTupleExtract` peephole in `OptimizeInstructions.cpp` handles:

- direct `tuple.extract(tuple.make(...))`

That tells us something very important about scheduler intent.
Binaryen wants tuple-opt to run after at least that peephole, because tuple-opt is supposed to split surviving tuple **locals**, not waste effort on tuple expression shapes that an earlier pass can already erase directly.

## Dedicated lit families and what they prove

The official `tuple-optimization.wast` file is a compact catalog of the pass's real contract.

### Families proving the positive core

- `just-set`
  - write-only tuple local still splits
- `just-get`
  - read-only tuple local still splits and uses default scalar locals
- `set-and-gets`
  - mixed write/read tuple local splits cleanly
- `tee`
  - tuple-local copy plus tuple tee both survive scalarization correctly
- `just-tee`
  - tuple tee still yields the correct lane as the enclosing expression value
- `no-uses`
  - immediate tuple-copy traffic with no later whole-tuple consumer can still optimize
- `set-after-set`
  - repeated tuple-local copying, even self-copy, stays within the approved family
- `tee-chain`
  - chains of tuple tees preserve the correct lane value and copy traffic
- `chain-3`
  - larger connected components still scalarize transitively
- `tuple.element.subtyping`
  - copied tuple lanes preserve source element typing and subtyping correctly

### Families proving the negative scope limits

- `just-get-bad`, `corruption-*`, `chain-3-corruption`
  - any whole-tuple escape poisons the connected component
- `make-extract-no-local*`
  - tuple expressions with no tuple local are not tuple-opt's job
- `set-of-block`
  - tuple-local writes from block results are deliberately out of scope
- `set-call`
  - tuple-returning calls are not treated like tuple.make or tuple-local copies here
- `unreachability`, `unreachable.tuple.extract`
  - unreachable tuple traffic should stay safe and conservative rather than over-optimized
- `two-2-three`, `three-2-two`
  - separate tuple-local families of different arities can both be optimized, but the pass still reasons per local/component, not as a free-form tuple algebra simplifier

## Narrow current-main drift note

I checked the core tuple-opt surfaces against current GitHub `main`.

Durable result:

- `TupleOptimization.cpp` is unchanged
- the relevant tuple-opt registration / scheduler lines in `pass.cpp` are unchanged
- the tuple-specific `OptimizeInstructions.cpp` peephole section is unchanged even though the file has unrelated edits elsewhere
- the dedicated `tuple-optimization.wast` lit file is unchanged

So current wiki pages should treat `version_129` as the release oracle without a current-main drift warning for the core upstream tuple-opt surfaces.

## Most important implementation takeaway

The upstream implementation is short because the problem it solves is narrow:

- tuple-local scratch storage only
- syntactic approved-use filtering only
- copy-connected component poisoning only
- scalarization only
- later local-cleanup passes do the rest

If a future explanation starts making tuple-opt sound like a general multivalue optimizer, it has probably drifted too far from what the official source file and lit suite actually do.

## Sources

- [`../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md`](../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeInstructions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast>
