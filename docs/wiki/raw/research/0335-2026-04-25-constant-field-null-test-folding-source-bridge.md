# 0335 - `constant-field-null-test-folding` source bridge

## Scope

- Continue the pass-wiki health campaign on 2026-04-25.
- Pick one pass whose coverage was incomplete, unclear, stale, or missing direct Starshine follow-along coverage.
- Chosen pass: local `constant-field-null-test-folding` / upstream `cfp-reftest`.

## Why this pass was chosen

The dossier already had a useful landing page, Binaryen strategy page, implementation/test map, matcher-mechanics page, and WAT-shape page.
It still had two durable gaps:

1. no sibling-specific immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, relying instead on the parent `constant-field-propagation` capture plus older research notes;
2. no dedicated `constant-field-null-test-folding/starshine-strategy.md`, forcing readers to infer local status from the parent CFP Starshine page.

That was enough to make the pass a good health target: the local name is easy to misread as a generic null-test optimizer, so the source and Starshine mapping should be explicit at the sibling page level.

## Sources consulted

Primary online sources captured in:

- `docs/wiki/raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md`

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
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- neighboring dossiers for `constant-field-propagation`, `global-type-optimization`, `type-refining`, and `global-struct-inference`

## Binaryen reading retained

- Upstream public pass name: `cfp-reftest`.
- Local Starshine pass name: `constant-field-null-test-folding`.
- Owner file: `src/passes/ConstantFieldPropagation.cpp`.
- Registration file: `src/passes/pass.cpp`.
- Dedicated lit proof file: `test/lit/passes/cfp-reftest.wast`.
- The pass is still a mode of ordinary closed-world CFP, not a separate analysis engine.
- `cfp-reftest` uses `ConstantFieldPropagation(true)` to enable the extra `ref.test` rescue path.
- The visible output remains narrow: replace an eligible `struct.get`-style read with a `select` over two CFP replacement payloads and a synthesized `ref.test`.
- The variant is downstream of ordinary CFP field facts and is not a generic existing-`ref.test`, null-check, or control-flow simplifier.

## Starshine status found

Current Starshine status is boundary-only:

- `src/passes/optimize.mbt#L127-L140` includes `constant-field-null-test-folding` in `pass_registry_boundary_only_names()` next to the parent `constant-field-propagation` name.
- `src/passes/optimize.mbt#L266-L268` creates boundary-only registry entries.
- `src/passes/optimize.mbt#L446-L463` rejects active requests for boundary-only names with a boundary-only error.
- `src/passes/optimize.mbt#L240-L263` keeps active presets limited to implemented module/HOT passes.
- `src/passes/registry_test.mbt#L121-L158` asserts that preset expansions stay on implemented `HotPass` or `ModulePass` entries.
- There is no `src/passes/constant_field_null_test_folding.mbt`, `src/passes/cfp_reftest.mbt`, or other owner file matching the pass.
- `agent-todo.md` has no dedicated `constant-field-null-test-folding` or `cfp-reftest` slice.

Reusable local infrastructure exists, but it is prerequisite surface, not an implementation:

- `src/lib/types.mbt#L31-L57` models heap/ref/value types.
- `src/lib/types.mbt#L733-L761` represents `StructGet`, `StructGetS`, `StructGetU`, `StructSet`, `RefTest`, and descriptor/ref opcodes.
- `src/wast/parser.mbt#L410-L437` and `src/wast/lower_to_lib.mbt#L2418-L2453` parse and lower GC/descriptor instructions.
- `src/validate/typecheck.mbt#L1868-L1930` validates `ref.test` and related cast/descriptor forms.
- `src/validate/typecheck.mbt#L2115-L2178` validates struct gets/sets and packed-field read variants.
- `src/binary/encode.mbt#L2629-L2659` and the paired decoder represent the GC opcode surface a future transform would rewrite and re-emit.

## Pages created or updated

Created:

- `docs/wiki/raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md`
- `docs/wiki/raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/starshine-strategy.md`

Updated:

- `docs/wiki/binaryen/passes/constant-field-null-test-folding/index.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md`
- `docs/wiki/binaryen/passes/constant-field-null-test-folding/wat-shapes.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Health notes

- The folder now has a sibling-specific raw manifest and a dedicated Starshine status page, so future wiki work should not treat either gap as open.
- The sibling remains unimplemented and boundary-only; the docs now say that directly in the sibling folder rather than relying only on the parent CFP page.
- The local-name caveat remains important: “constant-field-null-test-folding” is a local alias for upstream `cfp-reftest`, not a generic null-test pass.

## Follow-up questions

- If a future closed-world GC/type-analysis backlog slice is opened, decide whether the shared CFP field-fact infrastructure should serve `constant-field-propagation`, `constant-field-null-test-folding`, `type-refining`, and `global-type-optimization` together.
- Before implementing parity, re-check current Binaryen and Wasm GC validation rules for nonnullable `ref.test` emission and nullable-base repair.
