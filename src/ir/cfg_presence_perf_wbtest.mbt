///|
fn cfg_presence_bench(
  it : @bench.T,
  width : Int,
  kind : Int,
  before : Bool,
) -> Unit raise {
  let func = if kind == 2 {
    cfg_presence_lift(cfg_presence_continuation_module())
  } else {
    let f = HotFunc::new()
    for _ in 0..<width {
      hot_root_append(f, hot_build_nop(f))
    }
    if kind == 1 {
      ignore(
        hot_alloc_branch_table(
          f,
          HotBranchTable::new([], HOT_IMPLICIT_FUNCTION_LABEL),
        ),
      )
    }
    f
  }
  let actual = cfg_builder_new(func, true, true)
  let expected = cfg_presence_reference_new(func, true, true)
  assert_eq(actual.cfg, expected.cfg)
  assert_eq(actual.label_targets, expected.label_targets)
  assert_eq(actual.operand_seen, expected.operand_seen)
  assert_eq(actual.continuation_targets, expected.continuation_targets)
  it.bench(fn() {
    let builder = if before {
      cfg_presence_reference_new(func, true, true)
    } else {
      cfg_builder_new(func, true, true)
    }
    it.keep(
      builder.cfg.node_to_block.length() + builder.continuation_targets.length(),
    )
  })
}

///|
test "bench CFG presence empty before" (it : @bench.T) {
  cfg_presence_bench(it, 0, 0, true)
}

///|
test "bench CFG presence empty current" (it : @bench.T) {
  cfg_presence_bench(it, 0, 0, false)
}

///|
test "bench CFG presence small before" (it : @bench.T) {
  cfg_presence_bench(it, 32, 0, true)
}

///|
test "bench CFG presence small current" (it : @bench.T) {
  cfg_presence_bench(it, 32, 0, false)
}

///|
test "bench CFG presence wide before" (it : @bench.T) {
  cfg_presence_bench(it, 512, 0, true)
}

///|
test "bench CFG presence wide current" (it : @bench.T) {
  cfg_presence_bench(it, 512, 0, false)
}

///|
test "bench CFG presence small table before" (it : @bench.T) {
  cfg_presence_bench(it, 32, 1, true)
}

///|
test "bench CFG presence small table current" (it : @bench.T) {
  cfg_presence_bench(it, 32, 1, false)
}

///|
test "bench CFG presence wide table before" (it : @bench.T) {
  cfg_presence_bench(it, 512, 1, true)
}

///|
test "bench CFG presence wide table current" (it : @bench.T) {
  cfg_presence_bench(it, 512, 1, false)
}

///|
test "bench CFG presence resume before" (it : @bench.T) {
  cfg_presence_bench(it, 0, 2, true)
}

///|
test "bench CFG presence resume current" (it : @bench.T) {
  cfg_presence_bench(it, 0, 2, false)
}
