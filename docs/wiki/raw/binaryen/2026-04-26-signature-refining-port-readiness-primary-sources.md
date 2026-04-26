# Binaryen `signature-refining` port-readiness primary-source capture

_Capture date:_ 2026-04-26  
_Status:_ immutable source manifest for the 2026-04-26 `signature-refining` Starshine port-readiness follow-up

## Scope

This capture extends the earlier `docs/wiki/raw/binaryen/2026-04-24-signature-refining-primary-sources.md` dossier with a focused current-main recheck and a Starshine-code-readiness bridge. It does not replace the 2026-04-24 source dossier; cite both when discussing the full Binaryen strategy.

Living pages updated from this capture:

- `docs/wiki/binaryen/passes/signature-refining/index.md`
- `docs/wiki/binaryen/passes/signature-refining/starshine-strategy.md`
- `docs/wiki/binaryen/passes/signature-refining/starshine-port-readiness-and-validation.md`

## Official online sources consulted

### Release surface

- Binaryen GitHub releases index: <https://github.com/WebAssembly/binaryen/releases>
  - Observed on 2026-04-26.
  - The rendered release list still showed `version_129` as `Latest`, dated 2026-04-01 14:31, with tag commit `d0e2be9`.
  - No `version_130` text was present in the observed release list.

### Current-main source and test surfaces

- `src/passes/SignatureRefining.cpp`
  - raw main: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignatureRefining.cpp>
  - Observed 2026-04-26.
- `test/lit/passes/signature-refining.wast`
  - raw main: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-refining.wast>
  - Observed 2026-04-26.

## Durable observations

- The current official release surface still makes `version_129` the latest release, so the earlier tagged `version_129` dossier remains the stable release oracle for `signature-refining`.
- Current `main` still describes the pass as signature/function-type subtype refinement and explicitly distinguishes it from DAE-style per-function type mutation: `signature-refining` rewrites signature heap types while considering all users of the type, including functions sharing it and `call_ref` users.
- Current `main` still has the same teaching-relevant gates and phase order:
  - require GC;
  - bail out when any table exists;
  - collect direct `call`s, `call_ref`s, `call.without.effects` extra calls, and returned-value LUBs;
  - combine evidence by nominal function heap type;
  - freeze public, imported, tag-used, subtype-linked, JS-called-param, and continuation-param families as appropriate;
  - compute param and result refinements;
  - update parameter bodies before the whole-module signature rewrite;
  - run `GlobalTypeRewriter::updateSignatures(...)`;
  - clone `call.without.effects` imports when refined results require a new import type;
  - run `ReFinalize`.
- Current `main` `signature-refining.wast` still contains the critical proof families needed for a future Starshine port-readiness ladder: direct-call positives, `call_ref` positives, mixed-LUB outcomes, shared-heap-type updates, body repair locals, unreachable/no-call negatives, result-refinement positives, public/import/table/subtype/tag/continuation negatives, and `call.without.effects` import repair.
- Local Starshine source inspection on 2026-04-26 found the pass name still boundary-only in `src/passes/optimize.mbt`, no `src/passes/signature_refining.mbt` owner, no `call.without.effects` spelling under `src/`, and a text-front-end gap where the WAT AST/parser exposes `return_call_ref` but not direct `call_ref` even though the library, binary, HOT, and validator layers have `CallRef`.

## Uncertainties and caveats

- The current-main raw view used here is a line-compressed rendering from GitHub raw content, not a pinned commit hash. Treat it as a freshness check, not as an immutable release oracle.
- The local WAT `call_ref` gap is source-observed in this worktree, but it may be partly hidden behind generated or alternate fixture paths. Future implementation should verify by adding a direct text fixture before relying on WAT-only parity tests.
- Because `call.without.effects` is absent locally, a faithful Starshine port cannot claim complete Binaryen parity until it either models that intrinsic surface or explicitly scopes it out of the first implementation slice.

## Consumability rule

Use this file as provenance. Use `docs/wiki/binaryen/passes/signature-refining/starshine-port-readiness-and-validation.md` for the developer-facing first-slice and validation plan.
