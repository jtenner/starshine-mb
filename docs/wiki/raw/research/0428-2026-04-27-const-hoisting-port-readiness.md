---
kind: research
status: supported
last_reviewed: 2026-04-27
sources:
  - ../binaryen/2026-04-27-const-hoisting-port-readiness-primary-sources.md
  - ../binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../binaryen/2026-04-25-const-hoisting-current-main-recheck.md
  - ./0276-2026-04-23-const-hoisting-primary-sources-and-starshine-followup.md
  - ./0354-2026-04-25-const-hoisting-current-main-code-map.md
  - ../../binaryen/passes/const-hoisting/index.md
  - ../../binaryen/passes/const-hoisting/starshine-port-readiness-and-validation.md
---

# `const-hoisting` port-readiness follow-up

## Question

The `const-hoisting` dossier was already source-correct, but it still stopped at a status / port-map page. What should a future Starshine implementation slice actually do first, and which exact local code surfaces must be connected to Binaryen's repeated-literal byte-size contract?

## Findings

- The chosen pass is `const-hoisting`, a small public Binaryen pass that remains in Starshine's removed-name registry.
- The 2026-04-27 current-main recheck did not reveal teaching-relevant drift from the 2026-04-23 / 2026-04-25 dossier contract.
- Binaryen's pass remains a function-local scalar-literal size pass:
  - collect `Const` nodes by exact `Literal` identity,
  - use signed-LEB payload width for integers and fixed widths for `f32` / `f64`,
  - require strict raw-size savings under `before = num * size` and `after = size + 2 + 2 * num`,
  - reject `v128`,
  - add one fresh local plus entry-prelude `local.set` for each profitable bucket,
  - replace original literal use sites with `local.get`.
- Starshine currently keeps `const-hoisting` in `pass_registry_removed_names()` and rejects it honestly through the common removed-pass path.
- The local implementation-readiness hinge is already present in HOT scalar and local infrastructure:
  - registry status: `src/passes/optimize.mbt`,
  - HOT op and payload surface: `src/ir/hot_core.mbt`,
  - scalar lift/lower: `src/ir/hot_lift.mbt`, `src/ir/hot_lower.mbt`,
  - local and const builders: `src/ir/hot_builders.mbt`,
  - fresh body-local append: `src/ir/hot_mutate.mbt`,
  - byte-size ingredients: `src/binary/encode.mbt`.

## Wiki changes made from this research

- Added `docs/wiki/raw/binaryen/2026-04-27-const-hoisting-port-readiness-primary-sources.md`.
- Added `docs/wiki/raw/research/0428-2026-04-27-const-hoisting-port-readiness.md`.
- Added `docs/wiki/binaryen/passes/const-hoisting/starshine-port-readiness-and-validation.md`.
- Refreshed the `const-hoisting` overview, Starshine strategy, pass index, tracker, top-level wiki index, and wiki log so the first-slice and validation ladder are discoverable.

## Recommended future implementation ladder

1. Keep the removed-name behavior until a real owner file, dispatcher wiring, and focused tests exist.
2. Add an analyzer-only slice that reports repeated scalar literal buckets and computed byte thresholds without mutating.
3. Add exact literal-key grouping for `i32`, `i64`, `f32`, and `f64`, preserving float sign-bit and NaN-payload distinctions.
4. Add Binaryen-compatible encoded-size helpers and threshold tests: 3-byte integers require 6 uses, 4-byte integers / `f32` require 4 uses, and `f64` requires 2 uses.
5. Add deterministic prelude insertion with one fresh local and one initializer `local.set` per profitable bucket.
6. Add focused negatives for tiny signed-LEB constants, too-few uses, `v128`, nonliteral repeated computations, cross-function repeats, `+0.0` / `-0.0`, and distinct NaN payloads.
7. Compare isolated `--pass const-hoisting` output against Binaryen before any broader preset-scheduling decision.

## Uncertainty

The main local design choice is structural rather than semantic: Starshine can either mirror Binaryen's immediate extra prelude-block shape exactly or emit a locally cleaner equivalent shape if later canonicalization proves oracle-equivalent. Until that is decided, the validation bridge recommends matching Binaryen's structure first and treating any alternate canonical form as a deliberate follow-up.
