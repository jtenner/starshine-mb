///|
fn cl_live_set_test_fixture(
  param_count? : Int = 0,
) -> (@ir.HotFunc, @ir.HotCfg, @ir.HotLiveness) {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(
      params=Array::make(param_count, @lib.ValType::i32()),
      locals=Array::make(96 - param_count, @lib.ValType::i32()),
    ),
  )
  for index in [1, 95] {
    @ir.hot_root_append(
      func,
      @ir.hot_build_drop(func, @ir.hot_build_local_get(func, index)),
    )
  }
  let cfg = @ir.cfg_build(func, expand_operand_control=true)
  let use_def = @ir.use_def_build(func, cfg=Some(cfg))
  (func, cfg, @ir.liveness_build(cfg, use_def))
}

///|
test "coalesce initializes only actual live members" {
  let (_, cfg, liveness) = cl_live_set_test_fixture()
  let visits = [0]
  let live = cl_cfg_live_set_from_liveness(
    liveness,
    @ir.cfg_entry_block(cfg),
    96,
    true,
    visits=Some(visits),
  )
  assert_eq(live.members, [1, 95])
  assert_eq(live.positions[1], 0)
  assert_eq(live.positions[95], 1)
  assert_false(live.live[0])
  assert_true(visits[0] <= 2, msg="live initialization visits: \{visits[0]}")
}

///|
test "coalesce resets reused live membership and positions" {
  let (_, cfg, liveness) = cl_live_set_test_fixture()
  let scratch = CLCfgLiveSet::new(96)
  cl_cfg_live_set_add(scratch, 63)
  let builds = [0]
  let live = cl_cfg_live_set_from_liveness(
    liveness,
    @ir.cfg_entry_block(cfg),
    96,
    true,
    reuse=Some(scratch),
    builds=Some(builds),
  )
  assert_eq(live.members, [1, 95])
  assert_eq(scratch.members, [1, 95])
  assert_false(scratch.live[63])
  assert_eq(scratch.positions[63], -1)
  ignore(
    cl_cfg_live_set_from_liveness(
      liveness,
      @ir.cfg_exit_block(cfg),
      96,
      false,
      reuse=Some(scratch),
      builds=Some(builds),
    ),
  )
  assert_eq(scratch.members, [])
  assert_false(scratch.live[1])
  assert_false(scratch.live[95])
  assert_eq(scratch.positions[1], -1)
  assert_eq(scratch.positions[95], -1)
  assert_eq(builds[0], 0)
}

///|
test "coalesce interference shares one live workspace across both scans" {
  let (func, cfg, liveness) = cl_live_set_test_fixture()
  let actions = cl_cfg_collect_block_actions(func, cfg)
  let builds = [0]
  let visits = [0]
  let (interferences, sets, tees) = cl_cfg_compute_interferences(
    cfg,
    liveness,
    actions,
    96,
    0,
    live_set_builds=Some(builds),
    live_member_visits=Some(visits),
  )
  assert_true(cl_cfg_sparse_interferes(interferences, 1, 95))
  assert_false(cl_cfg_sparse_interferes(interferences, 0, 1))
  assert_eq(sets, [])
  assert_eq(tees, [])
  assert_true(builds[0] <= 1, msg="live workspaces built: \{builds[0]}")
  assert_true(visits[0] <= 4 * @ir.cfg_block_count(cfg))
}

///|
test "coalesce reused live workspace preserves unused parameter interference" {
  let (func, cfg, liveness) = cl_live_set_test_fixture(param_count=2)
  let (interferences, _, _) = cl_cfg_compute_interferences(
    cfg,
    liveness,
    cl_cfg_collect_block_actions(func, cfg),
    96,
    2,
  )
  assert_true(cl_cfg_sparse_interferes(interferences, 0, 1))
  assert_true(cl_cfg_sparse_interferes(interferences, 0, 95))
  assert_true(cl_cfg_sparse_interferes(interferences, 1, 95))
  assert_false(cl_cfg_sparse_interferes(interferences, 0, 2))
}
