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
fn code_pushing_test_node_tag(func : @ir.HotFunc, node_id : Int) -> String {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet | @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      "\{node.op}(\{node.imm0})"
    _ => node.op.to_string()
  }
}

///|
fn code_pushing_test_region_tags(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Array[String] {
  let tags : Array[String] = []
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    tags.push(
      code_pushing_test_node_tag(
        func,
        @ir.hot_region_get(func, region_ref, idx),
      ),
    )
  }
  tags
}

///|
fn code_pushing_test_run_hot(text : String) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
  let ctx = HotPassContext::new(
    code_pushing_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) => abort("expected code-pushing hot pass success, got \{err}")
  }
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
test "code-pushing sinks a local.set into the then arm when only then reads it" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end))",
  )
  let if_id = @ir.hot_root_get(func, 1)

  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)), "Nop")
  assert_eq(code_pushing_test_node_tag(func, if_id), "If")
  assert_eq(
    code_pushing_test_region_tags(func, @ir.hot_region_then_ref(func, if_id)),
    ["LocalSet(1)", "Drop"],
  )
}

///|
test "code-pushing still reorders next to an if pushpoint when both arms read" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 i32.const 99 drop local.get 0 if local.get 1 drop else local.get 1 drop end))",
  )

  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)), "Drop")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)),
    "LocalSet(1)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)), "If")
}

///|
test "code-pushing does not sink into if when both arms read the local" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop else local.get 1 drop end))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(1)",
  )
}

///|
test "code-pushing does not sink into if when a later root still reads the local" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop end local.get 1 drop))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(1)",
  )
}

///|
test "code-pushing allows a later read when the opposite arm is terminal" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if local.get 1 drop else unreachable end local.get 1 drop))",
  )
  let if_id = @ir.hot_root_get(func, 1)

  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)), "Nop")
  assert_eq(
    code_pushing_test_region_tags(func, @ir.hot_region_then_ref(func, if_id)),
    ["LocalSet(1)", "Drop"],
  )
}

///|
test "code-pushing blocks if sinking when the condition reads the same local" {
  let func = code_pushing_test_run_hot(
    "(module (func (local i32) i32.const 7 local.set 0 local.get 0 if local.get 0 drop end))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(0)",
  )
}

///|
test "code-pushing moves multiple local.set roots next to br_if while preserving order" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32 i32) block $exit i32.const 1 local.set 1 i32.const 2 local.set 2 i32.const 99 drop local.get 0 br_if $exit local.get 1 drop local.get 2 drop end))",
  )
  let block_id = @ir.hot_root_get(func, 0)
  let body_tags = code_pushing_test_region_tags(
    func,
    @ir.hot_region_body_ref(func, block_id),
  )

  assert_eq(body_tags[0], "Drop")
  assert_eq(body_tags[1], "LocalSet(1)")
  assert_eq(body_tags[2], "LocalSet(2)")
  assert_eq(body_tags[3], "BrIf")
}

///|
test "code-pushing leaves a local.set before a conflicting local read barrier" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) block $exit i32.const 1 local.set 1 local.get 1 drop local.get 0 br_if $exit local.get 1 drop end))",
  )
  let block_id = @ir.hot_root_get(func, 0)
  let body_tags = code_pushing_test_region_tags(
    func,
    @ir.hot_region_body_ref(func, block_id),
  )

  assert_eq(body_tags[0], "LocalSet(1)")
  assert_eq(body_tags[1], "Drop")
  assert_eq(body_tags[2], "BrIf")
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
