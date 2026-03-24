///|
pub enum HotVisitCtl[S, E] {
  Continue(S)
  Skip(S)
  Stop(S)
  Error(E)
}

///|
pub fn[S, E] hot_visit_continue(state : S) -> HotVisitCtl[S, E] {
  Continue(state)
}

///|
pub fn[S, E] hot_visit_skip(state : S) -> HotVisitCtl[S, E] {
  Skip(state)
}

///|
pub fn[S, E] hot_visit_stop(state : S) -> HotVisitCtl[S, E] {
  Stop(state)
}

///|
pub fn[S, E] hot_visit_error(err : E) -> HotVisitCtl[S, E] {
  Error(err)
}

///|
pub enum HotRewriteCtl[S, E] {
  Same(S)
  Replace(S, NodeId)
  Remove(S)
  Error(E)
}

///|
pub fn[S, E] hot_rewrite_same(state : S) -> HotRewriteCtl[S, E] {
  Same(state)
}

///|
pub fn[S, E] hot_rewrite_replace(
  state : S,
  replacement : NodeId,
) -> HotRewriteCtl[S, E] {
  Replace(state, replacement)
}

///|
pub fn[S, E] hot_rewrite_remove(state : S) -> HotRewriteCtl[S, E] {
  Remove(state)
}

///|
pub fn[S, E] hot_rewrite_error(err : E) -> HotRewriteCtl[S, E] {
  Error(err)
}

///|
fn hot_walk_push_live_node(
  func : HotFunc,
  stack : Array[NodeId],
  node_id : NodeId,
) -> Unit {
  if node_id != HOT_NONE_NODE && hot_node_is_live(func, node_id) {
    stack.push(node_id)
  }
}

///|
fn hot_walk_push_children_reversed(
  func : HotFunc,
  stack : Array[NodeId],
  node_id : NodeId,
) -> Unit {
  for i = hot_child_count(func, node_id) - 1; i >= 0; i = i - 1 {
    hot_walk_push_live_node(func, stack, hot_child_get(func, node_id, i))
  }
}

///|
pub fn[S, E] hot_for_each_root(
  func : HotFunc,
  initial : S,
  visit : (S, Int, NodeId) -> HotVisitCtl[S, E],
) -> Result[S, E] {
  let mut state = initial
  for idx = 0; idx < hot_root_count(func); idx = idx + 1 {
    match visit(state, idx, hot_root_get(func, idx)) {
      HotVisitCtl::Continue(next) => state = next
      HotVisitCtl::Skip(next) => state = next
      HotVisitCtl::Stop(next) => return Ok(next)
      HotVisitCtl::Error(err) => return Err(err)
    }
  }
  Ok(state)
}

///|
pub fn[S, E] hot_for_each_child(
  func : HotFunc,
  parent_id : NodeId,
  initial : S,
  visit : (S, Int, NodeId) -> HotVisitCtl[S, E],
) -> Result[S, E] {
  let mut state = initial
  for slot = 0; slot < hot_child_count(func, parent_id); slot = slot + 1 {
    match visit(state, slot, hot_child_get(func, parent_id, slot)) {
      HotVisitCtl::Continue(next) => state = next
      HotVisitCtl::Skip(next) => state = next
      HotVisitCtl::Stop(next) => return Ok(next)
      HotVisitCtl::Error(err) => return Err(err)
    }
  }
  Ok(state)
}

///|
pub fn[S, E] hot_walk_subtree_preorder(
  func : HotFunc,
  root_id : NodeId,
  initial : S,
  visit : (S, NodeId) -> HotVisitCtl[S, E],
) -> Result[S, E] {
  let mut state = initial
  let stack : Array[NodeId] = []
  hot_walk_push_live_node(func, stack, root_id)
  while stack.length() > 0 {
    let node_id = stack.pop().unwrap()
    match visit(state, node_id) {
      HotVisitCtl::Continue(next) => {
        state = next
        hot_walk_push_children_reversed(func, stack, node_id)
      }
      HotVisitCtl::Skip(next) => state = next
      HotVisitCtl::Stop(next) => return Ok(next)
      HotVisitCtl::Error(err) => return Err(err)
    }
  }
  Ok(state)
}

///|
pub fn[S, E] hot_walk_subtree_postorder(
  func : HotFunc,
  root_id : NodeId,
  initial : S,
  visit : (S, NodeId) -> HotVisitCtl[S, E],
) -> Result[S, E] {
  let mut state = initial
  let stack : Array[(NodeId, Bool)] = []
  if root_id != HOT_NONE_NODE && hot_node_is_live(func, root_id) {
    stack.push((root_id, false))
  }
  while stack.length() > 0 {
    let (node_id, expanded) = stack.pop().unwrap()
    if expanded {
      match visit(state, node_id) {
        HotVisitCtl::Continue(next) => state = next
        HotVisitCtl::Skip(next) => state = next
        HotVisitCtl::Stop(next) => return Ok(next)
        HotVisitCtl::Error(err) => return Err(err)
      }
      continue
    }
    stack.push((node_id, true))
    for i = hot_child_count(func, node_id) - 1; i >= 0; i = i - 1 {
      let child_id = hot_child_get(func, node_id, i)
      if child_id != HOT_NONE_NODE && hot_node_is_live(func, child_id) {
        stack.push((child_id, false))
      }
    }
  }
  Ok(state)
}

///|
pub fn[S, E] hot_walk_region(
  func : HotFunc,
  region_id : NodeId,
  initial : S,
  visit : (S, Int, NodeId) -> HotVisitCtl[S, E],
) -> Result[S, E] {
  hot_for_each_child(func, region_id, initial, visit)
}

///|
pub fn[S, E] hot_rewrite_children_by_slot(
  func : HotFunc,
  parent_id : NodeId,
  initial : S,
  rewrite : (S, NodeId, Int, NodeId) -> HotRewriteCtl[S, E],
) -> Result[S, E] {
  let mut state = initial
  for slot = 0; slot < hot_child_count(func, parent_id); slot = slot + 1 {
    let child_id = hot_child_get(func, parent_id, slot)
    match rewrite(state, parent_id, slot, child_id) {
      HotRewriteCtl::Same(next) => state = next
      HotRewriteCtl::Replace(next, replacement) => {
        hot_child_set(func, parent_id, slot, replacement)
        state = next
      }
      HotRewriteCtl::Remove(next) => {
        hot_child_set(func, parent_id, slot, HOT_NONE_NODE)
        state = next
      }
      HotRewriteCtl::Error(err) => return Err(err)
    }
  }
  Ok(state)
}

///|
pub fn[S, E] hot_worklist_walk(
  func : HotFunc,
  seeds : Array[NodeId],
  initial : S,
  visit : (S, NodeId) -> HotVisitCtl[S, E],
) -> Result[S, E] {
  let mut state = initial
  let stack : Array[NodeId] = []
  for i = seeds.length() - 1; i >= 0; i = i - 1 {
    hot_walk_push_live_node(func, stack, seeds[i])
  }
  while stack.length() > 0 {
    let node_id = stack.pop().unwrap()
    match visit(state, node_id) {
      HotVisitCtl::Continue(next) => {
        state = next
        hot_walk_push_children_reversed(func, stack, node_id)
      }
      HotVisitCtl::Skip(next) => state = next
      HotVisitCtl::Stop(next) => return Ok(next)
      HotVisitCtl::Error(err) => return Err(err)
    }
  }
  Ok(state)
}

///|
pub fn[S, E] hot_walk_control_regions(
  func : HotFunc,
  control_id : NodeId,
  initial : S,
  visit : (S, NodeId, HotControlRegionSlotInfo, NodeId) -> HotVisitCtl[S, E],
) -> Result[S, E] {
  let mut state = initial
  let slot_infos = hot_control_region_slot_info(
    hot_node_get(func, control_id).op,
  )
  for slot_info in slot_infos {
    if slot_info.slot >= hot_child_count(func, control_id) {
      continue
    }
    let region_id = hot_child_get(func, control_id, slot_info.slot)
    if region_id == HOT_NONE_NODE || !hot_node_is_live(func, region_id) {
      continue
    }
    match visit(state, control_id, slot_info, region_id) {
      HotVisitCtl::Continue(next) => state = next
      HotVisitCtl::Skip(next) => state = next
      HotVisitCtl::Stop(next) => return Ok(next)
      HotVisitCtl::Error(err) => return Err(err)
    }
  }
  Ok(state)
}
