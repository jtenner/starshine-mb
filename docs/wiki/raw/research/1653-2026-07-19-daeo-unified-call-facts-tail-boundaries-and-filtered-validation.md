---
kind: research
status: current
last_reviewed: 2026-07-19
sources:
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../binaryen/passes/dae-optimizing/binaryen-strategy.md
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../src/ir/cfg.mbt
  - ../../../../src/ir/liveness.mbt
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/dead_argument_elimination_wbtest.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ./1652-2026-07-19-dae-incoming-liveness-written-constants-and-bottom-results.md
  - ./1651-2026-07-19-daeo-block-fallthrough-validation-and-local-cleanup.md
---

# DAEO unified call facts, tail boundaries, and filtered validation

## Scope

This slice introduces the first live `DAEFunctionInfo`-equivalent analysis, repairs direct tail-callee accounting, adds exact stable callsite identities, extends incoming-value liveness through eligible `try_table` exceptional control, and replaces touched-pass per-definition validation with candidate-context batch validation and per-function rollback.

It retains the existing specialized rewrite lanes. A direct HOT stack over the first nested prefix was rejected because lowering between `optimize-instructions` and `heap2local` remains semantically productive. A smaller control-pass stack was byte-neutral on the dedicated aggregate but did not improve measured wall time, so the default nested order continues to lower at those barriers.

## Unified function information

`DaeFunctionInfo` now records the Binaryen-shaped fields:

- stale state;
- cached unused-parameter bits;
- exact direct callsites;
- exact dropped callsites;
- whether the function contains tail calls;
- exact direct tail callees;
- unseen-call / escape status.

Each `DaeStableCallsite` records:

- caller definition;
- a stable structured path;
- absolute callee;
- active/dead-suffix status;
- dropped-result status;
- direct-tail status.

Aggregate direct-call, dropped-call, reverse-caller, tail-callee, and escape facts are reconstructed from these records. The core records its current unused-parameter decision back into the same function information instead of keeping that fact entirely shape-local.

## Tail-call boundary repair

The previous current-call scanner allocated `tail_calls` but never set it for `return_call`. That allowed dropped-result removal through a direct tail-callee boundary. The repair distinguishes two contracts:

- a direct tail callee remains owned for parameter rewriting, because direct `return_call` operands and the callee signature can be updated together;
- the same callee is not owned for dropped-result removal, because tail-call result compatibility is a separate boundary constraint.

Focused coverage protects nested direct tail-call discovery and confirms that ordinary dead parameters are still removed through direct `return_call` sites.

This was the dominant dedicated-profile parity repair. Relative to the accepted note-`1652` aggregate, it fixed `128` prior mismatches with no new mismatch, validation, property, generator, or command-failure case.

## Exceptional incoming-value liveness

`liveness_build` now accepts `include_exceptional_edges=true` while preserving the old default. `cfg_build` separately accepts `conservative_exception_entries=false`. The latter omits the synthetic try-entry-to-handler edge while retaining explicit `throw`, `throw_ref`, and `rethrow` exceptional edges.

DAE uses that precise mode only for `try_table` bodies with no call instruction. Calls remain excluded because a call may throw from any pre-overwrite point and the current CFG does not yet split every call site into an exceptional source block.

The Binaryen-v131 oracle fixture:

- overwrites an incoming `i32` parameter;
- throws to a `try_table` catch target;
- reads the local after the target;
- receives one direct actual.

Binaryen removes the incoming parameter. Plain DAE and `dae-optimizing` now do the same. The inverse fixture, where `throw` precedes the overwrite, retains the parameter and validates.

Legacy `try` and continuation instructions remain conservative because legacy catch lifting and continuation exceptional control are not yet complete.

## Filtered validation architecture

`run_hot_pipeline_apply_hot_pass_to_touched` no longer validates every changed definition by constructing and checking a candidate module immediately. It now:

1. runs cheap descriptor-specific structural guards;
2. stages all touched function results;
3. validates all changed touched functions against one candidate module;
4. restores only invalid definitions;
5. retains valid siblings.

A white-box regression uses two changed functions, one invalid and one valid, and proves that only the invalid definition is rolled back.

A reusable `run_hot_pipeline_apply_hot_pass_stack_to_touched` also exists and is behavior-tested. The default DAEO pipeline does not yet use it across representation-sensitive barriers: the attempted `precompute-propagate -> dead-code-elimination -> optimize-instructions` stack prevented the later `heap2local` fixture from firing, and was rejected. The byte-neutral control stack was also removed from the default after no measured aggregate wall-time improvement.

## Dedicated Binaryen-v131 aggregate

Current accepted aggregate family result:

- requested profile: `dae-optimizing`;
- seed: `0x5eed`;
- requested/compared: `1024/1024`;
- exact normalized matches: `823`;
- remaining differences: `201`;
- validation/property/generator/command failures: zero;
- both DAE cleanup normalizers enabled.

The `201` remaining differences are the exact three already source-inspected Starshine-win families:

| family | count | raw delta | canonical delta |
|---|---:|---:|---:|
| computed effects | 83 | `-1,826` | `-830` |
| table effects | 58 | `-464` | `-464` |
| touched caller cleanup | 60 | `-830` | `-830` |
| total | 201 | `-3,120` | `-2,124` |

Every remaining case is smaller for Starshine. The computed/table families preserve each effectful or trapping removed actual in source order while deleting the unused boundary parameter; the touched-caller family removes only proved dead local-copy traffic. These are measured semantic/size wins, not merely validation-based classifications.

The tail-boundary repair changed the prior `695/329` result to `823/201`: `128` exact fixes, zero regressions.

## Fixed artifact

Input remains:

- `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- `3,204,405` bytes;
- `13,162` defined functions and `21` imports.

Current endpoint:

- output directory: `.tmp/daeo-unified-tail-eh-batch-20260719`;
- native SHA-256: `e91a2a2aa858b63f02329810b26fd893fe0f02f6c25149ddb67297c38f4c9cd0`;
- raw size: `3,121,651`;
- raw SHA-256: `7240854a65cefba0105bbdc36b57c7568a85f4e7a024eaab8977733580f3cf61`;
- Binaryen-v131 canonical size: `3,181,064`;
- canonical SHA-256: `114baf97c521af83910eea77546872f4204e1291dac5730e5d1829ee8c62c4f1`;
- first invocation wall time: `568.782s`;
- second invocation: `40.624s`, byte-identical;
- Binaryen-v131 validation/canonicalization: successful with `--all-features`.

Against Binaryen v131:

- raw module delta: `-54,854`;
- canonical module delta: `-80,332`;
- canonical body payload net: `-79,578`.

Canonical body ledger:

- `2,924` Starshine-larger bodies totaling `+56,531`;
- `2,568` Starshine-smaller bodies totaling `-136,109`;
- `7,670` equal bodies.

Relative to note `1651`, the tail-callee correction and batch-validation endpoint is `+7,045` raw and `+8,168` canonical. The delta is concentrated: only `33` bodies worsen, totaling `+8,847`, while `26` improve by `-707`. The largest tail-boundary correction is Func `1893`, `8 -> 4219` bytes; Binaryen is `4024`, so the old tiny body was not a valid output-parity win and the remaining `+195` is now the honest parity gap. Func `6727` grows `195 -> 2502` but remains `127` bytes smaller than Binaryen.

Gross-positive parity is nearly unchanged despite the larger net module:

- positive-body count improves `2930 -> 2924`;
- positive-byte total changes only `+56,460 -> +56,531` (`+71`);
- Func `7556` improves `+656 -> +421`;
- Func `1247` changes `+465 -> +489`.

Runtime improves independently and materially:

- note `1651` wall time: `1241s`;
- current wall time: `568.782s`;
- reduction: about `54.2%`;
- speedup: about `2.18x`.

The second invocation regresses from about `11s` to `40.624s`; convergence runtime therefore remains open even though first-invocation nested cleanup is substantially improved.

## Plain DAE diagnostic

The attempted plain dedicated-profile refresh at `.tmp/pass-fuzz-dae-unified-tail-eh-v131-1024-20260719` is not accepted evidence:

- only `896/1024` cases compared;
- `128` Binaryen command failures (`64` bad-section-size and `64` command-failed);
- it must not replace the accepted note-`1652` plain result.

The successful cases also exposed a separate plain-DAE scheduling question around direct effectful-operand localization. That must be renewed in an isolated clean-cache run and attributed separately; it does not alter the accepted DAEO result.

## Remaining work

1. Consume stable callsite paths directly in parameter/result rewrites instead of rescanning complete caller bodies.
2. Extend precise exceptional CFG construction to call sites, legacy `try`, and continuation instructions.
3. Prove read-only HOT entry-liveness equivalence before lifting the optimizing written-only restriction.
4. Retire representation-sensitive lowering barriers only after focused semantic and byte evidence.
5. Reduce the current `2924 / +56,531` gross-positive ledger, led by Funcs `41`, `9639`, `1247`, `6377`, `1111`, and `7556`.
6. Renew the full regular, dedicated, wasm-smith, and random-all Binaryen-v131 matrices.
7. Re-run plain DAE with an isolated Binaryen cache and renew `dae2` independently.
