///|
fn encoded_size_bench(
  it : @bench.T,
  count : Int,
  width : Int,
  shared : Bool,
  reference : Bool,
) -> Unit {
  let before = encoded_size_fixture(count, width)
  let funcs = before.code_sec.unwrap().0.mapi(fn(index, func) {
    if shared && index > 0 {
      func
    } else {
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new(Array::make(width + 1, @lib.Instruction::nop())),
      )
    }
  })
  let after = before.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(before).unwrap()
  @validate.validate_module(after).unwrap()
  let expected = (
    @binary.encode_module(before).unwrap().length(),
    @binary.encode_module(after).unwrap().length(),
  )
  if @binary.encoded_module_sizes(before, after).unwrap() != expected {
    abort("incorrect encoded sizes")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        (
          @binary.encode_module(before).unwrap().length(),
          @binary.encode_module(after).unwrap().length(),
        )
      } else {
        @binary.encoded_module_sizes(before, after).unwrap()
      },
    )
  })
}

///|
test "bench reuse-campaign encoded sizes shared functions=128 reference" (
  it : @bench.T,
) {
  encoded_size_bench(it, 128, 512, true, true)
}

///|
test "bench reuse-campaign encoded sizes shared functions=128 candidate" (
  it : @bench.T,
) {
  encoded_size_bench(it, 128, 512, true, false)
}

///|
test "bench reuse-campaign encoded sizes changed functions=128 reference" (
  it : @bench.T,
) {
  encoded_size_bench(it, 128, 512, false, true)
}

///|
test "bench reuse-campaign encoded sizes changed functions=128 candidate" (
  it : @bench.T,
) {
  encoded_size_bench(it, 128, 512, false, false)
}

///|
test "bench reuse-campaign encoded sizes small reference" (it : @bench.T) {
  encoded_size_bench(it, 1, 8, false, true)
}

///|
test "bench reuse-campaign encoded sizes small candidate" (it : @bench.T) {
  encoded_size_bench(it, 1, 8, false, false)
}
