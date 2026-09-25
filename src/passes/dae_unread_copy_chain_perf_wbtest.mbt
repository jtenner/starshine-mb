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

///|
fn dae_nested_unread_copy_chain_fixture(count : Int) -> @lib.Func {
  let locals = Array::make(count, @lib.ValType::i32())
  let body : Array[@lib.Instruction] = []
  for idx in 0..<count {
    let nested = [
      if idx == 0 {
        @lib.Instruction::i32_const(@lib.I32(7))
      } else {
        @lib.Instruction::local_get(@lib.LocalIdx::new((idx - 1).to_uint()))
      },
      @lib.Instruction::local_set(@lib.LocalIdx::new(idx.to_uint())),
    ]
    body.push(
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(nested)),
    )
  }
  @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(body))
}

///|
test "DAE nested unread copy chain removes all local dependencies" {
  let fixture = dae_nested_unread_copy_chain_fixture(4)
  let (cleaned, changed) = dae_cleanup_unread_locals(fixture, [])
  let @lib.Func(locals, @lib.Expr(body)) = cleaned
  assert_true(changed)
  assert_eq(locals.length(), 0)
  let reads : Array[Int] = []
  let writes : Array[Int] = []
  pass_lower_count_locals(body, reads, writes)
  assert_true(reads.is_empty() && writes.is_empty())
}

///|
test "DAE nested unread copy chain keeps a live terminal read" {
  let @lib.Func(locals, @lib.Expr(body)) = dae_nested_unread_copy_chain_fixture(
    4,
  )
  let live_body = body.copy()
  live_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(3U)))
  live_body.push(@lib.Instruction::return_())
  let fixture = @lib.Func::new(locals, @lib.Expr::new(live_body))
  let (cleaned, changed) = dae_cleanup_unread_locals(fixture, [])
  assert_false(changed)
  assert_eq(cleaned, fixture)
}

///|
test "DAE unread copy pairs stay within each conditional arm" {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ]
  let pairs : Array[(Int, Int)] = []
  dae_collect_unread_simple_copy_pairs(body, Array::make(4, 1), pairs)
  assert_eq(pairs, [(1, 2), (3, 0)])
}

///|
fn dae_nested_unread_copy_chain_bench(it : @bench.T, count : Int) -> Unit {
  let fixture = dae_nested_unread_copy_chain_fixture(count)
  let (cleaned, changed) = dae_cleanup_unread_locals(fixture, [])
  let @lib.Func(locals, _) = cleaned
  if !changed || locals.length() != 0 {
    abort("DAE nested unread-copy fixture did not fully clean")
  }
  it.bench(fn() { it.keep(dae_cleanup_unread_locals(fixture, [])) })
}

///|
test "bench dae nested unread copy chain count=128" (it : @bench.T) {
  dae_nested_unread_copy_chain_bench(it, 128)
}

///|
test "bench dae nested unread copy chain count=256" (it : @bench.T) {
  dae_nested_unread_copy_chain_bench(it, 256)
}
