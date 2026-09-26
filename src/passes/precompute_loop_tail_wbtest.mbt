///|
fn precompute_tail_test_loop() -> @lib.Instruction {
  @lib.Instruction::loop_(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
  )
}

///|
test "precompute infinite loop tail preserves prefix and discards only values" {
  let prefix = @lib.Instruction::call(@lib.FuncIdx::new(0U))
  let loop_ = precompute_tail_test_loop()
  let out = [
    prefix,
    loop_,
    @lib.Instruction::nop(),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::nop(),
  ]
  assert_true(precompute_raw_try_mark_value_tail_after_infinite_loop(out))
  assert_eq(out, [prefix, loop_, @lib.Instruction::unreachable_()])
  let only_nops = [loop_, @lib.Instruction::nop()]
  assert_false(
    precompute_raw_try_mark_value_tail_after_infinite_loop(only_nops),
  )
  assert_eq(only_nops, [loop_, @lib.Instruction::nop()])
  let blocked = [loop_, prefix, @lib.Instruction::i32_const(@lib.I32(9))]
  let original = blocked.copy()
  assert_false(precompute_raw_try_mark_value_tail_after_infinite_loop(blocked))
  assert_eq(blocked, original)
  let nested_loops = [loop_, loop_, @lib.Instruction::i32_const(@lib.I32(3))]
  assert_true(
    precompute_raw_try_mark_value_tail_after_infinite_loop(nested_loops),
  )
  assert_eq(nested_loops, [loop_, loop_, @lib.Instruction::unreachable_()])
}

///|
test "precompute infinite loop tail stops at the nearest unsupported instruction" {
  let out : Array[@lib.Instruction] = []
  let visits = [0]
  for i = 0; i < 128; i = i + 1 {
    out.push(@lib.Instruction::i32_const(@lib.I32(i)))
    assert_false(
      precompute_raw_try_mark_value_tail_after_infinite_loop(
        out,
        visits=Some(visits),
      ),
    )
    out.push(@lib.Instruction::drop())
    assert_false(
      precompute_raw_try_mark_value_tail_after_infinite_loop(
        out,
        visits=Some(visits),
      ),
    )
  }
  for i = 0; i < 128; i = i + 1 {
    assert_eq(out[i * 2], @lib.Instruction::i32_const(@lib.I32(i)))
    assert_eq(out[i * 2 + 1], @lib.Instruction::drop())
  }
  assert_true(visits[0] <= 384, msg="tail scan visits: \{visits[0]}")
}

///|
test "precompute dispatcher preserves infinite loop while marking value tail unreachable" {
  for pass_name in ["precompute", "precompute-propagate"] {
    let output = pass_test_run_pipeline(
      "(module (func (export \"run\") (result i32) (loop br 0) i32.const 310))",
      [pass_name],
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.CodeSec(funcs) = output.code_sec.unwrap()
    let @lib.Func(_, @lib.Expr(body)) = funcs[0]
    assert_eq(body, [
      precompute_tail_test_loop(),
      @lib.Instruction::unreachable_(),
    ])
  }
}
