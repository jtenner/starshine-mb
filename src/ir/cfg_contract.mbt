///|
pub type BlockId = Int

///|
pub enum CfgEdgeKind {
  FallthroughEdge
  BranchEdge
  ReturnEdge
  ExceptionalEdge
  UnreachableExitEdge
} derive(Eq, Show, Debug)

///|
pub enum CfgBlockBoundaryReason {
  RootEntry
  ControlHeader
  LoopHeader
  BodyRegionEntry
  ThenRegionEntry
  ElseRegionEntry
  CatchRegionEntry
  CatchListRegionEntry
  Terminator
} derive(Eq, Show, Debug)

///|
pub enum CfgControlSuccessorPolicy {
  InlineBodyRegion
  SplitThenElse
  SplitBodyCatch
  SplitBodyCatchList
} derive(Eq, Show, Debug)

///|
pub enum CfgExceptionTargetPolicy {
  NoExceptionEdge
  PropagateToCaller
  ToCatchRegion
  ToCatchListRegion
  DelegateToTarget
} derive(Eq, Show, Debug)

///|
fn cfg_is_root_node(func : HotFunc, node_id : NodeId) -> Bool {
  for root_idx = 0; root_idx < hot_root_count(func); root_idx = root_idx + 1 {
    if hot_root_get(func, root_idx) == node_id {
      return true
    }
  }
  false
}

///|
fn cfg_boundary_reason_from_region_role(
  role : HotControlRegionRole,
) -> CfgBlockBoundaryReason {
  match role {
    HotControlRegionRole::BodyRegion => CfgBlockBoundaryReason::BodyRegionEntry
    HotControlRegionRole::ThenRegion => CfgBlockBoundaryReason::ThenRegionEntry
    HotControlRegionRole::ElseRegion => CfgBlockBoundaryReason::ElseRegionEntry
    HotControlRegionRole::CatchRegion =>
      CfgBlockBoundaryReason::CatchRegionEntry
    HotControlRegionRole::CatchListRegion =>
      CfgBlockBoundaryReason::CatchListRegionEntry
  }
}

///|
fn cfg_op_is_terminator(op : HotOp) -> Bool {
  match op {
    HotOp::Block
    | HotOp::Loop
    | HotOp::If
    | HotOp::Try
    | HotOp::TryTable
    | HotOp::Br
    | HotOp::BrIf
    | HotOp::BrTable
    | HotOp::BrOnNull
    | HotOp::BrOnNonNull
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail
    | HotOp::Return
    | HotOp::Throw
    | HotOp::Rethrow
    | HotOp::ThrowRef
    | HotOp::Delegate
    | HotOp::Unreachable => true
    _ => false
  }
}

///|
pub fn cfg_block_boundary_reasons(
  func : HotFunc,
  node_id : NodeId,
) -> Array[CfgBlockBoundaryReason] {
  let reasons : Array[CfgBlockBoundaryReason] = []
  let op = hot_node_get(func, node_id).op

  if cfg_is_root_node(func, node_id) {
    reasons.push(CfgBlockBoundaryReason::RootEntry)
  }
  if hot_is_control_node(func, node_id) {
    reasons.push(CfgBlockBoundaryReason::ControlHeader)
    for slot_info in hot_control_region_slot_info(op) {
      reasons.push(cfg_boundary_reason_from_region_role(slot_info.role))
    }
  }
  if op == HotOp::Loop {
    reasons.push(CfgBlockBoundaryReason::LoopHeader)
  }
  if cfg_op_is_terminator(op) {
    reasons.push(CfgBlockBoundaryReason::Terminator)
  }
  reasons
}

///|
pub fn cfg_control_successor_policy(op : HotOp) -> CfgControlSuccessorPolicy? {
  match op {
    HotOp::Block | HotOp::Loop =>
      Some(CfgControlSuccessorPolicy::InlineBodyRegion)
    HotOp::If => Some(CfgControlSuccessorPolicy::SplitThenElse)
    HotOp::Try => Some(CfgControlSuccessorPolicy::SplitBodyCatch)
    HotOp::TryTable => Some(CfgControlSuccessorPolicy::SplitBodyCatchList)
    _ => None
  }
}

///|
pub fn cfg_exception_target_policy(op : HotOp) -> CfgExceptionTargetPolicy {
  match op {
    HotOp::Try => CfgExceptionTargetPolicy::ToCatchRegion
    HotOp::TryTable => CfgExceptionTargetPolicy::ToCatchListRegion
    HotOp::Throw | HotOp::ThrowRef | HotOp::Rethrow =>
      CfgExceptionTargetPolicy::PropagateToCaller
    HotOp::Delegate => CfgExceptionTargetPolicy::DelegateToTarget
    _ => CfgExceptionTargetPolicy::NoExceptionEdge
  }
}

///|
pub fn cfg_terminator_edge_kinds(op : HotOp) -> Array[CfgEdgeKind] {
  match op {
    HotOp::Br => [CfgEdgeKind::BranchEdge]
    HotOp::BrIf
    | HotOp::BrOnNull
    | HotOp::BrOnNonNull
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail =>
      [CfgEdgeKind::BranchEdge, CfgEdgeKind::FallthroughEdge]
    HotOp::BrTable => [CfgEdgeKind::BranchEdge]
    HotOp::Return => [CfgEdgeKind::ReturnEdge]
    HotOp::Throw | HotOp::ThrowRef | HotOp::Rethrow | HotOp::Delegate =>
      [CfgEdgeKind::ExceptionalEdge]
    HotOp::Unreachable => [CfgEdgeKind::UnreachableExitEdge]
    HotOp::Block | HotOp::Loop | HotOp::If | HotOp::Try | HotOp::TryTable =>
      [CfgEdgeKind::FallthroughEdge]
    _ => []
  }
}
