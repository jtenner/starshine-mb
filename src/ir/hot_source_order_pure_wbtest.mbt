///|
fn source_order_reference_hot_lower_impl_collect_preceding_dependency(
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
    source_order_reference_hot_lower_impl_collect_preceding_dependency(
      func, input_id, before_node_id, consumer_id, value_orders, node_effects, seen_consumer,
      consumer_bounds, touched, out,
    )
  }
}

///|
fn source_order_reference_hot_lower_impl_preceding_dependency_min_node(
  func : HotFunc,
  node_id : NodeId,
  cache : Array[Int],
  value_orders : Array[Int],
  node_effects : Array[EffectMask],
) -> Int {
  let none = hot_node_count(func)
  if node_id < 0 ||
    node_id >= cache.length() ||
    !hot_node_is_live(func, node_id) {
    return none
  }
  if cache[node_id] != -2 {
    return cache[node_id]
  }
  let mut minimum = if hot_node_result_arity(func, node_id) > 0 &&
    !effects_is_pure(node_effects[node_id]) {
    value_orders[node_id]
  } else {
    none
  }
  for input_id in hot_lower_impl_input_info(func, node_id).nodes {
    let input_minimum = source_order_reference_hot_lower_impl_preceding_dependency_min_node(
      func, input_id, cache, value_orders, node_effects,
    )
    if input_minimum < minimum {
      minimum = input_minimum
    }
  }
  cache[node_id] = minimum
  minimum
}

///|
fn source_order_pure_fixture(count : Int) -> (HotFunc, NodeId, NodeId, NodeId) {
  let func = HotFunc::new()
  let barrier = hot_build_call(func, 0, [], [])
  let leaves = Array::makei(count, fn(i) {
    hot_build_const_i32(func, @lib.I32(i))
  })
  fn build(start : Int, length : Int) -> NodeId {
    if length == 1 {
      return leaves[start]
    }
    let left = length / 2
    let node = hot_build_binary(
      func,
      @lib.ValType::i32(),
      build(start, left),
      build(start + left, length - left),
    )
    hot_node_exact_instr_set(func, node, @lib.Instruction::i32_add())
    node
  }
  let root = hot_build_drop(func, build(0, count))
  (func, root, leaves[0], barrier)
}

///|
test "pure dependency minimum leaves descendant cache entries unobserved" {
  let (func, root, leaf, _) = source_order_pure_fixture(16)
  let facts = HotSourceOrderFacts::new(func)
  assert_true(effects_is_pure(facts.node_effects[root]))
  let cache = Array::make(hot_node_count(func), -2)
  assert_eq(
    hot_lower_impl_preceding_dependency_min_node(
      func,
      root,
      cache,
      facts.value_orders,
      facts.node_effects,
    ),
    hot_node_count(func),
  )
  assert_eq(cache[root], hot_node_count(func))
  assert_eq(cache[leaf], -2)
}

///|
test "pure dependency collection preserves its empty scratch workspace" {
  let (func, root, _, barrier) = source_order_pure_fixture(16)
  let facts = HotSourceOrderFacts::new(func)
  let scratch = HotSourceOrderScratch::new(hot_node_count(func))
  let selected : Array[NodeId] = []
  hot_lower_impl_collect_preceding_dependency(
    func,
    root,
    barrier,
    root,
    facts.value_orders,
    facts.node_effects,
    scratch.seen_consumer,
    scratch.consumer_bounds,
    scratch.touched,
    selected,
  )
  assert_eq(selected, [])
  assert_eq(scratch.touched, [])
  assert_eq(scratch.seen_consumer[root], hot_node_count(func))
  assert_eq(scratch.consumer_bounds[root], -1)
}

///|
test "dependency pruning retains calls local reads loads and numeric traps" {
  for
    source in [
      "(module (import \"m\" \"f\" (func $f (result i32))) (func (result i32) call $f i32.const 1 i32.add))",
      "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.add))",
      "(module (memory 1) (func (result i32) i32.const 0 i32.load i32.const 1 i32.add))",
      "(module (func (result i32) i32.const 7 i32.const 0 i32.div_s i32.const 1 i32.add))",
    ] {
    let module_ = ir_test_module_from_wat(source)
    let index = if source.contains("import") { 1U } else { 0U }
    let func = hot_lift_func(module_, @lib.FuncIdx::new(index))
    let root = hot_root_get(func, hot_root_count(func) - 1)
    let barrier = hot_build_call(func, 0, [], [])
    let facts = HotSourceOrderFacts::new(func)
    assert_false(effects_is_pure(facts.node_effects[root]))
    let selected : Array[NodeId] = []
    let scratch = HotSourceOrderScratch::new(hot_node_count(func))
    hot_lower_impl_collect_preceding_dependency(
      func,
      root,
      barrier,
      root,
      facts.value_orders,
      facts.node_effects,
      scratch.seen_consumer,
      scratch.consumer_bounds,
      scratch.touched,
      selected,
    )
    assert_eq(selected, [root])
    assert_eq(
      hot_lower_impl_preceding_dependency_min_node(
        func,
        root,
        Array::make(hot_node_count(func), -2),
        facts.value_orders,
        facts.node_effects,
      ),
      source_order_reference_hot_lower_impl_preceding_dependency_min_node(
        func,
        root,
        Array::make(hot_node_count(func), -2),
        facts.value_orders,
        facts.node_effects,
      ),
    )
  }
}
