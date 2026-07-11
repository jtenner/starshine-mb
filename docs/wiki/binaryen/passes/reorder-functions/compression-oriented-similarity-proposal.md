---
kind: decision
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-reorder-functions-current-main-and-similarity-proposal-recheck.md
  - https://github.com/WebAssembly/binaryen/pull/8696
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./count-surfaces-ordering-and-omissions.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../reorder-functions-by-name/index.md
---

# Proposed Binaryen `reorder-functions-by-similarity`: compression boundary

## Status first

This is **not a current Binaryen pass** and **not a Starshine pass**.

As rechecked on 2026-07-11, upstream Binaryen PR [#8696](https://github.com/WebAssembly/binaryen/pull/8696) is open and proposes `reorder-functions-by-similarity`. Current Binaryen `main` registers only the shipped siblings:

- `reorder-functions` — static-reference-count order;
- `reorder-functions-by-name` — lexical/debug order.

Starshine keeps only those two shipped names as boundary-only entries in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). It has no owner, dispatcher case, preset slot, or compare-pass allowlist entry for any of the three spellings.

The durable rule is simple: **an open upstream pull request is design evidence, not a supported pass contract.**

## Why it is a different idea

The shipped `reorder-functions` pass tries to make frequently referenced function indices small. Its source-backed key is a tiny static-use count. See [`binaryen-strategy.md`](binaryen-strategy.md).

The proposed similarity pass instead tries to improve compression by grouping emitted function bodies that look alike. The proposal describes a structural lexicographic sort key:

```text
(function signature,
 local-variable types,
 bounded post-order opcode/immediate sequence,
 original defined-function order)
```

The intended compression intuition is that nearby similar byte sequences can give gzip, Brotli, or zstd more reusable context. This is a layout heuristic, not a semantic optimization and not runtime profile guidance.

## Proposed module shape

Conceptually, an input with unrelated source order:

```wat
(module
  (import "env" "i" (func $imported))
  (func $wide (param i64) ...)
  (func $add-a (param i32) (result i32) ...)
  (func $add-b (param i32) (result i32) ...)
)
```

could place the two similarly shaped `i32` functions adjacent after ordering:

```wat
(module
  (import "env" "i" (func $imported)) ;; import prefix preserved
  (func $add-a (param i32) (result i32) ...)
  (func $add-b (param i32) (result i32) ...)
  (func $wide (param i64) ...)
)
```

This is illustrative, not a promised exact output. PR #8696's proposal preserves imports before defined functions, sorts only defined bodies, and uses the original defined-function order as a final deterministic key component.

## Safety and correctness constraints if it lands

A declaration-order pass must preserve every observable function identity:

- direct calls, tail calls, and `ref.func` references must still reach the same logical function after numeric-index repair;
- start, function exports, element segments, initializer expressions, and function-indexed metadata must still point at the same logical function;
- the paired function and code section order must remain valid;
- imports must retain their required imported-function prefix;
- body structure may be inspected for a sort key, but it must not be transformed merely by ordering.

These are especially important in Starshine because its lowered IR carries numeric `FuncIdx` values. The existing [`starshine-strategy.md`](starshine-strategy.md) and [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) map the required permutation/remap surface; [`src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt) is a useful reference map, not a drop-in algorithm.

## Proposal-specific uncertainty

The upstream review contains active design uncertainty rather than a settled contract:

- The proposed bounded key rewards shared prefixes/prologues. A reviewer raised substring similarity as a potentially stronger but slower alternative.
- A maintainer suggested considering richer existing `Outlining.cpp` structural machinery; the author deferred that because it may make the pass much larger or slower.
- Which immediates belong in the key changes what “similar” means and can change compression outcomes.
- The author reported selected compressed-size wins, but no result establishes a universal raw-wasm, gzip, Brotli, or zstd improvement.

Keep these as explicit open questions. Do not backfill them as proven behavior into the shipped frequency pass.

## Starshine decision gate

Do not create a Starshine registry name or fuzz lane merely because the proposal is interesting. Reconsider only after upstream lands a stable public pass, then:

1. capture the landed owner, registration, tests, and release boundary;
2. decide whether Starshine wants exact parity, a different measured heuristic, or no port;
3. design a total function-index permutation that preserves imports and remaps all references;
4. add focused semantic fixtures before implementation;
5. measure raw wasm **and** relevant compressed outputs against a stable corpus;
6. add the pass to the harness only after an active local registry implementation exists.

Until then, `bun fuzz compare-pass --list-passes` is only a roster inspection tool. A made-up `--pass reorder-functions-by-similarity` command would be rejected and would provide no parity evidence.

## Sources

- [`../../../raw/binaryen/2026-07-11-reorder-functions-current-main-and-similarity-proposal-recheck.md`](../../../raw/binaryen/2026-07-11-reorder-functions-current-main-and-similarity-proposal-recheck.md)
- Binaryen PR [#8696](https://github.com/WebAssembly/binaryen/pull/8696) (open proposal; not current-main behavior)
- [`index.md`](index.md) — shipped pass status
- [`binaryen-strategy.md`](binaryen-strategy.md) — shipped static-frequency pass
- [`starshine-strategy.md`](starshine-strategy.md) — current local boundary-only status and remap map
