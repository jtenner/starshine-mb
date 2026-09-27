///|
test "command SimplifyLocals modes retain the guarded captured call result" {
  for
    pass in [
      "simplify-locals", "simplify-locals-notee", "simplify-locals-nonesting", "simplify-locals-nostructure",
      "simplify-locals-notee-nostructure", "precompute-propagate",
    ] {
    let output = cmd_deep_audit_run(
      "(module (import \"host\" \"read\" (func $read (result i32))) (func (export \"run\") (result i32) (local i32) call $read local.set 0 block local.get 0 drop call $read drop end local.get 0))",
      pass,
    )
    assert_true(@validate.validate_module(output) is Ok(_))
    let flat : Array[@lib.Instruction] = []
    for instr in cmd_deep_audit_body(output) {
      match instr {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(body)) => flat.append(body)
        _ => flat.push(instr)
      }
    }
    assert_eq(flat, [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ])
  }
}

///|
test "command cleanup modes preserve uncaptured structured import calls" {
  for
    pass in [
      "simplify-locals", "simplify-locals-notee", "simplify-locals-nonesting", "simplify-locals-nostructure",
      "simplify-locals-notee-nostructure", "precompute-propagate",
    ] {
    let output = cmd_deep_audit_run(
      "(module (import \"host\" \"read\" (func $read (param i32) (result i32))) (func (export \"run\") block i32.const 1 call $read drop end block i32.const 2 call $read drop end))",
      pass,
    )
    assert_true(@validate.validate_module(output) is Ok(_))
    let flat : Array[@lib.Instruction] = []
    for instr in cmd_deep_audit_body(output) {
      match instr {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(body)) => flat.append(body)
        _ => flat.push(instr)
      }
    }
    assert_eq(flat, [
      @lib.Instruction::i32_const(1),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(2),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
    ])
  }
}
