# 0140 - Binaryen `global-struct-inference` research

Supersession note, 2026-04-25: [`0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md`](0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md) and [`../binaryen/2026-04-25-global-struct-inference-primary-sources.md`](../binaryen/2026-04-25-global-struct-inference-primary-sources.md) supersede this note for raw-source provenance, current-main spot-check framing, and Starshine code-map completeness. Keep this note as the original Binaryen contract audit.

## Scope

- Continue the Binaryen pass wiki-ing campaign after the `global-refining` dossier.
- Follow the repo wiki process in `docs/README.md`.
- Consult the updated tracker and choose one still-eligible pass.
- Deepen the early module-pass documentation around Binaryen's GC-aware global-instance and struct-field reasoning.
- Produce durable notes that help a future Starshine maintainer preserve the real Binaryen contract instead of implementing either a much smaller closed-world-only constant folder or a much broader but incorrect whole-program struct analysis.

## Candidate selection

- `docs/wiki/binaryen/passes/tracker.md` now lists `global-struct-inference` as the strongest remaining implemented landing-page target after `global-refining`.
- `global-struct-inference` is still only `landing`, not `deep`, in the tracker.
- It is eligible under the campaign rules.
- `agent-todo.md` still has **no dedicated `GSI` slice** today; the only live references are:
  - the canonical ordered-path note `... -> global-refining -> remove-unused-module-elements -> gsi`
  - the shared post-`SSA` replay context that mentions the `DFE -> RUME -> MP -> OR -> GR -> GSI` prefix

## Local repo context that matters

### Canonical no-DWARF scheduler placement

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` records the open-world no-DWARF pre-pass cluster for the MoonBit debug artifact as:

- `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> remove-unused-module-elements -> gsi`

So `global-struct-inference` matters here as the bridge between:

- early declaration tightening (`global-refining`)
- second early global cleanup (`remove-unused-module-elements`)
- the start of the function-pass cluster (`ssa-nomerge -> dce -> ...`)

A closed-world Binaryen run can do more work around this point (`gto`, `remove-unused-types`, `cfp`, `abstract-type-refining`, `unsubtyping`), but the repo's main no-DWARF orientation page is the open-world path above.

### Current in-tree Starshine implementation

The local implementation lives in:

- `src/passes/global_struct_inference.mbt`
- `src/passes/global_struct_inference_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`

The current MoonBit pass is a **much narrower subset** of official Binaryen:

- it returns immediately unless `closed_world` is enabled
- it scans only defined immutable globals with top-level `struct.new*` initializers
- it only rewrites direct instruction pairs that are literally
  - `global.get`
  - immediately followed by `struct.get` / `struct.get_s` / `struct.get_u`
- it only folds field values it can materialize from simple literal, `ref.null`, `ref.func`, `string.const`, `global.get`, or default-value forms in the boundary IR
- it does **not** perform Binaryen's closed-world type-to-global candidate analysis over arbitrary ref producers such as locals, params, blocks, or merged parent types
- it does **not** implement Binaryen's un-nesting of non-constant operands into fresh immutable globals
- it does **not** model `ref.get_desc`, atomic gets, or the sibling `gsi-desc-cast` rewrite family

That is important because the older local research note `0068` summarized the pass mainly as a closed-world rewrite. The official source is broader than that in one direction (open-world direct-global reads) and much deeper than that in another (closed-world type-based candidate reasoning plus un-nesting).

### Current local evidence

The saved generated-artifact `-O4z` audit shows slot `7` (`gsi` / `global-struct-inference`) as:

- exact wasm equal: `yes`
- normalized WAT equal: `yes`
- Starshine wall/runtime: `410.401 ms`
- Binaryen wall/runtime: `197.827 ms`
- Starshine in-pass time: `0.002 ms`
- Binaryen in-pass time: `2.008 ms`

Sources:

- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/o4z-wasm-opt-debug.log`

Important caution:

- exact equality on that slot does **not** prove full parity
- the artifact apparently does not exercise the important official surfaces the local pass still lacks
- especially missing from local coverage are Binaryen's open-world direct-global fast path, closed-world param/local-based select rewrites, subtype propagation, un-nesting, and descriptor-facing helpers

### Current local registry surface

The active registry includes:

- `global-struct-inference`

The removed-name registry still tracks upstream-adjacent names such as:

- `global-struct-inference-desc-cast`
- `global-type-optimization`

That is a useful orientation clue: the repo currently implements the main `gsi` name, but not the nearby optional GC-type helper variants that Binaryen can run around the same global-prepass cluster.

## Official Binaryen source inventory

Primary `version_129` sources:

- `src/passes/GlobalStructInference.cpp`
- `src/passes/pass.cpp`
- `src/ir/possible-constant.h`
- `src/ir/subtypes.h`
- `test/lit/passes/gsi.wast`

Important helper dependencies visible in `GlobalStructInference.cpp`:

- `ModuleUtils::ParallelFunctionAnalysis`
- `FindAll<StructNew>`
- `PossibleConstantValues`
- `SubTypes`
- `Bits::makePackedFieldGet`
- `ReFinalize`
- `Names::getValidGlobalName`
- nested `PassRunner` with `reorder-globals-always`

Freshness check done for this note:

- `version_129` `src/passes/GlobalStructInference.cpp` differs from current `main` only by comment typo fixes (`synchonize` -> `synchronize`, `opportunitites` -> `opportunities`)
- `version_129` `test/lit/passes/gsi.wast` == current `main` `test/lit/passes/gsi.wast`

So there is no visible semantic post-`version_129` drift in the owning pass file or dedicated lit file right now.

## What the pass sounds like versus what it actually is

### Easy wrong mental model

A beginner might hear `global-struct-inference` and imagine:

- a broad escape-style analysis over all struct values in the program
- whole-program field-value inference for any object of a given type
- aggressive devirtualization based on arbitrary dataflow through locals, calls, and memory
- a pass that only works in closed world and only folds obvious constants

That is **not** what Binaryen `version_129` implements.

### Better source-backed mental model

Binaryen's pass is more specific and more structured:

1. if GC is off, do nothing
2. in closed world, build a map from optimizable struct heap types to immutable globals whose top-level initializers are `struct.new`
3. rule out types that are also allocated in functions or nested inside other global initializers
4. while walking functions, optimize three kinds of reads:
   - direct immutable-global reads (even in open world)
   - closed-world reads where a type can only come from one candidate global
   - closed-world reads where there are exactly two unique candidate values and one of them can be selected by a single `ref.eq`
5. if a useful field value is non-constant, un-nest it into a new immutable global and then read that global instead
6. refinalize when the replacement changes a node type
7. optionally, in the sibling `gsi-desc-cast` mode, rewrite some `ref.cast` checks to descriptor-equality casts

So the real contract is:

- **open-world direct immutable-global read optimization**
- plus **closed-world type-to-global candidate reasoning**
- plus **at-most-two-unique-values select synthesis**
- plus **fresh-global un-nesting for non-constant nested operands**
- plus **type repair / refinalization**

It is **not** generic whole-program field dataflow and it is **not** just the repo's current direct `global.get -> struct.get` constant folder.

## Actual Binaryen implementation structure

## 1. Early gates and mode split

`GlobalStructInference::run(Module* module)` begins with:

- `if (!module->features.hasGC()) return;`

Then it optionally creates `SubTypes` only when the `optimizeToDescCasts` constructor flag is on.

Most importantly, the pass splits into two layers:

- `analyzeClosedWorld(module)` runs **only** when `getPassOptions().closedWorld`
- `optimize(module)` runs **always** after that

That means the pass is **not** closed-world-only.
Closed world adds the type-global map and subtype reasoning, but the normal optimizer still has open-world opportunities after skipping `analyzeClosedWorld`.

That is the biggest correction to the older local summary.

## 2. Closed-world analysis: find which struct types are safe to reason about

`analyzeClosedWorld(module)` does two major scans.

### Function scan: any function-local `struct.new` poisons that exact type

Binaryen runs:

- `ModuleUtils::ParallelFunctionAnalysis<HeapTypes>`
- `FindAll<StructNew>(func->body)`

for each defined function.

If a struct type appears in a function-local `struct.new`, it is inserted into the `unoptimizable` set.

Source-backed meaning:

- once a type is allocated inside a function body, Binaryen no longer tries to claim that values of that type must come only from immutable globals

### Global scan: only top-level immutable `struct.new` globals are candidate sources

For each defined global, Binaryen:

- rejects imported globals
- marks nested non-top-level `struct.new` occurrences as unoptimizable
- ignores non-ref global initializers
- rejects globals whose declared type is not equality-comparable enough for `ref.eq`
  - specifically, the declared type must be a subtype of `eqref`
- rejects mutable globals
- records globals whose top-level initializer is a `struct.new`

The equality-comparable check is subtle and important.
It is why the lit file has:

- positive `eqref`-declared globals
- negative `anyref`-declared globals

Even if the underlying init is a struct, Binaryen refuses the multi-candidate `ref.eq` path when the declared global type is too broad to compare that way.

## 3. Subtype propagation runs upward in two different ways

Binaryen uses `SubTypes` because a read of a parent type can observe instances of its subtypes.

That yields two propagation rules.

### Unoptimizable subtype => unoptimizable supertype

If a child type is allocated in a function or nested global init, the parent becomes unoptimizable too.

The source comment says this directly:

- a `struct.get` might also read from any of the subtypes
- therefore an unoptimizable type makes all of its supertypes unoptimizable as well

This is why the lit file includes:

- positive child-local optimization that does **not** poison a distinct supertype when the read is only of the child type
- negative parent read cases where a child allocation blocks parent optimization

### Candidate globals from a subtype are visible through the supertype

If one type has candidate globals, a `struct.get` on its supertype might read them too, so Binaryen propagates global names upward through declared supertypes.

That is what enables shapes like:

- one global on each child type
- parent read optimized with a two-way `ref.eq` select over the two child-origin values

Finally, Binaryen sorts each propagated global vector to keep the pass deterministic.

## 4. Function optimization is a postorder walker over specific read families

The main nested worker is `FunctionOptimizer : PostWalker<FunctionOptimizer>`.

It visits:

- `StructGet`
- `RefGetDesc`
- and optionally `RefCast` when `optimizeToDescCasts` is enabled

### Important immediate rule: the field must be immutable

For ordinary field reads, Binaryen bails out on mutable fields immediately.

That is why the lit file begins with:

- positive immutable-field examples
- negative mutable-field examples

### Open-world fast path: direct read from an immutable global

Before using `typeGlobals`, Binaryen checks whether the read operand itself is a direct `global.get` of a defined immutable global initialized by `struct.new`.

If so, it can optimize **even in open world** because the exact global is known locally at the read site.

This direct-global fast path is broader than the repo's older wiki summary in one way:

- it does not need closed-world type-global reasoning

But it is also richer than the current local MoonBit implementation in two ways:

- it applies to Binaryen's actual AST nodes, including atomic get forms represented through `StructGet`
- it can reuse the same helper machinery as the broader closed-world path, including packed-field handling and non-constant un-nesting

## 5. Closed-world type-global path: zero, one, or two unique candidate values

If the fast path does not fire, Binaryen looks in `typeGlobals` using the operand heap type.

Three broad cases matter.

### No candidate globals

- do nothing

### Exactly one candidate global

Binaryen does **not** directly replace the read with the field value.
Instead it rewrites the reference operand to a block like:

- `block (result (ref ...))`
  - `drop(ref.as_non_null(original-ref))`
  - `global.get $known_global`

Then later passes may constant-fold the actual read if the field value is constant.

That detail is easy to miss.
The one-global case is mainly a **reference-origin rewrite**, not always an immediate constant-field replacement.

### Two unique candidate values, with one singleton group

Binaryen groups candidate globals by the value observed at the requested field (or descriptor).

- if all candidates map to one unique value, it can just trap on null and return that value
- if there are exactly two unique values, and one of those value-groups is associated with exactly one global, it can emit a single `select(ref.eq(..., global.get $singleton))`
- if there are more than two unique values, or both groups would need multiple comparisons, it gives up

The lit file explicitly exercises all of these:

- 3 globals / 3 unique values => no optimization
- 3 globals / 2 unique values where one is unique => optimize
- 4 globals / 2 equal pairs => still no optimization because neither group is singleton
- many globals / all same value => constant/no-select positive

So the real profitability rule is not “at most two globals.”
It is closer to:

- **at most two unique values, and if there are two, one must be testable with one `ref.eq`**

## 6. `PossibleConstantValues` decides what counts as “constant enough”

When Binaryen reads a field from a `struct.new`, it calls `readFromStructNew(...)` and uses `PossibleConstantValues`.

`PossibleConstantValues` can treat as constant:

- literal constants
- immutable `global.get`s

and otherwise marks the value unknown.

That is why the lit file has a dedicated positive family for:

- field operands that are themselves immutable `global.get`s

This also explains a subtle limitation:

- two syntactically identical non-constant expressions are **not** grouped as one constant value
- if they are not recognized as constant, they stay expression pointers, not value-equality classes

So the pass can optimize:

- `global.get $one` vs `global.get $two`

but not:

- two separate non-constant `i32.add` trees that just happen to compute the same result

unless later un-nesting or other passes canonicalize those independently.

## 7. Non-constant values can still optimize through un-nesting

One of the most important parts of the pass is the un-nesting mechanism.

If the selected field value is not constant, Binaryen can still proceed by:

1. recording a `GlobalToUnnest` work item
2. creating a temporary `global.get` placeholder expression in the function body
3. after parallel function optimization, adding a fresh immutable global initialized to the nested operand
4. replacing the original operand in the owning `struct.new` with `global.get $new_global`
5. retargeting the placeholder get to the new name
6. running nested `reorder-globals-always` so the new globals appear before their uses

This is how Binaryen turns shapes like:

```wat
(global $g (ref $S)
  (struct.new $S
    (i32.add (i32.const 41) (i32.const 1))))
```

into a form where `gsi` can select on:

- `global.get $g.unnested.0`

instead of giving up.

That is a major difference from the local MoonBit pass, which currently does no un-nesting at all.

## 8. Packed fields are handled at the replacement site

If the field is packed, Binaryen uses `Bits::makePackedFieldGet(...)` when materializing the replacement expression.

That means the pass does not just reuse the raw stored value.
It reproduces the same signed/unsigned field-read behavior that the original `struct.get_s` / `struct.get_u` would have had.

The lit file has a direct packed-field example where stored `257` and `258` become:

- masked `255`
- masked `2`

for `struct.get_u` on an `i8` field.

## 9. Atomic gets are still optimized on immutable fields

This is one of the easiest points to misunderstand.

Binaryen explicitly says that it does not need a fence or other synchronization-preservation special case here, because:

- the field is immutable
- therefore there cannot be writes that the atomic read would synchronize with

So even `struct.atomic.get acqrel` and the default seqcst form can be optimized when the field is immutable and the read-origin proof succeeds.

The lit file covers:

- one-global atomic get rewrite
- two-global atomic get select rewrite
- all-same-value atomic get constant rewrite

That means a future parity port must not conservatively forbid atomic-get optimization just because the read opcode sounds special.
The immutability proof is what matters.

## 10. Refinalization is part of the contract

Binaryen sets `refinalize = true` when a replacement can change expression types.
Two common reasons are:

- the rewritten reference operand has a more refined type than the old operand
- the replacement value has a more refined type than the original `struct.get` / `ref.get_desc`

At `visitFunction(...)`, the optimizer runs:

- `ReFinalize().walkFunctionInModule(func, getModule())`

if needed.

The lit file ends with a direct null-refinement example where:

- a field declared as `(ref null $A)` is inferred to always be `null`
- the enclosing block and later `ref.as_non_null` shape refine accordingly

So the pass is not just local tree surgery.
It relies on type repair after the rewrite.

## 11. `RefGetDesc` and the sibling `gsi-desc-cast` surface

The public default scheduler uses `gsi`, not `gsi-desc-cast`, but the same source file implements both.

### `RefGetDesc`

`visitRefGetDesc(...)` simply routes descriptor reads through the same `optimize(...)` helper using a sentinel `DescriptorIndex = -1`.

That means the pass is not limited to ordinary struct fields.
It also knows how to reason about descriptor reads using the same global-origin and un-nesting machinery.

### `gsi-desc-cast`

The sibling constructor flag enables `visitRefCast(...)`, which can replace:

- `ref.cast $T`

with a descriptor-equality-style cast when:

- the type has a descriptor type
- there are no relevant strict subtypes (unless the cast target is exact already)
- the descriptor type has exactly one candidate global in `typeGlobals`

This is explicitly a size-vs-speed tradeoff helper and is **not** part of the canonical no-DWARF open-world `-O` / `-Os` path tracked in the repo page.

## What the shipped lit file teaches

The dedicated `gsi.wast` test is broad and worth treating as part of the pass contract.
It covers:

- immutable vs mutable field gating
- one-global operand-rewrite positives
- 2-value and grouped-3-value select positives
- >2-unique-value bailouts
- function-local `struct.new` poisoning
- nested-global `struct.new` poisoning
- subtype propagation both positive and negative
- non-constant-field un-nesting
- overlapping un-nesting situations
- all-same-value constant cases
- `eqref` positive vs `anyref` negative global declarations
- direct `global.get`-operand positives
- packed-field signed/unsigned handling
- atomic-get positives
- bottom-type no-crash handling
- null-result refinement and refinalization

That is a much larger contract than the current local MoonBit test file.

## Biggest differences from the current Starshine implementation

## 1. Official Binaryen is not closed-world-only

Binaryen always runs `optimize(module)`.
Only the type-global analysis is closed-world-gated.

Current local pass:

- returns unchanged unless `closed_world` is true

That is a real semantic gap.

## 2. Official Binaryen optimizes arbitrary ref producers after closed-world analysis

Binaryen can optimize reads where the operand is:

- a local
- a parameter
- a value of a supertype
- something proven to come from one or two candidate globals

Current local pass only handles:

- immediate `global.get` followed by immediate `struct.get*`

## 3. Official Binaryen handles subtype reasoning

Binaryen uses `SubTypes` to:

- poison supertypes when children are unoptimizable
- propagate child globals upward to parent reads

Current local pass has no equivalent subtype reasoning.

## 4. Official Binaryen can un-nest non-constant operands

Binaryen can add new immutable globals and then reorder them.
Current local pass cannot.

## 5. Official Binaryen handles more read forms

Binaryen source and tests cover:

- ordinary `struct.get`
- packed signed/unsigned gets
- atomic gets
- `ref.get_desc`
- optional `gsi-desc-cast`

Current local pass only covers:

- immediate `struct.get` / `struct.get_s` / `struct.get_u`

## 6. Official Binaryen uses constant-global values, not just literals

`PossibleConstantValues` recognizes immutable `global.get`s as constant.
Current local pass has a much smaller notion of foldable value materialization.

## 7. Official Binaryen refinalizes changed functions

Current local boundary-IR implementation does not mirror the same typed-AST repair contract because it works in a different representation.
That is not automatically wrong, but it is still a real architectural difference from the source oracle.

## What a future Starshine port must preserve

A future strict-parity Starshine port or refactor must keep these source-backed rules honest:

- the pass is GC-gated
- open-world direct immutable-global read optimization still exists even without `closed_world`
- closed world adds a type-global map; it does not replace the open-world fast path
- only immutable fields are eligible
- mutable globals and nested/function-local allocators poison the relevant type families
- unoptimizable subtype allocations poison supertypes too
- candidate globals propagate upward to supertypes
- profitability is really “one value” or “two unique values with one singleton test,” not arbitrary many-way dispatch
- equality-comparable global declaration types matter for `ref.eq`-based selects
- packed-field signedness must be preserved on replacement
- atomic gets may still optimize when the field is immutable
- non-constant nested operands can still participate through un-nesting into fresh immutable globals
- refinalization is mandatory when replacement types become more precise
- the sibling `gsi-desc-cast` surface exists, but is distinct from the canonical `gsi` scheduler slot

If local code intentionally keeps a narrower subset, the wiki should continue describing that as a deliberate local divergence, not as "what Binaryen does."

## Durable conclusions

- Binaryen `global-struct-inference` is **not** just a closed-world constant folder.
- The official `version_129` contract is a layered pass:
  - open-world direct immutable-global read optimization
  - closed-world type-global candidate analysis
  - at-most-two-unique-values selection
  - non-constant operand un-nesting
  - type repair and optional desc-cast sibling support
- The current local Starshine implementation is meaningfully narrower than that contract, even though the saved generated-artifact `-O4z` slot is green.
- A narrow 2026-04-20 freshness check found no semantic post-`version_129` drift in the owning pass file or the dedicated lit file.
