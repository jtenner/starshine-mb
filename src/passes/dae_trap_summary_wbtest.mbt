///|
fn dae_trap_summary_test_scan(
  body : Array[@lib.Instruction],
  active? : Bool = true,
) -> (Bool, DaeCurrentCallFacts, Array[DaeFunctionInfo]) {
  let direct_calls = [0, 0]
  let tail_calls = [false, false]
  let direct_callers = dae_make_direct_callers(2)
  let dropped_calls = [0, 0]
  let escaped = [false, false]
  let infos = dae_make_function_infos(2, escaped)
  let trap = dae_scan_current_call_facts_instrs(
    body,
    1,
    1,
    [],
    direct_calls,
    tail_calls,
    direct_callers,
    dropped_calls,
    escaped,
    infos,
    [-1, -1],
    active,
  )
  (
    trap,
    { direct_calls, tail_calls, direct_callers, dropped_calls, escaped, },
    infos,
  )
}

///|
test "DAE call scan reports singleton wrapped traps without changing body ownership" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::unreachable_()]),
        ),
      ]),
    ),
  ]
  let saved = body.copy()
  for active in [true, false] {
    let (trap, facts, infos) = dae_trap_summary_test_scan(body, active~)
    assert_true(trap)
    assert_eq(facts.direct_calls, [0, 0])
    assert_eq(facts.direct_callers, [[], []])
    assert_true(infos[0].calls.is_empty())
    assert_eq(body, saved)
  }
}

///|
test "DAE fused trap summaries retain active calls and dead suffix exposure" {
  let input = pass_test_module_from_wat(
    "(module (func $target (result i32) i32.const 9) (elem declare func $target) (func (export \"run\") (result i32) call $target drop block block unreachable end end call $target drop ref.func $target drop return_call $target))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[1]
  let (trap, facts, infos) = dae_trap_summary_test_scan(body)
  assert_false(trap)
  assert_eq(facts.direct_calls, [1, 0])
  assert_eq(facts.dropped_calls, [1, 0])
  assert_eq(facts.direct_callers, [[1], []])
  assert_eq(facts.tail_calls, [false, false])
  assert_eq(facts.escaped, [true, false])
  assert_eq(infos[0].calls.length(), 2)
  assert_true(infos[0].calls[0].active)
  assert_false(infos[0].calls[1].active)
  assert_eq(infos[0].calls[0].path, [0])
  assert_eq(infos[0].calls[1].path, [3])
  let collected = dae_collect_current_call_facts(input, 2)
  assert_eq(facts.direct_calls, collected.direct_calls)
  assert_eq(facts.dropped_calls, collected.dropped_calls)
  assert_eq(facts.tail_calls, collected.tail_calls)
  assert_eq(facts.direct_callers, collected.direct_callers)
  assert_eq(facts.escaped[0], collected.escaped[0])
  assert_true(collected.escaped[1])
}

///|
test "DAE singleton summary keeps loops branches and non-singleton blocks distinct" {
  let input = pass_test_module_from_wat(
    "(module (func $target (result i32) i32.const 9) (func (export \"run\") (result i32) loop unreachable end call $target drop i32.const 0 if unreachable else unreachable end call $target drop block unreachable nop end call $target))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[1]
  let (trap, facts, _) = dae_trap_summary_test_scan(body)
  assert_false(trap)
  assert_eq(facts.direct_calls, [3, 0])
  assert_eq(facts.dropped_calls, [2, 0])
  for idx in [0, 4, 7] {
    let (child_trap, _, _) = dae_trap_summary_test_scan([body[idx]])
    assert_false(child_trap)
  }
}
