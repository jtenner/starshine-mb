///|
fn block_liveness_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit raise {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(96, @lib.ValType::i32())),
  )
  for index in 0..<width {
    let read = hot_build_local_get(func, index % 96)
    let add = hot_build_binary(
      func,
      @lib.ValType::i32(),
      read,
      hot_build_const_i32(func, @lib.I32(index)),
    )
    hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
    hot_root_append(func, hot_build_drop(func, add))
  }
  let cfg = cfg_build(func, expand_operand_control=true)
  block_liveness_assert_equivalent(func, cfg)
  let revision = hot_revision_current(func)
  it.bench(fn() {
    it.keep(
      if reference {
        liveness_build(cfg, use_def_build(func, cfg=Some(cfg)))
      } else {
        liveness_build_from_func(func, cfg)
      },
    )
  })
  assert_eq(hot_revision_current(func), revision)
}

///|
test "bench block liveness tiny full" (it : @bench.T) {
  block_liveness_bench(it, 1, true)
}

///|
test "bench block liveness tiny direct" (it : @bench.T) {
  block_liveness_bench(it, 1, false)
}

///|
test "bench block liveness medium full" (it : @bench.T) {
  block_liveness_bench(it, 16, true)
}

///|
test "bench block liveness medium direct" (it : @bench.T) {
  block_liveness_bench(it, 16, false)
}

///|
test "bench block liveness wide full" (it : @bench.T) {
  block_liveness_bench(it, 256, true)
}

///|
test "bench block liveness wide direct" (it : @bench.T) {
  block_liveness_bench(it, 256, false)
}
