# Optimize-instructions OI-K dedicated aggregate GenValid profile

Date: 2026-07-03

## Scope

This slice completes the OI-K tooling follow-up left by `1436`: add a dedicated GenValid trigger-smoke profile for GC aggregate constructor/get/set shapes and make OI-K sweep planning use that profile instead of the broader non-dedicated `pass-oi-ref-gc` reference smoke.

The new profile is intentionally limited to OI-K-owned aggregate surfaces:

- `struct.get(struct.new(...))` pure and effectful-sibling shapes;
- `array.get(array.new_fixed(...))` pure and effectful-sibling shapes;
- `array.set(array.new_fixed(...))` in-bounds and out-of-bounds effectful-value shapes;
- `array.len`, `array.get`, and `array.set` over repeated-value `array.new`, including effectful repeated values and effectful set values;
- dynamic-index, dynamic-length, and negative/huge-length fail-closed boundary labels.

Still out of scope:

- OI-J descriptor/exactness/TNH/IIT behavior, which remains owned by `pass-oi-descriptor-gc` and the OI-J row;
- OI-L shared/atomic/RMW/cmpxchg aggregate behavior;
- broad randomized GC aggregate generation beyond this trigger-smoke profile;
- new OI-K optimizer behavior beyond the already implemented and bounded surfaces from `1434` through `1436`.

## Starshine change

`src/validate/gen_valid.mbt` adds `PassOiGcAggregateProfile` with public profile name `pass-oi-gc-aggregate` and aliases through the normalized profile lookup path. The profile configuration enables the required GC/reference/call/global surface and disables unrelated memory/table/atomics/v128/name-section surfaces so sampled modules stay focused on aggregate constructor/get/set traffic.

The trigger profile has fifteen deterministic seed-indexed cases. Seeds `0x5eed` through `0x5efb` map directly to cases `0` through `14`, and `gen_valid_oi_trigger_profile_case_label` records stable `profile_case_label` values:

1. `oi-gc-aggregate:struct-get-new-pure`
2. `oi-gc-aggregate:struct-get-new-effectful-sibling`
3. `oi-gc-aggregate:array-get-new-fixed-pure`
4. `oi-gc-aggregate:array-get-new-fixed-effectful-sibling`
5. `oi-gc-aggregate:array-set-new-fixed-effectful-value`
6. `oi-gc-aggregate:array-set-new-fixed-effectful-oob`
7. `oi-gc-aggregate:array-new-len-pure`
8. `oi-gc-aggregate:array-new-len-effectful`
9. `oi-gc-aggregate:array-get-new-effectful-repeated`
10. `oi-gc-aggregate:array-get-new-effectful-oob`
11. `oi-gc-aggregate:array-set-new-effectful-repeated`
12. `oi-gc-aggregate:array-set-new-effectful-repeated-and-value`
13. `oi-gc-aggregate:dynamic-index-boundary`
14. `oi-gc-aggregate:dynamic-length-boundary`
15. `oi-gc-aggregate:negative-huge-length-boundary`

`gen_valid_oi_gc_aggregate_profile_module` builds validating modules with:

- one exported `run` function;
- two helper functions returning `i32` while incrementing a mutable `i32` global, used as effectful aggregate operands;
- one two-field mutable `i32` struct type;
- one mutable `i32` array type;
- actual `struct.new`, `struct.get`, `array.new_fixed`, `array.new`, `array.len`, `array.get`, and `array.set` instructions in the sampled `run` body.

This gives future OI-K sweeps real aggregate opcodes instead of depending on `pass-oi-ref-gc`, whose closeout sample contained only OI-I-style non-descriptor reference labels and zero aggregate constructor/get/set opcodes.

## Tests and sweep planning

`src/validate/gen_valid_tests.mbt` adds focused profile tests that assert:

- `PassOiGcAggregateProfile` has the expected name and focused GC/ref/call/global configuration;
- `gen_valid_profile_by_name("pass oi gc aggregate")` resolves to the new profile;
- all fifteen seeds select the expected stable labels;
- each generated module validates through Starshine's validator;
- each generated module reports reference-type usage and contains real `struct.*` or `array.*` aggregate instructions;
- the dynamic-index, dynamic-length, and negative/huge-length labels have distinct static signatures.

`scripts/lib/oi-parity-sweep.test.ts` now locks the checked-in OI-K matrix row to the dedicated profile by asserting:

- `genValidProfiles` contains `pass-oi-gc-aggregate`;
- `sweep.profile` is `pass-oi-gc-aggregate`;
- `sweep.blockedUntilProfileExists` is `false`.

The grouped sweep planner already reads profile/count/seed data from the matrix, so changing the OI-K row in `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json` is the planning wire-up. The row now uses count `120`, seed `0x5eed`, and profile `pass-oi-gc-aggregate`; the older `.tmp/oi-k-closeout-count256-20260703` `pass-oi-ref-gc` run remains historical cross-family quarantine evidence only.

## Matrix and docs updates

`docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json` now records `pass-oi-gc-aggregate` as an implemented trigger-smoke-plus profile owned by OI-K. The OI-K row now points future generator-backed closeout/reopening sweeps at the dedicated profile and keeps the previous `pass-oi-ref-gc` sample in a historical quarantine bucket.

`docs/wiki/binaryen/passes/optimize-instructions/index.md`, `docs/wiki/log.md`, and `agent-todo.md` record the profile split and restate the ownership boundary:

- OI-K aggregate constructor/get/set surfaces use `pass-oi-gc-aggregate`;
- OI-J descriptor/exactness/TNH/IIT remains separate;
- OI-L shared/atomic/RMW/cmpxchg remains separate.

## Classification

The profile is a tooling/signoff improvement, not a new optimizer rewrite. OI-K remains closed for the known represented behavior surface after `1436`, with accepted boundaries for direct-Binaryen-vs-O4z cleanup nuances, dynamic/negative/huge allocation lengths, dynamic indexes, `array.fill` / `array.copy`, descriptor/exactness/TNH/IIT, and shared/atomic surfaces.

The new reopening criterion is concrete: a future OI-K run should use `pass-oi-gc-aggregate` and classify any aggregate-profile residual as one of:

- direct Binaryen `--optimize-instructions` vs O4z cleanup boundary;
- bounded Starshine cleanup extension;
- fail-closed allocation/index/effect/trap boundary;
- true validation/runtime/effect-order/trap regression;
- non-OI-K surface that belongs to OI-J or OI-L.

## Grouped raw mismatch classification

The grouped sweep `.tmp/oi-k-gc-aggregate-grouped-count120-20260703/oi-k/OI-K-gc-constructors-fields-arrays` compared all `120/120` planned cases with `110` normalized matches, `10` raw mismatches, and zero validation/property/generator/command failures. All raw mismatches came from the `oi-local-carried` transform and only from three pure aggregate labels:

- `oi-gc-aggregate:array-get-new-fixed-pure` (`4` mismatches);
- `oi-gc-aggregate:struct-get-new-pure` (`3` mismatches);
- `oi-gc-aggregate:array-new-len-pure` (`3` mismatches).

All effectful, dynamic-index, dynamic-length, negative/huge-length, set, and out-of-bounds labels normalized in this grouped run. Runtime execution was off for this sweep (`runtimeExecution: "off"`, matrix `not-run`), so runtime status is recorded as not present; static WAT inspection found no `call` in the exported `run` bodies, no `unreachable` in the Binaryen or Starshine outputs, and no `global.set` traffic in the rewritten aggregate roots. The only `global.set` instructions are in the unused helper functions that remain in both tools' outputs. The artifact metadata did not include WAT file byte counts, so WAT delta is recorded as text-shape direction and line-count direction rather than an exact byte count.

| Case directory | Label | Grouped transform | Aggregate opcodes | Binaryen raw/canonical wasm | Starshine raw/canonical wasm | WAT delta | Runtime/trap status | Classification |
|---|---|---|---|---:|---:|---|---|---|
| `case-000010-gen-valid-transform-oi-local-carried` | `array-get-new-fixed-pure` | `oi-local-carried` | Binaryen has `array.new_fixed=1`, `array.get=1`; Starshine has no `array.*` | `124 / 124` | `119 / 110` | Starshine shorter; about `-7` WAT lines | Not run; no exported-root call/global/trap traffic; in-bounds index | Accepted cleanup extension |
| `case-000049-gen-valid-transform-oi-local-carried` | `array-get-new-fixed-pure` | `oi-local-carried` | Binaryen has `array.new_fixed=1`, `array.get=1`; Starshine has no `array.*` | `124 / 124` | `119 / 110` | Starshine shorter; about `-7` WAT lines | Not run; no exported-root call/global/trap traffic; in-bounds index | Accepted cleanup extension |
| `case-000091-gen-valid-transform-oi-local-carried` | `array-get-new-fixed-pure` | `oi-local-carried` | Binaryen has `array.new_fixed=1`, `array.get=1`; Starshine has no `array.*` | `124 / 124` | `119 / 110` | Starshine shorter; about `-7` WAT lines | Not run; no exported-root call/global/trap traffic; in-bounds index | Accepted cleanup extension |
| `case-000103-gen-valid-transform-oi-local-carried` | `array-get-new-fixed-pure` | `oi-local-carried` | Binaryen has `array.new_fixed=1`, `array.get=1`; Starshine has no `array.*` | `124 / 124` | `119 / 110` | Starshine shorter; about `-7` WAT lines | Not run; no exported-root call/global/trap traffic; in-bounds index | Accepted cleanup extension |
| `case-000037-gen-valid-transform-oi-local-carried` | `struct-get-new-pure` | `oi-local-carried` | Binaryen has `struct.new=1`, `struct.get=1`; Starshine has no `struct.*` | `125 / 125` | `119 / 110` | Starshine shorter; about `-6` WAT lines | Not run; no exported-root call/global/trap traffic | Accepted cleanup extension |
| `case-000079-gen-valid-transform-oi-local-carried` | `struct-get-new-pure` | `oi-local-carried` | Binaryen has `struct.new=1`, `struct.get=1`; Starshine has no `struct.*` | `125 / 125` | `119 / 110` | Starshine shorter; about `-6` WAT lines | Not run; no exported-root call/global/trap traffic | Accepted cleanup extension |
| `case-000106-gen-valid-transform-oi-local-carried` | `struct-get-new-pure` | `oi-local-carried` | Binaryen has `struct.new=1`, `struct.get=1`; Starshine has no `struct.*` | `125 / 125` | `119 / 110` | Starshine shorter; about `-6` WAT lines | Not run; no exported-root call/global/trap traffic | Accepted cleanup extension |
| `case-000058-gen-valid-transform-oi-local-carried` | `array-new-len-pure` | `oi-local-carried` | Binaryen has `array.new=1`, `array.len=1`; Starshine has no `array.*` | `120 / 120` | `119 / 110` | Starshine shorter; about `-6` WAT lines | Not run; no exported-root call/global/trap traffic; constant non-negative length | Accepted cleanup extension |
| `case-000061-gen-valid-transform-oi-local-carried` | `array-new-len-pure` | `oi-local-carried` | Binaryen has `array.new=1`, `array.len=1`; Starshine has no `array.*` | `120 / 120` | `119 / 110` | Starshine shorter; about `-6` WAT lines | Not run; no exported-root call/global/trap traffic; constant non-negative length | Accepted cleanup extension |
| `case-000115-gen-valid-transform-oi-local-carried` | `array-new-len-pure` | `oi-local-carried` | Binaryen has `array.new=1`, `array.len=1`; Starshine has no `array.*` | `120 / 120` | `119 / 110` | Starshine shorter; about `-6` WAT lines | Not run; no exported-root call/global/trap traffic; constant non-negative length | Accepted cleanup extension |

Opcode/traffic summary for the ten mismatches:

- Binaryen residuals have aggregate traffic only in the pure selected root: `struct.new/get` for the three struct cases, `array.new_fixed/get` for the four fixed-array cases, and `array.new/len` for the three repeated-array cases.
- Starshine replaces the selected pure aggregate result with the selected constant (`10`, `6`, or `3`) and drops it, leaving zero `struct.*` and zero `array.*` opcodes in each Starshine output.
- `drop`, `local.get`, `local.set`, and helper `global.set` traffic is otherwise representation-stable for the local-carried wrapper and unused helper functions. There are no `call`, `array.set`, `struct.new_default`, `array.new_default`, `array.get_s`, `array.get_u`, `struct.get_s`, `struct.get_u`, or `unreachable` opcodes in the residual outputs.

These ten residuals are not true OI-K bugs. Starshine removes one-use pure aggregate constructor/get/len shapes that direct Binaryen preserves in the grouped local-carried spelling, and does so with non-larger raw/canonical wasm while preserving the local-carried wrapper's observable traffic. There is no evidence of effect duplication, effect loss, trap loss, dynamic-index speculation, dynamic/negative/huge-length folding, descriptor/exactness/TNH/IIT, or shared/atomic/RMW/cmpxchg. OI-K therefore stays accepted/closed for the represented aggregate surface, with `pass-oi-gc-aggregate` as the reopening/signoff profile.

A final requested rerun after classification used `.tmp/oi-k-gc-aggregate-profile-final-count120` with the native release Starshine binary and Node runtime execution. It reproduced the same compare shape (`120/120` compared, `110` normalized, `10` raw mismatches, zero validation/property/generator/command failures) and strengthened the semantic evidence with runtime execution: `checked=120`, `unsupported=0`, `failed=0`, matrix `all-equal`, `equalResults=104`, `equalTraps=16`, `semanticMismatches=0`. Binaryen cache was `120/0`. Manual `wasm-tools validate --features all` accepted all `40` final residual raw/canonical artifacts (`binaryen.raw.wasm`, `starshine.raw.wasm`, `binaryen.wasm`, `starshine.wasm` for each mismatch directory).

## Focused signoff status

Code, test, matrix, wiki, log, todo, and this research note were prepared in this slice. Focused signoff was run after implementation:

```sh
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/tmp/parity-matrix.json.check
moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt --filter '*pass-oi-gc-aggregate*'
moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt --filter '*pass-targeted gen-valid profiles expose stable pass recipes*'
bun test scripts/lib/oi-parity-sweep.test.ts
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 120 --seed 0x5eed --pass optimize-instructions --gen-valid-profile pass-oi-gc-aggregate --out-dir .tmp/oi-k-gc-aggregate-count120-20260703 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
bun scripts/oi-parity-sweep.ts --family OI-K --out-dir .tmp/oi-k-gc-aggregate-grouped-count120-20260703 --execute --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
moon fmt
git diff --check
git diff --cached --check
moon info
```

Results:

- JSON validation passed.
- Focused `*pass-oi-gc-aggregate*` GenValid tests passed `2/2`.
- Focused pass-profile registry test passed `1/1`.
- `bun test scripts/lib/oi-parity-sweep.test.ts` passed `9/9` with the OI-K dedicated-profile matrix assertion green.
- Full `moon test` passed `7329/7329`; it reported pre-existing warnings in `src/binary/decode.mbt`, `src/binary/encode.mbt`, and `src/ir/hot_verify.mbt`.
- Native `src/cmd` release build passed; it reported pre-existing warnings in `src/binary/*`, `src/ir/hot_verify.mbt`, and `src/passes/pass_manager.mbt`.
- Direct profile smoke `.tmp/oi-k-gc-aggregate-count120-20260703` stopped at the compare-pass max-failure cap after `49/120` compared cases: `21` normalized matches, `28` raw mismatches, `0` validation/property/generator/command failures, Binaryen cache `25/24`. The mismatches are expected raw-shape evidence for this accepted-boundary profile, not test failures.
- Executed grouped OI-K sweep `.tmp/oi-k-gc-aggregate-grouped-count120-20260703/oi-k/OI-K-gc-constructors-fields-arrays` compared `120/120`: `110` normalized matches, `10` raw mismatches, `0` validation/property/generator/command failures, Binaryen cache `79/41`, runtime not run. All fifteen `pass-oi-gc-aggregate` labels sampled. Raw mismatches were limited to `struct-get-new-pure` (`3`), `array-get-new-fixed-pure` (`4`), and `array-new-len-pure` (`3`); all effectful, dynamic, negative/huge, and set labels matched in this grouped sweep.
- `moon fmt`, `git diff --check`, and `git diff --cached --check` passed.
- `moon info` passed with pre-existing warnings in `src/binary/*`, `src/ir/hot_verify.mbt`, `src/validate/gen_valid.mbt`, and `src/validate/gen_valid_ssa.mbt`.
