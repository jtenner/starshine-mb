///|
fn cl_branch_live_storage_result(
  body : Array[@lib.Instruction],
  live_after : Array[Bool],
  labels : Array[Array[Bool]],
  exception_live : Array[Bool],
  reference : Bool,
) -> (Array[Bool], Array[Bool], FixedArray[UInt64], Int, Int) {
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, live_after.length())
  let effective = Array::make(actions.length(), false)
  let hazards = CLBitMatrix::new(live_after.length())
  let visited = [0]
  let cursor = [actions.length() - 1]
  let live = if reference {
    cl_control_liveness_reference(
      body,
      actions,
      effective,
      hazards,
      visited,
      live_after,
      labels,
      cursor,
      exception_live~,
    )
  } else {
    cl_mark_structured_liveness_backward(
      body,
      actions,
      effective,
      hazards,
      visited,
      live_after,
      labels,
      cursor,
      exception_live~,
    )
  }
  (live, effective, hazards.bits.words, visited[0], cursor[0])
}

///|
test "coalesce branch joins preserve exact liveness hazards and caller rows" {
  for
    source in [
      "local.get 0 if local.get 1 local.set 2 else local.get 3 local.set 2 end local.get 2 drop",
      "block local.get 0 if i32.const 7 local.set 1 local.get 2 drop br 1 else local.get 3 drop end local.get 1 drop end local.get 2 drop",
      "block try_table (catch $e 0) local.get 0 if i32.const 7 local.set 1 throw $e else local.get 3 drop end end end local.get 1 drop",
      "local.get 0 if local.get 1 local.set 2 end local.get 2 drop",
    ] {
    let input = pass_test_module_from_wat(
      "(module (tag $e) (func (param i32) (local i32 i32 i32) \{source}))",
    )
    @validate.validate_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let live_after = [false, true, false, true]
    let labels = [[true, false, true, false]]
    let exception_live = [false, false, true, false]
    let before = live_after.copy()
    let saved_labels = labels.map(fn(row) { row.copy() })
    let saved_exception = exception_live.copy()
    let actual = cl_branch_live_storage_result(
      body, live_after, labels, exception_live, false,
    )
    assert_eq(
      actual,
      cl_branch_live_storage_result(
        body, live_after, labels, exception_live, true,
      ),
    )
    actual.0[0] = !actual.0[0]
    assert_eq(live_after, before)
    assert_eq(labels, saved_labels)
    assert_eq(exception_live, saved_exception)
  }
}

///|
test "coalesce branch joins retain both effective writes and owned empty results" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local i32 i32 i32) local.get 0 if local.get 1 local.set 2 else local.get 3 local.set 2 end local.get 2 drop))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let result = cl_branch_live_storage_result(
    body,
    [false, false, false, false],
    [],
    [],
    false,
  )
  assert_eq(result.0, [true, true, false, true])
  assert_eq(result.1, [false, false, true, false, true, false])
  assert_eq(result.3, 6)
  assert_eq(result.4, -1)
  let empty_input = pass_test_module_from_wat(
    "(module (func i32.const 0 if nop end))",
  )
  let @lib.Func(_, @lib.Expr(empty_body)) = empty_input.code_sec.unwrap().0[0]
  let seed : Array[Bool] = []
  let empty_result = cl_branch_live_storage_result(
    empty_body,
    seed,
    [],
    [],
    false,
  )
  empty_result.0.push(true)
  assert_eq(seed, [])
}
