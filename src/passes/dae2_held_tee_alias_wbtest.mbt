///|
fn dae2_held_tee_alias_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module
      #|  (import "env" "consume" (func $consume (param i32)))
      #|  (import "env" "combine" (func $combine (param i32 i32 i32 i32) (result i32)))
      #|  (memory 1)
      #|  (func (export "run") (param i32 i32) (local i32 i32 i32 i32)
      #|    local.get 1
      #|    local.get 0 i32.load local.tee 2
      #|    i32.const 0
      #|    local.get 0 i32.load offset=4
      #|    local.get 1 if local.get 2 call $consume end
      #|    local.set 4 local.set 3 local.tee 5
      #|    local.get 3 local.get 4 call $combine drop
      #|    local.get 5 call $consume))
    ),
  )
}

///|
test "DAE2 capture cleanup forwards the same held tee value across a void conditional" {
  let input = dae2_held_tee_alias_fixture()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 3)
  assert_eq(body.last(), Some(@lib.Instruction::call(@lib.FuncIdx::new(0U))))
  assert_eq(
    body[body.length() - 2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  )
  assert_true(@binary.encode_module(output).unwrap().length() < saved.length())
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 held tee proof retains overwritten sources and distinct produced lanes" {
  let input = dae2_held_tee_alias_fixture()
  let context = @ir.hot_module_context_from_module(input)
  let query = Some(fn(instr) {
    dae2_capture_stack_effect(instr, input, context)
  })
  let source = @lib.Instruction::local_tee(@lib.LocalIdx::new(2U))
  let target = @lib.Instruction::local_tee(@lib.LocalIdx::new(5U))
  for
    body in [
      [
        source,
        @lib.Instruction::i32_const(9),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        target,
      ],
      [source, @lib.Instruction::drop(), @lib.Instruction::i32_const(9), target],
      [
        source,
        @lib.Instruction::i32_const(1),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(9),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          ],
          None,
        ),
        target,
      ],
    ] {
    let reads = Array::make(6, 0)
    let writes = Array::make(6, 0)
    pass_lower_count_locals(body, reads, writes)
    assert_eq(
      dae2_alias_held_tee_source(body, body.length() - 1, writes, query),
      -1,
    )
  }
}

///|
test "DAE2 held tee proof bounds its backward scan at the same stack lane" {
  let input = dae2_held_tee_alias_fixture()
  let context = @ir.hot_module_context_from_module(input)
  let query = Some(fn(instr) {
    dae2_capture_stack_effect(instr, input, context)
  })
  for padding in [63, 64] {
    let body = [@lib.Instruction::local_tee(@lib.LocalIdx::new(2U))]
    for _ in 0..<padding {
      body.push(@lib.Instruction::nop())
    }
    body.push(@lib.Instruction::local_tee(@lib.LocalIdx::new(5U)))
    let writes = Array::make(6, 0)
    writes[2] = 1
    writes[5] = 1
    assert_eq(
      dae2_alias_held_tee_source(body, body.length() - 1, writes, query),
      if padding == 63 {
        2
      } else {
        -1
      },
    )
  }
}
