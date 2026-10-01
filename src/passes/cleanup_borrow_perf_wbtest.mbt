///|
fn sl_cleanup_borrow_bench(
  it : @bench.T,
  width : Int,
  depth : Int,
  active : Bool,
  reference : Bool,
) -> Unit raise {
  let locals = Array::make(if active { width } else { 1 }, "i32").join(" ")
  let leaves = Array::makei(width, fn(local) {
    let mut text = if active {
      "i32.const 7 local.set \{local} local.get \{local} drop"
    } else {
      "local.get 0 i32.const 1 i32.add drop"
    }
    for _ in 0..<depth {
      text = "block \{text} end"
    }
    text
  }).join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (local \{locals}) \{leaves}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let expected = sl_cleanup_borrow_reference(body, SlCleanupReadSet::new([]))
  let actual = sl_cleanup_drop_dead_pairs_with_reads(
    body,
    SlCleanupReadSet::new([]),
  )
  assert_eq(actual, expected)
  assert_eq(physical_equal(actual, body), !active)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(local_types, @lib.Expr::new(actual))]),
    ),
  ).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        sl_cleanup_borrow_reference(body, SlCleanupReadSet::new([]))
      } else {
        sl_cleanup_drop_dead_pairs_with_reads(body, SlCleanupReadSet::new([]))
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench continuation cleanup width=1 depth=0 unchanged rebuild predecessor" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 1, 0, false, true)
}

///|
test "bench continuation cleanup width=1 depth=0 unchanged borrow" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 1, 0, false, false)
}

///|
test "bench continuation cleanup width=256 depth=0 unchanged rebuild predecessor" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 256, 0, false, true)
}

///|
test "bench continuation cleanup width=256 depth=0 unchanged borrow" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 256, 0, false, false)
}

///|
test "bench continuation cleanup width=32 depth=1 unchanged rebuild predecessor" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 32, 1, false, true)
}

///|
test "bench continuation cleanup width=32 depth=1 unchanged borrow" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 32, 1, false, false)
}

///|
test "bench continuation cleanup width=32 depth=16 unchanged rebuild predecessor" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 32, 16, false, true)
}

///|
test "bench continuation cleanup width=32 depth=16 unchanged borrow" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 32, 16, false, false)
}

///|
test "bench continuation cleanup width=32 depth=1 active rebuild predecessor" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 32, 1, true, true)
}

///|
test "bench continuation cleanup width=32 depth=1 active borrow" (it : @bench.T) {
  sl_cleanup_borrow_bench(it, 32, 1, true, false)
}

///|
test "bench continuation cleanup width=32 depth=0 active rebuild predecessor" (
  it : @bench.T,
) {
  sl_cleanup_borrow_bench(it, 32, 0, true, true)
}

///|
test "bench continuation cleanup width=32 depth=0 active borrow" (it : @bench.T) {
  sl_cleanup_borrow_bench(it, 32, 0, true, false)
}
