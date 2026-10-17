---
kind: workflow
status: supported
last_reviewed: 2026-10-15
sources:
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tuple_alias_captures.mbt
  - ../../../../../src/validate/gen_valid_tuple_alias_captures_wbtest.mbt
  - ../../../../../src/fuzz/main.mbt

---

# `tuple-optimization` Fuzzing Profile

## October 15 callable aggregate renewal

Native `5d8ea74e` and generator `76b922fb` complete 10,000
`tuple-optimization-all` comparisons against verified Binaryen 133 at root
`0x5eed`. All 10,000 original/Starshine/Binaryen runtime observations agree;
none is blocked. Byte determinism, codec idempotence and the separate
semantic-idempotence property pass all 10,000. Validation, property, generator
and command failures are zero. There are 2,225 normalized matches and 7,775
structural differences; all raw outputs are smaller, with 7,775 smaller and
2,225 equal repository-canonical outputs. No canonical size loss is observed.

The manifest reports 2,095 input hash identities. Its 6,692 ordinary cases use
three callable literal templates: 3,339 spill, 1,161 tee and 2,192 copy-chain.
The 3,308 alias cases contribute 2,092 reported identities across trailing,
prefix and chain copies. Raw totals are 1,108,274/1,209,862 bytes and
repository-canonical totals 1,165,590/1,271,862 (Starshine/Binaryen). The
retained review reads 20 mismatch bundles; it does not individually read the
7,755 suppressed mismatch bodies or the 2,225 matched bodies.

The ordinary spill, tee and copy-chain generator cases now export `run` and
return both i32/i64 lanes. Their bodies execute in this campaign. This closes
the historical exportless ordinary-body observation limit below. It does not
make their fixed literal templates effectful or wide. Separate regression and
runtime lanes retain those requirements.

All 20 retained bundles have a source/dataflow review and independent expected
results. Four inspected mismatch families remove redundant local traffic while
preserving captured payloads and exact lane order; measured raw/canonical size
and local-operation counts improve. These are reviewer classifications for the
inspected families. A separate replay validates 80 input/Starshine/Binaryen/
Starshine-second-pass modules and checks 200 expected calls. Saved observations
provide another 138 checked calls. Those counts are separate from the 10,000
campaign cases; they do not inspect every suppressed raw output.

Local evidence root: `.tmp/report-optimization-20261014/`. Exact source and
binary identity are in `native-shared-work-reuse/`; generated cases and final
counters are in `fuzz-shared-work-reuse-20261015/tuple-optimization/`. Review,
raw audit and replay records are `review/tuple-shared-work-current-gpt.txt`,
`review/tuple-shared-work-retained-audit.json` and
`review/tuple-shared-work-retained-replay.{mjs,json}`. The permanent Tuple lane
passes 17,080 independent comparisons, including effects, host exceptions and
mixed numeric lanes. The later-delta Claude review returns only a usage-limit
response and remains incomplete.


## October 15 callable ordinary lane fixtures

The spill, copy-chain and tee fixtures previously had no exports or start and
returned no values. Their Node-v2 all-equal reports checked instantiation only.
The historical `972c897d` campaign retains that exact generator and scope. Separate
retained-body probes execute all20 saved bundles with independent contracts;
this does not repair missing execution of unretained bodies in that campaign.

Three new [generator tests](../../../../../src/validate/gen_valid_tuple_observable_lanes_wbtest.mbt)
fail on the original missing exports. The generator now retains each original
carrier and drop trigger, appends reads of the final i32/i64 lanes, and exports
`run` with those two results. Dedicated configuration allows two results and
nine spill statements. Profile labels, aggregate weights, seeds and alias-capture
behavior remain unchanged. All179 selected generator controls pass. At that checkpoint a new native
build and separate full aggregate remained required. The callable renewal
above completes that work for `5d8ea74e`; the old campaign must not be
presented as a callable-body campaign.


> **Current comparison baseline — October 14, 2026:** new comparisons use [Binaryen 133](../../release-horizon-and-oracles.md). The v131 and v132 results below retain their original versions and do not establish v133 signoff.

## October 14 loop alias capture profile

The `tuple-optimization-all` aggregate now includes
`tuple-optimization-alias-captures` at weight `3`. The existing spill, copy-chain,
and tee weights remain `3`, `2`, and `1`. This additive leaf is also available
through the ordinary profile-name lookup and all-profiles selection.

The leaf emits two exported integer functions. Both repeat a type-indexed
two-lane producer in a loop with distinct changing lane values. `snapshot`
captures the first producer values once and reads them after later producer
executions. `delayed` copies the previous capture before each new capture; its
first result is the locals' initial zero values. Seeds select prefix, trailing,
or two-hop alias copy layouts. Each captured/output lane has one lexical write;
extra local initializers would hide the stale alias trigger. Host arguments are
bounded to `1..4` iterations with `(argument & 3) + 1`.

The manifest retains `selected_profile` and uses these case labels:

- `tuple-optimization:alias-captures-prefix`
- `tuple-optimization:alias-captures-trailing`
- `tuple-optimization:alias-captures-chain`

The leaf excludes imports, calls, memory, tables, globals, GC, and traps. The
separate [V8 runtime lane](../../../../../scripts/test/tuple-alias-capture-runtime.ts)
covers initial parameter values, effect order, traps, mixed lanes, and repeated
cleanup pipelines. The [generator tests](../../../../../src/validate/gen_valid_tuple_alias_captures_wbtest.mbt)
check replay, valid modules, exact labels, bounded execution, old captures,
zero-before-capture behavior, and one lexical write per lane. These checks do
not replace a fresh v133 aggregate comparison.

Use the aggregate for ordinary dedicated-profile signoff; use the alias leaf
for targeted reproduction:

```sh
moon build --target native --release src/cmd
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-all-v133 --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --wasm-opt-bin <verified-v133-wasm-opt> --require-binaryen-version 133 --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Source: [alias generator](../../../../../src/validate/gen_valid_tuple_alias_captures.mbt)
and [profile mapping and weights](../../../../../src/validate/gen_valid.mbt).

The September 10 baseline was Binaryen 132. It superseded earlier baseline
wording at that time; the following results are historical evidence.

## September 11 shared capture renewal

Remote local-lifetime fixes introduce complete tuple captures before overlapping
local writes. The upgrade regression checks distinct values in all three lanes,
including a swapped copy-back. Same-lane copy-backs are recognized only with a
single definition, a direct matching source payload, and a bounded straight-line
root interval with no conflicting write. Reads of the replacement carrier are
refreshed only when they follow their original definition and feed later scalar
writes in the same region. This prevents lowering a read before its replacement
definition; the failed version returned `[42, 0, 202]`.

Native `7738a54f…` completes two renewed 10,000-case campaigns: the DAE2 tuple
member and the ordinary `tuple-optimization-all` aggregate. Both have 10,000
original-primary Bun/JavaScriptCore runtime matches, deterministic reruns and
codec roundtrips, with zero validation, command, generator or property failures.
All 10,000 outputs in each lane are canonically smaller than Binaryen. The
ordinary aggregate is also smaller in all raw outputs; the DAE2 tuple lane has
8,750 smaller and 1,250 larger raw outputs. Balanced capture cleanup closes the
5,000 canonical size losses found in the earlier renew18 tuple lane. Single
producer evaluation, overlapping local writes and distinct weighted lane values
remain the transform contract behind these size measurements.

The tuple member now also varies label metadata on both overlap forms. A focused
regression exposed stale label indices after DAE2 removed a tuple forwarding
block. Cleanup drops label names from changed functions and retains names for
unchanged functions. The generator and four-pass metadata regression pass; fresh
native comparison of these named variants is in progress. Exact evidence lives
in the [upgrade ledger](../../../raw/binaryen/2026-09-10-v132-validation.json).

Sources: [implementation](../../../../../src/passes/tuple_optimization.mbt),
[tests](../../../../../src/passes/tuple_optimization_wbtest.mbt),
[GenValid](../../../../../src/validate/gen_valid_dae2.mbt), and
[runtime comparisons](../../../../../scripts/test/binaryen132-lifetime-runtime.ts).

## 2026-09-01 candidate-free raw-gate renewal

The rebuilt release-native Starshine binary and explicitly required Binaryen v131 compare clean on regular GenValid: `.tmp/pass-fuzz-tuple-final-clean-regular-10000-20260901` is `10000/10000` normalized, with zero mismatches, validation failures, property failures, generator failures, or command failures. Raw totals are 42,190,083 Starshine versus 42,157,334 Binaryen bytes, while canonical bytes are exactly equal in every case.

The dedicated `.tmp/pass-fuzz-tuple-final-clean-dedicated-10000-20260901` lane completes all 10,000 cases with zero validation/property/generator/command failures and the same previously classified pure/drop-only scalar-spelling differences. Starshine is smaller in every case: raw totals are 495,472 versus 625,980 bytes and canonical totals are 419,104 versus 629,164 bytes. This lane proves that the raw classifier still admits the spill, tee, and copy-chain producer families; its mismatches remain the existing measured Starshine-win output-shape family, not a new normalization rule.

The production artifact remains byte-identical at SHA-256 `4b616a392d85a2c2dbf52ea08b27ad99cc07351a166838c0eaab2d9d6733d172`, and `[P0-WALL-TUPLE]` is now closed by the one-warmup/three-sample `897.562ms` no-trace command median against the `<=1.053s` absolute gate.

## 2026-09-01 shared HOT lower renewal

The rebuilt explicit current native binary and `.tmp/binaryen-version-131-bin/bin/wasm-opt` compared `10000/10000` regular GenValid cases at seed `0x5eed` with `--jobs auto`, `--max-subprocesses 8`, and `--max-mismatch-artifacts 20`. All 10,000 are normalized matches with zero mismatches, validation failures, property failures, generator failures, or command failures. Raw totals are `42,190,083` Starshine versus `42,157,334` Binaryen bytes (`2,967` equal and `7,033` Starshine-larger spelling cases), while canonical totals are exactly equal at `42,157,334` bytes in every case. Binaryen cache is `2/9998` hits/misses. Evidence: `.tmp/pass-fuzz-tuple-hot-lower-suffix-20260901/`.

This lane validates the shared future-dependency suffix index used by HOT lowering. It did not change the dedicated pure/drop-only scalar-spelling classification below and did not close `[P0-WALL-TUPLE]` at that checkpoint; the later candidate-free raw-gate renewal above supersedes that status and closes the production gate.

## Binaryen v131 spot renewal

The July 28, 2026 explicit-v131 renewal used the rebuilt `_build/native/release/build/cmd/cmd.exe` and `.tmp/binaryen-version-131/bin/wasm-opt`, verified as `wasm-opt version 131 (version_131)`:

- `.tmp/pass-fuzz-tuple-v131-spot-post-rebase-ordinary-1000`: `1000/1000` exact normalized matches, zero mismatches/failures, Binaryen cache `1000/0` hits/misses;
- `.tmp/pass-fuzz-tuple-v131-spot-post-rebase-dedicated-100`: `100/100` known raw scalar-spelling differences, zero validation/property/generator/command failures, selected/profile counts spill `41`, tee `15`, copy-chain `44`, Binaryen cache `100/0`.

Every dedicated input has zero call, memory, table, global, exception, atomic, unreachable, and trap facts. Starshine is smaller in all 100 cases: spill is uniformly `-22` encoded bytes, while tee and copy-chain are uniformly `-20`. This is the same narrow pure/drop-only measured-win family approved by the 2026-06-30 closeout, not a new v131 gap.

The owner file is unchanged from v130. The four dedicated-lit deltas are bottom-valued `local.tee` to `local.set` finalization in unreachability cases; a focused source-WAT probe confirms Binaryen's new text, while binary reparse reduces both outputs to the same valid 30-byte `unreachable` function. The renewal therefore closes without implementation work.

Recommended smoke lane: run the ordinary GenValid compare-pass lane for this pass:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profiles now exist for this pass:

- `tuple-optimization-spill`
- `tuple-optimization-copy-chain`
- `tuple-optimization-tee`
- `tuple-optimization-alias-captures`
- `tuple-optimization-all`

The aggregate profile emits type-indexed multivalue block carriers and spills/copies/tees tuple lanes through locals. The manifest `profile_case_label` is expected to be one of:

- `tuple-optimization:spill`
- `tuple-optimization:copy-chain`
- `tuple-optimization:tee`
- `tuple-optimization:alias-captures-prefix`
- `tuple-optimization:alias-captures-trailing`
- `tuple-optimization:alias-captures-chain`

Recommended dedicated smoke lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-profile --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Final 2026-06-30 closeout lanes are recorded in [research note 1387](./index.md): regular GenValid `100000 / 100000` normalized with zero failures; wasm-smith `9956 / 10000` compared with one unreachable-control-debris raw mismatch and `44` Binaryen/tool command failures, then zero mismatches under `--normalize unreachable-control-debris`; dedicated `tuple-optimization-all` `10000 / 10000` raw-red with zero failures and selected/profile-case counts spill `5030`, tee `1674`, copy-chain `3296`; random all-profiles `10000 / 10000` normalized with zero failures. The dedicated lane remains intentionally raw-red but is classified as the narrow simple type-indexed pure/drop-only scalar-spelling Starshine-win family: all `10000` cases have zero effect/trap facts and Starshine is uniformly smaller/fewer locals/fewer effective WAT ops in every profile family.

Initial count-30 profile smoke on 2026-06-29 generated and validated all cases but produced `30 / 30` normalized mismatches, split across spill `12`, copy-chain `14`, and tee `4`. A follow-up count-6 smoke after manifest plumbing produced `6 / 6` normalized mismatches with zero validation/generator/command/property failures and recorded profile-case counts (`tuple-optimization:spill` `4`, `tuple-optimization:tee` `2`) in `result.json`/`cases.jsonl`. Later type-indexed spill and tee scalarization slices removed raw tuple/block carriers from the simple spill and host-tee cases, but the count-30 dedicated smoke still reports `30 / 30` normalized mismatches because residual scalar temp/tee/copy spelling differs from Binaryen. The post-tee count-30 smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-host-tee-simple-payload` compared `30 / 30` with zero validation/generator/command/property failures and still found `30` mismatches; measured deltas were spill `+2` Starshine raw bytes but `-2` locals / `-3` ops per case, tee `+1` raw byte but `-2` locals / `-4` ops, and copy-chain `-4` raw bytes / `-6` locals / `-10` ops. The next drop-only type-indexed lane slice kept the dedicated profile raw-red but moved every sampled family to a raw-size/local/op win: `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-30-drop-only-split` compared `30 / 30` with zero validation/generator/command/property failures and `30` mismatches; spill cases are now `-3` Starshine raw bytes, `-2` locals, and `-5` ops each, tee cases `-4` raw bytes, `-2` locals, and `-6` ops each, and copy-chain cases remain `-4` raw bytes, `-6` locals, and `-10` ops each. A follow-up residual-spelling inspection classifies only this exact simple, pure, drop-only count-30 surface as a narrow measured Starshine-win scalar spelling family with reopening criteria; it does not turn the dedicated profile into green closeout evidence.

A broader count-100 dedicated smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-smoke-100-broader-bin` stayed in the same family: `100 / 100` compared, zero validation/generator/command/property failures, `100` raw mismatches, selected profiles spill `41`, tee `15`, and copy-chain `44`. Agent inspection found no effect/trap facts, float payloads, or raw Starshine tuple/block carrier debris. Deltas remained uniform: spill `-3` raw / `-11` normalized / `-2` locals / `-5` ops each, tee `-4` / `-12` / `-2` / `-6`, and copy-chain `-4` / `-20` / `-6` / `-10`. Treat this profile as an audit-driver for reducing or classifying current tuple scalarization parity gaps, not as green closeout evidence yet.

After adding TO detail performance timers, a general direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-100-detail-timers` compared `100 / 100`, with `100` normalized matches, zero mismatches, zero validation/generator/property/command failures, and Binaryen cache hits/misses `0 / 100`. The later root-slot lookup performance slice raised the ordinary direct smoke to `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-root-slot-hint`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache hits/misses `100 / 900`. These lanes guard that performance instrumentation/lookup changes did not perturb ordinary direct-pass behavior; they are not closeout replacements for the required full lanes.

The root-slot lookup slice also reran a bounded dedicated raw-red profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-root-slot-hint`. It stopped at the mismatch cap after `65 / 100` compared, with zero validation/generator/property/command failures, `65` raw mismatches, selected profiles spill `26`, tee `10`, copy-chain `29`, and profile labels spill `26`, tee `10`, copy-chain `29`. This is still the known simple scalar-spelling residual surface and does not broaden the narrow Starshine-win classification.

The pure drop-only elision slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-drop-only-elide-batched-mark`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. The bounded dedicated raw-red lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-drop-only-elide-batched-mark` stopped at the mismatch cap after `65 / 100` compared, with zero validation/generator/property/command failures, `65` raw mismatches, selected profiles and labels spill `26`, tee `10`, copy-chain `29`. Local measurement over those 65 failure dirs found uniform Starshine raw-size/op wins: spill averaged `-22` raw bytes / `0` locals / `-11` effective WAT ops, tee `-20` / `0` / `-10`, and copy-chain `-20` / `0` / `-10`. This keeps the classification narrow to simple pure/drop-only scalar spelling; broader type/lane/effect/non-drop surfaces remain unclassified.

The detached replacement-delete performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-detached-delete-timers`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. The bounded dedicated raw-red lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-detached-delete-timers` stopped at the mismatch cap after `65 / 100` compared, with zero validation/generator/property/command failures, `65` raw mismatches, selected profiles and labels spill `26`, tee `10`, copy-chain `29`. This is the same known scalar-spelling residual surface and is not final closeout evidence.

A follow-up root-removal performance experiment was reverted because per-group root splicing regressed candidate-heavy timings. After reverting that experiment and rebuilding native Starshine, `.tmp/pass-fuzz-tuple-optimization-genvalid-100-root-remove-rejected-baseline` compared `100 / 100`, normalized `100`, had zero validation/generator/property/command failures, and Binaryen cache `100 / 0`. This is a small regression guard for the reverted experiment only, not a replacement for the ordinary or final closeout lanes.

The scalarized tuple-local cleanup fast-skip slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-scalarized-cleanup-fast-skip`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. This guards that the cleanup pre-scan/use-def-skip did not perturb ordinary direct-pass behavior; it is not a replacement for the required final closeout lanes.

The aggregate rewrite-timer slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-aggregate-rewrite-timers`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-aggregate-rewrite-timers`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, selected/profile labels spill `33`, tee `12`, copy-chain `35`. Agent classification: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this timing-emission slice does not broaden the residual classification and is not a replacement for the final closeout lanes.

The pass-level batched root-removal slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-batched-root-removal`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-batched-root-removal`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, selected/profile labels spill `33`, tee `12`, copy-chain `35`. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this performance slice does not broaden the residual classification and is not a replacement for the final closeout lanes.

The rewrite use-def reuse slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-use-def-reuse`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-use-def-reuse`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, selected/profile labels spill `33`, tee `12`, copy-chain `35`. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this performance slice does not broaden the residual classification and is not a replacement for the final closeout lanes.

The targeted root-removal / fast root-region replacement slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-fast-root-replace`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-fast-root-replace`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`, and all input effect/trap counts zero. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this performance slice does not broaden the residual classification and is not a replacement for the final closeout lanes.

The elision-mask performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-elide-mask`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-elide-mask`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this performance slice does not broaden the residual classification and is not a replacement for the final closeout lanes.

The source-only/no-copy fast-path performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-source-fast-mask`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-source-fast-mask`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this performance slice does not broaden the residual classification and is not a replacement for the final closeout lanes.

The payload-facts performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-payload-facts`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-payload-facts`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`, and zero effect/trap counts. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this performance slice does not broaden the residual classification and is not a replacement for the final closeout lanes.

The no-tee cleanup performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-tee-cleanup-fast`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-tee-cleanup-fast`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this performance slice does not broaden the residual classification and is not a replacement for the final closeout lanes.

The no-new-local cleanup performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-new-local-fast`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-new-local-fast`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this cleanup fast path does not broaden the residual classification and is not a replacement for the final closeout lanes.

The no-scalarized-prescan cleanup performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-scalarized-prescan-fast`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-scalarized-prescan-fast`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`, and zero input effect/trap counts. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this cleanup fast path does not broaden the residual classification and is not a replacement for the final closeout lanes.

The local-set root fast-path performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-local-set-root-fast`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-local-set-root-fast`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`, and zero input effect/trap counts. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this rewrite fast path does not broaden the residual classification and is not a replacement for the final closeout lanes.

The no-result-link fast-path performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-result-fast`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-result-fast`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`, and zero input effect/trap counts. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this analysis/linking fast path does not broaden the residual classification and is not a replacement for the final closeout lanes.

The no-scalar-forward fast-path performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-scalar-fast`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-scalar-fast`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`, and zero input effect/trap counts. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this scalar-forward link/rebuild fast path does not broaden the residual classification and is not a replacement for the final closeout lanes.

The no-copy-payload fast-path performance slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-no-copy-fast`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-no-copy-fast`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`, and zero input effect/trap counts. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this exact-copy-link fast path does not broaden the residual classification and is not a replacement for the final closeout lanes.

The simple drop-only root-elision fast-path slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-root-elision-fast`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-root-elision-fast`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`, and zero input effect/trap counts. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this direct root-elision fast path does not broaden the residual classification and is not a replacement for the final closeout lanes.

The pre-collect root fast-path slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-precollect-root-fast-final`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-precollect-root-fast-final`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this pre-collect/direct root validation performance slice does not broaden the residual classification and is not a replacement for final closeout lanes.

The direct root fast-path slice reran the ordinary direct smoke at `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-direct-root-fast`: `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `1000 / 0`. It also reran a bounded dedicated profile lane at `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-direct-root-fast`: stopped at the mismatch cap after `80 / 100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80 / 0`, selected/profile labels spill `33`, tee `12`, copy-chain `35`. Agent classification is unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this direct no-seed-group-allocation performance slice is superseded by the final closeout lanes above.

See [research note 1358](./index.md), [research note 1359](./index.md), [research note 1360](./index.md), [research note 1361](./index.md), [research note 1362](./index.md), [research note 1363](./index.md), [research note 1364](./index.md), [research note 1365](./index.md), [research note 1366](./index.md), [research note 1367](./index.md), [research note 1368](./index.md), [research note 1369](./index.md), [research note 1370](./index.md), [research note 1371](./index.md), [research note 1372](./index.md), [research note 1373](./index.md), [research note 1374](./index.md), [research note 1375](./index.md), [research note 1376](./index.md), [research note 1377](./index.md), [research note 1378](./index.md), [research note 1379](./index.md), [research note 1380](./index.md), [research note 1381](./index.md), [research note 1382](./index.md), [research note 1383](./index.md), [research note 1384](./index.md), and [research note 1385](./index.md), and [research note 1386](./index.md).

### September 11 capture renewal

Native `7738a54f…` completes 10,000 `dae2-tuple-results` comparisons after the
balanced stack-capture repair. All 10,000 outputs are canonically smaller than
Binaryen; 8,750 are also raw-smaller and 1,250 raw-larger. All 10,000 independent
Bun/JavaScriptCore observations, deterministic replays and codec roundtrips pass,
with no validity, generator, command or property failures. This supersedes the
prior 5,000 canonical size losses. The agent classification is a measured
canonical-size win for these generated families, supported by the single-
evaluation contract and observable producer/consumer state. The separate
`tuple-optimization-all` aggregate also completes 10,000 comparisons with all
outputs smaller in both raw and canonical encoding, all runtime observations
matching, and no failures. See the
[upgrade ledger](../../../raw/binaryen/2026-09-10-v132-validation.json).
