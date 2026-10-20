///|
fn code_folding_exit_index_test_ctx() -> HotPassContext {
  HotPassContext::new(
    code_folding_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
fn code_folding_exit_index_fixture(count : Int32) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (import \"env\" \"a\" (func $a)) (import \"env\" \"b\" (func $b)) (func (param i32)",
  )
  for _ in 0..<count {
    wat.write_string(
      " (block $out (if (local.get 0) (then call $a br $out)) call $a)",
    )
  }
  wat.write_string("))")
  pass_test_module_from_wat(wat.to_string())
}

///|
test "CodeFolding revalidates cached exit branch after root insertion" {
  let func = @ir.hot_lift_func(
    pass_test_module_from_wat(
      "(module (import \"env\" \"a\" (func $a)) (import \"env\" \"b\" (func $b)) (func (param i32) (block $out (if (local.get 0) (then call $a br $out) (else call $a br $out)))))",
    ),
    @lib.FuncIdx::new(2U),
  )
  let ctx = code_folding_exit_index_test_ctx()
  let root = @ir.HotRegionRef::root()
  let block = @ir.hot_region_get(func, root, 0)
  let body = @ir.hot_region_body_ref(func, block)
  let if_id = @ir.hot_region_get(func, body, 0)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id).unwrap()
  let label_used = pass_compute_label_used(func)
  let index = code_folding_build_block_exit_index(func, label_used)
  // Both paths now run b, a. The saved branch offset points to a, not br.
  ignore(
    pass_splice_region(ctx, func, then_ref, 0, 0, [
      @ir.hot_build_call(func, 1, [], []),
    ]),
  )
  ignore(
    pass_splice_region(ctx, func, else_ref, 0, 0, [
      @ir.hot_build_call(func, 1, [], []),
    ]),
  )
  assert_true(
    code_folding_try_fold_block_exit_at_region(
      ctx, func, root, 0, label_used, index,
    ),
  )
  assert_eq(@ir.hot_region_root_count(func, root), 3)
  assert_eq(@ir.hot_node_get(func, @ir.hot_region_get(func, root, 1)).imm0, 1)
  assert_eq(@ir.hot_node_get(func, @ir.hot_region_get(func, root, 2)).imm0, 0)
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected valid shifted exit-tail rewrite: \{err}")
  }
}

///|
test "CodeFolding preserves effect order after nested suffix shifts exit branches" {
  let input =
    #|(module
    #| (import "env" "a" (func $a))
    #| (import "env" "b" (func $b))
    #| (import "env" "c" (func $c))
    #| (func (export "run") (param i32 i32)
    #|  (block $out
    #|   (if (local.get 0)
    #|    (then
    #|     (if (local.get 1) (then call $b call $a) (else call $c call $a))
    #|     br $out))
    #|   (if (local.get 1) (then call $b) (else call $c)))))
  let output = pass_test_run_pipeline(input, ["code-folding"]).unwrap()
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(err) => fail("expected valid nested exit-tail rewrite: \{err}")
  }
  let func = @ir.hot_lift_func(output, @lib.FuncIdx::new(3U))
  let root = @ir.HotRegionRef::root()
  assert_eq(@ir.hot_region_root_count(func, root), 1)
  let block = @ir.hot_region_get(func, root, 0)
  let body = @ir.hot_region_body_ref(func, block)
  let branch_if = @ir.hot_region_get(func, body, 0)
  let then_ref = @ir.hot_region_then_ref(func, branch_if)
  assert_true(
    @ir.hot_node_get(func, @ir.hot_region_get(func, then_ref, 0)).op
    is @ir.HotOp::If,
  )
  let call_a = @ir.hot_region_get(func, then_ref, 1)
  assert_true(@ir.hot_node_get(func, call_a).op is @ir.HotOp::Call)
  assert_eq(@ir.hot_node_get(func, call_a).imm0, 0)
}

///|
test "CodeFolding completes independent block exit folds in one region walk" {
  let func = @ir.hot_lift_func(
    code_folding_exit_index_fixture(4),
    @lib.FuncIdx::new(2U),
  )
  let ctx = code_folding_exit_index_test_ctx()
  let label_used = pass_compute_label_used(func)
  let index = code_folding_build_block_exit_index(func, label_used)
  assert_true(
    code_folding_visit_region(
      ctx,
      func,
      @ir.HotRegionRef::root(),
      label_used,
      false,
      index,
    ),
  )
  for idx in 0..<4 {
    let call = @ir.hot_region_get(func, @ir.HotRegionRef::root(), idx * 2 + 1)
    assert_true(@ir.hot_node_get(func, call).op is @ir.HotOp::Call)
    assert_eq(@ir.hot_node_get(func, call).imm0, 0)
  }
}

///|
// Equal work counts let the external allocator probe compare both paths.
fn code_folding_review_measure(it : @bench.T, work : () -> Unit) -> Unit {
  if @env.get_env_var("STARSHINE_PASS_REVIEW_FIXED") == Some("1") {
    for _ in 0..<64 {
      work()
    }
  } else if @env.get_env_var("STARSHINE_PASS_REVIEW_FIXED") != Some("0") {
    it.bench(work)
  }
}

///|
fn code_folding_independent_exit_bench(it : @bench.T, count : Int32) -> Unit {
  let fixture = code_folding_exit_index_fixture(count)
  let ctx = code_folding_exit_index_test_ctx()
  code_folding_review_measure(it, fn() {
    let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(2U))
    ignore(code_folding_run(ctx, func))
    it.keep(func)
  })
}

///|
test "bench code-folding independent exits count=64" (it : @bench.T) {
  code_folding_independent_exit_bench(it, 64)
}

///|
test "bench code-folding independent exits count=256" (it : @bench.T) {
  code_folding_independent_exit_bench(it, 256)
}

///|
fn code_folding_nested_exit_bench(
  it : @bench.T,
  depth : Int32,
  reference~ : Bool = false,
) -> Unit {
  let wat = StringBuilder::new()
  wat.write_string("(module (func")
  for _ in 0..<depth {
    wat.write_string(" block")
  }
  wat.write_string(" return")
  for _ in 0..<depth {
    wat.write_string(" end")
  }
  wat.write_string("))")
  let func = pass_test_lift_first_func(wat.to_string())
  let block = @ir.hot_region_get(func, @ir.HotRegionRef::root(), 0)
  code_folding_review_measure(it, fn() {
    it.keep(
      if reference {
        code_folding_nested_exit_reference(func, block)
      } else {
        code_folding_node_always_exits(
          func,
          block,
          pass_compute_label_used(func),
        )
      },
    )
  })
}

///|
test "bench code-folding nested exit depth=64" (it : @bench.T) {
  code_folding_nested_exit_bench(it, 64)
}

///|
test "bench code-folding nested exit depth=256" (it : @bench.T) {
  code_folding_nested_exit_bench(it, 256)
}

///|
test "bench code-folding nested exit reference depth=64" (it : @bench.T) {
  code_folding_nested_exit_bench(it, 64, reference=true)
}

///|
test "bench code-folding nested exit reference depth=256" (it : @bench.T) {
  code_folding_nested_exit_bench(it, 256, reference=true)
}
