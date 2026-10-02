///|
fn lower_use_counts_bench(
  it : @bench.T,
  width : Int,
  compact : Bool,
) -> Unit raise {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(16, @lib.ValType::i32())),
  )
  for index in 0..<width {
    let read = hot_build_local_get(func, index % 16)
    let add = hot_build_binary(
      func,
      @lib.ValType::i32(),
      read,
      hot_build_const_i32(func, @lib.I32(index)),
    )
    hot_root_append(func, hot_build_drop(func, add))
  }
  lower_use_counts_assert_equivalent(func)
  let revision = hot_revision_current(func)
  it.bench(fn() {
    if compact {
      it.keep(hot_node_use_counts_build(func))
    } else {
      it.keep(use_def_build_node_uses(func))
    }
  })
  assert_eq(hot_revision_current(func), revision)
}

///|
test "bench lower use counts tiny full sites" (it : @bench.T) {
  lower_use_counts_bench(it, 1, false)
}

///|
test "bench lower use counts tiny compact" (it : @bench.T) {
  lower_use_counts_bench(it, 1, true)
}

///|
test "bench lower use counts medium full sites" (it : @bench.T) {
  lower_use_counts_bench(it, 16, false)
}

///|
test "bench lower use counts medium compact" (it : @bench.T) {
  lower_use_counts_bench(it, 16, true)
}

///|
test "bench lower use counts wide full sites" (it : @bench.T) {
  lower_use_counts_bench(it, 256, false)
}

///|
test "bench lower use counts wide compact" (it : @bench.T) {
  lower_use_counts_bench(it, 256, true)
}
