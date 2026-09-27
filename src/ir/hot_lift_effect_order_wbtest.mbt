///|
test "lift first-effect queries visit only completed operands and retain no-effect after growth" {
  let func = HotFunc::new()
  for i in 0..<32 {
    ignore(hot_build_const_i32(func, @lib.I32(i)))
  }
  let value = hot_build_const_i32(func, @lib.I32(7))
  let cache : Array[Int] = []
  let visits = [0]
  assert_eq(
    hot_lift_impl_first_effect_order(
      func,
      value,
      cache,
      node_visits=Some(visits),
    ),
    2147483647,
  )
  let call = hot_build_call(func, 0, [@lib.ValType::i32()], [value])
  let drop = hot_build_drop(func, call)
  for node in [value, call, drop] {
    let original = hot_lower_impl_build_first_effect_orders(func)[node]
    assert_eq(
      hot_lift_impl_first_effect_order(
        func,
        node,
        cache,
        node_visits=Some(visits),
      ),
      if original == hot_node_count(func) {
        2147483647
      } else {
        original
      },
    )
  }
  assert_true(visits[0] <= 3, msg="effect-order node visits: \{visits[0]}")
  assert_eq(
    hot_lift_impl_first_effect_order(func, call, cache),
    hot_node_get(func, call).order,
  )
  assert_eq(hot_lift_impl_first_effect_order(func, value, cache), 2147483647)
}

///|
test "lift first-effect queries preserve control boundaries and earliest input effects" {
  let module = @wast.wast_to_binary_module(
    "(module (import \"env\" \"value\" (func (result i32))) (import \"env\" \"log\" (func)) (func (param i32) (result i32) block (result i32) local.get 0 call 1 end call 0 i32.add))",
  ).unwrap()
  let func = hot_lift_func_with_context_result(
    module,
    @lib.FuncIdx::new(2U),
    hot_module_context_from_module(module),
  ).unwrap()
  let reference = hot_lower_impl_build_first_effect_orders(func)
  let cache : Array[Int] = []
  for node = hot_node_count(func) - 1; node >= 0; node = node - 1 {
    assert_eq(
      hot_lift_impl_first_effect_order(func, node, cache),
      if reference[node] == hot_node_count(func) {
        2147483647
      } else {
        reference[node]
      },
    )
  }
  hot_verify_core(func).unwrap()
  hot_verify_control(func).unwrap()
}
