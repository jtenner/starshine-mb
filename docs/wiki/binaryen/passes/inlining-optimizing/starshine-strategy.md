---
kind: concept
status: working
last_reviewed: 2026-05-12
sources:
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining/starshine-strategy.md
  - ../dae-optimizing/index.md
  - ../precompute-propagate/index.md
  - ../duplicate-function-elimination/index.md
---

# Starshine Strategy For `inlining-optimizing`

## Current status

`inlining-optimizing` is a **partial active module pass** in Starshine. It is owned by [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt), shares its core with plain `inlining`, and adds the local optimizing-mode cleanup approximation.

Do not claim parity or signoff. Latest evidence remains red:

```text
.tmp/pass-fuzz-inlining-unique-selfloop-drop-jobs-auto
9975 compared
9968 normalized matches
7 mismatches
0 validation failures
25 ignored Binaryen/tool command failures
```

The latest lane used `--jobs auto` with a prebuilt native `--starshine-bin _build/native/release/build/cmd/cmd.exe`; the 25 command failures remain Binaryen/tool parse or canonicalization failures and do not count as Starshine semantic parity failures. `[INL]001` and `[INL]002` remain active.

## Exact local code map

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - registers `inlining-optimizing` as a module pass;
  - direct pass selection accepts it;
  - public `optimize` / `shrink` presets still omit the late Binaryen `INL` slot.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - dispatches `inlining-optimizing` to `inlining_run_module_pass(... optimize=true, trace=Some(options.trace), pass_name="inlining-optimizing")`.
- [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt)
  - shared core and optimizing approximation.
- [`src/passes/inlining_test.mbt`](../../../../../src/passes/inlining_test.mbt)
  - focused public-pipeline tests and current mismatch-frontier regressions.
- [`agent-todo.md`](../../../../../agent-todo.md)
  - active `[INL]001` and `[INL]002` deliverables and current artifact counts.
- [`CHANGELOG.md`](../../../../../CHANGELOG.md)
  - 2026-05-11 and 2026-05-12 implementation checkpoints.

## Current implemented behavior

- Active `inlining` and `inlining-optimizing` module-pass names.
- Iterative direct `call` and narrow direct `return_call` rewrite waves.
- Tiny and one-use private defined callee eligibility.
- Callee parameter/body-local appending and local-index remapping.
- Simple return-to-wrapper-block branch repair.
- Private helper removal after refs disappear.
- Function-index remapping across represented module surfaces.
- Nested-cleanup trace marker for optimizing mode.
- Broad cleanup approximation with untouched-body restoration and touched-local compaction.
- Exact-`unreachable` private-helper survivor prediction refinements, including shadowed void-cycle result-helper retention, duplicate trimming against non-exact same-signature survivors only when no used self-loop root is present, and unique private self-loop representative drops inside root SCCs.

## Current gaps

### `[INL]001`: core inliner parity

- exact Binaryen heuristic classes and options;
- no-inline policy flags;
- partial inlining splitter;
- nested `return_call*` repair;
- multi-result typing;
- label/name/annotation repair;
- exact action filtering, iteration caps, and size guard;
- remaining exact-`unreachable` helper retention mismatches; current saved `gen-valid` frontier is 7 cases (`001716`, `001838`, `003188`, `005502`, `005754`, `007720`, `008230`).

### `[INL]002`: optimizing suffix parity

- exact touched-function set;
- real `precompute-propagate` equivalent first;
- Binaryen default function pipeline on only touched functions;
- scheduler tests distinguishing touched callers/callees/removed helpers/untouched functions;
- late-tail artifact replay after direct parity.

## Dependency map

- [`../inlining/index.md`](../inlining/index.md) - shared core and plain stop-point contract.
- [`../precompute-propagate/index.md`](../precompute-propagate/index.md) - required first nested cleanup pass.
- [`../dae-optimizing/index.md`](../dae-optimizing/index.md) - adjacent boundary optimizer with similar touched-function nested-scheduler need.
- [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md) - immediate downstream function-graph cleanup.

## Classification policy

When comparing outputs, separate:

- Starshine semantic/normalized mismatches;
- Starshine validation failures;
- generator failures;
- Binaryen parser/canonicalization/tool command failures.

The user explicitly prefers Binaryen parse/canonicalization failures to be classified as ignored oracle/tool failures, not Starshine semantic failures.

## Bottom line

The correct local mental model is:

- **active but partial**;
- **validation-clean in latest 10k artifact range**;
- **not parity-green**;
- **core direct-call subset plus cleanup approximation**;
- **INL backlog still open**.
