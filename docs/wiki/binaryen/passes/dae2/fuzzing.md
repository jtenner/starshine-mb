---
kind: workflow
status: working
last_reviewed: 2026-10-04
sources:
  - ./starshine-strategy.md
  - ../../../../../src/ir/hot_lift_typed_block_entry_wbtest.mbt
  - ../../../../../src/cmd/dae2_typed_block_entry_wbtest.mbt
  - ../../../tooling/tracing-playbook.md
  - ../../../../../src/validate/gen_valid_dae2.mbt
  - ../../../../../src/validate/gen_valid_dae2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt
  - ../../../tooling/pass-fuzz-compare.md
  - ../../version-132-upgrade.md
---

# DAE2 GenValid coverage

## October 4 typed-block bounded renewal

Native `5bf4a1f5…` repairs concrete typed-block entry lowering and discarded
entry-effect duplication, while restoring compact branchless output. The
[repair dossier](./starshine-strategy.md#october-4-2026-retain-typed-block-entry-producers)
records RED tests, rejected native trials, 13,549 wasm-gc tests and original /
verified 133 execution for 27 fixtures per pass (434 validations and 1,272
supported side-observation comparisons across all four consumers).

This candidate has no new 10,000-case aggregate signoff. Long randomized and
aggregate renewal remains deferred under the active campaign's
[execution priority](../../../../../agent-todo.md). Existing dated aggregates
below retain their original binary hashes and do not sign this source. The
separate valid stack-polymorphic typed-entry lift failure, residual output
parity/size gaps and all four 1× targets remain open. Continue to use the
published aggregate profiles, explicit fresh native binary and verified v133
oracle when final renewal resumes.

## September 27 follow-up allocation campaign renewal

The [final follow-up report](../../../tooling/tracing-playbook.md#september-27-2026-follow-up-pass-allocation-campaign)
uses native CLI `6610a792ef8d07151ee38bd6c6fbfe82097086e4f50f6dfd3902eecacb00320e`,
verified Binaryen 133, seed `0x5eed`, eight subprocesses and 10,000 cases
per listed aggregate. It supersedes pending renewal for the follow-up
allocation changes and earlier current-baseline wording. New evidence
requires verified v133; older dated results retain their original scope.

| Lane | Aggregate | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | --- | ---: | ---: | ---: | ---: |
| `dae2` | `dae2` | 2,879 / 667 | 6,454 | 0 | 9,312 / 688 |
| `dae2-closed` | `dae2` | 0 / 100 | 9,900 | 706 | 9,312 / 688 |
| `dae2-optimizing` | `dae2` | 2,233 / 0 | 7,767 | 0 | 9,312 / 688 |

Validation, generator, property-counter, command and observed Starshine/
original semantic failures are zero. Blocked runtime cases remain unverified.
The report owns exact commands, normalizers, cache use, size-loss and retained
baseline replays, downstream evidence and agent classifications. Residual
parity/size gaps are not closed by validation or smaller output alone.

Local results: `.tmp/pass-perf-next-20260927/final-fuzz-dae2/result.json`, `.tmp/pass-perf-next-20260927/final-fuzz-dae2-closed/result.json`, `.tmp/pass-perf-next-20260927/final-fuzz-dae2-optimizing/result.json`.

## September 27 performance-campaign renewal

The [shared final campaign](../../../tooling/tracing-playbook.md#september-27-2026-precompute-cleanup-and-pass-allocation-campaign)
uses native CLI `5d009c4396b65d613acdc187e443f6c2cee843c7bfbc48ee726ba633de2aac54`,
verified Binaryen 133, seed `0x5eed`, `--jobs auto --max-subprocesses 8` and 10,000 cases
per lane. It supersedes earlier current-baseline wording; historical v131/v132
results retain their original scope. The shared report owns exact profiles,
normalizers, cache use, runtime limits, size deltas and baseline replays.

| Lane | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | ---: | ---: | ---: | ---: |
| `dae2` | 2,879 / 667 | 6,454 | 0 | 9,312 / 688 |
| `dae2-closed` | 0 / 100 | 9,900 | 706 | 9,312 / 688 |
| `dae2-optimizing` | 2,233 / 0 | 7,767 | 0 | 9,312 / 688 |

All listed lanes report zero validation, generator, property, command and observed
Starshine/original semantic failures. Runtime-blocked cases remain unverified;
shape/size classifications and any scoped exceptions are agent judgments in
the shared report, not conclusions implied by validation or normalization.

Local reports: `.tmp/pass-perf-campaign-20260927/final-fuzz-dae2/result.json`, `.tmp/pass-perf-campaign-20260927/final-fuzz-dae2-closed/result.json`, `.tmp/pass-perf-campaign-20260927/final-fuzz-dae2-optimizing/result.json`.

## September 26 final allocation/indexing renewal

The [final shared campaign](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal)
uses frozen native CLI `da5f112b6bbf092476d2d6ac6694128e19adca3d288003526ab01c3e0b0bfcbb`,
verified Binaryen 133 and 10,000 cases per documented aggregate at seed `0x5eed`.
The shared record owns exact commands, profiles, normalizers, cache counts,
runtime limits and baseline replays. This supersedes earlier current-baseline
wording; historical v131/v132 results keep their original scope.

| Lane | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | ---: | ---: | ---: | ---: |
| `dae2` | 2,879 / 667 | 6,454 | 0 | 9,312 / 688 |
| `dae2-closed` | 0 / 100 | 9,900 | 706 | 9,312 / 688 |
| `dae2-optimizing` | 2,233 / 0 | 7,767 | 0 | 9,312 / 688 |

All listed lanes report zero validation, generator or command failures and no
observed Starshine/original semantic mismatches. Cases blocked on the original
input remain unverified.
Residuals remain open parity gaps; canonically larger outputs remain quality
gaps even when cleanup normalization matches. Valid or smaller output alone is not an accepted win. Saved residuals and all canonically larger
cases reproduce the starting compiler bytes, as recorded in the shared replay.

Local reports: `.tmp/pass-perf-work-20260926/final4-fuzz-dae2/result.json`, `.tmp/pass-perf-work-20260926/final4-fuzz-dae2-closed/result.json`, `.tmp/pass-perf-work-20260926/final4-fuzz-dae2-optimizing/result.json`.

## September 26 shared source-order renewal

Fresh native `f7fb87fb1a66416d87a018b78fcd8fddf2f58a110d77f982c56434cd1a3bbaf9` renews 10,000 `dae2` aggregate comparisons in each world against the same verified Binaryen 133 oracle and settings below. Open counts remain 2,879 canonical / 667 cleanup-normalized / 6,454 residuals; closed counts remain 0 / 100 / 9,900, including 706 canonically larger outputs. Each world again has 9,312 Node-v2 matches and 688 original-runtime-blocked continuation cases, with zero semantic mismatches or validation, property, generator or command failures. The 12,476-test full suite passes. Residual parity and closed-world size gaps remain open; blocked runtime cases remain unverified.

Evidence: `.tmp/pass-fuzz-dae2{,-closed}-coalesce-source-order-v133-10000-20260926/`. The [shared renewal](../coalesce-locals/fuzzing.md#september-26-source-order-index-renewal) owns the other affected lanes and saved-output replay; the [strategy](./starshine-strategy.md#september-26-2026-shared-source-order-index) records the confirmed 15.7% large-artifact improvement.

## September 26 lazy local-flow renewal

Fresh native Starshine `0925e7e8ae15e1e06d4fa171fdcf5b251e42f68f627ef7955a10bf032570748f` renews both 10,000-case `dae2` aggregate lanes against the same verified v133 oracle, seed, worker limits, normalization and Node-v2 settings below. Counts are unchanged: open 2,879 canonical / 667 cleanup-normalized / 6,454 residual; closed 0 / 100 / 9,900, including 706 canonically larger outputs. Each world has 9,312 runtime matches and 688 original-runtime-blocked cases, with zero semantic mismatches or validation, property, generator or command failures. All 40 saved residual outputs are byte-identical to the pre-change CLI. My classification remains open parity gaps, including the 706 size-losing closed-world cases; blocked executions remain unverified.

All 12,470 default wasm-gc tests pass. Evidence: `.tmp/pass-fuzz-dae2-lazy-flow-{open,closed}-v133-10000-final-20260926/`, `.tmp/dae2-lazy-flow-replay/result.json`, and `.tmp/dae2-lazy-flow-full-tests-final-20260926.log`. The [strategy page](./starshine-strategy.md#september-26-2026-lazy-local-flow-analysis) records the 10–29% dedicated-fixture gains and neutral large-artifact repeat; this renewal does not close the overall performance gap.

## September 26 unchanged-function relift renewal

Verified Binaryen 133 (`8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`) and fresh native Starshine `b084365e0bd4b2bc98457da7eb8773504b5cf2720665dea7ae5b961d30c41a06` renew the `dae2` aggregate in both worlds, 10,000 comparisons each at seed `0x5eed`. The explicit native CLI and generator use eight subprocesses, `--jobs auto`, at most 20 mismatch artifacts, the default cache, `drop-consts` and `unreachable-control-debris` normalization, and `--semantic-oracle node-v2`. No external generator was requested.

| World | Canonical matches | Cleanup-normalized | Residuals | Canonically larger | Node-v2 matches | Runtime blocked |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Open | 2,879 | 667 | 6,454 | 0 | 9,312 | 688 |
| Closed | 0 | 100 | 9,900 | 706 | 9,312 | 688 |

Both lanes have zero semantic mismatches, validation, property, generator or command failures. The 688 blocked cases per world remain original-runtime-blocked continuation cases. All 40 saved raw residuals reproduce byte-for-byte against the pre-change CLI. My classification retains the residuals as parity gaps and the 706 closed-world larger outputs as size-losing gaps; passing runtime cases and normalization do not close those transform/size differences.

Evidence: `.tmp/pass-fuzz-dae2-relift-{open,closed}-v133-10000-final-20260926/` and `.tmp/dae2-relift-replay/result.json`. The [strategy page](./starshine-strategy.md#september-26-2026-skip-unchanged-rewrite-lifts) records source reasoning, red-first tests, isolated speedups and the 1.2% all-changing synthetic slowdown. Historical v132 results below retain their original version and scope.

The aggregate profile is **`dae2`**. This supersedes the June 16 note that no
dedicated profile existed. Its fourteen members cover forwarded results,
parameter/result cycles, control flow, argument effects, whole result tuples,
tail calls, indirect calls, open-world signatures, reference types, overwritten
locals, continuation signatures, multiple exception handlers, `call_ref`, and
`call.without.effects` intrinsic restrictions.

The `dae2-locals` member includes compiler-derived lifetime cases: a one-arm
conditional tail assignment before a later parameter tee; a conditional observer
before an exported-global write; and a pointer derived from an allocation result
before its header store. The observers expose arguments and global state, and the
allocation case exposes returned pointers and memory. Dropped results or unused
arguments remain real DAE2 opportunities. Seeds `0, 6, 12, 18` cover the two
conditional forms; `3, 15, 27, 39` cover bounded allocation addresses.
`simplify-locals-all` also samples this leaf. See the
[reduced runtime fixtures](../../../../../tests/fixtures/simplify-locals/) and
[generator assertions](../../../../../src/validate/gen_valid_dae2_wbtest.mbt).

Each member is also available as `dae2-<family>`; exact spellings and seeded
membership live in [the registry](../../../../../src/validate/gen_valid.mbt).
The bounded default tests validate four seeds per member and run both open- and
closed-world DAE2. Full comparison campaigns belong in the dedicated fuzz lane.

Build explicit native tools, then run at least 10,000 comparisons per world:

```sh
moon build --target native --release src/cmd
moon build --target native --release src/fuzz
bun fuzz compare-pass --count 10000 --min-compared 10000 --seed 0x5eed   --pass dae2 --gen-valid-profile dae2 --require-binaryen-version 133   --wasm-opt-bin .tmp/v133-signoff-oracles/binaryen-version_133/bin/wasm-opt   --starshine-bin _build/native/release/build/cmd/cmd.exe   --gen-valid-bin _build/native/release/build/fuzz/fuzz.exe   --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20   --normalize drop-consts --normalize unreachable-control-debris   --out-dir .tmp/dae2-v133-open
```

Repeat with `--closed-world` and a separate output directory. For an intake run
that must visit every case despite shape mismatches, set `--max-failures 10001`;
this changes the stopping budget, not the signoff requirements. Inspect every
result counter and classify residual differences. The process exit code alone
is not a parity verdict.

Run the original/Starshine/Binaryen execution lane with
`--semantic-oracle node-v2`. Continuation or other unsupported runtime slices
must remain explicitly blocked. A passing structural validator is not runtime
evidence. Cycles generated by this profile have a live bounded countdown.

Binaryen 132 registers `dae2` only. Starshine's `dae2-optimizing` runs real DAE2
followed by `simplify-locals` and `vacuum`; the comparison adapter supplies that
same three-pass sequence upstream. It is not an alias for ordinary DAE.

The runtime adapter implements `binaryen-intrinsics.call.without.effects` by
calling its final function-reference argument with the preceding arguments.
That intrinsic itself adds no imported-call event; effectful argument calls
remain observable. Ordinary imports with a matching field name retain ordinary
stub behavior. V128 intrinsic crossings are explicitly runtime-unverified.
The semantic cache includes the revised execution contract, so reports from the
old import-stub adapter cannot suppress fresh execution on unchanged Wasm bytes.
Vacuum removes unused intrinsic results while preserving arguments, and removes
unused function declarations only when no reference or element-index use remains.

Campaign hashes, classifications, measurements and outstanding failures belong
in [the upgrade evidence](../../version-132-upgrade.md). Initial implementation
and bounded tests do not establish 10,000-case signoff.

Tuple cases vary whether neither, either, or both result lanes are used. Their
producer and consumer increment exported state; exception cases also expose
handler effects. Pure fixtures cannot establish that a pass preserved call
count. The initial September 10 open/closed 10,000-case runs preceded these
observable fixtures and subsequent fixes; they are diagnostic evidence, not
final signoff for the revised implementation. Repeat both lanes on fresh binaries.

The locals member also varies conditional assignments inside value-producing
control and stack captures combining `memory.size`, `local.tee` and a later
load. The effectful-argument member holds a memory read across a clobbering call.
These are reduced compiler-runtime failures, not only opportunities for smaller
signatures. Both result values and exported state matter to the oracle.

Tuple generation also includes nested tuple-producing `if` expressions with
reads before writes in their arms. Both lane consumers refer to one evaluation
of the producer. LocalGraph tests require the read to retain its incoming
source without inventing a self-backedge from a second traversal of that tuple.
This regression also guards against exponential analysis on nested tuples.

Resumed `node-v2` runs now require the same semantic execution contract in
`toolchain.json`, in addition to the existing Binaryen identity. Old observations
from the pre-intrinsic adapter require a new output directory, even when the
Wasm bytes are unchanged. This prevents completed journal rows from bypassing
the semantic-cache contract check.

The September 11 aggregate seed correction separates leaf selection from body
seed bits. A bounded aggregate test now requires both ordinary effectful
arguments and memory reads held across clobbering calls. Prior aggregate runs
selected only the former; retain their results as coverage of their exact inputs
and renew both worlds before claiming the broader family is exercised.

The tuple member also varies three-lane captures whose destinations overlap a
source local. Same-lane and swapped copy-backs use distinct seeded values and a
weighted consumer, with an exported producer-call counter. The producer has an
unused parameter, so these are positive signature-removal cases. Run this member
through `tuple-optimization` as an additional shared-lowering regression lane.
The bounded generator test checks both variants and their declared result/local
budgets; broad comparison results must be renewed after this addition.

The continuation member varies ordinary index declarations and typed `funcref`
expression declarations. Declaration-only entries authorize `ref.func` validation
without exposing a runtime reference; actual continuation construction, body
references and concrete typed declarations still constrain signatures. The
suspend-only variant exercises positive signature pruning. Parser and pass tests
cover both forms independently.

The September 11 capture regression checks repeated `dae2-optimizing` runs on a
`memory.size` / tee / load expression. Balanced single-use captures are removed
after the cleanup sequence, and unused locals and their names are compacted with
one index map. This bounds scratch-local growth without moving evaluations or
cloning a multi-result producer. Native aggregate renewal follows this repair.

### September 11 renewed aggregate evidence

Native `7738a54f…` completes 10,000 cases in each of open-world DAE2,
closed-world DAE2, and `dae2-optimizing`. Each lane has 9,312 independent
Bun/JavaScriptCore observation matches and 688 explicit continuation execution
exclusions; validity, determinism and codec checks pass for all 10,000.
No generator, command or property failures remain. The 730 legacy multi-handler
cases still incur canonical size losses (`+2` closed, `+8` open, `+11` optimizing)
from HOT's single-handler representation and its `try_table` adaptation. These
remain a concrete representation gap, not an accepted size win. Native `91301a24…` renews `dae2-optimizing` with 7,137 canonically smaller,
2,133 equal and 730 larger outputs. This closes all 199 continuation-allocation
and tuple-wrapper size losses from the preceding checkpoint. The 730 remaining
larger outputs are the legacy handler family above. All 9,312 supported runtime
comparisons still match; continuation execution remains unsupported.

The tuple member now alternates label metadata on both overlap forms. Positive
regressions require valid named inputs and valid outputs through DAE2, its
optimizing variant, tuple optimization and instruction optimization. When tuple
forwarding cleanup removes labels, it removes stale label names only for the
changed functions. Native aggregate renewal for these named variants is in
progress. Exact counters,
hashes and prior evidence remain in the [upgrade ledger](../../../raw/binaryen/2026-09-10-v132-validation.json).

### September 15 local exception dispatch repair

Red-first dispatch and unused-void-wrapper regressions now pass for both DAE2
variants. Saved legacy exception case 29 is smaller at raw, canonical and
common-Oz stages with matching executed return and global effects against
verified v132. This supersedes that case's loss; historical aggregate counts
remain pending renewal. See [proof, sizes and guards](../../../ir2/architecture-rules.md#dae2-known-local-exception-dispatch-repair).

### September 15 continuation observations

[Four configured Node suspend observations and the verified v132 interpreter regression](../../../ir2/architecture-rules.md#continuation-runtime-observation-renewal)
renew the five saved continuation blockers with explicit engine-specific scope.
The resume-throw case is checked only with the verified interpreter.

### Existing duplicate-signature repair

Fresh raw section inspection identifies retained identical simple signatures in
the intrinsics, call-ref and open-world families. Four pass and four dispatcher
regressions fail before cleanup: both variants retain two void signatures on
unchanged and rewritten paths. Both DAE2 exits now reuse guarded type-only
canonicalization; local grouping is not involved. All 62 DAE2 pass tests pass.
An earlier indirect-call regression now compares actual callee/call-site types
and their retained i32 parameter instead of assuming duplicate slots survive.
Recursive, shared, subtyping and legacy graphs retain the existing guard.

### Effectful-argument result-wrapper repair

After signature rewriting, DAE2 flattens branchless result wrappers through
the existing label-aware lowering cleanup. The red-first pass and dispatcher
fixture preserves all three imported producer calls, their order and the sink
call while requiring removal of the unnecessary block. All 63 DAE2 pass tests
pass, including EH, indirect-call identity and argument-effect regressions.
Final fuzz renewal is explicitly deferred at the user's request.

### September 16 current-source renewal

The [final-source renewal](../../../ir2/architecture-rules.md#september-16-final-source-fuzz-renewal)
supersedes pending aggregate-renewal notes above. Fresh native binaries and
verified Binaryen 132 complete the following comparison checks:

- `dae2`: 10,000 compared; 2,879 normalized and 667 cleanup-normalized matches; 6,454 residuals; 567 raw-larger and zero canonical-larger outputs.
- `dae2-optimizing`: 10,000 compared; 2,233 normalized and 0 cleanup-normalized matches; 7,767 residuals; 624 raw-larger and zero canonical-larger outputs.

There are zero output-validation or command failures. The full default suite
passes 12,030 tests. Runtime properties were off; retained raw losses remain
parity gaps and existing semantic classifications are not broadened by size
alone. Commands, binary hashes, family counts and exclusions are in the linked
renewal record.

### September 16 scalar/declaration size follow-up

The shared scalar-add guard follow-up passes all 12,036 default tests. Fresh
native comparison repeats this dossier's preceding dedicated/ordinary lane
counts and size totals unchanged, with zero output-validation or command
failures and zero canonical size losses. Existing input-validator and runtime
limits remain unchanged.
Current binary hashes, per-lane cache/profile counts and scoped judgments are
in the [size follow-up report](../../../ir2/architecture-rules.md#september-16-further-oi-size-reductions).
