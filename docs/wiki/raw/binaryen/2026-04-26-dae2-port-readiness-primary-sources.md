# Binaryen `dae2` port-readiness primary-source capture

_Capture date:_ 2026-04-26  
_Status:_ immutable current-main / Starshine-readiness source manifest for the `docs/wiki/binaryen/passes/dae2/` dossier

## Scope

This capture rechecks the official Binaryen `dae2` sources after the 2026-04-25 dossier and records the Starshine code surfaces needed to make the existing status page actionable as a future first-slice plan. Use the living pages for explanation:

- `docs/wiki/binaryen/passes/dae2/index.md`
- `docs/wiki/binaryen/passes/dae2/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dae2/wat-shapes.md`
- `docs/wiki/binaryen/passes/dae2/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dae2/starshine-port-readiness-and-validation.md`

## Official Binaryen sources rechecked

- `DeadArgumentElimination2.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination2.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DeadArgumentElimination2.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination2.cpp>
  - Rechecked surfaces: top pass comment, `FunctionInfo`, `RootFuncTypeInfo`, `DAE2::run(...)`, `GraphBuilder`, `prepareReverseGraph()`, `computeFixedPoint()`, `Optimizer`, `DAETypeUpdater`, and `makeUnreferencedFunctionTypes(...)`.
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Rechecked surface: public `registerPass("dae2", "Experimental reimplementation of DAE", createDAE2Pass)` registration remains adjacent to the DAE family.
- `passes.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/passes.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - Rechecked surface: `createDAE2Pass()` factory declaration.
- `dae2.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae2.wast>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/dae2.wast>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast>
  - Rechecked surface: the primary oracle still runs `wasm-opt -all --dae2 --closed-world -S` and remains the representative fixture for direct dead params, forwarded cycles, `call_ref`, `call_indirect`, referenced and unreferenced type-tree cases, continuations/tags/public roots/intrinsics, replacement types, and effect/control-preserving removal.

## Starshine local sources rechecked

- `src/passes/optimize.mbt`
  - `pass_registry_boundary_only_names()` currently lists plain `dead-argument-elimination` and `dead-argument-elimination-optimizing`, but not `dae2`.
  - `pass_registry_removed_names()` also omits `dae2`.
  - `run_hot_pipeline_expand_passes(...)` returns `unknown pass flag {name}` when no registry entry exists, so current `--pass dae2` behavior is unknown-pass rather than boundary-only or removed.
- `src/passes/pass_manager.mbt`
  - `run_hot_pipeline_apply_module_pass(...)` dispatches the active module-pass set and has no DAE/DAE2 signature-rewrite case.
- `src/lib/types.mbt`
  - Existing IR surfaces include `FuncType`, `Call`, `CallIndirect`, `ReturnCallIndirect`, `CallRef`, `ReturnCallRef`, and `RefFunc`; these are prerequisites, not a `dae2` implementation.
- `src/validate/typecheck.mbt` and `src/validate/validate.mbt`
  - Existing call, indirect-call, reference-call, and declared-reference validation surfaces are the natural validation targets after a future type/signature rewrite.
- `src/wast/`
  - Existing text/parser/lowering surfaces are required for fixtures with typed calls, element declarations, `ref.func`, and reference-call forms.

## Durable observations from the recheck

- No teaching-relevant strategy drift was found between the 2026-04-25 dossier and the official Binaryen current-main sources rechecked on 2026-04-26.
- `dae2` remains a public upstream pass and remains explicitly experimental in the registration and source framing.
- The future Starshine first slice should not start by silently making `dae2` an alias for plain `dead-argument-elimination` or `dead-argument-elimination-optimizing`.
- A safe local sequence is: registry-honesty decision, no-rewrite analyzer, private direct-call scalar deletion, then referenced function-type-tree work only after module/type remap infrastructure exists.
- The official `dae2.wast` closed-world oracle is a good comparison target only once the implemented slice reaches the corresponding surface; an early private-direct-call subset should keep narrower focused tests and clearly state that it is not full Binaryen parity.

## Uncertainty and caveats

- This source capture confirms the teaching-level contract, not byte-for-byte identity of every current-main helper detail.
- The pass is explicitly incomplete upstream; result optimization, constant actual propagation, and type propagation should be rechecked if upstream expands `dae2`.
- Starshine has prerequisite call/type/reference representations and validators, but this recheck still found no local registry entry, owner file, dispatcher case, preset role, or backlog slice for `dae2` on 2026-04-26.

## Consumability rule

Cite this capture together with `docs/wiki/binaryen/passes/dae2/starshine-port-readiness-and-validation.md` when discussing a future Starshine implementation sequence. Cite the older 2026-04-25 raw manifest when discussing the broader `version_129` source dossier.
