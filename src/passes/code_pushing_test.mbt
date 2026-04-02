///|
fn code_pushing_test_find_first_node(
  func : @ir.HotFunc,
  target : String,
) -> Int {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if @ir.hot_node_get(func, node_id).op.to_string() == target {
      return node_id
    }
  }
  abort("expected test fixture to contain \{target}")
}

///|
test "code-pushing marks a single body-local set as SFA" {
  let func = pass_test_lift_first_func(
    "(module (func (local i32) i32.const 7 local.set 0 local.get 0 drop))",
  )
  let infos = cp_analyze_locals(func)
  let info = infos[0]

  assert_eq(info.num_sets, 1)
  assert_eq(info.num_gets, 1)
  assert_eq(info.num_gets_so_far, 1)
  assert_false(info.is_param)
  assert_false(info.saw_get_before_set)
  assert_true(info.sfa)
}

///|
test "code-pushing rejects params from SFA eligibility" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) i32.const 7 local.set 0 local.get 0 drop))",
  )
  let infos = cp_analyze_locals(func)
  let info = infos[0]

  assert_eq(info.num_sets, 1)
  assert_eq(info.num_gets, 1)
  assert_true(info.is_param)
  assert_false(info.sfa)
}

///|
test "code-pushing rejects locals with a get before the set in postorder" {
  let func = pass_test_lift_first_func(
    "(module (func (local i32) local.get 0 drop i32.const 7 local.set 0))",
  )
  let infos = cp_analyze_locals(func)
  let info = infos[0]

  assert_eq(info.num_sets, 1)
  assert_eq(info.num_gets, 1)
  assert_true(info.saw_get_before_set)
  assert_false(info.sfa)
}

///|
test "code-pushing rejects locals with multiple sets from SFA eligibility" {
  let func = pass_test_lift_first_func(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0 local.get 0 drop))",
  )
  let infos = cp_analyze_locals(func)
  let info = infos[0]

  assert_eq(info.num_sets, 2)
  assert_eq(info.num_gets, 1)
  assert_false(info.sfa)
}

///|
test "code-pushing summaries track local and global access sets" {
  let func = pass_test_lift_first_func(
    "(module (global (mut i32) (i32.const 0)) (func (local i32) (local.set 0 (global.get 0)) (global.set 0 (i32.const 1))))",
  )
  let global_get = code_pushing_test_find_first_node(func, "GlobalGet")
  let local_set = code_pushing_test_find_first_node(func, "LocalSet")
  let global_set = code_pushing_test_find_first_node(func, "GlobalSet")

  assert_true(cp_node_reads_global(func, global_get, 0))
  assert_false(cp_node_writes_global(func, global_get, 0))
  assert_false(cp_node_has_unremovable_side_effects(func, global_get))

  assert_true(cp_node_reads_global(func, local_set, 0))
  assert_true(cp_node_writes_local(func, local_set, 0))

  assert_true(cp_node_writes_global(func, global_set, 0))
  assert_true(cp_node_has_unremovable_side_effects(func, global_set))
}

///|
test "code-pushing treats trapping loads as unremovable side effects" {
  let func = pass_test_lift_first_func(
    "(module (memory 1) (func (param i32) local.get 0 i32.load drop))",
  )
  let load = code_pushing_test_find_first_node(func, "Load")

  assert_true(cp_node_has_unremovable_side_effects(func, load))
}

///|
test "code-pushing treats calls as unremovable side effects" {
  let func = pass_test_lift_first_func(
    "(module (func $caller call $callee drop) (func $callee (result i32) i32.const 1))",
  )
  let call = code_pushing_test_find_first_node(func, "Call")

  assert_true(cp_node_has_unremovable_side_effects(func, call))
}

///|
test "code-pushing slice-one hot pass runs without mutating the fixture" {
  let func = pass_test_lift_first_func(
    "(module (func (local i32) i32.const 7 local.set 0 local.get 0 drop))",
  )
  let before_revision = @ir.hot_revision_current(func)
  let ctx = HotPassContext::new(
    code_pushing_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(result) => {
      assert_false(result.changed)
      assert_eq(@ir.hot_revision_current(func), before_revision)
    }
    Err(err) =>
      fail("expected code-pushing slice-one hot pass success, got \{err}")
  }
}
