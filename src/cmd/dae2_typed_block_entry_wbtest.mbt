///|
test "command DAE2 modes preserve typed block entry producers and prune unused parameters" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (import \"host\" \"f\" (func (param i32) (result i32))) (global (export \"state\") (mut i32) (i32.const 0)) (func $callee (param i32 i32) (result i32) (local i32) i32.const 17 global.set 0 i32.const 19 call 0 local.get 0 block (param i32 i32) (result i32) i32.div_s end local.set 2 local.get 2 call 0) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 99 call $callee))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
  }
}

///|
test "command DAE2 discarded typed block results retain one entry import evaluation" {
  for pass in ["dae2", "dae2-optimizing"] {
    let output = cmd_deep_audit_run(
      "(module (import \"host\" \"f\" (func (param i32) (result i32))) (func $h (param i32 i32 i64) (result i32) local.get 0 call 0 local.get 1 block (param i32 i32) (result i32) i32.div_s end) (func (export \"run\") (param i32) i32.const 19 local.get 0 i64.const 99 call $h drop i32.const 23 call 0 drop))",
      pass,
    )
    @validate.validate_module(output).unwrap()
    let calls : Array[UInt] = []
    balanced_range_command_calls(cmd_deep_audit_body(output), calls)
    assert_eq(calls, [0U])
    assert_eq(cmd_deep_audit_body(output), [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_div_s(),
      @lib.Instruction::drop(),
    ])
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [])),
    )
  }
}
