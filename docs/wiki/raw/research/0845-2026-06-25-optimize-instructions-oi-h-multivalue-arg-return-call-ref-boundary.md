---
kind: research
status: supported
created: 2026-06-25
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md
  - ../../../binaryen/passes/optimize-instructions/wat-shapes.md
  - ../../../../src/passes/optimize_instructions.mbt
  - ../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-H multi-result argument `return_call_ref` boundary

## Summary

This slice extends the existing multi-result argument select-of-`ref.func` `call_ref` boundary to the tail-call spelling.

Binaryen `version_130` can lower a `return_call_ref` whose already-evaluated arguments come from a multi-result producer and whose callee is selected between direct `ref.func` targets. It localizes the pair-producing call through a tuple scratch plus scalar locals, then emits direct `return_call` arms inside an `if`.

Starshine's current OI-H call_ref localizer intentionally proves only scalar single-result call arguments. It does not yet have a tuple-scratch localization helper that can split a multi-result producer safely while preserving evaluation order. The public fixture now keeps the `return_call_ref` / `select` / `ref.func` shape explicitly instead of hiding the unsupported tail-call subcase inside the broader boundary.

No pass implementation change was made.

## Binaryen oracle

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-h-multivalue-arg-select-return-probe.wat -o -
```

Observed output:

- introduces a tuple scratch local for `call $pair`;
- extracts both scalar argument lanes into locals;
- lowers the selected direct targets to an `if` with `return_call $a` / `return_call $b` arms.

## Starshine coverage

Updated focused coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps multi-result argument select call_ref boundary`

The test now covers both ordinary `call_ref` and `return_call_ref` public-core forms. It asserts that the tail-call fixture still contains `return_call_ref`, `select`, `ref.func`, and the multi-result producer call, and does not pretend to have directized to `return_call` arms.

## Validation

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*multi-result argument select call_ref*'` passed `1/1`.

Broader OI-H validation is recorded in the committing slice.

## Remaining OI-H work

This is a boundary/status slice only. Broad OI-H work remains open for tuple-scratch localization, broader multivalue argument handling, and any further source-backed known-target forms beyond the covered direct `ref.func`, `table.get`, select, call-indexed table, and fallthrough-known subsets.
