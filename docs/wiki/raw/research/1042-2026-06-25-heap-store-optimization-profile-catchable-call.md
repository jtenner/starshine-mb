# Heap Store Optimization Catchable Direct-Call Profile Coverage

Date: 2026-06-25

## Summary

Extended the dedicated `heap-store-optimization` GenValid profile with a deterministic catchable result-typed `try_table` wrapper containing a direct `call`. This adds generated coverage for the broader call-bearing wrapper surface without pretending the still-open `call_indirect` / `call_ref` generator variants are covered.

The generated root uses the current no-param/no-result function as a void callable, then produces an i32 result for the wrapper:

```wat
memory.size
ref.null eq
struct.new $struct
local.set $local
block
  try_table (result i32) (catch_all 0)
    call $current
    i32.const 129
  end
  drop
end
local.get $local
i32.const 130
struct.set $struct 0
```

The wrapper is catchable and call-bearing, so it exercises a broader generated HSO-G/F barrier family than the existing pure/store/fill result wrappers. It intentionally remains a direct-call root only; indirect-call and typed-function-reference roots still need dedicated generator work and compare evidence.

## Test And Profile Coverage

Strengthened `src/fuzz/main_wbtest.mbt` red-first to require a `call` opcode in the HSO profile artifact. The test failed before the generator update because the dedicated profile had no direct-call root. `src/validate/gen_valid.mbt` now appends the deterministic catchable direct-call result wrapper when the current generated function has a no-param/no-result signature and tags are available.

## Evidence

- Red-first profile artifact test failed before the generator update because the HSO profile artifact lacked `call`.
- After the generator update:
  - `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed (`92/92`).
  - `moon fmt` passed.
  - `moon build --target-dir target --target native --release src/cmd` passed with the existing `src/passes/pass_manager.mbt` unused-function warnings and refreshed `target/native/release/build/cmd/cmd.exe`.
  - Dedicated profile smoke:
    - `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-catchable-call-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
    - Compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `0` hits / `20` misses.
  - Direct smoke:
    - `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-catchable-call-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`
    - Compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Classification

This is generated profile coverage for catchable direct-call result wrappers. It is not an output-shape deferral and not a broad closure of all call-bearing generated surfaces.

Remaining generated wrapper gaps include `call_indirect`, `call_ref`, mutable descriptor result-wrapper old-field variants, call-valued generated old-field variants, and broader descriptor/control combinations. Those remain open for HSO-D/F/G/H until they have their own generator roots, focused tests or blockers, and compare evidence.
