///|
test "DAE removes pure arithmetic arguments without localization or unused capture declarations" {
  let input = pass_test_module_from_wat(
    "(module (import \"m\" \"value\" (func $v (result i32))) (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) call $v drop i32.const 1 i32.const 7 i32.add local.get 0 call $h))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[1]
  let saved = @binary.encode_module(input).unwrap()
  let evidence = dae_rewrite_callsite_with_localization_at(
    body,
    body.length() - 1,
    [true, false],
    [@lib.ValType::i32(), @lib.ValType::i32()],
    0,
    1,
    input,
    dae_collect_func_type_indices(input),
  ).unwrap()
  assert_eq(evidence.localization_count, 0)
  assert_eq(evidence.localized_params, [false, false])
  assert_eq(evidence.scratch_local_types, [])
  let slices = dae_callsite_value_slice_evidence(
    body,
    body.length() - 1,
    2,
    0,
    input,
    dae_collect_func_type_indices(input),
  ).unwrap()
  let plan = dae_callsite_rewrite_plan(
    slices,
    [true, false],
    Some([@lib.ValType::i32(), @lib.ValType::i32()]),
  ).unwrap()
  assert_eq(
    dae_apply_callsite_rewrite_plan(body, plan, 1).unwrap().localized_params,
    [false, false],
  )
  assert_eq(plan.localized_params, [true, false])
  assert_eq(
    dae_apply_callsite_rewrite_plan(body, plan, 1).unwrap().instrs,
    evidence.instrs,
  )
  assert_eq(evidence.new_call_idx, 3)
  assert_eq(evidence.instrs, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
  for pass in ["dae", "dae-optimizing"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
    assert_eq(locals.length(), 0)
    assert_eq(caller, evidence.instrs)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE preserves localization for observable and potentially trapping arithmetic arguments" {
  for
    expression in [
      "call $v i32.const 7 i32.add", "i32.const 8 local.get 0 i32.div_s",
    ] {
    let input = pass_test_module_from_wat(
      "(module (import \"m\" \"value\" (func $v (result i32))) (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) \{expression} local.get 0 call $h))",
    )
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[1]
    let evidence = dae_rewrite_callsite_with_localization_at(
      body,
      body.length() - 1,
      [true, false],
      [@lib.ValType::i32(), @lib.ValType::i32()],
      0,
      1,
      input,
      dae_collect_func_type_indices(input),
    ).unwrap()
    assert_eq(evidence.localization_count, 1)
    assert_eq(evidence.scratch_local_types, [@lib.ValType::i32()])
    for i in 0..<3 {
      assert_eq(evidence.instrs[i], body[i])
    }
    assert_eq(
      evidence.instrs[3],
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    )
    for pass in ["dae", "dae-optimizing"] {
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
      @validate.validate_module(output).unwrap()
    }
  }
}

///|
test "DAE borrows suffix endpoints without including later calls or earlier live operands" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let saved = body.copy()
  assert_eq(
    dae_find_droppable_pure_stack_expr_start_from_end(body, None, 4, None),
    Some(1),
  )
  assert_eq(dae_find_droppable_pure_stack_expr_start(body, None), None)
  assert_eq(body, saved)
  // Intentionally invalid range endpoints must reject without reading the array.
  for end in [-1, 0, body.length() + 1] {
    assert_eq(
      dae_find_droppable_pure_stack_expr_start_from_end(body, None, end, None),
      None,
    )
  }
}

///|
test "DAE removes two pure arithmetic arguments around a live observable producer" {
  let input = pass_test_module_from_wat(
    "(module (import \"m\" \"value\" (func $v (result i32))) (func $h (param i32 i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 7 i32.add call $v local.get 0 i32.const 3 i32.mul call $h))",
  )
  let saved = @binary.encode_module(input).unwrap()
  for pass in ["dae", "dae-optimizing"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    assert_eq(locals.length(), 0)
    assert_eq(body, [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
    assert_eq(
      @ir.hot_module_resolve_func_type(
        @ir.hot_module_context_from_module(output),
        @lib.FuncIdx::new(1U),
      ),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
