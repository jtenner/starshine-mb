///|
test "compact CFG SSA records typed loop entry local reads" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (type $t (func (param i32))) (func (param i32) local.get 0 loop (type $t) unreachable end))",
  )
  let func = fixture.hot_func
  let loop_id = hot_root_get(func, 0)
  let entry_get = hot_child_get(func, loop_id, 0)
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let live = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, live, use_def)
  assert_true(ssa.local_get_values[entry_get] >= 0)
  assert_eq(
    ssa_value_origin(ssa, ssa_value_for_local_get(ssa, entry_get)),
    ssa_param_entry_def(0),
  )
}

///|
test "compact CFG SSA visits a repeated loop-entry producer once" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (type $t (func (param i32 i32))) (func (param i32) (local i32) (block (result i32 i32) i32.const 1 local.tee 1 local.get 0) loop (type $t) drop drop end))",
  )
  let func = fixture.hot_func
  let loop_id = hot_root_get(func, 0)
  assert_eq(hot_child_get(func, loop_id, 0), hot_child_get(func, loop_id, 1))
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let live = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, live, use_def)
  let mut tee_defs = 0
  for origin in ssa.value_origins {
    if origin is HotSsaValueOrigin::LocalTeeDef(_) {
      tee_defs += 1
    }
  }
  assert_eq(tee_defs, 1)
}
