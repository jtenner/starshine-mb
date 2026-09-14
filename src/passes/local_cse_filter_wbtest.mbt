///|
fn LcseRawExpr::review2_fixture(kind : Int) -> LcseRawExpr {
  {
    start: 0,
    end: 0,
    instr: @lib.Instruction::i32_const(@lib.I32(0)),
    key: 0,
    ty: @lib.ValType::i32(),
    size: 1,
    children: [],
    reads_locals: if kind == 1 {
      [0]
    } else {
      []
    },
    reads_memory: kind == 2,
    reads_memory_size: kind == 3,
    reads_table_state: kind == 4,
    reads_global: kind == 5,
    reads_heap: kind == 6,
    reads_atomic: kind == 7,
    reads_call: kind == 8,
    cache_child_for_replay: false,
    repeat_of: -1,
    local_id: -1,
    replay_local_ids: [],
  }
}

///|
test "review2 local-cse stable filters preserve duplicate survivor order" {
  let exprs = Array::makei(9, fn(i) { LcseRawExpr::review2_fixture(i) })
  let filters : Array[((Array[Int]) -> Unit, Array[Int])] = [
    (
      fn(active) { lcse_raw_filter_active_without_memory(exprs, active) },
      [6, 1, 0, 3, 4, 5, 7, 1],
    ),
    (
      fn(active) {
        lcse_raw_filter_active_without_memory_or_size(exprs, active)
      },
      [6, 1, 0, 4, 5, 7, 1],
    ),
    (
      fn(active) { lcse_raw_filter_active_without_local(exprs, active, 0) },
      [6, 0, 2, 3, 4, 5, 7, 8],
    ),
    (
      fn(active) { lcse_raw_filter_active_without_call(exprs, active) },
      [6, 1, 0, 2, 3, 4, 5, 7, 1],
    ),
    (
      fn(active) { lcse_raw_filter_active_without_heap(exprs, active) },
      [1, 0, 2, 3, 4, 5, 7, 1],
    ),
    (fn(active) { lcse_raw_filter_active_local_only(exprs, active) }, [1, 0, 1]),
  ]
  for (filter, expected) in filters {
    // Invalid IDs are intentionally unsupported entries and must be discarded.
    let active = [-1, 6, 1, 0, 2, 3, 4, 5, 7, 8, 1, 99]
    filter(active)
    assert_true(active == expected)
    filter(active)
    assert_true(active == expected)
    active.clear()
    filter(active)
    assert_true(active.is_empty())
    active.push(8)
    filter(active)
    if expected.contains(8) {
      assert_true(active == [8])
    } else {
      assert_true(active.is_empty())
    }
  }
  let active = [3, 2, 3, 0, 2]
  lcse_raw_remove_active_expr(active, 3)
  assert_true(active == [2, 0, 2])
  lcse_raw_remove_active_expr(active, 9)
  assert_true(active == [2, 0, 2])
  lcse_raw_remove_active_expr(active, 2)
  lcse_raw_remove_active_expr(active, 0)
  assert_true(active.is_empty())
}
