///|
test "dispatcher local-cse invalidates global read at idempotent call" {
  let source =
    #|(module
    #|  (global $g (mut i32) (i32.const 0))
    #|  (@binaryen.idempotent)
    #|  (func $set (result i32)
    #|    (if (i32.eqz (global.get $g))
    #|      (then (global.set $g (i32.const 1))))
    #|    (i32.const 0))
    #|  (func (result i32)
    #|    (drop (i32.add (global.get $g) (i32.const 2)))
    #|    (drop (call $set))
    #|    (i32.add (global.get $g) (i32.const 2))))
  let input = @passes.pass_test_module_from_wat(source)
  let output = optimize_module_with_pass_flags(
    input,
    ["local-cse"],
    OptimizeOptions::new(),
  ).unwrap()
  let body = match output.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(body))])) => body
    _ => fail("expected two function bodies")
  }
  let mut reads = 0
  for instr in body {
    match instr {
      @lib.GlobalGet(_) => reads += 1
      _ => ()
    }
  }
  @debug.assert_eq(reads, 2)
}
