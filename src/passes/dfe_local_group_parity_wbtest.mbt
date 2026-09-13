///|
fn dfe_local_group_parity_fixture(
  locals : Array[@lib.ValType],
  body : Array[@lib.Instruction],
  results : Array[@lib.ValType],
) -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], results)),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(body)),
    ]),
  )
}

///|
test "parity followup DFE groups fragmented numeric locals and remaps reads and writes" {
  let input = dfe_local_group_parity_fixture(
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ],
    [
      @lib.Instruction::i64_const(7L),
      @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    ],
    [@lib.ValType::i64()],
  )
  assert_true(@validate.validate_module(input) is Ok(_))
  for public_dispatch in [false, true] {
    let output = if public_dispatch {
      run_hot_pipeline(input, HotPipelineOptions::new(), [
        "duplicate-function-elimination",
      ]).unwrap()
    } else {
      dfe_run_module_pass(input)
    }
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(locals.get(2), @lib.ValType::i64())
    assert_eq(locals.get(3), @lib.ValType::i32())
    assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(2U)))
    assert_eq(body[2], @lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
    assert_true(@validate.validate_module(output) is Ok(_))
    assert_eq(
      @binary.encode_module(output).unwrap().length(),
      @binary.encode_module(input).unwrap().length() - 2,
    )
  }
}

///|
test "DFE intentionally declines local grouping that increases encoded index sizes" {
  let locals = [@lib.ValType::i64()]
  for _ in 0..<127 {
    locals.push(@lib.ValType::i32())
  }
  locals.push(@lib.ValType::i64())
  let body = []
  // Eight uses cross the 127/128 LEB boundary: more cost than two saved bytes.
  for _ in 0..<8 {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(127U)))
    body.push(@lib.Instruction::drop())
  }
  let input = dfe_local_group_parity_fixture(locals, body, [])
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = dfe_run_module_pass(input)
  let @lib.Func(output_locals, _) = output.code_sec.unwrap().0[0]
  let @lib.Func(input_locals, _) = input.code_sec.unwrap().0[0]
  assert_eq(output_locals, input_locals)
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(input).unwrap(),
  )
}
