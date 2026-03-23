# DCE Post-Rewrite Type Canonicalization

## Scope

- Keep working toward `DeadCodeElimination` parity with Binaryen on the fresh release artifact.
- Preserve valid DCE rewrites instead of backing them out because they leave duplicate simple type indices behind.
- Reuse existing safe module-level type cleanup rather than inventing DCE-specific type rules.

## Current Behavior

After the earlier DCE correctness fixes, direct fresh-artifact `--dead-code-elimination` validated again, but Starshine still carried a much larger printed type section than Binaryen:

- Starshine before this slice: `381` printed types, `3294` printed functions
- Binaryen direct `--dce`: `110` printed types, `3294` printed functions

The function count already matched, which made this look less like a live DCE merge-set difference and more like post-rewrite type cleanup drift.

## Root Cause

`DeadCodeElimination` rewrites function bodies, and some of those rewrites remove the last remaining use that distinguished one simple type index from another.

Typical shape:

```text
type[1] = [] -> [i32]
type[0] = [] -> [i32]   ;; duplicate simple type

drop(block (type 1) unreachable)
```

After DCE, the body may become:

```text
unreachable
```

At that point the duplicate block type is no longer needed, and duplicate simple function types can also collapse. Starshine already had a safe module-wide helper for this cleanup, but `run_dead_code_elimination(...)` was not using it.

## Binaryen Comparison

Binaryen’s direct `--dce` output on the fresh artifact is already much more compact in the type section than Starshine’s pre-slice output while keeping the same printed function count.

That makes the parity target clear:

- do not weaken DCE rewrites
- do not add DCE-specific quadratic cleanup
- do perform the same kind of safe duplicate simple type compaction after the rewrite

This is the same cleanup class Starshine already uses after `DuplicateFunctionElimination`.

## Implemented Change

In [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt):

- when `run_dead_code_elimination(...)` changes at least one function body, it now:
  - rebuilds the code section
  - runs `optimization_canonicalize_duplicate_simple_type_indices(...)`
  - marks `module_shape_changed` when that canonicalization actually rewrites the type section

Pseudo-code:

```text
rewrite all function bodies with DCE
if no function changed:
  return module unchanged

module = module with rewritten code section
module = canonicalize duplicate simple type indices(module)
return module
```

## Correctness Constraints

- Only compact duplicate simple types.
- Reuse the existing canonicalization helper rather than adding DCE-only remap logic.
- Preserve function bodies and function count; this is type-section cleanup, not another DCE rewrite.
- Keep the output validating after binary lowering.

## Validation

Code checks:

- `moon info && moon fmt`
- `moon test`
- `moon build --target native --release src/cmd`

Focused regression:

- `dead code elimination canonicalizes duplicate simple type indices after rewrite`

Fresh artifact checkpoints:

- direct Starshine `--dead-code-elimination`:
  - before: `2517968` bytes, `381` printed types, `3294` printed functions
  - after: `2511564` bytes, `109` printed types, `3294` printed functions
- direct Binaryen `--all-features --dce`:
  - `2534636` bytes, `110` printed types, `3294` printed functions
- fresh shared five-pass prefix after this slice remains validating and unchanged in size:
  - Starshine `DFE -> RUME -> MemoryPacking -> OnceReduction -> DCE`: `2352767`
  - Binaryen equivalent explicit prefix: `2374783`

## Performance Impact

- No new DCE-specific analysis.
- Reuses the existing duplicate-simple-type canonicalizer only when DCE already changed the module.
- The helper is module-wide, but it is linear in the type references it rewrites and avoids new repeated subtree scans.

## Open Questions

- Starshine is now much closer to Binaryen on the direct-DCE type section (`109` vs `110`), but there is still a remaining one-type and byte-size delta to inspect.
- The five-pass checkpoint size did not move even though the direct DCE checkpoint did, so the next parity slice should compare normalized four-pass vs five-pass output again and identify the next real Binaryen-only rewrite.
