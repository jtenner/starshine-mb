# Binaryen `const-hoisting` literal-identity follow-up

Date: 2026-04-21
Status: source-backed follow-up for existing dossier
Pass: `const-hoisting`
Local registry status: `removed` in `src/passes/optimize.mbt`
Binaryen release reviewed: `version_129`
Current-main drift check: reviewed on 2026-04-21; `src/passes/ConstHoisting.cpp` and `test/lit/passes/const-hoisting.wast` are still unchanged on `main`

## Why this follow-up exists

The existing `const-hoisting` dossier already covered the broad pass contract well:

- function-local repeated-`Const` grouping
- byte-based profitability
- fresh-local prelude insertion
- unsupported `v128`
- raw-size-versus-gzip warning

What it still under-taught was the **grouping key itself**.
That gap matters because `ConstHoisting.cpp` stores uses in an `InsertOrderedMap<Literal, ...>`, not in an integer-only bucket or a textual pretty-print bucket.
Without reading `literal.h`, it is easy to gloss over several important consequences:

- float literals are grouped by **bit pattern**, not “numeric sameness”
- `+0.0` and `-0.0` are different hoist buckets
- NaNs with different payloads are different hoist buckets
- the TODO comment about “zero” does not mean the current pass merges all zero-looking float encodings together

I also found one tiny but worth-recording upstream test-surface quirk:

- in `test/lit/passes/const-hoisting.wast`, the final `$enough-d` source comment still says `;; 4 bytes, need 4 appearances` next to `f64.const 0`, but the checked output and the implementation both show the real rule is **8 bytes, 2 appearances**

So this follow-up closes a real major-gap fallback inside an already-good dossier: the exact literal-identity semantics and the one misleading test comment were not yet documented in a compact canonical place.

## Sources reviewed

### Main pass surface

- `src/passes/ConstHoisting.cpp`
- `test/lit/passes/const-hoisting.wast`
- `src/passes/pass.cpp`

### Grouping-key and hashing surface

- `src/literal.h`

## Key source-backed findings

## 1. `const-hoisting` groups by `Literal`, and `Literal` equality is bitwise for basic values

`ConstHoisting.cpp` stores uses in:

- `InsertOrderedMap<Literal, std::vector<Expression**>> uses`

That alone tells us the grouping key is the entire `Literal`, not just a numeric value.
The real semantics live in `literal.h`.
There Binaryen documents `Literal::operator==` as:

- equality checks both the type and the bits
- NaN floats are therefore compared bitwise

That means the pass groups repeated constants by **typed bit identity**.

Practical consequence:

- `f32.const 0` and `f64.const 0` are different buckets because the types differ
- two `f32` NaNs with different payload bits are different buckets
- `f32.const 0x0p+0` and `f32.const -0x0p+0` are different buckets because their sign bits differ even though both compare numerically equal to zero in ordinary floating-point equality

## 2. The hash function matches the same bitwise policy

`literal.h` hashes:

- `i32` by `geti32()`
- `f32` by `reinterpreti32()`
- `i64` by `geti64()`
- `f64` by `reinterpreti64()`
- `v128` by two 64-bit chunks

So the map key is not only conceptually bitwise; the concrete hash implementation is bitwise for float values too.
That closes the usual “maybe equality is bitwise but hashing canonicalizes floats” doubt.

## 3. The existing zero TODO does **not** imply zero-sign canonicalization today

`ConstHoisting.cpp` still contains these TODOs:

- hoisting a zero does not even require an initial set
- hoisting float or double zero is especially beneficial

But the current pass does not call `Literal::isZero()` at all inside `worthHoisting(...)`.
Instead it uses:

- signed-LEB width for integers
- fixed widths `4` and `8` for floats
- the same one-formula byte comparison for every supported scalar literal

So current `version_129` behavior is still:

- no special zero path
- no “all float zeros share one bucket” rule
- no special removal of the initializing `local.set`

The TODO is future-looking only.

## 4. That matters for `+0.0` versus `-0.0`

`literal.h` also exposes `isZero()` for floats using numeric comparison to `0.0`, which means both `+0.0` and `-0.0` count as zero for that helper.
But because `const-hoisting` groups by `Literal` equality and hashes floats by their raw reinterpreted bits, the pass currently behaves more narrowly:

- `+0.0` and `-0.0` both satisfy the English idea of “zero”
- but they will still be collected in separate hoist groups today

That is a good example of why reading only the TODO comments would mis-teach the real pass behavior.

## 5. The same distinction matters for NaN payloads

`literal.h` explicitly documents that `Literal` equality compares NaNs bitwise so that a NaN literal is equal to itself when the bits match.
Therefore:

- repeated identical NaN bit patterns can be hoisted together if they are of a supported scalar float type and the byte threshold is met
- different NaN payloads are separate groups even if both print broadly as `nan`

The existing dedicated lit file does not isolate this case directly, so it was worth filing back into the living docs from the source review.

## 6. `v128` hashing exists, but the pass still bails out before using it

`literal.h` includes hashing for `v128` by two 64-bit chunks.
However `ConstHoisting.cpp` still returns `false` immediately for:

- `Type::v128`

So the SIMD bitwise key machinery exists in Binaryen's generic literal support, but `const-hoisting` intentionally does not use it yet.
That clarifies the boundary between generic `Literal` infrastructure and this specific pass contract.

## 7. The upstream lit file has one comment typo, but the checked behavior is still correct

In the final `f64` threshold example the source comment says:

- `;; 4 bytes, need 4 appearances`

But the surrounding checked output and the pass implementation agree on the actual rule:

- `f64` literals are modeled as `8` bytes
- `2` appearances are enough

So the correct teaching should follow:

- `ConstHoisting.cpp`
- the `CHECK:` lines in `const-hoisting.wast`

not that one inline comment.
This is a tiny issue, but documenting it prevents future wiki pages from copying the wrong threshold sentence.

## Durable conclusions

## Exact grouping rule

Teach `const-hoisting` grouping as:

- exact `Literal` key
- type-sensitive
- bit-sensitive for float values
- insertion-order stable

not as:

- generic numeric equality
- “same printed constant text”
- “all zeros are one bucket”

## Exact zero rule today

Teach zero handling as:

- ordinary generic byte-model handling today
- special-case-zero optimization only as a TODO in source comments

not as:

- already-implemented omission of the initializing `local.set`

## Exact float corner-case rule today

Teach float literal grouping as:

- identical bit-pattern `f32` / `f64` literals can group
- different NaN payloads do not group
- `+0.0` and `-0.0` do not group

That is the most important subtlety this follow-up adds.

## Exact test-surface rule today

Teach the `f64` threshold from the implementation and the checked output:

- 8 bytes
- 2 appearances

and explicitly ignore the single stale inline comment in the final lit example.

## Sources

- Existing dossier seed: `docs/wiki/raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md`
- Local tracking context:
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
- Binaryen `version_129`:
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/literal.h`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast`
- Binaryen `main` freshness check:
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstHoisting.cpp`
  - `https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/const-hoisting.wast`
