---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-abstract-type-refining-v130-main-admission-recheck.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `abstract-type-refining` fuzzing

## Current state: planned, not runnable

Do **not** run or publish a `compare-pass` smoke command for this pass today.

- `abstract-type-refining` is `BoundaryOnly` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), so an explicit Starshine request is intentionally rejected rather than transformed.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--abstract-type-refining` in `SUPPORTED_PASS_FLAGS`, so `bun fuzz compare-pass --pass abstract-type-refining ...` fails during option parsing before generation or oracle comparison.
- Neither failure proves semantic parity, a safe no-op, or Binaryen compatibility. The current evidence is the registry/admission boundary described in [`./starshine-strategy.md`](./starshine-strategy.md), not a comparison count.

This corrects the older page's misleading runnable-command wording. The reviewed upstream source floor is Binaryen `version_130`; the current-main web snapshot needs a pinned-checkout recheck before it can support a main-specific implementation claim. See [`../../../raw/binaryen/2026-07-11-abstract-type-refining-v130-main-admission-recheck.md`](../../../raw/binaryen/2026-07-11-abstract-type-refining-v130-main-admission-recheck.md).

## What a future lane must cover

A real lane must exercise a **closed-world GC** module pass, not merely generic reference instructions. Targeted fixtures and/or a dedicated GenValid profile need to distinguish:

1. no-GC and non-closed-world gates;
2. `struct.new*` creation evidence versus harmless type mentions;
3. always-on never-created-family bottomization;
4. TNH-only unique-live-child parent refinement and multiple-live-child bailouts;
5. exact casts that must remain impossible rather than becoming live-child successes;
6. descriptor casts, `ref.get_desc`, `br_on_cast_desc_eq*`, and `struct.new_desc` side-effect/null-trap repairs; and
7. coherent rewritten uses in locals, signatures, globals, module code, and recursive groups.

The upstream shape contract is in [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./traps-never-happen-exact-casts-and-descriptors.md`](./traps-never-happen-exact-casts-and-descriptors.md), and [`./wat-shapes.md`](./wat-shapes.md).

## Admission gates before publishing a command

Enable parity fuzzing only after all four conditions hold:

1. Starshine promotes the name from `BoundaryOnly` to an implemented module-pass registry/dispatcher entry with focused tests.
2. The comparison harness admits the exact public spelling, and `bun fuzz compare-pass --list-passes` shows it.
3. A closed-world GC fixture/profile proves meaningful coverage of the seven shape families above; use the same pinned Binaryen source revision for owner, helpers, and fixtures.
4. The first documented run states Binaryen revision, feature/world/TNH settings, `--min-compared`, normalizers, command-failure policy, and replay artifact location.

## Future command template

After those gates are met, a future maintainership change may replace this template with an executed result:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass abstract-type-refining \
  --gen-valid-profile abstract-type-refining --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-abstract-type-refining --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The profile name is intentionally illustrative: it does **not** exist today. Do not silently substitute a generic lane unless its feature facts and generation policy prove the closed-world GC/TNH/descriptor coverage required here.
