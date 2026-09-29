///|
fn cfg_fixed_workspace_bench(
  it : @bench.T,
  count : Int,
  expanded : Bool,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  for _ in 0..<count {
    hot_root_append(func, hot_build_nop(func))
  }
  for _ in 0..<3 {
    hot_root_append(
      func,
      hot_build_block(func, @lib.BlockType::void_(), [hot_build_nop(func)]),
    )
  }
  let selected = cfg_builder_new(func, true, expanded)
  let original = cfg_fixed_workspace_reference_new(func, true, expanded)
  if selected.cfg != original.cfg ||
    selected.label_targets != original.label_targets ||
    selected.operand_seen != original.operand_seen ||
    selected.continuation_targets != original.continuation_targets {
    abort("fixed-span initialization changed CFG state")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        cfg_fixed_workspace_reference_new(func, true, expanded)
      } else {
        cfg_builder_new(func, true, expanded)
      },
    )
  })
}

///|
test "bench CFG fixed spans nodes=129 compact grown" (it : @bench.T) {
  cfg_fixed_workspace_bench(it, 129, false, true)
}

///|
test "bench CFG fixed spans nodes=129 compact sized" (it : @bench.T) {
  cfg_fixed_workspace_bench(it, 129, false, false)
}

///|
test "bench CFG fixed spans nodes=8193 compact grown" (it : @bench.T) {
  cfg_fixed_workspace_bench(it, 8193, false, true)
}

///|
test "bench CFG fixed spans nodes=8193 compact sized" (it : @bench.T) {
  cfg_fixed_workspace_bench(it, 8193, false, false)
}

///|
test "bench CFG fixed spans nodes=129 expanded grown" (it : @bench.T) {
  cfg_fixed_workspace_bench(it, 129, true, true)
}

///|
test "bench CFG fixed spans nodes=129 expanded sized" (it : @bench.T) {
  cfg_fixed_workspace_bench(it, 129, true, false)
}

///|
test "bench CFG fixed spans nodes=8193 expanded grown" (it : @bench.T) {
  cfg_fixed_workspace_bench(it, 8193, true, true)
}

///|
test "bench CFG fixed spans nodes=8193 expanded sized" (it : @bench.T) {
  cfg_fixed_workspace_bench(it, 8193, true, false)
}
