///|
test "source-order own masks compose in place without changing operand orders" {
  for
    source in [
      "(module (func (param i32) (result i32) local.get 0 i32.const 3 i32.add))",
      "(module (func (param i32) (result i32) block (result i32) local.get 0 i32.const 0 i32.div_s end))",
      "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.load))",
      "(module (type $s (struct (field i32))) (func (param (ref null $s)) (result i32) local.get 0 struct.get $s 0))",
      "(module (import \"m\" \"f\" (func $f (result i32))) (func (param i32) (result i32) local.get 0 if (result i32) call $f else i32.const 2 end))",
      "(module (func (param i32) (result i32) local.get 0 block i32.const 11 local.set 0 end local.get 0 i32.add))",
      "(module (func (result i32) i32.const 1 block (param i32) (result i32) i32.const 2 i32.add end))",
    ] {
    let module_ = ir_test_module_from_wat(source)
    let index = if source.contains("import") { 1U } else { 0U }
    let func = hot_lift_func(module_, @lib.FuncIdx::new(index))
    let revision = hot_revision_current(func)
    let orders = HotSourceOrderOrders::new(func)
    let values = orders.value_orders.copy()
    let first_effects = orders.first_effect_orders.copy()
    for node in 0..<hot_node_count(func) {
      assert_eq(
        orders.own_effects[node],
        effects_mask_for_flags(hot_node_flags(func, node)) |
        effects_mask_for_node_exact(func, node),
      )
    }
    let expected = own_masks_reference_node_masks(func)
    assert_eq(effects_build_node_masks(func), expected)
    let composed = effects_build_node_masks(
      func,
      own_masks=Some(orders.own_effects),
    )
    assert_true(physical_equal(composed, orders.own_effects))
    assert_eq(composed, expected)
    assert_eq(orders.value_orders, values)
    assert_eq(orders.first_effect_orders, first_effects)
    let facts = HotSourceOrderFacts::new(func)
    assert_eq(facts.node_effects, expected)
    assert_eq(facts.value_orders, source_order_value_reference(func))
    assert_eq(
      facts.first_effect_orders,
      hot_lower_impl_build_first_effect_orders(func),
    )
    assert_eq(hot_revision_current(func), revision)
  }
}

///|
test "source-order own masks compose shared operand DAGs exactly once per row" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let mut value = hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    hot_build_local_get(func, 0),
  )
  for _ in 0..<12 {
    value = hot_build_binary(func, @lib.ValType::i32(), value, value)
    hot_node_exact_instr_set(func, value, @lib.Instruction::i32_add())
  }
  hot_root_append(func, hot_build_drop(func, value))
  let expected = own_masks_reference_node_masks(func)
  let orders = HotSourceOrderOrders::new(func)
  let composed = effects_build_node_masks(
    func,
    own_masks=Some(orders.own_effects),
  )
  assert_true(physical_equal(composed, orders.own_effects))
  assert_eq(composed, expected)
  assert_true(effects_reads_memory(composed[value]))
  let facts = HotSourceOrderFacts::new(func)
  assert_eq(facts.node_effects, expected)
  assert_eq(facts.value_orders, source_order_value_reference(func))
  assert_eq(
    facts.first_effect_orders,
    hot_lower_impl_build_first_effect_orders(func),
  )
}

///|
test "source-order own masks keep dead nodes zero and distinguish region effects" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let dead = hot_build_const_i32(func, @lib.I32(9))
  let value = hot_build_local_get(func, 0)
  let block = hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [value],
  )
  hot_root_append(func, block)
  hot_delete_node(func, dead)
  let orders = HotSourceOrderOrders::new(func)
  assert_eq(orders.own_effects[dead], 0U)
  assert_eq(orders.own_effects[value], EFFECT_MASK_LOCAL_STATE)
  let own_block = orders.own_effects[block]
  assert_eq(own_block & EFFECT_MASK_LOCAL_STATE, 0U)
  let expected = own_masks_reference_node_masks(func)
  assert_eq(effects_build_node_masks(func), expected)
  let composed = effects_build_node_masks(
    func,
    own_masks=Some(orders.own_effects),
  )
  assert_eq(composed, expected)
  assert_eq(composed[dead], 0U)
  assert_eq(composed[block] & EFFECT_MASK_LOCAL_STATE, EFFECT_MASK_LOCAL_STATE)
  assert_eq(orders.value_orders, source_order_value_reference(func))
  assert_eq(
    orders.first_effect_orders,
    hot_lower_impl_build_first_effect_orders(func),
  )
  let empty = HotSourceOrderOrders::new(HotFunc::new())
  assert_eq(empty.own_effects, [])
  assert_eq(empty.value_orders, [])
  assert_eq(empty.first_effect_orders, [])
}

///|
// Frozen v16 value/first-effect pass, before sharing its own-effect results.
#valtype
priv struct SourceOrderOwnMasksReferenceOrders {
  value_orders : Array[Int]
  first_effect_orders : Array[Int]
}

///|
fn SourceOrderOwnMasksReferenceOrders::new(
  func : HotFunc,
) -> SourceOrderOwnMasksReferenceOrders {
  let none = hot_node_count(func)
  let value_orders = Array::make(none, -1)
  let first_effect_orders = Array::make(none, -1)
  fn visit(node_id : NodeId) -> Unit {
    if node_id < 0 ||
      !hot_node_is_live(func, node_id) ||
      value_orders[node_id] >= 0 {
      return
    }
    let node = hot_node_get(func, node_id)
    value_orders[node_id] = node.order
    let own_effects = effects_mask_for_flags(node.flags) |
      effects_mask_for_node_exact(func, node_id)
    first_effect_orders[node_id] = if hot_lower_impl_has_external_effects(
        own_effects,
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
  { value_orders, first_effect_orders, }
}

///|
// Frozen original all-child mask pass, including own-payload reconstruction.
fn own_masks_reference_accumulate(
  func : HotFunc,
  node_id : NodeId,
  node_masks : Array[EffectMask],
  ready : @bitset.BitSet,
) -> EffectMask {
  if ready[node_id] {
    return node_masks[node_id]
  }
  let mut mask = effects_mask_for_flags(hot_node_flags(func, node_id))
  mask = mask | effects_mask_for_node_exact(func, node_id)
  for slot = 0; slot < hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = hot_child_get(func, node_id, slot)
    if child_id == HOT_NONE_NODE || !hot_node_is_live(func, child_id) {
      continue
    }
    mask = mask |
      own_masks_reference_accumulate(func, child_id, node_masks, ready)
  }
  node_masks[node_id] = mask
  ready[node_id] = true
  mask
}

///|
fn own_masks_reference_node_masks(func : HotFunc) -> Array[EffectMask] {
  let node_masks = Array::make(hot_node_count(func), 0U)
  let ready = @bitset.BitSet::new(hot_node_count(func))
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    ignore(own_masks_reference_accumulate(func, node_id, node_masks, ready))
  }
  node_masks
}
