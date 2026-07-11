# Binaryen `avoid-reinterprets` current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/avoid-reinterprets/` dossier

## Scope

This capture refreshes the upstream source basis last reviewed on 2026-05-05. It checks the owner, public registration, local-analysis dependencies, and dedicated memory32/memory64 fixtures. It does **not** claim byte-for-byte source identity, a complete upstream audit, or new Starshine parity evidence.

Use the living dossier for explanation and local status:

- `docs/wiki/binaryen/passes/avoid-reinterprets/index.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/single-load-chains-and-bailouts.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/wat-shapes.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-strategy.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/fuzzing.md`

## Official sources consulted

### Binaryen current `main`

- `src/passes/AvoidReinterprets.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AvoidReinterprets.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/AvoidReinterprets.cpp>
- `src/passes/pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `src/ir/local-graph.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/local-graph.h>
- `src/ir/properties.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/properties.h>
- `test/lit/passes/avoid-reinterprets.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/avoid-reinterprets.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/avoid-reinterprets.wast>
- `test/lit/passes/avoid-reinterprets64.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/avoid-reinterprets64.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/avoid-reinterprets64.wast>

### Historical comparison anchors

- 2026-05-05 current-main bridge: `docs/wiki/raw/binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md`
- `version_129` owner, registration, local-analysis, and fixture URLs recorded in `docs/wiki/raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`

## Durable observations

- Current `AvoidReinterprets.cpp` retains the narrow full-width-load contract. `canReplaceWithReinterpret(...)` still rejects unreachable and partial loads; the pass still recognizes exactly the four scalar reinterpret unary operations.
- The indirect family still uses `LocalGraph::getSets(...)`, requires exactly one non-null reaching set, follows only `Properties::getFallthrough(...)` values, follows unique `local.get` chains, and rejects cycles before accepting a terminal load.
- The final rewrite still keeps direct `reinterpret(load)` as a type-flipped load, while proven `reinterpret(local.get)` users read an alternate helper local. At the original load it saves the pointer once, creates the alternate typed load, and preserves the original typed load for other users.
- The current public registration remains `avoid-reinterprets` with the description “Tries to avoid reinterpret operations via more loads.” It remains an explicit public pass rather than evidence of default-pipeline membership.
- The current memory32 fixture continues to cover the direct `simple` family plus indirect `one`, `one-b`, `both`, `half`, and `copy` shapes. The current memory64 companion remains the pointer-address-type regression surface.
- No behavior-bearing drift was found on these reviewed upstream surfaces relative to the existing living explanation. The prior 2026-05-05 bridge is superseded as the freshness citation but remains historical provenance.

## Local Starshine reconciliation

Repository inspection on 2026-07-11 found:

- `src/passes/optimize.mbt` registers `avoid-reinterprets` as a module pass.
- `scripts/lib/pass-fuzz-compare-task.ts` admits `--avoid-reinterprets`.
- `src/passes/avoid_reinterprets.mbt` implements only adjacent direct full-width `load; reinterpret` replacement.
- `src/passes/avoid_reinterprets_test.mbt` covers all four direct scalar pairs plus partial-load and non-load bailouts.

Therefore an admitted generic compare-pass command is useful integration coverage, but it is **not** evidence that Starshine implements Binaryen’s indirect local-provenance/helper-local family. A future dedicated profile must generate direct opportunities and the upstream indirect positive/bailout matrix separately.

## Uncertainty and follow-up

- This is a documentation/source refresh; no upstream binary was executed and no Binaryen-versus-Starshine comparison was run in this maintenance slice.
- The checked files are enough to keep the existing teaching contract current, but not enough to prove that unrelated Binaryen scheduling or helper-library changes have no effect.
- The largest local parity gap remains indirect `reinterpret(local.get <- load)` rewriting. It needs an explicit Binaryen-compatible single-source provenance design before the pass can be treated as complete.
