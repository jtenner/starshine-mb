///|
fn inl_dead_suffix_marked_perf_bench(it : @bench.T, count : Int) -> Unit {
  let body : Array[@lib.Instruction] = [@lib.Instruction::unreachable_()]
  for idx in 0..<count {
    body.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    body.push(@lib.Instruction::drop())
  }
  let func = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  let marked = Array::make(count, true)
  if inl_func_has_dead_suffix_call_to_marked(func, marked) {
    abort("Inlining dead-suffix benchmark unexpectedly found a marked call")
  }
  it.bench(fn() {
    it.keep(inl_func_has_dead_suffix_call_to_marked(func, marked))
  })
}

///|
test "Inlining marked dead-suffix query keeps top-level call boundary" {
  let marked = [false, true, false]
  let make_func = fn(body : Array[@lib.Instruction]) {
    @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  }
  let marked_call = @lib.Instruction::call(@lib.FuncIdx::new(1U))
  assert_false(
    inl_func_has_dead_suffix_call_to_marked(
      make_func([marked_call, @lib.Instruction::unreachable_()]),
      marked,
    ),
  )
  assert_true(
    inl_func_has_dead_suffix_call_to_marked(
      make_func([@lib.Instruction::unreachable_(), marked_call]),
      marked,
    ),
  )
  let block_root = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::unreachable_()]),
  )
  assert_true(
    inl_func_has_dead_suffix_call_to_marked(
      make_func([
        block_root,
        @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
      ]),
      marked,
    ),
  )
  assert_false(
    inl_func_has_dead_suffix_call_to_marked(
      make_func([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([marked_call]),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(99U)),
      ]),
      marked,
    ),
  )
}

///|
test "bench Inlining dead-suffix marked targets=128" (it : @bench.T) {
  inl_dead_suffix_marked_perf_bench(it, 128)
}

///|
test "bench Inlining dead-suffix marked targets=256" (it : @bench.T) {
  inl_dead_suffix_marked_perf_bench(it, 256)
}
