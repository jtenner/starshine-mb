---
kind: workflow
status: working
last_reviewed: 2026-09-15
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
---

# `global-refining` Fuzzing Profile

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## 2026-08-21 nominal-ancestry scratch renewal

The pass-scoped ancestry scratch and first-common-declared-ancestor search preserve the nominal sibling-join behavior while eliminating per-query traversal arrays. Rebuilt native SHA-256 is `438531b72a40f9afbda4f12b768e036470f7302cdc01e950c2160cacb11feb0c`. The ordinary explicit-v131 GenValid lane at `.tmp/pass-fuzz-global-refining-ancestry-scratch-10000-20260821` compared **10,000/10,000** with **10,000 normalized matches**, zero compare-normalized matches, mismatches, validation failures, property failures, generator failures, or command failures. Binaryen cache counters were 2 hits / 9,998 misses; Binaryen failure cache counters were 0/0. The oracle was `.tmp/binaryen-version-131-bin/bin/wasm-opt`, version 131, SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

This remains ordinary repair/performance evidence, not four-lane final closeout: the pass still has no dedicated profile that deliberately generates branching nominal sibling writes.

## 2026-08-20 ref.func indexed-type correction

Native SHA-256 `b536e6105356d6b51dc10c7954047c933159dd46809b7c47566f979198a91093` corrects the local ref.func fact model. Pinned Binaryen v131 and `wasm-tools` treat `ref.func` as a non-null indexed function reference `(ref $type)`, not `(ref (exact $type))`. The former exact initializer/write facts could refine a mutable global to an exact type while its initializer or later `global.set` still produced a non-exact reference, yielding an externally invalid module. Initializer seeding and HOT `global.set` collection now share the same non-exact indexed fact helper; GC allocation constructors remain exact.

The direct `ref_func.1` replay now validates externally. A validated O4z continuation `global-refining -> optimize-instructions -> precompute -> duplicate-function-elimination` folds the resulting non-null `ref.is_null` function and reduces 231 → 225 bytes, byte-identical to Binaryen. Fresh-instance mutation and indirect-call probes preserve all `is_null`, `set-f`, `set-g`, `call-f`, `call-g`, and `call-v` behavior.

Renewed ordinary GenValid artifact `.tmp/pass-fuzz-global-refining-ref-func-indexed-10000` uses explicit `.tmp/binaryen-version-131-bin/bin/wasm-opt`: 10,000/10,000 compared, 10,000 normalized matches, zero mismatches, and zero validation/property/generator/command failures. Binaryen cache counters are 2 hits / 9,998 misses. This remains repair evidence rather than a complete four-lane closeout because no pass-owned dedicated profile exists yet.

Historical ordinary lane (retained for provenance; use the dedicated profile below for new pass evidence):

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-refining --out-dir .tmp/pass-fuzz-global-refining --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The 2026-08-20 nominal sibling-join repair used `.tmp/pass-fuzz-global-refining-sibling-join-10000` with this command shape: 10,000/10,000 compared, 10,000 normalized matches, zero mismatches, zero validation/property/generator/command failures, and Binaryen cache 2 hits/9,998 misses.

Dedicated GenValid profile: none documented for this pass yet. This repair did not declare final pass closeout; a future closeout still needs a pass-owned profile that deliberately generates declared sibling subtype joins, plus the full four-lane matrix.

If a future audit adds a pass-specific GenValid profile, update this page with the profile name, intended smoke/closeout count, any required `--require-feature` floors or `--normalize` flags, and the manifest fields needed for replay triage.

### September 15 encoding and coverage distinction

The current ordinary lane's 10,000 inputs contain no globals: its raw losses
measure numeric-local grouping and unused/duplicate function types, not global
refinement. The pass boundary now reuses guarded encoding cleanup; red-first
pass/command cases and all 24 global-refining tests pass.
[Proof and scope](../../../ir2/architecture-rules.md#global-refining-generic-encoding-repair).
A dedicated reference-global profile and final native renewal remain pending.
Historical versioned comparison counts above are preserved.

### September 15 dedicated reference-global aggregate

Use `global-refining-all` (alias `global-refining`) for ordinary dedicated signoff:

| Leaf | Generated contract |
| --- | --- |
| global-refining-private-writes | Narrower constructors/writes, nullable initializer variants |
| global-refining-export-boundaries | Mutable public type retained; immutable value refinement |
| global-refining-import-aliases | Mutable/immutable externref imports and dependent immutable aliases |
| global-refining-subtype-joins | Distinct sibling writes and varying parent hierarchy depth |

Field values vary by seed and exported functions read those values. Bounded
red-first generator and pass tests pass, as do all 1,833 validator tests.
This supersedes the absence-of-dedicated-profile limitation above; earlier
v131/v132 counts keep their original scope. [Coverage proof](../../../ir2/architecture-rules.md#global-refining-reference-global-coverage-repair).

```sh
moon build --target native --release src/cmd
bun fuzz compare-pass --pass global-refining --gen-valid-profile global-refining-all --count 10000 --seed 0x5eed --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version_132/bin/wasm-opt --require-binaryen-version 132 --out-dir .tmp/global-refining-dedicated
```

Final native results are pending campaign closeout.

### Dedicated-profile unused type repair

The first v132 reference-global aggregate exposed 7,500 raw size losses from
unused sibling types. Global-refining now invokes bounded whole-group cleanup
after refinement. The shared guard admits plain `ref.test` and `ref.cast`, whose
heap-type operands the DFE scanner/remapper already handles. Red-first tests
require dead sibling removal, retain types referenced only by these instructions,
and check operand remapping plus independent validation. The command dispatcher
also has a failing-before-fix sibling regression. Final aggregate renewal remains
pending; canonical equality alone did not close these raw losses.

### Grouped-local debug-name repair

Follow-up source review found that numeric-local grouping rewrote instructions
but left local names at old indices. Two red-first regressions now require the
same local permutation for names, preserving parameter indices and imported
function offsets. The command dispatcher covers the named case. Grouping
intentionally skips opaque, undecoded name payloads rather than corrupting their
indices. The common grouping helper now carries its permutation to the existing
name rewriter. Full-suite verification follows the remaining parity repairs.
