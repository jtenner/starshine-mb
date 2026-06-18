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
fn hot_mutate_require_label_id(
  func : HotFunc,
  label_id : LabelId,
  context : String,
) -> Unit {
  if label_id < 0 || label_id >= func.labels.length() {
    abort("\{context} must reference a valid LabelId")
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
fn hot_mutate_attach_child_span(
  func : HotFunc,
  node : HotNode,
  children : Array[NodeId],
  context : String,
) -> HotNode {
  hot_mutate_require_type_id(func, node.ty, context)
  if node.child_base != 0 || node.child_count != 0 {
    abort("\{context} requires a detached child span")
  }
  if children.length() == 0 {
    return node
  }
  let base = hot_alloc_child_span(func, children.length())
  hot_mutate_write_child_span(func, base, children)
  { ..node, child_base: base, child_count: children.length() }
}

///|
fn hot_mutate_attach_child1(
  func : HotFunc,
  node : HotNode,
  child0 : NodeId,
  context : String,
) -> HotNode {
  hot_mutate_require_type_id(func, node.ty, context)
  if node.child_base != 0 || node.child_count != 0 {
    abort("\{context} requires a detached child span")
  }
  hot_mutate_require_child_ref(func, child0)
  let base = hot_alloc_child_span(func, 1)
  func.children[base] = child0
  { ..node, child_base: base, child_count: 1 }
}

///|
fn hot_mutate_attach_child2(
  func : HotFunc,
  node : HotNode,
  child0 : NodeId,
  child1 : NodeId,
  context : String,
) -> HotNode {
  hot_mutate_require_type_id(func, node.ty, context)
  if node.child_base != 0 || node.child_count != 0 {
    abort("\{context} requires a detached child span")
  }
  hot_mutate_require_child_ref(func, child0)
  hot_mutate_require_child_ref(func, child1)
  let base = hot_alloc_child_span(func, 2)
  func.children[base] = child0
  func.children[base + 1] = child1
  { ..node, child_base: base, child_count: 2 }
}

///|
fn hot_mutate_attach_child3(
  func : HotFunc,
  node : HotNode,
  child0 : NodeId,
  child1 : NodeId,
  child2 : NodeId,
  context : String,
) -> HotNode {
  hot_mutate_require_type_id(func, node.ty, context)
  if node.child_base != 0 || node.child_count != 0 {
    abort("\{context} requires a detached child span")
  }
  hot_mutate_require_child_ref(func, child0)
  hot_mutate_require_child_ref(func, child1)
  hot_mutate_require_child_ref(func, child2)
  let base = hot_alloc_child_span(func, 3)
  func.children[base] = child0
  func.children[base + 1] = child1
  func.children[base + 2] = child2
  { ..node, child_base: base, child_count: 3 }
}

///|
pub fn hot_revision_bump(func : HotFunc) -> Unit {
  func.revision += 1
}

///|
pub fn hot_append_body_local(func : HotFunc, ty : ValType) -> LocalId {
  let local_id = hot_local_count(func)
  func.locals.locals.push(ty)
  hot_revision_bump(func)
  local_id
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
pub struct HotChildSpanRewrite {
  node_id : NodeId
  new_children : Array[NodeId]
} derive(Eq, Debug)

///|
pub fn HotChildSpanRewrite::new(
  node_id : NodeId,
  new_children : Array[NodeId],
) -> HotChildSpanRewrite {
  { node_id, new_children }
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
pub fn hot_control_result_type_set(
  func : HotFunc,
  control_id : NodeId,
  ty : TypeId,
) -> Unit {
  hot_mutate_require_live_node(func, control_id, "hot_control_result_type_set")
  hot_mutate_require_type_id(
    func, ty, "hot_control_result_type_set result type",
  )
  let node = hot_node_get(func, control_id)
  let label_id = hot_control_node_label(func, control_id)
  hot_mutate_require_label_id(
    func, label_id, "hot_control_result_type_set control label",
  )
  let result_arity = hot_type_result_arity(func, ty)
  func.nodes[control_id] = { ..node, ty, }
  let label = hot_label_get(func, label_id)
  let branch_arity = match node.op {
    HotOp::Loop => label.branch_arity
    _ => result_arity
  }
  func.labels[label_id] = { ..label, result_type: ty, branch_arity }
  for slot_info in hot_control_region_slot_info(node.op) {
    let holder = match slot_info.role {
      HotControlRegionRole::BodyRegion =>
        match node.op {
          HotOp::Block | HotOp::Loop => control_id
          _ =>
            if slot_info.slot >= node.child_count {
              HOT_NONE_NODE
            } else {
              hot_child_get(func, control_id, slot_info.slot)
            }
        }
      _ =>
        if slot_info.slot >= node.child_count {
          HOT_NONE_NODE
        } else {
          hot_child_get(func, control_id, slot_info.slot)
        }
    }
    if holder == HOT_NONE_NODE {
      continue
    }
    let region_label_id = hot_control_node_label(func, holder)
    hot_mutate_require_label_id(
      func, region_label_id, "hot_control_result_type_set region label",
    )
    let region_label = hot_label_get(func, region_label_id)
    func.labels[region_label_id] = {
      ..region_label,
      branch_arity: result_arity,
    }
  }
  hot_revision_bump(func)
}

///|
pub fn hot_replace_child_spans_and_control_result_type(
  func : HotFunc,
  control_id : NodeId,
  ty : TypeId,
  rewrites : Array[HotChildSpanRewrite],
) -> Unit {
  hot_mutate_require_live_node(
    func, control_id, "hot_replace_child_spans_and_control_result_type",
  )
  hot_mutate_require_type_id(
    func, ty, "hot_replace_child_spans_and_control_result_type result type",
  )
  for rewrite in rewrites {
    hot_mutate_require_live_node(
      func,
      rewrite.node_id,
      "hot_replace_child_spans_and_control_result_type child rewrite",
    )
    for child_id in rewrite.new_children {
      hot_mutate_require_child_ref(func, child_id)
    }
    let node = hot_node_get(func, rewrite.node_id)
    let base = hot_alloc_child_span(func, rewrite.new_children.length())
    hot_mutate_write_child_span(func, base, rewrite.new_children)
    func.nodes[rewrite.node_id] = {
      ..node,
      child_base: base,
      child_count: rewrite.new_children.length(),
    }
  }

  let node = hot_node_get(func, control_id)
  let label_id = hot_control_node_label(func, control_id)
  hot_mutate_require_label_id(
    func, label_id, "hot_replace_child_spans_and_control_result_type control label",
  )
  let result_arity = hot_type_result_arity(func, ty)
  func.nodes[control_id] = { ..node, ty, }
  let label = hot_label_get(func, label_id)
  let branch_arity = match node.op {
    HotOp::Loop => label.branch_arity
    _ => result_arity
  }
  func.labels[label_id] = { ..label, result_type: ty, branch_arity }
  for slot_info in hot_control_region_slot_info(node.op) {
    let holder = match slot_info.role {
      HotControlRegionRole::BodyRegion =>
        match node.op {
          HotOp::Block | HotOp::Loop => control_id
          _ =>
            if slot_info.slot >= node.child_count {
              HOT_NONE_NODE
            } else {
              hot_child_get(func, control_id, slot_info.slot)
            }
        }
      _ =>
        if slot_info.slot >= node.child_count {
          HOT_NONE_NODE
        } else {
          hot_child_get(func, control_id, slot_info.slot)
        }
    }
    if holder == HOT_NONE_NODE {
      continue
    }
    let region_label_id = hot_control_node_label(func, holder)
    hot_mutate_require_label_id(
      func, region_label_id, "hot_replace_child_spans_and_control_result_type region label",
    )
    let region_label = hot_label_get(func, region_label_id)
    func.labels[region_label_id] = {
      ..region_label,
      branch_arity: result_arity,
    }
  }
  hot_revision_bump(func)
}

///|
pub fn hot_control_demote_loop_to_block(
  func : HotFunc,
  loop_id : NodeId,
) -> Unit {
  hot_mutate_require_live_node(
    func, loop_id, "hot_control_demote_loop_to_block",
  )
  let node = hot_node_get(func, loop_id)
  if node.op != HotOp::Loop {
    abort("hot_control_demote_loop_to_block requires a loop node")
  }
  let label_id = hot_control_node_label(func, loop_id)
  hot_mutate_require_label_id(
    func, label_id, "hot_control_demote_loop_to_block loop label",
  )
  let label = hot_label_get(func, label_id)
  func.nodes[loop_id] = {
    ..node,
    op: HotOp::Block,
    flags: hot_default_flags_for_op(HotOp::Block),
  }
  func.labels[label_id] = { ..label, kind: HotLabelKind::BlockLabel }
  hot_revision_bump(func)
}

///|
pub fn hot_control_demote_if_to_block(
  func : HotFunc,
  if_id : NodeId,
  new_children : Array[NodeId],
) -> Unit {
  hot_mutate_require_live_node(func, if_id, "hot_control_demote_if_to_block")
  let node = hot_node_get(func, if_id)
  if node.op != HotOp::If {
    abort("hot_control_demote_if_to_block requires an if node")
  }
  let label_id = hot_control_node_label(func, if_id)
  hot_mutate_require_label_id(
    func, label_id, "hot_control_demote_if_to_block if label",
  )
  ignore(hot_replace_child_span(func, if_id, new_children))
  let next_node = hot_node_get(func, if_id)
  func.nodes[if_id] = {
    ..next_node,
    op: HotOp::Block,
    flags: hot_default_flags_for_op(HotOp::Block),
    imm0: label_id,
  }
  func.labels[label_id] = {
    kind: HotLabelKind::BlockLabel,
    owner: if_id,
    result_type: next_node.ty,
    branch_arity: hot_type_result_arity(func, next_node.ty),
  }
  hot_revision_bump(func)
}

///|
pub fn hot_tuple_make_promote_to_block(
  func : HotFunc,
  tuple_make_id : NodeId,
  block_type : BlockType,
) -> Unit {
  hot_mutate_require_live_node(
    func, tuple_make_id, "hot_tuple_make_promote_to_block",
  )
  let node = hot_node_get(func, tuple_make_id)
  if node.op != HotOp::TupleMake {
    abort("hot_tuple_make_promote_to_block requires a tuple.make node")
  }
  let results = hot_type_results(func, node.ty)
  if results.length() <= 1 {
    abort("hot_tuple_make_promote_to_block requires a multi-result tuple.make")
  }
  let ty = match block_type {
    TypeIdxBlockType(_) =>
      hot_type_intern_resolved_block_result(func, block_type, [], results)
    _ => hot_type_intern_block_result(func, block_type)
  }
  let label_id = hot_label_alloc(
    func,
    HotLabelKind::BlockLabel,
    ty,
    tuple_make_id,
    results.length(),
  )
  func.nodes[tuple_make_id] = {
    ..node,
    op: HotOp::Block,
    ty,
    flags: hot_default_flags_for_op(HotOp::Block),
    imm0: label_id,
    imm1: 0,
  }
  hot_revision_bump(func)
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
pub fn hot_label_owner_set(
  func : HotFunc,
  label_id : LabelId,
  owner : NodeId,
) -> Unit {
  hot_mutate_require_label_id(func, label_id, "hot label_owner_set label")
  hot_mutate_require_live_node(func, owner, "hot label_owner_set owner")
  let label = hot_label_get(func, label_id)
  func.labels[label_id] = { ..label, owner, }
  hot_revision_bump(func)
}

///|
pub fn hot_branch_target_set(
  func : HotFunc,
  node_id : NodeId,
  target : LabelId,
) -> Unit {
  hot_mutate_require_live_node(func, node_id, "hot branch_target_set node")
  hot_mutate_require_label_id(func, target, "hot branch_target_set target")
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Br
    | HotOp::BrIf
    | HotOp::BrOnNull
    | HotOp::BrOnNonNull
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail
    | HotOp::Delegate => {
      func.nodes[node_id] = { ..node, imm0: target }
      hot_revision_bump(func)
    }
    _ => abort("hot branch_target_set requires a single-target branch node")
  }
}

///|
pub fn hot_branch_table_set(
  func : HotFunc,
  node_id : NodeId,
  targets : Array[LabelId],
  default_target : LabelId,
) -> Unit {
  hot_mutate_require_live_node(func, node_id, "hot branch_table_set node")
  for target in targets {
    hot_mutate_require_label_id(func, target, "hot branch_table_set target")
  }
  hot_mutate_require_label_id(
    func, default_target, "hot branch_table_set default target",
  )
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::BrTable => {
      let table_id = hot_alloc_branch_table(
        func,
        HotBranchTable::new(targets, default_target),
      )
      func.nodes[node_id] = { ..node, imm0: table_id }
      hot_revision_bump(func)
    }
    _ => abort("hot branch_table_set requires a br_table node")
  }
}

///|
pub fn hot_legacy_try_catches_set(
  func : HotFunc,
  node_id : NodeId,
  catches : Array[HotCatchArm],
) -> Unit {
  hot_mutate_require_live_node(func, node_id, "hot legacy_try_catches_set node")
  for catch_ in catches {
    match catch_ {
      HotCatchArm::LegacyCatchArm(_, _) | HotCatchArm::LegacyCatchAllArm(_) =>
        ()
      _ => abort("hot legacy_try_catches_set requires legacy catch arms")
    }
  }
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Try => {
      let catch_id = hot_alloc_catch_info(func, HotCatchInfo::new(catches))
      func.nodes[node_id] = { ..node, imm1: catch_id }
      hot_revision_bump(func)
    }
    _ => abort("hot legacy_try_catches_set requires a try node")
  }
}

///|
pub fn hot_try_table_catches_set(
  func : HotFunc,
  node_id : NodeId,
  catches : Array[HotCatchArm],
) -> Unit {
  hot_mutate_require_live_node(func, node_id, "hot try_table_catches_set node")
  for catch_ in catches {
    let label_id = match catch_ {
      HotCatchArm::CatchArm(_, label_id)
      | HotCatchArm::CatchRefArm(_, label_id)
      | HotCatchArm::CatchAllArm(label_id)
      | HotCatchArm::CatchAllRefArm(label_id) => label_id
      HotCatchArm::LegacyCatchArm(_, _) | HotCatchArm::LegacyCatchAllArm(_) =>
        abort("hot try_table_catches_set requires try_table catch arms")
    }
    hot_mutate_require_label_id(
      func, label_id, "hot try_table_catches_set catch target",
    )
  }
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::TryTable => {
      let catch_id = hot_alloc_catch_info(func, HotCatchInfo::new(catches))
      func.nodes[node_id] = { ..node, imm1: catch_id }
      hot_revision_bump(func)
    }
    _ => abort("hot try_table_catches_set requires a try_table node")
  }
}

///|
pub fn hot_node_exact_instr_set(
  func : HotFunc,
  id : NodeId,
  instr : Instruction,
) -> Unit {
  hot_mutate_require_live_node(func, id, "hot node_exact_instr_set")
  let node = hot_node_get(func, id)
  match hot_node_exact_instr_payload_id(func, id) {
    Some(_) => {
      let payload_id = hot_alloc_instr_payload(
        func,
        HotInstrPayload::new(instr),
      )
      let next_node = match node.op {
        HotOp::Load
        | HotOp::Store
        | HotOp::RefTest
        | HotOp::RefCast
        | HotOp::RefTestDesc
        | HotOp::RefCastDescEq
        | HotOp::BrOnCast
        | HotOp::BrOnCastFail
        | HotOp::Atomic => { ..node, imm1: payload_id }
        _ => { ..node, imm0: payload_id }
      }
      func.nodes[id] = next_node
      hot_revision_bump(func)
    }
    None => abort("hot node_exact_instr_set requires an exact-instruction node")
  }
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
  func.deleted_nodes.push(false)
  hot_revision_bump(func)
  id
}

///|
fn hot_alloc_node_with_children(
  func : HotFunc,
  node : HotNode,
  children : Array[NodeId],
) -> NodeId {
  hot_alloc_node(
    func,
    hot_mutate_attach_child_span(
      func, node, children, "hot alloc_node_with_children",
    ),
  )
}

///|
fn hot_alloc_node_with_child1(
  func : HotFunc,
  node : HotNode,
  child0 : NodeId,
) -> NodeId {
  hot_alloc_node(
    func,
    hot_mutate_attach_child1(func, node, child0, "hot alloc_node_with_child1"),
  )
}

///|
fn hot_alloc_node_with_child2(
  func : HotFunc,
  node : HotNode,
  child0 : NodeId,
  child1 : NodeId,
) -> NodeId {
  hot_alloc_node(
    func,
    hot_mutate_attach_child2(
      func, node, child0, child1, "hot alloc_node_with_child2",
    ),
  )
}

///|
fn hot_alloc_node_with_child3(
  func : HotFunc,
  node : HotNode,
  child0 : NodeId,
  child1 : NodeId,
  child2 : NodeId,
) -> NodeId {
  hot_alloc_node(
    func,
    hot_mutate_attach_child3(
      func, node, child0, child1, child2, "hot alloc_node_with_child3",
    ),
  )
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
fn hot_delete_node_finalize(func : HotFunc, id : NodeId) -> Unit {
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
  if id < func.deleted_nodes.length() {
    func.deleted_nodes[id] = true
  }
  hot_revision_bump(func)
}

///|
pub fn hot_delete_detached_node(func : HotFunc, id : NodeId) -> Unit {
  hot_mutate_require_live_node(func, id, "hot_delete_detached_node")
  hot_delete_node_finalize(func, id)
}

///|
pub fn hot_delete_node(func : HotFunc, id : NodeId) -> Unit {
  hot_mutate_require_live_node(func, id, "hot_delete_node")
  hot_mutate_assert_unreferenced(func, id)
  hot_delete_node_finalize(func, id)
}
