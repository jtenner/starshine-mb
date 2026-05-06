# `const-hoisting` current-main recheck

## Question

Did Binaryen `main` change the teaching-relevant `const-hoisting` contract since the 2026-04-27 freshness layer, and does the Starshine dossier need a new anchor or only a new freshness note?

## Findings

- I rechecked the official Binaryen `main` `ConstHoisting.cpp`, `pass.cpp`, `const-hoisting.wast`, `literal.h`, and `wasm-binary.h` surfaces.
- The contract is unchanged: `const-hoisting` is still a function-local repeated-literal size pass that hoists profitable scalar `Const` groups into one fresh local plus a function-entry prelude `local.set`.
- The pass still groups by exact `Literal` identity, uses signed-LEB width for integers, uses fixed widths for `f32` / `f64`, rejects `v128`, and keeps the same strict byte-profitability rule.
- The upstream lit file still serves as the behavioral oracle for thresholds, ordering, and structural output shape.
- The same stale `f64` threshold comment caveat remains worth keeping explicit in the living dossier.
- Starshine still treats `const-hoisting` as removed, so this run only needs freshness and catalog updates, not a new implementation claim.

## Durables to file back into the wiki

- Add a new 2026-05-06 Binaryen raw manifest for the current-main recheck.
- Refresh the `const-hoisting` dossier pages so they cite the new manifest.
- Keep the stale `f64` comment caveat explicit instead of overwriting it.

## Result

The pass did not need a new semantic correction. It needed a current upstream anchor and a small hygiene refresh so the dossier stays obviously fresh for future ports.
