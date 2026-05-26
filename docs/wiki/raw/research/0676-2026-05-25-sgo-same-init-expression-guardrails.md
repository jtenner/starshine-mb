# SGO same-init expression guardrails

Date: 2026-05-25

## Question

For `[SGO]003B`, is there a fresh Binaryen-positive same-as-init expression grammar beyond Starshine's already-supported direct literal / `ref.null` / `ref.func` surface that should be implemented now?

## Sources and probes

Source context:

- `docs/wiki/raw/research/0574-2026-05-23-sgo-next-breadth-probe-inventory.md`
- `docs/wiki/raw/research/0576-2026-05-23-sgo-same-init-runtime-guardrails.md`
- `docs/wiki/raw/research/0658-2026-05-25-sgo-same-init-expression-closeout.md`
- `docs/wiki/raw/research/0675-2026-05-25-sgo-fact-table-source-audit.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`
- `src/passes/simplify_globals_optimizing.mbt`
- `src/passes/simplify_globals_optimizing_test.mbt`

Fresh Binaryen probes used the same pattern as earlier SGO inventories:

```sh
/usr/local/bin/wasm-opt --all-features --simplify-globals-optimizing -S -o - .tmp/sgo-probes/<probe>.wat
```

## Probe outcomes

### Arithmetic same-init expression: Binaryen negative

Shape:

```wat
(module
  (global $g (mut i32) (i32.const 7))
  (func $set
    (global.set $g
      (i32.add (i32.const 3) (i32.const 4))))
  (func $read (result i32) (global.get $g))
  (export "set" (func $set))
  (export "read" (func $read))
)
```

Binaryen preserved the mutable global, the arithmetic `global.set` operand, and the later `global.get`. This is not a behavior-positive same-init expression grammar.

### Select same-init expression: Binaryen negative

Shape:

```wat
(module
  (global $g (mut i32) (i32.const 7))
  (func $set
    (global.set $g
      (select (i32.const 7) (i32.const 8) (i32.const 1))))
  (func $read (result i32) (global.get $g))
  (export "set" (func $set))
  (export "read" (func $read))
)
```

Binaryen preserved the mutable global, the `select` operand, and the later `global.get`. This supports keeping value-computing expression equivalence out of same-init write removal unless a future exact positive is found.

### Alias initializer with matching global-get write: repeated-run sensitive, already covered

A one-shot run canonicalized the mutable global initializer from `global.get $c` to `i32.const 7` but preserved the write/read. A two-pass run removed the write and promoted the global immutable. Starshine already has a paired repeated-run guardrail for this shape, so no new implementation slice is needed here.

## Change

No optimizer behavior changed.

Added two focused guardrail tests in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing keeps arithmetic same-init expressions conservative`
- `simplify-globals-optimizing keeps select same-init expressions conservative`

These tests pin the fresh Binaryen-negative probes and keep future same-init work from treating folded arithmetic or `select` values as removable writes in the presence of later reads.

## Decision

`[SGO]003B` is accepted as evidence-gated / conservative for now.

Do not implement generic same-as-init expression equivalence for v0.1.0. The active same-init surface remains direct literals, `ref.null`, `ref.func`, and the already-pinned alias/repeated-run guardrails. Future same-init behavior work requires a new exact Binaryen-positive fixture plus paired negatives for block/result wrappers, provenance, trapping/effectful expressions, and object-identity-sensitive GC expressions.

## Validation

- `moon test src/passes` passed with `1612/1612` tests before docs closeout.
- `moon fmt` passed.
- `moon info` passed with the existing DAE unused-value warnings.
- Full `moon test` passed with `3688/3688` tests.

Direct SGO fuzz was not run for this guardrail-only slice because no matcher, transformation, registry, preset, or public behavior changed. The latest behavior-bearing SGO fuzz evidence remains `[SGO]003A` at `.tmp/pass-fuzz-sgo-fact-table-003a-10000` with `0` mismatches and `0` Starshine validation failures.

## Status

`[SGO]003B` is complete as a guardrail/evidence-gated slice. Full SGO parity remains active under `[SGO]003`; the next implementation target should move to `[SGO]003C` FlowScanner parity or another explicit Binaryen-positive child, not broad same-init expression matching.
