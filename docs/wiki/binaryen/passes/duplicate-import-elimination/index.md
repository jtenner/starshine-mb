---
kind: entity
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md
  - ../../../raw/research/0205-2026-04-21-duplicate-import-elimination-source-confirmation-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ../inlining-optimizing/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `duplicate-import-elimination`

## Role

- `duplicate-import-elimination` is an upstream Binaryen late module / boundary cleanup pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Binaryen runs it in the late post-pass cluster after the second `duplicate-function-elimination` and before `simplify-globals-optimizing`.

## Why this dossier needed a follow-up

This folder used to teach a much broader contract than Binaryen `version_129` actually implements.

The source-confirmation follow-up corrected the biggest mistake:

- current Binaryen `version_129` `duplicate-import-elimination` is a **function-import-only** alias-cleanup pass.

It does **not** currently deduplicate imported:

- globals
- tables
- memories
- tags

That correction comes directly from `src/passes/DuplicateImportElimination.cpp`, whose own opening comment says:

- `TODO: non-function imports too`

So this folder should now be read as a corrected, source-confirmed dossier rather than as a broad all-import working contract.

## Why it still matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `duplicate-import-elimination` after the second `duplicate-function-elimination` and before `simplify-globals-optimizing`.
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - top-level slot `51`
- The saved Binaryen debug log shows the pass is tiny but real:
  - `2.133e-05` seconds in the captured generated-artifact run
- `agent-todo.md` already has a dedicated slice for the pass under `DIE`.

## Correct beginner summary

A safe beginner mental model for Binaryen `version_129` is:

- if the module imported the same host **function** more than once under different internal names,
- and those imports have the same function type,
- Binaryen keeps the first imported function name,
- rewrites later direct function-name users to that first name,
- then deletes the later imported function declarations.

That is much closer to the real pass than either:

- “remove unused imports”, or
- “merge all duplicate imports of every kind.”

## Current durable takeaways

- `duplicate-import-elimination` is a **late module / boundary** pass, not a function-local peephole.
- In Binaryen `version_129`, it scans only:
  - imported functions
- Duplicate detection is not the broad `ImportInfo(kind,module,base,type)` story taught in the earlier dossier.
  The actual pass groups imports by:
  - `(module, base)`
  and then requires:
  - exact `Function::type` equality with the first-seen import for that pair.
- The canonical representative is simply the **first import seen** for that `(module, base)` bucket.
- The real rewrite surface is exactly the function-name surface in `OptUtils::replaceFunctions(...)`:
  - direct `call`
  - `ref.func`
  - function references found in module-code expression trees
  - `start`
  - function exports
- The pass removes duplicate imported functions immediately after retargeting users.
- The shipped dedicated test is correspondingly small and function-only.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Corrected strategy page for the real Binaryen `version_129` implementation: small late function-import alias cleanup, exact duplicate key, exact rewrite surface, and nearby non-goals.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact owner-file and shipped-test map showing that the real pass lives in `DuplicateImportElimination.cpp`, uses only `replaceFunctions(...)`, and is proven by one dedicated function-only test pair.
- [`./identity-and-rewrite-surface.md`](./identity-and-rewrite-surface.md)
  Focused guide to the exact duplicate key and rewrite surface, including the crucial correction from the older dossier's over-broad all-import story.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after WAT and module-shape catalog for the real positive function-import families, the preserved different-signature family, and the explicit current non-goals.

## Current maintenance rule

- Treat this folder as the canonical home for future `duplicate-import-elimination` research and port planning.
- Treat the older broad all-import story as superseded by the 2026-04-21 source-confirmation follow-up.
- Keep the folder explicitly marked as **unimplemented** until Starshine grows a real late module pass with the same function-import-only contract as Binaryen `version_129`, or until a deliberate divergence is documented.
- If future upstream Binaryen expands the pass beyond functions, record that as new drift instead of silently widening this `version_129` contract.

## Sources

- [`../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md`](../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md)
- [`../../../raw/research/0205-2026-04-21-duplicate-import-elimination-source-confirmation-followup.md`](../../../raw/research/0205-2026-04-21-duplicate-import-elimination-source-confirmation-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateImportElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.txt>
