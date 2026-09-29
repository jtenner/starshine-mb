///|
fn sl_get_count_cache_fixture(
  width : Int,
  reads : Int,
  locals_count? : Int = 1,
) -> @ir.HotFunc {
  let body = ["(module (func (result i32) (local"]
  for _ in 0..<locals_count {
    body.push("i32")
  }
  body.push(")")
  for _ in 0..<width {
    body.push("i32.const 7 local.set 0")
  }
  for _ in 1..<reads {
    body.push("local.get 0 drop")
  }
  body.push("local.get 0))")
  let input = pass_test_module_from_wat(body.join(" "))
  @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
}

///|
test "SL shares local read counting across unchanged stages with independent consumer snapshots" {
  let func = sl_get_count_cache_fixture(64, 3)
  let cache = SimplifyLocalsGetCounts::new()
  let scans = [0]
  let first = cache.snapshot(func, full_scans=Some(scans))
  assert_eq(first, [3])
  first[0] = 99
  assert_eq(cache.snapshot(func, full_scans=Some(scans)), [3])
  assert_eq(scans[0], 1)
  @ir.hot_verify_all(func).unwrap()
}

///|
test "SL cached read counts invalidate when locals or live node membership change" {
  let func = sl_get_count_cache_fixture(64, 1)
  let cache = SimplifyLocalsGetCounts::new()
  let scans = [0]
  assert_eq(cache.snapshot(func, full_scans=Some(scans)), [1])
  let local = @ir.hot_append_body_local(func, @lib.ValType::i32())
  let old = @ir.hot_root_get(func, @ir.hot_root_count(func) - 1)
  let replacement = @ir.hot_build_local_get(func, local)
  ignore(
    @ir.hot_root_splice(func, @ir.hot_root_count(func) - 1, 1, [replacement]),
  )
  assert_eq(
    cache.snapshot(func, full_scans=Some(scans)),
    simplify_locals_count_local_gets(func),
  )
  assert_eq(scans[0], 2)
  assert_eq(cache.snapshot(func, full_scans=Some(scans)), [1, 1])
  assert_eq(scans[0], 2)
  @ir.hot_delete_detached_node(func, old)
  assert_eq(cache.snapshot(func, full_scans=Some(scans)), [0, 1])
  assert_eq(scans[0], 3)
  @ir.hot_verify_all(func).unwrap()
}

///|
test "SL read count reuse never crosses function identities with equal revisions" {
  let functions : Array[@ir.HotFunc] = []
  for read in [0, 1] {
    let body = ["(module (func (result i32) (local i32 i32)"]
    for _ in 0..<64 {
      body.push("i32.const 7 local.set 0")
    }
    body.push("local.get \{read}))")
    functions.push(
      @ir.hot_lift_func(
        pass_test_module_from_wat(body.join(" ")),
        @lib.FuncIdx::new(0U),
      ),
    )
  }
  let first = functions[0]
  let second = functions[1]
  assert_eq(@ir.hot_revision_current(first), @ir.hot_revision_current(second))
  assert_eq(@ir.hot_node_count(first), @ir.hot_node_count(second))
  assert_eq(@ir.hot_local_count(first), @ir.hot_local_count(second))
  let cache = SimplifyLocalsGetCounts::new()
  let scans = [0]
  assert_eq(cache.snapshot(first, full_scans=Some(scans)), [1, 0])
  assert_eq(cache.snapshot(second, full_scans=Some(scans)), [0, 1])
  assert_eq(scans[0], 2)
  @ir.hot_verify_all(first).unwrap()
  @ir.hot_verify_all(second).unwrap()
}

///|
test "SL count snapshots use direct scanning for intentionally sparse large local declarations" {
  let func = sl_get_count_cache_fixture(16, 3, locals_count=128)
  // Copying a complete local row twice is a poor trade when the body is small.
  let cache = simplify_locals_new_get_count_cache(func)
  assert_true(cache is None)
  let expected = simplify_locals_count_local_gets(func)
  assert_eq(expected.length(), 128)
  assert_eq(expected[0], 3)
  let first = simplify_locals_counts_for_cycle(func, cache)
  first[0] = 99
  assert_eq(simplify_locals_counts_for_cycle(func, cache), expected)
  @ir.hot_verify_all(func).unwrap()
}

///|
test "SL main and dead cleanup share unchanged read counts without changing the function" {
  let wat = ["(module (func (param i32) (result i32)"]
  for _ in 0..<32 {
    wat.push("local.get 0 drop")
  }
  wat.push("local.get 0))")
  let input = pass_test_module_from_wat(wat.join(" "))
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let saved = @ir.hot_lower_func(func)
  let cache = simplify_locals_new_get_count_cache(func)
  assert_true(cache is Some(_))
  let scans = [0]
  let detached : Array[Int] = []
  let (changed, _) = simplify_locals_run_main_cycle(
    simplify_locals_wbtest_ctx(),
    func,
    true,
    detached,
    SimplifyLocalsPolicy::new(true, true, true),
    false,
    get_count_cache=cache,
    get_count_scans=Some(scans),
  )
  assert_false(changed)
  simplify_locals_delete_detached_nodes(func, detached)
  assert_false(
    simplify_locals_run_dead_cleanup(
      simplify_locals_wbtest_ctx(),
      func,
      [],
      [],
      true,
      get_count_cache=cache,
      get_count_scans=Some(scans),
    ),
  )
  assert_eq(scans[0], 1)
  assert_eq(@ir.hot_lower_func(func), saved)
  assert_eq(simplify_locals_count_local_gets(func), [33])
  @ir.hot_verify_all(func).unwrap()
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([saved]))).unwrap()
}

///|
fn sl_get_count_policies() -> Array[(String, SimplifyLocalsPolicy)] {
  [
    ("simplify-locals", SimplifyLocalsPolicy::new(true, true, true)),
    (
      "simplify-locals-nonesting",
      SimplifyLocalsPolicy::new(false, false, false),
    ),
    ("simplify-locals-notee", SimplifyLocalsPolicy::new(true, false, true)),
    (
      "simplify-locals-nostructure",
      SimplifyLocalsPolicy::new(false, true, true),
    ),
    (
      "simplify-locals-notee-nostructure",
      SimplifyLocalsPolicy::new(false, false, true),
    ),
  ]
}

///|
fn sl_get_count_run_fixture(
  input : @lib.Module,
  policy : SimplifyLocalsPolicy,
  reuse : Bool,
  protected? : Bool = false,
) -> @lib.Module {
  let context = @ir.hot_module_context_from_module(input)
  let func = @ir.hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(0U),
    context,
  ).unwrap()
  let ctx = HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(context),
  )
  if protected {
    ignore(
      simplify_locals_run_control_embedded_tee_root_only(
        ctx,
        func,
        policy,
        reuse_get_counts=reuse,
      ),
    )
  } else {
    ignore(
      simplify_locals_run_with_options(
        ctx,
        func,
        policy,
        reuse_get_counts=reuse,
      ),
    )
  }
  @ir.hot_verify_all(func).unwrap()
  input.with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)]))
}

///|
fn sl_get_count_active_fixture(width : Int) -> @lib.Module {
  let wat = [
    "(module (func (export \"run\") (param i32) (result i32) (local i32 i32) local.get 0 i32.const 1 i32.add local.set 1 local.get 1 local.set 2 local.get 2 drop",
  ]
  for _ in 0..<width {
    wat.push("local.get 0 drop")
  }
  wat.push("local.get 0))")
  pass_test_module_from_wat(wat.join(" "))
}

///|
test "SL cached cleanup matches uncached active transforms in all five modes" {
  let input = sl_get_count_active_fixture(32)
  let saved = @binary.encode_module(input).unwrap()
  for (name, policy) in sl_get_count_policies() {
    let reference = sl_get_count_run_fixture(input, policy, false)
    let output = sl_get_count_run_fixture(input, policy, true)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_false(output.code_sec == input.code_sec)
    @validate.validate_module(output).unwrap()
    let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [name]).unwrap()
    assert_false(dispatched.code_sec == input.code_sec)
    @validate.validate_module(dispatched).unwrap()
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "SL cached read facts preserve effects, typed loop carriers and tuple producers" {
  let sources = [
    "(module (memory 1) (global $g (mut i32) (i32.const 0)) (func (param i32) (result i32) (local i32 i32) local.get 0 i32.load local.set 1 i32.const 0 i32.const 7 i32.store local.get 1 local.set 2 local.get 2 global.set $g local.get 1))",
    "(module (func (param i32) (result i32) (local i32) i32.const 3 local.set 1 local.get 0 loop (param i32) (result i32) local.set 1 local.get 1 i32.const 1 i32.sub local.tee 1 local.get 1 br_if 0 end local.get 1 i32.add))",
    "(module (func (param i32) (result i32) (local i32 i32) block (result i32 i32) local.get 0 i32.const 7 end local.set 2 local.set 1 local.get 1 local.get 2 i32.add))",
  ]
  for source in sources {
    let input = pass_test_module_from_wat(source)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    for (_, policy) in sl_get_count_policies() {
      let reference = sl_get_count_run_fixture(input, policy, false)
      let output = sl_get_count_run_fixture(input, policy, true)
      assert_eq(
        @binary.encode_module(output).unwrap(),
        @binary.encode_module(reference).unwrap(),
      )
      @validate.validate_module(output).unwrap()
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "SL cached protected-control cleanup preserves embedded tees and cleans unrelated roots" {
  let wat = [
    "(module (func (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 local.get 1 local.set 2 local.get 2 drop block local.get 0 local.tee 1 drop end",
  ]
  for _ in 0..<32 {
    wat.push("local.get 0 drop")
  }
  wat.push("local.get 0))")
  let input = pass_test_module_from_wat(wat.join(" "))
  let saved = @binary.encode_module(input).unwrap()
  for (_, policy) in sl_get_count_policies() {
    let reference = sl_get_count_run_fixture(
      input,
      policy,
      false,
      protected=true,
    )
    let output = sl_get_count_run_fixture(input, policy, true, protected=true)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    @validate.validate_module(output).unwrap()
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
