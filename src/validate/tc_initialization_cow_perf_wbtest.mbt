///|
fn tc_initialization_cow_bench(
  it : @bench.T,
  width : Int,
  writes : Int,
  unset : Bool,
  reference : Bool,
) -> Unit {
  let mask = Array::make(width, !unset)
  let body = Array::make(64, Instruction::nop())
  for index = 0; index < writes; index = index + 1 {
    body.push(Instruction::local_set(LocalIdx::new(index.to_uint())))
  }
  let entry = TcState::{
    ..make_state(empty_env(), []),
    initialized_locals: mask,
  }
  it.bench(fn() {
    let owner = TcInitializationOwner::new()
    let mut state = TcState::{
      ..entry,
      initialized_locals: if reference {
        tc_fork_initialized_for_body_reference(mask, body)
      } else {
        tc_fork_initialized_for_body(mask, body)
      },
    }
    for index = 0; index < writes; index = index + 1 {
      if reference {
        state.initialized_locals[index] = true
      } else {
        state = state.mark_local_initialized(
          LocalIdx::new(index.to_uint()),
          initialization_owner=Some(owner),
        )
      }
    }
    it.keep(state.initialized_locals)
  })
}

///|
test "bench initialization width=4 writes=0 set reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 4, 0, false, true)
}

///|
test "bench initialization width=4 writes=0 set owned-sequence" (it : @bench.T) {
  tc_initialization_cow_bench(it, 4, 0, false, false)
}

///|
test "bench initialization width=4 writes=0 unset reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 4, 0, true, true)
}

///|
test "bench initialization width=4 writes=0 unset owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 4, 0, true, false)
}

///|
test "bench initialization width=4 writes=1 set reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 4, 1, false, true)
}

///|
test "bench initialization width=4 writes=1 set owned-sequence" (it : @bench.T) {
  tc_initialization_cow_bench(it, 4, 1, false, false)
}

///|
test "bench initialization width=4 writes=1 unset reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 4, 1, true, true)
}

///|
test "bench initialization width=4 writes=1 unset owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 4, 1, true, false)
}

///|
test "bench initialization width=4 writes=4 set reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 4, 4, false, true)
}

///|
test "bench initialization width=4 writes=4 set owned-sequence" (it : @bench.T) {
  tc_initialization_cow_bench(it, 4, 4, false, false)
}

///|
test "bench initialization width=4 writes=4 unset reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 4, 4, true, true)
}

///|
test "bench initialization width=4 writes=4 unset owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 4, 4, true, false)
}

///|
test "bench initialization width=128 writes=0 set reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 128, 0, false, true)
}

///|
test "bench initialization width=128 writes=0 set owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 128, 0, false, false)
}

///|
test "bench initialization width=128 writes=0 unset reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 128, 0, true, true)
}

///|
test "bench initialization width=128 writes=0 unset owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 128, 0, true, false)
}

///|
test "bench initialization width=128 writes=1 set reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 128, 1, false, true)
}

///|
test "bench initialization width=128 writes=1 set owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 128, 1, false, false)
}

///|
test "bench initialization width=128 writes=1 unset reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 128, 1, true, true)
}

///|
test "bench initialization width=128 writes=1 unset owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 128, 1, true, false)
}

///|
test "bench initialization width=128 writes=64 set reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 128, 64, false, true)
}

///|
test "bench initialization width=128 writes=64 set owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 128, 64, false, false)
}

///|
test "bench initialization width=128 writes=64 unset reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 128, 64, true, true)
}

///|
test "bench initialization width=128 writes=64 unset owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 128, 64, true, false)
}

///|
test "bench initialization width=1024 writes=0 set reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 1024, 0, false, true)
}

///|
test "bench initialization width=1024 writes=0 set owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 1024, 0, false, false)
}

///|
test "bench initialization width=1024 writes=0 unset reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 1024, 0, true, true)
}

///|
test "bench initialization width=1024 writes=0 unset owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 1024, 0, true, false)
}

///|
test "bench initialization width=1024 writes=1 set reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 1024, 1, false, true)
}

///|
test "bench initialization width=1024 writes=1 set owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 1024, 1, false, false)
}

///|
test "bench initialization width=1024 writes=1 unset reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 1024, 1, true, true)
}

///|
test "bench initialization width=1024 writes=1 unset owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 1024, 1, true, false)
}

///|
test "bench initialization width=1024 writes=64 set reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 1024, 64, false, true)
}

///|
test "bench initialization width=1024 writes=64 set owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 1024, 64, false, false)
}

///|
test "bench initialization width=1024 writes=64 unset reference" (it : @bench.T) {
  tc_initialization_cow_bench(it, 1024, 64, true, true)
}

///|
test "bench initialization width=1024 writes=64 unset owned-sequence" (
  it : @bench.T,
) {
  tc_initialization_cow_bench(it, 1024, 64, true, false)
}
