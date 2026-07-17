---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./1630-2026-07-16-daeo-forwarded-cycle-priority.md
  - ./1602-2026-07-14-daeo-payoff-local-order-final-matrix.md
---

# DAEO Func 8429 payoff-local convergence

## Goal

Reduce defined Func `8429` / absolute Func `8450` to at most Binaryen v130's `25742`-byte canonical body while preserving optimizing-only scheduling, plain-DAE separation, validity, whole-module size, runtime, and one-invocation convergence.

The accepted pre-slice artifact was `.tmp/daeo-func8429-typeidx-block-result-20260717/out.wasm`: raw `3205256`, canonical `3266798`, module gap `+4342`, and Func `8429` body `25791` (`+49`).

## Attribution

A post-finalization public `reorder-locals` probe reduced Func `8429` to `25758` (`+16`) by lowering local-index immediate cost after all DAEO cleanup had finished. Earlier in-pipeline reorder probes were followed by cleanup that changed the access profile and did not retain this gain.

The remaining semantic delta was not another local-order heuristic. Canonical WAT comparison found sixteen repeated calls from the selected payoff callee to one private direct callee. Starshine passed identical `i32.const 2` and `i32.const 48` operands at every owned callsite; Binaryen removed both read-only parameters and materialized the constants in the callee. The existing exact-literal transaction already proved the required ownership, call-count, uniform-value, read-only-parameter, callsite-rewrite, and signature-rewrite invariants. The gap was large-module candidate scheduling.

## Retained implementation

- The highest-ranked dropped-result payoff callee is retained as the only post-finalization broad local-order candidate.
- Its body is deep-cloned before `rl_rewrite_func` remaps nested arrays, preventing rollback aliasing.
- Public access-frequency/first-use `reorder-locals` runs after final cleanup and type pruning, validates the selected definition, and has no later body mutation.
- Before payoff cleanup, a bounded raw stack-order prefilter collects only defined direct callees whose call is immediately preceded by a scalar literal. The existing exact-literal verifier then scans authoritative current call facts only for those plausible callees.
- On the artifact this selects caller def `8429` and callee def `10750`, removes the two uniform scalar parameters, and deletes the corresponding call operands everywhere.
- The exact-literal signature change exposes one direct-GC batch and the next source-backed broad adjacent root. Both are completed in the same invocation before the ordinary payoff cleanup, preserving byte-identical second-run convergence.
- Plain `dead-argument-elimination` does not schedule any of these optimizing-only payoff steps.

The focused regression was red first: a broad payoff fixture retained mixed live `i64`/`i32` locals and a private two-parameter callee receiving the same adjacent scalar literals. Before implementation DAEO left both parameters and type-stable local order; afterward it removes the parameters, frequency-orders the finalized mixed locals, validates, and plain DAE retains the original signature.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted output: `.tmp/daeo-func8429-complete-converged-20260717/out.wasm` and `.canonical.wasm`.

- raw size: `3205376` bytes;
- canonical size: `3266662` bytes;
- Binaryen-v130 canonical reference: `3262456` bytes;
- canonical module gap: `+4206`, below the established `+10000` boundary and `136` bytes smaller than the pre-slice accepted canonical artifact;
- Func `8429` canonical body: `25694` bytes, `48` bytes smaller than Binaryen and `97` bytes smaller than the pre-slice body;
- Func `9347` canonical body remains `14706` bytes;
- raw SHA-256: `e3fa72d4d64450d41fffe80f07d3a0eece852ed83e71b1f68d760a9652e8719f`;
- canonical SHA-256: `d0410333903d1a90d0dcb10293c8435bc77d0d296badc28f063a6c21910d0280`;
- native SHA-256: `6057190705590291c3deeca348a48276aa43d7bd9d2980bd3400152f9ba74122`;
- traced DAEO time: `69911125us`, improving the pre-slice `71492436us` trace by about `2.2%`;
- a second DAEO invocation is byte-identical in raw and canonical output.

The retained trace records:

```text
pass[dae-optimizing]:payoff-direct-callee-exact-literal caller_def=8429 callee_def=10750
pass[dae-optimizing]:payoff-post-literal-direct-gc primary_def=7113
pass[dae-optimizing]:payoff-post-literal-adjacent root_def=7004 defs=[7007, 7008] payoff=2131
pass[dae-optimizing]:payoff-final-reorder defs=[8429, 9347] accepted_defs=1 ...
```

## Validation

- red-first focused DAEO fixture observed the private literal callee remain at two parameters before implementation;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- simplify-locals focused tests: `65/65`;
- DAE white-box tests: `208/208`;
- DAEO focused tests: `335/335`;
- full `moon test`: `8881/8881`;
- native release build: passed;
- `wasm-tools validate --features all`: passed for first and converged second outputs;
- dedicated DAEO GenValid smoke: `1000/1000` normalized, zero mismatches or failures;
- regular GenValid smoke: `1000/1000` normalized, zero mismatches or failures.

The full four-lane closeout matrix was not rerun for this focused artifact slice. The audit remains active on other function-body and whole-module parity gaps plus the documented pre-slot public optimize/shrink/O4z blockers, but the requested Func `8429` body target is complete.
