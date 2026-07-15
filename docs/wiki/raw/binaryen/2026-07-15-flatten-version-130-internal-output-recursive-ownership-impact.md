# Binaryen v130 `flatten`: internal output bridge, recursive ownership, and iteration impact

## Scope

This note records the 2026-07-15 internal-only iteration that:

1. added a lowering bridge from resultless synthetic catch-all HOT `Try` nodes to representable nested `block` / `try_table` wasm;
2. replaced six overlapping bounded direct-call argument recognizers with one recursive distinct one-use ownership collector;
3. admitted direct `i32.sub` call arguments and reused recognized multi-root suffix ownership results instead of rebuilding the same use-def proof.

The public registry, dispatcher, CLI execution path, preset scheduler, compare-harness allowlist, and API snapshots remain unchanged. `flatten` is still public-removed.

## Pinned source and commits

- Iteration-start baseline: `89bbc2a7b08b71813a8cdac2532b9431ead5a3cb`.
- Code commit 1: `b789c2ff7589ebb766af89fc69cf7446778621c1` (`feat: lower synthetic catch-all try nodes`).
- Code commit 2: `a2ce97352765c73250de0ccc4422eb3b7147244f` (`refactor: collect owned flatten call trees recursively`).
- Code commit 3: `7af372b56967607310425cfce1a1b6bd777f5932` (`perf: reuse flatten suffix ownership results`).
- Captured owner: `.tmp/binaryen-v130/Flatten.cpp`.
- Owner SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`.
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`.
- Direct probe form: `wasm-opt <probe>.wat --all-features --flatten -S`.

Binaryen v130 routes concrete legacy-try do/catch results through one local and retains unreachable post-`br_table` call trees in Flat-IR order. Starshine continues to delete only complete unreachable suffixes after unconditional transfer and complete exclusive ownership proof.

## Red-first tests

Exactly one behavioral test was added for each code commit:

- `hot lower bridges a resultless synthetic catch-all try through try_table` failed because HOT lowering aborted on `Try`, then passed with exact output-shape and module-validation checks;
- `flatten emits valid wasm after removing a recursively owned call argument suffix` failed because the recursive subtract/add/two-multiply call tree remained deferred, then passed through internal flatten, HOT verification, lowering, encoding, and wasm validation;
- `flatten removes an exclusively owned direct subtract call suffix` failed because direct subtraction was outside the call-root roster, then passed after admission and ownership-result reuse.

## Consolidated baseline/current/Binaryen matrix

A detached worktree at the iteration baseline and the current worktree ran the same package-private synthetic HOT builders. The current lane additionally lowered, encoded, validated, and ran `vacuum -> dead-code-elimination`. Binaryen used equivalent exported WAT modules and `--flatten`, followed by `--vacuum --dce` for the cleanup neighborhood.

### Transformation and representability

| Probe | Baseline transform | Current transform | Current local delta | Current live-node delta | Baseline output | Current output |
| --- | --- | --- | ---: | ---: | --- | --- |
| catch-all result bridge | changed; Flat | changed; Flat | +1 | +3 | unavailable: synthetic `Try` lower abort | lowered, encoded, validated |
| recursive subtract/add/two-multiply call suffix | unchanged; non-Flat | changed; Flat | +2 | -6 | unavailable | lowered, encoded, validated |
| direct subtract call suffix | unchanged; non-Flat | changed; Flat | +2 | 0 net; owned call/tree deleted and routing nodes added | unavailable | lowered, encoded, validated |

The first probe demonstrates infrastructure movement rather than new flatten admission: the baseline already flattened the HOT shape but could not emit it. The other two probes are behavior movement from `DeferredLegacyTry` to admitted Flat output.

### Encoded bytes and cleanup neighborhood

| Probe | Input | Baseline Starshine | Current Starshine | Current cleanup | Binaryen flatten | Binaryen cleanup |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| catch-all result bridge | 66 | unavailable | 85 | 79 | 87 | 72 |
| recursive call tree | 69 | unavailable | 89 | 88 | 94 | 82 |
| direct subtract call | 69 | unavailable | 89 | 88 | 94 | 82 |
| **Aggregate** | **204** | **unavailable** | **263** | **255** | **275** | **236** |

Current direct Starshine output is 12 bytes smaller than Binaryen direct output (`-4.36%`) on this narrow matrix, but this is not a size-win classification: after the matched cleanup neighborhood Starshine is 19 bytes larger (`+8.05%`). Starshine cleanup removes only 8 bytes (`-3.04%`) versus Binaryen's 39 bytes (`-14.18%`). The remaining nested bridge/control/local debris is therefore an open **size-losing cleanup-neighborhood parity gap**.

All input, Binaryen direct, Binaryen cleanup, Starshine direct, and Starshine cleanup artifacts passed `wasm-tools validate --features all`. Current Starshine's encoded-output measurement blocker is cleared only for the synthetic resultless catch-all bridge. Typed catches, payload repair, nested-pop repair, `rethrow`, and `delegate` remain unrepresentable and gated.

### Runtime and semantics

Node instantiated every encoded artifact with a no-op `env.sink` import. Each probe returned the expected deterministic result (`3` for the branch-free bridge and `7` for both table-transfer probes). Each lane used 10,000 warmups and 15 samples of 100,000 calls. Sum of per-probe medians:

| Lane | Sum of medians |
| --- | ---: |
| input | 1.300592 ms |
| Binaryen flatten | 1.453869 ms |
| Binaryen cleanup | 1.327724 ms |
| current Starshine | 1.393295 ms |
| current Starshine cleanup | 1.265086 ms |

These sub-millisecond per-probe samples establish deterministic semantic agreement and no obvious generated-runtime regression. They are too noisy and too narrow for a durable runtime-win claim. Baseline Starshine runtime remains unavailable because the baseline cannot lower the synthetic `Try`.

### Pass-local performance

A native release temporary package prebuilt 120 HOT functions, evenly split across the one-multiply, two-multiply, and deeper-two-multiply call-argument families. Five warmups preceded 20 measured `flatten_run(...)` batches. Binaryen v130 used nine `BINARYEN_PASS_DEBUG=1` runs on the equivalent candidate-dense WAT.

| Lane | Median | Range | Ratio to Binaryen |
| --- | ---: | ---: | ---: |
| iteration baseline | 16,880 us | 16,539..17,409 us | 63.45x |
| current Starshine | 3,682.5 us | 3,529..3,765 us | 13.84x |
| Binaryen v130 | 266.05 us | 250.16..380.856 us | 1.00x |

Ownership-result reuse and the recursive collector reduce the refreshed baseline median by 78.18%. This is material progress, but current Starshine is still about 6.92 times slower than the project's maximum acceptable `2x Binaryen` threshold. Performance remains a public-exposure blocker.

## Validation

- HOT-lower focused file: `87/87`.
- Flatten focused file: `238/238`.
- Private flatten file: `142/142`.
- Pass package: `5,710/5,710`.
- Full suite: `9,168/9,168`.
- `moon info`: passed with existing warnings.
- Targeted formatter execution completed for changed files during each code slice. A later `moon fmt --check` still reports two pre-existing formatter disagreements in old `flatten_test.mbt` blocks; those unrelated lines were intentionally not included in this iteration.
- Current HOT passed Starshine verification before lowering; every encoded direct and cleanup artifact passed `wasm-tools validate --features all`.

## Classification and remaining blockers

- **Behavior movement:** recursive owned call trees and direct subtract roots now transform without arbitrary depth or immediate-argument count caps.
- **Infrastructure movement:** resultless synthetic catch-all HOT `Try` can now lower to valid `try_table` wasm.
- **True semantic mismatch:** none observed in the measured probes.
- **Validation failure:** none.
- **Direct-size result:** smaller than Binaryen on this narrow matrix, but not a proven win because cleanup loses.
- **Cleanup result:** size-losing parity gap; Starshine leaves 19 aggregate bytes beyond Binaryen after matched cleanup.
- **Generated runtime:** deterministic agreement; no durable win claimed.
- **Pass performance:** improved materially but still 13.84x Binaryen and outside the `<=2x` target.
- **Unsupported/gated:** typed catches and payloads, nested-pop repair, `rethrow`, `delegate`, structured suffix control-plus-label deletion, broader branch/control families, result calls, indirect/reference calls, and public pass execution.
- **Public signoff:** not run. The pass remains removed, has no dedicated GenValid aggregate, and cannot honestly enter the required four-lane compare matrix yet.

## Public status and next work

This iteration is incomplete. It clears the narrow synthetic catch-all output blocker and removes bounded call-tree recognizers, but it does not satisfy output cleanup, performance, EH, broad behavior, profile, four-lane, aggressive-neighborhood, or documentation-closeout criteria for public exposure.

Recommended next slices are:

1. reduce the extra bridge/control/local debris exposed by the matched cleanup matrix without weakening EH gates;
2. move the recursive ownership/use-def snapshot outward so candidate-dense scans approach the `<=2x Binaryen` target;
3. add a tested representation for one typed catch payload or record the exact lower/repair blocker if nested-pop correctness cannot yet be preserved.
