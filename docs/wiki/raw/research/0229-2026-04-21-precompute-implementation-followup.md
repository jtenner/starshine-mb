# Binaryen `precompute` follow-up: implementation structure, helper ownership, and proof surface

_Date:_ 2026-04-21  
_Status:_ absorbed into the living `docs/wiki/binaryen/passes/precompute/` dossier in this same change  
_Related living pages:_
- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/precompute/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/precompute/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/precompute/propagation-partial-precompute-and-gc-identity.md`
- `docs/wiki/binaryen/passes/precompute/wat-shapes.md`
- `docs/wiki/binaryen/passes/precompute/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/precompute-propagate/index.md`

## Why this follow-up existed

The `precompute` folder was already a deep dossier, so this was an explicit major-gap fallback rather than a new-pass expansion.

The gap was still real:

- the existing living pages already explained the pass strategy, the plain-versus-propagate split, the WAT shapes, and the current Starshine gap,
- but they still lacked one compact source-confirmed page that answered a different practical question:
  - **which upstream files actually own the plain `precompute` contract, and which tests prove that contract instead of the sibling `precompute-propagate` one?**

That missing map made four things too easy to blur together:

1. `Precompute.cpp` owns both public pass names, so the plain pass has a broader shared-engine contract than its small name suggests.
2. `pass.cpp` and `opt-utils.h` matter for the public/scheduler split even though they do not own the compile-time evaluator itself.
3. the most important plain-pass proofs are spread across a family of `precompute*.wast` files rather than one single tiny canonical lit file.
4. the neighboring `precompute-propagate*` tests are part of the teaching boundary, because they prove which local-worklist behavior belongs to the sibling and should not be silently attributed to plain `precompute`.

## Process followed

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/precompute/` folder
- the neighboring `docs/wiki/binaryen/passes/precompute-propagate/` folder

I also checked the current backlog situation in `agent-todo.md`:

- there **is** a dedicated `PC` slice today,
- specifically `[PC]001 - Constant Folding Surface` and `[PC]002 - Early/Late Slot Regression and Artifact Parity`.

So this follow-up supports a real live implementation area instead of documenting a pass with no active local owner.

## Official Binaryen sources reviewed

Primary upstream sources:

- `src/passes/Precompute.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/wasm-interpreter.h`
- `src/ir/local-graph.h`
- `src/ir/properties.h`
- `test/lit/passes/precompute-effects.wast`
- `test/lit/passes/precompute-partial.wast`
- `test/lit/passes/precompute_all-features.wast`
- `test/lit/passes/precompute-gc.wast`
- `test/lit/passes/precompute-gc-immutable.wast`
- `test/lit/passes/precompute-gc-atomics.wast`
- `test/lit/passes/precompute-gc-atomics-rmw.wast`
- `test/lit/passes/precompute-strings.wast`
- `test/lit/passes/precompute-ref-func.wast`
- `test/lit/passes/precompute-relaxed.wast`
- `test/lit/passes/precompute-stack-switching.wast`
- neighboring boundary files `test/lit/passes/precompute-propagate-partial.wast` and `test/lit/passes/precompute-propagate_all-features.wast`

## Main findings

### 1. `Precompute.cpp` is the real owner, but it owns both public pass names

The earlier living dossier already taught the algorithm correctly, but this follow-up makes the ownership split explicit:

- `Precompute.cpp` owns the evaluator, child-retention logic, partial-precompute phase, optional propagation phase, emitability rules, and final refinalization.
- plain `precompute` is therefore **not** a tiny standalone file-local subset living somewhere else.
- the plain/sibling distinction is mostly expressed through constructor flags, scheduler placement, and which tests prove each public surface.

That is a very different owner story from passes where plain and sibling modes live in separate source files.

### 2. The public meaning split lives partly outside `Precompute.cpp`

`pass.cpp` proves that:

- `precompute` and `precompute-propagate` are two real public upstream pass names,
- plain `precompute` is the one used in the top-level no-DWARF `-O` / `-Os` path,
- and the sibling variant is intentionally described as the local-propagating form.

`opt-utils.h` proves the other half:

- nested `optimizeAfterInlining(...)` reruns prepend `precompute-propagate`,
- so a future parity model must not describe plain `precompute` as the only practical precompute-family surface.

### 3. The helper ownership graph matters for teaching the pass honestly

The file-and-helper split is part of the contract here:

- `wasm-interpreter.h` owns `ConstantExpressionRunner` and `Flow`, which is why the pass is semantic compile-time execution rather than peephole matching.
- `local-graph.h` owns the influence graph that only the sibling variant uses for local worklist propagation.
- `properties.h` owns fallthrough and constant-expression helpers that shape both partial precompute and propagation boundaries.

That matters because a beginner can otherwise misread `Precompute.cpp` as if it were a self-contained pattern file.

### 4. The proof surface is broad and deliberately split

There is no one tiny dedicated `precompute.wast` file that proves the whole plain-pass contract.

Instead the real proof surface is spread across a family:

- `precompute-effects.wast` for speculative evaluation plus child-retention and ordering-sensitive bailouts,
- `precompute-partial.wast` for the upward partial-`select` algorithm,
- `precompute_all-features.wast` for broad scalar/control/tuple behavior,
- `precompute-gc*.wast` for heap identity, immutable reads, and atomic boundaries,
- `precompute-strings.wast`, `precompute-ref-func.wast`, `precompute-relaxed.wast`, and `precompute-stack-switching.wast` for important feature-specific boundaries.

The neighboring `precompute-propagate*` files are part of the teaching map too because they show where the extra local-worklist behavior begins.

### 5. The major missing beginner answer really was owner/test attribution

The previous pages already explained *what* the pass does.
What they did not answer compactly was:

- which files should a future porter read first,
- which files prove plain `precompute` specifically,
- and which files belong to the shared family or the sibling variant instead.

That compact answer is now what the new living page exists to provide.

## Durable conclusions to keep in the living wiki

- `precompute` was already deep, but it still needed an implementation/test-map page because its real contract is split between a shared owner file, helper files, public registration/scheduler files, and a broad lit family.
- Plain `precompute` should be taught as the shared semantic evaluator core in its non-propagating public mode, not as a tiny isolated subset or as a synonym for the sibling `precompute-propagate` pass.
- The broad lit roster is part of the real contract here; good documentation should keep effects, partial-precompute, GC, strings, `ref.func`, relaxed-SIMD, and stack-switching boundaries visible instead of overfitting to only one test file.
- `agent-todo.md` still has active `PC` slices, so this documentation depth is directly relevant to live local work.

## Files updated in this change

- `docs/wiki/raw/research/0229-2026-04-21-precompute-implementation-followup.md`
- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/precompute/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/precompute/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source links

- Binaryen `version_129` `Precompute.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` `wasm-interpreter.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
- Binaryen `version_129` `local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- Binaryen `version_129` `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- Binaryen `version_129` `precompute-effects.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-effects.wast>
- Binaryen `version_129` `precompute-partial.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-partial.wast>
- Binaryen `version_129` `precompute_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute_all-features.wast>
- Binaryen `version_129` `precompute-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc.wast>
- Binaryen `version_129` `precompute-gc-immutable.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc-immutable.wast>
- Binaryen `version_129` `precompute-gc-atomics.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc-atomics.wast>
- Binaryen `version_129` `precompute-gc-atomics-rmw.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc-atomics-rmw.wast>
- Binaryen `version_129` `precompute-strings.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-strings.wast>
- Binaryen `version_129` `precompute-ref-func.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-ref-func.wast>
- Binaryen `version_129` `precompute-relaxed.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-relaxed.wast>
- Binaryen `version_129` `precompute-stack-switching.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-stack-switching.wast>
- Binaryen `version_129` neighboring propagate files:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>
