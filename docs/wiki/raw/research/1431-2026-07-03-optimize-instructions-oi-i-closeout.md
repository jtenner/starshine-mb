# Optimize-instructions OI-I closeout refresh

## Question

Can the non-descriptor OI-I reference equality/null/test/cast surface move out of active v0.1 full-parity work without using OI-I evidence to close descriptor/exactness/TNH/IIT OI-J?

## Scope

In scope:

- `ref.eq`
- `ref.is_null`
- `ref.as_non_null`
- non-descriptor `ref.test`
- non-descriptor `ref.cast`

Out of scope and quarantined to OI-J:

- descriptor casts and `ref.get_desc`
- exactness beyond already-covered OI-J exact-cast guards
- TNH / IIT mode behavior
- branch-on-cast descriptor localization
- descriptor generator/tooling fixes

## Classification

OI-I is a finite accepted non-descriptor boundary for v0.1 closeout, not an active full-parity release blocker.

All currently sampled non-descriptor OI-I residuals in the latest reliable grouped lane are classified:

1. covered by focused tests and normalized grouped evidence;
2. measured Starshine-win or canonical-neutral representation boundaries; or
3. explicitly quarantined when the topic is descriptor/exactness/TNH/IIT and therefore OI-J.

No new behavior implementation was added in this slice. I did not identify a narrow true gap from the existing sampled residuals: the residuals are dropped-null-test/drop-debris representation differences or branch-cast result-type spelling differences with preserved control/effect/trap traffic and no validation/property/command failures in the recorded lane.

## Evidence refresh status

The requested fresh command was run after shell access became available:

```sh
moon build --target native --release src/cmd
rm -rf .tmp/oi-i-closeout-count256-20260703
bun scripts/oi-parity-sweep.ts --family OI-I --count 256 \
  --out-dir .tmp/oi-i-closeout-count256-20260703 \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --execute -- --runtime-execution node \
  --max-failures 2000 --keep-going-after-command-failures
bun scripts/oi-parity-sweep.ts --family OI-I \
  --out-dir .tmp/oi-i-closeout-count256-20260703 \
  --summarize-existing
```

This note refreshes and closes the classification using:

- fresh `.tmp/oi-i-closeout-count256-20260703/oi-i/OI-I-ref-null-cast-basics/result.json` and `summary.json`;
- the prior reliable grouped lane `.tmp/oi-i-ref-gc-count45-20260630/oi-i/OI-I-ref-null-cast-basics/result.json` and `summary.json`;
- direct no-transform triage `.tmp/oi-ref-gc-direct-no-transform-triage-20260627/result.json`;
- representative direct and grouped failure WAT/metadata under those directories;
- OI-I source-backed notes `0757` through `0814`;
- OI-J notes only for quarantine boundaries.

## Current OI-I row snapshot before update

Before this refresh, `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json` had:

- row id: `OI-I-ref-null-cast-basics`
- status: `mismatch`
- priority: `P1`
- closeout state: `parity-gap`
- last reliable grouped evidence: `.tmp/oi-i-ref-gc-count45-20260630`
- remaining work wording: active full-parity behavior work remained
- blocker/quarantine text: non-descriptor evidence must not close OI-J

This was internally inconsistent with the row's own classified buckets, which already accepted the sampled residuals for v0.1 and kept OI-J quarantined. This slice resolves that inconsistency by moving OI-I out of active/full-parity release work with explicit reopening criteria.

## Source-backed implemented OI-I surface

Notes `0757` through `0814` cover the implemented non-descriptor reference basics:

- `ref.is_null(ref.null)` to `i32.const 1`;
- null-operand `ref.eq` to `ref.is_null`, and null/null equality to `i32.const 1`;
- known-non-null `ref.i31`, `ref.func`, and declared non-null local null tests/equality to `i32.const 0`;
- `ref.as_non_null(ref.null)` to `unreachable` and `ref.as_non_null` removal for local known-non-null `i31`, `func`, and declared non-null local refs;
- nullable and non-null null-operand `ref.test` / `ref.cast` results, including non-null null-cast to `unreachable`;
- successful local `i31` `ref.test` / `ref.cast` for `i31`, `eq`, and `any` targets;
- successful local `ref.func` `ref.test` / `ref.cast` for exact `func` targets;
- literal `ref.i31(i32.const)` equality;
- same-local `ref.eq(local.get N, local.get N)` and same-local `ref.i31(local.get N)` equality;
- same-local equality through nullable no-op/upcast `ref.cast` and nullable `ref.as_non_null`, preserving the required null trap;
- impossible equality/test/cast subsets for absolute and indexed i31/struct/array local heaps;
- effectful prefix preservation for known-null, known-non-null, successful, failed, same-local, and impossible equality/test/cast/as_non_null subsets.

These notes deliberately reserve descriptor, exactness, TNH, and IIT behavior for OI-J.

## Fresh grouped count256 lane

`result.json` for `.tmp/oi-i-closeout-count256-20260703/oi-i/OI-I-ref-null-cast-basics` records:

- requested: `256`
- compared: `256`
- normalized matches: `131`
- cleanup-normalized matches: `0`
- raw mismatches: `125`
- validation failures: `0`
- generator failures: `0`
- property failures: `0`
- command failures: `0`
- Binaryen cache: `256` hits / `0` misses
- runtime execution: requested `node`; checked `256`, unsupported `0`, failed `0`; runtime matrix was empty because the profile exposes no executable runtime samples
- selected profile: `pass-oi-ref-gc`
- profile labels: `branch-cast-boundaries=77`, `direct-null-test-cast-eq=91`, `local-carried-null-test-cast=88`

Per-label classification from the same lane:

- `oi-ref-gc:local-carried-null-test-cast`: `88/88` normalized matches after known-null local cleanup.
- `oi-ref-gc:direct-null-test-cast-eq`: `91/91` residuals, still the measured Starshine-win dropped-debris boundary.
- `oi-ref-gc:branch-cast-boundaries`: `43/77` normalized matches and `34/77` residuals, still canonical-neutral/raw-smaller branch-cast result-type spelling drift with preserved branch/effect/trap traffic.

Manual validation accepted all `500` residual raw/canonical artifacts from the count256 failure dirs with `wasm-tools validate --features all`.

Aggregate residual measurements from count256:

- `direct-null-test-cast-eq + oi-effectful-sibling`: `51` residuals, raw/canonical/WAT deltas `-306/-306/-3162` for Starshine; `ref.is_null 102/102`, `global.set 255/255`, `drop 510/408`, `unreachable 51/51`, `i32.const 714/714`.
- `direct-null-test-cast-eq + oi-local-carried`: `40` residuals, raw/canonical/WAT deltas `0/-320/-4400` for Starshine; `ref.is_null 80/0`, `local.set 40/40`, `local.get 40/40`, `drop 320/240`, `unreachable 40/40`, `i32.const 160/240`.
- `branch-cast-boundaries + oi-effectful-sibling`: `34` residuals, raw/canonical/WAT deltas `-136/0/-136` for Starshine; `br_on_cast 136/136`, `br_on_cast_fail 68/68`, `global.set 170/170`, `drop 238/238`, `unreachable 34/34`, `i32.const 408/408`.

Runtime-green evidence is not the classification basis here because the runtime matrix had no executable samples. The classification rests on validation, representative WAT inspection, opcode/traffic preservation, and measured size/opcode aggregates.

## Prior reliable grouped lane

`result.json` for `.tmp/oi-i-ref-gc-count45-20260630/oi-i/OI-I-ref-null-cast-basics` records:

- requested: `45`
- compared: `45`
- normalized matches: `23`
- cleanup-normalized matches: `0`
- raw mismatches: `22`
- validation failures: `0`
- generator failures: `0`
- property failures: `0`
- command failures: `0`
- Binaryen cache: `45` hits / `0` misses
- runtime execution: `off`
- runtime checked / unsupported / failed: `0 / 0 / 0`
- selected profile: `pass-oi-ref-gc`
- transforms: `oi-local-carried=23`, `oi-effectful-sibling=22`
- profile labels: `branch-cast-boundaries=12`, `direct-null-test-cast-eq=15`, `local-carried-null-test-cast=18`

Per-label classification from the same lane:

- `oi-ref-gc:local-carried-null-test-cast`: `18/18` normalized matches after the known-null local cleanup.
- `oi-ref-gc:direct-null-test-cast-eq`: `15/15` residuals, measured Starshine-win representation boundary.
- `oi-ref-gc:branch-cast-boundaries`: `5/12` normalized matches and `7/12` residuals; residuals are canonical-neutral/raw-smaller branch-cast result-type spelling drift with preserved branch/effect/trap traffic.

This prior count45 lane is superseded as the latest grouped count by the count256 lane above, but it remains useful because its representative WAT files were already inspected in detail and show the same residual families.

## Representative direct residual

Direct no-transform lane `.tmp/oi-ref-gc-direct-no-transform-triage-20260627` records:

- requested: `3`
- compared: `3`
- normalized matches: `2`
- raw mismatches: `1`
- validation/generator/property/command failures: `0`
- Binaryen cache: `0` hits / `3` misses
- runtime: not run
- residual label: `oi-ref-gc:direct-null-test-cast-eq`

Representative `case-000002-gen-valid` has no transform and preserves the trap tail. Binaryen leaves more dropped null-test/null debris:

- Binaryen WAT includes two dropped `ref.is_null(ref.null none)`, multiple dropped `ref.null none`, dropped constants, and `unreachable`.
- Starshine folds the dropped null tests to dropped constants, removes extra dropped null debris, preserves the final `unreachable`, and keeps no effectful traffic because the direct representative has no effects.

Previously recorded size evidence for this direct residual: raw size ties at `48` bytes while canonical size improves to Starshine `40` vs Binaryen `48` bytes.

## Representative grouped direct-null/test/cast residual

Grouped representative `.tmp/oi-i-ref-gc-count45-20260630/.../case-000002-gen-valid-transform-oi-effectful-sibling` records:

- label: `oi-ref-gc:direct-null-test-cast-eq`
- transform: `oi-effectful-sibling`
- input facts: mutates global, may trap
- validation/generator/property/command failures: none in the lane

Inspection:

- both tools preserve the ordered `global.set` prefix traffic (`101`, if-result `102/103`, `104`, block-side `105`, `106`);
- Binaryen keeps two dropped `ref.is_null(ref.null none)` plus several dropped `ref.null none` / constant nodes before `unreachable`;
- Starshine keeps the same effect prefix and final `unreachable` while removing extra dropped null/reference debris and folding to fewer dropped constants/nulls.

Aggregate row evidence for all direct-null/test/cast residuals:

- residuals: `15`
- raw/canonical/WAT deltas: `-42 / -106 / -1314` for Starshine
- `ref.is_null`: Binaryen/Starshine `30 / 14`
- `global.set`: `35 / 35`
- `local.get`: `8 / 8`
- `drop`: `134 / 104`
- `unreachable`: `15 / 15`
- `i32.const`: `130 / 146`

Classification: measured Starshine-win representation boundary. Effects, local traffic, and trap tail are preserved while Starshine removes more dead null-test/drop debris.

## Representative grouped branch-cast residual

Grouped representative `.tmp/oi-i-ref-gc-count45-20260630/.../case-000008-gen-valid-transform-oi-effectful-sibling` records:

- label: `oi-ref-gc:branch-cast-boundaries`
- transform: `oi-effectful-sibling`
- input facts: mutates global, has exception, has unreachable, may trap
- validation/generator/property/command failures: none in the lane

Inspection:

- both tools preserve the same `global.set` and dropped condition/effect prefix;
- both tools keep four branch-cast blocks:
  - two `br_on_cast`
  - two `br_on_cast_fail`
- both tools preserve the final `unreachable`;
- the visible drift is block result spelling: Binaryen prints `result nullref`, Starshine prints `result anyref` for those dropped blocks.

Aggregate row evidence for branch-cast residuals:

- residuals: `7`
- raw/canonical/WAT deltas: `-28 / 0 / -28` for Starshine
- `br_on_cast`: `28 / 28`
- `br_on_cast_fail`: `14 / 14`
- `global.set`: `35 / 35`
- `drop`: `49 / 49`
- `unreachable`: `7 / 7`
- `i32.const`: `84 / 84`

Classification: accepted non-descriptor representation boundary. It is canonical-neutral, raw/WAT-smaller for Starshine, and preserves branch/control/effect/trap opcode traffic.

## OI-J quarantine

The OI-I evidence above must not be used to close OI-J.

Reasons:

- `pass-oi-ref-gc` is deliberately non-descriptor after earlier descriptor-bearing grouped attempts produced generator/toolchain failures.
- The comparable OI-I lanes do not exercise `ref.get_desc`, official descriptor casts, `ref.test_desc`, exactness breadth, TNH, or IIT.
- OI-J has its own row, profile, evidence, and blockers for descriptor/exactness/TNH/IIT surfaces.

Any future residual involving descriptor operands, exact type result requirements, TNH/IIT skip behavior, `ref.get_desc`, or descriptor branch localization belongs to OI-J, not OI-I.

## Decision

Move OI-I out of active/full-parity v0.1 work as an accepted intentional non-descriptor boundary.

Current sampled non-descriptor residuals are classified:

- implemented and covered: notes `0757` through `0814`, plus local-carried known-null grouped matches;
- source-backed / tested no-rewrite or no-broaden boundaries: descriptor/exactness/TNH/IIT quarantined to OI-J;
- measured Starshine-win representation boundary: direct-null/test/cast residuals;
- measured canonical-neutral/raw-smaller representation boundary: branch-cast effectful-wrapper residuals.

## Reopening criteria

Reopen OI-I only if a fresh non-descriptor OI-I lane or source probe shows one of:

- validation failure in a Starshine output;
- runtime semantic mismatch or unequal trap behavior;
- lost or reordered `global.set`, `call`, local traffic, branch-cast, drop, or `unreachable` behavior;
- raw or canonical Starshine size loss in a sampled residual without a documented semantic/size win;
- a new non-descriptor OI-I label/residual outside the currently classified direct-null/test/cast, local-carried known-null, and branch-cast-boundary buckets;
- source-backed non-descriptor behavior that is small, implementable, and not descriptor/exactness/TNH/IIT.

Do not reopen OI-I for descriptor/exactness/TNH/IIT evidence; file that under OI-J.

## Validation run for this closeout note

After shell access became available, the following validation/evidence commands ran successfully before commit:

- `moon build --target native --release src/cmd`
- `bun scripts/oi-parity-sweep.ts --family OI-I --count 256 --out-dir .tmp/oi-i-closeout-count256-20260703 --starshine-bin target/native/release/build/cmd/cmd.exe --execute -- --runtime-execution node --max-failures 2000 --keep-going-after-command-failures`
- `bun scripts/oi-parity-sweep.ts --family OI-I --out-dir .tmp/oi-i-closeout-count256-20260703 --summarize-existing`
- `wasm-tools validate --features all` over all `500` count256 residual Binaryen/Starshine raw/canonical artifacts

Repository validation and commit-level checks are recorded in the commit message for the OI-G/OI-I docs commit.
