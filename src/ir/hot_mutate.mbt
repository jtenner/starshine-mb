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
  if !hot_label_is_live(func, label_id) {
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
priv struct HotCatchPayloadLaneRepair {
  payload_id : NodeId
  parent_id : NodeId
  parent_slot : Int
  val_type : ValType
}

///|
priv struct HotCatchPayloadRepair {
  catch_ref : HotRegionRef
  lanes : Array[HotCatchPayloadLaneRepair]
}

///|
fn hot_catch_payload_site_matches(
  site : HotUseSite,
  user : NodeId,
  slot : Int,
  kind : HotUseSlotKind,
) -> Bool {
  site.user == user && site.slot == slot && site.kind == kind
}

///|
fn hot_catch_payload_lane_repair(
  func : HotFunc,
  use_def : HotUseDef,
  catch_ref : HotRegionRef,
  entry_slot : Int,
  payload_id : NodeId,
  root_id : NodeId,
  root_user : NodeId,
  root_slot : Int,
) -> HotCatchPayloadLaneRepair? {
  let payload = hot_node_get(func, payload_id)
  let payload_types = hot_type_results(func, payload.ty)
  if payload.op != HotOp::Catch ||
    payload.child_count != 0 ||
    payload_types.length() != 1 {
    return None
  }

  let mut current = root_id
  let mut expected_user = root_user
  let mut expected_slot = root_slot
  let mut expected_kind = HotUseSlotKind::RootUseSlot
  let mut parent_id = HOT_NONE_NODE
  let mut parent_slot = -1
  while current != payload_id {
    if current < 0 || !hot_node_is_live(func, current) {
      return None
    }
    let sites = node_use_sites_borrowed(use_def, current)
    if sites.length() != 1 ||
      !hot_catch_payload_site_matches(
        sites[0],
        expected_user,
        expected_slot,
        expected_kind,
      ) {
      return None
    }
    let node = hot_node_get(func, current)
    match node.op {
      HotOp::Block => {
        let body_ref = hot_region_body_ref(func, current)
        if hot_region_root_count(func, body_ref) == 0 {
          return None
        }
        expected_user = current
        expected_slot = 0
        expected_kind = HotUseSlotKind::RootUseSlot
        current = hot_region_get(func, body_ref, 0)
      }
      HotOp::If => {
        parent_id = current
        parent_slot = 0
        expected_user = current
        expected_slot = 0
        expected_kind = HotUseSlotKind::ChildUseSlot
        current = hot_child_get(func, current, 0)
      }
      HotOp::Loop | HotOp::Try | HotOp::TryTable => return None
      _ => {
        if node.child_count == 0 {
          return None
        }
        parent_id = current
        parent_slot = 0
        expected_user = current
        expected_slot = 0
        expected_kind = HotUseSlotKind::ChildUseSlot
        current = hot_child_get(func, current, 0)
      }
    }
  }
  if parent_id == HOT_NONE_NODE {
    return None
  }

  let payload_sites = node_use_sites_borrowed(use_def, payload_id)
  if payload_sites.length() != 2 {
    return None
  }
  let mut saw_entry = false
  let mut saw_nested = false
  for site in payload_sites {
    if hot_catch_payload_site_matches(
        site,
        catch_ref.holder,
        entry_slot,
        HotUseSlotKind::RootUseSlot,
      ) {
      saw_entry = true
    } else if hot_catch_payload_site_matches(
        site, expected_user, expected_slot, expected_kind,
      ) {
      saw_nested = true
    } else {
      return None
    }
  }
  if !saw_entry || !saw_nested {
    return None
  }
  Some({ payload_id, parent_id, parent_slot, val_type: payload_types[0] })
}

///|
fn hot_scalar_catch_payload_first_descendant_repair(
  func : HotFunc,
  use_def : HotUseDef,
  catch_ref : HotRegionRef,
  payload_id : NodeId,
) -> HotCatchPayloadLaneRepair? {
  if hot_region_root_count(func, catch_ref) < 2 ||
    hot_region_get(func, catch_ref, 0) != payload_id {
    return None
  }
  hot_catch_payload_lane_repair(
    func,
    use_def,
    catch_ref,
    0,
    payload_id,
    hot_region_get(func, catch_ref, 1),
    catch_ref.holder,
    1,
  )
}

///|
fn hot_ordered_catch_payload_repair(
  func : HotFunc,
  use_def : HotUseDef,
  catch_ref : HotRegionRef,
  payloads : Array[NodeId],
) -> HotCatchPayloadRepair? {
  let catch_root_count = hot_region_root_count(func, catch_ref)
  if payloads.length() < 2 || catch_root_count < payloads.length() + 1 {
    return None
  }
  let first_tag = hot_node_get(func, payloads[0]).imm0
  for slot = 0; slot < payloads.length(); slot = slot + 1 {
    let payload_id = payloads[slot]
    let payload = hot_node_get(func, payload_id)
    if hot_region_get(func, catch_ref, slot) != payload_id ||
      payload.op != HotOp::Catch ||
      payload.imm0 != first_tag {
      return None
    }
  }

  let mut final_ref = catch_ref
  let mut final_start_slot = payloads.length()
  if catch_root_count == payloads.length() + 1 {
    let mut current = hot_region_get(func, catch_ref, payloads.length())
    let mut expected_user = catch_ref.holder
    let mut expected_slot = payloads.length()
    while true {
      if current < 0 || !hot_node_is_live(func, current) {
        return None
      }
      let sites = node_use_sites_borrowed(use_def, current)
      if sites.length() != 1 ||
        !hot_catch_payload_site_matches(
          sites[0],
          expected_user,
          expected_slot,
          HotUseSlotKind::RootUseSlot,
        ) {
        return None
      }
      if hot_node_get(func, current).op != HotOp::Block {
        return None
      }
      let body_ref = hot_region_body_ref(func, current)
      let root_count = hot_region_root_count(func, body_ref)
      if root_count == 0 {
        return None
      }
      let first_root = hot_region_get(func, body_ref, 0)
      if root_count == 1 && hot_node_get(func, first_root).op == HotOp::Block {
        expected_user = current
        expected_slot = 0
        current = first_root
        continue
      }
      if root_count < payloads.length() {
        return None
      }
      final_ref = body_ref
      final_start_slot = 0
      break
    }
  } else if catch_root_count < payloads.length() * 2 {
    return None
  }

  let lanes : Array[HotCatchPayloadLaneRepair] = []
  for slot = 0; slot < payloads.length(); slot = slot + 1 {
    let root_slot = final_start_slot + slot
    let lane = match
      hot_catch_payload_lane_repair(
        func,
        use_def,
        catch_ref,
        slot,
        payloads[slot],
        hot_region_get(func, final_ref, root_slot),
        final_ref.holder,
        root_slot,
      ) {
      Some(plan) => plan
      None => return None
    }
    lanes.push(lane)
  }
  Some({ catch_ref, lanes })
}

///|
fn hot_catch_payload_repair_plan(
  func : HotFunc,
  max_lanes : Int,
) -> Array[HotCatchPayloadRepair]? {
  let use_def = use_def_build_node_uses(func)
  let plans : Array[HotCatchPayloadRepair] = []
  let mut payload_count = 0
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    match hot_node_get(func, node_id).op {
      HotOp::Catch => payload_count += 1
      HotOp::CatchAll => return None
      _ => ()
    }
  }
  let mut planned_payloads = 0
  for try_id = 0; try_id < hot_node_count(func); try_id = try_id + 1 {
    if !hot_node_is_live(func, try_id) ||
      hot_node_get(func, try_id).op != HotOp::Try {
      continue
    }
    let catch_ref = match hot_region_catch_ref(func, try_id) {
      Some(catch_ref) => catch_ref
      None => continue
    }
    let root_count = hot_region_root_count(func, catch_ref)
    let mut lane_count = 0
    while lane_count < root_count &&
          hot_node_get(func, hot_region_get(func, catch_ref, lane_count)).op ==
          HotOp::Catch {
      lane_count += 1
    }
    if lane_count == 0 {
      continue
    }
    if max_lanes >= 0 && lane_count > max_lanes {
      return None
    }
    if lane_count == 1 {
      let payload_id = hot_region_get(func, catch_ref, 0)
      let lane = match
        hot_scalar_catch_payload_first_descendant_repair(
          func, use_def, catch_ref, payload_id,
        ) {
        Some(lane) => lane
        None => return None
      }
      plans.push({ catch_ref, lanes: [lane] })
      planned_payloads += 1
    } else {
      let payloads : Array[NodeId] = []
      for slot = 0; slot < lane_count; slot = slot + 1 {
        payloads.push(hot_region_get(func, catch_ref, slot))
      }
      let plan = match
        hot_ordered_catch_payload_repair(func, use_def, catch_ref, payloads) {
        Some(plan) => plan
        None => return None
      }
      plans.push(plan)
      planned_payloads += lane_count
    }
  }
  if planned_payloads != payload_count {
    return None
  }
  Some(plans)
}

///|
fn hot_repair_catch_payloads(func : HotFunc, max_lanes : Int) -> Bool {
  let plans = match hot_catch_payload_repair_plan(func, max_lanes) {
    Some(plans) => plans
    None => return false
  }
  if plans.is_empty() {
    return false
  }
  for plan in plans {
    let captures : Array[NodeId] = []
    for lane in plan.lanes {
      let local_id = hot_append_body_local(func, lane.val_type)
      captures.push(hot_build_local_set(func, local_id, lane.payload_id))
      let replacement = hot_build_local_get(func, local_id)
      hot_child_set(func, lane.parent_id, lane.parent_slot, replacement)
    }
    let stack_ordered_captures : Array[NodeId] = []
    for idx = captures.length() - 1; idx >= 0; idx = idx - 1 {
      stack_ordered_captures.push(captures[idx])
    }
    hot_region_insert(
      func,
      plan.catch_ref,
      plan.lanes.length(),
      stack_ordered_captures,
    )
  }
  true
}

///|
/// Report whether every typed legacy catch payload in the function can be
/// captured exactly once on its catch region's first-descendant line.
pub fn hot_scalar_catch_payloads_repairable(func : HotFunc) -> Bool {
  hot_catch_payload_repair_plan(func, 1) is Some(_)
}

///|
/// Capture every repairable scalar legacy catch payload into a typed local at
/// catch entry and replace its exact nested first-descendant use. The complete
/// function is preflighted before any local, node, root, child, or revision
/// mutation; unsupported multiple payloads, nested catches, loops, sharing, or
/// outside uses leave the function unchanged.
pub fn hot_repair_scalar_catch_payloads(func : HotFunc) -> Bool {
  hot_repair_catch_payloads(func, 1)
}

///|
/// Report whether every typed legacy catch payload is either the exact scalar
/// first-descendant family or one ordered same-tag lane vector under an
/// exclusive direct block chain. Catch-all markers, loops, nested catches,
/// sharing, outside uses, or any partial lane reject the complete function.
pub fn hot_ordered_catch_payloads_repairable(func : HotFunc) -> Bool {
  hot_catch_payload_repair_plan(func, -1) is Some(_)
}

///|
/// Capture exact scalar or ordered same-tag legacy catch payloads atomically.
/// Lane locals retain source order; entry captures consume the handler stack in
/// reverse lane order before exact old-position reads replace every payload use.
pub fn hot_repair_ordered_catch_payloads(func : HotFunc) -> Bool {
  hot_repair_catch_payloads(func, -1)
}

///|
pub fn hot_set_body_local_type(
  func : HotFunc,
  local_id : LocalId,
  ty : ValType,
) -> Bool {
  let body_local_id = local_id - hot_param_count(func)
  if body_local_id < 0 || body_local_id >= func.locals.locals.length() {
    return false
  }
  if func.locals.locals[body_local_id] == ty {
    return false
  }
  func.locals.locals[body_local_id] = ty
  hot_revision_bump(func)
  true
}

///|
pub fn hot_weaken_body_local_to_nullable_ref(
  func : HotFunc,
  local_id : LocalId,
) -> Bool {
  let current = match hot_local_type(func, local_id) {
    Some(ty) => ty
    None => return false
  }
  let ref_type = match current {
    RefTypeValType(rt) if rt.is_non_nullable() => rt
    _ => return false
  }
  hot_set_body_local_type(
    func,
    local_id,
    ValType::ref_type(
      RefType::new(true, ref_type.get_heap_type(), exact=ref_type.is_exact()),
    ),
  )
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
pub fn hot_loop_entry_values_clear(
  func : HotFunc,
  loop_id : NodeId,
) -> Array[NodeId] {
  hot_mutate_require_live_node(func, loop_id, "hot_loop_entry_values_clear")
  let loop_node = hot_node_get(func, loop_id)
  if loop_node.op != HotOp::Loop {
    abort("hot_loop_entry_values_clear requires a loop node")
  }
  let label_id = hot_control_node_label(func, loop_id)
  hot_mutate_require_label_id(
    func, label_id, "hot_loop_entry_values_clear loop label",
  )
  let label = hot_label_get(func, label_id)
  let input_count = label.branch_arity
  if input_count < 0 || input_count > loop_node.child_count {
    abort("hot_loop_entry_values_clear requires a valid loop input prefix")
  }
  let removed : Array[NodeId] = []
  let body : Array[NodeId] = []
  for slot = 0; slot < loop_node.child_count; slot = slot + 1 {
    let child_id = hot_child_get(func, loop_id, slot)
    if slot < input_count {
      removed.push(child_id)
    } else {
      body.push(child_id)
    }
  }
  ignore(hot_replace_child_span(func, loop_id, body))
  func.labels[label_id] = { ..label, branch_arity: 0 }
  hot_revision_bump(func)
  removed
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
pub fn hot_node_promote_to_block(
  func : HotFunc,
  node_id : NodeId,
  block_type : BlockType,
  new_children : Array[NodeId],
) -> Unit {
  hot_mutate_require_live_node(func, node_id, "hot_node_promote_to_block")
  let ty = hot_type_intern_block_result(func, block_type)
  ignore(hot_replace_child_span(func, node_id, new_children))
  let label_id = hot_label_alloc(
    func,
    HotLabelKind::BlockLabel,
    ty,
    node_id,
    hot_type_result_arity(func, ty),
  )
  let node = hot_node_get(func, node_id)
  func.nodes[node_id] = {
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
fn hot_delete_node_tombstone(func : HotFunc, id : NodeId) -> Unit {
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
}

///|
fn hot_delete_node_finalize(func : HotFunc, id : NodeId) -> Unit {
  hot_delete_node_tombstone(func, id)
  hot_revision_bump(func)
}

///|
fn hot_mutate_node_targets_marked_label(
  func : HotFunc,
  node_id : NodeId,
  label_marks : @bitset.BitSet,
) -> Bool {
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Br
    | HotOp::BrIf
    | HotOp::BrOnNull
    | HotOp::BrOnNonNull
    | HotOp::BrOnCast
    | HotOp::BrOnCastFail
    | HotOp::Delegate =>
      node.imm0 >= 0 &&
      node.imm0 < func.labels.length() &&
      label_marks[node.imm0]
    HotOp::BrTable => {
      let table_id = node.imm0
      let default_target = hot_branch_table_default_target(func, table_id)
      if default_target >= 0 &&
        default_target < func.labels.length() &&
        label_marks[default_target] {
        return true
      }
      for target in hot_branch_table_targets(func, table_id) {
        if target >= 0 && target < func.labels.length() && label_marks[target] {
          return true
        }
      }
      false
    }
    HotOp::TryTable => {
      for catch_arm in hot_catch_info_get(func, node.imm1).catches {
        let target = match catch_arm {
          HotCatchArm::CatchArm(_, label_id)
          | HotCatchArm::CatchRefArm(_, label_id)
          | HotCatchArm::CatchAllArm(label_id)
          | HotCatchArm::CatchAllRefArm(label_id) => label_id
        }
        if target >= 0 && target < func.labels.length() && label_marks[target] {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn hot_mutate_node_is_control(node : HotNode) -> Bool {
  match node.op {
    HotOp::Block | HotOp::Loop | HotOp::If | HotOp::Try | HotOp::TryTable =>
      true
    _ => false
  }
}

///|
/// Delete an exact detached forest and all labels its controls own.
///
/// The operation fails without mutation when the roots are empty, duplicate,
/// or overlapping; when any descendant graph is shared or cyclic; when any node
/// is still rooted or owned by another live node; when control-label ownership
/// is incomplete; or when any outside branch/catch targets an owned label.
pub fn hot_delete_detached_forest(
  func : HotFunc,
  root_ids : Array[NodeId],
) -> Bool {
  if root_ids.is_empty() {
    return false
  }
  let node_count = hot_node_count(func)
  let root_marks = @bitset.BitSet::new(node_count)
  let node_marks = @bitset.BitSet::new(node_count)
  let nodes : Array[NodeId] = []
  let pending : Array[NodeId] = []
  for root_id in root_ids {
    if root_id < 0 ||
      root_id >= node_count ||
      root_marks[root_id] ||
      !hot_node_is_live(func, root_id) {
      return false
    }
    root_marks[root_id] = true
    pending.push(root_id)
  }
  while !pending.is_empty() {
    let node_id = pending.pop().unwrap()
    if !hot_node_is_live(func, node_id) {
      return false
    }
    if node_marks[node_id] {
      continue
    }
    node_marks[node_id] = true
    nodes.push(node_id)
    let node = hot_node_get(func, node_id)
    for slot = 0; slot < node.child_count; slot = slot + 1 {
      let child_id = hot_child_get(func, node_id, slot)
      if child_id != HOT_NONE_NODE {
        pending.push(child_id)
      }
    }
  }

  let incoming = Array::make(node_count, 0)
  for node_id in nodes {
    let node = hot_node_get(func, node_id)
    for slot = 0; slot < node.child_count; slot = slot + 1 {
      let child_id = hot_child_get(func, node_id, slot)
      if child_id == HOT_NONE_NODE || !node_marks[child_id] {
        continue
      }
      incoming[child_id] = incoming[child_id] + 1
      if incoming[child_id] > 1 {
        return false
      }
    }
  }
  for root_id in root_ids {
    if incoming[root_id] != 0 {
      return false
    }
  }
  for node_id in nodes {
    if !root_marks[node_id] && incoming[node_id] != 1 {
      return false
    }
  }
  for root in func.roots {
    if node_marks[root] {
      return false
    }
  }
  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) || node_marks[node_id] {
      continue
    }
    let node = hot_node_get(func, node_id)
    for slot = 0; slot < node.child_count; slot = slot + 1 {
      let child_id = hot_child_get(func, node_id, slot)
      if child_id != HOT_NONE_NODE && node_marks[child_id] {
        return false
      }
    }
  }

  let label_marks = @bitset.BitSet::new(func.labels.length())
  let labels : Array[LabelId] = []
  for label_id = 0; label_id < func.labels.length(); label_id = label_id + 1 {
    if !hot_label_is_live(func, label_id) {
      continue
    }
    let owner = hot_label_owner(func, label_id)
    if owner >= 0 && owner < node_count && node_marks[owner] {
      label_marks[label_id] = true
      labels.push(label_id)
    }
  }
  for node_id in nodes {
    let node = hot_node_get(func, node_id)
    if !hot_mutate_node_is_control(node) {
      continue
    }
    let label_id = hot_control_node_label(func, node_id)
    if !hot_label_is_live(func, label_id) ||
      !label_marks[label_id] ||
      hot_label_owner(func, label_id) != node_id {
      return false
    }
  }
  for label_id in labels {
    let owner = hot_label_owner(func, label_id)
    if !hot_mutate_node_is_control(hot_node_get(func, owner)) ||
      hot_control_node_label(func, owner) != label_id {
      return false
    }
  }
  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    if hot_node_is_live(func, node_id) &&
      !node_marks[node_id] &&
      hot_mutate_node_targets_marked_label(func, node_id, label_marks) {
      return false
    }
  }

  for label_id in labels {
    let label = hot_label_get(func, label_id)
    func.labels[label_id] = { ..label, owner: HOT_NONE_NODE, branch_arity: 0 }
  }
  for node_id in nodes {
    hot_delete_node_tombstone(func, node_id)
  }
  hot_revision_bump(func)
  true
}

///|
/// Delete exact detached structured trees and all labels they own.
pub fn hot_delete_detached_control_forest(
  func : HotFunc,
  root_ids : Array[NodeId],
) -> Bool {
  if root_ids.is_empty() {
    return false
  }
  let node_count = hot_node_count(func)
  for root_id in root_ids {
    if root_id < 0 ||
      root_id >= node_count ||
      !hot_node_is_live(func, root_id) ||
      !hot_mutate_node_is_control(hot_node_get(func, root_id)) {
      return false
    }
  }
  hot_delete_detached_forest(func, root_ids)
}

///|
/// Delete one exact detached structured subtree and all labels it owns.
pub fn hot_delete_detached_control_subtree(
  func : HotFunc,
  root_id : NodeId,
) -> Bool {
  hot_delete_detached_control_forest(func, [root_id])
}

///|
pub fn hot_delete_detached_node(func : HotFunc, id : NodeId) -> Unit {
  hot_mutate_require_live_node(func, id, "hot_delete_detached_node")
  hot_delete_node_finalize(func, id)
}

///|
/// Delete an exact distinct detached node set with one revision invalidation.
pub fn hot_delete_detached_nodes(
  func : HotFunc,
  node_ids : Array[NodeId],
) -> Unit {
  let seen = @bitset.BitSet::new(hot_node_count(func))
  for node_id in node_ids {
    hot_mutate_require_live_node(func, node_id, "hot_delete_detached_nodes")
    if seen[node_id] {
      abort("hot_delete_detached_nodes requires distinct node ids")
    }
    seen[node_id] = true
  }
  if node_ids.is_empty() {
    return
  }
  for node_id in node_ids {
    hot_delete_node_tombstone(func, node_id)
  }
  hot_revision_bump(func)
}

///|
pub fn hot_delete_node(func : HotFunc, id : NodeId) -> Unit {
  hot_mutate_require_live_node(func, id, "hot_delete_node")
  hot_mutate_assert_unreferenced(func, id)
  hot_delete_node_finalize(func, id)
}
