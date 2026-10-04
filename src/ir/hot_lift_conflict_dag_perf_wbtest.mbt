///|
fn lift_conflict_dag_bench(it : @bench.T, kind : Int) -> Unit raise {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(129, @lib.ValType::i32())),
  )
  let mut value = hot_build_local_get(func, 64)
  if kind >= 2 {
    value = hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      hot_build_local_get(func, 128),
    )
  }
  let shared = kind >= 4
  let depth = if kind == 0 { 0 } else if shared { 12 } else { 32 }
  for _ in 0..<depth {
    value = hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      if shared {
        value
      } else {
        hot_build_const_i32(func, @lib.I32(1))
      },
    )
  }
  let warm = kind == 3 || kind == 5
  let masks = HotLiftLocalAccessMasks::new()
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      true,
      masks=Some(masks),
    ),
  )
  assert_eq(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      64,
      true,
      masks=Some(masks),
    ),
    hot_lift_impl_value_conflicts_with_local_access(func, value, 64, true),
  )
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      true,
      masks=Some(masks),
    ),
  )
  let revision = hot_revision_current(func)
  it.bench(fn() {
    let selected = if kind == 0 {
      None
    } else if warm {
      Some(masks)
    } else {
      Some(HotLiftLocalAccessMasks::new())
    }
    it.keep(
      hot_lift_impl_value_conflicts_with_local_access(
        func,
        value,
        0,
        true,
        masks=selected,
      ),
    )
  })
  assert_eq(hot_revision_current(func), revision)
}

///|
test "bench lift exact conflicts leaf control" (it : @bench.T) {
  lift_conflict_dag_bench(it, 0)
}

///|
test "bench lift exact conflicts single-band cold32" (it : @bench.T) {
  lift_conflict_dag_bench(it, 1)
}

///|
test "bench lift exact conflicts mixed-tree cold32" (it : @bench.T) {
  lift_conflict_dag_bench(it, 2)
}

///|
test "bench lift exact conflicts mixed-tree warm32" (it : @bench.T) {
  lift_conflict_dag_bench(it, 3)
}

///|
test "bench lift exact conflicts shared-DAG cold12" (it : @bench.T) {
  lift_conflict_dag_bench(it, 4)
}

///|
test "bench lift exact conflicts shared-DAG warm12" (it : @bench.T) {
  lift_conflict_dag_bench(it, 5)
}
