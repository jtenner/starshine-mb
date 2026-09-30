///|
/// Source-order facts shared by lowering and the operand-expanded CFG.
/// Cached local-access summaries are populated on demand.
priv struct HotSourceOrderFacts {
  local_access_cache : Array[Int]
  value_orders : Array[Int]
  node_effects : Array[EffectMask]
  first_effect_orders : Array[Int]
  preceding_dependency_min_cache : Array[Int]
  local_access_nodes : Array[Array[NodeId]?]
  first_local_access_orders : @hashmap.HashMap[
    NodeId,
    @hashmap.HashMap[Int, Int],
  ]
  local_access_seen : Array[Int]
  mut local_access_stamp : Int
  mut dependency_scratch : HotSourceOrderScratch?
}

///|
priv struct HotSourceOrderScratch {
  seen_consumer : Array[Int]
  consumer_bounds : Array[Int]
  anti_dependencies : @bitset.BitSet
  touched : Array[NodeId]
  carried : Array[NodeId]
}

///|
fn HotSourceOrderScratch::new(count : Int) -> HotSourceOrderScratch {
  {
    seen_consumer: Array::make(count, count),
    consumer_bounds: Array::make(count, -1),
    anti_dependencies: @bitset.BitSet::new(count),
    touched: [],
    carried: [],
  }
}

///|
#valtype
priv struct HotSourceOrderOrders {
  value_orders : Array[Int]
  first_effect_orders : Array[Int]
  own_effects : Array[EffectMask]
}

///|
fn HotSourceOrderOrders::new(func : HotFunc) -> HotSourceOrderOrders {
  let none = hot_node_count(func)
  let value_orders = Array::make(none, -1)
  let first_effect_orders = Array::make(none, -1)
  let own_effects = Array::make(none, 0U)
  fn visit(node_id : NodeId) -> Unit {
    if node_id < 0 ||
      !hot_node_is_live(func, node_id) ||
      value_orders[node_id] >= 0 {
      return
    }
    let node = hot_node_get(func, node_id)
    value_orders[node_id] = node.order
    let own_mask = effects_mask_for_flags(node.flags) |
      effects_mask_for_node_exact(func, node_id)
    own_effects[node_id] = own_mask
    first_effect_orders[node_id] = if hot_lower_impl_has_external_effects(
        own_mask,
      ) {
      node.order
    } else {
      none
    }
    // Both summaries use the same operand edges and discovery order. Publish
    // both initial values before recursion, preserving shared/cyclic visits.
    for input_id in hot_lower_impl_input_info(func, node_id).nodes {
      if input_id < 0 || !hot_node_is_live(func, input_id) {
        continue
      }
      visit(input_id)
      value_orders[node_id] = value_orders[node_id].max(value_orders[input_id])
      first_effect_orders[node_id] = first_effect_orders[node_id].min(
        first_effect_orders[input_id],
      )
    }
  }
  for node_id in 0..<none {
    visit(node_id)
  }
  { value_orders, first_effect_orders, own_effects, }
}

///|
fn HotSourceOrderFacts::new(func : HotFunc) -> HotSourceOrderFacts {
  let orders = HotSourceOrderOrders::new(func)
  {
    local_access_cache: Array::make(hot_node_count(func), -1),
    value_orders: orders.value_orders,
    // The operand-order walk already computed each node's own mask. Compose
    // all live child edges into that owned buffer without rereading payloads.
    node_effects: effects_build_node_masks(
      func,
      own_masks=Some(orders.own_effects),
    ),
    first_effect_orders: orders.first_effect_orders,
    preceding_dependency_min_cache: Array::make(hot_node_count(func), -2),
    local_access_nodes: Array::make(hot_node_count(func), None),
    first_local_access_orders: @hashmap.new(),
    local_access_seen: Array::make(hot_node_count(func), 0),
    local_access_stamp: 0,
    dependency_scratch: None,
  }
}

///|
fn hot_source_order_local_access_nodes(
  func : HotFunc,
  node_id : NodeId,
  facts : HotSourceOrderFacts,
) -> Array[NodeId] {
  if facts.local_access_nodes[node_id] is Some(nodes) {
    return nodes
  }
  facts.local_access_stamp += 1
  let stamp = facts.local_access_stamp
  let accesses : Array[NodeId] = []
  fn visit(id : NodeId) -> Unit {
    if id < 0 ||
      facts.local_access_seen[id] == stamp ||
      !hot_node_is_live(func, id) {
      return
    }
    facts.local_access_seen[id] = stamp
    match hot_node_get(func, id).op {
      HotOp::LocalGet | HotOp::LocalSet | HotOp::LocalTee => accesses.push(id)
      _ => ()
    }
    let count = hot_lower_impl_local_state_child_count(func, id)
    for slot = 0; slot < count; slot = slot + 1 {
      visit(hot_child_get(func, id, slot))
    }
  }
  visit(node_id)
  facts.local_access_nodes[node_id] = Some(accesses)
  accesses
}

///|
fn hot_source_order_first_local_access_orders(
  func : HotFunc,
  node_id : NodeId,
  accesses : Array[NodeId],
  facts : HotSourceOrderFacts,
  visits? : Array[Int]? = None,
) -> @hashmap.HashMap[Int, Int] {
  if facts.first_local_access_orders.get(node_id) is Some(orders) {
    return orders
  }
  let orders : @hashmap.HashMap[Int, Int] = @hashmap.new()
  for access_id in accesses {
    match visits {
      Some(count) => count[0] += 1
      None => ()
    }
    let access = hot_node_get(func, access_id)
    let previous = orders.get(access.imm0).or(hot_node_count(func))
    if access.order < previous {
      orders.set(access.imm0, access.order)
    }
  }
  facts.first_local_access_orders.set(node_id, orders)
  orders
}

///|
fn hot_source_order_preceding_dependencies(
  func : HotFunc,
  current_root : NodeId,
  future_roots : Array[NodeId],
  future_start : Int,
  future_dependency_suffix_minima : HotSourceOrderRootIndex?,
  facts : HotSourceOrderFacts,
  scratch_builds? : Array[Int]? = None,
  root_visits? : Array[Int]? = None,
  carried_builds? : Array[Int]? = None,
) -> Array[NodeId] {
  // Extracting an existing value into a new statement preserves its execution
  // order. Its allocation ID can be newer than the consumer of an older read.
  let source_order = hot_node_get(func, current_root).order
  let current_order = if source_order < current_root {
    source_order
  } else {
    current_root
  }
  let call_order_required = hot_node_result_arity(func, current_root) == 0 &&
    (match hot_query_op(func, current_root) {
      HotOp::Call | HotOp::CallIndirect | HotOp::CallRef => true
      _ => false
    })
  let effect_order_required = hot_lower_impl_has_external_effects(
    facts.node_effects[current_root],
  )
  if !call_order_required &&
    !effect_order_required &&
    !hot_lower_impl_node_accesses_local(
      func,
      current_root,
      facts.local_access_cache,
    ) {
    return []
  }
  match future_dependency_suffix_minima {
    Some(index) =>
      if future_start < 0 ||
        future_start >= index.suffix_minima.length() ||
        index.suffix_minima[future_start] >= current_order {
        return []
      }
    None => ()
  }
  let candidates = match future_dependency_suffix_minima {
    Some(index) if index.maximum >= current_order =>
      Some(index.candidates(future_start, current_order))
    _ => None
  }
  let candidate_count = match candidates {
    Some(slots) => slots.length()
    None => future_roots.length() - future_start
  }
  if candidate_count <= 0 {
    return []
  }
  let scratch = match facts.dependency_scratch {
    Some(scratch) => scratch
    None => {
      match scratch_builds {
        Some(count) => count[0] += 1
        None => ()
      }
      match carried_builds {
        Some(count) => count[0] += 1
        None => ()
      }
      let scratch = HotSourceOrderScratch::new(hot_node_count(func))
      facts.dependency_scratch = Some(scratch)
      scratch
    }
  }
  let seen_consumer = scratch.seen_consumer
  let consumer_bounds = scratch.consumer_bounds
  let carried = scratch.carried
  let minimum_cache = Some(facts.preceding_dependency_min_cache)
  // A newly inserted computation follows region order. A wrapper extracted
  // from an old value retains that value's order even with a new allocation ID.
  // Infer anti-dependence within the preserved value/current/consumer interval.
  for position = 0; position < candidate_count; position = position + 1 {
    let idx = match candidates {
      Some(slots) => slots[position]
      None => future_start + position
    }
    if future_roots[idx] > current_order {
      match root_visits {
        Some(count) => count[0] += 1
        None => ()
      }
      hot_lower_impl_collect_preceding_dependency_indexed(
        func,
        future_roots[idx],
        current_order,
        future_roots[idx],
        facts.value_orders,
        facts.node_effects,
        seen_consumer,
        consumer_bounds,
        scratch.touched,
        carried,
        minimum_cache,
        None,
      )
    }
  }
  let anti_dependencies = scratch.anti_dependencies
  for node_id in carried {
    anti_dependencies[node_id] = true
  }
  for position = 0; position < candidate_count; position = position + 1 {
    let idx = match candidates {
      Some(slots) => slots[position]
      None => future_start + position
    }
    if future_roots[idx] <= current_order {
      match root_visits {
        Some(count) => count[0] += 1
        None => ()
      }
      hot_lower_impl_collect_preceding_dependency_indexed(
        func,
        future_roots[idx],
        current_order,
        future_roots[idx],
        facts.value_orders,
        facts.node_effects,
        seen_consumer,
        consumer_bounds,
        scratch.touched,
        carried,
        minimum_cache,
        None,
      )
    }
  }
  carried.sort_by(fn(left, right) {
    facts.value_orders[left].compare(facts.value_orders[right])
  })
  let selected : Array[NodeId] = []
  for node_id in carried {
    if (
        anti_dependencies[node_id] &&
        facts.value_orders[node_id] < facts.first_effect_orders[current_root] &&
        (
          call_order_required ||
          (
            effect_order_required &&
            hot_lower_impl_has_external_effects(facts.node_effects[node_id])
          )
        )
      ) ||
      // A new wrapper can have a higher allocation order than a later
      // value. Its old child accesses still precede that value: a forward
      // dependency requires value < child access < existing consumer. The
      // upper bound distinguishes a new write from a wrapped old write.
      hot_lower_impl_carried_local_write_conflicts(
        func,
        node_id,
        current_root,
        facts,
        before_access_order=facts.value_orders[node_id],
        access_before_order=Some(consumer_bounds[node_id]),
      ) ||
      // A stack value can read a local before a later root overwrites it.
      // Preserve this anti-dependence as well as writes consumed by roots.
      (
        anti_dependencies[node_id] &&
        hot_lower_impl_carried_local_write_conflicts(
          func,
          current_root,
          node_id,
          facts,
          after_order=facts.value_orders[node_id],
        )
      ) {
      selected.push(node_id)
    }
  }
  // Facts belong to one immutable source-order snapshot. Queries do not nest;
  // clear only visited entries before the next root reuses this workspace.
  for node_id in scratch.touched {
    seen_consumer[node_id] = hot_node_count(func)
    consumer_bounds[node_id] = -1
    anti_dependencies[node_id] = false
  }
  scratch.touched.clear()
  // Selected rows belong to callers. Only the internal temporary vector is
  // reused, retaining its high-water capacity for this immutable snapshot.
  carried.clear()
  selected
}

///|
fn hot_source_order_future_suffix_minima(
  func : HotFunc,
  roots : Array[NodeId],
  facts : HotSourceOrderFacts,
) -> HotSourceOrderRootIndex? {
  if roots.length() < 64 ||
    !hot_lower_impl_roots_may_need_future_dependencies(
      func,
      roots,
      facts.local_access_cache,
      facts.node_effects,
    ) {
    return None
  }
  Some(HotSourceOrderRootIndex::new(func, roots, facts))
}

///|
priv struct HotSourceOrderRootIndex {
  suffix_minima : Array[Int]
  minima : Array[Int]
  leaf_base : Int
  length : Int
  maximum : Int
}

///|
fn HotSourceOrderRootIndex::new(
  func : HotFunc,
  roots : Array[NodeId],
  facts : HotSourceOrderFacts,
) -> HotSourceOrderRootIndex {
  let suffix_minima = hot_lower_impl_build_preceding_dependency_suffix_minima(
    func,
    roots,
    facts.preceding_dependency_min_cache,
    facts.value_orders,
    facts.node_effects,
  )
  let mut leaf_base = 1
  while leaf_base < roots.length() {
    leaf_base *= 2
  }
  let minima = Array::make(leaf_base * 2, hot_node_count(func))
  let mut maximum = 0
  for idx in 0..<roots.length() {
    let minimum = hot_lower_impl_preceding_dependency_min_node(
      func,
      roots[idx],
      facts.preceding_dependency_min_cache,
      facts.value_orders,
      facts.node_effects,
    )
    minima[leaf_base + idx] = minimum
    if minimum > maximum {
      maximum = minimum
    }
  }
  let mut idx = leaf_base - 1
  while idx > 0 {
    let left = minima[idx * 2]
    let right = minima[idx * 2 + 1]
    minima[idx] = if left < right { left } else { right }
    idx -= 1
  }
  { suffix_minima, minima, leaf_base, length: roots.length(), maximum, }
}

///|
fn HotSourceOrderRootIndex::candidates(
  self : HotSourceOrderRootIndex,
  start : Int,
  before : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  fn visit(index : Int, left : Int, right : Int) -> Unit {
    if right <= start || left >= self.length || self.minima[index] >= before {
      return
    }
    if index >= self.leaf_base {
      out.push(left)
      return
    }
    let mid = (left + right) / 2
    visit(index * 2, left, mid)
    visit(index * 2 + 1, mid, right)
  }
  // Left-to-right traversal preserves source root order, including equal-order
  // carried values. A skipped subtree cannot contain an eligible dependency.
  visit(1, 0, self.leaf_base)
  out
}
