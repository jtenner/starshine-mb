---
kind: research
status: current
last_reviewed: 2026-06-09
sources:
  - ../../../../src/passes/ssa_nomerge.mbt
  - ../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/ir/ssa_policy.mbt
  - ../../../../src/ir/ssa_local.mbt
  - ../../../../src/ir/ssa_destroy.mbt
  - ../../../../src/ir/cfg.mbt
  - ../../ir2/local-ssa-policy.md
  - ../../binaryen/passes/ssa-nomerge/parity.md
related:
  - ../../binaryen/passes/ssa-nomerge/index.md
  - ../../binaryen/passes/ssa-nomerge/parity.md
  - ../../ir2/local-ssa-policy.md
---

# SSA No-Merge Exceptional-Edge Audit

## Question

Can the current Starshine `ssa-nomerge` implementation corrupt locals, and what SSA-related risks remain after auditing the local SSA builder, destructor, pass guard, and raw fallback path?

## Finding: true corruption on exceptional exits

The audit found a true semantic bug in the HOT `ssa-nomerge` path when a `try_table` body writes a local and then throws to a catch target outside the `try_table`.

Reduced shape:

```wat
(module
  (tag $e)
  (func (export "f") (result i32)
    (local i32)
    i32.const 1
    local.set 0
    (block $h
      (try_table (catch $e $h)
        i32.const 2
        local.set 0
        throw $e))
    local.get 0))
```

Before the fix, Starshine rewrote both `local.set` instructions to `drop`, leaving the final `local.get 0` to read the default zero. The original program returns `2` on the caught exceptional path. The module still validated, so this was a runtime semantic corruption, not a validation failure.

Root cause: Starshine local SSA v1 explicitly skips exceptional successors while recording phi inputs. That is correct for the documented overlay contract, but unsafe for `ssa_destroy_into_hot(...)` when the pass rewrites local definitions in functions containing `try_table` / `throw` flow.

## Fix

- `src/passes/ssa_nomerge.mbt` now makes the HOT `ssa-nomerge` path fail closed for exceptional-flow nodes: `Try`, `TryTable`, `Throw`, `ThrowRef`, `Rethrow`, `Delegate`, `Catch`, and `CatchAll`.
- `src/passes/ssa_nomerge_test.mbt` adds the reduced `try_table` regression and verifies the local writes are preserved.
- This aligns the pass with the existing SSA v1 exclusion instead of pretending exceptional-edge SSA exists.

## Secondary parity improvement: default locals after branchy control

The audit also found a recurring direct-compare drift family: functions with no local writes but with default body-local reads after branchy control were left as `local.get`, while Binaryen materializes explicit defaults.

This was not semantic corruption because WebAssembly body locals are default-initialized, but it caused many direct compare mismatches and hid more important signal.

Fix:

- `src/passes/pass_manager.mbt` now uses a dedicated raw no-write/default-read rewriter that recursively replaces reads of never-written body locals with type defaults across block, loop, if, and try_table bodies.
- This path does not run local SSA, allocate aliases, or reason about branches; it is a simple no-writes rewrite.
- A branchy `br_table` regression in `ssa_nomerge_test.mbt` locks the improvement.

## Final-lane parity improvement: dropped unreachable debris

The requested `100000`-case final lane initially found three raw mismatches after the exceptional-edge/default-local fixes. All three were wasm-smith unreachable-tail shapes where Starshine preserved `drop (unreachable)` or nested dropped-unreachable debris immediately before a hard `unreachable`, while Binaryen canonicalized the tail to the later `unreachable`.

Agent classification: this was semantic-safe unreachable-control debris and a size/shape opportunity, not local SSA corruption. The dropped expression is already an unconditional trap and the following hard `unreachable` traps as well.

Fix:

- The no-write direct `ssa-nomerge` raw path now also applies the existing dropped-unreachable-debris cleanup helper after optional default-local materialization.
- This remains narrow: it only runs in functions with no local writes, so it does not widen branch-sensitive alias SSA.
- `ssa_nomerge_test.mbt` adds `ssa-nomerge removes dropped unreachable debris before a following unreachable` to cover the final-lane family.

## Audit of SSA-related implementation surfaces

Reviewed active SSA-related files:

- `src/ir/ssa_policy.mbt`: overlay types, v1 exclusions, liveness-pruned dominance-frontier placement.
- `src/ir/ssa_local.mbt`: dominator-tree rename, local stacks, phi input recording, and normal-predecessor alignment.
- `src/ir/ssa_destroy.mbt`: concrete-local assignment, predecessor-copy insertion, parallel-copy scheduling, dead-def cleanup, and temp-local trimming.
- `src/passes/ssa_nomerge.mbt`: pass guards and HOT SSA destruction entry point.
- `src/passes/pass_manager.mbt`: raw `ssa-nomerge` fast paths and fail-closed handoff to HOT.
- Tests in `src/ir/*ssa*_test.mbt` and `src/passes/ssa_nomerge_test.mbt`.

The important contract remains: local SSA v1 is normal-flow-only. Any pass that wants to mutate through SSA in an exceptional-control function must first implement exceptional-edge SSA semantics, or fail closed like `ssa-nomerge` now does.

## Validation

Commands run after the fix:

- `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt`
  - `28` passed, `0` failed.
- `moon test src/ir`
  - `251` passed, `0` failed.
- `moon test src/passes`
  - `2047` passed, `0` failed.
- `moon build --target native --release src/cmd`
  - passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-audit-after-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`
  - compared `998/1000`, normalized matches `998`, mismatches `0`, validation/property/generator failures `0`, command failures `2`.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-audit-after-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - compared `9977/10000`, normalized matches `9977`, mismatches `0`, validation/property/generator failures `0`, command failures `23`.
- Initial final lane before the dropped-unreachable-debris cleanup: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-final-100000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - compared `99751/100000`, normalized matches `99748`, mismatches `3`, validation/property/generator failures `0`, command failures `249`. The three mismatches were agent-classified as semantic-safe dropped-unreachable debris before a hard `unreachable`.
- Final lane after the debris cleanup: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-final-100000-after-debris --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - compared `99751/100000`, normalized matches `99751`, mismatches `0`, validation/property/generator failures `0`, command failures `249` (`219` `binaryen-rec-group-zero`, `12` `binaryen-bad-section-size`, `11` `binaryen-command-failed`, `6` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`).
- `moon test`
  - `5245` passed, `0` failed.
- `moon fmt`
  - completed.

`moon info` still reproduces the known Moon tool DB panic and did not complete.

Two extra probes were not usable as signoff evidence:

- `--require-feature exception_try_table_matrix` failed during GenValid batch generation with no return code.
- `--runtime-execution node` timed out before case execution began.

## Remaining risks and recommendations

1. **Exceptional-edge SSA is still not implemented.** This is acceptable only because `ssa-nomerge` now skips exceptional-flow HOT mutation. Do not relax that guard without adding phi placement/input semantics for exceptional successors.
2. **The direct compare lane is final-lane green with `local-cleanup-debris` normalization.** The normalizer is still needed for semantically equivalent local-cleanup shape differences, but no true semantic mismatches or raw unreachable-debris mismatches remain in the `100000` requested lane.
3. **Artifact exact parity remains open.** `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-ssa-nomerge-debug-wasi-after-debris --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge` completed and validated, with Starshine pass time `9.931 ms` versus Binaryen pass time `385.285 ms`, but normalized WAT and canonical function compare were not equal. The first diff (`defined=0 abs=27`) is local-cleanup/temporary-local shape drift, not a classified runtime corruption; the Starshine artifact's `--help` smoke exited `0`.
4. **The O4z public preset still intentionally no-ops `ssa-nomerge`.** Direct explicit pass execution is safer, but current O4z artifact replay with the no-op in place aborted during a later `remove-unused-names` slot (`exit=134` in `.tmp/o4z-ssa-audit/o4z-trace.stderr`). That separate preset/artifact blocker prevents using this slice as evidence to re-enable the O4z SSA slot.
5. **Raw fast paths should stay intentionally narrow.** The new default-local and dropped-unreachable-debris rewrites are safe because they only run when there are no writes; do not generalize them into branch-sensitive alias SSA without tests and Binaryen evidence.
