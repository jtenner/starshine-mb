---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../../../raw/wasm/2026-05-20-call-ref-source-refresh.md
  - ../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md
  - ../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-signature-refining-port-readiness-primary-sources.md
  - ../../../raw/research/0398-2026-04-26-signature-refining-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./params-results-publicity-and-intrinsics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./params-results-publicity-and-intrinsics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../signature-pruning/index.md
  - ../type-refining/index.md
  - ../global-refining/index.md
---

# `signature-refining`: Starshine port readiness and validation

Use this page when turning the existing `signature-refining` dossier into implementation work.
The rest of the folder explains the upstream Binaryen contract; this page turns that contract into a Starshine-first implementation ladder, with the ordinary-`call_ref` fixture guidance narrowed by the 2026-05-20 call-ref refresh in [`../../../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../../../raw/wasm/2026-05-20-call-ref-source-refresh.md).

## Current status in one sentence

`signature-refining` is still **boundary-only** in Starshine: the name is known, active requests are rejected, and no local owner pass exists yet.

Relevant local anchors:

- [`src/passes/optimize.mbt#L127-L135`](../../../../../src/passes/optimize.mbt#L127-L135) keeps `signature-refining` in `pass_registry_boundary_only_names()`.
- [`src/passes/optimize.mbt#L518-L520`](../../../../../src/passes/optimize.mbt#L518-L520) rejects active boundary-only requests.
- [`src/passes/optimize.mbt#L434-L449`](../../../../../src/passes/optimize.mbt#L434-L449) keeps the active `optimize` / `shrink` presets free of boundary-only names.
- No `src/passes/signature_refining.mbt` owner file exists today.

## Binaryen behavior a future port must preserve

A faithful port must preserve these source-backed facts from [`./binaryen-strategy.md`](./binaryen-strategy.md):

1. Run only when GC is available.
2. Bail out when tables exist.
3. Decide per nominal function heap type, not per function body.
4. Collect direct `call`, `call_ref`, `call.without.effects`, and returned-value facts.
5. Use argument LUBs for parameter refinement.
6. Use returned-value LUBs for result refinement.
7. Freeze public, imported, tag-used, and subtype-linked function types.
8. Freeze only parameter refinement for JS-called and continuation-used signatures.
9. Repair function bodies before rewriting nominal signatures when sharper params would invalidate old local writes.
10. Rewrite signature heap types atomically, including `call_ref` users.
11. Clone `call.without.effects` imports when result refinement changes the intrinsic signature.
12. Refinalize after all type and call-surface updates.

The simplest correct Starshine implementation is therefore a module/type-graph pass, not a HOT peephole.

## Starshine prerequisite map

| Need | Local surface today | Readiness |
| --- | --- | --- |
| Known pass name and diagnostics | `src/passes/optimize.mbt` boundary-only registry | ready for first red/green registry tests |
| Function type declarations | [`src/lib/types.mbt#L98-L105`](../../../../../src/lib/types.mbt#L98-L105), [`src/lib/types.mbt#L147-L168`](../../../../../src/lib/types.mbt#L147-L168), [`src/lib/types.mbt#L416-L433`](../../../../../src/lib/types.mbt#L416-L433) | representation exists |
| Direct calls and `call_ref` IR | [`src/lib/types.mbt#L520-L532`](../../../../../src/lib/types.mbt#L520-L532) | representation exists |
| Text fixtures for direct calls | `src/wast/parser.mbt` call and `call_indirect` cases | ready |
| Text fixtures for direct `call_ref` | [`src/wast/parser.mbt#L365-L370`](../../../../../src/wast/parser.mbt#L365-L370), [`src/wast/parser.mbt#L1882-L1887`](../../../../../src/wast/parser.mbt#L1882-L1887) | gap: parser exposes `return_call_ref`, not direct `call_ref` |
| Binary `call_ref` round trip | [`src/binary/decode.mbt#L2568-L2575`](../../../../../src/binary/decode.mbt#L2568-L2575), [`src/binary/encode.mbt#L2032-L2040`](../../../../../src/binary/encode.mbt#L2032-L2040) | ready |
| Call-family validation | [`src/validate/typecheck.mbt#L894-L956`](../../../../../src/validate/typecheck.mbt#L894-L956), [`src/validate/typecheck.mbt#L990-L1049`](../../../../../src/validate/typecheck.mbt#L990-L1049), [`src/validate/typecheck.mbt#L3214-L3220`](../../../../../src/validate/typecheck.mbt#L3214-L3220) | ready for post-rewrite validation checks |
| `call.without.effects` parity | repo search under `src/` | gap: no local spelling found |
| Shared nominal type rewriter | no obvious dedicated surface | gap: likely new module-pass infrastructure |

## Recommended implementation ladder

### Slice 0: registry honesty stays green

Before writing the pass, add or refresh tests proving the current status:

- `signature-refining` is listed as boundary-only.
- `--pass signature-refining` rejects with the boundary-only diagnostic.
- active presets do not contain the name.

This guards against accidental silent no-op behavior while the implementation is incomplete.

### Slice 1: no-rewrite module analyzer

Add a module pass skeleton that computes facts but always returns the original module.
Minimum facts to prove in tests:

- GC feature absent => no work.
- any table present => no work.
- function heap types are collected by nominal type index.
- imports and tag-used signatures are classified as frozen.
- direct-call argument types are visible to the analyzer.

Exit criterion: the pass can print or test its analysis decisions without mutating signatures.

### Slice 2: private direct-call param refinement only

Implement the smallest useful transform:

- one private function type;
- one or more functions using that type;
- no imports, tags, tables, subtyping blockers, `call_ref`, or `call.without.effects`;
- actual arguments have a strictly sharper common ref type;
- only parameter types change;
- function body locals still validate without fixup-local insertion.

Before/after shape:

```wat
;; before
(type $sig (sub (func (param anyref))))
(type $s (struct))
(func $target (type $sig) (param anyref) nop)
(func $caller (call $target (struct.new $s)))

;; after
(type $sig (sub (func (param (ref (exact $s))))))
(func $target (type $sig) (param (ref (exact $s))) nop)
(func $caller (call $target (struct.new $s)))
```

Validation:

- Starshine output validates.
- Binaryen `--signature-refining` output has the same normalized type shape for this family.
- public/import/table/tag/subtype negatives remain unchanged.

### Slice 3: shared heap-type fanout

Extend slice 2 so all functions sharing the refined heap type update together, even when only one sibling is called.
This is the first important guard against a false per-function implementation.

### Slice 4: body fixup locals

Add the Binaryen-backed case where sharpening a param would make an existing local write invalid.
The port needs a Starshine equivalent of Binaryen `TypeUpdating::updateParamTypes(...)` before this slice can be correct.

### Slice 5: result refinement

Add returned-value LUB analysis and result-signature rewriting.
This slice should include:

- body-result positives;
- explicit `return` positives;
- `return_call` / `return_call_indirect` / `return_call_ref` evidence as supported locally;
- surrounding expression refinalization checks.

### Slice 6: `call_ref` and `return_call_ref`

Use binary or library fixtures first because the 2026-05-20 call-ref refresh keeps ordinary non-tail `call_ref` outside high-level Starshine WAST text.
Do not claim text-fixture parity until direct `call_ref` WAST parsing/lowering/printing is added.

### Slice 7: `call.without.effects` parity

This is not optional for full Binaryen parity.
Until Starshine models the intrinsic, document the pass as a scoped subset.
When it lands, test both:

- extra-call operands participating in param refinement;
- cloned import signatures after result refinement.

## Validation ladder

1. Unit tests for analyzer classification and boundary-only-to-active registry transition.
2. Focused WAT or library fixtures for direct-call param positives and frozen negatives.
3. Binary round-trip tests for any `call_ref` / `return_call_ref` fixture families.
4. `moon test` after each slice.
5. Pass-targeted oracle comparison once the pass has a visible transform:
   - `bun fuzz compare-pass --pass signature-refining ...` after the harness can invoke the local pass name.
6. A 10,000-case pass-targeted fuzz run before marking the pass implemented.
7. Preset scheduling only after the closed-world GC/type cluster policy is explicit; do not add it to the current open-world no-DWARF preset by accident.

## Non-goals for the first implementation

- Do not implement this as a HOT peephole.
- Do not mutate public or imported function types in the first slice.
- Do not handle tables until the Binaryen source has a different strategy or Starshine deliberately designs one.
- Do not claim `call.without.effects` parity while the local IR has no such spelling.
- Do not add the pass to `optimize` / `shrink` merely because the explicit pass flag works.

## Health notes from the 2026-05-05 check

- The existing folder was internally source-correct, so this follow-up adds a freshness bridge rather than superseding the Binaryen strategy.
- The current-main source recheck again found no teaching-relevant drift from the `version_129` dossier.
- The most actionable local hygiene issue is still the direct `call_ref` text-surface gap: the 2026-05-20 call-ref refresh keeps ordinary non-tail `call_ref` as core/binary/validator/generator-visible but not high-level Starshine WAST text, so future tests should not assume WAST can express every Binaryen proof family until that gap is closed.

## Sources

- [`../../../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../../../raw/wasm/2026-05-20-call-ref-source-refresh.md)
- [`../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md)
- [`../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-signature-refining-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-signature-refining-port-readiness-primary-sources.md)
- [`../../../raw/research/0398-2026-04-26-signature-refining-port-readiness.md`](../../../raw/research/0398-2026-04-26-signature-refining-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
