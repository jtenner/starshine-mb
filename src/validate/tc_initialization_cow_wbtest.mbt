///|
test "initializing a borrowed branch preserves entry and sibling masks" {
  let entry = make_state(empty_env(), [])
  let mask = [false, true, false]
  let entry = TcState::{ ..entry, initialized_locals: mask, }
  let sibling = TcState::{ ..entry, }
  let written = entry.mark_local_initialized(@lib.LocalIdx::new(0U))
  assert_eq(written.initialized_locals, [true, true, false])
  assert_eq(entry.initialized_locals, [false, true, false])
  assert_eq(sibling.initialized_locals, [false, true, false])
  let written_again = written.mark_local_initialized(@lib.LocalIdx::new(2U))
  assert_eq(written_again.initialized_locals, [true, true, true])
  assert_eq(written.initialized_locals, [true, true, false])
  let same = written_again.mark_local_initialized(@lib.LocalIdx::new(1U))
  assert_true(
    physical_equal(same.initialized_locals, written_again.initialized_locals),
  )
}

///|
test "large branch initialization defers its copy until a false bit changes" {
  let mask = Array::make(256, true)
  mask[254] = false
  let body = Array::make(
    32,
    @lib.Instruction::local_set(@lib.LocalIdx::new(254U)),
  )
  let fork = tc_fork_initialized_for_body(mask, body)
  assert_true(physical_equal(mask, fork))
  let state = TcState::{
    ..make_state(empty_env(), []),
    initialized_locals: fork,
  }
  let changed = state.mark_local_initialized(@lib.LocalIdx::new(254U))
  assert_false(mask[254])
  assert_true(changed.initialized_locals[254])
  assert_false(physical_equal(changed.initialized_locals, mask))
}

///|
test "one owned instruction sequence copies once for distinct local initializations" {
  let env = empty_env().with_locals(Locals::single(256U, ValType::i32()))
  let entry = make_state(env, [])
  entry.initialized_locals.fill(false)
  let copies = [0]
  let owner = TcInitializationOwner::new(copy_count=Some(copies))
  let mut state = entry
  for index = 0; index < 64; index = index + 1 {
    state = typecheck_local_set(
      state.push1(ValType::i32()),
      LocalIdx::new(index.to_uint()),
      initialization_owner=Some(owner),
    ).unwrap()
  }
  assert_eq(copies[0], 1)
  for index = 0; index < 256; index = index + 1 {
    assert_eq(state.initialized_locals[index], index < 64)
    assert_false(entry.initialized_locals[index])
  }
  let sibling_owner = TcInitializationOwner::new()
  let sibling = entry.mark_local_initialized(
    LocalIdx::new(100U),
    initialization_owner=Some(sibling_owner),
  )
  assert_true(sibling.initialized_locals[100])
  assert_false(state.initialized_locals[100])
}

///|
test "body state fork retains initialization facts and resets scope escape observations" {
  let env = empty_env().with_locals(Locals::single(256U, ValType::i32()))
  let entry = make_state(env, [])
  entry.initialized_locals[3] = false
  let entry = TcState::{ ..entry, reachable_escape_depths: [2], }
  let fork = tc_state_fork_body(entry, env.with_label([]), [ValType::i32()])
  assert_false(fork.initialized_locals[3])
  assert_true(physical_equal(entry.initialized_locals, fork.initialized_locals))
  assert_eq(fork.reachable_escape_depths, [])
  let changed = fork.mark_local_initialized(LocalIdx::new(3U))
  assert_true(changed.initialized_locals[3])
  assert_false(entry.initialized_locals[3])
}

///|
test "unchanged if joins borrow their mask and subsequent writes isolate every branch" {
  let env = empty_env().with_locals(Locals::single(8U, ValType::i32()))
  let entry = make_state(env, [])
  entry.initialized_locals[3] = false
  let yes = tc_state_fork_body(entry, env.with_label([]), [])
  let no = tc_state_fork_body(entry, env.with_label([]), [])
  let merged = tc_state_finish_if(entry, entry, yes, no, []).unwrap()
  assert_true(
    physical_equal(merged.initialized_locals, entry.initialized_locals),
  )
  let written = Typecheck::typecheck(
    Expr::new([
      Instruction::i32_const(7),
      Instruction::local_set(LocalIdx::new(3U)),
      Instruction::local_get(LocalIdx::new(3U)),
      Instruction::drop(),
    ]),
    merged,
  ).unwrap()
  assert_true(written.initialized_locals[3])
  assert_false(entry.initialized_locals[3])
  assert_false(yes.initialized_locals[3])
  assert_false(no.initialized_locals[3])
  assert_false(merged.initialized_locals[3])
  assert_eq(written.stack, [])
}

///|
test "nested unchanged if joins preserve shared definite initialization facts" {
  let env = empty_env().with_locals(Locals::single(8U, ValType::i32()))
  let entry = make_state(env, [])
  entry.initialized_locals[3] = false
  let inner = Instruction::if_(
    BlockType::void_(),
    [Instruction::nop()],
    Some([Instruction::nop()]),
  )
  let output = Typecheck::typecheck(
    Expr::new([
      Instruction::i32_const(1),
      Instruction::if_(
        BlockType::void_(),
        [Instruction::i32_const(0), inner],
        Some([Instruction::i32_const(1), inner]),
      ),
    ]),
    entry,
  ).unwrap()
  assert_true(
    physical_equal(output.initialized_locals, entry.initialized_locals),
  )
  assert_false(output.initialized_locals[3])
  assert_true(output.reachable)
  assert_eq(output.stack, [])
  assert_true(
    Typecheck::typecheck(Instruction::local_get(LocalIdx::new(3U)), output)
    is Err(_),
  )
}
