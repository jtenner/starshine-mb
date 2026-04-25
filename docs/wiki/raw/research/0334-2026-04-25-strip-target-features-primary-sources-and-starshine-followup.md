# `strip-target-features` primary sources and Starshine follow-up

_Date:_ 2026-04-25  
_Status:_ absorbed into living wiki pages  
_Supersedes:_ the older catalog-only mentions that treated `strip-target-features` as a late upstream-only name without a dedicated dossier or local status map

## Question

The pass wiki already mentioned Binaryen's `strip-target-features` in the late-pass chronology, but it had no stable pass dossier.
The goal of this run was to answer:

- what does Binaryen's `strip-target-features` actually do?
- does it transform Binaryen IR or only emitted binary metadata?
- what concrete shape changes should readers expect?
- what exact Starshine code locations explain the current local status?

## Sources checked

Primary online sources:

- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `StripTargetFeatures.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Binaryen current-`main` `StripTargetFeatures.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp>
- WebAssembly Core custom-section reference: <https://webassembly.github.io/spec/core/binary/modules.html#custom-section>

Local repository surfaces:

- `src/passes/optimize.mbt`
- `src/lib/types.mbt`
- `src/binary/decode.mbt`
- `src/binary/encode.mbt`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/`
- `docs/wiki/binaryen/passes/remove-relaxed-simd/`

## Findings

- Binaryen `version_129` exposes `strip-target-features` as a public pass through `pass.cpp` and `passes.h`.
- The owner file is intentionally tiny. The important code-level fact is `modifiesBinaryenIR() == false`.
- The pass does not mutate the in-memory module. It sets `runner->options.emitTargetFeatures = false`, changing whether Binaryen emits the target-features custom section when output is written later.
- This means the pass's teaching surface is an output metadata shape, not a function / expression / type transformation.
- The WebAssembly core custom-section rule supports treating target-features as non-executing metadata, but that does not mean the metadata is useless: tools can rely on it to discover required or used features.
- Starshine currently has no `strip-target-features` registry entry. Explicit pass requests fail as unknown rather than boundary-only or removed.
- Starshine does preserve arbitrary custom sections through `Module.custom_secs`, `CustomSec`, binary decode, and binary encode, but it has no first-class `emitTargetFeatures` option and no decoded semantic model for target-feature payloads.

## Wiki changes made from these findings

Created a new living dossier:

- `docs/wiki/binaryen/passes/strip-target-features/index.md`
- `docs/wiki/binaryen/passes/strip-target-features/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/strip-target-features/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/strip-target-features/wat-shapes.md`
- `docs/wiki/binaryen/passes/strip-target-features/starshine-strategy.md`

Created a raw source manifest:

- `docs/wiki/raw/binaryen/2026-04-25-strip-target-features-primary-sources.md`

Updated catalogs and chronology:

- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/log.md`

## Follow-up questions

- Find the exact upstream commit or release note that introduced `strip-target-features`; the source-level contract is clear in `version_129`, but the changelog provenance is not as clean as for neighboring pass dossiers.
- If Starshine ever adds this pass, decide whether to mimic Binaryen's output-option architecture or to implement a concrete custom-section deletion pass over decoded `Module.custom_secs`.
- If implementing concrete deletion, source-confirm the target-features payload format before attempting semantic filtering; this pass should remove the whole output feature section, not rewrite individual feature flags.
