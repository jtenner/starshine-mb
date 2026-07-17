---
kind: workflow
status: strong
last_reviewed: 2026-07-11
sources:
  - ../../../raw/research/1648-2026-07-17-dce-batch-writeback-and-shrink-vacuum-attribution.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `dead-code-elimination` Fuzzing Profile

Recommended smoke lane for future DCE changes: run the ordinary GenValid compare-pass lane for this pass, adding the documented `local-cleanup-debris` normalizer when the expected raw diff is Starshine-only local/no-op cleanup:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dead-code-elimination --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid profile status: **closed for the current Binaryen `version_130` DCE audit.** The aggregate has twelve leaves; the count-10000 `dead-code-elimination-all` lane completes with every mismatch classified; fixed split-local-set remains green at scale; branch-payload-forwarder plus pure/effectful structured-prefix mismatches are measured Starshine wins; prefix-to-branch-payload is normalized-green; explicit count-10000 wasm-smith, broad random-all-profiles, bounded O4z/neighborhood DCE-slot evidence, and the fresh regular direct count-100000 lane with `local-cleanup-debris` are classified. Legacy `try`, old-EH `pop`/nested-pop, and stack-switching remain documented local representation/tool boundaries with reopening criteria, not hidden parity claims.

`dead-code-elimination-all` now exists as a composite GenValid profile. Its current deterministic leaves are:

- `dead-code-elimination-non-control`: emits a validating `select` whose first unreachable child should preserve an earlier `i32.const`/`drop` prefix and remove the later condition child under Binaryen DCE;
- `dead-code-elimination-block-suffix`: emits a validating `block` with live prefix work, literal `unreachable`, and a dead suffix that Binaryen DCE should trim;
- `dead-code-elimination-if-both-arms`: emits a validating resultful `if` whose then and else arms are both literal `unreachable`;
- `dead-code-elimination-if-condition`: emits a validating stack-polymorphic resultful `if` whose condition is literal `unreachable`, covering Binaryen's v130 unreachable-condition arm-deletion family and Starshine's raw pre-lift repair path;
- `dead-code-elimination-loop-body`: emits a validating `loop` with a literal `unreachable` body;
- `dead-code-elimination-try-table`: emits a validating resultful `try_table` with a literal `unreachable` body and no catches, covering Binaryen's v130 result-voidification plus explicit unreachable-tail shape for this modern EH surface. Focused pass tests also cover the reachable `catch` body-suffix case.
- `dead-code-elimination-try-table-catch-ref`: emits a validating modern-EH `try_table` inside a resultful block, with a `catch_ref` targeting the block label and a dead `ref.null exn` suffix after `throw`. This keeps generated coverage on exnref-carrying catch targets and the raw suffix-trim / type-voidification path added during the focused catch slice.
- `dead-code-elimination-branch-payload-forwarder`: emits a validating nested branch-payload forwarder in a resultful block, where a resultful inner block branches to itself with a `local.get` payload and the enclosing void block forwards that payload to the outer result block. This covers the first generated Starshine-only HOT cleanup family: removing the dead forwarding wrapper / unreachable tail without changing the branch payload.
- `dead-code-elimination-prefix-branch-payload`: emits a validating resultful block with a void prefix block immediately before a branch payload and dead unreachable tail. This covers Starshine's HOT prefix-to-branch-payload folding surface while keeping the generated shape simple enough for focused singleton compare.
- `dead-code-elimination-split-local-set-wrapper`: emits a validating resultful function whose `local.set` value is a nested branch-payload wrapper with local writes and an unreachable tail. This is the generated Starshine-only split `local.set` wrapper leaf. Slice10 exposed a size-losing public-pipeline parity gap; slice11 fixed it, and the count-10000 dedicated lane sampled 809/809 split-wrapper matches.
- `dead-code-elimination-structured-prefix`: emits a validating non-control first-unreachable-root shape with multiple preserved prefixes, including a structured void prefix block, a pure scalar immediately before `unreachable`, and a dead tail. This covers the pure multi-prefix / structured-prefix surface left open by the first non-control raw repair.
- `dead-code-elimination-effectful-structured-prefix`: emits a validating memory module with `memory.grow` and trapping `i32.load` prefixes before a pure scalar, `unreachable`, and a dead tail. This covers the effectful/trapping multi-prefix surface and verifies that Starshine's pure-dead-value cleanup preserves preceding memory effects/traps.

The compare harness records `selected_profile` for these leaves through the existing composite-profile manifest path. `profile_case_label` is not yet DCE-specific; add it when a leaf grows multiple internal subcases rather than one shape per selected profile.

First dedicated smoke evidence from 2026-06-28:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice
```

Result: compared 100/100, normalized matches 50, mismatches 50, validation/generator/property/command failures 0. Selected-profile counts were 25 each for non-control, block-suffix, if-both-arms, and loop-body. Agent classification:

- 25 `dead-code-elimination-block-suffix` cases matched Binaryen.
- 25 `dead-code-elimination-if-both-arms` cases matched Binaryen.
- 25 `dead-code-elimination-non-control` cases are a Binaryen-shape parity gap: Binaryen preserves the pure prefix as `drop (i32.const 1)` before the trap while Starshine drops it and leaves only `unreachable`. This is not closed as a Starshine win because no size/perf benefit was measured and Binaryen's v130 source contract preserves prefix children.
- 25 `dead-code-elimination-loop-body` cases are a parity gap: Binaryen replaces a loop whose body is a literal `unreachable` with the unreachable, while Starshine keeps the loop and materializes an explicit unreachable tail. This is valid output but remains open because no Starshine benefit was measured.

Follow-up dedicated smoke evidence after the 2026-06-28 loop/raw-skip parity slice:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice3-final2
```

Result: compared 100/100, normalized matches 75, mismatches 25, validation/generator/property/command failures 0. Selected-profile counts were again 25 each for non-control, block-suffix, if-both-arms, and loop-body. Agent classification: block-suffix, if-both-arms, and loop-body matched in this smoke; the remaining 25 mismatches were `dead-code-elimination-non-control` prefix-preservation parity gaps. An attempted HOT-lift prefix preservation fix proved too broad by breaking other pass tests, so the next slice needed a narrower DCE-owned path.

Follow-up dedicated smoke evidence after the 2026-06-28 non-control raw-prefix and `try_table` profile slice:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice4-final
```

Result: compared 100/100, normalized matches 100, mismatches 0, validation/generator/property/command failures 0. Selected-profile counts were non-control 23, block-suffix 18, if-both-arms 24, loop-body 16, and try-table 19. Agent classification: all currently generated DCE aggregate leaves matched Binaryen in this smoke. This is not final closeout; unsupported or under-sampled EH surfaces and Starshine-only HOT families still need generated/scaled evidence.

Follow-up dedicated smoke evidence after the 2026-06-28 stack-polymorphic `if` and reachable-`catch` `try_table` suffix slice:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice5-final2
```

Result: compared 100/100, normalized matches 100, mismatches 0, validation/generator/property/command failures 0. Selected-profile counts were non-control 23, block-suffix 18, if-both-arms 24, loop-body 16, and try-table 19. Agent classification: all then-generated DCE aggregate leaves still matched Binaryen in this smoke. An earlier attempt in `.tmp/pass-fuzz-dce-genvalid-all-100-slice5-final` produced 19 validation failures for the `try_table` leaf because the raw voidification path did not add Binaryen's explicit unreachable tail; the final fix appends the tail for nonfallthrough void `try_table` roots and the rerun is green.

Follow-up dedicated smoke evidence after adding the generated `try_table catch_ref` leaf:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice6
```

Result: compared 100/100, normalized matches 100, cleanup-normalized matches 0, mismatches 0, validation/generator/property/command failures 0, Binaryen cache 97 hits/3 misses. Selected-profile counts were try-table 24, loop-body 20, try-table-catch-ref 15, block-suffix 15, if-both-arms 14, and non-control 12. Agent classification: every generated leaf, including the new `catch_ref` exnref-carrying surface, matched Binaryen in this count-100 smoke.

Follow-up evidence after adding the generated unreachable-if-condition leaf and scaling the dedicated lane:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice7
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-1000-slice7
```

Count-100 result: compared 100/100, normalized matches 100, cleanup-normalized matches 0, mismatches 0, validation/generator/property/command failures 0, Binaryen cache 97 hits/3 misses. Selected-profile counts were block-suffix 19, if-both-arms 16, try-table 16, non-control 14, try-table-catch-ref 13, loop-body 12, and if-condition 10.

Count-1000 scaled dedicated result: compared 1000/1000, normalized matches 1000, cleanup-normalized matches 0, mismatches 0, validation/generator/property/command failures 0, command failures 0, Binaryen cache 1000 hits/0 misses. Selected-profile counts were try-table-catch-ref 155, non-control 151, try-table 146, if-both-arms 140, if-condition 139, loop-body 137, and block-suffix 132. Agent classification: every generated core/EH leaf, including the new unreachable-condition `if` leaf, matched Binaryen in this scoped lane; no mismatches required family classification.

Follow-up evidence after adding the generated branch-payload-forwarder HOT leaf plus the first broad/direct probes:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice8
bun scripts/pass-fuzz-compare.ts --count 10 --seed 0x5eed --pass dead-code-elimination --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-direct-10-slice8
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 20 --seed 0x5eed --pass dead-code-elimination --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-wasm-smith-20-slice8
```

Dedicated count-100 result: compared 100/100, normalized matches 87, cleanup-normalized matches 0, mismatches 13, validation/generator/property/command failures 0, Binaryen cache 98 hits/2 misses. Selected-profile counts were non-control 13, branch-payload-forwarder 13, if-both-arms 13, block-suffix 13, loop-body 12, if-condition 12, try-table-catch-ref 12, and try-table 12. Agent classification: all 13 mismatches were the new `dead-code-elimination-branch-payload-forwarder` leaf. Binaryen keeps the void forwarding block plus dead `unreachable`; Starshine removes that wrapper and branches directly with the same payload. Sample `case-000002-gen-valid` validates on both sides and shrinks canonical/raw wasm from 42 bytes to 38 bytes, so this sampled family is classified as a measured Starshine-win cleanup rather than a parity gap.

Broad direct fallback result: the intended 1000-case and 100-case ordinary GenValid lanes timed out after 600s before writing `result.json` (`.tmp/pass-fuzz-dce-genvalid-direct-1000-slice8` reached 30 mismatch records; `.tmp/pass-fuzz-dce-genvalid-direct-100-slice8` reached 31 mismatch records). The inspected partial records are the same broad `binaryen-oracle-portable` empty-`else` `nop` cleanup family described below: first diffs are Binaryen `(nop)` versus an empty Starshine `else`, and sample sizes shrink 4209→4206 and 5603→5599 bytes. A bounded count-10 ordinary GenValid fallback completed: compared 10/10, normalized matches 0, mismatches 10, validation/generator/property/command failures 0, Binaryen cache 10 hits/0 misses. Agent classification: all completed and inspected partial direct mismatches are sampled Starshine-win no-op cleanup; Binaryen retains empty-`else` `nop` nodes while Starshine removes them, both outputs validate, and sampled canonical wasm sizes are smaller for Starshine in every inspected case. The timeout itself remains a broad-lane scaling/performance risk and does not close the required direct lane.

Small wasm-smith result: `.tmp/pass-fuzz-dce-wasm-smith-20-slice8` compared 20/20 with 20 normalized matches, zero mismatches/failures, wasm-smith cache 20 hits/0 misses, and Binaryen cache 0 hits/20 misses. This is only a tiny smoke, not the required explicit wasm-smith closeout lane.

Follow-up evidence after adding the generated prefix-to-branch-payload HOT leaf and narrowing direct-lane timeout triage:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice9
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-prefix-branch-payload --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-prefix-branch-payload-100-slice9
bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass dead-code-elimination --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-direct-20-slice9
```

Aggregate count-100 result: compared 100/100, normalized matches 92, cleanup-normalized matches 0, mismatches 8, validation/generator/property/command failures 0, Binaryen cache 99 hits/1 miss. Selected-profile counts were block-suffix 19, if-condition 16, if-both-arms 12, loop-body 12, try-table 10, non-control 8, try-table-catch-ref 8, branch-payload-forwarder 8, and prefix-branch-payload 7. Agent classification: all 8 mismatches were the pre-existing `dead-code-elimination-branch-payload-forwarder` measured Starshine-win family; the new prefix-to-branch-payload leaf matched Binaryen for every sampled aggregate case.

Singleton prefix-to-branch-payload count-100 result: compared 100/100 with 100 normalized matches, zero mismatches/failures, and Binaryen cache 100 hits/0 misses. Agent classification: the generated prefix-to-payload HOT leaf is green at this smoke size; no mismatch family needed classification.

Direct-lane triage result: another count-100 direct run with `--max-failures 20` still timed out after 600s and wrote 30 mismatch records without `result.json`, so the timeout is not just the high mismatch cap from slice8. A completed count-20 ordinary GenValid fallback compared 20/20 with 20 mismatches, zero failures, and Binaryen cache 20/0. All 20 cases selected `binaryen-oracle-portable`; a diff scan found only Binaryen-retained `(nop)` nodes removed by Starshine from otherwise empty `else` arms, with Starshine canonical wasm smaller in every case (sample sizes 4209→4206, 5603→5599, 2816→2814). Sample case 1 validates on both sides with `wasm-tools validate --features all`. Agent classification: these completed count-20 mismatches are sampled Starshine-win no-op cleanup under the DCE cleanup contract, but the larger direct lane remains a scaling/performance risk and is not closed.

Follow-up evidence after adding the generated split-local-set and structured-prefix leaves:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-split-local-set-wrapper --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-split-local-set-wrapper-100-slice10
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-structured-prefix --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-structured-prefix-100-slice10
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice10
```

Split-local-set singleton result: compared 100/100 with 100 mismatches, zero validation/generator/property/command failures, and Binaryen cache 84/16. Agent classification: all cases are the same generated `dead-code-elimination-split-local-set-wrapper` family and are a **size-losing parity gap** for the public compare lane. Binaryen rewrites the wrapper to a void `if` plus direct `br` payload; Starshine keeps the resultful wrapper shape. Sample case 1 validates on both sides but Binaryen canonical wasm is smaller (71 bytes) than Starshine (75 bytes), so this is not a Starshine-win cleanup and remains open implementation work.

Structured-prefix singleton result: compared 100/100 with 100 mismatches, zero validation/generator/property/command failures, and Binaryen cache 84/16. Agent classification: all cases are the same structured-prefix family and are a sampled **Starshine-win pure-dead-value cleanup**. Binaryen preserves the pure scalar immediately before `unreachable` as `drop (i32.const 3)` while Starshine removes that pure dead value, preserves the earlier prefix effects/structured block, and emits smaller canonical wasm in sample case 1 (31 bytes vs Binaryen 34 bytes). Reopen this classification for effectful/trapping prefixes, lost structured-prefix effects, validation failures, or a size-losing variant.

Aggregate count-100 result: compared 100/100 with 77 normalized matches, 23 mismatches, zero failures, and Binaryen cache 100/0. Selected-profile counts were if-both-arms 7, prefix-branch-payload 11, if-condition 12, block-suffix 12, loop-body 11, branch-payload-forwarder 6, split-local-set-wrapper 7, try-table-catch-ref 8, structured-prefix 10, non-control 5, and try-table 11. Agent classification: 7 split-local-set cases are the size-losing parity gap above; 10 structured-prefix cases are the sampled Starshine-win pure-dead-value cleanup above; 6 branch-payload-forwarder cases are the previously measured Starshine-win wrapper cleanup. No mismatch in this aggregate smoke is unclassified, but the split-local-set generated leaf now blocks dedicated-profile closeout until fixed or explicitly accepted with reopening criteria.

Follow-up evidence after fixing the generated split-local-set public-lane gap and adding effectful/trapping structured-prefix coverage:

```sh
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-split-local-set-wrapper --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-split-local-set-wrapper-100-slice11
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-effectful-structured-prefix --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-effectful-structured-prefix-100-slice11
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-100-slice11
```

Split-local-set singleton result: compared 100/100 with 100 normalized matches, zero failures, and Binaryen cache 100/0. Agent classification: the prior public generated split-wrapper size-losing parity gap is fixed for this singleton lane.

Effectful-structured-prefix singleton result: compared 100/100 with 100 mismatches, zero failures, and Binaryen cache 84/16. Agent classification: all cases are sampled **Starshine-win pure-dead-value cleanup with effectful/trapping prefixes preserved**. Sample case 1 validates on both sides, preserves Binaryen's `memory.grow` and trapping `i32.load` drops, removes only Binaryen's pure `drop (i32.const 3)`, and shrinks canonical wasm 44→41 bytes. Reopen on lost memory effects/traps, validation failures, or size-losing variants.

Aggregate count-100 result: compared 100/100 with 72 normalized matches, 28 mismatches, zero failures, and Binaryen cache 100/0. Selected-profile counts were prefix-branch-payload 8, effectful-structured-prefix 7, try-table-catch-ref 6, try-table 8, branch-payload-forwarder 8, structured-prefix 13, split-local-set-wrapper 10, loop-body 11, if-both-arms 6, block-suffix 7, if-condition 10, and non-control 6. Agent classification: 7 effectful-structured-prefix cases are the new Starshine-win pure-dead-value cleanup with memory effects/traps preserved; 13 structured-prefix cases are the prior pure Starshine-win cleanup; 8 branch-payload-forwarder cases are the prior measured wrapper-cleanup Starshine wins. The split-local-set leaf sampled 10 cases and all matched. No mismatch in this aggregate smoke is unclassified.

Follow-up evidence after scaling the post-fix aggregate and direct-lane strategy:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --gen-valid-profile dead-code-elimination-all --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 10000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-all-10000-slice12-full
bun scripts/pass-fuzz-compare.ts --count 50 --seed 0x5eed --pass dead-code-elimination --jobs 4 --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-direct-50-jobs4-slice12
bun scripts/pass-fuzz-compare.ts --count 50 --seed 0x5eef --pass dead-code-elimination --jobs 4 --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-direct-50-seed5eef-jobs4-slice12
```

Dedicated count-10000 result: compared 10000/10000 with 7513 normalized matches, 2487 mismatches, zero validation/generator/property/command failures, Binaryen cache 10000/0, and `maxFailuresHit: false`. Selected-profile counts were prefix-branch-payload 881, try-table 854, if-both-arms 846, branch-payload-forwarder 842, if-condition 838, block-suffix 837, try-table-catch-ref 829, loop-body 824, structured-prefix 825, effectful-structured-prefix 820, split-local-set-wrapper 809, and non-control 795. Agent classification: all 842 branch-payload-forwarder mismatches are the previously measured Starshine-win wrapper cleanup (representative validates and shrinks 42→38 bytes); all 825 structured-prefix mismatches are Starshine-win pure-dead-value cleanup with earlier prefixes preserved (representative validates and shrinks 34→31 bytes); all 820 effectful-structured-prefix mismatches are Starshine-win pure-dead-value cleanup with `memory.grow`/trapping `i32.load` prefixes preserved (representative validates and shrinks 44→41 bytes). The fixed split-local-set leaf sampled 809/809 matches. No mismatch in the required dedicated aggregate lane is unclassified.

Direct-lane strategy result: the ordinary direct count-100 lane remains too slow under the current harness/failure-artifact pattern. A count-100 rerun with `--jobs auto` timed out after 1800s with 94 recorded `binaryen-oracle-portable` mismatches and no `result.json`; a `--jobs 4` rerun also timed out after 1800s with 95 recorded mismatches and no `result.json`. Completed bounded shards at count 50 with `--jobs 4` and seeds `0x5eed` and `0x5eef` both wrote result summaries: each compared 50/50, had 0 normalized matches, 50 mismatches, zero failures, and selected only `binaryen-oracle-portable`. A diff scan across all 100 completed direct shard mismatches found only Binaryen-retained `(nop)` nodes removed by Starshine from otherwise empty `else` arms; Starshine canonical wasm was smaller in every case by 2-4 bytes, and representative outputs validate. These direct shards are classified as sampled Starshine-win no-op cleanup, while the required large regular GenValid lane remains open for a harness/performance-aware strategy instead of another unbounded count-100+ attempt.

Follow-up evidence after explicit wasm-smith and broad random-all-profiles closeout probes:

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass dead-code-elimination --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-wasm-smith-10000-slice13
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass dead-code-elimination --gen-valid-profile random-all-profiles --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-random-all-profiles-10000-slice13
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5555 --pass dead-code-elimination --gen-valid-profile random-all-profiles --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-random-all-profiles-100-slice13
```

Explicit wasm-smith count-10000 result: compared 9956/10000 with 9954 normalized matches, 2 mismatches, zero validation/generator/property failures, and 44 Binaryen/oracle command failures. Cache counters were wasm-smith 10000/0, Binaryen 126/9830, and Binaryen failure 0/44. Command failures are classified as Binaryen/tool boundaries: `binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, and `binaryen-table-index-out-of-range=1`. The two mismatches (`case-009332-wasm-smith` and `case-009390-wasm-smith`) are classified as Starshine-win pure-dead-value cleanup: Starshine removes pure dropped `memory.size`/`f64.const` or `f32.const` work before an unreachable/`try_table` tail, both Binaryen and Starshine outputs validate, and normalized canonical wasm shrinks 77→64 and 84→78 bytes respectively. Case `009390` has mixed raw encoder size noise, so the size claim is canonical/normalized, not raw-byte parity.

Broad `random-all-profiles` result: the intended count-10000 lane timed out after 1800s without `result.json`, but wrote 252 case records and 147 mismatch artifacts. The partial mismatch families were already the same as the completed count-100 fallback: 39 `binaryen-oracle-portable` and 59 `pass-fuzz-stress` empty-else/`nop` or pure-debris removals, plus 49 `ssa-nomerge-smoke` dropped-result/`local.tee` cleanup cases; no additional partial family appeared. The completed fallback `.tmp/pass-fuzz-dce-random-all-profiles-100-slice13` compared 100/100 with 39 normalized matches, 61 mismatches, zero failures, and Binaryen cache 100/0. Selected-profile counts were pass-fuzz-stress 22, ssa-nomerge-smoke 21, ssa-nomerge-parity 20, coverage-forced-portable 19, and binaryen-oracle-portable 18. Mismatches were exactly pass-fuzz-stress 22, ssa-nomerge-smoke 21, and binaryen-oracle-portable 18. Agent classification: pass-fuzz-stress and binaryen-oracle-portable mismatches are Starshine-win empty-else `nop` / pure-debris cleanup with 40/40 canonical outputs smaller; ssa-nomerge-smoke mismatches are Starshine-win dropped-result and dropped-`local.tee` cleanup, turning dropped resultful `if`s into void `if`s and dropped `local.tee`s into `local.set`s while preserving writes, with 21/21 canonical outputs smaller by 13 bytes. Representative outputs validate. The broad lane remains open at scale because count-10000 timed out, but the completed fallback plus partial diff scan found no unclassified broad family.

Follow-up evidence after the direct-lane low-artifact strategy and O4z/neighborhood replay:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dead-code-elimination --normalize local-cleanup-debris --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-direct-1000-local-cleanup-slice14
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --normalize local-cleanup-debris --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-direct-10000-local-cleanup-slice14
bun scripts/self-optimize-compare.ts .tmp/dce-o4z-slice14/binaryen-prefix-before-dce.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/dce-o4z-slice14/dce-slot-compare --dead-code-elimination
bun scripts/self-optimize-compare.ts .tmp/dce-o4z-slice14/slot42-prefix-before-dce.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/dce-o4z-slice14/slot42-dce-slot-compare --dead-code-elimination
```

Direct low-artifact result: the compare harness has no summarization-only/no-artifact option, and raw mismatches still run GenValid reduction plus `persistFailureArtifacts(...)`; using `--normalize local-cleanup-debris` turns the already-classified empty-else `nop` family into cleanup-normalized matches and avoids artifact-heavy timeout behavior. The count-1000 probe completed 1000/1000 with 1000 cleanup-normalized matches, zero mismatches/failures, and Binaryen cache 98/902. The scaled direct lane `.tmp/pass-fuzz-dce-genvalid-direct-10000-local-cleanup-slice14` completed 10000/10000 with 0 raw normalized matches, 10000 cleanup-normalized matches, zero mismatches/failures, `maxFailuresHit=false`, and Binaryen cache 1002/8998; all 10000 cases selected `binaryen-oracle-portable`. Representative manual replay of `gen-valid-000001.wasm` validates both outputs, shows only Binaryen-retained empty-else `(nop)` nodes removed by Starshine, and shrinks canonical wasm 4209→4206. Agent classification: the direct lane is not raw-output parity, but its only known raw diff family is a measured Starshine-win no-op cleanup and is now covered at count 10000 by the explicit cleanup normalizer.

O4z/neighborhood result: the current no-DWARF `-O4z` DCE neighborhood is the first optimize/shrink DCE slot after `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> global-struct-inference -> ssa-nomerge`. The historical `tests/node/dist/starshine-debug-wasi.wasm` artifact is absent in this checkout, so bounded replay used the checked-in O4z repros under `tests/repros/`. Binaryen prefix predecessors were built with `wasm-opt --all-features --enable-nontrapping-float-to-int --duplicate-function-elimination --remove-unused-module-elements --memory-packing --once-reduction --global-refining --gsi --ssa-nomerge` and validated before direct DCE compare. For `o4z-debug-startup-map-init-repro.wasm`, `.tmp/dce-o4z-slice14/dce-slot-compare` reports `normalizedWatEqual=true`, `canonicalFuncPrettyEqual=true`, no first differing function, Starshine size 190994 vs Binaryen 191000, and pass-local time 0.311ms vs 1.226ms; trace reasons were 27 `no-dce-candidates`, 8 `loop-outer-branch-dce-noop`, 1 `large-local-dce-noop`, and 7 HOT visits with `changed=false`. For `o4z-slot42-merge-blocks-f1355-nodata.wasm`, `.tmp/dce-o4z-slice14/slot42-dce-slot-compare` reports canonical wasm equal and normalized WAT equal; trace reasons were 52 `no-dce-candidates`, 14 `loop-outer-branch-dce-noop`, and 27 HOT visits with `changed=false`. That small fixture's pass-local timing was slower than Binaryen (3.219ms vs 0.913ms), so keep performance signoff separate from this bounded classification. Agent classification: no new DCE-specific HOT/lowering-survival mismatch family appears in the bounded O4z DCE-slot replays.

Follow-up evidence after the broad random-all-profiles scale strategy and final readiness review:

```sh
bun test scripts/lib/pass-fuzz-compare-task.test.ts
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass dead-code-elimination --gen-valid-profile random-all-profiles --normalize local-cleanup-debris --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-random-all-profiles-10000-local-cleanup-slice15-final
wasm-opt --version
git diff --check
```

Broad `random-all-profiles` scale result: the first retry with the pre-existing normalizer still timed out after 2400s because every `ssa-nomerge-smoke` selected case remained a raw mismatch; 6286 case records and 1296 mismatch artifacts showed no new family. A narrowly justified `local-cleanup-debris` harness update was added test-first to normalize two already-classified DCE cleanup shapes from slice13: dropped `local.tee` writes become equivalent `local.set`s, and dropped resultful `if`s with pure terminal result values become void `if`s while preserving branch-local writes. The focused harness test failed before the normalizer extension and then `bun test scripts/lib/pass-fuzz-compare-task.test.ts` passed 37/37.

With that supported low-artifact strategy, `.tmp/pass-fuzz-dce-random-all-profiles-10000-local-cleanup-slice15-final` completed 10000/10000 with 4007 raw normalized matches, 5993 cleanup-normalized matches, zero mismatches, zero validation/generator/property/command failures, `maxFailuresHit=false`, and Binaryen cache 6620/3380. Selected-profile counts were `pass-fuzz-stress=2062`, `coverage-forced-portable=2037`, `ssa-nomerge-smoke=1973`, `ssa-nomerge-parity=1970`, and `binaryen-oracle-portable=1958`. The raw-normalized matches were exactly the coverage/SSA-parity leaves; cleanup-normalized matches were the previously classified `binaryen-oracle-portable`, `pass-fuzz-stress`, and `ssa-nomerge-smoke` no-op/pure-debris/dropped-result/local.tee Starshine-win cleanup families. No broad mismatch remains unclassified.

Final readiness classification: `wasm-opt --version` reports `wasm-opt version 130 (version_130)`. The direct, dedicated, explicit wasm-smith, broad random-all-profiles, and bounded O4z/neighborhood lanes now have classified results with zero true semantic mismatches, zero Starshine validation failures, and no unclassified output-shape families. The regular direct and broad lanes are explicit cleanup-normalized readiness evidence rather than raw output parity; the normalizer is scoped to inspected Starshine-win no-op/local/pure-result cleanup where side effects, branch payloads, memory effects, and traps are preserved and canonical output shrinks or matches. The fresh regular GenValid count-100000 lane below closes the requested heavier direct signoff for the current v0.1.0 DCE behavior audit.

Starshine-only HOT family classification status as of this slice:

| Starshine-only family | Current classification | Focused evidence / reopening criteria |
| --- | --- | --- |
| Dead roots after nonfallthrough control | Implemented semantic cleanup, not a Binaryen source family. | Covered by tests such as `dead-code-elimination removes unreachable roots after return` and shared-subtree tail deletion. Reopen on semantic/runtime mismatch or size-losing compare family. |
| Dropped-control/result voidification | Implemented semantic cleanup and needed for local HOT result-liveness lowering. | Covered by dropped `if`/block/loop wrapper tests and branch-target boundaries. Reopen if branch payloads or incoming labels lose effects/results. |
| Explicit unreachable-tail materialization | Implemented local lowering-survival repair. | Covered by split-drop/nonfallthrough and loop-body wrapper tests. It must not mask Binaryen loop literal-body parity; the new loop replacement and raw-skip guard keep literal loops Binaryen-shaped. |
| Branch-payload forwarders | Implemented Starshine cleanup with focused HOT tests and generated profile coverage; generated mismatches are measured Starshine wins. | Covered by typed payload-forwarder and nested local.set payload-forwarder tests plus `dead-code-elimination-branch-payload-forwarder`. Count-100 dedicated slice8 sampled 13 generated mismatches; count-10000 slice12 sampled 842. Representative output validates and shrinks 42→38 bytes by removing a dead forwarding wrapper/unreachable tail while preserving the branch payload. Reopen on semantic/runtime mismatch, size-losing branch-payload family, or scaled-profile regression. |
| Split `local.set` wrapper rewrites | Implemented Starshine HOT cleanup with focused tests and generated public-pipeline parity after the slice11 fix. | Covered by direct, nested, void-if, prefix-heavy, store/store/return, and generated public-pipeline split-wrapper tests plus `dead-code-elimination-split-local-set-wrapper`. Singleton count-100 slice10 exposed a 100/100 size-losing parity gap; slice11 fixed the public lane and `.tmp/pass-fuzz-dce-split-local-set-wrapper-100-slice11` matched 100/100. Count-10000 slice12 sampled 809 split-wrapper cases and all matched. Reopen on validation failures, reintroduced size-losing split-wrapper drift, or scaled-profile regression. |
| Prefix-to-branch-payload folding | Implemented Starshine cleanup with a whitebox test and generated singleton coverage. | Covered by `dead-code-elimination folds nonfallthrough prefix blocks into branch payloads` plus `dead-code-elimination-prefix-branch-payload`. Singleton count-100 slice9 matched Binaryen 100/100; reopen on semantic/runtime mismatch, size-losing generated drift, or scaled-profile regression. |
| Raw-skip gates | Active fail-closed pass-manager behavior. | Existing O4z/load-call-set/loop-outer-branch tests plus the new literal-unreachable loop raw-skip exclusion. Reopen if a raw skip hides a Binaryen DCE family. |
| Pass-manager writeback guards | Active lowering guard, not Binaryen parity. | The generated non-control prefix family is covered by a narrow DCE-owned raw path, stack-polymorphic `if` / `try_table` cleanup also uses pass-manager raw repair before HOT lifting, and slice11 lets validated DCE writeback proceed for the generated stack-polymorphic split-wrapper instead of keeping the suspicious-carrier original. `dead-code-elimination-structured-prefix` and `dead-code-elimination-effectful-structured-prefix` cover pure/effectful structured-prefix surfaces. Reopen for lost effect/trap prefixes, validation failures, or raw/writeback repair that masks a Binaryen parity gap. |

Residual boundaries and reopening criteria:

- Core non-EH Binaryen v130 families are covered by focused tests plus generated/direct evidence: non-control first-unreachable-child cleanup, block suffix trim/collapse/type update, unreachable `if` condition, both-arms-unreachable `if`, and literal-unreachable loop replacement. Reopen on a true semantic mismatch, Starshine validation failure, lost prefix effect/trap, or size-losing generated family not already covered by the fixed split-wrapper case.
- Modern `try_table` literal-unreachable typing and reachable catch/catch_ref body-suffix cleanup are covered by focused tests and generated leaves. Reopen on lost catch payloads, missing explicit unreachable tails needed for validation, or new Binaryen EH source behavior not represented by the current modern `TryTable`/`Throw`/`ThrowRef` IR.
- Legacy `try`, old-EH `pop`/nested-pop, and stack-switching `resume`/`resume_throw` are documented local representation/tool boundaries: Starshine's canonical `src/lib` instruction set has modern `try_table`, `throw`, and `throw_ref` but no legacy `try`, `pop`, `resume`, or `resume_throw`; WAST legacy try lowers before optimizer passes; stack-switching is not represented. Reopen if those opcodes enter canonical `src/lib` / HOT IR, if lowering begins preserving old-EH `pop`, or if Binaryen changes DCE to require a modern equivalent.
- Direct and broad GenValid closeout evidence uses the explicit `local-cleanup-debris` normalizer for already-inspected Starshine-win cleanup families: empty-else `nop`, pure dead value/debris before unreachable, dropped resultful `if` pure result values, and dropped `local.tee` values converted to `local.set`. Reopen if this normalizer hides a side-effecting value, branch payload, memory/table/global mutation, trap, validation problem, size-losing family, or a new raw mismatch outside those inspected shapes.
- O4z/neighborhood replay is bounded to checked-in repros because the historical `tests/node/dist/starshine-debug-wasi.wasm` artifact is absent. Reopen if that artifact returns with a DCE-specific slot mismatch, if a new generated O4z predecessor shows a DCE semantic difference, or if pass-local performance is investigated as a DCE-owned blocker rather than the separate whole-command/performance backlog.

Fresh 100000-case direct signoff requested after recursive readiness:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass dead-code-elimination --normalize local-cleanup-debris --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dce-genvalid-direct-100000-local-cleanup-final
```

Result: compared 100000/100000 with 0 raw normalized matches, 100000 cleanup-normalized matches, zero mismatches, zero validation/generator/property/command failures, `maxFailuresHit=false`, and cache counters wasm-smith 0/0, Binaryen 10334/89666, Binaryen failures 0/0. The local oracle was `wasm-opt version 130 (version_130)`. Agent classification: this is the same documented direct DCE cleanup family already inspected at count 10000—Binaryen-retained no-op/local/pure-result debris normalized by `local-cleanup-debris`; no new mismatch or failure family appeared.

The 2026-07-17 current-artifact batch/validity slice in research note [`1648`](../../../raw/research/1648-2026-07-17-dce-batch-writeback-and-shrink-vacuum-attribution.md) reran the two lanes required for that performance/correctness change with a fresh explicit native binary and Binaryen v130. Regular GenValid with `local-cleanup-debris` compared `10000/10000` with `10000` normalized matches and zero failures/mismatches. Dedicated `dead-code-elimination-all` compared `10000/10000` with `7513` normalized matches and the exact established `2487` measured Starshine-win mismatches: `842` branch-payload-forwarder, `825` structured-prefix, and `820` effectful-structured-prefix; all `809` split-local-set-wrapper cases still matched. No new family, validation failure, or semantic mismatch appeared.

Future full pass closeout reruns, if required after new DCE changes, should use the repo-standard pass matrix with the DCE-specific cleanup normalizer on the regular and broad lanes. Use `_build/native/release/build/cmd/cmd.exe` after `moon build --target native --release src/cmd`; a concurrently present `target/native/...` artifact needs explicit freshness verification before it can be used for signoff.
