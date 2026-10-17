///|
// Candidate-only private storage controls. Install after the behavior RED and
// candidate source: the old type intentionally has no journal fields.
fn dae2_sparse_state_fixture(
  width~ : Int32 = 8,
) -> (Dae2Graph, Dae2Function, Dae2RawForwardState) {
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
    [@lib.ValType::i32()],
  )
  let state = Dae2RawForwardState::new(
    Dae2RawControlState::new(
      Dae2RawPlan::new(graph.used.length()),
      [info],
      0,
      [],
      width,
      None,
      None,
    ),
    4096,
  )
  (graph, info, state)
}

///|
fn dae2_sparse_state_write(
  state : Dae2RawForwardState,
  local : Int32,
  source : Int32,
) -> Unit {
  let old = state.state.locals[local]
  let value = state.state.plan.write(local, source)
  state.state.assign(local, value)
  state.write_locals.push(local)
  state.write_entries.push(old)
  state.changed(local~)
}

///|
fn dae2_sparse_state_seed(
  state : Dae2RawForwardState,
  source : Int32,
  width~ : Int32 = 8,
) -> Unit {
  for local in 3..<(3 + width) {
    dae2_sparse_state_write(state, local, source)
  }
}

///|
fn dae2_sparse_state_pair(
  state : Dae2RawForwardState,
  info : Dae2Function,
) -> Unit {
  dae2_sparse_state_write(state, 3, info.param_locations[1])
  dae2_sparse_state_write(state, 4, info.param_locations[2])
}

///|
fn dae2_sparse_state_solve(
  graph : Dae2Graph,
  info : Dae2Function,
  state : Dae2RawForwardState,
  frame : Dae2RawForwardFrame,
) -> Unit raise {
  assert_true(state.finish_frame(frame))
  for local in 3..<6 {
    state.state.plan.edge(info.result_location, state.state.locals[local])
  }
  state.state.plan.commit(graph)
  graph.observe(info.result_location)
  graph.solve()
  assert_true(graph.used[info.param_locations[1]])
}

///|
test "DAE2 sparse journal cold unchanged and one-change states allocate no extra arrays" {
  // Full module/byte/source-write proof precedes the physical storage checks.
  for changes in [0, 1] {
    let input = dae2_sparse_exit_fixture(8, 8, changes)
    let saved = @binary.encode_module(input).unwrap()
    @validate.validate_module(input).unwrap()
    raw_conditional_compare_boundaries(input, 2)
    let actual = dae2_run_module_pass(input, false).unwrap()
    let reference = dae2_run_module_pass(
      input,
      false,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    let (graph, info, state) = dae2_sparse_state_fixture()
    let frame = state.push_frame(0)
    dae2_sparse_state_seed(state, info.param_locations[1])
    state.merge_incoming(frame)
    for _ in 0..<8 {
      if changes == 1 {
        dae2_sparse_state_write(state, 3, info.param_locations[1])
      }
      state.merge_incoming(frame)
    }
    dae2_sparse_state_solve(graph, info, state, frame)
    assert_false(graph.used[info.param_locations[0]])
    assert_false(graph.used[info.param_locations[2]])
    assert_true(state.changed_locals is None)
    assert_eq(state.change_base_epoch, -1)
  }
}

///|
test "DAE2 sparse journal starts after actual repeated wide merge and preserves complete change history" {
  dae2_sparse_incoming_compare(dae2_sparse_exit_fixture(8, 8, 2))
  let (graph, info, state) = dae2_sparse_state_fixture()
  let frame = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1])
  state.merge_incoming(frame)
  assert_true(state.changed_locals is None)
  dae2_sparse_state_pair(state, info)
  state.merge_incoming(frame)
  assert_eq(state.changed_locals, Some([]))
  assert_eq(state.change_base_epoch, state.state_epoch)
  dae2_sparse_state_pair(state, info)
  state.merge_incoming(frame)
  dae2_sparse_state_solve(graph, info, state, frame)
  assert_true(graph.used[info.param_locations[2]])
  assert_eq(
    state.changed_locals.unwrap().length(),
    state.state_epoch - state.change_base_epoch,
  )
  assert_true(
    state.changed_locals.unwrap().capacity() <=
    (2 * state.changed_locals.unwrap().length()).max(8),
  )
  assert_true(state.remaining_work >= 0)
}

///|
test "DAE2 bounded scalar dedup distinguishes different frames at the same state epoch" {
  let (graph, info, state) = dae2_sparse_state_fixture()
  let outer = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1])
  state.merge_incoming(outer)
  dae2_sparse_state_pair(state, info)
  state.merge_incoming(outer)
  let inner = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1])
  state.merge_incoming(inner)
  state.merge_incoming(outer)
  dae2_sparse_state_write(state, 3, info.param_locations[0])
  dae2_sparse_state_write(state, 4, info.param_locations[2])
  let epoch = state.state_epoch
  state.merge_incoming(inner)
  state.merge_incoming(outer)
  assert_eq(state.state_epoch, epoch)
  assert_eq(inner.incoming_epoch, epoch)
  assert_eq(outer.incoming_epoch, epoch)
  assert_true(state.finish_frame(inner))
  dae2_sparse_state_solve(graph, info, state, outer)
  assert_true(graph.used[info.param_locations[0]])
  assert_true(graph.used[info.param_locations[2]])
}

///|
test "DAE2 sparse older frame cursor retains legacy entry when journal starts in a child" {
  let (graph, info, state) = dae2_sparse_state_fixture()
  let outer = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1])
  state.merge_incoming(outer)
  let inner = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1])
  state.merge_incoming(inner)
  dae2_sparse_state_write(state, 3, info.param_locations[0])
  dae2_sparse_state_write(state, 4, info.param_locations[2])
  state.merge_incoming(inner)
  assert_true(outer.incoming_epoch < state.change_base_epoch)
  state.merge_incoming(outer)
  assert_eq(outer.incoming_epoch, state.state_epoch)
  assert_true(state.finish_frame(inner))
  dae2_sparse_state_solve(graph, info, state, outer)
  assert_true(graph.used[info.param_locations[0]])
  assert_true(graph.used[info.param_locations[2]])
}

///|
test "DAE2 bounded scalar dedup keeps exact journal cursors near the epoch limit" {
  let (graph, info, state) = dae2_sparse_state_fixture()
  let frame = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1])
  state.merge_incoming(frame)
  dae2_sparse_state_pair(state, info)
  state.merge_incoming(frame)
  // Keep the same complete history while moving its epoch origin. Dedup
  // requires no separate generation counter or per-local stamp reset.
  let shift = 2147483519 - state.state_epoch
  state.state_epoch += shift
  state.change_base_epoch += shift
  frame.incoming_epoch += shift
  dae2_sparse_state_pair(state, info)
  let before = state.remaining_work
  state.merge_incoming(frame)
  assert_eq(before - state.remaining_work, 7)
  assert_eq(frame.incoming_epoch, state.state_epoch)
  dae2_sparse_state_solve(graph, info, state, frame)
  assert_true(graph.used[info.param_locations[2]])
}

///|
test "DAE2 sparse unknown private mutation history intentionally retains the legacy merge" {
  let (graph, info, state) = dae2_sparse_state_fixture()
  let frame = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1])
  state.merge_incoming(frame)
  dae2_sparse_state_pair(state, info)
  state.merge_incoming(frame)
  // The private legacy clock hook cannot certify a local. It invalidates the
  // optional journal, while the complete original source-write journal stays.
  let old = state.state.locals[3]
  let value = state.state.plan.write(3, info.param_locations[0])
  state.state.assign(3, value)
  state.write_locals.push(3)
  state.write_entries.push(old)
  state.changed()
  assert_true(state.changed_locals is None)
  state.merge_incoming(frame)
  dae2_sparse_state_solve(graph, info, state, frame)
  assert_true(graph.used[info.param_locations[0]])
  assert_true(graph.used[info.param_locations[2]])
}

///|
test "DAE2 more than eight journal events intentionally keep the paid legacy merge" {
  dae2_sparse_incoming_compare(dae2_sparse_exit_fixture(8, 8, 2))
  let (graph, info, state) = dae2_sparse_state_fixture()
  let frame = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1])
  state.merge_incoming(frame)
  dae2_sparse_state_pair(state, info)
  state.merge_incoming(frame)
  dae2_sparse_state_pair(state, info)
  state.merge_incoming(frame)
  for event in 0..<9 {
    dae2_sparse_state_write(
      state,
      3 + event % 2,
      info.param_locations[1 + event % 2],
    )
  }
  // Nine source-event reads and eight legacy lane visits fit exactly.
  // This intentionally unsupported delta never initializes local stamps.
  state.remaining_work = 17
  state.merge_incoming(frame)
  for local in 3..<6 {
    state.state.plan.edge(
      info.result_location,
      frame.incoming.unwrap().values.get(local).unwrap(),
    )
  }
  state.state.plan.commit(graph)
  graph.observe(info.result_location)
  graph.solve()
  assert_false(graph.used[info.param_locations[0]])
  assert_true(graph.used[info.param_locations[1]])
  assert_true(graph.used[info.param_locations[2]])
  assert_eq(state.remaining_work, 0)
  assert_eq(frame.incoming_epoch, state.state_epoch)
}

///|
test "DAE2 bounded scalar dedup merges each final local once despite duplicate events" {
  dae2_sparse_incoming_compare(dae2_sparse_exit_fixture(16, 4, 2))
  let (graph, info, state) = dae2_sparse_state_fixture(width=16)
  let frame = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1], width=16)
  state.merge_incoming(frame)
  dae2_sparse_state_pair(state, info)
  state.merge_incoming(frame)
  dae2_sparse_state_write(state, 3, info.param_locations[1])
  dae2_sparse_state_write(state, 4, info.param_locations[2])
  dae2_sparse_state_write(state, 3, info.param_locations[0])
  let writes = state.state.plan.write_locations.unwrap()
  let ignored = writes[writes.length() - 3].1
  let before = state.state.plan.count
  state.merge_incoming(frame)
  let after = state.state.plan.count
  dae2_sparse_state_solve(graph, info, state, frame)
  assert_true(graph.used[info.param_locations[0]])
  assert_true(graph.used[info.param_locations[2]])
  assert_false(graph.used[ignored])
  // join(phi, right) can allocate another phi even when right is already an
  // indirect child. Dedup must call the lane worker once per final local.
  assert_eq(after, before + 2)
}

///|
test "DAE2 scalar dedup whose worst work is not cheaper intentionally uses legacy lanes" {
  dae2_sparse_incoming_compare(dae2_sparse_exit_fixture(4, 4, 2))
  let (graph, info, state) = dae2_sparse_state_fixture(width=4)
  let frame = state.push_frame(0)
  dae2_sparse_state_seed(state, info.param_locations[1], width=4)
  state.merge_incoming(frame)
  dae2_sparse_state_pair(state, info)
  state.merge_incoming(frame)
  dae2_sparse_state_pair(state, info)
  // Two discovery events plus four legacy visits fit exactly. The bounded
  // two-event dedup worst case is five units and must not replace four lanes.
  state.remaining_work = 6
  state.merge_incoming(frame)
  for local in 3..<6 {
    state.state.plan.edge(
      info.result_location,
      frame.incoming.unwrap().values.get(local).unwrap(),
    )
  }
  state.state.plan.commit(graph)
  graph.observe(info.result_location)
  graph.solve()
  assert_false(graph.used[info.param_locations[0]])
  assert_true(graph.used[info.param_locations[1]])
  assert_true(graph.used[info.param_locations[2]])
  assert_eq(state.remaining_work, 0)
  assert_eq(frame.incoming_epoch, state.state_epoch)
}
