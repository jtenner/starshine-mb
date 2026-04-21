# Binaryen `propagate-globals-globally` deepening research

Date: 2026-04-21
Status: source-backed major-gap follow-up
Pass: `propagate-globals-globally`
Local registry status: `boundary-only` in `src/passes/optimize.mbt`
Prior dossier note: `0162-2026-04-21-propagate-globals-globally-binaryen-research.md`

## 1. Why this pass was still an eligible campaign target

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/propagate-globals-globally/` folder

The tracker no longer had any obvious `none` targets, so this thread needed a justified **major-gap fallback**.

`propagate-globals-globally` qualified because the existing dossier still had a real source-structure error and a real teaching gap:

1. it incorrectly claimed the core implementation lived in `src/passes/PropagateGlobals.cpp`
2. the actual `version_129` implementation is a **small sibling inside `src/passes/SimplifyGlobals.cpp`**
3. the existing pages therefore blurred the real relation between this pass and `simplify-globals*`
4. they also underexplained the exact constant-scope rules (`canHandleAsGlobal`, `allInputsConstant`, reverse global scan, and active data/elem offset rewriting)
5. `agent-todo.md` still has **no dedicated `propagate-globals-globally` slice**

So this is not a random refresh. It closes a concrete source-backed gap in an existing dossier.

## 2. Source inventory reviewed for this follow-up

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md`
- `docs/wiki/raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md`
- `docs/wiki/raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`
- `docs/wiki/raw/research/0124-2026-04-20-string-gathering-binaryen-research.md`

### Official Binaryen `version_129` sources

- `src/passes/SimplifyGlobals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `test/lit/passes/propagate-globals-globally.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
- Binaryen `version_129` release page
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- current `main` spot check of the same source file
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>

## 3. Main correction

The old folder's biggest mistake was structural:

- **there is no `src/passes/PropagateGlobals.cpp` in Binaryen `version_129`**
- the public pass `propagate-globals-globally` is implemented inside **`src/passes/SimplifyGlobals.cpp`**
- the public registration in `pass.cpp` constructs `PropagateGlobals` with `optimize = false`
- the same source file also owns the broader `simplify-globals` and `simplify-globals-optimizing` family

That means the most important teaching fact is not merely "this is smaller than simplify-globals".
It is stronger:

- this pass is a **shared-engine sibling** of `simplify-globals*`, with the function-walking half intentionally disabled

That shared-engine fact is what future Starshine work must preserve.

## 4. The pass in one paragraph

Binaryen `propagate-globals-globally` is a late **module pass** that computes a small map of startup-known global expressions, substitutes those known expressions into other startup-safe global users, and then rewrites only module-level places that are evaluated during startup: defined global initializers plus active data and active element offsets. It does not walk ordinary function bodies because its constructor uses `optimize = false`, so the larger `simplify-globals*` code-level propagation and cleanup logic never runs.

## 5. Public registration and sibling identity

`pass.cpp` registers:

- `propagate-globals-globally`
- `simplify-globals`
- `simplify-globals-optimizing`

The important source-backed split is that `propagate-globals-globally` is not a separate algorithm file. It is a different constructor mode of the same `PropagateGlobals` pass class.

That means the clean family picture is:

- `propagate-globals-globally` = startup-only shared-engine mode
- `simplify-globals` = broader shared-engine mode with function walking and cleanup
- `simplify-globals-optimizing` = same broader mode plus the nested rerun story documented elsewhere

## 6. Real implementation structure in `SimplifyGlobals.cpp`

The reviewed `version_129` source defines a `PropagateGlobals` pass class with the key field:

- `bool optimize`

That field is the entire family split.

### 6.1 Startup-safe expression scope: `canHandleAsGlobal`

The pass has a helper that decides whether an expression is safe to treat as a global/startup expression. The accepted surface is intentionally tiny and startup-shaped:

- `Const`
- `GlobalGet`
- unary ops whose child is startup-safe
- binary ops whose children are startup-safe
- `Select` whose three inputs are startup-safe
- string builtins such as `StringConst`, `StringMeasure`, `StringConcat`, `StringEq`, `StringWTF16Get`, `StringSliceWTF`, and `StringNewWTF16Array`

Anything else is rejected.

This is a key beginner correction:

- the pass is **not** limited to direct `global.get` replacement
- but it is also **not** a general startup-expression evaluator over every IR node

It owns a curated "global-safe" expression subset.

### 6.2 Constant discovery: `allInputsConstant`

A second helper asks whether every `GlobalGet` inside one of those startup-safe expressions already refers to a known constant expression in the current map.

If yes, Binaryen can rebuild the whole expression with those uses substituted and record the result as a new known startup value.

So the pass grows knowledge in the form:

- known global name -> replacement expression

not merely:

- known global name -> raw `Const`

That matters because expressions like arithmetic or string operations over known startup globals can become known too.

### 6.3 Substitution engine: `GlobalUseModifier` and `replaceUses`

Once Binaryen knows that some globals map to startup-known expressions, it uses a tiny postwalk rewriter to replace `global.get $g` with a copy of the recorded expression.

This is another important clarification:

- the pass does **not** evaluate the expression directly everywhere by hand
- it first substitutes known uses, then relies on the startup-safety and all-inputs-constant checks to decide whether the surrounding expression is itself now known

### 6.4 Reverse scan over defined globals

The startup-global phase iterates defined globals in reverse order, tries to substitute already-known globals into each initializer, and records the initializer if it now has all-constant inputs.

The source-backed durable point is not a particular theorem about wasm declaration rules; it is the concrete implementation fact:

- Binaryen performs a reverse pass over defined globals while growing the constants map

A future port should preserve that order unless it can justify an equivalent fixed point explicitly.

### 6.5 Module-level rewrite targets beyond globals

After building the constants map, Binaryen rewrites more than just globals.

It walks:

- all **active data segments** with offsets
- all **active element segments** with offsets

and substitutes known startup globals there too.

This is the most important visible shape the old dossier underexplained.

The pass is therefore best taught as:

- startup global propagation into **global initializers and active segment offsets**

not just:

- global-to-global propagation

### 6.6 The optimize gate

At the end of `run(Module*)`, the pass checks `optimize`.

- when `optimize` is `false`, the pass stops after the startup/module-level propagation work
- when `optimize` is `true`, Binaryen continues into the broader `simplify-globals` family logic, including function walking and the later cleanup surfaces already documented elsewhere

This one flag is the cleanest source-backed explanation of the family split.

## 7. What the pass really rewrites

## Positive family 1: direct global chains

If a startup-safe global initializer reads another global whose startup value is known, Binaryen substitutes that expression.

Conceptually:

```wat
(global $base i32 (i32.const 8))
(global $g i32 (global.get $base))
```

becomes closer to:

```wat
(global $base i32 (i32.const 8))
(global $g i32 (i32.const 8))
```

## Positive family 2: expression chains, not just direct aliases

Because the accepted startup-safe surface includes unary/binary/select/string nodes, Binaryen can propagate through larger startup expressions.

Conceptually:

```wat
(global $base i32 (i32.const 8))
(global $g i32 (i32.add (global.get $base) (i32.const 4)))
```

can become closer to:

```wat
(global $base i32 (i32.const 8))
(global $g i32 (i32.const 12))
```

or at minimum a rewritten expression with the `global.get` removed, depending on later folding.

The important contract is the substitution surface, not the exact final printer output.

## Positive family 3: active data offsets

Conceptually:

```wat
(global $off i32 (i32.const 8))
(data (global.get $off) "abc")
```

can become:

```wat
(global $off i32 (i32.const 8))
(data (i32.const 8) "abc")
```

## Positive family 4: active element offsets

The same startup-offset logic applies to active elem segments.

Conceptually:

```wat
(global $off i32 (i32.const 1))
(elem (table $t) (global.get $off) func $f)
```

can become closer to:

```wat
(global $off i32 (i32.const 1))
(elem (table $t) (i32.const 1) func $f)
```

## Positive family 5: startup-safe string expressions

Because the accepted scope includes several `string.*` nodes, the pass can simplify startup string expressions too.

That is why it is a real neighbor of `string-gathering`, not just a generic scalar-global helper.

## 8. What it deliberately leaves alone

## Negative family 1: ordinary function bodies

This is the clearest family split.

If the same `global.get` appears in a function body, `propagate-globals-globally` does not own it because `optimize = false` prevents the broader code-walking simplify-globals path from running.

## Negative family 2: non-global-safe startup expressions

If an initializer or offset contains an expression outside the curated startup-safe subset, this pass stops.

That means the pass is not a generic evaluator for all Binaryen IR that happens to appear in a global-ish position.

## Negative family 3: broader simplify-globals cleanup

This pass does not itself own:

- practical-immutability discovery in function code
- `read-only-to-write` removal
- dead global-set cleanup in code
- runtime `global.get` propagation
- the optimizing sibling's nested rerun behavior

Those belong to the broader siblings in the same source file.

## 9. Important interactions with neighboring passes

## With `simplify-globals`

The most important relationship is no longer just "neighboring pass".
It is:

- **same engine, broader mode**

So a future Starshine port can likely share helper machinery, but it must preserve the smaller startup-only stop point for this specific public pass.

## With `simplify-globals-optimizing`

Same story, except the optimizing sibling also owns the nested rerun contract after changed functions.

## With `string-gathering`

Because the startup-safe surface includes string operations, this pass can expose cleaner string-bearing startup expressions before later string canonicalization or gathering passes.

## With `reorder-globals`

By simplifying global initializers and active offsets, it can also make top-level dependency structure easier for later layout passes to reason about, even though it does not reorder declarations itself.

## 10. What the official test proves

The shipped `propagate-globals-globally.wast` matters because it proves Binaryen considers this a distinct public behavior surface, not merely an internal helper mode.

The durable test-backed lessons are:

- startup global chains are a real rewrite target
- active segment offsets are a real rewrite target
- the pass is intentionally smaller than full `simplify-globals*`

## 11. Current-main drift check

A spot check against current `main` found the same family structure still in place on the reviewed surface:

- `propagate-globals-globally` is still registered publicly
- the implementation is still in `SimplifyGlobals.cpp`
- the key shared-engine split still hinges on the `optimize` flag

So the correction here is not only relevant to the old tag; it still matches the current upstream shape on the reviewed surfaces.

## 12. What a future Starshine port must preserve

A correct port should preserve all of these facts together:

1. this is a **module pass**, not a hot function pass
2. it is a **shared-engine sibling** of `simplify-globals*`
3. its startup-safe surface is a curated subset, not arbitrary IR
4. it records and substitutes **known startup expressions**, not only direct constants
5. it rewrites **defined global initializers plus active data/elem offsets**
6. it stops before function-body propagation when the public pass is `propagate-globals-globally`

## 13. Why this follow-up improves the wiki

This deepening closes the biggest remaining teaching gap in the folder.

Before this follow-up, the dossier got the broad idea right but the most important implementation fact wrong:

- it separated this pass too far from `simplify-globals*`

After this follow-up, the wiki can now teach the pass accurately as:

- a small public startup-only mode of the same Binaryen engine that later powers the broader global simplifier family

That is much more useful for a future Starshine port.

## 14. Open questions and explicit uncertainty

### Strong conclusions

These are strongly supported by the reviewed sources:

- the public pass exists in `pass.cpp`
- its implementation lives in `SimplifyGlobals.cpp`, not a standalone `PropagateGlobals.cpp`
- the pass uses a startup-safe expression filter, constant-input check, and substitution helper
- it rewrites defined globals plus active data/elem offsets
- the shared-engine family split is controlled by `optimize`

### Inferences kept explicit

These summaries are still partly inferential and should stay labeled that way:

- the exact motivation for the reverse global scan is clearer as an implementation fact than as a formal semantic proof in this note
- the exact printed after-shape in examples may depend on later folding and printer details, so the WAT examples are conceptual

## 15. Final recommendation

Treat `propagate-globals-globally` as a **major-gap-closed dossier** now.

Future recursive campaign threads should not revisit this folder as if it still lacked a real source-backed implementation map unless they can point to a new concrete gap beyond the one closed here.

## Sources

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md`
- `docs/wiki/raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md`
- `docs/wiki/raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`
- `docs/wiki/raw/research/0124-2026-04-20-string-gathering-binaryen-research.md`

### Official Binaryen sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
- <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>
