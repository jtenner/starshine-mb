---
kind: concept
status: supported
last_reviewed: 2026-08-29
sources:
  - ./index.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/merge_similar_functions.mbt
  - ../../../../../src/passes/merge_similar_functions_test.mbt
  - ../../../../../src/passes/merge_similar_functions_wbtest.mbt
  - ../../../../../src/validate/gen_valid_merge_similar_functions.mbt
  - ../../../../../src/validate/gen_valid_merge_similar_functions_wbtest.mbt
related:
  - ./binaryen-strategy.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./profitability-indirection-and-type-barriers.md
  - ./fuzzing.md
---

# Starshine validation for `merge-similar-functions`

## Implemented surface

The former removed/boundary-only plan is complete. Starshine has an active module owner, registry entry, dispatcher arm, focused tests, dedicated GenValid profiles, compare-pass support, and O4z portfolio integration.

The implementation covers:

- literal parameterization for `i32`, `i64`, `f32`, `f64`, and `v128`
- repeated diff-vector reuse
- profitable exact duplicates
- duplicate simple function type indices with equal resolved signatures
- original params plus shifted body locals
- nested block, loop, if, legacy-try, and try-table bodies
- same-type direct-callee parameterization through typed function refs
- tail-call-preserving thunks and `return_call_ref`
- 255-parameter admission and 256-parameter rejection
- deterministic primary-function class order
- complete-module validation rollback

## Focused tests

The focused suites cover positive and fail-closed behavior:

- large literal siblings
- repeated literals sharing one parameter
- local-index shifting
- same-signature direct callees
- incompatible callee signatures
- nested literal sites
- exact duplicates
- duplicate simple type indices
- differing local declaration type barriers
- helper order across interleaved classes
- tiny-function profitability bailout
- O4z portfolio routing
- generated profile validation, encoding, roundtrip, and actual pass triggering

## Pinned Binaryen 131 evidence

Final direct compare evidence uses `.tmp/toolchains/binaryen-version_131/bin/wasm-opt` with `--require-binaryen-version 131`.

- regular GenValid: 100,000/100,000 compared; 96,352 ordinary plus 3,648 command-cleanup-normalized matches; zero mismatches or failures
- dedicated `merge-similar-functions-all`: 10,000/10,000 exact normalized matches; zero failures
- wasm-smith: 9,956 comparable; 9,955 ordinary plus one unreachable-cleanup-normalized match; zero residual mismatches; 44 classified Binaryen/tool failures
- random-all profiles: 10,000/10,000 compared; 9,854 ordinary plus 46 cleanup-normalized matches; 100 inspected canonical-smaller pre-existing command/representation residuals; zero validation, generator, property, or command failures
- original-primary semantic v2: 100/100 all-equal, zero blocked and zero mismatching cases on the final eight-leaf aggregate
- structural properties: 100/100 byte-deterministic, codec-idempotent, and pass-idempotent

The random-all residuals are not MSF transform drift: the pass does not merge those modules, and the differences are pre-existing Starshine canonical local/block encodings that are 8-12 bytes smaller than Binaryen's output.

## Performance and artifact gate

Direct production timing uses one warmup plus three alternating measurements on the prior 5,261,119-byte Starshine O4z artifact:

- Starshine median: 1.225 seconds
- Binaryen 131 median with `-s 2`: 0.616 seconds
- ratio: 1.989x

The integrated O4z output is 5,113,549 bytes, validates externally, passes self-opt smoke, and is 30,513 bytes smaller than the pinned Binaryen 131 O4z output for the same 14,943,550-byte input.

## Maintenance rule

Keep the pass active only while all of these remain true:

- direct output validates transactionally
- exact diff-vector reuse and local shifting remain covered
- call-target classes retain exact type gates and declarative refs
- dedicated GenValid continues to guarantee profitable triggers
- the regular and dedicated lanes have zero residual mismatches after only documented command-level cleanup normalization
- O4z keeps its locked top-level scheduler order and receives MSF through the validated portfolio candidate
