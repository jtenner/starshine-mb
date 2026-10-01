///|
fn sl_type_seed_bench_run(
  body : Array[@lib.Instruction],
  env : @validate.Env,
  queries : Int,
  reuse : Bool,
) -> Int {
  let mut seed : SlStatementTypeSeed? = None
  let mut completed = 0
  for query in 0..<queries {
    if reuse && query > 0 && seed is None && env.locals.length() >= 128 {
      seed = Some(SlStatementTypeSeed::new(env))
    }
    let state = match seed {
      Some(seed) => seed.fresh_state()
      None =>
        if reuse {
          @validate.make_state_owned(env, [])
        } else {
          @validate.make_state(env, [])
        }
    }
    match @validate.Typecheck::typecheck(@lib.Expr::new(body), state) {
      Ok(state) =>
        if state.reachable && state.stack.is_empty() {
          completed += 1
        }
      Err(_) => abort("invalid statement benchmark")
    }
  }
  completed
}

///|
fn sl_type_seed_bench(
  it : @bench.T,
  locals : Int,
  queries : Int,
  reuse : Bool,
) -> Unit raise {
  let env = sl_type_seed_env(locals)
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let saved = body.copy()
  assert_eq(sl_type_seed_bench_run(body, env, queries, false), queries)
  assert_eq(sl_type_seed_bench_run(body, env, queries, true), queries)
  it.bench(fn() { it.keep(sl_type_seed_bench_run(body, env, queries, reuse)) })
  assert_eq(body, saved)
}

///|
test "bench statement type seed locals=8 queries=1 fresh" (it : @bench.T) {
  sl_type_seed_bench(it, 8, 1, false)
}

///|
test "bench statement type seed locals=8 queries=1 reuse" (it : @bench.T) {
  sl_type_seed_bench(it, 8, 1, true)
}

///|
test "bench statement type seed locals=8 queries=32 fresh" (it : @bench.T) {
  sl_type_seed_bench(it, 8, 32, false)
}

///|
test "bench statement type seed locals=8 queries=32 reuse" (it : @bench.T) {
  sl_type_seed_bench(it, 8, 32, true)
}

///|
test "bench statement type seed locals=128 queries=1 fresh" (it : @bench.T) {
  sl_type_seed_bench(it, 128, 1, false)
}

///|
test "bench statement type seed locals=128 queries=1 reuse" (it : @bench.T) {
  sl_type_seed_bench(it, 128, 1, true)
}

///|
test "bench statement type seed locals=128 queries=32 fresh" (it : @bench.T) {
  sl_type_seed_bench(it, 128, 32, false)
}

///|
test "bench statement type seed locals=128 queries=32 reuse" (it : @bench.T) {
  sl_type_seed_bench(it, 128, 32, true)
}

///|
test "bench statement type seed locals=8192 queries=1 fresh" (it : @bench.T) {
  sl_type_seed_bench(it, 8192, 1, false)
}

///|
test "bench statement type seed locals=8192 queries=1 reuse" (it : @bench.T) {
  sl_type_seed_bench(it, 8192, 1, true)
}

///|
test "bench statement type seed locals=8192 queries=32 fresh" (it : @bench.T) {
  sl_type_seed_bench(it, 8192, 32, false)
}

///|
test "bench statement type seed locals=8192 queries=32 reuse" (it : @bench.T) {
  sl_type_seed_bench(it, 8192, 32, true)
}

///|
fn sl_type_seed_balanced_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit raise {
  let locals = Array::make(width, "i32").join(" ")
  let middle = Array::makei(32, fn(i) { "local.get \{i + 1} call $consume" }).join(
    " ",
  )
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (local \{locals}) call $produce local.set 0 \{middle} local.get 0 call $consume))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let env = @validate.Env::new().with_module(input).with_locals(local_types)
  let expected = sl_balanced_tree_reference_flat(body, env)
  let actual = run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets_flat(
    body, env,
  )
  assert_eq(actual, expected)
  assert_eq(actual.1, 1)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(local_types, @lib.Expr::new(actual.0))]),
    ),
  ).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        sl_balanced_tree_reference_flat(body, env)
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets_flat(
          body, env,
        )
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench seeded balanced cleanup locals=128 reference" (it : @bench.T) {
  sl_type_seed_balanced_bench(it, 128, true)
}

///|
test "bench seeded balanced cleanup locals=128 reuse" (it : @bench.T) {
  sl_type_seed_balanced_bench(it, 128, false)
}

///|
test "bench seeded balanced cleanup locals=8192 reference" (it : @bench.T) {
  sl_type_seed_balanced_bench(it, 8192, true)
}

///|
test "bench seeded balanced cleanup locals=8192 reuse" (it : @bench.T) {
  sl_type_seed_balanced_bench(it, 8192, false)
}
