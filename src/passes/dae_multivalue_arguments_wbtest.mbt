///|
test "DAE multi-value actuals preserve the caller stack prefix" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func $pair (result i32 i32) i32.const 5 i32.const 6)
      #|   (func $target (param i32 i32) (result i32) i32.const 100)
      #|   (func $run (export "run") (result i32)
      #|     i32.const 1 call $pair call $target i32.add)
      #|   (func call $run i32.const 101 i32.ne if unreachable end))
    ),
  )
  dae_tail_actuals_execute(input)
  for pass_name in ["dae", "dae-optimizing"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
    @validate.validate_module(output).unwrap()
    dae_tail_actuals_execute(output)
    assert_eq(dae_wb_param_count(output, 1), 0)
  }
}

///|
test "DAE localized multi-value actuals remove each lane without changing the other" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func $pair (result i32 i32) i32.const 5 i32.const 6)
      #|   (func $target (param i32 i32) (result i32) local.get 0)
      #|   (func (result i32) i32.const 1 call $pair call $target i32.add))
    ),
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[2]
  let types = dae_collect_func_type_indices(input)
  for remove in [[true, false], [false, true], [true, true]] {
    let rewritten = dae_rewrite_callsite_with_localization_at(
      body,
      2,
      remove,
      [@lib.ValType::i32(), @lib.ValType::i32()],
      0,
      0,
      input,
      types,
    ).unwrap()
    assert_eq(rewritten.instrs[0], @lib.Instruction::i32_const(1))
    assert_eq(
      rewritten.instrs[1],
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    )
    assert_eq(rewritten.instrs[rewritten.new_call_idx], body[2])
  }
}

///|
test "DAE multi-value lane removal retains live arguments and ambient lanes" {
  for
    (params, result, expected) in [
      ("i32 i32", "local.get 0", 6),
      ("i32 i32", "local.get 1", 7),
      ("i32", "i32.const 100", 106),
    ] {
    let adds = if params == "i32" { "i32.add i32.add" } else { "i32.add" }
    let input = pass_test_module_from_wat(
      "(module (func $pair (result i32 i32) i32.const 5 i32.const 6) " +
      "(func $target (param \{params}) (result i32) \{result}) " +
      "(func $run (export \"run\") (result i32) i32.const 1 call $pair call $target \{adds}) " +
      "(func call $run i32.const \{expected} i32.ne if unreachable end))",
    )
    for pass_name in ["dae", "dae-optimizing"] {
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
        pass_name,
      ]).unwrap()
      @validate.validate_module(output).unwrap()
      dae_tail_actuals_execute(output)
      assert_eq(
        dae_wb_param_count(output, 1),
        if params == "i32" {
          0
        } else {
          1
        },
      )
    }
  }
}

///|
test "DAE multi-value kept lanes use distinct scratch slots and reuse them at the next call" {
  let input = pass_test_module_from_wat(
    "(module (func $triple (result i32 i32 i32) i32.const 4 i32.const 5 i32.const 6) " +
    "(func $target (param i32 i32 i32)) (func call $triple call $target))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[2]
  let types = dae_collect_func_type_indices(input)
  let first = dae_rewrite_callsite_with_localization_at(
    body,
    1,
    [true, false, false],
    Array::make(3, @lib.ValType::i32()),
    0,
    0,
    input,
    types,
  ).unwrap()
  assert_eq(first.scratch_local_types, Array::make(2, @lib.ValType::i32()))
  assert_eq(first.instrs, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
  let second = dae_rewrite_callsite_with_localization_at(
    body,
    1,
    [true, false, false],
    Array::make(3, @lib.ValType::i32()),
    0,
    0,
    input,
    types,
    existing_scratch_local_types=first.scratch_local_types,
  ).unwrap()
  assert_eq(second.scratch_local_types, first.scratch_local_types)
  assert_eq(second.instrs, first.instrs)
}

///|
test "DAE GC narrowing uses distinct result lanes from shared typed controls" {
  for control in ["block", "loop", "if"] {
    let producer = if control == "if" {
      "i32.const 0 (if (type $carrier) " +
      "(then i32.const 9 struct.new_default $left struct.new_default $right) " +
      "(else i32.const 11 struct.new_default $left struct.new_default $right))"
    } else {
      "(\{control} (type $carrier) i32.const 9 struct.new_default $left struct.new_default $right)"
    }
    let input = pass_test_module_from_wat(
      "(module (type $base (sub (struct))) " +
      "(type $left (sub final $base (struct))) " +
      "(type $right (sub final $base (struct))) " +
      "(type $carrier (func (result i32 (ref $left) (ref $right)))) " +
      "(func $target (param i32 (ref null $base) (ref null $base)) (result i32) " +
      "local.get 1 ref.is_null local.get 2 ref.is_null i32.add local.get 0 i32.add) " +
      "(func (export \"run\") (result i32) i32.const 1 " +
      producer +
      " call $target i32.add))",
    )
    let output = dae_run_module_pass(input)
    @validate.validate_module(output).unwrap()
    let @lib.FuncType(params, _) = dae_resolve_func_type(
      output,
      dae_collect_func_type_indices(output),
      0,
    ).unwrap()
    assert_eq(params, [
      @lib.ValType::i32(),
      @lib.ValType::ref_type(
        @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
      ),
      @lib.ValType::ref_type(
        @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(2U))),
      ),
    ])
  }
}

///|
test "DAE GC narrowing keeps scalar locals beside multi-value call lanes" {
  for local_after_pair in [false, true] {
    let operands = if local_after_pair {
      "call $pair local.get 0"
    } else {
      "local.get 0 call $pair"
    }
    let input = pass_test_module_from_wat(
      "(module (type $base (sub (struct))) " +
      "(type $left (sub final $base (struct))) " +
      "(type $right (sub final $base (struct))) " +
      "(import \"host\" \"pair\" (func $pair (result (ref $left) (ref $right)))) " +
      "(func $target (param (ref null $base) (ref null $base) (ref null $base)) (result i32) " +
      "local.get 0 ref.is_null local.get 1 ref.is_null i32.add local.get 2 ref.is_null i32.add) " +
      "(func (export \"run\") (param (ref $left)) (result i32) " +
      "\{operands} call $target))",
    )
    let output = dae_run_module_pass(input)
    @validate.validate_module(output).unwrap()
    let @lib.FuncType(params, _) = dae_resolve_func_type(
      output,
      dae_collect_func_type_indices(output),
      1,
    ).unwrap()
    let left = @lib.ValType::ref_type(
      @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
    )
    let right = @lib.ValType::ref_type(
      @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(2U))),
    )
    assert_eq(
      params,
      if local_after_pair {
        [left, right, left]
      } else {
        [left, left, right]
      },
    )
  }
}

///|
test "DAE GC narrowing follows result lanes below a dropped trailing lane" {
  let input = pass_test_module_from_wat(
    "(module (type $base (sub (struct))) " +
    "(type $leaf (sub final $base (struct))) " +
    "(type $carrier (func (result (ref $leaf) i32))) " +
    "(func $target (param (ref null $base)) (result i32) local.get 0 ref.is_null) " +
    "(func (export \"run\") (result i32) " +
    "(block (type $carrier) struct.new_default $leaf i32.const 9) drop call $target))",
  )
  let output = dae_run_module_pass(input)
  @validate.validate_module(output).unwrap()
  let @lib.FuncType(params, _) = dae_resolve_func_type(
    output,
    dae_collect_func_type_indices(output),
    0,
  ).unwrap()
  assert_eq(params, [
    @lib.ValType::ref_type(
      @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
    ),
  ])
}
