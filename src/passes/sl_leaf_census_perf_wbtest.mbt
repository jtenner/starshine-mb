///|
fn sl_leaf_census_bench(
  it : @bench.T,
  width : Int,
  depth : Int,
  active : Bool,
  reference : Bool,
) -> Unit raise {
  let leaves = Array::makei(width, fn(_) {
    let mut text = if active {
      "local.get 0 if (result i32) i32.const 7 else i32.const 9 end drop"
    } else {
      "local.get 0 i32.const 1 i32.add drop"
    }
    for _ in 0..<depth {
      text = "block \{text} end"
    }
    text
  }).join(" ")
  let input = pass_test_module_from_wat("(module (func (param i32) \{leaves}))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let params = [@lib.ValType::i32()]
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, body)
  let expected = run_hot_pipeline_raw_simplify_locals_rewrite_leaf_conditional_assignments_worker(
    body, params, locals,
  )
  let actual = run_hot_pipeline_raw_simplify_locals_rewrite_leaf_conditional_assignments(
    body,
    params,
    locals,
    stats~,
  )
  assert_eq(actual, expected)
  assert_eq(actual.1, if active { width } else { 0 })
  assert_eq(physical_equal(actual.0, body), !active)
  it.bench(fn() {
    it.keep(
      if reference {
        run_hot_pipeline_raw_simplify_locals_rewrite_leaf_conditional_assignments_worker(
          body, params, locals,
        )
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_leaf_conditional_assignments(
          body,
          params,
          locals,
          stats~,
        )
      },
    )
  })
}

///|
test "bench leaf conditional width=1 depth=0 unchanged original" (it : @bench.T) {
  sl_leaf_census_bench(it, 1, 0, false, true)
}

///|
test "bench leaf conditional width=1 depth=0 unchanged census" (it : @bench.T) {
  sl_leaf_census_bench(it, 1, 0, false, false)
}

///|
test "bench leaf conditional width=256 depth=0 unchanged original" (
  it : @bench.T,
) {
  sl_leaf_census_bench(it, 256, 0, false, true)
}

///|
test "bench leaf conditional width=256 depth=0 unchanged census" (it : @bench.T) {
  sl_leaf_census_bench(it, 256, 0, false, false)
}

///|
test "bench leaf conditional width=32 depth=8 unchanged original" (
  it : @bench.T,
) {
  sl_leaf_census_bench(it, 32, 8, false, true)
}

///|
test "bench leaf conditional width=32 depth=8 unchanged census" (it : @bench.T) {
  sl_leaf_census_bench(it, 32, 8, false, false)
}

///|
test "bench leaf conditional width=32 depth=8 active original" (it : @bench.T) {
  sl_leaf_census_bench(it, 32, 8, true, true)
}

///|
test "bench leaf conditional width=32 depth=8 active census" (it : @bench.T) {
  sl_leaf_census_bench(it, 32, 8, true, false)
}
