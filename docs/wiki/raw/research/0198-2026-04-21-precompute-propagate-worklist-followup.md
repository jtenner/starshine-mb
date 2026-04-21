# Binaryen `precompute-propagate` worklist / fallthrough follow-up

Date: 2026-04-21

## Scope

This note is a follow-up to the existing `precompute-propagate` dossier.

The folder already had a solid landing page, strategy page, implementation/test map, and WAT-shape page. But after the tracker filled out, it still had one real teaching gap worth a source-backed major-gap fallback:

- it named the extra `LazyLocalGraph` propagation phase,
- but it still did **not** explain the exact `propagateLocals(...)` contract well enough for a future port or for beginner-to-intermediate readers.

That missing middle layer mattered because the actual Binaryen `version_129` behavior is narrower and more surprising than the existing folder made obvious:

- it propagates **fallthrough values of sets**, not arbitrary full expressions,
- it requires **all reaching sets for a get to agree on one concrete literal tuple**,
- it treats **entry values for vars** as default zero literals but bails out for **nondefaultable locals** and params,
- it only seeds the second walk through a **get-values map**,
- it uses a **set/get influence worklist** instead of an open-ended fixed-point CFG solver,
- and it intentionally **does not rerun partial-select precompute** after propagation.

That is enough of a real source-backed nuance gap to justify one focused follow-up page.

## Candidate selection result

Chosen pass: `precompute-propagate`

Why this follow-up was still eligible:

- the tracker now says the main parity queue and the first upstream-only expansion wave are dossier-covered,
- the user explicitly asked for exactly one pass that still needs more wiki information,
- `precompute-propagate` is not on the do-not-pick list for this thread,
- and the existing folder still lacked one dedicated page for the real local worklist / fallthrough / merge-consensus boundary.

So this is not a new tracker expansion; it is a justified major-gap follow-up inside an already existing dossier.

## Backlog slice check

`agent-todo.md` still has **no dedicated `precompute-propagate` slice**.

The pass remains visible indirectly through nearby slices and docs:

- `[PC]001` says to keep the plain-`precompute` vs `precompute-propagate` split explicit.
- `dae-optimizing` and `inlining-optimizing` still depend on the nested `optimizeAfterInlining(...)` contract that prepends `precompute-propagate`.
- `simplify-globals-optimizing` still matters as the contrast case that reruns the default function pipeline without that prepended pass.

## Sources reviewed for this follow-up

### Local repo sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/precompute-propagate/index.md`
- `docs/wiki/binaryen/passes/precompute-propagate/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/precompute-propagate/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/precompute-propagate/wat-shapes.md`
- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/precompute/propagation-partial-precompute-and-gc-identity.md`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/Precompute.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/ir/local-graph.h`
- `test/lit/passes/precompute-propagate-partial.wast`
- `test/lit/passes/precompute-propagate_all-features.wast`

## Main findings

## 1. The real extra phase is a small local worklist, not a generic SCCP engine

The existing dossier was right to emphasize `LazyLocalGraph`, but the follow-up source read makes the shape much clearer.

`propagateLocals(Function* func)` in `Precompute.cpp` does this:

1. construct `LazyLocalGraph localGraph(func, getModule())`
2. scan the graph's recorded get/set locations
3. try to prove individual `LocalSet*` values concrete
4. try to prove individual `LocalGet*` values concrete
5. push newly-proven gets and sets onto a small worklist
6. follow only graph influences from that worklist until no new constants appear
7. return whether any `LocalGet*` constants were learned

That is much smaller than:

- sparse conditional constant propagation,
- arbitrary CFG-wide lattice solving,
- or a repeated whole-pass convergence loop.

A better teaching line is:

- Binaryen does one targeted local get/set consensus solve, then reruns the main evaluator once.

## 2. Sets are analyzed through **fallthrough values**, not through arbitrary whole-expression replacement

This is the easiest detail to miss and the most important one to preserve in a port.

`checkConstantSet(...)` does **not** ask whether the entire `local.set` value expression can be replaced directly in place.
Instead it computes:

- `precomputeValue(Properties::getFallthrough(set->value, ...))`

That means Binaryen can look through some wrappers to the value that would actually fall through, which is why `precompute-propagate` can still learn from shapes involving things like `local.tee` or some wrappers that plain syntactic constant propagation would treat as opaque.

But Binaryen then immediately narrows that freedom again:

- the candidate propagated literal must be concrete, and
- `Type::isSubType(values.getType(), set->value->type)` must hold.

So the pass is not allowed to propagate a fallthrough value whose type would be invalid for the original set value expression.

The in-file `ref.cast` example is the important warning case:

- a fallthrough null from inside `ref.cast` does not mean the full expression may safely propagate that null as if the cast were gone.

## 3. Gets are constant only when **every reaching set agrees exactly**

`checkConstantGet(...)` is stricter than the existing dossier made explicit.

For a `local.get` to become constant, Binaryen iterates all sets returned by `localGraph.getSets(get)` and requires that every reachable source produce the same concrete `Literals` value.

Important consequences:

- identical constants on both branches can collapse the get,
- different constants on different incoming sets block propagation,
- one constant branch plus one nonconstant branch blocks propagation,
- and the phase is consensus-based rather than branch-predicate-based.

This is the source-backed reason tests like the following behave differently:

- `split-but-join` folds because both arms store the same constant,
- `split-but-join-different` does not fold because the incoming constants differ,
- `split-but-join-different-b` does not fold because one arm is not proven constant.

## 4. Function-entry values are treated differently for vars, params, and nondefaultable locals

The get-consensus logic has an important three-way entry boundary.

When `localGraph.getSets(get)` yields a `nullptr` reaching source, Binaryen interprets that as reading the function-entry value.

Then it distinguishes:

- **param**: always bail out; params are not constant here
- **defaultable var**: use `Literal::makeZeros(localType)` as the entry value
- **nondefaultable var**: bail out, because this is either unreachable imprecision or an internal error and the pass refuses to guess

This matters because it explains several otherwise-surprising outcomes:

- why locals with implicit zero init can participate in consensus,
- why params do not,
- and why the pass is conservative around nondefaultable locals and unreachable code.

## 5. The worklist is bidirectional across get/set influences, but the final rerun only consumes `getValues`

Another important nuance is that Binaryen computes both set and get constants during propagation, but it does not expose them equally.

Internally it tracks:

- `setValues: LocalSet* -> Literals`
- `getValues: LocalGet* -> Literals`

And it uses both on the worklist:

- constant sets can make influenced gets constant,
- constant gets can make influenced sets constant.

But the second full walk consults only `getValues` directly through `PrecomputingExpressionRunner::visitLocalGet(...)`.

So the set map is a propagation helper, while the get map is the user-visible hook that enlarges what the main evaluator can prove on the rerun.

That is a cleaner mental model than saying the pass “rewrites sets and gets equally.”

## 6. The phase deliberately stops after one extra full walk

`doWalkFunction(...)` makes the stopping rule explicit:

- run the ordinary walk,
- run partial-select precompute,
- if `propagate == true`, run `propagateLocals(...)`,
- if propagation learned any get constants, rerun the main walk once,
- **do not** rerun partial-select precompute again,
- and leave rarer later opportunities to later executions of the pass or `--converge`.

That means the real contract is:

- one extra local-fact solve,
- one extra evaluator walk,
- no built-in repeated convergence loop.

This is exactly the kind of subtle scheduler/algorithm contract that future Starshine code could easily over- or under-implement without an explicit page.

## 7. Partial-select precompute has its own cache-safety boundary that still matters to the propagate variant

The dedicated `precompute-propagate-partial.wast` test is not just a generic partial-precompute test.
It locks a bug boundary that matters specifically because propagation can unlock extra later simplifications.

During speculative parent-into-select-arm evaluation, Binaryen:

- uses a temporary `HeapValues temp`,
- explicitly avoids the normal heap-value cache,
- and clears the temp cache between the two arms.

The reason is subtle but important:

- speculative no-trap or alternate-branch computations must not poison the real heap-identity/trap reasoning used by the ordinary pass state.

That is a concrete future-port invariant, not just an implementation detail.

## 8. The all-features lit file makes the local-worklist contract much more concrete than the old dossier admitted

`precompute-propagate_all-features.wast` shows that the propagation phase covers and preserves several exact families:

Positive or clarifying families:

- direct local-carried arithmetic folding (`basic`, `later`, `later2`)
- branch-join consensus on identical constants (`split-but-join`, `two-ways-but-identical`)
- zero-init entry consensus (`split-but-join-init0`)
- propagation through `local.tee` / fallthrough (`through-tee`)
- tuple-local constant propagation (`tuple-local`)

Negative or bailout families:

- differing incoming constants (`split-but-join-different`)
- one nonconstant incoming arm (`split-but-join-different-b`)
- loop-carried or otherwise not-consensus-safe shapes (`deadloop` and related examples)

So the all-features file is not incidental; it is the clearest upstream beginner-facing oracle for what this phase really means by “propagates through locals.”

## 9. The pass still inherits the shared emitability barrier against most heap refs

The extra local phase does not bypass the shared `precompute` family rule that most references are not re-emittable as constants.

`canEmitConstantFor(...)` still allows:

- null refs,
- function refs,
- UTF-16 string literals,
- and ordinary numeric literals,

but rejects other reference literals for replacement.

The source even comments that immutable GC references are not handled here because the pass may evaluate and reevaluate code multiple times in places like `propagateLocals(...)`.

So a future port must keep this distinction explicit:

- the interpreter may know more than the final IR emitter is allowed to print.

## 10. This follow-up closes a real major-gap fallback inside the existing dossier

The original dossier was already worth keeping, but it still compressed too many critical details into one sentence about `LazyLocalGraph` propagation.

After this follow-up, the living docs should explicitly teach:

- the set/get worklist topology,
- fallthrough-value analysis,
- subtype filtering for propagated set values,
- entry-default handling and nondefaultable-local bailout,
- exact all-reaching-sets consensus for gets,
- the one-extra-walk stopping rule,
- and the temporary heap-cache rule used by partial-select precompute.

That is enough to count as closing a genuine source-backed teaching gap rather than merely restyling a page.

## Living-doc consequences

This follow-up supports:

- adding one dedicated living page focused on the local worklist / fallthrough / merge-consensus mechanics,
- refreshing the `precompute-propagate` landing page and strategy page to point at that page,
- expanding the implementation/test map to mention `precompute-propagate_all-features.wast` explicitly,
- and updating shared tracker/index/log pages so future recursive threads do not treat this exact `precompute-propagate` gap as still open.

## Source URLs

- Binaryen `version_129` `Precompute.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` `local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- Binaryen `version_129` `precompute-propagate-partial.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
- Binaryen `version_129` `precompute-propagate_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>
