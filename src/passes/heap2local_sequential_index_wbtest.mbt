///|
test "heap2local sequential write slots sort without root-sized state" {
  let writes = [(900, 9), (3, 1), (401, 7), (17, 4)]
  let sorted = h2l_sort_sequential_write_slots(writes)
  assert_eq(sorted, [(3, 1), (17, 4), (401, 7), (900, 9)])
}

///|
test "bench heap2local sequential write slots=256" (it : @bench.T) {
  let writes : Array[(Int, Int)] = []
  for index = 0; index < 256; index = index + 1 {
    writes.push((4096 - index * 7, index))
  }
  it.bench(fn() {
    let sorted = h2l_sort_sequential_write_slots(writes)
    it.keep(sorted)
  })
}
