///|
test "if exit normalization keeps stack checks and every escape kind" {
  for ty in [ValType::i32(), ValType::i64(), ValType::i31ref()] {
    for reachable in [false, true] {
      for
        escape in [
          NoTcEscape,
          BranchTcEscape(0),
          BranchTcEscape(3),
          TerminalTcEscape,
        ] {
        let stack = [ty]
        let state = tc_state_new(empty_env(), stack, reachable, escape)
        let held = state.stack.copy()
        let expected = if reachable {
          (true, NoTcEscape)
        } else {
          match escape {
            NoTcEscape | TerminalTcEscape => (false, TerminalTcEscape)
            BranchTcEscape(0) => (true, NoTcEscape)
            BranchTcEscape(depth) => (false, BranchTcEscape(depth - 1))
          }
        }
        assert_eq(
          normalize_untyped_if_branch_exit(state, [ty]).unwrap(),
          expected,
        )
        assert_eq(
          tc_state_normalize_untyped_if_branch_exit(state, [ty]).unwrap(),
          expected,
        )
        assert_eq(state.stack, held)
        assert_eq(state.reachable, reachable)
        assert_eq(state.escape, escape)
      }
    }
  }
}

///|
test "if exit normalization retains exact stack failures and virtual bottom behavior" {
  let reachable = tc_state_new(empty_env(), [], true, NoTcEscape)
  assert_eq(
    normalize_untyped_if_branch_exit(reachable, [ValType::i32()]).unwrap_err(),
    "stack underflow",
  )
  for escape in [NoTcEscape, TerminalTcEscape] {
    let unreachable = tc_state_new(empty_env(), [], false, escape)
    assert_eq(
      normalize_untyped_if_branch_exit(unreachable, [ValType::i32()]).unwrap(),
      (false, TerminalTcEscape),
    )
  }
  for reachable in [false, true] {
    let mismatched = tc_state_new(
      empty_env(),
      [ValType::i64()],
      reachable,
      NoTcEscape,
    )
    assert_eq(
      normalize_untyped_if_branch_exit(mismatched, [ValType::i32()]).unwrap_err(),
      "type mismatch",
    )
    let extra = tc_state_new(
      empty_env(),
      [ValType::i32(), ValType::i32()],
      reachable,
      NoTcEscape,
    )
    assert_eq(
      normalize_untyped_if_branch_exit(extra, [ValType::i32()]).unwrap_err(),
      "type mismatch",
    )
    let bottom = tc_state_new(
      empty_env(),
      [ValType::bottom()],
      reachable,
      NoTcEscape,
    )
    assert_eq(
      normalize_untyped_if_branch_exit(bottom, [ValType::i32()]).unwrap(),
      (reachable, if reachable { NoTcEscape } else { TerminalTcEscape }),
    )
  }
}

///|
test "finish if reports then failure before else and leaves both states intact" {
  let entry = make_state(empty_env(), [])
  let yes = tc_state_new(entry.env, [], true, NoTcEscape)
  let no = tc_state_new(entry.env, [ValType::i64()], true, NoTcEscape)
  assert_eq(
    tc_state_finish_if(entry, entry, yes, no, [ValType::i32()]).unwrap_err(),
    "stack underflow",
  )
  assert_eq(yes.stack, [])
  assert_eq(no.stack, [ValType::i64()])
  assert_eq(entry.stack, [])
  let valid = tc_state_new(entry.env, [ValType::i32()], true, NoTcEscape)
  assert_eq(
    tc_state_finish_if(entry, entry, valid, no, [ValType::i32()]).unwrap_err(),
    "type mismatch",
  )
  assert_eq(valid.stack, [ValType::i32()])
  assert_eq(no.stack, [ValType::i64()])
}

///|
test "finish if retains branch reachability initialization joins and shifted observations" {
  let env = empty_env().with_locals(Locals::single(2U, ValType::i32()))
  let parent = TcState::{ ..make_state(env, []), reachable_escape_depths: [5], }
  let yes = TcState::{
    ..tc_state_new(env, [], false, BranchTcEscape(0)),
    initialized_locals: [true, false],
    reachable_escape_depths: [2],
  }
  let no = TcState::{
    ..tc_state_new(env, [], false, BranchTcEscape(3)),
    initialized_locals: [false, true],
    reachable_escape_depths: [4],
  }
  let out = tc_state_finish_if(parent, parent, yes, no, [ValType::i32()]).unwrap()
  assert_true(physical_equal(out.env, env))
  assert_true(out.reachable)
  assert_eq(out.escape, NoTcEscape)
  assert_eq(out.stack, [ValType::i32()])
  assert_eq(out.initialized_locals, [true, false])
  assert_eq(out.reachable_escape_depths, [5, 1, 3])
  assert_eq(yes.stack, [])
  assert_eq(no.stack, [])
  let stopped = TcState::{ ..no, reachable_escape_depths: [], }
  let joined = tc_state_finish_if(
    make_state(env, []),
    make_state(env, []),
    stopped,
    stopped,
    [],
  ).unwrap()
  assert_false(joined.reachable)
  assert_eq(joined.escape, BranchTcEscape(2))
}
