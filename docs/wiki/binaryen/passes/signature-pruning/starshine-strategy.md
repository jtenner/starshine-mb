---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../../../raw/wasm/2026-05-20-call-ref-source-refresh.md
  - ../../../raw/binaryen/2026-04-26-signature-pruning-port-readiness-primary-sources.md
  - ../../../raw/research/0404-2026-04-26-signature-pruning-port-readiness.md
  - ../../../raw/binaryen/2026-05-05-signature-pruning-current-main-recheck.md
  - ../../../raw/research/0470-2026-05-05-signature-pruning-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md
  - ../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../type-refining/index.md
  - ../signature-refining/index.md
  - ../global-refining/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./constant-actuals-localization-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../type-refining/index.md
  - ../signature-refining/index.md
  - ../global-refining/index.md
  - ../dead-argument-elimination/index.md
---

# Starshine Strategy For `signature-pruning`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md), the 2026-05-05 current-main recheck in [`../../../raw/binaryen/2026-05-05-signature-pruning-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-signature-pruning-current-main-recheck.md), the 2026-05-20 call-ref source refresh in [`../../../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../../../raw/wasm/2026-05-20-call-ref-source-refresh.md), and the implementation bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main infrastructure gaps a future parity port must resolve.

## The honest current status

`signature-pruning` is still **unimplemented** in Starshine.
There is no `src/passes/signature_pruning.mbt`, `src/passes/signature-pruning.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `signature-pruning` in the registry as a known boundary-only name;
- reject active requests honestly instead of silently no-oping;
- keep the upstream closed-world GC/type-cluster contract visible in the wiki;
- keep its absence from the canonical open-world no-DWARF path explicit;
- keep the missing dedicated backlog slice explicit;
- document why a future port is module/type-graph and function-body rewrite work, not a HOT peephole.

This is a **status-and-port-planning** page, not an implementation page. For first-slice sequencing and validation details, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
    - `pass_registry_boundary_only_names()` includes `"signature-pruning"` and the neighboring `"signature-refining"` spelling.
- registry entry construction for boundary-only names
  - [`src/passes/optimize.mbt#L264-L268`](../../../../../src/passes/optimize.mbt#L264-L268)
    - each boundary-only name becomes a boundary-only registry entry through `pass_registry_entry_boundary_only(...)`.
- registry category lookup
  - [`src/passes/optimize.mbt#L363-L368`](../../../../../src/passes/optimize.mbt#L363-L368)
    - `pass_registry_category(...)` reads the cached entry category for known names.
- active request guard for boundary-only passes
  - [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
- active preset absence
  - [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
    - the built-in `optimize` and `shrink` presets expand only the currently implemented module/HOT sequence and do not include `signature-pruning`.
  - [`src/passes/registry_test.mbt#L129-L158`](../../../../../src/passes/registry_test.mbt#L129-L158)
    - the preset test asserts every expanded preset name is `HotPass` or `ModulePass`, which keeps boundary-only names out of the active default path.
- boundary-only planning provenance
  - [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L96-L98`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L96-L98)
    - the pass-port map groups `signature-pruning` with type, global, and signature shaping names rather than HOT cleanup names.
- function type and call representation a future port would have to rewrite
  - [`src/lib/types.mbt#L98-L105`](../../../../../src/lib/types.mbt#L98-L105)
    - `TypeIdx` and `FuncIdx` are explicit typed indices.
  - [`src/lib/types.mbt#L147-L168`](../../../../../src/lib/types.mbt#L147-L168)
    - `SubType`, `RecType`, and `TagType` model nominal type declarations that can make a function heap type public or otherwise unsafe to shrink.
  - [`src/lib/types.mbt#L416-L433`](../../../../../src/lib/types.mbt#L416-L433)
    - `FuncType`, `TypeSec`, and `FuncSec` encode the function signature and function-section surface a future module pass must update.
  - [`src/lib/types.mbt#L525-L532`](../../../../../src/lib/types.mbt#L525-L532)
    - `Call`, `CallIndirect`, `ReturnCall`, `ReturnCallIndirect`, `CallRef`, and `ReturnCallRef` are instruction variants, which keeps the direct-call versus table-mediated boundary visible.
  - [`src/lib/types.mbt#L2987-L3019`](../../../../../src/lib/types.mbt#L2987-L3019)
    - constructor helpers exist for direct calls, indirect calls, tail calls, `call_ref`, and `return_call_ref`.
- WAT parser and lowerer surfaces a future port can reuse for fixtures
  - [`src/wast/parser.mbt#L1240-L1368`](../../../../../src/wast/parser.mbt#L1240-L1368)
    - type-use parsing is centralized and shared by call-like and block-like text forms.
  - [`src/wast/parser.mbt#L1885-L1888`](../../../../../src/wast/parser.mbt#L1885-L1888)
    - `return_call_ref` parses with a type use today.
  - [`src/wast/lower_to_lib.mbt#L1934-L1981`](../../../../../src/wast/lower_to_lib.mbt#L1934-L1981)
    - `call_indirect`, `return_call_indirect`, and `return_call_ref` lower type-use-bearing WAST forms to library instructions.
  - current WAST caveat
    - the 2026-05-20 call-ref refresh confirms the library, binary, generator, and validator surfaces for `CallRef` and keeps ordinary non-tail `call_ref` classified as core/binary/generator-visible but not high-level Starshine WAST text. Future text-fixture work should add direct `call_ref` keyword/parser/lowerer/printer coverage before relying on WAST-only fixtures; until then, use library/binary fixtures and the focused WAST function-call guide.
- validation surfaces a future port must preserve after pruning signatures
  - [`src/validate/env.mbt#L179-L190`](../../../../../src/validate/env.mbt#L179-L190)
    - validation resolves `TypeIdx` to `FuncType` and resolves tag function types through the type environment.
  - [`src/validate/env.mbt#L332-L340`](../../../../../src/validate/env.mbt#L332-L340)
    - validation can retrieve both a function's effective `FuncType` and its original `TypeIdx`.
  - [`src/validate/typecheck.mbt#L894-L956`](../../../../../src/validate/typecheck.mbt#L894-L956)
    - direct calls, `call_indirect`, and `call_ref` pop parameters and push results from resolved function types.
  - [`src/validate/typecheck.mbt#L990-L1049`](../../../../../src/validate/typecheck.mbt#L990-L1049)
    - `return_call_indirect` and `return_call_ref` check return-result compatibility and then consume parameters plus callee reference operands.
  - [`src/validate/typecheck.mbt#L3214-L3220`](../../../../../src/validate/typecheck.mbt#L3214-L3220)
    - the instruction dispatcher routes all call-family variants to the validators above.
- binary encoder/decoder surfaces a future port must keep coherent after rewrites
  - [`src/binary/decode.mbt#L2568-L2575`](../../../../../src/binary/decode.mbt#L2568-L2575)
    - binary `call_ref` / `return_call_ref` opcodes decode with `TypeIdx` immediates.
  - [`src/binary/encode.mbt#L2032-L2040`](../../../../../src/binary/encode.mbt#L2032-L2040)
    - the same instruction variants encode back with `TypeIdx` immediates.
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `signature-pruning` in the active default route.
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `signature-pruning` slice.

That map is the durable local status today: the pass is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's `signature-pruning` changes nominal function signatures, function declarations, function bodies, direct call sites, and `call_ref` users together after closed-world heap-type-level analysis.
The transformed shapes appear across:

- private function heap-type declarations and rec groups;
- function section entries and imported function types;
- direct `call` and `return_call` operands;
- `call_ref` and `return_call_ref` type immediates;
- callee locals and body expressions when removed params must become locals;
- constant-actual materialization inside callee bodies;
- call operand localization blocks when effectful actuals originally blocked removal;
- public/imported/tag/continuation/table/JS/intrinsic/subtyping boundary families.

A faithful Starshine port would need to reason over:

- the module's full function heap-type inventory;
- which function types are public or externally visible;
- imported functions, tags, continuations, tables, and JS-call intrinsics;
- entry liveness of parameter locals inside every function body;
- all direct calls and `call_ref` uses for a nominal function heap type;
- constant-actual agreement across all calls to a heap type;
- safe conversion of removed params into locals inside callee bodies;
- synchronized actual-argument removal at every direct and `call_ref` user;
- module-wide nominal signature rewriting;
- local-index repair and validation after parameter-to-local conversion;
- delayed localization and at most one extra pruning cycle.

Those requirements cross package and module boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass or shared closed-world signature-rewrite engine, not a small `HotFunc` rewrite.

## What Starshine currently does for the pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `signature-pruning` in `pass_registry_boundary_only_names()`.
That means:

- the spelling remains discoverable in local registry behavior;
- neighboring GC/type docs can point at one consistent local status;
- future port work has to intentionally move the pass into an implemented category.

### 2. The active pipeline rejects it honestly

When a user requests a boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to shrink function heap types;
- the registry category remains executable documentation;
- future implementation work will have to change the category and diagnostics intentionally.

### 3. The active presets exclude it

The Starshine `optimize` and `shrink` presets expand only implemented module/HOT passes today.
The registry test asserts that preset expansions stay on active pass names.
That matches the current local strategy: `signature-pruning` has no open-world no-DWARF preset role in this repo today.

### 4. The local pass-port map groups it with boundary shaping

The 2026-03-24 pass-port registry map groups `signature-pruning` with type, global, and signature shaping.
That local grouping still matches the source-backed upstream contract better than treating the pass as function-local DAE.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- return without rewriting when GC is unavailable;
- require an explicit closed-world mode before running the pass;
- bail out or deliberately expand the design when tables exist;
- decide per nominal function heap type, not per textual function shape or per individual function;
- collect direct calls and `call_ref` users separately from table-mediated calls;
- use entry-liveness for incoming parameter values instead of raw `local.get` text search;
- freeze imported and public signature families;
- freeze tag-used, continuation-used, JS-called, `call.without.effects`, and subtype-linked function types unless Starshine has a documented stronger proof;
- apply constant-actual materialization before deciding which params are removable;
- remove params across all functions sharing the heap type and all direct / `call_ref` users;
- preserve distinct nominal heap types even when two signatures shrink to the same final function shape;
- rewrite `TypeSec`, `FuncSec`, direct call sites, `call_ref` type immediates, and callee locals coherently;
- repair local indices and validation stack behavior after removed params become locals;
- localize blocked effectful operands before the second pass cycle;
- cap the rewrite at the source-backed two-cycle behavior unless a later source check justifies a fixed point.

For the upstream details and local port ladder, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./constant-actuals-localization-and-boundaries.md`](./constant-actuals-localization-and-boundaries.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)

## Nearby boundaries to keep distinct

### `dead-argument-elimination`

See [`../dead-argument-elimination/index.md`](../dead-argument-elimination/index.md).

DAE works from individual functions and direct call surfaces.
`signature-pruning` works from nominal function heap types and can update `call_ref` users when all uses of the heap type agree.
Do not collapse the two into one pass name or one proof model.

### `signature-refining`

See [`../signature-refining/index.md`](../signature-refining/index.md).

`signature-refining` changes parameter and result types.
`signature-pruning` removes parameters.
They sit next to each other in Binaryen's closed-world GC/type cluster, but their transformations and repair obligations are different.

### `type-refining`

See [`../type-refining/index.md`](../type-refining/index.md).

`type-refining` changes struct field declaration types.
`signature-pruning` changes function heap-type arity and call surfaces.
Both need closed-world GC/type reasoning, but they own different declaration surfaces.

### `global-refining`

See [`../global-refining/index.md`](../global-refining/index.md).

`global-refining` changes global declaration types after collecting global writes.
`signature-pruning` changes nominal function signatures after collecting parameter liveness and call actuals.
They belong to the same broad closed-world tightening cluster, not the same implementation engine.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep boundary-only rejection until the transform exists;
   - move `signature-pruning` to an active category only when the module pass exists.
2. no-op gates
   - no GC;
   - missing closed-world mode;
   - any table in the module;
   - imported/public/tag/continuation/JS/intrinsic/subtype blockers.
3. direct-call positives
   - single function losing one unused param;
   - all params removed;
   - overwritten incoming param counted dead by entry liveness.
4. heap-type aggregation
   - two functions sharing one type where one live sibling blocks removal;
   - two distinct function heap types that shrink to the same textual shape but stay distinct.
5. `call_ref` positives and negatives
   - removable `call_ref` actuals update with the signature;
   - table-mediated or indirect forms stay blocked until explicitly supported.
6. constant-actual promotion
   - integer, `ref.func`, and `ref.null` constants;
   - disagreement or effectful constants block or defer correctly.
7. localization and second-cycle behavior
   - effectful actuals that only optimize after localization;
   - no unbounded rerun loop.
8. round-trip and validation
   - WAT fixture support where available;
   - library/binary fixtures for direct `CallRef` until ordinary `call_ref` text lowering exists;
   - `moon test` and focused Binaryen comparison once the pass is implemented.

Until those layers exist, the correct Starshine behavior remains the current boundary-only rejection.
