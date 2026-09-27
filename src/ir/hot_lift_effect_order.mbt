///|
// Completed roots and operand trees are immutable during lifting. Region bodies
// are separate scopes, exactly as in lowering's first-effect analysis. A stable
// sentinel is required because the function keeps growing between queries.
fn hot_lift_impl_first_effect_order(
  func : HotFunc,
  node : NodeId,
  cache : Array[Int],
  node_visits? : Array[Int]? = None,
) -> Int {
  if node < 0 || !hot_node_is_live(func, node) {
    return 2147483647
  }
  while cache.length() <= node {
    cache.push(-1)
  }
  if cache[node] >= 0 {
    return cache[node]
  }
  match node_visits {
    Some(visits) => visits[0] += 1
    None => ()
  }
  let own = effects_mask_for_flags(hot_node_flags(func, node)) |
    effects_mask_for_node_exact(func, node)
  cache[node] = if hot_lower_impl_has_external_effects(own) {
    hot_node_get(func, node).order
  } else {
    2147483647
  }
  for input in hot_lower_impl_input_info(func, node).nodes {
    let order = hot_lift_impl_first_effect_order(
      func,
      input,
      cache,
      node_visits~,
    )
    if order < cache[node] {
      cache[node] = order
    }
  }
  cache[node]
}
