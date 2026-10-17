///|
test "touched precompute size selection preserves short splats and untouched functions" {
  let input = pass_test_module_from_wat(
    "(module (func (result v128) i32.const 0 i32x4.splat) (func (result v128) v128.const i32x4 0 0 0 0))",
  )
  let options = HotPipelineOptions::new(shrink_level=1)
  for name in ["precompute", "precompute-propagate"] {
    let descriptor = pass_registry_lookup(name).unwrap().descriptor.unwrap()
    let output = run_hot_pipeline_apply_hot_pass_to_touched(
      input,
      descriptor,
      [true, false],
      options,
    ).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    let funcs = output.code_sec.unwrap().0
    let @lib.Func(_, @lib.Expr(body)) = funcs[0]
    assert_eq(body, [
      @lib.Instruction::i32_const(0),
      @lib.Instruction::i8x16_splat(),
    ])
    assert_true(physical_equal(funcs[1], input.code_sec.unwrap().0[1]))
    assert_true(
      @binary.encode_module(output).unwrap().length() <=
      @binary.encode_module(input).unwrap().length(),
    )
  }
}

///|
test "stack precompute size selection materializes final folded vectors" {
  let input = pass_test_module_from_wat(
    "(module (func (result v128) i32.const 0 i32x4.splat))",
  )
  let entry = pass_registry_lookup("precompute").unwrap()
  let output = run_hot_pipeline_apply_hot_pass_stack(
    input,
    [entry],
    HotPipelineOptions::new(shrink_level=1),
  ).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body, [
    @lib.Instruction::i32_const(0),
    @lib.Instruction::i8x16_splat(),
  ])
  assert_true(
    @binary.encode_module(output).unwrap().length() <=
    @binary.encode_module(input).unwrap().length(),
  )
}

///|
test "filtered stack precompute size selection leaves unselected literals intact" {
  let input = pass_test_module_from_wat(
    "(module (func (result v128) i32.const 0 i32x4.splat) (func (result v128) v128.const i32x4 0 0 0 0))",
  )
  let options = HotPipelineOptions::new(shrink_level=1)
  for
    names in [["precompute"], ["precompute-propagate", "optimize-instructions"]] {
    let descriptors = names.map(fn(name) {
      pass_registry_lookup(name).unwrap().descriptor.unwrap()
    })
    let output = run_hot_pipeline_apply_hot_pass_stack_to_touched(
      input,
      descriptors,
      [true, false],
      options,
    ).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    let funcs = output.code_sec.unwrap().0
    let @lib.Func(_, @lib.Expr(body)) = funcs[0]
    assert_eq(body, [
      @lib.Instruction::i32_const(0),
      @lib.Instruction::i8x16_splat(),
    ])
    assert_true(physical_equal(funcs[1], input.code_sec.unwrap().0[1]))
  }
}

///|
test "reorder globals does not use discarded compiler facts to hide name framing growth" {
  let names = Array::makei(128, fn(index) {
    @lib.NameAssoc::new(
      index.to_uint(),
      @lib.Name::from_string(
        if index == 127 {
          "x".repeat(15616)
        } else {
          "aaaa"
        },
      ),
    )
  })
  // This single bounded name-map fixture crosses the 16383-byte subsection
  // framing boundary after index zero moves to128; it is not a seed sweep.
  let input = encoded_profitability_global_fixture()
    .with_name_sec(
      @lib.NameSec::new(global_names=Some(@lib.NameMap::new(names))),
    )
    .with_compiler_fact_custom_section(
      @representation.CompilerFactCustomSection::new(
        @representation.OptimizationFactsSec::new(),
      ),
    )
  ignore(@validate.validate_module(input).unwrap())
  let output = reorder_globals_run_module_pass(input)
  ignore(@validate.validate_module(output).unwrap())
  let old_bytes = @binary.encode_module(
    input.without_compiler_fact_custom_section(),
  ).unwrap()
  let new_bytes = @binary.encode_module(
    output.without_compiler_fact_custom_section(),
  ).unwrap()
  assert_true(
    new_bytes.length() <= old_bytes.length(),
    msg="discarded facts must not finance larger executable/name encoding",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let index = match body[0] {
    @lib.GlobalGet(@lib.GlobalIdx(index)) => index.to_int()
    _ => fail("expected retained global read")
  }
  assert_eq(
    output.global_sec.unwrap().0[index],
    input.global_sec.unwrap().0[128],
  )
}
