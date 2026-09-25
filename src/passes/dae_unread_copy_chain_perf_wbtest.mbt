///|
fn dae_unread_copy_chain_fixture(count : Int) -> @lib.Func {
  let locals = Array::make(count, @lib.ValType::i32())
  let body : Array[@lib.Instruction] = []
  for idx in 0..<count {
    body.push(
      if idx == 0 {
        @lib.Instruction::i32_const(@lib.I32(7))
      } else {
        @lib.Instruction::local_get(@lib.LocalIdx::new((idx - 1).to_uint()))
      },
    )
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(idx.to_uint())))
  }
  @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(body))
}

///|
fn dae_unread_copy_chain_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = dae_unread_copy_chain_fixture(count)
  let (cleaned, changed) = dae_cleanup_unread_locals(fixture, [])
  let @lib.Func(locals, @lib.Expr(body)) = cleaned
  if !changed || locals.length() != 0 || !body.is_empty() {
    abort("DAE unread-copy fixture did not fully clean")
  }
  it.bench(fn() { it.keep(dae_cleanup_unread_locals(fixture, [])) })
}

///|
test "DAE unread-copy propagation keeps chains with a live terminal read" {
  let fixture = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::return_(),
    ]),
  )
  let (rewritten, changed) = dae_cleanup_unread_locals(fixture, [])
  assert_false(changed)
  assert_eq(rewritten, fixture)
}

///|
test "bench dae unread copy chain count=128" (it : @bench.T) {
  dae_unread_copy_chain_bench(it, 128)
}

///|
test "bench dae unread copy chain count=256" (it : @bench.T) {
  dae_unread_copy_chain_bench(it, 256)
}
