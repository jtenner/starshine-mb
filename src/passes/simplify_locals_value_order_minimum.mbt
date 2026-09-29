///|
priv struct SimplifyLocalsValueOrderMinimums {
  mut owner : @ir.HotFunc?
  mut revision : Int
  states : Array[Int]
  minimums : Array[Int]
}

///|
fn SimplifyLocalsValueOrderMinimums::new() -> SimplifyLocalsValueOrderMinimums {
  { owner: None, revision: -1, states: [], minimums: [], }
}

///|
fn SimplifyLocalsValueOrderMinimums::minimum(
  self : SimplifyLocalsValueOrderMinimums,
  func : @ir.HotFunc,
  node : Int,
  full_queries? : Array[Int]? = None,
) -> Int {
  let count = @ir.hot_node_count(func)
  let revision = @ir.hot_revision_current(func)
  let current = match self.owner {
    Some(owner) =>
      physical_equal(owner, func) &&
      self.revision == revision &&
      self.states.length() >= count
    None => false
  }
  if !current {
    for index in 0..<self.states.length() {
      self.states[index] = 0
    }
    while self.states.length() < count {
      self.states.push(0)
      self.minimums.push(0x7fffffff)
    }
    self.owner = Some(func)
    self.revision = revision
  }
  if node < 0 || node >= count || !@ir.hot_node_is_live(func, node) {
    return 0x7fffffff
  }
  if self.states[node] != 2 {
    match full_queries {
      Some(queries) => queries[0] += 1
      None => ()
    }
  }
  self.collect(func, node)
}

///|
fn SimplifyLocalsValueOrderMinimums::region(
  self : SimplifyLocalsValueOrderMinimums,
  func : @ir.HotFunc,
  region : @ir.HotRegionRef,
) -> Int {
  let mut minimum = 0x7fffffff
  for index in 0..<@ir.hot_region_root_count(func, region) {
    minimum = Int::min(
      minimum,
      self.collect(func, @ir.hot_region_get(func, region, index)),
    )
  }
  minimum
}

///|
fn SimplifyLocalsValueOrderMinimums::collect(
  self : SimplifyLocalsValueOrderMinimums,
  func : @ir.HotFunc,
  node : Int,
) -> Int {
  if node < 0 ||
    node >= self.states.length() ||
    !@ir.hot_node_is_live(func, node) {
    return 0x7fffffff
  }
  if self.states[node] == 2 {
    return self.minimums[node]
  }
  // Valid HOT is a DAG. A temporary cycle is unknown and must keep the safety
  // barrier, rather than making a cyclic dependency appear absent.
  if self.states[node] == 1 {
    return 0
  }
  self.states[node] = 1
  let mut minimum = if @ir.hot_node_result_arity(func, node) > 0 {
    node
  } else {
    0x7fffffff
  }
  for slot in 0..<@ir.hot_child_count(func, node) {
    if !simplify_locals_is_region_child_slot(func, node, slot) {
      minimum = Int::min(
        minimum,
        self.collect(func, @ir.hot_child_get(func, node, slot)),
      )
    }
  }
  match @ir.hot_node_op(func, node) {
    @ir.Block | @ir.Loop =>
      minimum = Int::min(
        minimum,
        self.region(func, @ir.hot_region_body_ref(func, node)),
      )
    @ir.If => {
      minimum = Int::min(
        minimum,
        self.region(func, @ir.hot_region_then_ref(func, node)),
      )
      match @ir.hot_region_else_ref(func, node) {
        Some(region) => minimum = Int::min(minimum, self.region(func, region))
        None => ()
      }
    }
    @ir.Try => {
      minimum = Int::min(
        minimum,
        self.region(func, @ir.hot_region_body_ref(func, node)),
      )
      match @ir.hot_region_catch_ref(func, node) {
        Some(region) => minimum = Int::min(minimum, self.region(func, region))
        None => ()
      }
    }
    @ir.TryTable => {
      minimum = Int::min(
        minimum,
        self.region(func, @ir.hot_region_body_ref(func, node)),
      )
      minimum = Int::min(
        minimum,
        self.region(func, @ir.hot_region_catch_list_ref(func, node)),
      )
    }
    _ => ()
  }
  self.minimums[node] = minimum
  self.states[node] = 2
  minimum
}

///|
fn simplify_locals_contains_value_before_with_minimums(
  func : @ir.HotFunc,
  node : Int,
  before : Int,
  minimums : SimplifyLocalsValueOrderMinimums?,
  seen_rows? : Array[Int]? = None,
) -> Bool {
  match minimums {
    Some(minimums) => minimums.minimum(func, node) < before
    None => {
      match seen_rows {
        Some(rows) => rows[0] += 1
        None => ()
      }
      simplify_locals_node_contains_value_before(
        func,
        node,
        before,
        Array::make(@ir.hot_node_count(func), false),
      )
    }
  }
}

///|
fn simplify_locals_value_order_minimums_for_region(
  sinkables : SimplifyLocalsSinkables,
  func : @ir.HotFunc,
  region : @ir.HotRegionRef,
) -> SimplifyLocalsValueOrderMinimums? {
  if @ir.hot_region_root_count(func, region) < 16 {
    return None
  }
  match sinkables.value_order_minimums {
    Some(minimums) => Some(minimums)
    None => {
      let minimums = SimplifyLocalsValueOrderMinimums::new()
      sinkables.value_order_minimums = Some(minimums)
      Some(minimums)
    }
  }
}
