///|
fn lower_stack_update_bench(it : @bench.T, width : Int) -> Unit {
  let func = HotFunc::new()
  let id = hot_build_const_i32(func, @lib.I32(7))
  let stack : HotLowerValueStack = hot_lower_value_stack_new()
  it.bench(fn() {
    stack.clear()
    for index in 0..<width {
      stack.push({ node_id: index, val_type: @lib.ValType::i32(), })
    }
    hot_lower_impl_update_stack(func, id, width, stack)
    it.keep(stack)
  })
}

///|
test "bench lower stack update consume2" (it : @bench.T) {
  lower_stack_update_bench(it, 2)
}

///|
test "bench lower stack update consume64" (it : @bench.T) {
  lower_stack_update_bench(it, 64)
}
