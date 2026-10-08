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
    read_flags: if kind >= 2 {
      1 << (kind - 2)
    } else {
      0
    },
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
    (
      fn(active) { lcse_raw_filter_active_without_global(exprs, active) },
      [6, 1, 0, 2, 3, 4, 7, 1],
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

///|
fn lcse_local_filter_perf_bench(it : @bench.T, writes : Int) -> Unit {
  let exprs = Array::makei(256, fn(_) { LcseRawExpr::review2_fixture(0) })
  let active : Array[Int] = []
  for idx in 0..<256 {
    active.push(idx)
  }
  lcse_raw_filter_active_without_local(exprs, active, 1)
  if active.length() != 256 {
    abort("Local CSE filter benchmark lost surviving expressions")
  }
  it.bench(fn() {
    for _ in 0..<writes {
      lcse_raw_filter_active_without_local(exprs, active, 1)
    }
    it.keep(active.length())
  })
}

///|
test "bench Local CSE retained filter writes=64" (it : @bench.T) {
  lcse_local_filter_perf_bench(it, 64)
}

///|
test "bench Local CSE retained filter writes=256" (it : @bench.T) {
  lcse_local_filter_perf_bench(it, 256)
}

///|
fn lcse_other_filter_perf_bench(it : @bench.T, kind : Int) -> Unit {
  let exprs = Array::makei(256, fn(_) { LcseRawExpr::review2_fixture(0) })
  let active : Array[Int] = []
  for idx in 0..<256 {
    active.push(idx)
  }
  it.bench(fn() {
    for _ in 0..<256 {
      match kind {
        0 => lcse_raw_filter_active_without_memory(exprs, active)
        1 => lcse_raw_filter_active_without_heap(exprs, active)
        _ => lcse_raw_remove_active_expr(active, -1)
      }
    }
    it.keep(active.length())
  })
}

///|
test "bench Local CSE retained memory filter writes=256" (it : @bench.T) {
  lcse_other_filter_perf_bench(it, 0)
}

///|
test "bench Local CSE retained heap filter writes=256" (it : @bench.T) {
  lcse_other_filter_perf_bench(it, 1)
}

///|
test "bench Local CSE absent active ID writes=256" (it : @bench.T) {
  lcse_other_filter_perf_bench(it, 2)
}
