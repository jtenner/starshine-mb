# Binaryen v130 `flatten`: nested dead-call arguments and iteration impact

## Scope

This note pins the 2026-07-15 internal-only iteration that widened Starshine's exact legacy-try `br_table` dead-suffix proof for three resultless direct-call argument trees:

1. one `i32.add` / `i32.sub` with one owned `i32.mul` child and one constant;
2. one `i32.add` / `i32.sub` with two owned `i32.mul` children;
3. one bounded outer add/sub combining the two-multiply tree with one direct constant.

The public registry, dispatcher, CLI execution path, preset scheduler, compare-harness allowlist, and API snapshots remained unchanged. `flatten` is still public-removed.

## Pinned source and commits

- Iteration-start baseline: `515d01be67f9c51479d4f87d541b944149416056`.
- Code commit 1: `18a868a5d4e22373daaf92dd28e56f7f9aa3b921` (`feat: admit flatten multiply-child call arguments`).
- Code commit 2: `9c6d614c9acb80bf9a8b665ea2b903b3abf0f414` (`feat: admit flatten two-multiply call arguments`).
- Code commit 3: `40d4fad8cb86d45e763c897c071f01aa67c71d2c` (`feat: admit flatten deeper multiply call arguments`).
- Captured owner: `.tmp/binaryen-v130/Flatten.cpp`.
- Owner SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`.
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`.
- Probe form: `wasm-opt <probe>.wat --all-features --flatten -S`.

Binaryen v130 preserves each dead tree's immediate call-argument position and nested operand order after the unconditional table transfer, adding Flat-IR locals and unreachable placeholders rather than executing the suffix. Starshine's narrower internal optimization deletes the complete owned suffix because the preceding `br_table` transfer is unconditional. This is not generic purity or trap analysis: every deleted call, argument node, and descendant must be distinct and one-use.

## Red-first tests

The following verifier-backed tests were added in `src/passes/flatten_test.mbt`:

- `flatten removes a call with one multiply-child argument after a scalar legacy try table`;
- `flatten removes a call with two multiply children after a scalar legacy try table`;
- `flatten removes a call with a deeper two-multiply argument after a scalar legacy try table`.

Each test failed `0/1` before its implementation and passed `1/1` afterwards. The two-multiply test uses subtraction to lock noncommutative left/right order. No duplicate private recognizer positive was added.

## Fixed impact corpus

The corpus was pinned before code changes under `.tmp/flatten-impact-corpus/`:

| Item | Purpose |
| --- | --- |
| `call-one-multiply-child.wat` | Code-commit-1 direct probe. |
| `call-two-multiply-children.wat` | Code-commit-2 direct probe; locks left-multiply, right-multiply, then subtraction. |
| `call-deeper-two-multiply-children.wat` | Code-commit-3 direct probe; locks both multiplies, inner add, outer add. |
| `boundary-alternate-unary-call.wat` | Retained fail-closed alternate `i32.ctz` call-argument opcode. |
| `boundary-structured-suffix.wat` | Retained fail-closed structured suffix; HOT cannot delete the control and owned label metadata together. |
| `multi-function.wat` | Three admitted functions plus one retained alternate-unary boundary. |
| `candidate-dense.wat` | 120 functions, evenly split across the three newly admitted families, for coverage and pass-local timing. |

Ignored raw inputs, Binaryen WAT, encoded inputs, direct Binaryen outputs, cleanup outputs, coverage logs, timing samples, and runtime JSON remain under `.tmp/flatten-impact-corpus/` and `.tmp/flatten-impact-results/`.

## Transformation coverage

Coverage used an ignored package-private HOT measurement test copied into a detached worktree at the baseline commit. The same fixed synthetic HOT shapes were measured at the baseline and after code commit 3.

| Corpus item | Functions | Baseline changed | Current changed | Newly transformed | Current unchanged / gate | Locals introduced | Live nodes removed |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| one-multiply call | 1 | 0 | 1 | 1 | 0 | 2 | 1 |
| two-multiply call | 1 | 0 | 1 | 1 | 0 | 2 | 3 |
| deeper call | 1 | 0 | 1 | 1 | 0 | 2 | 5 |
| alternate-unary boundary | 1 | 0 | 0 | 0 | 1 `DeferredLegacyTry` | 0 | 0 |
| structured boundary | 1 | 0 | 0 | 0 | 1 `DeferredLegacyTry` | 0 | 0 |
| multi-function | 4 | 0 | 3 | 3 | 1 alternate-unary `DeferredLegacyTry` | 6 | 9 |
| candidate-dense | 120 | 0 | 120 | 120 | 0 | 240 | 360 |
| **Aggregate** | **129** | **0** | **126** | **126** | **3 retained fail-closed functions** | **252** | **378** |

Five of seven modules now contain transformed functions; the baseline transformed zero. The three admitted single-function probes, functions `one`, `two`, and `deep` in the multi-function item, and all 120 candidate-dense functions changed from `DeferredLegacyTry` to `Admitted` and ended Flat according to the internal classifier. The two explicit boundary modules and `multi-function`'s boundary function remained unchanged.

This is measured goalpost movement: transformation coverage increased from `0/129` to `126/129` functions on the fixed corpus. It is not a test-count claim.

## Encoded bytes and cleanup neighborhood

The three newly admitted shapes exist only in synthetic HOT today. Lowering a synthetic legacy `Try` reaches HOT lower's unsupported-node abort, while lifting the representable WAT form introduces repair-sensitive catch nodes and therefore correctly gates the internal pass. Consequently, actual baseline/current Starshine wasm bytes are **not representable** for this surface without either public wiring or the still-missing legacy-EH lower/repair bridge. This is classified as a measurement-infrastructure failure, not a zero-byte delta and not a size win.

Binaryen v130 encoded artifacts were still retained for the fixed WAT corpus:

| Item | Input bytes | Binaryen flatten bytes | Binaryen cleanup bytes |
| --- | ---: | ---: | ---: |
| one-multiply call | 69 | 93 | 84 |
| two-multiply call | 69 | 93 | 84 |
| deeper call | 69 | 93 | 84 |
| alternate-unary boundary | 69 | 93 | 84 |
| structured boundary | 61 | 85 | 76 |
| multi-function | 162 | 259 | 223 |
| candidate-dense | 3,532 | 6,412 | 5,332 |
| **Aggregate** | **4,031** | **7,128** | **5,967** |

Binaryen direct flatten is `+3,097` bytes (`+76.83%`) versus input; its cleanup neighborhood is `+1,936` bytes (`+48.03%`) versus input and `-1,161` bytes (`-16.29%`) versus direct flatten. These are Binaryen reference costs, not Starshine size results. Current-minus-baseline and current-minus-Binaryen Starshine byte deltas remain unavailable until actual internal output can be lowered and encoded.

## Runtime and semantics

Node instantiated every encoded input, Binaryen direct-flatten output, and Binaryen cleanup output. Every measured export deterministically returned `7`; warmup was `10,000` calls, each sample measured `100,000` calls, and each median used 15 samples. The sum of per-module medians was:

- input: `6.878027 ms`;
- Binaryen flatten: `6.817874 ms`, `-0.060153 ms` / `-0.87%` versus input;
- Binaryen cleanup: `6.712375 ms`, `-0.165652 ms` / `-2.41%` versus input.

Per-item medians and ranges are preserved in `.tmp/flatten-impact-results/runtime.json`. The results are noisy at sub-millisecond scale, so they establish runtime equivalence and no obvious Binaryen regression rather than a durable performance win.

Actual iteration-baseline and current Starshine generated-module runtimes are unavailable for the same legacy-try lowering reason as encoded bytes. They must not be inferred from HOT verification. This is a runtime-measurement infrastructure failure, not a zero runtime delta.

## Optimizer performance

A native release temporary package prebuilt 120 HOT functions before timing only `flatten_run(...)`. Five warmups preceded 20 measured batches:

- iteration baseline: median `551 us`, range `527..632 us`;
- current Starshine: median `9,592.5 us`, range `9,443..10,417 us`;
- Binaryen v130 `BINARYEN_PASS_DEBUG=1`: median `334 us`, range `269..449 us` across nine runs of the equivalent candidate-dense WAT.

Current Starshine is about `17.41x` slower than its fail-closed baseline and `28.72x` Binaryen's pass-local median on this synthetic candidate-dense corpus. It therefore misses the project's `<= 2x Binaryen` target and remains a public-exposure blocker. The slowdown is kept because it accompanies 120 newly admitted transformations in an internal removed pass; it is not described as generated-module runtime.

## Correctness and classification

- Focused tests: `236/236`.
- Private flatten tests: `142/142`.
- Pass package: `5,708/5,708`.
- Full suite: `9,165/9,165`.
- `moon info` and targeted `moon fmt`: passed with existing warnings only.
- All Binaryen input/direct/cleanup artifacts validated with `wasm-tools validate --features all`.
- Every executable input and Binaryen output returned the same deterministic result.
- Immediate argument order is recorded before nested descendants; subtraction orientation and left-to-right multiply operands are preserved.
- Deleted calls and arithmetic, including any potentially trapping descendants in the admitted roster, are removed only after unconditional table transfer and complete distinct one-use ownership proof.
- Alternate opcodes, sharing/repetition, multiple nested rich arguments, result calls, indirect/reference calls, structured suffixes, repair-sensitive catch payloads, `rethrow`, and `delegate` remain gated.

Failure classification:

- Starshine validation failure: none in focused HOT verification.
- True semantic mismatch: none observed.
- Parity gap: actual lowered output parity remains unavailable for this synthetic legacy-try surface.
- Size regression: Starshine unavailable; Binaryen direct and cleanup byte expansion recorded above.
- Runtime regression: no obvious Binaryen generated-module regression; Starshine generated-module result unavailable.
- Performance regression: current candidate-dense pass-local time is materially above baseline and the project target.
- Unsupported/gated shape: alternate unary and structured suffix boundaries remain gated.
- Measurement infrastructure failure: Starshine encoded-size, cleanup, and generated-runtime lanes cannot represent the synthetic legacy-try HOT shapes.

## Public status and next work

The iteration counts as goalpost movement only through measured transform coverage: `126` functions and five modules now transform where the baseline transformed none. No Starshine byte or runtime win is claimed.

Public comparison remains blocked. The four-lane compare-pass matrix, pass-specific profile, public CLI execution, aggressive cleanup neighborhood, and preset scheduling were not run because `flatten` remains intentionally removed. Before exposure, the implementation still needs the legacy-EH lower/repair bridge or another honest internal measurement route, optimizer-performance work, broader call-tree ownership without arbitrary caps, structured control-plus-label deletion, remaining control/table/EH families, and full public signoff.
