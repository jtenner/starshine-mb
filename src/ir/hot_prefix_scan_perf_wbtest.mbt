///|
fn hot_prefix_scan_bench(it : @bench.T, count : Int) -> Unit raise {
  let types = Array::make(count, "i32").join(" ")
  let constants = Array::make(count, "i32.const 7").join(" ")
  let input = @wast.wast_to_binary_module(
    "(module (type (func (param " +
    types +
    ") (result " +
    types +
    "))) (func (result " +
    types +
    ") " +
    constants +
    " block (type 0) end))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let block = hot_root_get(func, 0)
  assert_eq(hot_node_get(func, block).imm1, count)
  hot_verify_control(func).unwrap()
  let use_def = hot_node_use_counts_build(func)
  let frames = hot_lower_impl_new_label_frames(func)
  let options = HotLowerOptions::new()
  let output = hot_lower_impl_body_items(
    func,
    block,
    use_def,
    frames,
    -1,
    [],
    options,
  )
  assert_eq(output.length(), 0)
  it.bench(fn() {
    it.keep(
      hot_lower_impl_body_items(func, block, use_def, frames, -1, [], options),
    )
  })
}

///|
#skip
test "bench explicit prefix producer scan 32 distinct producers" (it : @bench.T) {
  hot_prefix_scan_bench(it, 32)
}

///|
#skip
test "bench explicit prefix producer scan 128 distinct producers" (
  it : @bench.T,
) {
  hot_prefix_scan_bench(it, 128)
}

///|
#skip
test "bench explicit prefix producer scan 512 distinct producers" (
  it : @bench.T,
) {
  hot_prefix_scan_bench(it, 512)
}

///|
#skip
test "bench explicit prefix producer scan 2048 distinct producers" (
  it : @bench.T,
) {
  hot_prefix_scan_bench(it, 2048)
}
