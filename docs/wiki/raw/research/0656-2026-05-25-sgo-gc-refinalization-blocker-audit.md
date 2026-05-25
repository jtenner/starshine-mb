# SGO GC refinalization blocker audit

## Scope

Research-only `[SGO]003L` closeout for GC refinalization-safe replacement surfaces in `simplify-globals-optimizing`.

The concrete question is whether to implement the narrow Binaryen `simplify-globals-gc.wast` positive where a `ref.cast` consumes a `ref.func` global replacement, or to keep it blocked until the parser/validation/refinalization path is isolated.

## Sources checked

- Prior probe: `docs/wiki/raw/research/0583-2026-05-23-sgo-gc-refcast-probe.md`.
- Starshine WAT parser/lowering surfaces for descriptor ref ops and normal `ref.cast` absence:
  - `src/wast/keywords.mbt`
  - `src/wast/parser.mbt`
  - `src/wast/lower_to_lib.mbt`
- Starshine lib / binary / validation surfaces that do know about normal `RefCast`:
  - `src/lib/types.mbt`
  - `src/binary/decode.mbt`
  - `src/binary/encode.mbt`
  - `src/validate/typecheck.mbt`
- Existing SGO test coverage in `src/passes/simplify_globals_optimizing_test.mbt`.
- Official Binaryen GC lit family previously captured through the SGO current-main and v129 research notes.

## Findings

The blocker is real and should remain explicit:

- normal `ref.cast` exists in Starshine's lib, binary encode/decode, and typechecker surfaces;
- normal `ref.cast` is not currently accepted through the WAT parser/lowering path used by source-alignment tests;
- descriptor casts such as `ref.cast_desc_eq` are parser-supported, but they are not a substitute for the official normal-`ref.cast` positive;
- the 0583 temporary programmatic lib-level positive still failed through the `simplify-globals-optimizing` pipeline, so the issue is not only WAT spelling;
- the already-landed less-refined alias negative pins the conservative boundary where replacing a less-refined GC global with a more-refined alias would require broader refinalization.

Because the target positive changes reference precision, landing it safely needs a minimal fixture that validates through the normal pipeline after SGO replacement and any required function refinalization. Approximating it with descriptor casts or broad GC object duplication would blur distinct contracts.

## Decision

Close `[SGO]003L` as blocked/research-only for now.

Do not implement the `ref.cast(ref.func-global)` positive inside `[SGO]003` until a dedicated prerequisite slice provides:

1. normal `ref.cast` WAT parsing/lowering for the fixture shape;
2. a minimal lib-level or parser-supported validating SGO fixture where replacement changes reference precision;
3. confirmation that the SGO pipeline's type repair/refinalization path handles the changed function;
4. paired negatives for less-refined alias replacement and object-identity-sensitive replacement.

Explicit non-goals remain unchanged: broad `struct.new_default` duplication, arbitrary GC object identity copying, and descriptor GC/ref ops without source-backed fixtures.

## Validation

- `git diff --check` — passed.

No Moon tests or direct SGO fuzz were required for this slice because no code, parser behavior, matcher logic, registry, preset, or normative pass docs changed.

## Status

`[SGO]003L` is complete as a blocked/research-only closeout. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
