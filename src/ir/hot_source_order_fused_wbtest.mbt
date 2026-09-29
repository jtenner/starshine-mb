///|
fn source_order_value_reference(func : HotFunc) -> Array[Int] {
  let orders = Array::make(hot_node_count(func), -1)
  fn visit(node_id : NodeId) -> Int {
    if node_id < 0 || !hot_node_is_live(func, node_id) {
      return -1
    }
    if orders[node_id] >= 0 {
      return orders[node_id]
    }
    orders[node_id] = hot_node_get(func, node_id).order
    for input_id in hot_lower_impl_input_info(func, node_id).nodes {
      let input_order = visit(input_id)
      if input_order > orders[node_id] {
        orders[node_id] = input_order
      }
    }
    orders[node_id]
  }
  for node_id = 0; node_id < orders.length(); node_id = node_id + 1 {
    ignore(visit(node_id))
  }
  orders
}

///|
test "source-order combined facts preserve value and first-effect orders" {
  for
    source in [
      "(module (import \"m\" \"f\" (func $f (result i32))) (func (param i32) (result i32) call $f local.get 0 i32.add))",
      "(module (func (param i32) (result i32) local.get 0 block i32.const 11 local.set 0 end local.get 0 i32.add))",
      "(module (type $s (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 i32.const 7 local.tee 0 if (type $s) local.get 0 i32.add else local.get 0 i32.sub end))",
      "(module (memory 1) (func (param i32) (result i32) block (result i32) local.get 0 i32.load end))",
    ] {
    let module_ = ir_test_module_from_wat(source)
    let index = if source.contains("import") { 1U } else { 0U }
    let func = hot_lift_func(module_, @lib.FuncIdx::new(index))
    let facts = HotSourceOrderFacts::new(func)
    assert_eq(facts.value_orders, source_order_value_reference(func))
    assert_eq(
      facts.first_effect_orders,
      hot_lower_impl_build_first_effect_orders(func),
    )
  }
  let func = HotFunc::new()
  let deleted = hot_build_nop(func)
  hot_delete_node(func, deleted)
  let facts = HotSourceOrderFacts::new(func)
  assert_eq(facts.value_orders, source_order_value_reference(func))
  assert_eq(
    facts.first_effect_orders,
    hot_lower_impl_build_first_effect_orders(func),
  )
}
