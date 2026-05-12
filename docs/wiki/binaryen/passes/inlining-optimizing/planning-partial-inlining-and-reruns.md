---
kind: concept
status: supported
last_reviewed: 2026-05-12
sources:
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining/heuristics-splitting-and-plain-vs-optimizing.md
---

# `inlining-optimizing`: planning, partial inlining, and reruns

## Big warning

`inlining-optimizing` is not “inline more.” It is:

- the whole shared inliner;
- plus changed-function cleanup immediately afterward.

Both halves matter.

## 1. Whole-module planning decides both rewrite and deletion

The planner needs to know:

- which functions are defined versus imported;
- which functions are exported or start roots;
- which functions have `ref.func` / element/table-like uses;
- direct call counts;
- callee size and shape;
- loops, calls, tail-call forms, and `try_delegate`;
- explicit no-inline policy;
- recursive growth hazards.

That is why this pass belongs in module-pass scheduling, not a local HOT peephole.

## 2. Root survival is orthogonal to callsite rewrite

A direct call can disappear while the callee survives. Survival reasons include:

- export;
- start function;
- `ref.func` or element/table use;
- other remaining calls;
- explicit no-inline or structural non-inlineability;
- Binaryen helper/representative retention behavior.

Current Starshine covers exported tiny-helper survival and has active exact-`unreachable` representative work, but not the full root/use matrix.

## 3. Direct-call action surface stays the current baseline

The reviewed `version_129` and 2026-04-25 current-main bridge support this wording:

- chosen actions are direct `call` / `return_call` based;
- `ref.func` counts keep boundaries alive;
- `call_ref` / `return_call_ref` matter for copied-body repair and surrounding reasoning;
- broad generic `call_ref` inlining is not the source-backed first-slice contract.

## 4. Partial inlining is a separate transformation

Partial inlining is not “copy half a function.” It is:

1. split a narrow source shape into an inlineable helper plus outlined remainder;
2. run ordinary inlining on the new helper.

Binaryen supports two narrow top-of-function families:

- Pattern A: simple early guard/return then heavier work;
- Pattern B: short simple top-level `if` ladder with no else arms and final-item local-dependency checks.

Current Starshine does not implement either.

## 5. Touched functions are the bridge to the optimizing suffix

After core inlining, Binaryen knows which functions changed. The optimizing variant uses a filtered runner so cleanup runs only where it can matter.

Touched-function fidelity matters because an unfiltered cleanup lane can:

- rewrite untouched functions too early;
- hide mismatches that belong to another pass;
- create order drift in the late tail;
- make direct-pass attribution harder.

Current Starshine approximates this by running a broad cleanup lane, then restoring untouched function bodies and compacting touched locals. This is useful but not exact Binaryen behavior.

## 6. `precompute-propagate` is not optional

Binaryen prepends `precompute-propagate` before the default function pipeline. This is the concrete reason the optimizing suffix is powerful: inlined constants and copied expressions often become foldable before later cleanup passes see them.

The local equivalent is still missing. `[INL]002` remains active until the real touched-function scheduler lands.

## 7. The late-tail neighborhood consumes the result

`inlining-optimizing` feeds:

- `duplicate-function-elimination`;
- `duplicate-import-elimination`;
- `simplify-globals-optimizing`;
- `remove-unused-module-elements`.

So direct `--pass inlining-optimizing` parity should come before preset scheduling, but final v0.1.0 confidence also needs ordered-neighborhood replay once direct mismatches are gone.

## 8. Current mismatch frontier

The latest artifact is validation-clean and command-failure-classified, but not parity-green. The remaining 15 normalized mismatches are exact-`unreachable` private-helper retention/representative cases.

That means the immediate next useful questions are not “does the pass validate?” but:

- which private exact-unreachable helpers does Binaryen retain as representatives?
- which signatures does Binaryen preserve for uncalled or duplicate unreachable helpers?
- does Starshine over-remove or over-retain after helper compaction?
- does nested cleanup approximation hide or introduce representative differences?

## Good future-agent checklist

When investigating an `inlining-optimizing` diff, classify it as one of:

1. core eligibility mismatch;
2. core rewrite/repair mismatch;
3. helper deletion/retention mismatch;
4. touched-function set mismatch;
5. nested cleanup scheduler mismatch;
6. downstream late-tail mismatch;
7. Binaryen/tool parse/canonicalization failure.

Only categories 1-5 belong to direct `INL` work. Category 7 is ignored oracle/tool failure per user preference.
