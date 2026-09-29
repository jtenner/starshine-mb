///|
test "DAE child scan restores traversal scratch and owns recorded call paths" {
  let path = [99]
  let direct = [0, 0]
  let tails = [false, false]
  let callers = dae_make_direct_callers(2)
  let dropped = [0, 0]
  let escaped = [false, false]
  let infos = dae_make_function_infos(2, escaped)
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
  ]
  assert_false(
    dae_scan_current_call_facts_child(
      body,
      1,
      1,
      path,
      7,
      2,
      direct,
      tails,
      callers,
      dropped,
      escaped,
      infos,
      [-1, -1],
      true,
    ),
  )
  assert_eq(path, [99])
  assert_eq(infos[0].calls[0].path, [99, 7, 2, 0])
  assert_eq(direct, [1, 0])
  assert_eq(dropped, [1, 0])
  let capacity = path.capacity()
  assert_false(
    dae_scan_current_call_facts_child(
      body,
      1,
      1,
      path,
      8,
      3,
      direct,
      tails,
      callers,
      dropped,
      escaped,
      infos,
      [-1, -1],
      false,
    ),
  )
  assert_eq(path, [99])
  assert_eq(path.capacity(), capacity)
  assert_eq(infos[0].calls[1].path, [99, 8, 3, 0])
  path[0] = 88
  assert_eq(infos[0].calls[0].path, [99, 7, 2, 0])
  assert_eq(infos[0].dropped_calls[0].path, [99, 7, 2, 0])
}

///|
test "DAE child scratch retains singleton trap summaries in count-only scans" {
  let path = [99]
  let capacity = path.capacity()
  assert_true(
    dae_scan_current_call_facts_child(
      [@lib.Instruction::unreachable_()],
      0,
      0,
      path,
      7,
      0,
      [0],
      [false],
      [[]],
      [0],
      [false],
      [],
      [-1],
      true,
    ),
  )
  assert_eq(path, [99])
  assert_eq(path.capacity(), capacity)
}
