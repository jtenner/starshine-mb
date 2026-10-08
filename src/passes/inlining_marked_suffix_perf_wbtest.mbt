///|
fn inl_marked_suffix_perf_fixture(
  count : Int,
) -> (Array[@lib.Instruction], Array[Bool]) {
  let body : Array[@lib.Instruction] = []
  for idx in 0..<count {
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(idx.to_uint())))
  }
  let marked = Array::make(count * 2, false)
  for idx = count; idx < count * 2; idx = idx + 1 {
    marked[idx] = true
  }
  (body, marked)
}

///|
test "Inlining marked suffix detects a call after the start position" {
  let (body, marked) = inl_marked_suffix_perf_fixture(4)
  assert_false(inl_suffix_calls_marked_func(body, 1, marked))
  marked[3] = true
  assert_true(inl_suffix_calls_marked_func(body, 1, marked))
  assert_false(inl_suffix_calls_marked_func(body, 4, marked))
}

///|
test "Inlining marked suffix preserves nested and tail-call coverage" {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(2U))]),
    ),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::call(@lib.FuncIdx::new(3U))],
      Some([@lib.Instruction::return_call(@lib.FuncIdx::new(4U))]),
    ),
    @lib.Instruction::try_(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(5U))]),
      [],
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(99U)),
  ]
  let marked = Array::make(6, false)
  marked[1] = true
  assert_false(inl_suffix_calls_marked_func(body, 1, marked))
  marked[2] = true
  assert_true(inl_suffix_calls_marked_func(body, 1, marked))
  marked[2] = false
  marked[3] = true
  assert_true(inl_suffix_calls_marked_func(body, 1, marked))
  marked[3] = false
  marked[4] = true
  assert_true(inl_suffix_calls_marked_func(body, 1, marked))
  marked[4] = false
  marked[5] = true
  assert_true(inl_suffix_calls_marked_func(body, 1, marked))
  assert_true(inl_suffix_has_self_call(body, 1, 4))
  assert_false(inl_suffix_has_self_call(body, 1, 1))
}

///|
fn inl_marked_suffix_perf_bench(it : @bench.T, count : Int) -> Unit {
  let (body, marked) = inl_marked_suffix_perf_fixture(count)
  if inl_suffix_calls_marked_func(body, 0, marked) {
    abort("Inlining marked suffix benchmark must have no matching call")
  }
  it.bench(fn() { it.keep(inl_suffix_calls_marked_func(body, 0, marked)) })
}

///|
test "bench Inlining marked suffix count=128" (it : @bench.T) {
  inl_marked_suffix_perf_bench(it, 128)
}

///|
test "bench Inlining marked suffix count=256" (it : @bench.T) {
  inl_marked_suffix_perf_bench(it, 256)
}

///|
fn inl_self_suffix_perf_bench(it : @bench.T, self_abs : Int) -> Unit {
  let body = Array::make(16, @lib.Instruction::nop())
  if inl_suffix_has_self_call(body, 0, self_abs) {
    abort("Inlining self suffix benchmark must have no self call")
  }
  it.bench(fn() { it.keep(inl_suffix_has_self_call(body, 0, self_abs)) })
}

///|
test "bench Inlining absent self suffix abs=2048" (it : @bench.T) {
  inl_self_suffix_perf_bench(it, 2048)
}

///|
test "bench Inlining absent self suffix abs=4096" (it : @bench.T) {
  inl_self_suffix_perf_bench(it, 4096)
}
