---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-ssa-current-main-and-local-admission-recheck.md
  - ../../../../../src/passes/ssa.mbt
  - ../../../../../src/passes/ssa_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../tooling/pass-fuzz-compare.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../ssa-nomerge/fuzzing.md
---

# `ssa` fuzzing and comparison boundary

## Current status: planned-only

Starshine has an **active partial** direct `ssa` pass: it handles selected non-merge local families and deliberately returns merge-read functions unchanged. That does **not** make a Binaryen-oracle compare lane runnable yet.

The compare-pass harness allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) includes `--ssa-nomerge` but not `--ssa`. Therefore this command is currently a safe roster inspection only:

```sh
bun fuzz compare-pass --list-passes
```

Do **not** publish or interpret `bun fuzz compare-pass --pass ssa ...` as a failed or green parity lane. It is rejected before input generation or either optimizer runs.

## Why active execution and harness admission differ

| Surface | Current fact | What it proves |
| --- | --- | --- |
| `src/passes/optimize.mbt` + `src/passes/ssa.mbt` | `ssa` is an active hot-pass name for non-merge families. | Direct local execution exists. |
| `src/passes/ssa_test.mbt`, registry tests, and CLI adapter tests | Repeated parameter writes and legal default-reference reads rewrite; a diamond merge stays unchanged. | The deliberately limited local behavior. |
| `scripts/lib/pass-fuzz-compare-task.ts` | `SUPPORTED_PASS_FLAGS` omits `--ssa`. | No compare-pass admission or canonical flag mapping exists. |
| Binaryen `SSAify.cpp` | Full `ssa` owns merge locals, incoming `local.tee`s, and parameter-entry prepends. | The larger upstream contract still missing locally. |

A direct CLI test is not a pass-parity test. A harness allowlist entry is not enough either: it must also map to the intended Binaryen flag and generate meaningful shapes.

## Admission checklist for a future lane

Before adding a runnable `ssa` comparison command, satisfy all four gates:

1. **Local scope:** retain active direct behavior and explicitly decide which full-SSA merge families are implemented.
2. **Oracle mapping:** map the canonical local `ssa` name to Binaryen `--ssa`, not `--ssa-nomerge`.
3. **Harness admission:** add `--ssa` to `SUPPORTED_PASS_FLAGS` with tests for the mapping and preflight behavior.
4. **Meaningful generation:** add a dedicated `ssa` GenValid profile with direct non-merge shapes plus explicit-write, parameter-entry, default-entry, and fail-closed nondefaultable merge fixtures as implementation grows.

After those gates, start with reduced WAT replays for each admitted mutation family. Then run the repository-standard direct-pass matrix with a freshly built `_build/native/release/build/cmd/cmd.exe`; do not use an older `target/native/...` artifact without freshness verification. See [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md).

## Current non-claim

The lack of a harness lane is a tooling/admission boundary. It does not prove that Starshine's direct non-merge subset is unavailable, nor does it hide the larger open parity gap: Binaryen's merge-local, incoming-tee, parameter-prepend, loop/branch/EH, and typed-control behavior remains work tracked in `[SSA-FULL]002C` onward.
