///|
fn vacuum_scan_order_bench(
  it : @bench.T,
  kind : Int,
  depth : Int,
  active : Bool,
  reference : Bool,
) -> Unit raise {
  let parent = vacuum_scan_order_parent()
  let body = if active {
    vacuum_scan_order_bodies()[kind]
  } else {
    let mut tail = @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new(Array::make(64, @lib.Instruction::nop())),
    )
    for _ in 0..<depth {
      tail = @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([tail]),
      )
    }
    let row = Array::make(23, @lib.Instruction::drop())
    row.push(tail)
    row
  }
  let expected = vacuum_scan_order_result(kind, body, parent, true)
  assert_eq(vacuum_scan_order_result(kind, body, parent, false), expected)
  assert_eq(expected is Some(_), active)
  it.bench(fn() {
    it.keep(vacuum_scan_order_result(kind, body, parent, reference))
  })
}

///|
test "bench vacuum scan order 0 flat original" (it : @bench.T) {
  vacuum_scan_order_bench(it, 0, 0, false, true)
}

///|
test "bench vacuum scan order 0 flat shape-first" (it : @bench.T) {
  vacuum_scan_order_bench(it, 0, 0, false, false)
}

///|
test "bench vacuum scan order 0 nested original" (it : @bench.T) {
  vacuum_scan_order_bench(it, 0, 128, false, true)
}

///|
test "bench vacuum scan order 0 nested shape-first" (it : @bench.T) {
  vacuum_scan_order_bench(it, 0, 128, false, false)
}

///|
test "bench vacuum scan order 0 admitted original" (it : @bench.T) {
  vacuum_scan_order_bench(it, 0, 0, true, true)
}

///|
test "bench vacuum scan order 0 admitted shape-first" (it : @bench.T) {
  vacuum_scan_order_bench(it, 0, 0, true, false)
}

///|
test "bench vacuum scan order 1 flat original" (it : @bench.T) {
  vacuum_scan_order_bench(it, 1, 0, false, true)
}

///|
test "bench vacuum scan order 1 flat shape-first" (it : @bench.T) {
  vacuum_scan_order_bench(it, 1, 0, false, false)
}

///|
test "bench vacuum scan order 1 nested original" (it : @bench.T) {
  vacuum_scan_order_bench(it, 1, 128, false, true)
}

///|
test "bench vacuum scan order 1 nested shape-first" (it : @bench.T) {
  vacuum_scan_order_bench(it, 1, 128, false, false)
}

///|
test "bench vacuum scan order 1 admitted original" (it : @bench.T) {
  vacuum_scan_order_bench(it, 1, 0, true, true)
}

///|
test "bench vacuum scan order 1 admitted shape-first" (it : @bench.T) {
  vacuum_scan_order_bench(it, 1, 0, true, false)
}

///|
test "bench vacuum scan order 2 flat original" (it : @bench.T) {
  vacuum_scan_order_bench(it, 2, 0, false, true)
}

///|
test "bench vacuum scan order 2 flat shape-first" (it : @bench.T) {
  vacuum_scan_order_bench(it, 2, 0, false, false)
}

///|
test "bench vacuum scan order 2 nested original" (it : @bench.T) {
  vacuum_scan_order_bench(it, 2, 128, false, true)
}

///|
test "bench vacuum scan order 2 nested shape-first" (it : @bench.T) {
  vacuum_scan_order_bench(it, 2, 128, false, false)
}

///|
test "bench vacuum scan order 2 admitted original" (it : @bench.T) {
  vacuum_scan_order_bench(it, 2, 0, true, true)
}

///|
test "bench vacuum scan order 2 admitted shape-first" (it : @bench.T) {
  vacuum_scan_order_bench(it, 2, 0, true, false)
}
