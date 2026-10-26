///|
fn db19_f06_bench(it : @bench.T, literal : String, count : Int32) -> Unit {
  let text = StringBuilder::new()
  text.write_string("(module (func ")
  if count == 0 {
    text.write_string("nop")
  }
  for _ in 0..<count {
    text.write_string("i32.const ")
    text.write_string(literal)
    text.write_string(" drop ")
  }
  text.write_string("))")
  let input = text.to_string()
  let mut callbacks = 0
  it.bench(count=5, fn() {
    callbacks = callbacks + 1
    it.keep(@wast.wast_to_binary_module(input))
  })
  println("DB19_CALLBACKS=\{callbacks}")
  let checked = @wast.wast_to_binary_module(input)
  println("DB19_VALIDATION_ACCEPTED=\{checked is Ok(_)}")
  match checked {
    Err(err) => println("DB19_VALIDATION_ERROR=\{err}")
    Ok(module_) =>
      match module_.code_sec {
        Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instructions))])) =>
          for instruction in instructions {
            if instruction is @lib.I32Const(@lib.I32(value)) {
              println("DB19_FIRST_I32=\{value}")
              break
            }
          }
        _ => ()
      }
  }
}

///|
test "bench db19 F06 no scalar constant" (it : @bench.T) {
  db19_f06_bench(it, "", 0)
}

///|
test "bench db19 F06 signed small x256" (it : @bench.T) {
  db19_f06_bench(it, "-17", 256)
}

///|
test "bench db19 F06 signed minimum x256" (it : @bench.T) {
  db19_f06_bench(it, "-2147483648", 256)
}

///|
test "bench db19 F06 unsigned maximum x256" (it : @bench.T) {
  db19_f06_bench(it, "4294967295", 256)
}

///|
test "bench db19 F06 unsigned upper half x256" (it : @bench.T) {
  db19_f06_bench(it, "2147483648", 256)
}

///|
test "bench db19 F06 invalid above unsigned maximum" (it : @bench.T) {
  db19_f06_bench(it, "4294967296", 1)
}

///|
test "bench db19 F06 invalid below signed minimum" (it : @bench.T) {
  db19_f06_bench(it, "-2147483649", 1)
}
