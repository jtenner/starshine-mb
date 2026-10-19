///|
test "command RUME retains indirect callee after runtime table write" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (type $callback (func (result i32)))
      #|  (table 1 funcref)
      #|  (func $answer (type $callback) (i32.const 42))
      #|  (elem declare func $answer)
      #|  (func (export "run") (result i32)
      #|    (table.set (i32.const 0) (ref.func $answer))
      #|    (call_indirect (type $callback) (i32.const 0))))
    ),
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["remove-unused-module-elements"],
    OptimizeOptions::new(closed_world=true),
  ).unwrap()
  match output.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, body), _])) =>
      @debug.assert_eq(
        body,
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(42))]),
      )
    _ => fail("expected callable target and exported caller")
  }
}
