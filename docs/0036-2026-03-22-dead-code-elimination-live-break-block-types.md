# DeadCodeElimination Live Break Block Types

Status: completed Slice 4 from [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md). `DeadCodeElimination` now distinguishes between concrete typed blocks that really became unreachable and concrete typed blocks that still have a live incoming break supplying the result.

## Scope

Checkpoint the minimal local `TypeUpdater` equivalent needed for typed `block` handling: detect surviving breaks to the current block label after DCE rewrites, avoid invalidly poisoning parents when a `br_if` or sibling break can still produce the block result, and rewrite only the truly dead concrete blocks into unreachable-equivalent structure.

## Landed Behavior

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) now routes typed `block` rewriting through a dedicated helper instead of treating every single-child unreachable tail the same.
- Concrete `block` instructions now only count as escaping their parent when:
  - the surviving tail still escapes, and
  - no live incoming break still targets that block label.
- When a concrete typed block no longer has a live value-producing break, DCE rewrites it to the local unreachable-equivalent form:
  - the single surviving child when only one remains, or
  - a `void` block preserving the side-effectful prefix followed by the escaping tail.
- A surviving `br_if` path to the current block now keeps the concrete block type intact, which prevents DCE from dropping parent consumers like `drop` and emitting invalid typed bodies.

## Correctness Constraints

- `drop(block (result i32) (drop (i32.const 1)) unreachable)` must become a `void` unreachable-equivalent block, not an invalid `i32`-typed child left directly in a void function body.
- `drop(block (result i32) (br_if 0 ...) unreachable)` must keep the outer `drop`, because the conditional branch can still supply the block result.
- The live-break scan must account for nested control-flow depth so `br 1` inside a nested block still counts as a live break to the outer block.

## Validation

- Added whitebox coverage in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for:
  - concrete blocks with no live remaining breaks
  - concrete blocks with a surviving incoming `br_if` value path
- Verified with `moon test src/optimization/dead_code_elimination_wbtest.mbt`.

## Performance Impact

- Negligible. The new live-break scan is local to rewritten typed blocks and only walks the surviving subtree.

## Next Work

- Slice 5 still needs the two `if`-specific rules: unreachable-condition replacement and both-arms-unreachable propagation.
- Slice 6 still needs the conservative loop rule after that.
