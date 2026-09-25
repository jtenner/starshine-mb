///|
fn inl_dead_suffix_targets_perf_fixture(count : Int) -> @lib.Func {
  let body : Array[@lib.Instruction] = [@lib.Instruction::unreachable_()]
  for idx in 0..<count {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(idx.to_uint())))
  }
  @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
}

///|
fn inl_dead_suffix_targets_perf_bench(it : @bench.T, count : Int) -> Unit {
  let func = inl_dead_suffix_targets_perf_fixture(count)
  let facts = inl_collect_dead_suffix_targets(func)
  if !facts.has_any ||
    facts.total_count != count ||
    facts.targets.length() != count ||
    facts.counts.length() != count {
    abort("inlining dead-suffix targets fixture lost a call")
  }
  it.bench(fn() { it.keep(inl_collect_dead_suffix_targets(func)) })
}

///|
test "inlining dead-suffix target counts preserve first occurrence order" {
  let body : Array[@lib.Instruction] = [@lib.Instruction::unreachable_()]
  for target in [2, 1, 2, 0, 1] {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(target.to_uint())))
  }
  let facts = inl_collect_dead_suffix_targets(
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
  )
  assert_eq(facts.total_count, 5)
  assert_eq(facts.targets, [2, 1, 0])
  assert_eq(facts.counts, [2, 2, 1])
}

///|
test "inlining dead-suffix counts survive index promotion" {
  let body : Array[@lib.Instruction] = [@lib.Instruction::unreachable_()]
  for target in 0..<10 {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(target.to_uint())))
  }
  for target in [0, 7, 9] {
    body.push(
      @lib.Instruction::return_call(@lib.FuncIdx::new(target.to_uint())),
    )
  }
  let facts = inl_collect_dead_suffix_targets(
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
  )
  assert_eq(facts.total_count, 13)
  assert_eq(facts.targets, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
  assert_eq(facts.counts, [2, 1, 1, 1, 1, 1, 1, 2, 1, 2])
}

///|
test "bench inlining dead-suffix distinct targets count=128" (it : @bench.T) {
  inl_dead_suffix_targets_perf_bench(it, 128)
}

///|
test "bench inlining dead-suffix distinct targets count=256" (it : @bench.T) {
  inl_dead_suffix_targets_perf_bench(it, 256)
}

///|
fn inl_dead_suffix_repeated_target_perf_bench(
  it : @bench.T,
  count : Int,
) -> Unit {
  let body : Array[@lib.Instruction] = [@lib.Instruction::unreachable_()]
  for _ in 0..<count {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  }
  let func = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  let facts = inl_collect_dead_suffix_targets(func)
  if facts.targets != [0] || facts.counts != [count] {
    abort("inlining repeated target fixture lost calls")
  }
  it.bench(fn() { it.keep(inl_collect_dead_suffix_targets(func)) })
}

///|
test "bench inlining dead-suffix repeated target count=128" (it : @bench.T) {
  inl_dead_suffix_repeated_target_perf_bench(it, 128)
}

///|
test "bench inlining dead-suffix repeated target count=256" (it : @bench.T) {
  inl_dead_suffix_repeated_target_perf_bench(it, 256)
}
