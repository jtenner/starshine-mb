# Binaryen `gufa-cast-all` research

_Date:_ 2026-04-21  
_Status:_ source-backed upstream-only dossier expansion  
_Pass:_ `gufa-cast-all`  
_Local registry status:_ boundary-only (`src/passes/optimize.mbt`)  
_Canonical upstream oracle:_ Binaryen `version_129`

## 1. Why this pass is an eligible campaign target now

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- the existing `gufa/` and `gufa-optimizing/` dossiers

The main no-DWARF parity queue and the first tracker-expansion wave are already dossier-covered.
`gufa-optimizing` was closed in the immediately previous thread.
The local registry still exposes another real public sibling, `gufa-cast-all`, but the tracker did not yet give it its own row or folder.
That makes `gufa-cast-all` a justified next expansion because:

1. it is already named in the local boundary-only registry,
2. upstream Binaryen publishes it as a separate public pass,
3. upstream ships a dedicated `gufa-cast-all.wast` lit file,
4. the existing `gufa` family docs mention it, but do not yet give beginners a dedicated canonical landing page for its exact contract.

## 2. Backlog / local-project status

`agent-todo.md` currently has **no dedicated `gufa-cast-all` slice**.
So this note is documentation-first research, not execution against an existing local implementation slice.

## 3. Main answer in one paragraph

Binaryen `gufa-cast-all` is **not** a different whole-program inference algorithm from plain `gufa`, and it is **not** the cleanup-owning sibling `gufa-optimizing`.
It is the same `GUFA.cpp` engine run with `optimizing = false` and `castAll = true`.
That means Binaryen still builds the same module-wide `ContentOracle`, still performs the same core GUFA rewrites (`unreachable`, exact value replacement, `ref.eq`, `ref.test`, and existing `ref.cast` refinement), but then does one extra post-refinalize walk that inserts **new explicit `ref.cast` instructions** when the oracle knows a narrower castable reference type than the current IR type.
It does **not** run the nested `dce` + `vacuum` cleanup owned by `gufa-optimizing`.

## 4. Primary upstream sources consulted

### Official release / implementation sources

- Binaryen `version_129` release page  
  <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `src/passes/pass.cpp`  
  <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/GUFA.cpp`  
  <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- `src/ir/possible-contents.h`  
  <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- `test/lit/passes/gufa-cast-all.wast`  
  <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
- neighboring comparison files:
  - `test/lit/passes/gufa.wast`  
    <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - `test/lit/passes/gufa-optimizing.wast`  
    <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>

### Current-main freshness spot checks

I also spot-checked the same public surfaces on `main`:

- `src/passes/pass.cpp`  
  <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/passes/GUFA.cpp`  
  <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
- `test/lit/passes/gufa-cast-all.wast`  
  <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa-cast-all.wast>

On the reviewed public surfaces, I did not find a source-backed reason to treat `version_129` as stale for this pass.
That is an inference from the reviewed current-main spot checks, not a line-by-line proof of complete file identity.

## 5. Registration and scheduler facts

## Public pass identity

`pass.cpp` registers `gufa`, `gufa-cast-all`, and `gufa-optimizing` as distinct public passes.
That means `gufa-cast-all` is not just a hidden flag on plain `gufa`; it is part of Binaryen's real public pass surface.

## Default-preset fact

Like the broader GUFA family dossier already notes, this pass is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path and does not appear in the saved generated-artifact `-O4z` skip queue.
So this thread is explicitly working in the tracker-expansion space, not in the original parity queue.

## 6. Exact implementation shape in `GUFA.cpp`

The key factories at the bottom of `GUFA.cpp` are the simplest exact oracle for the family split:

- `createGUFAPass()` => `new GUFAPass(false, false)`
- `createGUFAOptimizingPass()` => `new GUFAPass(true, false)`
- `createGUFACastAllPass()` => `new GUFAPass(false, true)`

That single split is the core of the dossier:

- plain `gufa` = no cleanup rerun, no new-cast insertion
- `gufa-optimizing` = cleanup rerun, no new-cast insertion
- `gufa-cast-all` = new-cast insertion, no cleanup rerun

## 7. Shared analysis: still `ContentOracle`

`gufa-cast-all` still depends on the same whole-program `ContentOracle` from `possible-contents.h`.
The main result kinds remain:

- `None`
- `Literal`
- `GlobalInfo`
- `ConeType`
- `Many`

So the sibling split is **not** in the analysis lattice.
The split happens in the post-rewrite behavior after the common GUFA reasoning has already run.

## 8. Shared first-phase rewrites: still plain GUFA logic

Before the sibling-specific step, `gufa-cast-all` still inherits plain GUFA's core rewrite surface:

- replace impossible traffic with `unreachable`
- replace a location with one known exact value when Binaryen can emit that value legally
- simplify `ref.eq` when the two possible-content sets cannot intersect
- simplify `ref.test` when the operand contents are provably inside or outside the target cone
- sharpen an **existing** `ref.cast` when the oracle knows a narrower target

This matters because the dedicated sibling is easy to misread as “the variant that does all the casts.”
That is incomplete.
It first does ordinary GUFA, and only then adds **new** casts in places where plain GUFA would stop.

## 9. The real sibling-specific phase: `addNewCasts`

The decisive implementation fact is the `visitFunction` ordering in `GUFA.cpp`:

1. run the shared GUFA visitor
2. if anything changed, run `ReFinalize()`
3. if `castAll`, run `addNewCasts(func)`
4. if anything changed, run `EHUtils::handleBlockNestedPops(...)`
5. if `optimizing`, run nested `dce` then `vacuum`

For `gufa-cast-all`, that means:

- `optimizing = false`
- `castAll = true`

So this sibling owns **step 3** and deliberately skips **step 5**.

## 10. What `addNewCasts` is actually trying to do

The second walk is not generic cast insertion.
It is a narrow, source-backed attempt to make more precise reference information explicit in the IR.

The reviewed `GUFA.cpp` logic and the dedicated lit file together show this contract:

- only consider expressions whose current type is a reference type that can actually be cast
- ask the oracle for the expression's possible contents
- only proceed when those contents describe a **narrower cone** than the current static type
- only insert a cast when the narrowed type is still valid to express as a cast target
- relax exactness when the relevant descriptor/custom-descriptor feature support is unavailable
- avoid cases that would be invalid, uncastable, or would obviously not improve the direct IR contract

A beginner-friendly summary is:

- plain `gufa` can often *know* more than it can directly rewrite,
- `gufa-cast-all` turns some of that extra knowledge into explicit `ref.cast` nodes.

## 11. Important exactness rule

The existing `gufa` dossier already surfaced the family's exactness sensitivity, and it matters even more here.
The reviewed sources show that exact inferred types may need to be downgraded to inexact ones when the custom-descriptor feature support is not available.

So `gufa-cast-all` is **not** “insert the most precise imaginable cast.”
It is “insert the most precise cast that this module's feature/legality surface can actually represent.”

That is a future-port invariant.

## 12. What the dedicated lit file teaches

The strongest teaching source is `test/lit/passes/gufa-cast-all.wast`.
That file exists precisely because the sibling has a real public contract that would be easy to lose inside the broader `gufa` folder.

The lit file proves several durable points:

### A. The pass can add a new cast where plain GUFA would leave the expression alone

This is the headline behavior.
The oracle may know that a value is really in a narrower subtype cone, but plain GUFA may not have a direct replacement available.
`gufa-cast-all` can emit a fresh `ref.cast` to make that knowledge explicit.

### B. Exact versus inexact cast targets are feature-sensitive

The test surface exercises exactness-sensitive families, confirming that the pass cannot blindly emit exact casts whenever the inference engine knows one exact subtype.
Legality still depends on feature support.

### C. Castability boundaries are real

The reviewed test names and source comments show that some candidate expressions remain unchanged even when the oracle knows more.
That is not a bug; it is part of the contract.
Some shapes are not valid targets for the pass's new-cast insertion step.

### D. This sibling is different from `gufa-optimizing`

The dedicated optimizing lit file proves cleanup ownership.
The dedicated cast-all lit file proves cast insertion ownership.
Together they make the family split crisp.

## 13. Positive IR / WAT shapes worth teaching

These are the durable source-backed shape families a beginner-to-intermediate implementer should understand.

### Positive shape 1: a reference value is known to live in a tighter subtype cone

Conceptually:

```wat
(local.get $x) ;; static type is broad, actual contents are narrower
```

After `gufa-cast-all`, conceptually:

```wat
(ref.cast (ref $Narrower)
  (local.get $x)
)
```

Teaching point:

- the pass is materializing knowledge the oracle already had,
- not deriving new knowledge from the cast itself.

### Positive shape 2: plain GUFA sharpens an existing cast, then cast-all can still add new ones elsewhere

The family already knows how to refine an existing cast target when the oracle proves a narrower result.
`gufa-cast-all` extends the visible surface by adding casts in places where no cast was present before.

Teaching point:

- “refine existing cast” and “insert new cast” are different rewrite families.

### Positive shape 3: the inserted cast creates downstream opportunities

This is partly an inference from the pass design and partly stated intent from the sibling's purpose.
The new explicit cast can make later GC/cast-oriented passes see sharper information.
That is why Binaryen publishes this as its own mode instead of folding it invisibly into plain `gufa`.

## 14. Negative / preserved / bailout shapes

### Negative shape 1: no nested `dce` + `vacuum`

This sibling does **not** own the cleanup rerun.
If the pass adds new IR wrapper structure that later cleanup could simplify, that cleanup is not part of `gufa-cast-all` itself.
That belongs to `gufa-optimizing`.

### Negative shape 2: no new whole-program analysis

The pass does not change the `ContentOracle` or add a second inference lattice.
Its new behavior is purely in how it uses the already-known cone information.

### Negative shape 3: no arbitrary cast insertion everywhere the oracle knows more

The insertion step is filtered by castability, legality, type precision rules, and exactness constraints.
The lit file's preserved cases matter because they teach that some “obvious” casts still should not be emitted.

### Negative shape 4: ordered / tricky / unsupported families stay conservative

The broader GUFA family already avoids certain rewrite families for safety and legality reasons.
`gufa-cast-all` inherits those boundaries before the new-cast step even begins.

## 15. Helper dependencies and future-port implications

A future Starshine port needs more than a one-line registry stub.
The source-backed dependency cluster includes:

- `ContentOracle` / `PossibleContents`
- the common GUFA visitor logic in `GUFA.cpp`
- `ReFinalize`
- `EHUtils::handleBlockNestedPops`
- whatever local type-feature utilities Binaryen uses to decide whether an exact or inexact cast target is expressible

The most important preservation rules are:

1. keep the same shared analysis as plain `gufa`
2. keep the same shared core rewrite surface as plain `gufa`
3. run refinalization before the cast-insertion walk
4. make new-cast insertion a separate pass phase, not an ad hoc side effect of the main visitor
5. preserve feature-sensitive exactness downgrades
6. do **not** silently add the optimizing sibling's `dce` + `vacuum` rerun
7. keep the split from both `gufa` and `gufa-optimizing` explicit in the public registry and docs

## 16. Easy misconceptions this dossier should prevent

### Misconception 1: “`gufa-cast-all` is just more aggressive GUFA”

Too vague.
The better statement is:

- it is the public GUFA sibling that **adds new explicit `ref.cast` nodes** after the common rewrite phase.

### Misconception 2: “`gufa-cast-all` is the one that cleans up GUFA's extra wrappers”

Wrong sibling.
That is `gufa-optimizing`.

### Misconception 3: “If the oracle knows the exact subtype, the pass should always emit an exact cast”

Not necessarily.
The reviewed sources and lit surface show that exactness is feature-sensitive and may need to be downgraded.

## 17. Durable conclusions

1. `gufa-cast-all` is a real public Binaryen pass, not just a hidden flag.
2. It is correctly modeled as a separate sibling of `gufa` and `gufa-optimizing`.
3. The engine is still the shared `GUFA.cpp` + `ContentOracle` family.
4. The exact split is `optimizing = false`, `castAll = true`.
5. Its distinctive contract is a post-refinalize **new-cast insertion walk**.
6. It does not own the nested `dce` + `vacuum` cleanup contract.
7. The dedicated `gufa-cast-all.wast` lit file is important because it teaches cast insertion, exactness limits, and preserved no-op cases that are easy to lose if the sibling is treated only as a footnote.

## 18. Concrete docs work this research note should drive

- add a dedicated `docs/wiki/binaryen/passes/gufa-cast-all/` folder
- add at least:
  - `index.md`
  - `binaryen-strategy.md`
  - `implementation-structure-and-tests.md`
  - `cast-insertion-exactness-and-boundaries.md`
  - `wat-shapes.md`
- update `docs/wiki/binaryen/passes/tracker.md`
- update `docs/wiki/binaryen/passes/index.md`
- update `docs/wiki/index.md`
- append a `docs/wiki/log.md` entry

## 19. Open questions / uncertainty

- I did not perform a full line-by-line diff of all reviewed `version_129` and `main` GUFA-family files. The claim that `version_129` remains a stable teaching oracle is therefore a reviewed-surface inference, not a complete proof of file identity.
- The exact internal helper names used by the cast-insertion walk beyond the public `addNewCasts` phase are less important than the stable semantic contract above, and I have kept this note focused on the externally meaningful behavior.
