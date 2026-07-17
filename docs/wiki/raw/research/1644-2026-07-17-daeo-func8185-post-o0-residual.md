---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ./1643-2026-07-17-daeo-func8185-i64-zero-carrier.md
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
---

# DAEO Func 8185 post-O0 residual

## Question

Does the remaining canonical Func `8185` gap, `2458` versus final Binaryen DAEO `2429`, have another safe owner in the documented Binaryen O0 downstream sequence?

## Fresh sequence result

Input: note `1643` endpoint `.tmp/daeo-func8185-i64zero-candidate-20260717/run2.canonical.wasm`.

Artifacts: `.tmp/daeo-func8185-post-i64zero-o0-sequence-20260717/`.

The exact downstream sequence was replayed one pass at a time:

`precompute-propagate -> dce -> remove-unused-names -> remove-unused-brs -> remove-unused-names -> optimize-instructions -> heap-store-optimization -> precompute -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> coalesce-locals -> simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> precompute -> optimize-instructions -> heap-store-optimization -> vacuum`.

Func `8185` remains `2458` through the first twelve passes, including the direct no-structure/vacuum pair. `remove-unused-brs` temporarily produces `2459`; later reorder restores `2458`; merge-blocks returns to `2459`, which remains the final O0-sequence endpoint. Every generated module validates.

## Classification

The remaining `29` bytes are **not owned by another isolated pass in this documented downstream O0 sequence**. Applying or broadening another local movement/coalescing rule based only on the final Binaryen body would therefore be speculative: it would not have a directly replayed pass owner, and prior broader movement probes already changed unrelated functions or lost canonical size.

This closes the current Func `8185` local movement/coalescing audit as source-backedly exhausted at body `2458`. It does not claim semantic equivalence from size alone and does not classify the final body-shape difference as a Starshine win. The `+29` remains a parity gap attributable to Binaryen DAEO's internal iterative state/scheduling or to an earlier interaction not reproduced by the isolated post-Starshine O0 replay.

Reopening this family requires one of:

- a direct Binaryen trace/source path proving the internal rewrite owner;
- a minimized replay that reproduces the `2458 -> 2429` transition;
- measured Starshine benefit proving the retained shape wins without regressions.

Absent that evidence, no further Func `8185` rewrite is safe to retain in this audit.

## Remaining release work

The canonical module gap is still `+1494`, below the `< +10000` requirement. Required closeout work is now the four-lane `100000/10000/10000/10000` matrix with the explicit native binary and both DAE normalizers, followed by fresh attribution and resolution or source-backed closure of the public optimize/shrink/O4z pre-DAEO blockers from note `1584`.
