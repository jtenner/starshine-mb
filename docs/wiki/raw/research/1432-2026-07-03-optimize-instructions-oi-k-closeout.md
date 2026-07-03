# Optimize-instructions OI-K GC aggregate closeout refresh

Date: 2026-07-03

## Question

Can OI-K, the GC aggregate constructor/get/set/default/ordering surface, move out of active full-parity work, or should it stay active with a finite residual list?

## Pre-flight

The OI-G and OI-I docs/matrix prerequisites were validated and committed before this slice continued:

- commit `299b3e1ec docs: record OI-G and OI-I closeout refreshes` contains `1430` and `1431` plus the matrix/index/log/todo updates;
- `moon build --target native --release src/cmd` passed/no work to do before the OI-I refresh;
- OI-I fresh count256 `.tmp/oi-i-closeout-count256-20260703` compared `256/256`, with zero validation/generator/property/command failures;
- OI-G summarize-existing confirmed `.tmp/oi-g-closeout-count980-20260703` at `980/980` normalized with zero raw mismatches/failures;
- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/tmp/parity.json`, `git diff --check`, and `git diff --cached --check` passed before commit.

OI-M reopening criteria did not fire. OI-J descriptor/exactness/TNH/IIT work was not attempted and is not closed by this note.

## Current OI-K row before update

Before this refresh, `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json` had:

- row id: `OI-K-gc-constructors-fields-arrays`;
- `starshineStatus`: `mismatch`;
- `priority`: `P2`;
- `closeoutState`: `parity-gap`;
- `genValidProfiles`: `pass-oi-ref-gc`;
- `metamorphicTransforms`: `oi-local-carried`, `oi-effectful-sibling`, `oi-trapping-sibling`;
- `sweep.enabled`: `true`, but pointed at the non-dedicated `pass-oi-ref-gc` profile.

The row already listed source/test-backed represented subsets and broad remaining work. This refresh narrows that broad text by separating implemented OI-K behavior, Binaryen no-rewrite boundaries, fail-closed allocation/index/value boundaries, OI-J/OI-L quarantines, and true source-backed effect-localization gaps.

## Implemented or bounded OI-K sub-surfaces

Implemented and focused-test covered:

- `struct.get(struct.new(...))` for direct one-use matching constructors when non-selected fields are pure (`0823`);
- packed `struct.get_s` / `struct.get_u(struct.new(...))`, preserving signedness via constants, sign-extension, or masks (`0824`);
- `struct.get(struct.new_default(...))` and packed default gets for defaultable non-descriptor fields (`0828`);
- `array.len(array.new_fixed(...))` for pure fixed elements (`0825`);
- constant-index `array.get(array.new_fixed(...))`, including pure out-of-bounds to `unreachable` (`0826`);
- packed `array.get_s` / `array.get_u(array.new_fixed(...))` with signedness preservation (`0827`);
- constant-length/index `array.get(array.new_default(...))`, including packed default gets and pure out-of-bounds (`0829`);
- small non-negative constant-length `array.len(array.new_default(...))` (`0830`);
- small constant repeated-value `array.len(array.new(...))` (`0831`);
- constant-index `array.get(array.new(...))` repeated-value forwarding, including effectful selected values and pure out-of-bounds (`0832`);
- pure constant-index `array.set` removal on fresh `array.new_fixed`, `array.new_default`, and `array.new` arrays, with pure out-of-bounds writes to `unreachable` (`0833`, `0835`).

Source-backed no-rewrite or no-OI-gap boundaries:

- `array.fill` and `array.copy` over fresh arrays are not Binaryen `optimize-instructions` rewrites in direct or O4z-style probes; keeping them is OI parity, not a Starshine gap (`0836`).

Fail-closed correctness boundaries:

- negative and huge `array.new_default` lengths must not be folded because doing so can erase allocation traps (`1319`);
- negative/huge `array.new` lengths follow the same non-trapping length guard (`0831`, `0832`, `0835`);
- dynamic lengths and dynamic indexes remain unchanged because allocation and bounds traps cannot be locally proven away;
- effectful repeated values, effectful set values, and effectful non-selected fixed elements/fields are not duplicated or dropped by Starshine.

Quarantined or non-OI-K surfaces:

- descriptor-bearing `struct.new_default_desc`, descriptor array/default operands, exactness, TNH, and IIT belong to OI-J;
- shared/atomic aggregate RMW/cmpxchg belongs to OI-L until representation/parser/lowering support is complete;
- multi-use aggregate scalarization remains fail-closed unless a future Binaryen source/probe proves the exact one-use/multi-use rewrite and Starshine has safe use-count/effect localization.

## Fresh grouped evidence

Command:

```sh
rm -rf .tmp/oi-k-closeout-count256-20260703
bun scripts/oi-parity-sweep.ts --family OI-K --count 256 \
  --out-dir .tmp/oi-k-closeout-count256-20260703 \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --execute -- --runtime-execution node \
  --max-failures 2000 --keep-going-after-command-failures
bun scripts/oi-parity-sweep.ts --family OI-K \
  --out-dir .tmp/oi-k-closeout-count256-20260703 \
  --summarize-existing
```

Result for `OI-K-gc-constructors-fields-arrays`:

- requested/compared: `256/256`
- normalized matches: `113`
- cleanup-normalized matches: `0`
- raw mismatches: `143`
- validation failures: `0`
- generator failures: `0`
- property failures: `0`
- command failures: `0`
- Binaryen cache: `256/0`; Binaryen failures `0/0`; wasm-smith `0/0`
- runtime execution: checked `256`, unsupported `0`, failed `0`; runtime matrix outcome was empty with total `0`, equal results `0`, equal traps `0`, semantic mismatches `0`
- selected profile: `pass-oi-ref-gc=256`
- profile labels: `oi-ref-gc:branch-cast-boundaries=77`, `oi-ref-gc:direct-null-test-cast-eq=91`, `oi-ref-gc:local-carried-null-test-cast=88`
- case-label statuses: branch-cast `25` match / `52` mismatch; direct-null/test/cast `91` mismatch; local-carried known-null `88` match
- failure dirs: `143`

Tooling classification: the OI-K family sweep is mechanically supported, but the row still uses the non-dedicated `pass-oi-ref-gc` profile. The fresh count256 lane did not generate sampled GC aggregate constructor/get/set residuals. Its residuals are OI-I reference/null/cast traffic already classified by `1431`; they are not OI-K evidence and must not be used to close OI-J.

## Residual validation and opcode/traffic inspection

Manual validation accepted all `572` residual raw/canonical artifacts from the count256 OI-K-family failure dirs:

```sh
find .tmp/oi-k-closeout-count256-20260703/oi-k/OI-K-gc-constructors-fields-arrays/failures \
  -type f \( -name 'binaryen.raw.wasm' -o -name 'starshine.raw.wasm' \
  -o -name 'binaryen.wasm' -o -name 'starshine.wasm' \) \
  -print0 | xargs -0 -n1 -P 16 wasm-tools validate --features all
```

Aggregate OI-K opcode grep across all residual `binaryen.wat` and `starshine.wat` files found zero occurrences of:

- `struct.new`
- `struct.new_default`
- `struct.get`
- `struct.get_s`
- `struct.get_u`
- `array.new_fixed`
- `array.new_default`
- `array.new`
- `array.len`
- `array.get`
- `array.get_s`
- `array.get_u`
- `array.set`

Residual aggregate buckets, therefore all non-OI-K:

| label / transform | n | Starshine raw/canonical/WAT delta | matched traffic |
| --- | ---: | ---: | --- |
| `oi-ref-gc:branch-cast-boundaries` / `oi-effectful-sibling` | 30 | `-120 / 0 / -120` | `drop 210/210`, `global.set 150/150`, `unreachable 30/30` |
| `oi-ref-gc:branch-cast-boundaries` / `oi-trapping-sibling` | 22 | `-88 / 0 / -88` | `drop 176/176`, `unreachable 22/22` |
| `oi-ref-gc:direct-null-test-cast-eq` / `oi-effectful-sibling` | 30 | `-180 / -180 / -1860` | `drop 300/240`, `global.set 150/150`, `unreachable 30/30` |
| `oi-ref-gc:direct-null-test-cast-eq` / `oi-local-carried` | 30 | `0 / -240 / -3300` | `local.get 30/30`, `local.set 30/30`, `drop 240/180`, `unreachable 30/30` |
| `oi-ref-gc:direct-null-test-cast-eq` / `oi-trapping-sibling` | 31 | `-186 / -186 / -1922` | `drop 341/279`, `unreachable 31/31` |

The requested OI-K traffic list (`struct.new`, `struct.new_default`, `struct.get`, `struct.get_s`, `struct.get_u`, `array.new_fixed`, `array.new_default`, `array.new`, `array.len`, `array.get`, `array.get_s`, `array.get_u`, `array.set`, `call`) is absent from the residual WAT except for generic non-GC traffic already shown above (`drop`, `local.get`, `local.set`, `global.set`, `unreachable`).

## Representative inspection

Grouped representatives from the fresh count256 OI-K-family sweep are cross-family OI-I, not OI-K:

- `.tmp/oi-k-closeout-count256-20260703/oi-k/OI-K-gc-constructors-fields-arrays/failures/case-000002-gen-valid-transform-oi-effectful-sibling` is `oi-ref-gc:direct-null-test-cast-eq` under `oi-effectful-sibling`; both tools preserve the private-global prefix and final trap tail, while Starshine removes more dropped null/reference debris.
- `.tmp/oi-k-closeout-count256-20260703/oi-k/OI-K-gc-constructors-fields-arrays/failures/case-000008-gen-valid-transform-oi-effectful-sibling` is `oi-ref-gc:branch-cast-boundaries` under `oi-effectful-sibling`; both tools preserve branch/effect/trap traffic, with result-type spelling drift.
- `.tmp/oi-k-closeout-count256-20260703/oi-k/OI-K-gc-constructors-fields-arrays/failures/case-000009-gen-valid-transform-oi-trapping-sibling` is an OI-I branch-cast/trapping-sibling residual with no aggregate constructor/get/set opcodes.

Direct OI-K behavior evidence remains the focused Binaryen probes and red-first tests from notes `0823` through `0836` and `1319`; this grouped lane did not provide direct GC aggregate residual dirs to classify.

## Classification

This slice materially narrows OI-K but does not claim full Binaryen behavior parity.

Current sampled GC aggregate residuals: none. The fresh count256 OI-K-family lane sampled only `pass-oi-ref-gc` OI-I labels and produced zero residual `struct.*` / `array.*` constructor/get/set opcodes.

Covered or bounded OI-K surface:

- represented pure/default one-use constructor forwarding and set-removal subsets are implemented and focused-test covered;
- `array.fill` / `array.copy` is a source-backed Binaryen no-rewrite boundary;
- negative/huge/dynamic length and dynamic index surfaces are fail-closed allocation/bounds-trap boundaries;
- descriptor/exactness/TNH/IIT is quarantined to OI-J;
- shared/atomic aggregate operations are quarantined to OI-L.

True remaining OI-K behavior gaps:

- source-backed effect localization for effectful non-selected `struct.new` fields and `array.new_fixed` elements where Binaryen preserves dropped sibling effects before forwarding the selected value;
- source-backed effect localization for effectful `array.set` values or effectful repeated-value operands where Binaryen lowers to `drop(effect); nop` or `drop(effect); unreachable` under proven in-bounds/out-of-bounds conditions;
- any future dedicated OI-K generator/profile residual that contains actual `struct.*` or `array.*` constructor/get/set opcodes and is not one of the covered/bounded/quarantined buckets above.

Because those effect-localization gaps are real source-backed Binaryen behavior and not merely output drift, this note keeps OI-K active but narrows the row to exact remaining work instead of broad GC aggregate parity.

## Next work / reopening criteria

Do not add endless GC breadth by default. The next high-leverage OI-K work should be one of:

1. add a small dedicated `pass-oi-gc-aggregate` trigger profile that samples the already-covered pure/default OI-K shapes plus one explicit effect-localization candidate, then classify only actual aggregate residuals; or
2. implement one source-backed effect-localization shape red-first, preserving non-selected effects/traps and allocation/bounds traps exactly; or
3. if product scope accepts the effect-localization gap as a release boundary, explicitly approve moving OI-K to `intentional-boundary` with that boundary named.

Keep OI-K active/reopen for:

- validation failure or runtime semantic mismatch in an OI-K aggregate output;
- any residual containing `struct.new`, `struct.new_default`, `struct.get`, `struct.get_s`, `struct.get_u`, `array.new_fixed`, `array.new_default`, `array.new`, `array.len`, `array.get`, `array.get_s`, `array.get_u`, or `array.set` that is not already implemented, a Binaryen no-rewrite boundary, a trap-preserving fail-closed boundary, OI-J, or OI-L;
- lost/reordered non-selected field/element effects or traps;
- packed signedness/masking drift;
- dropped allocation traps for dynamic, negative, or huge lengths;
- dynamic index speculation;
- raw/canonical Starshine size loss in an implemented subset without a documented win;
- descriptor/exactness/TNH/IIT evidence, which must be filed under OI-J rather than OI-K.

## Validation for this note

Commands run in this slice:

- `bun scripts/oi-parity-sweep.ts --family OI-K --count 256 --out-dir .tmp/oi-k-closeout-count256-20260703 --starshine-bin target/native/release/build/cmd/cmd.exe --execute -- --runtime-execution node --max-failures 2000 --keep-going-after-command-failures`
- `bun scripts/oi-parity-sweep.ts --family OI-K --out-dir .tmp/oi-k-closeout-count256-20260703 --summarize-existing`
- `wasm-tools validate --features all` over all `572` residual raw/canonical artifacts from the count256 OI-K-family sweep

Repository validation for the docs/matrix update:

- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/tmp/parity.json`
- `git diff --check`
- `git diff --cached --check` (run before staging, with no staged diff)

No optimizer source or tests changed in this slice.
