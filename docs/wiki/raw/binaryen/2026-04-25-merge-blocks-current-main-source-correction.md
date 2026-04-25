# Binaryen `merge-blocks` current-main source correction

_Capture date:_ 2026-04-25  
_Status:_ immutable source-correction manifest for `docs/wiki/binaryen/passes/merge-blocks/`

## Scope

This capture corrects the earlier local teaching frame for Binaryen `merge-blocks`. The older dossier treated the pass as a tail-child-only flattening pass that accepts unnamed or same-name child blocks. Re-reading the official Binaryen sources on 2026-04-25 shows that framing was too narrow and partly inverted:

- the upstream source scans named block children, not unnamed children;
- it can rewrite child block names to a parent name through a recursive branch-user safety proof;
- it has dedicated `if`, `throw`, `rethrow`, and `return` visitors beyond ordinary block-list splicing;
- the function-wide `ProblemFinder` bailout still exists, but it is only one guard in a larger named-block deblocking pass.

Use the living dossier pages for explanation:

- `docs/wiki/binaryen/passes/merge-blocks/index.md`
- `docs/wiki/binaryen/passes/merge-blocks/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-blocks/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-blocks/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md`

## Official sources consulted

### Tagged `version_129` source oracle

- Binaryen `version_129` release page:
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `MergeBlocks.cpp`:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
  - Raw mirror consulted: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MergeBlocks.cpp>
- Dedicated lit test:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
  - Raw mirror consulted: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/merge-blocks.wast>
- Scheduler / registry source:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Helper surfaces used by the implementation:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-traversal.h>

### Current-main drift check

- `MergeBlocks.cpp` on current `main`:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
  - Raw mirror consulted: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MergeBlocks.cpp>
- `merge-blocks.wast` on current `main`:
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast>
  - Raw mirror consulted: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/merge-blocks.wast>
- `pass.cpp` on current `main`:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

## Source locations and durable observations

- `MergeBlocks.cpp` still defines a function-level `ProblemFinder` prescan before the main `PostWalker` body. The correction is that this prescan does not make the pass tail-child-only; it prevents an ambiguous same-name branch-retargeting family before the broader walker runs.
- The main block rewrite depends on a named-block helper and `canChangeTo(...)`. That helper returns false for nameless blocks, returns true for a direct same-name parent/child relation, and otherwise recursively proves that branch users of the child label can be changed to the parent without crossing invalidating effects.
- `visitBlock(...)` scans block children in the containing block list, checks named grandchildren before removal, splices the accepted child's list into the parent list, rewrites scope-name uses from the child name to the parent name, and refinalizes the rewritten block.
- `visitIf(...)` has its own deblocking path for named block wrappers in `if` arms, so the pass is not limited to `Block`-as-parent cases.
- The terminal visitors for `throw`, `rethrow`, and `return` remove a child block name when that name is only wrapping a terminal expression family; this is another pass surface omitted by the older tail-child-only summary.
- The dedicated `merge-blocks.wast` file includes explicit `no-merge-nameless` coverage, so the older “unnamed tail block merges” claim is contradicted by the official test surface.
- The focused current-main recheck found no teaching-relevant drift from the corrected `version_129` contract above. The correction is against the local dossier's earlier interpretation, not a newly introduced upstream behavior after `version_129`.

## Supersession

This source correction partially supersedes these repo-authored notes and pages for their tail-child-only / unnamed-child teaching frame:

- `docs/wiki/raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md`
- `docs/wiki/raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md`
- the pre-2026-04-25 versions of `docs/wiki/binaryen/passes/merge-blocks/binaryen-strategy.md` and `docs/wiki/binaryen/passes/merge-blocks/wat-shapes.md`

The older notes remain useful for historical scheduling context and for recording when Starshine's local `merge-blocks` implementation became active.
