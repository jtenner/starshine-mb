# Binaryen `inlining` follow-up: compilation hints, `no-inline` flags, and clone survival

Date: 2026-04-21

## Why this follow-up exists

The existing `docs/wiki/binaryen/passes/inlining/` dossier was already solid on the main heuristic/planner/rewrite story, but it still lacked one compact source-confirmed page for a subtle teaching gap that official upstream tests exercise directly:

- `@metadata.code.inline` compilation-hint bytes exist and roundtrip in Binaryen IR,
- but Binaryen `version_129` plain `inlining` does **not** use those bytes as its actual do-not-inline switch surface,
- instead the pass consults per-function `noFullInline` / `noPartialInline` flags,
- and those flags can survive cloning through utilities like `ModuleUtils::copyFunction`, which is why the dedicated `no-inline-monomorphize-inlining.wast` test matters.

That distinction is easy to blur if a reader sees `inline-hints.wast`, `no-inline.wast`, and the `Inlining.cpp` heuristics all mentioned in one folder without a focused bridge page.

The tracker currently has no obvious remaining `none` targets, so this is an explicitly justified major-gap follow-up on an already-good but not-yet-fully-source-confirmed dossier.

## Canonical repo context consulted first

Per repo rules, I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/inlining/` folder

`agent-todo.md` has **no dedicated plain `inlining` slice**; it only has the optimizing `INL` slice. That stays true after this follow-up.

## Sources reviewed

Primary upstream Binaryen `version_129` sources:

- `src/passes/Inlining.cpp`
- `src/passes/NoInline.cpp`
- `src/passes/pass.cpp`
- `src/pass.h`
- `src/wasm.h`
- `src/wasm/wasm.cpp`
- `src/wasm/wasm-binary.cpp`
- `src/parser/contexts.h`
- `src/ir/module-utils.cpp`
- `test/lit/inline-hints.wast`
- `test/lit/inline-hints-func.wast`
- `test/lit/passes/no-inline.wast`
- `test/lit/passes/no-inline-monomorphize-inlining.wast`

Current-main spot checks:

- `main/src/passes/NoInline.cpp`
- `main/src/passes/Inlining.cpp`
- `main/src/wasm.h`
- `main/src/parser/contexts.h`
- `main/src/ir/module-utils.cpp`

## Main findings

### 1. `@metadata.code.inline` is a real parsed/printed IR annotation, but it is not the same thing as Binaryen's `--no-inline*` controls

`src/wasm.h` defines compilation-hint storage on `CodeAnnotation`:

- `NeverInline = 0`
- `AlwaysInline = 127`
- `std::optional<uint8_t> inline_`

`src/wasm/wasm.cpp` names the annotation key `metadata.code.inline`.

`src/parser/contexts.h` parses the **last** inline hint annotation at a site, requires a one-byte string payload, rejects values above `127`, and stores the surviving byte in `CodeAnnotation.inline_`.

`src/wasm/wasm-binary.cpp` writes inline hints back out as one-byte expression-hint payloads.

The dedicated tests prove the practical result:

- `test/lit/inline-hints.wast` roundtrips expression-level inline hints on `call`, `call_indirect`, and `call_ref` nodes, including `"\00"`, `"\01"`, `"\7e"`, and `"\7f"`.
- `test/lit/inline-hints-func.wast` roundtrips a function-level `@metadata.code.inline "\12"` annotation.

So the compilation-hints surface is real and preserved.

But `Inlining.cpp` does **not** consult `CodeAnnotation.inline_` when deciding whether a function is fully or partially inlineable in `version_129`.

### 2. The actual Binaryen do-not-inline surface is function flags set by separate passes

`src/wasm.h` stores the real inliner-facing booleans on each `Function`:

- `bool noFullInline = false;`
- `bool noPartialInline = false;`

`src/passes/NoInline.cpp` is the real implementation for the user-facing controls:

- `--no-inline`
- `--no-full-inline`
- `--no-partial-inline`

It matches function names via `String::wildcardMatch(pattern, func->name.toString())` and then sets:

- both flags for `--no-inline`
- only `noFullInline` for `--no-full-inline`
- only `noPartialInline` for `--no-partial-inline`

`src/passes/pass.cpp` registers all three as distinct public pass names.

### 3. `Inlining.cpp` consults those function flags directly

The actual inliner gate is in `Inlining.cpp`:

- full inlining is considered only when `!func->noFullInline && info.worthFullInlining(...)`
- partial/split inlining is considered only when `!func->noPartialInline && functionSplitter`

So the implementation split is explicit in source:

- compilation-hint bytes are stored in annotations,
- Binaryen's current practical inline suppression uses function booleans,
- and the inliner reads the booleans, not the annotation byte.

### 4. The official `no-inline.wast` file proves that full and partial suppression are independently real

`test/lit/passes/no-inline.wast` is not just a generic negative test. It proves three different policy surfaces:

- `--no-full-inline=*maybe*` preserves only the `full-maybe-inline` helper while still allowing the partial-inline candidate family,
- `--no-partial-inline=*maybe*` preserves only the `partial-maybe-inline` family while still allowing the full-inline candidate family,
- `--no-inline=*maybe*` blocks both.

This matters because the public CLI naming matches the exact booleans the pass uses.

### 5. Clone survival is source-confirmed, not just a test-level accident

The existing dossier already mentioned that `no-inline-monomorphize-inlining.wast` proves metadata survival through monomorphization, but this follow-up closes the source-confirmation gap.

`src/ir/module-utils.cpp` copies both flags when cloning a function:

- `ret->noFullInline = func->noFullInline;`
- `ret->noPartialInline = func->noPartialInline;`

It also copies `funcAnnotations`.

That means the official test result is directly explained by source ownership:

- monomorphization creates copied functions,
- copied functions inherit the no-inline booleans,
- later plain `inlining` still sees those copied functions as not inlineable.

So the `no-inline-monomorphize-inlining.wast` result is not an opaque pipeline accident; it is the direct consequence of Binaryen's generic function-copy utility preserving inline-suppression flags.

### 6. Root-survival is still separate from no-inline suppression

While reviewing this follow-up, I re-checked the already-documented root story in `Inlining.cpp`:

- `visitCall` increments `refs` for direct calls,
- `visitRefFunc` increments `refs` for `ref.func`,
- exports and the start function set `usedGlobally = true`.

That means a function can remain non-deletable for root/reference reasons even when it is otherwise inlineable.

This follow-up does **not** change the earlier direct-call planner summary. It just clarifies that the inline policy surface (`noFullInline` / `noPartialInline`) is yet another separate axis from:

- compilation-hint bytes, and
- root-survival / declaration-retention.

## Current-main drift check

A narrow 2026-04-21 spot check found the reviewed pieces still present on Binaryen `main`:

- `NoInline.cpp` still uses wildcard name matching to set `noFullInline` / `noPartialInline`.
- `Inlining.cpp` still gates full and partial inlining on those same booleans.
- `wasm.h` still defines `CodeAnnotation::NeverInline`, `AlwaysInline`, and `inline_`, plus the function booleans.
- `parser/contexts.h` still parses inline-hint bytes with the same `<= 127` rule.
- `module-utils.cpp` still copies the no-inline booleans when cloning functions.

I did **not** re-audit the entire broader inlining family on trunk here; this is only a focused no-drift check for the specific metadata/policy surfaces in this follow-up.

## Durable conclusions to file back into the living wiki

1. In Binaryen `version_129`, `@metadata.code.inline` is a real compilation-hints annotation surface that roundtrips in IR and binary custom sections.
2. That annotation is **not** the same as Binaryen's current practical plain-`inlining` suppression mechanism.
3. The real do-not-inline control surface for plain `inlining` is the pair of function booleans `noFullInline` and `noPartialInline`.
4. Those booleans are set by separate wildcard-matching passes (`no-inline`, `no-full-inline`, `no-partial-inline`).
5. Those booleans survive function cloning through `ModuleUtils::copyFunction`, which directly explains the official monomorphize-plus-no-inline test behavior.
6. Root/reference retention (`refs`, `ref.func`, exports, start) remains a separate reason why a function can survive declaration cleanup after some direct callsites inline.

## Living wiki updates required

- Add a focused page under `docs/wiki/binaryen/passes/inlining/` for compilation hints vs no-inline flags and clone survival.
- Refresh the landing page, strategy page, implementation/test map, and heuristics page to point at that page and summarize the distinction correctly.
- Update the shared tracker/index/log so future recursive campaign threads can see this source-confirmation gap is now closed.
