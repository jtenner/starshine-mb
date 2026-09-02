---
kind: workflow
status: strong
last_reviewed: 2026-09-02
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid_directize.mbt
  - ../../../../../src/validate/gen_valid_directize_tests.mbt
  - ../../../../../src/passes/directize_test.mbt
  - ../../../../../src/passes/directize_wbtest.mbt
  - ../../../../../src/passes_perf_long/directize_perf_test.mbt
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

## September 2, 2026 renewal

The final admission-gate binary is `_build/native/release/build/cmd/cmd.exe`, SHA-256 `3e610bb09848340b1c8d83e6d093c4e3925d64d9196bc589163745efe3b49d08`. Both renewed lanes use `.tmp/binaryen-version-131-bin/bin/wasm-opt`, verified as `wasm-opt version 131 (version_131)` at SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`, plus the explicit prebuilt native Starshine command and GenValid binaries, `--jobs auto`, and `--max-subprocesses 8`.

| Lane | Out dir | Requested / compared | Canonical-equal | Explicit mismatches | Canonical size classification | Failures |
| --- | --- | ---: | ---: | ---: | --- | --- |
| regular GenValid | `.tmp/pass-fuzz-directize-final-regular-10000-20260902` | `10000 / 10000` | `10000` | `0` | `0 / 10000 / 0` smaller/equal/larger | zero validation, property, generator, and command failures |
| dedicated `directize-all` | `.tmp/pass-fuzz-directize-final-dedicated-10000-20260902` | `10000 / 10000` | `559` | `9441` | `9441 / 559 / 0` smaller/equal/larger | zero validation, property, generator, and command failures |

The dedicated run deliberately uses no cleanup normalizer and permits the full mismatch count, so the reproducible output-shape family remains visible. It selected all eight leaves and all 27 case labels with the same distribution shown below.

The `9441` mismatches are one exact pass-independent family rather than missed Directize rewrites:

- `src/validate/gen_valid_directize.mbt` emits a callee containing one inert `nop` in every dedicated case except `directize:wrong-type-trap` and `directize:select-multivalue-results`;
- the manifest contains `273` wrong-type cases and `286` multivalue-select cases, exactly the `559` canonical-equal outputs;
- every other case contains one callee `nop`, or two for ordinary scalar `select` fixtures, which Starshine omits when serializing the transformed module while Binaryen v131 retains them;
- all 20 persisted mismatch artifacts span constant, select, table-fact, tail-call, GC, table64, legacy-EH, and boundary labels and differ by exactly those generated `nop`s after the matching direct/trap/select rewrite;
- Starshine is canonically smaller in all `9441` cases and never larger, totaling `559353` versus `570049` bytes, a `10696`-byte reduction.

Agent classification: **pass-independent inert-`nop` elision and canonical size win, not a Directize semantic or transformation-parity gap**. The family is recorded explicitly rather than hidden behind a broad cleanup normalizer.

## 2026-07-30 four-lane matrix

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

### September 2 production closeout

The canonical input is `.tmp/production-smoke/size-attribution-accurate/common-star-canonical.wasm`, 4,977,401 bytes at SHA-256 `4acd06537e4466bc372a73c2e37da46f1cd94c3baca1fd62c1aa5fe76b944721`. A one-time `wasm-tools print` attribution finds 2,261 `call_indirect` sites across 261 definitions; every site targets table 1, and every target is dynamic, primarily the production `local.get; i32.load; call_indirect` shape. No site has the immediate constant or constant-arm `select` target accepted by `directize_try_rewrite_call_tail(...)`.

Clean HEAD native SHA-256 `925e2f72645efcfe48887635888b1b170d21f213ecc568283b4b106fb3436d7f` admitted these impossible candidates and exceeded a 120-second no-trace bound. The exact recursive gate now checks table eligibility plus the only supported immediate target spellings before function-context construction and producer scanning. One warmup plus three serial measured pairs produce:

| Metric | Starshine median | Binaryen v131 median | Ratio / result |
| --- | ---: | ---: | --- |
| no-trace command | `689.065ms` | `563.773ms` | `1.222x`; `416.935ms` below the fixed `<=1.106s` gate |
| pass-local | `49.177ms` | `36.192ms` | `1.359x` |
| module-pass stage | `49.194ms` | n/a | exact owner after admission |
| optimizer pipeline | `64.853ms` | n/a | `15.659ms` median pipeline remainder |

The completed current command is more than `174.149x` faster than the same-input clean-HEAD timeout lower bound and `2.029x` faster than the older `1.398s` inventory checkpoint. All three Starshine raw and no-trace outputs are byte-identical to the input. The harness's Binaryen no-pass canonicalization makes Starshine and Binaryen exactly equal at 5,300,041 bytes, SHA-256 `4a9c3279a6fb409fbf9eaf68f714141aacfd8d6d9ddacd098f29afe4bbefe583`.

The native benchmark file records two complementary lanes on x86_64 AMD Ryzen 7 8845HS with MoonBit `0.1.20260713`:

- trigger-bearing 256-call depth-64 select producer: `12.37ms +/- 137.51us`;
- fail-closed 2,048-function dynamic-target breadth: `156.93us +/- 1.76us`, requiring exact module equality and preserved indirect calls before timing.

### Historical July evidence

A 2026-07-30 performance review replaced repeated backward suffix allocation/typechecking in select discovery with a single producer/provenance stack scan. The trigger-bearing skipped native-release lane `src/passes_perf_long/directize_perf_test.mbt` uses `256` indirect calls with depth-`64` argument and condition expressions and reports a final median of `17.415ms` under its `22ms` bound; the pre-repair fixture measured roughly `28–30ms`. Fresh rebuilt native SHA-256 `84bcf115d3ce400923aa7b239c94d20f278eb1bd6455bb031c87b284f12006fd` preserves exact Binaryen-v131 parity in `.tmp/review-fix-directize-regular-100000-20260730-final` (`100000/100000`) and `.tmp/review-fix-directize-dedicated-10000-20260730-final` (`10000/10000`), with zero failures or mismatches. Focused directize tests now pass `18/18`, including chained rewritten-call result provenance.

`.tmp/directize-v131-final-artifact-20260730` reports:

- Starshine pass-local `46.973ms`;
- Binaryen pass-local `42.052ms`;
- ratio `1.12x`, inside the repository's `2x` closeout target;
- whole command `692.690ms` versus `758.656ms` in Starshine's favor.

The debug artifact has `2261` remaining `call_indirect` sites in both outputs; it does not provide a pass trigger. Its canonical text/bytes remain affected by the separately tracked self-opt normalization asymmetry (`[TOOL]001`), so this run is timing evidence, not direct semantic equality evidence. The dedicated generated lane is the transform-bearing output-parity proof.

## Validation gate

The September 2 implementation gate records:

- focused Directize white-box admission: `1/1`;
- legacy-EH audit: `9/9`;
- focused Directize behavior: `18/18`;
- full `moon test`: `10910/10910`;
- native-release Directize benchmarks: `2/2`;
- `bun validate full --profile ci --target wasm-gc` passed at seed `0x1a06246af1465da`, including 5,000 valid-AST checks and 86,820 binary roundtrips;
- both explicit-v131 10,000-case lanes above with zero validation, property, generator, or command failures.

The 2026-07-30 implementation gate also passed:

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
