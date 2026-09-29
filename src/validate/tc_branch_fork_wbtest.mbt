///|
test "initialization forks borrow masks and isolate actual writes" {
  let mask = Array::make(256, true)
  mask[3] = false
  let safe = [
    Instruction::i32_const(I32(1)),
    Instruction::local_set(LocalIdx::new(0U)),
  ]
  let borrowed = tc_fork_initialized_for_body(mask, safe)
  assert_true(physical_equal(mask, borrowed))
  assert_eq(mask[3], false)
  let writes = [
    Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
    Instruction::local_set(LocalIdx::new(3U)),
  ]
  let isolated = tc_fork_initialized_for_body(mask, writes)
  assert_true(physical_equal(mask, isolated))
  let state = TcState::{
    ..make_state(empty_env(), []),
    initialized_locals: isolated,
  }
  let isolated = state.mark_local_initialized(LocalIdx::new(3U)).initialized_locals
  assert_eq(mask[3], false)
  assert_eq(isolated[3], true)
}

///|
test "initialization forks isolate writes in nested arms loops and legacy catches" {
  let mask = Array::make(256, true)
  mask[3] = false
  let writes = [Instruction::local_set(LocalIdx::new(3U))]
  for
    instr in [
      Instruction::block(BlockType::void_(), Expr::new(writes)),
      Instruction::loop_(BlockType::void_(), Expr::new(writes)),
      Instruction::if_(BlockType::void_(), [], Some(writes)),
      Instruction::try_table(BlockType::void_(), [], Expr::new(writes)),
      Instruction::try_(BlockType::void_(), Expr::new([]), [
        @lib.LegacyCatch::all(Expr::new(writes)),
      ]),
    ] {
    let forked = tc_fork_initialized_for_body(mask, [instr])
    let state = TcState::{
      ..make_state(empty_env(), []),
      initialized_locals: forked,
    }
    let changed = state.mark_local_initialized(LocalIdx::new(3U))
    assert_true(changed.initialized_locals[3])
    assert_eq(mask[3], false)
  }
}

///|
test "initialization forks defer copies for long bodies and small masks" {
  let mask = Array::make(256, false)
  let forked = tc_fork_initialized_for_body(
    mask,
    Array::make(9, Instruction::nop()),
  )
  assert_true(physical_equal(mask, forked))
  let state = TcState::{
    ..make_state(empty_env(), []),
    initialized_locals: forked,
  }
  let changed = state.mark_local_initialized(LocalIdx::new(0U))
  assert_true(changed.initialized_locals[0])
  assert_eq(mask[0], false)
  let small = [false]
  let forked = tc_fork_initialized_for_body(small, [])
  assert_true(physical_equal(small, forked))
  let state = TcState::{
    ..make_state(empty_env(), []),
    initialized_locals: forked,
  }
  let changed = state.mark_local_initialized(LocalIdx::new(0U))
  assert_true(changed.initialized_locals[0])
  assert_eq(small[0], false)
}

///|
test "borrowed nested block cannot leak a later initialization across if arms" {
  let env = empty_env().with_locals(
    Locals::new([@lib.LocalRun::new(256U, ValType::i32())]),
  )
  let entry = make_state(env, [ValType::i32()])
  entry.initialized_locals[3] = false
  let yes = [
    Instruction::block(BlockType::void_(), Expr::new([Instruction::nop()])),
    Instruction::i32_const(I32(7)),
    Instruction::local_set(LocalIdx::new(3U)),
  ]
  let merged = typecheck_if(entry, BlockType::void_(), yes, Some([])).unwrap()
  assert_false(entry.initialized_locals[3])
  assert_false(merged.initialized_locals[3])
  // The read is intentionally invalid: only the then arm initializes local 3.
  assert_true(typecheck_local_get(merged, LocalIdx::new(3U)) is Err(_))
}
