///|
fn dae2_local_counting_perf_run(
  it : @bench.T,
  width : Int,
  nested : Bool,
  direct : Bool,
) -> Unit raise {
  let leaf = "local.get 0 local.set 1 local.get 1 local.tee 2 drop"
  let body = Array::make(
    width,
    if nested {
      "block loop \{leaf} end end"
    } else {
      leaf
    },
  ).join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local i32 i32) \{body}))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let reads = Array::make(3, 0)
  let writes = Array::make(3, 0)
  let old_reads = Array::make(3, 0)
  let old_writes = Array::make(3, 0)
  pass_lower_count_locals(body, reads, writes)
  parameter_alias_reference_pass_lower_count_locals(body, old_reads, old_writes)
  assert_eq(reads, old_reads)
  assert_eq(writes, old_writes)
  it.bench(fn() {
    reads.fill(0)
    writes.fill(0)
    if direct {
      pass_lower_count_locals(body, reads, writes)
    } else {
      parameter_alias_reference_pass_lower_count_locals(body, reads, writes)
    }
    it.keep(reads)
    it.keep(writes)
  })
}

///|
test "bench raw local counting 8 flat original" (it : @bench.T) {
  dae2_local_counting_perf_run(it, 8, false, false)
}

///|
test "bench raw local counting 8 flat direct" (it : @bench.T) {
  dae2_local_counting_perf_run(it, 8, false, true)
}

///|
test "bench raw local counting 512 flat original" (it : @bench.T) {
  dae2_local_counting_perf_run(it, 512, false, false)
}

///|
test "bench raw local counting 512 flat direct" (it : @bench.T) {
  dae2_local_counting_perf_run(it, 512, false, true)
}

///|
test "bench raw local counting 8 structured original" (it : @bench.T) {
  dae2_local_counting_perf_run(it, 8, true, false)
}

///|
test "bench raw local counting 8 structured direct" (it : @bench.T) {
  dae2_local_counting_perf_run(it, 8, true, true)
}

///|
test "bench raw local counting 512 structured original" (it : @bench.T) {
  dae2_local_counting_perf_run(it, 512, true, false)
}

///|
test "bench raw local counting 512 structured direct" (it : @bench.T) {
  dae2_local_counting_perf_run(it, 512, true, true)
}
