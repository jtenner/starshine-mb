///|
pub struct HotLoopExit {
  from : BlockId
  edge : CfgEdge
} derive(Eq, Show, Debug)

///|
pub struct HotLoopSummary {
  header : BlockId
  blocks : Array[BlockId]
  latches : Array[BlockId]
  exits : Array[HotLoopExit]
  parent : Int
  depth : Int
} derive(Eq, Show, Debug)

///|
pub struct HotLoopInfo {
  loops : Array[HotLoopSummary]
  block_to_loop : Array[Int]
  block_depth : Array[Int]
} derive(Eq, Show, Debug)

///|
priv struct LoopInfoTemp {
  header : BlockId
  block_bits : Bitset
  blocks : Array[BlockId]
  latches : Array[BlockId]
  exits : Array[HotLoopExit]
} derive(Eq, Show, Debug)

///|
fn loop_info_is_reachable(dom : HotDominators, block_id : BlockId) -> Bool {
  dom_dominates(dom, dom.entry_block, block_id)
}

///|
fn loop_info_has_backedge(
  edge : CfgEdge,
  dom : HotDominators,
  from : BlockId,
) -> Bool {
  edge.kind != CfgEdgeKind::ExceptionalEdge &&
  dom_dominates(dom, edge.block, from)
}

///|
fn loop_info_bitset_to_blocks(bits : Bitset) -> Array[BlockId] {
  let blocks : Array[BlockId] = []
  bitset_for_each_set_bit(bits, fn(block_id) { blocks.push(block_id) })
  blocks
}

///|
fn loop_info_bitset_clone(src : Bitset) -> Bitset {
  let out = bitset_new(src.size)
  ignore(bitset_union_into(out, src))
  out
}

///|
fn loop_info_contains_exit(
  exits : Array[HotLoopExit],
  candidate : HotLoopExit,
) -> Bool {
  for exit in exits {
    if exit.from == candidate.from &&
      exit.edge.kind == candidate.edge.kind &&
      exit.edge.block == candidate.edge.block {
      return true
    }
  }
  false
}

///|
fn loop_info_build_one(
  cfg : HotCfg,
  header : BlockId,
  latches : Array[BlockId],
) -> LoopInfoTemp {
  let block_bits = bitset_new(cfg_block_count(cfg))
  ignore(bitset_set(block_bits, header))
  let worklist : Array[BlockId] = []
  for latch in latches {
    if bitset_set(block_bits, latch) {
      worklist.push(latch)
    }
  }
  while worklist.length() > 0 {
    let block_id = worklist.pop().unwrap()
    for pred in cfg_predecessor_edges(cfg, block_id) {
      if pred.kind == CfgEdgeKind::ExceptionalEdge {
        continue
      }
      if bitset_set(block_bits, pred.block) {
        worklist.push(pred.block)
      }
    }
  }
  let blocks = loop_info_bitset_to_blocks(block_bits)
  let exits : Array[HotLoopExit] = []
  for block_id in blocks {
    for edge in cfg_successor_edges(cfg, block_id) {
      if bitset_contains(block_bits, edge.block) {
        continue
      }
      let exit = { from: block_id, edge }
      if !loop_info_contains_exit(exits, exit) {
        exits.push(exit)
      }
    }
  }
  { header, block_bits, blocks, latches, exits }
}

///|
fn loop_info_is_subset(lhs : Bitset, rhs : Bitset) -> Bool {
  let diff = loop_info_bitset_clone(lhs)
  ignore(bitset_difference_into(diff, rhs))
  for bit in 0..<diff.size {
    if bitset_contains(diff, bit) {
      return false
    }
  }
  true
}

///|
fn loop_info_parent(temps : Array[LoopInfoTemp], loop_idx : Int) -> Int {
  let mut parent = -1
  let mut parent_size = 1 << 30
  for idx = 0; idx < temps.length(); idx = idx + 1 {
    if idx == loop_idx {
      continue
    }
    if !bitset_contains(temps[idx].block_bits, temps[loop_idx].header) ||
      !loop_info_is_subset(temps[loop_idx].block_bits, temps[idx].block_bits) {
      continue
    }
    if temps[idx].blocks.length() < parent_size {
      parent = idx
      parent_size = temps[idx].blocks.length()
    }
  }
  parent
}

///|
fn loop_info_depths(parents : Array[Int]) -> Array[Int] {
  let depths = Array::make(parents.length(), 0)
  for idx = 0; idx < parents.length(); idx = idx + 1 {
    let mut depth = 1
    let mut cursor = parents[idx]
    while cursor >= 0 {
      depth = depth + 1
      cursor = parents[cursor]
    }
    depths[idx] = depth
  }
  depths
}

///|
fn loop_info_block_mappings(
  block_count : Int,
  temps : Array[LoopInfoTemp],
  depths : Array[Int],
) -> (Array[Int], Array[Int]) {
  let block_to_loop = Array::make(block_count, -1)
  let block_depth = Array::make(block_count, 0)
  for block_id = 0; block_id < block_count; block_id = block_id + 1 {
    let mut best_loop = -1
    let mut best_depth = 0
    let mut best_size = 1 << 30
    for idx = 0; idx < temps.length(); idx = idx + 1 {
      if !bitset_contains(temps[idx].block_bits, block_id) {
        continue
      }
      if depths[idx] > best_depth ||
        (depths[idx] == best_depth && temps[idx].blocks.length() < best_size) {
        best_loop = idx
        best_depth = depths[idx]
        best_size = temps[idx].blocks.length()
      }
    }
    block_to_loop[block_id] = best_loop
    block_depth[block_id] = best_depth
  }
  (block_to_loop, block_depth)
}

///|
fn loop_info_join_lines(lines : Array[String]) -> String {
  if lines.length() == 0 {
    return ""
  }
  let mut out = lines[0]
  for idx = 1; idx < lines.length(); idx = idx + 1 {
    out = out + "\n" + lines[idx]
  }
  out
}

///|
pub fn loop_info_build(cfg : HotCfg, dom : HotDominators) -> HotLoopInfo {
  let latches_by_header : Array[Array[BlockId]] = []
  for _ in 0..<cfg_block_count(cfg) {
    latches_by_header.push([])
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    if !loop_info_is_reachable(dom, block_id) {
      continue
    }
    for edge in cfg_successor_edges(cfg, block_id) {
      if loop_info_has_backedge(edge, dom, block_id) {
        latches_by_header[edge.block].push(block_id)
      }
    }
  }

  let temps : Array[LoopInfoTemp] = []
  for header = 0; header < cfg_block_count(cfg); header = header + 1 {
    if latches_by_header[header].length() == 0 {
      continue
    }
    temps.push(loop_info_build_one(cfg, header, latches_by_header[header]))
  }

  let parents = Array::make(temps.length(), -1)
  for idx = 0; idx < temps.length(); idx = idx + 1 {
    parents[idx] = loop_info_parent(temps, idx)
  }
  let depths = loop_info_depths(parents)
  let loops : Array[HotLoopSummary] = []
  for idx = 0; idx < temps.length(); idx = idx + 1 {
    loops.push({
      header: temps[idx].header,
      blocks: temps[idx].blocks,
      latches: temps[idx].latches,
      exits: temps[idx].exits,
      parent: parents[idx],
      depth: depths[idx],
    })
  }
  let (block_to_loop, block_depth) = loop_info_block_mappings(
    cfg_block_count(cfg),
    temps,
    depths,
  )
  { loops, block_to_loop, block_depth }
}

///|
pub fn loop_header(info : HotLoopInfo, loop_id : Int) -> BlockId {
  info.loops[loop_id].header
}

///|
pub fn loop_blocks(info : HotLoopInfo, loop_id : Int) -> Array[BlockId] {
  info.loops[loop_id].blocks.copy()
}

///|
pub fn loop_latches(info : HotLoopInfo, loop_id : Int) -> Array[BlockId] {
  info.loops[loop_id].latches.copy()
}

///|
pub fn loop_exits(info : HotLoopInfo, loop_id : Int) -> Array[HotLoopExit] {
  info.loops[loop_id].exits.copy()
}

///|
pub fn loop_depth(info : HotLoopInfo, block_id : BlockId) -> Int {
  if block_id < 0 || block_id >= info.block_depth.length() {
    abort("loop_depth requires a valid block id")
  }
  info.block_depth[block_id]
}

///|
pub fn loop_for_block(info : HotLoopInfo, block_id : BlockId) -> Int? {
  if block_id < 0 || block_id >= info.block_to_loop.length() {
    abort("loop_for_block requires a valid block id")
  }
  match info.block_to_loop[block_id] {
    -1 => None
    loop_id => Some(loop_id)
  }
}

///|
pub fn loop_info_debug_dump(info : HotLoopInfo) -> String {
  let lines : Array[String] = []
  for idx = 0; idx < info.loops.length(); idx = idx + 1 {
    let summary = info.loops[idx]
    lines.push(
      "loop=\{idx} header=\{summary.header} depth=\{summary.depth} parent=\{summary.parent} blocks=\{summary.blocks} latches=\{summary.latches} exits=\{summary.exits}",
    )
  }
  loop_info_join_lines(lines)
}
