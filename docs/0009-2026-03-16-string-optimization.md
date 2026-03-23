# StringGathering Re-implementation Blueprint

Status: researched and implementation-ready blueprint.

Prerequisite status: the direct `string.const` instruction surface is now landed in [`docs/0052-2026-03-22-string-const-surface.md`](/home/jtenner/Projects/starshine-mb/docs/0052-2026-03-22-string-const-surface.md), so this pass is no longer blocked on missing literal IR support.
Slice status: [`docs/0053-2026-03-22-string-gathering-existing-global-reuse.md`](/home/jtenner/Projects/starshine-mb/docs/0053-2026-03-22-string-gathering-existing-global-reuse.md) lands the first implementation slice, reusing existing immutable defining globals in raw and typed function bodies; missing-global synthesis, module-level patchpoints, and global-order repair are still open.

## Executive Summary
`StringGathering` lifts all `string.const` to immutable globals and rewrites uses to `global.get`, reducing runtime creation cost.

## Behavior to Match
- In a `string-gathering`-style pass:
  - scan defined functions and module code for `string.const`,
  - create/reuse immutable `(ref string)` globals,
  - replace remaining uses with `global.get` to the defining global.
- Preserve existing reusable global initializers to avoid self-reference cycles.
- Sort per-string global additions deterministically.
- Make defining globals reachable in initializer order.

## Reuse Rules
- Reuse only when global is:
  - defined (not imported),
  - immutable,
  - exactly `(ref string)`,
  - initialized by direct `string.const`.
- First eligible global per string is canonical.
- Wrong-type, mutable, imported, and non-eligible globals are not reused.

## Single-Walk Shape
1. Pre-scan globals for reusable defining globals and preserve their init slots.
2. One walk over all defined function bodies + module code, collecting mutable patchpoints and unique strings.
3. Sort unique strings deterministically.
4. Add missing defining globals with deterministic names (`string.const_...` with escaping/uniquifier).
5. Reorder globals so defining globals appear before dependents.
6. Rewrite all collected patchpoints except preserved defining initializers.

## Data Needed
- patchpoint list for each `string.const` site
- `string -> defining global` map
- `preserve` set for canonical initializer patchpoints
- ordered global name pool and feature-gate check

## Complexity
- O(N) walk + O(U) string collection + O(U log U) sort
- O(K) rewrite, where K is `string.const` occurrences
- O(G) global reorder (stable partition preferred)

## Pipeline Placement
- Run in global post pipeline under `optimize >= 2` and Strings-feature gate.
- Prefer right before `reorder-globals` (existing placement convention).

## Test Set (Binaryen-aligned)
- reuse eligible immutable global
- wrong type string global rejected
- imported globals ignored
- duplicate defining globals collapse to first canonical
- mutable defining global rewritten to immutable canonical
- global-order repair for initializer dependencies
- idempotence (pass is no-op on second run)

## Risk Notes
- If Starshine indexes globals, global permutation updates are required after reorder; fail fast if not implemented.
- Sorting behavior must remain deterministic across runs.
- Preserve existing defining global initializers to avoid invalid self-references.
