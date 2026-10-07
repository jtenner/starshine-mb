///|
test "RSE raw reference candidate lookup scales with matching values" {
  let width = 512
  let types = Array::make(width, @lib.ValType::eqref_null())
  let state = RseRawState::new(types, width, @validate.Env::new())
  let visits = [0]
  for local_id in 0..<width {
    assert_eq(
      rse_raw_refined_get_local(state, local_id, candidate_visits=Some(visits)),
      local_id,
    )
  }
  assert_true(visits[0] <= width * 2)
}

///|
test "RSE raw candidate index follows local writes and merged values" {
  let types = Array::make(4, @lib.ValType::eqref_null())
  let state = RseRawState::new(types, 4, @validate.Env::new())
  let first = state.local_values[0]
  let second = state.local_values[1]
  assert_eq(rse_raw_candidates_for_value(state, first), [0])
  rse_raw_local_set(state, 2, first)
  assert_eq(rse_raw_candidates_for_value(state, first), [0, 2])
  rse_raw_local_set(state, 0, second)
  assert_eq(rse_raw_candidates_for_value(state, first), [2])
  assert_eq(rse_raw_candidates_for_value(state, second), [0, 1])
  let branch = RseRawState::clone_from(state)
  rse_raw_local_set(branch, 3, first)
  assert_eq(rse_raw_candidates_for_value(branch, first), [2, 3])
  assert_eq(rse_raw_candidates_for_value(state, first), [2])
  rse_raw_merge_sources(state, [branch.local_values])
  assert_eq(rse_raw_candidates_for_value(state, first), [2, 3])
}

///|
test "bench RSE raw candidate linear reference width=512" (it : @bench.T) {
  let width = 512
  let types = Array::make(width, @lib.ValType::eqref_null())
  let state = RseRawState::new(types, width, @validate.Env::new())
  it.bench(fn() {
    let mut visits = 0
    for local_id in 0..<width {
      let value = state.local_values[local_id]
      for candidate_id in 0..<width {
        if state.local_values[candidate_id] == value {
          visits = visits + 1
        }
      }
    }
    it.keep(visits)
  })
}

///|
test "bench RSE raw indexed candidates width=512" (it : @bench.T) {
  let width = 512
  let types = Array::make(width, @lib.ValType::eqref_null())
  let state = RseRawState::new(types, width, @validate.Env::new())
  ignore(rse_raw_candidates_for_value(state, state.local_values[0]))
  it.bench(fn() {
    let mut visits = 0
    for local_id in 0..<width {
      let value = state.local_values[local_id]
      for _ in rse_raw_candidates_for_value(state, value) {
        visits = visits + 1
      }
    }
    it.keep(visits)
  })
}
