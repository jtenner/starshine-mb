///|
fn hot_prefix_results_reference(
  func : HotFunc,
  id : NodeId,
  count : Int,
  value_stack : HotLowerValueStack,
) -> Unit {
  let node = hot_node_get(func, id)
  let input_ids : Array[NodeId] = []
  let input_occurrences : Array[Int] = []
  for i = 0; i < count; i = i + 1 {
    let input_id = func.children[node.child_base + i]
    let input_types = hot_type_results(func, hot_node_type(func, input_id))
    let mut occurrence = 0
    let mut existing = -1
    for idx = 0; idx < input_ids.length(); idx = idx + 1 {
      if input_ids[idx] == input_id {
        occurrence = input_occurrences[idx]
        existing = idx
        break
      }
    }
    if occurrence < input_types.length() {
      value_stack.push({ node_id: input_id, val_type: input_types[occurrence], })
    }
    if existing >= 0 {
      input_occurrences[existing] = occurrence + 1
    } else {
      input_ids.push(input_id)
      input_occurrences.push(1)
    }
  }
}

///|
fn hot_prefix_results_bench(it : @bench.T, before : Bool) -> Unit {
  let func = hot_lift_body(@lib.Expr::new([]), HotLocals::new())
  let inputs : Array[NodeId] = []
  for index in 0..<2048 {
    inputs.push(hot_build_const_i32(func, @lib.I32(index)))
  }
  let block = hot_build_block(func, @lib.BlockType::void_(), inputs)
  it.bench(fn() {
    let stack : HotLowerValueStack = hot_lower_value_stack_new()
    if before {
      hot_prefix_results_reference(func, block, inputs.length(), stack)
    } else {
      hot_lower_impl_push_control_prefix(func, block, inputs.length(), stack)
    }
    it.keep(stack)
  })
}

///|
#skip
test "bench 2048 control prefix lanes before run scan" (it : @bench.T) {
  hot_prefix_results_bench(it, true)
}

///|
#skip
test "bench 2048 control prefix lanes with run scan" (it : @bench.T) {
  hot_prefix_results_bench(it, false)
}
