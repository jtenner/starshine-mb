///|
fn sl_root_constants_bench(
  it : @bench.T,
  width : Int,
  active : Bool,
) -> Unit raise {
  let locals = Array::make(width, "i32").join(" ")
  let text = Array::makei(width, fn(local) {
    if active {
      "i32.const 7 local.tee \{local} drop block local.get \{local} drop end"
    } else {
      "local.get \{local} i32.const 1 i32.add drop"
    }
  }).join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (local \{locals}) \{text}))",
  )
  let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let expected = sl_inline_root_constants(body)
  assert_eq(physical_equal(expected, body), !active)
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(local_types, @lib.Expr::new(expected))]),
    ),
  ).unwrap()
  it.bench(fn() { it.keep(sl_inline_root_constants(body)) })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "bench root constants cold width1" (it : @bench.T) {
  sl_root_constants_bench(it, 1, false)
}

///|
test "bench root constants cold width256" (it : @bench.T) {
  sl_root_constants_bench(it, 256, false)
}

///|
test "bench root constants active width1" (it : @bench.T) {
  sl_root_constants_bench(it, 1, true)
}

///|
test "bench root constants active width32" (it : @bench.T) {
  sl_root_constants_bench(it, 32, true)
}

///|
test "bench root constants active width256" (it : @bench.T) {
  sl_root_constants_bench(it, 256, true)
}

///|
test "bench root constants sparse high local indices" (it : @bench.T) {
  let locals = Array::make(8193, "i32").join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local \{locals}) i32.const 7 local.set 8192 block (result i32) local.get 8192 end))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  it.bench(fn() { it.keep(sl_inline_root_constants(body)) })
}

///|
test "bench root constants rejected float growth" (it : @bench.T) {
  let input = pass_test_module_from_wat(
    "(module (func (param f64) (result f64) f64.const 1 local.set 0 local.get 0 local.get 0 f64.add local.get 0 f64.add))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_true(physical_equal(sl_inline_root_constants(body), body))
  it.bench(fn() { it.keep(sl_inline_root_constants(body)) })
}
