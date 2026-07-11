---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-avoid-reinterprets-current-main-recheck.md
  - ../../../raw/research/0516-2026-05-06-avoid-reinterprets-direct-revalidation.md
  - ../../../../../src/passes/avoid_reinterprets.mbt
  - ../../../../../src/passes/avoid_reinterprets_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../tooling/pass-fuzz-compare.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./single-load-chains-and-bailouts.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `avoid-reinterprets` fuzzing and signoff boundary

## Current state: admitted integration smoke, not complete parity signoff

`avoid-reinterprets` is admitted in the current compare-pass harness and is an active Starshine module pass:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) registers the spelling;
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) admits `--avoid-reinterprets`; and
- [`src/passes/avoid_reinterprets.mbt`](../../../../../src/passes/avoid_reinterprets.mbt) implements only adjacent direct full-width `load; reinterpret` pairs.

That makes this command a useful **integration smoke** for registry, dispatcher, encoding, validation, and unchanged-case behavior:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass avoid-reinterprets --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-avoid-reinterprets-genvalid-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Do **not** call a green generic run complete Binaryen parity. Current Binaryen also rewrites proven `reinterpret(local.get <- load)` chains with pointer and alternate-value helper locals; Starshine intentionally does not implement that family yet. Random valid input may contain few or no trigger shapes, and output validity or normalized equality alone cannot prove coverage of an absent transform.

The previous direct revalidation is historical evidence, not a substitute for a current directed profile: see [`../../../raw/research/0516-2026-05-06-avoid-reinterprets-direct-revalidation.md`](../../../raw/research/0516-2026-05-06-avoid-reinterprets-direct-revalidation.md).

## Required reduced fixtures before any comparison claim

Keep the focused local tests and add future cases in the layers below before treating a fuzz result as meaningful.

| Layer | Required cases | Current status |
| --- | --- | --- |
| Direct pairs | All four full-width scalar pairs, nested structured bodies, partial-load and non-load no-ops | Implemented; see [`src/passes/avoid_reinterprets_test.mbt`](../../../../../src/passes/avoid_reinterprets_test.mbt). |
| Indirect positive | One unique local source, copy chain, many reinterpret users, mixed original/reinterpret users | Upstream-only parity gap. |
| Indirect bailouts | Parameter/default entry, merged reaching definitions, non-fallthrough wrapper, unsupported cycle, partial/unreachable source load | Upstream-only parity gap. |
| Address width | Memory32 and memory64 indirect fixtures; inspect `i32` versus `i64` pointer helper local typing | Upstream-only parity gap. |

The exact upstream shape contract and the reasons for these boundaries are in [`./wat-shapes.md`](./wat-shapes.md) and [`./single-load-chains-and-bailouts.md`](./single-load-chains-and-bailouts.md). The current-main source capture confirms that these are still Binaryen's reviewed owner/fixture families: [`../../../raw/binaryen/2026-07-11-avoid-reinterprets-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-avoid-reinterprets-current-main-recheck.md).

## Missing dedicated profile

There is no checked-in `avoid-reinterprets` GenValid profile today. Generic GenValid is therefore a compatibility smoke, not a trigger guarantee.

Before declaring the direct slice re-signed or expanding it, add a stable profile (for example, `avoid-reinterprets-direct`) that emits at least one valid direct full-width pair in each module and records the selected pair/width. A second profile must not be added until the indirect local-provenance family exists; it should then generate the positive and bailout matrix separately rather than hiding failures in one broad random profile.

A future direct-profile lane should look like:

```text
bun fuzz compare-pass --pass avoid-reinterprets --count 10000 --seed 0x5eed \
  --gen-valid-profile avoid-reinterprets-direct \
  --out-dir .tmp/pass-fuzz-avoid-reinterprets-direct-10000 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This is a future template, not a command supported by the current profile roster.

## Completion gate

Do not mark this pass parity-complete until all of the following are true:

1. reduced direct, indirect-positive, indirect-bailout, and memory64 fixtures match the reviewed Binaryen behavior;
2. Starshine has a documented single-source provenance rule compatible with Binaryen's `LocalGraph` plus fallthrough behavior;
3. a dedicated GenValid profile proves it creates target opportunities; and
4. the normal project pass-signoff matrix is run with explicit native binary, parallel workers, and agent-classified mismatch evidence.

Until then, report the precise state: **active direct-load subset; generic compare-pass admitted; indirect provenance/helper-local parity still open**.
