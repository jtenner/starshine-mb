///|
fn hot_mutate_type_id_is_valid(func : HotFunc, ty : TypeId) -> Bool {
  ty >= 0 && ty < func.types.length()
}

///|
fn hot_mutate_require_type_id(
  func : HotFunc,
  ty : TypeId,
  context : String,
) -> Unit {
  if !hot_mutate_type_id_is_valid(func, ty) {
    abort("\{context} must reference a valid interned TypeId")
  }
}

///|
fn hot_mutate_require_live_node(
  func : HotFunc,
  node_id : NodeId,
  context : String,
) -> Unit {
  if !hot_node_is_live(func, node_id) {
    abort("\{context} must reference a live NodeId")
  }
}

///|
fn hot_mutate_child_ref_is_valid(func : HotFunc, child_id : NodeId) -> Bool {
  child_id == HOT_NONE_NODE || hot_node_is_live(func, child_id)
}

///|
fn hot_mutate_require_child_ref(func : HotFunc, child_id : NodeId) -> Unit {
  if !hot_mutate_child_ref_is_valid(func, child_id) {
    abort("hot child slots must reference live NodeIds or HOT_NONE_NODE")
  }
}

///|
fn hot_mutate_require_root_index(
  func : HotFunc,
  idx : Int,
  allow_end? : Bool = false,
) -> Unit {
  let upper = if allow_end {
    func.roots.length()
  } else {
    func.roots.length() - 1
  }
  if idx < 0 || idx > upper {
    abort("hot root index out of bounds")
  }
}

///|
fn hot_mutate_require_remove_count(
  length : Int,
  idx : Int,
  remove_count : Int,
) -> Unit {
  if remove_count < 0 || idx + remove_count > length {
    abort("hot splice remove_count out of bounds")
  }
}

///|
fn hot_mutate_require_child_index(node : HotNode, idx : Int) -> Unit {
  if idx < 0 || idx >= node.child_count {
    abort("hot child index out of bounds")
  }
}

///|
fn hot_mutate_require_node_shape(
  func : HotFunc,
  node : HotNode,
  context : String,
) -> Unit {
  hot_mutate_require_type_id(func, node.ty, context)
  if node.child_base < 0 ||
    node.child_count < 0 ||
    node.child_base + node.child_count > func.children.length() {
    abort("\{context} must reference an in-bounds child span")
  }
}

///|
fn hot_mutate_write_child_span(
  func : HotFunc,
  base : Int,
  children : Array[NodeId],
) -> Unit {
  for i = 0; i < children.length(); i = i + 1 {
    hot_mutate_require_child_ref(func, children[i])
    func.children[base + i] = children[i]
  }
}

///|
pub fn hot_revision_bump(func : HotFunc) -> Unit {
  func.revision += 1
}

///|
pub fn hot_root_count(func : HotFunc) -> Int {
  func.roots.length()
}

///|
pub fn hot_root_get(func : HotFunc, idx : Int) -> NodeId {
  hot_mutate_require_root_index(func, idx)
  func.roots[idx]
}

///|
pub fn hot_root_set(func : HotFunc, idx : Int, id : NodeId) -> Unit {
  hot_mutate_require_root_index(func, idx)
  hot_mutate_require_live_node(func, id, "hot root slots")
  func.roots[idx] = id
  hot_revision_bump(func)
}

///|
pub fn hot_root_append(func : HotFunc, id : NodeId) -> Unit {
  hot_mutate_require_live_node(func, id, "hot root slots")
  func.roots.push(id)
  hot_revision_bump(func)
}

///|
pub fn hot_append_root(func : HotFunc, id : NodeId) -> Unit {
  hot_root_append(func, id)
}

///|
fn hot_mutate_root_insert_no_bump(
  func : HotFunc,
  idx : Int,
  id : NodeId,
) -> Unit {
  func.roots.push(id)
  let mut i = func.roots.length() - 1
  while i > idx {
    func.roots[i] = func.roots[i - 1]
    i = i - 1
  }
  func.roots[idx] = id
}

///|
pub fn hot_root_insert(func : HotFunc, idx : Int, id : NodeId) -> Unit {
  hot_mutate_require_root_index(func, idx, allow_end=true)
  hot_mutate_require_live_node(func, id, "hot root slots")
  hot_mutate_root_insert_no_bump(func, idx, id)
  hot_revision_bump(func)
}

///|
fn hot_mutate_root_remove_no_bump(func : HotFunc, idx : Int) -> NodeId {
  let removed = func.roots[idx]
  let last = func.roots.length() - 1
  for i = idx; i < last; i = i + 1 {
    func.roots[i] = func.roots[i + 1]
  }
  ignore(func.roots.pop())
  removed
}

///|
pub fn hot_root_remove(func : HotFunc, idx : Int) -> NodeId {
  hot_mutate_require_root_index(func, idx)
  let removed = hot_mutate_root_remove_no_bump(func, idx)
  hot_revision_bump(func)
  removed
}

///|
pub fn hot_root_splice(
  func : HotFunc,
  idx : Int,
  remove_count : Int,
  new_roots : Array[NodeId],
) -> Array[NodeId] {
  hot_mutate_require_root_index(func, idx, allow_end=true)
  hot_mutate_require_remove_count(func.roots.length(), idx, remove_count)
  for root in new_roots {
    hot_mutate_require_live_node(func, root, "hot root slots")
  }
  let removed : Array[NodeId] = []
  for i = idx; i < idx + remove_count; i = i + 1 {
    removed.push(func.roots[i])
  }
  for _ in 0..<remove_count {
    ignore(hot_mutate_root_remove_no_bump(func, idx))
  }
  for insert_idx = 0
      insert_idx < new_roots.length()
      insert_idx = insert_idx + 1 {
    hot_mutate_root_insert_no_bump(
      func,
      idx + insert_idx,
      new_roots[insert_idx],
    )
  }
  hot_revision_bump(func)
  removed
}

///|
pub fn hot_child_count(func : HotFunc, id : NodeId) -> Int {
  hot_mutate_require_live_node(func, id, "hot child_count")
  func.nodes[id].child_count
}

///|
pub fn hot_child_get(func : HotFunc, id : NodeId, idx : Int) -> NodeId {
  let node = hot_node_get(func, id)
  hot_mutate_require_child_index(node, idx)
  func.children[node.child_base + idx]
}

///|
pub fn hot_child_set(
  func : HotFunc,
  id : NodeId,
  idx : Int,
  child : NodeId,
) -> Unit {
  let node = hot_node_get(func, id)
  hot_mutate_require_child_index(node, idx)
  hot_mutate_require_child_ref(func, child)
  func.children[node.child_base + idx] = child
  hot_revision_bump(func)
}

///|
pub fn hot_alloc_child_span(func : HotFunc, count : Int) -> Int {
  if count < 0 {
    abort("hot child span count must be non-negative")
  }
  let base = func.children.length()
  for _ in 0..<count {
    func.children.push(HOT_NONE_NODE)
  }
  base
}

///|
pub fn hot_alloc_children(func : HotFunc, count : Int) -> Int {
  hot_alloc_child_span(func, count)
}

///|
pub fn hot_replace_child_span(
  func : HotFunc,
  id : NodeId,
  new_children : Array[NodeId],
) -> Array[NodeId] {
  let node = hot_node_get(func, id)
  let removed : Array[NodeId] = []
  for i = 0; i < node.child_count; i = i + 1 {
    removed.push(func.children[node.child_base + i])
  }
  let base = hot_alloc_child_span(func, new_children.length())
  hot_mutate_write_child_span(func, base, new_children)
  func.nodes[id] = {
    ..node,
    child_base: base,
    child_count: new_children.length(),
  }
  hot_revision_bump(func)
  removed
}

///|
pub fn hot_node_get(func : HotFunc, id : NodeId) -> HotNode {
  hot_mutate_require_live_node(func, id, "hot node_get")
  func.nodes[id]
}

///|
pub fn hot_node_set(func : HotFunc, id : NodeId, node : HotNode) -> Unit {
  hot_mutate_require_live_node(func, id, "hot node_set")
  hot_mutate_require_node_shape(func, node, "hot node_set")
  func.nodes[id] = node
  hot_revision_bump(func)
}

///|
pub fn hot_replace_node(
  func : HotFunc,
  id : NodeId,
  new_node : HotNode,
) -> Unit {
  hot_node_set(func, id, {
    ..new_node,
    flags: hot_default_flags_for_op(new_node.op),
  })
}

///|
pub fn hot_alloc_node(func : HotFunc, node : HotNode) -> NodeId {
  hot_mutate_require_node_shape(func, node, "hot alloc_node")
  let id = func.nodes.length()
  func.nodes.push(node)
  hot_revision_bump(func)
  id
}

///|
fn hot_mutate_assert_unreferenced(func : HotFunc, id : NodeId) -> Unit {
  for root in func.roots {
    if root == id {
      abort(
        "hot_delete_node requires the target node to be detached from roots",
      )
    }
  }
  for node_id = 0; node_id < func.nodes.length(); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) || node_id == id {
      continue
    }
    let node = func.nodes[node_id]
    for i = 0; i < node.child_count; i = i + 1 {
      if func.children[node.child_base + i] == id {
        abort(
          "hot_delete_node requires the target node to be detached from child spans",
        )
      }
    }
  }
}

///|
pub fn hot_delete_node(func : HotFunc, id : NodeId) -> Unit {
  hot_mutate_require_live_node(func, id, "hot_delete_node")
  hot_mutate_assert_unreferenced(func, id)
  func.nodes[id] = {
    op: HotOp::Nop,
    ty: hot_type_void(func),
    flags: hot_default_flags_for_op(HotOp::Nop),
    imm0: 0,
    imm1: 0,
    child_base: 0,
    child_count: 0,
  }
  func.free_nodes.push(id)
  hot_revision_bump(func)
}
