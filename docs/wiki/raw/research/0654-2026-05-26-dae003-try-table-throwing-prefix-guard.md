# DAE003 try_table throwing-prefix guard

Date: 2026-05-26

## Scope

This recovery slice adds one more `[DAE003-F]` structured-carrier negative guard for non-adjacent `try_table` carriers.

The newly covered shape is a caller-local carrier whose `try_table` body contains a throwing/control-transfer prefix before a materializable constant leaf:

```wat
block $exit (result i32)
  try_table (result i32) (catch $e $exit)
    i32.const 99
    throw $e
    i32.const 88
  end
end
local.set 0
local.get 0
call $target
```

Starshine must preserve the target parameter for this shape. The body is not equivalent to the trailing constant leaf because `throw` transfers control through the catch; treating the final constant as the call actual would silently change behavior.

## Evidence

- Added focused test `dae-optimizing preserves try-table carrier with throwing prefix` in `src/passes/dae_optimizing_test.mbt`.
- `moon test src/passes` passed with `1411` tests.

No optimizer behavior changed; the existing structured-carrier recognizer already keeps this control-sensitive shape conservative.

## Classification

This is a negative-guard coverage slice, not a new positive materialization family. It narrows the remaining `[DAE003-F]` risk by pinning the throwing-prefix `try_table` boundary. Broader try/try_table positives remain deferred until they preserve exception/control behavior with focused tests and artifact/fuzz evidence.
