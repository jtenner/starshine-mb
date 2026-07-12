# Binaryen `inlining` current-main toolchain-inline-hint recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source correction for the living `inlining` and `inlining-optimizing` dossiers

## Scope

This narrow recheck supersedes the **freshness claim** in the 2026-06-02 inlining bridge only where that bridge said current `main` had no teaching-relevant inliner-policy drift. It does not replace the tagged `version_129` source manifest or the older no-inline / clone-survival evidence.

The trigger was a current-main review of the shared inliner. It found a material new policy input: a function-level **toolchain inline hint**. The finding applies to both public inliner names because they share `Inlining.cpp`.

## Primary sources reread

### Upstream Binaryen `main`

- Shared owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Inlining.cpp>
- Public pass registration/scheduling context: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Historical no-inline policy/source distinction: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/NoInline.cpp>

### Current Starshine evidence consulted

- Shared local owner: `src/passes/inlining.mbt`
- Local no-inline policy: `src/passes/no_inline.mbt`
- Registry/presets: `src/passes/optimize.mbt`
- Dispatcher: `src/passes/pass_manager.mbt`

## Current upstream result

Current Binaryen `main` extends `FunctionInfo` with an optional `toolchainInlineHint`. During the function scan, `Inlining.cpp` copies it from `func->funcAnnotations.toolchainInline`.

The full-inlining profitability check now applies this ordering:

1. reject a function containing `try_delegate`;
2. if the toolchain hint is `CodeAnnotation::NeverInline`, reject full inlining;
3. if the toolchain hint is `CodeAnnotation::AlwaysInline`, accept full inlining;
4. otherwise continue with the existing tiny, one-use, shrinking-trivial, and optimize-level-dependent flexible heuristics.

This is a real semantic policy input, not merely output metadata. The existing source facts remain true: the planner still records only direct `call` targets for recursion/call-cost purposes, deliberately omitting `call_indirect` and `call_ref`; copied-body repair still handles broader call forms.

## What this correction does **not** establish

- It does **not** show that arbitrary `@metadata.code.inline` byte payloads are the new control. The reviewed field is `funcAnnotations.toolchainInline`, whereas the older dossier's `CodeAnnotation::inline_` discussion concerns a separate inline-metadata surface.
- It does **not** supersede the separate `no-inline`, `no-full-inline`, and `no-partial-inline` policy family or the existing evidence that its flags survive cloning.
- It does **not** prove how Binaryen parses, encodes, or exposes the toolchain hint to WAT/CLI users. Those producer/format surfaces were outside this narrow reread.
- It does **not** demonstrate Starshine support. Starshine's current `no-inline*` markers are local function annotations; its documented `metadata.code.inline` handling remains metadata-only and lacks Binaryen's general expression/code-annotation model.

## Consumability rule

Use this capture for the current-main correction that toolchain `AlwaysInline` / `NeverInline` affects Binaryen full-inlining eligibility after the `try_delegate` bailout and before ordinary profitability thresholds. Keep the older `@metadata.code.inline` versus `no-inline*` material for its narrower, separately sourced distinction. Any future Starshine port needs an explicit representation, parser/binary, precedence, fixture, and compare-pass plan rather than treating this source correction as local feature support.
