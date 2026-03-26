///|
pub enum HotUseSlotKind {
  ChildUseSlot
  RootUseSlot
} derive(Eq, Show, Debug)

///|
pub struct HotUseSite {
  user : NodeId
  slot : Int
  kind : HotUseSlotKind
} derive(Eq, Show, Debug)

///|
pub struct HotUseDef {
  node_uses : Array[Array[HotUseSite]]
  block_defs : Array[Bitset]
  block_uses : Array[Bitset]
  local_reads : Array[Array[NodeId]]
  local_writes : Array[Array[NodeId]]
  local_write_blocks : Array[Array[BlockId]]
} derive(Eq, Show, Debug)

///|
fn use_def_bitset_clone(src : Bitset) -> Bitset {
  let out = bitset_new(src.size)
  ignore(bitset_union_into(out, src))
  out
}

///|
fn use_def_require_node_range(use_def : HotUseDef, node_id : NodeId) -> Unit {
  if node_id < 0 || node_id >= use_def.node_uses.length() {
    abort("use-def node query requires a valid node id")
  }
}

///|
fn use_def_require_block_range(use_def : HotUseDef, block_id : BlockId) -> Unit {
  if block_id < 0 || block_id >= use_def.block_defs.length() {
    abort("use-def block query requires a valid block id")
  }
}

///|
fn use_def_require_local_range(use_def : HotUseDef, local_id : LocalId) -> Unit {
  if local_id < 0 || local_id >= use_def.local_reads.length() {
    abort("use-def local query requires a valid local id")
  }
}

///|
fn use_def_live_child(func : HotFunc, node_id : NodeId, slot : Int) -> NodeId? {
  let child_id = hot_child_get(func, node_id, slot)
  if child_id == HOT_NONE_NODE || !hot_node_is_live(func, child_id) {
    return None
  }
  Some(child_id)
}

///|
fn use_def_region_slot(op : HotOp, slot : Int) -> Bool {
  match op {
    HotOp::Block | HotOp::Loop => true
    _ => {
      for slot_info in hot_control_region_slot_info(op) {
        if slot_info.slot == slot {
          return true
        }
      }
      false
    }
  }
}

///|
fn use_def_add_site(
  node_uses : Array[Array[HotUseSite]],
  node_id : NodeId,
  site : HotUseSite,
) -> Unit {
  node_uses[node_id].push(site)
}

///|
fn use_def_track_local_node(
  func : HotFunc,
  node_id : NodeId,
  local_reads : Array[Array[NodeId]],
  local_writes : Array[Array[NodeId]],
) -> Unit {
  let node = hot_node_get(func, node_id)
  match node.op {
    // use_def_visit_node only visits each live node once, so these per-local
    // lists do not need an extra linear de-duplication scan.
    HotOp::LocalGet => local_reads[node.imm0].push(node_id)
    HotOp::LocalSet | HotOp::LocalTee => local_writes[node.imm0].push(node_id)
    _ => ()
  }
}

///|
fn use_def_visit_region(
  func : HotFunc,
  region_ref : HotRegionRef,
  node_uses : Array[Array[HotUseSite]],
  local_reads : Array[Array[NodeId]],
  local_writes : Array[Array[NodeId]],
  seen : Array[Bool],
) -> Unit {
  for slot = 0; slot < hot_region_root_count(func, region_ref); slot = slot + 1 {
    let root_id = hot_region_get(func, region_ref, slot)
    if root_id == HOT_NONE_NODE || !hot_node_is_live(func, root_id) {
      continue
    }
    use_def_add_site(node_uses, root_id, {
      user: region_ref.holder,
      slot,
      kind: HotUseSlotKind::RootUseSlot,
    })
    use_def_visit_node(
      func, root_id, node_uses, local_reads, local_writes, seen,
    )
  }
}

///|
fn use_def_visit_node(
  func : HotFunc,
  node_id : NodeId,
  node_uses : Array[Array[HotUseSite]],
  local_reads : Array[Array[NodeId]],
  local_writes : Array[Array[NodeId]],
  seen : Array[Bool],
) -> Unit {
  if seen[node_id] {
    return
  }
  seen[node_id] = true
  use_def_track_local_node(func, node_id, local_reads, local_writes)
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Block | HotOp::Loop => {
      use_def_visit_region(
        func,
        hot_region_body_ref(func, node_id),
        node_uses,
        local_reads,
        local_writes,
        seen,
      )
      return
    }
    _ => ()
  }
  for slot = 0; slot < hot_child_count(func, node_id); slot = slot + 1 {
    match use_def_live_child(func, node_id, slot) {
      Some(child_id) => {
        use_def_add_site(node_uses, child_id, {
          user: node_id,
          slot,
          kind: HotUseSlotKind::ChildUseSlot,
        })
        use_def_visit_node(
          func, child_id, node_uses, local_reads, local_writes, seen,
        )
      }
      None => ()
    }
  }
}

///|
fn use_def_block_mark_use(
  local_count : Int,
  defs : Bitset,
  uses : Bitset,
  local_id : LocalId,
) -> Unit {
  if local_id < 0 || local_id >= local_count {
    abort("use-def local use must reference an existing local")
  }
  if !bitset_contains(defs, local_id) {
    ignore(bitset_set(uses, local_id))
  }
}

///|
fn use_def_block_mark_def(
  local_count : Int,
  defs : Bitset,
  block_id : BlockId,
  local_id : LocalId,
  local_write_blocks : Array[Array[BlockId]],
) -> Unit {
  if local_id < 0 || local_id >= local_count {
    abort("use-def local def must reference an existing local")
  }
  if bitset_set(defs, local_id) {
    local_write_blocks[local_id].push(block_id)
  }
}

///|
fn use_def_scan_block_node(
  func : HotFunc,
  node_id : NodeId,
  block_id : BlockId,
  local_count : Int,
  defs : Bitset,
  uses : Bitset,
  local_write_blocks : Array[Array[BlockId]],
  seen_stamps : Array[Int],
) -> Unit {
  if seen_stamps[node_id] == block_id {
    return
  }
  seen_stamps[node_id] = block_id
  let node = hot_node_get(func, node_id)
  for slot = 0; slot < hot_child_count(func, node_id); slot = slot + 1 {
    if use_def_region_slot(node.op, slot) {
      continue
    }
    match use_def_live_child(func, node_id, slot) {
      Some(child_id) =>
        use_def_scan_block_node(
          func, child_id, block_id, local_count, defs, uses, local_write_blocks,
          seen_stamps,
        )
      None => ()
    }
  }
  match node.op {
    HotOp::LocalGet =>
      use_def_block_mark_use(local_count, defs, uses, node.imm0)
    HotOp::LocalSet | HotOp::LocalTee =>
      use_def_block_mark_def(
        local_count,
        defs,
        block_id,
        node.imm0,
        local_write_blocks,
      )
    _ => ()
  }
}

///|
fn use_def_build_block_sets(
  func : HotFunc,
  cfg : HotCfg,
) -> (Array[Bitset], Array[Bitset], Array[Array[BlockId]]) {
  let local_count = hot_local_count(func)
  let seen_stamps = Array::make(hot_node_count(func), -1)
  let block_defs : Array[Bitset] = []
  let block_uses : Array[Bitset] = []
  let local_write_blocks : Array[Array[BlockId]] = []
  for _ in 0..<local_count {
    local_write_blocks.push([])
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    let defs = bitset_new(local_count)
    let uses = bitset_new(local_count)
    for node_id in cfg_block_get(cfg, block_id).nodes {
      use_def_scan_block_node(
        func, node_id, block_id, local_count, defs, uses, local_write_blocks, seen_stamps,
      )
    }
    block_defs.push(defs)
    block_uses.push(uses)
  }
  (block_defs, block_uses, local_write_blocks)
}

///|
fn use_def_build_node_and_local_uses(
  func : HotFunc,
) -> (Array[Array[HotUseSite]], Array[Array[NodeId]], Array[Array[NodeId]]) {
  let node_uses : Array[Array[HotUseSite]] = []
  let seen : Array[Bool] = []
  for _ in 0..<hot_node_count(func) {
    node_uses.push([])
    seen.push(false)
  }
  let local_reads : Array[Array[NodeId]] = []
  let local_writes : Array[Array[NodeId]] = []
  for _ in 0..<hot_local_count(func) {
    local_reads.push([])
    local_writes.push([])
  }
  use_def_visit_region(
    func,
    HotRegionRef::root(),
    node_uses,
    local_reads,
    local_writes,
    seen,
  )
  (node_uses, local_reads, local_writes)
}

///|
fn use_def_empty_local_write_blocks(local_count : Int) -> Array[Array[BlockId]] {
  let local_write_blocks : Array[Array[BlockId]] = []
  for _ in 0..<local_count {
    local_write_blocks.push([])
  }
  local_write_blocks
}

///|
pub fn use_def_build_node_uses(func : HotFunc) -> HotUseDef {
  let (node_uses, local_reads, local_writes) = use_def_build_node_and_local_uses(
    func,
  )
  {
    node_uses,
    block_defs: [],
    block_uses: [],
    local_reads,
    local_writes,
    local_write_blocks: use_def_empty_local_write_blocks(hot_local_count(func)),
  }
}

///|
pub fn use_def_build(func : HotFunc, cfg? : HotCfg? = None) -> HotUseDef {
  let (node_uses, local_reads, local_writes) = use_def_build_node_and_local_uses(
    func,
  )
  let (block_defs, block_uses, local_write_blocks) = match cfg {
    Some(existing) => use_def_build_block_sets(func, existing)
    None =>
      match hot_verify_control(func) {
        Ok(_) => use_def_build_block_sets(func, cfg_build(func))
        Err(_) => ([], [], [])
      }
  }
  {
    node_uses,
    block_defs,
    block_uses,
    local_reads,
    local_writes,
    local_write_blocks,
  }
}

///|
pub fn node_use_sites(
  use_def : HotUseDef,
  node_id : NodeId,
) -> Array[HotUseSite] {
  use_def_require_node_range(use_def, node_id)
  use_def.node_uses[node_id].copy()
}

///|
pub fn node_use_count(use_def : HotUseDef, node_id : NodeId) -> Int {
  use_def_require_node_range(use_def, node_id)
  use_def.node_uses[node_id].length()
}

///|
pub fn block_local_defs(use_def : HotUseDef, block_id : BlockId) -> Bitset {
  use_def_require_block_range(use_def, block_id)
  use_def_bitset_clone(use_def.block_defs[block_id])
}

///|
pub fn block_local_uses(use_def : HotUseDef, block_id : BlockId) -> Bitset {
  use_def_require_block_range(use_def, block_id)
  use_def_bitset_clone(use_def.block_uses[block_id])
}

///|
pub fn local_read_nodes(
  use_def : HotUseDef,
  local_id : LocalId,
) -> Array[NodeId] {
  use_def_require_local_range(use_def, local_id)
  use_def.local_reads[local_id].copy()
}

///|
pub fn local_write_nodes(
  use_def : HotUseDef,
  local_id : LocalId,
) -> Array[NodeId] {
  use_def_require_local_range(use_def, local_id)
  use_def.local_writes[local_id].copy()
}

///|
pub fn local_write_block_ids(
  use_def : HotUseDef,
  local_id : LocalId,
) -> Array[BlockId] {
  use_def_require_local_range(use_def, local_id)
  use_def.local_write_blocks[local_id].copy()
}
