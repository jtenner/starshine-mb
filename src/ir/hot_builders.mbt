///|
fn hot_builder_results_type(
  func : HotFunc,
  result_types : Array[ValType],
) -> TypeId {
  match result_types.length() {
    0 => hot_type_void(func)
    1 => hot_type_intern_value(func, result_types[0])
    _ => hot_type_intern_results(func, result_types)
  }
}

///|
fn hot_builder_local_value_type(func : HotFunc, local_id : LocalId) -> ValType {
  match hot_local_type(func, local_id) {
    Some(ty) => ty
    None => abort("hot builder local id must reference an existing param/local")
  }
}

///|
fn hot_builder_tag_idx_raw(tag_idx : TagIdx) -> Int {
  let TagIdx(raw) = tag_idx
  raw.reinterpret_as_int()
}

///|
fn hot_build_region(
  func : HotFunc,
  body : Array[NodeId],
  result_arity : Int,
) -> NodeId {
  let region_id = hot_build_node(
    func,
    HotOp::Block,
    hot_type_void(func),
    children=body,
  )
  let label_id = hot_label_alloc(
    func,
    HotLabelKind::RegionLabel,
    hot_type_void(func),
    region_id,
    result_arity,
  )
  hot_node_set(func, region_id, {
    ..hot_node_get(func, region_id),
    imm0: label_id,
  })
  region_id
}

///|
pub fn hot_build_node(
  func : HotFunc,
  op : HotOp,
  ty : TypeId,
  imm0? : Int = 0,
  imm1? : Int = 0,
  children? : Array[NodeId] = [],
) -> NodeId {
  let node = {
    op,
    ty,
    flags: hot_default_flags_for_op(op),
    imm0,
    imm1,
    child_base: 0,
    child_count: 0,
  }
  match children.length() {
    0 => hot_alloc_node(func, node)
    1 => hot_alloc_node_with_child1(func, node, children[0])
    2 => hot_alloc_node_with_child2(func, node, children[0], children[1])
    3 =>
      hot_alloc_node_with_child3(
        func,
        node,
        children[0],
        children[1],
        children[2],
      )
    _ => hot_alloc_node_with_children(func, node, children)
  }
}

///|
fn hot_build_node1(
  func : HotFunc,
  op : HotOp,
  ty : TypeId,
  child0 : NodeId,
  imm0? : Int = 0,
  imm1? : Int = 0,
) -> NodeId {
  hot_alloc_node_with_child1(
    func,
    {
      op,
      ty,
      flags: hot_default_flags_for_op(op),
      imm0,
      imm1,
      child_base: 0,
      child_count: 0,
    },
    child0,
  )
}

///|
fn hot_build_node2(
  func : HotFunc,
  op : HotOp,
  ty : TypeId,
  child0 : NodeId,
  child1 : NodeId,
  imm0? : Int = 0,
  imm1? : Int = 0,
) -> NodeId {
  hot_alloc_node_with_child2(
    func,
    {
      op,
      ty,
      flags: hot_default_flags_for_op(op),
      imm0,
      imm1,
      child_base: 0,
      child_count: 0,
    },
    child0,
    child1,
  )
}

///|
fn hot_build_node3(
  func : HotFunc,
  op : HotOp,
  ty : TypeId,
  child0 : NodeId,
  child1 : NodeId,
  child2 : NodeId,
  imm0? : Int = 0,
  imm1? : Int = 0,
) -> NodeId {
  hot_alloc_node_with_child3(
    func,
    {
      op,
      ty,
      flags: hot_default_flags_for_op(op),
      imm0,
      imm1,
      child_base: 0,
      child_count: 0,
    },
    child0,
    child1,
    child2,
  )
}

///|
pub fn hot_build_nop(func : HotFunc) -> NodeId {
  hot_build_node(func, HotOp::Nop, hot_type_void(func))
}

///|
pub fn hot_build_unreachable(func : HotFunc) -> NodeId {
  hot_build_node(func, HotOp::Unreachable, hot_type_void(func))
}

///|
pub fn hot_build_drop(func : HotFunc, value : NodeId) -> NodeId {
  hot_build_node1(func, HotOp::Drop, hot_type_void(func), value)
}

///|
pub fn hot_build_return(func : HotFunc, values : Array[NodeId]) -> NodeId {
  let expected = hot_type_result_arity(func, hot_body_result_type(func))
  if values.length() != expected {
    abort("hot return builder values must match the function body result arity")
  }
  hot_build_node(func, HotOp::Return, hot_type_void(func), children=values)
}

///|
pub fn hot_build_const_i32(func : HotFunc, value : I32) -> NodeId {
  let const_id = hot_alloc_const(func, HotConstPayload::i32_const(value))
  hot_build_node(
    func,
    HotOp::Const,
    hot_type_intern_value(func, @lib.ValType::i32()),
    imm0=const_id,
  )
}

///|
pub fn hot_build_const_i64(func : HotFunc, value : I64) -> NodeId {
  let const_id = hot_alloc_const(func, HotConstPayload::i64_const(value))
  hot_build_node(
    func,
    HotOp::Const,
    hot_type_intern_value(func, @lib.ValType::i64()),
    imm0=const_id,
  )
}

///|
pub fn hot_build_ref_null(func : HotFunc, value : RefType) -> NodeId {
  let const_id = hot_alloc_const(func, HotConstPayload::ref_null_const(value))
  hot_build_node(
    func,
    HotOp::RefNull,
    hot_type_intern_value(func, @lib.ValType::ref_null_type(value)),
    imm0=const_id,
  )
}

///|
pub fn hot_build_string_const(func : HotFunc, value : Bytes) -> NodeId {
  let const_id = hot_alloc_const(func, HotConstPayload::string_const(value))
  hot_build_node(
    func,
    HotOp::Const,
    hot_type_intern_value(func, @lib.ValType::stringref()),
    imm0=const_id,
  )
}

///|
pub fn hot_build_local_get(func : HotFunc, local_id : LocalId) -> NodeId {
  hot_build_node(
    func,
    HotOp::LocalGet,
    hot_type_intern_value(func, hot_builder_local_value_type(func, local_id)),
    imm0=local_id,
  )
}

///|
pub fn hot_build_local_set(
  func : HotFunc,
  local_id : LocalId,
  value : NodeId,
) -> NodeId {
  let _ = hot_builder_local_value_type(func, local_id)
  hot_build_node1(
    func,
    HotOp::LocalSet,
    hot_type_void(func),
    value,
    imm0=local_id,
  )
}

///|
pub fn hot_build_local_tee(
  func : HotFunc,
  local_id : LocalId,
  value : NodeId,
) -> NodeId {
  hot_build_node1(
    func,
    HotOp::LocalTee,
    hot_type_intern_value(func, hot_builder_local_value_type(func, local_id)),
    value,
    imm0=local_id,
  )
}

///|
pub fn hot_build_global_get(
  func : HotFunc,
  global_idx : Int,
  result_type : ValType,
) -> NodeId {
  hot_build_node(
    func,
    HotOp::GlobalGet,
    hot_type_intern_value(func, result_type),
    imm0=global_idx,
  )
}

///|
pub fn hot_build_global_set(
  func : HotFunc,
  global_idx : Int,
  value : NodeId,
) -> NodeId {
  hot_build_node1(
    func,
    HotOp::GlobalSet,
    hot_type_void(func),
    value,
    imm0=global_idx,
  )
}

///|
pub fn hot_build_br(
  func : HotFunc,
  target : LabelId,
  values? : Array[NodeId] = [],
) -> NodeId {
  hot_build_node(
    func,
    HotOp::Br,
    hot_type_void(func),
    imm0=target,
    children=values,
  )
}

///|
pub fn hot_build_br_if(
  func : HotFunc,
  target : LabelId,
  condition : NodeId,
  values? : Array[NodeId] = [],
) -> NodeId {
  let children = values.copy()
  children.push(condition)
  hot_build_node(func, HotOp::BrIf, hot_type_void(func), imm0=target, children~)
}

///|
pub fn hot_build_br_table(
  func : HotFunc,
  targets : Array[LabelId],
  default_target : LabelId,
  selector : NodeId,
  values? : Array[NodeId] = [],
) -> NodeId {
  let table_id = hot_alloc_branch_table(
    func,
    HotBranchTable::new(targets, default_target),
  )
  let children = values.copy()
  children.push(selector)
  hot_build_node(
    func,
    HotOp::BrTable,
    hot_type_void(func),
    imm0=table_id,
    children~,
  )
}

///|
pub fn hot_build_call(
  func : HotFunc,
  func_idx : Int,
  result_types : Array[ValType],
  args : Array[NodeId],
) -> NodeId {
  hot_build_node(
    func,
    HotOp::Call,
    hot_builder_results_type(func, result_types),
    imm0=func_idx,
    children=args,
  )
}

///|
pub fn hot_build_call_indirect(
  func : HotFunc,
  type_idx : TypeIdx,
  table_idx : TableIdx,
  result_types : Array[ValType],
  args : Array[NodeId],
  callee : NodeId,
) -> NodeId {
  let sig_id = hot_alloc_call_sig(
    func,
    HotCallSig::new(type_idx, table_idx=Some(table_idx)),
  )
  let children = args.copy()
  children.push(callee)
  hot_build_node(
    func,
    HotOp::CallIndirect,
    hot_builder_results_type(func, result_types),
    imm0=sig_id,
    children~,
  )
}

///|
pub fn hot_build_call_ref(
  func : HotFunc,
  type_idx : TypeIdx,
  result_types : Array[ValType],
  args : Array[NodeId],
  callee_ref : NodeId,
) -> NodeId {
  let sig_id = hot_alloc_call_sig(func, HotCallSig::new(type_idx))
  let children = args.copy()
  children.push(callee_ref)
  hot_build_node(
    func,
    HotOp::CallRef,
    hot_builder_results_type(func, result_types),
    imm0=sig_id,
    children~,
  )
}

///|
pub fn hot_build_return_call(
  func : HotFunc,
  func_idx : Int,
  args : Array[NodeId],
) -> NodeId {
  hot_build_node(
    func,
    HotOp::ReturnCall,
    hot_type_void(func),
    imm0=func_idx,
    children=args,
  )
}

///|
pub fn hot_build_return_call_indirect(
  func : HotFunc,
  type_idx : TypeIdx,
  table_idx : TableIdx,
  args : Array[NodeId],
  callee : NodeId,
) -> NodeId {
  let sig_id = hot_alloc_call_sig(
    func,
    HotCallSig::new(type_idx, table_idx=Some(table_idx)),
  )
  let children = args.copy()
  children.push(callee)
  hot_build_node(
    func,
    HotOp::ReturnCallIndirect,
    hot_type_void(func),
    imm0=sig_id,
    children~,
  )
}

///|
pub fn hot_build_return_call_ref(
  func : HotFunc,
  type_idx : TypeIdx,
  args : Array[NodeId],
  callee_ref : NodeId,
) -> NodeId {
  let sig_id = hot_alloc_call_sig(func, HotCallSig::new(type_idx))
  let children = args.copy()
  children.push(callee_ref)
  hot_build_node(
    func,
    HotOp::ReturnCallRef,
    hot_type_void(func),
    imm0=sig_id,
    children~,
  )
}

///|
pub fn hot_build_load(
  func : HotFunc,
  result_type : ValType,
  memarg : MemArg,
  address : NodeId,
) -> NodeId {
  let memarg_id = hot_alloc_memarg(func, HotMemArg::new(memarg))
  hot_build_node(
    func,
    HotOp::Load,
    hot_type_intern_value(func, result_type),
    imm0=memarg_id,
    children=[address],
  )
}

///|
pub fn hot_build_store(
  func : HotFunc,
  memarg : MemArg,
  address : NodeId,
  value : NodeId,
) -> NodeId {
  let memarg_id = hot_alloc_memarg(func, HotMemArg::new(memarg))
  hot_build_node(func, HotOp::Store, hot_type_void(func), imm0=memarg_id, children=[
    address, value,
  ])
}

///|
pub fn hot_build_table_get(
  func : HotFunc,
  table_idx : Int,
  result_type : ValType,
  index : NodeId,
) -> NodeId {
  hot_build_node(
    func,
    HotOp::TableGet,
    hot_type_intern_value(func, result_type),
    imm0=table_idx,
    children=[index],
  )
}

///|
pub fn hot_build_table_set(
  func : HotFunc,
  table_idx : Int,
  index : NodeId,
  value : NodeId,
) -> NodeId {
  hot_build_node(func, HotOp::TableSet, hot_type_void(func), imm0=table_idx, children=[
    index, value,
  ])
}

///|
pub fn hot_build_heap(
  func : HotFunc,
  result_types : Array[ValType],
  instr : Instruction,
  children : Array[NodeId],
) -> NodeId {
  let payload_id = hot_alloc_instr_payload(func, HotInstrPayload::new(instr))
  hot_build_node(
    func,
    HotOp::Heap,
    hot_builder_results_type(func, result_types),
    imm0=payload_id,
    children~,
  )
}

///|
pub fn hot_build_unary(
  func : HotFunc,
  result_type : ValType,
  operand : NodeId,
) -> NodeId {
  hot_build_node1(
    func,
    HotOp::Unary,
    hot_type_intern_value(func, result_type),
    operand,
  )
}

///|
pub fn hot_build_binary(
  func : HotFunc,
  result_type : ValType,
  lhs : NodeId,
  rhs : NodeId,
) -> NodeId {
  hot_build_node2(
    func,
    HotOp::Binary,
    hot_type_intern_value(func, result_type),
    lhs,
    rhs,
  )
}

///|
pub fn hot_build_compare(func : HotFunc, lhs : NodeId, rhs : NodeId) -> NodeId {
  hot_build_node2(
    func,
    HotOp::Compare,
    hot_type_intern_value(func, @lib.ValType::i32()),
    lhs,
    rhs,
  )
}

///|
pub fn hot_build_convert(
  func : HotFunc,
  result_type : ValType,
  operand : NodeId,
) -> NodeId {
  hot_build_node1(
    func,
    HotOp::Convert,
    hot_type_intern_value(func, result_type),
    operand,
  )
}

///|
pub fn hot_build_tuple_make(
  func : HotFunc,
  result_types : Array[ValType],
  values : Array[NodeId],
) -> NodeId {
  hot_build_node(
    func,
    HotOp::TupleMake,
    hot_builder_results_type(func, result_types),
    children=values,
  )
}

///|
pub fn hot_build_tuple_extract(
  func : HotFunc,
  result_type : ValType,
  tuple : NodeId,
  index : Int,
) -> NodeId {
  hot_build_node1(
    func,
    HotOp::TupleExtract,
    hot_type_intern_value(func, result_type),
    tuple,
    imm0=index,
  )
}

///|
pub fn hot_build_throw(
  func : HotFunc,
  tag_idx : TagIdx,
  args : Array[NodeId],
) -> NodeId {
  hot_build_node(
    func,
    HotOp::Throw,
    hot_type_void(func),
    imm0=hot_builder_tag_idx_raw(tag_idx),
    children=args,
  )
}

///|
pub fn hot_build_throw_ref(func : HotFunc, exnref : NodeId) -> NodeId {
  hot_build_node1(func, HotOp::ThrowRef, hot_type_void(func), exnref)
}

///|
pub fn hot_build_delegate(func : HotFunc, target : LabelId) -> NodeId {
  hot_build_node(func, HotOp::Delegate, hot_type_void(func), imm0=target)
}

///|
pub fn hot_build_block(
  func : HotFunc,
  block_type : BlockType,
  body : Array[NodeId],
) -> NodeId {
  let ty = hot_type_intern_block_result(func, block_type)
  let id = hot_build_node(func, HotOp::Block, ty, children=body)
  let label_id = hot_label_alloc(
    func,
    HotLabelKind::BlockLabel,
    ty,
    id,
    hot_type_result_arity(func, ty),
  )
  hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
  id
}

///|
pub fn hot_build_loop(
  func : HotFunc,
  block_type : BlockType,
  body : Array[NodeId],
) -> NodeId {
  let ty = hot_type_intern_block_result(func, block_type)
  let id = hot_build_node(func, HotOp::Loop, ty, children=body)
  let label_id = hot_label_alloc(
    func,
    HotLabelKind::LoopLabel,
    ty,
    id,
    hot_type_result_arity(func, ty),
  )
  hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
  id
}

///|
pub fn hot_build_if(
  func : HotFunc,
  block_type : BlockType,
  condition : NodeId,
  then_body : Array[NodeId],
  else_body? : Array[NodeId]? = None,
) -> NodeId {
  let ty = hot_type_intern_block_result(func, block_type)
  let result_arity = hot_type_result_arity(func, ty)
  let then_region = hot_build_region(func, then_body, result_arity)
  let else_region = match else_body {
    Some(body) => hot_build_region(func, body, result_arity)
    None => HOT_NONE_NODE
  }
  let id = hot_build_node3(
    func,
    HotOp::If,
    ty,
    condition,
    then_region,
    else_region,
  )
  let label_id = hot_label_alloc(
    func,
    HotLabelKind::IfLabel,
    ty,
    id,
    result_arity,
  )
  hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
  id
}

///|
pub fn hot_build_try(
  func : HotFunc,
  block_type : BlockType,
  body : Array[NodeId],
  catch_body? : Array[NodeId]? = None,
) -> NodeId {
  let ty = hot_type_intern_block_result(func, block_type)
  let result_arity = hot_type_result_arity(func, ty)
  let body_region = hot_build_region(func, body, result_arity)
  let catch_region = match catch_body {
    Some(items) => hot_build_region(func, items, result_arity)
    None => HOT_NONE_NODE
  }
  let id = hot_build_node2(func, HotOp::Try, ty, body_region, catch_region)
  let label_id = hot_label_alloc(
    func,
    HotLabelKind::TryLabel,
    ty,
    id,
    result_arity,
  )
  hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
  id
}

///|
pub fn hot_build_try_table(
  func : HotFunc,
  block_type : BlockType,
  catches : Array[HotCatchArm],
  body : Array[NodeId],
  catch_list_body? : Array[NodeId] = [],
) -> NodeId {
  let ty = hot_type_intern_block_result(func, block_type)
  let result_arity = hot_type_result_arity(func, ty)
  let body_region = hot_build_region(func, body, result_arity)
  let catch_list_region = hot_build_region(func, catch_list_body, result_arity)
  let catch_info_id = hot_alloc_catch_info(func, HotCatchInfo::new(catches))
  let id = hot_build_node2(
    func,
    HotOp::TryTable,
    ty,
    body_region,
    catch_list_region,
    imm1=catch_info_id,
  )
  let label_id = hot_label_alloc(
    func,
    HotLabelKind::TryTableLabel,
    ty,
    id,
    result_arity,
  )
  hot_node_set(func, id, { ..hot_node_get(func, id), imm0: label_id })
  id
}
