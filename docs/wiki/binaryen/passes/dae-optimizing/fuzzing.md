---
kind: workflow
status: supported
last_reviewed: 2026-09-16
sources:
  - ../../../ir2/architecture-rules.md
  - ../../../raw/research/1654-2026-07-19-daeo-stable-callsite-uniform-actuals.md
  - ../../../raw/research/1653-2026-07-19-daeo-unified-call-facts-tail-boundaries-and-filtered-validation.md
  - ../../../raw/research/1652-2026-07-19-dae-incoming-liveness-written-constants-and-bottom-results.md
  - ../../../raw/research/1651-2026-07-19-daeo-block-fallthrough-validation-and-local-cleanup.md
  - ../../../raw/research/1650-2026-07-18-daeo-broad-boundary-and-uniform-constant-parity.md
  - ../../../raw/research/1629-2026-07-16-daeo-direct-gc-batch-performance.md
  - ../../../raw/research/1628-2026-07-16-daeo-unbounded-convergence-batching-checkpoint.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../dead-argument-elimination/fuzzing.md
---

# `dae-optimizing` Fuzzing Profile

## September 13 touched-local cleanup

The [parity follow-up](../../../ir2/architecture-rules.md#september-13-parity-follow-up)
adds fixed-point unread-local cleanup to functions touched by the committed DAE
boundary rewrite before the nested roster. Dead copies and scratch storage
collapse while effectful/trapping producers stay in place. Explicit mutation
flags avoid NaN equality as a convergence test; actual rewrites clear stale
local-name metadata. Failing-first direct/pipeline and bounded NaN regressions
cover the repair. The ledger records the fresh `dae-optimizing` 10,000-case
aggregate with both required cleanup normalizers and original/Starshine/oracle
runtime comparisons. Historical matrices below keep their original versions
and artifact-specific open work.


> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Dedicated profile

The pass-owned GenValid aggregate is `dae-optimizing`. The aliases `dae-optimizing-closeout`, `dae-optimizing-all`, and `dae-optimizing-all-profiles` select the same aggregate.

The aggregate has 15 weighted leaves:

| leaf | generated ownership surface |
|---|---|
| `dae-optimizing-core` | private helper boundary rewrite plus ordinary touched-function cleanup |
| `dae-optimizing-many-touched` | more than eight independently changed functions |
| `dae-optimizing-medium-module` | modules above the old 100-function cleanup guard |
| `dae-optimizing-large-locals` | changed functions above the old 128-local guard |
| `dae-optimizing-touched-caller` | material callers whose callsite changes without a signature change |
| `dae-optimizing-forwarded-suffix` | stack-carried older arguments plus an exact final constant suffix |
| `dae-optimizing-result-control` | removed results followed by structured branch cleanup |
| `dae-optimizing-structured-locals` | copy, sequential coloring, loop copy, branch result, `if` result, tee chain, and nested-block local cleanup |
| `dae-optimizing-return-cleanup` | dead suffixes after an explicit return |
| `dae-optimizing-immutable-field` | immutable global struct-field folding, null exposure, and downstream callee specialization |
| `dae-optimizing-computed-effects` | pure computed actuals plus effectful/trapping replay through `global.set`, `memory.grow`, and loads |
| `dae-optimizing-table-effects` | `table.grow` effects and `table.get` bounds traps |
| `dae-optimizing-gc-computed` | `struct.new`, `array.new`, `array.new_default`, and `array.new_fixed` actuals |
| `dae-optimizing-tail-boundary` | direct tail-call bailout behavior |
| `dae-optimizing-type-reuse` | compacted function-signature reuse and conservative mixed type-section repair |

The structured-local and GC-constructor subcases derive their selector from an independent GenValid stream seed rather than raw `seed % n`; this keeps aggregate coverage deterministic without correlating subcases with aggregate member selection. The manifest records both `selected_profile` and a stable `profile_case_label`, and focused tests require every leaf and every structured/GC subcase to appear in a bounded aggregate sample.

Use the DAE cleanup normalizers on all generated DAEO lanes:

```sh
--normalize drop-consts --normalize unreachable-control-debris
```

These normalizers cover only the documented dropped-constant and unreachable/control debris families. Any remaining mismatch still requires an agent semantic, size, validity, or tool-failure classification.

Recommended dedicated closeout lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --gen-valid-profile dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-profile-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

## Required closeout matrix

Report these independently with a freshly built explicit native binary:

1. regular GenValid: `100000`, seed `0x5eed`;
2. explicit wasm-smith: `10000`, seed `0x5eed`, `--wasm-smith`;
3. dedicated `dae-optimizing`: `10000`, seed `0x5eed`;
4. `random-all-profiles`: `10000`, seed `0x5555`.

For each lane report requested/compared counts, normalized and cleanup-normalized matches, raw mismatches, validation/generator/property failures, command-failure classes, cache counters, and selected subprofile counts when available.

## Fresh current evidence

The August 12, 2026 refresh after the medium-module dropped-result fallback and guarded plain-inlining work uses native SHA-256 `04c07833321cb6b6013f3ae2cbba4dc692ea802ff6f5a04810b2640120768c10`, explicit verified Binaryen v131, both DAE normalizers, `--jobs auto`, persistent cache, and no reduction. The dedicated aggregate at `.tmp/pass-fuzz-dae-optimizing-profile-10000-o4z-fallback-complete-20260812` compares `10000/10000`: `6954` normalized matches, `0` cleanup-normalized matches, `3046` residuals, and zero validation/generator/property/command failures. Binaryen cache is `10000` hits / `0` misses with no cached failures. All 15 aggregate leaves and all structured-local/GC subcases are represented.

The harness does not classify the `3046` residuals. Saved-artifact inspection groups them exactly into immutable-field `931`, computed-effects `886`, forwarded-suffix `634`, and touched-caller `595`. Every Starshine raw and canonical output is smaller; aggregate raw/canonical delta is `-37,910` bytes, with zero equal-size or size-losing residual. These are the same source-backed transform contracts previously classified as Starshine cleanup wins: effects and traps are replayed in source order, while dead boundary/local transport is removed. This is a fresh dedicated-profile refresh, not a replacement for the unchanged July 21 four-lane closeout matrix.

The July 20, 2026 Binaryen-v131 direct closeout uses native Starshine SHA-256 `95daa8811dceffee74da3082cfb765e17b2d7497db27aa54090ccb94fce42e8c` and explicit `.tmp/binaryen-version-131-bin/bin/wasm-opt`:

| lane | requested / compared | exact | cleanup-normalized | residuals | failures |
|---|---:|---:|---:|---:|---:|
| regular GenValid | `100000 / 100000` | `100000` | `0` | `0` | `0` |
| dedicated `dae-optimizing` | `10000 / 10000` | `6365` | `0` | `3635` classified Starshine wins | `0` |
| explicit wasm-smith | `10000 / 9956` | `9955` | `1` | `0` | `44` Binaryen-only tool failures |
| random-all | `10000 / 10000` | `9243` | `62` | `695` classified Starshine wins | `0` |

Dedicated residuals are exactly five generated families: immutable field `931`, computed effects `886`, forwarded suffix `634`, touched caller `595`, and table effects `589`. Every canonical wasm output is smaller for Starshine; aggregate canonical delta is `-33,568` bytes, with no equal-size or size-losing case.

Random-all residuals are coverage-forced-portable `174`, precompute-propagate local facts `106`, DAE effectful args `88`, computed effects `74`, immutable field `58`, forwarded suffix `54`, table effects `52`, touched caller `49`, and localization `40`. Every residual is canonically smaller for Starshine; aggregate canonical delta is `-603,405` bytes. The `44` wasm-smith command failures are entirely Binaryen-v131 oracle failures: rec-group-zero `39`, invalid tag index `1`, table index out of range `1`, and bad section size `3`. There are zero Starshine validation, generator, property, command, size-losing, unknown/risky, or true-semantic residuals. Artifacts are under `.tmp/dae-v131-closeout-*20260720/` and remain local.

Research note [`1654`](../../../raw/research/1654-2026-07-19-daeo-stable-callsite-uniform-actuals.md) adds a focused Binaryen-v131 exact regression for active uniform actual `7` plus inactive conflicting actual `8`; both tools remove the parameter and emit the same `call; unreachable` shape. Direct Starshine execution over the first `128` targeted inputs completes without command stderr or per-case timeout. Two outer-time-limited compare attempts stopped at `95` compared cases with `72` matches, `23` prior-family differences, and zero reported failures; those partial runs are diagnostic and do not replace the complete lane below.

Research note [`1653`](../../../raw/research/1653-2026-07-19-daeo-unified-call-facts-tail-boundaries-and-filtered-validation.md) is the current complete targeted Binaryen-v131 checkpoint. It adds unified stable callsite/function facts, repairs direct tail-callee ownership, extends incoming-value liveness through restricted call-free `try_table` exceptional edges, and batches touched HOT candidate-context validation with independent invalid-function rollback. The current lane is `.tmp/pass-fuzz-daeo-unified-tail-eh-filtered-v131-1024-20260719`:

- requested/compared: `1024/1024` at seed `0x5eed`;
- exact normalized matches: `823`;
- cleanup-normalized matches: `0`;
- remaining normalized differences: `201`;
- validation/generator/property/command failures: `0/0/0/0`;
- Binaryen cache hits/misses: `1024/0`;
- all 15 leaves, all seven structured-local subcases, and all four GC-constructor subcases were emitted.

Relative to note `1652`, the direct-tail repair converts `128` mismatches to exact matches with zero regression. The harness itself does not classify the `201` residuals. Saved-artifact inspection identifies exactly three measured Starshine-win families:

| family | count | raw delta | canonical delta |
|---|---:|---:|---:|
| computed effects | 83 | `-1826` | `-830` |
| table effects | 58 | `-464` | `-464` |
| touched caller cleanup | 60 | `-830` | `-830` |
| total | 201 | `-3120` | `-2124` |

Every residual is smaller for Starshine. Computed/table cases preserve each effectful or trapping removed actual in source order while deleting the unused boundary parameter; touched-caller cases delete only proved dead local-copy traffic. Forwarded-suffix and immutable-field residuals now match Binaryen exactly. This is targeted generated parity-or-better evidence, not final pass closeout.

The 2026-07-21 final Binaryen-v131 matrix uses native SHA-256 `100397722893a76c76a3d3eed486e38c60df932b4b73da36574d35d17112520f`, explicit official v131, both cleanup normalizers, `--jobs auto`, persistent cache, and no-reduction counted mode. Plain DAE is: regular `100000/100000` exact; dedicated `5000` exact + `5000` previously classified smaller/equal-size fewer-local Starshine wins; wasm-smith `9956/9956` exact comparable with only the known `44` Binaryen failures; random-all `8521` exact + `62` cleanup-normalized + `1417` previously classified wins. DAEO is: regular `100000/100000` exact; dedicated `6365` exact + `3635` previously classified wins; wasm-smith `9955` exact + `1` cleanup-normalized with the same `44` Binaryen failures; random-all `9243` exact + `62` cleanup-normalized + `695` previously classified wins. Every lane has zero Starshine validation, generator, property, or command failure and no new/unclassified residual family.

The retained plain artifact is valid/idempotent at `2,991,169` bytes, with `85.329s` / `64.277s` medians and a `-9,670` canonical delta against Binaryen. DAEO is valid/idempotent at `2,991,168` bytes with `25.440s` / `21.475s` medians; its raw delta is `-70,900`, while the canonical `+4,318` shared nested local-layout/remap family is assigned to neighboring local-cleanup owners in the de-artifacting inventory.

Research note [`1652`](../../../raw/research/1652-2026-07-19-dae-incoming-liveness-written-constants-and-bottom-results.md) remains the preceding source slice. Its accepted `.tmp/pass-fuzz-daeo-hot-liveness-unprofitable-v4-v131-1024-20260719` result was `695/329` with zero failures. Two rejected coarse throttle experiments produced `658/366`; unrestricted optimizing HOT liveness exposed the same 37-case regression, led by case `63`, and remains narrowed to written params. Plain DAE's accepted correct-profile smoke remains `.tmp/pass-fuzz-dae-hot-liveness-unprofitable-v131-1024-correct-20260719` at `512/512` with zero failures. The later `.tmp/pass-fuzz-dae-unified-tail-eh-v131-1024-20260719` attempt has `128` Binaryen command failures and is not accepted renewal evidence.

The July 17 direct-closeout record is the authoritative prior four-lane closeout. A freshly relinked explicit native binary at SHA-256 `3180bb10194a19fff1c939beee4d6d2b20f1f830aee0be34fa7e37e1097f55fa` and explicit Binaryen v130 produced: regular `.tmp/pass-fuzz-daeo-closeout-regular-100000-v130-20260717` `100000/100000` normalized; dedicated `.tmp/pass-fuzz-daeo-closeout-dedicated-10000-v130-20260717` `10000/10000` normalized; wasm-smith `.tmp/pass-fuzz-daeo-closeout-wasm-smith-10000-v130-20260717` `9955` normalized plus `1` cleanup-normalized out of `9956`, with only the unchanged `44` Binaryen/oracle failures; random-all `.tmp/pass-fuzz-daeo-closeout-random-all-10000-v130-20260717` `9633` normalized plus the exact same `367` earlier measured/source-backed cleanup wins. The `367` failure-directory names and all `3670` files are byte-identical to the prior reviewed corpus, with aggregate Starshine deltas `-110224` raw / `-797486` canonical / `-5465849` WAT and no canonical/WAT-positive case. All lanes use both DAE cleanup normalizers, `--jobs auto`, the explicit native binary, and the default persistent cache. There are no unknown/risky, generated size-losing, Starshine-validation, or true-semantic residuals. This closeout was current for the then-tested behavior and is historical after later changes; new comparisons use Binaryen 132, while public optimize/shrink/O4z artifact blockers remain separate.

The retained Func 8185 immutable-field-delay evidence records the focused immutable-field-delay smokes with explicit native SHA-256 `20a36db6f8b546a1571533dd134cbc2bed244b5aebb4b8323f63e6967db5dcc5`: dedicated `.tmp/pass-fuzz-dae-optimizing-field6-final-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-field6-final-regular-1000` each compare and normalize `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property/command failures and Binaryen cache `1000/0`. Both use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. These focused smokes accompany valid byte-identical first/second artifact outputs, canonical Func `8185` body `2462` matching the direct no-structure/vacuum probe, and a canonical-module gap of `+1498`; they do not replace the required four-lane closeout matrix.

The retained Func 8184 null-guard/call-argument evidence records the focused Func-`8184` smokes with explicit native SHA-256 `73f86497e49a958d15e7c1d2824086688c43742e1cc67a3b05dcc2b51596679a`: dedicated `.tmp/pass-fuzz-dae-optimizing-func8184-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-func8184-regular-1000` each compare and normalize `1000/1000`, with zero compare-normalized matches, mismatches, validation/generator/property/command failures and Binaryen cache `1000/0`. Both use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. These focused smokes accompany valid byte-identical first/second artifact outputs, exact canonical Func `8184` body parity at `11`, and a canonical-module gap of `+1500`; they do not replace the required four-lane closeout matrix.

The retained Func 8186 final-return evidence records the focused final-return smokes with explicit native SHA-256 `91310f086edec4263c6496e9599579c8cf6674186b9de939bb4fcdd0a676576c`: dedicated `.tmp/pass-fuzz-dae-optimizing-final-return-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-final-return-regular-1000` each compare and normalize `1000/1000`, with zero compare-normalized matches, mismatches, validation/generator/property/command failures and Binaryen cache `1000/0`. Both use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. These focused smokes accompany valid byte-identical first/second artifact outputs, exact canonical Func `8186` body parity at `10`, and a canonical-module gap of `+1516`; they do not replace the required four-lane closeout matrix.

The retained Func 8185 dead-result-store evidence records the focused never-read-result-store smokes with explicit native SHA-256 `23753ece5222807f661a13ef1cd3e14519b2db33ec35d28cd1b26ca707766a94`: dedicated `.tmp/pass-fuzz-dae-optimizing-dead-result-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-dead-result-regular-1000` each compare and normalize `1000/1000`, with zero compare-normalized matches, mismatches, validation/generator/property/command failures and Binaryen cache `1000/0`. Both use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. These focused smokes accompany valid byte-identical first/second artifact outputs, canonical Func `8185` body `2464` versus Binaryen's `2429`, and a canonical-module gap of `+1517`; they do not replace the required four-lane closeout matrix.

The retained Func 8185 copy-retarget evidence records the focused copy-producer-retarget smokes with explicit native SHA-256 `afe3fd177be17e180d81eea5c05fccec9806e81826271f3c321456f0409e1784`: dedicated `.tmp/pass-fuzz-dae-optimizing-copy-retarget-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-copy-retarget-regular-1000` each compare and normalize `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property/command failures and Binaryen cache `1000/0`. Both use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. These focused smokes accompany valid byte-identical first/second artifact outputs, canonical Func `8185` body `2466` versus Binaryen's `2429`, and a canonical-module gap of `+1519`; they do not replace the required four-lane closeout matrix.

The retained Func 8185 vacuum-nop evidence records the focused final-`vacuum` nop smokes with explicit native SHA-256 `355e915122fd976198876709798ad9bbfa10ad75eac52085ac8f14bec2716fbf`: dedicated `.tmp/pass-fuzz-dae-optimizing-vacuum-nops-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-vacuum-nops-regular-1000` each compare and normalize `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property/command failures and Binaryen cache `1000/0`. Both use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. These focused smokes accompany valid byte-identical first/second artifact outputs, canonical Func `8185` body `2566` versus Binaryen's `2429`, and a canonical-module gap of `+1639`; they do not replace the required four-lane closeout matrix.

The retained Func 8185 branch-result-if evidence records the focused Func `8185` branch-result-`if` smokes with explicit native SHA-256 `6647b9913d403b170ad2f672198c622382a97e391ba6b48c0c0a62765a7cff37`: dedicated `.tmp/pass-fuzz-dae-optimizing-branch-result-if-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-branch-result-if-regular-1000` each compare and normalize `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property/command failures and Binaryen cache `1000/0`. Both use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. These focused smokes accompany valid byte-identical first/second artifact outputs, a canonical Func `8185` reduction from `2644` to `2590`, exact branch/`unreachable` count closure, and a canonical-module gap of `+1663`; they do not replace the required four-lane closeout matrix.

The retained Func 8185 linear-coalescing evidence records the focused Func `8185` conservative-linear-coalescing smokes with explicit native SHA-256 `9bea4ab087d91d338dff2388a9603a3da505e5d0f52e36aad5fff68e33dddee8`: dedicated `.tmp/pass-fuzz-dae-optimizing-func8185-linear-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-func8185-linear-regular-1000` each compare and normalize `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property/command failures and Binaryen cache `1000/0`. Both use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. These focused smokes accompany valid byte-identical first/second artifact outputs, a canonical Func `8185` reduction from `2716` to `2644`, and a canonical-module gap of `+1717`; they do not replace the required four-lane closeout matrix.

The retained Func 8186 literal-suffix evidence records the focused Func `8186` stack-carried-literal smokes with explicit native SHA-256 `26ed277bff6a886fb199289857ddf18e79d9fb2052f2da53ea15e227841429ec`: dedicated `.tmp/pass-fuzz-dae-optimizing-func8186-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-func8186-regular-1000` each compare and normalize `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property/command failures and Binaryen cache `1000/0`. Both use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. These focused smokes accompany valid byte-identical first/second artifact outputs, a canonical Func `8186` body reduction from `218` to `11`, a secondary Func `8185` reduction to `2716`, and a canonical-module gap of `+1789`; they do not replace the required four-lane closeout matrix.

The retained Func 8185 cleanup/order evidence records the focused Func `8185` productive-cleanup/order smokes with explicit native SHA-256 `68638ed1f1129c93dcb152930173763b467eee1cc7ce60ba342acfe4cb738344`: dedicated `.tmp/pass-fuzz-dae-optimizing-func8185-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-func8185-regular-1000` each compare and normalize `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property/command failures. Binaryen cache hits/misses are `984/16` for the dedicated lane and `0/1000` for regular. These focused smokes accompany valid byte-identical first/second artifact outputs, a canonical Func `8185` body reduction from `2978` to `2748`, and a canonical-module gap of `+2030`; they do not replace the required four-lane closeout matrix.

The retained Func 8187 normalized-literal-chain evidence records the focused Func `8187` completion smokes with explicit native SHA-256 `970bb7456dba663dbd566bbbd789d5543d8eb1960a1fdc44662b56fb2ad030bf`: dedicated `.tmp/pass-fuzz-dae-optimizing-func8187-final-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-func8187-final-regular-1000` each compare and normalize `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, and Binaryen cache `1000/0`. These focused smokes accompany valid byte-identical first/second artifact outputs and a canonical Func `8187` body of `767` versus Binaryen's `961`; they do not replace the required four-lane closeout matrix.

The retained Func 8429 payoff-convergence evidence records the focused Func `8429` completion smokes with explicit native SHA-256 `6057190705590291c3deeca348a48276aa43d7bd9d2980bd3400152f9ba74122`: dedicated `.tmp/pass-fuzz-dae-optimizing-func8429-final-converged-profile-1000` and regular `.tmp/pass-fuzz-dae-optimizing-func8429-final-converged-regular-1000` each compare and normalize `1000/1000`, with zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, and Binaryen cache `1000/0`. These focused smokes accompany valid byte-identical first/second artifact outputs; they do not replace the required four-lane closeout matrix.

Research note [`1629`](../../../raw/research/1629-2026-07-16-daeo-direct-gc-batch-performance.md) records post-fusion smoke evidence with native SHA-256 `ac02b98c3649966b5cacb8c6dbefebb36a4918839131a9ca5368ab84fea2ddb0`: dedicated `.tmp/pass-fuzz-daeo-fused-dedicated-1000-20260716` and regular `.tmp/pass-fuzz-daeo-fused-regular-1000-20260716` each compare and normalize `1000/1000` with zero mismatches or validation/generator/property/command failures and Binaryen cache `1000/0`. These are performance-slice smokes, not replacements for the note-1628 `10000`-case lanes or the required four-lane closeout matrix.

Research note [`1628`](../../../raw/research/1628-2026-07-16-daeo-unbounded-convergence-batching-checkpoint.md) records the post-convergence checkpoint with explicit native Starshine and Binaryen v130: dedicated `.tmp/pass-fuzz-daeo-final-dedicated-10000-20260716` and regular `.tmp/pass-fuzz-daeo-final-regular-10000-20260716` each compare `10000/10000`, normalize all `10000`, and have zero mismatches or validation/generator/property/command failures under both DAE cleanup normalizers. Optimize, shrink, and O4z still run DAEO exactly once and emit the same valid 38-byte dedicated-profile output. This is fresh generated and scheduling evidence, not full closeout: wasm-smith and random-all were not refreshed.

Research note [`1568`](./index.md) records post-tuple-cleanup evidence from native commit `cf08ff06f`:

- dedicated `.tmp/pass-fuzz-dae-optimizing-dedicated-10000-20260713-post-tuple`: `10000/10000` normalized, zero cleanup-normalized matches, mismatches, or failures, selected `dae-optimizing=10000`, Binaryen cache `10000/0`;
- regular `.tmp/pass-fuzz-dae-optimizing-genvalid-100000-20260713-post-tuple`: `100000/100000` normalized, zero cleanup-normalized matches, mismatches, or failures, Binaryen cache `100000/0`.

Research note [`1569`](./index.md) completes the fresh direct matrix:

- explicit wasm-smith requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `1`, mismatches `0`, with `44` Binaryen/oracle tool failures and no Starshine failure;
- random-all requested/compared `10000/10000`, normalized `9633`, left `367` byte-identical previously reviewed residuals (`dae-effectful-args=124`, `coverage-forced-portable=243`), and had zero failures. The two residual families are agent-classified as measured/source-backed Starshine cleanup wins; the aggregate deltas are `-110219` raw, `-797486` canonical, and `-5465849` WAT bytes, with no canonical/WAT-positive case.

Research note [`1582`](./index.md) refreshes scheduled evidence after the current matrix. Dedicated-profile `optimize`, `shrink`, and synthesized O4z each execute DAEO exactly once immediately after late HSO and before `inlining-optimizing`, emit the same valid 38-byte output, and spend `668us`, `665us`, and `733us` in DAEO.

No retained DAEO behavior changed in notes [`1583`](./index.md) and [`1584`](./index.md), so the note `1581` four-lane direct matrix remains current. Note `1583` rejects both a size-losing result-only Func-12293/8429 endpoint and a size-winning but over-target selected-cleanup endpoint. Note `1584` refines scheduled ownership: large `--optimize` stalls in direct `vacuum`, while large `-O4z` stalls earlier in `ssa-nomerge`; neither reaches DAEO.

Research note [`1570`](./index.md) adds post-fix scheduled evidence: public `optimize`, public `shrink`, and synthesized `-O4z` each run DAEO exactly once in the locked late neighborhood and produce the same valid `38`-byte output as Binaryen O4z on the dedicated profile. It also fixes an artifact-discovered scratch-local collision and reruns the dedicated lane at `10000/10000` normalized. The current stripped wasm-gc artifact meets the pass-local ratio target (`9692.498ms` Starshine versus `8083.49ms` Binaryen) but remains blocked at Starshine final validation on nondefaultable GC body-local initialization.

Research note [`1571`](./index.md) refreshes two more lanes with the post-fix native binary SHA-256 `5ee57c2cb70bc0a73faff5831fbc93db45ad3b7f9aac522e6d714f52f4ff50da`:

- regular GenValid `.tmp/pass-fuzz-dae-optimizing-genvalid-100000-post-scratchfloor-20260713`: `100000/100000` normalized, zero mismatches or failures, Binaryen cache `100000/0`;
- explicit wasm-smith `.tmp/pass-fuzz-dae-optimizing-wasm-smith-10000-post-scratchfloor-20260713`: requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `1`, zero mismatches and no Starshine failures; the `44` command failures are the unchanged Binaryen/oracle classes (`rec-group-zero=39`, invalid-tag=1, table-index=1, bad-section-size=3), with caches wasm-smith `10000/0`, Binaryen `9956/0`, and Binaryen failures `44/0`.

Research note [`1572`](./index.md) completes the post-fix matrix with `.tmp/pass-fuzz-dae-optimizing-random-all-10000-post-scratchfloor-20260713`: `10000/10000` compared, `9633` normalized, `367` mismatches, and zero validation/generator/property/command failures. The failure-directory set and all `3670` residual files are byte-identical to the pre-fix lane. The residuals remain exactly `dae-effectful-args=124` and `coverage-forced-portable=243`, with aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes and no canonical/WAT-positive cases. They remain agent-classified measured/source-backed Starshine cleanup wins, not harness claims.

Research note [`1573`](./index.md) fixes a DAEO-owned flattened rec-group type lookup/append correctness bug and reruns the full matrix with native binary SHA-256 `be413f169ff1cc8fc779168c4093fca8291fa86fa7d672d2c2a4bb54fae73c6d`:

- dedicated: `10000/10000` normalized, zero failures;
- regular: `100000/100000` normalized, zero failures;
- wasm-smith: `9955` normalized plus `1` cleanup-normalized out of `9956` comparable cases, zero mismatches and no Starshine failures, with the same `44` Binaryen/oracle failures;
- random-all: `9633` normalized plus the same `367` measured/source-backed Starshine cleanup wins, zero failures, and `0` changed files across `3670` comparisons with the preceding lane.

Research note [`1581`](./index.md) refreshes the full required direct matrix after note `1580` with native SHA-256 `48abcd5da8b92b45423915c0cd70740ff072cd420d21ab76e55ceabb0e5e5812`: dedicated `10000/10000` normalized; regular `100000/100000` normalized; explicit wasm-smith `9955` normalized plus `1` cleanup-normalized out of `9956` comparable cases with the unchanged `44` Binaryen/oracle failures; random-all `9633` normalized plus the same `367` measured/source-backed cleanup wins. The random-all failure-directory set and all `3670` files are byte-identical to the post-recgroup lane, so the `coverage-forced-portable=243` / `dae-effectful-args=124` agent classifications and `-110219` raw / `-797486` canonical / `-5465849` WAT aggregate deltas remain current. There are no unknown/risky, size-losing generated, validation, or true-semantic residuals.

Research notes [`1585`](./index.md) and [`1586`](./index.md) retained new optimizing-only behavior after note `1581`, so that older complete matrix is historical rather than current closeout evidence. Research note [`1587`](./index.md) records the post-change refresh using explicit native SHA-256 `2e69c9602f2fa252f8e7ef13f40659b8cc8e6ef763fb12ab1a3041fd4e1d3905`: dedicated `10000/10000` normalized, regular `100000/100000` normalized, and wasm-smith `9955` normalized plus `1` cleanup-normalized with the unchanged `44` Binaryen/oracle failures. Random-all timed out after `1800s` with only `307/10000` records. Its `12` partial mismatch directories are byte-identical to prior known measured/source-backed cleanup families, but a partial run cannot satisfy closeout. The current required four-lane matrix is therefore incomplete. DAEO also retains a `+14846` canonical artifact gap and pre-slot large optimize/shrink/O4z blockers.

Research note [`1590`](./index.md) supersedes that incomplete matrix after notes [`1588`](./index.md) and [`1589`](./index.md). It records the intermediate complete four-lane matrix before the adjacent-chain behavior landed.

Research note [`1593`](./index.md) is the complete pre-Func-41 matrix after notes [`1591`](./index.md) and [`1592`](./index.md).

Research note [`1599`](./index.md) is the historical adjacent-pair matrix. Research note [`1602`](./index.md) is the historical payoff-order matrix. Research note [`1604`](./index.md) is the historical forwarded-cycle matrix. Research note [`1606`](./index.md) is the historical unread-sink matrix after note [`1605`](./index.md) corrected the computed-zero hypothesis.

Research note [`1607`](./index.md) is the forwarding-component matrix. It closes the named Func `7007` / `7008` / `7010` / `7024` parameter component but leaves a `+32` raw pre-canonical residue.

Research note [`1608`](./index.md) is the grouped-signature matrix. With explicit native SHA-256 `052744e643849edf18f8987497d04922e41d972ba697789fa97250d25f3684fd`, Binaryen v130, and both DAE normalizers: dedicated is `10000/10000` normalized; regular is `100000/100000` normalized; wasm-smith is `9955` normalized plus `1` cleanup-normalized out of `9956` comparable cases with only the unchanged `44` Binaryen/oracle failures; random-all completes `10000/10000` with `9633` normalized and `367` mismatches under `--no-reduce-mismatches --max-failures 10000`. The established `coverage-forced-portable=243` / `dae-effectful-args=124` measured/source-backed Starshine cleanup-win classification has aggregate `-110224` raw / `-797486` canonical / `-5465849` WAT deltas.

Research note [`1609`](./index.md) is the historical post-component coalescing matrix.

Research note [`1610`](./index.md) is the historical function-filtered vacuum matrix.

Research note [`1611`](./index.md) is the historical branch/dead-tee/compaction matrix.

Research note [`1612`](./index.md) is the historical selected copy/readback matrix.

Research note [`1613`](./index.md) is the historical selected aggregate-spill matrix.

Research note [`1614`](./index.md) is the historical selected uniform-null matrix.

Research note [`1615`](./index.md) is the historical terminal-local matrix after Func `7105` reached Binaryen's exact 50-byte, zero-body-local shape.

Research note [`1616`](./index.md) is the historical Type `309` wrapper and first call-result transport matrix.

Research note [`1617`](./index.md) is the historical sibling-terminal transport matrix.

Research note [`1618`](./index.md) is the historical complete-call transport matrix.

Research note [`1619`](./index.md) is the historical complete-carrier cleanup matrix.

Research note [`1620`](./index.md) is the historical remapped-carrier matrix after exact two-producer first-result sinking, exact three-producer paired-result sinking, and typed terminal complete-block carrier sinking.

Research note [`1621`](./index.md) is the historical one-argument/four-argument/identity block-carrier matrix.

Research note [`1622`](./index.md) is the historical paired-store/terminal-call matrix.

Research note [`1623`](./index.md) is the historical single-traversal aggregate-readback matrix.

Research note [`1624`](./index.md) is historical after the next three terminal-call argument transports landed.

The retained 1627 checkpoint records one strict red-first consumed call-argument slot reuse. Its explicit native SHA-256 `fad834ed0d10e25d71f890c4c96afd4e8c0f0db3ec74f533191152c91c892a53` drove the historical Binaryen-v130 final lanes with `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt`: dedicated `10000/10000` normalized; regular `100000/100000` normalized; wasm-smith `9955` normalized plus `1` cleanup-normalized out of `9956`, with only the unchanged `44` Binaryen/oracle failures; random-all `10000/10000` with `9633` normalized and the same `367` mismatches. All `367` failure-directory names, all `3670` saved files, and all `10000` case records were byte-identical to the preceding checkpoint, so the established `coverage-forced-portable=243` / `dae-effectful-args=124` measured/source-backed cleanup-win classification remained unchanged at aggregate Starshine deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes with no positive canonical/WAT case. There were no unknown/risky, generated size-losing, Starshine-validation, or true-semantic generated residuals. Public optimize, shrink, and `--optimize -O4z` executed DAEO exactly once after late HSO and immediately before `inlining-optimizing`; plain `dae` emitted no post-component cleanup. The direct artifact improved to raw `3194703` / canonical `3272193`; CPU-affinity controlled repeats `16611.320ms`, `16706.526ms`, and `16765.932ms` remained below the absolute `17076.04ms` ceiling. Broader terminal/unreachable/dead-suffix aliases tied both endpoints and block-producer reuse regressed both, so the iteration stopped at a concrete same-traversal profitability/evidence blocker. This is historical v130 evidence; the DAEO gap and pre-slot large scheduled blockers remain open under newer current-source signoff.

Research note [`1626`](./index.md) is historical after the consumed-slot reuse in note `1627`.

Research note [`1625`](./index.md) is historical after sinking an exact composite final call argument plus Binaryen-v130 target-first and target-last terminal-call block-result carriers. Explicit native SHA-256 `b5296018f93bb6bde6b2789d6452f2a52038fea95709500ddda40ee3b603cdf4` drives the authoritative final lanes with `WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt`: dedicated `10000/10000` normalized; regular `100000/100000` normalized; wasm-smith `9955` normalized plus `1` cleanup-normalized out of `9956`, with only the unchanged `44` Binaryen/oracle failures; random-all `10000/10000` with `9633` normalized and the same `367` mismatches. All `367` failure-directory names, all `3670` saved files, and all `10000` case records are byte-identical to note `1624`, so the established `coverage-forced-portable=243` / `dae-effectful-args=124` measured/source-backed cleanup-win classification remains unchanged at aggregate Starshine deltas `-110224` raw / `-797486` canonical / `-5465849` WAT bytes with no positive canonical/WAT case. There are no unknown/risky, generated size-losing, Starshine-validation, or true-semantic generated residuals. Public optimize, shrink, and `--optimize -O4z` execute DAEO exactly once after late HSO and immediately before `inlining-optimizing`; plain `dae` emits no post-component cleanup. The direct artifact improves to raw `3194711` / canonical `3272201`; CPU-affinity controlled repeats `16657.065ms`, `16567.610ms`, and `16862.325ms` remain below the absolute `17076.04ms` ceiling. DAEO remains open for the `+9745` canonical gap, unproved selected-function output shapes, and pre-slot large scheduled blockers.
