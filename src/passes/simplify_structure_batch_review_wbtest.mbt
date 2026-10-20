///|
fn sl_structure_batch_review_fixture(
  count : Int32,
  shared~ : Bool = false,
) -> (@ir.HotFunc, Array[Int32]) {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=Array::make(count, @lib.ValType::i32())),
  )
  let controls : Array[Int32] = []
  for index in 0..<count {
    let local = if shared { 0 } else { index }
    let control = @ir.hot_build_if(
      func,
      @lib.BlockType::void_(),
      @ir.hot_build_const_i32(func, @lib.I32(1)),
      [
        @ir.hot_build_local_set_from_value(
          func,
          local,
          @ir.hot_build_const_i32(func, @lib.I32(9)),
        ),
      ],
    )
    controls.push(control)
    @ir.hot_root_append(func, control)
    @ir.hot_root_append(
      func,
      @ir.hot_build_drop(func, @ir.hot_build_local_get(func, local)),
    )
  }
  (func, controls)
}

///|
test "simplify structure applies independent local rewrites in one scan" {
  let (func, controls) = sl_structure_batch_review_fixture(8)
  assert_true(simplify_locals_run_structure_rewrites(func, []))
  for control in controls {
    assert_eq(@ir.hot_node_result_arity(func, control), 1)
  }
  @ir.hot_verify_core(func).unwrap()
  @ir.hot_verify_control(func).unwrap()
}

///|
test "simplify structure defers writers sharing a local until the next cycle" {
  let (func, controls) = sl_structure_batch_review_fixture(2, shared=true)
  assert_true(simplify_locals_run_structure_rewrites(func, []))
  assert_eq(@ir.hot_node_result_arity(func, controls[0]), 1)
  assert_eq(@ir.hot_node_result_arity(func, controls[1]), 0)
  assert_true(simplify_locals_run_structure_rewrites(func, []))
  assert_eq(@ir.hot_node_result_arity(func, controls[1]), 1)
}

///|
fn sl_structure_batch_finish(
  count : Int32,
  batch : Bool,
  shared~ : Bool = false,
) -> (@lib.Func, Int32) {
  let (func, _) = sl_structure_batch_review_fixture(count, shared~)
  let mut cycles = 0
  while true {
    cycles += 1
    let detached : Array[Int32] = []
    let changed = simplify_locals_run_structure_rewrites(
      func,
      detached,
      batch_independent=batch,
    )
    simplify_locals_delete_detached_nodes(func, detached)
    if !changed {
      break
    }
    if cycles > count + 1 {
      abort("structure cleanup did not converge")
    }
  }
  (@ir.hot_lower_func(func), cycles)
}

///|
test "simplify structure batched cleanup retains the exact lowered function" {
  let (before, old_cycles) = sl_structure_batch_finish(8, false)
  let (after, new_cycles) = sl_structure_batch_finish(8, true)
  assert_eq(after, before)
  assert_eq(old_cycles, 9)
  assert_eq(new_cycles, 2)
  // Rewrites of the same local must keep the original count-refresh boundary.
  let (shared_before, shared_old_cycles) = sl_structure_batch_finish(
    8,
    false,
    shared=true,
  )
  let (shared_after, shared_new_cycles) = sl_structure_batch_finish(
    8,
    true,
    shared=true,
  )
  assert_eq(shared_after, shared_before)
  assert_eq(shared_new_cycles, shared_old_cycles)
}

///|
fn sl_structure_batch_review_bench(
  it : @bench.T,
  count : Int32,
  batch : Bool,
) -> Unit {
  let (before, _) = sl_structure_batch_finish(count, false)
  let (after, _) = sl_structure_batch_finish(count, true)
  if before != after {
    abort("structure batching changed the lowered function")
  }
  it.bench(fn() { it.keep(sl_structure_batch_finish(count, batch)) })
}

///|
fn sl_structure_full_review_bench(
  it : @bench.T,
  count : Int32,
  batch : Bool,
) -> Unit {
  it.bench(fn() {
    let (func, _) = sl_structure_batch_review_fixture(count)
    let ctx = HotPassContext::new(
      simplify_locals_descriptor(),
      @ir.HotAnalysisCache::new(),
      HotPipelineVerifyPolicy::after_each_pass(),
      false,
      fn(_) { () },
    )
    it.keep(
      simplify_locals_run_with_options(
        ctx,
        func,
        SimplifyLocalsPolicy::new(true, true, true),
        batch_structure_rewrites=batch,
      ),
    )
    it.keep(@ir.hot_lower_func(func))
  })
}

///|
test "bench simplify structure successful single 32" (it : @bench.T) {
  sl_structure_batch_review_bench(it, 32, false)
}

///|
test "bench simplify structure successful batched 32" (it : @bench.T) {
  sl_structure_batch_review_bench(it, 32, true)
}

///|
test "bench simplify structure successful single 64" (it : @bench.T) {
  sl_structure_batch_review_bench(it, 64, false)
}

///|
test "bench simplify structure successful batched 64" (it : @bench.T) {
  sl_structure_batch_review_bench(it, 64, true)
}

///|
test "bench simplify structure successful single 128" (it : @bench.T) {
  sl_structure_batch_review_bench(it, 128, false)
}

///|
test "bench simplify structure successful batched 128" (it : @bench.T) {
  sl_structure_batch_review_bench(it, 128, true)
}

///|
test "bench simplify full successful single 32" (it : @bench.T) {
  sl_structure_full_review_bench(it, 32, false)
}

///|
test "bench simplify full successful batched 32" (it : @bench.T) {
  sl_structure_full_review_bench(it, 32, true)
}

///|
test "bench simplify full successful single 64" (it : @bench.T) {
  sl_structure_full_review_bench(it, 64, false)
}

///|
test "bench simplify full successful batched 64" (it : @bench.T) {
  sl_structure_full_review_bench(it, 64, true)
}

///|
test "bench simplify full successful single 128" (it : @bench.T) {
  sl_structure_full_review_bench(it, 128, false)
}

///|
test "bench simplify full successful batched 128" (it : @bench.T) {
  sl_structure_full_review_bench(it, 128, true)
}
