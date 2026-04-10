---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./parity.md
---

# Binaryen `remove-unused-module-elements` Strategy

## Upstream Source Rule

- Primary source: Binaryen `version_129` `src/passes/RemoveUnusedModuleElements.cpp`.
- Upstream treats this as module-wide dead-element elimination, not merely dead-function pruning.

## Three-State Model

- Upstream distinguishes three states for a module element:
  - no references at all: remove it
  - references but no uses: keep an entity to refer to, but it may be weakenable
  - uses: keep it as a fully live element
- That distinction matters for things like `ref.func`, `call_ref`, indirect calls, and other carriers where "referenced" is weaker than "definitely executed".

## Analysis Strategy

- Walk expressions and note:
  - used module elements
  - referenced module elements
  - `call_ref` heap types
  - `ref.func` targets
  - struct-field reads
  - indirect-call table plus heap-type pairs
- Propagate liveness from the current used set until no new reachable module items appear.
- Only after that analysis phase does upstream decide which elements can be removed or simplified.

## Practical Consequences

- This pass has to understand much more than direct calls.
- Tables, memories, tags, element segments, and data segments all participate in the liveness graph.
- Active segments can keep imported parents alive.
- A correct implementation needs section-aware remapping after removal, not just a filtered function list.

## Practical Rule For This Wiki

- Keep "upstream Binaryen strategy" distinct from the narrower in-tree Starshine implementation details.
- When comparing parity, ask first whether a mismatch is:
  - a liveness decision gap
  - a reference-vs-use distinction gap
  - or a post-removal rewrite gap

## Sources

- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
- Binaryen `version_129` no-DWARF pipeline source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
