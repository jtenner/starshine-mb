# 0906 - code-pushing ref-into-if refinalization

Date: 2026-06-25

## Question

Can Starshine make concrete progress on Binaryen's `code-pushing_into_if.wast` `ref-into-if` family by supporting the local type weakening/refinalization that is required after sinking a non-null reference local set into one `if` arm?

## Answer

Yes. Starshine now covers the lit-derived `ref-into-if` shape through the HOT pass path:

- the single-set into-`if` sink accepts direct `local.get` values, not just pure computed values;
- it preserves the existing source-local safety boundary by rejecting a sink when the crossed `if` arm writes the source local;
- after sinking, it weakens a moved non-null body-local reference type to the corresponding nullable reference type so the lowered module validates when the moved set no longer dominates every later use under Wasm's non-null local validation rules.

This is intentionally narrow. It does not implement a general local-subtyping/refinalization pass, does not weaken parameters or unrelated locals, and does not broaden the official shared-GC WAT surface beyond the one `ref-into-if` fixture needed here.

## API/support added

`src/ir/hot_mutate.mbt` now exposes two small public mutation helpers:

- `hot_set_body_local_type(func, local_id, ty)` updates a body-local type and bumps the HOT revision;
- `hot_weaken_body_local_to_nullable_ref(func, local_id)` changes a non-null body-local ref type to the same heap/exactness nullable ref type.

These helpers are used by `code-pushing` after an into-`if` sink. Non-ref, already-nullable, parameter, or out-of-range locals are no-ops.

## TDD evidence

Red-first focused test:

```sh
moon test --target native src/passes/code_pushing_test.mbt -f 'code-pushing sinks ref local into if arm and weakens local to nullable'
```

failed before implementation. The first attempt exposed the prerequisite fixture issue: Starshine's normal pass fixture helper validates inputs and rejects non-defaultable non-null body locals. The final test parses the official-lit-style WAT directly, bypasses input validation for this known Binaryen-valid definite-assignment surface, then requires the optimized output to validate.

Final focused validation:

```sh
moon fmt
moon info
moon test --target native src/passes/code_pushing_test.mbt -f 'code-pushing sinks ref local into if arm and weakens local to nullable'
moon test --target native src/passes/code_pushing_test.mbt
moon test --target native src/ir/hot_mutate_test.mbt
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 200 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-refinalize-smoke-200 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures
```

Results:

- `moon fmt` passed.
- `moon info` passed with the pre-existing `src/validate` warnings.
- The new focused ref-into-if test passed.
- Focused `code_pushing_test.mbt` passed `138/138`.
- Focused `hot_mutate_test.mbt` passed `9/9`.
- Native `src/cmd` build passed with pre-existing warnings.
- Bounded dedicated compare smoke `.tmp/pass-fuzz-code-pushing-refinalize-smoke-200` compared `200/200`: `101` normalized, `99` cleanup-normalized, `0` raw mismatches, `0` validation/generator/property/command failures.

A full four-lane direct-pass matrix was not run because the change is a narrow lit-derived positive plus a source-local guard, and generated inputs normally avoid non-defaultable non-null body locals under Starshine's current validator.

## Remaining work

- Starshine still lacks full validation support for non-defaultable non-null body locals under definite-assignment rules. This slice bypasses input validation only in the focused test so it can exercise the Binaryen lit surface and require the optimized output to validate.
- Broader official `code-pushing-gc.wast` shared-GC representation remains a separate fixture/support gap; implement only for source-backed CP surfaces that are still useful.
- Public preset/neighborhood scheduling remains blocked until direct `code-pushing` behavior and ordered-neighborhood proof are complete.
