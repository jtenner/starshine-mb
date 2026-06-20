# Optimize-instructions OI-H argument-bearing select call_ref boundary

## Question

Can Starshine safely widen the OI-H `visitCallRef(...)` select-known-target lowering from zero-argument `call_ref` / `return_call_ref` forms to argument-bearing calls?

## Classification

Completed boundary `[O4Z-AUDIT-OI-H]` sub-slice: Starshine intentionally keeps argument-bearing typed `select(ref.func A, ref.func B, cond)` targets under `call_ref` and `return_call_ref` unchanged until the pass has a Binaryen-style localizing lowering.

This is a fail-closed behavior guard, not a parity implementation. Binaryen `version_130` rewrites the probed forms by storing already-evaluated call arguments in temporary locals before moving the target condition into an `if`. Starshine's current zero-argument select lowering cannot be widened by simply duplicating `args`, because that would duplicate argument side effects/traps and reorder evaluation relative to the target condition.

## Source anchors

- `docs/wiki/raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md` maps Binaryen `visitCallRef(...)` to `[O4Z-AUDIT-OI-H]`, including select-of-known-targets and helper dependencies such as localizing.
- `docs/wiki/raw/research/0752-2026-06-19-optimize-instructions-oi-h-select-ref-func-call-ref.md` implemented only the zero-argument select-known-target subset and explicitly left argument-bearing forms open.
- Local Binaryen oracle probe with `wasm-opt version_130` confirmed the broader behavior:
  - `local.get 0; ref.func $a; ref.func $b; local.get 1; select (result (ref $target)); call_ref $target` becomes a temp-local write for `local.get 0`, followed by an `if (result i32)` whose arms direct-call `$a` / `$b` with `local.get` of that temp.
  - the same target under `return_call_ref $target` becomes a void `if` whose arms `return_call` `$a` / `$b` with the localized argument.

Probe command:

```sh
wasm-opt .tmp/oi-h-select-call-ref-args.wat --enable-gc --enable-reference-types --enable-tail-call --optimize-instructions -S --print
```

## Local Starshine decision

The local implementation in `src/passes/optimize_instructions.mbt` keeps the select-known-target branch guarded by `args.length() == 0`. That guard is intentional for now:

- WebAssembly evaluates call arguments before the callee reference for `call_ref` stack forms.
- Rewriting an argument-bearing select target to `if` arms must preserve that single argument evaluation before the branch condition chooses the direct target.
- Binaryen preserves this by localizing the already-evaluated arguments, then reading the temporaries from each direct-call arm.
- Starshine does not yet have a dedicated localizing builder/proof in this OI helper for fresh temp locals, local lifetime cleanup, multivalue arguments, or effect/trap preservation.

The new boundary test locks this behavior so a future widening must be explicit and accompanied by localization tests rather than accidentally duplicating arguments.

## Tests

Added `optimize-instructions intentionally keeps argument select call_ref targets until localization exists` in `src/passes/optimize_instructions_test.mbt`.

The direct-core fixture declares:

- a target type `(param i32) (result i32)`;
- a caller type `(param i32 i32) (result i32)`;
- two target functions;
- one `call_ref` caller and one `return_call_ref` caller that pass `local.get 0` as the argument and select between direct `ref.func` target arms using `local.get 1`.

The test asserts both optimized callers still contain `call_ref` / `return_call_ref`, `select`, and `ref.func`, and that they have not been rewritten to direct `call` / `return_call` arms.

Focused boundary evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*argument select call_ref*'
# Total tests: 1, passed: 1, failed: 0.
```

## Broader validation

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*call_ref*'
# Total tests: 4, passed: 4, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
# Total tests: 134, passed: 134, failed: 0.

moon fmt
# Finished.

moon test src/passes
# Total tests: 2646, passed: 2646, failed: 0.

moon build --target native --release src/cmd
# Finished with existing pass_manager unused-function warnings.

moon info
# Finished with existing warnings in src/validate/gen_valid.mbt and src/validate/gen_valid_ssa.mbt.
```

## Direct compare evidence

Command:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-argument-select-call-ref-boundary-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-argument-select-call-ref-boundary-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested: `10000`
- compared: `55/10000`
- normalized matches: `27`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- raw mismatches: `28`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `1`
- jobs: `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`) from the cached failure lane.

Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new `call_ref` semantic failures. Grepping final failure WAT/text artifacts for `call_ref`, `return_call_ref`, `ref.func`, `select`, `call_indirect`, and `return_call_indirect` found no occurrences.

## Remaining OI-H work

`[O4Z-AUDIT-OI-H]` remains open for:

- fallthrough-known direct targets with preserved target-side effects;
- a future positive argument-bearing select-of-known-targets lowering that localizes already-evaluated arguments before introducing the `if`;
- broader type/effect negatives around those shapes;
- any unsupported `return_call_ref` surface if future fixtures expose representation gaps.

This slice closes only the current fail-closed argument-bearing select boundary so later work cannot silently widen it unsafely.
