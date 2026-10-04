///|
fn encoded_string_free_bench(
  it : @bench.T,
  count : Int,
  width : Int,
  strings : Bool,
) -> Unit {
  let funcs = Array::makei(count, fn(_) {
    let body = Array::make(width, Instruction::nop())
    if strings {
      body.push(Instruction::string_const(b"shared"))
      body.push(Instruction::drop())
    }
    Func::new(Locals::empty(), Expr::new(body))
  })
  let module_ = encoded_string_free_module(funcs)
  @validate.validate_module(module_).unwrap()
  let size = encode_module(module_).unwrap().length()
  if encoded_module_sizes(module_, module_).unwrap() != (size, size) {
    abort("string-free size benchmark lost exact bytes")
  }
  it.bench(fn() { it.keep(encoded_module_sizes(module_, module_).unwrap()) })
}

///|
test "bench string-free sizing tiny empty pool" (it : @bench.T) {
  encoded_string_free_bench(it, 1, 8, false)
}

///|
test "bench string-free sizing wide empty pool" (it : @bench.T) {
  encoded_string_free_bench(it, 64, 256, false)
}

///|
test "bench string-free sizing tiny nonempty pool" (it : @bench.T) {
  encoded_string_free_bench(it, 1, 8, true)
}

///|
test "bench string-free sizing wide nonempty pool" (it : @bench.T) {
  encoded_string_free_bench(it, 64, 256, true)
}
