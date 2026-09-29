///|
fn sl_wrapper_retirement_fixture(width : Int) -> @lib.Module {
  let wat = ["(module (func (result i32) (local i32)"]
  for _ in 0..<width {
    wat.push("i32.const 7 local.set 0")
  }
  wat.push("local.get 0))")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn sl_wrapper_retirement_batch(
  input : @lib.Module,
  reference : Bool,
) -> @ir.HotFunc {
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let set = @ir.hot_root_get(func, 0)
  let value = @ir.hot_child_get(func, set, 0)
  for kind in 0..<5 {
    if reference {
      let scratch = match kind {
        0 => @ir.hot_build_nop(func)
        1 => @ir.hot_build_drop(func, value)
        2 => @ir.hot_build_local_get(func, 0)
        3 => @ir.hot_build_local_tee_from_set(func, set)
        _ => @ir.hot_build_local_set_from_value(func, 0, value)
      }
      // Frozen previous factories used checked arena-wide deletion here.
      let _ = @ir.hot_node_get(func, scratch)
      @ir.hot_delete_node(func, scratch)
    } else {
      let _ = match kind {
        0 => simplify_locals_make_nop(func)
        1 => simplify_locals_make_drop(func, value)
        2 => simplify_locals_make_local_get(func, 0)
        3 => simplify_locals_make_local_tee(func, set)
        _ => simplify_locals_make_local_set(func, 0, value)
      }
    }
  }
  func
}

///|
fn sl_wrapper_retirement_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let input = sl_wrapper_retirement_fixture(width)
  let saved = @binary.encode_module(input).unwrap()
  let before = sl_wrapper_retirement_batch(input, true)
  let after = sl_wrapper_retirement_batch(input, false)
  @ir.hot_verify_all(before).unwrap()
  @ir.hot_verify_all(after).unwrap()
  if before.nodes != after.nodes ||
    before.children != after.children ||
    @ir.hot_lower_func(after) != @ir.hot_lower_func(before) {
    abort("fresh wrapper retirement changed node order, spans or body")
  }
  @validate.validate_module(
    input.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(after)])),
  ).unwrap()
  // Fresh lift per iteration keeps arena size bounded instead of accumulating
  // tombstones across calibrator batches; both sides include that same lift.
  it.bench(fn() { it.keep(sl_wrapper_retirement_batch(input, reference)) })
  if @binary.encode_module(input).unwrap() != saved {
    abort("fresh wrapper benchmark mutated input")
  }
}

///|
test "bench SL replacement retirement width=1 checked reference" (it : @bench.T) {
  sl_wrapper_retirement_bench(it, 1, true)
}

///|
test "bench SL replacement retirement width=1 fresh detached" (it : @bench.T) {
  sl_wrapper_retirement_bench(it, 1, false)
}

///|
test "bench SL replacement retirement width=128 checked reference" (
  it : @bench.T,
) {
  sl_wrapper_retirement_bench(it, 128, true)
}

///|
test "bench SL replacement retirement width=128 fresh detached" (it : @bench.T) {
  sl_wrapper_retirement_bench(it, 128, false)
}

///|
test "bench SL replacement retirement width=4096 checked reference" (
  it : @bench.T,
) {
  sl_wrapper_retirement_bench(it, 4096, true)
}

///|
test "bench SL replacement retirement width=4096 fresh detached" (it : @bench.T) {
  sl_wrapper_retirement_bench(it, 4096, false)
}
