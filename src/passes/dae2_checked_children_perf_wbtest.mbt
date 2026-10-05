///|
test "bench DAE2 checked child sources tiny" (it : @bench.T) {
  dae2_entry_interval_bench(it, 2, 0, false)
}

///|
test "bench DAE2 checked child sources shared depth" (it : @bench.T) {
  dae2_entry_interval_bench(it, 2, 64, false)
}

///|
test "bench DAE2 checked child sources unrelated writes" (it : @bench.T) {
  dae2_entry_interval_bench(it, 33, 32, false)
}
