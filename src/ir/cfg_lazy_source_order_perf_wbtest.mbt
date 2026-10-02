///|
fn cfg_lazy_source_order_bench(
  it : @bench.T,
  width : Int,
  multi : Bool,
  eager : Bool,
  carried? : Bool = false,
) -> Unit {
  let func = if carried {
    let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
    let read = hot_build_local_get(func, 0)
    hot_root_append(
      func,
      hot_build_local_set(func, 0, hot_build_const_i32(func, @lib.I32(9))),
    )
    hot_root_append(func, hot_build_drop(func, read))
    for _ in 0..<width {
      hot_root_append(func, hot_build_nop(func))
    }
    func
  } else if multi {
    cfg_segment_storage_fixture(width)
  } else {
    let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
    let mut value = hot_build_local_get(func, 0)
    for i in 0..<width {
      value = hot_build_select(
        func,
        @lib.ValType::i32(),
        value,
        hot_build_const_i32(func, @lib.I32(i)),
        hot_build_const_i32(func, @lib.I32(1)),
      )
    }
    let drop = hot_build_drop(func, value)
    hot_root_append(
      func,
      hot_build_block(func, @lib.BlockType::void_(), [drop]),
    )
    func
  }
  hot_verify_all_or_abort(func)
  cfg_verify(cfg_build(func, expand_operand_control=true))
  let run = fn(old) {
    let builder = cfg_builder_new(func, true, true)
    if old && builder.source_order is None {
      builder.source_order = Some(HotSourceOrderFacts::new(func))
    }
    ignore(cfg_builder_region_segments(builder, func, HotRegionRef::root()))
    builder.cfg
  }
  if run(true) != run(false) {
    abort("deferred CFG setup changed operands, edges or root mappings")
  }
  it.bench(fn() { it.keep(run(eager)) })
}

///|
test "bench CFG source setup single width=8 eager" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 8, false, true)
}

///|
test "bench CFG source setup single width=8 demand" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 8, false, false)
}

///|
test "bench CFG source setup single width=128 eager" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 128, false, true)
}

///|
test "bench CFG source setup single width=128 demand" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 128, false, false)
}

///|
test "bench CFG source setup multi width=8 eager" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 8, true, true)
}

///|
test "bench CFG source setup multi width=8 demand" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 8, true, false)
}

///|
test "bench CFG source setup multi width=64 eager" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 64, true, true)
}

///|
test "bench CFG source setup multi width=64 demand" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 64, true, false)
}

///|
test "bench CFG source setup carried width=8 eager" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 8, true, true, carried=true)
}

///|
test "bench CFG source setup carried width=8 demand" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 8, true, false, carried=true)
}

///|
test "bench CFG source setup carried width=128 eager" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 128, true, true, carried=true)
}

///|
test "bench CFG source setup carried width=128 demand" (it : @bench.T) {
  cfg_lazy_source_order_bench(it, 128, true, false, carried=true)
}
