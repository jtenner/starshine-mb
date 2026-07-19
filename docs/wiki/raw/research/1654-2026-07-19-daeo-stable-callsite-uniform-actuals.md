---
kind: research
status: current
last_reviewed: 2026-07-19
sources:
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../binaryen/passes/dae-optimizing/binaryen-strategy.md
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/dead_argument_elimination_wbtest.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ./1653-2026-07-19-daeo-unified-call-facts-tail-boundaries-and-filtered-validation.md
---

# DAEO stable-callsite uniform actuals

## Scope

This slice consumes the stable structured callsite paths introduced in note `1653` for the first transform analysis: uniform-actual collection when the callee also has inactive direct calls in dead suffixes.

The previous caller-scope walker used current direct-caller ownership but rescanned every syntactic call in each owning body. An inactive call after `unreachable` could therefore poison an otherwise uniform active actual. The module boundary scanner already distinguished active and inactive callsites, but the value analysis did not consume that distinction.

## Implementation

For modules below the exact-path threshold, uniform-actual dispatch checks the target's existing `DaeFunctionInfo.calls` list for an inactive direct call. Artifact-scale modules bypass even that per-target scan and retain the caller-scope walker.

`dae_resolve_stable_callsite_scope` resolves the scanner's path encoding through:

- block child `0`;
- loop child `1`;
- if-then child `2`;
- if-else child `3`;
- `try_table` body child `4`.

It returns the exact containing instruction sequence, call index, and nested entry-stack arity. `dae_collect_uniform_const_actuals_from_function_infos` then evaluates only active non-tail callsites and reuses the existing stack-slice, forwarded-constant, immutable-global, and local-carrier logic.

`dae_collect_uniform_const_actuals_from_current_call_facts` selects the stable-path collector only when inactive calls exist. Artifact-scale modules currently retain the caller-scope walker because resolving every nested path without cached scope handles regressed fixed-point runtime; the stable path is enabled below `1024` total functions. This is a measured performance guard and remains an explicit removal target once function information owns cached scope/stack evidence.

## Red/green regression

The focused fixture has:

- one private `(param i32) -> i32` callee that reads its parameter;
- one active call with actual `7`;
- `unreachable`;
- one inactive call with conflicting actual `8`.

Before implementation, `dae-optimizing` retained the parameter (`1 != 0`). After implementation, it removes the parameter and both tools produce the same canonical shape:

```wat
(func $target
  nop)
(func (result i32)
  call $target
  unreachable)
```

Binaryen v131 and Starshine outputs are textually identical on `.tmp/daeo-inactive-uniform-actual-check.wat` after their respective `dae-optimizing` runs.

White-box coverage also proves that:

- the target function info reports an inactive call;
- the stable collector ignores the inactive conflicting actual;
- the surviving uniform value is `i32.const 7`.

## Validation and performance

- `src/passes`: `6171/6171`; full Moon: `9649/9649` after this slice.
- Direct execution over the first `128` targeted-profile inputs completes `128/128` with no Starshine command stderr or timeout under a per-case `20s` bound.
- Two compare-harness attempts stopped at `95` compared cases under the outer command timeout, with `72` matches, `23` prior-family differences, and zero reported validation/property/generator/command failures. Those partial runs are diagnostic only and do not replace note `1653`'s complete `823/201` aggregate.
- Current native SHA-256: `582f584c886d3afd70150a402465d3feeec811d02d3946a504fa06a35e58f321`.
- On the note-`1653` fixed-point artifact, output remains byte-identical at `3,121,651` raw bytes. One current untraced observation is `52.436s`, so note `1653`'s `40.624s` second-invocation checkpoint is not improved and convergence performance remains red.

An unrestricted stable-path collector was rejected for artifact-scale use: fixed-point tracing increased the reverse-exact-literal lane from the prior approximately `15.7s` observation to about `19.4s`, and pass wall time rose. Restricting inactive-call detection to sub-threshold modules avoids enlarging every artifact-scale function-info record, but the scope-path resolver still lacks cached scope/entry-stack handles. The `<1024` guard restores the old artifact-scale collector algorithm while retaining the semantic repair on generated and ordinary modules; it does not establish runtime parity, and the current fixed-point observation remains slower than note `1653`.

## Remaining work

1. Replace path arrays with stable callsite records that cache the containing scope identity, instruction index, and entry-stack arity.
2. Remove the artifact-scale guard after proving stable lookup faster than caller-scope rescanning.
3. Consume exact callsites in operand rewriting, dropped-result repair, localization-pending tracking, and result removal.
4. Complete a fresh `1024` targeted aggregate with the current binary; do not treat the two partial `95`-case runs as signoff.
5. Retain note `1653` as the current complete generated and fixed-artifact checkpoint until that rerun finishes.
