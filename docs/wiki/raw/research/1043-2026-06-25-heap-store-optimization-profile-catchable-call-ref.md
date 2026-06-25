# Heap Store Optimization Catchable `call_ref` Profile Coverage

Date: 2026-06-25

## Summary

Extended the dedicated `heap-store-optimization` GenValid profile with a deterministic catchable result-typed `try_table` wrapper containing a typed-function-reference `call_ref`. This complements research note `1042`'s direct-call root and covers another generated call-bearing wrapper surface.

The generated root uses the module's declared `ref.func` target when the target has no parameters and no results:

```wat
memory.size
ref.null eq
struct.new $struct
local.set $local
block
  try_table (result i32) (catch_all 0)
    ref.func $target
    call_ref $target_type
    i32.const 131
  end
  drop
end
local.get $local
i32.const 132
struct.set $struct 0
```

This is a generated `call_ref` wrapper root only. It does not cover `call_indirect`, mutable descriptor result-wrapper old-field variants, or call-valued generated old-field variants.

## Test And Profile Coverage

Strengthened `src/fuzz/main_wbtest.mbt` red-first to require `call_ref` in the HSO profile artifact. The test failed before the generator update because the dedicated profile had a direct `call` root but no `call_ref` root. `src/validate/gen_valid.mbt` now appends the deterministic catchable `call_ref` result wrapper when a declared no-param/no-result `ref.func` target is available.

## Evidence

- Red-first profile artifact test failed before the generator update because the HSO profile artifact lacked `call_ref`.
- After the generator update:
  - `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed (`92/92`).
  - `moon fmt` passed.
  - `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
  - Dedicated profile smoke:
    - `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-catchable-call-ref-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
    - Compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `0` hits / `20` misses.
  - Direct smoke:
    - `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-catchable-call-ref-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`
    - Compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Classification

This is generated profile coverage for catchable `call_ref` result wrappers. It is not a broad closure of all typed-function-reference HSO surfaces.

Remaining generated wrapper gaps include `call_indirect`, mutable descriptor result-wrapper old-field variants, call-valued generated old-field variants, and broader descriptor/control combinations. Those remain open for HSO-D/F/G/H until they have their own generator roots, focused tests or blockers, and compare evidence.
