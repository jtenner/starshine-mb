///|
fn code_folding_label_map_bench(it : @bench.T, count : Int) -> Unit {
  let left_base = 100000
  let right_base = 200000
  it.bench(fn() {
    let map = code_folding_label_map_new()
    for idx in 0..<count {
      if !code_folding_label_map_add(map, left_base + idx, right_base + idx) {
        abort("distinct label pair rejected")
      }
    }
    it.keep(map)
  })
}

///|
test "CodeFolding label map preserves pair bijection" {
  let map = code_folding_label_map_new()
  assert_true(code_folding_label_map_add(map, 1, 101))
  assert_true(code_folding_label_map_add(map, 2, 102))
  assert_true(code_folding_label_map_add(map, 1, 101))
  assert_false(code_folding_label_map_add(map, 1, 102))
  assert_false(code_folding_label_map_add(map, 2, 101))
  assert_eq(code_folding_label_map_lookup_left(map, 1), 0)
  assert_eq(code_folding_label_map_lookup_right(map, 102), 1)
  assert_eq(map.left_labels.length(), 2)
}

///|
test "bench code-folding label map count=1024" (it : @bench.T) {
  code_folding_label_map_bench(it, 1024)
}

///|
test "bench code-folding label map count=2048" (it : @bench.T) {
  code_folding_label_map_bench(it, 2048)
}
