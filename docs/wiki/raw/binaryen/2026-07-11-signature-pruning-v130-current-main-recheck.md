# Binaryen `signature-pruning` version_130 / current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source bridge for `docs/wiki/binaryen/passes/signature-pruning/`

## Scope

This focused reread refreshes the current-main claim in the `signature-pruning` dossier. It compares the official Binaryen `main` owner, registration, and dedicated lit surface with the public `version_130` baseline. It supersedes the **freshness claim** of [`2026-05-05-signature-pruning-current-main-recheck.md`](2026-05-05-signature-pruning-current-main-recheck.md), while retaining all earlier raw captures as historical provenance.

This is source reconciliation, not a Binaryen execution run, a full commit-history audit, or evidence that Starshine implements the pass.

## Primary sources reread

### Binaryen `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignaturePruning.cpp>
- Raw owner: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignaturePruning.cpp>
- Registration/default-pipeline owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Dedicated lit oracle: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signature-pruning.wast>

### Release baseline

- `version_130` owner: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/SignaturePruning.cpp>
- `version_130` registration/default-pipeline owner: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- `version_130` dedicated lit oracle: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/signature-pruning.wast>

### Historical provenance retained

- [`2026-04-24-signature-pruning-primary-sources.md`](2026-04-24-signature-pruning-primary-sources.md) - tagged `version_129` dossier anchor.
- [`2026-04-26-signature-pruning-port-readiness-primary-sources.md`](2026-04-26-signature-pruning-port-readiness-primary-sources.md) - first current-main port-readiness bridge.
- [`2026-05-05-signature-pruning-current-main-recheck.md`](2026-05-05-signature-pruning-current-main-recheck.md) - superseded current-main freshness claim.

## Durable observations

The reviewed `version_130` and current-main owner/lit/registration surfaces show no behavior-bearing drift for the existing living contract:

- The pass remains GC-gated, rejects open-world invocation with the `--closed-world` diagnostic, and returns without changes when any table exists.
- It still aggregates entry-liveness, direct `call` users, and `call_ref` users by **nominal function heap type**, not by one function or textual signature shape.
- It still freezes imported/public/tag/continuation/JS-called/subtype-linked signatures and `call.without.effects` targets before rewriting.
- It still applies shared constant actuals before parameter removal; it preserves distinct nominal types through `GlobalTypeRewriter::updateSignatures(...)`; and it runs at most one localization-enabled rerun.
- The dedicated lit oracle still covers direct plus `call_ref` pruning, effectful-operand localization, all-parameter removal, overwritten incoming parameters, shared-type siblings, table/public boundaries, and distinct-type preservation.
- Public registration still exposes `signature-pruning` with the summary “remove params from function signature types where possible.” The closed-world GC/type-cluster scheduler placement remains a `pass.cpp` policy rather than a pass-body optimize-level gate.

## Local-status reconciliation

Local source inspection remains unchanged:

- [`src/passes/optimize.mbt`](../../../src/passes/optimize.mbt) lists `signature-pruning` as boundary-only.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts) does **not** admit `--signature-pruning` in `SUPPORTED_PASS_FLAGS`.

Therefore, a current Starshine-vs-Binaryen `compare-pass` command for this name is not runnable. Parser rejection is a status check, not parity evidence.

## Scope and uncertainty

This capture only supports the reviewed owner, registration/default-pipeline, and dedicated-fixture claims. It does not establish byte-for-byte source identity for every helper or unchanged code path, and it does not update Starshine implementation status. Reopen the contract if a later upstream release/current-main change, a helper-specific review, or a focused transform artifact contradicts it.

## Consumability rule

Use this capture for 2026-07-11 current-main / `version_130` freshness claims. Use the living dossier for explanations and future-port guidance; retain prior raw manifests for their historical scope.
