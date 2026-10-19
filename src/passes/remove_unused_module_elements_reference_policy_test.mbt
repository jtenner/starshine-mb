///|
test "RUME closed world preserves static indirect callees" {
  let input =
    #|(module
    #|  (type $callback (func (result i32)))
    #|  (table 1 funcref)
    #|  (func $answer (type $callback) (i32.const 42))
    #|  (elem (i32.const 0) func $answer)
    #|  (func (export "run") (result i32)
    #|    (call_indirect (type $callback) (i32.const 0))))
  let output = pass_test_run_pipeline(
    input,
    ["remove-unused-module-elements"],
    options=HotPipelineOptions::new(closed_world=true),
  ).unwrap()
  match output.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, body), _])) =>
      @debug.assert_eq(
        body,
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(42))]),
      )
    _ => fail("expected callable target and indirect caller")
  }
}

///|
test "RUME closed world preserves runtime indirect callees in either discovery order" {
  let prefix =
    #|(module
    #|  (type $callback (func (result i32)))
    #|  (table 1 funcref)
    #|  (func $answer (type $callback) (i32.const 42))
    #|  (elem declare func $answer)
  let install =
    #|  (func (export "install")
    #|    (table.set (i32.const 0) (ref.func $answer)))
  let run =
    #|  (func (export "run") (result i32)
    #|    (call_indirect (type $callback) (i32.const 0)))
  for functions in [install + run, run + install] {
    let output = pass_test_run_pipeline(
      prefix + functions + ")",
      ["remove-unused-module-elements"],
      options=HotPipelineOptions::new(closed_world=true),
    ).unwrap()
    match output.code_sec {
      Some(@lib.CodeSec([@lib.Func(_, body), _, _])) =>
        @debug.assert_eq(
          body,
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(42))]),
        )
      _ => fail("expected callable target, table writer, and indirect caller")
    }
  }
}
