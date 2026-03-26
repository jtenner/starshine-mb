///|
pub struct HotRegionRef {
  holder : NodeId
} derive(Eq, Show, Debug)

///|
pub fn HotRegionRef::root() -> HotRegionRef {
  { holder: HOT_NONE_NODE }
}

///|
fn hot_region_is_root(region_ref : HotRegionRef) -> Bool {
  region_ref.holder == HOT_NONE_NODE
}

///|
fn hot_region_require_index(
  length : Int,
  idx : Int,
  allow_end? : Bool = false,
) -> Unit {
  let upper = if allow_end { length } else { length - 1 }
  if idx < 0 || idx > upper {
    abort("hot region index out of bounds")
  }
}

///|
fn hot_region_require_remove_count(
  length : Int,
  idx : Int,
  remove_count : Int,
) -> Unit {
  if remove_count < 0 || idx + remove_count > length {
    abort("hot region remove_count out of bounds")
  }
}

///|
fn hot_region_is_region_holder(func : HotFunc, holder : NodeId) -> Bool {
  if !hot_node_is_live(func, holder) {
    return false
  }
  let node = hot_node_get(func, holder)
  match node.op {
    HotOp::Loop => true
    HotOp::Block => {
      let label_id = hot_control_node_label(func, holder)
      if label_id < 0 || label_id >= func.labels.length() {
        return false
      }
      match hot_label_kind(func, label_id) {
        HotLabelKind::BlockLabel | HotLabelKind::RegionLabel => true
        _ => false
      }
    }
    _ => false
  }
}

///|
fn hot_region_require_holder(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> NodeId {
  if hot_region_is_root(region_ref) {
    abort("hot root region does not have a node holder")
  }
  if !hot_region_is_region_holder(func, region_ref.holder) {
    abort("hot region ref must point at a valid region holder")
  }
  region_ref.holder
}

///|
fn hot_region_ref_from_holder(func : HotFunc, holder : NodeId) -> HotRegionRef {
  if !hot_region_is_region_holder(func, holder) {
    abort("hot region ref holder must point at a valid region body node")
  }
  { holder, }
}

///|
fn hot_region_body_base(func : HotFunc, holder : NodeId) -> Int {
  let node = hot_node_get(func, holder)
  if node.op != HotOp::Loop {
    return 0
  }
  let label_id = hot_control_node_label(func, holder)
  if label_id < 0 {
    return 0
  }
  hot_label_branch_arity(func, label_id)
}

///|
fn hot_region_optional_slot_ref(
  func : HotFunc,
  control_id : NodeId,
  slot : Int,
) -> HotRegionRef? {
  let node = hot_node_get(func, control_id)
  if slot >= node.child_count {
    return None
  }
  let holder = func.children[node.child_base + slot]
  if holder == HOT_NONE_NODE {
    return None
  }
  Some(hot_region_ref_from_holder(func, holder))
}

///|
pub fn hot_region_body_ref(func : HotFunc, control_id : NodeId) -> HotRegionRef {
  match hot_node_get(func, control_id).op {
    HotOp::Block | HotOp::Loop => hot_region_ref_from_holder(func, control_id)
    HotOp::Try | HotOp::TryTable =>
      hot_region_optional_slot_ref(func, control_id, 0).unwrap()
    HotOp::If =>
      abort("if bodies must be addressed through then/else region refs")
    _ => abort("hot_region_body_ref requires a structured control node")
  }
}

///|
pub fn hot_region_then_ref(func : HotFunc, if_id : NodeId) -> HotRegionRef {
  if hot_node_get(func, if_id).op != HotOp::If {
    abort("hot_region_then_ref requires an if node")
  }
  hot_region_optional_slot_ref(func, if_id, 1).unwrap()
}

///|
pub fn hot_region_else_ref(func : HotFunc, if_id : NodeId) -> HotRegionRef? {
  if hot_node_get(func, if_id).op != HotOp::If {
    abort("hot_region_else_ref requires an if node")
  }
  hot_region_optional_slot_ref(func, if_id, 2)
}

///|
pub fn hot_region_catch_ref(func : HotFunc, try_id : NodeId) -> HotRegionRef? {
  if hot_node_get(func, try_id).op != HotOp::Try {
    abort("hot_region_catch_ref requires a try node")
  }
  hot_region_optional_slot_ref(func, try_id, 1)
}

///|
pub fn hot_region_catch_list_ref(
  func : HotFunc,
  try_table_id : NodeId,
) -> HotRegionRef {
  if hot_node_get(func, try_table_id).op != HotOp::TryTable {
    abort("hot_region_catch_list_ref requires a try_table node")
  }
  hot_region_optional_slot_ref(func, try_table_id, 1).unwrap()
}

///|
fn hot_region_roots(func : HotFunc, region_ref : HotRegionRef) -> Array[NodeId] {
  if hot_region_is_root(region_ref) {
    return hot_root_span(func)
  }
  let holder = hot_region_require_holder(func, region_ref)
  let node = hot_node_get(func, holder)
  let roots : Array[NodeId] = []
  let base = hot_region_body_base(func, holder)
  let total = node.child_count
  for idx = base; idx < total; idx = idx + 1 {
    roots.push(func.children[node.child_base + idx])
  }
  roots
}

///|
fn hot_region_write_roots(
  func : HotFunc,
  region_ref : HotRegionRef,
  roots : Array[NodeId],
) -> Array[NodeId] {
  if hot_region_is_root(region_ref) {
    return hot_root_splice(func, 0, hot_root_count(func), roots)
  }
  let holder = hot_region_require_holder(func, region_ref)
  let node = hot_node_get(func, holder)
  let next : Array[NodeId] = []
  let base = hot_region_body_base(func, holder)
  for idx = 0; idx < base; idx = idx + 1 {
    next.push(func.children[node.child_base + idx])
  }
  for root in roots {
    next.push(root)
  }
  hot_replace_child_span(func, holder, next)
}

///|
pub fn hot_region_root_count(func : HotFunc, region_ref : HotRegionRef) -> Int {
  if hot_region_is_root(region_ref) {
    return hot_root_count(func)
  }
  let holder = hot_region_require_holder(func, region_ref)
  hot_node_get(func, holder).child_count - hot_region_body_base(func, holder)
}

///|
pub fn hot_region_result_arity(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> Int {
  if hot_region_is_root(region_ref) {
    return hot_type_result_arity(func, hot_body_result_type(func))
  }
  let holder = hot_region_require_holder(func, region_ref)
  let label_id = hot_control_node_label(func, holder)
  hot_label_branch_arity(func, label_id)
}

///|
pub fn hot_region_get(
  func : HotFunc,
  region_ref : HotRegionRef,
  idx : Int,
) -> NodeId {
  hot_region_require_index(hot_region_root_count(func, region_ref), idx)
  if hot_region_is_root(region_ref) {
    return hot_root_get(func, idx)
  }
  let holder = hot_region_require_holder(func, region_ref)
  let node = hot_node_get(func, holder)
  func.children[node.child_base + hot_region_body_base(func, holder) + idx]
}

///|
pub fn hot_region_set(
  func : HotFunc,
  region_ref : HotRegionRef,
  idx : Int,
  node_id : NodeId,
) -> NodeId {
  let previous = hot_region_get(func, region_ref, idx)
  if hot_region_is_root(region_ref) {
    hot_root_set(func, idx, node_id)
  } else {
    let holder = hot_region_require_holder(func, region_ref)
    hot_child_set(
      func,
      holder,
      hot_region_body_base(func, holder) + idx,
      node_id,
    )
  }
  previous
}

///|
pub fn hot_region_insert(
  func : HotFunc,
  region_ref : HotRegionRef,
  idx : Int,
  node_ids : Array[NodeId],
) -> Unit {
  ignore(hot_region_splice(func, region_ref, idx, 0, node_ids))
}

///|
pub fn hot_region_remove(
  func : HotFunc,
  region_ref : HotRegionRef,
  idx : Int,
  count : Int,
) -> Array[NodeId] {
  hot_region_splice(func, region_ref, idx, count, [])
}

///|
pub fn hot_region_splice(
  func : HotFunc,
  region_ref : HotRegionRef,
  idx : Int,
  remove_count : Int,
  node_ids : Array[NodeId],
) -> Array[NodeId] {
  let current = hot_region_roots(func, region_ref)
  hot_region_require_index(current.length(), idx, allow_end=true)
  hot_region_require_remove_count(current.length(), idx, remove_count)
  let next : Array[NodeId] = []
  for i = 0; i < idx; i = i + 1 {
    next.push(current[i])
  }
  for node_id in node_ids {
    next.push(node_id)
  }
  for i = idx + remove_count; i < current.length(); i = i + 1 {
    next.push(current[i])
  }
  let removed : Array[NodeId] = []
  for i = idx; i < idx + remove_count; i = i + 1 {
    removed.push(current[i])
  }
  ignore(hot_region_write_roots(func, region_ref, next))
  removed
}

///|
pub fn hot_region_replace_body(
  func : HotFunc,
  region_ref : HotRegionRef,
  node_ids : Array[NodeId],
) -> Unit {
  ignore(hot_region_write_roots(func, region_ref, node_ids))
}
