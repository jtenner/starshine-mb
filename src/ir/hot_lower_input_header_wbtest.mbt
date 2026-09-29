///|
fn input_header_assert_queries(func : HotFunc) -> Unit raise {
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  for node in 0..<hot_node_count(func) {
    if !hot_node_is_live(func, node) {
      continue
    }
    let actual_copies = [0]
    let reference_copies = [0]
    let actual = hot_lower_impl_input_info(
      func,
      node,
      copied_slots=Some(actual_copies),
    )
    let expected = input_header_reference_info(
      func,
      node,
      copied_slots=Some(reference_copies),
    )
    assert_eq(actual.nodes.to_owned(), expected.nodes.to_owned())
    assert_eq(actual.pop_count, expected.pop_count)
    assert_eq(actual_copies, reference_copies)
  }
  assert_eq(hot_revision_current(func), revision)
  assert_eq(func.free_nodes, free)
}

///|
test "inline checked header reads preserve every operand role in control fixtures" {
  input_header_assert_queries(cfg_segment_storage_fixture(4))
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(7))
  let second = hot_build_const_i32(func, @lib.I32(9))
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let body = hot_build_drop(func, first)
  ignore(hot_build_block(func, @lib.BlockType::void_(), [body]))
  ignore(
    hot_build_if(
      func,
      @lib.BlockType::void_(),
      condition,
      [body],
      else_body=Some([]),
    ),
  )
  let ty = hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [],
  )
  let loop_node = hot_build_node(func, HotOp::Loop, ty, children=[
    first, second, body,
  ])
  let label = hot_label_alloc(func, HotLabelKind::LoopLabel, ty, loop_node, 2)
  hot_node_set(func, loop_node, {
    ..hot_node_get(func, loop_node),
    imm0: label,
  })
  input_header_assert_queries(func)
  let inputs = hot_lower_impl_input_info(func, loop_node)
  assert_eq(inputs.nodes.to_owned(), [first, second])
  assert_eq(inputs.pop_count, 2)
}

///|
test "inline checked header reads preserve sparse lanes and legacy live admission" {
  let func = HotFunc::new()
  let deleted = hot_build_nop(func)
  let tuple = hot_build_call(
    func,
    0,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [],
  )
  let consumer = hot_build_call(func, 1, [], [tuple, tuple])
  // Intentionally absent slots are supported by the operand-query contract,
  // including temporary HOT nodes before encoded-module validation.
  let sparse = hot_build_node(func, HotOp::Call, hot_type_void(func), children=[
    tuple,
    HOT_NONE_NODE,
    tuple,
  ])
  hot_delete_node(func, deleted)
  input_header_assert_queries(func)
  func.deleted_nodes.clear()
  input_header_assert_queries(func)
  assert_eq(hot_lower_impl_input_info(func, consumer).nodes.to_owned(), [
    tuple, tuple,
  ])
  let copies = [0]
  assert_eq(
    hot_lower_impl_input_info(func, sparse, copied_slots=Some(copies)).nodes.to_owned(),
    [tuple, tuple],
  )
  assert_eq(copies[0], 2)
}

///|
fn input_header_reference_info(
  func : HotFunc,
  id : NodeId,
  copied_slots? : Array[Int]? = None,
) -> HotLowerInputs {
  let node = hot_node_get(func, id)
  match node.op {
    HotOp::Block => {
      let count = if node.imm1 > 0 { node.imm1 } else { 0 }
      {
        nodes: func.children[node.child_base:node.child_base + count],
        pop_count: count,
      }
    }
    HotOp::Try
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
    | HotOp::RefFunc => { nodes: func.children[0:0], pop_count: 0, }
    HotOp::Loop => {
      let input_count = hot_label_branch_arity(
        func,
        hot_control_node_label(func, id),
      )
      {
        nodes: func.children[node.child_base:node.child_base + input_count],
        pop_count: input_count,
      }
    }
    HotOp::If => {
      if node.child_count == 3 {
        return {
          nodes: func.children[node.child_base:node.child_base + 1],
          pop_count: 1,
        }
      }
      let inputs : Array[NodeId] = []
      for slot in 3..<node.child_count {
        inputs.push(func.children[node.child_base + slot])
      }
      inputs.push(func.children[node.child_base])
      { nodes: inputs[:], pop_count: inputs.length(), }
    }
    _ => {
      // Lowering and source-order analysis only read the current HOT snapshot.
      // Dense child storage can be borrowed; absent slots need compact storage.
      let children = func.children[node.child_base:node.child_base +
        node.child_count]
      let nodes = if children.any(fn(child) { child == HOT_NONE_NODE }) {
        let kept : Array[NodeId] = []
        for child in children {
          if child != HOT_NONE_NODE {
            match copied_slots {
              Some(count) => count[0] += 1
              None => ()
            }
            kept.push(child)
          }
        }
        kept[:]
      } else {
        children
      }
      let pop_count = match node.op {
        HotOp::BrIf | HotOp::BrTable | HotOp::BrOnNull | HotOp::BrOnNonNull => 1
        HotOp::BrOnCast | HotOp::BrOnCastFail =>
          match hot_node_exact_instr(func, id) {
            Some(@lib.BrOnCastDescEq(_, _, _))
            | Some(@lib.BrOnCastDescEqFail(_, _, _)) => 2
            _ => 1
          }
        _ => nodes.length()
      }
      { nodes, pop_count, }
    }
  }
}
