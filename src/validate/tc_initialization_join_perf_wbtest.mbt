///|
fn tc_borrowed_join_bench(
  it : @bench.T,
  width : Int,
  alias : Bool,
  reference : Bool,
) -> Unit {
  let left = Array::makei(width, fn(i) { i % 3 == 0 })
  let right = if alias {
    left
  } else {
    Array::makei(width + 1, fn(i) { i % 5 == 0 })
  }
  let expected = tc_initialized_intersection(left, right)
  let joined = tc_initialized_join(left, right)
  if joined != expected {
    abort("borrowed join changed definite initialization")
  }
  let state = TcState::{
    ..make_state(empty_env(), []),
    initialized_locals: joined,
  }
  let written = state.mark_local_initialized(LocalIdx::new(1U))
  if !written.initialized_locals[1] || left[1] || right[1] || joined[1] {
    abort("later initialization changed a borrowed branch")
  }
  it.bench(fn() {
    for _ in 0..<128 {
      it.keep(
        if reference {
          tc_initialized_intersection(left, right)
        } else {
          tc_initialized_join(left, right)
        },
      )
    }
  })
}

///|
test "bench initialization join alias=true width=4 owned-reference" (
  it : @bench.T,
) {
  tc_borrowed_join_bench(it, 4, true, true)
}

///|
test "bench initialization join alias=true width=4 borrowed" (it : @bench.T) {
  tc_borrowed_join_bench(it, 4, true, false)
}

///|
test "bench initialization join alias=false width=4 owned-reference" (
  it : @bench.T,
) {
  tc_borrowed_join_bench(it, 4, false, true)
}

///|
test "bench initialization join alias=false width=4 borrowed" (it : @bench.T) {
  tc_borrowed_join_bench(it, 4, false, false)
}

///|
test "bench initialization join alias=true width=128 owned-reference" (
  it : @bench.T,
) {
  tc_borrowed_join_bench(it, 128, true, true)
}

///|
test "bench initialization join alias=true width=128 borrowed" (it : @bench.T) {
  tc_borrowed_join_bench(it, 128, true, false)
}

///|
test "bench initialization join alias=false width=128 owned-reference" (
  it : @bench.T,
) {
  tc_borrowed_join_bench(it, 128, false, true)
}

///|
test "bench initialization join alias=false width=128 borrowed" (it : @bench.T) {
  tc_borrowed_join_bench(it, 128, false, false)
}

///|
test "bench initialization join alias=true width=1024 owned-reference" (
  it : @bench.T,
) {
  tc_borrowed_join_bench(it, 1024, true, true)
}

///|
test "bench initialization join alias=true width=1024 borrowed" (it : @bench.T) {
  tc_borrowed_join_bench(it, 1024, true, false)
}

///|
test "bench initialization join alias=false width=1024 owned-reference" (
  it : @bench.T,
) {
  tc_borrowed_join_bench(it, 1024, false, true)
}

///|
test "bench initialization join alias=false width=1024 borrowed" (it : @bench.T) {
  tc_borrowed_join_bench(it, 1024, false, false)
}

///|
test "bench initialization join alias=true width=4096 owned-reference" (
  it : @bench.T,
) {
  tc_borrowed_join_bench(it, 4096, true, true)
}

///|
test "bench initialization join alias=true width=4096 borrowed" (it : @bench.T) {
  tc_borrowed_join_bench(it, 4096, true, false)
}

///|
test "bench initialization join alias=false width=4096 owned-reference" (
  it : @bench.T,
) {
  tc_borrowed_join_bench(it, 4096, false, true)
}

///|
test "bench initialization join alias=false width=4096 borrowed" (it : @bench.T) {
  tc_borrowed_join_bench(it, 4096, false, false)
}
