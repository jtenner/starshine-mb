---
kind: concept
status: strong
last_reviewed: 2026-07-26
sources:
  - ./index.md
  - ../../../../../src/passes/local_subtyping.mbt
  - ../../../../../src/passes/local_subtyping_test.mbt
  - ../../../../../src/passes/local_subtyping_wbtest.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ./fuzzing.md
---

# Starshine strategy for `local-subtyping`

## Current implementation

Starshine runs `local-subtyping` as a module pass. Each iteration rebuilds module context, rewrites every defined function, and repeats until reference-local declarations and represented expression types stabilize.

The implementation has four cooperating analysis paths:

1. **Raw preflight and control refinalization.** It recursively normalizes abstract typed nulls, refinalizes the official i31-valued if/direct-branch block shapes, and preserves ref-catch result carriers.
2. **Raw assignment analysis.** When every relevant write has a known raw producer type, this path includes unreachable writes and avoids unnecessary HOT lifting. Unknown producers are not silently treated as precise in the ordinary path.
3. **HOT assignment analysis.** Functions requiring richer expression typing use HOT result types; known raw facts may replace equally complete but less precise HOT facts.
4. **Dominance analysis.** A conservative structured scan controls nullable-to-non-null rewrites and keeps branch, loop, try-table, and historical validator boundaries safe.

## LUB strategy

Assigned reference types are folded pairwise:

- subtype-related pairs choose the wider member after combining nullability;
- exact bottoms (`none`, `nofunc`, `nocont`) are accepted beneath compatible exact concrete types;
- sibling concrete types search declared supertype chains;
- unrelated concrete/internal values fall back through the narrowest matching abstract family (`i31`, `struct`, `array`, `string`, `func`, `cont`, `exn`, `extern`, `eq`, `any`);
- the final candidate must remain a subtype of the declared local type.

This closes the previously ungenerated concrete-parent, abstract-eq, function-family, and null-bottom families.

## Iteration and expression repair

The pass repeats because one narrowed declaration can sharpen a later `local.get`, `select`, or `call_ref` assignment. Represented repairs include:

- adjacent local-get select LUB annotations;
- zero-parameter call-ref type immediates;
- bottom call-ref replacement with an unreachable `(ref none)` value block;
- typed-null bottom normalization;
- official i31 if/block result refinalization.

Starshine local.get/local.tee instructions do not store a separate emitted result type, so declaration rebuilding supplies their output type. Tee-parent validation tests protect this representation choice.

## Safety boundaries

- Parameters are never rewritten.
- Non-reference and tuple locals are ignored.
- Legacy `try` causes a module-level no-op before mutation.
- Ref-catch flow uses conservative raw facts and disables non-null dominance.
- Control-result refinalization is shape-gated; unsupported stacks stay unchanged rather than relying on partial inference.
- Historical Binaryen outputs rejected by current validators remain nullable in Starshine.

## Verification

The seven-leaf `local-subtyping-all` aggregate covers straight-line dominance, structured dominance, unreachable tails, assignment LUBs, repeated refinement, null bottoms, and control-result refinalization. The final v131 matrix and selected-family counts are in [`fuzzing.md`](./fuzzing.md).
