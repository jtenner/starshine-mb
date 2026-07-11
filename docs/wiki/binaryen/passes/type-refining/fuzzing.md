---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `type-refining` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` lane for `type-refining` today.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps `type-refining` boundary-only. An explicit request intentionally rejects; no local owner pass exists.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--type-refining` in `SUPPORTED_PASS_FLAGS`, and it has no admitted mapping for the upstream `type-refining-gufa` companion.
- A rejected command, a boundary-only diagnostic, or zero comparisons is a **status check**, not Binaryen-parity evidence. Follow the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the admitted harness roster:

```text
bun fuzz compare-pass --list-passes
```

## Why ordinary GenValid is insufficient by itself

The normal upstream pass is a closed-world GC type-graph rewrite: it infers private struct-field types from writes, then repairs reads and writes after the declarations become narrower. Its GUFA sibling shares the rewrite back end but uses different inference. A generic random lane can neither identify which variant ran nor prove the required fixups.

Before a runnable lane exists, focused fixtures must cover at least:

- non-GC/open-world, public-type, array, and unsupported continuation boundaries;
- direct private `struct.set` inference positives plus the tee-versus-block fallthrough distinction;
- nullability, exactness, subtype-LUB, and result/read repair cases after a field narrows;
- constructor, set, RMW, and cmpxchg sites that require casts, traps, or value preservation after rewriting; and
- a separate status decision and fixtures for `type-refining-gufa`, rather than silently treating it as the normal pass.

See [`./wat-shapes.md`](./wat-shapes.md), [`./normal-vs-gufa-and-fixups.md`](./normal-vs-gufa-and-fixups.md), and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Future runnable template

Enable a comparison lane only after all of these are true:

1. an active Starshine closed-world module pass implements a documented normal `type-refining` subset;
2. the registry and docs state whether `type-refining-gufa` is separately unsupported, mapped, or implemented;
3. `SUPPORTED_PASS_FLAGS` admits the active spelling and `bun fuzz compare-pass --list-passes` reports it; and
4. a GC/type-aware fixture corpus or generator profile yields meaningful compared cases with an explicit `--min-compared` threshold.

Candidate command shape once those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass type-refining --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-type-refining --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. Record the closed-world configuration, normal-versus-GUFA scope, profile/fixture mix, normalizers, and replay-artifact contract before using it as parity evidence.
