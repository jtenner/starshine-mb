---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../../../raw/wasm/2026-06-05-tool-conventions-custom-metadata-routing.md
  - ../../../raw/binaryen/2026-05-05-strip-target-features-current-main-recheck.md
  - ../../../raw/research/0483-2026-05-05-strip-target-features-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-strip-target-features-port-readiness-primary-sources.md
  - ../../../raw/research/0429-2026-04-27-strip-target-features-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-strip-target-features-source-correction.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/validate.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../strip-toolchain-annotations/index.md
  - ../remove-relaxed-simd/index.md
  - ../../../binary/custom-and-name-sections.md
---

# Starshine port readiness and validation for `strip-target-features`

## Current decision point

`strip-target-features` is not implemented or registered in Starshine today. A future Starshine change must first make an explicit product/API choice:

1. keep the pass unknown and document it as upstream-only;
2. add a boundary-only or removed registry entry so user-facing errors are deliberate;
3. add a narrow module pass that deletes decoded opaque `target_features` custom sections; or
4. add first-class target-feature metadata and implement a closer Binaryen-style metadata toggle.

Do not treat opaque custom-section round-tripping as an implementation of the pass. Round-tripping can preserve `target_features`; the pass must suppress or clear that metadata. For the shared Starshine `CustomSec` / structured `name` model, `producers` provenance boundary, and placement-normalization caveats, see [`../../../binary/custom-and-name-sections.md`](../../../binary/custom-and-name-sections.md) and [`../../../raw/wasm/2026-06-05-tool-conventions-custom-metadata-routing.md`](../../../raw/wasm/2026-06-05-tool-conventions-custom-metadata-routing.md).

## Upstream contract to match

Binaryen `version_129` and current `main` use one small owner class for two public passes:

- `emit-target-features` sets `module->hasFeaturesSection = true`;
- `strip-target-features` sets `module->hasFeaturesSection = false`;
- function bodies and executable module sections are not walked;
- `requiresNonNullableLocalFixups()` is false;
- `modifiesBinaryenIR()` is true through the base `Pass` default, not a local override in the checked owner file.

That means the Starshine implementation should be taught as **module/output metadata work**, not a HOT instruction peephole. The 2026-05-05 current-main recheck preserved that upstream contract.

## Exact local code surfaces

Read these before coding:

- `src/passes/optimize.mbt:127-139` - boundary-only names; both `strip-target-features` and `emit-target-features` are absent.
- `src/passes/optimize.mbt:143-152` - removed names; both names are absent.
- `src/passes/optimize.mbt:153-292` - active hot/module pass and preset registry; no target-feature pass exists.
- `src/passes/optimize.mbt:474-490` - unknown/boundary/removed request errors.
- `src/lib/types.mbt:351-424` - `Module.custom_secs` stores opaque custom sections.
- `src/lib/types.mbt:8079-8081` - `CustomSec::new(...)` constructor.
- `src/binary/decode.mbt:1153-1195` - module decode stores non-`name` custom sections as `CustomSec`.
- `src/binary/decode.mbt:1882-1886` - standalone `CustomSec` decoder.
- `src/binary/encode.mbt:1134-1143` - `CustomSec` encoder writes section id 0 with stored name and bytes.
- `src/binary/encode.mbt:1651-1745` - module encoder emits `custom_secs` first and then emits the name section separately.
- `src/validate/validate.mbt:2280-2291` - raw `name` custom sections are rejected; target-feature semantics are not validated.

## Safe first slices

### Slice 0: registry honesty only

If the project only wants clearer user-facing behavior, add a registry entry without changing module contents.

Validation:

- explicit `--pass strip-target-features` reports the chosen boundary-only or removed status;
- `emit-target-features` is either documented as intentionally unsupported or given the same explicit treatment;
- no optimize/shrink preset includes either metadata pass;
- no binary output changes.

### Slice 1: opaque custom-section deletion

If the project wants useful local behavior before adding first-class target-feature metadata, implement a module pass that removes only custom sections named `target_features` from `Module.custom_secs`.

Validation positives:

- one `CustomSec("target_features", payload)` is removed;
- multiple `target_features` custom sections are all removed or the chosen duplicate policy is documented and tested;
- arbitrary non-target custom sections remain in order;
- the `name` section remains represented through `Module.name_sec` / `raw_name_sec_payload`, not through `custom_secs`;
- all executable sections are byte- or structure-equivalent.

Validation negatives:

- do not remove `producers`, toolchain annotations, `name`, or unknown custom sections;
- do not read `producers` name-version pairs as feature, optimization, or scheduling facts;
- do not rewrite relaxed SIMD, memory64, GC, EH, strings, custom descriptors, or any feature-using instruction;
- do not filter individual feature entries inside a kept section;
- do not make validation accept unsupported feature use.

### Slice 2: first-class target-feature metadata

A closer Binaryen port would decode target-feature metadata into explicit module state, emit it from that state, and make `strip-target-features` clear that state. That larger slice should include `emit-target-features` policy at the same time, because Binaryen exposes the two as sibling toggles over the same flag.

Open questions:

- Should Starshine preserve unknown or malformed target-feature payloads opaquely, normalize them, or reject them?
- Should `emit-target-features` synthesize metadata from Starshine's feature model, only re-enable previously decoded metadata, or stay unsupported until a first-class feature model exists?
- Should metadata stripping be available only as an explicit pass, or also as an output option?

## Binaryen oracle lanes

For parity checks, compare Binaryen output with and without:

```text
wasm-opt --strip-target-features
wasm-opt --emit-target-features
```

Use fixtures that separate metadata from executable semantics:

- a module with target-features metadata and a simple function;
- a module with target-features plus unrelated custom sections;
- a module with feature-using code where the feature use remains unchanged;
- an already-stripped module.

The expected behavioral signal is only target-feature section presence or absence.

## Completion checklist

A Starshine PR should not claim implementation until it has:

- explicit registry status for `strip-target-features`;
- a documented choice for `emit-target-features`;
- tests for target-feature removal/suppression;
- tests preserving unrelated custom sections and executable IR;
- docs updated in this folder plus [`../tracker.md`](../tracker.md);
- no accidental addition to optimize/shrink presets.
