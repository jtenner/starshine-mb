///|
fn sl_constant_sink_bench(
  it : @bench.T,
  width : Int,
  blocked : Bool,
  reference : Bool,
) -> Unit raise {
  let stores = Array::makei(width, fn(local) {
    "i32.const 5 local.set \{local}"
  }).join(" ")
  let reads = Array::makei(width, fn(local) { "local.get \{local} drop" }).join(
    " ",
  )
  let barriers = if blocked {
    Array::make(width * 4, "call $effect").join(" ")
  } else {
    ""
  }
  let locals = Array::make(width, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func $effect)) (func (local \{locals}) \{stores} \{barriers} \{reads}))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let expected = sl_constant_sink_reference(body)
  let actual = sl_sink_constant_stores_flat(body)
  assert_eq(actual, expected)
  assert_eq(actual.1, if blocked { 0 } else { width })
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
    ),
  ).unwrap()
  it.bench(fn() {
    it.keep(
      if reference {
        sl_constant_sink_reference(body)
      } else {
        sl_sink_constant_stores_flat(body)
      },
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench constant sink pending=8 suffix reference" (it : @bench.T) {
  sl_constant_sink_bench(it, 8, false, true)
}

///|
test "bench constant sink pending=8 linear" (it : @bench.T) {
  sl_constant_sink_bench(it, 8, false, false)
}

///|
test "bench constant sink pending=32 suffix reference" (it : @bench.T) {
  sl_constant_sink_bench(it, 32, false, true)
}

///|
test "bench constant sink pending=32 linear" (it : @bench.T) {
  sl_constant_sink_bench(it, 32, false, false)
}

///|
test "bench constant sink pending=512 suffix reference" (it : @bench.T) {
  sl_constant_sink_bench(it, 512, false, true)
}

///|
test "bench constant sink pending=512 linear" (it : @bench.T) {
  sl_constant_sink_bench(it, 512, false, false)
}

///|
test "bench constant sink pending=32 barriers reference" (it : @bench.T) {
  sl_constant_sink_bench(it, 32, true, true)
}

///|
test "bench constant sink pending=32 barriers linear" (it : @bench.T) {
  sl_constant_sink_bench(it, 32, true, false)
}
