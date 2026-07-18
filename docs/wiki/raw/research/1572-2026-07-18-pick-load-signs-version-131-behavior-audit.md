---
kind: research
status: current
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_131
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/PickLoadSigns.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/bits.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/pick-load-signs_sign-ext.wast
  - ../../../../src/passes/pick_load_signs.mbt
  - ../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
related:
  - ../../binaryen/passes/pick-load-signs/index.md
  - ../../binaryen/passes/pick-load-signs/parity.md
  - ../../binaryen/passes/pick-load-signs/fuzzing.md
  - ./0784-2026-06-20-pick-load-signs-modern-signoff-refresh.md
---

# `pick-load-signs` Binaryen `version_131` behavior audit

## Conclusion

The initial audit found five Starshine-only evidence families and kept direct behavior parity open. The same-day implementation follow-up resolved every size-losing or unproven family by deleting the redundant extension expression after a complete matching-source proof. Starshine now covers every Binaryen `version_131` transform and bailout and retains the broader families only as measured smaller-output wins:

1. commuted i32 low-mask evidence (`i32.const MASK; local.get; i32.and`);
2. i32 unsigned shift-pair evidence (`shl` followed by `shr_u`);
3. i64 direct signed-extension evidence (`i64.extend8_s`, `extend16_s`, `extend32_s`);
4. i64 low-mask zero-extension evidence;
5. i64 signed and unsigned shift-pair evidence.

The repaired `pick-load-signs-all` profile exposes every retained family. Final source, runtime, size, performance, focused-test, and four-lane evidence closes PLS at Binaryen-v131-or-better behavior parity. The gap sections below preserve the audit-time findings; the implementation follow-up at the end records their resolution.

## Oracle refresh

Binaryen `version_131` was published on 2026-07-15. The audited tag resolves to commit `1f903c14babf829745b421b92ff0f286e93e4209`.

Downloaded official x86_64 Linux asset:

- archive SHA-256: `b5bf1f0eaf17c63ee588ff7a5954dc8f6ce2c26989051c66f24dfe9ece3e46db`
- executable reports: `wasm-opt version 131 (version_131)`

Captured source hashes:

- `PickLoadSigns.cpp`: `193cc5e649fec018c330295a2cd7a23f60ff5d58db2a4ce73f958bcf4f02f6f5`
- `properties.h`: `defabdab16c412fbd3f1ac6b247712558edc6f7f99ef974a79cc8a5c404805e2`
- dedicated lit file: `5c162bb61512a8d671275d671e4cecabcab5c781cad40687ba20ce355cf8b1b0`

The pass owner, helper behavior, and dedicated lit file are byte-identical between Binaryen `version_130` and `version_131`. `pass.cpp` changed for unrelated pass registrations; the PLS registration and default-pipeline gate remain unchanged.

## Binaryen v131 behavior contract

The source-owned contract remains:

- skip functions when the module has no memory;
- collect candidate loads only from exact non-tee `local.set(load ...)` producers;
- count every `local.get` of the candidate local;
- recognize i32 signed evidence from `i32.extend8_s`, `i32.extend16_s`, or equal-constant nonzero `i32.shl -> i32.shr_s` pairs;
- recognize i32 unsigned evidence only from `i32.and` with the value on the left and an exact nonzero low-bit mask constant on the right;
- reject if any use is unrecognized;
- reject conflicting widths or a width that does not match the load width;
- reject atomic loads;
- choose signed when `signedUses * 2 >= unsignedUses`, otherwise unsigned;
- share use evidence per local but apply the width check per candidate load.

`properties.h` is still explicitly i32-only. It does not recognize unsigned shift pairs and does not recognize i64 evidence.

## Source-to-Starshine matrix

| Binaryen v131 family | Starshine status | Evidence |
| --- | --- | --- |
| exact non-tee `local.set(load)` | matched | source review and direct probes |
| no-memory skip, including imported memory admission | matched | focused tests and probes |
| i32 direct signed extension, 8/16 | matched | direct probes |
| i32 signed shift pair, 8/16 | matched | direct probes, including negative/effective shift constants |
| i32 right-hand low mask, 8/16 | matched | direct probes |
| all-uses-recognized bailout | matched | equality and official `br_if` probes |
| conflicting signed width bailout | matched | direct probe |
| load/use width mismatch bailout | matched | direct probe |
| no-use bailout | matched | direct probe |
| same-local multiple candidates | matched | same-width and mixed-width probes |
| signed weighting (`1 signed : 2 unsigned` signed; `1 : 3` unsigned) | matched | direct probes |
| `local.tee` producer bailout | matched | focused test and direct probe |
| atomic exclusion | matched by candidate exclusion | source review |
| unknown uses after unreachable or in a dead constant-if arm | matched | direct probes |

No Binaryen-owned transform family was found that Starshine fails to perform.

## Remaining behavior-parity gaps

### Gap 1: commuted i32 mask evidence

Binaryen requires:

```wat
(i32.and (local.get $x) (i32.const 255))
```

Starshine also accepts:

```wat
(i32.and (i32.const 255) (local.get $x))
```

The focused probe changes `i32.load8_s` to `i32.load8_u` only in Starshine. This is semantically valid because `i32.and` is commutative. A tiny `pick-load-signs -> optimize-instructions` probe measured canonical output at `48` bytes for Starshine versus `52` bytes for Binaryen, so this is a candidate measured Starshine win. It remains open until that intentional divergence is explicitly accepted and covered as such.

### Gap 2: i32 unsigned shift-pair evidence

Starshine accepts:

```wat
(i32.shr_u
  (i32.shl (local.get $x) (i32.const K))
  (i32.const K))
```

and flips signed `i32.load8_s` / `i32.load16_s` producers to unsigned. Binaryen v131 does not recognize this as zero-extension evidence; `getZeroExtValue(...)` only recognizes a right-hand low mask.

This is not currently a measured win. On the 8-bit tiny probe, canonical `pick-load-signs -> optimize-instructions` output was `54` bytes for Starshine versus `52` bytes for Binaryen because Binaryen converted the shift pair to a mask while Starshine retained it. Treat this as an open size-losing parity gap unless the downstream cleanup is repaired and remeasured.

### Gap 3: i64 direct signed-extension evidence

Starshine flips `i64.load8_u`, `i64.load16_u`, and `i64.load32_u` when all uses are the matching `i64.extend8_s`, `i64.extend16_s`, or `i64.extend32_s`. Binaryen PLS is i32-only and leaves those loads unchanged.

The transforms are semantically valid. Tiny downstream probes for all three widths measured canonical `pick-load-signs -> optimize-instructions` output at `48` bytes for Starshine versus `49` bytes for Binaryen because Starshine removed the now-redundant direct extension. This is a candidate measured Starshine win, but it is still an unapproved direct-pass divergence.

### Gap 4: i64 low-mask zero-extension evidence

Starshine flips signed i64 narrow loads when every use masks to the matching low width with `i64.and`. Binaryen PLS leaves all i64 loads unchanged.

The transform is semantically valid, but the 8-bit downstream probe remained equal-size at `52` canonical bytes and still differed only in load signedness. No material win is proven, so this remains an open parity gap. Starshine also accepts the commuted constant-left form, combining this gap with gap 1's operand-order breadth.

### Gap 5: i64 signed and unsigned shift-pair evidence

Starshine recognizes equal-constant `i64.shl -> i64.shr_s` and `i64.shl -> i64.shr_u` pairs for 8-, 16-, and 32-bit narrow loads. Binaryen PLS recognizes no i64 evidence.

The signed 32-bit tiny downstream probe was equal-size at `49` bytes and still differed in load signedness. The unsigned 16-bit probe was size-losing for Starshine (`54` versus Binaryen `53`) because Binaryen reduced the shift pair to a mask while Starshine retained it. Keep both signed and unsigned i64 shift families open; the unsigned family is presently size-losing on the measured probe.

## Dedicated-profile coverage gap

`pick-load-signs-all` is parity-clean by construction rather than behavior-complete:

- `pick-load-signs-unsigned-shift` uses an already-unsigned load, so it cannot reveal gap 2;
- `pick-load-signs-i64-watch` uses an already-signed load, so it cannot reveal gaps 3-5;
- there is no commuted-mask leaf for gap 1.

The aggregate must be revised to expose the mutating divergence families. Until then, a green dedicated-profile lane is evidence for the upstream-common subset only.

## Version-131 four-lane evidence

All commands used the rebuilt native Starshine binary and the official v131 `wasm-opt` via explicit `--wasm-opt-bin`.

### Regular GenValid

- requested/compared: `100000/100000`
- normalized matches: `100000`
- mismatches/failures: `0`
- Binaryen cache: `314` hits / `99686` misses
- out dir: `.tmp/pass-fuzz-pick-load-signs-v131-genvalid-100000`

### wasm-smith

- requested/compared: `10000/9956`
- normalized matches: `9955`
- raw mismatches: `1`
- command failures: `44`
  - `binaryen-rec-group-zero`: `39`
  - `binaryen-invalid-tag-index`: `1`
  - `binaryen-table-index-out-of-range`: `1`
  - `binaryen-bad-section-size`: `3`
- cache: wasm-smith `0/10000`; Binaryen success `106/9850`; Binaryen failure `0/44`
- out dir: `.tmp/pass-fuzz-pick-load-signs-v131-wasm-smith-10000`

The sole raw mismatch, case `009332`, had no PLS load/sign pattern. It was one extra Starshine `(drop (unreachable))` wrapper before an existing `unreachable`. Replay with `--normalize unreachable-control-debris` classified it as `1` cleanup-normalized match and `0` remaining mismatches. Agent classification: codec/HOT writeback unreachable-control debris, not PLS behavior.

### Dedicated `pick-load-signs-all`

- requested/compared: `10000/10000`
- normalized matches: `10000`
- mismatches/failures: `0`
- all 11 leaves sampled
- Binaryen cache: `9976` hits / `24` misses
- out dir: `.tmp/pass-fuzz-pick-load-signs-v131-profile-10000`

### Random all profiles

- profile: `random-all-profiles`
- requested/compared: `10000/10000`
- normalized matches: `10000`
- mismatches/failures: `0`
- Binaryen cache: `5324` hits / `4676` misses
- out dir: `.tmp/pass-fuzz-pick-load-signs-v131-random-all-10000`

## Moon evidence

- `moon build --target native --release src/cmd`: passed with existing warnings.
- `moon test src/passes`: `5845/5845` passed.

## Audit-time closeout decision

The initial audit kept `[O4Z-PLS]001` open pending behavior repair, profile repair, and fresh signoff. The following implementation follow-up satisfies those conditions.

## Same-day implementation follow-up

### Behavior repair

Starshine now records broader evidence roots and removes them only after proving:

- the local is not a parameter;
- every explicit write is an exact matching PLS load candidate;
- every candidate reaches the evidence width and final signedness;
- at least one candidate changes signedness.

Eligible roots are replaced by the associated `local.get`. This removes commuted i32 masks, i32 unsigned shifts, i64 direct extensions, i64 masks, and i64 signed/unsigned shifts after the load opcode changes. Parameter-entry values, non-load writes, mixed widths, and partial conversions preserve the original evidence expression.

Exact straight-line forms also gained a raw pass-manager path. Upstream-common i32 forms preserve Binaryen's direct-pass extension shape; retained broader forms remove the redundant evidence without HOT lift.

### TDD evidence

Red-first focused tests covered:

- i32 unsigned shifts at widths 8 and 16;
- i64 unsigned shifts at widths 8, 16, and 32;
- commuted i32 masks;
- i64 masks and direct signed extensions;
- i64 signed shifts at widths 8, 16, and 32;
- preservation with a non-load writer;
- preservation when a parameter entry value can reach the read;
- zero-HOT-allocation raw rewrites.

Final focused results are `5857/5857` passes tests and `1704/1704` validation tests.

### GenValid repair

The aggregate still has 11 selected leaves, but the behavior leaves now expose the real breadth:

- `unsigned-mask`: right-hand and commuted i32 masks plus i64 mask widths 8/16/32;
- `unsigned-shift`: mutating i32 widths 8/16 plus i64 widths 8/16/32;
- `i64-watch`: mutating direct signed extensions and signed shifts at widths 8/16/32.

Focused generator tests assert every listed shape.

### Direct size matrix

All 16 retained width/family probes remove their evidence expression. Canonical direct-pass output is smaller than Binaryen by `1` to `7` bytes:

- commuted i32 masks: `48` vs `52/53`;
- i32 unsigned shifts: `48` vs `54`;
- i64 direct signed extensions: `48` vs `49`;
- i64 masks: `48` vs `52/53/55`;
- i64 signed and unsigned shifts: `48` vs `54`.

### Runtime matrix

A 16-case negative-boundary runtime matrix used initialized memory and exported functions. Binaryen and Starshine results matched for every retained family and width, including signed minima and unsigned high-bit values.

### Performance

Native-release whole-command medians over 2,000-function exact-shape modules:

- unsigned shifts: Starshine `7.36 ms`, Binaryen `8.18 ms`;
- masks: Starshine `6.35 ms`, Binaryen `6.94 ms`;
- i64 direct/signed-shift: Starshine `6.21 ms`, Binaryen `7.15 ms`.

### Final four-lane matrix

- regular GenValid: `100000/100000` exact normalized, zero failures;
- wasm-smith: `9956/10000` compared, `9955` exact normalized, one unchanged PLS-unrelated debris mismatch, and `44` Binaryen/tool failures; normalized replay clears the mismatch;
- `pick-load-signs-all`: `10000/10000`, `6452` exact matches and `3548` measured Starshine-win mismatches, zero failures;
- random all profiles: `10000/10000` exact normalized, zero failures.

The dedicated `3548` mismatches exactly equal selected counts for `unsigned-mask` (`1762`), `unsigned-shift` (`1225`), and `i64-watch` (`561`). Representative aggregate modules are smaller by `20`, `30`, and `21` canonical bytes respectively. All other leaves match Binaryen exactly.

### Ordered neighborhood

The scheduled `pick-load-signs -> precompute` dedicated-profile lane completed `10000/10000` cases with `5300` exact matches, `4700` smaller Starshine outputs, and zero failures. All mismatches were size wins: the three PLS behavior leaves retained their `-20`, `-30`, and `-21` aggregate deltas, while neighboring `precompute` additionally reduced the tee and mixed-width leaves by `8` and `3` bytes. No size-losing or invalid scheduled output remained.

### Final decision

Close `[O4Z-PLS]001`. No missing Binaryen-owned behavior, size-losing retained family, speed-losing representative exact-shape workload, scheduled-neighborhood regression, validation failure, or true semantic mismatch remains. Reopen under the criteria recorded in the living parity page.
