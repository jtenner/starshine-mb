---
kind: research
status: active
created: 2026-06-25
sources:
  - ./1046-2026-06-25-heap-store-optimization-profile-call-old-field.md
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/fuzz/main_wbtest.mbt
---

# HSO generated call-result old-field blocker

Question: should the dedicated `heap-store-optimization` GenValid profile grow a true call-result old-field root now, instead of the `1046` value-block approximation?

## Answer

Not in this bounded slice. The current profile can emit call-containing old-field roots, but it cannot yet emit a true call-result old field without changing the profile's function-signature contract.

The current deterministic root from `1046` is intentionally only an approximation:

- the overwritten field is `block (result i32) { call $self; i32.const ... }`;
- the call is a void side effect;
- the field value is the following constant, not the direct call result.

A true call-result root would require a callable helper whose signature returns the field type, for example `(func (result i32))` or an imported/direct helper `(param i32) (result i32)` with suitable arguments. The dedicated HSO profile currently fixes `max_params: 0`, `max_results: 0`, `max_imports: 0`, and disables the normal call generators. Its deterministic HSO roots therefore rely on the existing no-param/no-result defined functions and ad hoc calls that the profile inserts itself.

## Current artifact evidence

After refreshing the native compare binary with:

```sh
moon build --target-dir target --target native --release src/cmd
```

I emitted one current dedicated-profile case:

```sh
rm -rf .tmp/hso-profile-current-inspect
moon run src/fuzz -- --emit-gen-valid-batch --count 1 --seed 0x5eed \
  --out-dir .tmp/hso-profile-current-inspect \
  --gen-valid-profile heap-store-optimization \
  --manifest .tmp/hso-profile-current-inspect/manifest.json
wasm-tools print .tmp/hso-profile-current-inspect/gen-valid-000001.wasm \
  > .tmp/hso-profile-current-inspect/gen-valid-000001.wat
```

The emitted artifact has only the void function type:

```text
(type (;0;) (func))
```

and its call-bearing HSO profile roots call that void type, while result-producing wrappers use surrounding `block (result i32)` / `try_table (result i32)` constants. Grepping the artifact showed `call`, `call_indirect`, and `call_ref`, but no callable type with a result.

## Classification

This is a generated-profile coverage blocker, not a Starshine HSO behavior non-goal and not evidence that the source-backed call-result families are complete. Focused HSO tests still cover direct-call, `call_indirect`, `call_ref`, and tail-call result-wrapper old-field boundaries; the dedicated profile simply lacks a true random/deterministic old-field root where the overwritten field value is produced directly by the call instruction.

## Reopening criteria

Reopen this blocker when one of these is acceptable:

- split the HSO profile into a second callable-result subprofile with at least one no-param result helper;
- add an HSO-only imported helper and document that the dedicated profile is no longer import-free;
- add deterministic helper functions outside the ordinary profile signature budget; or
- safely raise `max_results` / call feature settings without destabilizing existing no-param/no-result roots and table/ref.func assumptions.

Any reopening should add a feature-floor test that distinguishes a real call-result old field from `1046`'s value-block approximation, then rerun focused fuzz, a dedicated-profile smoke with `--normalize local-cleanup-debris`, and a direct compare smoke.
