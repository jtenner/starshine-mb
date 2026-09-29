///|
test "precompute simple value tails avoid full fold scans and preserve their instructions" {
  for shape in ["value", "constant"] {
    let input = precompute_tail_admission_fixture(16, shape)
    @validate.validate_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let original = body.copy()
    let checks = [0]
    assert_false(
      precompute_raw_fold_output_tail(body, full_tail_checks=Some(checks)),
    )
    assert_eq(body, original)
    assert_eq(checks[0], 0)
  }
}

///|
test "precompute value-tail admission retains infinite-loop cleanup" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) loop br 0 end local.get 0))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let output = body.copy()
  let checks = [0]
  assert_true(
    precompute_raw_fold_output_tail(output, full_tail_checks=Some(checks)),
  )
  assert_eq(output, [body[0], @lib.Instruction::unreachable_()])
  assert_eq(checks[0], 0)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(output))]),
    ),
  ).unwrap()
  assert_eq(body.length(), 2)
}

///|
test "precompute tail admission still folds active scalar operators through dispatch" {
  let input = precompute_tail_admission_fixture(1, "active")
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let output = body.copy()
  let checks = [0]
  assert_true(
    precompute_raw_fold_output_tail(output, full_tail_checks=Some(checks)),
  )
  assert_eq(output.last(), Some(@lib.Instruction::i32_const(@lib.I32(3))))
  assert_eq(checks[0], 1)
  let expected = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "precompute",
  ]).unwrap()
  @validate.validate_module(expected).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = expected.code_sec.unwrap().0[0]
  assert_eq(result.last(), Some(@lib.Instruction::i32_const(@lib.I32(3))))
  assert_eq(body.last(), Some(@lib.Instruction::i32_add()))
}

///|
test "root snapshot prefix stops on the first incompatible instruction without changing guard decisions" {
  let input = precompute_root_snapshot_fixture(16, false)
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let original = body.copy()
  let visits = [0]
  assert_false(
    run_hot_pipeline_raw_has_root_global_snapshot_write_prefix(
      body,
      instruction_visits=Some(visits),
    ),
  )
  assert_eq(precompute_root_snapshot_prefix_reference(body), false)
  assert_eq(visits[0], 1)
  assert_eq(body, original)
}

///|
test "root snapshot prefix retains active guards and the sixteenth live-instruction boundary" {
  let input = precompute_root_snapshot_fixture(16, true)
  @validate.validate_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let visits = [0]
  assert_true(
    run_hot_pipeline_raw_has_root_global_snapshot_write_prefix(
      body,
      instruction_visits=Some(visits),
    ),
  )
  assert_eq(visits[0], 4)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(input).unwrap(),
  )
  for position in [15, 16] {
    let prefix : Array[@lib.Instruction] = [body[0], body[1], body[2]]
    prefix.push(@lib.Instruction::nop())
    for _ in 0..<6 {
      prefix.push(@lib.Instruction::nop())
      prefix.push(@lib.Instruction::i32_const(@lib.I32(1)))
      prefix.push(@lib.Instruction::drop())
    }
    if position == 16 {
      prefix.push(@lib.Instruction::i32_eqz())
    }
    prefix.push(body[3])
    let before = prefix.copy()
    let candidate = input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(prefix))]),
    )
    @validate.validate_module(candidate).unwrap()
    assert_eq(
      run_hot_pipeline_raw_has_root_global_snapshot_write_prefix(prefix),
      position == 15,
    )
    assert_eq(precompute_root_snapshot_prefix_reference(prefix), position == 15)
    assert_eq(prefix, before)
  }
}
