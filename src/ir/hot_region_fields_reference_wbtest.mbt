///|
// Frozen pre-field-read query contracts. Keep descendant queries frozen too so
// a faster label reader cannot silently improve the reference benchmark.
fn region_fields_header_label(func : HotFunc, id : NodeId) -> LabelId {
  let node = hot_node_get(func, id)
  match node.op {
    HotOp::Block | HotOp::Loop | HotOp::If | HotOp::Try | HotOp::TryTable =>
      node.imm0
    _ => -1
  }
}

///|
fn region_fields_header_base(func : HotFunc, id : NodeId) -> Int {
  let node = hot_node_get(func, id)
  if node.op == HotOp::Block && node.imm1 > 0 {
    return node.imm1
  }
  if node.op != HotOp::Loop {
    return 0
  }
  let label = region_fields_header_label(func, id)
  if label < 0 {
    return 0
  }
  hot_label_branch_arity(func, label)
}

///|
fn region_fields_header_holder(func : HotFunc, id : NodeId) -> Bool {
  if !hot_node_is_live(func, id) {
    return false
  }
  match hot_node_get(func, id).op {
    HotOp::Loop => true
    HotOp::Block => {
      let label = region_fields_header_label(func, id)
      if label < 0 || label >= func.labels.length() {
        return false
      }
      match hot_label_kind(func, label) {
        HotLabelKind::BlockLabel | HotLabelKind::RegionLabel => true
        _ => false
      }
    }
    _ => false
  }
}

///|
fn region_fields_header_count(func : HotFunc, region : HotRegionRef) -> Int {
  if region.holder == HOT_NONE_NODE {
    return hot_root_count(func)
  }
  if !region_fields_header_holder(func, region.holder) {
    abort("hot region ref must point at a valid region holder")
  }
  hot_node_get(func, region.holder).child_count -
  region_fields_header_base(func, region.holder)
}

///|
fn region_fields_header_get(
  func : HotFunc,
  region : HotRegionRef,
  slot : Int,
) -> NodeId {
  hot_region_require_index(region_fields_header_count(func, region), slot)
  if region.holder == HOT_NONE_NODE {
    return hot_root_get(func, slot)
  }
  if !region_fields_header_holder(func, region.holder) {
    abort("hot region ref must point at a valid region holder")
  }
  let node = hot_node_get(func, region.holder)
  func.children[node.child_base +
  region_fields_header_base(func, region.holder) +
  slot]
}
