---
kind: entity
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - ../../../raw/research/0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md
  - ../../../raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md
  - ../../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md
  - ../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md
  - ../../../raw/research/0109-2026-04-18-generated-o4z-optimize-instructions-slot44-retired-by-replay-verification.md
related:
  - ./binaryen-strategy.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../precompute/index.md
  - ../heap-store-optimization/index.md
  - ../vacuum/index.md
---

# `optimize-instructions`

## Role

- `optimize-instructions` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, `optimize-instructions` is a function-parallel post-walk peephole and canonicalization pass.
- The public summary in `pass.cpp` is only `optimizes instruction combinations`.

That summary is true, but much too small.

A better beginner summary is:

- Binaryen tries to rewrite instructions into cheaper or easier-to-optimize shapes,
- but it does so using real knowledge about bit-widths, effect ordering, fallthrough values, null traps, GC casts, and feature gates,
- so the pass reaches far beyond plain arithmetic simplification.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` explicitly named `optimize-instructions` as the strongest remaining implemented-landing target after the `vacuum` dossier landed.
- The canonical no-DWARF `-O` / `-Os` scheduler uses it **twice** in the default function pipeline:
  - once early
  - once late
- The saved generated-artifact `-O4z` audit also saw it at two real top-level Binaryen slots:
  - slot `16`
  - slot `44`
- The saved Binaryen debug log contains `36` `running pass: optimize-instructions` lines in total, so nested optimizing reruns make it much more common than the two visible top-level slots suggest.
- The local backlog does not yet have a dedicated `OI` slice, so richer docs here help future planning as much as future implementation work.
- This pass sits directly beside other cleanup / simplification neighbors already tracked in the wiki:
  - `heap-store-optimization`
  - `precompute`
  - `rse`
  - `vacuum`

## Most important durable takeaways

- Binaryen `optimize-instructions` is **not** just constant folding.
- Binaryen `optimize-instructions` is **not** just integer arithmetic peepholes.
- The pass is built around five linked ideas:
  1. canonicalize instruction spellings first
  2. use bit-width and sign-extension facts from a pre-scan of locals
  3. apply many local expression rewrites under effect-ordering constraints
  4. exploit trap / null / cast facts for reference and GC operations
  5. repair changed types and EH pop nesting after the main walk
- The pass depends heavily on helper utilities such as:
  - `Bits`
  - `Properties`
  - `EffectAnalyzer`
  - `ShallowEffectAnalyzer`
  - `GCTypeUtils`
  - `ChildLocalizer`
  - `BranchHints::flip`
  - `ReFinalize`
  - `EHUtils::handleBlockNestedPops`
  - `CallUtils::convertToDirectCalls`
- The canonical no-DWARF scheduler uses it in both an **early canonicalization** role and a **late cleanup-canonicalization** role.
- Current Starshine only models a narrow, mostly integer / boolean / control-flow slice of the upstream behavior.
- The earlier generated-artifact hard failures in slots `16` and `44` are now fully retired.
  - The durable explanation is that the saved failures were fixed by HOT-lowering / writeback guards, not by discovering a new still-open Binaryen peephole mismatch in the pass itself.

## Beginner warning: what the name hides

The easy wrong mental model is:

- `optimize-instructions` is just “replace `x == 0` with `eqz` and a few similar identities”

The safer mental model is:

- Binaryen uses `optimize-instructions` as a broad instruction-shape canonicalizer,
- then uses that canonical form to simplify arithmetic, boolean, memory, `if` / `select`, `call_ref`, GC casts, GC RMWs, tuple extraction, and several trap-sensitive shapes,
- while preserving effect order and type validity.

That difference matters a lot for future parity work.

## What the pass sounds like versus what it actually does

What it sounds like:

- a small math peephole pass

What it actually is in `version_129`:

- a large function-parallel AST post-walk with:
  - local bit / sign-extension scanning
  - iterative per-node re-optimization
  - canonicalized compare / commutative operand ordering
  - integer and float peepholes
  - boolean-context and ternary rewrites
  - memory and bulk-memory lowering
  - `call_ref` directization opportunities
  - descriptor- and exactness-aware GC cast simplification
  - unshared GC RMW / cmpxchg lowering
  - tuple extraction cleanup
  - deferred `ReFinalize`
  - final EH pop repair

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, main phases, and the difference between the pass's public name and its real scope.
- [`./gc-casts-call_ref-and-trap-sensitive-rewrites.md`](./gc-casts-call_ref-and-trap-sensitive-rewrites.md)
  - Focused guide to the easiest part of the pass to underestimate: null-trap reasoning, cast removal limits, descriptor / exactness handling, `call_ref` lowering, and unshared GC atomic rewrites.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering positive, negative, bailout, control, memory, GC, `call_ref`, tuple, and metadata-sensitive rewrite families.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine strategy and the major Binaryen behaviors the repo still does not model.

## Current maintenance rule

- Treat this folder as the canonical home for future `optimize-instructions` parity and scheduler research.
- Use Binaryen `version_129` as the current source oracle for new conclusions.
- Keep the Binaryen strategy page and the Starshine strategy page in sync whenever the in-tree implementation grows beyond the current integer / boolean / control-focused HOT subset.
- Keep the landing page honest about the ordered-artifact story:
  - slot `16` is retired
  - slot `44` is retired
  - the remaining work is documentation depth, parity breadth, and runtime honesty, not an open hard-corruption witness.

## Sources

- [`../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md`](../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md)
- [`../../../../../src/passes/optimize_instructions.mbt`](../../../../../src/passes/optimize_instructions.mbt)
- [`../../../../../src/passes/optimize_instructions_test.mbt`](../../../../../src/passes/optimize_instructions_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
- Representative Binaryen `version_129` tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-default.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-call_ref.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-gc-tnh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-bulk-memory.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-multivalue.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions_branch-hints-fold.wast>
