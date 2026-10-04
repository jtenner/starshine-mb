///|
test "bench subtree reads tiny active" (it : @bench.T) {
  sl_cleanup_nowrite_bench(it, 1, 0, true, false)
}

///|
test "bench subtree reads depth16 active" (it : @bench.T) {
  sl_cleanup_nowrite_bench(it, 1, 16, true, false)
}

///|
test "bench subtree reads depth64 active" (it : @bench.T) {
  sl_cleanup_nowrite_bench(it, 1, 64, true, false)
}

///|
test "bench subtree reads width32 depth16 active" (it : @bench.T) {
  sl_cleanup_nowrite_bench(it, 32, 16, true, false)
}

///|
test "bench subtree reads width32 depth16 unchanged" (it : @bench.T) {
  sl_cleanup_nowrite_bench(it, 32, 16, false, false)
}

///|
test "bench subtree reads width256 flat unchanged" (it : @bench.T) {
  sl_cleanup_nowrite_bench(it, 256, 0, false, false)
}
