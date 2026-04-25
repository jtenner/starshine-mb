---
kind: research
status: partially_superseded
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
  - ../../binaryen/passes/remove-relaxed-simd/index.md
  - ../../binaryen/passes/remove-relaxed-simd/binaryen-strategy.md
  - ../../binaryen/passes/remove-relaxed-simd/wat-shapes.md
  - ../../binaryen/passes/remove-relaxed-simd/starshine-strategy.md
  - ./0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/wast/types.mbt
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/decode.mbt
related:
  - ../../binaryen/passes/late-pipeline-dispatch.md
  - ../../binaryen/passes/precompute/index.md
superseded_by:
  - ./0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md
---

> Supersession note (2026-04-25): this note remains the original dossier provenance, but `0355` supersedes the feature-gate / changed-function wording. The reviewed Binaryen owner file walks functions and refinalizes after the postwalk; it does not show the previously stated per-function relaxed-SIMD feature guard or changed-flag-gated refinalization.

# `remove-relaxed-simd` primary sources and Starshine follow-up

## Question

The pass catalog already mentioned `--remove-relaxed-simd` as a newer upstream-only Binaryen pass, but there was no dedicated dossier explaining what it transforms, why Binaryen traps instead of choosing deterministic SIMD equivalents, or what Starshine can currently do with relaxed SIMD instructions.

## Sources reviewed

- Official Binaryen `version_129` release page and `CHANGELOG.md`.
- Binaryen `version_129` and current-`main` `RemoveRelaxedSIMD.cpp`.
- Binaryen `version_129` `pass.cpp`, `passes.h`, and `child-localizer.h`.
- Binaryen `version_129` and current-`main` `test/lit/passes/remove-relaxed-simd.wast`.
- WebAssembly relaxed SIMD proposal overview and repository.
- Local Starshine registry and relaxed-SIMD surfaces in `src/passes/optimize.mbt`, `src/wast/`, `src/lib/types.mbt`, `src/validate/typecheck.mbt`, `src/binary/encode.mbt`, `src/binary/decode.mbt`, and `src/ir/hot_lift.mbt`.

## Findings

- `remove-relaxed-simd` is a real public Binaryen pass. The tagged `version_129` changelog still records it as a `version_126` addition.
- Binaryen's implementation is deliberately conservative: it replaces relaxed SIMD instructions with `unreachable` rather than selecting one deterministic representative instruction.
- The rewrite is still effect-preserving. The pass uses `ChildLocalizer` so child expressions are evaluated or localized before the replacement trap.
- The pass is function-parallel and traps matched relaxed SIMD expressions. This note originally said it refinalizes changed functions and skips functions when the module feature set lacks relaxed SIMD; `0355` corrects that overread: the reviewed owner file postwalks each function and refinalizes after the walk without a visible feature guard or changed flag.
- The official lit file proves representative positive rewrites and non-relaxed SIMD preservation. Complete opcode coverage is better sourced from the visitor enumerations in `RemoveRelaxedSIMD.cpp`.
- Starshine has no registry entry for `remove-relaxed-simd`; explicit requests therefore hit the generic unknown-pass path today.
- Starshine already has broad relaxed-SIMD plumbing: WAT keywords, WAT AST opcodes, parser classifications, WAT-to-lib lowering, lib instruction constructors, typechecking tests, binary opcode encode/decode for prefix opcodes `256` through `275`, and HOT lift/lower support through `HotOp::Simd`.

## Durable wiki updates made

- Added a raw Binaryen primary-source manifest at `docs/wiki/raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`.
- Added a new living dossier under `docs/wiki/binaryen/passes/remove-relaxed-simd/` with:
  - landing overview;
  - Binaryen strategy;
  - implementation/test map;
  - WAT-shape catalog;
  - Starshine status and port map.
- Updated the pass folder catalog, tracker, top-level wiki index, and log so the formerly only-mentioned upstream pass now has a stable home.

## Uncertainty

- The reviewed sources prove expression rewrites and function refinalization. They do not prove a feature-section cleanup obligation. A future Starshine implementation should source-confirm whether Binaryen clears relaxed-SIMD feature metadata or whether removing all relaxed opcodes is sufficient for the intended downstream consumer.
- The official proposal explains the nondeterministic/implementation-defined nature of the relaxed family, but individual deterministic replacement choices are intentionally not chosen by Binaryen's pass; this dossier therefore treats trapping as the source-backed semantics, not as a placeholder for a better lowering.

## Follow-up questions

- Should Starshine track `remove-relaxed-simd` as `Removed`, `BoundaryOnly`, or keep it unknown until a real pass exists?
- If implemented, should the first Starshine port be a HOT pass over `HotOp::Simd` or a module pass that can also adjust module feature metadata if source-confirmed necessary?
- Should precompute and effect-analysis docs link to the new dossier when discussing why relaxed SIMD is not folded?
