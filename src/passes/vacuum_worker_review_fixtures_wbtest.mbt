///|
fn vacuum_worker_review_f2850() -> Array[@lib.Instruction] {
  let retained_env = @lib.LocalIdx::new(407U)
  let retained_index = @lib.LocalIdx::new(408U)
  let retained_value = @lib.LocalIdx::new(409U)
  let env = @lib.LocalIdx::new(3U)
  let index = @lib.LocalIdx::new(4U)
  let value = @lib.LocalIdx::new(5U)
  let should_return = @lib.LocalIdx::new(95U)
  let guard_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::local_set(should_return),
    ],
    Some([
      @lib.Instruction::local_get(env),
      @lib.Instruction::local_get(index),
      @lib.Instruction::call(@lib.FuncIdx::new(9U)),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::local_set(should_return),
    ]),
  )
  let return_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(value),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_get(env),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::return_(),
    ],
    None,
  )
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::local_get(retained_value),
      @lib.Instruction::local_set(value),
    ]),
    @lib.Instruction::local_get(retained_env),
    @lib.Instruction::local_set(env),
    @lib.Instruction::local_get(retained_index),
    @lib.Instruction::local_tee(index),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_lt_s(),
    guard_if,
    @lib.Instruction::local_get(should_return),
    return_if,
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::local_get(env),
      @lib.Instruction::drop(),
    ]),
  ]
  [pass_manager_test_vacuum_plain_block(parent_body)]
}

///|
fn vacuum_worker_review_f1963() -> Array[@lib.Instruction] {
  let arg0 = @lib.LocalIdx::new(1U)
  let arg1 = @lib.LocalIdx::new(2U)
  let lhs_arg = @lib.LocalIdx::new(5U)
  let rhs_arg = @lib.LocalIdx::new(6U)
  let selector = @lib.LocalIdx::new(9U)
  let lhs_result = @lib.LocalIdx::new(86U)
  let rhs_result = @lib.LocalIdx::new(87U)
  let compare_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::br(@lib.LabelIdx::new(2U))],
    Some([
      @lib.Instruction::local_get(lhs_result),
      @lib.Instruction::i32_wrap_i64(),
      @lib.Instruction::local_set(selector),
      @lib.Instruction::local_get(rhs_result),
      @lib.Instruction::i64_const(@lib.I64(4294967296L)),
      @lib.Instruction::i64_eq(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::br(@lib.LabelIdx::new(3U))],
        Some([
          @lib.Instruction::local_get(selector),
          @lib.Instruction::local_get(rhs_result),
          @lib.Instruction::i32_wrap_i64(),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::br(@lib.LabelIdx::new(4U))],
            None,
          ),
        ]),
      ),
    ]),
  )
  let sentinel_body = [
    @lib.Instruction::local_get(arg0),
    @lib.Instruction::local_get(arg1),
    @lib.Instruction::local_get(lhs_arg),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_set(lhs_result),
    @lib.Instruction::local_get(arg0),
    @lib.Instruction::local_get(arg1),
    @lib.Instruction::local_get(rhs_arg),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_set(rhs_result),
    @lib.Instruction::local_get(lhs_result),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::i64_eq(),
    compare_if,
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(sentinel_body),
        ]),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
      @lib.Instruction::return_(),
    ]),
  ]
  input
}
