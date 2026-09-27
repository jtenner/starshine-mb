///|
priv struct HotLowerCopiedInputs {
  nodes : Array[NodeId]
  pop_count : Int
}

///|
fn hot_lower_copy_input_reference(
  func : HotFunc,
  id : NodeId,
) -> HotLowerCopiedInputs {
  let node = hot_node_get(func, id)
  match node.op {
    HotOp::Block
    | HotOp::Try
    | HotOp::TryTable
    | HotOp::Nop
    | HotOp::Unreachable
    | HotOp::Const
    | HotOp::RefNull
    | HotOp::LocalGet
    | HotOp::GlobalGet
    | HotOp::MemorySize
    | HotOp::TableSize
    | HotOp::DataDrop
    | HotOp::ElemDrop
    | HotOp::RefFunc => { nodes: [], pop_count: 0, }
    HotOp::Loop => {
      let out : Array[NodeId] = []
      let input_count = hot_label_branch_arity(
        func,
        hot_control_node_label(func, id),
      )
      for i = 0; i < input_count; i = i + 1 {
        out.push(func.children[node.child_base + i])
      }
      { nodes: out, pop_count: input_count, }
    }
    HotOp::If => { nodes: [func.children[node.child_base]], pop_count: 1, }
    _ => {
      let out : Array[NodeId] = []
      for i = 0; i < node.child_count; i = i + 1 {
        let child = func.children[node.child_base + i]
        if child != HOT_NONE_NODE {
          out.push(child)
        }
      }
      let pop_count = match node.op {
        HotOp::BrIf | HotOp::BrTable | HotOp::BrOnNull | HotOp::BrOnNonNull => 1
        HotOp::BrOnCast | HotOp::BrOnCastFail =>
          match hot_node_exact_instr(func, id) {
            Some(@lib.BrOnCastDescEq(_, _, _))
            | Some(@lib.BrOnCastDescEqFail(_, _, _)) => 2
            _ => 1
          }
        _ => out.length()
      }
      { nodes: out, pop_count, }
    }
  }
}

///|
fn hot_lower_input_view_benchmark(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  let args = Array::makei(width, fn(i) {
    hot_build_const_i32(func, @lib.I32(i))
  })
  let call = hot_build_call(func, 0, [], args)
  let expected = hot_lower_copy_input_reference(func, call)
  let actual = hot_lower_impl_input_info(func, call)
  if actual.nodes.to_owned() != expected.nodes ||
    actual.pop_count != expected.pop_count {
    abort("operand query changed input lanes")
  }
  it.bench(fn() {
    for _ in 0..<256 {
      if reference {
        it.keep(hot_lower_copy_input_reference(func, call))
      } else {
        it.keep(hot_lower_impl_input_info(func, call))
      }
    }
  })
}

///|
test "bench lower operands copy width=2 queries=256" (it : @bench.T) {
  hot_lower_input_view_benchmark(it, 2, true)
}

///|
test "bench lower operands view width=2 queries=256" (it : @bench.T) {
  hot_lower_input_view_benchmark(it, 2, false)
}

///|
test "bench lower operands copy width=128 queries=256" (it : @bench.T) {
  hot_lower_input_view_benchmark(it, 128, true)
}

///|
test "bench lower operands view width=128 queries=256" (it : @bench.T) {
  hot_lower_input_view_benchmark(it, 128, false)
}
