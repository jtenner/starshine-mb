///|
fn dae2_one_write_exit_fixture() -> @lib.Module {
  let body = StringBuilder()
  body.write_string("block $out ")
  for local in 3..<67 {
    body.write_string("local.get 1 local.set \{local} ")
  }
  for _ in 0..<64 {
    body.write_string("local.get 1 local.set 3 local.get 0 br_if $out ")
  }
  body.write_string("end local.get 4")
  let locals = StringBuilder()
  for _ in 0..<64 {
    locals.write_string("i32 ")
  }
  pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i64) (result i32) (local \{locals.to_string()}) \{body.to_string()}) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
  )
}

///|
test "DAE2 single-write exits preserve every demand within the original raw work bound" {
  // Bounded: 64 locals, 64 conditional exits, 386 h source instructions.
  // The old 64-lane scan at every exit alone needs 4096 work units, more
  // than the unchanged 3152-unit whole-plan limit. Real admission must improve.
  let input = dae2_one_write_exit_fixture()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let @lib.Func(locals, @lib.Expr(instructions)) = input.code_sec.unwrap().0[0]
  let count = dae2_raw_forward_instruction_count(instructions, Some(context))
  assert_eq(count, 386)
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i64()],
    [@lib.ValType::i32()],
  )
  let state = Dae2RawForwardState::new(
    Dae2RawControlState::new(
      Dae2RawPlan::new(graph.used.length()),
      [info],
      0,
      [],
      locals.length(),
      None,
      Some(context),
    ),
    64 + 8 * count,
  )
  let outcome = state.body(instructions, 0, 1)
  // Before the fix, a valid body can fail only through the work limit here.
  assert_true(outcome is Some(_) || state.remaining_work < 0)
  println(
    "one-write-budget instructions=\{count} remaining=\{state.remaining_work} admitted=\{outcome is Some(_)}",
  )
  for closed_world in [false, true] {
    let raw_writes = []
    let hot_writes = []
    let (raw_bits, admitted) = raw_conditional_boundary_bits(
      input,
      true,
      closed_world~,
      write_demands=Some(raw_writes),
    )
    let (hot_bits, _) = raw_conditional_boundary_bits(
      input,
      false,
      closed_world~,
      write_demands=Some(hot_writes),
    )
    assert_eq(raw_bits, hot_bits)
    assert_eq(raw_writes, hot_writes)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    // Required positive admission; expected baseline runtime RED is 1 != 2.
    assert_eq(admitted, 2)
    let lifts = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      analysis_lifts=Some(lifts),
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(lifts[0], 0)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 one-write incoming guard retains an earlier parameter after restore" {
  let (graph, info, state) = dae2_incoming_set_fixture()
  let frame = state.push_frame(0)
  dae2_incoming_set_write(state, 0, info.param_locations[1])
  state.merge_incoming(frame)
  state.restore(frame.undo_mark)
  dae2_incoming_set_write(state, 2, -1)
  // One new event but two state changes: restore must keep the full merge.
  state.merge_incoming(frame)
  assert_eq(frame.incoming.unwrap().order, [0, 2])
  dae2_incoming_set_check(graph, info, state, frame, 0, true, true)
}

///|
test "DAE2 one-write incoming guard retains both changed lanes" {
  let (graph, info, state) = dae2_incoming_set_fixture()
  let frame = state.push_frame(0)
  dae2_incoming_set_write(state, 0, info.param_locations[1])
  state.merge_incoming(frame)
  dae2_incoming_set_write(state, 0, info.param_locations[0])
  dae2_incoming_set_write(state, 2, info.param_locations[1])
  state.merge_incoming(frame)
  assert_eq(frame.incoming.unwrap().order, [0, 2])
  dae2_incoming_set_check(graph, info, state, frame, 0, true, true)
}

///|
test "DAE2 one-write incoming newly discovered lane retains the earlier entry" {
  let (graph, info, state) = dae2_incoming_set_fixture()
  let frame = state.push_frame(0)
  dae2_incoming_set_write(state, 2, info.param_locations[0])
  state.merge_incoming(frame)
  dae2_incoming_set_write(state, 0, info.param_locations[1])
  state.merge_incoming(frame)
  assert_eq(frame.incoming.unwrap().order, [2, 0])
  dae2_incoming_set_check(graph, info, state, frame, 0, true, true)
}

///|
test "DAE2 one-write incoming first nonempty merge keeps the earlier empty edge" {
  let (graph, info, state) = dae2_incoming_set_fixture()
  let frame = state.push_frame(0)
  state.merge_incoming(frame)
  dae2_incoming_set_write(state, 0, info.param_locations[1])
  state.merge_incoming(frame)
  assert_eq(frame.incoming.unwrap().order, [0])
  dae2_incoming_set_check(graph, info, state, frame, 0, true, true)
}
