///|
fn write_facts_perf_fixture(count : Int, dense : Bool) -> HotFunc {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(4, @lib.ValType::i32())),
  )
  for index in 0..<count {
    if dense || index % 16 == 0 {
      let value = hot_build_const_i32(func, @lib.I32(index))
      let root = if index % 2 == 0 {
        hot_build_local_set(func, index % 4, value)
      } else {
        hot_build_drop(func, hot_build_local_tee(func, index % 4, value))
      }
      hot_root_append(func, root)
    } else {
      hot_root_append(func, hot_build_nop(func))
    }
  }
  func
}

///|
fn write_facts_perf_run(
  it : @bench.T,
  count : Int,
  dense : Bool,
  original : Bool,
) -> Unit {
  let func = write_facts_perf_fixture(count, dense)
  hot_verify_all_or_abort(func)
  it.bench(fn() {
    if original {
      it.keep(write_facts_reference_locals(func))
      it.keep(write_facts_reference_tees(func))
    } else {
      let facts = local_graph_build_write_facts(func)
      it.keep(facts.local_ids)
      it.keep(facts.is_tees)
    }
  })
}

///|
test "bench writer facts roots=128 dense=false separate" (it : @bench.T) {
  write_facts_perf_run(it, 128, false, true)
}

///|
test "bench writer facts roots=128 dense=false fused" (it : @bench.T) {
  write_facts_perf_run(it, 128, false, false)
}

///|
test "bench writer facts roots=128 dense=true separate" (it : @bench.T) {
  write_facts_perf_run(it, 128, true, true)
}

///|
test "bench writer facts roots=128 dense=true fused" (it : @bench.T) {
  write_facts_perf_run(it, 128, true, false)
}

///|
test "bench writer facts roots=8192 dense=false separate" (it : @bench.T) {
  write_facts_perf_run(it, 8192, false, true)
}

///|
test "bench writer facts roots=8192 dense=false fused" (it : @bench.T) {
  write_facts_perf_run(it, 8192, false, false)
}

///|
test "bench writer facts roots=8192 dense=true separate" (it : @bench.T) {
  write_facts_perf_run(it, 8192, true, true)
}

///|
test "bench writer facts roots=8192 dense=true fused" (it : @bench.T) {
  write_facts_perf_run(it, 8192, true, false)
}
