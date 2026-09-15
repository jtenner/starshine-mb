///|
fn cmd_dae2_exception_parity_dispatch(body : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.Throw(_) => count += 1
      @lib.TryTable(_, _, @lib.Expr(nested)) => {
        count += 1
        count += cmd_dae2_exception_parity_dispatch(nested)
      }
      @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
        count += cmd_dae2_exception_parity_dispatch(nested)
      @lib.If(_, yes, no) => {
        count += cmd_dae2_exception_parity_dispatch(yes)
        if no is Some(no) {
          count += cmd_dae2_exception_parity_dispatch(no)
        }
      }
      _ => ()
    }
  }
  count
}

///|
test "DAE2 command exception parity folds known local dispatch" {
  for pass in ["dae2", "dae2-optimizing"] {
    let input = @passes.pass_test_module_from_wat(
      "(module (tag (param i32)) (global (export \"effects\") (mut i32) (i32.const 0)) (func (param i32) (result i32) global.get 0 i32.const 1 i32.add global.set 0 local.get 0) (func (param i32) global.get 0 i32.const 2 i32.add global.set 0) (func (export \"run\") (result i32) (try (result i32) (do (throw 0 (i32.const 37))) (catch 0 (call 0) (call 1) (i32.const 37)) (catch_all (i32.const 36)))))",
    )
    let output = optimize_module_with_pass_flags(
      input,
      [pass],
      OptimizeOptions::new(),
    ).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
    @debug.assert_eq(cmd_dae2_exception_parity_dispatch(body), 0)
  }
}
