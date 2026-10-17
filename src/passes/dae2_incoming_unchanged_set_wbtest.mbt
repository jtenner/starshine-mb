///|
fn dae2_incoming_set_fixture() -> (Dae2Graph, Dae2Function, Dae2RawForwardState) {
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [@lib.ValType::i32()],
  )
  let state = Dae2RawControlState::new(
    Dae2RawPlan::new(graph.used.length()),
    [info],
    0,
    [],
    2,
    None,
    None,
  )
  (graph, info, Dae2RawForwardState::new(state, 128))
}

///|
fn dae2_incoming_set_write(
  state : Dae2RawForwardState,
  local : Int32,
  source : Int32,
) -> Unit {
  let old = state.state.locals[local]
  let value = state.state.plan.write(local, source)
  state.state.assign(local, value)
  state.write_locals.push(local)
  state.write_entries.push(old)
  state.changed()
}

///|
fn dae2_incoming_set_check(
  graph : Dae2Graph,
  info : Dae2Function,
  state : Dae2RawForwardState,
  frame : Dae2RawForwardFrame,
  local : Int32,
  first : Bool,
  second : Bool,
) -> Unit raise {
  assert_eq(graph.used, [false, false, false])
  assert_eq(graph.first_edge, [-1, -1, -1])
  assert_eq(graph.last_edge, [-1, -1, -1])
  assert_eq(graph.edges, [])
  assert_eq(graph.work, [])
  assert_true(state.finish_frame(frame))
  state.state.plan.edge(info.result_location, state.state.locals[local])
  state.state.plan.commit(graph)
  graph.observe(info.result_location)
  graph.solve()
  assert_eq(graph.used[info.param_locations[0]], first)
  assert_eq(graph.used[info.param_locations[1]], second)
}

///|
test "DAE2 incoming unchanged lane keeps graph demand and avoids another map write" {
  let (graph, info, state) = dae2_incoming_set_fixture()
  let frame = state.push_frame(0)
  let sets = [0]
  dae2_incoming_set_write(state, 2, info.param_locations[0])
  state.merge_incoming(frame, incoming_sets=Some(sets))
  assert_eq(sets[0], 1)
  dae2_incoming_set_write(state, 3, -1)
  state.merge_incoming(frame, incoming_sets=Some(sets))
  // The new third local is inserted. The existing first lane is unchanged.
  assert_eq(frame.incoming.unwrap().order, [2, 3])
  assert_eq(state.state.plan.count, 2)
  assert_eq(
    state.state.plan.write_locations.unwrap().map(fn(pair) { pair.0 }),
    [2, 3],
  )
  dae2_incoming_set_check(graph, info, state, frame, 2, true, false)
  assert_eq(sets[0], 2)
}

///|
test "DAE2 incoming restored constant preserves earlier demand without rewriting its map lane" {
  let (graph, info, state) = dae2_incoming_set_fixture()
  let frame = state.push_frame(0)
  let sets = [0]
  dae2_incoming_set_write(state, 2, info.param_locations[0])
  state.merge_incoming(frame, incoming_sets=Some(sets))
  state.restore(frame.undo_mark)
  state.merge_incoming(frame, incoming_sets=Some(sets))
  assert_eq(frame.incoming.unwrap().order, [2])
  assert_eq(state.state.plan.count, 1)
  dae2_incoming_set_check(graph, info, state, frame, 2, true, false)
  assert_eq(sets[0], 1)
}

///|
test "DAE2 incoming first negative value is inserted and stays in sparse order" {
  let (graph, info, state) = dae2_incoming_set_fixture()
  let frame = state.push_frame(0)
  let sets = [0]
  dae2_incoming_set_write(state, 2, info.param_locations[0])
  state.restore(frame.undo_mark)
  state.merge_incoming(frame, incoming_sets=Some(sets))
  assert_eq(sets[0], 1)
  assert_eq(frame.incoming.unwrap().order, [2])
  assert_eq(frame.incoming.unwrap().values.get(2), Some(-1))
  dae2_incoming_set_check(graph, info, state, frame, 2, false, false)
}

///|
test "DAE2 incoming changed source still updates the lane and preserves both dependencies" {
  let (graph, info, state) = dae2_incoming_set_fixture()
  let frame = state.push_frame(0)
  let sets = [0]
  dae2_incoming_set_write(state, 2, info.param_locations[0])
  state.merge_incoming(frame, incoming_sets=Some(sets))
  dae2_incoming_set_write(state, 2, info.param_locations[1])
  state.merge_incoming(frame, incoming_sets=Some(sets))
  assert_eq(sets[0], 2)
  assert_eq(frame.incoming.unwrap().order, [2])
  assert_eq(state.state.plan.count, 3)
  dae2_incoming_set_check(graph, info, state, frame, 2, true, true)
}

///|
test "DAE2 incoming map update elision keeps exact forward analysis output and input ownership" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32) (result i32) (local i32 i32) loop end local.get 0 if local.get 0 local.set 2 else local.get 0 local.set 2 end local.get 2) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 17 call $h))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let actual = dae2_run_module_pass(input, false).unwrap()
  let expected = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
  ).unwrap()
  @validate.validate_module(actual).unwrap()
  assert_eq(
    @binary.encode_module(actual).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(actual),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  let @lib.Func(_, @lib.Expr(caller)) = actual.code_sec.unwrap().0[1]
  assert_eq(caller, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
