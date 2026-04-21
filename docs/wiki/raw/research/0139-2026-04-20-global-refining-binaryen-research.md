# 0139 - Binaryen `global-refining` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the `once-reduction` dossier.
- Follow the repo wiki process in `docs/README.md`.
- Consult the updated tracker and choose one still-eligible pass.
- Deepen the early module-pass documentation around Binaryen's GC-aware global-type tightening.
- Produce durable notes that help a future Starshine maintainer preserve the real Binaryen contract instead of implementing a more ambitious but incorrect "global type inference" pass.

## Candidate selection

- `docs/wiki/binaryen/passes/tracker.md` now lists `global-refining` as the strongest remaining implemented landing-page target after `once-reduction`.
- `global-refining` is still only `landing`, not `deep`, in the tracker.
- It is eligible under the campaign rules.
- `agent-todo.md` still has **no dedicated `GR` slice** today; the relevant references are only the canonical ordered-path notes (`... -> once-reduction -> global-refining -> gsi -> ...`) and the shared post-`SSA` replay context that mentions the `DFE -> RUME -> MP -> OR -> GR -> GSI` prefix.

## Local repo context that matters

### Canonical no-DWARF scheduler placement

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` records the open-world no-DWARF pre-pass cluster for the MoonBit debug artifact as:

- `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> remove-unused-module-elements -> gsi`

So `global-refining` matters here as the bridge between:

- early run-once cleanup (`once-reduction`)
- second early global cleanup (`remove-unused-module-elements`)
- later GC-specific global-instance reasoning (`gsi` / `global-struct-inference`)

### Current in-tree Starshine implementation

The local implementation lives in:

- `src/passes/global_refining.mbt`
- `src/passes/global_refining_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`

The current MoonBit pass already does a conservative subset of Binaryen's idea:

- look only at defined private ref-typed globals
- collect initializer and observed `global.set` value ref types
- compute a conservative join using the validator environment's subtype matcher
- rewrite the declared global type when the result is a subtype of the old one

But it is **narrower than official Binaryen** in important ways:

- it skips all exported globals, even immutable ones
- it does not use the `closed_world` option even though the pipeline already threads that option for `global-struct-inference`
- it does not model Binaryen's `PublicTypeValidator` path for immutable exported globals in open world
- it does not need a separate AST `global.get` retagging pass because the local boundary IR does not cache expression result types the same way Binaryen's AST does

### Current local evidence

The generated-artifact `-O4z` audit shows slot `5` (`global-refining`) as:

- exact wasm equal: `yes`
- normalized WAT equal: `yes`
- Starshine wall/runtime: `403.297 ms`
- Binaryen wall/runtime: `198.980 ms`
- Starshine in-pass time: `0.611 ms`
- Binaryen in-pass time: `2.100 ms`

Source: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`

Important caution:

- exact equality on that slot does **not** prove full parity
- `global-refining` is often tiny or a no-op on real modules
- the saved artifact apparently does not exercise the official exported-global boundary matrix that the local implementation still lacks

## Official Binaryen source inventory

Primary `version_129` sources:

- `src/passes/GlobalRefining.cpp`
- `src/passes/pass.cpp`
- `src/ir/lubs.h`
- `src/ir/public-type-validator.h`
- `src/pass.h`
- `test/lit/passes/global-refining.wast`

Freshness check done for this note:

- `version_129` `src/passes/GlobalRefining.cpp` == current `main` `src/passes/GlobalRefining.cpp`
- `version_129` `test/lit/passes/global-refining.wast` == current `main` `test/lit/passes/global-refining.wast`

So there is no visible post-`version_129` semantic drift in the owning pass file or dedicated lit file right now.

## What the pass sounds like versus what it actually is

### Easy wrong mental model

A beginner might hear `global-refining` and imagine:

- a global dataflow pass
- maybe something like constant propagation
- maybe whole-program use-def reasoning over `global.get` and `global.set`
- maybe control-flow-sensitive narrowing based on where writes dominate reads

That is **not** what Binaryen `version_129` implements.

### Better source-backed mental model

Binaryen's pass is much smaller and more specific:

1. only run when GC features are enabled
2. find every `global.set` in defined functions
3. compute the least upper bound of the initializer type plus every assigned value type for each global
4. skip imported globals and boundary-dangerous exported cases
5. if the LUB is a strict subtype of the old global type, rewrite the declaration
6. update `global.get` nodes to report the new type and refinalize changed code

So this is really:

- **whole-module declaration tightening from observed value types**
- plus **boundary legality checks**
- plus **cached-type repair**

It is **not** an effects pass, not a dominance pass, not a constant-propagation pass, and not a global dead-store pass.

## Actual Binaryen implementation structure

## 1. Early gate: GC only

`GlobalRefining::run(Module* module)` begins with:

- `if (!module->features.hasGC()) return;`

That is important for two reasons:

- the pass is treated as part of the GC-sensitive early module cluster in the default scheduler
- even though some test shapes use function-reference syntax, the official implementation still refuses to run at all without GC enabled

## 2. Parallel `global.set` discovery

Binaryen does not walk the whole module serially for writes.
It uses:

- `ModuleUtils::ParallelFunctionAnalysis<GlobalInfo>`
- `FindAll<GlobalSet>(func->body)`

per defined function.

That means the expensive scan phase is deliberately simple and parallel:

- no CFG
- no effects
- no liveness
- no dominance
- just collect the `GlobalSet*` nodes so later code can look only at their value types

## 3. Type aggregation is just `LUBFinder`

The pass stores:

- `std::unordered_map<Name, LUBFinder> lubs;`

and for every collected `global.set` it does:

- `lubs[set->name].note(set->value->type);`

`src/ir/lubs.h` shows that `LUBFinder` is tiny:

- it starts at `Type::unreachable`
- each `note(type)` applies `Type::getLeastUpperBound(lub, type)`
- `noted()` just checks whether the current LUB is still `unreachable`

That is the heart of the pass.
There is no fancier analysis hidden elsewhere.

## 4. Boundary legality is the subtle part

This is the part most likely to be misunderstood.

Binaryen distinguishes:

- imported vs defined globals
- exported vs private globals
- mutable vs immutable exports
- open world vs closed world
- public vs non-public refined types

### Imported globals

Imported globals are never refined.

### Exported globals in open world

The official code inserts exported globals into `unoptimizable` only when:

- `global->mutable_`

in open world.

So in open world:

- exported mutable globals are **not** refined
- exported immutable globals may still be refined

But only if the resulting refined type is still a valid public type.

### Exported globals in closed world

In `version_129`, Binaryen is actually **more conservative** in closed world for this pass.
It marks every exported global unoptimizable when:

- `getPassOptions().closedWorld`

The code comment explains the reason:

- changing an export from a public type to a private one could cause validation issues
- TODO: they could refine to a still-public type in the future

So the official current rule is:

- closed world => skip all exported globals

That is easy to get wrong because many people expect closed world to allow *more* aggressive exported-type changes here. For this exact pass today, it does not.

### Public-type validation

For the remaining open-world immutable export case, Binaryen checks:

- `PublicTypeValidator publicTypeValidator(module->features);`
- `publicTypeValidator.isValidPublicType(newType)`

`src/ir/public-type-validator.h` makes the important beginner-facing rule explicit:

- basic public types are fine
- tuple public types are checked recursively
- exact ref types are **not** valid public types when custom descriptors are not enabled

That explains the dedicated lit behavior:

- open-world immutable exports can refine to things like `nullfuncref`
- they cannot refine to private exact heap-ref types just because the LUB found one

## 5. Initializers matter as much as writes

After gathering all `global.set` value types, the pass still does:

- `lub.note(global->init->type);`

for each candidate global.

So the contract is:

- refined type must cover the initializer and every later assigned value

This is why the lit file covers all of these:

- init-only null globals
- init-only `ref.func` globals
- null + later non-null writes
- non-null + later null writes
- heterogeneous write families like `i31`, `struct`, and multiple null forms

## 6. The actual rewrite is tiny

If the new LUB differs from the old type and passes the boundary checks, Binaryen does only this declaration edit:

- `global->type = newType;`

There is no separate `global.set` rewrite algorithm here.
There is no user-side `global.get` replacement with constants.
There is no elimination of dead globals.

## 7. But cached type repair is mandatory

After changing declarations, Binaryen must update all `global.get` expressions that now return a narrower type.

That is why the pass defines `GetUpdater`, a nested `WalkerPass<PostWalker<...>>` that:

- visits `GlobalGet`
- compares `curr->type` against `wasm.getGlobal(curr->name)->type`
- rewrites the cached type if needed
- sets `modified = true`
- calls `ReFinalize().walkFunctionInModule(...)` after a changed function
- also runs over module code with `runOnModuleCode(...)`

This part is easy to miss if you read the file only as a declaration-rewrite pass.
But it is essential for correctness in Binaryen's typed AST.

## 8. No non-nullable local fixups required

Both the top-level pass and `GetUpdater` override:

- `requiresNonNullableLocalFixups() -> false`

That is a good negative fact to record.
The pass changes global declarations and `global.get` result types, but it does not create the kind of local-structural-dominance problems that need the generic non-nullable-local repair pass.

## What the official lit file teaches

The dedicated `global-refining.wast` file is small but very dense.
The durable lessons are:

### 1. Init-only globals can refine

Examples:

- `funcref` initialized with `ref.null $foo_t` becomes `nullfuncref`
- `funcref` initialized with `ref.func $foo` becomes `(ref (exact $foo_t))`

### 2. Later null writes keep exactness but make the global nullable

If the initializer is `ref.func` but later code stores `ref.null`, Binaryen refines to:

- `(ref null (exact $foo_t))`

not just broad `funcref`.

### 3. Later non-null writes can make a global non-nullable

If all observed values are non-null exact-function refs, the global can become non-null exact.

### 4. Heterogeneous GC values refine to a meaningful middle type

The file's `anyref` example with:

- `ref.i31`
- `struct.new_default`
- `ref.null eq`
- `ref.null i31`
- `ref.null $array`

refines the global to:

- `eqref`

This is a great beginner example because it shows the pass is computing a true **least upper bound**, not just picking one write and not just collapsing everything back to `anyref`.

### 5. Another global's initializer may depend on the refined one

The file includes:

- global `$a` refined from `(ref $super)` to `(ref (exact $sub))`
- global `$b` initialized by `(global.get $a)`

The expected output keeps `$b` valid, which is why the pass must repair `global.get` result types after declaration changes.

### 6. Export behavior is intentionally asymmetric

The last module is the critical matrix:

- unexported mutable null-func global can refine
- unexported immutable null-func global can refine
- exported mutable global stays broad in open world and closed world
- exported immutable global refines in open world to `nullfuncref`
- exported immutable global stays broad in closed world

That last line is the most unintuitive one and should remain explicit in the wiki.

## Important pass interactions

## Scheduler meaning

For the canonical open-world no-DWARF path relevant to this repo:

- `once-reduction -> global-refining -> remove-unused-module-elements -> gsi`

Meaning:

- `once-reduction` may simplify away some run-once scaffolding first
- `global-refining` then tightens global declaration types based on still-reachable writes
- the second early `remove-unused-module-elements` can drop module junk unlocked by the GC/type cluster
- `gsi` then sees narrower, more useful global types

## Closed-world neighbors

In `pass.cpp`, closed world inserts more passes around it:

- before: `type-refining`, `signature-pruning`, `signature-refining`
- after: optional `gto`, `remove-unused-module-elements`, `remove-unused-types`, `cfp`/`cfp-reftest`, `gsi`, `abstract-type-refining`, `unsubtyping`

So for future research, the exact neighbor story depends on whether we are documenting:

- the repo's current canonical open-world no-DWARF path
- or the broader Binaryen closed-world GC cluster

## What this pass does **not** do

These are worth keeping explicit in living docs:

- no control-flow-sensitive reasoning about which sets dominate which gets
- no effect analysis
- no liveness analysis
- no constant propagation from globals
- no removal of dead `global.set`
- no `global.get`-to-constant replacement
- no direct `gsi`-style field-value inference
- no global-type change for imported globals
- no broad exported-global rewriting in open world or closed world

## Current Starshine comparison

The local MoonBit implementation matches the broad idea but not the whole official boundary matrix.

### Source-backed local strengths

- It already refines private defined ref globals from initializer and observed write types.
- It already computes conservative joins across sibling writes.
- The saved generated-artifact slot is exact-equal.
- Focused local tests cover:
  - private narrower writes
  - exported-global bailout
  - sibling-write shared-supertype join

### Source-backed local gaps

1. **Export policy is narrower than Binaryen.**
   - Local code skips all exported globals.
   - Binaryen still refines open-world immutable exports if the result is public.

2. **`closed_world` is not threaded into this pass.**
   - `pass_manager.mbt` threads `options.closed_world` to `global-struct-inference`.
   - It does not thread it to `global-refining`.

3. **There is no local `PublicTypeValidator` equivalent on this path.**
   - So the open-world immutable-export case cannot currently be modeled faithfully.

4. **The implementation strategy differs.**
   - Binaryen uses typed AST nodes, `FindAll<GlobalSet>`, `LUBFinder`, and `GetUpdater` + `ReFinalize`.
   - Starshine uses a cheap boundary pre-scan, HOT lifting only for functions that actually set candidate globals, and validator-environment subtype matching.

5. **The local pass lacks the explicit Binaryen GC gate.**
   - The practical effect may still often be a no-op when no ref globals exist.
   - But it is still a real semantic difference from official source.

### Likely reason the saved audit still matches

The most plausible explanation is:

- the saved artifact either does not expose the missing exported-global/public-type cases
- or the pass is effectively a no-op / same-op on that module

That is an inference from the green audit plus the visible local-vs-upstream boundary differences, not a quoted upstream claim.

## Durable rules a future Starshine port must preserve

- Treat `global-refining` as a **module declaration pass**, not a local peephole pass.
- Use the initializer and **all** observed `global.set` value types when computing the candidate refined type.
- Use a true least upper bound; do not just pick the narrowest or last-seen write.
- Never widen a global type; only accept strict subtype improvements.
- Keep imported globals untouched.
- Preserve Binaryen's exported-global matrix exactly if the goal is parity:
  - open world mutable export => no refine
  - open world immutable export => refine only if new type is public
  - closed world export => currently no refine at all in official `version_129`
- If local IR caches expression result types, retag `global.get` users after changing declarations.
- Refinalize changed code after retagging.
- Do not add generic non-nullable-local fixups here unless the local representation really needs them.

## Open questions / uncertainty

- The official source explicitly rewrites `global.get` cached types, and the lit file also shows some null values printed in narrower textual form after refinement. The pass file does **not** directly mutate `global.set` value expressions, so the exact reason for those narrower printed null spellings is probably downstream type/refinalization or print normalization behavior. That explanation is an inference from the source plus test output, not something spelled out in prose comments.
- The local MoonBit implementation may already be "good enough" for real artifact parity because the artifact does not hit the exported immutable/public-type cases, but that remains an inference until a dedicated Binaryen compare lane covers those shapes directly.

## Recommended living wiki pages

This note should be absorbed into:

- `docs/wiki/binaryen/passes/global-refining/index.md`
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-refining/exports-public-types-and-retagging.md`
- `docs/wiki/binaryen/passes/global-refining/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-refining/parity.md`

## Sources

### Repo sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0068-2026-03-25-global-struct-inference.md`
- `docs/wiki/raw/research/0080-2026-04-11-late-pipeline-pass-dispatch-audit.md`
- `src/passes/global_refining.mbt`
- `src/passes/global_refining_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `agent-todo.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-debug-2026-03-25/direct-pass-health/summary.tsv`

### Official Binaryen sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalRefining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/public-type-validator.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-refining.wast>

### Narrow freshness-check surface

- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalRefining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-refining.wast>
