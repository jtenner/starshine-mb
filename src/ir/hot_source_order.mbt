///|
/// Source-order facts shared by lowering and the operand-expanded CFG.
/// Cached local-access summaries are populated on demand.
priv struct HotSourceOrderFacts {
  local_access_cache : Array[Int]
  value_orders : Array[Int]
  node_effects : Array[EffectMask]
  first_effect_orders : Array[Int]
  preceding_dependency_min_cache : Array[Int]
}

///|
fn HotSourceOrderFacts::new(func : HotFunc) -> HotSourceOrderFacts {
  {
    local_access_cache: Array::make(hot_node_count(func), -1),
    value_orders: hot_lower_impl_build_value_orders(func),
    node_effects: effects_build_node_masks(func),
    first_effect_orders: hot_lower_impl_build_first_effect_orders(func),
    preceding_dependency_min_cache: Array::make(hot_node_count(func), -2),
  }
}

///|
fn hot_source_order_preceding_dependencies(
  func : HotFunc,
  current_root : NodeId,
  future_roots : Array[NodeId],
  future_start : Int,
  future_dependency_suffix_minima : Array[Int]?,
  facts : HotSourceOrderFacts,
) -> Array[NodeId] {
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
    Some(suffix_minima) =>
      if future_start < 0 ||
        future_start >= suffix_minima.length() ||
        suffix_minima[future_start] >= current_root {
        return []
      }
    None => ()
  }
  let seen_consumer = Array::make(hot_node_count(func), hot_node_count(func))
  let consumer_bounds = Array::make(hot_node_count(func), -1)
  let carried : Array[NodeId] = []
  // An inserted root can have a newer ID than the consumer it precedes.
  // That order comes from the region, not from a former stack lifetime.
  // Infer an anti-dependence only within the value/current/consumer interval.
  for idx = future_start; idx < future_roots.length(); idx = idx + 1 {
    if future_roots[idx] > current_root {
      hot_lower_impl_collect_preceding_dependency(
        func,
        future_roots[idx],
        current_root,
        future_roots[idx],
        facts.value_orders,
        facts.node_effects,
        seen_consumer,
        consumer_bounds,
        carried,
      )
    }
  }
  let anti_dependencies = @bitset.BitSet::new(hot_node_count(func))
  for node_id in carried {
    anti_dependencies[node_id] = true
  }
  for idx = future_start; idx < future_roots.length(); idx = idx + 1 {
    if future_roots[idx] <= current_root {
      hot_lower_impl_collect_preceding_dependency(
        func,
        future_roots[idx],
        current_root,
        future_roots[idx],
        facts.value_orders,
        facts.node_effects,
        seen_consumer,
        consumer_bounds,
        carried,
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
          after_order=facts.value_orders[node_id],
        )
      ) {
      selected.push(node_id)
    }
  }
  selected
}

///|
fn hot_source_order_future_suffix_minima(
  func : HotFunc,
  roots : Array[NodeId],
  facts : HotSourceOrderFacts,
) -> Array[Int]? {
  if roots.length() < 64 ||
    !hot_lower_impl_roots_may_need_future_dependencies(
      func,
      roots,
      facts.local_access_cache,
      facts.node_effects,
    ) {
    return None
  }
  Some(
    hot_lower_impl_build_preceding_dependency_suffix_minima(
      func,
      roots,
      facts.preceding_dependency_min_cache,
      facts.value_orders,
      facts.node_effects,
    ),
  )
}
