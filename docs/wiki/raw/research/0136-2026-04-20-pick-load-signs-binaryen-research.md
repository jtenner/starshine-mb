# Pick-Load-Signs Binaryen Research

## Scope

- Deepen the existing `pick-load-signs` landing page into a real Binaryen dossier.
- Use Binaryen `version_129` as the main semantic oracle.
- Explain the actual implementation structure in beginner-friendly language.
- Record the important correction to the older local port note: upstream `pick-load-signs` is narrower than that earlier note implied.
- Keep the result useful for future Starshine parity work in the early memory/sign-cleanup cluster.

## Why this pass was the right target now

- The updated tracker named `pick-load-signs` as the strongest remaining implemented landing-page target after `heap2local` was deepened.
- `pick-load-signs` is already implemented locally, but the wiki surface was still just:
  - a short landing page
  - a parity note
- It sits in an important early cleanup neighborhood in the canonical no-DWARF path:
  - `... -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> precompute ...`
- The saved generated-artifact `-O4z` audit already shows `pick-load-signs` as an implemented, successful slot rather than an open corruption family, so the durable work here is understanding and documentation rather than emergency triage.

## Local source material audited first

Repo docs and trackers:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- existing living pages under `docs/wiki/binaryen/passes/pick-load-signs/`
- archived note `docs/wiki/raw/research/0069-2026-03-26-pick-load-signs.md`
- smoke rerun note `docs/wiki/raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`
- saved generated-artifact audit `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- saved Binaryen debug log `.artifacts/o4z-wasm-opt-debug.log`

Current in-tree Starshine implementation surfaces:

- `src/passes/pick_load_signs.mbt`
- `src/passes/pick_load_signs_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

Important local backlog note:

- `agent-todo.md` currently has **no dedicated `PLS` slice**.
- The relevant local backlog surface is indirect:
  - the canonical no-DWARF path entry for `pick-load-signs`
  - the shared post-SSA hot-prefix notes that already mention the `... -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> simplify-locals` cluster
  - the existing pass/cmd tests and parity notes for the implemented pass

## Official upstream source-of-truth files

Primary `version_129` sources:

- `src/passes/PickLoadSigns.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/ir/properties.h`
- dedicated test: `test/lit/passes/pick-load-signs_sign-ext.wast`

Helpful neighboring official test surface:

- `test/lit/passes/optimize-instructions-sign_ext.wast`

That neighboring file matters because it helps show which sign-extension cleanup families live in `optimize-instructions` rather than in `pick-load-signs` itself.

## Beginner summary

Binaryen `pick-load-signs` is a very small pass.

A better summary than the short registry description is:

1. find a narrow non-atomic integer load written into a local by an exact `local.set`,
2. inspect every `local.get` use of that local in its immediate AST context,
3. recognize only a few exact sign/zero-extension shapes,
4. and if **every** use is one of those recognized shapes at the same width, flip the load opcode to the signed or unsigned variant that removes the most follow-up extension work.

That is much smaller than a generic “integer load canonicalization” pass.

## Biggest beginner-facing correction

The easiest wrong mental model is:

- `pick-load-signs` handles all narrow integer load signedness cleanup, including i64 extension families

A more accurate model for Binaryen `version_129` is:

- `pick-load-signs` is a tiny AST-context-based rewrite over exact local-written narrow loads, and its actual recognized usage helpers here are effectively **i32-only**.

### Why the `i32-only` claim matters

This is an inference directly from the official source, not from a prose comment.

- `PickLoadSigns.cpp` only asks `Properties::getZeroExtValue(...)`, `getZeroExtBits(...)`, `getSignExtValue(...)`, and `getSignExtBits(...)` about a local use.
- In `properties.h`, those helpers immediately bail out unless `curr->type == Type::i32`.
- `PickLoadSigns.cpp` does not add its own i64-specific fallback logic.

So although the pass looks like it could conceptually help with `i64.load8_*`, `i64.load16_*`, or `i64.load32_*`, the released upstream implementation here does not actually recognize i64 sign/zero-extension evidence in this pass.

That is one of the most important durable findings in this research pass.

## Scheduler placement

### Top-level no-DWARF `-O` / `-Os`

From `pass.cpp` and the repo's canonical pathway page:

- `pick-load-signs` runs in the early function cleanup cluster.
- In the no-DWARF `-O` / `-Os` function path it sits after:
  - `optimize-instructions`
  - `heap-store-optimization`
- and before:
  - `precompute`

The relevant gate in `pass.cpp` is:

- run `pick-load-signs` when `optimizeLevel >= 2` **or** `shrinkLevel >= 2`

That placement matters because:

- earlier passes have already simplified obvious instruction and heap-store shapes,
- `pick-load-signs` then canonicalizes a very narrow memory-to-local sign choice,
- and `precompute` / later cleanup can benefit from the simplified opcode choice.

### Nested reruns

`opt-utils.h` shows that `optimizeAfterInlining(...)` reruns the default function-optimization stack after inlining-related passes.
That means `pick-load-signs` is not just a top-level one-shot optimization.

The saved local debug log confirms that directly:

- `.artifacts/o4z-wasm-opt-debug.log` contains `18` `running pass: pick-load-signs` lines

So future scheduler work must not model this pass as “slot 18 once and done.”

## Actual implementation structure in `PickLoadSigns.cpp`

The file is small enough that its whole structure matters.

### 1. The pass type

Upstream defines:

- `struct PickLoadSigns : public WalkerPass<ExpressionStackWalker<PickLoadSigns>>`

Important consequences:

- it is a function-parallel pass
- it walks ordinary Binaryen AST expressions
- it relies on the expression stack to inspect parent and grandparent context
- it does **not** build a CFG, liveness graph, or local-use graph here

### 2. Per-function state

The pass stores two pieces of per-function state:

- `std::vector<Usage> usages`
  - indexed by local index
- `std::unordered_map<Load*, Index> loads`
  - mapping exact candidate load nodes to the target local index

The `Usage` struct tracks:

- `signedUsages`
- `signedBits`
- `unsignedUsages`
- `unsignedBits`
- `totalUsages`

That is the whole scoring model.

### 3. `doWalkFunction(...)`

The function-level entry does three things:

1. if the module has no memories, return immediately
2. resize the `usages` vector to the function local count
3. walk the function, then call `optimize()`

This is a real semantic short-circuit:

- no memory means no loads
- therefore there can be no candidates

### 4. `visitLocalSet(...)` collects candidates

The candidate side is intentionally narrow.

Upstream records a candidate only when:

- the current node is a `local.set`
- it is **not** a tee
- and the set's value is exactly a `Load`

So the producer contract is:

- exact `local.set(load ...)`
- no `local.tee`
- no “load buried under another value-producing wrapper” matching here

That is one of the pass's simplest but most important shape constraints.

### 5. `visitLocalGet(...)` scores uses

Every `local.get` increments `usage.totalUsages`.
Then the pass inspects up to two ancestor positions using the expression stack:

- `i = 2` => immediate parent
- `i = 3` => grandparent

That is why the file comment says sign- and zero-extension may have:

- one level of nesting
- or two levels of nesting

The pass then asks the official `Properties` helpers whether that ancestor is:

- a recognized zero-extension of this `local.get`
- or a recognized sign-extension of this `local.get`

If yes, it records the width.
If the same family appears later with a different width, it zeroes out the remembered width for that family so the later `optimize()` phase can reject the rewrite.

### 6. The exact recognized shapes come from `properties.h`

This is where the real surface becomes much clearer.

#### `Properties::getSignExtValue(...)`

For this pass, the recognized sign-extension shapes are:

- `i32.extend8_s x`
- `i32.extend16_s x`
- `(i32.shr_s (i32.shl x K) K)` with the same nonzero shift `K`

And the width helper reports:

- `8`
- `16`
- or `32 - K` for the shift pair

#### `Properties::getZeroExtValue(...)`

For this pass, the recognized zero-extension shape is:

- `(i32.and x MASK)` where `MASK` contains a contiguous low-bit mask and `Bits::getMaskedBits(mask) != 0`

And the width helper reports that low-bit width.

#### Important non-shape

There is **no** i64 companion logic in these helpers for this pass path.
That is why the source-backed reading here is effectively i32-only.

## `optimize()` decision rules

The final decision loop is extremely small but semantically important.

For each candidate `(load, localIndex)` pair, upstream refuses to rewrite when any of these hold:

- `usage.totalUsages == 0`
- `signedUsages + unsignedUsages != totalUsages`
  - meaning at least one use was not recognized as a sign/zero-extension family
- signed evidence exists but its width does not equal `load->bytes * 8`
- unsigned evidence exists but its width does not equal `load->bytes * 8`
- the load is atomic

If those checks pass, the pass chooses:

- `signed` if `signedUsages * 2 >= unsignedUsages`
- otherwise `unsigned`

The comment explains the weighting:

- a signed-use shift-pair can remove two shift instructions
- so signed evidence is weighted more heavily than a plain one-for-one vote would suggest

## Important shape consequences

### Any unknown use blocks the rewrite

Because `totalUsages` always increments but signed/unsigned counters only increment for recognized shapes, any other use means:

- `signedUsages + unsignedUsages != totalUsages`

and the candidate is rejected.

This is exactly why the dedicated negative test with `br_if` matters.

### The pass is AST-context-sensitive, not dataflow-smart

It does **not** prove that a local value is “eventually sign-extended somewhere.”
It asks a much stricter question:

- is this exact `local.get` sitting in one of the allowed parent/grandparent shapes right now?

That difference is very important for future ports.

### The decision data is per local, but width checks are per load

The `Usage` record is keyed by local index.
However, the final width guard compares the shared usage-width result against each candidate load's own `bytes * 8`.

So if the same local receives mixed-width narrow loads, the pass does **not** automatically rewrite all of them together.
Only the loads whose width matches the local's all-use evidence can flip.

That is easy to miss on a first read.

## Official test surface

The dedicated upstream lit file is small:

- `pick-load-signs_sign-ext.wast`

It only locks two i32 cases:

1. a negative case where the local's value is also used as a `br_if` carried value, so the load must **not** flip
2. a simple positive case where the local is only fed into `i32.extend8_s`, so the load may flip from `i32.load8_u` to `i32.load8_s`

That dedicated test file is important, but it is also deliberately tiny.

## Why the neighboring `optimize-instructions-sign_ext.wast` file matters

The broader sign-extension cleanup story visible in official tests lives elsewhere.

`optimize-instructions-sign_ext.wast` contains many i32 and i64 cases where Binaryen removes explicit sign-extension operations because the load or input shape already guarantees the needed semantics.

That neighboring file is strong supporting evidence for the source reading here:

- upstream Binaryen absolutely cares about i64 sign-extension cleanup,
- but that broader cleanup does not belong to `pick-load-signs` in `version_129`.
- it belongs mainly to `optimize-instructions`.

## Positive shapes worth teaching

The important upstream positive families are:

- `local.set $x (i32.load8_u ...)` then `i32.extend8_s (local.get $x)`
  - can flip to `i32.load8_s`
- `local.set $x (i32.load16_s ...)` then `(local.get $x) & 65535`
  - can flip to `i32.load16_u`
- `local.set $x (i32.load16_u ...)` then `(local.get $x << 16) >>_s 16`
  - can flip to `i32.load16_s`
- the sign/zero-extension recognizer may sit at the parent or the grandparent of the `local.get`

## Negative shapes worth teaching

The important upstream bailout families are:

- `local.tee` producer instead of plain `local.set`
- any use in an unrecognized operation such as compare/call/branch/value merge
- the official `br_if` value-use case in the shipped test
- mixed-width evidence for one sign family
- a usage width that does not match the load width
- atomic loads
- all analogous i64 shapes in this pass, because the official recognition helpers here do not model them

## Important correction to the older repo note

The archived local port note `0069-2026-03-26-pick-load-signs.md` was useful as implementation history, but a fresh `version_129` source review corrects one part of it:

- the old note treated i64 extension evidence as part of Binaryen `pick-load-signs` behavior
- the official upstream source for `version_129` does not support that reading in this pass

That older note should still be kept as local port history.
But this new dossier should be treated as the better source for upstream Binaryen semantics.

## Current-main freshness check

A narrow 2026-04-20 direct comparison found:

- `src/passes/PickLoadSigns.cpp` is identical between `version_129` and current `main`
- `test/lit/passes/pick-load-signs_sign-ext.wast` is also identical between `version_129` and current `main`

So unlike some other passes in this campaign, there is no visible current-main drift story to record here.

## Implications for Starshine

The in-tree Starshine implementation is broader and structurally different:

- it is a HOT/use-def pass, not an AST expression-stack walker
- it explicitly recognizes i64 extend, mask, and shift-pair families
- it adds raw candidate-scan fast skips and aggregated trace reasons

That is not automatically wrong.
But it is a real scope difference from official Binaryen `version_129`.

So future Starshine parity work should keep these rules explicit:

- if strict upstream parity is the goal, i64 support in local `pick-load-signs` should be treated as a documented divergence until it is either narrowed or shown to match upstream behavior through another pass sequence
- keep the exact non-tee `local.set(load ...)` producer contract explicit
- keep the all-uses-recognized rule explicit
- keep atomic-load exclusion explicit
- keep the signed-side weighting rule explicit
- keep the no-memory fast skip and raw candidate screening, even though they are local infrastructure rather than upstream AST logic

## Most important durable takeaways

- Upstream `pick-load-signs` is far smaller than its name suggests.
- The real official helper dependency is `properties.h`, and that makes the pass effectively i32-only in `version_129`.
- The pass is AST-context-sensitive, not CFG- or use-def-driven.
- Any unrecognized use blocks the rewrite.
- The signed side wins ties because it can save more follow-up instructions.
- The dedicated official test surface is intentionally tiny, so the source matters more than the test count here.
- Current `main` matches `version_129` exactly for the owning source file and dedicated lit test.
