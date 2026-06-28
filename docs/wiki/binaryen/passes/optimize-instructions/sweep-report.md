---
kind: workflow
status: working
last_reviewed: 2026-06-27
sources:
  - ./parity-matrix.json
  - ./fuzzing.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../raw/research/0726-2026-06-19-optimize-instructions-o4z-behavior-inventory.md
  - ../../../../../scripts/oi-parity-sweep.ts
  - ../../../../../scripts/lib/oi-parity-sweep.ts
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ../../../tooling/pass-fuzz-compare.md
---

# OptimizeInstructions parity sweep workflow

## Purpose

`optimize-instructions` parity work should now start from the family matrix in
[`parity-matrix.json`](./parity-matrix.json), not from a single hand-picked WAT
probe. The matrix is the durable inventory for OI-D through OI-M behavior
families and records:

- row id and family;
- upstream owner / lit source;
- feature requirements;
- Binaryen oracle mode;
- current Starshine status;
- priority;
- blocker or boundary reason; and
- last checked evidence.

The goal is to make future work sweep a behavior family, classify the row, and
then implement infrastructure that closes many rows at once.

## Status vocabulary

Use only the matrix vocabulary so grouped reports remain machine-readable:

| Status | Meaning |
| --- | --- |
| `covered` | Starshine behavior is implemented and has direct evidence for this row. |
| `mismatch` | Binaryen behavior is known or expected to differ; fix or classify with replay evidence. |
| `intentional-boundary` | Starshine intentionally keeps a narrower behavior for a documented reason plus reopening condition. |
| `blocked-surface` | Local representation, flags, parser support, or generator support is missing. |
| `unsafe-gap` | A potential correctness, validation, trap, or effect-order hazard outranks representation parity. |
| `starshine-win-candidate` | Starshine may differ in a beneficial way, but only after size/perf/semantic evidence is recorded. |

A mismatch is not automatically safe just because both outputs validate or
Starshine prints fewer instructions. Classify with a replayed transform contract,
measured size/perf/downstream delta, or precise semantic argument.

## Runner

Use [`../../../../../scripts/oi-parity-sweep.ts`](../../../../../scripts/oi-parity-sweep.ts)
as the grouped wrapper over `scripts/pass-fuzz-compare.ts`.

Dry-run the high-priority rows:

```sh
bun scripts/oi-parity-sweep.ts --priority P0
```

Dry-run one family using its pass-specific smoke profile:

```sh
bun scripts/oi-parity-sweep.ts --family OI-G
```

Run the same family against the default GenValid generator when you intentionally
want a baseline lane independent of the dedicated profile:

```sh
moon build --target native --release src/cmd
bun scripts/oi-parity-sweep.ts \
  --family OI-G \
  --default-gen-valid \
  --execute \
  --count 100 \
  --out-dir .tmp/oi-parity-sweep-memory-default \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Execute a dedicated-profile row:

```sh
moon build --target native --release src/cmd
bun scripts/oi-parity-sweep.ts \
  --family OI-G \
  --execute \
  --count 100 \
  --out-dir .tmp/oi-parity-sweep-memory \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

The runner emits `compare-pass` commands shaped as:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count <row-or-override-count> \
  --seed <row-or-override-seed> \
  --pass optimize-instructions \
  --out-dir <sweep-root>/<family>/<row-id> \
  --gen-valid-profile <row-profile> \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --jobs auto
```

`pass-fuzz-compare` invokes Binaryen as `wasm-opt --all-features
--optimize-instructions` and compares Starshine `--optimize-instructions` via the
existing canonicalized normalized-WAT path documented in
[`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md).

Executed sweeps now print a `Result summaries` section per row: compared count,
normalized/cleanup/mismatch counts, validation/generator/property/command failure
counts, selected profile counts, `genValidProfileCaseCounts`, and grouped
`cases.jsonl` statuses by `genValidProfileCaseLabel`. When a transformed GenValid
case has no profile case label yet, the summary falls back to a `transform:<id>`
group so broad metamorphic sweeps are still mechanically classifiable before
opening individual WAT diffs. To re-read already executed sweep output without
rerunning Binaryen or Starshine, use the same filters and root directory with
`--summarize-existing`:

```sh
bun scripts/oi-parity-sweep.ts \
  --family OI-D,OI-E \
  --out-dir .tmp/oi-parity-sweep-summary-smoke \
  --summarize-existing
```

Use this summary layer as the first classifier for trigger-profile and transform
rows: group by case label or `transform:<id>`, inspect one representative WAT diff
per group, then update the matrix with an agent-classified parity gap, boundary,
or Starshine-win candidate. The summary is not a semantic-safety proof.

`parity-matrix.json` has a `classifiedCaseLabels` convention for this step. Each
row-level entry records `label`, `transformId`, `representativeFailureDir`,
`status`, `agentClassification`, `observedDiff`, `nextAction`, and
`lastCheckedEvidence`. This is deliberately separate from the runner output:
compare-pass reports mechanics, while the matrix stores the agent's source-backed
classification and next implementation or measurement action.

The first use of this convention classified the 2026-06-27 OI-D/OI-E count-3
summary smoke under `.tmp/oi-parity-sweep-summary-smoke`. OI-D's three labels were
mixed mismatches: the small implementation candidate was literal double-`eqz`
final folding from Starshine's `i32.ne(1, 0)` shape to Binaryen's `i32.const 1`,
while the extra constant-compare and constant-sign-extension folds needed measured
Starshine-win evidence. That literal double-`eqz` candidate is now implemented
with a focused pass test, and `.tmp/oi-parity-sweep-oi-d-double-eqz-fix-smoke`
shows the OI-D count-3 lane still has three raw mismatches but no longer differs
on the double-`eqz` representative. Measuring the saved canonical wasm outputs
classifies the residual OI-D representatives as Starshine-win candidates in this
sample: -5 bytes for the commuted constant-compare/sign-extension case and -2
bytes for each direct/local-carried constant-sign-extension case, with both tools'
canonical outputs validating. OI-E's direct/local-carried sign-extension labels
are Starshine-win candidates because Starshine removes redundant local-fact sign
extensions that Binaryen keeps in the representative WAT; the local-tee label is
mixed with the OI-D scalar constant-compare drift.

The same convention now covers the first grouped OI-F transform run at
`.tmp/oi-f-effectful-family-classify-20260627`. The count-4 sweep compared 4/4
with four raw mismatches and no validation/generator/property/command failures,
then grouped cases by `transform:<id>`: `oi-if-select-shell`,
`oi-effectful-sibling`, `oi-trapping-sibling`, and `oi-commuted-operands`. After
validating both tools' raw/canonical outputs, the pure if/select shell, dead
trapping sibling, and commuted-constant representatives are recorded as sampled
canonical-size Starshine-win candidates under their synthetic transform contracts
(Starshine canonical outputs are smaller by 112, 140, and 100 bytes respectively,
while raw Starshine bytes remain larger). The private-global `oi-effectful-sibling`
representative was initially size-losing. Follow-up red-first slices now match
Binaryen's same-global `if` arm sinking, sampled dropped/nested constant
`i32.add`, `i32.sub`, `i64.add`/`i64.sub`, and `i32.wrap_i64` constant folding,
sampled nonnegative signed-to-unsigned compare/div/rem/shift spellings, and the
sampled finite float sub/div spellings in both HOT or raw-skip paths. The grouped
rerun at `.tmp/oi-f-effectful-family-fix7-20260627` compared 4/4 with one
normalized match and three raw mismatches: `transform:oi-effectful-sibling` is the
match, while `oi-if-select-shell`, `oi-trapping-sibling`, and
`oi-commuted-operands` still mismatch; validation/generator/property/command
failures are all zero. Manual measurement of the effectful case keeps Binaryen and
Starshine normalized wasm size parity at 2893 bytes, raw size Starshine 4135 vs
Binaryen 2893, equal `global.set` counts at 10 vs 10, matching i32/i64 signed and
unsigned scalar spelling counts, and matching sampled float opcode counts
(`f32.sub/add/div/mul` 0/4/2/2 and `f64.sub/add/div/mul` 0/6/2/4 for both tools).
The label is no longer a sampled normalized OI-D/OI-F mismatch, but raw-byte size
remains a separate encoder/structure residual and OI-F stays open on the other
three grouped labels.

## Smoke profiles and transform coverage

`parity-matrix.json` deliberately records profile and metamorphic transform work before all targeted generator code exists. The first OI profiles now exist in `src/validate/gen_valid.mbt` as smoke-level GenValid configs:

- `pass-oi-default-scalar` for OI-D;
- `pass-oi-local-facts` for OI-E;
- `pass-oi-boolean-select` for OI-F;
- `pass-oi-memory-bulk` for OI-G;
- `pass-oi-call-ref` for OI-H;
- `pass-oi-ref-gc` for OI-I through OI-L; and
- `pass-oi-tuple` for OI-M.

These profiles are accepted by `--gen-valid-profile` and have stable labels. `pass-oi-default-scalar`, `pass-oi-local-facts`, and `pass-oi-ref-gc` now emit deterministic seed-indexed trigger smoke modules, so they are no longer only broad bounded configs or one fixed trigger module; the remaining profiles are still smoke configs. GenValid manifests and compare-pass result artifacts now expose `profile_case_label` / `genValidProfileCaseCounts` / `genValidProfileCaseLabel` metadata for OI-D/OI-E/OI-I, letting agents group raw mismatches by direct, local-carried, local.tee, local-mask, branch-cast, and direct null/test/cast trigger cases without manually opening every WAT first. The next generator-quality slice should turn the seed-indexed OI-D/OI-E/OI-I selectors into randomized trigger-biased constructors and make the other high-churn profiles emit OI-specific opportunities more reliably. The current `pass-oi-ref-gc` selector is deliberately non-descriptor because the previous descriptor-bearing broad config produced wasm-tools baseline validation failures in compare-pass; OI-J descriptor/exactness/TNH/IIT remains blocked pending a dedicated profile or compatible oracle path.

The first transform designs are:

- `oi-local-carried`;
- `oi-local-tee-wrapped`;
- `oi-effectful-sibling`;
- `oi-trapping-sibling`;
- `oi-commuted-operands`;
- `oi-if-select-shell`;
- `oi-memory-size-boundary`;
- `oi-call-ref-target-wrapper`; and
- `oi-tuple-selected-lane`.

`pass-oi-default-scalar` now emits deterministic seed-indexed trigger smoke modules from `src/validate/gen_valid.mbt`: seed modulo three selects direct scalar, local-carried scalar, or local.tee/commuted scalar shells while preserving the baseline `i32.add`, double `i32.eqz`, `i64.eqz`, sign-extension, and shift surfaces. The focused test `OI-D and OI-E trigger-smoke profiles select distinct seed-indexed cases` failed before this selector and passes now. A follow-up fuzz manifest test `emit gen-valid optimize-instructions trigger profiles record selected OI case labels` failed before metadata existed and now proves the selected OI case labels. A count-3 compare at `.tmp/oi-d-trigger-profile-cases-compare-smoke` compared 3/3 with three raw mismatches and no validation/generator/property/command failures; the grouped `OI-D` execute sweep with `--count 3` also compared 3/3 with three raw mismatches. A metadata refresh at `.tmp/oi-d-trigger-profile-cases-metadata-smoke` compared 3/3 and records the three OI-D case labels in `result.json`, `summary.json`, `cases.jsonl`, and the GenValid manifest. A grouped runner summary smoke at `.tmp/oi-parity-sweep-summary-smoke` re-ran OI-D/OI-E with `--count 3`; OI-D compared 3/3, had three raw mismatches, and reported one mismatch each for `oi-default-scalar:local-tee-commuted-add-zero`, `oi-default-scalar:direct`, and `oi-default-scalar:local-carried-add-zero` in the runner's `Result summaries` output. After the literal double-`eqz` final fold landed, `.tmp/oi-parity-sweep-oi-d-double-eqz-fix-smoke` still compared OI-D 3/3 with three raw mismatches and no validation/generator/property/command failures, but the residual diffs no longer include `i32.ne(1, 0)` vs `i32.const 1`; they are constant compare/sign-extension output-shape candidates. Measured canonical wasm sizes are Starshine 91 vs Binaryen 96 bytes for the commuted case, 63 vs 65 bytes for the direct case, and 71 vs 73 bytes for the local-carried case; `wasm-tools validate --features all` passes for both tools' canonical outputs. Classify this as open OI-D direct/local-carried/local.tee parity evidence with sampled Starshine-win candidates, not semantic-safety proof for broader ungenerated shapes.

`pass-oi-local-facts` now emits deterministic seed-indexed trigger smoke modules from `src/validate/gen_valid.mbt`: seed modulo three selects direct sign-extension facts, local.tee add-zero facts, or local-carried mask facts. The focused seed-indexed test failed before this selector and passes now, and the fuzz manifest metadata test now proves the selected OI-E labels are emitted. A count-3 compare at `.tmp/oi-e-trigger-profile-cases-compare-smoke` compared 3/3 with three raw mismatches and no validation/generator/property/command failures; the grouped `OI-E` execute sweep with `--count 3` also compared 3/3 with three raw mismatches. A metadata refresh at `.tmp/oi-e-trigger-profile-cases-metadata-smoke` compared 3/3 and records the three OI-E case labels in compare artifacts. The grouped runner summary smoke at `.tmp/oi-parity-sweep-summary-smoke` also compared OI-E 3/3, had three raw mismatches, and reported one mismatch each for `oi-local-facts:local-carried-mask`, `oi-local-facts:direct-sign-extension`, and `oi-local-facts:local-tee-add-zero` in the runner's `Result summaries` output. Classify this as open OI-E direct/local.tee/local-mask parity evidence, not semantic-safety proof.

`pass-oi-ref-gc` now emits deterministic seed-indexed non-descriptor reference trigger smoke modules from `src/validate/gen_valid.mbt`: seed modulo three selects branch-cast boundaries, direct null/test/cast/equality, or local-carried null/test/cast forms. This replaced the previous broad descriptor-bearing `pass-oi-ref-gc` sweep shape after `.tmp/oi-ref-gc-grouped-sweep-20260627` compared 0/6 OI-I/OI-J requested cases because all generated inputs failed the compare-pass wasm-tools baseline validator with `malformed section id: 14`. The focused `OI-I ref-gc trigger-smoke profile selects distinct seed-indexed reference cases` test failed red-first and now passes. A fresh grouped OI-I/OI-J summary at `.tmp/oi-ref-gc-trigger-grouped-sweep-20260627` now compares 3/3 per row with zero validation/generator/property/command failures. OI-I initially had one match (`oi-ref-gc:local-carried-null-test-cast`) and two mismatches: the branch-cast representative was a size-losing output-shape gap where Binaryen narrowed block results to `nullref` and collapsed duplicate trap tails (89/85 raw/canonical bytes) while Starshine kept `anyref` result blocks and two dropped unreachable blocks (108/96 bytes), and the direct/effectful representative was mixed with OI-F/OI-D private-global/scalar spelling drift. The branch-cast gap is now fixed for the sampled non-descriptor trigger: red-first `optimize_instructions_test.mbt` coverage drove null-fed `br_on_cast`/`br_on_cast_fail` block-result narrowing, unreachable-guard cast-branch collapse, dropped-unreachable-block collapse, and root dead-suffix trimming. The fresh `.tmp/oi-ref-gc-branch-cast-fix4-20260627` grouped OI-I run compares 3/3 with two normalized matches and one remaining raw mismatch; `branch-cast-boundaries` and `local-carried-null-test-cast` match. A no-transform reduction at `.tmp/oi-ref-gc-direct-no-transform-triage-20260627` shows `direct-null-test-cast-eq` still mismatches without `oi-effectful-sibling`, so the direct reference cleanup is OI-I-owned. That representative is currently classified as a sampled Starshine-win candidate: Starshine trims/folds only dropped pure null tests and a side-effect-free nullable-ref shell before the same guaranteed non-null-cast trap tail; Binaryen keeps those dropped shells; raw/canonical outputs validate for both tools; canonical wasm is Starshine 40 bytes vs Binaryen 48 bytes, with raw wasm 48 bytes each. The disabled OI-J run under the branch-cast fix root is still non-descriptor evidence only: branch-cast now matches there too, but OI-J descriptor/exactness/TNH/IIT remains blocked pending a compatible descriptor profile or oracle path. Do not treat this OI-J run as descriptor/exactness/TNH/IIT coverage.

`oi-local-carried` is implemented as an OI-specific smoke transform. It adds an i32 local to each defined function and prepends a stack-neutral `local.set` / `local.get` scalar carrier before the original body. The runner forwards this id to compare-pass for rows that list it; future OI-D/OI-E work should upgrade it from synthetic i32 smoke coverage to wrappers around existing producers, type-specific carriers, and actual LocalScanner facts.

`oi-local-tee-wrapped` is implemented as an OI-specific smoke transform. It adds an i32 local to each defined function and prepends a stack-neutral `local.tee` / `drop` carrier plus one `local.get` / `i32.add` / `drop` use before the original body. The runner forwards this id to compare-pass for rows that list it; future OI-D/OI-E work should upgrade it from synthetic i32 local.tee smoke coverage to existing-producer wrappers, non-i32 carriers, and targeted maxBits/signExt/nullness fact surfaces.

`oi-commuted-operands` is implemented as an OI-specific smoke transform. It prepends stack-neutral i32 constant pairs for `i32.add`, `i32.and`, and `i32.eq` in both operand orders before each defined function body. The runner forwards this id to compare-pass for rows that list it; future OI-D/OI-E/OI-F/OI-G work should upgrade it from synthetic constants to existing-producer wrappers, i64/float/select/memory-address operands, and effect/trap/no-reorder boundary siblings.

`oi-if-select-shell` is implemented as an OI-specific smoke transform. It prepends stack-neutral i32-result `if`, void `if/else`, identical-arm `select`, and `eqz`-condition `select` shells before each defined function body. The runner forwards this id to compare-pass for rows that list it; a one-case `pass-oi-boolean-select` compare smoke found 1 raw mismatch with no validation/generator/command failures, so OI-F remains an open parity row rather than a signed-off transform family. Future OI-F work should upgrade it from synthetic constants to existing-producer wrappers, branch-hint/no-fold metadata surfaces, and effectful/trapping condition siblings.

`oi-effectful-sibling` is implemented as an OI-specific smoke transform. It appends a private mutable i32 global and prepends stack-neutral side-effect shells (`global.set`/`global.get`, effectful `if`/`else`, a select sibling, and an arithmetic sibling) before each defined function body. The runner forwards this id to compare-pass for rows that list it; a one-case `pass-oi-boolean-select` compare smoke found 1 raw mismatch with no validation/generator/command failures, so the result is open OI-F parity evidence, not semantic-safety proof. Future OI-F/OI-G/OI-H/OI-M work should upgrade it from synthetic private-global effects to existing-producer wrappers, typed/reference/memory-specific operands, and tuple selected-lane side-effect siblings.

`oi-trapping-sibling` is implemented as an OI-specific smoke transform. It prepends a stack-neutral dead `if` shell containing scalar div/rem-by-zero trap-shaped siblings plus a live `i32.const` / `drop` sibling before each defined function body. The runner forwards this id to compare-pass for rows that list it; a one-case `pass-oi-boolean-select` compare smoke found 1 raw mismatch with no validation/generator/command failures, so the result is open OI-F parity evidence, not semantic-safety proof. Future work should upgrade it from dead scalar trap shapes to existing-producer wrappers, live-but-preserved trap ordering, memory/ref/GC/tuple trap lanes, and family-specific trigger-biased profiles.

`oi-memory-size-boundary` is implemented as an OI-specific smoke transform. It prepends a dead `if` containing `memory.copy` / `memory.fill` size variants `0`, `1`, `2`, `3`, `4`, `5`, `8`, and `16` for the first i32 memory. The runner forwards this id to compare-pass. Future memory work should extend this smoke layer to live-but-equivalent, effect/trap sibling, dynamic-operand, and memory64 variants before claiming OI-G family coverage.

`oi-call-ref-target-wrapper` is implemented as an OI-specific smoke transform. It appends a private no-op function/type plus a declarative element segment and prepends direct `ref.func` / `call_ref`, block-returned target, typed-select target, and dead `call_ref` shells before each previously defined function. The runner forwards this id to compare-pass for rows that list it; this is first OI-H target-wrapper coverage, not family signoff. A one-case default GenValid compare smoke produced one raw mismatch with no validation/generator/command failures, so the result is open OI-H parity evidence. The first `pass-oi-call-ref` compare smoke hit a generator failure from a wasm-tools-invalid base module; that was narrowed to stringref/exn value types leaking into the wasm-tools oracle lane and fixed by keeping stringref behind const-expression-rich profiles and exnref behind tag-enabled profiles. The fixed seed-0x5eed `pass-oi-call-ref` + `oi-call-ref-target-wrapper` smoke now compares 1/1 with 1 raw mismatch and 0 validation/generator/property/command failures. Its representative first exposed a size-losing OI-H parity gap: Binaryen directized the synthetic direct `ref.func` / `call_ref` wrappers to direct calls, leaving 0 `call_ref` opcodes in normalized WAT; Starshine initially left 40 `call_ref` opcodes and 25 `ref.func` occurrences, with Starshine raw output over 12KB vs Binaryen 554 bytes. The raw skip path now has focused red-first coverage for adjacent `ref.func`, block-returned `ref.func`, constant-select `ref.func`, single-use `local.set(ref.func)` / `local.get` call_ref/return_call_ref pairs, guaranteed `ref.null; ref.as_non_null` trap tails, dropped result blocks whose body is already unreachable, dropped null `ref.test` / nullable `ref.cast`, and dropped non-null `ref.cast` trap tails before skip. The fresh `.tmp/oi-call-ref-target-wrapper-compare-smoke-ref-null-cast-trim2` representative still mismatches, but the sampled OI-H target spelling and sampled GC cast/test debris have been eliminated: Starshine and Binaryen both have `call_ref=0`, `return_call_ref=0`, `table.get=0`, 20 direct `call $5` occurrences, `ref.test=0`, `ref.cast=0`, `br_on_cast=0`, `br_on_cast_fail=0`, and five `unreachable` roots; both raw outputs validate. Starshine raw size is now 572 bytes vs Binaryen 554 bytes, so the remaining size-losing diff is local-section / dropped-`ref.func` output shape drift, not another sampled `call_ref` target-wrapper miss. A grouped OI-H count-3 sweep at `.tmp/oi-h-target-wrapper-grouped-sweep-20260627` then exercised `oi-call-ref-target-wrapper`, `oi-local-carried`, and `oi-effectful-sibling` together. It compared 3/3 with three raw mismatches and no validation/generator/property/command failures, but every sampled Starshine and Binaryen output had `call_ref=0`, `return_call_ref=0`, and `table.get=0`; `--summarize-existing` now groups those cases as `transform:oi-call-ref-target-wrapper`, `transform:oi-local-carried`, and `transform:oi-effectful-sibling`. The target-wrapper group remains local-section/dropped-`ref.func` drift, while the local-carried and effectful-sibling groups are cross-family dropped-null/local-section and effectful-if/scalar spelling drift after successful call_ref cleanup. Future OI-H work should run broader table-state, `return_call_ref`, argument-localization, multivalue, and effect/trap target-boundary sweeps, while OI-I/OI-J and OI-F/OI-D work should use grouped sweeps to classify their own live reference/effect/scalar residuals beyond these fixed sampled OI-H target forms.

`oi-tuple-selected-lane` is implemented as an OI-specific smoke transform. It appends a multivalue block type returning `i32`, `i64`, `f32`, and `f64`, adds one scratch local per lane to each defined function, and prepends stack-neutral multivalue block / lane-store / selected-lane `local.get` / `drop` shells for each selected lane. The runner forwards this id to compare-pass for OI-M rows that list it; this is first OI-M machine-generated selected-lane coverage, not tuple-scratch family signoff. A one-case `pass-oi-tuple` compare smoke compared 1/1 and found 1 raw mismatch with 0 validation/generator/property/command failures. The representative is now classified in the matrix as a sampled Starshine-win candidate for this pure synthetic shell: Binaryen scalarizes through straight-line locals, Starshine keeps nested block-result expressions, Starshine canonical wasm is 4100 bytes vs Binaryen 4326 bytes (-226), raw wasm is 3975 vs 4229 bytes (-254), and both outputs validate. Future OI-M work should upgrade it from synthetic constants and scratch locals to existing-producer tuple wrappers, selected trapping lanes, multi-result effectful/trapping siblings, and trigger-biased `pass-oi-tuple` constructors. All first-layer OI-specific transform ids are now implemented; future design-only `oi-*` ids should remain filtered until their MoonBit transform exists.

## Family-first triage loop

For each row or family:

1. Run the sweep dry-run and inspect the planned row grouping.
2. Upgrade the needed GenValid profile / transform if the row needs stronger
   trigger coverage than the current smoke config provides.
3. Run a small `--count 100` family sweep.
4. Classify each result as covered, mismatch, intentional boundary,
   blocked-surface, unsafe-gap, or Starshine-win candidate.
5. Update `parity-matrix.json` with the new status and `lastCheckedEvidence`.
6. Add focused MoonBit tests only for behavior that the family sweep identifies
   as implementable and semantically safe.
7. Prefer infrastructure fixes that close multiple rows: local per-node fixpoint,
   first-class OI fact service, shared effect/trap/reorder/localization helpers,
   and matrix-driven raw-gate escapes.

Do not add another one-off OI behavior note without linking it from the matrix row
or using it to update a row's status.

## Current recommended next slice

After the smoke profiles and first smoke transforms, implement trigger-biased constructors or stronger metamorphic transforms for three highest-churn lanes:

1. use the runner `Result summaries` / `--summarize-existing` output to classify OI-D/OI-E/OI-I raw mismatch dirs mechanically by `genValidProfileCaseLabel`, then scale `pass-oi-default-scalar` / `pass-oi-local-facts` / `pass-oi-ref-gc` from deterministic seed-indexed trigger smokes into randomized direct scalar identities, type-specific local-carried/local.tee, local-mask, commuted-operand, branch-cast, and direct reference wrappers around existing producers;
2. split a true OI-J descriptor/exactness/TNH/IIT profile or oracle path from the current non-descriptor `pass-oi-ref-gc` smoke so grouped OI-J sweeps no longer rely on descriptor-bearing modules that wasm-tools rejects or on non-descriptor OI-I evidence;
3. `pass-oi-boolean-select` with if/select wrappers around existing producers plus typed effectful/trapping/no-fold condition siblings beyond the current synthetic if/select and private-global effect smoke transforms;
4. `pass-oi-call-ref` scale-up and trigger hardening: the seed-0x5eed stringref/exn oracle validity blocker is fixed, but OI-H still needs existing-producer/table/local target wrappers, `return_call_ref`, argument localization, multivalue variants, and effect/trap target-boundary cases beyond the current private no-op target smoke transform;
5. `pass-oi-memory-bulk` with live memory-size boundary, memory64, commuted store/address operands, and tiny copy/fill variants beyond the current dead-branch smoke transform; and
6. `pass-oi-tuple` with trigger-biased selected-lane constructors, existing-producer tuple wrappers, and effect/trap sibling variants beyond the current synthetic multivalue selected-lane smoke transform.

Those target the current highest-churn areas: scalar/default rewrites, boolean/select shells, memory-size boundaries, and tuple selected-lane boundaries.
