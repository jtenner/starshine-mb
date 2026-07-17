---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ./1642-2026-07-17-daeo-func8185-immutable-field-delay.md
---

# DAEO Func 8185 i64 zero carrier

## Attribution

Starting from note `1642`'s canonical Func `8185` body `2462`, a fresh exact Binaryen-v130 O0 sequence leaves the body unchanged through tuple optimization, then changes it as follows:

- `simplify-locals-nostructure`: `2462 -> 2459`;
- `vacuum`: `2459 -> 2458`;
- the remaining downstream sequence converges at `2459` because later branch/block representation changes add one encoded byte;
- final Binaryen DAEO remains `2429`.

The first direct owner is one body-local `i64` carrier with exactly one `i64.const 0; local.set`, sixteen reads, and no tee. Binaryen removes the producer and materializes `i64.const 0` at every read.

## Safety and implementation

The retained post-finalization rewrite is optimizing-only and requires exactly:

- a body local, never a parameter;
- local type `i64`;
- sixteen gets, one set, and zero tees across the full structured body;
- an adjacent top-level `i64.const 0; local.set target` producer;
- all sixteen reads replaced successfully.

The constant is pure and nontrapping. Duplicating it at each read cannot move, add, suppress, or reorder an effect or trap, and the exact one-write count proves every read observes zero. Other constants, types, counts, parameters, writes, or tees reject. The existing selected-definition validation, strict encoded-size profitability gate, and rollback remain authoritative.

Red-first white-box coverage failed on the unbound helper, then passed for the exact positive and fifteen-read, second-write, and tee negatives.

## Artifact result

Artifacts: `.tmp/daeo-func8185-i64zero-candidate-20260717/`.

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

- raw size: `3203060`, `-4` versus note `1642`;
- canonical size: `3263950`, `-4` versus note `1642`;
- Binaryen-v130 canonical module: `3262456`;
- canonical gap: `+1494`;
- Func `8185`: `2458` versus Binaryen DAEO `2429`, `+29`;
- raw SHA-256: `367c7eaf8979696ea64b414d064fff48ca559cde83c0bc5b9417d20359f6ccf6`;
- canonical SHA-256: `66337f04f33ffbcceca2240bec20c21b386d5114224d2b02b0f51ca545051e7b`;
- native SHA-256: `3180bb10194a19fff1c939beee4d6d2b20f1f830aee0be34fa7e37e1097f55fa`;
- first invocation wall time: `95.679s`.

The second invocation is byte-identical in raw and canonical form. All outputs validate with all features.

## Validation and remaining work

- `moon fmt`: passed;
- pass-manager white-box: `285/285`;
- full Moon suite: `8901/8901`;
- native release build: passed with pre-existing warnings;
- artifact raw/canonical validation and convergence: passed.

No fresh generated fuzz lane was run for this exact count-only pure-constant materialization slice; the full required closeout matrix remains outstanding and must cover it with both DAE normalizers and the explicit native binary.

The remaining Func `8185 +29` belongs after the first no-structure/vacuum owner. It still requires direct final-DAEO source attribution. Public optimize/shrink/O4z pre-slot blockers from note `1584` also remain open.
