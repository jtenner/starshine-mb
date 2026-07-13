# Binaryen `merge-blocks` expression-child current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source manifest for `docs/wiki/binaryen/passes/merge-blocks/`

## Why this capture exists

The living `merge-blocks` dossier correctly rejected the older named-block-retargeting story, but it still taught an incomplete current upstream implementation: a collection of special `drop(block ...)`, `if`, and `throw` helpers. That model hides the current owner file's more general expression-child rewrite and makes the checked-in Starshine `i32.store` coverage look like a local-only extension.

This capture supersedes that incomplete *current-source interpretation*. Older raw captures remain historical provenance and are intentionally not edited.

## Official sources consulted

### Current-main primary sources

- Binaryen owner: [`src/passes/MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp)
- Binaryen registration/scheduling surface: [`src/passes/pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp)
- Binaryen focused lit fixture: [`test/lit/passes/merge-blocks.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast)

### Released comparison anchor

- Binaryen `version_130` owner file: [`src/passes/MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MergeBlocks.cpp)
- Binaryen `version_130` focused fixture: [`test/lit/passes/merge-blocks.wast`](https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/merge-blocks.wast)
- Binaryen [`version_130` release](https://github.com/WebAssembly/binaryen/releases/tag/version_130)

## Durable findings

### 1. Current upstream has structural, special, and generic routes

`MergeBlocks.cpp` still merges eligible nested child blocks into block lists and loop tails. It also has a generic `visitExpression(...)` path: for a **non-control** expression child that is an unnamed multi-item `block`, it can move the block's prefix before the parent expression and retain the block tail as that expression child. An ordinary value-consuming instruction such as `i32.store`, `array.set`, or a call can use this generic route.

The generic path is not the whole owner: `visitDrop(...)` invokes dropped-block cleanup, `visitIf(...)` handles only the condition, and `visitThrow(...)` has its own operand route. The important correction is that those special routes do not exhaust `merge-blocks`; arm regions remain structured control regions.

### 2. This is constrained prefix extraction, not arbitrary flattening

The generic path requires an unnamed list block with at least two items and a tail whose type matches the block result. It preserves the tail as the expression input. It also uses `EffectAnalyzer::orderedBefore(...)` checks against already-seen child effects to preserve operand evaluation order. The rewrite is consequently not permission to hoist any nested block or reorder two effectful operands.

### 3. The focused official fixture proves the special and generic boundaries

The current focused fixture covers `if`-condition extraction, ordinary generic operand extraction through `array.set` and multi-argument calls, and effect-order cases where a later prefix must remain nested. It does not need a store-specific fixture for the generic non-control visitor to establish the ordinary-operand contract. A current Starshine documentation page must distinguish fixture evidence from the broader owner-file mechanism.

### 4. Current source vocabulary differs from the stale helper table

The reviewed current owner is organized around `visitBlock(...)`, `visitDrop(...)`, `visitExpression(...)`, `visitIf(...)`, `visitThrow(...)`, and `visitFunction(...)`. `optimizeBlock(...)` and `optimizeDroppedBlock(...)` remain current helpers, but the old table's nonexistent `optimizeIf(...)` / `optimizeThrow(...)` labels and omission of generic `visitExpression(...)` made it an unreliable current-main map.

### 5. Release comparison boundary

The `version_130` owner-file spot check has the same teaching-important generic `visitExpression(...)` prefix-extraction structure. This capture does **not** claim a complete historical diff against every older Binaryen release; use a tag-specific source review before making a finer release claim.

## Starshine evidence used for reconciliation

The local HOT pass independently has a similarly shaped expression-child helper:

- `src/passes/merge_blocks.mbt:293-334` — candidate legality;
- `src/passes/merge_blocks.mbt:336-414` — `merge_blocks_lift_expression_block_children(...)`;
- `src/passes/merge_blocks_test.mbt:2168-2295` — `if` condition, `drop`, `i32.store`, and `throw` fixtures.

This is an implementation correspondence, not proof of full Binaryen parity. Starshine uses one HOT helper across its supported expression children, whereas Binaryen splits special drop/if/throw routes from the generic non-control visitor. Starshine also adds live-label, typed-carrier, loop-containing-region, branch-prefix, and HOT-effects guards; its current fixture set is narrower than every upstream expression family.

## Documentation actions required

- describe current upstream as **structured block/loop merging plus effect-safe generic expression-child prefix extraction**;
- distinguish generic ordinary-child shapes such as `i32.store` from special `drop`, `if`, and `throw` visitor routes;
- distinguish prefix extraction from arbitrary flattening and spell out the evaluation-order guard;
- correct current owner/test maps and Starshine's living strategy pages;
- retain old raw captures and mark the new capture as the current source interpretation.
