# SGO same-init and runtime guardrail tests

_Date:_ 2026-05-23  
_Status:_ filed into living SGO docs/backlog

## Question

After the 0574 next-breadth probe inventory found several expression-looking Binaryen negatives, pin the most useful local guardrails so future `[SGO]003` work does not accidentally broaden same-init or runtime fact tracking beyond the oracle-backed surface.

## Sources and probes

Primary local source:

- [`0574`](./0574-2026-05-23-sgo-next-breadth-probe-inventory.md)

Binaryen probe commands:

```sh
/usr/local/bin/wasm-opt --all-features --simplify-globals-optimizing -S -o - .tmp/sgo-alias-init-direct-literal-one-shot.wat
/usr/local/bin/wasm-opt --all-features --simplify-globals-optimizing -S -o - .tmp/sgo-alias-init-direct-literal-same-func.wat
/usr/local/bin/wasm-opt --all-features --simplify-globals-optimizing -S -o - .tmp/sgo-block-runtime-set-negative.wat
```

## Added tests

### Alias initializer plus direct literal write stays one-shot mutable

Fixture shape:

```wat
(module
  (global $c i32 (i32.const 7))
  (global $g (mut i32) (global.get $c))
  (func (result i32)
    (global.set $g (i32.const 7))
    (global.get $g)))
```

Binaryen rewrites `$g`'s initializer to `i32.const 7` and can replace the same-function runtime read with `i32.const 7`, but it still preserves `$g` as mutable and keeps the direct literal `global.set` in the one-shot run. Starshine now pins the same local boundary with:

- `simplify-globals-optimizing keeps alias-init direct literal same-init write one-shot`

This prevents future same-init broadening from treating alias canonicalization plus direct literal write as a one-run removable write without separate oracle evidence.

### Block-wrapped runtime set operand does not become a runtime fact

Fixture shape:

```wat
(module
  (global $g (mut i32) (i32.const 0))
  (func (result i32)
    (global.set $g
      (block (result i32)
        (i32.const 5)))
    (global.get $g)))
```

Binaryen preserves the block-wrapped set operand and the later `global.get`. Starshine now pins the same guardrail with:

- `simplify-globals-optimizing keeps block-wrapped runtime set operands conservative`

This prevents future runtime-trace work from treating cleanup-obvious block constants as current facts unless Binaryen first proves the exact shape as a positive.

## Existing local coverage confirmed

The block-wrapped same-init write with a real later read from 0574 was already covered by:

- `simplify-globals-optimizing keeps result-block same-as-init writes`

## Non-claims

- This was a guardrail test/docs slice, not a new rewrite implementation.
- It does not claim full SGO parity.
- It keeps `[SGO]003` active/partial and keeps broad same-init expression equivalence deferred.
