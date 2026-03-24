///|
fn hot_query_op(func : HotFunc, node_id : NodeId) -> HotOp {
  hot_node_get(func, node_id).op
}

///|
fn hot_query_single_result_is_numeric(func : HotFunc, node_id : NodeId) -> Bool {
  match hot_type_results(func, hot_node_type(func, node_id)) {
    [@lib.NumTypeValType(_)] => true
    _ => false
  }
}

///|
pub fn hot_node_kind_is_control(func : HotFunc, node_id : NodeId) -> Bool {
  hot_is_control_node(func, node_id)
}

///|
pub fn hot_node_kind_is_branch(func : HotFunc, node_id : NodeId) -> Bool {
  hot_is_branch(func, node_id) || hot_query_op(func, node_id) == HotOp::Delegate
}

///|
pub fn hot_node_kind_is_call(func : HotFunc, node_id : NodeId) -> Bool {
  match hot_query_op(func, node_id) {
    HotOp::Call
    | HotOp::CallIndirect
    | HotOp::CallRef
    | HotOp::ReturnCall
    | HotOp::ReturnCallIndirect
    | HotOp::ReturnCallRef => true
    _ => false
  }
}

///|
pub fn hot_node_kind_is_local(func : HotFunc, node_id : NodeId) -> Bool {
  match hot_query_op(func, node_id) {
    HotOp::LocalGet | HotOp::LocalSet | HotOp::LocalTee => true
    _ => false
  }
}

///|
pub fn hot_node_kind_is_global(func : HotFunc, node_id : NodeId) -> Bool {
  match hot_query_op(func, node_id) {
    HotOp::GlobalGet | HotOp::GlobalSet => true
    _ => false
  }
}

///|
pub fn hot_node_kind_is_memory(func : HotFunc, node_id : NodeId) -> Bool {
  match hot_query_op(func, node_id) {
    HotOp::Load
    | HotOp::Store
    | HotOp::MemorySize
    | HotOp::MemoryGrow
    | HotOp::MemoryCopy
    | HotOp::MemoryFill
    | HotOp::MemoryInit
    | HotOp::DataDrop => true
    _ => false
  }
}

///|
pub fn hot_node_kind_is_table(func : HotFunc, node_id : NodeId) -> Bool {
  match hot_query_op(func, node_id) {
    HotOp::TableGet
    | HotOp::TableSet
    | HotOp::TableSize
    | HotOp::TableGrow
    | HotOp::TableFill
    | HotOp::TableCopy
    | HotOp::TableInit
    | HotOp::ElemDrop => true
    _ => false
  }
}

///|
pub fn hot_node_kind_is_numeric(func : HotFunc, node_id : NodeId) -> Bool {
  match hot_query_op(func, node_id) {
    HotOp::Unary | HotOp::Binary | HotOp::Compare | HotOp::Convert => true
    HotOp::Const => hot_query_single_result_is_numeric(func, node_id)
    _ => false
  }
}

///|
pub fn hot_node_kind_is_tuple(func : HotFunc, node_id : NodeId) -> Bool {
  match hot_query_op(func, node_id) {
    HotOp::TupleMake | HotOp::TupleExtract => true
    _ => false
  }
}

///|
pub fn hot_node_kind_is_exception(func : HotFunc, node_id : NodeId) -> Bool {
  match hot_query_op(func, node_id) {
    HotOp::Throw
    | HotOp::Rethrow
    | HotOp::ThrowRef
    | HotOp::Delegate
    | HotOp::Catch
    | HotOp::CatchAll => true
    _ => false
  }
}

///|
pub fn hot_node_kind_is_simd(func : HotFunc, node_id : NodeId) -> Bool {
  hot_query_op(func, node_id) == HotOp::Simd
}

///|
pub fn hot_node_kind_is_atomic(func : HotFunc, node_id : NodeId) -> Bool {
  hot_query_op(func, node_id) == HotOp::Atomic
}

///|
pub fn hot_node_type(func : HotFunc, node_id : NodeId) -> TypeId {
  hot_node_get(func, node_id).ty
}

///|
pub fn hot_node_result_arity(func : HotFunc, node_id : NodeId) -> Int {
  hot_type_result_arity(func, hot_node_type(func, node_id))
}

///|
pub fn hot_branch_target(func : HotFunc, node_id : NodeId) -> LabelId? {
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Br
    | HotOp::BrIf
    | HotOp::BrOnNull
    | HotOp::BrOnNonNull
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail
    | HotOp::Delegate => Some(node.imm0)
    HotOp::BrTable => Some(hot_branch_table_default_target(func, node.imm0))
    _ => None
  }
}

///|
pub fn hot_branch_table_targets_for_node(
  func : HotFunc,
  node_id : NodeId,
) -> Array[LabelId] {
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::BrTable => hot_branch_table_targets(func, node.imm0).copy()
    _ => []
  }
}

///|
pub fn hot_root_span(func : HotFunc) -> Array[NodeId] {
  let out : Array[NodeId] = []
  for i = 0; i < hot_root_count(func); i = i + 1 {
    out.push(hot_root_get(func, i))
  }
  out
}

///|
pub fn hot_child_span(func : HotFunc, node_id : NodeId) -> Array[NodeId] {
  let out : Array[NodeId] = []
  for i = 0; i < hot_child_count(func, node_id); i = i + 1 {
    out.push(hot_child_get(func, node_id, i))
  }
  out
}

///|
pub fn hot_local_param_count(func : HotFunc) -> Int {
  hot_param_count(func)
}

///|
pub fn hot_local_body_count(func : HotFunc) -> Int {
  hot_local_count(func) - hot_local_param_count(func)
}

///|
pub fn hot_local_is_param(func : HotFunc, local_id : LocalId) -> Bool {
  local_id >= 0 && local_id < hot_local_param_count(func)
}

///|
pub fn hot_node_is_deleted(func : HotFunc, node_id : NodeId) -> Bool {
  node_id >= 0 &&
  node_id < hot_node_count(func) &&
  !hot_node_is_live(func, node_id)
}
