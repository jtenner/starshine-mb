---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-26-asyncify-port-readiness-primary-sources.md
  - ../../../raw/research/0401-2026-04-26-asyncify-port-readiness.md
  - ../../../raw/binaryen/2026-05-05-asyncify-current-main-recheck.md
  - ../../../raw/research/0445-2026-05-05-asyncify-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md
  - ../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/wast/keywords.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./state-machine-memory-and-eh-boundaries.md
  - ../memory64-lowering/index.md
  - ../legalize-js-interface/index.md
---

# Starshine `asyncify` port readiness and validation ladder

## Why this page exists

The rest of the `asyncify` dossier explains the pass contract.
This page answers the implementation-planning question: **what should Starshine prove first if someone decides to port it?**

The short answer is: do not start with the full `asyncify.wast` output.
Start by preserving registry honesty, then build a tiny module-pass slice that either rewrites one direct async import path correctly or rejects unsupported families explicitly.

## Current local status to preserve

Starshine currently has no `asyncify` pass.
That is not merely a missing owner file:

- `src/passes/optimize.mbt:128-154` lists boundary-only and removed pass names, and `asyncify` is absent.
- `src/passes/optimize.mbt:158-252` lists active hot/module/preset registry entries, and `asyncify` is absent.
- `src/passes/optimize.mbt:455-459` is therefore the generic unknown-pass request path for `--pass asyncify` today.
- No `src/passes/asyncify.mbt`, dispatcher case, preset slot, option model, parity page, or active backlog slice was found in this run.

A first Starshine change should decide that status deliberately.
It can keep `asyncify` unknown, add it as boundary-only, or begin an active module pass, but it should not accidentally imply partial support.

## Reusable local surfaces

A future implementation would be a module pass.
The useful existing surfaces are prerequisites, not Asyncify support:

| Need | Current Starshine surface | Port implication |
| --- | --- | --- |
| Add or rewrite globals | `src/lib/types.mbt:224`, `442` | Asyncify state/data globals need declaration and validation. |
| Add helper exports | `src/lib/types.mbt:227`, `460` | Runtime API exports must be created with duplicate-name checks. |
| Add helper functions and bodies | `src/lib/types.mbt:433`, `493`, `515-585` | The pass must extend function and code sections coherently. |
| Instrument direct / indirect calls | `src/lib/types.mbt:527-528`; `src/binary/encode.mbt:2002-2015` | Direct and indirect calls are representable, but no callgraph rewrite exists for Asyncify. |
| Reject or handle tail calls | `src/lib/types.mbt:529-530`; `src/validate/typecheck.mbt:3219-3223` | Binaryen's reviewed path rejects tail calls; a local port needs an explicit rule. |
| Emit memory/global traffic | `src/lib/types.mbt:540`, `567`; `src/binary/encode.mbt:2088`, `2250` | Save/restore code must validate and encode for the selected memory width. |
| Build WAT fixtures | `src/wast/keywords.mbt:87-90`, `137`, `174` | Text tests can cover indirect/tail calls, `global.set`, and `memory.grow`. |

## First-slice order

### 1. Registry honesty

Add tests for the chosen public behavior before any rewrite:

- unknown pass stays unknown, if the project wants no local contract yet;
- boundary-only pass rejects active execution clearly, if the project wants discoverability;
- active pass accepts `--pass asyncify`, if implementation begins.

This prevents wiki drift where documentation says “future port” but the CLI appears to promise more.

### 2. Rejecting analyzer

Build a no-rewrite analyzer over a tiny module:

- identify imported async roots;
- walk direct calls enough to report candidate functions;
- reject `return_call`, `return_call_indirect`, and `return_call_ref` under `asyncify`;
- reject EH/catch and unsupported option families deliberately for the first slice.

This slice is valuable even before instrumentation because Asyncify correctness depends on the set of frames that may unwind.

### 3. Direct imported-root instrumentation

Start with one imported async root and one caller, no live locals, memory32 only.
The expected output should prove:

- Asyncify state/data globals exist;
- runtime helper exports exist;
- the relevant call site is state-machine-aware;
- unrelated functions remain unchanged;
- the module validates after section updates.

### 4. Scalar live-local save/restore

Add exactly one `i32` local live across the call.
Do not jump immediately to reference locals, multi-value blocks, or nested EH.
The proof obligation is that normal execution sees the same value, the unwind path stores it, and the rewind path reloads it.

### 5. Direct callgraph fanout

Instrument transitive direct callers and preserve functions outside the async closure.
This is where the pass becomes recognizably whole-module rather than call-site-only.

### 6. Indirect call policy

Binaryen is conservative around indirect calls unless the user config proves they can be ignored.
A Starshine port needs both:

- one conservative positive that instruments a possible indirect async edge;
- one deliberate ignored-indirect negative if local options expose that policy.

### 7. Memory64 pointer traffic

The official source comments still distinguish wasm32 from wasm64 Asyncify stack layout.
After memory32 is green, add memory64 input and require `i64` pointer traffic.
Hard-coding `i32` would pass many simple fixtures and still be wrong.

### 8. EH/catch behavior

EH/catch should not be hidden under generic validation.
Either:

- implement the source-backed catch-unwind option behavior; or
- keep rejecting EH/catch input with a stable diagnostic until a dedicated slice ports it.

### 9. Dynamic host harness

Static WAT comparison is not enough for Asyncify.
The last readiness gate is an execution test that drives one unwind/rewind round trip through the exported runtime API.
Until then, a port can be shape-correct and still semantically wrong.

## Validation checklist

For every active slice, require:

- module validation after section synthesis and body rewrites;
- duplicate export-name checks for the Asyncify runtime API;
- call-index and function-index consistency after adding helper functions;
- memory index and pointer-width consistency;
- Binaryen oracle comparison for the supported subset;
- no accidental instrumentation of functions outside the async closure;
- clear diagnostics for unsupported tail calls, EH/catch, and option families.

## Main non-goals for the first local port

- Do not implement `mod-asyncify-*` helper passes first; they are siblings/follow-up simplifiers, not the main transformation.
- Do not treat Asyncify as a HOT peephole pass.
- Do not match the entire official `asyncify.wast` output before the direct-call scalar subset is stable.
- Do not rely on normalized text output alone for final correctness.

## Sources

- [`../../../raw/binaryen/2026-04-26-asyncify-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-asyncify-port-readiness-primary-sources.md)
- [`../../../raw/research/0401-2026-04-26-asyncify-port-readiness.md`](../../../raw/research/0401-2026-04-26-asyncify-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md`](../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md)
- [`../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md`](../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/wast/keywords.mbt`](../../../../../src/wast/keywords.mbt)
