///|
fn slns_loop_guard_fixture(
  initializers : Int,
  parameter_style : Bool,
) -> Array[@lib.Instruction] {
  let instrs : Array[@lib.Instruction] = []
  for idx in 0..<initializers {
    instrs.push(
      if parameter_style {
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
      } else {
        @lib.Instruction::i32_const(@lib.I32(idx))
      },
    )
    instrs.push(
      @lib.Instruction::local_set(@lib.LocalIdx::new((idx + 1).to_uint())),
    )
  }
  let body = Array::make(512, @lib.Instruction::nop())
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
    ),
  )
  body.push(
    @lib.Instruction::local_set(
      @lib.LocalIdx::new((initializers + 1).to_uint()),
    ),
  )
  instrs.push(
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(body)),
  )
  instrs
}

///|
fn slns_loop_guard_bench(
  it : @bench.T,
  initializers : Int,
  parameter_style : Bool,
) -> Unit {
  let fixture = slns_loop_guard_fixture(initializers, parameter_style)
  let check = if parameter_style {
    run_hot_pipeline_raw_simplify_locals_has_parameter_initialized_result_loop_carrier
  } else {
    run_hot_pipeline_raw_simplify_locals_has_initialized_loop_carrier
  }
  if check(fixture) {
    abort("SimplifyLocals negative loop-guard fixture unexpectedly matched")
  }
  it.bench(fn() { it.keep(check(fixture)) })
}

///|
test "bench simplify-locals parameter loop guard initializers=64" (
  it : @bench.T,
) {
  slns_loop_guard_bench(it, 64, true)
}

///|
test "bench simplify-locals parameter loop guard initializers=128" (
  it : @bench.T,
) {
  slns_loop_guard_bench(it, 128, true)
}

///|
test "bench simplify-locals initialized loop guard initializers=64" (
  it : @bench.T,
) {
  slns_loop_guard_bench(it, 64, false)
}

///|
test "bench simplify-locals initialized loop guard initializers=128" (
  it : @bench.T,
) {
  slns_loop_guard_bench(it, 128, false)
}

///|
test "simplify-locals parameter loop guard finds a nested result write" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let instrs = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new(body)),
  ]
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_parameter_initialized_result_loop_carrier(
      instrs,
    ),
  )
}

///|
test "simplify-locals initialized loop guard finds a nested local write" {
  let instrs = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    ),
  ]
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_initialized_loop_carrier(instrs),
  )
}
