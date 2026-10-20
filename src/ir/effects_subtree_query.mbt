///|
fn effects_subtree_own_mask(func : HotFunc, node_id : NodeId) -> EffectMask {
  effects_mask_for_flags(hot_node_flags(func, node_id)) |
  effects_mask_for_node_exact(func, node_id)
}

///|
priv struct EffectsSubtreeWord {
  mut bits : UInt64
}

///|
priv struct EffectsSubtreeVisited {
  mut sparse : @hashmap.HashMap[Int32, EffectsSubtreeWord]?
  mut dense : @bitset.BitSet?
  mut last_word_index : Int32
  mut last_word : EffectsSubtreeWord?
  sparse_limit : Int32
}

///|
fn EffectsSubtreeVisited::new(node_count : Int32) -> EffectsSubtreeVisited {
  {
    sparse: if node_count <= 4096 {
      None
    } else {
      Some(@hashmap.new())
    },
    dense: if node_count <= 4096 {
      Some(@bitset.BitSet::new(node_count))
    } else {
      None
    },
    last_word_index: -1,
    last_word: None,
    // A sparse word has 64 visited bits. Promote while its hash storage is
    // still small compared with the compact whole-arena bitset.
    sparse_limit: (node_count / 1024).max(1),
  }
}

///|
fn EffectsSubtreeVisited::enter(
  self : EffectsSubtreeVisited,
  node_id : NodeId,
  node_count : Int32,
) -> Bool {
  match self.dense {
    Some(bits) => {
      if bits[node_id] {
        return false
      }
      bits[node_id] = true
    }
    None => {
      let entries = self.sparse.unwrap()
      let word_index = node_id >> 6
      let word = if self.last_word_index == word_index {
        self.last_word.unwrap()
      } else {
        let word = match entries.get(word_index) {
          Some(word) => word
          None => {
            let word = { bits: 0UL, }
            entries.set(word_index, word)
            word
          }
        }
        self.last_word_index = word_index
        self.last_word = Some(word)
        word
      }
      let mask = 1UL << (node_id & 63)
      if (word.bits & mask) != 0UL {
        return false
      }
      word.bits = word.bits | mask
      if entries.length() >= self.sparse_limit {
        let bits = @bitset.BitSet::new(node_count)
        for index, entry in entries {
          for bit in 0..<64 {
            if (entry.bits & (1UL << bit)) != 0UL {
              bits[index * 64 + bit] = true
            }
          }
        }
        self.dense = Some(bits)
        self.sparse = None
        self.last_word = None
        self.last_word_index = -1
      }
    }
  }
  true
}

///|
fn effects_subtree_accumulate_dense(
  func : HotFunc,
  node_id : NodeId,
  seen : @bitset.BitSet,
) -> EffectMask {
  if hot_child_count(func, node_id) != 0 {
    if seen[node_id] {
      return 0U
    }
    seen[node_id] = true
  }
  let mut mask = effects_subtree_own_mask(func, node_id)
  for slot = 0; slot < hot_child_count(func, node_id); slot = slot + 1 {
    let child = hot_child_get(func, node_id, slot)
    if child >= 0 && hot_node_is_live(func, child) {
      mask = mask | effects_subtree_accumulate_dense(func, child, seen)
    }
  }
  mask
}

///|
fn effects_subtree_accumulate(
  func : HotFunc,
  node_id : NodeId,
  seen : EffectsSubtreeVisited,
) -> EffectMask {
  match seen.dense {
    Some(bits) => return effects_subtree_accumulate_dense(func, node_id, bits)
    None => ()
  }
  // Repeated leaf masks are idempotent; only inner nodes need cycle/DAG marks.
  if hot_child_count(func, node_id) == 0 {
    return effects_subtree_own_mask(func, node_id)
  }
  if !seen.enter(node_id, hot_node_count(func)) {
    return 0U
  }
  let mut mask = effects_subtree_own_mask(func, node_id)
  for slot = 0; slot < hot_child_count(func, node_id); slot = slot + 1 {
    let child = hot_child_get(func, node_id, slot)
    if child >= 0 && hot_node_is_live(func, child) {
      mask = mask | effects_subtree_accumulate(func, child, seen)
    }
  }
  mask
}

///|
/// Query exact subtree effects without full-arena effect-mask scratch.
/// Leaves and shallow scalar trees need no allocation. Larger queries start
/// sparse in large arenas and switch to compact visited bits as density rises.
pub fn effects_for_node_subtree(func : HotFunc, node_id : NodeId) -> EffectMask {
  let mut mask = effects_subtree_own_mask(func, node_id)
  let mut shallow = true
  for slot = 0; slot < hot_child_count(func, node_id); slot = slot + 1 {
    let child = hot_child_get(func, node_id, slot)
    if child < 0 || !hot_node_is_live(func, child) {
      continue
    }
    if hot_child_count(func, child) != 0 {
      shallow = false
      break
    }
    mask = mask | effects_subtree_own_mask(func, child)
  }
  if shallow {
    return mask
  }
  effects_subtree_accumulate(
    func,
    node_id,
    EffectsSubtreeVisited::new(hot_node_count(func)),
  )
}
