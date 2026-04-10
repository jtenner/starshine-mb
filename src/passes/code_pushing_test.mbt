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
fn code_pushing_test_find_block_body_region(
  func : @ir.HotFunc,
  result_arity : Int,
  tags : Array[String],
) -> @ir.HotRegionRef {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block => {
        if @ir.hot_node_result_arity(func, node_id) != result_arity {
          continue
        }
        let region = @ir.hot_region_body_ref(func, node_id)
        if code_pushing_test_region_tags(func, region) == tags {
          return region
        }
      }
      _ => ()
    }
  }
  abort("expected block body region with tags \{tags}")
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
fn code_pushing_test_run_hot_code(text : String, code_idx : Int) -> @ir.HotFunc {
  let fixture = @ir.ir_test_build_hot_from_wat(text, code_idx~)
  let func = fixture.hot_func
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
priv struct CodePushingRealCarrierFixture {
  carrier_body : @ir.HotRegionRef
  err_body : @ir.HotRegionRef
}

///|
fn code_pushing_test_find_real_carrier_fixture(
  func : @ir.HotFunc,
) -> CodePushingRealCarrierFixture {
  let mut carrier_body : @ir.HotRegionRef? = None
  let mut err_body : @ir.HotRegionRef? = None
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block => {
        let region = @ir.hot_region_body_ref(func, node_id)
        let tags = code_pushing_test_region_tags(func, region)
        if tags ==
          ["Block", "LocalSet(5)", "If", "Store", "Drop", "LocalGet(3)"] {
          carrier_body = Some(region)
          continue
        }
        if tags == ["Br"] {
          let branch_id = @ir.hot_region_get(func, region, 0)
          if @ir.hot_child_count(func, branch_id) >= 1 {
            let payload = @ir.hot_child_get(func, branch_id, 0)
            if payload >= 0 && @ir.hot_node_is_live(func, payload) {
              match @ir.hot_node_get(func, payload).op {
                @ir.HotOp::Block => err_body = Some(region)
                _ => ()
              }
            }
          }
        }
      }
      _ => ()
    }
  }
  {
    carrier_body: match carrier_body {
      Some(region) => region
      None => abort("expected real-carrier body region")
    },
    err_body: match err_body {
      Some(region) => region
      None => abort("expected parent err region")
    },
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
test "code-pushing counts local.tee as a set for SFA eligibility" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) (local f32) (f32.const 6) (local.set 1) (if (i32.const 0) (then nop) (else nop)) (drop (local.tee 1 (f32.const 91))) (if (i32.const 0) (then nop) (else nop)) (local.get 0)))",
  )
  let info = cp_analyze_locals(func)[1]

  assert_eq(info.num_sets, 2)
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
test "code-pushing does not move a call-fed local.set before a later if" {
  let func = code_pushing_test_run_hot_code(
    "(module (func $caller (local i32) call $callee local.set 0 local.get 0 if nop end) (func $callee (result i32) i32.const 1))",
    0,
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(0)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)), "If")
}

///|
test "code-pushing moves a local-get local.set past an if with calls in its arms" {
  let source =
    #|(module
    #|  (func $touch (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32)
    #|    (local.get 1)
    #|    (local.set 2)
    #|    (if
    #|      (local.get 0)
    #|      (then
    #|        (call $touch
    #|          (local.get 1)))
    #|      (else
    #|        (call $touch
    #|          (local.get 0))))
    #|    (local.get 2)))
    #|)
  let func = code_pushing_test_run_hot_code(source, 1)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "If", "LocalSet(2)", "LocalGet(2)",
  ])
}

///|
test "code-pushing moves an alias local.set past a later if even with an earlier block-loop return root" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $mk (result i32)
    #|    (i32.const 4))
    #|  (func $touch (param i32))
    #|  (func $dropref (param i32))
    #|  (func $join (param i32 i32) (result i32)
    #|    (local.get 0))
    #|  (func (param i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (block $done
    #|      (loop $label
    #|        (if
    #|          (local.get 0)
    #|          (then
    #|            (return
    #|              (i32.const 7))))
    #|        (br $done)))
    #|    (call $mk)
    #|    (local.set 1)
    #|    (local.get 1)
    #|    (local.set 2)
    #|    (i32.load
    #|      (local.get 0))
    #|    (local.set 3)
    #|    (if
    #|      (i32.gt_s
    #|        (i32.load
    #|          (local.get 0))
    #|        (i32.const 1))
    #|      (then
    #|        (call $touch
    #|          (local.get 3)))
    #|      (else
    #|        (if
    #|          (i32.eq
    #|            (i32.load
    #|              (local.get 0))
    #|            (i32.const 1))
    #|          (then
    #|            (call $dropref
    #|              (local.get 0))))))
    #|    (local.get 3)
    #|    (local.set 4)
    #|    (call $join
    #|      (local.get 2)
    #|      (local.get 4)))
    #|)
  let func = code_pushing_test_run_hot_code(source, 4)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "Block", "LocalSet(1)", "LocalSet(3)", "If", "LocalSet(2)", "LocalSet(4)", "Call",
  ])
}

///|
test "code-pushing does not move a local.set when no later target root exists" {
  let func = code_pushing_test_run_hot(
    "(module (func (local i32) i32.const 7 local.set 0 local.get 0 drop))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(0)",
  )
}

///|
test "code-pushing does not move a local.set before an unrelated if" {
  let func = code_pushing_test_run_hot(
    "(module (func (local i32) i32.const 7 local.set 0 i32.const 1 if nop end))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(0)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)), "If")
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
test "code-pushing moves a local.set past an if when the if does not read it" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32 i32) (local i32) i32.const 7 local.set 2 local.get 0 if local.get 1 drop end local.get 2 drop))",
  )

  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)),
    "LocalSet(2)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)), "Drop")
}

///|
test "code-pushing can split movable local.set roots around an if" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32 i32) local.get 0 local.set 1 i32.const 9 local.set 2 local.get 0 if local.get 1 drop else local.get 1 drop end local.get 2 drop))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(1)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)),
    "LocalSet(2)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)), "Drop")
}

///|
test "code-pushing moves a later local.set after an if even with an earlier kept local.set before the if" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32 i32) i32.const 7 local.set 1 local.get 0 local.set 2 local.get 2 if local.get 2 drop end local.get 1 drop))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(2)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)),
    "LocalSet(1)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)), "Drop")
}

///|
test "code-pushing still moves a later local.set after an if when the earlier kept local.set is read inside and after the if" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32 i32) i32.const 7 local.set 1 local.get 0 local.set 2 local.get 2 if local.get 2 drop end local.get 2 drop local.get 1 drop))",
  )

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "If", "LocalSet(1)", "Drop", "Drop",
  ])
}

///|
test "code-pushing moves an artifact-shaped tee-fed local.set after an if when only later roots read it" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $alloc (param i32) (result i32)
    #|    i32.const 0)
    #|  (func $use (param i32))
    #|  (func (param i32)
    #|    (local i32 i32 i32 i32)
    #|    local.get 0
    #|    local.set 1
    #|    i32.const 4
    #|    call $alloc
    #|    local.tee 4
    #|    i32.const 1
    #|    i32.store offset=4
    #|    local.get 4
    #|    local.get 1
    #|    i32.store offset=8
    #|    local.get 4
    #|    local.set 2
    #|    local.get 0
    #|    local.set 3
    #|    local.get 3
    #|    if
    #|      local.get 3
    #|      call $use
    #|    end
    #|    local.get 3
    #|    drop
    #|    local.get 2
    #|    drop))
    #|
  let func = code_pushing_test_run_hot_code(source, 2)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(1)", "Store", "Store", "LocalSet(3)", "If", "LocalSet(2)", "Drop",
    "Drop",
  ])
}

///|
test "code-pushing moves a later-used local.set past an if with multiple future reads" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32 i32) local.get 0 local.set 1 i32.const 9 local.set 2 local.get 0 if local.get 1 drop else local.get 1 drop end block local.get 2 drop local.get 2 drop end local.get 2 drop))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(1)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)),
    "LocalSet(2)",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)),
    "Block",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 4)), "Drop")
}

///|
test "code-pushing moves a dead local.set past a later void if" {
  let source =
    #|(module
    #|  (func (param i64)
    #|    (local f32)
    #|    (if (i32.const 1)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    (f32.const 82)
    #|    (local.set 1)
    #|    nop
    #|    (block
    #|      nop)
    #|    (if (i32.const 1)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    nop))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "If", "Nop", "Block", "If", "LocalSet(1)", "Nop",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing moves a dead local.set past an unrelated param local.set and later void if" {
  let source =
    #|(module
    #|  (func (param f64) (result f32)
    #|    (local i32)
    #|    (local f32)
    #|    (local i64)
    #|    (if (i32.const 0)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    (i32.const 326)
    #|    (local.set 1)
    #|    (f64.const 2)
    #|    (local.set 0)
    #|    (if (i32.const 0)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    (local.get 2)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "If", "LocalSet(0)", "If", "LocalSet(1)", "LocalGet(2)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing moves a dead local.set across local-only roots when no later read needs it" {
  let source =
    #|(module
    #|  (func (param i64) (result f32)
    #|    (local f32)
    #|    (local f64)
    #|    (local f64)
    #|    nop
    #|    (f64.const 22)
    #|    (local.set 3)
    #|    (drop
    #|      (local.tee 2
    #|        (f64.const 24)))
    #|    (if (i32.const 0)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    (if (i32.const 0)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    (f32.const 65)
    #|    (local.set 1)
    #|    (local.get 1)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "Nop", "Drop", "If", "If", "LocalSet(3)", "LocalSet(1)", "LocalGet(1)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing does not move a local.set when a later local.tee rewrites it" {
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local f32)
    #|    (f32.const 6)
    #|    (local.set 1)
    #|    (if (i32.const 0)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    (drop
    #|      (local.tee 1
    #|        (f32.const 91)))
    #|    (if (i32.const 0)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    (local.get 0)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(1)", "If", "Drop", "If", "LocalGet(0)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing moves a dead local.set past pure drops and a later void if before an unrelated final root" {
  let source =
    #|(module
    #|  (global i32 (i32.const 149))
    #|  (func (param i64) (result i64)
    #|    (local f32)
    #|    (local f64)
    #|    (if (i32.const 0)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    (f32.const 18)
    #|    (local.set 1)
    #|    (drop
    #|      (i32.const 898))
    #|    (drop
    #|      (global.get 0))
    #|    (if (i32.const 0)
    #|      (then
    #|        nop)
    #|      (else
    #|        nop))
    #|    (local.get 0)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "If", "Drop", "Drop", "If", "LocalSet(1)", "LocalGet(0)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing moves a pure local.set past a trapping local.set and if when safe" {
  let func = code_pushing_test_run_hot(
    "(module (memory 1) (func (param i32 i32) (local i32 i32) local.get 0 local.set 2 local.get 1 i32.load local.set 3 local.get 0 if local.get 3 drop end local.get 2 drop))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(3)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)),
    "LocalSet(2)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)), "Drop")
}

///|
test "code-pushing does not move a local.set after a result if" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if (result i32) i32.const 1 else i32.const 0 end drop local.get 1 drop))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(1)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)), "Drop")
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)), "Drop")
}

///|
test "code-pushing does not sink into a result-producing if arm" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 local.get 0 if (result i32) local.get 1 drop i32.const 1 else i32.const 0 end drop))",
  )

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(1)",
  )
}

///|
test "code-pushing rewrites inside a branch-free nested non-void region" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32 i32) local.get 0 if (result i32) local.get 1 local.set 2 i32.const 9 local.set 3 local.get 0 if local.get 2 drop else local.get 2 drop end local.get 3 else i32.const 0 end))",
  )
  let if_id = @ir.hot_root_get(func, 0)

  assert_eq(
    code_pushing_test_region_tags(func, @ir.hot_region_then_ref(func, if_id)),
    ["LocalSet(2)", "If", "LocalSet(3)", "LocalGet(3)"],
  )
}

///|
test "code-pushing keeps nested non-void region rewrites valid after lowering" {
  let source = "(module (func (param i32 i32) (result i32) (local i32 i32) local.get 0 if (result i32) local.get 1 local.set 2 i32.const 9 local.set 3 local.get 0 if local.get 2 drop else local.get 2 drop end local.get 3 else i32.const 0 end))"
  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites a branch-free root non-void region around sibling ifs" {
  let source =
    #|(module
    #|  (func (result i32) (local i32 i32 i32 i32 i32)
    #|    i32.const 2
    #|    local.set 0
    #|    i32.const 2
    #|    local.set 1
    #|    local.get 1
    #|    i32.const 1
    #|    i32.gt_s
    #|    if
    #|      local.get 1
    #|      i32.const 1
    #|      i32.sub
    #|      local.set 4
    #|      local.get 0
    #|      if
    #|        local.get 0
    #|        drop
    #|      else
    #|        local.get 1
    #|        i32.const 1
    #|        i32.eq
    #|        if
    #|        end
    #|      end
    #|    end
    #|    local.get 0
    #|    local.set 2
    #|    i32.const 3
    #|    local.set 3
    #|    local.get 3
    #|    i32.const 1
    #|    i32.gt_s
    #|    if
    #|      local.get 3
    #|      i32.const 1
    #|      i32.sub
    #|      local.set 4
    #|      local.get 3
    #|      if
    #|        local.get 3
    #|        drop
    #|      else
    #|        local.get 3
    #|        i32.const 1
    #|        i32.eq
    #|        if
    #|        end
    #|      end
    #|    end
    #|    local.get 3
    #|    local.set 4
    #|    local.get 2
    #|    local.get 4
    #|    i32.add)
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(0)",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)),
    "LocalSet(1)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)),
    "LocalSet(3)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 4)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 5)),
    "LocalSet(2)",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 6)),
    "LocalSet(4)",
  )
}

///|
test "code-pushing keeps root non-void sibling-if rewrites valid after lowering" {
  let source =
    #|(module
    #|  (func (result i32) (local i32 i32 i32 i32 i32)
    #|    i32.const 2
    #|    local.set 0
    #|    i32.const 2
    #|    local.set 1
    #|    local.get 1
    #|    i32.const 1
    #|    i32.gt_s
    #|    if
    #|      local.get 1
    #|      i32.const 1
    #|      i32.sub
    #|      local.set 4
    #|      local.get 0
    #|      if
    #|        local.get 0
    #|        drop
    #|      else
    #|        local.get 1
    #|        i32.const 1
    #|        i32.eq
    #|        if
    #|        end
    #|      end
    #|    end
    #|    local.get 0
    #|    local.set 2
    #|    i32.const 3
    #|    local.set 3
    #|    local.get 3
    #|    i32.const 1
    #|    i32.gt_s
    #|    if
    #|      local.get 3
    #|      i32.const 1
    #|      i32.sub
    #|      local.set 4
    #|      local.get 3
    #|      if
    #|        local.get 3
    #|        drop
    #|      else
    #|        local.get 3
    #|        i32.const 1
    #|        i32.eq
    #|        if
    #|        end
    #|      end
    #|    end
    #|    local.get 3
    #|    local.set 4
    #|    local.get 2
    #|    local.get 4
    #|    i32.add)
    #|)
  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing does not rewrite split-carry result-if regions" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (block (result i32)
    #|              (block $cont
    #|                (if (local.get 0)
    #|                  (then
    #|                    (local.set 3 (local.get 1))
    #|                    (local.set 2 (local.get 1))
    #|                    (br $cont))
    #|                  (else
    #|                    (local.set 3 (i32.const 5))
    #|                    (local.set 2 (i32.const 9))
    #|                    (br $mid))))
    #|              (local.get 2))))
    #|        (i32.const 1)))
    #|    (local.get 3)
    #|    (if
    #|      (local.get 3)
    #|      (then
    #|        (drop (local.get 3))))
    #|    (local.get 2)))
    #|)
  let func = code_pushing_test_run_hot(source)
  let if_id = code_pushing_test_find_first_node(func, "If")

  assert_eq(
    code_pushing_test_region_tags(func, @ir.hot_region_then_ref(func, if_id)),
    ["LocalSet(3)", "LocalSet(2)", "Br"],
  )
  assert_eq(
    code_pushing_test_region_tags(
      func,
      @ir.hot_region_else_ref(func, if_id).unwrap(),
    ),
    ["LocalSet(3)", "LocalSet(2)", "Br"],
  )
}

///|
test "code-pushing does not rewrite a root sibling-if fed by split-carry results" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (block (result i32)
    #|              (block $cont
    #|                (if (local.get 0)
    #|                  (then
    #|                    (local.set 3 (local.get 1))
    #|                    (local.set 2 (local.get 1))
    #|                    (br $cont))
    #|                  (else
    #|                    (local.set 3 (i32.const 5))
    #|                    (local.set 2 (i32.const 9))
    #|                    (br $mid))))
    #|              (local.get 2))))
    #|        (i32.const 1)))
    #|    (local.set 4 (local.get 3))
    #|    (if
    #|      (local.get 3)
    #|      (then
    #|        (drop (local.get 3))))
    #|    (local.get 4)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "LocalSet(2)",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)),
    "LocalSet(4)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)),
    "LocalGet(4)",
  )
}

///|
test "code-pushing keeps split-carry root sibling-if rewrites valid after lowering" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (block (result i32)
    #|              (block $cont
    #|                (if (local.get 0)
    #|                  (then
    #|                    (local.set 3 (local.get 1))
    #|                    (local.set 2 (local.get 1))
    #|                    (br $cont))
    #|                  (else
    #|                    (local.set 3 (i32.const 5))
    #|                    (local.set 2 (i32.const 9))
    #|                    (br $mid))))
    #|              (local.get 2))))
    #|        (i32.const 1)))
    #|    (local.set 4 (local.get 3))
    #|    (if
    #|      (local.get 3)
    #|      (then
    #|        (drop (local.get 3))))
    #|    (local.get 4)))
    #|)
  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing can reorder in a non-void root region without region-label branches" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32) i32.const 7 local.set 2 local.get 0 if local.get 1 drop end i32.const 1))",
  )

  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)),
    "LocalSet(2)",
  )
}

///|
test "code-pushing rewrites a non-void prefix before a later branch root" {
  let source = "(module (func (param i32 i32) (result i32) (local i32) i32.const 7 local.set 2 local.get 0 if local.get 1 drop end block $done local.get 0 br_if $done end local.get 2))"
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)),
    "LocalSet(2)",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)),
    "Block",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)),
    "LocalGet(2)",
  )

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing ignores an earlier unrelated explicit-exit local.set when moving a later local.set in a non-void region" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $carry (result i32)
    #|      (if (local.get 0)
    #|        (then
    #|          (br $carry
    #|            (i32.const 7))))
    #|      (i32.const 9))
    #|    (local.set 2)
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 3)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "If", "LocalSet(3)", "LocalGet(3)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit local.set carrying a self-contained block" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (local.set 2
    #|      (block $carry (result i32)
    #|        (block $work
    #|          (if (local.get 0)
    #|            (then
    #|              (br $work))
    #|            (else
    #|              (br $carry (i32.const 7))))
    #|          unreachable)
    #|        (i32.const 9)))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 3)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "If", "LocalSet(3)", "LocalGet(3)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit local.set carrying a live-like dropped-owner block" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 2
    #|      (block $holder (result i32)
    #|        (drop
    #|          (block $outer (result i32)
    #|            (block $prefix
    #|              (if (local.get 0)
    #|                (then
    #|                  (br $outer (i32.const 0)))
    #|                (else
    #|                  (drop (i32.const 0)))))
    #|            (local.get 1)
    #|            (local.set 4)
    #|            (local.get 1)
    #|            (local.set 5)
    #|            (local.get 5)
    #|            (if
    #|              (then
    #|                (drop (local.get 5))))
    #|            (local.get 4)))
    #|        (i32.const 9)))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 3)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "If", "LocalSet(3)", "LocalGet(3)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit local.set carrying a nested self-owner if block" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 2
    #|      (block $carry (result i32)
    #|        (block $mid
    #|          (br $carry
    #|            (if (result i32)
    #|              (local.get 0)
    #|              (then
    #|                (block $inner (result i32)
    #|                  (local.set 4 (local.get 1))
    #|                  (br $inner (local.get 4))))
    #|              (else
    #|                (local.set 4 (i32.const 5))
    #|                (local.get 4)))))
    #|        (local.get 1)))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (local.set 5)
    #|    (local.get 5)
    #|    (if
    #|      (then
    #|        (drop (local.get 5))))
    #|    (local.get 3)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "LocalSet(5)", "If", "LocalSet(3)", "LocalGet(3)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit local.set carrying a self-owner block with return" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (local.set 2
    #|      (block $carry (result i32)
    #|        (local.get 1)
    #|        (local.set 4)
    #|        (if (local.get 0)
    #|          (then
    #|            (return (local.get 4)))
    #|          (else
    #|            (br $carry (local.get 4))))
    #|        unreachable))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 3)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "If", "LocalSet(3)", "LocalGet(3)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit local.set carrying a simple owner-only if payload" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (if (result i32) (local.get 0)
    #|              (then
    #|                (local.set 3 (local.get 1))
    #|                (local.get 3))
    #|              (else
    #|                (local.set 3 (i32.const 5))
    #|                (local.get 3)))))
    #|        (local.get 3)))
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 4)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "If", "LocalSet(4)", "LocalGet(4)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an owner-only if payload carrier even when the trailing local.get is not the payload-written local" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (if (result i32) (local.get 0)
    #|              (then
    #|                (local.set 3 (local.get 1))
    #|                (i32.const 7))
    #|              (else
    #|                (local.set 3 (i32.const 5))
    #|                (i32.const 9)))))
    #|        (local.get 1)))
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 4)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "If", "LocalSet(4)", "LocalGet(4)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an owner-only if payload when the payload branches back to the inner block" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (if (result i32) (local.get 0)
    #|              (then
    #|                (local.set 3 (local.get 1))
    #|                (local.get 3))
    #|              (else
    #|                (local.set 4 (local.get 1))
    #|                (br $mid)))))
    #|        (local.get 4)))
    #|    (local.get 1)
    #|    (local.set 5)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 5)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "If", "LocalSet(5)", "LocalGet(5)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an owner-only if payload with a nested explicit exit even when the trailing local.get is unrelated" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (if (result i32) (local.get 0)
    #|              (then
    #|                (local.set 3 (local.get 1))
    #|                (i32.const 7))
    #|              (else
    #|                (local.set 3 (i32.const 5))
    #|                (br $mid)))))
    #|        (local.get 1)))
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 4)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "If", "LocalSet(4)", "LocalGet(4)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing does not rewrite past an owner-only if payload with a direct inner-owner exit plus terminal exit" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (if (result i32) (local.get 0)
    #|              (then
    #|                (return (i32.const 7)))
    #|              (else
    #|                (local.set 3 (i32.const 5))
    #|                (br $mid)))))
    #|        (local.get 1)))
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 1)
    #|    (if
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 4)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "LocalSet(4)", "If", "LocalGet(4)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing does not rewrite past a terminal owner-carrier when an unrelated condition local.set sits before the later if" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $mid
    #|          (br $outer
    #|            (if (result i32) (local.get 0)
    #|              (then
    #|                (return (i32.const 7)))
    #|              (else
    #|                (local.set 3 (i32.const 5))
    #|                (br $mid)))))
    #|        (local.get 1)))
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 0)
    #|    (local.set 5)
    #|    (if (local.get 5)
    #|      (then
    #|        (drop (local.get 1))))
    #|    (local.get 4)))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "LocalSet(4)", "LocalSet(5)", "If", "LocalGet(4)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing does not rewrite past an earlier branch root even when the crossed gap is branch-free" {
  let source = "(module (func (param i32 i32) (result i32) (local i32 i32) block $done local.get 0 br_if $done end local.get 1 local.set 2 i32.const 7 local.set 3 local.get 2 if local.get 2 drop end local.get 3))"
  let func = code_pushing_test_run_hot(source)

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "Block",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)),
    "LocalSet(2)",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)),
    "LocalSet(3)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 4)),
    "LocalGet(3)",
  )

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing does not rewrite a parent-escape carrier with a branch-free crossed gap" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32)
    #|    (block $outer (result i32)
    #|      (block $err
    #|        (block $carrier (result i32)
    #|          (block $work
    #|            (local.get 0)
    #|            (if (result i32)
    #|              (then
    #|                (local.set 2 (local.get 1))
    #|                (local.set 3 (local.get 1))
    #|                (br $work))
    #|              (else
    #|                (local.set 6 (i32.const 9))
    #|                (br $err)))
    #|            unreachable)
    #|          (block $skip
    #|            (br_if $skip (local.get 0)))
    #|          (local.set 4 (local.get 2))
    #|          (local.set 5 (local.get 3))
    #|          (if
    #|            (local.get 4)
    #|            (then
    #|              (call $side (local.get 4))))
    #|          (drop (i32.const 0))
    #|          (local.get 5))
    #|        br $outer)
    #|      (local.get 6))))
    #|)
  let func = code_pushing_test_run_hot_code(source, 1)
  let carrier_body = code_pushing_test_find_block_body_region(func, 1, [
    "Block", "Block", "LocalSet(4)", "LocalSet(5)", "If", "Drop", "LocalGet(5)",
  ])

  assert_eq(code_pushing_test_region_tags(func, carrier_body), [
    "Block", "Block", "LocalSet(4)", "LocalSet(5)", "If", "Drop", "LocalGet(5)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing does not rewrite past an earlier zero-result branch root" {
  let source = "(module (func (param i32 i32) (result i32) (local i32) block $done local.get 0 br_if $done end i32.const 7 local.set 2 local.get 0 if local.get 1 drop end local.get 2))"
  let func = code_pushing_test_run_hot(source)

  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)),
    "Block",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)),
    "LocalSet(2)",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)),
    "LocalGet(2)",
  )

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit local.set if carrier" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 2
    #|      (if (result i32)
    #|        (local.get 0)
    #|        (then
    #|          (local.set 5 (local.get 1))
    #|          (i32.const 7))
    #|        (else
    #|          (local.set 5 (local.get 1))
    #|          (call $side (local.get 1))
    #|          (return (i32.const 9)))))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 4)
    #|    (if
    #|      (then
    #|        (call $side (local.get 4))))
    #|    (local.get 3))
    #|)
  let func = code_pushing_test_run_hot_code(source, 1)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "LocalSet(4)", "If", "LocalSet(3)", "LocalGet(3)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit if root" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (if
    #|      (local.get 0)
    #|      (then
    #|        (local.set 4 (local.get 1))
    #|        (return (i32.const 9))))
    #|    (local.get 1)
    #|    (local.set 2)
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 3)
    #|    (if
    #|      (then
    #|        (call $side (local.get 3))))
    #|    (local.get 2))
    #|)
  let func = code_pushing_test_run_hot_code(source, 1)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "If", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit local.set block carrier when the crossed gap itself is safe" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 2
    #|      (block $block1 (result i32)
    #|        (block $block
    #|          (br $block1
    #|            (if (result i32)
    #|              (local.get 0)
    #|              (then
    #|                (return (i32.const 7)))
    #|              (else
    #|                (local.set 5 (local.get 1))
    #|                (br $block)))))
    #|        (local.get 5)))
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 4)
    #|    (if
    #|      (then
    #|        (call $side (local.get 4))))
    #|    (local.get 3))
    #|)
  let func = code_pushing_test_run_hot_code(source, 1)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "LocalSet(4)", "If", "LocalSet(3)", "LocalGet(3)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit local.set carrier before a loaded condition-set and later if" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $side (param i32))
    #|  (func $join (param i32 i32) (result i32)
    #|    (local.get 0))
    #|  (func (param i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32)
    #|    (local.set 3
    #|      (block $block1 (result i32)
    #|        (block $block
    #|          (br $block1
    #|            (if (result i32)
    #|              (local.get 0)
    #|              (then
    #|                (return (i32.const 7)))
    #|              (else
    #|                (local.set 6 (local.get 1))
    #|                (br $block)))))
    #|        (local.get 6)))
    #|    (local.get 2)
    #|    (local.set 4)
    #|    (i32.load
    #|      (local.get 1))
    #|    (local.set 5)
    #|    (if
    #|      (local.get 0)
    #|      (then
    #|        (call $side (local.get 5)))
    #|      (else
    #|        (if (local.get 0)
    #|          (then
    #|            (call $side (local.get 1))))))
    #|    (local.get 5)
    #|    (local.set 7)
    #|    (call $join
    #|      (local.get 4)
    #|      (local.get 7)))
    #|)
  let func = code_pushing_test_run_hot_code(source, 2)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(3)", "LocalSet(5)", "If", "LocalSet(4)", "LocalSet(7)", "Call",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier explicit-exit local.set block carrier with a call-prefixed inner block when the crossed gap is safe" {
  let source =
    #|(module
    #|  (func $side (param i32))
    #|  (func (param i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (local.set 3
    #|      (block $block1 (result i32)
    #|        (block $block
    #|          (call $side (local.get 2))
    #|          (br $block1
    #|            (if (result i32)
    #|              (local.get 0)
    #|              (then
    #|                (return (i32.const 7)))
    #|              (else
    #|                (local.set 6 (local.get 1))
    #|                (br $block)))))
    #|        (local.get 6)))
    #|    (local.get 1)
    #|    (local.set 4)
    #|    (local.get 1)
    #|    (local.set 5)
    #|    (local.get 5)
    #|    (if
    #|      (then
    #|        (call $side (local.get 5))))
    #|    (local.get 4))
    #|)
  let func = code_pushing_test_run_hot_code(source, 1)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(3)", "LocalSet(5)", "If", "LocalSet(4)", "LocalGet(4)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier dropped result-carrying block root" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $outer (result i32)
    #|      (block $prefix (result i32)
    #|        (block $work
    #|          (if (local.get 0)
    #|            (then
    #|              (br $work))
    #|            (else
    #|              (br $prefix (i32.const 0))))
    #|          unreachable)
    #|        (i32.const 1))
    #|      drop
    #|      (local.get 1)
    #|      (local.set 2)
    #|      (local.get 1)
    #|      (local.set 3)
    #|      (local.get 3)
    #|      (if
    #|        (then
    #|          (drop (local.get 3))))
    #|      (local.get 2)))
    #|)
  let func = code_pushing_test_run_hot(source)
  let mut outer_body : @ir.HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, node_id) == 1 {
          let region = @ir.hot_region_body_ref(func, node_id)
          let tags = code_pushing_test_region_tags(func, region)
          candidate_tags.push(tags.to_string())
          if tags.length() == 5 &&
            tags[0] == "Drop" &&
            tags[4] == "LocalGet(2)" &&
            tags.contains("LocalSet(2)") &&
            tags.contains("LocalSet(3)") &&
            tags.contains("If") {
            outer_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let outer_body = match outer_body {
    Some(region) => region
    None =>
      fail("expected dropped-result-prefix non-void body: \{candidate_tags}")
  }

  assert_eq(code_pushing_test_region_tags(func, outer_body), [
    "Drop", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier self-contained block root" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $prefix
    #|      (block $carry (result i32)
    #|        (block $work
    #|          (if (local.get 0)
    #|            (then
    #|              (br $work))
    #|            (else
    #|              (br $carry (i32.const 0))))
    #|          unreachable)
    #|        (i32.const 1))
    #|      drop)
    #|    (local.get 1)
    #|    (local.set 2)
    #|    (local.get 1)
    #|    (local.set 3)
    #|    (local.get 3)
    #|    (if
    #|      (then
    #|        (drop (local.get 3))))
    #|    (local.get 2))
    #|)
  let func = code_pushing_test_run_hot(source)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "Block", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past an earlier block root that exits a dropped owner" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $holder (result i32)
    #|      (drop
    #|        (block $outer (result i32)
    #|          (block $prefix
    #|            (if (local.get 0)
    #|              (then
    #|                (br $outer (i32.const 0)))
    #|              (else
    #|                (drop (i32.const 0)))))
    #|          (local.get 1)
    #|          (local.set 2)
    #|          (local.get 1)
    #|          (local.set 3)
    #|          (local.get 3)
    #|          (if
    #|            (then
    #|              (drop (local.get 3))))
    #|          (local.get 2)))
    #|      (i32.const 9)))
    #|)
  let func = code_pushing_test_run_hot(source)
  let mut outer_body : @ir.HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, node_id) == 1 {
          let region = @ir.hot_region_body_ref(func, node_id)
          let tags = code_pushing_test_region_tags(func, region)
          candidate_tags.push(tags.to_string())
          if tags.length() == 5 &&
            tags[0] == "Block" &&
            tags[4] == "LocalGet(2)" &&
            tags.contains("LocalSet(2)") &&
            tags.contains("LocalSet(3)") &&
            tags.contains("If") {
            outer_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let outer_body = match outer_body {
    Some(region) => region
    None => fail("expected dropped-owner non-void body: \{candidate_tags}")
  }

  assert_eq(code_pushing_test_region_tags(func, outer_body), [
    "Block", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites a live-like dropped-owner predecessor chain" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $holder (result i32)
    #|      (drop
    #|        (block $outer (result i32)
    #|          (block $prefix
    #|            (if (local.get 0)
    #|              (then
    #|                (call $touch (local.get 1))
    #|                (br $prefix))
    #|              (else
    #|                (if (local.get 0)
    #|                  (then
    #|                    (call $touch (local.get 1))
    #|                    (br $prefix))
    #|                  (else
    #|                    (drop (i32.const 0)))))))
    #|          (br $outer (i32.const 0))
    #|          (call $touch (local.get 1))
    #|          (local.get 1)
    #|          (local.set 2)
    #|          (local.get 1)
    #|          (local.set 3)
    #|          (local.get 3)
    #|          (if
    #|            (then
    #|              (call $touch (local.get 3))))
    #|          (local.get 2)))
    #|      (i32.const 9)))
    #|  (func $touch (param i32)))
    #|)
  let func = code_pushing_test_run_hot(source)
  let mut outer_body : @ir.HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, node_id) == 1 {
          let region = @ir.hot_region_body_ref(func, node_id)
          let tags = code_pushing_test_region_tags(func, region)
          candidate_tags.push(tags.to_string())
          if tags.length() == 7 &&
            tags[0] == "Block" &&
            tags[1] == "Br" &&
            tags[2] == "Call" &&
            tags[6] == "LocalGet(2)" &&
            tags.contains("LocalSet(2)") &&
            tags.contains("LocalSet(3)") &&
            tags.contains("If") {
            outer_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let outer_body = match outer_body {
    Some(region) => region
    None => fail("expected live-like dropped-owner body: \{candidate_tags}")
  }

  assert_eq(code_pushing_test_region_tags(func, outer_body), [
    "Block", "Br", "Call", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing extracts an alias local.set out of a dropped carrier" {
  let source =
    #|(module
    #|  (func $touch (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (block $holder (result i32)
    #|      (drop
    #|        (block $outer (result i32)
    #|          (local.get 1)
    #|          (local.set 4)
    #|          (local.get 4)
    #|          (local.set 2)
    #|          (br $outer (i32.const 0))))
    #|      (local.get 1)
    #|      (local.set 3)
    #|      (local.get 3)
    #|      (if
    #|        (then
    #|          (call $touch (local.get 3))))
    #|      (local.get 2)))
    #|)
  let func = code_pushing_test_run_hot_code(source, 1)
  let mut holder_body : @ir.HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, node_id) == 1 {
          let region = @ir.hot_region_body_ref(func, node_id)
          let tags = code_pushing_test_region_tags(func, region)
          candidate_tags.push(tags.to_string())
          if tags ==
            [
              "Drop", "LocalSet(3)", "If", "LocalSet(4)", "LocalSet(2)", "LocalGet(2)",
            ] {
            holder_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let holder_body = match holder_body {
    Some(region) => region
    None => fail("expected dropped-carrier holder body: \{candidate_tags}")
  }
  let outer = @ir.hot_child_get(
    func,
    @ir.hot_region_get(func, holder_body, 0),
    0,
  )
  let outer_body = @ir.hot_region_body_ref(func, outer)

  assert_eq(code_pushing_test_region_tags(func, holder_body), [
    "Drop", "LocalSet(3)", "If", "LocalSet(4)", "LocalSet(2)", "LocalGet(2)",
  ])
  assert_eq(code_pushing_test_region_tags(func, outer_body), [
    "Nop", "Nop", "Br",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing extracts a call-fed local.set out of a dropped carrier" {
  let source =
    #|(module
    #|  (func $mk (param i32) (result i32)
    #|    (local.get 0))
    #|  (func $touch (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $holder (result i32)
    #|      (drop
    #|        (block $outer (result i32)
    #|          (block $prefix
    #|            nop)
    #|          (local.set 2
    #|            (call $mk
    #|              (local.get 1)))
    #|          (call $touch
    #|            (local.get 1))
    #|          (br $outer
    #|            (i32.const 0))))
    #|      (local.get 1)
    #|      (local.set 3)
    #|      (local.get 3)
    #|      (if
    #|        (then
    #|          (call $touch
    #|            (local.get 3))))
    #|      (local.get 2)))
    #|)
  let func = code_pushing_test_run_hot_code(source, 2)
  let mut holder_body : @ir.HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, node_id) == 1 {
          let region = @ir.hot_region_body_ref(func, node_id)
          let tags = code_pushing_test_region_tags(func, region)
          candidate_tags.push(tags.to_string())
          if tags == ["Drop", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)"] {
            holder_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let holder_body = match holder_body {
    Some(region) => region
    None =>
      fail("expected call-fed dropped-carrier holder body: \{candidate_tags}")
  }
  let outer = @ir.hot_child_get(
    func,
    @ir.hot_region_get(func, holder_body, 0),
    0,
  )
  let outer_body = @ir.hot_region_body_ref(func, outer)

  assert_eq(code_pushing_test_region_tags(func, holder_body), [
    "Drop", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)",
  ])
  assert_eq(code_pushing_test_region_tags(func, outer_body), [
    "Block", "LocalTee(4)", "Call", "Br",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing extracts a call-fed local.set out of a dropped carrier after a safe explicit-exit prefix" {
  let source =
    #|(module
    #|  (func $mk (param i32) (result i32)
    #|    (local.get 0))
    #|  (func $touch (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32)
    #|    (block $holder (result i32)
    #|      (drop
    #|        (block $outer (result i32)
    #|          (local.set 4
    #|            (block $carry (result i32)
    #|              (block $mid
    #|                (br $carry
    #|                  (if (result i32)
    #|                    (local.get 0)
    #|                    (then
    #|                      (local.set 5 (local.get 1))
    #|                      (local.get 5))
    #|                    (else
    #|                      (local.set 5 (i32.const 5))
    #|                      (local.get 5)))))
    #|              (local.get 1)))
    #|          (local.set 2
    #|            (call $mk
    #|              (local.get 1)))
    #|          (call $touch
    #|            (local.get 1))
    #|          (br $outer
    #|            (i32.const 0))))
    #|      (local.get 1)
    #|      (local.set 3)
    #|      (local.get 3)
    #|      (if
    #|        (then
    #|          (call $touch
    #|            (local.get 3))))
    #|      (local.get 2)))
    #|)
  let func = code_pushing_test_run_hot_code(source, 2)
  let mut holder_body : @ir.HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, node_id) == 1 {
          let region = @ir.hot_region_body_ref(func, node_id)
          let tags = code_pushing_test_region_tags(func, region)
          candidate_tags.push(tags.to_string())
          if tags == ["Drop", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)"] {
            holder_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let holder_body = match holder_body {
    Some(region) => region
    None =>
      fail(
        "expected call-fed dropped-carrier holder body with safe prefix: \{candidate_tags}",
      )
  }
  let outer = @ir.hot_child_get(
    func,
    @ir.hot_region_get(func, holder_body, 0),
    0,
  )
  let outer_body = @ir.hot_region_body_ref(func, outer)

  assert_eq(code_pushing_test_region_tags(func, holder_body), [
    "Drop", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)",
  ])
  assert_eq(code_pushing_test_region_tags(func, outer_body), [
    "LocalSet(4)", "LocalTee(6)", "Call", "Br",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing extracts a nested call-fed local.set out of a dropped carrier" {
  let source =
    #|(module
    #|  (func $mk (param i32) (result i32)
    #|    (local.get 0))
    #|  (func $touch (param i32))
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32)
    #|    (block $holder (result i32)
    #|      (drop
    #|        (block $outer (result i32)
    #|          (block $nested
    #|            (local.set 4
    #|              (call $mk
    #|                (local.get 1))))
    #|          (call $touch
    #|            (local.get 1))
    #|          (br $outer
    #|            (i32.const 0))))
    #|      (local.get 1)
    #|      (local.set 3)
    #|      (local.get 3)
    #|      (if
    #|        (then
    #|          (call $touch
    #|            (local.get 3))))
    #|      (local.get 4)))
    #|)
  let func = code_pushing_test_run_hot_code(source, 2)
  let mut holder_body : @ir.HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, node_id) == 1 {
          let region = @ir.hot_region_body_ref(func, node_id)
          let tags = code_pushing_test_region_tags(func, region)
          candidate_tags.push(tags.to_string())
          if tags == ["Drop", "LocalSet(3)", "If", "LocalSet(4)", "LocalGet(4)"] {
            holder_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let holder_body = match holder_body {
    Some(region) => region
    None =>
      fail(
        "expected nested call-fed dropped-carrier holder body: \{candidate_tags}",
      )
  }
  let outer = @ir.hot_child_get(
    func,
    @ir.hot_region_get(func, holder_body, 0),
    0,
  )
  let outer_body = @ir.hot_region_body_ref(func, outer)
  let nested = @ir.hot_region_get(func, outer_body, 0)
  let nested_body = @ir.hot_region_body_ref(func, nested)

  assert_eq(code_pushing_test_region_tags(func, holder_body), [
    "Drop", "LocalSet(3)", "If", "LocalSet(4)", "LocalGet(4)",
  ])
  assert_eq(code_pushing_test_region_tags(func, outer_body), [
    "Block", "Call", "Br",
  ])
  assert_eq(code_pushing_test_region_tags(func, nested_body), ["LocalTee(5)"])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing rewrites past a self-and-dropped-owner block root" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    (block $holder (result i32)
    #|      (drop
    #|        (block $outer (result i32)
    #|          (block $prefix
    #|            (if (local.get 0)
    #|              (then
    #|                (call $touch (local.get 1))
    #|                (br $prefix))
    #|              (else
    #|                (if (local.get 0)
    #|                  (then
    #|                    (call $touch (local.get 1))
    #|                    (br $prefix))
    #|                  (else
    #|                    (drop (i32.const 0))))))
    #|            (br $outer (i32.const 0)))
    #|          (call $touch (local.get 1))
    #|          (local.get 1)
    #|          (local.set 2)
    #|          (local.get 1)
    #|          (local.set 3)
    #|          (local.get 3)
    #|          (if
    #|            (then
    #|              (call $touch (local.get 3))))
    #|          (local.get 2)))
    #|      (i32.const 9)))
    #|  (func $touch (param i32)))
    #|)
  let func = code_pushing_test_run_hot(source)
  let mut outer_body : @ir.HotRegionRef? = None
  let candidate_tags : Array[String] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, node_id) == 1 {
          let region = @ir.hot_region_body_ref(func, node_id)
          let tags = code_pushing_test_region_tags(func, region)
          candidate_tags.push(tags.to_string())
          if tags.length() == 6 &&
            tags[0] == "Block" &&
            tags[1] == "Call" &&
            tags[5] == "LocalGet(2)" &&
            tags.contains("LocalSet(2)") &&
            tags.contains("LocalSet(3)") &&
            tags.contains("If") {
            outer_body = Some(region)
            break
          }
        }
      _ => ()
    }
  }
  let outer_body = match outer_body {
    Some(region) => region
    None => fail("expected self-and-dropped-owner body: \{candidate_tags}")
  }

  assert_eq(code_pushing_test_region_tags(func, outer_body), [
    "Block", "Call", "LocalSet(3)", "If", "LocalSet(2)", "LocalGet(2)",
  ])

  match pass_test_run_pipeline(source, ["code-pushing"]) {
    Ok(_) => ()
    Err(err) => fail(err)
  }
}

///|
test "code-pushing does not rewrite a parent-exit payload-carry shape" {
  let source = "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $exit (block $work (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 2 (local.get 1)) (br $work)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (br $outer (local.get 2))) (i32.const 0))))"
  let func = code_pushing_test_run_hot(source)
  let exit_body = code_pushing_test_find_block_body_region(func, 0, [
    "Block", "Br",
  ])
  let work = @ir.hot_region_get(func, exit_body, 0)
  let work_body = @ir.hot_region_body_ref(func, work)

  assert_eq(code_pushing_test_region_tags(func, exit_body), ["Block", "Br"])
  assert_eq(code_pushing_test_region_tags(func, work_body), [
    "If", "Unreachable",
  ])
}

///|
test "code-pushing does not extract a carrier payload through a parent err block" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $incref (param i32))
    #|  (func $decref (param i32))
    #|  (func $decode (param i32 i32) (result i32)
    #|    local.get 0)
    #|  (func $get_tag (param i32) (result i32)
    #|    i32.const 1)
    #|  (func (param i32 i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (block $outer (result i32)
    #|      (block $err
    #|        (block $carrier (result i32)
    #|          (block $work
    #|            (local.get 1)
    #|            (i32.load offset=8 align=1)
    #|            (local.tee 4)
    #|            (i32.const 1)
    #|            i32.add
    #|            (local.set 5)
    #|            (local.get 0)
    #|            (call $incref)
    #|            (local.get 0)
    #|            (local.get 5)
    #|            (call $decode)
    #|            (local.tee 6)
    #|            (call $get_tag)
    #|            (i32.const 1)
    #|            i32.eq
    #|            (if (result i32)
    #|              (then
    #|                (local.get 6)
    #|                (i32.load offset=12 align=1)
    #|                (local.set 7)
    #|                (local.get 6)
    #|                (i32.load offset=8 align=1)
    #|                (local.set 8)
    #|                (local.get 7)
    #|                (local.get 8)
    #|                (local.set 3)
    #|                (local.set 2)
    #|                (br $work))
    #|              (else
    #|                (local.get 0)
    #|                (call $decref)
    #|                (local.get 2)
    #|                (call $decref)
    #|                (local.get 3)
    #|                (call $decref)
    #|                (local.get 1)
    #|                (call $decref)
    #|                (local.get 6)
    #|                (i32.load offset=8 align=1)
    #|                (local.set 9)
    #|                (br $err)))
    #|            unreachable)
    #|          (local.get 2)
    #|          (local.set 5)
    #|          (local.get 2)
    #|          (if
    #|            (then
    #|              (local.get 2)
    #|              (call $decref)))
    #|          (local.get 1)
    #|          (local.get 5)
    #|          (i32.store offset=8 align=1)
    #|          (i32.const 0)
    #|          drop
    #|          (local.get 3))
    #|        br $outer)
    #|      (local.get 9))))
    #|)
  let func = code_pushing_test_run_hot_code(source, 4)
  let real = code_pushing_test_find_real_carrier_fixture(func)

  assert_eq(code_pushing_test_region_tags(func, real.err_body), ["Br"])
  assert_eq(code_pushing_test_region_tags(func, real.carrier_body), [
    "Block", "LocalSet(5)", "If", "Store", "Drop", "LocalGet(3)",
  ])
}

///|
test "code-pushing can move a local.set fed by an earlier local.tee past an if" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32) (local i32 i32 i32) i32.const 8 local.tee 3 drop local.get 3 local.set 2 local.get 0 local.set 1 local.get 0 if local.get 1 drop else local.get 1 drop end block local.get 2 drop local.get 2 drop end local.get 2 drop))",
  )

  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 0)), "Drop")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 1)),
    "LocalSet(1)",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 2)), "If")
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 3)),
    "LocalSet(2)",
  )
  assert_eq(
    code_pushing_test_node_tag(func, @ir.hot_root_get(func, 4)),
    "Block",
  )
  assert_eq(code_pushing_test_node_tag(func, @ir.hot_root_get(func, 5)), "Drop")
}

///|
test "code-pushing moves a tee-fed local.set after an if even with a later kept condition local.set before the if" {
  let func = code_pushing_test_run_hot(
    "(module (func (param i32 i32) (local i32 i32 i32) local.get 0 local.tee 4 drop local.get 4 local.set 2 local.get 1 local.set 3 local.get 3 if local.get 3 drop end local.get 2 drop local.get 3 drop))",
  )

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "Drop", "LocalSet(3)", "If", "LocalSet(2)", "Drop", "Drop",
  ])
}

///|
test "code-pushing moves an alias local.set after an if when a kept loaded local.set still sits before the if" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $alloc (param i32) (result i32)
    #|    i32.const 0)
    #|  (func $use (param i32))
    #|  (func (param i32)
    #|    (local i32 i32 i32 i32 i32)
    #|    i32.const 10016
    #|    local.set 2
    #|    i32.const 8
    #|    call $alloc
    #|    local.tee 4
    #|    i32.const 1573120
    #|    i32.store offset=4
    #|    local.get 4
    #|    i32.const 0
    #|    i32.store offset=8
    #|    local.get 4
    #|    local.get 2
    #|    i32.store offset=12
    #|    local.get 4
    #|    local.set 1
    #|    local.get 0
    #|    i32.load offset=8
    #|    local.set 3
    #|    local.get 0
    #|    i32.load
    #|    i32.const 1
    #|    i32.gt_s
    #|    if
    #|      local.get 3
    #|      call $use
    #|    end
    #|    local.get 3
    #|    local.tee 5
    #|    i32.load offset=8
    #|    drop
    #|    local.get 1
    #|    drop))
    #|
  let func = code_pushing_test_run_hot_code(source, 2)

  assert_eq(code_pushing_test_region_tags(func, @ir.HotRegionRef::root()), [
    "LocalSet(2)", "Store", "Store", "Store", "LocalSet(3)", "If", "LocalSet(1)",
    "Drop", "Drop",
  ])
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
