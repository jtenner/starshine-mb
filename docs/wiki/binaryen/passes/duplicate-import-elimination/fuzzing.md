---
kind: workflow
status: strong
last_reviewed: 2026-07-28
sources:
  - ../../../raw/binaryen/2026-07-28-duplicate-import-elimination-v131-refresh.md
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/fuzz/main.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt
---

# `duplicate-import-elimination` fuzzing profile

## Current closeout profile

Use `--gen-valid-profile duplicate-import-elimination`. The aggregate has five leaves:

| Leaf | Weight | Required family coverage |
| --- | ---: | --- |
| `duplicate-import-elimination-functions` | 2 | direct and nested `call`, `ref.func`, `return_call`, start, export, declarative function element, defined-function index shift |
| `duplicate-import-elimination-identity` | 2 | same-type duplicates, mixed-type representative reset, different module, different base, structurally equal types under distinct `TypeIdx` declarations |
| `duplicate-import-elimination-module-code` | 2 | table/global `ref.func` initializers plus function-index, untyped-expression, and typed-expression element payloads |
| `duplicate-import-elimination-legacy-eh` | 4 | protected body, typed catch, catch-all, delegate-bearing nested legacy `try`, and `try_table` protected body |
| `duplicate-import-elimination-nonfunction` | 2 | duplicate globals, tables, memories, and tags remain untouched |

Every positive leaf contains at least one duplicate function import. The non-function leaf is an intentional scope-boundary negative. `src/passes/duplicate_import_elimination_test.mbt` encodes, decodes, transforms, validates, and reruns every leaf and every identity/EH variant; positives must remove a function import, the negative must remain exactly unchanged, and every result must be idempotent.

Manifest metadata records the selected leaf and one of these family labels:

- `duplicate-import-elimination:body-references`
- `duplicate-import-elimination:identity-same-type`
- `duplicate-import-elimination:identity-representative-reset`
- `duplicate-import-elimination:identity-different-module`
- `duplicate-import-elimination:identity-different-base`
- `duplicate-import-elimination:identity-equal-structural-types`
- `duplicate-import-elimination:module-code-references`
- `duplicate-import-elimination:legacy-eh-protected`
- `duplicate-import-elimination:legacy-eh-typed-catch`
- `duplicate-import-elimination:legacy-eh-catch-all`
- `duplicate-import-elimination:legacy-eh-delegate`
- `duplicate-import-elimination:try-table-protected`
- `duplicate-import-elimination:nonfunction-negative`

## Oracle and artifacts

The 2026-07-28 renewal used:

- native Starshine: `_build/native/release/build/cmd/cmd.exe`
- native SHA-256: `8ddb0aa17930e0511b9c446ebf7c5e6b9efefc33d07567a10cb43f391a6cf1ea`
- explicit official oracle: `.tmp/binaryen-version-131-bin/bin/wasm-opt`
- oracle text: `wasm-opt version 131 (version_131)`
- oracle SHA-256: `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`
- default persistent cache: `.tmp/pass-fuzz-cache`
- `--jobs auto`, which resolved to 16 workers

The v131 owner, rewrite helper, and dedicated input fixture are byte-identical to their retained v130 hashes; see the [v131 source refresh](../../../raw/binaryen/2026-07-28-duplicate-import-elimination-v131-refresh.md).

## Full four-lane matrix

| Lane | Seed | Out dir | Requested / compared | Direct normalized | Cleanup-normalized | Raw mismatches | Failures | Cache |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| regular GenValid | `0x5eed` | `.tmp/pass-fuzz-die-v131-regular-100000-20260728` | `100000 / 100000` | `100000` | `0` | `0` | validation/property/generator/command `0` | Binaryen `314` hits / `99686` misses; failures `0/0` |
| dedicated aggregate | `0x5eed` | `.tmp/pass-fuzz-die-v131-dedicated-10000-20260728` | `10000 / 10000` | `10000` | `0` | `0` | validation/property/generator/command `0` | Binaryen `10000/0`; failures `0/0` |
| random all-profiles | `0x5555` | `.tmp/pass-fuzz-die-v131-random-all-10000-20260728` | `10000 / 10000` | `9375` | `0` | `625` | validation/property/generator/command `0` | Binaryen `5416/4584`; failures `0/0` |
| explicit wasm-smith, required unnormalized run | `0x5eed` | `.tmp/pass-fuzz-die-v131-wasm-smith-10000-20260728` | `10000 / 9956` | `9955` | `0` | `1` | 44 Binaryen/tool failures: rec-group-zero `39`, invalid-tag-index `1`, table-index-out-of-range `1`, bad-section-size `3`; zero Starshine failures | wasm-smith `10000/0`; Binaryen `106/9850`; failures `0/44` |
| wasm-smith classification confirmation with `unreachable-control-debris` | `0x5eed` | `.tmp/pass-fuzz-die-v131-wasm-smith-10000-unreachable-normalized-20260728` | `10000 / 9956` | `9955` | `1` | `0` | same 44 Binaryen/tool failures | wasm-smith `10000/0`; Binaryen `9956/0`; failures `44/0` |

Commands used the standard closeout form with explicit `--wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt`, `--jobs auto`, `--starshine-bin _build/native/release/build/cmd/cmd.exe`, `--max-failures 2000`, and `--keep-going-after-command-failures`.

## Dedicated family counts

The 10,000-case aggregate selected every leaf:

- legacy EH: `3361`
- non-function negative: `1645`
- module code: `1678`
- identity: `1684`
- body references: `1632`

Every case label was represented:

- legacy protected `677`
- typed catch `635`
- catch-all `689`
- delegate `701`
- `try_table` protected `659`
- same-type identity `321`
- representative reset `339`
- different module `332`
- different base `356`
- equal structural types `336`
- module code `1678`
- body references `1632`
- non-function negative `1645`

Agent classification: all pass-owned positive and negative families are exact Binaryen-v131 normalized matches. No Starshine-only representation difference is retained for a DIE transform family.

## Residual classifications

### Random-all 625-case local-run family

All 625 mismatches select `remove-unused-brs-control`. The representative input has no imports, so both DIE implementations are no-ops. The difference is the already-classified decoder/encoder multivalue local-run family: Starshine retains a synthetic same-typed scratch local in a separate declaration run and is one canonical byte larger. This is a real size-losing representation gap owned by local-run canonicalization, not by DIE detection, rewrite, removal, legacy EH traversal, or metadata repair. It remains tracked outside this pass.

### wasm-smith `case-009332`

The input has no function imports and therefore no DIE opportunity. Binaryen emits `drop(memory.size); drop(f64.const); unreachable`; Starshine emits the same prefix plus `drop(unreachable); unreachable`. The path is already unreachable, and the existing `unreachable-control-debris` normalizer moves the sole raw mismatch to `cleanupNormalizedMatchCount=1`. Agent classification: pass-independent unreachable-control representation debris, not a DIE semantic or size claim.

### Binaryen/tool failures

The 44 wasm-smith failures are oracle/tool admission failures, not Starshine pass failures:

- zero-length recursion group: `39`
- invalid tag index: `1`
- table index out of range: `1`
- bad section size: `3`

## Performance

The implementation owner did not change in this renewal. The retained direct pass-local fixtures remain the current performance evidence:

| Fixture | Starshine median | Binaryen median | Ratio |
| --- | ---: | ---: | ---: |
| `die-import-heavy-2000i-128u.wasm` | `0.447 ms` | `2.00646 ms` | `0.223x` |
| `die-user-heavy-800i-4000u.wasm` | `0.2835 ms` | `0.946297 ms` | `0.300x` |

Both satisfy the stricter 1x target and the repository 2x acceptance bound. Re-run them if the implementation owner or remap complexity changes.

## Closeout verdict and reopening criteria

Direct Binaryen-v131 behavior parity is closed. Reopen if:

- Binaryen widens the pass beyond imported functions;
- any dedicated family stops producing its intended opportunity or boundary;
- a dedicated family develops a non-exact normalized result;
- Starshine produces a validation, generator, property, or command failure;
- a residual contains a duplicate function-import opportunity and cannot be attributed away from DIE by inspected input and output evidence;
- raw-name, structured-name, annotation, defined-function index, legacy-EH, start/export, or module-code remapping regresses;
- pass-local timing exceeds Binaryen under the retained fixture method.
