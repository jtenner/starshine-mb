# SGO dominance lit regression slice

_Date:_ 2026-05-23  
_Status:_ filed into living SGO docs/backlog

## Question

After the 0574 next-breadth inventory pointed `[SGO]003` at official `simplify-globals-dominance.wast` shapes, compare that lit file against Starshine's runtime propagation tests and add the smallest missing regression without claiming full Binaryen `SimplifyGlobals.cpp` parity.

## Sources and probes

Primary source:

- Binaryen `version_129` `test/lit/passes/simplify-globals-dominance.wast`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/simplify-globals-dominance.wast>

Local anchors:

- `docs/wiki/raw/research/0574-2026-05-23-sgo-next-breadth-probe-inventory.md`
- `src/passes/simplify_globals_optimizing_test.mbt`
- `src/passes/simplify_globals_optimizing.mbt`

Binaryen probe command:

```sh
/usr/local/bin/wasm-opt --all-features --simplify-globals-optimizing -S -o - .tmp/sgo-dominance-before-call-used-probe.wat
```

Probe fixture, adapted from the official lit so the branch is not folded away and the pre-call read remains value-observable:

```wat
(module
  (global $global (mut i32) (i32.const 0))
  (func $test (param $p i32) (result i32)
    (global.set $global (i32.const 10))
    (if (result i32) (local.get $p)
      (then
        (i32.add
          (global.get $global)
          (call $test (i32.const 0))))
      (else
        (i32.const 0))))
  (export "test" (func $test)))
```

Binaryen rewrote the dominated pre-call read to `i32.const 10`, preserved the recursive call, and did not need to infer anything after the call. In the direct official lit, Binaryen also preserves the read after the call and preserves the else-arm read as a TODO/negative.

## Local mapping

Starshine already had broad runtime propagation coverage for:

- straight-line `global.set const -> global.get`;
- adjacent and nested plain blocks;
- call barriers;
- then-body reads with and without else arms;
- nested then blocks;
- else-arm conservatism;
- post-if join conservatism.

The missing source-shaped regression was the exact dominated-then/recursive-call flavor from the official dominance lit: a read in the then body may be rewritten before a recursive call, but the recursive call remains a barrier for later facts.

Added test:

- `simplify-globals-optimizing rewrites dominated then reads before recursive call barriers`

The test is behavior-preserving for the current implementation: it passed immediately after being added because `sgo_rewrite_runtime_trace_expr_with_facts` already propagates facts into then bodies and clears facts at calls. It is still useful as a lit-aligned guardrail tying Starshine's broader local tests back to Binaryen's official dominance file.

## Non-claims

- This is a regression/documentation slice, not a new rewrite implementation.
- It does not claim full SGO parity.
- It keeps the known dominance negatives unchanged: reads after calls remain barriers, else-arm reads remain conservative, and post-if facts are not inferred from branch-local writes.
