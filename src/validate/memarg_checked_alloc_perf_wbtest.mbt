///|
// Frozen pre-change reference. Retain tuple+Ok success costs deliberately.
fn memarg_alloc_reference_check(
  st : TcState,
  ma : MemArg,
  default_mem : MemIdx,
  nbits : Int32,
) -> Result[(MemIdx, Limits), String] {
  let MemArg(U32(align_pow_u), mem_opt, U64(offset)) = ma
  let mem = match mem_opt {
    None => default_mem
    Some(m) => m
  }
  let MemType(lim, _) = match st.env.get_memtype(mem) {
    None => return Err("invalid memory index in memarg")
    Some(mt) => mt
  }

  // (1) alignment: 2^n <= N/8
  let max_align_bytes = nbits / 8
  if max_align_bytes <= 0 {
    return Err("invalid access width")
  }
  let align_pow = align_pow_u.reinterpret_as_int()
  if align_pow < 0 {
    return Err("negative alignment power")
  }
  if align_pow >= 64 {
    return Err("alignment too large")
  }
  let align_bytes : UInt64 = 1 << align_pow
  if align_bytes > max_align_bytes.to_uint64() {
    return Err("memarg alignment too large for access width")
  }

  // (2) offset: m < 2^|at|
  let bits = lim.mem_addr_bits()
  if bits == 32 {
    if offset >= 1 << 32 {
      return Err("memarg offset out of range for i32 memory")
    }
  } else {
    // i64 memory: offset is UInt64 so always < 2^64
    ()
  }
  Ok((mem, lim))
}

///|
fn memarg_alloc_reference_atomic(
  st : TcState,
  ma : MemArg,
  default_mem : MemIdx,
  nbits : Int32,
) -> Result[(MemIdx, Limits), String] {
  let (mem, lim) = match
    memarg_alloc_reference_check(st, ma, default_mem, nbits) {
    Err(e) => return Err(e)
    Ok(x) => x
  }
  match st.env.get_memtype(mem) {
    None => return Err("invalid memory index in memarg")
    Some(_) => ()
  }
  Ok((mem, lim))
}

///|
fn memarg_alloc_reference_bits(
  st : TcState,
  arg : MemArg,
  memory : MemIdx,
  is_atomic : Bool,
) -> Int32 {
  let result = if is_atomic {
    memarg_alloc_reference_atomic(st, arg, memory, 32)
  } else {
    memarg_alloc_reference_check(st, arg, memory, 32)
  }
  match result {
    Err(error) => -error.length()
    Ok((_, limits)) => limits.mem_addr_bits()
  }
}

///|
fn memarg_alloc_current_bits(
  st : TcState,
  arg : MemArg,
  memory : MemIdx,
  is_atomic : Bool,
) -> Int32 {
  let checked = if is_atomic {
    memarg_check_atomic(st, arg, memory, 32)
  } else {
    memarg_check(st, arg, memory, 32)
  }
  match checked.error {
    Some(error) => -error.length()
    None => if checked.address64 { 64 } else { 32 }
  }
}

///|
fn memarg_checked_alloc_bench(
  it : @bench.T,
  width : Int32,
  is_atomic : Bool,
  cold : Bool,
  reference : Bool,
) -> Unit raise {
  let env = memarg_prepared_env(shared=true)
  let saved_memories = env.mems.copy()
  let state = make_state_owned(env, [])
  let args = if cold {
    [
      memarg_prepared_arg(64U, memory=Some(MemIdx::new(2U))),
      memarg_prepared_arg(64U),
    ]
  } else {
    [
      memarg_prepared_arg(2U, offset=4294967295UL),
      memarg_prepared_arg(
        2U,
        memory=Some(MemIdx::new(1U)),
        offset=0xffffffffffffffffUL,
      ),
      memarg_prepared_arg(2U, offset=0xffffffffffffffffUL),
    ]
  }
  let memories = if cold {
    [MemIdx::new(0U), MemIdx::new(0U)]
  } else {
    [MemIdx::new(0U), MemIdx::new(0U), MemIdx::new(1U)]
  }
  let expected = if cold {
    [
      -"invalid memory index in memarg".length(),
      -"alignment too large".length(),
    ]
  } else {
    [32, 64, 64]
  }
  for slot in 0..<args.length() {
    assert_eq(
      memarg_alloc_reference_bits(state, args[slot], memories[slot], is_atomic),
      expected[slot],
    )
    assert_eq(
      memarg_alloc_current_bits(state, args[slot], memories[slot], is_atomic),
      expected[slot],
    )
  }
  it.bench(fn() {
    let mut checksum = 0
    for index in 0..<width {
      let slot = index % args.length()
      checksum += if reference {
        memarg_alloc_reference_bits(
          state,
          args[slot],
          memories[slot],
          is_atomic,
        )
      } else {
        memarg_alloc_current_bits(state, args[slot], memories[slot], is_atomic)
      }
    }
    // Keep only a primitive checksum. Passing the new value carrier through
    // a generic keep/container could box it and invalidate this allocation test.
    it.keep(checksum)
  })
  assert_eq(state.stack, [])
  assert_eq(env.mems, saved_memories)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked regular width=32 reference" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 32, false, false, true)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked regular width=32 current" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 32, false, false, false)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked regular width=128 reference" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 128, false, false, true)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked regular width=128 current" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 128, false, false, false)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked regular width=512 reference" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 512, false, false, true)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked regular width=512 current" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 512, false, false, false)
}

///|
#skip("manual native cold-error checked-memarg allocation control; excluded from default tests")
test "bench memarg checked regular cold width=32 reference" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 32, false, true, true)
}

///|
#skip("manual native cold-error checked-memarg allocation control; excluded from default tests")
test "bench memarg checked regular cold width=32 current" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 32, false, true, false)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked atomic width=32 reference" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 32, true, false, true)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked atomic width=32 current" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 32, true, false, false)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked atomic width=128 reference" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 128, true, false, true)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked atomic width=128 current" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 128, true, false, false)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked atomic width=512 reference" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 512, true, false, true)
}

///|
#skip("manual native checked-memarg allocation and instruction control; excluded from default tests")
test "bench memarg checked atomic width=512 current" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 512, true, false, false)
}

///|
#skip("manual native cold-error checked-memarg allocation control; excluded from default tests")
test "bench memarg checked atomic cold width=32 reference" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 32, true, true, true)
}

///|
#skip("manual native cold-error checked-memarg allocation control; excluded from default tests")
test "bench memarg checked atomic cold width=32 current" (it : @bench.T) {
  memarg_checked_alloc_bench(it, 32, true, true, false)
}
