///|
fn cl_prefix_copy_scan_bench(
  it : @bench.T,
  count : Int32,
  mode : Int32,
  reference : Bool,
) -> Unit {
  let body = cl_prefix_copy_scan_fixture(count)
  if mode == 1 {
    // Mutable source: retain the complete suffix query and its write barrier.
    body.push(@lib.Instruction::i32_const(@lib.I32(7)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  }
  if mode == 2 {
    // Destinations rejected from existing counts need no source query.
    for dest in 1..<(count + 1) {
      body.push(@lib.Instruction::i32_const(@lib.I32(7)))
      body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(dest.to_uint())))
    }
    body.push(@lib.Instruction::i32_const(@lib.I32(7)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
  }
  let types = Array::make(count + 1, @lib.ValType::i32())
  let gets = Array::make(count + 1, 0)
  let sets = Array::make(count + 1, 0)
  let tees = Array::make(count + 1, 0)
  cl_count_syntactic_local_accesses(body, gets, sets, tees)
  let expected = Array::make(count + 1, -1)
  let actual = Array::make(count + 1, -1)
  cl_prefix_copy_scan_reference(body, expected, sets, tees, types)
  cl_mark_loop_prefix_copy_aliases(body, actual, sets, tees, types)
  if actual != expected {
    abort("prefix admission changed aliases")
  }
  it.bench(fn() {
    let aliases = Array::make(count + 1, -1)
    if reference {
      cl_prefix_copy_scan_reference(body, aliases, sets, tees, types)
    } else {
      cl_mark_loop_prefix_copy_aliases(body, aliases, sets, tees, types)
    }
    it.keep(aliases)
  })
}

///|
test "bench coalesce prefix immutable 1 reference" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 1, 0, true)
}

///|
test "bench coalesce prefix immutable 1 counted" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 1, 0, false)
}

///|
test "bench coalesce prefix immutable 8 reference" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 8, 0, true)
}

///|
test "bench coalesce prefix immutable 8 counted" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 8, 0, false)
}

///|
test "bench coalesce prefix immutable 128 reference" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 128, 0, true)
}

///|
test "bench coalesce prefix immutable 128 counted" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 128, 0, false)
}

///|
test "bench coalesce prefix immutable 1024 reference" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 1024, 0, true)
}

///|
test "bench coalesce prefix immutable 1024 counted" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 1024, 0, false)
}

///|
test "bench coalesce prefix mutable 128 reference" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 128, 1, true)
}

///|
test "bench coalesce prefix mutable 128 counted" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 128, 1, false)
}

///|
test "bench coalesce prefix rejected 128 reference" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 128, 2, true)
}

///|
test "bench coalesce prefix rejected 128 counted" (it : @bench.T) {
  cl_prefix_copy_scan_bench(it, 128, 2, false)
}
