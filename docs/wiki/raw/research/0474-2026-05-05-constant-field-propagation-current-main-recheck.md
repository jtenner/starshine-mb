# 0474 - `constant-field-propagation` current-main recheck

## Scope

- Continue the pass-wiki health campaign on 2026-05-05.
- Pick one pass whose coverage was still missing a current-main freshness bridge and a port-readiness page.
- Chosen pass: `constant-field-propagation` / upstream `cfp`.

## Why this pass was chosen

`constant-field-propagation` already had a good upstream strategy dossier, but it still needed a 2026-05-05 freshness bridge and a dedicated Starshine implementation-readiness page so the parent CFP family is easier to teach and port.
The pass is also a good sibling to keep explicit because Starshine preserves both local descriptive names as boundary-only registry entries:

- `constant-field-propagation` for upstream `cfp`
- `constant-field-null-test-folding` for upstream `cfp-reftest`

## Sources consulted

Primary online sources captured in:

- `docs/wiki/raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md`

Local Starshine sources consulted:

- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/lib/types.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/validate/env.mbt`
- `src/validate/typecheck.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/index.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/index.md`
- `docs/wiki/binaryen/passes/global-type-optimization/index.md`
- `docs/wiki/binaryen/passes/type-refining/index.md`
- `docs/wiki/binaryen/passes/global-struct-inference/index.md`

## Binaryen reading retained

The source-backed CFP story did not change:

- `ConstantFieldPropagation.cpp` is the shared engine for upstream `cfp` and `cfp-reftest`.
- The pass is GC-gated and closed-world-only.
- The engine scans struct construction, writes, defaults, copies, and RMW / cmpxchg-style unknowns through shared struct helpers, then solves field facts over exact/inexact type views and copy edges before rewriting reads.
- The tracked value domain is deliberately tiny: no value, one literal constant, one immutable global, or unknown.
- Rewrites target reads, especially `struct.get` / packed variants and descriptor reads; replacements must preserve null traps, packed-field semantics, subtype validity, and atomic synchronization boundaries.
- `cfp-reftest` remains the narrow sibling that adds a `select(ref.test(...))` rescue path when exactly two subtype-separated buckets are provable.

## Main health correction

The parent CFP folder now has a dedicated current-main bridge and a dedicated Starshine readiness page.
That closes the main doc gap for readers who need to move from strategy to implementation planning.

The corrected teaching rule is:

- use `cfp.wast` as the parent CFP contract surface,
- use `cfp-reftest.wast` as the sibling-variant proof surface,
- use `gto_and_cfp_in_O.wast` as the compact scheduler-neighborhood proof,
- use the new Starshine port-readiness bridge when planning an actual port.

## Starshine status found

Current Starshine status is still boundary-only:

- `src/passes/optimize.mbt#L127-L140` includes `constant-field-propagation` and `constant-field-null-test-folding` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt#L266-L268` creates boundary-only registry entries.
- `src/passes/optimize.mbt#L446-L463` rejects active requests for boundary-only names.
- `src/passes/optimize.mbt#L240-L263` keeps active presets limited to implemented passes, and `src/passes/registry_test.mbt#L121-L158` asserts that preset entries are active `HotPass` or `ModulePass` entries.
- There is no `src/passes/constant_field_propagation.mbt` owner file.
- `agent-todo.md` has no dedicated `constant-field-propagation`, `cfp`, `constant-field-null-test-folding`, or `cfp-reftest` implementation slice.

Reusable local infrastructure exists, but it is not the pass:

- `src/lib/types.mbt#L31-L57` has the heap/ref/value type model.
- `src/lib/types.mbt#L136-L159` has `TypeMetadata`, `SubType`, `RecType`, and `DefType`.
- `src/lib/types.mbt#L733-L761` represents struct creation, struct field reads/writes, descriptor reads, and descriptor tests/casts.
- `src/wast/parser.mbt#L410-L437` parses WAT-side struct/descriptor instruction variants.
- `src/wast/lower_to_lib.mbt#L2418-L2453` lowers WAT type immediates for those instructions to library instructions.
- `src/validate/env.mbt#L150-L181` resolves type/heap/subtype facts.
- `src/validate/env.mbt#L246-L272` populates validation environments from rec groups.
- `src/validate/env.mbt#L395-L435` encodes descriptor-result rules.
- `src/validate/typecheck.mbt#L1868-L1930` validates `ref.get_desc`, `ref.test`, casts, and descriptor compatibility.
- `src/validate/typecheck.mbt#L2115-L2178` validates struct field reads/writes and packed-field read forms.
- `src/validate/typecheck.mbt#L3277-L3290` dispatches those instruction validators.
- `src/binary/encode.mbt#L2629-L2659` encodes the GC struct-field read family.

## Pages created or updated

Created:

- `docs/wiki/raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md`
- `docs/wiki/raw/research/0474-2026-05-05-constant-field-propagation-current-main-recheck.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-port-readiness-and-validation.md`

Substantially refreshed:

- `docs/wiki/binaryen/passes/constant-field-propagation/index.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Health-check result

The main touched-area health fix folded into this update was the stale `constant-field-propagation` freshness note.
The new port-readiness bridge and current-main bridge now give the folder a cleaner stepping stone from upstream contract to local implementation planning.

## Follow-up questions

- Should Starshine eventually build a shared closed-world struct-field fact engine for `constant-field-propagation`, `constant-field-null-test-folding`, `type-refining`, `global-type-optimization`, and `global-struct-inference` instead of landing one-off module passes?
- What API surface should represent closed-world mode locally before boundary-only GC/type passes become active?
- Should registry tests add direct assertions for every boundary-only GC/type name, including both CFP-family local names, or keep relying on the pass registry list and preset exclusion tests?
