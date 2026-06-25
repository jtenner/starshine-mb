---
kind: research
status: partially-superseded
created: 2026-06-25
sources:
  - ./1046-2026-06-25-heap-store-optimization-profile-call-old-field.md
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/fuzz/main_wbtest.mbt
---

# HSO generated call-result old-field blocker

Partial supersession: `1054` adds the direct-call-result generated floor with an HSO-only no-param `(result i32)` helper. The remaining blocker scope is generated `call_indirect` result, `call_ref` result, descriptor/mutable-descriptor, and tail-call old-field variants.

Question: should the dedicated `heap-store-optimization` GenValid profile grow a true call-result old-field root now, instead of the `1046` value-block approximation?

## Answer

Not in the original bounded slice. As of `1054`, the profile can emit a true direct-call-result old field through an HSO-only no-param `(result i32)` helper. The remaining generated-profile blocker is the broader indirect/ref/descriptor/tail-call call-result old-field surface.

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

Remaining reopening criteria:

- add generated true `call_indirect` result old fields without destabilizing the current table/ref.func assumptions;
- add generated true `call_ref` result old fields;
- add generated descriptor/mutable-descriptor true call-result old fields; or
- add generated tail-call old-field siblings where the constructor field is not merely bottom/unreachable as classified in `1053`.

Each reopening should add a feature-floor test that distinguishes the new real call-result old-field family from `1046`'s value-block approximation and from `1054`'s direct-call floor, then rerun focused fuzz, a dedicated-profile smoke with `--normalize local-cleanup-debris`, and a direct compare smoke.
