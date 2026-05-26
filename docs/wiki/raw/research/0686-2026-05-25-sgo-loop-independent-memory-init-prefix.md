# SGO loop independent memory-init prefix

## Context

Active slice: `[SGO]003C5` loop-specific FlowScanner parity for `simplify-globals-optimizing`.

The previous loop-prefix slices admitted exact Binaryen-positive independent side-effect prefixes before a yielded candidate-global read inside a non-branching value loop: `global.set`, `local.set`, scalar stores, `table.set`, `memory.fill`, and `memory.copy`. This note covers the next narrow bulk-memory sibling: `const; const; const; memory.init <data>; global.get <candidate>`.

## Binaryen probe

Fixture:

```wat
(module
  (memory (export "mem") 1)
  (data $d "abcd")
  (global $once (mut i32) (i32.const 0))
  (func (export "run")
    loop (result i32)
      i32.const 0
      i32.const 0
      i32.const 4
      memory.init $d
      global.get $once
    end
    if
      i32.const 1
      global.set $once
    end))
```

Command:

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-loop-memory-init-probe.wat -o .tmp/sgo-loop-memory-init-probe.opt.wat
```

Observed result: Binaryen makes `$once` immutable and removes the `global.get` / `global.set` fake guard while preserving `memory.init $d`. This is the same narrow loop-prefix contract as the prior `memory.fill` and `memory.copy` slices: the side effect is independent because all three consumed operands are constants.

## Starshine change

- Added focused positive regression `simplify-globals-optimizing removes loop-wrapped independent memory-init effect prefixes`.
- Added paired negative regression `simplify-globals-optimizing keeps loop-wrapped candidate-derived memory-init prefixes conservative`, where the destination operand is `global.get $once`.
- Extended `sgo_loop_independent_prefix_triple_effect_matches(...)` to accept `@lib.MemoryInit(_, _)` alongside `memory.fill` and `memory.copy`.

TDD evidence: after adding tests first, `moon test src/passes` failed on the positive regression because `$once` remained mutable. After the implementation, `moon test src/passes` passed (`1629/1629`), with only pre-existing DAE/pass-manager unused warnings.

## Validation

- `moon test src/passes` passed (`1629/1629`).
- `moon fmt` passed.
- `moon info` passed, with the established DAE/pass-manager unused warnings.
- Full `moon test` passed (`3705/3705`), with the same established warnings.
- Direct SGO fuzz:

```sh
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-memory-init-0686-10000
```

Result: `6759/10000` compared before the configured `20` Binaryen/tool command-failure stop, `6759` normalized matches, `0` mismatches, `0` Starshine validation failures. Command failures were the established Binaryen/tool classes: `17` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.

## Classification

No Starshine semantic or validation mismatches were found. The 20 failures are classified as tool/Binaryen command failures, matching the established direct SGO fuzz frontier for this harness/seed.

## Remaining work

`[SGO]003C5` remains active for future exact loop-prefix shapes only when backed by fresh Binaryen-positive probes and paired negatives. Obvious neighboring shapes include other bulk/table operations such as `table.fill`, `table.init`, `table.copy`, and operandless `data.drop` / `elem.drop`, but each needs its own exact fixture and guardrail before implementation.
