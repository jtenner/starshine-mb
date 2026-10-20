///|
fn sl_structure_scan_review_fixture(depth : Int32) -> @ir.HotFunc {
  let func = @ir.HotFunc::new()
  let mut root = @ir.hot_build_nop(func)
  for _ in 0..<depth {
    root = @ir.hot_build_block(func, @lib.BlockType::void_(), [root])
  }
  @ir.hot_root_append(func, root)
  func
}

///|
test "simplify structure census retains one-armed if and block return candidates" {
  let flat = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.add))",
  )
  assert_eq(simplify_locals_structure_control_flags(flat), (false, false))
  assert_false(simplify_locals_run_structure_rewrites(flat, []))
  let blocks = sl_structure_scan_review_fixture(8)
  assert_eq(simplify_locals_structure_control_flags(blocks), (true, false))
  assert_false(simplify_locals_run_structure_rewrites(blocks, []))
  let conditional = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 9 local.set 1 end local.get 1))",
  )
  assert_eq(simplify_locals_structure_control_flags(conditional), (true, true))
  assert_true(simplify_locals_run_structure_rewrites(conditional, []))
  let returning_block = pass_test_lift_first_func(
    "(module (func (param i32) (local i32) block i32.const 7 local.set 1 local.get 0 br_if 0 i32.const 9 local.set 1 end local.get 1 drop))",
  )
  assert_eq(
    simplify_locals_structure_control_flags(returning_block),
    (true, false),
  )
  assert_true(simplify_locals_run_structure_rewrites(returning_block, []))
}

///|
fn sl_structure_scan_review_bench(
  it : @bench.T,
  depth : Int32,
  reference : Bool,
) -> Unit {
  let func = sl_structure_scan_review_fixture(depth)
  it.bench(fn() {
    let changed = if reference {
      simplify_locals_try_structure_rewrite_region(
        func,
        @ir.HotRegionRef::root(),
        simplify_locals_count_local_gets(func),
        [],
      )
    } else {
      simplify_locals_run_structure_rewrites(func, [])
    }
    if changed {
      abort("structure scan changed inert block tree")
    }
    it.keep(func)
  })
}

///|
test "bench simplify structure repeated scans depth=16" (it : @bench.T) {
  sl_structure_scan_review_bench(it, 16, true)
}

///|
test "bench simplify structure candidate census depth=16" (it : @bench.T) {
  sl_structure_scan_review_bench(it, 16, false)
}

///|
test "bench simplify structure repeated scans depth=256" (it : @bench.T) {
  sl_structure_scan_review_bench(it, 256, true)
}

///|
test "bench simplify structure candidate census depth=256" (it : @bench.T) {
  sl_structure_scan_review_bench(it, 256, false)
}
