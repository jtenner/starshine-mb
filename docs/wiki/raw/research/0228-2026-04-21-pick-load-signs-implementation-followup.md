# Binaryen `pick-load-signs` follow-up: implementation structure, helper ownership, and proof surface

_Date:_ 2026-04-21  
_Status:_ absorbed into the living `docs/wiki/binaryen/passes/pick-load-signs/` dossier in this same change  
_Related living pages:_
- `docs/wiki/binaryen/passes/pick-load-signs/index.md`
- `docs/wiki/binaryen/passes/pick-load-signs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/pick-load-signs/wat-shapes.md`
- `docs/wiki/binaryen/passes/pick-load-signs/parity.md`
- `docs/wiki/binaryen/passes/pick-load-signs/starshine-hot-ir-strategy.md`

## Why this follow-up existed

The `pick-load-signs` folder was already a deep dossier, so this was an explicit major-gap fallback rather than a new-pass expansion.

The gap was real anyway:

- the existing living pages already explained the pass strategy, WAT shapes, parity state, and Starshine HOT implementation,
- but they still lacked one compact source-confirmed page that answered a different beginner-to-intermediate question:
  - **which upstream files actually own the pass contract, and which tests prove each part of that contract?**

That missing map made three facts too easy to lose:

1. `PickLoadSigns.cpp` is the real owner and is much more self-contained than the pass name suggests.
2. `properties.h`, not a hidden load-analysis subsystem, owns most of the sign/zero-extension recognition logic that makes the pass effectively i32-only in `version_129`.
3. the dedicated `pick-load-signs_sign-ext.wast` file is intentionally tiny, so the neighboring `optimize-instructions-sign_ext.wast` file is part of the teaching story even though it belongs to a different pass.

## Process followed

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/pick-load-signs/` folder

I also checked the current backlog situation in `agent-todo.md`:

- there is **no dedicated `pick-load-signs` slice** today,
- only indirect mentions in the no-DWARF ordered-path summary and downstream cleanup replay notes.

So this follow-up is documentation maintenance, not a reflection of a live open implementation slice.

## Official Binaryen sources reviewed

Primary upstream sources:

- `src/passes/PickLoadSigns.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/ir/properties.h`
- `test/lit/passes/pick-load-signs_sign-ext.wast`
- `test/lit/passes/optimize-instructions-sign_ext.wast`

Freshness spot check sources:

- current `main` `src/passes/PickLoadSigns.cpp`
- current `main` `test/lit/passes/pick-load-signs_sign-ext.wast`

## Main findings

### 1. The implementation really is concentrated in one small owner file

The earlier living dossier was already correct about the high-level algorithm, but this follow-up made the ownership split explicit:

- `PickLoadSigns.cpp` owns the actual pass logic,
- `pass.cpp` owns public registration text and scheduler placement,
- `opt-utils.h` matters only because nested `optimizeAfterInlining(...)` reruns can make the pass appear more than once in practical pipelines,
- and `properties.h` owns the exact recognition helpers that constrain the usable sign/zero-extension surface.

That is a much smaller ownership graph than many other Binaryen passes.

### 2. The pass is self-contained partly because it delegates recognition outward

The implementation does not carry a large local pattern zoo.
Instead it relies on `properties.h` helpers for the most important meaning tests:

- sign-extension-value detection,
- sign-extension-bit extraction,
- zero-extension-value detection,
- zero-extension-bit extraction.

That means a correct teaching page needs to mention helper ownership, not just `PickLoadSigns.cpp` itself.

### 3. The proof surface is split across a tiny dedicated test and a neighboring non-owner test

The dedicated lit file proves the core pass contract:

- one positive sign-extension rewrite,
- one negative non-recognized-use bailout.

But the larger practical “what about i64 sign-extension cleanup?” question is answered mostly by **a different pass’s tests**:

- `optimize-instructions-sign_ext.wast`.

That split matters because otherwise beginners can easily over-attribute broader Binaryen sign-extension cleanup to `pick-load-signs`.

### 4. The no-drift claim stayed true on the checked surfaces

A narrow spot check still found no visible drift between `version_129` and current `main` on:

- `PickLoadSigns.cpp`
- `pick-load-signs_sign-ext.wast`

So the current dossier can continue using `version_129` as the semantic oracle here without carrying a new trunk-drift caveat.

## Durable conclusions to keep in the living wiki

- `pick-load-signs` was already deep, but it still needed an implementation/test-map page to make its small owner graph explicit.
- The pass is simpler to port and easier to mis-teach than many Binaryen hot passes because so much of its real contract is split between `PickLoadSigns.cpp` and helper semantics in `properties.h`.
- The dedicated upstream proof file is intentionally tiny, so good teaching must keep the boundary with `optimize-instructions` explicit rather than pretending all sign-extension cleanup evidence belongs to `pick-load-signs` itself.
- `agent-todo.md` still has no dedicated live slice for this pass today.

## Files updated in this change

- `docs/wiki/raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md`
- `docs/wiki/binaryen/passes/pick-load-signs/index.md`
- `docs/wiki/binaryen/passes/pick-load-signs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/pick-load-signs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/pick-load-signs/parity.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source links

- Binaryen `version_129` `PickLoadSigns.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/PickLoadSigns.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- Binaryen `version_129` dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/pick-load-signs_sign-ext.wast>
- Binaryen `version_129` neighboring sign-extension lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-sign_ext.wast>
- Binaryen current `main` `PickLoadSigns.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/PickLoadSigns.cpp>
- Binaryen current `main` dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/pick-load-signs_sign-ext.wast>
