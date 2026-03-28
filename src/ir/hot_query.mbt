///|
fn hot_query_op(func : HotFunc, node_id : NodeId) -> HotOp {
  hot_node_get(func, node_id).op
}

///|
pub enum HotSimpleValueKey {
  ConstValue(HotConstPayload)
  LocalGetValue(LocalId)
} derive(Eq, Show, Debug)

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
pub fn hot_node_kind_is_heap(func : HotFunc, node_id : NodeId) -> Bool {
  hot_query_op(func, node_id) == HotOp::Heap
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
pub fn hot_simple_value_key(
  func : HotFunc,
  node_id : NodeId,
) -> HotSimpleValueKey? {
  if node_id < 0 ||
    node_id >= hot_node_count(func) ||
    !hot_node_is_live(func, node_id) {
    return None
  }
  let node = hot_node_get(func, node_id)
  if node.child_count != 0 {
    return None
  }
  match node.op {
    HotOp::Const =>
      Some(HotSimpleValueKey::ConstValue(hot_const_get(func, node.imm0)))
    HotOp::LocalGet => Some(HotSimpleValueKey::LocalGetValue(node.imm0))
    _ => None
  }
}

///|
pub fn hot_nodes_match_simple_value(
  func : HotFunc,
  lhs : NodeId,
  rhs : NodeId,
) -> Bool {
  hot_simple_value_key(func, lhs) == hot_simple_value_key(func, rhs)
}

///|
pub fn hot_region_single_live_root(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId? {
  if hot_region_root_count(func, region_ref) != 1 {
    return None
  }
  let candidate = hot_region_get(func, region_ref, 0)
  if candidate < 0 || !hot_node_is_live(func, candidate) {
    return None
  }
  Some(candidate)
}

///|
pub fn hot_region_single_live_block_root(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId? {
  let candidate = match hot_region_single_live_root(func, region_ref) {
    Some(candidate) => candidate
    None => return None
  }
  match hot_query_op(func, candidate) {
    HotOp::Block => Some(candidate)
    _ => None
  }
}

///|
pub fn hot_region_single_live_block_body(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> HotRegionRef? {
  match hot_region_single_live_block_root(func, region_ref) {
    Some(block_id) => Some(hot_region_body_ref(func, block_id))
    None => None
  }
}

///|
pub fn hot_region_single_live_if_root(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId? {
  let candidate = match hot_region_single_live_root(func, region_ref) {
    Some(candidate) => candidate
    None => return None
  }
  match hot_query_op(func, candidate) {
    HotOp::If => Some(candidate)
    _ => None
  }
}

///|
pub fn hot_region_single_plain_br_root(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId? {
  let candidate = match hot_region_single_live_root(func, region_ref) {
    Some(candidate) => candidate
    None => return None
  }
  let node = hot_node_get(func, candidate)
  match node.op {
    HotOp::Br if node.child_count == 0 => Some(candidate)
    _ => None
  }
}

///|
pub fn hot_region_single_plain_br_target(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> LabelId? {
  match hot_region_single_plain_br_root(func, region_ref) {
    Some(br_id) => hot_branch_target(func, br_id)
    None => None
  }
}

///|
pub fn hot_region_single_exit_root(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId? {
  let candidate = match hot_region_single_live_root(func, region_ref) {
    Some(candidate) => candidate
    None => return None
  }
  let node = hot_node_get(func, candidate)
  match node.op {
    HotOp::Return => Some(candidate)
    HotOp::Br if node.child_count == 0 => Some(candidate)
    _ => None
  }
}

///|
pub fn hot_region_holder_block_root(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId? {
  let holder = region_ref.holder
  if holder < 0 || !hot_node_is_live(func, holder) {
    return None
  }
  match hot_query_op(func, holder) {
    HotOp::Block => Some(holder)
    _ => None
  }
}

///|
pub fn hot_region_holder_block_label(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> LabelId? {
  match hot_region_holder_block_root(func, region_ref) {
    Some(holder) => Some(hot_control_node_label(func, holder))
    None => None
  }
}

///|
pub fn hot_region_split_trailing_payload_roots(
  func : HotFunc,
  region_ref : HotRegionRef,
  result_arity : Int,
) -> (Array[NodeId], Array[NodeId])? {
  hot_split_trailing_payload_roots(
    func,
    hot_region_roots(func, region_ref),
    result_arity,
  )
}

///|
pub fn hot_split_trailing_payload_roots(
  func : HotFunc,
  roots : Array[NodeId],
  result_arity : Int,
) -> (Array[NodeId], Array[NodeId])? {
  if result_arity <= 0 {
    return Some((roots, []))
  }
  let mut payload_arity = 0
  let mut payload_start = roots.length()
  while payload_start > 0 && payload_arity < result_arity {
    let candidate = roots[payload_start - 1]
    let candidate_arity = hot_node_result_arity(func, candidate)
    if candidate_arity <= 0 {
      return None
    }
    payload_arity += candidate_arity
    payload_start -= 1
  }
  if payload_arity != result_arity {
    return None
  }
  let prefix : Array[NodeId] = []
  for idx = 0; idx < payload_start; idx = idx + 1 {
    prefix.push(roots[idx])
  }
  let payload : Array[NodeId] = []
  for idx = payload_start; idx < roots.length(); idx = idx + 1 {
    payload.push(roots[idx])
  }
  Some((prefix, payload))
}

///|
pub fn hot_node_repeated_live_child(
  func : HotFunc,
  node_id : NodeId,
) -> NodeId? {
  if node_id < 0 ||
    node_id >= hot_node_count(func) ||
    !hot_node_is_live(func, node_id) {
    return None
  }
  let node = hot_node_get(func, node_id)
  if node.child_count == 0 {
    return None
  }
  let candidate = hot_child_get(func, node_id, 0)
  if candidate < 0 || !hot_node_is_live(func, candidate) {
    return None
  }
  for child_idx = 1; child_idx < node.child_count; child_idx = child_idx + 1 {
    if hot_child_get(func, node_id, child_idx) != candidate {
      return None
    }
  }
  Some(candidate)
}

///|
pub fn hot_region_repeated_live_root(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId? {
  let root_count = hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return None
  }
  let candidate = hot_region_get(func, region_ref, 0)
  if candidate < 0 || !hot_node_is_live(func, candidate) {
    return None
  }
  for idx = 1; idx < root_count; idx = idx + 1 {
    if hot_region_get(func, region_ref, idx) != candidate {
      return None
    }
  }
  Some(candidate)
}

///|
pub fn hot_region_repeated_live_if_root(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId? {
  let candidate = match hot_region_repeated_live_root(func, region_ref) {
    Some(candidate) => candidate
    None => return None
  }
  match hot_query_op(func, candidate) {
    HotOp::If => Some(candidate)
    _ => None
  }
}

///|
pub fn hot_region_repeated_live_block_root(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId? {
  let candidate = match hot_region_repeated_live_root(func, region_ref) {
    Some(candidate) => candidate
    None => return None
  }
  match hot_query_op(func, candidate) {
    HotOp::Block => Some(candidate)
    _ => None
  }
}

///|
pub fn hot_region_repeated_live_block_body(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> HotRegionRef? {
  match hot_region_repeated_live_block_root(func, region_ref) {
    Some(block_id) => Some(hot_region_body_ref(func, block_id))
    None => None
  }
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
