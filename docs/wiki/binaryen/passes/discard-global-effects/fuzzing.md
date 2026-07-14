---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ./index.md
  - ./metadata-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./metadata-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../global-effects/index.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `discard-global-effects` fuzzing status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `discard-global-effects` today.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--discard-global-effects` in `SUPPORTED_PASS_FLAGS`, so the harness rejects the argument before input generation or either optimizer runs.
- Starshine has no `discard-global-effects` registry entry or dispatcher implementation in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). Its boundary-only `global-effects` entry is a different, producer-side compatibility name.
- More fundamentally, the upstream pass clears in-memory `Function.effects` metadata while leaving the module's Wasm text unchanged. A canonical WAT match—or a run with zero meaningful metadata observations—would not prove cleanup correctness. See [`index.md`](index.md), [`metadata-shapes.md`](metadata-shapes.md), and the upstream source capture [`../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md`](../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md).

A rejected command is therefore a **status check**, not a failed smoke lane or Binaryen-parity evidence. Apply the four pass-admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the harness roster:

```text
bun fuzz compare-pass --list-passes
```

## Why ordinary compare-pass output is insufficient

Binaryen's upstream owner clears every defined function's stored effect summary:

```text
before: Function.effects = known summary | absent
pass:   Function.effects.reset()
after:  Function.effects = absent
Wasm:   unchanged
```

That means a future port needs **metadata-observable** testing first. A WAT-only compare harness can be a secondary composition check after an effect-sensitive consumer runs, but it cannot be the primary oracle for the cleanup itself.

A meaningful future test sequence is:

1. create persistent module-level summaries with a producer compatible with Binaryen `generate-global-effects`;
2. inspect that selected functions carry known summaries;
3. run `discard-global-effects`;
4. inspect that every summary is absent, including previously empty/imported/unchanged-body cases; and
5. run an effect-sensitive consumer or invalidating rewrite to prove it recomputes facts or behaves conservatively instead of reading stale metadata.

The current Starshine HOT effect cache is revision-keyed analysis state, not persistent module metadata, so it does not supply steps 1–4 yet. See [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).

## Future admission and validation plan

Do not enable a canonical compare lane until all of these are true:

1. Starshine has a real persistent producer and an active cleanup pass, not a no-op or a boundary-only rejection;
2. `SUPPORTED_PASS_FLAGS` admits `--discard-global-effects`, and `bun fuzz compare-pass --list-passes` reports it;
3. the local spelling maps to Binaryen's public `--discard-global-effects` flag; and
4. a metadata-observer test adapter or a dedicated in-process test can assert summary presence/absence before and after the pass.

Only then may a **secondary** composition lane use a command shaped like:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass global-effects --pass discard-global-effects \
  --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-discard-global-effects \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is deliberately a future template, not current guidance. The future harness also needs an explicit policy for how `generate-global-effects` is spelled locally (`global-effects` today is boundary-only) and how it observes metadata rather than inferring correctness from unchanged WAT.

## Required targeted cases before signoff

| Case | Required assertion |
| --- | --- |
| No summaries | Cleanup is idempotent and leaves module bytes/WAT unchanged. |
| One defined function with a known summary | The exact metadata field becomes absent. |
| Multiple defined functions | Cleanup clears every function, not only a changed or reachable one. |
| Imported function | Preserve its declaration while defining and testing the intended summary policy explicitly. |
| Producer → cleanup → consumer | Consumer cannot observe a stale summary; it recomputes or uses conservative facts. |
| Effect-adding rewrite after production | Lifecycle invalidation and explicit cleanup agree; neither leaves a stale fact usable. |
| Binary/WAT roundtrip | Confirms that metadata-only cleanup does not accidentally mutate emitted Core Wasm. |

When a local implementation exists, report metadata-observer results, composition outcomes, compared-case counts, and any canonical WAT drift separately. Do not call an unchanged WAT result a parity proof for metadata cleanup.
