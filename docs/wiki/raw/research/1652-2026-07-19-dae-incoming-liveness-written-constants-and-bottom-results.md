---
kind: research
status: current
last_reviewed: 2026-07-19
sources:
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../binaryen/passes/dae-optimizing/binaryen-strategy.md
  - ../../binaryen/passes/dae-optimizing/signature-updates-and-nested-reruns.md
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/dead_argument_elimination_wbtest.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./1651-2026-07-19-daeo-block-fallthrough-validation-and-local-cleanup.md
---

# DAE incoming liveness, written constants, and bottom-result control

## Scope

This slice ports three source-backed Binaryen-v131 core DAE behaviors without widening the expensive DAEO nested scheduler or changing the fixed-artifact broad-cleanup policy:

1. incoming parameter values killed before every read are removable through the shared HOT CFG/use-def/liveness stack for branch-target and call-containing bodies, with conservative exception/continuation fallback;
2. uniform constants, including immutable globals, can initialize replacement locals for removed parameters that are later written;
3. removing a dropped uninhabitable reference result preserves caller non-returning control with `call; unreachable`;
4. the core honors Binaryen's `unprofitableRemovalIters` single-caller-chain stop without suppressing result/refinement convergence or pending localization retries.

The implementation is intentionally bounded. Optimizing DAE uses HOT entry liveness only to prove written incoming values dead; read-only parameters retain the established syntactic fact until the HOT lowering/use-def contract is proven equivalent on every structured result carrier. Exception/continuation edges, recursive/shared breadth, the complete Binaryen filtered nested pipeline, the fixed-artifact gross-positive/remap ledgers, and the `942.590s` nested runtime owner remain open.

## Incoming-value liveness

The old raw scan treated any `local.get` as use of the incoming parameter value. Binaryen instead asks whether the parameter is live at function entry, so `local.set 0; local.get 0` does not keep the incoming value alive.

Starshine now lifts eligible functions through `HotFunc`, builds `HotCfg` and `HotUseDef`, and queries `HotLiveness` at the CFG entry block. This handles local branch targets and ordinary direct/indirect calls instead of relying on the earlier shape-specific backward walker. Throw/rethrow, legacy try, `try_table`, suspend/resume, and stack-switch bodies remain conservative because the current liveness builder intentionally excludes exceptional edges. The previous structured walker remains the plain-DAE fallback when HOT lifting is unavailable. Before the ordinary callsite/signature transaction runs, suffix instructions after function-terminal control are removed so dead raw local references cannot invalidate local remapping.

Focused regressions cover:

- a one-param overwritten incoming value;
- one overwritten slot in a mixed signature;
- a parameter read only after `return`;
- an overwrite before a local branch target;
- an overwrite in a call-containing body;
- the corresponding optimizing DAE branch/call forms.

The first optimizing integration applied HOT liveness to every parameter and changed 37 previously exact generated cases. Case `63` showed why: a read-only nested block-result carrier with distinct caller actuals `7` and `8` was incorrectly collapsed to a zero-param boundary. The accepted policy therefore uses HOT liveness in optimizing DAE only when the parameter is written; read-only facts stay syntactic. This preserves the new overwritten-input proofs and restores the generated aggregate exactly.

## Unprofitable single-caller convergence

Binaryen increments `unprofitableRemovalIters` when an iteration removes parameters from exactly one function, that function has one direct caller, and no call target awaits localization. Later iterations skip further parameter removal while still allowing result refinement/removal and the optimizing cleanup phase.

Starshine now counts parameter-removing core transactions per wave and records the single-caller subset from the shared call-fact snapshot. Once the Binaryen stop condition is reached, later core waves skip ordinary parameter transactions but continue other convergence. The computed-operand retry remains available only when the direct rewrite failed and the stack-carried localization retry succeeds.

The v131 oracle fixture has `$a` and `$b` in a forwarding chain where `$b` overwrites its first parameter. Binaryen removes both `$b` params but retains `$a`'s one now-unused param; Starshine now matches that boundary. A coarse experiment that stopped the entire core, and a second experiment that suppressed every computed retry, both produced `658/1024` exact matches and `366` mismatches. Both were rejected. The accepted phase-specific policy restores `695/329`.

## Written uniform constants

Binaryen's `ParamUtils::applyConstantValues` does not reject a parameter merely because the function writes it later. It initializes the parameter slot at function entry; later writes retain their semantics.

Starshine's removed-param callee rewrite now distinguishes:

- read-only constantized params, whose gets are replaced directly;
- written constantized params, which retain a replacement local and receive `constant; local.set replacement` at function entry.

The generic call-free uniform-constant lane accepts both materializable literals and immutable `global.get` values for plain `dae` and `dae-optimizing`. Multi-param initialization preserves parameter order. Focused regressions cover one written literal param, one written slot in a mixed signature, and an immutable-global source. White-box coverage locks the entry-initializer/local-map order.

## Uninhabitable dropped results

For a dropped non-nullable bottom reference result, deleting only the `drop` would allow the caller to continue after a call that was previously known not to return. Starshine now recognizes non-nullable `none`, `noextern`, `nofunc`, `noexn`, and `nocont` abstract heap results, including shared forms. Dropped direct calls are rewritten to `call; unreachable`, and the dead caller suffix is truncated before result/signature finalization.

The focused `(ref none)` regression matches the Binaryen-v131 contract and validates after result removal.

## Validation

Artifact-driving native binary:

- `_build/native/release/build/cmd/cmd.exe`
- SHA-256 `1e1ffbb12204466b1b8b694965ffef23c6a1dc8e98269815952e8d2d7a0d7239`

Green local checks:

- focused `dae_optimizing_test.mbt`: `340/340`;
- DAE white-box: `209/209`;
- pass-manager white-box: `295/295`;
- all pass-package tests: `6105/6105`;
- full Moon suite: `9579/9579`;
- `moon info`, `moon fmt`, and explicit native release build completed.

Binaryen-v131 targeted aggregate:

- accepted current run `.tmp/pass-fuzz-daeo-hot-liveness-unprofitable-v4-v131-1024-20260719`;
- requested/compared `1024/1024`;
- exact normalized `695`, cleanup-normalized `0`, remaining `329`;
- validation/generator/property/command failures `0/0/0/0`;
- Binaryen cache `1024/0`;
- output counts are unchanged from notes `1651` and the earlier note-`1652` checkpoint, so the widened source behaviors introduce no generated DAEO regression in the 15-leaf matrix.

Plain-DAE targeted aggregate:

- accepted current run `.tmp/pass-fuzz-dae-hot-liveness-unprofitable-v131-1024-correct-20260719`;
- requested/compared `1024/1024`;
- exact normalized `512`, cleanup-normalized `0`, remaining `512`;
- validation/generator/property/command failures `0/0/0/0`;
- Binaryen cache `1008/16`.

The plain-DAE residual count is a smoke result, not closeout or a semantic classification. The complete explicit-v131 regular, dedicated, wasm-smith, and random-all matrices remain required separately for plain DAE and DAEO.

## Remaining work

1. Prove or repair HOT read-only entry-liveness equivalence for structured result carriers before removing the optimizing written-param restriction; add exceptional-edge liveness before enabling EH/continuation bodies.
2. Remove the remaining call-free admission boundary for written uniform constants after current-call facts are unified.
3. Replace the wave-level localization approximation with one unified function-info scanner carrying exact call targets awaiting localization.
4. Complete mixed/multivalue return removal and broader tail/escape reconstruction.
5. Implement Binaryen's full touched-function `precompute-propagate -> default function pipeline` through a performant filtered batch runner.
6. Reduce the note-`1651` `+56460` gross-positive body ledger, `704` remap increases, and `1239.983s` pass-local runtime.
7. Run the complete current four-lane v131 matrices and renew the fixed artifact before claiming closure.
