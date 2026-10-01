///|
fn sl_compound_seed_batch(
  body : Array[@lib.Instruction],
  env : @validate.Env,
  queries : Int,
  reuse : Bool,
) -> Int {
  let mut seed : SlStatementTypeSeed? = None
  let mut completed = 0
  let wide_environment = reuse && env.locals.length() >= 128
  let mut checked_compound = false
  for _ in 0..<queries {
    let suffix = if reuse {
      let compound = wide_environment &&
        !run_hot_pipeline_raw_simplify_locals_instr_is_pure_movable_value(
          body[body.length() - 1],
        )
      if compound && checked_compound && seed is None && wide_environment {
        seed = Some(SlStatementTypeSeed::new(env))
      }
      checked_compound = checked_compound || compound
      sl_value_suffix_at_with_seed(
        body,
        body.length(),
        1,
        env,
        seed,
        None,
        None,
      )
    } else {
      sl_compound_suffix_reference(body, body.length(), 1, env)
    }
    completed += suffix.length()
  }
  completed
}

///|
fn sl_compound_seed_bench(
  it : @bench.T,
  locals : Int,
  queries : Int,
  leaf : Bool,
  reuse : Bool,
) -> Unit raise {
  let env = sl_type_seed_env(locals)
  let body = if leaf {
    [@lib.Instruction::i32_const(@lib.I32(1))]
  } else {
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_add(),
    ]
  }
  assert_eq(
    sl_compound_seed_batch(body, env, queries, false),
    body.length() * queries,
  )
  assert_eq(
    sl_compound_seed_batch(body, env, queries, true),
    body.length() * queries,
  )
  it.bench(fn() { it.keep(sl_compound_seed_batch(body, env, queries, reuse)) })
}

///|
test "bench compound suffix locals=8 queries=1 V80 predecessor" (it : @bench.T) {
  sl_compound_seed_bench(it, 8, 1, false, false)
}

///|
test "bench compound suffix locals=8 queries=1 reuse" (it : @bench.T) {
  sl_compound_seed_bench(it, 8, 1, false, true)
}

///|
test "bench compound suffix locals=128 queries=1 V80 predecessor" (
  it : @bench.T,
) {
  sl_compound_seed_bench(it, 128, 1, false, false)
}

///|
test "bench compound suffix locals=128 queries=1 reuse" (it : @bench.T) {
  sl_compound_seed_bench(it, 128, 1, false, true)
}

///|
test "bench compound suffix locals=128 queries=32 V80 predecessor" (
  it : @bench.T,
) {
  sl_compound_seed_bench(it, 128, 32, false, false)
}

///|
test "bench compound suffix locals=128 queries=32 reuse" (it : @bench.T) {
  sl_compound_seed_bench(it, 128, 32, false, true)
}

///|
test "bench compound suffix locals=8192 queries=32 V80 predecessor" (
  it : @bench.T,
) {
  sl_compound_seed_bench(it, 8192, 32, false, false)
}

///|
test "bench compound suffix locals=8192 queries=32 reuse" (it : @bench.T) {
  sl_compound_seed_bench(it, 8192, 32, false, true)
}

///|
test "bench compound suffix leaf locals=8192 queries=32 V80 predecessor" (
  it : @bench.T,
) {
  sl_compound_seed_bench(it, 8192, 32, true, false)
}

///|
test "bench compound suffix leaf locals=8192 queries=32 reuse" (it : @bench.T) {
  sl_compound_seed_bench(it, 8192, 32, true, true)
}
