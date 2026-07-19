---
kind: comparison
status: supported
last_reviewed: 2026-07-19
sources:
  - ../../release-horizon-and-oracles.md
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedModuleElements.cpp
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
  - ./index.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./retention-and-index-rewrites.md
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../scripts/self-optimize-compare.ts
---

# `remove-unused-module-elements` Binaryen Parity

## Durable Conclusions

- `remove-unused-module-elements` is an active module pass, not a HOT-IR pass.
- The current Starshine slice is directly re-proven under the refreshed 2026-06-03 pass-fuzz harness.
- The major previously known semantic gaps are closed:
  - unused imported module elements are now dropped and survivors remapped
  - empty active data on both defined and imported memories is now dropped
  - no-op active nullref elem segments on imported tables are now dropped
  - non-constant active segment offsets are rooted in the full pass, not only the non-function variant
  - empty const-offset active element segments are pruned after liveness propagation
  - `ref.func` declaration-only element segments are retained, and declaration-only active segments on otherwise-dead tables are nullified to declarative elems instead of retaining dead tables

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt).
- The focused suite lives in [`../../../../../src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt).
- Explicit pass execution also has CLI and compare-tool coverage through [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) and [`../../../../../scripts/self-optimize-compare.ts`](../../../../../scripts/self-optimize-compare.ts).

## Focused Coverage Now Locked In

- explicit memarg memory-index rewrites
- imported-parent retention for active segments
- unused imported module-element drop plus survivor remap
- empty active data drop on live and imported memories
- no-op active nullref elem drop on imported tables
- non-noop active `nullfuncref` elem retention on live defined tables
- active element segments with global offsets in the full `remove-unused-module-elements` pass
- declarative elems needed by live `ref.func`
- declaration-only active elems on otherwise-dead tables rewritten to declarative elems

## Current Direct Signoff

- Final 2026-06-03 direct command: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-module-elements --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-rume-audit-declonly-10000`.
- Result: `9972 / 10000` compared cases, `9972` normalized matches, `0` semantic mismatches, `0` validation failures, `0` generator failures, and `28` command failures.
- Command-failure classification: `22` Binaryen empty-recursion-group parser failures, `1` Binaryen bad-section-size parser failure, `1` Binaryen table-index-out-of-range parser failure, `1` Binaryen invalid-tag-index parser failure, and `3` Starshine command failures in the same non-mismatch command-failure bucket as prior RUME signoff.
- `DFE -> RUME` neighborhood smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass duplicate-function-elimination --pass remove-unused-module-elements --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dfe-rume-audit-1000` reached `998 / 1000` compared, `998` normalized matches, `0` mismatches, and `2` Binaryen empty-recursion-group command failures.
- Debug-artifact pass-local timing: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-module-elements --timing-only --out-dir .tmp/rume-debug-artifact-timing-declonly` reported canonical wasm equality, Starshine pass runtime `25.198 ms`, Binaryen pass runtime `38.936 ms`, and no raw skip.
- The prior 2026-05-06 revalidation remains useful historical evidence; see [research note 0545](./index.md).

## Binaryen v131 gap

V131 table-initial-value roots, overlap/null/wrong-type segment retention, reference-only trap-callee emptying, and `traps_never_happen` are implemented and covered by focused fixtures in `remove_unused_module_elements_test.mbt`.

### 2026-07-19 closeout matrix (explicit v131)

Oracle: `.tmp/binaryen-version-131-bin/bin/wasm-opt` (`wasm-opt version 131 (version_131)`).
Native Starshine: `_build/native/release/build/cmd/cmd.exe`.

| Lane | Out-dir | Result |
|------|---------|--------|
| wasm-smith 10k (`--seed 0x5eed`) | `.tmp/pass-fuzz-rume-v131-closeout-wasm-smith-10000` | `9950` compared, `9949` normalized matches, **1** mismatch (`case-004700`), `50` command failures |
| GenValid regular 100k (`--seed 0x5eed`) | `.tmp/pass-fuzz-rume-v131-closeout-genvalid-100000` | `100000` compared, `100000` normalized matches, `0` mismatches, `0` command failures |
| random-all-profiles 10k (`--seed 0x5555`) | `.tmp/pass-fuzz-rume-v131-closeout-random-all-10000` | `10000` compared, `10000` normalized matches, `0` mismatches |
| DFE → RUME neighborhood 1k | `.tmp/pass-fuzz-rume-v131-closeout-dfe-rume-1000` | `1000` compared, `1000` normalized matches, `0` mismatches |
| pass-cleanup 10k (interim) | `.tmp/pass-fuzz-rume-v131-closeout-pass-cleanup-10000-noreduce` | **not a usable RUME probe**: hit `--max-failures 2000` with `2015/2015` mismatches; diffs are large-body local/`tee` expression-shape drift, not RUME keep/drop |

Command-failure classes on the wasm-smith lane: `binaryen-rec-group-zero` 39, `starshine-command-failed` 6, `binaryen-bad-section-size` 3, `binaryen-invalid-tag-index` 1, `binaryen-table-index-out-of-range` 1.

### Case `004700` classification (Starshine-win)

Input: unused memory64 with a huge `initial`, one large-offset active data segment, and one in-bounds active data segment.
Binaryen keeps the memory and both active segments; Starshine drops to `(module)`.

Cause: Binaryen roots “may trap” active data with
`maxWritten > Index(memory->initial << pageSizeLog2)`. Truncating the byte size to `Index` false-positives OOB on huge memory64 minima. Starshine compares against a full u64 byte size (`rume_mem_type_min_bytes`), so both segments are correctly in-bounds and unused defined memory is dropped.

This is an intentional Starshine win (correct OOB math, much smaller module), not a parity gap to “fix” toward Binaryen’s `Index` truncation.

Focused fixture: `remove-unused-module-elements drops nonempty in-bounds active data on unused memories` (matches Binaryen on ordinary memory32 sizes). Docs that previously claimed “nonempty active data always keeps defined memory” were corrected to match Binaryen’s import-visibility / trap-only startup rooting.

Early neighborhoods / late-tail and a dedicated RUME GenValid profile remain open under `[V131-RUME]001`.

## Historical remaining gap

- The remaining post-fix v130 compare noise was not a known RUME semantic mismatch.
- V131 turns the former test gap into a released parity obligation: Starshine needs focused table-default callable-root, wrong-type/default trap, null/overlap, and `trapsNeverHappen`-policy boundary fixtures. Its retain-all-active-elems rule is conservative under default semantics but broader than Binaryen and does not prove v131 output parity; see [`./indirect-call-trap-preservation.md`](./indirect-call-trap-preservation.md).
- The saved backlog classifies the remaining failures as parser-compatibility and decoder or validator coverage work outside the pass's intended semantics.
- Historical direct-smoke evidence from `2026-04-11` still matters: `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --count 200 --seed 0x5eed ...` reported `199 / 200` compared, `199` normalized matches, `1` command failure (`binaryen-rec-group-zero`, `case-000029-wasm-smith`), and `0` mismatches.
- The later RUME blocker record is stronger and more specific after the semantic cleanup: `.tmp/pass-fuzz-rume-live-nullfuncref-rerun` reached `165 / 165` comparable `wasm-smith` cases with `0` mismatches before the `20` command-failure cutoff.
- In that later rerun Starshine contributed no command failures; the remaining failure slots were Binaryen-side parser or canonicalization blockers: `binaryen-invalid-type-index`, `binaryen-rec-group-zero`, `binaryen-invalid-wasm-type-neg64`, and three later Binaryen parser failures at cases `000162`, `000167`, and `000185`.
- Treat the direct pass as semantically signed off for the currently comparable corpus until a new semantic mismatch appears; the open work is parser-compatibility / coverage hardening, not another RUME keep/drop or remap bug.
- For future coverage-only RUME sweeps, `pass-fuzz-compare` now has `--keep-going-after-command-failures`, which records classified Binaryen parser/canonicalization failures without letting those known command-failure families consume the `--max-failures` cutoff.
- A `2026-04-24` keep-going rerun exposed one more real semantic mismatch at `.tmp/pass-fuzz-rume-keep-going-2026-04-24/failures/case-000186-wasm-smith`: Binaryen keeps imported tables and nonempty active expression elem segments even when every initializer is `ref.null`; Starshine had treated null-only expression elems as effect-free and dropped them.
- That mismatch is now fixed. The follow-up rerun `bun scripts/pass-fuzz-compare.ts --pass remove-unused-module-elements --generator wasm-smith --count 300 --seed 0x5eed --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-rume-keep-going-2026-04-24-fix` reported `298 / 300` compared, `298` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `2` command failures.
- The 2026-05-06 refreshed full direct revalidation later exposed and fixed the non-constant active-segment rooting and empty active-elem pruning drift, then reached `9972 / 10000` compared cases with `0` semantic mismatches.

## Practical Rule

- Treat the v130 core as implemented, but treat v131 table-initial-value and overlap/trap behavior as active parity work rather than coverage-only maintenance.
- If a new mismatch appears, debug it as either:
  - liveness decision drift
  - imported-parent retention drift
  - or incomplete remap coverage

## Sources

- Backlog status source: [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Supplemental health rerun: [research note 0078](../tracker.md)
- Implementation: [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
- Focused tests: [`../../../../../src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt)
- V131 trap-policy source: [Binaryen `RemoveUnusedModuleElements.cpp`](https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp)
