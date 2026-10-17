---
kind: workflow
status: supported
last_reviewed: 2026-10-15
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ./index.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_wbtest.mbt
  - ../../../../../src/validate/gen_valid_heap2local_owner_updates.mbt
  - ../../../../../src/validate/gen_valid_heap2local_owner_updates_wbtest.mbt

---

# `heap2local` Fuzzing Profile

> **Comparison baseline — October 14, 2026:** new comparisons use [Binaryen 133](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 and v132 sources, commands, artifacts and results retain their historical versions and do not establish v133 signoff.

## October 15 shared-work build renewal

Fresh native `5d8ea74e23ab4237` and generator `76b922fbe5da4122` complete
10,000 `heap2local-all` cases at seed `0x5eed` against verified Binaryen 133.
All 10,000 original/Starshine/Binaryen Node 26 observations agree. Independent
validation, byte determinism and codec idempotence pass; there are no runtime
blocks, semantic differences, validation, property, generator or command
failures. All outputs differ structurally and are smaller in both raw and
repository-canonical bytes. This is a semantic result, not exact-output parity.

The manifest has 10,000 nonempty records but 2,807 distinct input hashes:
3,019 struct cases (five hashes), 2,026 array cases (three), 1,944 reference
cases (seven), and 3,011 owner cases (2,792). All exact manifest call,
import-effect and exception facts are zero. These pure scalar owner inputs do
not establish host-effect, handler or nested cleanup coverage. The separate
permanent runtime/regression lanes retain those obligations; coarse byte-level
effect flags are not proof of executed calls or exception paths.

The retained 20 bundles have an additional independent replay with 195 explicit
calls and 45 start calls. Each owner's boolean branch combinations use a
separate field-array oracle. Three exact same-seed cases cover the
read-after-write owner family absent from the artifact cap; their input hashes
match the manifest and 90 additional calls agree with the field oracle. These
checks are separate from campaign counters. Conditional owner inputs have six constructor sites across the branch arms.
Three allocations execute per original/Binaryen call; the scalar output has
zero. This follows from inspected code paths, not an allocation counter. It
adds 12 i32 locals and more local traffic. Keep that tradeoff explicit; no
general runtime or memory win follows from size alone. The separate replay
total is 285 explicit calls and 45 start invocations (330 executions).

Evidence root: local `.tmp/report-optimization-20261014/` with immutable source
and binary identity in `native-shared-work-reuse/`, campaign and raw cases in
`fuzz-shared-work-reuse-20261015/heap2local/`, and review/replay records in
`review/heap-shared-work-current-gpt.txt` and
`review/heap-shared-work-artifacts/`. The full gate passes 14,300 tests and the
permanent Heap2Local runtime lane passes 11,568 comparisons. Excluded owner,
reference, exception and dynamic-array cases below remain outside this claim.

## October 15 current-source owner-publication renewal

Fresh native `b29aee1d5208047c` and generator `55996bb01ef9cfb1` complete
10,000 `heap2local-all` comparisons against verified Binaryen133. The exact
source snapshot and build identities are retained in
`.tmp/report-optimization-20261014/native-write-visit-corrected/`; reports are
under `fuzz-write-visit/heap2local/`.

All10,000 original/Starshine/Binaryen Node26 observations agree. Independent
validation, byte determinism and codec idempotence pass all10,000. There are no
semantic, blocked-runtime, validation, generator, command or property failures.
All10,000 outputs differ structurally; this is not an exact-output parity claim.
Starshine is smaller in every case: raw1,195,642 versus1,404,329 bytes total;
repository-canonical1,187,654 versus1,404,329.

The repaired generator now produces10,000 nonempty constructor/accessor cases,
with zero empty bodies:3,019 struct,2,026 array,1,944 reference and3,011 owner
updates. This supersedes the trigger-coverage limit of the earlier batch below,
not its historical results. There are2,807 distinct input hashes:15 ordinary
templates and2,792 owner-update value variants.

Independent review reads all20 retained bundles. A separate deterministic replay
reproduces all15 ordinary input hashes plus the constant-first owner case missing
from those bundles, checks exact input hashes before optimization, validates
outputs, and executes explicit calls. This extension is separate from the10,000
harness counters. The source contract and inspected ordinary families support
smaller scalar scaffolding. Owner updates remove six static allocations and
13–15 field reads, with5–13 canonical bytes saved. They also use13 declared
locals versus Binaryen's1 and52–54 static local operations versus19–21. Keep
that pressure cost explicit; no general runtime, peak-memory or native-spill gain
is established by this comparison. The independent review and raw extension
records are in `review/heap-write-visit-families.txt` and
`review/heap-write-visit-data/` under the local evidence root.

The same current binary also passes11,568 permanent Heap2Local V8 comparisons,
including unsigned packed reads and once/twice cleanup. The complete explicit
WasmGC suite passes14,219 tests. These checks close the reduced owner-publication
and control-ownership failures in this source snapshot; they do not cover every
excluded reference, exception or dynamic-array case listed below.

## 2026-08-21 packed local-read correctness repair

Native SHA-256 `de2470509283618793ca6103b0e64ce33a5c14c3e67c4fae1436fb3a56b19a67` repairs mutable packed arrays scalarized into i32 locals. The local-owner path previously replaced `array.get`, `array.get_s`, and `array.get_u` uniformly with `local.get`. Because array writes keep the raw i32 producer in the scalar local, signed and unsigned packed reads still require Wasm storage conversion: i8/i16 signed reads now append `i32.extend8_s` / `i32.extend16_s`, while unsigned reads append `& 0xff` / `& 0xffff`. Unpacked value arrays retain the direct local read.

This was a true semantic failure in the final8 WAGO artifacts. The i8 fixture returned 128 and 255 instead of -128 and -1; the i16 fixture returned 32768 and 65535 instead of -32768 and -1. Rebuilding from retained pre-fold artifacts now produces byte-identical Binaryen outputs at 90 and 95 bytes, and every exported result matches pinned Binaryen. Focused Heap2Local coverage is 22/22. Precompute's immutable packed-array path and the final fresh-array fold already handled signedness correctly; focused regressions now lock positive sign-bit patterns in all three owners.

Explicit pinned-v131 repair smoke uses `.tmp/binaryen-version-131-bin/bin/wasm-opt`:

- regular `.tmp/pass-fuzz-heap2local-final9-packed-sign-v131-regular-1000`: 1,000/1,000 normalized, zero failures or mismatches;
- dedicated `.tmp/pass-fuzz-heap2local-final9-packed-sign-v131-dedicated-1000`: 244 normalized plus 756 established smaller Starshine local/default/drop-debris residuals, zero validation/property/generator/command failures; all 756 are smaller, no scanned H2L operation has presence drift, and no residual contains `array.get_s` or `array.get_u`;
- wasm-smith `.tmp/pass-fuzz-heap2local-final9-packed-sign-v131-wasm-smith-1000`: 997/1,000 normalized, three Binaryen command failures, zero mismatches or Starshine failures;
- bounded random-all `.tmp/pass-fuzz-heap2local-final9-packed-sign-v131-random-all-100`: 85 normalized plus 15 smaller residuals, zero validation/property/generator/command failures, and no packed get residual. Two constructor-presence differences belong to `memory-packing-boundaries` and `ssa-nomerge-smoke`, not Heap2Local leaves.

These are repair smoke lanes, not a replacement for the existing full four-lane closeout matrix below.

Regular direct lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --out-dir .tmp/pass-fuzz-heap2local --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --wasm-opt-bin <verified-v133-wasm-opt> --require-binaryen-version 133 --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid aggregate: `heap2local-all`.

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --gen-valid-profile heap2local-all --out-dir .tmp/pass-fuzz-heap2local-genvalid-all-10000 --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --wasm-opt-bin <verified-v133-wasm-opt> --require-binaryen-version 133 --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Aliases accepted by GenValid profile lookup: `heap2local`, `heap-to-local`, `h2l`, `heap2local-closeout`, and `heap2local-all-profiles`.

## Profile leaves

- `heap2local-struct`: local-held fresh struct candidates with `struct.new` / `struct.new_default`, `struct.set`, `struct.get`, owner locals, and local-copy-shaped traffic.
- `heap2local-array`: constant-size local-held array candidates with `array.new_default`, `array.new_fixed`, constant-index `array.get`, and `array.set`.
- `heap2local-ref`: direct fresh-reference folds with `ref.as_non_null`, `ref.eq`, and `ref.test` over fresh struct allocations.
- `heap2local-owner-updates`: three conditional allocation epochs assigned to the same nullable three-field owner. Later constructors read the preceding owner's fields, with swapped fields, cyclic reads, and a constant first operand followed by old-field reads. Three independent i32 branch parameters and three exported i32 results make each allocation choice observable.

The aggregate samples all four leaves and records the selected leaf through the normal composite-profile manifest `selected_profile` field. Use that field when triaging generated mismatches so struct scalarization, array lowering, ref folds, and owner updates stay separated. The older recorded aggregate counts below use the original three leaves.

The owner-update leaf derives bounded field values and its operand family directly from the recorded source seed (`seed % 3`). The usual config label, GC constructor/accessor facts, and exact opcode counts remain available. Its [bounded generator tests](../../../../../src/validate/gen_valid_heap2local_owner_updates_wbtest.mbt) check three adjacent seeds, valid modules, replay equality, same-owner publication order, per-arm field reads, independent branch parameters, and exported numeric observations. Use the singleton profile for a targeted reproduction and `heap2local-all` for ordinary dedicated-profile signoff. The October 15 renewal below includes 3,011 owner-update cases; older three-leaf results keep their historical scope.

## Current smoke status

A 2026-07-02 first aggregate smoke after profile config fixes, `.tmp/pass-fuzz-heap2local-genvalid-all-1000-aggregate-config-fix`, compared `278/1000` before hitting the mismatch cap: `67` normalized matches, `211` mismatches, zero command/validation/generator/property failures, selected profiles `heap2local-struct=131`, `heap2local-array=75`, and `heap2local-ref=72` before cap. Treat these as open behavior-parity gaps; do not use the profile as a green signoff lane until the mismatch families are reduced or fixed.

A follow-up slice reduced `case-000001` (`selected_profile=heap2local-struct`) to repeated same-owner fresh struct allocations with a self-copy write. Starshine now scalarizes that generated family and removes residual `struct.new`, `struct.new_default`, `struct.get`, and `struct.set` traffic. Replay `.tmp/pass-fuzz-heap2local-case000001-after-sequential-owner` still reports a raw mismatch (`1/1`, zero failures) because Binaryen preserves extra local/default-value/drop debris while Starshine emits a smaller scalarized form. Agent classification: **behavior-parity improvement plus residual output-shape/local-debris drift**, not the original true GC-scalarization parity gap. A 100-case struct leaf smoke, `.tmp/pass-fuzz-heap2local-struct-100-after-sequential-owner`, compared `100/100`: `18` normalized and `82` mismatches, zero failures; every saved Starshine mismatch had no residual `struct.new`, `struct.get`, or `struct.set`. A classifier over the `82` saved struct residuals found `82/82` with no residual GC ops and `82/82` with smaller Starshine canonical wasm, so this sampled struct residual family is currently agent-classified as Starshine output-shape/local-debris wins pending a H2L-specific normalizer or larger-lane confirmation.

A third slice reduced aggregate `case-000015` (`heap2local-array`) to repeated same-owner fixed array allocation epochs and aggregate `case-000004` (`heap2local-ref`) to direct fresh `struct.new_default` `ref.test`. Starshine now scalarizes straight-line repeated same-owner array epochs and folds direct fresh-struct `ref.test` to `i32.const 1`. Replays `.tmp/pass-fuzz-heap2local-case000015-after-sequential-array` and `.tmp/pass-fuzz-heap2local-case000004-after-direct-struct-reftest` still mismatch raw compare but have no residual array/struct/ref-test traffic; the residual is Binaryen's preserved scalar local/default/drop scaffolding. The post-fix aggregate smoke `.tmp/pass-fuzz-heap2local-all-100-after-sequential-array-reftest` compared `100/100`: `22` normalized, `78` mismatches, zero command/validation/generator/property failures, Binaryen cache `100/0`, selected profiles `heap2local-struct=49`, `heap2local-array=22`, and `heap2local-ref=29`. Agent classifier over all `78` saved mismatches found no residual generated H2L operations in Starshine output (`struct`/`array`/`ref.eq`/`ref.test` tokens absent) and `78/78` smaller Starshine canonical wasm.

A scaled generated lane, `.tmp/pass-fuzz-heap2local-all-1000-after-array-reftest`, compared `1000/1000`: `244` normalized, `756` residual mismatches, zero command/validation/generator/property failures, Binaryen cache `1000/0`, selected profiles `heap2local-struct=423`, `heap2local-array=276`, and `heap2local-ref=301`. Saved residuals by selected leaf were `heap2local-struct=351`, `heap2local-array=146`, and `heap2local-ref=259`; inferred normalized-by-leaf counts were `struct=72`, `array=130`, and `ref=42`. A classifier over all `756` saved residuals found no Starshine residual generated H2L operations (`struct.new`, `struct.new_default`, `struct.get`, `struct.set`, `array.new`, `array.new_default`, `array.new_fixed`, `array.get`, `array.get_s`, `array.get_u`, `array.set`, `ref.eq`, or `ref.test`) and `756/756` smaller Starshine canonical wasm than Binaryen. Representative sampled diffs for `case-000001` (`struct`), `case-000015` (`array`), and `case-000004` (`ref`) show Binaryen preserving scalar temp/default/null drops while Starshine emits the shorter scalarized form. Existing normalizers did not classify this family: reruns with `--normalize ssa-local-allocation-debris --normalize local-cleanup-debris` and with `--normalize drop-consts --normalize ssa-local-allocation-debris --normalize local-cleanup-debris` both stayed at `244` normalized, `0` compare-normalized, and `756` mismatches.

The required dedicated `10000` lane first hit the mismatch cap with `.tmp/pass-fuzz-heap2local-all-10000-after-array-reftest`: `2689/10000` compared, `679` normalized, `2010` mismatches, zero failures, selected profiles `heap2local-struct=1159`, `heap2local-array=787`, and `heap2local-ref=743`. It was rerun with the cap raised so the profile could complete: `.tmp/pass-fuzz-heap2local-all-10000-full-residuals-after-array-reftest` compared `10000/10000`: `2474` normalized, `7526` residual mismatches, zero command/validation/generator/property failures, Binaryen cache `10000/0`, selected profiles `heap2local-struct=4290`, `heap2local-array=2885`, and `heap2local-ref=2825`. Saved residuals by selected leaf were `heap2local-struct=3600`, `heap2local-array=1437`, and `heap2local-ref=2489`; inferred normalized-by-leaf counts were `struct=690`, `array=1448`, and `ref=336`. A classifier over all `7526` saved residuals found no residual generated H2L operations in either Starshine or Binaryen WAT for the same scanned operation set, and found `7526/7526` Starshine canonical wasm outputs smaller than Binaryen. The byte deltas were stable by leaf: struct residuals were `79` bytes vs Binaryen `105` (`-26`), array residuals `83` vs `106` (`-23`), and ref residuals `76` vs `107` (`-31`). Late representative samples `case-001001` (`struct`), `case-001010` (`array`), and `case-001008` (`ref`) match the earlier pattern: both tools eliminate the generated H2L operations, while Binaryen preserves scalar temp/default/null drops that Starshine omits.

Current agent judgment for the scaled generated lanes: **Starshine output-shape/local-debris wins after H2L traffic removal**, not active generated H2L misses. The full dedicated profile is now documented at the required `10000` scale.

## Final-matrix refresh and normalizer decision

A later 2026-07-02 slice inspected the compare normalizer surface and chose **not** to add a H2L-specific normalizer yet. Existing generic normalizers are syntax/debris scoped (`drop-consts`, `unreachable-control-debris`, `local-cleanup-debris`, `ssa-local-allocation-debris`), and the H2L residual family would require semantic gating on generated H2L traffic plus paired Binaryen/Starshine output inspection. Rather than risk hiding future generated allocation/get/set/ref residuals behind cleanup normalization, the dedicated H2L family remains a raw-mismatch, agent-classified Starshine output-shape win with explicit reopening criteria: reopen if any dedicated or random-all residual contains generated H2L ops in either output, Starshine is not smaller, validation/property failures appear, or source-backed Binaryen transform families remain unimplemented.

Current signoff-lane refresh with `_build/native/release/build/cmd/cmd.exe`:

- Regular GenValid `.tmp/pass-fuzz-heap2local-genvalid-100000-20260702`: `100000/100000` compared, `100000` normalized, zero cleanup-normalized matches, zero mismatches, zero validation/generator/property/command failures, Binaryen cache `314/99686`, selected profile `binaryen-oracle-portable=100000`.
- Explicit wasm-smith `.tmp/pass-fuzz-heap2local-wasm-smith-10000-20260702`: `9956/10000` compared, `9955` normalized, one raw mismatch, and `44` Binaryen/oracle command failures. The single mismatch, `case-009332-wasm-smith`, is unrelated to H2L and is the known unreachable-control-debris shape (`drop(unreachable)` before `unreachable`). Replay `.tmp/pass-fuzz-heap2local-wasm-smith-case9332-normalized` with `--normalize unreachable-control-debris` compared `1/1` with one compare-normalized match and zero failures. Full rerun `.tmp/pass-fuzz-heap2local-wasm-smith-10000-unreachable-normalized-20260702` compared `9956/10000` with `9955` normalized, `1` compare-normalized, `0` mismatches, and the same `44` command failures (`39` rec-group-zero plus invalid-tag/table-index/bad-section parser classes as recorded in `cases.jsonl`).
- Broad random-all-profiles `.tmp/pass-fuzz-heap2local-genvalid-random-all-profiles-10000-20260702`: `10000/10000` compared, `8772` normalized, `1228` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `2183/7817`. Selected profiles were `ssa-nomerge-smoke=1699`, `heap2local-array=454`, `coverage-forced-portable=1610`, `ssa-nomerge-parity=1644`, `heap2local-struct=715`, `binaryen-oracle-portable=1703`, `pass-fuzz-stress=1691`, and `heap2local-ref=484`. All mismatches came from the H2L leaves: `struct=587`, `array=221`, `ref=420`; classifier found no residual generated H2L ops in either output, `1228/1228` smaller Starshine canonical wasm, and the same stable deltas (`struct -26`, `array -23`, `ref -31` bytes).

## Binaryen v131 refresh

Final explicit-v131 lanes use `_build/native/release/build/cmd/cmd.exe`, `.tmp/binaryen-version-131-bin/bin/wasm-opt`, and `.tmp/h2l-v131-cache`:

- Regular `.tmp/h2l-v131-regular-10000-final`: `10000/10000` normalized, zero failures or mismatches.
- Wasm-smith `.tmp/h2l-v131-wasm-smith-10000-final`: `9956/10000` compared, `9955` normalized, one `unreachable-control-debris` compare-normalized match, zero mismatches, and `44` Binaryen command failures.
- Dedicated `.tmp/h2l-v131-all-10000-final`: `2474` normalized plus `7526` raw residuals. Both outputs contain no generated H2L operations in every residual; Starshine is smaller in `7526/7526`, with stable deltas `struct -26`, `array -23`, and `ref -31`, saving `203810` canonical bytes in aggregate.
- Random `.tmp/h2l-v131-random-all-10000-final`: `8517` normalized plus `1483` raw residuals, zero failures. The residual profiles are `local-subtyping-straight-line=712`, `heap2local-struct=297`, `heap2local-ref=206`, `heap2local-array=131`, `precompute-gc-values=72`, and `precompute-gc-atomic-boundary=65`; no scanned H2L operation has presence drift between outputs, Starshine is smaller in `1483/1483`, and aggregate savings are `37178` bytes.

The random lane exposed and now locks additional direct behavior: nullable GC-supertype drop-only struct owners, direct fresh nonpacked and packed struct/array reads, and fixed-array OOB trapping. The official shared reference-valued `acqrel` cmpxchg fixture is not classified as green: Starshine decodes it but rejects it during validation because reference-valued aggregate atomic RMW/cmpxchg is not represented by the current validator/atomic semantics.

## Pass-local timing and O4z slot evidence

A bounded pass-local probe over nine representative dedicated-profile inputs from `.tmp/pass-fuzz-heap2local-all-10000-full-residuals-after-array-reftest/inputs/gen-valid/` recorded Starshine H2L pass-local times between `0.031ms` and `0.044ms` (median `0.033ms`) versus Binaryen `0.061245ms` to `0.074439ms` (median `0.068469ms`). Every sampled case was inside the repo pass-local floor and kept the same smaller Starshine residual sizes (`79/105`, `83/106`, or `76/107` bytes depending on leaf).

Current generated `-O4z` slot evidence used `_build/wasm/debug/build/cmd/cmd.wasm` rebuilt in this checkout and a Binaryen-produced predecessor after the current Starshine/Binaryen no-DWARF prefix through the pass immediately before H2L:

```sh
wasm-opt _build/wasm/debug/build/cmd/cmd.wasm --all-features \
  --once-reduction --global-refining --gsi --ssa-nomerge --dce \
  --remove-unused-names --remove-unused-brs --remove-unused-names --vacuum \
  --remove-unused-brs --optimize-instructions --heap-store-optimization \
  --pick-load-signs --precompute --code-pushing --tuple-optimization \
  --simplify-locals-nostructure --vacuum --reorder-locals --remove-unused-brs \
  -o .tmp/h2l-o4z-slot-evidence-20260702/prefix-before-h2l.wasm
bun scripts/self-optimize-compare.ts .tmp/h2l-o4z-slot-evidence-20260702/prefix-before-h2l.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/h2l-o4z-slot-evidence-20260702/slot-h2l-compare \
  --timing-only --heap2local
```

The direct H2L slot was an exact canonical match: Starshine and Binaryen outputs were both `3,015,145` bytes, `wasmEqual=true`, and selected outputs validated. The measured pass-local time was inside the repo floor (`67.539ms` Starshine vs `153.397ms` Binaryen in the standalone slot run; a repeated prefix table recorded `60.175ms` vs `116.222ms`). Whole-command Starshine time stayed slower (`1907.600ms` vs `522.067ms`) because traced non-pass decode/validation/command work dominated; classify that under `[WALL]001`, not as an H2L pass-local blocker.

The adjacent GC/local-cleanup neighborhood was replayed incrementally from the same predecessor. `heap2local`, `heap2local + optimize-casts`, and `heap2local + optimize-casts + local-subtyping` were exact canonical matches. Adding `coalesce-locals` introduced a broader neighborhood output-size gap (`3,012,858` Starshine bytes vs `2,860,415` Binaryen), and adding `local-cse` kept that gap (`3,012,790` vs `2,858,855`). Because the H2L-only, H2L+OC, and H2L+OC+LS prefixes are exact and validated, the current neighborhood gap is classified as neighbor-owned ordered-pipeline evidence rather than an H2L blocker.

## Closeout status

H2L is audit-complete for the representable Binaryen v131 direct-pass/O4z scope. The recorded four-lane matrix is complete; sequential branch-target and unreachable-flow behavior is focused and green; dedicated and random residuals have equal H2L-operation presence and strictly smaller Starshine output; wasm-smith's sole residual is generic unreachable-control debris; and the rebuilt v131 O4z H2L slot is an exact `4180576`-byte canonical match with pass-local `101.912ms` Starshine versus `160.650ms` Binaryen. Reopen for validation/property failures, H2L-operation drift, a size-losing residual, or when shared reference-valued ordered atomic RMW/cmpxchg becomes representable.

## Known exclusions

The dedicated profile intentionally focuses on validator-accepted H2L opportunities. It does not force nondefaultable-local repair, broad descriptor-cast traffic, escapes through calls/returns, arbitrary mixed branch/select provenance, dynamic array sizes/indexes, or the full atomic/RMW/cmpxchg surface. The owner-update leaf covers branch-selected fresh structs of one concrete type. In particular, the v131 shared reference-valued `acqrel` cmpxchg scratch-local fixture is a recorded validator/atomic-semantics blocker, not an accepted parity difference.

## Required signoff use

For ordinary H2L audit signoff, use the 10,000-case `heap2local-all` lane with a fresh prebuilt native binary and a verified Binaryen 133 oracle. Run a separate external-generator lane only when explicitly requested. The older four-lane records below retain their original scope and versions.

### October 15 owner-publication semantic renewal

Five fixed seeds from the empty-body cases now have red-first generator tests.
Dedicated struct/reference profiles reserve one GC type slot; array/all profiles
reserve three because ordinary and packed struct definitions precede the array.
The existing Natural-mode rule, profile weights, seed streams, public API and
fact calculation remain unchanged. All 176 selected generator controls pass,
including [the five constructor/accessor trigger tests](../../../../../src/validate/gen_valid_heap2local_dedicated_trigger_wbtest.mbt).
This repaired future generated coverage without changing that completed batch.
The current-source renewal above subsequently establishes10,000 nonempty
constructor/accessor comparisons.

The owner-publication and control-ownership repairs complete a dedicated native
10,000-case comparison against verified Binaryen 133. Build `6184d26753bd4cc8`
contains Heap2Local source `0288fd59306028c6` and SimplifyLocals source
`abc4325970ae7a`; subsequent Tuple/Coalesce changes require their own build and
checks. This renews these two repaired source owners, not every later worktree
change or the older external-generator lanes.

- All 10,000 original/Starshine/Binaryen Node-v2 semantic observations agree.
  All cases validate, are byte-deterministic, and pass codec idempotence.
  There are no runtime-blocked, generator, command, or property failures.
- The aggregate samples 3,011 owner-update, 3,019 struct, 2,026 array, and
  1,944 reference cases. It has 1,758 normalized matches and 8,242 structural
  differences. Starshine canonical bytes total 1,124,174 against 1,296,745;
  every difference is smaller, and no case is larger.
- Coverage limit: the manifest identifies 1,758 empty function bodies with no
  heap constructors or accesses (978 array, 514 struct, 266 reference cases).
  These are exactly the normalized matches; they do not exercise scalarization.
  The other 8,242 bodies are nonempty. All retained 20 reports have nonempty
  invocation plans and actual exported calls: 139 calls per tool in total.
  Per-case plans for the other 9,980 cases were consumed, so their exact total
  call count is unavailable. Do not describe all 10,000 inputs as heap rewrites.
- Independent inspection of the 20 retained bundles covers reference/default
  cleanup (-31 bytes), sequential struct epochs (-26), sequential array epochs
  (-23), and staged branch-selected updates (-13). **Agent judgment: scoped
  Starshine wins.** The judgment uses the inspected field/epoch transitions,
  non-escaping allocation contracts, complete three-way observations, and byte
  savings. Validation or smaller bytes alone do not establish semantics.
  The artifact cap does not provide full shape inspection of all 8,242 cases.
- The separate [native runtime lane](../../../../../scripts/test/heap2local-owner-update-runtime.ts)
  checks 1,278 cases across eight outputs (10,224 comparisons), including
  packed bounds, tee-store ordering, non-null references, nested constructors,
  aborted publication, exceptions, and repeated cleanup. All observations match
  the original and the oracle. Source regressions additionally check shared
  control ownership and donor preservation.

The later unsigned packed-read extension uses build `f4a1b19775b649b8`,
with the same Heap2Local and SimplifyLocals source owners. It adds scalarized
i8/i16 signed and unsigned reads across struct/array replacement epochs and
array-tee constructor trap boundaries. All 1,446 cases across eight outputs
agree (11,568 comparisons). Implementing and dispatcher tests assert masks,
sign extension, valid round trips, and removal of the tested heap operations.
This extends semantic coverage; it does not replace the earlier fixture's size
measurements below. Raw output is in `.tmp/heap2local-owner-runtime-GHbIoM`.

The final whole-build checkpoint `a379e1a3d7d95e79b` reruns all 11,568 native
comparisons successfully (`.tmp/heap2local-owner-runtime-L2YOSQ`). The expanded
fixture encodes 6,128 input bytes, 5,855 after Starshine Heap2Local alone and
5,348 after Binaryen (+507 Starshine bytes). Cleanup gives 4,189 versus 4,435.
Static local/reference-local totals are 262/75 before cleanup and 70/53 after
cleanup; original totals are 46/45 and Binaryen cleanup totals 52/45. These
counts expose storage cost; they do not prove GC retention. The measured
`repeated` export removes all ten heap instructions and uses eight locals
(four after cleanup), versus two locals and ten heap instructions in Binaryen.
Raw footprint, seven rotating CLI rounds and separate V8 samples are in
`.tmp/report-optimization-20261014/heap-footprint/run-PSB2hK`. This supersedes the
older fixture totals only for the expanded input hash recorded there.

The combined runtime fixture also exposes a cost: Heap2Local alone emits
4,944 bytes against Binaryen's 4,240 (+704). The stated cleanup roster emits
3,482 against 3,724; repeating cleanup emits 3,307 against 3,694. Keep the
pass-only size gap open for that broader fixture. Per-producer staging adds
O(producers × retained fields) scalar storage and publication operations.
These semantic/size checks establish no general runtime, allocation-byte,
RSS, GC-retention, or startup gain.

Local raw evidence is retained under
`.tmp/report-optimization-20261014/fuzz-final/heap2local`,
`.tmp/heap2local-owner-runtime-ND07bu`, and
`.tmp/report-optimization-20261014/review/final-heap-independent-2.txt`.
The campaign uses seed `0x5eed`, eight subprocesses, a 5,000 ms semantic
deadline, determinism, codec idempotence, and a 20 structural-artifact cap.
No external wasm-smith lane ran.

### September 15 retained type overhead repair

After writeback, guarded whole-group pruning removes unused signatures and
recursive hierarchies while retaining stronger scalarization. Two red-first
pass cases and all 72 heap2local tests pass, including direct byte reduction.
[Proof and scope](../../../ir2/architecture-rules.md#heap2local-retained-type-overhead-repair).
Final native aggregate renewal remains pending.

### September 16 current-source renewal

The [final-source renewal](../../../ir2/architecture-rules.md#september-16-final-source-fuzz-renewal)
supersedes pending aggregate-renewal notes above. Fresh native binaries and
verified Binaryen 132 complete the following comparison checks:

- `heap2local`: 10,000 compared; 2,474 normalized and 0 cleanup-normalized matches; 7,526 residuals; 0 raw-larger and zero canonical-larger outputs.

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
