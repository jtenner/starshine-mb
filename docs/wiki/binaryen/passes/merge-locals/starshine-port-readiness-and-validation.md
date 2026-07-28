---
kind: concept
status: strong
last_reviewed: 2026-07-28
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/merge-locals_all-features.wast
  - ../../../../../src/passes/merge_locals.mbt
  - ../../../../../src/passes/merge_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/validate/gen_valid.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./fuzzing.md
---

# Starshine validation and reopening guide for `merge-locals`

This page formerly tracked a partial forward-only port. That status is superseded: Starshine now implements the Binaryen-v131 graph algorithm for HOT-admitted control and a safe raw regional bridge for legacy EH.

## Closed implementation surface

- temporary source-local tee instrumentation;
- eager original-state local graph;
- destination ownership and reverse source ownership;
- single-source and exact-type gates;
- post-rewrite graph verification and all-sibling rollback;
- local-set and local-tee candidates;
- block, `if`, loop, and `try_table` control;
- straight-line immutable-snapshot fast path;
- protected-body, typed-catch, catch-all, and delegate-bearing legacy-`try` regions;
- no-candidate byte-preserving bypass;
- public registry, direct CLI, O4z scheduling, and compare-harness admission.

## Final Binaryen-v131 matrix

All commands used explicit official `.tmp/binaryen-version-131-bin/bin/wasm-opt`, reporting `wasm-opt version 131 (version_131)`, SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`, and rebuilt `_build/native/release/build/cmd/cmd.exe`, SHA-256 `8bc8fa62e9580d12ce9e8981153d4ab88c5d6a00a0deffb0a9628c3a492c4723`.

| Lane | Result | Classification |
| --- | --- | --- |
| Regular GenValid, `100000`, seed `0x5eed` | `100000/100000` normalized, zero failures | Exact. |
| `merge-locals-all`, `10000`, seed `0x5eed` | `9353` normalized, `647` residuals, zero failures | Every residual is the `trivial-confusion` unread-tee Starshine win, `-2` canonical bytes each. |
| Random all profiles, `10000`, seed `0x5555` | `9330` normalized, `670` residuals, zero failures | `625` structured-result wins at `-8` bytes and `45` unread-tee wins at `-2` bytes. |
| wasm-smith, `10000`, seed `0x5eed` | `9956` comparable, `9955` normalized, one residual, `44` Binaryen-only failures | Residual case `9332` is a no-copy, pass-byte-no-op codec baseline. |

The dedicated aggregate selected all fifteen leaves and every seed-rotated subfamily, including all four legacy-EH region forms.

## Runtime and idempotence

A `1000`-case `merge-locals-all` lane completed `1000/1000` idempotence checks with zero property failures. Node checked all cases without adapter failure; the 60 exported legacy-EH modules produced 60 equal results and zero semantic mismatches. A random-all structured-result representative produced the same runtime trap in both tools and remained idempotent.

## Official fixtures

- The v131 lit `between-unreachable` module is canonical-text exact and 28 bytes in both tools.
- The full all-features fixture validates in both tools. Starshine is 753 bytes and Binaryen 747 bytes. The six-byte aggregate difference comes from Binaryen rebuilding one deeply nested fuzz-only value-block sequence while Starshine preserves that control shape; local-copy decisions are otherwise matched or improved, and Starshine removes unread tees in several fixture functions. This retained shape is accepted only with the measured `3.60x` pass-local speed advantage and should reopen if it recurs as a generated canonical size-loss family.

## Validation commands

```text
moon info
moon fmt
moon test --package jtenner/starshine/passes --file merge_locals_test.mbt
moon test --package jtenner/starshine/validate --file gen_valid_merge_locals_tests.mbt
moon test src/passes
moon test
moon build --target native --release src/cmd
```

See [`fuzzing.md`](fuzzing.md) for the exact compare commands and cache counters.

## Remaining non-pass work

- `[TOOL]001`: symmetric handling of no-copy unreachable-debris writer differences.
- `[WALL]001`: whole-command decode, validation, encoding, buffering, and process-startup attribution.
- `[COALESCE-LOCALS]001`: downstream extended local-cleanup suffix numbering and shape gaps; these are not direct `merge-locals` failures.
