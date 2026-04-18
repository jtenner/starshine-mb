# 0109 - Generated `-O4z` slot 44 `optimize-instructions` retired by replay verification

## Status

- Date: 2026-04-18
- Type: One-off repair note
- Retires: [O4Z]007 in `agent-todo.md`
- Prior capture: [0100 - generated `-O4z` slot 44 later `optimize-instructions` final-validate underflow](./0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md)

## Scope

- Binaryen slot: `44`
- Observed Binaryen pass: `optimize-instructions`
- Starshine pass: `--optimize-instructions`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm`
- In-tree replay lock added in this run:
  - `src/cmd/cmd_wbtest.mbt`
- Earlier likely-fixing implementation surface (already landed before this run):
  - `src/ir/hot_lower.mbt`
  - `src/ir/hot_lower_test.mbt`
  - [0103 - slot 16 `Func 652` carrier guard](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md)
  - [0104 - slot 16 `Func 1818` split parent-exit payload guard](./0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md)

## Failure recap

[0100](./0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md) captured a hard corruption on the saved slot-43 predecessor:

- direct Starshine replay aborted with `error: final module validate: stack underflow`
- the offending function was `(Func 1818)`
- the compare harness stopped before Starshine could produce a valid output module

## Current replay result

The current tree no longer reproduces that failure.

Direct replay now succeeds on the same saved predecessor:

- command:
  - `_build/native/release/build/cmd/cmd.exe --optimize-instructions --out .artifacts/tmp-direct-optimize-instructions-after-precompute.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm`
- exit status: `0`
- follow-up validation:
  - `wasm-tools validate .artifacts/tmp-direct-optimize-instructions-after-precompute.wasm`
- result: valid output module

The direct extracted replay is also green now:

- command:
  - `_build/native/release/build/cmd/cmd.exe --extract-functions=1818 --optimize-instructions --out .tmp/o4z-slot44-f1818.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm`
- exit status: `0`
- follow-up validation:
  - `wasm-tools validate .tmp/o4z-slot44-f1818.wasm`
- result: valid extracted output module

The Binaryen compare harness also reaches canonical parity on the same predecessor now:

- command:
  - `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/o4z-slot44-verify --optimize-instructions`
- current result summary:
  - `normalizedWatEqual=true`
  - `canonicalFuncPrettyEqual=true`
  - `canonicalWasmEqual=false`

## Findings

### 1. The saved slot-44 blocker is stale on the current tree

This is a direct observation from rerunning the exact saved predecessor and the same pass flag that [0100](./0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md) recorded. The old `final module validate: stack underflow` failure no longer appears.

### 2. The later slot-44 `Func 1818` family was likely retired by the already-landed HOT-lower guards from the slot-16 follow-up

Inference, not a freshly reduced proof:

- this run did not need a new `optimize-instructions` rewrite change to make slot `44` succeed
- the same function family (`Func 1818`) was already implicated in the earlier slot-16 follow-up from [0104](./0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md)
- the earlier slot-16 fixes in [0103](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md) and [0104](./0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md) both lived in shared HOT-lower carrier / parent-exit packing logic rather than in a slot-specific `optimize-instructions` mutator

The safest durable conclusion is therefore: slot `44` no longer needs a new pass-local fix, and the current evidence is most consistent with the earlier shared HOT-lower guards having retired the later replay as well.

### 3. The right in-tree lock is an artifact-backed native replay regression, not another speculative rewrite

Because the failure is already gone, the value of this run is to lock the exact saved predecessor and the extracted `Func 1818` witness into `src/cmd/cmd_wbtest.mbt` instead of reopening pass logic without a live red repro.

## Validation

Focused validation for this retirement:

1. `moon test --target native --package jtenner/starshine/cmd --file cmd_wbtest.mbt --index 117-119`
2. `_build/native/release/build/cmd/cmd.exe --optimize-instructions --out .artifacts/tmp-direct-optimize-instructions-after-precompute.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm`
3. `wasm-tools validate .artifacts/tmp-direct-optimize-instructions-after-precompute.wasm`
4. `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/o4z-slot44-verify --optimize-instructions`

## Durable conclusion

`[O4Z]007` is retired. The saved later slot-44 `optimize-instructions` replay on the generated `cmd.wasm` artifact now completes successfully, emits valid wasm, and matches Binaryen at the normalized-WAT and canonical-function level. No new pass-local fix was needed in this run; the current evidence instead points back to the already-landed shared HOT-lower guard work from [0103](./0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md) and [0104](./0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md). The new in-tree responsibility is simply to keep that exact saved predecessor replay locked by artifact-backed native wbtests.
