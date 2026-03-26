///|
pub struct CfgEdge {
  kind : CfgEdgeKind
  block : BlockId
} derive(Eq, Show, Debug)

///|
pub struct HotBlockInfo {
  id : BlockId
  nodes : Array[NodeId]
  preds : Array[CfgEdge]
  succs : Array[CfgEdge]
  is_synthetic : Bool
  region_holder : NodeId
  start_slot : Int
  end_slot : Int
} derive(Eq, Show, Debug)

///|
pub struct CfgRegionRootBlock {
  region_holder : NodeId
  slot : Int
  block : BlockId
} derive(Eq, Show, Debug)

///|
pub struct HotCfg {
  blocks : Array[HotBlockInfo]
  node_to_block : Array[BlockId]
  region_roots : Array[CfgRegionRootBlock]
  mut entry_block : BlockId
  mut exit_block : BlockId
  mut exceptional_exit_block : BlockId?
} derive(Eq, Show, Debug)

///|
priv struct CfgBuilder {
  cfg : HotCfg
  label_targets : Array[BlockId]
}

///|
priv struct CfgRegionBuild {
  entry_block : BlockId?
  exit_blocks : Array[BlockId]
}

///|
priv struct CfgRegionSegment {
  block_id : BlockId
  end_slot : Int
}

///|
fn cfg_builder_new(func : HotFunc) -> CfgBuilder {
  let node_to_block : Array[BlockId] = []
  for _ in 0..<hot_node_count(func) {
    node_to_block.push(-1)
  }
  let label_targets : Array[BlockId] = []
  for _ in 0..<func.labels.length() {
    label_targets.push(-1)
  }
  {
    cfg: {
      blocks: [],
      node_to_block,
      region_roots: [],
      entry_block: -1,
      exit_block: -1,
      exceptional_exit_block: None,
    },
    label_targets,
  }
}

///|
fn cfg_builder_region_holder(region_ref : HotRegionRef) -> NodeId {
  region_ref.holder
}

///|
fn cfg_builder_add_block(
  builder : CfgBuilder,
  nodes : Array[NodeId],
  is_synthetic : Bool,
  region_holder? : NodeId = HOT_NONE_NODE,
  start_slot? : Int = -1,
  end_slot? : Int = -1,
) -> BlockId {
  let id = builder.cfg.blocks.length()
  builder.cfg.blocks.push({
    id,
    nodes,
    preds: [],
    succs: [],
    is_synthetic,
    region_holder,
    start_slot,
    end_slot,
  })
  for node_id in nodes {
    builder.cfg.node_to_block[node_id] = id
  }
  id
}

///|
fn cfg_builder_add_edge(
  builder : CfgBuilder,
  from : BlockId,
  to : BlockId,
  kind : CfgEdgeKind,
) -> Unit {
  builder.cfg.blocks[from].succs.push({ kind, block: to })
  builder.cfg.blocks[to].preds.push({ kind, block: from })
}

///|
fn cfg_builder_label_target_set(
  builder : CfgBuilder,
  label_id : LabelId,
  block_id : BlockId,
) -> Unit {
  builder.label_targets[label_id] = block_id
}

///|
fn cfg_builder_label_target_get(
  builder : CfgBuilder,
  label_id : LabelId,
) -> BlockId {
  match builder.label_targets.get(label_id) {
    Some(block_id) if block_id >= 0 => block_id
    _ =>
      abort(
        "cfg build requires every referenced hot label to resolve to a built block",
      )
  }
}

///|
fn cfg_builder_exceptional_exit_block(builder : CfgBuilder) -> BlockId {
  match builder.cfg.exceptional_exit_block {
    Some(block_id) => block_id
    None => {
      let block_id = cfg_builder_add_block(builder, [], true)
      builder.cfg.exceptional_exit_block = Some(block_id)
      block_id
    }
  }
}

///|
fn cfg_builder_connect_exits(
  builder : CfgBuilder,
  exits : Array[BlockId],
  target : BlockId?,
) -> Unit {
  match target {
    Some(block_id) =>
      for exit_block in exits {
        cfg_builder_add_edge(
          builder,
          exit_block,
          block_id,
          CfgEdgeKind::FallthroughEdge,
        )
      }
    None => ()
  }
}

///|
fn cfg_builder_region_segments(
  builder : CfgBuilder,
  func : HotFunc,
  region_ref : HotRegionRef,
) -> Array[CfgRegionSegment] {
  let segments : Array[CfgRegionSegment] = []
  let region_holder = cfg_builder_region_holder(region_ref)
  let root_count = hot_region_root_count(func, region_ref)
  let mut start = 0
  while start < root_count {
    let mut end = start + 1
    while end < root_count {
      let previous = hot_region_get(func, region_ref, end - 1)
      if cfg_op_is_terminator(hot_node_get(func, previous).op) {
        break
      }
      let next = hot_region_get(func, region_ref, end)
      if hot_is_control_node(func, next) {
        break
      }
      end = end + 1
    }
    let nodes : Array[NodeId] = []
    for slot = start; slot < end; slot = slot + 1 {
      nodes.push(hot_region_get(func, region_ref, slot))
    }
    let block_id = cfg_builder_add_block(
      builder,
      nodes,
      false,
      region_holder~,
      start_slot=start,
      end_slot=end,
    )
    for slot = start; slot < end; slot = slot + 1 {
      builder.cfg.region_roots.push({ region_holder, slot, block: block_id })
    }
    segments.push({ block_id, end_slot: end })
    start = end
  }
  segments
}

///|
fn cfg_builder_region_build_empty(
  builder : CfgBuilder,
  region_ref : HotRegionRef,
  force_entry : Bool,
) -> CfgRegionBuild {
  if !force_entry {
    return { entry_block: None, exit_blocks: [] }
  }
  let block_id = cfg_builder_add_block(
    builder,
    [],
    true,
    region_holder=cfg_builder_region_holder(region_ref),
    start_slot=0,
    end_slot=0,
  )
  { entry_block: Some(block_id), exit_blocks: [block_id] }
}

///|
fn cfg_builder_maybe_continuation(
  builder : CfgBuilder,
  next_block : BlockId?,
) -> (BlockId?, Bool) {
  match next_block {
    Some(block_id) => (Some(block_id), false)
    None => {
      let block_id = cfg_builder_add_block(builder, [], true)
      (Some(block_id), true)
    }
  }
}

///|
fn cfg_builder_branch_targets(
  builder : CfgBuilder,
  func : HotFunc,
  node_id : NodeId,
) -> Array[BlockId] {
  let targets : Array[BlockId] = []
  match hot_node_get(func, node_id).op {
    HotOp::BrTable => {
      for label_id in hot_branch_table_targets_for_node(func, node_id) {
        targets.push(cfg_builder_label_target_get(builder, label_id))
      }
      match hot_branch_target(func, node_id) {
        Some(label_id) =>
          targets.push(cfg_builder_label_target_get(builder, label_id))
        None => ()
      }
    }
    _ =>
      match hot_branch_target(func, node_id) {
        Some(label_id) =>
          targets.push(cfg_builder_label_target_get(builder, label_id))
        None => ()
      }
  }
  targets
}

///|
fn cfg_builder_exception_target(
  builder : CfgBuilder,
  handler_target : BlockId?,
) -> BlockId {
  match handler_target {
    Some(block_id) => block_id
    None => cfg_builder_exceptional_exit_block(builder)
  }
}

///|
fn cfg_builder_process_block(
  builder : CfgBuilder,
  func : HotFunc,
  region_ref : HotRegionRef,
  segments : Array[CfgRegionSegment],
  segment_idx : Int,
  handler_target : BlockId?,
  exits : Array[BlockId],
) -> Unit {
  let segment = segments[segment_idx]
  let current_block = segment.block_id
  let next_block = if segment_idx + 1 < segments.length() {
    Some(segments[segment_idx + 1].block_id)
  } else {
    None
  }
  let last_node = hot_region_get(func, region_ref, segment.end_slot - 1)
  let node = hot_node_get(func, last_node)
  match node.op {
    HotOp::Block => {
      let (continuation, synthetic_exit) = cfg_builder_maybe_continuation(
        builder, next_block,
      )
      cfg_builder_label_target_set(
        builder,
        hot_control_node_label(func, last_node),
        continuation.unwrap(),
      )
      let body_build = cfg_builder_build_region(
        builder,
        func,
        hot_region_body_ref(func, last_node),
        handler_target,
        force_entry=true,
      )
      cfg_builder_add_edge(
        builder,
        current_block,
        body_build.entry_block.unwrap(),
        CfgEdgeKind::FallthroughEdge,
      )
      cfg_builder_connect_exits(builder, body_build.exit_blocks, continuation)
      if synthetic_exit {
        exits.push(continuation.unwrap())
      }
    }
    HotOp::Loop => {
      cfg_builder_label_target_set(
        builder,
        hot_control_node_label(func, last_node),
        current_block,
      )
      let body_build = cfg_builder_build_region(
        builder,
        func,
        hot_region_body_ref(func, last_node),
        handler_target,
        force_entry=true,
      )
      cfg_builder_add_edge(
        builder,
        current_block,
        body_build.entry_block.unwrap(),
        CfgEdgeKind::FallthroughEdge,
      )
      cfg_builder_connect_exits(builder, body_build.exit_blocks, next_block)
      if next_block == None {
        for exit_block in body_build.exit_blocks {
          exits.push(exit_block)
        }
      }
    }
    HotOp::If => {
      let (continuation, synthetic_exit) = cfg_builder_maybe_continuation(
        builder, next_block,
      )
      cfg_builder_label_target_set(
        builder,
        hot_control_node_label(func, last_node),
        continuation.unwrap(),
      )
      let then_build = cfg_builder_build_region(
        builder,
        func,
        hot_region_then_ref(func, last_node),
        handler_target,
        force_entry=true,
      )
      cfg_builder_add_edge(
        builder,
        current_block,
        then_build.entry_block.unwrap(),
        CfgEdgeKind::FallthroughEdge,
      )
      cfg_builder_connect_exits(builder, then_build.exit_blocks, continuation)
      match hot_region_else_ref(func, last_node) {
        Some(else_ref) => {
          let else_build = cfg_builder_build_region(
            builder,
            func,
            else_ref,
            handler_target,
            force_entry=true,
          )
          cfg_builder_add_edge(
            builder,
            current_block,
            else_build.entry_block.unwrap(),
            CfgEdgeKind::FallthroughEdge,
          )
          cfg_builder_connect_exits(
            builder,
            else_build.exit_blocks,
            continuation,
          )
        }
        None =>
          cfg_builder_add_edge(
            builder,
            current_block,
            continuation.unwrap(),
            CfgEdgeKind::FallthroughEdge,
          )
      }
      if synthetic_exit {
        exits.push(continuation.unwrap())
      }
    }
    HotOp::Try => {
      let (continuation, synthetic_exit) = cfg_builder_maybe_continuation(
        builder, next_block,
      )
      cfg_builder_label_target_set(
        builder,
        hot_control_node_label(func, last_node),
        continuation.unwrap(),
      )
      let catch_build = match hot_region_catch_ref(func, last_node) {
        Some(catch_ref) =>
          Some(
            cfg_builder_build_region(
              builder,
              func,
              catch_ref,
              handler_target,
              force_entry=true,
            ),
          )
        None => None
      }
      let body_build = cfg_builder_build_region(
        builder,
        func,
        hot_region_body_ref(func, last_node),
        match catch_build {
          Some(build) => build.entry_block
          None => handler_target
        },
        force_entry=true,
      )
      cfg_builder_add_edge(
        builder,
        current_block,
        body_build.entry_block.unwrap(),
        CfgEdgeKind::FallthroughEdge,
      )
      cfg_builder_connect_exits(builder, body_build.exit_blocks, continuation)
      match catch_build {
        Some(build) => {
          cfg_builder_add_edge(
            builder,
            current_block,
            build.entry_block.unwrap(),
            CfgEdgeKind::ExceptionalEdge,
          )
          cfg_builder_connect_exits(builder, build.exit_blocks, continuation)
        }
        None => ()
      }
      if synthetic_exit {
        exits.push(continuation.unwrap())
      }
    }
    HotOp::TryTable => {
      let (continuation, synthetic_exit) = cfg_builder_maybe_continuation(
        builder, next_block,
      )
      cfg_builder_label_target_set(
        builder,
        hot_control_node_label(func, last_node),
        continuation.unwrap(),
      )
      let catch_build = cfg_builder_build_region(
        builder,
        func,
        hot_region_catch_list_ref(func, last_node),
        handler_target,
        force_entry=true,
      )
      let body_build = cfg_builder_build_region(
        builder,
        func,
        hot_region_body_ref(func, last_node),
        catch_build.entry_block,
        force_entry=true,
      )
      cfg_builder_add_edge(
        builder,
        current_block,
        body_build.entry_block.unwrap(),
        CfgEdgeKind::FallthroughEdge,
      )
      cfg_builder_add_edge(
        builder,
        current_block,
        catch_build.entry_block.unwrap(),
        CfgEdgeKind::ExceptionalEdge,
      )
      cfg_builder_connect_exits(builder, body_build.exit_blocks, continuation)
      cfg_builder_connect_exits(builder, catch_build.exit_blocks, continuation)
      if synthetic_exit {
        exits.push(continuation.unwrap())
      }
    }
    HotOp::Br =>
      for target in cfg_builder_branch_targets(builder, func, last_node) {
        cfg_builder_add_edge(
          builder,
          current_block,
          target,
          CfgEdgeKind::BranchEdge,
        )
      }
    HotOp::BrIf
    | HotOp::BrOnNull
    | HotOp::BrOnNonNull
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail => {
      for target in cfg_builder_branch_targets(builder, func, last_node) {
        cfg_builder_add_edge(
          builder,
          current_block,
          target,
          CfgEdgeKind::BranchEdge,
        )
      }
      match next_block {
        Some(block_id) =>
          cfg_builder_add_edge(
            builder,
            current_block,
            block_id,
            CfgEdgeKind::FallthroughEdge,
          )
        None => exits.push(current_block)
      }
    }
    HotOp::BrTable =>
      for target in cfg_builder_branch_targets(builder, func, last_node) {
        cfg_builder_add_edge(
          builder,
          current_block,
          target,
          CfgEdgeKind::BranchEdge,
        )
      }
    HotOp::Return
    | HotOp::ReturnCall
    | HotOp::ReturnCallIndirect
    | HotOp::ReturnCallRef =>
      cfg_builder_add_edge(
        builder,
        current_block,
        builder.cfg.exit_block,
        CfgEdgeKind::ReturnEdge,
      )
    HotOp::Throw | HotOp::ThrowRef | HotOp::Rethrow =>
      cfg_builder_add_edge(
        builder,
        current_block,
        cfg_builder_exception_target(builder, handler_target),
        CfgEdgeKind::ExceptionalEdge,
      )
    HotOp::Delegate =>
      for target in cfg_builder_branch_targets(builder, func, last_node) {
        cfg_builder_add_edge(
          builder,
          current_block,
          target,
          CfgEdgeKind::ExceptionalEdge,
        )
      }
    HotOp::Unreachable =>
      cfg_builder_add_edge(
        builder,
        current_block,
        builder.cfg.exit_block,
        CfgEdgeKind::UnreachableExitEdge,
      )
    _ =>
      match next_block {
        Some(block_id) =>
          cfg_builder_add_edge(
            builder,
            current_block,
            block_id,
            CfgEdgeKind::FallthroughEdge,
          )
        None => exits.push(current_block)
      }
  }
}

///|
fn cfg_builder_build_region(
  builder : CfgBuilder,
  func : HotFunc,
  region_ref : HotRegionRef,
  handler_target : BlockId?,
  force_entry? : Bool = false,
) -> CfgRegionBuild {
  if hot_region_root_count(func, region_ref) == 0 {
    return cfg_builder_region_build_empty(builder, region_ref, force_entry)
  }
  let segments = cfg_builder_region_segments(builder, func, region_ref)
  let exits : Array[BlockId] = []
  for idx = 0; idx < segments.length(); idx = idx + 1 {
    cfg_builder_process_block(
      builder, func, region_ref, segments, idx, handler_target, exits,
    )
  }
  { entry_block: Some(segments[0].block_id), exit_blocks: exits }
}

///|
fn cfg_verify(cfg : HotCfg) -> Unit {
  for block_id = 0; block_id < cfg.blocks.length(); block_id = block_id + 1 {
    let block = cfg.blocks[block_id]
    if block.id != block_id {
      abort("cfg block ids must match their storage index")
    }
    for succ in block.succs {
      if succ.block < 0 || succ.block >= cfg.blocks.length() {
        abort("cfg successor target must reference a valid block id")
      }
      let mut found = false
      for pred in cfg.blocks[succ.block].preds {
        if pred.block == block_id && pred.kind == succ.kind {
          found = true
          break
        }
      }
      if !found {
        abort("cfg successors and predecessors must stay symmetric")
      }
    }
    for pred in block.preds {
      if pred.block < 0 || pred.block >= cfg.blocks.length() {
        abort("cfg predecessor source must reference a valid block id")
      }
      let mut found = false
      for succ in cfg.blocks[pred.block].succs {
        if succ.block == block_id && succ.kind == pred.kind {
          found = true
          break
        }
      }
      if !found {
        abort("cfg predecessors and successors must stay symmetric")
      }
    }
  }
  for node_id = 0; node_id < cfg.node_to_block.length(); node_id = node_id + 1 {
    let block_id = cfg.node_to_block[node_id]
    if block_id < 0 {
      continue
    }
    if block_id >= cfg.blocks.length() {
      abort("cfg node-to-block mapping must reference a valid block")
    }
    let mut found = false
    for mapped in cfg.blocks[block_id].nodes {
      if mapped == node_id {
        found = true
        break
      }
    }
    if !found {
      abort("cfg node-to-block mapping must match the owning block node list")
    }
  }
  for entry in cfg.region_roots {
    if entry.block < 0 || entry.block >= cfg.blocks.length() {
      abort("cfg region-root mapping must reference a valid block")
    }
  }
}

///|
pub fn cfg_build(func : HotFunc) -> HotCfg {
  hot_verify_all_or_abort(func)
  let builder = cfg_builder_new(func)
  let entry_block = cfg_builder_add_block(builder, [], true)
  let exit_block = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry_block
  builder.cfg.exit_block = exit_block

  let root_build = cfg_builder_build_region(
    builder,
    func,
    HotRegionRef::root(),
    None,
  )
  match root_build.entry_block {
    Some(block_id) =>
      cfg_builder_add_edge(
        builder,
        entry_block,
        block_id,
        CfgEdgeKind::FallthroughEdge,
      )
    None =>
      cfg_builder_add_edge(
        builder,
        entry_block,
        exit_block,
        CfgEdgeKind::FallthroughEdge,
      )
  }
  cfg_builder_connect_exits(builder, root_build.exit_blocks, Some(exit_block))

  cfg_verify(builder.cfg)
  builder.cfg
}

///|
pub fn cfg_block_count(cfg : HotCfg) -> Int {
  cfg.blocks.length()
}

///|
pub fn cfg_entry_block(cfg : HotCfg) -> BlockId {
  cfg.entry_block
}

///|
pub fn cfg_exit_block(cfg : HotCfg) -> BlockId {
  cfg.exit_block
}

///|
pub fn cfg_exceptional_exit_block(cfg : HotCfg) -> BlockId? {
  cfg.exceptional_exit_block
}

///|
pub fn cfg_block_get(cfg : HotCfg, block_id : BlockId) -> HotBlockInfo {
  cfg.blocks[block_id]
}

///|
pub fn cfg_block_for_node(cfg : HotCfg, node_id : NodeId) -> BlockId? {
  match cfg.node_to_block.get(node_id) {
    Some(block_id) if block_id >= 0 => Some(block_id)
    _ => None
  }
}

///|
pub fn cfg_block_for_region_root(
  cfg : HotCfg,
  region_ref : HotRegionRef,
  slot : Int,
) -> BlockId? {
  let region_holder = cfg_builder_region_holder(region_ref)
  for entry in cfg.region_roots {
    if entry.region_holder == region_holder && entry.slot == slot {
      return Some(entry.block)
    }
  }
  None
}

///|
pub fn cfg_successors(cfg : HotCfg, block_id : BlockId) -> Array[CfgEdge] {
  cfg_successor_edges(cfg, block_id).copy()
}

///|
pub fn cfg_predecessors(cfg : HotCfg, block_id : BlockId) -> Array[CfgEdge] {
  cfg_predecessor_edges(cfg, block_id).copy()
}

///|
pub fn cfg_successor_edges(cfg : HotCfg, block_id : BlockId) -> Array[CfgEdge] {
  cfg.blocks[block_id].succs
}

///|
pub fn cfg_predecessor_edges(
  cfg : HotCfg,
  block_id : BlockId,
) -> Array[CfgEdge] {
  cfg.blocks[block_id].preds
}
