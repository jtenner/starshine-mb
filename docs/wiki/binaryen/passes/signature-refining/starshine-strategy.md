---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md
  - ../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../signature-pruning/index.md
  - ../global-refining/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./params-results-publicity-and-intrinsics.md
  - ./wat-shapes.md
  - ../signature-pruning/index.md
  - ../global-refining/index.md
  - ../type-refining/index.md
  - ../constant-field-propagation/index.md
---

# Starshine Strategy For `signature-refining`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main infrastructure gaps a future parity port must resolve.

## The honest current status

`signature-refining` is still **unimplemented** in Starshine.
There is no `src/passes/signature_refining.mbt`, `src/passes/signature-refining.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `signature-refining` in the registry as a known boundary-only name;
- reject active requests honestly instead of silently no-oping;
- keep the upstream closed-world GC/type-cluster contract visible in the wiki;
- keep its absence from the canonical open-world no-DWARF path explicit;
- keep the missing dedicated backlog slice explicit;
- document why a future port is module/type-graph and function-body rewrite work, not a HOT peephole.

This is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
    - `pass_registry_boundary_only_names()` includes `"signature-refining"` beside the neighboring `"signature-pruning"` spelling.
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
    - the built-in `optimize` and `shrink` presets expand only the currently implemented module/HOT sequence and do not include `signature-refining`.
  - [`src/passes/registry_test.mbt#L129-L158`](../../../../../src/passes/registry_test.mbt#L129-L158)
    - the preset test asserts every expanded preset name is `HotPass` or `ModulePass`, which keeps boundary-only names out of the active default path.
- boundary-only planning provenance
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L60)
    - the pass-port map groups `signature-refining` with type, global, and signature shaping names rather than HOT cleanup names.
- function type and nominal type representation a future port would have to rewrite
  - [`src/lib/types.mbt#L98-L105`](../../../../../src/lib/types.mbt#L98-L105)
    - `TypeIdx` and `FuncIdx` are explicit typed indices.
  - [`src/lib/types.mbt#L147-L168`](../../../../../src/lib/types.mbt#L147-L168)
    - `SubType`, `RecType`, and `TagType` model nominal type declarations and tag boundaries that can freeze a function heap type.
  - [`src/lib/types.mbt#L416-L433`](../../../../../src/lib/types.mbt#L416-L433)
    - `FuncType`, `TypeSec`, and `FuncSec` encode the function signature and function-section surface a future module pass must update.
  - [`src/lib/types.mbt#L525-L532`](../../../../../src/lib/types.mbt#L525-L532)
    - `Call`, `CallIndirect`, `ReturnCall`, `ReturnCallIndirect`, `CallRef`, and `ReturnCallRef` are instruction variants, which keeps the direct-call, table-mediated, and reference-call boundaries visible.
  - [`src/lib/types.mbt#L2987-L3019`](../../../../../src/lib/types.mbt#L2987-L3019)
    - constructor helpers exist for direct calls, indirect calls, tail calls, `call_ref`, and `return_call_ref`.
- WAT parser and lowerer surfaces a future port can reuse for fixtures
  - [`src/wast/parser.mbt#L1240-L1368`](../../../../../src/wast/parser.mbt#L1240-L1368)
    - type-use parsing is centralized and shared by type-index-bearing text forms.
  - [`src/wast/parser.mbt#L365-L370`](../../../../../src/wast/parser.mbt#L365-L370)
    - the WAT AST currently exposes call, indirect-call, return-call, indirect-return-call, and `return_call_ref` variants; this local text AST does not show a direct `CallRef` variant beside `ReturnCallRef`.
  - [`src/wast/parser.mbt#L1882-L1887`](../../../../../src/wast/parser.mbt#L1882-L1887)
    - `return_call_ref` parses with a type use today.
  - [`src/wast/lower_to_lib.mbt#L1934-L1981`](../../../../../src/wast/lower_to_lib.mbt#L1934-L1981)
    - `call_indirect`, `return_call_indirect`, and `return_call_ref` lower type-use-bearing WAST forms to library instructions.
  - current WAT caveat
    - this follow-up confirmed the library, binary, generator, and validator surfaces for `CallRef`; it did **not** find a direct `CallRef` WAT parser/lowerer case beside the `ReturnCallRef` case, so future text-fixture work should verify or add direct `call_ref` text lowering before relying only on WAT fixtures.
- validation surfaces a future port must preserve after refining signatures
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
  - [`src/validate/typecheck.mbt#L6394-L6427`](../../../../../src/validate/typecheck.mbt#L6394-L6427)
    - dedicated tests keep `CallRef` and `ReturnCallRef` validation behavior visible.
- binary encoder/decoder surfaces a future port must keep coherent after rewrites
  - [`src/binary/decode.mbt#L2568-L2575`](../../../../../src/binary/decode.mbt#L2568-L2575)
    - binary `call_ref` / `return_call_ref` opcodes decode with `TypeIdx` immediates.
  - [`src/binary/encode.mbt#L2032-L2040`](../../../../../src/binary/encode.mbt#L2032-L2040)
    - the same instruction variants encode back with `TypeIdx` immediates.
- missing `call.without.effects` local surface
  - repo search found no `call.without.effects` spelling under `src/` in this run.
  - a future faithful port must either add that intrinsic import/call model or explicitly document why the local Binaryen-parity subset excludes it.
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `signature-refining` in the active default route.
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `signature-refining` slice.

That map is the durable local status today: the pass is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's `signature-refining` changes nominal function signatures, function declarations, call result types, `call_ref` users, and some function bodies together after heap-type-level analysis.
The transformed shapes appear across:

- private function heap-type declarations and rec groups;
- function section entries and imported function types;
- direct `call` and `return_call` operand/result surfaces;
- `call_ref` and `return_call_ref` type immediates;
- function bodies when sharper params require broader fixup locals;
- surrounding control expressions whose result type sharpens after call/result refinement;
- `call.without.effects` imports whose result type must be cloned after refinement;
- public/imported/tag/continuation/table/JS/subtyping boundary families.

A faithful Starshine port would need to reason over:

- the module's full function heap-type inventory;
- which function types are public or externally visible;
- imported functions, tags, continuations, tables, JS-call intrinsics, and `call.without.effects` imports;
- all direct calls, `call_ref` uses, return calls, and returned values for a nominal function heap type;
- param LUBs across every actual argument reaching that type;
- result LUBs across every body and explicit/tail return produced by functions of that type;
- safe insertion of fixup locals when param sharpening would invalidate existing broader local writes;
- synchronized nominal signature rewriting across `TypeSec`, `FuncSec`, direct calls, and `call_ref` type immediates;
- intrinsic import cloning for refined `call.without.effects` result signatures;
- validation and refinalization after every changed signature and call surface.

Those requirements cross package and module boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass or shared closed-world signature-rewrite engine, not a small `HotFunc` rewrite.

## What Starshine currently does for the pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `signature-refining` in `pass_registry_boundary_only_names()`.
That means:

- the spelling remains discoverable in local registry behavior;
- neighboring GC/type docs can point at one consistent local status;
- future port work has to intentionally move the pass into an implemented category.

### 2. The active pipeline rejects it honestly

When a user requests a boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to tighten signature types;
- the registry category remains executable documentation;
- future implementation work will have to change the category and diagnostics intentionally.

### 3. The active presets exclude it

The Starshine `optimize` and `shrink` presets expand only implemented module/HOT passes today.
The registry test asserts that preset expansions stay on active pass names.
That matches the current local strategy: `signature-refining` has no open-world no-DWARF preset role in this repo today.

### 4. The local pass-port map groups it with boundary shaping

The 2026-03-24 pass-port registry map groups `signature-refining` with type, global, and signature shaping.
That local grouping still matches the source-backed upstream contract better than treating the pass as a function-local peephole.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- return without rewriting when GC is unavailable;
- require an explicit closed-world mode before default-preset scheduling, even though upstream direct invocation relies on conservative blockers rather than a pass-local closed-world fatal guard;
- bail out or deliberately expand the design when tables exist;
- decide per nominal function heap type, not per textual function shape or per individual function;
- collect direct calls, `call_ref` users, `call.without.effects` extra calls, and returned-value evidence separately from table-mediated calls;
- freeze imported and public signature families;
- freeze tag-used and subtype-linked function types completely;
- freeze JS-called and continuation-used params unless Starshine has a documented stronger proof;
- refine params from actual argument LUBs and results from returned-value LUBs;
- insert parameter fixup locals before rewriting signatures when narrowed params would otherwise break old local writes;
- rewrite `TypeSec`, `FuncSec`, direct call result types, `call_ref` type immediates, and surrounding expression types coherently;
- clone or otherwise repair `call.without.effects` imports when refined target results require a sharper intrinsic signature;
- run validation/refinalization after the module-wide rewrite.

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./params-results-publicity-and-intrinsics.md`](./params-results-publicity-and-intrinsics.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `signature-pruning`

See [`../signature-pruning/index.md`](../signature-pruning/index.md).

`signature-pruning` removes parameters.
`signature-refining` keeps arity but changes parameter and result types.
They sit next to each other in Binaryen's closed-world GC/type cluster, but their transformed shapes and repair obligations are different.

### `type-refining`

See [`../type-refining/index.md`](../type-refining/index.md).

`type-refining` changes struct field declaration types.
`signature-refining` changes function heap-type parameter and result types.
Both need closed-world GC/type reasoning, but they own different declaration surfaces.

### `global-refining`

See [`../global-refining/index.md`](../global-refining/index.md).

`global-refining` changes global reference types and retags `global.get` expressions.
`signature-refining` changes nominal function signatures and call/result surfaces.
Do not move one pass's retagging assumptions into the other without a source check.

### `constant-field-propagation`

See [`../constant-field-propagation/index.md`](../constant-field-propagation/index.md).

`constant-field-propagation` can exploit refined GC shapes later in the closed-world cluster, but it does not own the signature LUB analysis.
Keep the scheduler relationship explicit instead of folding the passes together.

## Current uncertainty and follow-up questions

- Starshine has no local `call.without.effects` spelling under `src/` today. A future parity port needs a real intrinsic model or an explicit scoped exclusion.
- Direct `CallRef` exists in the library, validator, generator, and binary encoder/decoder, but this run only found WAT text lowering for `return_call_ref`; future text fixture work should confirm or add direct `call_ref` parser/lowerer coverage before relying on WAT-only regression tests.
- The upstream pass body itself does not require `--closed-world`, while the default scheduler only runs it in the closed-world GC cluster. This dossier treats that as a scheduler-vs-pass-body split and should keep the distinction visible.
- No current Starshine module pass provides reusable public-heap-type discovery, returned-value LUBs, parameter local repair, nominal signature rewriting, or `call.without.effects` import cloning. A future implementation should design that shared infrastructure before trying to port the pass as a one-off rewrite.

## Sources

- [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md)
- [`../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md`](../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- [`../../../../../src/validate/env.mbt`](../../../../../src/validate/env.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
