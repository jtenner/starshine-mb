///|
fn admitted_reads_perf_fixture(width : Int32, shared : Bool) -> HotFunc {
  let func = HotFunc::new()
  let deleted = hot_build_nop(func)
  hot_delete_node(func, deleted)
  let common = hot_build_const_i32(func, @lib.I32(1))
  for _ in 0..<width {
    let value = if shared {
      common
    } else {
      hot_build_const_i32(func, @lib.I32(1))
    }
    let drop = hot_build_drop(func, value)
    hot_root_append(
      func,
      hot_build_block(func, @lib.BlockType::void_(), [drop]),
    )
  }
  // Keep a real tombstone after all fixture allocations, which can reuse slots.
  let retired = hot_build_nop(func)
  hot_delete_node(func, retired)
  hot_verify_all_or_abort(func)
  func
}

///|
fn admitted_reads_perf_run(
  it : @bench.T,
  width : Int32,
  shared : Bool,
  reference : Bool,
) -> Unit {
  let func = admitted_reads_perf_fixture(width, shared)
  it.bench(fn() {
    it.keep(
      if reference {
        admitted_reads_reference_child_graph(func, None)
      } else {
        hot_verify_child_graph(func, None)
      },
    )
  })
}

///|
test "bench admitted verifier width=128 shared=false checked" (it : @bench.T) {
  admitted_reads_perf_run(it, 128, false, true)
}

///|
test "bench admitted verifier width=128 shared=false direct" (it : @bench.T) {
  admitted_reads_perf_run(it, 128, false, false)
}

///|
test "bench admitted verifier width=128 shared=true checked" (it : @bench.T) {
  admitted_reads_perf_run(it, 128, true, true)
}

///|
test "bench admitted verifier width=128 shared=true direct" (it : @bench.T) {
  admitted_reads_perf_run(it, 128, true, false)
}

///|
test "bench admitted verifier width=4096 shared=false checked" (it : @bench.T) {
  admitted_reads_perf_run(it, 4096, false, true)
}

///|
test "bench admitted verifier width=4096 shared=false direct" (it : @bench.T) {
  admitted_reads_perf_run(it, 4096, false, false)
}

///|
test "bench admitted verifier width=4096 shared=true checked" (it : @bench.T) {
  admitted_reads_perf_run(it, 4096, true, true)
}

///|
test "bench admitted verifier width=4096 shared=true direct" (it : @bench.T) {
  admitted_reads_perf_run(it, 4096, true, false)
}
