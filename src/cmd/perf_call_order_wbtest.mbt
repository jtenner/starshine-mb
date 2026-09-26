///|
test "command coalesce and dae2 preserve repeated carried call order" {
  for pass in ["coalesce-locals", "dae2"] {
    let output = cmd_deep_audit_run(
      "(module (import \"m\" \"value\" (func (result i32))) (import \"m\" \"barrier\" (func)) (func (export \"run\") (result i32) (local i32 i32) call 0 call 1 local.set 0 call 0 call 1 local.set 1 local.get 0 local.get 1 i32.add))",
      pass,
    )
    assert_true(@validate.validate_module(output) is Ok(_))
    let calls : Array[@lib.Instruction] = []
    for instr in cmd_deep_audit_body(output) {
      if instr is @lib.Call(_) {
        calls.push(instr)
      }
    }
    assert_eq(calls, [
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
  }
}
