///|
fn sl_get_count_cache_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let func = sl_get_count_cache_fixture(width, 3)
  let expected = simplify_locals_count_local_gets(func)
  let cache = simplify_locals_new_get_count_cache(func)
  if simplify_locals_counts_for_cycle(func, cache) != expected ||
    simplify_locals_counts_for_cycle(func, cache) != expected {
    abort("read-count benchmark changed immutable function facts")
  }
  let revision = @ir.hot_revision_current(func)
  it.bench(fn() {
    let cache = if reference {
      None
    } else {
      simplify_locals_new_get_count_cache(func)
    }
    let first = simplify_locals_counts_for_cycle(func, cache)
    let second = simplify_locals_counts_for_cycle(func, cache)
    it.keep((first, second))
  })
  if @ir.hot_revision_current(func) != revision ||
    simplify_locals_count_local_gets(func) != expected {
    abort("read-count benchmark mutated the HOT function")
  }
}

///|
test "bench SL unchanged count stages width=1 reference" (it : @bench.T) {
  sl_get_count_cache_bench(it, 1, true)
}

///|
test "bench SL unchanged count stages width=1 direct fallback" (it : @bench.T) {
  sl_get_count_cache_bench(it, 1, false)
}

///|
test "bench SL unchanged count stages width=128 reference" (it : @bench.T) {
  sl_get_count_cache_bench(it, 128, true)
}

///|
test "bench SL unchanged count stages width=128 cached" (it : @bench.T) {
  sl_get_count_cache_bench(it, 128, false)
}

///|
test "bench SL unchanged count stages width=4096 reference" (it : @bench.T) {
  sl_get_count_cache_bench(it, 4096, true)
}

///|
test "bench SL unchanged count stages width=4096 cached" (it : @bench.T) {
  sl_get_count_cache_bench(it, 4096, false)
}

///|
fn sl_get_count_active_bench(
  it : @bench.T,
  width : Int,
  reuse : Bool,
  mode : Int,
) -> Unit {
  let input = sl_get_count_active_fixture(width)
  let policy = sl_get_count_policies()[mode].1
  let reference = sl_get_count_run_fixture(input, policy, false)
  let output = sl_get_count_run_fixture(input, policy, true)
  let saved = @binary.encode_module(input).unwrap()
  if @binary.encode_module(output).unwrap() !=
    @binary.encode_module(reference).unwrap() ||
    output.code_sec == input.code_sec {
    abort("cached read-count benchmark changed output or lost active cleanup")
  }
  @validate.validate_module(output).unwrap()
  it.bench(fn() { it.keep(sl_get_count_run_fixture(input, policy, reuse)) })
  if @binary.encode_module(input).unwrap() != saved {
    abort("cached cleanup benchmark mutated input")
  }
}

///|
test "bench SL active count cleanup mode=0 width=1 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, false, 0)
}

///|
test "bench SL active count cleanup mode=0 width=1 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, true, 0)
}

///|
test "bench SL active count cleanup mode=0 width=128 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, false, 0)
}

///|
test "bench SL active count cleanup mode=0 width=128 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, true, 0)
}

///|
test "bench SL active count cleanup mode=1 width=1 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, false, 1)
}

///|
test "bench SL active count cleanup mode=1 width=1 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, true, 1)
}

///|
test "bench SL active count cleanup mode=1 width=128 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, false, 1)
}

///|
test "bench SL active count cleanup mode=1 width=128 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, true, 1)
}

///|
test "bench SL active count cleanup mode=2 width=1 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, false, 2)
}

///|
test "bench SL active count cleanup mode=2 width=1 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, true, 2)
}

///|
test "bench SL active count cleanup mode=2 width=128 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, false, 2)
}

///|
test "bench SL active count cleanup mode=2 width=128 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, true, 2)
}

///|
test "bench SL active count cleanup mode=3 width=1 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, false, 3)
}

///|
test "bench SL active count cleanup mode=3 width=1 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, true, 3)
}

///|
test "bench SL active count cleanup mode=3 width=128 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, false, 3)
}

///|
test "bench SL active count cleanup mode=3 width=128 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, true, 3)
}

///|
test "bench SL active count cleanup mode=4 width=1 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, false, 4)
}

///|
test "bench SL active count cleanup mode=4 width=1 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 1, true, 4)
}

///|
test "bench SL active count cleanup mode=4 width=128 reference" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, false, 4)
}

///|
test "bench SL active count cleanup mode=4 width=128 cached" (it : @bench.T) {
  sl_get_count_active_bench(it, 128, true, 4)
}
