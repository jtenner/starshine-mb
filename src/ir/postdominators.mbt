///|
pub struct HotPostDominators {
  roots : Array[BlockId]
  reachable : Bitset
  postdom_sets : Array[Bitset]
  ipdoms : Array[BlockId]
  children : Array[Array[BlockId]]
  frontiers : Array[Array[BlockId]]
} derive(Eq, Show, Debug)

///|
fn postdom_has_reachable(reachable : Bitset, block_id : BlockId) -> Bool {
  if block_id < 0 || block_id >= reachable.size {
    return false
  }
  bitset_contains(reachable, block_id)
}

///|
fn postdom_bitset_clone(src : Bitset) -> Bitset {
  let out = bitset_new(src.size)
  ignore(bitset_union_into(out, src))
  out
}

///|
fn postdom_root_blocks(cfg : HotCfg) -> Array[BlockId] {
  let roots = [cfg_exit_block(cfg)]
  match cfg_exceptional_exit_block(cfg) {
    Some(block_id) if block_id != cfg_exit_block(cfg) => roots.push(block_id)
    _ => ()
  }
  roots
}

///|
fn postdom_successors(
  cfg : HotCfg,
  reachable : Bitset,
  block_id : BlockId,
) -> Array[BlockId] {
  let succs : Array[BlockId] = []
  for edge in cfg_successors(cfg, block_id) {
    if postdom_has_reachable(reachable, edge.block) {
      succs.push(edge.block)
    }
  }
  succs
}

///|
fn postdom_build_children(
  block_count : Int,
  ipdoms : Array[BlockId],
) -> Array[Array[BlockId]] {
  let children : Array[Array[BlockId]] = []
  for _ in 0..<block_count {
    children.push([])
  }
  for block_id = 0; block_id < block_count; block_id = block_id + 1 {
    let ipdom = ipdoms[block_id]
    if ipdom >= 0 {
      children[ipdom].push(block_id)
    }
  }
  children
}

///|
fn postdom_build_frontiers(
  cfg : HotCfg,
  reachable : Bitset,
  ipdoms : Array[BlockId],
) -> Array[Array[BlockId]] {
  let frontier_bits : Array[Bitset] = []
  for _ in 0..<cfg_block_count(cfg) {
    frontier_bits.push(bitset_new(cfg_block_count(cfg)))
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    if !postdom_has_reachable(reachable, block_id) {
      continue
    }
    let succs = postdom_successors(cfg, reachable, block_id)
    if succs.length() < 2 {
      continue
    }
    for succ in succs {
      let mut runner = succ
      while runner >= 0 && runner != ipdoms[block_id] {
        ignore(bitset_set(frontier_bits[runner], block_id))
        runner = ipdoms[runner]
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
fn postdom_build_ipdoms(postdom : HotPostDominators) -> Array[BlockId] {
  let ipdoms = Array::make(postdom.postdom_sets.length(), -1)
  let roots = bitset_new(postdom.reachable.size)
  for root in postdom.roots {
    ignore(bitset_set(roots, root))
  }
  for block_id = 0
      block_id < postdom.postdom_sets.length()
      block_id = block_id + 1 {
    if !postdom_has_reachable(postdom.reachable, block_id) ||
      bitset_contains(roots, block_id) {
      continue
    }
    let candidates = postdom_bitset_clone(postdom.postdom_sets[block_id])
    ignore(bitset_clear(candidates, block_id))
    let strict : Array[BlockId] = []
    bitset_for_each_set_bit(candidates, fn(candidate) { strict.push(candidate) })
    for candidate in strict {
      let mut is_ipdom = true
      for other in strict {
        if other == candidate {
          continue
        }
        if !bitset_contains(postdom.postdom_sets[candidate], other) {
          is_ipdom = false
          break
        }
      }
      if is_ipdom {
        ipdoms[block_id] = candidate
        break
      }
    }
  }
  ipdoms
}

///|
fn postdom_join_lines(lines : Array[String]) -> String {
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
fn postdom_verify(cfg : HotCfg, postdom : HotPostDominators) -> Unit {
  for root in postdom.roots {
    if !postdom_has_reachable(postdom.reachable, root) {
      abort("postdominators must mark every configured exit root as reachable")
    }
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    if !postdom_has_reachable(postdom.reachable, block_id) {
      if postdom.ipdoms[block_id] != -1 {
        abort("unreachable blocks must not carry immediate post-dominators")
      }
      continue
    }
    if !bitset_contains(postdom.postdom_sets[block_id], block_id) {
      abort("every reachable block must postdominate itself")
    }
    let ipdom = postdom.ipdoms[block_id]
    if ipdom >= 0 && !postdom_postdominates(postdom, ipdom, block_id) {
      abort("immediate post-dominators must postdominate their child block")
    }
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    for child in postdom.children[block_id] {
      if postdom.ipdoms[child] != block_id {
        abort(
          "postdominator tree children must match immediate post-dominators",
        )
      }
    }
    for frontier in postdom.frontiers[block_id] {
      if !postdom_has_reachable(postdom.reachable, frontier) {
        abort("postdominator frontiers must stay within the reachable overlay")
      }
    }
  }
}

///|
pub fn postdom_build(cfg : HotCfg) -> HotPostDominators {
  let roots = postdom_root_blocks(cfg)
  let reachable_order = cfg_reverse_postorder_from_exit_with_exceptions(cfg)
  let reachable = bitset_new(cfg_block_count(cfg))
  for block_id in reachable_order {
    ignore(bitset_set(reachable, block_id))
  }
  let universe = postdom_bitset_clone(reachable)
  let postdom_sets : Array[Bitset] = []
  let root_set = bitset_new(cfg_block_count(cfg))
  for root in roots {
    ignore(bitset_set(root_set, root))
  }
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    let set = bitset_new(cfg_block_count(cfg))
    if !postdom_has_reachable(reachable, block_id) {
      postdom_sets.push(set)
      continue
    }
    if bitset_contains(root_set, block_id) {
      ignore(bitset_set(set, block_id))
    } else {
      ignore(bitset_union_into(set, universe))
    }
    postdom_sets.push(set)
  }

  let mut changed = true
  while changed {
    changed = false
    for idx = reachable_order.length() - 1; idx >= 0; idx = idx - 1 {
      let block_id = reachable_order[idx]
      if bitset_contains(root_set, block_id) {
        continue
      }
      let succs = postdom_successors(cfg, reachable, block_id)
      let next_set = if succs.length() == 0 {
        bitset_new(cfg_block_count(cfg))
      } else {
        let intersect = postdom_bitset_clone(postdom_sets[succs[0]])
        for succ_idx = 1; succ_idx < succs.length(); succ_idx = succ_idx + 1 {
          ignore(
            bitset_intersect_into(intersect, postdom_sets[succs[succ_idx]]),
          )
        }
        intersect
      }
      ignore(bitset_set(next_set, block_id))
      if !bitset_equals(postdom_sets[block_id], next_set) {
        postdom_sets[block_id] = next_set
        changed = true
      }
    }
  }

  let base = {
    roots,
    reachable,
    postdom_sets,
    ipdoms: Array::make(cfg_block_count(cfg), -1),
    children: Array::make(cfg_block_count(cfg), []),
    frontiers: Array::make(cfg_block_count(cfg), []),
  }
  let ipdoms = postdom_build_ipdoms(base)
  let children = postdom_build_children(cfg_block_count(cfg), ipdoms)
  let frontiers = postdom_build_frontiers(cfg, reachable, ipdoms)
  let postdom = { roots, reachable, postdom_sets, ipdoms, children, frontiers }
  postdom_verify(cfg, postdom)
  postdom
}

///|
pub fn postdom_ipdom(
  postdom : HotPostDominators,
  block_id : BlockId,
) -> BlockId? {
  if block_id < 0 || block_id >= postdom.ipdoms.length() {
    abort("postdom_ipdom requires a valid block id")
  }
  match postdom.ipdoms[block_id] {
    -1 => None
    block => Some(block)
  }
}

///|
pub fn postdom_children(
  postdom : HotPostDominators,
  block_id : BlockId,
) -> Array[BlockId] {
  if block_id < 0 || block_id >= postdom.children.length() {
    abort("postdom_children requires a valid block id")
  }
  postdom.children[block_id].copy()
}

///|
pub fn postdom_postdominates(
  postdom : HotPostDominators,
  lhs : BlockId,
  rhs : BlockId,
) -> Bool {
  if rhs < 0 ||
    rhs >= postdom.postdom_sets.length() ||
    lhs < 0 ||
    lhs >= postdom.postdom_sets.length() ||
    !postdom_has_reachable(postdom.reachable, lhs) ||
    !postdom_has_reachable(postdom.reachable, rhs) {
    return false
  }
  bitset_contains(postdom.postdom_sets[rhs], lhs)
}

///|
pub fn postdom_frontier(
  postdom : HotPostDominators,
  block_id : BlockId,
) -> Array[BlockId] {
  if block_id < 0 || block_id >= postdom.frontiers.length() {
    abort("postdom_frontier requires a valid block id")
  }
  postdom.frontiers[block_id].copy()
}

///|
pub fn postdom_debug_dump(postdom : HotPostDominators) -> String {
  let lines = ["roots=\{postdom.roots}"]
  for block_id = 0
      block_id < postdom.postdom_sets.length()
      block_id = block_id + 1 {
    if !postdom_has_reachable(postdom.reachable, block_id) {
      continue
    }
    lines.push(
      "block=\{block_id} ipdom=\{postdom_ipdom(postdom, block_id)} children=\{postdom.children[block_id]} frontier=\{postdom.frontiers[block_id]}",
    )
  }
  postdom_join_lines(lines)
}
