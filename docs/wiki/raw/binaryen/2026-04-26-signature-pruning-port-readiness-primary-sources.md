---
kind: raw-source
status: supported
last_reviewed: 2026-04-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignaturePruning.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signature-pruning.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp
related:
  - ../research/0404-2026-04-26-signature-pruning-port-readiness.md
  - ../../binaryen/passes/signature-pruning/index.md
---

# Binaryen `signature-pruning` current-main port-readiness sources

This is a focused primary-source ingest for the 2026-04-26 Starshine wiki port-readiness bridge for `signature-pruning`.
It supplements the earlier immutable `version_129` manifest in [`2026-04-24-signature-pruning-primary-sources.md`](./2026-04-24-signature-pruning-primary-sources.md) rather than replacing it.

## Checked primary sources

- Binaryen current `main` owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignaturePruning.cpp>
- Binaryen current `main` dedicated lit file: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signature-pruning.wast>
- Binaryen current `main` pass registration / scheduler file: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Helper surfaces used by the pass:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>

## Current-main findings

The current-main owner still teaches the same durable strategy as the 2026-04-24 `version_129` dossier:

- `SignaturePruning::run` returns when GC is absent, fatals without `--closed-world`, and returns without rewriting when the module has tables.
- The pass still runs at most two iterations: one ordinary iteration plus one possible rerun when constant-actual application or delayed call-operand localization can expose more work.
- The fact collection is still function-parallel and still combines direct `Call`, `CallRef`, and entry-used parameter facts by nominal function heap type.
- Imports, public function heap types, tag-used signatures, continuation signatures, JS-called signatures, `call.without.effects` users, and immediate subtype / supertype signature links remain important blockers.
- `ParamUtils::applyConstantValues(...)` still runs before pruning and can make a parameter newly removable.
- `ParamUtils::removeParameters(...)` still edits function bodies and call operands first, then `GlobalTypeRewriter::updateSignatures(...)` atomically rewrites the nominal signature graph.
- `ParamUtils::localizeCallsTo(...)` still happens after signature rewriting, not before, so parameter-local index repair remains part of the source-backed ordering constraint.

## Lit-surface findings

The current dedicated `signature-pruning.wast` file still proves the teaching-relevant families used by this dossier:

- middle, edge, and all-parameter removal from a function type;
- synchronized direct `call` and `call_ref` argument removal;
- incoming-parameter overwrite cases where the parameter index appears but its entry value is dead;
- effectful actual localization before successful removal;
- constant-actual promotion into callee bodies;
- no-op behavior around imported/public/subtyped/tag/continuation/table or otherwise unsupported surfaces.

## No teaching-relevant drift found

This ingest found no teaching-relevant current-main drift from the earlier `version_129` story.
The durable delta for the wiki is not a changed Binaryen algorithm; it is Starshine-side readiness: first slice boundaries, validation order, local code surfaces, and local text/binary fixture caveats are now filed in a dedicated bridge page.

## Uncertainties and caveats

- This was a focused source check of the owner, helper, scheduler, and dedicated test surfaces, not a whole-repository semantic audit.
- GitHub current `main` is moving. Treat this file as a 2026-04-26 spot check and keep future drift notes explicit.
- The local Starshine WAT parser still needs a direct `call_ref` fixture check before future port tests rely only on text WAT; library/binary fixtures may be safer for the first `call_ref` slice.
