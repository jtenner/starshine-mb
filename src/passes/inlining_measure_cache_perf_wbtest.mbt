///|
fn inl_measure_cache_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let body = Array::make(width, @lib.Instruction::nop())
  let cache = InlBodyMeasureCache::new(1)
  let expected = inl_measure_body(body)
  if cache.measure(0, body) != expected {
    abort("body facts changed")
  }
  it.bench(fn() {
    for _ in 0..<128 {
      it.keep(
        if reference {
          inl_measure_body(body)
        } else {
          cache.measure(0, body)
        },
      )
    }
  })
}

///|
test "bench reuse-campaign inlining repeated body facts width=16 reference" (
  it : @bench.T,
) {
  inl_measure_cache_bench(it, 16, true)
}

///|
test "bench reuse-campaign inlining repeated body facts width=16 cached" (
  it : @bench.T,
) {
  inl_measure_cache_bench(it, 16, false)
}

///|
test "bench reuse-campaign inlining repeated body facts width=1024 reference" (
  it : @bench.T,
) {
  inl_measure_cache_bench(it, 1024, true)
}

///|
test "bench reuse-campaign inlining repeated body facts width=1024 cached" (
  it : @bench.T,
) {
  inl_measure_cache_bench(it, 1024, false)
}

///|
fn inl_measure_dirty_cache_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let body = Array::make(width, @lib.Instruction::nop())
  let cache = InlBodyMeasureCache::new(1)
  let touched = [true]
  let mapping = [0]
  it.bench(fn() {
    for _ in 0..<128 {
      if reference {
        it.keep(inl_measure_body(body))
      } else {
        cache.remap(touched, mapping)
        it.keep(cache.measure(0, body))
      }
    }
  })
}

///|
test "bench reuse-campaign inlining dirty body width=16 reference" (
  it : @bench.T,
) {
  inl_measure_dirty_cache_bench(it, 16, true)
}

///|
test "bench reuse-campaign inlining dirty body width=16 cached" (it : @bench.T) {
  inl_measure_dirty_cache_bench(it, 16, false)
}

///|
test "bench reuse-campaign inlining dirty body width=1024 reference" (
  it : @bench.T,
) {
  inl_measure_dirty_cache_bench(it, 1024, true)
}

///|
test "bench reuse-campaign inlining dirty body width=1024 cached" (
  it : @bench.T,
) {
  inl_measure_dirty_cache_bench(it, 1024, false)
}
