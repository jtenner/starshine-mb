# Binaryen `code-folding` port-readiness primary-source recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `code-folding` Starshine port-readiness bridge

## Scope

This source manifest supports the living port-readiness page for `code-folding`:

- `docs/wiki/binaryen/passes/code-folding/starshine-port-readiness-and-validation.md`

It does **not** supersede the earlier tagged and current-main manifests:

- `docs/wiki/raw/binaryen/2026-04-22-code-folding-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`

The purpose here is narrower: connect the reviewed upstream source locations to a practical Starshine implementation and validation ladder.

## Official online sources consulted

### Binaryen current `main`

- `src/passes/CodeFolding.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/CodeFolding.cpp>
  - Source locations used: the `CodeFolding` pass class, candidate-tail helpers, `canMove(...)`, `optimizeExpressionTails(...)`, `optimizeTerminatingTails(...)`, `doWalkFunction(...)`, and the unsupported-branch `unoptimizables` path.
- `src/passes/pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Source locations used: public pass registration and default-function-pipeline placement for `code-folding`.
- `src/passes/opt-utils.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/opt-utils.h>
  - Source locations used: after-inlining/default-function-pipeline rerun context that makes `code-folding` appear inside optimizing cleanup clusters.
- `src/passes/passes.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/passes.h>
  - Source locations used: public pass-constructor declaration.
- `test/lit/passes/code-folding.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-folding.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/code-folding.wast>
  - Source locations used: positive and negative proof families for `if` arm folds, block-exit/fallthrough folds, terminating-tail helper-label folds, `br_on_*` poisoning, outside-target bailouts, refined-result typing, and EH-sensitive shapes.

### Tagged comparison anchor

- `CodeFolding.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `passes.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `code-folding.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>

## Durable observations for Starshine port readiness

- The reviewed current-main sources still expose `code-folding` as a function-local pass. No whole-module deduplication or cross-function matching surface was found.
- The implementation remains split into two teachable algorithms:
  - expression-exit folding for named block exits and foldable `if` arms
  - function-ending suffix sharing for `return`, `return_call*`, and `unreachable` tails
- The source-backed safety gates remain the correct first Starshine port boundaries:
  - unsupported branch forms can poison label-based folding
  - branch-target scope must remain valid after motion
  - EH-sensitive `pop` and throwing movement are conservative bailouts
  - helper-block insertion must pass the size/profitability heuristic
  - block-adding rewrites can require EH nested-pop repair
- The shipped lit file is still the strongest first test oracle for a local port. It covers both obvious positives and the less obvious negative families; future local reduced tests should seed from those families before wider artifact replay.
- The default-function-pipeline placement still makes the pass a late-cluster transform that expects later cleanup (`merge-blocks`, branch cleanup, name cleanup, peepholes, `rse`, and `vacuum`) to consume helper structure. A Starshine port should not try to fold and fully clean every helper shape in one pass.

## No-drift note

This focused recheck did not find a teaching-relevant current-main drift from the existing 2026-04-25 `code-folding` strategy pages. The new durable value is the Starshine implementation-readiness bridge: exact local prerequisites, a safer minimum viable slice order, and a validation ladder tied back to the official proof families.

## Uncertainty and caveats

- This is a source/documentation recheck, not a byte-for-byte diff between `version_129` and current `main`.
- The exact local representation for movement-safety facts remains a Starshine design decision. Existing HOT helpers expose labels, region roots, branch targets, and mutation APIs, but no dedicated `code-folding` candidate/equality/scope-analysis owner exists yet.
- EH-sensitive movement should start as a bailout in a first Starshine port unless a later implementation explicitly proves the Binaryen nested-pop repair contract in local HOT/lower/writeback terms.
