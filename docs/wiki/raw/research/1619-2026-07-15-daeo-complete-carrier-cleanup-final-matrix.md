# 1619 — DAEO complete carrier cleanup final matrix

Date: 2026-07-15

Status: current direct `dae-optimizing` signoff after exactly three red-first code commits. The direct Binaryen v130 gap remains open, so this note is a checkpoint rather than parity closeout.

## Summary

This iteration keeps plain `dead-argument-elimination` / `dae` separate and extends only the optimizing post-component cleanup already limited to selected changed definitions.

The retained work closes three exact current-artifact families:

1. a complete Func `7008` `call 7053` carrier beginning before `call 7096`, preserving the complete producer through `call 7106`, and moving it across three pure terminal arguments;
2. the conditional selector sibling that preserves the ambient selector condition and `call 7123`, moving only immutable caller-local arguments before the complete `call 7096` / `call 7106` producer;
3. a post-remap four-field terminal aggregate spill whose nullable aggregate still traps at the first `struct.get`, while four exact one-use field locals are replaced by direct field reads.

The three changes reuse existing authoritative local-reference counts, recursive selected-function traversal, selected-definition validation, selected-function encoded-size profitability, rollback, and compaction. The third change extends the already-running post-remap readback traversal; it does not add another instruction scan. Remapped counts are built while the existing local-compaction loop emits retained locals.

Public `optimize`, `shrink`, and `--optimize -O4z` still execute exactly one late `dae-optimizing` slot after `heap-store-optimization` and immediately before `inlining-optimizing`.

## Exact code-commit contract

Starting point:

```text
7e4e17288 docs: record DAEO complete call transport signoff
```

Exactly three code commits were retained:

1. `c28c14854 feat: sink selected DAEO complete call7053 carriers`
   - red-first fixture: `DAEO selected cleanup sinks a complete call7053 carrier through three terminal arguments`;
   - recognizes the complete fourteen-instruction producer/consumer slice rather than a visible operand suffix;
   - uses local type/count/effect guards and existing selected-function profitability;
   - direct artifact delta: `-13` raw / `-14` canonical bytes.
2. `7b252b9cd feat: sink selected DAEO conditional call7053 carriers`
   - red-first fixture: `DAEO selected cleanup sinks a conditional complete call7053 carrier`;
   - preserves the ambient condition and selector call, moving only immutable caller-local arguments;
   - direct artifact delta: `-6` raw / `-7` canonical bytes.
3. `30c67909a feat: forward selected DAEO terminal aggregate slices`
   - red-first fixture: `DAEO selected readback traversal forwards terminal four-field aggregates`;
   - runs in the existing post-remap readback traversal, where the artifact shape actually exists;
   - requires four distinct exact one-get/one-set/no-tee field locals, a shared aggregate/type, exact field/read ordering, signed extensions, terminal call, and branch;
   - replaces the aggregate `local.tee` with `local.set`, preserves the nullable null trap at the first direct field read, and updates count evidence;
   - derives remapped counts while compacting locals, avoiding a second local-count loop and any extra instruction scan;
   - direct artifact delta: `-26` raw / `-64` canonical bytes.

No fourth code-changing commit was made.

## Rejected experiments

The following probes were fully reverted and are not part of the retained implementation:

- a block-result-to-`call 7053` matcher that omitted part of the branch-heavy complete producer and rolled the artifact back to raw `3194964` / canonical `3272572`;
- an incomplete conditional-selector move that reproduced the known rollback endpoint raw `3195898` / canonical `3273521`;
- complete four-field aggregate-prefix variants attempted before remap, which were byte-identical because the terminal aggregate shape is created by the existing remap/dead-tee traversal;
- several diagnostic reachability probes, all removed before commit.

The established safety rule remains: do not move only visible final call operands when an earlier call/control producer remains ambient on the stack. Future transport must cover the complete stack-value slice.

## Explicit native binary

All final direct and compare evidence uses:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 b9c7011d3e0a17bbc8deaa90b55db9d012c4eb230fdba76e2b61cd8c431dda2b
```

Binaryen v130 is selected explicitly through:

```text
WASM_OPT_BIN=$BINARYEN_BIN_DIR/wasm-opt
```

The compare matrix uses `--jobs auto`, the explicit native Starshine binary, and both documented DAE normalizers:

```text
--normalize drop-consts --normalize unreachable-control-debris
```

Random-all additionally uses `--no-reduce-mismatches --max-failures 10000`.

## Validation

Final validation after the amended third commit:

- `moon info`: passed with existing warnings only;
- `moon fmt`: passed; the unrelated `moon.mod` spelling rewrite was restored;
- `moon test`: `8854/8854` passed;
- `moon build --target native --release src/cmd`: passed;
- `bun validate full --profile ci --target wasm-gc --seed 1784065000000000`: passed;
- full profile highlights: `validate-valid=5000`, `validate-invalid-ast=2650`, `binary-roundtrip=86820`, `cmd-harness=4096`, all passing;
- focused readback tests: `3/3` passed;
- focused aggregate tests: `6/6` passed;
- focused selected-cleanup tests: `21/21` passed;
- no `.mbti` public-API diff exists.

## Direct artifact and Binaryen gap

Input:

```text
.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

Two final Starshine runs are byte-identical and validate before and after Binaryen canonicalization.

| output | raw bytes | canonical bytes | SHA-256 |
|---|---:|---:|---|
| Starshine final | `3194836` | `3272348` | raw `f580e9498f211800ee8480f69dac2fff56897b5c6533d0ffea8af7fc6e3e2a11`; canonical `f6043b872c45af3503c3d6b029ef8fbe6aa62717b932ae26d95c424d67be7932` |
| Binaryen v130 | `3177421` | `3262456` | raw `ff8ca32be820290276e2f8cedac9a16d7fc2fb3a9620b71c542b27a28cc7d992`; canonical `d933d99ce4b55b284a8214a04d2c38f7b64fd7e5e0caf06e4330185d5b738b7e` |
| remaining gap | `+17415` | `+9892` | open parity gap |

Relative to note `1618`, this iteration improves the artifact by:

```text
raw:       3194881 -> 3194836  (-45)
canonical: 3272433 -> 3272348  (-85)
```

No part of the remaining module or selected-function body gap is accepted merely because Starshine has fewer local gets/tees or validates. The residual remains a parity gap until aligned or proven as a measured Starshine win.

## Controlled timing

Fresh Binaryen v130 reference retained from the same artifact contract:

```text
8538.02ms
```

Two uncontaminated final pass-local Starshine repeats, with no `starshine-sidework` process in the before/after snapshots, are:

```text
16633.600ms  (1.95x Binaryen)
16929.736ms  (1.98x Binaryen)
```

Both are below the absolute `17076.04ms` ceiling. Later attempts that overlapped renewed side-work were not used for controlled signoff; one such contaminated repeat measured `17542.636ms`.

## Required direct compare matrix

### Dedicated `dae-optimizing`

```text
.tmp/pass-fuzz-daeo-complete-carriers-final2-dedicated-10000-20260715
```

- requested/compared `10000/10000`;
- selected profile `dae-optimizing=10000`;
- normalized `10000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`.

### Regular GenValid

```text
.tmp/pass-fuzz-daeo-complete-carriers-final2-regular-100000-20260715
```

- requested/compared `100000/100000`;
- normalized `100000`, cleanup-normalized `0`, mismatches `0`;
- validation/generator/property/command failures `0`;
- Binaryen cache `100000/0`.

### Explicit wasm-smith

```text
.tmp/pass-fuzz-daeo-complete-carriers-final2-wasm-smith-10000-20260715
```

- requested `10000`, compared `9956`;
- normalized `9955`, cleanup-normalized `1`, mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all Binaryen/oracle tool failures: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- caches: wasm-smith `10000/0`, Binaryen success `9956/0`, Binaryen failure `44/0`.

### Random all profiles

```text
.tmp/pass-fuzz-daeo-complete-carriers-final2-random-all-10000-20260715
```

- requested/compared `10000/10000`;
- normalized `9633`, cleanup-normalized `0`, mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- residual profiles: `coverage-forced-portable=243`, `dae-effectful-args=124`.

All `367` failure-directory names and all `3670` saved files are byte-identical to note `1618`. The existing agent classification is therefore unchanged and independently remeasured:

```text
aggregate Starshine - Binaryen raw:       -110224 bytes
aggregate Starshine - Binaryen canonical: -797486 bytes
aggregate Starshine - Binaryen WAT:       -5465849 bytes
positive canonical cases:                 0
positive WAT cases:                       0
```

These two residual families remain measured/source-backed intentional Starshine cleanup wins. There are no unknown/risky, size-losing generated, Starshine-validation, or true-semantic residuals in the matrix.

## Plain DAE separation

A fresh direct plain-DAE replay on the large stripped artifact:

- validates;
- emits exactly one `pass[dae]:start` and one `pass[dae]:done`;
- emits no `pass[dae-optimizing]:start`;
- emits no `post-component-cleanup` trace;
- measures `3555.120ms` pass-local;
- writes `3201276` bytes with SHA-256 `dfa016aa935b02fecab5f6bde7aeea71fcb5d2088f26be3390755a881a2e3ca8`.

The complete-carrier and terminal-aggregate rewrites remain optimizing-only.

## Exact-once public scheduling

The first final dedicated-profile input was replayed through public `--optimize`, public `--shrink`, and synthesized `--optimize -O4z`.

All three:

- validate;
- emit the same `38`-byte output;
- have SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`;
- execute exactly one top-level `dae-optimizing` start/done pair;
- place the late `heap-store-optimization` trace immediately before DAEO;
- place `inlining-optimizing:start` immediately after `dae-optimizing:done`.

Observed whole-command times were `6ms`, `5ms`, and `5ms` respectively.

## Remaining direct work

The direct gap is not eliminated:

```text
raw gap:       +17415
canonical gap: +9892
```

No new residual family from generated testing is open, but the large artifact still contains unproved selected-function output-shape gaps. In particular:

- complete one-use carriers such as the remaining large `block i32` producers in Func `7008` must be moved only with their entire nested control/call stack-value slice;
- earlier partial moves proved that visible final operands are not a safe boundary;
- terminal aggregate shapes created by dead-tee remapping should be handled in the existing counted post-remap traversal rather than by another pre-remap scan;
- byte-identical or validation-only probes are not acceptable commits;
- the next iteration must again retain exactly three red-first measured code commits, one consolidated signoff, and one docs-only commit while preserving the timing ceiling and public scheduling.

The broader pre-DAEO large scheduled `[WALL]001` blockers also remain outside this direct-pass iteration.
