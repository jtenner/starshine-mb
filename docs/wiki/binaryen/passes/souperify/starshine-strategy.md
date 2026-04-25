---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-souperify-primary-sources.md
  - ../../../raw/research/0338-2026-04-25-souperify-source-bridge.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/ir/use_def.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../../../src/ir/ssa_policy.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-dataflow-traces-and-single-use-boundaries.md
  - ./wat-shapes.md
  - ../flatten/index.md
  - ../simplify-locals-nonesting/index.md
  - ../dataflow-optimization/index.md
---

# Starshine `souperify` status and port strategy

## Current status

Starshine does **not** implement Binaryen `souperify` or `souperify-single-use` today.

This is stronger than “not wired into presets”:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) has no active, module, boundary-only, removed, or preset registry entry for either spelling.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) has no module or HOT dispatcher case for a Souper trace-emission pass.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt) can report unknown pass flags, but it has no Binaryen-like Souper text output mode.
- No `src/passes/*souper*` owner file exists.
- [`agent-todo.md`](../../../../../agent-todo.md) has no dedicated `souperify` slice on 2026-04-25.

So a user request for `--souperify` would currently be an **unknown pass**, not a boundary-only tracked pass and not a removed-name pass.

## Why this is not a normal HOT pass port

Binaryen `souperify` is an extractor / printer, not a mutating optimization pass. The upstream pass:

1. verifies already-flat input;
2. builds Binaryen DataFlow IR;
3. discovers local influence and external uses;
4. builds bounded traces;
5. prints Souper-style text containing `var`, `phi`, `block`, `pc`, `blockpc`, and `zext`; and
6. leaves the wasm module body conceptually unchanged.

That does not fit cleanly into the current Starshine `HotPassDescriptor` model, which is optimized for mutating HOT/module passes that return a changed/unchanged module result.

A faithful local design should therefore start by deciding whether `souperify` belongs in:

- the ordinary pass registry,
- a separate analysis/export command,
- or a debugging / trace subcommand that can consume the optimized module but writes textual Souper output.

## Current local code map

### Registry and request behavior

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `pass_registry_boundary_only_names()` and `pass_registry_removed_names()` do not include `souperify` or `souperify-single-use`.
  - `run_hot_pipeline_expand_passes(...)` returns an unknown-pass error when a requested name is absent from the registry.
  - The current `optimize` and `shrink` presets do not expand either name.

### Dispatcher

- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - The module-pass dispatcher covers the active module passes such as `duplicate-function-elimination`, `remove-unused-module-elements`, `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, and `reorder-locals`.
  - There is no side-effect-free text-emission pass lane and no Souper-specific case.

### CLI and config plumbing

- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
  - CLI/config/env pass names flow into `run_hot_pipeline(...)`.
  - `CmdError::UnknownPassFlag` and the user message `unknown pass flag: ...` are present.
  - There is no option analogous to Binaryen's Souper-output behavior, no stdout contract for extracted traces, and no separate output-file kind for Souper text.

### Local-use and SSA prerequisites

- [`src/ir/use_def.mbt`](../../../../../src/ir/use_def.mbt)
  - Provides node-use, local-read, local-write, and per-block local-use/def data.
  - This is a useful prerequisite for value-use reasoning, but it is not Binaryen's `LocalGraph` influence model and does not by itself implement copy-chain external-use classification.
- [`src/ir/ssa_local.mbt`](../../../../../src/ir/ssa_local.mbt) and [`src/ir/ssa_policy.mbt`](../../../../../src/ir/ssa_policy.mbt)
  - Provide HOT local-SSA value IDs, phi placement, liveness-aware local policies, and merge reasoning.
  - These are useful prerequisites for a future trace graph, but they are not currently exposed as a Souper DataFlow IR or printed trace language.

### Instruction and frontend surfaces

- [`src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt)
  - Lifts many wasm operators into HOT op families, including locals, constants, unary/binary integer operations, `select`, blocks, loops, and `if` nodes.
  - This gives a future extractor a practical input representation, but it is not Binaryen's flatness verifier or DataFlow graph builder.
- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt), [`src/wast/`](../../../../../src/wast/), [`src/binary/encode.mbt`](../../../../../src/binary/encode.mbt), [`src/binary/decode.mbt`](../../../../../src/binary/decode.mbt), and [`src/validate/`](../../../../../src/validate/)
  - Provide the parser, core instruction, binary, and validation surfaces needed to build fixtures and round-trip wasm shapes.
  - They do not define a Souper text AST or printer.

## Binaryen-to-Starshine strategy mapping

| Binaryen strategy surface | Current Starshine state | Future local requirement |
| --- | --- | --- |
| Public `souperify` / `souperify-single-use` pass names | Unknown names; not tracked in registry | Decide whether to add pass-registry entries or a separate extraction command |
| `Flat::verifyFlatness(func)` precondition | No direct Binaryen-flatness verifier | Either require a local flat/HOT-normal form or implement a verifier that rejects non-flat functions before extraction |
| DataFlow node graph (`Var`, `Expr`, `Phi`, `Cond`, `Block`, `Zext`, `Bad`) | HOT SSA/use-def helpers exist, but no Souper trace graph | Add a small extraction IR or adapt HOT SSA with explicit printed-node identities |
| `UseFinder` over `LocalGraph` | `HotUseDef` tracks uses and locals, but not the same influence/copy-chain model | Implement copy-chain following, external-use classification, and multi-use child detection |
| Bounded `Trace` growth with `Var` fallback | No trace builder | Add depth/total limits and same-type unknown-variable fallback |
| `if`-derived `pc` / `blockpc` | CFG/control nodes exist, but no Souper condition printer | Add condition extraction and printed metadata; keep non-`if` path conditions explicitly unsupported unless implemented |
| Loop-phi avoidance | HOT SSA can model phis, but no Souper loop policy exists | Preserve Binaryen's conservative loop-carried `var` boundary or document any deliberate divergence |
| Souper text output | No output surface | Add CLI/stdout/file contract and tests that compare text, not just mutated wasm |
| Single-use sibling | No sibling behavior | Implement child-dependency truncation, not root filtering |

## Validation strategy for a future port

A faithful local port should validate with text-output fixtures, not only wasm round-trips.

Minimum test families:

- flat straight-line integer slices;
- unsupported nested/non-flat input rejection or precondition failure;
- `if`-guarded `pc` and `blockpc` traces;
- branch-merged locals that print `phi` / `block`;
- reusable child in plain `souperify` with external-use annotation;
- reusable child in `souperify-single-use` summarized as `var`;
- deep trace truncation at configurable limits;
- unsupported op and bad-merge bailout families;
- loop-carried local summarized conservatively;
- no wasm-body mutation unless the local API deliberately exposes a trace side effect as the result.

## Main caveats

- Do not present existing Starshine HOT SSA as an implementation of Binaryen DataFlow IR. It is a possible foundation, not a port.
- Do not add a hidden mutating no-op pass and call it `souperify`; the visible product of Binaryen's pass is the emitted trace text.
- Do not merge this dossier into [`../dataflow-optimization/index.md`](../dataflow-optimization/index.md). Both use Binaryen DataFlow concepts, but `dataflow-optimization` rewrites wasm IR while `souperify` prints extraction traces.
- Re-check upstream before expanding the path-condition story beyond `if`; the reviewed source still records wider path-condition support as unfinished.
