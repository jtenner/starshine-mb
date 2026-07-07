# OptimizeInstructions br_if equality blocker

Date: 2026-07-07

## Question

Can the next fact-driven OI slice widen `OiConsecutiveInputEqualityFact` to cover Binaryen v130's value-carrying left-`br_if` fallthrough case for trap-relaxed same-address `memory.copy`?

## Binaryen source fact

Binaryen v130 `OptimizeInstructions::areConsecutiveInputsEqual` has an explicit left-input loop for this case in `.tmp/binaryen-version130/OptimizeInstructions.cpp`:

- it calls `Properties::getFallthrough(..., FallthroughBehavior::NoTeeBrIf)`;
- when the current left fallthrough is a conditional `Break` with a payload, it walks the `br_if` condition with `EffectAnalyzer`;
- it continues equality on the branch payload;
- the branch effect itself is ignored because a taken branch skips the parent expression being optimized.

That means a source-level shape like a TNH `memory.copy(br_if $exit payload condition, payload, size)` can be equal if the payload and adjacent source are `ExpressionAnalyzer::equal` and the condition effects are not ordered before the right value.

## Probe

Local probe `.tmp/oi-brif-equality-probe.wat`:

```wat
(module
  (memory 1)
  (func (export "f") (param $addr i32) (param $size i32) (param $cond i32)
    (block $exit (result i32)
      local.get $addr
      local.get $cond
      br_if $exit
      local.get $addr
      local.get $size
      memory.copy
      i32.const 0)
    drop))
```

Binaryen command:

```sh
wasm-opt .tmp/oi-brif-equality-probe.wat --optimize-instructions -S --all-features --traps-never-happen -o -
```

Binaryen output drops the same-address `memory.copy` under TNH and preserves the value-carrying `br_if`, source operand, and size as drops before the replacement result.

## Starshine blocker

A red-first Starshine public-pipeline test for the same WAT did not reach a normal residual `memory.copy` assertion. The pass aborted inside HOT verification while `optimize-instructions` requested effects for the lifted value-carrying `br_if` shape:

```text
hot_verify_all_or_abort
cfg_build
cache_get_or_build_cfg
cache_get_or_build_effects
pass_require_effects
optimize_instructions_node_effects_are_pure
optimize_instructions_try_collapse_dropped_unreachable_block
optimize_instructions_visit_node
```

Because the blocker is in HOT/pass verification rather than the OI equality classifier alone, widening `OiConsecutiveInputEqualityFact` now would create an untestable or aborting public behavior path. The code therefore keeps `HotOp::BrIf` as an explicit left-fallthrough equality boundary with this note as the reopening reference.

## Reopening criteria

Reopen this OI-G equality slice when one of these is true:

1. HOT CFG/effects verification accepts value-carrying `br_if` operands in the reduced public WAT above.
2. A safe HOT-only fixture can express the same value-carrying `br_if` without bypassing required verification.
3. A different represented visitor site exposes Binaryen's direct `Break` payload equality fact without the value-branch verifier failure.

Once reopened, implement a real fact rather than a local special case: `OiLeftFallthroughInputFact` should peel `BrIf` payload child 0, add the condition child's effects/write ids to the after-value interference fields, reject unsupported condition control conservatively, and keep the existing `OiConsecutiveInputEqualityFact::proves_equal` ordered-effect check as the single consumer.
