///|
fn sl_flat_statement_bench(
  it : @bench.T,
  width : Int,
  control : Bool,
  reference : Bool,
) -> Unit raise {
  let leaves = sl_prefix_fixture(width)
  let body = if control {
    [@lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(leaves))]
  } else {
    leaves
  }
  let env = @validate.Env::new()
  let expected = sl_flat_statement_reference(body, 0, env)
  let actual = run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
    body,
    env,
    false,
    flat_only=true,
  )
  assert_eq(actual, expected)
  it.bench(fn() {
    it.keep(
      if reference {
        sl_flat_statement_reference(body, 0, env)
      } else {
        run_hot_pipeline_raw_simplify_locals_statement_prefix_end(
          body,
          env,
          false,
          flat_only=true,
        )
      },
    )
  })
}

///|
test "bench flat statement width=1 rejected control original" (it : @bench.T) {
  sl_flat_statement_bench(it, 1, true, true)
}

///|
test "bench flat statement width=1 rejected control early" (it : @bench.T) {
  sl_flat_statement_bench(it, 1, true, false)
}

///|
test "bench flat statement width=1024 rejected control original" (it : @bench.T) {
  sl_flat_statement_bench(it, 1024, true, true)
}

///|
test "bench flat statement width=1024 rejected control early" (it : @bench.T) {
  sl_flat_statement_bench(it, 1024, true, false)
}

///|
test "bench flat statement width=1 admitted flat original" (it : @bench.T) {
  sl_flat_statement_bench(it, 1, false, true)
}

///|
test "bench flat statement width=1 admitted flat early" (it : @bench.T) {
  sl_flat_statement_bench(it, 1, false, false)
}

///|
test "bench flat statement width=1024 admitted flat original" (it : @bench.T) {
  sl_flat_statement_bench(it, 1024, false, true)
}

///|
test "bench flat statement width=1024 admitted flat early" (it : @bench.T) {
  sl_flat_statement_bench(it, 1024, false, false)
}
