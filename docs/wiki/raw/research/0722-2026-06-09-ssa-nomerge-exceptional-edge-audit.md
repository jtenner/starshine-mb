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

## Follow-up: artifact param-slot shape reduction

A continuation audit reduced the first direct debug-artifact diff family (`defined=0 abs=27`) without changing the exceptional-edge policy.

Finding: the raw structured path used fresh temporary locals plus branch-result scratch copies for nested param writes even when the next observable param use read that value before any overwrite, and it also copied param aliases at an `if` join when no later read-before-write needed the value. Binaryen keeps those nested param writes on the canonical param slot and does not materialize unneeded param merge copies in the reduced `Func 27` family.

Fix:

- `src/passes/pass_manager.mbt` now propagates a read-before-write future bitset through raw structured `ssa-nomerge` recursion.
- Param `local.set` instructions may reuse the canonical param slot when the current or inherited continuation reads that param before the next write.
- Fallthrough `if` alias merge copies now skip params that have no later read-before-write, while body-local branch merge behavior stays conservative.
- `src/passes/ssa_nomerge_test.mbt` adds `ssa-nomerge keeps nested structured param write canonical before next read`.

Evidence:

- `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` passed `29/29`.
- `moon test src/passes` passed `2048/2048`.
- `moon build --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-param-canonical-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `998/1000`, normalized `998`, mismatches `0`, command failures `2`.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-param-canonical-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `9977/10000`, normalized `9977`, mismatches `0`, command failures `23`.
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-ssa-nomerge-debug-wasi-param-merge-needed --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge` still is not exact-normalized/canonical-function equal (`defined=0 abs=27` remains first diff), but the first diff is now a local-numbering / temporary-local representation drift where Starshine uses fewer locals than Binaryen.
- Fresh direct trace census `.tmp/ssa-nomerge-param-canonical-trace` exited `0` and found one invalid-lower skip: `skip-invalid-lower suspicious-escape-carrier` at `Func 4302`. Other counted `skip-raw` lines are raw fast/no-op paths (`2117` `large-structured-local-writes`, `1722` `structured-local-writes`, `1077` `no-local-writes`, `1020` `straight-line-local-writes`).
- Current `-O4z` debug-artifact replay with `--debug-serial-passes --tracing pass -O4z` still aborts with exit `134` in a later `remove-unused-names` neighborhood after `Func 2560` changes and before lower/validation completes. This remains an O4z/RUN-neighborhood blocker, not evidence that the direct SSA slot is corrupt.

## Follow-up: large structured coverage and Func 4302 carrier narrowing

A second continuation targeted the two remaining high-signal direct artifact gaps from the param-slot census: broad `large-structured-local-writes` no-ops and the one direct `skip-invalid-lower suspicious-escape-carrier` at `Func 4302`.

Findings:

- The `Func 4302` suspicious-carrier skip was a false-positive guard classification for a valid result-carrier block whose inner prefix contains `return` only inside nested structured control. The old suspicious-carrier predicate treated any nested hard exit under the prefix as suspicious. The narrowed predicate now only treats immediate hard exits in the carrier prefix as suspicious, while still walking nested bodies for genuinely nested carrier hazards.
- Raw structured `ssa-nomerge` limits were too conservative for the current artifact. Raising the structured raw coverage budget from `128` instructions / `64` branchy locals to `4096` instructions / `1024` branchy locals moves moderate branchy and large no-branch structured functions through the raw rewrite path. Remaining large skips are now only very large functions.
- The trace payload for the remaining large-structured skips now records function index, instruction count, and local count so follow-up agents can sample the exact huge functions rather than working from a reason-only census.

Tests added/updated:

- `ssa-nomerge rewrites moderately large structured branch functions without hot fallback`
- `ssa-nomerge rewrites very large structured local-write functions without branches`
- `ssa-nomerge rewrites func4302-style returning carriers without suspicious skip`

Evidence:

- Focused red verification was observed for the large-structured branch fixture, the no-branch large structured fixture, and the reduced `Func 4302` carrier fixture before implementation.
- `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` passed `30/30`.
- `moon test src/passes` passed `2049/2049`.
- `moon test` passed `5247/5247`.
- `moon fmt` completed.
- `moon info` still reproduces the known Moon DB panic.
- `moon build --target native --release src/cmd` passed with the pre-existing pass-manager warnings.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-high-threshold-narrow-ssa-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `9977/10000`, normalized `9977`, mismatches `0`, validation/property/generator failures `0`, command failures `23`.
- Fresh direct trace census `.tmp/ssa-nomerge-high-threshold-narrow-ssa-trace` exited `0`: `2524` `structured-local-writes`, `1077` `no-local-writes`, `1020` `straight-line-local-writes`, `17` `large-structured-local-writes`, and `0` `skip-invalid-lower` lines. The remaining large skips are huge: sampled payloads include `Func 95` (`5183` instrs / `822` locals), `Func 265` (`9664` / `1175`), `Func 3536` (`16195` / `2871`), `Func 3781` (`39283` / `6634`), `Func 3885` (`26350` / `3879`), and `Func 5417` (`19507` / `3524`). Starshine direct pass-local time in that trace was `26.271 ms`.
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-ssa-nomerge-debug-wasi-high-threshold --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge` completed and validated. It still is not normalized/canonical-function equal (`defined=0 abs=27` remains first diff). Starshine pass-local time was `27.256 ms`; Binaryen pass-local time was `391.377 ms`. Whole-command wall time and final size remain worse for Starshine in this direct artifact lane (`3411862` bytes versus Binaryen `3155990`), so this does not close artifact output parity.
- `wasm-tools validate` succeeded on `.tmp/ssa-nomerge-high-threshold-narrow-ssa-trace/starshine.wasm` and `.tmp/self-ssa-nomerge-debug-wasi-high-threshold/starshine.wasm`; the Starshine artifact `--help` smoke exited `0`.

Classification:

- The old one-off `Func 4302` direct suspicious-carrier skip is fixed/narrowed and no longer appears in the current direct artifact trace.
- The broad `large-structured-local-writes` family was materially reduced (`2117` -> `17`) without direct fuzz mismatches. The remaining `17` are intentionally still active backlog, not accepted no-ops: they are very large raw structured functions that need sampled size/performance work rather than another blind threshold lift.
- The first larger-coverage replay exposed a real output-quality issue in the newly covered raw structured path: unneeded branch/label alias copies materialized default locals and temporary merge locals even when no later read-before-write could observe them.

## Follow-up: needed-only structured copies and canonical body-local reuse

A third continuation improved the output quality of the raw structured path without widening thresholds again.

Findings:

- The first exact artifact diff remains `defined=0 abs=27`; it is still a local-numbering / temporary-local representation difference where Starshine uses fewer locals in that first function than Binaryen, not known corruption.
- The main artifact size regression after wider structured coverage came from raw structured branch and label exits copying aliases for locals that the continuation would not read before overwrite. Those copies also forced result scratch locals for typed regions. Label targets now carry the continuation read-before-write bitset, and branch/label merge copies run only for needed aliases.
- Body-local `local.set` can safely reuse the canonical local slot when the current or inherited continuation reads that local before the next write. This matches the earlier param-slot policy and avoids fresh temporaries in structured bodies while preserving branch-target copies where a branch exits before a later fallthrough write.

Tests added/updated:

- `ssa-nomerge avoids canonical copies for block-exit locals not read later`
- `ssa-nomerge avoids default merge copies for branch locals not read later`
- `ssa-nomerge keeps body-local writes canonical before next read`
- Existing structured branch, block-exit, `br_if`, early-return, and typed-if tests were updated to assert the smaller canonical-slot output.

Evidence:

- Focused red verification was observed for the unneeded branch-local default-copy fixture and the body-local canonical-write fixture before implementation.
- `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` passed `33/33`.
- `moon test src/passes` passed `2052/2052`.
- `moon build --target native --release src/cmd` passed with the pre-existing pass-manager warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-canonical-local-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `998/1000`, normalized `998`, mismatches `0`, command failures `2`.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-canonical-local-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `9977/10000`, normalized `9977`, mismatches `0`, validation/property/generator failures `0`, command failures `23`.
- Fresh direct trace census `.tmp/ssa-nomerge-canonical-local-trace` exited `0` with the same skip-family counts as the previous larger-coverage trace: `2524` `structured-local-writes`, `1077` `no-local-writes`, `1020` `straight-line-local-writes`, `17` `large-structured-local-writes`, and `0` `skip-invalid-lower` lines. Starshine direct pass-local time was `26.731 ms` in the artifact replay.
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-ssa-nomerge-debug-wasi-canonical-local --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge` completed and validates. It still is not normalized/canonical-function equal (`defined=0 abs=27` remains first diff), but the direct artifact is now size-winning for Starshine in this lane: `3150432` bytes versus Binaryen `3155990`. Starshine pass-local time was `26.731 ms`; Binaryen pass-local time was `392.500 ms`.
- `wasm-tools validate` succeeded on `.tmp/ssa-nomerge-canonical-local-trace/starshine.wasm` and `.tmp/self-ssa-nomerge-debug-wasi-canonical-local/starshine.wasm`; `bun validate self-opt-smoke --wasm .tmp/self-ssa-nomerge-debug-wasi-canonical-local/starshine.wasm --limit 1` validated the artifact and ran the help/spec smoke (`1` selected spec file skipped by the smoke harness, `0` failures).

Classification:

- The direct artifact size regression from the high-threshold structured slice is fixed and reversed for this artifact lane; exact normalized/canonical function parity remains open because of representation drift.
- The remaining `17` `large-structured-local-writes` functions are still active backlog. They should be sampled with extracted-function replays and measured output/performance evidence before any further threshold change.
- O4z `ssa-nomerge` preset scheduling remains blocked by the separate O4z/RUN neighborhood failure; this direct-pass output win is not by itself evidence to re-enable the public O4z slot.

## Remaining risks and recommendations

1. **Exceptional-edge SSA is still not implemented.** This is acceptable only because `ssa-nomerge` now skips exceptional-flow HOT mutation. Do not relax that guard without adding phi placement/input semantics for exceptional successors.
2. **The direct compare lane is final-lane green with `local-cleanup-debris` normalization.** The normalizer is still needed for semantically equivalent local-cleanup shape differences, but no true semantic mismatches or raw unreachable-debris mismatches remain in the `100000` requested lane.
3. **Artifact exact parity remains open, but direct artifact size is now favorable.** The latest direct artifact replay `.tmp/self-ssa-nomerge-debug-wasi-canonical-local` completed and validated, with Starshine pass time `26.731 ms` versus Binaryen pass time `392.500 ms`, but normalized WAT and canonical function compare were not equal (`defined=0 abs=27` remains first diff). That first diff is still local-numbering / temporary-local representation drift, and this lane is now size-winning for Starshine (`3150432` bytes versus Binaryen `3155990`).
4. **The O4z public preset still intentionally no-ops `ssa-nomerge`.** Direct explicit pass execution is safer, but current O4z artifact replay with the no-op in place aborts during a later `remove-unused-names` neighborhood (`exit=134`, current trace `.tmp/o4z-ssa-audit-current/stderr.txt`, tail at `Func 2560`). That separate preset/artifact blocker prevents using this slice as evidence to re-enable the O4z SSA slot.
5. **Raw fast paths should stay measured, not blind.** The new default-local and dropped-unreachable-debris rewrites are safe because they only run when there are no writes. The larger structured raw budget plus needed-only/canonical-local cleanup is direct-compare green and size-winning on the debug-WASI direct artifact, but the remaining `17` huge functions still need sampled output/performance work before further widening.
