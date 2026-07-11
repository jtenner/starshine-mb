---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `rereloop` / `re-reloop` Fuzzing Status

## Current status: planned-only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for this pass today.

Binaryen publishes the transform as `rereloop`, but Starshine's preserved local spelling is `re-reloop`. Neither spelling is currently runnable through the comparison harness:

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--rereloop` or `--re-reloop` in `SUPPORTED_PASS_FLAGS`, so either requested name is rejected during argument parsing, before input generation or either optimizer runs.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lists `re-reloop` as **Removed**, not active. Its request path deliberately rejects that known local name instead of dispatching a transform.
- The harness has no current `--re-reloop` → Binaryen `--rereloop` alias. Do not treat the spelling mismatch as harmless: mapping must be explicit before a future lane can be evidence.

A parser rejection, removed-pass rejection, or zero compared cases is a **status result**, not Binaryen-parity evidence. The upstream `rereloop` contract remains documented by the existing current-main source recheck in [`../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md); this page corrects only the local lane-admission claim.

## Safe inspection now

```text
bun fuzz compare-pass --list-passes
```

This reports only the current harness roster. It does not run `rereloop` or `re-reloop`, and it supplies no transform-oracle evidence.

## Future runnable-lane template

Use this **only after** every admission gate below is true:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass re-reloop --count 10000 --seed 0x5eed \
  --gen-valid-profile <flat-rereloop-profile> \
  --out-dir .tmp/pass-fuzz-rereloop --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

The template uses the current local spelling intentionally. If Starshine instead promotes `rereloop` or supports both names, document the chosen public contract and its exact Binaryen flag mapping before copying a command.

### Admission gates

1. **Harness:** admit the selected local spelling in `SUPPORTED_PASS_FLAGS`, test its mapping to Binaryen's public `--rereloop`, and make `--list-passes` report it.
2. **Starshine:** replace the `re-reloop` removed entry with an active implementation, dispatcher route, owner file, and focused tests. A known-but-rejected registry name is not sufficient.
3. **Flat-input surface:** add fixtures or a named generator profile that reaches the pass's required flat-control input discipline. Generic valid modules do not establish `Flat::verifyFlatness` or exercise CFG reconstruction.
4. **Oracle reachability:** include a meaningful `--min-compared` threshold and shape coverage for flat `if`, named block/loop targets, grouped `br_table` targets, dead-end repairs, and result-typed `unreachable` repair. Keep EH and non-flat cases as explicit rejection/bailout tests until a supported policy exists.

Before a generator profile exists, direct Binaryen `--flatten --rereloop` fixture runs remain useful upstream-shape evidence. They are **not** a substitute for an active Starshine comparison lane.

## Future signoff boundary

A real lane must classify output differences rather than treating valid output as parity. In particular, Binaryen's generic renderer may introduce helper blocks and an `i32` label local; a future Starshine representation difference needs source-backed semantic evidence and measured benefit, not a blanket "safe" label. Pair normalized comparison with the focused fixture matrix and the flatness/registry rules in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
