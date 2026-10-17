///|
fn dae2_structured_command_effects(
  body : Array[@lib.Instruction],
) -> (Int32, Int32) {
  let mut loads = 0
  let mut calls = 0
  for instr in body {
    match instr {
      @lib.I32Load(_) => loads += 1
      @lib.Call(@lib.FuncIdx(0U)) => calls += 1
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) => {
        let (child_loads, child_calls) = dae2_structured_command_effects(child)
        loads += child_loads
        calls += child_calls
      }
      @lib.If(_, yes, no) => {
        let (child_loads, child_calls) = dae2_structured_command_effects(yes)
        loads += child_loads
        calls += child_calls
        if no is Some(child) {
          let (child_loads, child_calls) = dae2_structured_command_effects(
            child,
          )
          loads += child_loads
          calls += child_calls
        }
      }
      _ => ()
    }
  }
  (loads, calls)
}

///|
test "DAE2 structured command keeps trapping removed arguments and callee effects" {
  let input = @wast.wast_to_binary_module(
    "(module (memory (export \"memory\") 1) (global $effects (export \"effects\") (mut i32) (i32.const 0)) (func $h (param i32 i32 i32 i64) (result i32) global.get $effects i32.const 1 i32.add global.set $effects local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) loop local.get 0 local.get 1 i32.load local.get 2 i64.const 9 call $h local.set 3 end local.get 3))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for pass_name in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass_name],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.empty_env()
      .with_module(output)
      .resolve_functype(output.func_sec.unwrap().0[0])
      .unwrap(),
      @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    )
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    assert_eq(
      dae2_structured_command_effects(body),
      (1, 1),
      msg="\{pass_name}: \{@lib.Expr::new(body)}",
    )
    assert_eq(output.mem_sec, input.mem_sec)
    assert_eq(output.global_sec, input.global_sec)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
