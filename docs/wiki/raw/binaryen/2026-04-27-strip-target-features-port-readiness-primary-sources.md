# Binaryen `strip-target-features` port-readiness primary-source capture

_Capture date:_ 2026-04-27  
_Status:_ immutable source manifest for `docs/wiki/binaryen/passes/strip-target-features/`

## Scope

This capture refreshes the 2026-04-26 source correction and adds the missing Starshine port-readiness bridge for Binaryen's `strip-target-features` pass. It focuses on the exact upstream module-metadata contract and the local Starshine code surfaces a future port would touch.

## Official primary sources consulted

### Binaryen `src/passes/StripTargetFeatures.cpp`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp>
- raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/StripTargetFeatures.cpp>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp>
- raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/StripTargetFeatures.cpp>
- Reviewed symbols:
  - `struct StripTargetFeatures : public Pass`
  - `requiresNonNullableLocalFixups() override { return false; }`
  - `bool isStripped`
  - `StripTargetFeatures(bool isStripped)`
  - `void run(Module* module) override { module->hasFeaturesSection = !isStripped; }`
  - `createStripTargetFeaturesPass()` creates the stripping variant with `true`
  - `createEmitTargetFeaturesPass()` creates the emitting variant with `false`

### Binaryen `src/passes/pass.cpp`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Reviewed symbols:
  - `registerPass("emit-target-features", ...)`
  - `registerPass("strip-target-features", ...)`

### Binaryen `src/passes/passes.h`

- `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Reviewed declarations:
  - `createEmitTargetFeaturesPass()`
  - `createStripTargetFeaturesPass()`

### Binaryen `src/pass.h`

- current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- Reviewed symbol:
  - base `Pass::modifiesBinaryenIR()` defaults to true.

This matters because the checked `StripTargetFeatures.cpp` does not need its own explicit `modifiesBinaryenIR()` override to report that the module IR/state changes. Older wiki wording that said the owner file itself returned true was too literal; the durable contract is that the pass reports true through the base default while mutating `Module::hasFeaturesSection`.

### WebAssembly custom-section context

- Core spec custom sections: <https://webassembly.github.io/spec/core/binary/modules.html#custom-section>

This source confirms the section-level context: custom sections are binary sections, not executable instructions. The Binaryen pass changes whether target-feature metadata is emitted; it does not lower feature-using code.

## Local Starshine sources consulted

- `src/passes/optimize.mbt:127-139` - boundary-only registry names; `strip-target-features` and `emit-target-features` are absent.
- `src/passes/optimize.mbt:143-152` - removed registry names; both names are absent.
- `src/passes/optimize.mbt:153-292` - active pass and preset registry construction; no target-feature metadata pass exists.
- `src/passes/optimize.mbt:474-490` - unknown pass rejection, then boundary-only/removed rejection.
- `src/lib/types.mbt:351-424` - `Module.custom_secs` and constructor storage for opaque custom sections.
- `src/lib/types.mbt:8079-8081` - `CustomSec::new(...)` constructor.
- `src/binary/decode.mbt:1153-1195` - custom-section decode loop; non-`name` sections are stored as opaque `CustomSec` values.
- `src/binary/decode.mbt:1882-1886` - standalone `CustomSec` decoder.
- `src/binary/encode.mbt:1134-1143` - `CustomSec` encoder writes section id 0 with stored name and bytes.
- `src/binary/encode.mbt:1651-1745` - module encoder emits `custom_secs` before ordinary sections and emits the name section separately later.
- `src/validate/validate.mbt:2280-2291` - raw `name` custom sections are rejected; there is no target-features semantic validation.

## Durable observations

- Upstream `strip-target-features` and `emit-target-features` share one tiny owner class parameterized by `isStripped`.
- `strip-target-features` sets `Module::hasFeaturesSection` false; `emit-target-features` sets it true.
- The pass does not walk functions or rewrite instructions, types, imports, exports, memories, tables, globals, elements, data, or names.
- The pass does not override `modifiesBinaryenIR()` in the checked source; it inherits the base `Pass` default of true. The 2026-04-26 conclusion that the pass is not `modifiesBinaryenIR() == false` remains correct, but the owner-file wording should say inherited default rather than explicit override.
- `requiresNonNullableLocalFixups()` returns false because metadata toggling cannot create invalid nonnullable locals.
- Starshine currently has neither `strip-target-features` nor `emit-target-features` in its active, boundary-only, or removed pass registry.
- Starshine's closest current representation is opaque custom-section storage, not a first-class `hasFeaturesSection` bit. A local pass that deletes `CustomSec("target_features", ...)` would be useful but not the same internal strategy as Binaryen's module flag.

## Uncertainty and caveats

- This run did not chase the historical commit that introduced the shared `emit-target-features` / `strip-target-features` owner shape. The current and `version_129` source surfaces agree, which is sufficient for this wiki pass dossier.
- The exact byte payload format of Binaryen's target-features custom section was not audited here because the pass does not parse individual feature entries.
- A future Starshine implementation must first choose whether to add first-class target-feature metadata, mutate opaque custom sections, or only expose an explicit boundary/unknown status. Those choices have different parity claims.

## Supersedes and refines

This capture refines:

- `docs/wiki/raw/binaryen/2026-04-26-strip-target-features-source-correction.md`
- `docs/wiki/raw/research/0390-2026-04-26-strip-target-features-source-correction.md`

It preserves the 2026-04-26 correction that the pass mutates module state, while correcting the too-specific statement that `StripTargetFeatures.cpp` explicitly overrides `modifiesBinaryenIR()`.
