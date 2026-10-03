///|
fn lower_lazy_order_carried_fixture(width : Int) -> HotFunc {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let read = hot_build_local_get(func, 0)
  for index in 0..<width {
    hot_root_append(
      func,
      hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(index))),
    )
  }
  hot_root_append(func, hot_build_drop(func, read))
  hot_verify_all_or_abort(func)
  func
}

///|
fn lower_lazy_order_bench(
  it : @bench.T,
  width : Int,
  carried : Bool,
  reference : Bool,
) -> Unit raise {
  let func = if carried {
    lower_lazy_order_carried_fixture(width)
  } else {
    cfg_segment_storage_fixture(width)
  }
  lower_lazy_assert_eager_equivalent(func)
  let revision = hot_revision_current(func)
  it.bench(fn() {
    let frames = hot_lower_impl_new_label_frames(func)
    if reference {
      frames.source_order = Some(HotSourceOrderFacts::new(func))
    }
    it.keep(lower_lazy_raw_region(func, frames))
    it.keep(frames)
  })
  assert_eq(hot_revision_current(func), revision)
}

///|
test "bench lower ordering forward tiny eager" (it : @bench.T) {
  lower_lazy_order_bench(it, 1, false, true)
}

///|
test "bench lower ordering forward tiny lazy" (it : @bench.T) {
  lower_lazy_order_bench(it, 1, false, false)
}

///|
test "bench lower ordering forward wide eager" (it : @bench.T) {
  lower_lazy_order_bench(it, 256, false, true)
}

///|
test "bench lower ordering forward wide lazy" (it : @bench.T) {
  lower_lazy_order_bench(it, 256, false, false)
}

///|
test "bench lower ordering carried tiny eager" (it : @bench.T) {
  lower_lazy_order_bench(it, 1, true, true)
}

///|
test "bench lower ordering carried tiny lazy" (it : @bench.T) {
  lower_lazy_order_bench(it, 1, true, false)
}

///|
test "bench lower ordering carried wide eager" (it : @bench.T) {
  lower_lazy_order_bench(it, 256, true, true)
}

///|
test "bench lower ordering carried wide lazy" (it : @bench.T) {
  lower_lazy_order_bench(it, 256, true, false)
}
