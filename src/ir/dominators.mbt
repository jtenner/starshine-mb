///|
pub struct HotDominators {
  entry_block : BlockId
  reachable : Bitset
  idoms : Array[BlockId]
  children : Array[Array[BlockId]]
  frontiers : Array[Array[BlockId]]
  dom_preorder : Array[Int]
  dom_postorder : Array[Int]
} derive(Eq, Show, Debug)

///|
fn dom_has_reachable(blocks : Bitset, block_id : BlockId) -> Bool {
  if block_id < 0 || block_id >= blocks.size {
    return false
  }
  bitset_contains(blocks, block_id)
}

///|
fn dom_normal_preds(
  cfg : HotCfg,
  reachable : Bitset,
  block_id : BlockId,
) -> Array[BlockId] {
  let preds : Array[BlockId] = []
  for edge in cfg_predecessors(cfg, block_id) {
    if edge.kind == CfgEdgeKind::ExceptionalEdge ||
      !dom_has_reachable(reachable, edge.block) {
      continue
    }
    preds.push(edge.block)
  }
  preds
}

///|
fn dom_intersect(
  idoms : Array[BlockId],
  rpo_index : Array[Int],
  lhs : BlockId,
  rhs : BlockId,
) -> BlockId {
  let mut finger_lhs = lhs
  let mut finger_rhs = rhs
  while finger_lhs != finger_rhs {
    while rpo_index[finger_lhs] > rpo_index[finger_rhs] {
      finger_lhs = idoms[finger_lhs]
    }
    while rpo_index[finger_rhs] > rpo_index[finger_lhs] {
      finger_rhs = idoms[finger_rhs]
    }
  }
  finger_lhs
}

///|
fn dom_build_children(
  block_count : Int,
  reachable_rpo : Array[BlockId],
  idoms : Array[BlockId],
) -> Array[Array[BlockId]] {
  let children : Array[Array[BlockId]] = []
  for _ in 0..<block_count {
    children.push([])
  }
  for idx = 1; idx < reachable_rpo.length(); idx = idx + 1 {
    let block_id = reachable_rpo[idx]
    children[idoms[block_id]].push(block_id)
  }
  children
}

///|
fn dom_build_tree_intervals(
  entry_block : BlockId,
  children : Array[Array[BlockId]],
) -> (Array[Int], Array[Int]) {
  let dom_preorder = Array::make(children.length(), -1)
  let dom_postorder = Array::make(children.length(), -1)
  let stack : Array[(BlockId, Bool)] = [(entry_block, false)]
  let mut tick = 0
  while stack.length() > 0 {
    let (block_id, expanded) = stack.pop().unwrap()
    if expanded {
      dom_postorder[block_id] = tick
      tick = tick + 1
      continue
    }
    dom_preorder[block_id] = tick
    tick = tick + 1
    stack.push((block_id, true))
    for idx = children[block_id].length() - 1; idx >= 0; idx = idx - 1 {
      stack.push((children[block_id][idx], false))
    }
  }
  (dom_preorder, dom_postorder)
}

///|
fn dom_build_frontiers(
  cfg : HotCfg,
  reachable : Bitset,
  idoms : Array[BlockId],
) -> Array[Array[BlockId]] {
  let frontier_bits : Array[Bitset] = []
  for _ in 0..<cfg_block_count(cfg) {
    frontier_bits.push(bitset_new(cfg_block_count(cfg)))
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    if !dom_has_reachable(reachable, block_id) {
      continue
    }
    let preds = dom_normal_preds(cfg, reachable, block_id)
    if preds.length() < 2 {
      continue
    }
    for pred in preds {
      let mut runner = pred
      while runner != idoms[block_id] {
        ignore(bitset_set(frontier_bits[runner], block_id))
        runner = idoms[runner]
      }
    }
  }
  let frontiers : Array[Array[BlockId]] = []
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    let frontier : Array[BlockId] = []
    bitset_for_each_set_bit(frontier_bits[block_id], fn(target) {
      frontier.push(target)
    })
    frontiers.push(frontier)
  }
  frontiers
}

///|
fn dom_verify(cfg : HotCfg, dom : HotDominators) -> Unit {
  if !dom_has_reachable(dom.reachable, dom.entry_block) {
    abort("dominators must mark the cfg entry block as reachable")
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    if !dom_has_reachable(dom.reachable, block_id) {
      if dom.idoms[block_id] != -1 {
        abort("unreachable blocks must not carry an immediate dominator")
      }
      continue
    }
    if block_id == dom.entry_block {
      if dom.idoms[block_id] != block_id {
        abort("entry block must self-root the internal dominator tree")
      }
      continue
    }
    let idom = dom.idoms[block_id]
    if idom < 0 || !dom_has_reachable(dom.reachable, idom) {
      abort(
        "reachable non-entry blocks must have reachable immediate dominators",
      )
    }
    if !dom_dominates(dom, idom, block_id) {
      abort("immediate dominators must dominate their child block")
    }
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    for child in dom.children[block_id] {
      if dom.idoms[child] != block_id {
        abort("dominator tree children must agree with immediate dominators")
      }
    }
    for frontier in dom.frontiers[block_id] {
      if !dom_has_reachable(dom.reachable, frontier) {
        abort("dominance frontiers must only reference reachable blocks")
      }
    }
  }
}

///|
fn dom_join_lines(lines : Array[String]) -> String {
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
pub fn dom_build(cfg : HotCfg) -> HotDominators {
  let reachable_rpo = cfg_reverse_postorder(cfg)
  let block_count = cfg_block_count(cfg)
  let reachable = bitset_new(block_count)
  let rpo_index = Array::make(block_count, -1)
  for idx = 0; idx < reachable_rpo.length(); idx = idx + 1 {
    let block_id = reachable_rpo[idx]
    ignore(bitset_set(reachable, block_id))
    rpo_index[block_id] = idx
  }
  let entry_block = cfg_entry_block(cfg)
  let idoms = Array::make(block_count, -1)
  idoms[entry_block] = entry_block
  let mut changed = true
  while changed {
    changed = false
    for idx = 1; idx < reachable_rpo.length(); idx = idx + 1 {
      let block_id = reachable_rpo[idx]
      let preds = dom_normal_preds(cfg, reachable, block_id)
      let mut new_idom = -1
      for pred in preds {
        if idoms[pred] < 0 {
          continue
        }
        new_idom = if new_idom < 0 {
          pred
        } else {
          dom_intersect(idoms, rpo_index, pred, new_idom)
        }
      }
      if new_idom < 0 {
        abort(
          "reachable dominator blocks must have a non-exceptional predecessor",
        )
      }
      if idoms[block_id] != new_idom {
        idoms[block_id] = new_idom
        changed = true
      }
    }
  }
  let children = dom_build_children(block_count, reachable_rpo, idoms)
  let (dom_preorder, dom_postorder) = dom_build_tree_intervals(
    entry_block, children,
  )
  let frontiers = dom_build_frontiers(cfg, reachable, idoms)
  let dom = {
    entry_block,
    reachable,
    idoms,
    children,
    frontiers,
    dom_preorder,
    dom_postorder,
  }
  dom_verify(cfg, dom)
  dom
}

///|
pub fn dom_idom(dom : HotDominators, block_id : BlockId) -> BlockId? {
  if !dom_has_reachable(dom.reachable, block_id) || block_id == dom.entry_block {
    return None
  }
  Some(dom.idoms[block_id])
}

///|
pub fn dom_children(dom : HotDominators, block_id : BlockId) -> Array[BlockId] {
  if block_id < 0 || block_id >= dom.children.length() {
    abort("dom_children requires a valid block id")
  }
  dom.children[block_id].copy()
}

///|
pub fn dom_dominates(dom : HotDominators, lhs : BlockId, rhs : BlockId) -> Bool {
  if !dom_has_reachable(dom.reachable, lhs) ||
    !dom_has_reachable(dom.reachable, rhs) {
    return false
  }
  dom.dom_preorder[lhs] <= dom.dom_preorder[rhs] &&
  dom.dom_postorder[rhs] <= dom.dom_postorder[lhs]
}

///|
pub fn dom_strictly_dominates(
  dom : HotDominators,
  lhs : BlockId,
  rhs : BlockId,
) -> Bool {
  lhs != rhs && dom_dominates(dom, lhs, rhs)
}

///|
pub fn dom_frontier(dom : HotDominators, block_id : BlockId) -> Array[BlockId] {
  if block_id < 0 || block_id >= dom.frontiers.length() {
    abort("dom_frontier requires a valid block id")
  }
  dom.frontiers[block_id].copy()
}

///|
pub fn dom_debug_dump(dom : HotDominators) -> String {
  let lines = ["entry=\{dom.entry_block}"]
  for block_id = 0; block_id < dom.idoms.length(); block_id = block_id + 1 {
    if !dom_has_reachable(dom.reachable, block_id) {
      continue
    }
    lines.push(
      "block=\{block_id} idom=\{dom_idom(dom, block_id)} children=\{dom.children[block_id]} frontier=\{dom.frontiers[block_id]}",
    )
  }
  dom_join_lines(lines)
}
