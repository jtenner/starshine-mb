///|
fn lower_result_stack_reference(
  func : HotFunc,
  id : NodeId,
  stack : Array[HotLowerStackValue],
) -> Unit {
  for val_type in hot_type_results(func, hot_node_type(func, id)) {
    stack.push({ node_id: id, val_type, })
  }
}

///|
fn lower_result_stack_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit raise {
  let func = HotFunc::new()
  let values = Array::make(width, @lib.ValType::i32())
  let shape = if width == 0 {
    hot_type_intern_void(func)
  } else if width == 1 {
    hot_type_intern_value(func, @lib.ValType::i32())
  } else {
    hot_type_intern_results(func, values)
  }
  let node = hot_build_node(func, HotOp::Nop, shape)
  let stack : Array[HotLowerStackValue] = []
  hot_lower_impl_push_results(func, node, stack)
  assert_eq(stack.length(), width)
  stack.clear()
  let revision = hot_revision_current(func)
  it.bench(fn() {
    if reference {
      lower_result_stack_reference(func, node, stack)
    } else {
      hot_lower_impl_push_results(func, node, stack)
    }
    it.keep(stack)
    stack.clear()
  })
  assert_eq(hot_type_results(func, shape), values)
  assert_eq(hot_revision_current(func), revision)
}

///|
test "bench lower result stack void owned" (it : @bench.T) {
  lower_result_stack_bench(it, 0, true)
}

///|
test "bench lower result stack void direct" (it : @bench.T) {
  lower_result_stack_bench(it, 0, false)
}

///|
test "bench lower result stack scalar owned" (it : @bench.T) {
  lower_result_stack_bench(it, 1, true)
}

///|
test "bench lower result stack scalar direct" (it : @bench.T) {
  lower_result_stack_bench(it, 1, false)
}

///|
test "bench lower result stack tuple owned" (it : @bench.T) {
  lower_result_stack_bench(it, 4, true)
}

///|
test "bench lower result stack tuple direct" (it : @bench.T) {
  lower_result_stack_bench(it, 4, false)
}
