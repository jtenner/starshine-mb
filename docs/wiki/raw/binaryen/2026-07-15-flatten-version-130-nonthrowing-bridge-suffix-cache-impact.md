# Binaryen v130 `flatten`: nonthrowing bridge cleanup and run-wide suffix ownership

## Scope

This note records the bounded internal-only iteration that:

1. proves whether a resultless synthetic catch-all `Try` body may throw before HOT lowering;
2. removes dead handler scaffolding for nonthrowing bodies, retaining only a void block when the try label is targeted;
3. admits direct `i32.mul` and `i32.and` resultless-call argument roots after unconditional legacy-try `br_table` transfer;
4. replaces repeated suffix use-def construction with one run-wide snapshot and admission-time cache of exact owned nodes plus owner region.

The public registry, dispatcher, CLI execution path, preset scheduler, compare allowlist, and API snapshots remain unchanged. `flatten` is still public-removed.

## Pinned source and commits

- Iteration start: `4c8a02ebc`.
- Code commit 1: `d20ebd21c` (`perf: elide nonthrowing flatten catch bridges`).
- Code commit 2: `e9cb90b84` (`perf: share flatten suffix use-def proofs`).
- Code slice 3: run-wide suffix cache plus direct `i32.and` admission, committed with this note.
- Captured owner: `.tmp/binaryen-v130/Flatten.cpp`.
- Owner SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`.
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`.
- Direct probe form: `wasm-opt <probe>.wat --all-features --flatten -S`.

Binaryen v130 direct flatten retains the legacy try and unreachable suffix in Flat-IR order. Its matched `--vacuum --dce` neighborhood removes a catch whose body cannot throw. Starshine now performs that nonthrowing proof during lowering, while preserving the bridge for calls or other possibly throwing bodies.

## Red-first tests

Exactly one behavioral test was added for each code slice:

- `hot lower elides a nonthrowing synthetic catch-all bridge` failed on the nested `block` / `try_table` bridge, then passed with direct body emission and module validation; the prior bridge test was changed to contain a possibly throwing call and still proves the bridge path;
- `flatten removes an exclusively owned direct multiply call suffix` failed unchanged at `238/239`, then passed after direct `i32.mul` root admission and per-attempt use-def reuse;
- `flatten removes an exclusively owned direct and call suffix` failed unchanged at `239/240`, then passed after direct `i32.and` admission and run-wide cached ownership.

The whitebox outside-roster boundary moved from newly admitted `i32.mul`, then `i32.and`, to still-gated `i32.or`; it remains a fail-closed boundary rather than a second positive slice.

## Ownership and mutation safety

`FlattenRewriteState` now owns:

- one use-def snapshot built before admission;
- one optional exact dead-suffix node vector per table node;
- the exact owner region for each cached vector;
- a `rewrites_started` boundary.

Admission computes and caches the complete distinct one-use proof. Rewrite consumes only a cache entry whose table id and owner region match. If mutation has started and no matching cache exists, suffix recognition returns `None`. This prevents a stale pre-mutation use-def snapshot from widening ownership after structural edits.

## Refreshed output matrix

The same three synthetic probes from the prior impact note were regenerated after the lowering change. Binaryen artifacts remain the pinned prior-oracle outputs.

| Probe | Input | Starshine direct | Starshine cleanup | Binaryen direct | Binaryen cleanup |
| --- | ---: | ---: | ---: | ---: | ---: |
| catch-all result bridge | 66 | 64 | 64 | 87 | 72 |
| recursive call tree | 69 | 74 | 74 | 94 | 82 |
| direct subtract call | 69 | 74 | 74 | 94 | 82 |
| **Aggregate** | **204** | **212** | **212** | **275** | **236** |

Every current Starshine direct and cleanup artifact passed `wasm-tools validate --features all`.

The narrow bridge/control/local family is now a measured Starshine size win:

- direct: 63 bytes smaller than Binaryen (`212` versus `275`);
- matched cleanup: 24 bytes smaller than Binaryen (`212` versus `236`);
- Starshine cleanup is a no-op on these already-clean emitted shapes.

The WAT difference is source-backed: nonthrowing catch bodies are unreachable, live try-label branches are preserved by one void block, and Starshine avoids Binaryen's extra result-copy locals. This classification is limited to the measured synthetic catch-all subset; it is not evidence for typed catches or broader EH.

## Runtime semantics

Node instantiated all input, Binaryen direct, Binaryen cleanup, current Starshine direct, and current Starshine cleanup artifacts with a no-op `env.sink` import. Every probe returned the expected deterministic result (`3` for the branch-free bridge and `7` for both table-transfer probes).

Sum of per-probe medians after 10,000 warmups and 15 samples of 100,000 calls:

| Lane | Sum of medians |
| --- | ---: |
| input | 1.342171 ms |
| Binaryen direct | 1.524702 ms |
| Binaryen cleanup | 1.364372 ms |
| Starshine direct | 1.379081 ms |
| Starshine cleanup | 1.365836 ms |

These samples establish deterministic agreement and no obvious runtime regression. They remain too narrow and noisy for a runtime-win claim.

## Pass-local performance

The representative native release benchmark prebuilt 120 HOT functions, evenly split across the one-multiply-child, two-multiply-child, and deeper-two-multiply-plus-constant call-argument families. Five warmups preceded 20 measured `flatten_run(...)` batches.

| Lane | Median | Range | Ratio to Binaryen |
| --- | ---: | ---: | ---: |
| prior current | 3,682.5 us | 3,529..3,765 us | 13.84x |
| run-wide cached current | 2,345.5 us | 2,248..2,660 us | 8.82x |
| cached EH/effective-terminal current | 1,641 us | 1,583..1,813 us | 6.17x |
| cached scalar-try support current | 1,275 us | 1,224..1,324 us | 4.79x |
| explicit EH admission-gate current | 1,347.5 us | 1,280..1,931 us | 5.06x |
| Binaryen v130 | 266.05 us | 250.16..380.856 us | 1.00x |

The follow-up profile attributed most measured time to repeated legacy-try support during rewrite. `FlattenRewriteState` now caches the immutable pre-admission EH prerequisite classification, try-target terminal checks consume the existing cached suffix proof instead of rebuilding an uncached use-def snapshot, and the complete scalar legacy-try support decision is cached per owner before mutation and consumed only by matching later rewrite checks. The representative median improved another 22.30% from `1,641 us` to `1,275 us`. After adding explicit catch-payload and exceptional-transfer admission outcomes, the same 120-function native-release shape reran at `1,347.5 us` median (`1,280..1,931 us`), or `5.06x` Binaryen. Performance therefore remains well outside the maximum acceptable `2x Binaryen` threshold and blocks public exposure.

## Validation

- HOT-lower focused file: `88/88`.
- Flatten focused file: `240/240`.
- Private flatten file: `142/142`.
- Pass package: `5,712/5,712`.
- Full suite: `9,171/9,171`.
- `moon info`: passed with existing warnings.
- Every regenerated matrix artifact validated with all features.
- `git diff --check` and docs link/source review are required before commit.

Follow-up proof-cache validation: direct `i32.or` behavior was red at `240/241` and green at `241/241`; direct `i32.xor` behavior was red at `241/242` and green at `242/242`. Private flatten passed `142/142`, the pass package passed `5,714/5,714`, and `moon info` passed with the existing warnings.

Follow-up EH-gate validation used a pinned Binaryen v130 typed-catch probe. Direct `--flatten` stages the typed `(pop i32)` into a fresh local before the original drop, confirming that payload extraction is semantic work rather than optional cleanup. The updated private behavior test first failed because a rooted `Catch` plus an otherwise flattenable rich operand returned `{ changed: true }`; explicit `DeferredCatchPayloadRepair` and `DeferredExceptionalTransferRepair` admission outcomes now stop `Catch`/`CatchAll` and `Rethrow`/`Delegate` functions before locals or operand rewrites can begin. Final validation passed private flatten `142/142`, passes `5,714/5,714`, the full suite `9,173/9,173`, `moon info`, targeted formatting, and `git diff --check`. Repository-wide `moon fmt --check` still fails only on the pre-existing `moon.mod` `options(source: ...)` versus `source = ...` syntax disagreement.

## Classification and remaining blockers

- **Measured Starshine win:** nonthrowing synthetic catch-all bridge/control/local output is 24 aggregate bytes smaller than Binaryen after matched cleanup, with deterministic runtime agreement.
- **Performance movement:** run-wide suffix caching plus cached EH, effective-terminal, and scalar-try support proofs reduce the representative median from `3,682.5 us` to `1,275 us`; the post-EH-gate rerun is `1,347.5 us`, or `5.06x` Binaryen, and remains outside target.
- **Behavior movement:** direct `i32.mul`, `i32.and`, `i32.or`, and `i32.xor` call roots now use the same recursive complete-ownership proof.
- **Validation failure:** none observed.
- **True semantic mismatch:** none observed in the measured probes.
- **Durable representation gate:** `Catch`/`CatchAll` now select `DeferredCatchPayloadRepair`, while `Rethrow`/`Delegate` select `DeferredExceptionalTransferRepair`, before any mutation. This closes a partial-mutation hole but does not implement EH repair.
- **Still gated:** typed catches and payloads, nested-pop repair, `rethrow`, `delegate`, structured suffix control-plus-label deletion, broader branch/control families, result calls, indirect/reference calls, and public execution.
- **Public signoff:** not run. No flatten GenValid aggregate or four-lane compare surface exists, and public wiring remains intentionally removed.

## Next work

1. profile and remove the next dominant repeated support/label-use scan without weakening exact label or ownership proof;
2. investigate typed catch payload representation and nested-pop repair as a lib/HOT capability slice, retaining whole-function failure atomicity;
3. add a flatten-specific GenValid aggregate only after the admitted public surface and failure contract are stable enough to compare honestly.
