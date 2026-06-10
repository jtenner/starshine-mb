---
kind: comparison
status: working
last_reviewed: 2026-06-09
sources:
  - ../../../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md
  - ../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md
  - ../../../raw/research/0555-2026-05-07-aud001-backlog-split-after-current-head-rerun.md
  - ../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md
  - ../../../raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md
  - ../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
  - ../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./merge-shapes-and-canonical-slots.md
  - ./wat-shapes.md
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lift_test.mbt
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `ssa-nomerge` Binaryen Parity

This page is the current local signoff tracker.
Use the strategy and shape pages in this folder for the upstream Binaryen algorithm itself; use `[./implementation-structure-and-tests.md](./implementation-structure-and-tests.md)` for owner-file and proof-surface navigation. This page is about the repo's current evidence and remaining gaps.

## Durable Conclusions

- The June 2026 exceptional-edge corruption family is fixed in-tree by making HOT `ssa-nomerge` fail closed on `try_table` / throw-family flow, matching the documented SSA v1 normal-flow-only contract.
- The June 2026 default-local branchy-control drift family is fixed in the raw no-write path: reads of never-written body locals are materialized as explicit type defaults across block/loop/if/try_table bodies without invoking HOT SSA.
- The June 2026 final-lane dropped-unreachable-debris drift family is fixed in the same no-write raw path: `drop (unreachable)` / nested dropped-unreachable debris before a hard `unreachable` is collapsed using the existing shared cleanup helper.
- The April `2026-04-10` dead-param-write parity family is now fixed in-tree for `ssa-nomerge`.
- Current source-mode `ssa-nomerge` replay on the checked-in debug CLI artifact now completes, validates, and matches Binaryen on normalized WAT and canonical per-function output.
- Random compare fuzz is still useful, but it is not sufficient as the only signoff lane for `ssa-nomerge`.
- The 2026-05-07 current-head local-declaration shaping drift family is fixed in-tree: `ssa_destroy` now matches Binaryen temp-local preservation/reuse for unreachable dead `local.tee` value-if carriers without generic lowerer trimming.
- Fresh post-merge reruns on seed `0x51a` stayed clean in both the mixed-generator and `gen-valid` lanes.
- The reduced unreachable compare-carrier slice behind the traced `Func 523` family is now covered in-tree in both lift and pass tests.
- The old traced `Func 523` `writeback-validate:type mismatch` skip is now retired by the focused extracted-function CLI replay test.
- Exact raw-byte parity is still not claimed because Starshine's raw lowering path can still fail closed on artifact-only writeback families, and this follow-up did not rerun a fresh full-artifact traced skip census.

## Current In-Tree Status

- The implementation lives in `[../../../../../src/passes/ssa_nomerge.mbt](../../../../../src/passes/ssa_nomerge.mbt)`.
- The current raw-lowering fixes live in `[../../../../../src/passes/pass_manager.mbt](../../../../../src/passes/pass_manager.mbt)`: dead param writes spill through fresh locals, live straight-line and typed-if param flows stay on the canonical param slot, no-write default-local reads are rewritten through a dedicated recursive default materializer instead of falling back to HOT SSA, and no-write dropped-unreachable debris is cleaned before hard `unreachable` tails.
- That rule is an in-tree inference from Binaryen `src/passes/SSAify.cpp` `createNewIndexes()` plus direct `wasm-opt --ssa-nomerge` micro-replays on reduced param-write cases.
- The same pass-manager path still rejects per-function writebacks that fail module-aware validation, in addition to the existing `invalid-escape-carrier` and `suspicious-escape-carrier` families.
- The `cmd` package contains a native debug-artifact replay test in `[../../../../../src/cmd/cmd_wbtest.mbt](../../../../../src/cmd/cmd_wbtest.mbt)`, and a focused `moon test src/cmd --target native --filter 'run_cmd_with_adapter validates ssa-nomerge on debug artifact'` run is currently green.
- The reduced `Func 523` follow-up now also lives in `[../../../../../src/ir/hot_lift.mbt](../../../../../src/ir/hot_lift.mbt)`, `[../../../../../src/ir/hot_lift_test.mbt](../../../../../src/ir/hot_lift_test.mbt)`, `[../../../../../src/passes/ssa_nomerge_test.mbt](../../../../../src/passes/ssa_nomerge_test.mbt)`, and the focused extracted-function CLI replay in `[../../../../../src/cmd/cmd_wbtest.mbt](../../../../../src/cmd/cmd_wbtest.mbt)`.
- The 2026-06-09 audit added focused `try_table` exceptional-exit, branchy default-local-read, dropped-unreachable-debris, nested param-slot, large structured raw coverage, needed-only branch/label copies, canonical body-local writes, and `Func 4302` carrier-narrowing regressions in `[../../../../../src/passes/ssa_nomerge_test.mbt](../../../../../src/passes/ssa_nomerge_test.mbt)`; details and command evidence live in `[../../../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md](../../../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md)`.

## Current Signoff State

- 2026-06-09 dropped-local-increment guard hardening: `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` passed `49/49`, adding no-HOT-mutation regressions for dropped `i32.add(local.get, 1)` increments in functions that also contain local writes.
- 2026-06-09 nested CFG-sensitive control fail-closed hardening: `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` passed `46/46`, adding no-HOT-mutation regressions for nested value-control local traffic, branch/terminator-sensitive nested regions, and local preservation around nested result regions.
- 2026-06-09 typed-loop-param fail-closed hardening: `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` passed `42/42`, adding pipeline-trace no-HOT-mutation assertions for typed loop-param control, locals written before typed loops, backedge-vs-body-local separation, hot-path revision checks for the validated param-only typed-loop `br` repro, and tightening the existing typed-loop induction fixture. `moon test src/ir` passed `251/251` and `moon test src/passes` passed `2061/2061` after the follow-up.
- 2026-06-09 exceptional-edge fail-closed hardening: `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` adds a pipeline-trace no-HOT-mutation assertion, default-local catch continuation, conditional throw, `rethrow`, and `delegate` regressions on top of the original `try_table` write-before-throw case.
- 2026-06-09 focused pass test after the exceptional-edge/default-local/debris fixes: `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` passed `28/28`.
- 2026-06-09 artifact param-slot, large-structured, and needed-copy/canonical-local follow-ups: `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` now passes `33/33`, `moon test --package jtenner/starshine/passes` passes `2052/2052`, and the earlier full `moon test` passed `5247/5247` after adding nested param-write, large structured raw coverage, reduced `Func 4302` carrier, unneeded-copy, and canonical body-local regressions.
- 2026-06-09 SSA package coverage before the artifact param-slot follow-up: `moon test --package jtenner/starshine/ir` passed `251/251`, `moon test --package jtenner/starshine/passes` passed `2047/2047`, and full `moon test` passed `5245/5245`.
- 2026-06-09 direct compare: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-audit-after-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` mismatches, no validation/property/generator failures, and `23` Binaryen/tool command failures.
- Initial final lane before the dropped-unreachable-debris follow-up: `.tmp/pass-fuzz-ssa-nomerge-final-100000` compared `99751/100000`, normalized `99748`, with `3` agent-classified semantic-safe unreachable-debris mismatches and `249` Binaryen/tool command failures.
- Current final lane after the debris follow-up: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-final-100000-after-debris --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `99751/100000`, with `99751` normalized matches, `0` mismatches, no validation/property/generator failures, and `249` Binaryen/tool command failures (`219` `binaryen-rec-group-zero`, `12` `binaryen-bad-section-size`, `11` `binaryen-command-failed`, `6` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`).
- 2026-06-09 large-structured / `Func 4302` follow-up direct compare: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-ssa-nomerge-high-threshold-narrow-ssa-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `9977/10000`, with `9977` normalized matches, `0` mismatches, no validation/property/generator failures, and `23` Binaryen/tool command failures. The later needed-copy/canonical-local compare `.tmp/pass-fuzz-ssa-nomerge-canonical-local-10000` had the same compare/normalization counts; the earlier param-slot compare `.tmp/pass-fuzz-ssa-nomerge-param-canonical-10000` also had the same counts.
- `moon info` still reproduces the known Moon DB panic; `moon fmt` completed.
- `wasm-tools validate tests/node/dist/starshine-debug-wasi.wasm` succeeds.
- `moon test --package jtenner/starshine/ir --file ssa_destroy_test.mbt` is green with focused temp-local declaration and unreachable dead-tee regressions.
- `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` is green with focused dead-param, live-param, unreachable-carrier, and value-if temp-local regressions.
- `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 500 --min-compared 500 --seed 0x5eed --keep-going-after-command-failures --pass ssa-nomerge --out-dir .tmp/recheck-ssa-nomerge-genvalid-500-if-order-fix` is green at `500 / 500` compared, `500` normalized matches, and `0` mismatches.
- `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 10000 --min-compared 10000 --seed 0x5eed --keep-going-after-command-failures --pass ssa-nomerge --out-dir .tmp/pass-fuzz-ssa-nomerge-genvalid-10000-if-order-fix-rerun` is green at `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, and `0` validation/generator/command failures.
- Historical `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 10000 --min-compared 10000 --seed 0x5eed --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff-gen-valid --pass ssa-nomerge` was green at `10000 / 10000` compared and `10000` normalized matches.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff --pass ssa-nomerge` stays mismatch-free on comparable cases (`2380 / 10000` compared, `0` mismatches) and only stops on the Binaryen-only `binaryen-rec-group-zero` parser family.
- `bun scripts/pass-fuzz-compare.ts --count 2000 --seed 0x51a --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-postcommit-mixed-seed51a --pass ssa-nomerge` stayed clean on all comparable cases (`1996 / 2000`, `0` mismatches, `4` Binaryen-only parser gaps).
- `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 10000 --min-compared 10000 --seed 0x51a --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-postcommit-genvalid-seed51a --pass ssa-nomerge` is also green at `10000 / 10000` compared and `10000` normalized matches.
- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/self-ssa-nomerge-debug-wasi-canonical-local --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge` completes and validates, but still reports `Normalized WAT equal: no` and `Canonical function compare equal: no` (`defined=0 abs=27` first diff). Starshine pass-local time was `26.731 ms` versus Binaryen `392.500 ms`, and final direct output size is now size-winning for Starshine (`3150432` bytes versus Binaryen `3155990`). `bun validate self-opt-smoke --wasm .tmp/self-ssa-nomerge-debug-wasi-canonical-local/starshine.wasm --limit 1` validated the artifact and completed with `0` failures.
- `moon test --package jtenner/starshine/ir --file hot_lift_test.mbt -F '*wired to typed block results*'` is green for the reduced unreachable compare-carrier lift slice.
- `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt -F '*func 523 shape*'` is green for the reduced pass-level `Func 523` follow-up.
- `moon run src/cmd --target native -- --debug-serial-passes --tracing pass --ssa-nomerge --out /tmp/ssa-nomerge-func523-followup.wasm tests/node/dist/starshine-debug-wasi.wasm` still exits zero, and `wasm-tools validate /tmp/ssa-nomerge-func523-followup.wasm` still succeeds.

## Coverage / Investigation Lanes

### 2026-06-09 join-allocation investigation (case `000001`)

Reduced block-join replay (`.tmp/ssa-block-join-minimal/`) proves **semantic-equivalent join allocation drift** when both tools actually run `ssa-nomerge`: Starshine’s raw structured path keeps canonical slots (`$x`/`$x`/`$x`) while Binaryen fresh-allocates per set (`$2`/`$3`/`$3`). Both outputs validate and observe the same post-join value.

The dense GenValid `ssa-nomerge` profile smoke lane (`0/100` normalized) is **not** primarily a normalizer gap. For case `000001`, `starshine.raw.wasm` is unchanged from input (`330` bytes, HOT `changed=false`, raw structured rewrite `None`), while Binaryen applies `--ssa-nomerge` (`271` bytes). The harness compares canonicalized **untransformed** Starshine output against Binaryen’s transformed output because the dense template combines fail-closed / raw-skip shapes with rewrite-expected slices in one function (`ssa_nested_cfg_fail_closed_shape`, dropped-increment guard shapes, and combined structured density).

**Classification:** coverage-lane artifact for the dense profile; `semantic-equivalent-join-allocation-drift` only for isolated fixtures where both sides transform.

**Normalizer:** opt-in `--normalize ssa-local-allocation-debris` stays narrow (straight-line islands and immediate pre-`if` carriers only). Do not broaden it across control-flow joins without proof and negative tests.

**Signoff baseline:** mixed-generator `100000` lane with `--normalize local-cleanup-debris` (`99751/99751` normalized matches) under **Current Signoff State** above.

### GenValid profile split (2026-06-09)

| Profile | Purpose | Compare against Binaryen? |
|---|---|---|
| `ssa-nomerge-coverage` (`ssa-nomerge` alias) | Dense SSA body templates, all `ssa-*` coverage floors, fail-closed stress shapes | **No** — coverage/stress only |
| `ssa-nomerge-parity` | Lighter templates: rewrite shapes where Starshine is expected to run the comparable path; excludes nested-CFG fail-closed, dropped-increment guard, unreachable-carrier, and other skip-inducing slices | **Yes** — intended future GenValid parity lane |
| `ssa-nomerge-stress` | Reserved pathological/fail-closed lane (currently aliases dense coverage templates) | **No** |

Use `--gen-valid-profile ssa-nomerge-parity` with parity-appropriate `--require-feature` floors for SSA rewrite signoff experiments. Keep `--gen-valid-profile ssa-nomerge-coverage` (or legacy `ssa-nomerge`) for scanner/floor coverage only.

## Remaining Gap

- Dropped-local-increment behavior remains intentionally narrow. The guard currently covers `drop(i32.add(local.get, i32.const 1))` after the function has local writes; reversed operands, other integer widths, and other constants are not claimed unless separate tests and implementation support are added.
- Nested CFG-sensitive control remains intentionally fail-closed. SSA v1 local analysis can miss local reads/writes and terminator-sensitive flow inside nested value-control regions, so `ssa-nomerge` skips these shapes via `ssa_nomerge_has_nested_cfg_sensitive_control(...)`. This is safe because HOT mutation is avoided, not because nested value-region SSA is fully modeled.
- Nested CFG-sensitive behavior is fail-closed for HOT SSA mutation and regression-covered: dropped value blocks with local traffic, nested result-typed `if` arms inside dropped value blocks, nested `br` terminators inside dropped value blocks, and nested `br_if` local traffic inside dropped value blocks must not produce `pass[ssa-nomerge]:mutated` in pipeline traces and must leave the hot-path revision unchanged. Root-level value blocks and structured control bodies whose children are region-root slots remain outside this guard and may still rewrite through HOT SSA or the raw no-write path.
- Future work requires nested-region-aware liveness/use-def, exact local read discovery inside value control, rename semantics for nested value regions, and destruction/lowering tests that prove local copies are inserted only at valid stack-neutral sites — not Binaryen parity claims for nested CFG-sensitive SSA.
- Typed loop-param control remains explicitly unsupported and intentionally fail-closed. HOT represents typed loop params as `BlockResultResolved` param prefixes on `HotOp::Loop` children and as branch operands on backedges, with `HotLabelInfo.branch_arity` recording the payload count. SSA v1's local overlay models only `LocalGet` / `LocalSet` / `LocalTee` reaching definitions; it does not treat loop-param stack flow as local defs, and destruction only inserts predecessor copies for overlay phis on normal CFG edges — not wasm branch operands that re-enter typed loop headers.
- `ssa-nomerge` is safe because it skips typed-loop-param HOT mutation via `ssa_nomerge_has_loop_param_control(...)`, not because the local SSA overlay models loop-carried param ABI.
- Typed-loop-param behavior is fail-closed for HOT SSA mutation and regression-covered: pipeline traces must not contain `pass[ssa-nomerge]:mutated` for typed-loop-param fixtures, locals written before the loop stay preserved, backedge-carried param values stay separate from unrelated body locals, and the hot-path revision check stays unchanged for the validated param-only typed-loop `br` repro. A dedicated `br_if`-to-typed-loop WAT fixture is still deferred because the attempted operand+condition shapes fail module validation in the pass-test harness even though unconditional `br` repros lift and validate.
- Future work requires loop-param-aware liveness, use-def facts for branch operands, phi placement at typed loop headers, rename semantics that distinguish entry vs backedge param values, destruction copies before loop backedge terminators, lowering that preserves typed loop branch operands, and a validated `br_if` regression once the harness accepts that shape — not broad Binaryen parity claims for typed-loop SSA.
- Exceptional-edge SSA remains explicitly unimplemented and intentionally deferred. The CFG already records `ExceptionalEdge` successors for `try` / `try_table` headers and throw-family terminators, but SSA v1 liveness, dominators, phi placement, dominator-stack rename, and predecessor-copy destruction all follow the normal-flow-only contract.
- Catch continuations are not dominated by throwing blocks.
- The current rename algorithm cannot propagate reaching definitions across exceptional edges without a dedicated exceptional SSA mode.
- `ssa-nomerge` is safe because it skips exceptional-flow HOT mutation via `ssa_nomerge_has_exceptional_flow(...)`, not because the local SSA overlay models exceptional successors.
- Exceptional-flow behavior is fail-closed for HOT SSA mutation and regression-covered: `try_table` write-before-throw, default-local catch continuation, conditional throw with a preceding local write, legacy `rethrow` / `delegate` shapes, and a pipeline trace that must not contain `pass[ssa-nomerge]:mutated`. Some existing raw/no-write normalization may still preserve semantics, but `ssa-nomerge` must not enter HOT local-SSA rewriting for exceptional-flow functions. These tests prove preserved local traffic where writes exist; they do not enable exceptional SSA rewriting.
- Full exceptional SSA remains deferred. Future work requires exceptional-inclusive liveness, catch-block phi placement, exceptional phi inputs, rename semantics for catch blocks, SSA destruction copies before throw/rethrow/delegate terminators, and shape-by-shape guard narrowing with rewrite tests — not Binaryen parity claims for exceptional SSA.
- The O4z public preset still intentionally no-ops `ssa-nomerge`; the direct-pass corruption and debris fixes do not by themselves justify re-enabling the O4z slot.
- The 2026-06-09 direct final lane is normalized-green at `99751/100000` with `0` mismatches, and the param-slot / needed-copy follow-ups stayed green at `9977/10000`; artifact exact parity and O4z neighborhood replay remain open.
- The direct `[SSA]001` temp-local declaration drift is closed by focused tests plus the current `10000 / 10000` `gen-valid` lane.
- The focused extracted-function CLI replay now proves that the old `Func 523` `writeback-validate:type mismatch` skip is retired.
- A fresh direct traced skip census after the large-structured / `Func 4302` follow-up is available in `.tmp/ssa-nomerge-high-threshold-narrow-ssa-trace`: raw fast/no-op skip families are `2524` `structured-local-writes`, `1077` `no-local-writes`, `1020` `straight-line-local-writes`, and only `17` `large-structured-local-writes`; there are `0` `skip-invalid-lower` lines. Remaining large skips now carry exact payloads such as `func=(Func 3781) instrs=39283 locals=6634`. The older `2026-04-11` count of `228` suspicious skips and the param-slot follow-up count of `1` `Func 4302` suspicious skip are both superseded.
- The same input still succeeds under Binaryen with `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --ssa-nomerge`.
- So the current output-facing blocker for the reduced `Func 523` family is fixed, the `Func 4302` false-positive suspicious skip is narrowed away, most large-structured direct no-ops are now covered, and the high-threshold raw-structured artifact size regression is fixed by needed-only copies/canonical body-local reuse. Direct artifact replay remains mandatory because exact normalized/canonical function parity is not green and the remaining `17` huge structured functions are still skipped.

## Practical Rule

- Keep direct debug-artifact replay in the `ssa-nomerge` signoff loop.
- Treat the seeded `binaryen-rec-group-zero` wasm-smith failure as an oracle parser gap, not an SSA semantic mismatch.
- Treat current-source behavior parity as green for the fixed dead-param family, the reduced unreachable compare-carrier follow-up, the exceptional-edge fail-closed guard, the raw no-write default-local rewrite, the raw no-write dropped-unreachable-debris cleanup, and the raw structured needed-copy/canonical-local cleanup, but do not claim exact artifact parity until a fresh traced full-artifact replay is normalized/canonical-function equal or the remaining representation drift is intentionally accepted.
- Keep the direct artifact replay and the `10000 / 10000` `gen-valid` compare lane together as the minimum signoff pair; the current `0x5eed` `gen-valid` lane is green in `.tmp/pass-fuzz-ssa-nomerge-genvalid-10000-if-order-fix-rerun`.

## Sources

- 2026-06-09 exceptional-edge/default-local audit: `[../../../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md](../../../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md)`
- Implementation/test-map refresh: `[../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md](../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md)`
- Research note for this refresh: `[../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md](../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md)`
- Archived research doc: `[../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md](../../../raw/research/0076-2026-04-10-ssa-nomerge-parity-investigation.md)`
- Pass implementation: `[../../../../../src/passes/ssa_nomerge.mbt](../../../../../src/passes/ssa_nomerge.mbt)`
- Pass manager guard: `[../../../../../src/passes/pass_manager.mbt](../../../../../src/passes/pass_manager.mbt)`
- CLI artifact test surface: `[../../../../../src/cmd/cmd_wbtest.mbt](../../../../../src/cmd/cmd_wbtest.mbt)`
- Random compare harness: `[../../../../../scripts/lib/pass-fuzz-compare-task.ts](../../../../../scripts/lib/pass-fuzz-compare-task.ts)`

