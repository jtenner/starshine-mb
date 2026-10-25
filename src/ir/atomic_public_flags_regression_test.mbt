///|
test "atomic store public flags must retain trap write and side effects" {
  let module_ = @wast.wast_to_binary_module(
    "(module (memory 1 1 shared) (func (i32.atomic.store (i32.const 0) (i32.const 1))))",
  ).unwrap()
  assert_true(@validate.validate_module(module_) is Ok(_))
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let store = hot_root_get(func, 0)
  assert_true(hot_node_get(func, store).op is HotOp::Atomic)
  let mask = effects_for_node(func, store)
  assert_true(effects_writes_memory(mask))
  assert_true((mask & EFFECT_MASK_TRAP) != 0U)
  assert_false(effects_is_pure(mask))
  // Required behavior: public flags must agree with the exact atomic effects.
  // Keep the observations together so a failure reports all three flags.
  @debug.assert_eq(
    (
      hot_may_trap(func, store),
      hot_has_side_effect(func, store),
      hot_node_has_flag(func, store, HOT_FLAG_STORE),
    ),
    (true, true, true),
  )
}
