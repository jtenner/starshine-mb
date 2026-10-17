///|
fn pure_suffix_statement_seed_fixture(
  local_count : Int32,
  repeated_uses : Bool,
) -> (@lib.Module, @validate.Env, Array[@lib.Instruction]) raise {
  let width = 4
  let stores = Array::makei(width, fn(index) {
    "i32.const \{index + 7} local.set \{index}"
  }).join(" ")
  let reads = Array::makei(width, fn(index) {
    "local.get \{index} call $consume"
  }).join(" ")
  let local_types = "i32 ".repeat(local_count)
  let uses = if repeated_uses { reads + " " + reads } else { reads }
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"consume\" (func $consume (param i32))) (func (local \{local_types}) \{stores} \{uses}))",
  )
  ignore(@validate.validate_module(input).unwrap())
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let env = @validate.Env::new()
    .with_module(input)
    .with_locals(locals)
    .with_return_type(Some([]))
  (input, env, body)
}

///|
test "pure suffix repeated blocked reads bound full local initialization without changing code" {
  for local_count in [128, 129] {
    // Two separate reads intentionally block this single-consumer forwarding
    // rule. Four stores keep the default regression small despite the wide env.
    let (input, env, body) = pure_suffix_statement_seed_fixture(
      local_count, true,
    )
    let saved = @binary.encode_module(input).unwrap()
    let slots = [0]
    let (output, rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat_with_statement_setup(
      body,
      env,
      initialization_slots=Some(slots),
    )
    assert_eq(rewrites, 0)
    assert_eq(output, body)
    let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
    let candidate = input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(output))]),
    )
    ignore(@validate.validate_module(candidate).unwrap())
    assert_eq(@binary.encode_module(candidate).unwrap(), saved)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_true(
      slots[0] <= 2 * local_count,
      msg="repeated statement queries must share full-local setup: \{slots[0]}",
    )
  }
}

///|
test "pure suffix seeded and cold paths retain positive forwarding and independent inputs" {
  for local_count in [4, 127, 128, 129] {
    let (input, env, body) = pure_suffix_statement_seed_fixture(
      local_count, false,
    )
    let saved = @binary.encode_module(input).unwrap()
    let output = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
      body, env,
    )
    assert_true(output.1 > 0)
    assert_eq(output, sl_pure_middle_reference_flat(body, env))
    let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
    ignore(
      @validate.validate_module(
        input.with_code_sec(
          @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(output.0))]),
        ),
      ).unwrap(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "pure suffix terminal store makes no statement setup without a following query" {
  let input = pass_test_module_from_wat(
    "(module (func (local " + "i32 ".repeat(128) + ") i32.const 7 local.set 0))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let env = @validate.Env::new()
    .with_module(input)
    .with_locals(locals)
    .with_return_type(Some([]))
  let saved = @binary.encode_module(input).unwrap()
  let slots = [0]
  let (output, rewrites) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat_with_statement_setup(
    body,
    env,
    initialization_slots=Some(slots),
  )
  assert_eq(output, body)
  assert_eq(rewrites, 0)
  assert_eq(slots[0], 0)
  ignore(
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(output))]),
      ),
    ).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "statement seed caller keeps invalid and escaping probes isolated from later valid queries" {
  let (_, env, _) = pure_suffix_statement_seed_fixture(128, true)
  let seed = SlStatementTypeSeed::new(env)
  // These probes are intentionally invalid or escaping under this empty stack.
  for
    invalid in [
      [@lib.Instruction::drop()],
      [@lib.Instruction::local_get(@lib.LocalIdx::new(128U))],
    ] {
    assert_eq(sl_statement_at(invalid, 0, env, typed_seed=Some(seed)), [])
    assert_eq(
      sl_statement_at([@lib.Instruction::nop()], 0, env, typed_seed=Some(seed)),
      [@lib.Instruction::nop()],
    )
  }
  let escape = [@lib.Instruction::return_()]
  assert_eq(sl_statement_at(escape, 0, env, typed_seed=Some(seed)), [])
  assert_eq(
    sl_statement_at(escape, 0, env, allow_escape=true, typed_seed=Some(seed)),
    escape,
  )
  assert_eq(
    sl_statement_at([@lib.Instruction::nop()], 0, env, typed_seed=Some(seed)),
    [@lib.Instruction::nop()],
  )
  assert_true(seed.state.stack.is_empty())
  assert_true(seed.state.reachable)
  assert_eq(seed.state.escape, @validate.tc_escape_none())
  assert_true(seed.state.initialized_locals.all(fn(bit) { bit }))
}
