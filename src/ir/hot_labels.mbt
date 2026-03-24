///|
pub enum HotControlRegionRole {
  BodyRegion
  ThenRegion
  ElseRegion
  CatchRegion
  CatchListRegion
} derive(Eq, Show, Debug)

///|
pub struct HotControlRegionSlotInfo {
  slot : Int
  role : HotControlRegionRole
  required : Bool
} derive(Eq, Show, Debug)

///|
pub fn hot_label_alloc(
  func : HotFunc,
  kind : HotLabelKind,
  result_type : TypeId,
  owner : NodeId,
  branch_arity : Int,
) -> LabelId {
  let id = func.labels.length()
  func.labels.push({ kind, result_type, owner, branch_arity })
  id
}

///|
pub fn hot_label_get(func : HotFunc, label_id : LabelId) -> HotLabelInfo {
  func.labels[label_id]
}

///|
pub fn hot_label_owner(func : HotFunc, label_id : LabelId) -> NodeId {
  hot_label_get(func, label_id).owner
}

///|
pub fn hot_label_kind(func : HotFunc, label_id : LabelId) -> HotLabelKind {
  hot_label_get(func, label_id).kind
}

///|
pub fn hot_label_result_type(func : HotFunc, label_id : LabelId) -> TypeId {
  hot_label_get(func, label_id).result_type
}

///|
pub fn hot_label_branch_arity(func : HotFunc, label_id : LabelId) -> Int {
  hot_label_get(func, label_id).branch_arity
}

///|
pub fn hot_control_node_label(func : HotFunc, node_id : NodeId) -> LabelId {
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Block | HotOp::Loop | HotOp::If | HotOp::Try | HotOp::TryTable =>
      node.imm0
    _ => -1
  }
}

///|
fn hot_control_slot(
  slot : Int,
  role : HotControlRegionRole,
  required : Bool,
) -> HotControlRegionSlotInfo {
  { slot, role, required }
}

///|
pub fn hot_control_region_slot_info(
  op : HotOp,
) -> Array[HotControlRegionSlotInfo] {
  match op {
    HotOp::Block | HotOp::Loop =>
      [hot_control_slot(0, HotControlRegionRole::BodyRegion, true)]
    HotOp::If =>
      [
        hot_control_slot(1, HotControlRegionRole::ThenRegion, true),
        hot_control_slot(2, HotControlRegionRole::ElseRegion, false),
      ]
    HotOp::Try =>
      [
        hot_control_slot(0, HotControlRegionRole::BodyRegion, true),
        hot_control_slot(1, HotControlRegionRole::CatchRegion, false),
      ]
    HotOp::TryTable =>
      [
        hot_control_slot(0, HotControlRegionRole::BodyRegion, true),
        hot_control_slot(1, HotControlRegionRole::CatchListRegion, false),
      ]
    _ => []
  }
}
