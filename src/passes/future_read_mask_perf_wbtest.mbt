///|
fn sl_future_read_bench(
  it : @bench.T,
  width : Int,
  mode : Int,
  reference : Bool,
) -> Unit raise {
  let locals = Array::make(width, "i32").join(" ")
  let body_text = match mode {
    0 =>
      Array::makei(width, fn(local) {
        "i32.const 7 local.set \{local} local.get \{local} drop"
      }).join(" ")
    1 =>
      Array::make(width, "i32.const 7 local.set 0 local.get 0 drop").join(" ")
    2 =>
      "i32.const 7 local.set 0 local.get 0 drop " +
      Array::make(width, "nop").join(" ")
    _ => Array::make(width, "local.get 0 i32.const 1 i32.add drop").join(" ")
  }
  let input = pass_test_module_from_wat(
    "(module (func (local \{locals}) \{body_text}))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let expected = sl_cleanup_future_reference(body, SlCleanupReadSet::new([]))
  let actual = sl_cleanup_drop_dead_pairs_with_reads(
    body,
    SlCleanupReadSet::new([]),
  )
  assert_eq(actual, expected)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(local_types, @lib.Expr::new(actual))]),
    ),
  ).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        sl_cleanup_future_reference(body, SlCleanupReadSet::new([]))
      } else {
        sl_cleanup_drop_dead_pairs_with_reads(body, SlCleanupReadSet::new([]))
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench future-read width=1 distinct predecessor" (it : @bench.T) {
  sl_future_read_bench(it, 1, 0, true)
}

///|
test "bench future-read width=1 distinct bounded" (it : @bench.T) {
  sl_future_read_bench(it, 1, 0, false)
}

///|
test "bench future-read width=32 distinct predecessor" (it : @bench.T) {
  sl_future_read_bench(it, 32, 0, true)
}

///|
test "bench future-read width=32 distinct bounded" (it : @bench.T) {
  sl_future_read_bench(it, 32, 0, false)
}

///|
test "bench future-read width=512 distinct predecessor" (it : @bench.T) {
  sl_future_read_bench(it, 512, 0, true)
}

///|
test "bench future-read width=512 distinct bounded" (it : @bench.T) {
  sl_future_read_bench(it, 512, 0, false)
}

///|
test "bench future-read width=32 reused predecessor" (it : @bench.T) {
  sl_future_read_bench(it, 32, 1, true)
}

///|
test "bench future-read width=32 reused bounded" (it : @bench.T) {
  sl_future_read_bench(it, 32, 1, false)
}

///|
test "bench future-read width=512 single-query predecessor" (it : @bench.T) {
  sl_future_read_bench(it, 512, 2, true)
}

///|
test "bench future-read width=512 single-query bounded" (it : @bench.T) {
  sl_future_read_bench(it, 512, 2, false)
}

///|
test "bench future-read width=512 unchanged predecessor" (it : @bench.T) {
  sl_future_read_bench(it, 512, 3, true)
}

///|
test "bench future-read width=512 unchanged bounded" (it : @bench.T) {
  sl_future_read_bench(it, 512, 3, false)
}

///|
test "bench future-read width=512 reused predecessor" (it : @bench.T) {
  sl_future_read_bench(it, 512, 1, true)
}

///|
test "bench future-read width=512 reused bounded" (it : @bench.T) {
  sl_future_read_bench(it, 512, 1, false)
}
