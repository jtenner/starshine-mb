///|
fn balanced_range_command_calls(
  instrs : Array[@lib.Instruction],
  calls : Array[UInt],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.Call(@lib.FuncIdx(index)) => calls.push(index)
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        balanced_range_command_calls(body, calls)
      @lib.If(_, yes, no) => {
        balanced_range_command_calls(yes, calls)
        match no {
          Some(body) => balanced_range_command_calls(body, calls)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
test "structured local cleanup command preserves producer and consumer order" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result i64))) (import \"env\" \"consume\" (func $consume (param i64))) (import \"env\" \"tick\" (func $tick)) (func (export \"run\") (local i64 i64 i64 i64 i64 i64 i64 i64) block call $produce local.set 0 call $tick local.get 0 call $consume call $produce local.tee 1 call $consume local.get 1 call $consume end))",
  ).unwrap()
  for pass_name in ["simplify-locals", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass_name],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let calls = []
    balanced_range_command_calls(body, calls)
    assert_eq(calls, [0U, 2U, 1U, 0U, 1U, 1U])
    if pass_name == "dae2-optimizing" {
      assert_eq(locals.length(), 1)
    }
  }
}
