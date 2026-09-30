///|
// Frozen V24b collector/query for output and performance controls.
fn source_order_minimum_reference_collect(
  func : HotFunc,
  node_id : NodeId,
  before_node_id : NodeId,
  consumer_id : NodeId,
  value_orders : Array[Int],
  node_effects : Array[EffectMask],
  seen_consumer : Array[Int],
  consumer_bounds : Array[Int],
  touched : Array[NodeId],
  out : Array[NodeId],
) -> Unit {
  if node_id < 0 ||
    node_id >= seen_consumer.length() ||
    seen_consumer[node_id] <= consumer_id ||
    !hot_node_is_live(func, node_id) {
    return
  }
  // Subtree masks include every operand: a pure tree cannot contain an
  // effectful value that needs to be carried across this root.
  if effects_is_pure(node_effects[node_id]) {
    return
  }
  if seen_consumer[node_id] == seen_consumer.length() {
    touched.push(node_id)
  }
  seen_consumer[node_id] = consumer_id
  if value_orders[node_id] < before_node_id &&
    hot_node_result_arity(func, node_id) > 0 &&
    !effects_is_pure(node_effects[node_id]) {
    if consumer_bounds[node_id] < 0 {
      out.push(node_id)
    }
    consumer_bounds[node_id] = consumer_id
    return
  }
  let inputs = hot_lower_impl_input_info(func, node_id)
  for input_id in inputs.nodes {
    source_order_minimum_reference_collect(
      func, input_id, before_node_id, consumer_id, value_orders, node_effects, seen_consumer,
      consumer_bounds, touched, out,
    )
  }
}

///|
fn source_order_minimum_reference_query(
  func : HotFunc,
  current_root : NodeId,
  future_roots : Array[NodeId],
  future_start : Int,
  future_dependency_suffix_minima : HotSourceOrderRootIndex?,
  facts : HotSourceOrderFacts,
  scratch_builds? : Array[Int]? = None,
  root_visits? : Array[Int]? = None,
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
  let scratch = match facts.dependency_scratch {
    Some(scratch) => scratch
    None => {
      match scratch_builds {
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
  let carried : Array[NodeId] = []
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
      source_order_minimum_reference_collect(
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
      source_order_minimum_reference_collect(
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
  selected
}
