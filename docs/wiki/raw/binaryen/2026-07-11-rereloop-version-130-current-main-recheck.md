# Binaryen `rereloop` version_130/current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source bridge for the living `docs/wiki/binaryen/passes/rereloop/` dossier

## Scope

This bridge refreshes the upstream release horizon for Binaryen `rereloop` after the earlier 2026-05-05 current-main review. It compares the reviewed public owner, registration/scheduler context, generic relooper contract, flatness precondition, and focused fixtures at released `version_130` and current `main`.

It does **not** claim a complete repository diff, a new Starshine implementation, or executable Binaryen-vs-Starshine parity evidence. Read the living dossier for the maintained explanation and local status.

## Official sources reviewed

### Released `version_130`

- `src/passes/ReReloop.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/ReReloop.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/ReReloop.cpp>
- `src/passes/pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp>
- `src/cfg/Relooper.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_130/src/cfg/Relooper.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/cfg/Relooper.h>
- `src/ir/flat.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/flat.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/flat.h>
- `test/lit/passes/flatten_rereloop.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/flatten_rereloop.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/flatten_rereloop.wast>
- `test/lit/passes/opt_flatten.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/opt_flatten.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/opt_flatten.wast>

### Current `main`

- `src/passes/ReReloop.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReReloop.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReReloop.cpp>
- `src/passes/pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `src/cfg/Relooper.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/cfg/Relooper.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/cfg/Relooper.h>
- `src/ir/flat.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/flat.h>
- `test/lit/passes/flatten_rereloop.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_rereloop.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/flatten_rereloop.wast>
- `test/lit/passes/opt_flatten.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/opt_flatten.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/opt_flatten.wast>

## Durable observations

- Released `version_130` and reviewed current-main `ReReloop.cpp` retain the same pass-local contract: `Flat::verifyFlatness(function)`, task-based CFG construction for flat control, an explicit hard failure for `Try` / `Throw` / `Rethrow`, pre-render dead-end terminator repair, `RelooperBuilder` rendering through a fresh `i32` helper local, result-type repair with `unreachable`, and `ReFinalize`.
- The owner comment still states that the pass depends on `flatten` being run first. The pass remains a public `rereloop` transform rather than proof of membership in a default optimization preset.
- The reviewed registration/scheduler context remains the same teaching boundary: `rereloop` is public, while the flatten-era aggressive scheduler neighborhood still contains a TODO rather than an enabled default rereloop slot.
- The generic `Relooper` and `Flat` sources continue to justify the existing explanation of side-effect-free edge-condition discipline, generic structured shapes, and helper-label-local rendering. This is a source-contract confirmation, not a claim that every current-main helper implementation detail was exhaustively audited.
- The reviewed `flatten_rereloop.wast` and `opt_flatten.wast` sources preserve the existing fixture role: flattened control-flow reconstruction and flatten-era integration evidence. No behavior-bearing change was identified on this reviewed release/current surface.

## Starshine reconciliation

Repository inspection on 2026-07-11 confirms:

- `src/passes/optimize.mbt` retains only the removed local alias `re-reloop`.
- `src/cli/cli_test.mbt` accepts `--re-reloop` during parsing, while `src/cmd/cmd_wbtest.mbt` proves command rejection and help omission.
- There is no `rereloop` / `re_reloop` pass owner under `src/passes/`, and `scripts/lib/pass-fuzz-compare-task.ts` admits neither spelling.
- `agent-todo.md` has no current rereloop implementation slice.

Therefore the local status is still **removed and planned-only**. A generic compare-pass invocation cannot prove anything for this pass until Starshine has an active implementation, a deliberate local-to-upstream flag mapping, and a profile that guarantees flat inputs.

## Supersession and uncertainty

- This bridge supersedes the 2026-05-05 recheck as the freshness citation. Older raw manifests remain useful historical provenance and should not be edited.
- No Binaryen executable, Starshine executable, or pass-fuzz lane was run in this documentation maintenance slice.
- The reviewed files are sufficient to refresh the documented contract and release horizon. They do not prove that unrelated current-main files or future scheduler changes cannot affect a later implementation.
