///|
// Frozen predecessor: an owned row with a discarded membership index.
fn sl_cleanup_read_copy_reference(
  source : SlCleanupReadSet,
) -> SlCleanupReadSet {
  SlCleanupReadSet::new(source.reads.copy())
}

///|
fn sl_cleanup_read_copy_bench(
  it : @bench.T,
  width : Int,
  stride : Int,
  reference : Bool,
  mutate? : Bool = true,
  probe? : Bool = true,
) -> Unit raise {
  let source = SlCleanupReadSet::new(
    Array::makei(width, fn(index) { index * stride }),
  )
  let last = (width - 1) * stride
  let absent = width * stride + 1
  assert_true(source.contains(last))
  let saved = source.reads.copy()
  let expected = sl_cleanup_read_copy_reference(source)
  let actual = source.copy()
  expected.insert(absent)
  actual.insert(absent)
  assert_eq(actual.reads, expected.reads)
  assert_true(actual.contains(last))
  assert_true(actual.contains(absent))
  assert_false(source.contains(absent))
  it.bench(fn() {
    let copy = if reference {
      sl_cleanup_read_copy_reference(source)
    } else {
      source.copy()
    }
    if probe {
      it.keep(copy.contains(last))
    }
    if mutate {
      copy.insert(absent)
    }
    it.keep(copy)
  })
  assert_eq(source.reads, saved)
}

///|
test "bench cleanup read copy tiny=1 original" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 1, 1, true)
}

///|
test "bench cleanup read copy tiny=1 retained" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 1, 1, false)
}

///|
test "bench cleanup read copy tiny=8 original" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 8, 1, true)
}

///|
test "bench cleanup read copy tiny=8 retained" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 8, 1, false)
}

///|
test "bench cleanup read copy dense=64 original" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 64, 1, true)
}

///|
test "bench cleanup read copy dense=64 retained" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 64, 1, false)
}

///|
test "bench cleanup read copy dense=512 original" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 512, 1, true)
}

///|
test "bench cleanup read copy dense=512 retained" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 512, 1, false)
}

///|
test "bench cleanup read copy sparse=64 original" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 64, 64, true)
}

///|
test "bench cleanup read copy sparse=64 retained" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 64, 64, false)
}

///|
test "bench cleanup read copy dense=512 read only original" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 512, 1, true, mutate=false)
}

///|
test "bench cleanup read copy dense=512 read only retained" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 512, 1, false, mutate=false)
}

///|
test "bench cleanup read copy dense=512 unused original" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 512, 1, true, mutate=false, probe=false)
}

///|
test "bench cleanup read copy dense=512 unused retained" (it : @bench.T) {
  sl_cleanup_read_copy_bench(it, 512, 1, false, mutate=false, probe=false)
}
