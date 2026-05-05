# 0475 - `constant-field-null-test-folding` current-main recheck

## Scope

- Continue the pass-wiki health campaign on 2026-05-05.
- Pick one pass whose coverage was still missing a sibling-specific current-main freshness bridge.
- Chosen pass: `constant-field-null-test-folding` / upstream `cfp-reftest`.

## Why this pass was chosen

The parent `constant-field-propagation` dossier already had a 2026-05-05 current-main bridge, but the sibling page still relied on the older 2026-04-25 source bridge.
That left the local-name variant slightly stale even though it is the same CFP engine plus one narrow `ref.test` rescue path.

This recheck keeps the sibling explicit so readers do not have to infer it only from the parent CFP folder.

## Sources consulted

Primary online sources captured in:

- `docs/wiki/raw/binaryen/2026-05-05-constant-field-null-test-folding-current-main-recheck.md`

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
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/index.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/wat-shapes.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/starshine-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-propagation/starshine-port-readiness-and-validation.md`

## Binaryen reading retained

The source-backed CFP sibling story did not change:

- `ConstantFieldPropagation.cpp` still owns both `cfp` and `cfp-reftest`.
- The pass is GC-gated and closed-world-only.
- The ordinary engine still scans struct construction, writes, defaults, and copies before solving field facts over exact/inexact type views and copy edges.
- The tracked replacement domain is deliberately tiny: one literal constant, one immutable global, or unknown.
- `cfp-reftest` still remains the narrow sibling that adds a `select(ref.test(...))` rescue path when exactly two subtype-separated buckets are provable.

## Maintenance result

The local teaching rule is now cleaner:

- use `cfp.wast` as the parent CFP contract surface,
- use `cfp-reftest.wast` as the sibling-variant proof surface,
- use `gto_and_cfp_in_O.wast` as the compact scheduler-neighborhood proof,
- use the sibling-specific current-main bridge when the wiki needs freshness without re-deriving the whole parent folder.

## Pages created or updated

Created:

- `docs/wiki/raw/binaryen/2026-05-05-constant-field-null-test-folding-current-main-recheck.md`
- `docs/wiki/raw/research/0475-2026-05-05-constant-field-null-test-folding-current-main-recheck.md`

Substantially refreshed:

- `docs/wiki/binaryen/passes/constant-field-null-test-folding/index.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/wat-shapes.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Health-check result

The main touched-area health fix folded into this update was the stale sibling freshness bridge.
The folder now has a direct current-main bridge rather than making readers infer the variant only from the parent CFP dossier.

## Follow-up questions

- Should the sibling page keep tracking `cfp-reftest` separately even if future Starshine work lands a shared CFP module-analysis engine?
- Should the parent CFP and sibling CFP pages eventually share one common closed-world GC/type readiness bridge, or stay split so the variant-specific `ref.test` rescue path stays teachable on its own?
