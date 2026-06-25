---
kind: concept
status: supported
last_reviewed: 2026-06-19
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
  - ../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md
  - ../../../raw/research/0444-2026-05-05-optimize-instructions-current-main-recheck.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `optimize-instructions` strategy

## Upstream source rule

This page's explanatory strategy prose was originally written against Binaryen `version_129` and remains useful for the pass model. For release-gating O4z implementation work, use the 2026-06-19 `version_130` matrix in [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md) as the current source/lit owner map.

A 2026-05-05 current-main spot check on `OptimizeInstructions.cpp`, `pass.cpp`, `opt-utils.h`, and representative default/sign-extension/bulk-memory/`call_ref`/GC/multivalue tests did not surface teaching-relevant drift on the reviewed surfaces. The later `version_130` O4z matrix preserves the same broad contract shape and routes remaining Starshine gaps to `[O4Z-AUDIT-OI-B]` through `[O4Z-AUDIT-OI-N]`.

Primary files:

- `src/passes/OptimizeInstructions.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/opt-utils.h`

Most important helper dependencies:

- `src/ir/bits.h`
- `src/ir/branch-hints.h`
- `src/ir/drop.h`
- `src/ir/effects.h`
- `src/ir/eh-utils.h`
- `src/ir/gc-type-utils.h`
- `src/ir/literal-utils.h`
- `src/ir/load-utils.h`
- `src/ir/localize.h`
- `src/ir/manipulation.h`
- `src/ir/properties.h`
- `src/ir/type-updating.h`
- `src/passes/call-utils.h`

The shipped lit tests are also part of the contract here, especially:

- arithmetic / default surface
- sign-extension and memory64
- bulk memory and ignore-implicit-traps
- branch-hint / no-fold-or-reorder
- multivalue / tuple
- call_ref
- GC, exact, descriptor, and TNH/IIT casts
- struct RMW / GC atomics

## High-level intent

Binaryen uses `optimize-instructions` to simplify instruction-shaped code *after* first forcing many expressions into more canonical forms.

That sounds small, but the real `version_129` pass is broad.

It combines:

- arithmetic and compare peepholes
- bit-width and sign-extension reasoning
- boolean-context normalization
- `if` / `select` / ternary shell rewrites
- memory and bulk-memory simplification
- `call_ref` target simplification
- GC cast / null-trap reasoning
- GC RMW / cmpxchg cleanup or lowering
- tuple extraction cleanup
- final type and EH repair

A good short description is:

- **canonicalize first, then exploit the canonical form everywhere it is safe**

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Local pre-scan | Infer `maxBits` and `signExtBits` for locals | Enable bit-width and sign-extension peepholes later |
| Main post-walk | Visit expressions bottom-up | See child shapes before parent rewrites |
| Per-node local fixpoint | `replaceCurrent()` re-runs local rewrites until stable | Let one rewrite unlock the next on the same node |
| Canonicalize binary spellings | Move consts right, normalize compares, order symmetric children | Keep later pattern matching manageable |
| Integer/float peepholes | Rewrites for shifts, masks, add/sub, compare, wrap/extend, rounding | Shrink or expose simpler forms |
| Boolean / ternary cleanup | Normalize boolean conditions and fold / hoist duplicated shells | Improve `if` / `select` shapes without full CFG work |
| Memory / bulk-memory cleanup | Fold offsets, simplify stores, lower tiny copy/fill cases | Turn generic memory ops into simpler instruction forms |
| Reference / GC cleanup | Skip redundant null checks, simplify casts/tests, rewrite `call_ref`, lower some unshared GC atomics | Exploit type and trap facts safely |
| Deferred repair | `ReFinalize`, `FinalOptimizer`, `handleBlockNestedPops` | Keep valid types and EH structure |

## Phase 1: the pass shell is more important than it looks

`OptimizeInstructions` is a `WalkerPass<PostWalker<OptimizeInstructions>>` and reports `isFunctionParallel() == true`.

That already tells us:

- it is per-function
- it works on AST shape, not CFG dataflow
- it expects local visitor logic plus helper analyses to do most of the work

The whole function flow in `doWalkFunction()` is:

1. read option flags (`fastMath`, `neverFold`, `neverReorder`)
2. run `LocalScanner`
3. do the main post-order walk
4. if any rewrite changed types, run `ReFinalize`
5. run `FinalOptimizer`
6. run `EHUtils::handleBlockNestedPops`

That means type repair and EH cleanup are not afterthoughts.

They are part of the pass contract.

## Phase 2: `LocalScanner` feeds a lot of the later “small” rules

Before the main walk, Binaryen scans all locals and records two facts per local:

- `maxBits`
- `signExtBits`

For params, Binaryen starts pessimistically:

- `maxBits` = full type width
- `signExtBits` = unknown

For non-params, Binaryen starts optimistically:

- `maxBits = 0`
- `signExtBits = 0`

Then each integer `local.set` updates those facts using:

- `Properties::getFallthrough(...)`
- `Bits::getMaxBits(...)`
- sign-extend recognition via `Properties::getSignExtValue(...)`
- sign-relevant signed loads

This is a very important beginner point.

Many later rules are not just syntax matches.

They depend on a lightweight whole-function summary about what locals can actually contain.

## Phase 3: `replaceCurrent()` is a local fixpoint loop

`replaceCurrent()` is deliberately more than a raw AST replacement helper.

When a visitor replaces the current node, Binaryen then re-visits that same node repeatedly until no more local rewrite fires.

That has two big consequences:

- the pass can canonicalize a shape and then immediately use the new shape
- many rules are written assuming another rule may have run one moment earlier on the same node

This is why the implementation feels dense but still converges.

The per-node work is intentionally designed as a tiny local rewrite chain.

## Phase 4: canonicalization is a strategy layer, not a style preference

Before most binary peepholes, `visitBinary()` checks `shouldCanonicalize()` and then calls `canonicalize()`.

Key canonicalization decisions include:

- prefer a constant on the right
- prefer `add` with a negative constant over `sub` with a positive constant in many integer cases
- prefer comparisons against `0`
  - `x > -1 -> x >= 0`
  - `x < 1 -> x <= 0`
  - unsigned `x < 1 -> x == 0`
- prefer comparisons against signed min/max and unsigned max in edge cases
- prefer `LocalGet` on the right in certain symmetric patterns
- sort otherwise-equal symmetric children by node kind / opcode / local index
- when relational operands swap, reverse the relational opcode as needed

This is one of the deepest durable lessons from the file.

The pass is not trying to match every possible spelling of a pattern.

It first tries to make many spellings converge.

## Phase 5: integer and float peepholes are huge, but they are not the whole story

The central `visitBinary()` visitor is enormous.

The most important rewrite clusters are:

### Arithmetic normalization

Examples from the source:

- `(0 - x) + y -> y - x` when reordering is safe (this leading form reorders the two value computations, so it is gated on a sound operand-reorder proof, not on purity — see `optimize_instructions_subtrees_can_swap`)
- `y + (0 - x) -> y - x` (trailing form; operands stay in order, no reorder needed)
- `-x * -y -> x * y` (both `(0 - x)` wrappers stripped in place, so no reorder and applies even for effectful factors like `(0 - call) * (0 - y)`)
- `x + (-C) -> x - C`
- `-x + y -> y - x` for floats when safe
- `x + (-y) -> x - y` and `x - (-y) -> x + y`
- `-x * y -> -(x * y)` for some integer cases

### Shift / rotate / mask cleanup

Examples:

- fold the effective shift amount to `31` or `63`
- remove shifts by zero
- simplify `x <<>> (y & 31|63)` into `x <<>> y`
- if the masked shift amount is provably always zero and the mask side has no side effects, return `x`
- combine nested constant shifts / rotates
- use rotate forms for some bit tricks unless `targetJS` makes that undesirable

### Power-of-two lowering

The pass rewrites some constant-right operations into simpler bitwise forms:

- multiply by power-of-two -> `shl`
- unsigned remainder by power-of-two -> `and` with `C-1`
- unsigned divide by power-of-two -> `shr_u`
- power-of-two float divide -> multiply by the inverse power-of-two

### Sign-extension synthesis and elimination

This is one of the file's recurring themes.

The pass can:

- recognize shift-pair sign-extension idioms and replace them with explicit `extend8_s`, `extend16_s`, `extend32_s`
- delete redundant sign-extension work when the child is already sufficiently sign-extended
- convert some sign-extended comparisons to cheaper zero-extended forms
- use local pre-scan knowledge when a `LocalGet`'s sign-extended nature is not visible syntactically at the read site

### Compare and relational cleanup

Examples:

- `(x - y) == 0 -> x == y`
- `(x - y) != 0 -> x != y`
- unsigned `(x - y) > 0 -> x != y`
- some `x + C1 > C2` style shapes move constants across the comparison when that math stays linear and does not overflow in the relevant signed/unsigned sense
- bit-knowledge can prove comparisons always true or always false

### Bit-knowledge simplification

`Bits::getMaxBits(...)` and friends drive many rules.

The pass can sometimes prove:

- a mask is redundant
- a comparison is impossible
- an expression can only be zero
- a value already fits in fewer bits so a signed op can be lowered to an unsigned one

This is a major reason the local pre-scan exists.

### Float and conversion cleanup

The pass also handles:

- redundant integer->float->integer roundtrips
- redundant rounding after integer-to-float conversion
- `x * -1.0` canonicalization, with `fastMath`-dependent signed-zero behavior
- duplicate unary float ops like `abs(abs(x))`
- NaN-specific comparison simplifications in some constant-right cases

## Phase 6: boolean-context reasoning is a separate sub-algorithm

Binaryen does not treat boolean producers as just more arithmetic.

`optimizeBoolean(...)` is a dedicated helper for values flowing into boolean contexts.

Important families there include:

- `eqz(eqz(x)) -> x`
- invert relational operators under `eqz`
- `x != 0 -> x` in boolean context
- `% power-of-two` boolean tests become masked tests
- sign-extended boolean values can use cheaper zero-extends
- the helper recurses into boolean-result `block`, `if`, `select`, and `try` shapes

This matters because later `if` and `select` optimizations often begin by normalizing their conditions through this helper first.

## Phase 7: `if` optimization here is narrower than it sounds

A very important fact for this repo:

- upstream `OptimizeInstructions.cpp` does **not** implement generic constant-if folding in `visitIf()`

`visitIf()` mainly does three things:

1. optimize the condition in boolean context
2. if there is an `else` and the condition is `eqz`, flip the arms and call `BranchHints::flip(...)`
3. if the arms are identical and folding is allowed, fold them carefully
4. then call `optimizeTernary(...)`

So the upstream pass's control-flow role is:

- boolean normalization and duplicated-shell cleanup

not:

- “evaluate any condition if possible and choose a branch.”

That distinction matters because current Starshine *does* perform explicit constant-if picking in its HOT pass.

## Phase 8: `select` and ternary shell optimization are bigger than the `if` story

`optimizeSelect(...)` and `optimizeTernary(...)` together form a major sub-story.

Key select families:

- constant-condition cleanup when effect order allows it
- `x ? x : 0`-style and `x ? 0 : x`-style simplifications
- boolean `select` between `0` / `1` lowering to booleanized conditions or `and` / `or`
- flipping arms to remove `eqz`
- folding identical arms when side effects allow it

Key ternary-shell families in `optimizeTernary(...)`:

- if one arm is `eqz(inner)` and the other is `0` or `1`, move the unary shell outside the ternary
- if both arms are shallow-equal one-child wrappers, hoist the wrapper outside the ternary and keep simplifying

But there are strong limits.

The pass refuses to hoist blindly when:

- the arm shell is a control-flow structure
- the inner child types are incompatible
- a `select` arm has side effects that would change execution semantics
- `Properties::canEmitSelectWithArms(...)` says the new select would not be valid or desirable

So this is a careful local shape optimizer, not a general control simplifier.

## Phase 9: memory and bulk-memory are real pass responsibilities

This pass directly owns several memory-shape simplifications.

### Address / offset cleanup

`optimizeMemoryAccess(...)` can fold constants from the pointer into the offset when doing so is safe, and it distinguishes memory32 vs memory64 overflow boundaries.

### Store-value and load-result cleanup

`optimizeStoredValue(...)` and adjacent load-result rewrites can:

- truncate stored integer constants to the actual stored byte width
- remove redundant `and` masks on narrower stores
- widen direct `i32.wrap_i64` values under i32 stores to matching i64 stores, preserving the original store memarg offset and alignment
- classify sign-extension-before-store spellings with current oracle evidence; Binaryen `version_130` keeps the probed explicit sign-extension opcodes before narrow stores, so Starshine treats those exact spellings as parity boundaries today
- replace some reinterpret-store combinations with a store of the original representation type, preserving the original store memarg offset and alignment
- keep probed local-carried/shared reinterpret-store forms such as `local.tee(f32.reinterpret_i32(...))` or `local.set`/`local.get` before `f32.store`; the 2026-06-25 `version_130` oracle does not rewrite those into representation stores
- replace full-width load plus reinterpret-result combinations with a load of the final representation type
- replace some i32-load plus `i64.extend_i32_*` combinations with matching i64 loads such as `i64.load32_u`, `i64.load32_s`, or narrow `i64.load8/16_*` when the intermediate value semantics match, preserving the original load memarg offset and alignment
- keep probed local-carried/shared load-result forms such as `local.tee(i32.load)` feeding reinterpret or `i64.extend_i32_*`; the 2026-06-25 `version_130` oracle does not rewrite those into representation loads

### Bulk memory

`optimizeMemoryCopy(...)` and `optimizeMemoryFill(...)` handle small fixed-size shapes.

Examples:

- under IIT/TNH, `memory.copy(x, x, size)` can collapse to dropped operands
- `memory.copy(..., const-size)` may lower to one load plus one store for small sizes
- `memory.fill(..., const-value, const-size)` may lower to one or two stores or one SIMD store; current `version_130` probes also lower size-1 local or no-param-call values directly to `i32.store8`, while keeping probed non-local wider fill values as `memory.fill`
- size `0` cases are only dropped under trap-relaxing modes

This is one of the strongest signs that the pass is broader than its name implies.

## Phase 10: reference / GC logic is a huge part of the pass

A large fraction of the file is about reference-typed and GC-specific shapes.

The focused page in this folder covers them in more detail, but the main implementation facts are:

- null-trap reasoning via `skipNonNullCast(...)` and `trapOnNull(...)`
- optional cast removal via `skipCast(...)` in TNH mode
- static cast-result evaluation via `GCTypeUtils::evaluateCastCheck(...)`
- careful preservation of useful exactness / descriptor information
- `call_ref` direct-call, call_indirect, and select-of-direct-target rewrites
- default-value constructor cleanup for `struct.new` / `array.new` / `array.new_fixed`
- relaxation of acquire-release ops on unshared GC heaps
- lowering of some unshared GC RMW / cmpxchg forms to simpler get/set code
- tuple extraction cleanup via `tuple.extract(tuple.make(...))`

This part of the pass is where a future honest Starshine port would need the most new helper infrastructure.

## Phase 11: `FinalOptimizer` and EH repair are part of the postcondition

After the main walk:

- `FinalOptimizer` does some last algebraic spelling cleanup, especially around constant adds/subs and signed-LEB-friendly forms
- `EHUtils::handleBlockNestedPops(...)` repairs exception-pop nesting that some rewrites can temporarily invalidate

So the pass does not promise:

- “every rewrite is perfectly final and structurally safe the moment it happens”

Instead, it promises:

- “the whole function is valid and cleaned up after the pass shell finishes its repair steps”

## Scheduler placement is part of the meaning of the pass

In the canonical no-DWARF default function pipeline, `optimize-instructions` runs twice:

1. early, after `remove-unused-brs`
2. late, after the second `precompute` slot and just before late `heap-store-optimization`, `rse`, and final `vacuum`

Those placements make sense once the real behavior is understood.

### Early slot meaning

Early `optimize-instructions` helps:

- normalize compares and boolean conditions before other local / branch cleanups
- remove some tuple-related shapes before tuple optimization
- canonicalize small arithmetic and bit patterns before `precompute` and code-pushing / local passes interact with them

### Late slot meaning

Late `optimize-instructions` helps:

- exploit shapes exposed by structural cleanup (`merge-blocks`, `remove-unused-brs`, late propagation)
- clean up final instruction spellings before `rse` and `vacuum`

So the pass is both:

- an early enabler
- and a late cleanup amplifier

## What the pass sounds like versus what it actually is

What it sounds like:

- a small instruction peephole pass

What it actually is:

- a large instruction-shape canonicalization pass with real effect, type, trap, memory, call, and GC semantics

That is why the file is so big.

The size is not accidental drift.

The pass genuinely owns a broad slice of Binaryen's mid- to late-function simplification surface.

## Bottom line

Binaryen `optimize-instructions` in `version_129` is a layered pass:

- pre-scan locals
- canonicalize shapes
- simplify many instruction families under effect and type constraints
- exploit trap / cast / call_ref facts where legal
- repair types and EH shape at the end

The name makes it sound tiny.

The implementation says otherwise.
