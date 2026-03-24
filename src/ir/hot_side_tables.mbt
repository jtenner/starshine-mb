///|
pub enum HotSideTableKind {
  ConstPayloadTable
  MemArgTable
  BranchTableTable
  CatchInfoTable
  CallSigTable
} derive(Eq, Show, Debug)

///|
pub fn HotConstPayload::i32_const(value : I32) -> HotConstPayload {
  I32Const(value)
}

///|
pub fn HotConstPayload::i64_const(value : I64) -> HotConstPayload {
  I64Const(value)
}

///|
pub fn HotConstPayload::ref_null_const(value : RefType) -> HotConstPayload {
  RefNullConst(value)
}

///|
pub fn HotConstPayload::string_const(value : Bytes) -> HotConstPayload {
  StringConst(value)
}

///|
pub fn HotMemArg::new(memarg : MemArg) -> HotMemArg {
  { memarg, }
}

///|
pub fn HotBranchTable::new(
  targets : Array[LabelId],
  default_target : LabelId,
) -> HotBranchTable {
  { targets, default_target }
}

///|
pub fn HotCatchArm::catch_(tag_idx : TagIdx, label_id : LabelId) -> HotCatchArm {
  CatchArm(tag_idx, label_id)
}

///|
pub fn HotCatchArm::catch_ref(
  tag_idx : TagIdx,
  label_id : LabelId,
) -> HotCatchArm {
  CatchRefArm(tag_idx, label_id)
}

///|
pub fn HotCatchArm::all(label_id : LabelId) -> HotCatchArm {
  CatchAllArm(label_id)
}

///|
pub fn HotCatchArm::all_ref(label_id : LabelId) -> HotCatchArm {
  CatchAllRefArm(label_id)
}

///|
pub fn HotCatchInfo::new(catches : Array[HotCatchArm]) -> HotCatchInfo {
  { catches, }
}

///|
pub fn HotCallSig::new(
  type_idx : TypeIdx,
  table_idx? : TableIdx? = None,
) -> HotCallSig {
  { type_idx, table_idx }
}

///|
pub fn hot_alloc_const(
  func : HotFunc,
  payload : HotConstPayload,
) -> SideTableId {
  let id = func.consts.length()
  func.consts.push(payload)
  id
}

///|
pub fn hot_const_get(func : HotFunc, id : SideTableId) -> HotConstPayload {
  func.consts[id]
}

///|
pub fn hot_alloc_memarg(func : HotFunc, memarg : HotMemArg) -> SideTableId {
  let id = func.memargs.length()
  func.memargs.push(memarg)
  id
}

///|
pub fn hot_memarg_get(func : HotFunc, id : SideTableId) -> HotMemArg {
  func.memargs[id]
}

///|
pub fn hot_alloc_branch_table(
  func : HotFunc,
  table : HotBranchTable,
) -> SideTableId {
  let id = func.branch_tables.length()
  func.branch_tables.push(table)
  id
}

///|
pub fn hot_branch_table_targets(
  func : HotFunc,
  id : SideTableId,
) -> Array[LabelId] {
  func.branch_tables[id].targets
}

///|
pub fn hot_branch_table_default_target(
  func : HotFunc,
  id : SideTableId,
) -> LabelId {
  func.branch_tables[id].default_target
}

///|
pub fn hot_alloc_catch_info(func : HotFunc, info : HotCatchInfo) -> SideTableId {
  let id = func.catches.length()
  func.catches.push(info)
  id
}

///|
pub fn hot_catch_info_get(func : HotFunc, id : SideTableId) -> HotCatchInfo {
  func.catches[id]
}

///|
pub fn hot_alloc_call_sig(func : HotFunc, sig : HotCallSig) -> SideTableId {
  let id = func.call_sigs.length()
  func.call_sigs.push(sig)
  id
}

///|
pub fn hot_call_sig_get(func : HotFunc, id : SideTableId) -> HotCallSig {
  func.call_sigs[id]
}

///|
pub fn hot_side_table_kind_for_op(op : HotOp) -> HotSideTableKind? {
  match op {
    HotOp::Const | HotOp::RefNull => Some(HotSideTableKind::ConstPayloadTable)
    HotOp::Load | HotOp::Store | HotOp::Atomic =>
      Some(HotSideTableKind::MemArgTable)
    HotOp::BrTable => Some(HotSideTableKind::BranchTableTable)
    HotOp::TryTable => Some(HotSideTableKind::CatchInfoTable)
    HotOp::CallIndirect
    | HotOp::CallRef
    | HotOp::ReturnCallIndirect
    | HotOp::ReturnCallRef => Some(HotSideTableKind::CallSigTable)
    _ => None
  }
}
