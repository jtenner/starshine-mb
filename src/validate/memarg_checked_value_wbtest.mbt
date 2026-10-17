///|
fn memarg_prepared_env(shared~ : Bool = false) -> Env {
  Env::{
    ..empty_env(),
    mems: [
      MemType::new(Limits::i32(1U, Some(2U)), shared~),
      MemType::new(Limits::i64(1UL, Some(2UL)), shared~),
    ],
  }
}

///|
fn memarg_prepared_arg(
  align : UInt32,
  memory~ : MemIdx? = None,
  offset~ : UInt64 = 0UL,
) -> MemArg {
  MemArg::new(U32::new(align), memory, @lib.U64::new(offset))
}

///|
// Only this test adapter changes when the private success carrier changes.
// No adapter or Result normalization is used by the measured native loop.
fn memarg_prepared_address(
  st : TcState,
  arg : MemArg,
  default_memory : MemIdx,
  width : Int32,
  is_atomic : Bool,
) -> Result[ValType, String] {
  let checked = if is_atomic {
    memarg_check_atomic(st, arg, default_memory, width)
  } else {
    memarg_check(st, arg, default_memory, width)
  }
  match checked.error {
    Some(error) => Err(error)
    None => Ok(checked.address_type())
  }
}

///|
fn memarg_prepared_apply(kind : Int32, st : TcState, arg : MemArg) -> TcResult {
  match kind {
    0 => typecheck_load(st, arg, 32, ValType::i32())
    1 => typecheck_store(st, arg, 32, ValType::i32())
    2 => typecheck_v128_mem_load(st, arg, 128)
    3 => typecheck_v128_mem_store(st, arg, 128)
    4 => typecheck_v128_load_lane(st, arg, 32, LaneIdx::new(b'\x00'), b'\x04')
    5 => typecheck_v128_store_lane(st, arg, 32, LaneIdx::new(b'\x00'), b'\x04')
    6 => typecheck_atomic_load(st, arg, 32, ValType::i32())
    7 => typecheck_atomic_store(st, arg, 32, ValType::i32())
    8 => typecheck_atomic_notify(st, arg)
    9 => typecheck_atomic_wait(st, arg, 32, ValType::i32())
    10 => typecheck_atomic_rmw(st, arg, 32, ValType::i32())
    11 => typecheck_atomic_cmpxchg(st, arg, 32, ValType::i32())
    _ => abort("unknown prepared memory consumer")
  }
}

///|
fn memarg_prepared_stack(
  kind : Int32,
  address : ValType,
) -> (Array[ValType], Array[ValType]) {
  match kind {
    0 | 6 => ([address], [ValType::i32()])
    1 | 7 => ([address, ValType::i32()], [])
    2 => ([address], [ValType::v128()])
    3 | 5 => ([address, ValType::v128()], [])
    4 => ([address, ValType::v128()], [ValType::v128()])
    8 | 10 => ([address, ValType::i32()], [ValType::i32()])
    9 => ([address, ValType::i32(), ValType::i64()], [ValType::i32()])
    11 => ([address, ValType::i32(), ValType::i32()], [ValType::i32()])
    _ => abort("unknown prepared memory stack")
  }
}

///|
test "memarg checked value preserves default explicit memory and address widths" {
  let state = make_state_owned(memarg_prepared_env(), [ValType::f64()])
  for is_atomic in [false, true] {
    for
      (default_memory, explicit_memory, offset, expected) in [
        (0U, None, 4294967295UL, ValType::i32()),
        (1U, None, 0xffffffffffffffffUL, ValType::i64()),
        (0U, Some(MemIdx::new(1U)), 0xffffffffffffffffUL, ValType::i64()),
        (1U, Some(MemIdx::new(0U)), 4294967295UL, ValType::i32()),
      ] {
      for (width, align) in [(8, 0U), (16, 1U), (32, 2U), (64, 3U), (128, 4U)] {
        assert_eq(
          memarg_prepared_address(
            state,
            memarg_prepared_arg(align, memory=explicit_memory, offset~),
            MemIdx::new(default_memory),
            width,
            is_atomic,
          ),
          Ok(expected),
        )
      }
    }
  }
  assert_eq(state.stack, [ValType::f64()])
}

///|
test "memarg checked value preserves exact error precedence before stack access" {
  let state = make_state_owned(memarg_prepared_env(), [ValType::f64()])
  for is_atomic in [false, true] {
    for
      (memory, width, align, offset, error) in [
        (2U, 0, 0xffffffffU, 4294967296UL, "invalid memory index in memarg"),
        (0U, 0, 0xffffffffU, 4294967296UL, "invalid access width"),
        (0U, 7, 64U, 4294967296UL, "invalid access width"),
        (0U, 32, 0xffffffffU, 4294967296UL, "negative alignment power"),
        (0U, 32, 64U, 4294967296UL, "alignment too large"),
        (
          0U, 32, 3U, 4294967296UL, "memarg alignment too large for access width",
        ),
        (0U, 32, 0U, 4294967296UL, "memarg offset out of range for i32 memory"),
      ] {
      assert_eq(
        memarg_prepared_address(
          state,
          memarg_prepared_arg(align, memory=Some(MemIdx::new(memory)), offset~),
          MemIdx::new(1U),
          width,
          is_atomic,
        ),
        Err(error),
      )
      assert_eq(state.stack, [ValType::f64()])
    }
  }
}

///|
test "memarg checked value preserves all twelve successful consumer stack effects" {
  for memory in [0U, 1U] {
    let address = if memory == 0U { ValType::i32() } else { ValType::i64() }
    for shared in [false, true] {
      let env = memarg_prepared_env(shared~)
      let saved_memories = env.mems.copy()
      for kind in 0..<12 {
        let (operands, results) = memarg_prepared_stack(kind, address)
        let stack = [ValType::f64()]
        for operand in operands {
          stack.push(operand)
        }
        let state = make_state_owned(env, stack)
        let next = memarg_prepared_apply(
          kind,
          state,
          memarg_prepared_arg(0U, memory=Some(MemIdx::new(memory))),
        ).unwrap()
        let expected = [ValType::f64()]
        for result in results {
          expected.push(result)
        }
        assert_eq(next.stack, expected)
        assert_eq(state.stack, expected)
        assert_true(next.reachable)
        assert_false(next.polymorphic)
        assert_eq(next.escape, NoTcEscape)
        assert_eq(next.reachable_escape_depths, [])
        assert_eq(next.initialized_locals, [])
      }
      assert_eq(env.mems, saved_memories)
    }
  }
}

///|
test "memarg failure leaves every consumer stack unchanged before operand pops" {
  for kind in 0..<12 {
    let state = make_state_owned(memarg_prepared_env(), [
      ValType::f64(),
      ValType::v128(),
      ValType::i64(),
    ])
    let saved = state.stack.copy()
    match
      memarg_prepared_apply(
        kind,
        state,
        memarg_prepared_arg(
          64U,
          memory=Some(MemIdx::new(2U)),
          offset=4294967296UL,
        ),
      ) {
      Err(error) => assert_eq(error, "invalid memory index in memarg")
      Ok(_) => fail("invalid memory must fail before stack pops")
    }
    assert_eq(state.stack, saved)
  }
}

///|
test "memory consumer type errors preserve the existing partial-pop stack state" {
  let env = memarg_prepared_env()
  let arg = memarg_prepared_arg(0U)
  let bad_value = make_state_owned(env, [
    ValType::f64(),
    ValType::i32(),
    ValType::f32(),
  ])
  match typecheck_store(bad_value, arg, 64, ValType::i64()) {
    Err(error) => assert_eq(error, "type mismatch: expected=I64 actual=F32")
    Ok(_) => fail("wrong store value must fail")
  }
  assert_eq(bad_value.stack, [ValType::f64(), ValType::i32()])
  let bad_address = make_state_owned(env, [
    ValType::f64(),
    ValType::i64(),
    ValType::i32(),
  ])
  match typecheck_store(bad_address, arg, 32, ValType::i32()) {
    Err(error) => assert_eq(error, "type mismatch: expected=I32 actual=I64")
    Ok(_) => fail("wrong store address must fail")
  }
  assert_eq(bad_address.stack, [ValType::f64()])
  let bad_timeout = make_state_owned(env, [
    ValType::f64(),
    ValType::i32(),
    ValType::i32(),
    ValType::f32(),
  ])
  match typecheck_atomic_wait(bad_timeout, arg, 32, ValType::i32()) {
    Err(error) => assert_eq(error, "type mismatch: expected=I64 actual=F32")
    Ok(_) => fail("wrong wait timeout must fail first")
  }
  assert_eq(bad_timeout.stack, [ValType::f64(), ValType::i32(), ValType::i32()])
}

///|
test "SIMD lane error remains ahead of memory and operand errors" {
  for store in [false, true] {
    let state = make_state_owned(memarg_prepared_env(), [])
    let arg = memarg_prepared_arg(
      64U,
      memory=Some(MemIdx::new(2U)),
      offset=4294967296UL,
    )
    let result = if store {
      typecheck_v128_store_lane(state, arg, 32, LaneIdx::new(b'\x04'), b'\x04')
    } else {
      typecheck_v128_load_lane(state, arg, 32, LaneIdx::new(b'\x04'), b'\x04')
    }
    match result {
      Err(error) => assert_eq(error, "invalid lane index")
      Ok(_) => fail("invalid SIMD lane must fail")
    }
    assert_eq(state.stack, [])
  }
}

///|
test "memory checks remain mandatory on polymorphic stacks" {
  for kind in 0..<12 {
    let state = make_state_owned(memarg_prepared_env(), []).set_unreachable()
    let (_, expected) = memarg_prepared_stack(kind, ValType::i32())
    let next = memarg_prepared_apply(kind, state, memarg_prepared_arg(0U)).unwrap()
    assert_eq(next.stack, expected)
    assert_false(next.reachable)
    assert_true(next.polymorphic)
    assert_eq(next.escape, TerminalTcEscape)
    let invalid = make_state_owned(memarg_prepared_env(), []).set_unreachable()
    match
      memarg_prepared_apply(
        kind,
        invalid,
        memarg_prepared_arg(0U, memory=Some(MemIdx::new(2U))),
      ) {
      Err(error) => assert_eq(error, "invalid memory index in memarg")
      Ok(_) => fail("unreachable memory access still requires a valid memory")
    }
    assert_eq(invalid.stack, [])
  }
}

///|
test "memory preflight errors precede stack underflow" {
  let state = make_state_owned(memarg_prepared_env(), [])
  match typecheck_load(state, memarg_prepared_arg(64U), 32, ValType::i32()) {
    Err(error) => assert_eq(error, "alignment too large")
    Ok(_) => fail("invalid alignment must fail before empty-stack access")
  }
  assert_eq(state.stack, [])
  match typecheck_load(state, memarg_prepared_arg(0U), 32, ValType::i32()) {
    Err(error) => assert_eq(error, "stack underflow")
    Ok(_) => fail("valid memory access needs an address")
  }
  assert_eq(state.stack, [])
}

///|
test "checked memarg results reach real public load and atomic instruction validation" {
  let env = memarg_prepared_env()
  for memory in [0U, 1U] {
    let address = if memory == 0U { ValType::i32() } else { ValType::i64() }
    let arg = memarg_prepared_arg(2U, memory=Some(MemIdx::new(memory)))
    for
      instruction in [
        Instruction::i32_load(arg),
        Instruction::i32_atomic_load(arg),
      ] {
      let state = make_state_owned(env, [ValType::f64(), address])
      let next = Typecheck::typecheck(instruction, state).unwrap()
      assert_eq(next.stack, [ValType::f64(), ValType::i32()])
      assert_true(next.reachable)
      assert_false(next.polymorphic)
    }
  }
  let invalid = make_state_owned(env, [ValType::f64()])
  let saved = invalid.stack.copy()
  match
    Typecheck::typecheck(
      Instruction::i32_load(
        memarg_prepared_arg(64U, memory=Some(MemIdx::new(2U))),
      ),
      invalid,
    ) {
    Err(error) => assert_eq(error, "invalid memory index in memarg")
    Ok(_) =>
      fail("public load must validate its memory before popping its address")
  }
  assert_eq(invalid.stack, saved)
}
