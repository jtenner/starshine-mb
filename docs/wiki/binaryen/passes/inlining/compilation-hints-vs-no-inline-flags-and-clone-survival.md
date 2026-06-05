---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/research/0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md
  - ../../../raw/wasm/2026-06-05-compilation-hints-boundary-refresh.md
  - ../../../raw/binaryen/2026-06-02-inlining-current-main-recheck.md
  - ../../../raw/research/0695-2026-06-02-inlining-current-main-recheck.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/NoInline.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-binary.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/parser/contexts.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/inline-hints.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/inline-hints-func.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ../../../wast/code-metadata-and-function-annotations.md
  - ../../../wasm-compilation-hints-boundary.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ../inlining-optimizing/index.md
  - ../monomorphize/index.md
---

# `inlining`: compilation hints vs `no-inline` flags and clone survival

This page closes one easy-to-miss gap in the plain-`inlining` story:

- Binaryen has a real `@metadata.code.inline` annotation surface,
- but Binaryen `version_129` plain `inlining` does **not** use that annotation as its practical “do not inline this function” switch,
- and the real switch surface can survive function cloning.

If you miss that split, the official `inline-hints*`, `no-inline*`, and `no-inline-monomorphize-inlining` tests look like one fuzzy topic instead of three connected but different ones. For standards-status and Starshine-local support claims about the broader active Phase-2 Compilation Hints proposal (`metadata.code.compilation_priority`, `metadata.code.instr_freq`, and `metadata.code.call_targets`), start from [`../../../wasm-compilation-hints-boundary.md`](../../../wasm-compilation-hints-boundary.md); this Binaryen page remains about the `version_129` inline-hint and no-inline pass evidence.

## 1. `@metadata.code.inline` is a real Binaryen IR and binary annotation surface

Binaryen's core IR defines inline-hint storage in `src/wasm.h`:

- `CodeAnnotation::NeverInline = 0`
- `CodeAnnotation::AlwaysInline = 127`
- `CodeAnnotation::inline_` as an optional one-byte value

`src/wasm/wasm.cpp` names the annotation key `metadata.code.inline`.

`src/parser/contexts.h` then parses the **last** inline hint annotation at a site:

- it requires a one-byte string payload,
- warns on empty or malformed strings,
- rejects values above `127`,
- and stores the surviving byte in `CodeAnnotation.inline_`.

`src/wasm/wasm-binary.cpp` writes the same data back out as a one-byte expression-hint payload in the custom annotation section.

## What the official tests prove

### `test/lit/inline-hints.wast`

This file proves expression-level roundtripping on multiple call-like nodes:

- `(@metadata.code.inline "\00")` on `call`
- `(@metadata.code.inline "\01")` on `call`
- `(@metadata.code.inline "\7e")` on `call`
- `(@metadata.code.inline "\7f")` on `call`
- `(@metadata.code.inline "\12")` on `call_indirect`
- `(@metadata.code.inline "\34")` on `call_ref`

The durable lesson is:

- inline-hint bytes are real parsed-and-printed Binaryen IR, not a docs-only comment syntax.

### `test/lit/inline-hints-func.wast`

This file proves that a function-level `@metadata.code.inline` annotation also roundtrips.

So the annotation surface is broader than just individual direct calls.

## 2. But plain `inlining` does not read those bytes as its actual no-inline policy

The practical source check here is simple but important:

- `Inlining.cpp` consults `Function::noFullInline`
- `Inlining.cpp` consults `Function::noPartialInline`
- `Inlining.cpp` does **not** consult `CodeAnnotation::inline_`

The full-inline gate is:

- only consider full inlining when `!func->noFullInline && info.worthFullInlining(...)`

The partial/split gate is:

- only consider split inlining when `!func->noPartialInline && functionSplitter`

So for `version_129`, the reliable mental model is:

- `@metadata.code.inline` is preserved metadata,
- but the plain Binaryen inliner's practical suppression policy comes from separate function booleans.

## 3. The real no-inline policy surface is a separate pass family

Binaryen implements the public controls in `src/passes/NoInline.cpp`, and `src/passes/pass.cpp` registers them as three separate pass names:

- `no-inline`
- `no-full-inline`
- `no-partial-inline`

The implementation is tiny and explicit:

- it takes a wildcard pattern argument,
- matches function names with `String::wildcardMatch(...)`,
- sets `func->noFullInline` and/or `func->noPartialInline`.

That means the official CLI wording maps directly onto the internal booleans the inliner later checks.

## 4. Full and partial suppression are independently real

`test/lit/passes/no-inline.wast` is the main proof surface for that split.

It does not just show “some functions stay un-inlined.”
It shows that three different policies are real and separable:

### `--no-full-inline=*maybe*`

- preserves the `full-maybe-inline` function boundary,
- but still allows the partial-inline candidate family.

### `--no-partial-inline=*maybe*`

- preserves the `partial-maybe-inline` source shape,
- but still allows the ordinary full-inline candidate family.

### `--no-inline=*maybe*`

- blocks both full and partial inlining for matching names.

That is exactly the split you would expect from the two booleans in `Function`.

## 5. Clone survival is source-confirmed, not just a pipeline accident

The existing dossier already noted that `test/lit/passes/no-inline-monomorphize-inlining.wast` proves no-inline intent survives through monomorphization.
This page closes the source-confirmation gap for why. A 2026-06-02 current-main recheck still shows the same flag-copy split in `Inlining.cpp`, `NoInline.cpp`, and `module-utils.cpp`.

`src/ir/module-utils.cpp` copies the inliner-facing flags when cloning a function:

- `ret->noFullInline = func->noFullInline;`
- `ret->noPartialInline = func->noPartialInline;`

It also copies `funcAnnotations`.

So the dedicated monomorphize-plus-inline test is directly explained by source ownership:

- monomorphization creates copied functions,
- copied functions inherit the no-inline booleans,
- later `inlining` still sees those copies as blocked.

## Why this matters for `no-inline-monomorphize-inlining.wast`

That file proves two contrasted realities:

- without no-inline marking, the specialized clones created by monomorphization are still fair inlining targets,
- with `--no-inline=*noinline*`, the copied/specialized versions stay non-inlineable too.

The source-backed reason is not a hidden special case inside monomorphization.
It is the generic function-copy utility preserving the flags.

## 6. Do not confuse no-inline policy with root survival

This follow-up also re-checks an existing but easy-to-blur neighbor fact.

`FunctionInfoScanner` in `Inlining.cpp` counts and preserves other reasons a function may survive:

- `visitCall` increments `refs` for direct calls,
- `visitRefFunc` increments `refs` for `ref.func`,
- exports and the start function set `usedGlobally = true`.

So a function can survive for at least three different families of reasons:

1. it is still rooted or referenced,
2. it is still too large or structurally uninlineable,
3. it has explicit `noFullInline` / `noPartialInline` policy flags.

Those are separate axes.

## 7. Beginner-safe summary

If you need one short rule of thumb, use this:

- `@metadata.code.inline` = preserved Binaryen inline-hint metadata bytes,
- `no-inline` / `no-full-inline` / `no-partial-inline` = actual Binaryen pass-level suppression knobs,
- `ModuleUtils::copyFunction` preserves those suppression knobs on clones,
- and root/reference retention is yet another separate reason a function may remain declared after some callsites inline.

That summary matches the reviewed `version_129` code much better than the simpler but misleading claim:

- “Binaryen uses inline-hint annotations as its ordinary no-inline mechanism.”

## Starshine implementation note

As of 2026-06-02, Starshine has a first local policy surface for this split:

- `no-inline=<pattern>` marks both full and partial suppression;
- `no-full-inline=<pattern>` marks full suppression only;
- `no-partial-inline=<pattern>` marks partial suppression only;
- the direct inliner honors full suppression, while partial suppression is stored for future splitter work;
- [WAT function identifiers](../../../wast/identifier-name-and-annotation-authoring.md), including imported function identifiers, are lowered into structured function names so CLI text inputs can match ordinary `$name` functions;
- repeated policy passes deduplicate the internal markers instead of stacking duplicate annotations;
- no-match policy passes leave the annotation section absent when no prior annotations exist;
- helper-compaction remaps function annotations and function names alongside function indices, so surviving protected functions keep their policy, removed helpers do not leak policy to index `0`, and later policy passes can still match surviving WAT identifiers;
- function-scoped local/label name maps are dropped after inlining rewrites until full name repair exists, avoiding invalid stale local-name metadata;
- `no_inline_copy_policy_annotations(...)` copies the internal full/partial policy markers from an original function to a copied function, providing the shared hook future clone/copy transforms need to mirror Binaryen `copyFunction` flag preservation;
- `@metadata.code.inline` annotations are still treated as metadata and do not block full inlining.

The local policy matches names from the structured name section, including those produced from WAST identifiers by the text lowerer. The annotation storage and `metadata.code.inline` / branch-hint caveats are centralized in [`../../../wast/code-metadata-and-function-annotations.md`](../../../wast/code-metadata-and-function-annotations.md): Starshine's `(@...)` lane is function/import-only and in-memory today, not a binary or expression-level code-metadata model. The broader Compilation Hints proposal boundary lives in [`../../../wasm-compilation-hints-boundary.md`](../../../wasm-compilation-hints-boundary.md); Starshine currently has no typed hint payload parser, byte-offset metadata model, structured WAST hint syntax, generator gate, or optimizer consumer for `compilation_priority`, `instr_freq`, or `call_targets`. The compaction remap preserves both function names and policy annotations through inlining helper removal, and the copy helper covers the currently available clone-survival surface even though Starshine does not yet have an active monomorphize/copy transform consuming it. `[INL]004` is accepted for this current policy surface; partial-inlining-specific no-inline behavior moves with `[INL]005`.

## What future Starshine widening should preserve

- Distinguish Binaryen inline-hint metadata and active-proposal Compilation Hints metadata from actual inliner policy flags.
- Model full-vs-partial suppression as separate controls.
- Preserve no-inline flags across any future function-cloning utility.
- Keep root/reference retention separate from policy suppression.
- Avoid teaching `inline-hints.wast` and `no-inline.wast` as if they prove the same mechanism.
