# Binaryen `const-hoisting` research

Date: 2026-04-21
Status: source-backed upstream-only dossier seed
Pass: `const-hoisting`
Local registry status: `removed` in `src/passes/optimize.mbt`
Binaryen release reviewed: `version_129`
Current-main drift check: reviewed on 2026-04-21; `src/passes/ConstHoisting.cpp`, `test/lit/passes/const-hoisting.wast`, and the `pass.cpp` registration are unchanged on `main`

## Why this note exists

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only wave are already dossier-covered.
That means this thread had to either justify a major-gap fallback or add another genuinely eligible upstream-only registry pass.

`const-hoisting` is a good source-backed expansion target because:

- it is still explicitly named in the local removed-pass registry in `src/passes/optimize.mbt`
- it is a real public Binaryen pass in `src/passes/pass.cpp`
- it has a dedicated upstream implementation file and dedicated lit file
- it sits near already-documented size-oriented cleanup passes like `optimize-added-constants*`, `precompute*`, `simplify-locals*`, and `merge-similar-functions`, but it teaches a different idea: **binary encoding size economics for repeated literal constants**
- `agent-todo.md` currently has **no dedicated `const-hoisting` slice**

## Executive summary

Binaryen `const-hoisting` is a tiny function-parallel size pass that finds repeated `Const` expressions with the same literal value inside one function, decides whether replacing them with a temp local would shrink the binary encoding, and if so:

1. creates a fresh local of the constant's type
2. inserts a single `local.set temp (const ...)` into a synthesized function-entry prelude block
3. rewrites every repeated constant use site to `local.get temp`
4. leaves later cleanup to nearby passes like `merge-blocks`

The pass is **not**:

- generic constant propagation
- value numbering
- arithmetic simplification
- cross-function pooling
- global-constant hoisting
- a runtime-performance optimizer

Its real job is much narrower:

- **trade repeated large literal encodings for one literal plus many cheap `local.get`s**

## Source files reviewed

### Primary implementation

- `src/passes/ConstHoisting.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/const-hoisting.wast`

### Important helper dependencies

- `support/insert_ordered.h`
  - stable first-seen ordering for literal groups
- `wasm-binary.h`
  - LEB byte-size measurement helpers used to estimate encoded constant size
- `wasm-builder.h`
  - fresh local creation plus emitted `local.set` / `local.get` / `block` / `sequence` nodes
- `pass.h`
  - the pass is a `WalkerPass<PostWalker<ConstHoisting>>` and marks itself function-parallel

## Public registration and naming

`pass.cpp` registers:

- `const-hoisting`
- summary text: `hoist repeated constants to a local (necessary for the register allocator in some cases)`

That registration matters because the local Starshine registry still lists the name but has no dedicated living dossier yet.

## What the implementation actually does

## 1. Collect repeated literal values

The pass has one core data structure:

- `InsertOrderedMap<Literal, std::vector<Expression**>> uses`

During `visitConst(Const* curr)` it records:

- the literal value itself as the grouping key
- the `Expression**` pointer to each concrete use site

Important consequence:

- grouping is by **literal identity**, not by “equivalent computation”
- only already-materialized `Const` nodes count
- two different ASTs that both evaluate to the same value do not matter unless they have already become `Const`

So the pass depends heavily on earlier passes having already folded things into literal constants.
That is why it pairs naturally with `precompute`, but it is not a substitute for `precompute`.

## 2. Decide whether hoisting is worth it

The profitability rule is the heart of the pass.
Binaryen first requires:

- at least `MIN_USES = 2`

But `2` is only a coarse floor.
The real decision is byte-based.

### Encoded constant size model

For each literal, the pass computes `size`:

- `i32`: signed LEB width of the encoded value
- `i64`: signed LEB width of the encoded value
- `f32`: fixed `4` bytes
- `f64`: fixed `8` bytes
- `v128`: not implemented, never hoisted
- `none` / `unreachable`: impossible here

Then it compares:

- `before = num * size`
- `after = size + 2 /* local.set */ + 2 * num /* local.get per use */`

Hoist only if:

- `after < before`

So Binaryen is explicitly modeling:

- one literal still needs to exist
- one `local.set` costs bytes too
- each rewritten use becomes a short `local.get`

This is why the pass name is easy to misunderstand.
It is not blindly hoisting repeated constants; it is doing a tiny **binary-size algebra check**.

## 3. The useful thresholds

The source comment rewrites the algebra as:

- `size > 2(1+num)/(num-1)`
- equivalently `num > (size+2)/(size-2)`

Practical thresholds visible in the upstream lit file:

- `1`-byte constants: never worth hoisting
- `2`-byte constants: never worth hoisting
- `3`-byte constants: need `6` uses
- `4`-byte constants: need `4` uses
- `8`-byte constants: need `2` uses

That explains the test cases exactly:

- `i32.const 8192` or `-8193` are `3`-byte signed LEBs, so they need `6` uses
- `i32.const 1048576` or `-1048577` are `4`-byte signed LEBs, so they need `4` uses
- `f32.const 0` is always `4` bytes, so it needs `4` uses
- `f64.const 0` is always `8` bytes, so just `2` uses are enough
- small signed LEB cases like `0`, `63`, `64`, `8191`, `-64`, `-65`, `-8192` stay inline because their encodings are only `1` or `2` bytes

## 4. Rewrite shape

When a literal group is profitable, `hoist(...)`:

- adds a new local of the literal type to the current function
- uses the first recorded constant expression as the initializer of a fresh `local.set`
- rewrites every use site in that group to `local.get temp`
- returns the `local.set` so the caller can place it in the prelude

This means the actual rewrite is always:

- **one `local.set` at function entry**
- **all occurrences become `local.get`s**

It does **not**:

- thread the temp through CFG joins
- try to place the temp lazily near first use
- avoid lifetime extension
- try to reuse existing locals

The algorithm is intentionally tiny.

## 5. Prelude insertion contract

If any constants were hoisted in a function, `visitFunction` wraps the body as:

- `sequence(block(prelude), original_body)`

The source comment explicitly says:

- `merge-blocks can optimize this into a single block later in most cases`

That means the extra wrapper block is part of the real pass contract, and later cleanup is expected to normalize it.

## 6. Stable hoist ordering

The map is an `InsertOrderedMap`, so profitable literal groups are emitted in first-seen order.

Why this matters:

- temp-local numbering becomes stable
- emitted prelude order becomes predictable
- the dedicated lit file can check exact output shapes

## Important implementation boundaries

## Boundary: function-local only

Everything in the reviewed implementation is function-scoped.
There is no module-wide pooling, no global synthesis, and no sharing across functions.

Inference note:

- the pass declares itself function-parallel and the reviewed tests are all per-function, so the intended contract is clearly per-function hoisting rather than cross-function pooling.

## Boundary: literal-only

The pass only visits `Const` nodes.
It does not look at:

- `global.get`
- immutable globals
- constant expressions in initializers or offsets
- arithmetic trees that could become constant

So it is downstream of constant folding, not part of it.

## Boundary: no `v128`

`v128` returns `false` immediately in `worthHoisting`.
This is an explicit implementation limitation, not a theoretical proof that SIMD constants are never worth hoisting.

## Boundary: no special-case zero optimization yet

The top comment has TODOs explaining that zero is special:

- integer zero could potentially avoid even the initializing `local.set`
- float and double zero look especially attractive because their inline encodings are large

But `version_129` does **not** implement those TODOs.
So even repeated `0` literals are still judged by the generic byte algebra.

## Boundary: no effect analysis needed

Because the only moved expressions are literal `Const`s:

- there are no side effects
- no traps
- no evaluation-order hazards
- no control-dependence checks

That is why the implementation can stay so small compared with motion passes like `code-pushing` or `licm`.

## Boundary: size first, not speed first

The source comment warns that the pass often shrinks raw code size but can **increase gzip size**.
So the correct beginner framing is:

- Binaryen is optimizing **raw binary encoding size**, not compressed transfer size and not execution speed.

That warning is easy to miss and important for future scheduler decisions.

## What is easy to misunderstand

## Misunderstanding 1: “This is just CSE for constants.”

Not quite.

- CSE proves reused computation identities.
- `const-hoisting` only handles already-materialized literal nodes.
- It does not discover repeated non-literal computation.

## Misunderstanding 2: “If a constant appears twice, Binaryen hoists it.”

False.

Binaryen hoists only when the byte model wins.
Two uses are enough only for large constants like `f64` literals, not for typical small `i32` values.

## Misunderstanding 3: “This is for performance because a local is cheaper than a constant.”

The code and tests do not frame it that way.
The implementation is about **encoding size**, and the source even warns that gzip size may get worse.

## Misunderstanding 4: “This is global constant deduplication.”

No.
It neither creates globals nor shares values across functions.

## Misunderstanding 5: “All numeric types are supported.”

No.
`v128` is explicitly unimplemented in the reviewed source.

## Relationship to nearby passes

## `precompute` / `precompute-propagate`

These passes can create more literal `Const` nodes.
`const-hoisting` can then compress repeated large literal payloads.
So the passes are complementary:

- `precompute*` makes constants exist
- `const-hoisting` decides whether repeated large constants should become one set plus many gets

## `simplify-locals*`

`const-hoisting` introduces fresh locals and a prelude block.
A future scheduler that runs locals cleanup nearby must preserve the size reasoning; it should not immediately undo the profitable hoists without a stronger objective.

## `merge-blocks`

The implementation explicitly relies on later cleanup here.
The prelude is wrapped in an extra block, and the source comment expects `merge-blocks` to simplify that structure later.

## `optimize-added-constants*`

Those passes are about folding memory-address arithmetic into offsets under low-memory safety assumptions.
`const-hoisting` is unrelated except that all three are size-oriented and easy to misread from their names alone.

## WAT shapes that matter

### Positive shape: repeated large signed-LEB `i32`

```wat
(func
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
  (drop (i32.const 8192))
)
```

Binaryen rewrites to the rough shape:

```wat
(func
  (local i32)
  (block
    (local.set 0 (i32.const 8192))
  )
  (block
    (drop (local.get 0))
    ...
  )
)
```

### Positive shape: repeated `f64.const`

Two uses are enough because the literal payload is large:

```wat
(func
  (drop (f64.const 0))
  (drop (f64.const 0))
)
```

### Negative shape: many tiny `i32.const`

These stay inline:

- `0`
- `63`
- `64`
- `8191`
- `-64`
- `-65`
- `-8192`

because their signed-LEB sizes are only `1` or `2` bytes.

### Negative shape: SIMD constant

Any `v128.const` currently stays inline because the pass does not implement SIMD profitability or rewriting.

## Beginner-friendly porting rules for Starshine

A future Starshine port should preserve all of these facts:

1. **Literal identity grouping**
   - group by exact literal value and type, not by arbitrary equivalent computation
2. **Byte-accurate profitability**
   - preserve the same encoded-size model or document intentional divergence
3. **Per-function scope**
   - do not silently turn this into module-global pooling
4. **Fresh temp locals only**
   - the reviewed upstream pass allocates fresh locals instead of trying to reuse existing ones
5. **Prelude block insertion**
   - the extra structural wrapper is part of the current upstream contract
6. **`v128` no-op boundary**
   - keep the unsupported SIMD boundary explicit unless intentionally expanded
7. **Zero TODOs are still TODOs**
   - do not teach the unimplemented zero special case as if upstream already did it
8. **Size objective, not runtime objective**
   - keep the raw-size vs gzip-size warning visible

## Open questions / uncertainty

- I did not inspect Binaryen preset scheduling to find a canonical default slot for `const-hoisting`; this note is about the public pass contract, not pipeline placement.
- The per-function isolation is strongly implied by the function-parallel walker setup and the observed tests, but I did not audit the pass-runner internals line by line in this thread. That point is a high-confidence inference, not a directly quoted framework guarantee.

## Durable conclusion

`const-hoisting` is one of the smallest Binaryen passes in the registry, but it is not trivial.
The real contract is:

- **find repeated literal constants inside a function**
- **measure whether one literal plus `local.set` / `local.get`s is smaller in raw wasm encoding**
- **rewrite only the profitable cases**
- **leave later block cleanup to neighbors**

That makes it a clean upstream-only dossier target:

- real public pass
- real local registry entry
- real dedicated tests
- no current living wiki page before this thread
- easy to mis-teach without source-backed notes

## Sources

- Local registry: `src/passes/optimize.mbt`
- Binaryen `version_129`:
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast`
- Binaryen `main` freshness check:
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstHoisting.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/const-hoisting.wast`
- Local planning context:
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
