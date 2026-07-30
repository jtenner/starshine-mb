---
kind: workflow
status: strong
last_reviewed: 2026-07-30
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid_directize.mbt
  - ../../../../../src/validate/gen_valid_directize_tests.mbt
  - ../../../../../src/passes/directize_test.mbt
  - ./index.md
---

# `directize` fuzzing and Binaryen-v131 closeout

## Oracle and build anchors

The 2026-07-30 closeout used:

- official Binaryen tag `version_131`, commit `1f903c14babf829745b421b92ff0f286e93e4209`;
- `.tmp/binaryen-version-131-bin/bin/wasm-opt`, reporting `wasm-opt version 131 (version_131)` and SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`;
- rebuilt native Starshine `_build/native/release/build/cmd/cmd.exe`, SHA-256 `887b727d07304063c536461b326e4a47e8d7aa797b67676bef816d69efb13c0f`.

Reviewed source hashes:

| Source | SHA-256 |
| --- | --- |
| `src/passes/Directize.cpp` | `f543aed65195289abf4ddfceb02a29e334c79a14f31ce07b624d832b81001363` |
| `src/passes/call-utils.h` | `3ea7409716721ae756c8a014f4bae09d2f4b11e6f4ea1e52b8249645986723f0` |
| `src/ir/table-utils.h` | `b45c6aa874081eae48bf8ce48681afe2fbfc95071c7df998efb67192b715d972` |
| `src/ir/table-utils.cpp` | `cc53115aad789c59d660c55be12f84acb7d69a07eebad1bd8220345b30f5710a` |
| `directize_all-features.wast` | `4f26c5a59fdcfb4e172a7fca408cbeee68041ef4d3c920b8b522ef672c2da3e1` |
| `directize_init.wast` | `8e471b3e09cc1dc9363dc4fa02468f42b411ae14f6b72692f9e4f9bc111f0f2d` |
| `directize-gc.wast` | `9e080ec4e65919c7b29a303b0d5cbe351413fdb1018920a3d3ac2823b5a6be51` |
| `directize-wasm64.wast` | `eed6754bf6fa8acb724247bf842c860ece938bd693bf12ba955132702fa605f9` |

## Pass-owned aggregate profile

The stable closeout profile is `directize-all`. It deterministically samples eight leaves:

| Leaf | Weight | Owned surface |
| --- | ---: | --- |
| `directize-constant` | 3 | segment-known calls, absent-default holes, `ref.func` defaults, explicit/unknown defaults with active overrides, wrong-type traps |
| `directize-select` | 3 | known/known, known/trap, trap/trap, condition evaluation, and multivalue-result select lowering |
| `directize-table-facts` | 3 | `table.set`, `table.fill`, destination `table.copy`, `table.init`, and append-only `table.grow` facts |
| `directize-tail-call` | 2 | `return_call_indirect` known and trap outcomes |
| `directize-gc` | 2 | subtype-compatible direct calls and reversed-subtype traps |
| `directize-table64` | 2 | full-width i64 known targets and the `2^32 + 1` no-truncation trap boundary |
| `directize-legacy-eh` | 3 | protected body, typed catch, catch-all, delegate, and `try_table` traversal |
| `directize-boundaries` | 2 | imported/exported table negatives, passive/declarative non-participation, and multi-table positives |

Every generated leaf validates and contains an indirect-call surface. `src/passes/directize_test.mbt` additionally runs five deterministic seeds per leaf and requires each generated module to trigger a valid pass-owned rewrite. The profile is a member of `random-all-profiles`, and batch manifests preserve both `selected_profile` and `profile_case_label`.

## Final four-lane matrix

All commands used explicit `--jobs auto`, `--starshine-bin _build/native/release/build/cmd/cmd.exe`, `--wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt`, `--max-failures 2000`, `--keep-going-after-command-failures`, and `--no-reduce-mismatches`.

| Lane | Seed | Out dir | Requested / compared | Normalized | Compare-normalized | Raw mismatches | Command failures | Cache |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| regular GenValid | `0x5eed` | `.tmp/pass-fuzz-directize-v131-final-regular-100000-20260730` | `100000 / 100000` | `100000` | `0` | `0` | `0` | Binaryen `100000` hits / `0` misses |
| dedicated `directize-all` | `0x5eed` | `.tmp/pass-fuzz-directize-v131-final-dedicated-10000-20260730` | `10000 / 10000` | `10000` | `0` | `0` | `0` | Binaryen `10000` hits / `0` misses |
| explicit wasm-smith | `0x5eed` | `.tmp/pass-fuzz-directize-v131-final-wasm-smith-10000-20260730` | `10000 / 9956` | `9955` | `0` | `1` | `44` Binaryen/tool failures | wasm-smith `10000/0`; Binaryen `9956/0`; failure cache `44/0` |
| random all-profiles | `0x5555` | `.tmp/pass-fuzz-directize-v131-final-random-all-10000-20260730` | `10000 / 10000` | `9820` | `0` | `180` | `0` | Binaryen `10000` hits / `0` misses |

There were zero validation, generator, property, or Starshine command failures in all four lanes.

### Dedicated distribution

The dedicated lane selected every leaf:

- `directize-legacy-eh`: `1467`
- `directize-select`: `1541`
- `directize-constant`: `1507`
- `directize-table-facts`: `1482`
- `directize-tail-call`: `1006`
- `directize-gc`: `1019`
- `directize-boundaries`: `993`
- `directize-table64`: `985`

All `27` recorded case labels were selected. Notable counts include multivalue select `286`, table64 known/trap `460/525`, GC subtype/reversed `512/507`, legacy protected/typed/catch-all/delegate/try-table `306/259/295/293/314`, and table set/fill/copy/init/grow `301/292/290/297/302`.

## Residual classifications

### wasm-smith residual

The sole raw mismatch, case `009332`, contains no calls and therefore cannot exercise `directize`. Binaryen's parse/emit path removes a `drop(unreachable)` wrapper while Starshine preserves it, producing `77` versus `79` canonical bytes. Replaying the full lane with `--normalize unreachable-control-debris` at `.tmp/pass-fuzz-directize-v131-final-wasm-smith-10000-normalized-20260730` classifies it as one compare-normalized match and leaves zero mismatches.

Agent classification: **pass-independent cleanup representation gap**, not a directize semantic or size claim.

The `44` command failures are Binaryen/tool admissions: `39` zero-sized recursion groups, `1` invalid tag index, `1` table index out of range, and `3` bad section sizes.

### Random all-profiles residuals

All `180` raw mismatches came from `remove-unused-brs-*` profile inputs with `hasCall=false`: GC `39`, multivalue-drop `33`, control `39`, cleanup `23`, and switch `46`. None contains a direct or indirect call, so none can exercise this pass. They are the established Binaryen-vs-Starshine local reconstruction/encoding family exposed by the updated composite distribution, not directize behavior.

Canonical size deltas (`Starshine - Binaryen`) were `-12` for `12` cases, `-8` for `134`, `-1` for `1`, and `+1` for `33`. The `+1` subgroup remains a pass-independent local-run representation gap; the smaller outputs are not used to excuse any directize drift.

Agent classification: **180 pass-independent codec/local-reconstruction residuals; zero directize-owned mismatches**.

## Behavior repairs found by the audit

The source/profile audit found and fixed four released-default gaps:

1. table64 call targets and active offsets now use full-width unsigned addresses; `4294967297` cannot truncate to slot `1`;
2. the validator now pops the table's address type for `call_indirect` / `return_call_indirect` (`i32` for table32, `i64` for table64);
3. select lowering now accepts known-trap arms and multivalue results, reusing an existing no-parameter block-signature type when possible and interning one new signature when required;
4. explicit non-`ref.func` table initializers, including explicit `ref.null`, remain unknown exactly as Binaryen v131 does, while an absent initializer keeps the defined-table null-hole trap rule.

The table model was also changed from an initial-size allocation to sparse explicit-entry facts plus a full-width declared initial size. This avoids allocating an array proportional to a large table limit and matches Binaryen's separation between flattened segment entries and declared defaults.

## Artifact and performance evidence

`.tmp/directize-v131-final-artifact-20260730` reports:

- Starshine pass-local `46.973ms`;
- Binaryen pass-local `42.052ms`;
- ratio `1.12x`, inside the repository's `2x` closeout target;
- whole command `692.690ms` versus `758.656ms` in Starshine's favor.

The debug artifact has `2261` remaining `call_indirect` sites in both outputs; it does not provide a pass trigger. Its canonical text/bytes remain affected by the separately tracked self-opt normalization asymmetry (`[TOOL]001`), so this run is timing evidence, not direct semantic equality evidence. The dedicated generated lane is the transform-bearing output-parity proof.

## Validation gate

The final implementation gate passed:

- `moon info`
- `moon fmt`
- directize focused tests: `16/16`
- directize profile tests: `2/2`
- table64/typecheck focused tests: `71/71`
- `moon test src/passes`: `6580/6580`
- `moon test src/fuzz`: `642/642`
- full `moon test`: `10104/10104`
- `moon build --target native --release src/cmd`
- `bun validate readme-api-sync`
- `bun validate full --profile ci --target wasm-gc`, including all `86820` binary roundtrips

## Reopening criteria

Reopen direct `directize` parity if any of the following occurs:

- Binaryen changes `Directize.cpp`, `call-utils.h`, or the table-info contract;
- a generated case with a directize-owned call/table label produces a raw mismatch, validation failure, or semantic runtime mismatch;
- table64, GC subtype, legacy-EH traversal, trap-effect preservation, or multivalue-select behavior regresses;
- optional `directize-initial-contents-immutable` support becomes part of Starshine's public pass-argument surface;
- pass-local time exceeds `2x` Binaryen on a comparable trigger-bearing artifact.
