# 0127 - `flatten` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented Binaryen aggressive flat-IR preparation pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what `flatten` actually does, how the prelude algorithm works, which helper utilities it depends on, which IR / WAT shapes it rewrites or preserves, and what a future Starshine port must keep exact.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` still listed `flatten` with wiki status `none` when this thread started.
- It is the top suggested next target after the newly-landed `directize` dossier.
- It is the first currently undocumented pass in the aggressive `-O4` / `-O4z` prelude:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - slot `9`
- The saved Binaryen debug log shows it is not just a one-off top-level curiosity in that captured run:
  - top-level slot `9` took about `1.67786` seconds
  - the same full run executed `flatten` `18` total times because nested optimizing reruns reuse the default function pipeline
- Unlike several already-documented late-tail passes, `flatten` does **not** currently have a dedicated implementation slice in `agent-todo.md`.
  - The closest local planning note is still the older Batch 2 intent in `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` and `docs/0065-2026-03-24-ir2-execution-plan.md`.
- The pass name is very easy to overread. A shallow mental model like “remove nesting” misses several crucial realities:
  - `flatten` is a specific formal **Flat IR** normalizer defined in `src/ir/flat.h`
  - it introduces many temp locals on purpose
  - it forbids value-carrying `block` / `if` / `loop` / `try` forms
  - it rewrites `local.tee`, value-carrying `br` / `br_if` / `switch`, and even concrete function bodies
  - it uses a postorder `preludes` algorithm instead of a simple local rewrite helper
  - it has explicit `version_129` hard failures on `BrOn*` and `TryTable`
  - it still carries an open TODO about some non-nullability cases

That combination makes `flatten` a strong dossier target: it sits early in the aggressive optimizer, it changes the IR shape that later locals passes see, and the real contract is much more precise than the name suggests.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/0065-2026-03-24-ir2-execution-plan.md`

### Official Binaryen `version_129` sources

- `src/passes/Flatten.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Flatten.cpp>
- `src/ir/flat.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- dedicated / near-dedicated flatten tests
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten-eh-legacy.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>

### Freshness check on current upstream `main`

- `src/passes/Flatten.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Flatten.cpp>

I only used `main` for a narrow freshness check on the two easiest drift points to miss:

- the top-of-file non-nullability TODO
- the hard `Unsupported instruction for Flatten` fatal on `BrOn` / `TryTable`

As of `2026-04-20`, both of those lines are still present on `main`.

## Fast answer

Binaryen’s `flatten` pass is an aggressive early `-O4` / `-O4z` function pass that rewrites Binaryen IR into a formal “Flat IR” shape.

The short version is:

1. walk expressions in postorder
2. move nested effectful or value-producing work into temp-local-producing **preludes**
3. eliminate value-carrying control structures by routing their values through locals
4. eliminate `local.tee`
5. route branch values through named-target temp locals
6. leave behind only flat children such as `local.get`, constants, `unreachable`, and the special allowed nested `ref.as_non_null`

The most durable source-derived facts are:

- `flatten` is registered as a function-parallel pass whose summary is “flattens out code, removing nesting.”
- It is only inserted in `pass.cpp` when `options.optimizeLevel >= 4`.
  - That means it is **not** part of the canonical no-DWARF `-O` / `-Os` path tracked elsewhere in this repo.
- The aggressive scheduler comment says Binaryen first flattens the IR and then runs passes that depend on flat IR.
  - The explicit immediate trio is `flatten -> simplify-locals-notee-nostructure -> local-cse`.
- The formal flatness contract in `flat.h` has four main rules:
  1. aside from `local.set`, operands must be `local.get`, constants, `unreachable`, or `ref.as_non_null`
  2. control-flow structures may not return values
  3. `local.tee` is disallowed
  4. `local.set` cannot take control flow as its value
- The implementation uses two core state maps:
  - `preludes`: code that must execute immediately before a given expression
  - `breakTemps`: temp locals keyed by branch target names for carried branch values
- Important control-flow families get custom handling:
  - `Block`
  - `If`
  - `Loop`
  - legacy `Try`
  - `Break` / `br_if`
  - `Switch` / `br_table`
- `If` temp typing uses `Type::getLeastUpperBound(...)`, not the original exact arm types.
  - That is an important GC/reference-typing detail.
- `flatten` deliberately adds many locals, so it invalidates DWARF.
- `flatten` also has to repair EH stack discipline afterwards with `EHUtils::handleBlockNestedPops(...)` because flattening can insert blocks inside `catch` bodies.
- In `version_129`, the pass **fatals** on `BrOn*` and `TryTable` instead of conservatively skipping them.
- There is still a top-of-file TODO about some non-nullability cases.
  - However, the shipped tests also show selective non-null support already works for some cases, such as flattening a non-nullable param/local.get case and a `ref.as_non_null` result case.

## Where it appears in the scheduler

## Registered pass surface

`pass.cpp` registers:

- `flatten`
  - description: “flattens out code, removing nesting”

`passes.h` declares:

- `createFlattenPass()`

There is no public `flatten-always` or similar helper variant in `version_129`.

## Aggressive-only placement

The important scheduler region in `pass.cpp` is:

- `ssa-nomerge`
- if `optimizeLevel >= 4`:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- then the rest of the main function optimizer continues with `dce`, `remove-unused-brs`, `optimize-instructions`, and so on

So the most important scheduler truth is:

- `flatten` is **not** ordinary no-DWARF `-O` / `-Os` work
- it is aggressive optimize-level-4-only work
- its main purpose is to expose later flat-IR-friendly locals cleanup

The scheduler comment says exactly why Binaryen does this:

- if it is “willing to work very very hard,” it flattens the IR and runs optimizations that depend on flat IR
- `local-cse` is particularly useful after flatten, but flatten creates many new redundant locals, so Binaryen first runs some simplify-locals cleanup

That is a very strong hint about intended pass meaning.

## Saved generated-artifact `-O4z` evidence

The saved ordered replay records:

- slot `9`: `flatten`

The saved Binaryen debug log records the top-level aggressive opening cluster as:

- `ssa-nomerge`
- `flatten`
- `simplify-locals-notee-nostructure`
- `local-cse`
- `dce`

and the top-level flatten slot took about `1.67786` seconds in that captured run.

The same saved debug log also records `18` total `flatten` executions. That is much more than one top-level slot, so a real implementation dossier must remember the nested-rerun story too.

The simplest explanation is:

- Binaryen’s optimizing passes rerun the default function optimization pipeline on changed functions
- and the aggressive `optimizeLevel >= 4` prefix includes flatten

I did not fully re-audit every nested helper for this note, but the saved debug log and the already-documented optimizing-pass rerun structure line up with that interpretation.

## Formal Flat IR contract from `flat.h`

The most important source file for understanding this pass is not just `Flatten.cpp`; it is `src/ir/flat.h`.

`flat.h` says flattening is not vague “less nesting.” It is a precise AST contract.

### Rule 1: operands must be very simple

Except for `local.set`, operands must be one of:

- `local.get`
- constant expression
- `unreachable`
- `ref.as_non_null`

Anything else must be computed earlier and written to a local.

### Rule 2: control flow cannot carry values

These structures must not return values after flattening:

- `block`
- `loop`
- `if`
- `try`

The function body also must not have a concrete result type by itself.

### Rule 3: no `local.tee`

Flattened IR must use standalone `local.set`, not nested tee forms.

### Rule 4: `local.set` cannot receive control flow

Even if a control-flow child is unreachable, it still is not allowed directly as the value child of `local.set`.

## A very important nuance: `ref.as_non_null`

`flat.h` explicitly allows nested `ref.as_non_null`.

The source comment explains that this is special-case behavior because flattening cannot always spill it the same way it spills other values.

At the same time, the test corpus shows selective non-null handling already works in some real cases:

- `flatten.wast` proves a non-nullable function param/local.get case
- `flatten_all-features.wast` proves a `ref.as_non_null` result case

So the safest wording is:

- non-null support in `version_129` is **selective**, not absent
- but it is also **not complete**, because `Flatten.cpp` still has an open TODO about some non-nullability families

## Actual implementation structure

## 1. Pass shape and mutable state

`Flatten` is implemented as:

- `WalkerPass<ExpressionStackWalker<Flatten, UnifiedExpressionVisitor<Flatten>>>`

and reports:

- `isFunctionParallel() == true`
- `invalidatesDWARF() == true`

The two central mutable maps are:

- `preludes`
  - `Expression* -> vector<Expression*>`
- `breakTemps`
  - `Name -> Index`

Those are the core algorithm.

## 2. Prelude-based postorder rewriting

The top comment in `Flatten.cpp` explains the intended algorithm clearly:

- when visiting an expression, handle it together with code that must run immediately before it
- if an expression has side effects or produces a non-flat child shape, reduce it to a `local.get` and put the actual work in a prelude
- preludes can migrate upward only through non-control parents
- control-flow parents must explicitly place their children’s preludes in the right position

This gives a useful beginner mental model:

- flatten is really a **pre-execute then read-from-temp** rewrite
- not a generic recursive “replace nesting with locals somewhere” pass

## 3. Control-flow rewrites are custom and value-aware

### `Block`

For a block:

- child preludes are inserted directly into the block item list before each item
- if the block had a concrete result type, that value is routed through a temp local
- if there is already a `breakTemps` temp for the block name, Binaryen reuses it
- otherwise it allocates a fresh temp
- the block becomes `Type::none`
- the current expression is replaced with `local.get temp`
- the whole block itself becomes a prelude

This is one of the easiest ways to see that flatten is not a mere local child rewrite. It rewrites the control structure itself.

### `If`

For an if:

- condition preludes go before the whole `if`
- arm preludes stay inside the respective arms
- if the `if` is value-typed, Binaryen allocates a temp and stores each concrete arm result into it
- the temp type is the least upper bound of the two arm types when there is an `else`
- if the original `if` produced a value in the outer expression, Binaryen replaces that outer use with `local.get temp`

That `LUB` detail is important for GC/reference typing. A future port must not assume exact arm type identity.

### `Loop`

For a value-carrying loop:

- Binaryen writes the loop body’s value into a temp
- changes the loop itself to `Type::none`
- replaces the outer value use with `local.get temp`
- and treats the loop as a prelude

### legacy `Try`

For a value-carrying legacy `try`:

- Binaryen allocates one temp for the try result
- both the main body and each catch body store to that temp when they produce a concrete value
- the outer use becomes `local.get temp`
- and the `try` becomes a prelude

This is not the end of EH handling, though: flatten later has to fix nested pops.

## 4. `local.tee`, branch values, and switch values are all rewritten specially

### `local.tee`

If Binaryen sees `local.tee`:

- if its value is `unreachable`, it simply replaces the tee with the unreachable value
- otherwise it converts the tee to a plain set, pushes that set into preludes, and leaves a `local.get` in the original position

That is the entire “no tee” rule in action.

### `Break` / `br_if`

For branch values:

- if the branch carries a concrete value, Binaryen routes it through a named-target temp via `getTempForBreakTarget(...)`
- then it clears the branch’s value field and refinalizes the branch

The surprising part is the `br_if` special case.

A conditional branch may still leave a value flowing out when the branch is **not** taken. The source comment documents a real type mismatch hazard:

- the target block’s carried type may differ from the innermost block’s flowing-out type

So Binaryen may allocate **two** locals:

- one temp keyed to the break target type
- one extra temp with the original flowing-out value type

That is a subtle but very important correctness rule.

### `Switch` / `br_table`

For a switch carrying a value:

- Binaryen first stores the value into a temp once
- then copies that temp into all unique branch-target temps returned by `BranchUtils::getUniqueTargets(...)`
- then removes the switch value field itself

This is one of the clearest examples that flatten preserves control semantics by duplicating local traffic, not by trying to outsmart the branch structure.

## 5. General spill rule after special handling

After the custom cases, `Flatten.cpp` continues with a general rule:

- `ReFinalizeNode()` visits the current expression because children may have changed
- if the current expression is now `unreachable`, Binaryen keeps the real expression as a prelude and leaves behind a placeholder `unreachable`
- otherwise, if the current expression still has a concrete type, Binaryen allocates a temp local, pushes `local.set temp, expr` into preludes, and replaces the current expression with `local.get temp`

This means flatten is very aggressive.

Even if a nested expression is perfectly valid WebAssembly by itself, Binaryen may still spill it purely to satisfy the formal flatness rules.

## 6. Prelude migration rules matter for correctness

After building `ourPreludes`, Binaryen decides where they can live:

- if the parent exists and is **not** a control-flow structure, the preludes migrate to the parent’s prelude list
- otherwise the preludes stay attached to the current expression, and the control-flow parent will place them explicitly later

That is the key source-level reason side effects remain ordered correctly.

It also explains why control-flow nodes get their own custom logic instead of using only one generic helper.

## 7. Function finishing and EH pop repair

In `visitFunction(...)`, Binaryen does two final things:

1. if the function body still has a concrete type, wrap it in `return`
2. attach any remaining body preludes with `getPreludesWithExpression(...)`

Then it runs:

- `EHUtils::handleBlockNestedPops(curr, *getModule())`

The comment explains why:

- flatten can create blocks within `catch`
- that can make exception `pop` locations invalid
- so Binaryen fixes them afterwards

The dedicated `flatten-eh-legacy.wast` file exists specifically to lock that behavior down.

## Important test-backed shape families

The flatten test surface is much broader than the tiny `flatten.wast` smoke test.

## 1. Simple nested arithmetic becomes temp locals

`flatten_all-features.wast` begins with very basic proofs that:

- `(drop (i32.add ...))` becomes a temp local plus dropped `local.get`
- a function body returning `(i32.add ...)` becomes a temp local plus `return (local.get ...)`

This is the beginner-friendly baseline: ordinary nested value trees become compute-then-read-from-local.

## 2. Value-carrying `block` becomes prelude block + get

The same file locks the pattern where a block used as an operand of `i32.add` is rewritten so that:

- the block runs earlier
- its last value is stored in a temp
- the outer add consumes `local.get temp`

This is the canonical “flatten removes control-flow return values” shape.

## 3. `local.tee` inside value blocks explodes into extra local traffic

`flatten_all-features.wast` includes direct `local.tee` examples showing that flatten introduces more copies than you might expect:

- tee becomes set plus get
- nested tee chains become several locals in sequence

This is exactly why the scheduler comment says Binaryen must simplify locals a little before trying `local-cse`.

## 4. `br_if` and `br_table` values are routed through locals

Several test sections prove that:

- carried `br_if` values are stored before the branch
- untaken `br_if` paths can still need a flowing-out local value
- `br_table` / switch values are preserved through local routing rather than left nested

The source-only double-temp rule for mismatched target/outflow types is especially important here.

## 5. EH flattening is real and needs repair

`flatten-eh-legacy.wast` proves two important things:

- flatten handles legacy try/catch result and pop traffic by introducing temp locals
- flatten can create blocks inside a catch, which then requires EH pop-location fixup

That second point is easy to miss if you only read the pass name.

## 6. Selective non-null support is already test-backed

Two small but important tests matter here:

- `flatten.wast` shows a non-nullable param/local.get case that is okay after flatten
- `flatten_all-features.wast` shows a `ref.as_non_null` result case that is also accepted

So the open non-nullability TODO is real, but it is **not** evidence that every non-null family is unsupported.

## 7. Downstream passes rely on flatness being real

`opt_flatten.wast`, `flatten_rereloop.wast`, and `flatten_i64-to-i32-lowering.wast` all show that flatten is not just an isolated normalizer test.

Binaryen ships direct pass-composition tests where flattened output is fed to later passes.

That is strong evidence that the flatness contract matters as a shared intermediate representation boundary, not just as an internal cleanup curiosity.

## What `flatten` does **not** do

Binaryen `version_129` `flatten` is not:

- `merge-blocks`
- `code-folding`
- `simplify-locals`
- `local-cse`
- `merge-locals`
- a profitability pass
- a CFG simplifier
- a direct fixpoint optimizer that removes all redundant locals after introducing them

It is a structural normalizer.

That is why the immediate scheduler neighbors matter so much.

## Hard limits and honest caveats

## 1. `BrOn*` and `TryTable` are hard failures in `version_129`

`Flatten.cpp` literally does:

- `Fatal() << "Unsupported instruction for Flatten"`

when it sees:

- `BrOn`
- `TryTable`

This is more than a bailout. It is a hard unsupported-instruction path.

I also checked current upstream `main` on `2026-04-20`, and those lines are still present there.

## 2. The top-level non-nullability TODO is still open

`Flatten.cpp` still begins with a TODO documenting a non-nullability example it does not handle yet.

I am interpreting that as:

- some non-null or tuple/non-defaultable families remain incomplete
- but the shipped test corpus proves some non-null cases already work

So a future Starshine port should not simplify this into either:

- “flatten fully supports non-nullability”, or
- “flatten cannot handle non-null values at all”

Both would overstate the source.

## 3. I did not fully audit every downstream flat-IR verifier user

`flat.h` provides `verifyFlatness(...)`, and several flatten composition tests suggest downstream passes rely on it.

I did **not** do a whole-repo code-search audit of every verifier call site for this note.

So when I say flatten is a shared flat-IR boundary, that conclusion is well-supported by `flat.h`, pass scheduling, and the test surface, but the full list of downstream verifier users remains outside this note’s audited scope.

## Future Starshine port checklist

A future Starshine `flatten` port should preserve all of the following:

- the **formal flat-IR contract** from `flat.h`, not just a loose “less nesting” intuition
- the postorder **prelude map** algorithm or something behaviorally equivalent
- explicit rewrites for:
  - value-carrying `block`
  - value-carrying `if`
  - value-carrying `loop`
  - value-carrying legacy `try`
  - `local.tee`
  - carried `br` / `br_if`
  - carried `switch` / `br_table`
- the `if` least-upper-bound temp typing rule
- the branch-target temp map keyed by label name
- the double-temp `br_if` rule when target type differs from flowing-out type
- the `switch` unique-target fanout rule
- the generic unreachable-placeholder rule
- the function-body `return` wrapping rule
- the EH nested-pop repair step
- the aggressive `-O4`-only scheduler placement before `simplify-locals-notee-nostructure` and `local-cse`
- the explicit unsupported-instruction policy for `BrOn*` / `TryTable`, unless the project intentionally documents a divergence
- explicit tests for selective non-null cases and the still-open non-null TODO families

## Bottom line

The cleanest beginner-friendly summary is:

- `flatten` is Binaryen’s aggressive **prelude + temp-local normalizer** for Flat IR
- it does not try to optimize away the local traffic it creates
- it exists so later passes can operate on a much simpler, more local expression shape
- its correctness depends on several easy-to-miss details:
  - control-flow results becoming locals
  - carried branch values becoming named-target temps
  - `if` temp typing using least upper bounds
  - unreachable placeholders preserving earlier control effects
  - EH pop fixups after catch-local block insertion
  - and the current unsupported `BrOn*` / `TryTable` boundary
