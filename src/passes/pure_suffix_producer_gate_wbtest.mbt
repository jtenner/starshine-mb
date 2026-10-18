///|
test "pure suffix compound rejection preserves code without producer typechecks" {
  for local_count in [4, 128, 129] {
    let input = pass_test_module_from_wat(
      "(module (func (local " +
      "i32 ".repeat(local_count) +
      ") i32.const 7 i32.const 2 i32.add local.set 0 local.get 0 drop i32.const 9 i32.const 3 i32.mul local.set 1 local.get 1 drop))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let env = @validate.Env::new()
      .with_module(input)
      .with_locals(locals)
      .with_return_type(Some([]))
    let probes = [0]
    let actual = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat_with_statement_setup(
      body,
      env,
      producer_probe_instructions=Some(probes),
    )
    assert_eq(actual, sl_pure_middle_reference_flat(body, env))
    assert_eq(actual.1, 0)
    assert_true(physical_equal(actual.0, body))
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(probes[0], 0)
  }
}

///|
test "pure suffix producer gate retains literal and local forwarding after computed stores" {
  for
    body in [
      "i32.const 7 i32.const 2 i32.add local.set 1 i32.const 9 local.set 2 local.get 2",
      "i32.const 7 i32.const 2 i32.add local.set 1 local.get 0 local.set 2 local.get 2",
      "i32.const 7 i32.const 2 i32.add local.set 1 nop local.get 0 local.set 2 local.get 2",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (param i32) (result i32) (local i32 i32) \{body}))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(instrs)) = input.code_sec.unwrap().0[0]
    let all_locals = @lib.Locals::from_types([@lib.ValType::i32()])
    all_locals.append(locals)
    let env = @validate.Env::new()
      .with_module(input)
      .with_locals(all_locals)
      .with_return_type(Some([@lib.ValType::i32()]))
    let actual = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
      instrs, env,
    )
    assert_eq(actual, sl_pure_middle_reference_flat(instrs, env))
    assert_true(actual.1 > 0)
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "simplify-locals",
    ]).unwrap()
    @validate.validate_module(output).unwrap()
  }
}
