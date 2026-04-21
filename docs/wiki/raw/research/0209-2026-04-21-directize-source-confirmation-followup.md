# Binaryen `directize` source-confirmation follow-up

Date: 2026-04-21

## Why this follow-up exists

The existing `docs/wiki/binaryen/passes/directize/` folder was already a real dossier, so this was **not** a normal uncovered-pass pick.
I chose it anyway as an explicitly justified follow-up because the tracker no longer had obvious `none` targets, while `directize` still lacked one compact source-confirmed owner/test-map page answering a beginner-practical question the landing, strategy, and table-info pages were still spreading across prose:

- which official files actually own the pass,
- which helper files are part of the real contract,
- what the shipped Binaryen lit files directly prove,
- and which details are source-derived rather than isolated by a dedicated testcase.

That gap matters here because `directize` is easy to mis-teach as either “constant indices become direct calls” or “a generic indirect-call optimizer,” while the real `version_129` contract is a tiny module-prepass plus a narrow `CallIndirect` walker layered over shared table and call helpers.

## Process followed

Per repo rules I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/directize/` folder

`agent-todo.md` **does** still have a dedicated `DIR` slice:

- `[DIR]001 - Indirect-to-Direct Eligibility`
- `[DIR]002 - Call Rewrite, Boundary Regressions, and Artifact Proof`

So unlike some of the recent follow-ups, this dossier already had explicit backlog ownership; the missing piece was the compact official file/test map.

## Official source set reviewed

Primary Binaryen `version_129` sources:

- `src/passes/Directize.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/call-utils.h`
- `src/ir/table-utils.h`
- `src/ir/table-utils.cpp`
- `src/ir/type-updating.h`
- `test/lit/passes/directize_all-features.wast`
- `test/lit/passes/directize-gc.wast`
- `test/lit/passes/directize-wasm64.wast`

## Compact source-confirmed implementation map

## `src/passes/Directize.cpp`

This file owns the pass itself.
What it directly proves:

- `directize` is a real **module pass**, not just a function-local peephole.
- The pass immediately bails out when the module has no tables.
- It reads the optional `directize-initial-contents-immutable` pass arg up front.
- It computes whole-module table facts first with `TableUtils::computeTableInfo(...)`.
- It fast-exits again if no table reports `canOptimizeByEntry()`.
- The actual rewrite walk is a small function-parallel `PostWalker` over `CallIndirect` only.
- Constant targets are classified into exactly three outcomes:
  - `Known`
  - `Trap`
  - `Unknown`
- The pass rewrites only to:
  - `call` / `return_call`
  - `unreachable` with child side effects preserved
  - or an `if` built by the shared select-lowering helper
- The walker tracks `changedTypes` and repairs edited functions with `ReFinalize()`.

Most important negative facts:

- there is no `call_ref` visitor here,
- there is no broader value-range analysis,
- there is no nested cleanup runner inside `Directize.cpp` itself,
- and there is no profitability gate beyond “is the answer sound?”

## `src/passes/call-utils.h`

This helper owns the pass's non-constant target special case.
What it directly proves:

- the only supported non-constant shape is a `select` target,
- both select arms must classify to `Known` or `Trap`,
- any `Unknown` arm blocks the rewrite,
- unreachable operands or unreachable select types block the rewrite,
- the helper introduces fresh locals so call operands are evaluated once,
- and the result is an `if`, not a more general control transformation.

This is the file that source-confirms the narrow “select between known/trap answers” story.
Without it, the landing page could still leave readers guessing whether partial directization, nested selects, or arbitrary symbolic target expressions were supported.

## `src/ir/table-utils.h` and `src/ir/table-utils.cpp`

These files own the biggest safety boundary in the pass.
What they directly prove:

- `TableInfo` tracks `mayBeModified`, `initialContentsImmutable`, and `flatTable`.
- `canOptimizeByEntry()` requires both a valid flattened table view and either:
  - a table that cannot be modified, or
  - immutable initial contents.
- imported and exported tables count as modifiable in ordinary mode.
- runtime mutation barriers include:
  - `table.set`
  - `table.fill`
  - destination `table.copy`
  - `table.init`
- flat-table inference is deliberately cheap and conservative:
  - constant segment offsets only
  - function-typed entries only
  - no overflow or initial-size violation while materializing names

That is the real owner file pair behind the pass's table-knowledge story.
`Directize.cpp` consumes these facts, but it does not define them.

## `src/ir/type-updating.h`

This helper is the reason post-rewrite refinalization is part of the official contract instead of an incidental cleanup.
It explains the standard “edit first, then repair types” approach used by Binaryen passes.
For `directize`, that matters because the pass can:

- replace a reachable call with `unreachable`,
- refine visible result types after exposing a more precise direct callee,
- and add fresh locals when lowering a supported `select` target.

## `src/passes/pass.cpp`

This file proves identity and placement.
What it directly proves:

- `directize` is a real public pass name.
- Its official short description is the small “turns indirect calls into direct ones” summary.
- In the no-DWARF optimize tail tracked in this repo, `directize` runs after `reorder-globals` as the final top-level pass.
- The surrounding scheduler comment explicitly says the pass may open more `inlining` / `dae` opportunities, but ordinary one-shot optimization only comes back for them under `--converge`.

## `src/passes/passes.h`

This header proves constructor identity:

- `createDirectizePass()`

That matters because it confirms `directize` is its own public pass surface, not just a hidden mode of `inlining`, `dae`, `call-utils`, or `table-utils`.

## Compact official test map

## `test/lit/passes/directize_all-features.wast`

This is the main shipped behavior map.
It directly proves:

- basic constant-index direct-call rewrites,
- tail `return_call_indirect` rewrites,
- known-trap replacement with `unreachable`,
- multiple-table coverage,
- imported-table and exported-table conservatism in ordinary mode,
- the effect of `directize-initial-contents-immutable`,
- the important hole-versus-beyond-known-prefix distinction,
- conservative no-ops when element layouts cannot be flattened cheaply,
- select-target lowering to `if` with fresh locals,
- and mutation barriers for at least `table.set`, `table.fill`, and `table.init`.

It is also the clearest direct proof that Binaryen keeps some constant-index calls indirect on mutable tables even in immutable-initial-contents mode when the queried slot lies beyond the known flattened prefix.

## `test/lit/passes/directize-gc.wast`

This file proves that directization uses subtype compatibility, not just exact signature identity.
It directly shows:

- supertype-typed indirect calls can directize to subtype targets,
- the reversed subtype direction is a known trap,
- and directization can refine the visible result type when a more precise direct callee becomes visible.

This is the strongest official correction to the common beginner mistake “the table slot must have exactly the same signature name.”

## `test/lit/passes/directize-wasm64.wast`

This file proves the index logic is really width-correct on wasm64.
Its core value is simple but important:

- Binaryen does not accidentally truncate large `i64` table indices to `i32` before classifying them.

That small dedicated test matters because the pass otherwise looks so scalar and local that width bugs would be easy to miss.

## What the lit files do **not** isolate by themselves

The shipped tests are good, but several important facts are easier to learn from source than from testcase headings alone:

- the two-stage structure `computeTableInfo(...)` -> `canOptimizeByEntry()` -> `CallIndirect` walker,
- the exact ownership split between `Directize.cpp` and `call-utils.h`,
- the fact that destination `table.copy` is a mutation barrier even though the dedicated lit roster does not isolate it the way it isolates `table.set`, `table.fill`, and `table.init`,
- the fast whole-pass no-op when no table is optimizable by entry,
- and the deliberate `ReFinalize()` repair after type-changing rewrites.

## Corrected compact teaching summary

After this source sweep, the safest short explanation of Binaryen `version_129` `directize` is:

- a final late-tail module pass
- that first asks shared `table-utils` code whether any table has safe entry-level knowledge,
- then walks only `CallIndirect` / tail-`CallIndirect` sites,
- classifies constant targets as known direct call vs known trap vs unknown,
- handles one extra shared-helper case for `select` between known/trap answers,
- preserves operand side effects when replacing a known trap with `unreachable`,
- and repairs edited function types afterward with `ReFinalize()`.

That is much narrower and more file-local than “generic indirect-call optimization.”

## Living wiki changes required by this follow-up

This follow-up should add one dedicated living page under the existing dossier:

- `docs/wiki/binaryen/passes/directize/implementation-structure-and-tests.md`

And should refresh the landing page plus shared indexes so future threads can see that `directize` no longer lacks a compact source-confirmed owner/test map.

## Open questions after this follow-up

These now feel secondary rather than structural:

- whether current upstream `main` has drifted in any meaningful way from the reviewed `version_129` owner/test split,
- whether Binaryen will ever widen the select-target helper beyond the current exact-two-arm known/trap contract,
- and whether a future Starshine port should intentionally expose more table-layout proof power than Binaryen's current flat-table conservatism.

## Sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>
