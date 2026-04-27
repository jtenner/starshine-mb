# Binaryen `flatten` port-readiness primary-source recheck

_Capture date:_ 2026-04-27  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/flatten/` dossier and future Starshine implementation-readiness page

## Scope

This source capture rechecks the official Binaryen `flatten` owner, formal Flat IR verifier, scheduler surface, and primary direct tests while adding the practical Starshine first-slice question that the 2026-04-25 implementation/test-map page did not yet answer: **what should a future Starshine port validate first, and what local surfaces must it touch?**

This is a continuation of:

- `docs/wiki/raw/binaryen/2026-04-23-flatten-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`

No teaching-relevant upstream drift was found from the 2026-04-25 current-main bridge. The new durable value is the analyzer/implementation sequencing for a future local port.

## Official Binaryen primary sources rechecked

### Current `main`

- `src/passes/Flatten.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Flatten.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp>
  - Observed on 2026-04-27.
  - GitHub displayed `424` lines / `391` loc.
  - Durable observations for port readiness:
    - the file still describes the pass as flattening into `Flat IR` and still carries the non-nullability TODO;
    - the implementation still centers on `preludes` and `breakTemps`;
    - constants and `nop` still exit early instead of being spilled pointlessly;
    - `Block`, `If`, `Loop`, and legacy `Try` still get custom value-erasure handling;
    - reachable `local.tee` still becomes `local.set` prelude plus `local.get`, while unreachable tees keep the unreachable value;
    - carried `br` / `br_if` values still use target temps, including the two-temp mismatch family when target type and flowing-out type differ;
    - carried `switch` / `br_table` values still fan out to all unique target temps;
    - `BrOn*` and `TryTable` are still hard unsupported families for this pass;
    - function exit still attaches remaining preludes and calls `EHUtils::handleBlockNestedPops(...)`.
- `src/ir/flat.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/flat.h>
  - Observed on 2026-04-27.
  - GitHub displayed `134` lines / `120` loc.
  - Durable observations for port readiness:
    - the formal target is still an AST property checker, not a profitability heuristic;
    - ordinary operands still must be constant expressions, `local.get`, `unreachable`, or `ref.as_non_null`;
    - control-flow structures and function bodies still must not flow concrete values;
    - reachable tees are still rejected;
    - `local.set` still cannot directly hold control flow;
    - nested `ref.as_non_null` remains a deliberate exception because non-null values cannot be spilled to locals in the same way.
- `src/passes/pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Observed on 2026-04-27.
  - Durable observations for port readiness:
    - `flatten` remains an aggressive `optimizeLevel >= 4` cluster member;
    - the relevant sequence remains `ssa-nomerge`, `flatten`, `simplify-locals-notee-nostructure`, then `local-cse`;
    - the cluster comment still frames the later local cleanup as depending on Flat IR.
- `src/passes/passes.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Observed on 2026-04-27.
  - Durable observation: `createFlattenPass()` remains a declared public pass constructor.

### Tagged `version_129` anchors retained

- `src/passes/Flatten.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Flatten.cpp>
- `src/ir/flat.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>

## Official Binaryen tests rechecked

- `test/lit/passes/flatten.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten.wast>
  - Durable observation: still a tiny smoke proof, not the full pass contract.
- `test/lit/passes/flatten_all-features.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_all-features.wast>
  - Durable observation: still the broad direct proof surface for value-carrying control, branch payloads, tees, references, and unsupported families.
- `test/lit/passes/flatten-eh-legacy.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten-eh-legacy.wast>
  - Durable observation: still the direct proof surface for legacy EH/catch `pop` repair after flatten inserts block structure.
- `test/lit/passes/opt_flatten.wast`, `flatten_rereloop.wast`, and `flatten_i64-to-i32-lowering.wast`
  - Tagged `version_129` anchors remain useful for downstream-cluster validation because they prove why later passes consume flattened input.

## Starshine local surfaces rechecked

- `src/passes/optimize.mbt:143-151`
  - `pass_registry_removed_names()` still includes `"flatten"`.
- `src/cli/cli_test.mbt:280-285`
  - Explicit `--flatten` is still preserved when trap-mode flags are filtered from the pass list.
- `src/cli/cli_test.mbt:313-316`
  - Explicit `--flatten` is still preserved when an `-O` flag is also present.
- `src/passes/pass_manager.mbt`
  - Still has no active `flatten` dispatcher case.
- `docs/0065-2026-03-24-ir2-execution-plan.md:39`
  - Still lists `flatten` first in the old preferred Batch 2 implementation order.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:47`
  - Still records `flatten` as removed until implemented.
- `agent-todo.md`
  - Still has no dedicated active `flatten` backlog slice.

## Durable conclusions

- The upstream contract remains stable: `flatten` is a function-parallel structural normalizer into Binaryen Flat IR.
- A future Starshine port should not begin as a broad optimizer rewrite. It should begin with a no-rewrite analyzer/verifier that classifies Flat-IR violations and records where preludes, temps, and unsupported-family decisions would be needed.
- The first mutating slice should be narrow: simple expression spill plus function-body return wrapping, then value-carrying `block` / `if` rewrites, then tee and branch-payload channels.
- EH and unsupported-feature policy are not optional late polish. They are correctness and honesty gates before any parity claim.
- Current Starshine status remains unchanged: known removed name, preserved CLI spelling, no dispatcher/owner file, old planning docs, and no active backlog slice.

## Consumability rule

Use this capture as the source-backed anchor for `docs/wiki/binaryen/passes/flatten/starshine-port-readiness-and-validation.md`. Use the living pages for explanation and future edits.
