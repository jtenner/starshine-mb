---
kind: workflow
status: working
last_reviewed: 2026-06-28
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
three grouped labels. A follow-up `--summarize-existing` review of the same fix7
root refreshed those three labels without changing their classification: all raw
and canonical outputs validate, the pure if/select shell remains a sampled
canonical Starshine win at 2732 vs 2844 bytes, the dead trapping shell remains a
sampled canonical Starshine win at 2705 vs 2845 bytes, and the commuted-constant
shell remains a sampled canonical Starshine win at 2755 vs 2855 bytes. Raw
Starshine bytes are still larger for those first and third labels, so the matrix
keeps them sampled candidates rather than OI-F closure or raw-size parity.

The first grouped OI-G transform run was `.tmp/oi-g-memory-family-classify-20260628`.
It compared 5/5 with five raw mismatches and no validation, generator, property,
or command failures, grouped by `transform:<id>` for `oi-memory-size-boundary`,
`oi-local-carried`, `oi-effectful-sibling`, `oi-trapping-sibling`, and
`oi-commuted-operands`. The memory-size-boundary label was classified as an
OI-G-owned tiny bulk-memory lowering parity gap, not a safe representation
difference: Binaryen lowered sampled size `1`/`2`/`4`/`8`/`16`
`memory.copy`/`memory.fill` variants while Starshine left all 20 copy plus 20
fill operations. A red-first fix now covers dead-if/raw-skipped shells and lowers
those tiny copy/fill variants while preserving zero-size and size-3/5 spellings.
The grouped fix4 sweep at `.tmp/oi-g-memory-family-fix4-20260628` still compares
5/5 with five raw mismatches and no validation, generator, property, or command
failures, but `oi-memory-size-boundary` now has matching 10 copy / 10 fill and
v128 load/store counts on both tools. Follow-up WAT and section inspection
classifies the remaining memory-size-boundary diff as structural/code-section
drift rather than unlowered bulk-memory: Starshine folds more constant
ordinary/atomic memory addresses into offsets (186 offset-bearing memory ops vs
Binaryen 104), keeps one fewer i32 local in function 0, and all section-size
deltas are isolated to code (raw code Starshine/Binaryen 6162/6100; canonical
code 6080/6108). The sample remains a canonical Starshine-win candidate
(6209/6237 bytes) with raw-byte residual (6291/6229). The remaining four labels
still have matching sampled memory opcode counts; after fix4 they are sampled
canonical-size Starshine-win candidates with raw-size residuals, not OI-G family
closure. All 20 fix4 raw/canonical outputs validate.

`pass-oi-memory-bulk` is now stronger than a broad smoke config and stronger
than the earlier three-case trigger smoke. It emits thirteen OI-G
trigger-smoke-plus cases: live private-global plus dead-trap boundaries, direct
i32 tiny-bulk and load/store lowering, memory64 dynamic/local-carried bulk
operands, no-param-call/existing-producer-wrapped tiny bulk, narrow-store masks,
dynamic i32 local.tee bulk operands, multi-memory bulk operations, seed-derived
nonzero in-page copy/read addresses, seed-derived non-primary-memory in-page
copy/read addresses, seed-derived private-destination cross-memory random-address
copy/read addresses, seed-derived memory64 private-destination cross-memory
random-address copy/read addresses, seed-derived source-visible cross-memory
copy/read with destination-byte restore, and seed-derived memory64 source-visible
cross-memory copy/read with destination-byte restore. The focused generator test failed
red-first first on missing OI-G labels, then on the missing three expanded
labels, then on the missing multi-memory label/signature, then on the missing
random-address-copy-read label/signature, then on the missing
multi-memory-random-address-copy-read, cross-memory-random-address,
memory64-cross-memory-random-address, cross-memory-restore, and
memory64-cross-memory-restore labels/signatures before implementation; it now
passes. The latest post-memory64-restore grouped run at
`.tmp/oi-g-memory64-cross-memory-restore-count312-20260629` compares 201/312
transform-applicable cases with 179 normalized matches and zero validation,
generator, property, or command failures;
`oi-memory-bulk:memory64-cross-memory-restore-copy-read` has 11/11 matches and
no memory64 source-visible destination-restore opcode drift. The prior
count-288 root remains the first i32 source-visible restore evidence, the
all-comparable count-264 root remains the latest pre-restore aggregate, and the
count-198 root remains the first non-primary random-address evidence. A targeted
`--runtime-execution node` follow-up at
`.tmp/oi-g-memory64-cross-memory-restore-runtime-count65-20260629` compared
65/65 with 60 normalized matches and zero runtime semantic failures, but the
runtime matrix was blocked (`checked=36`, `unsupported=29`, `failed=0`). The
exact singleton restore seeds `0x5ef8` and `0x5ef9` each normalized 1/1 and each
reported `unsupported=1`, so runtime source-visible restore execution remains
open until the modules are executable under a compatible adapter/export path.
The direct count-18 profile lane at `.tmp/oi-g-memory-bulk-expanded-profile-count18-20260628` sampled
the first six labels, compared 18/18 with 14 normalized matches, four store-mask
mismatches, and no validation, generator, property, or command failures. The
no-transform store-mask residual is a sampled Starshine-win candidate for the
store-truncation contract: Binaryen removes the i32.store8/i32.store16 masks but
keeps the redundant `i64.and 255` before `i64.store8`, while Starshine removes it
too; raw/canonical Starshine/Binaryen size is 56/60 and all outputs validate.

The grouped count-6 OI-G sweep at
`.tmp/oi-g-memory-family-expanded-profile-20260628` compared 6/6 with two
normalized matches and four mismatches. Dynamic-i32 plus
`oi-memory-size-boundary` and direct-tiny plus `oi-local-carried` matched. The
previous memory64/effectful, direct-tiny/trapping, and memory64/commuted
residuals retain their earlier classifications. The new store-mask plus
`oi-memory-size-boundary` residual was size-losing, not safe drift: Starshine
left the i32 store masks that Binaryen removes in the dead-shell/raw path, with
raw Starshine/Binaryen 258/234 and canonical 243/234; all raw/canonical failure
outputs validated. A red-first pass/raw-shell test now covers that profile case,
and the raw partial path removes redundant i32/i64 low-bit masks after the dead
memory-size-boundary shell. The direct rerun
`.tmp/oi-g-memory-bulk-store-mask-raw-fix-count18-20260628` still has the four
known no-transform store-mask mismatches, and grouped rerun
`.tmp/oi-g-memory-family-store-mask-raw-fix-20260628` still compares 6/6 with two
normalized matches and four mismatches, but the grouped store-mask representative
is reduced to the known low-byte-store residual: Binaryen keeps only the
`i64.store8` mask, Starshine removes it, raw Starshine/Binaryen size is 245/234,
wasm-opt no-pass canonical size is 230/234, and all measured outputs validate.
The broader grouped count>=11 blocker is now fixed in the transform/generator
layer. `oi-memory-size-boundary` previously accepted only i32 memories, so the
sweep aborted before `result.json` when that transform reached a later
memory64-only trigger case. Red-first `metamorphic_wbtest.mbt` and
`main_wbtest.mbt` coverage now prove memory64-only modules get an i64
address/size dead copy/fill shell and batch selection emits those candidates.
Grouped reruns completed: count 11 at
`.tmp/oi-g-memory-family-memory64-boundary-fix-count11-20260628b` compared 11/11
with 4 normalized matches and 7 mismatches, count 12 at
`.tmp/oi-g-memory-family-memory64-boundary-fix-count12-20260628` compared 12/12
with 4 normalized matches and 8 mismatches, and the first count 18 at
`.tmp/oi-g-memory-family-memory64-boundary-fix-count18-20260628` compared 18/18
with 6 normalized matches and 12 mismatches; all three had zero
validation/generator/property/command failures. The new memory64 +
`oi-memory-size-boundary` representative keeps memory.copy/fill counts matching
at 4/4 and canonical size parity at 234/234, while raw Starshine/Binaryen is
249/234 because Starshine folds `i64.load offset=24` with `i64.const 8` where
Binaryen keeps `i64.const 32`; all raw/canonical outputs validate.

A follow-up count-18 classification found one remaining canonical size-losing
sample: `oi-memory-bulk:live-effect-trap-boundaries + oi-commuted-operands`
kept a raw-skipped ordered const equality compare that Binaryen folds. Red-first
`src/passes/optimize_instructions_test.mbt` coverage now locks the sampled raw
fallback contract, and `src/passes/pass_manager.mbt` folds adjacent ordered
`i32`/`i64` const eq/ne in raw-skipped functions while preserving the reverse
spelling observed in the Binaryen probe. Fresh grouped reruns at
`.tmp/oi-g-memory-family-raw-const-eq-fix-count18-20260628` and
`.tmp/oi-g-memory-family-raw-const-eq-fix-count24-20260628` compare 18/18 and
24/24 with 7 and 9 normalized matches, 11 and 15 mismatches, and zero
validation/generator/property/command failures. The live-effect label now matches
2/2 at count 18 and 3/3 at count 24. Manual size review of all count-18/count-24
failure dirs found zero remaining canonical size-losing mismatches, and all 44
count-18 plus 60 count-24 Binaryen/Starshine raw/canonical outputs validate.

A bounded count-30 scale-up at `.tmp/oi-g-memory-family-count30-20260628`
compares 30/30 with 10 normalized matches, 20 mismatches, and zero
validation/generator/property/command failures. It still has no canonical
size-losing failure dirs: all 80 Binaryen/Starshine raw/canonical failure outputs
validate. The new groups did not expose an OI-G memory-opcode drift. Dynamic-i32
+ `oi-commuted-operands` keeps matching memory.copy/fill/load counts and differs
only because Starshine folds a dropped pure reverse const equality that Binaryen
keeps (raw/canonical 89/92 Starshine/Binaryen). Memory64 +
`oi-trapping-sibling` keeps matching memory.copy/fill/i64.load counts and differs
because Starshine removes a dead if-false trap shell that Binaryen leaves
(raw 66/86, canonical 63/86). New store-mask effectful/commuted representatives
extend the known low-byte-store contract: memory store counts match, Starshine
removes `i64.and 255` before `i64.store8`, and the commuted case also folds a
dropped pure const equality (canonical 112/116 and 86/93).

A follow-up count-36 scale-up at `.tmp/oi-g-memory-family-count36-20260628`
compares 36/36 with 13 normalized matches, 23 mismatches, and zero
validation/generator/property/command failures. Manual review again found zero
canonical size-losing failure dirs, and all 92 Binaryen/Starshine raw/canonical
failure outputs validate. The six new samples stayed within existing
classifications: live-effect is now 4/4 matched; existing-producer gained one
`oi-effectful-sibling` match; the three new mismatches are another memory64
`oi-memory-size-boundary` offset-folding representative with matching memory
op counts and canonical parity (234/234), another direct-tiny
`oi-trapping-sibling` representative with matching tiny bulk/memory counts and
canonical parity (243/243) but dead scalar div spelling plus offset-folding/raw
residuals, and another memory64 `oi-commuted-operands` dropped reverse const-eq
Starshine win (raw/canonical 90/93 Starshine/Binaryen).

A count-42 scale-up at `.tmp/oi-g-memory-family-count42-20260628` compares 42/42
with 17 normalized matches, 25 mismatches, and zero validation/generator/property/command failures. Manual review found zero canonical size-losing failure dirs,
and all 100 Binaryen/Starshine raw/canonical failure outputs validate. The six new
samples stayed within existing classifications: live-effect is now 6/6 matched;
existing-producer gained `oi-local-carried` and `oi-memory-size-boundary` matches;
the two new mismatches are another existing-producer `oi-trapping-sibling`
representative with equal memory load/store counts, dead-helper trap-shell
trimming, and raw/canonical Starshine/Binaryen 116/151 and 105/151, plus another
store-mask `oi-local-carried` representative where Starshine removes the redundant
`i64.and 255` before `i64.store8` that Binaryen keeps (raw/canonical 68/72).

A count-48 requested scale-up at `.tmp/oi-g-memory-family-count48-20260628`
generated and compared 45/48 transform-balanced cases with 18 normalized matches,
27 mismatches, and zero validation/generator/property/command failures. Manual
review found zero canonical size-losing failure dirs, and all 108
Binaryen/Starshine raw/canonical failure outputs validate. The new case-000044
live-effect + `oi-trapping-sibling` mismatch keeps memory load/store counts equal
and differs only in a sampled dead scalar trap shell (`i32.div_s` vs Binaryen's
`i32.div_u` spelling): raw Starshine/Binaryen 101/98, canonical 98/98. The new
case-000045 memory64 + `oi-commuted-operands` mismatch repeats the pure dropped
reverse const-eq fold with memory.copy/fill/i64.load counts equal and
raw/canonical Starshine/Binaryen 90/93.

A count-54 requested saturation check at `.tmp/oi-g-memory-family-count54-20260628`
compared the same 45 transform-balanced cases as count 48: 18 normalized
matches, 27 mismatches, zero validation/generator/property/command failures, and
Binaryen cache hits/misses 45/0. Manual review again found zero canonical
size-losing failure dirs, and all 108 Binaryen/Starshine raw/canonical failure
outputs validate. Because increasing the requested count from 48 to 54 produced
no new comparable cases, further OI-G scale-up needed generator/transform
scheduling breadth rather than only a higher requested count.

The multi-memory generator-breadth slice supplied that new breadth. A direct
count-7 compare at `.tmp/oi-g-memory-bulk-multimemory-count7-20260628` compared
7/7 with six normalized matches, one known store-mask mismatch, zero
validation/generator/property/command failures, and the new multi-memory case
matching. A grouped count-63 sweep at
`.tmp/oi-g-memory-family-multimemory-count63-20260628` compared 53/63
transform-balanced cases with 27 normalized matches, 26 mismatches, zero
validation/generator/property/command failures, and Binaryen cache hits/misses
45/8. The profile cases were multi-memory=6, dynamic-i32=10, store-mask=5,
existing-producer=12, live-effect=4, direct-tiny=9, and memory64=7. Manual review
validated all 104 Binaryen/Starshine raw/canonical failure outputs and found zero
canonical size-losing failure dirs; nine failure dirs remained raw-size-larger for
Starshine. The only multi-memory mismatch was case-000049 under
`oi-trapping-sibling`: direct/no-transform multi-memory matched, five of six
grouped multi-memory samples matched, and the lone residual had no remaining
`memory.copy`/`memory.fill` in either normalized output, differing only by dead
scalar trap spelling (`i32.div_s` vs Binaryen `i32.div_u`) with raw
Starshine/Binaryen 95/94 and canonical 94/94.

A follow-up red-first raw-spelling slice removed that residual. Binaryen
`version_130` prints nonnegative signed integer `div`/`rem` by constant zero as
unsigned spellings because both signed and unsigned forms trap before producing a
value. The focused raw-skip test failed until `src/passes/pass_manager.mbt` stopped
excluding zero divisors from this spelling rewrite. The fresh grouped baseline at
`.tmp/oi-g-memory-family-divzero-spelling-fix-count63-20260628` compares 63/63
with 39 normalized matches, 24 mismatches, zero validation/generator/property/
command failures, and Binaryen cache hits/misses 63/0. Profile-case statuses are
multi-memory=6 all matching, live-effect=4 all matching, dynamic-i32=13 with one
commuted dropped-compare mismatch, store-mask=5 mismatches, existing-producer=17
with four commuted dropped-compare mismatches, direct-tiny=9 with five offset-
folding/raw residuals, and memory64=9 mismatches. Manual review validated all 96
Binaryen/Starshine raw/canonical failure outputs and found zero canonical
size-losing failure dirs; seven failure dirs remain raw-size-larger for Starshine.

A live zero-size boundary slice then added `oi-live-zero-memory-boundary`, a
reachable no-op bulk-memory transform that prepends zero-size `memory.copy` and
`memory.fill` operations to each defined function. The red-first metamorphic test
failed while the transform id/constructor was missing and passed after
implementation. The grouped run at `.tmp/oi-g-live-zero-memory-boundary-count70-20260628`
compares 70/70 with 49 normalized matches, 21 mismatches, zero
validation/generator/property/command failures, and Binaryen cache hits/misses
61/9. All 11 sampled `oi-live-zero-memory-boundary` cases match: direct-tiny=3,
dynamic-i32=3, existing-producer=4, and memory64=1. Manual review of the 21
failure dirs validates all 84 Binaryen/Starshine raw/canonical outputs, finds zero
canonical size-losing failure dirs, and leaves seven raw-size-larger Starshine
dirs as raw-byte residuals. The new transform adds live zero-size evidence, but it
is not live trap-order, atomics, or randomized memory closure.

A live nonzero copy/read slice then added `oi-live-nonzero-memory-copy-boundary`,
a guarded reachable length-1 `memory.copy` from address 0 to itself plus byte
`load`/`drop` transform. The focused transform test failed red-first on the
missing id/constructor, then passed after `src/fuzz/metamorphic.mbt` and
`scripts/lib/oi-parity-sweep.ts` wiring. The first count-77 grouped run at
`.tmp/oi-g-live-nonzero-copy-boundary-count77-20260628` compared 57/77 with 30
normalized matches, 27 mismatches, and zero validation/generator/property/command
failures, but all eight sampled live-nonzero cases mismatched because raw-skipped
Starshine kept `i32.ne(memory.size, 0)` as an if condition where Binaryen prints
`memory.size`. Red-first `src/passes/optimize_instructions_test.mbt` coverage
now guards that raw partial condition-context rewrite, and
`src/passes/pass_manager.mbt` simplifies the sampled raw-skipped shell to
Binaryen's spelling. The post-fix run at
`.tmp/oi-g-live-nonzero-copy-boundary-raw-if-fix-count77-20260628` compares 66/77
with 43 normalized matches, 23 mismatches, zero validation/generator/property/
command failures, and Binaryen cache hits/misses 66/0. Multi-memory, dynamic-i32,
and live-effect labels all match in this run; live-nonzero samples are six matches
and three direct-tiny mismatches. Manual validation/size review of all 23 failure
dirs validates 92 Binaryen/Starshine raw/canonical outputs, finds zero canonical
size-losing dirs, and leaves nine raw-size-larger Starshine dirs. The remaining
live-nonzero direct-tiny residuals are offset-folding/raw-size cases with
canonical size parity 238/238, not live memory opcode drift.

A fixed page-middle live nonzero copy/read slice then added
`oi-live-nonzero-memory-mid-copy-boundary`, a guarded reachable length-1
`memory.copy` from byte 32768 to itself followed by a byte `load`/`drop` at the
same address. The focused transform test failed red-first on the missing
id/constructor and passed after `src/fuzz/metamorphic.mbt`, `src/fuzz/main.mbt`,
and `scripts/lib/oi-parity-sweep.ts` wiring. The grouped count-110 run at
`.tmp/oi-g-live-nonzero-mid-copy-boundary-count110-20260628` compares 110/110
with 62 normalized matches, 48 mismatches, zero validation/generator/property/
command failures, and Binaryen cache hits/misses 100/10. Every forwarded
transform sampled ten cases. The new mid-copy transform samples ten cases: six
match, two memory64 residuals repeat the existing `i64.load offset=24` versus
`i64.const 32` offset-folding/raw drift at canonical parity 90/90, and two
direct-tiny residuals repeat i32 load/store offset-folding/raw drift at canonical
parity 244/244. Manual validation/size review of all 48 failure dirs validates
192 Binaryen/Starshine raw/canonical outputs, finds zero canonical size-losing
dirs, and leaves 27 raw-size-larger Starshine dirs. This is fixed page-middle
copy/read evidence only, not randomized-address, atomics, true live trap-order,
OI-G closure, or OI-J descriptor/exactness/TNH/IIT evidence.

A live nonzero fill/read slice then added
`oi-live-nonzero-memory-fill-restore-boundary`, a guarded reachable length-1
`memory.fill` that restores byte 0 by loading the current byte as the fill value,
then load/drops byte 0. The focused transform test failed red-first on the
missing id/constructor and passed after `src/fuzz/metamorphic.mbt`,
`src/fuzz/main.mbt`, and `scripts/lib/oi-parity-sweep.ts` wiring. The grouped
count-84 run at `.tmp/oi-g-live-nonzero-fill-restore-boundary-count84-20260628`
compares 84/84 with 58 normalized matches, 26 mismatches, zero
validation/generator/property/command failures, and Binaryen cache hits/misses
78/6. The new fill-restore transform samples ten cases: eight match and two
memory64 cases mismatch only on the existing i64.load offset-folding/raw-size
residual. In the representative both tools keep `memory.fill=1`,
`memory.copy=1`, `i32.load8_u=2`, `memory.size=1`, and `i64.ne=1`; raw
Starshine/Binaryen is 87/84 and canonical size parity is 84/84. Manual
validation/size review of all 26 failure dirs validates 104 Binaryen/Starshine
raw/canonical outputs, finds zero canonical size-losing dirs, and leaves eleven
raw-size-larger Starshine dirs.

A live nonzero nonzero-address fill/read slice then added
`oi-live-nonzero-memory-end-fill-restore-boundary`, a guarded reachable
end-byte `memory.fill` restore/read transform. It computes the address as
`memory.size * 65536 - 1`, restores that byte from its current value, and then
load/drops it. The focused transform test failed red-first on the missing
id/constructor and passed after `src/fuzz/metamorphic.mbt`, `src/fuzz/main.mbt`,
and `scripts/lib/oi-parity-sweep.ts` wiring. The first grouped count-91 run at
`.tmp/oi-g-live-nonzero-end-fill-restore-boundary-count91-full-20260628`
compared 91/91 with 48 normalized matches, 43 mismatches, zero failures, and
Binaryen cache hits/misses 89/2, but manual size review found ten canonical
size-losing end-fill residuals where Starshine kept raw-skipped
`memory.size * 65536` while Binaryen printed `memory.size << 16`. A red-first
pass test now covers that gap, and `src/passes/pass_manager.mbt` rewrites
non-constant-lhs i32/i64 power-of-two multiplies to shifts in raw-skipped OI
functions. The post-fix grouped run at
`.tmp/oi-g-live-nonzero-end-fill-restore-boundary-raw-shift-fix-count91-20260628`
compares 91/91 with 54 normalized matches, 37 mismatches, zero failures, and
Binaryen cache hits/misses 91/0. The new end-fill transform samples ten cases:
six match and four mismatch only on existing memory64/direct-tiny offset-folding
or raw-size residuals, with canonical size parity (102/102 or 256/256). Manual
validation/size review of all 37 failure dirs validates 148 Binaryen/Starshine
raw/canonical outputs, finds zero canonical size-losing dirs, and leaves eighteen
raw-size-larger Starshine dirs.

A fixed page-middle live nonzero fill/read slice then added
`oi-live-nonzero-memory-mid-fill-restore-boundary`, a guarded reachable
`memory.fill` restore/read transform for byte 32768 in the first page. The
focused transform test failed red-first on the missing id/constructor and passed
after `src/fuzz/metamorphic.mbt`, `src/fuzz/main.mbt`, and
`scripts/lib/oi-parity-sweep.ts` wiring. The grouped count-100 run at
`.tmp/oi-g-live-nonzero-mid-fill-restore-boundary-count100-20260628` compares
100/100 with 61 normalized matches, 39 mismatches, zero validation/generator/
property/command failures, and Binaryen cache hits/misses 91/9. Every forwarded
transform sampled ten cases. The new mid-fill transform samples ten cases: five
match, one direct-tiny residual is existing offset-folding/raw drift at canonical
parity 244/244, and four store-mask residuals are the known low-byte-mask
Starshine-win candidates with canonical Starshine/Binaryen size 83/87. Manual
validation/size review of all 39 failure dirs validates 156 Binaryen/Starshine
raw/canonical outputs, finds zero canonical size-losing dirs, and leaves sixteen
raw-size-larger Starshine dirs. This is fixed-address page-middle evidence only,
not randomized-address, atomics, true live trap-order, OI-G closure, or OI-J
descriptor/exactness/TNH/IIT evidence.

A red-first raw fallback slice then targeted the count-110 offset-folding residuals
instead of classifying them away. `src/passes/optimize_instructions_test.mbt` now
covers raw-skipped memory32 load/store and memory64 load/store forms with
constant addresses plus nonzero static offsets; the focused test failed before the
implementation and passed after `src/passes/pass_manager.mbt` folded nonnegative
memory32 `const + offset` and non-overflowing memory64 `const + offset` to
Binaryen's zero-offset/folded-address spelling. The fresh grouped run at
`.tmp/oi-g-raw-const-mem-offset-fix-count110-20260628` compares 110/110 with 89
normalized matches, 21 mismatches, zero validation/generator/property/command
failures, and Binaryen cache hits/misses 110/0. This reduces the previous
count-110 baseline from 48 mismatches to 21. Manual validation/size review of all
21 failure dirs validates 84 Binaryen/Starshine raw and normalized outputs, finds
zero normalized/canonical size-losing dirs, and leaves only two raw-size-larger
Starshine dirs, both remaining store-mask plus `oi-memory-size-boundary` raw
residuals. Direct-tiny profile samples are now 15/15 matches; live-effect,
trapping-sibling, live-nonzero mid-copy, and live-nonzero end-fill transforms all
match every sampled case in this run. Remaining mismatches are store-mask
low-byte-mask Starshine-win candidates and commuted dropped-compare Starshine-win
candidates under existing-producer, memory64, dynamic-i32, or multi-memory
wrappers, not memory.copy/fill opcode drift or the prior direct-tiny/memory64
constant-offset residuals.

A red-first transform-breadth slice then added first live atomic evidence instead
of treating atomics as implied by ordinary load/store coverage.
`src/fuzz/metamorphic_wbtest.mbt` failed on the missing
`oi-live-nonzero-memory-atomic-boundary` id/constructor, then passed after
`src/fuzz/metamorphic.mbt` added a guarded `memory.size != 0` prefix that executes
a reachable `i32.atomic.load8_u` at byte 0 and drops the result for memory32 or
memory64 modules. `scripts/lib/oi-parity-sweep.ts` now forwards the transform for
OI-G rows. The grouped count-120 run at
`.tmp/oi-g-live-atomic-boundary-count120-20260628` compares 120/120 with 99
normalized matches, 21 mismatches, zero validation/generator/property/command
failures, and Binaryen cache hits/misses 115/5. The new atomic transform samples
ten cases: eight match and two store-mask cases repeat the known low-byte-store
mask residual; both tools keep the same `i32.atomic.load8_u` count. Manual
validation/size review of all 21 failure dirs validates 84 Binaryen/Starshine raw
and canonical outputs, finds zero canonical size-losing dirs, and leaves five
raw-size-larger Starshine dirs. That residual set was still store-mask
low-byte-mask candidates or commuted dropped-compare candidates; no atomic opcode
or validation drift was found.

A follow-up red-first transform-breadth slice added first live no-op atomic
store/RMW/cmpxchg evidence instead of closing atomics from the atomic-load probe.
`src/fuzz/metamorphic_wbtest.mbt` failed on the missing
`oi-live-nonzero-memory-atomic-rmw-boundary` id/constructor, then passed after
`src/fuzz/metamorphic.mbt` added a guarded `memory.size != 0` prefix that
preserves byte 0 while executing atomic store8 of the currently loaded byte,
`i32.atomic.rmw.add` with value 0, and `i32.atomic.rmw.cmpxchg` with
expected/replacement 0 for memory32 or memory64 modules. Later red-first
extensions of the same test failed until the transform also included no-op
`i32_8`/`i32_16`/`i64`/`i64_8`/`i64_16`/`i64_32` atomic RMW add variants, an
`i64.atomic.rmw.cmpxchg` 0->0 spelling, the same sequence at byte 16, the same
sequence at page-middle byte 32768, no-op full/narrow i32/i64
`atomic.rmw.sub`/`or`/`xor` by zero plus `atomic.rmw.and` by all-ones, and then a
dynamic end-byte `memory.size * 65536 - 1` byte-width sequence under the same
`memory.size != 0` guard. The end-byte sequence intentionally uses only byte-width
atomics to avoid full-width alignment traps: store8 of the loaded byte,
i32/i64 `atomic.rmw8` add/sub/or/xor by zero, i32/i64 `atomic.rmw8.and` by
all-ones, and i32/i64 `atomic.rmw8.cmpxchg` 0->0. The grouped count-130 run at
`.tmp/oi-g-live-atomic-rmw-boundary-count130-20260628` compared 130/130 with 108
normalized matches, 22 mismatches, zero validation/generator/property/command
failures, and Binaryen cache hits/misses 123/7. The integer-variant run at
`.tmp/oi-g-live-atomic-rmw-variants-count130-20260628`, the byte-16 refresh at
`.tmp/oi-g-live-atomic-rmw-nonzero-address-count130-20260628`, the byte-32768
refresh at `.tmp/oi-g-live-atomic-rmw-midpage-count130-20260628`, the no-op
operation refresh at `.tmp/oi-g-live-atomic-rmw-noop-variants-count130-20260628`,
and the dynamic end-byte refresh at
`.tmp/oi-g-live-atomic-rmw-end-byte-count130-20260628` all compare 130/130 with
108 normalized matches, 22 mismatches, zero failures, and Binaryen cache
hits/misses 125/5 for the latest runs. The broadened transform samples ten cases
and all ten match; the prior atomic-load transform also samples ten cases and all
ten match in this run. Manual validation/size review of all 22 latest failure
dirs validates 88 Binaryen/Starshine raw and canonical outputs, finds zero
canonical size-losing dirs, and leaves two raw-size-larger Starshine dirs. The
latest residual set is still store-mask low-byte-mask candidates or commuted
dropped-compare candidates; no atomic opcode or validation drift was found.

Remaining grouped residuals are sampled candidates with explicit reopening
criteria, not OI-G closure: store-mask low-byte-store mask removal remains a
canonical Starshine-win candidate; existing-producer, memory64, multi-memory,
dynamic-i32, direct-tiny, random-address-copy-read,
multi-memory-random-address-copy-read, and memory64-cross-memory residuals are
commuted dropped-compare, store-mask, or synthetic cleanup candidates with memory
opcode counts aligned or irrelevant to the diff. The grouped count-198
multi-memory random-address run keeps live-effect labels fully matching, shows
the new profile case at 24/25 matches, validates all 136 Binaryen/Starshine
raw/canonical failure outputs, finds zero canonical size-losing dirs, and leaves
only two raw-size-larger Starshine dirs; the count-264 memory64 private
cross-memory run samples `oi-memory-bulk:memory64-cross-memory-random-address-copy-read`
22/22 matches. The post-restore count-288 slice adds first source-visible
destination-byte restore evidence: direct count-60 samples
`oi-memory-bulk:cross-memory-restore-copy-read` 5/5 matches, grouped count-288
samples it 15/15 matches, all 84 failure-dir raw/canonical outputs validate, and
there are zero canonical size-losing or raw-size-larger Starshine failure dirs.
The post-memory64-restore count-312 slice adds sampled memory64 source-visible
destination-byte restore evidence: direct count-65 samples
`oi-memory-bulk:memory64-cross-memory-restore-copy-read` 3/3 matches, grouped
count-312 samples it 11/11 matches, all 88 failure-dir raw/canonical outputs
validate, there are zero canonical size-losing dirs, and seven unrelated
raw-size-larger Starshine failure dirs remain.
The refreshed atomic variant evidence covers fixed byte-0, byte-16, and
page-middle byte-32768 no-op integer RMW add/sub/and/or/xor and cmpxchg
spellings, but still not xchg, wait/notify, randomized-address atomics, or
multi-memory atomic address ordering. Broader source-visible restore shapes,
atomic xchg/wait/notify and randomized operation variants, randomized live memory
wrappers, store/address commutation, randomized multi-memory wrappers, raw-byte
alignment, randomized memory64 coverage, true live trap/effect ordering, and
grouped mismatch reduction remain open. OI-J descriptor/exactness/TNH/IIT remains
blocked on true descriptor-compatible evidence; do not close it from these
non-descriptor OI-G memory sweeps.

## Smoke profiles and transform coverage

`parity-matrix.json` deliberately records profile and metamorphic transform work before all targeted generator code exists. The first OI profiles now exist in `src/validate/gen_valid.mbt` as smoke-level GenValid configs:

- `pass-oi-default-scalar` for OI-D;
- `pass-oi-local-facts` for OI-E;
- `pass-oi-boolean-select` for OI-F;
- `pass-oi-memory-bulk` for OI-G;
- `pass-oi-call-ref` for OI-H;
- `pass-oi-ref-gc` for OI-I through OI-L; and
- `pass-oi-tuple` for OI-M.

These profiles are accepted by `--gen-valid-profile` and have stable labels. `pass-oi-default-scalar`, `pass-oi-local-facts`, `pass-oi-memory-bulk`, and `pass-oi-ref-gc` now emit trigger smoke modules, so they are no longer only broad bounded configs or one fixed trigger module; the remaining profiles are still smoke configs. OI-G is the first of these to move beyond three labels: its profile now includes memory64 dynamic/live boundary/direct tiny-bulk, existing-producer call-wrapped bulk, store-mask, dynamic-i32 bulk, multi-memory bulk, seed-derived random-address copy/read, non-primary-memory random-address copy/read, private-destination cross-memory random-address copy/read, memory64 private-destination cross-memory random-address copy/read, source-visible destination-restore cross-memory copy/read, and memory64 source-visible destination-restore cross-memory copy/read labels. GenValid manifests and compare-pass result artifacts expose `profile_case_label` / `genValidProfileCaseCounts` / `genValidProfileCaseLabel` metadata for OI-D/OI-E/OI-G/OI-I, letting agents group raw mismatches without manually opening every WAT first. The next generator-quality slice should turn the remaining seed-indexed OI-D/OI-E/OI-I selectors into randomized trigger-biased constructors and continue reducing/classifying OI-G grouped store-mask, commuted-compare, raw-size, multi-memory, broader cross-memory restore/mutation, and atomic-address issues before scaling counts. The current `pass-oi-ref-gc` selector is deliberately non-descriptor because the previous descriptor-bearing broad config produced wasm-tools baseline validation failures in compare-pass; OI-J descriptor/exactness/TNH/IIT remains blocked pending a dedicated profile or compatible oracle path.

The first transform designs are:

- `oi-local-carried`;
- `oi-local-tee-wrapped`;
- `oi-effectful-sibling`;
- `oi-trapping-sibling`;
- `oi-commuted-operands`;
- `oi-if-select-shell`;
- `oi-memory-size-boundary`;
- `oi-live-zero-memory-boundary`;
- `oi-live-nonzero-memory-copy-boundary`;
- `oi-live-nonzero-memory-mid-copy-boundary`;
- `oi-live-nonzero-memory-end-copy-boundary`;
- `oi-live-nonzero-memory-dynamic-copy-boundary`;
- `oi-live-nonzero-memory-varied-copy-boundary`;
- `oi-live-nonzero-memory-second-copy-boundary`;
- `oi-live-nonzero-memory-cross-copy-boundary`;
- `oi-live-nonzero-memory-atomic-boundary`;
- `oi-live-nonzero-memory-atomic-rmw-boundary`;
- `oi-live-nonzero-memory-fill-restore-boundary`;
- `oi-live-nonzero-memory-mid-fill-restore-boundary`;
- `oi-live-nonzero-memory-end-fill-restore-boundary`;
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

`oi-memory-size-boundary` is implemented as an OI-specific smoke transform. It prepends a dead `if` containing `memory.copy` / `memory.fill` size variants `0`, `1`, `2`, `3`, `4`, `5`, `8`, and `16` for the first memory, using i32 operands for memory32 and i64 operands for memory64-only modules. The runner forwards this id to compare-pass. Future memory work should extend this smoke layer to live-but-equivalent, effect/trap sibling, dynamic-operand, broader atomic, and multi-memory variants before claiming OI-G family coverage.

`oi-live-zero-memory-boundary` is implemented as an OI-specific smoke transform. It prepends reachable zero-size `memory.copy` / `memory.fill` operations for the first memory to each defined function, using i32 operands for memory32 and i64 operands for memory64-only modules. The runner forwards this id to compare-pass for OI-G rows that list it. The first grouped count-70 run with this transform matched all 11 sampled live-zero cases and had zero validation/generator/property/command failures; it is live zero-size evidence only, not trap-order or atomics signoff.

`oi-live-nonzero-memory-mid-copy-boundary` is implemented as an OI-specific smoke transform. It guards `memory.size != 0`, then performs a reachable length-1 `memory.copy` from byte 32768 to itself plus a byte load/drop at the same address, using i32 operands for memory32 and i64 operands for memory64-only modules. The runner forwards this id to compare-pass for OI-G rows that list it. The first grouped count-110 run samples ten mid-copy cases with six matches and four offset-folding/raw residuals at canonical parity, with zero validation/generator/property/command failures and zero canonical size-losing failure dirs. It is fixed page-middle copy/read evidence only, not randomized-address, atomics, or trap-order closure.

`oi-live-nonzero-memory-end-copy-boundary` is implemented as an OI-specific smoke transform. It guards `memory.size != 0`, computes the last byte as `memory.size * 65536 - 1`, performs a reachable length-1 `memory.copy` from that address to itself, and load/drops the same byte, using i32 operands for memory32 and i64 operands for memory64-only modules. The runner forwards this id to compare-pass for OI-G rows that list it. The grouped count-140 run `.tmp/oi-g-live-end-copy-boundary-count140-20260628` samples ten end-copy cases with nine matches and one known store-mask low-byte-mask residual, compares 140/140 with 119 normalized matches and 21 mismatches overall, has zero validation/generator/property/command failures, and has zero canonical size-losing failure dirs after manual validation/size review. It is dynamic end-byte copy/read evidence only, not randomized-address, atomics, live trap-order, or family closure.

`oi-live-nonzero-memory-dynamic-copy-boundary` is implemented as an OI-specific smoke transform. It guards `memory.size != 0`, computes a dynamic interior byte address as `memory.size * 32768`, performs a reachable length-1 `memory.copy` from that address to itself, and load/drops the same byte, using i32 operands for memory32 and i64 operands for memory64-only modules. The runner forwards this id to compare-pass for OI-G rows that list it. The initial grouped count-150 run exposed a raw OI parity gap: Starshine kept the dynamic self-copy and then kept the multiply spelling while Binaryen lowered to load/store and printed `memory.size << 15`. Red-first pass coverage now fixes both raw fallback gaps. The fresh fix2 count-150 run `.tmp/oi-g-live-dynamic-copy-boundary-fix2-count150-20260628` samples ten dynamic-copy cases and all ten match; the whole row compares 150/150 with 129 normalized matches, 21 mismatches, zero validation/generator/property/command failures, zero canonical size-losing failure dirs, and three raw-size-larger Starshine dirs. This is sampled dynamic interior-address copy/read evidence only; randomized-address, multi-memory-specific ordering, live trap-order, and OI-G closure remain open.

`oi-live-nonzero-memory-varied-copy-boundary` is implemented as an OI-specific smoke transform. It guards `memory.size != 0`, then performs reachable length-1 self `memory.copy` plus byte `load`/`drop` at bytes 17, 1024, 49152, and 65535. The runner forwards this id to compare-pass for OI-G rows that list it. The grouped count-170 run `.tmp/oi-g-live-varied-copy-boundary-count170-20260629` compares 170/170 with 145 normalized matches, 25 mismatches, zero validation/generator/property/command failures, and Binaryen cache hits/misses 164/6. The transform samples ten cases with eight matches. Its two residuals are classified as the known store-mask low-byte-mask candidate, not varied-address copy/read drift: representative WAT inspection shows both tools lower all varied self-copies to load8/store8 forms (`memory.copy` 0/0, `i32.load8_u` 8/8, `i32.store8` 5/5), and the diff is the unrelated `i64.store8` low-byte mask where Binaryen keeps `i64.and 255` and Starshine removes it. Manual review validates all 100 failure-dir raw/canonical outputs, finds zero canonical size-losing dirs, and leaves six raw-size-larger Starshine dirs. Treat this as fixed varied-address copy/read smoke evidence only; it is not randomized-address, atomics, true live trap-order, cross-memory mutation, OI-G closure, or descriptor-compatible OI-J evidence.

`oi-memory-bulk:random-address-copy-read` is implemented as an OI-G trigger-smoke-plus profile case in `src/validate/gen_valid.mbt`. It selects a seed-derived nonzero in-page address, performs a length-1 self `memory.copy`, and byte-load/drops that same address. The focused generator test failed red-first when seed `0x5ef4` still selected the older memory64 case, then passed after the profile grew to eight cases. The grouped count-180 run `.tmp/oi-g-random-address-copy-read-count180-20260629` compares 180/180 with 148 normalized matches, 32 mismatches, zero validation/generator/property/command failures, and Binaryen cache hits/misses 155/25. The new profile case samples 22 cases with 21 matches; its one residual is a known commuted dropped-compare Starshine-win candidate, not copy/read drift. Representative case 000056 uses address 44129, both tools lower the self-copy to load8/store8 forms (`memory.copy` 0/0, `i32.load8_u` 2/2, `i32.store8` 1/1), and all 128 raw/canonical outputs from the 32 failure dirs validate with zero canonical size-losing dirs. Treat this as seed-derived random-address copy/read profile evidence only; it is not randomized multi-memory mutation, atomics, true live trap-order, OI-G closure, or descriptor-compatible OI-J evidence.

`oi-memory-bulk:multi-memory-random-address-copy-read` is implemented as an OI-G trigger-smoke-plus profile case in `src/validate/gen_valid.mbt`. It defines two i32 memories, selects a seed-derived nonzero in-page address, performs a length-1 self `memory.copy` on non-primary memory index 1, and byte-load/drops that same memory/address. The focused generator test failed red-first when seed `0x5ef5` still selected the older memory64 case, then passed after the profile grew to nine cases while preserving the seed `0x5eed` through `0x5ef4` sequence. The grouped count-198 run `.tmp/oi-g-multimemory-random-address-count198-20260629` compares 198/198 with 164 normalized matches, 34 mismatches, zero validation/generator/property/command failures, and Binaryen cache hits/misses 162/36. The new profile case samples 25 cases with 24 matches; its one residual is the known commuted dropped-compare Starshine-win candidate, not non-primary copy/read drift. Representative case 000056 uses address 44129 on memory 1; both tools lower the self-copy to load8/store8 forms (`memory.copy` 0/0, `i32.load8_u` 2/2, `i32.store8` 1/1), and all 136 raw/canonical outputs from the 34 failure dirs validate with zero canonical size-losing dirs. Treat this as seed-derived non-primary-memory random-address copy/read profile evidence only; it is not cross-memory random mutation, atomics, true live trap-order, OI-G closure, or descriptor-compatible OI-J evidence.

`oi-live-nonzero-memory-second-copy-boundary` is implemented as an OI-specific smoke transform. It guards a non-primary `memory.size != 0`, performs a reachable length-1 `memory.copy` from byte 0 of that non-primary memory to itself, and load/drops the same byte. When the input already has a non-primary memory, it uses that memory with its i32/i64 address type; when the input has only one memory, it appends a private second i32 memory so grouped transform scheduling remains applicable without changing exported memory behavior. The focused transform test failed red-first on the missing id/constructor, and the first grouped count-160 attempt failed before comparison because the non-primary-only transform stalled on single-memory profile positions. The private-second-memory applicability fix removed that generator stall. The grouped count-160 run `.tmp/oi-g-live-second-copy-boundary-fix-count160-20260628` compares 160/160 with 138 normalized matches, 22 mismatches, zero validation/generator/property/command failures, Binaryen cache hits/misses 153/7, zero canonical size-losing failure dirs, and two raw-size-larger Starshine dirs. The new transform samples ten cases: nine match and one repeats the known store-mask low-byte-mask residual; in that representative both tools lower the non-primary self-copy to `i32.load8_u` plus `i32.store8` under the same memory.size guard. This is non-primary-memory copy/read smoke evidence only, not cross-memory copy mutation, randomized-address, atomics, live trap-order closure, or OI-J descriptor evidence.

`oi-memory-bulk:cross-memory-random-address-copy-read` is implemented as an OI-G trigger-smoke-plus profile case in `src/validate/gen_valid.mbt`. It defines two i32 memories, selects a seed-derived nonzero in-page address, performs a length-1 `memory.copy` from source memory 0 to private destination memory 1, and byte-load/drops that same destination memory/address. The focused generator test failed red-first when seed `0x5ef6` still selected the older memory64 case, then passed after the profile grew to ten cases while preserving the seed `0x5eed` through `0x5ef5` sequence. A direct count-10 profile compare at `.tmp/oi-g-memory-bulk-cross-memory-random-profile-count10-20260629` normalized 10/10 with zero failures. The grouped count-240 run `.tmp/oi-g-cross-memory-random-address-count240-20260629` compares 240/240 with 197 normalized matches, 43 mismatches, zero validation/generator/property/command failures, and Binaryen cache hits/misses 180/60. The new profile case samples 21 cases and all 21 match; all 172 raw/canonical Binaryen/Starshine outputs from the unrelated 43 failure dirs validate with zero canonical size-losing dirs and zero raw-size-larger Starshine dirs. Treat this as seed-derived private-destination cross-memory random-address evidence only; it is not source-visible cross-memory mutation, atomics, true live trap-order, OI-G closure, or descriptor-compatible OI-J evidence.

`oi-memory-bulk:memory64-cross-memory-random-address-copy-read` is implemented as an OI-G trigger-smoke-plus profile case in `src/validate/gen_valid.mbt`. It defines two memory64 memories, selects a seed-derived nonzero in-page i64 address, performs a length-1 `memory.copy` from source memory 0 to private destination memory 1, and byte-load/drops that same destination memory/address using i64 operands. The focused generator test failed red-first when seed `0x5ef7` still selected the older memory64-dynamic case, then passed after the profile grew to eleven cases while preserving the seed `0x5eed` through `0x5ef6` sequence. A direct count-50 profile compare at `.tmp/oi-g-memory-bulk-memory64-cross-memory-random-profile-count50-20260629` compares 50/50 with 46 normalized matches, four known store-mask mismatches, zero failures, and the new label matching 1/1. The grouped count-264 run `.tmp/oi-g-memory64-cross-memory-random-address-count264-20260629` compares 264/264 with 235 normalized matches, 29 mismatches, zero validation/generator/property/command failures, and Binaryen cache hits/misses 174/90. The new profile case samples 22 cases and all 22 match; all 116 raw/canonical Binaryen/Starshine outputs from the unrelated 29 failure dirs validate with zero canonical size-losing dirs and nine raw-size-larger Starshine dirs. Treat this as seed-derived memory64 private-destination cross-memory random-address evidence only; it is not source-visible cross-memory mutation, atomics, true live trap-order, OI-G closure, or descriptor-compatible OI-J evidence.

`oi-memory-bulk:cross-memory-restore-copy-read` is implemented as an OI-G trigger-smoke-plus profile case in `src/validate/gen_valid.mbt`. It defines two i32 memories, selects a seed-derived nonzero in-page address, saves the destination byte from memory 1 into a local, performs a length-1 `memory.copy` from source memory 0 to destination memory 1, byte-load/drops that destination byte, and restores the saved destination byte with `i32.store8`. The focused generator test failed red-first when seed `0x5ef8` still selected an older case, then passed after the profile grew to twelve cases while preserving the seed `0x5eed` through `0x5ef7` sequence. A direct count-60 profile compare at `.tmp/oi-g-cross-memory-restore-profile-count60-20260629` compares 60/60 with 55 normalized matches, five known store-mask mismatches, zero failures, and the new label matching 5/5. The grouped count-288 run `.tmp/oi-g-cross-memory-restore-count288-20260629` compares 149/288 transform-applicable cases with 128 normalized matches, 21 mismatches, zero validation/generator/property/command failures, and Binaryen cache hits/misses 99/50. The new profile case samples 15 grouped cases and all 15 match; all 84 raw/canonical Binaryen/Starshine outputs from the unrelated 21 failure dirs validate with zero canonical size-losing dirs and zero raw-size-larger Starshine dirs. Treat this as seed-derived source-visible destination-restore cross-memory evidence only; it is not broad source-visible mutation closure, memory64 restore evidence, atomics, true live trap-order, OI-G closure, or descriptor-compatible OI-J evidence.

`oi-memory-bulk:memory64-cross-memory-restore-copy-read` is implemented as an OI-G trigger-smoke-plus profile case in `src/validate/gen_valid.mbt`. It defines two memory64 memories, selects a seed-derived nonzero in-page i64 address, saves the destination byte from memory 1 into an i64 local, performs a length-1 `memory.copy` from source memory 0 to destination memory 1, byte-load/drops that destination byte, and restores the saved destination byte with `i64.store8`. The focused generator test failed red-first when seed `0x5ef9` still selected `memory64-dynamic-bulk`, then passed after the profile grew to thirteen cases while preserving the seed `0x5eed` through `0x5ef8` sequence. A direct count-65 profile compare at `.tmp/oi-g-memory64-cross-memory-restore-profile-count65-20260629` compares 65/65 with 60 normalized matches, five known store-mask mismatches, zero failures, and the new label matching 3/3. The grouped count-312 run `.tmp/oi-g-memory64-cross-memory-restore-count312-20260629` compares 201/312 transform-applicable cases with 179 normalized matches, 22 mismatches, zero validation/generator/property/command failures, and Binaryen cache hits/misses 133/68. The new profile case samples 11 grouped cases and all 11 match; all 88 raw/canonical Binaryen/Starshine outputs from the unrelated 22 failure dirs validate with zero canonical size-losing dirs and seven raw-size-larger Starshine dirs. Treat this as seed-derived memory64 source-visible destination-restore cross-memory evidence only; it is not broad source-visible mutation closure, runtime execution evidence, atomics, true live trap-order, OI-G closure, or descriptor-compatible OI-J evidence.

`oi-live-nonzero-memory-cross-copy-boundary` is implemented as an OI-specific smoke transform. It appends a private nonzero destination memory matching the source address width, guards source and destination `memory.size != 0`, performs reachable length-1 `memory.copy` operations from the first source memory to that private destination memory at fixed in-page bytes 17, 1024, 49152, and 65535, and load/drops each private destination byte. The private destination keeps source-visible memory behavior stable while introducing real cross-memory copy mutation shapes. The original focused transform test failed red-first on the missing id/constructor; a later red-first test failed while the transform still emitted only byte 17, then passed after `src/fuzz/metamorphic.mbt` emitted all four fixed addresses. The latest red-first focused test failed because the transform required an i32 source memory, then passed after memory64-compatible source plus private memory64 destination support was added. The grouped count-240 run `.tmp/oi-g-cross-memory-random-address-count240-20260629` samples this transform 13 times and all 13 match; the grouped count-264 run `.tmp/oi-g-memory64-cross-memory-random-address-count264-20260629` samples it 14 times and all 14 match. The latest run has zero validation/generator/property/command failures and zero canonical size-losing failure dirs. The prior count-216 representative case 000211 remains useful fixed-address evidence: both tools lower all four i32 cross-memory copies to load8/store8 forms (`memory.copy` 0/0, `i32.load8_u` 8/8, `i32.store8` 5/5), with canonical Starshine/Binaryen sizes 156/161 and all outputs validating; that diff was unrelated `i64.store8` low-byte-mask cleanup. This is fixed-address private-destination cross-memory copy/read smoke evidence for memory32 and memory64, not source-visible cross-memory mutation, multi-memory atomics, live trap-order closure, or OI-J descriptor evidence.

`oi-live-nonzero-memory-atomic-boundary` is implemented as an OI-specific smoke transform. It guards `memory.size != 0`, then performs a reachable `i32.atomic.load8_u` from byte 0 and drops the result, using i32 operands for memory32 and i64 operands for memory64-only modules. The runner forwards this id to compare-pass for OI-G rows that list it. The first grouped count-120 run samples ten atomic cases with eight matches and two known store-mask low-byte-mask residuals; both tools keep the same atomic-load opcode count. The later grouped count-130 run samples the atomic-load transform ten times and all ten match. It is atomic-load evidence only, not broader atomic RMW/cmpxchg, store-address commutation, randomized-address, trap-order, or family closure.

`oi-live-nonzero-memory-atomic-rmw-boundary` is implemented as an OI-specific smoke transform. It guards `memory.size != 0`, then preserves byte 0, byte 16, and byte 32768 while executing atomic store8 of the currently loaded byte, no-op full/narrow i32/i64 `atomic.rmw.add`/`sub`/`or`/`xor` variants with value 0, no-op full/narrow i32/i64 `atomic.rmw.and` variants with all-ones values, and i32/i64 `atomic.rmw.cmpxchg` with expected/replacement 0, using i32 operands for memory32 and i64 operands for memory64-only modules. It also computes dynamic end byte `memory.size * 65536 - 1` and emits byte-width store8/load8, i32/i64 `atomic.rmw8` add/sub/or/xor by zero, i32/i64 `atomic.rmw8.and` by all-ones, and i32/i64 `atomic.rmw8.cmpxchg` 0->0 there so the last-byte probe does not introduce full-width alignment traps. The runner forwards this id to compare-pass for OI-G rows that list it. The first grouped count-130 run samples ten atomic RMW/store cases and all ten match, with zero validation/generator/property/command failures and zero canonical size-losing failure dirs. The refreshed `.tmp/oi-g-live-atomic-rmw-end-byte-count130-20260628` run keeps the byte-0/byte-16/byte-32768/dynamic-end-byte transform at 10/10 matches, compares 130/130 with 108 normalized matches and 22 mismatches, and has zero validation/generator/property/command failures or canonical size-losing failure dirs. This is fixed-address plus single dynamic end-byte no-op integer atomic store/RMW/cmpxchg evidence, not xchg, wait/notify, randomized multi-memory atomic ordering, live trap-order, or OI-G closure.

`oi-live-nonzero-memory-fill-restore-boundary` is implemented as an OI-specific smoke transform. It guards `memory.size != 0`, then performs a reachable length-1 `memory.fill` that restores byte 0 from its current value plus a byte load/drop, using i32 operands for memory32 and i64 operands for memory64-only modules. The runner forwards this id to compare-pass for OI-G rows that list it. The first grouped count-84 run sampled ten fill-restore cases with eight matches and two memory64 offset-folding/raw residual mismatches; it is live nonzero fill/read evidence, not broader atomics, randomized-address, trap-order, or family closure.

`oi-live-nonzero-memory-mid-fill-restore-boundary` is implemented as an OI-specific smoke transform. It guards `memory.size != 0`, restores byte 32768 with a reachable length-1 `memory.fill` using the current byte value, and load/drops the same address, using i32 operands for memory32 and i64 operands for memory64-only modules. The runner forwards this id to compare-pass for OI-G rows that list it. The first grouped count-100 run samples ten mid-fill cases with five matches, one direct-tiny offset-folding/raw residual at canonical parity, and four known store-mask low-byte-mask Starshine-win candidates; it is fixed-address page-middle fill/read evidence, not randomized-address, atomics, trap-order, or family closure.

`oi-live-nonzero-memory-end-fill-restore-boundary` is implemented as an OI-specific smoke transform. It guards `memory.size != 0`, computes the last byte address as `memory.size * 65536 - 1`, performs a reachable length-1 `memory.fill` restoring that byte from its current value, and load/drops the same address, using i32 operands for memory32 and i64 operands for memory64-only modules. The runner forwards this id to compare-pass for OI-G rows that list it. The first grouped count-91 run exposed ten canonical size-losing raw `memory.size * 65536` residuals; a red-first raw mul-to-shl fix removed those size losses. The post-fix count-91 run samples ten end-fill cases with six matches and four offset-folding/raw residual mismatches at canonical parity; it is live nonzero nonzero-address fill/read evidence, not atomics, full randomized-address, trap-order, or family closure.

`oi-call-ref-target-wrapper` is implemented as an OI-specific smoke transform. It appends a private no-op function/type plus a declarative element segment and prepends direct `ref.func` / `call_ref`, block-returned target, typed-select target, and dead `call_ref` shells before each previously defined function. The runner forwards this id to compare-pass for rows that list it; this is first OI-H target-wrapper coverage, not family signoff. A one-case default GenValid compare smoke produced one raw mismatch with no validation/generator/command failures, so the result is open OI-H parity evidence. The first `pass-oi-call-ref` compare smoke hit a generator failure from a wasm-tools-invalid base module; that was narrowed to stringref/exn value types leaking into the wasm-tools oracle lane and fixed by keeping stringref behind const-expression-rich profiles and exnref behind tag-enabled profiles. The fixed seed-0x5eed `pass-oi-call-ref` + `oi-call-ref-target-wrapper` smoke now compares 1/1 with 1 raw mismatch and 0 validation/generator/property/command failures. Its representative first exposed a size-losing OI-H parity gap: Binaryen directized the synthetic direct `ref.func` / `call_ref` wrappers to direct calls, leaving 0 `call_ref` opcodes in normalized WAT; Starshine initially left 40 `call_ref` opcodes and 25 `ref.func` occurrences, with Starshine raw output over 12KB vs Binaryen 554 bytes. The raw skip path now has focused red-first coverage for adjacent `ref.func`, block-returned `ref.func`, constant-select `ref.func`, single-use `local.set(ref.func)` / `local.get` call_ref/return_call_ref pairs, guaranteed `ref.null; ref.as_non_null` trap tails, dropped result blocks whose body is already unreachable, dropped null `ref.test` / nullable `ref.cast`, and dropped non-null `ref.cast` trap tails before skip. The fresh `.tmp/oi-call-ref-target-wrapper-compare-smoke-ref-null-cast-trim2` representative still mismatches, but the sampled OI-H target spelling and sampled GC cast/test debris have been eliminated: Starshine and Binaryen both have `call_ref=0`, `return_call_ref=0`, `table.get=0`, 20 direct `call $5` occurrences, `ref.test=0`, `ref.cast=0`, `br_on_cast=0`, `br_on_cast_fail=0`, and five `unreachable` roots; both raw outputs validate. Starshine raw size is now 572 bytes vs Binaryen 554 bytes, so the remaining size-losing diff is local-section / dropped-`ref.func` output shape drift, not another sampled `call_ref` target-wrapper miss. A grouped OI-H count-3 sweep at `.tmp/oi-h-target-wrapper-grouped-sweep-20260627` then exercised `oi-call-ref-target-wrapper`, `oi-local-carried`, and `oi-effectful-sibling` together. It compared 3/3 with three raw mismatches and no validation/generator/property/command failures, but every sampled Starshine and Binaryen output had `call_ref=0`, `return_call_ref=0`, and `table.get=0`; `--summarize-existing` now groups those cases as `transform:oi-call-ref-target-wrapper`, `transform:oi-local-carried`, and `transform:oi-effectful-sibling`. The target-wrapper group remains local-section/dropped-`ref.func` drift, while the local-carried and effectful-sibling groups are cross-family dropped-null/local-section and effectful-if/scalar spelling drift after successful call_ref cleanup. Future OI-H work should run broader table-state, `return_call_ref`, argument-localization, multivalue, and effect/trap target-boundary sweeps, while OI-I/OI-J and OI-F/OI-D work should use grouped sweeps to classify their own live reference/effect/scalar residuals beyond these fixed sampled OI-H target forms.

`oi-tuple-selected-lane` is implemented as an OI-specific smoke transform. It appends a multivalue block type returning `i32`, `i64`, `f32`, and `f64`, adds one scratch local per lane to each defined function, and prepends stack-neutral multivalue block / lane-store / selected-lane `local.get` / `drop` shells for each selected lane. The runner forwards this id to compare-pass for OI-M rows that list it; this is first OI-M machine-generated selected-lane coverage, not tuple-scratch family signoff. A one-case `pass-oi-tuple` compare smoke compared 1/1 and found 1 raw mismatch with 0 validation/generator/property/command failures. The representative is now classified in the matrix as a sampled Starshine-win candidate for this pure synthetic shell: Binaryen scalarizes through straight-line locals, Starshine keeps nested block-result expressions, Starshine canonical wasm is 4100 bytes vs Binaryen 4326 bytes (-226), raw wasm is 3975 vs 4229 bytes (-254), and both outputs validate. Future OI-M work should upgrade it from synthetic constants and scratch locals to existing-producer tuple wrappers, selected trapping lanes, multi-result effectful/trapping siblings, and trigger-biased `pass-oi-tuple` constructors. All first-layer OI-specific transform ids plus the current live-nonzero OI-G follow-ups are now implemented; future design-only `oi-*` ids should remain filtered until their MoonBit transform exists.

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

1. use the runner `Result summaries` / `--summarize-existing` output to classify OI-D/OI-E/OI-G/OI-I raw mismatch dirs mechanically by `genValidProfileCaseLabel`, then scale `pass-oi-default-scalar` / `pass-oi-local-facts` / `pass-oi-memory-bulk` / `pass-oi-ref-gc` from deterministic seed-indexed trigger smokes into randomized direct scalar identities, type-specific local-carried/local.tee, local-mask, commuted-operand, memory wrappers, branch-cast, and direct reference wrappers around existing producers;
2. split a true OI-J descriptor/exactness/TNH/IIT profile or oracle path from the current non-descriptor `pass-oi-ref-gc` smoke so grouped OI-J sweeps no longer rely on descriptor-bearing modules that wasm-tools rejects or on non-descriptor OI-I evidence;
3. `pass-oi-boolean-select` with if/select wrappers around existing producers plus typed effectful/trapping/no-fold condition siblings beyond the current synthetic if/select and private-global effect smoke transforms;
4. `pass-oi-call-ref` scale-up and trigger hardening: the seed-0x5eed stringref/exn oracle validity blocker is fixed, but OI-H still needs existing-producer/table/local target wrappers, `return_call_ref`, argument localization, multivalue variants, and effect/trap target-boundary cases beyond the current private no-op target smoke transform;
5. `pass-oi-memory-bulk` next should keep reducing/classifying the remaining grouped count-264 mismatches after the raw ordered const eq/ne, multi-memory/random-address/cross-memory/memory64-cross-memory generator-breadth, raw div/rem-by-zero, raw constant-offset, live atomic-load, live no-op atomic store/RMW/cmpxchg, dynamic end-byte copy/read, dynamic interior-address copy/read, non-primary-memory copy/read, and memory64-compatible private cross-copy slices, then broaden the generator/transform scheduler again with randomized memory64/multi-memory wrappers, commuted store/address operands, broader atomic variants/wait/notify, source-visible cross-memory mutation with restore if provably safe, true live memory/trap-order evidence, and tiny copy/fill variants beyond the current smoke transforms; keep the store-mask residuals classified as sampled low-byte-store Starshine-win candidates with raw-byte residual and reopen them on validation, truncation-contract, raw-byte-parity, or canonical size-regression evidence; and
6. `pass-oi-tuple` with trigger-biased selected-lane constructors, existing-producer tuple wrappers, and effect/trap sibling variants beyond the current synthetic multivalue selected-lane smoke transform.

Those target the current highest-churn areas: scalar/default rewrites, boolean/select shells, memory-size boundaries, and tuple selected-lane boundaries.
