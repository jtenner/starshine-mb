///|
test "command optimize-instructions flattens tuple wrappers in producer order" {
  let output = cmd_deep_audit_run(
    "(module (type (func (result i32 i64 f32 f64))) (global (mut i64) (i64.const 0)) (func (export \"run\") (result i32) (local i32 i64 f32 f64) block (type 0) i32.const 1159 call 1 f32.const 59.5 f64.const 87.25 end local.set 3 local.set 2 local.set 1 local.set 0 local.get 0) (func (result i64) i64.const 123 global.set 0 i64.const 22))",
    "optimize-instructions",
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.filter(fn(i) { i is @lib.Block(_, _) }).length(), 0)
  assert_eq(
    body.filter(fn(i) {
      i is @lib.I32Const(_) ||
      i is @lib.Call(_) ||
      i is @lib.F32Const(_) ||
      i is @lib.F64Const(_)
    }),
    [
      @lib.Instruction::i32_const(@lib.I32(1159)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::f32_const(@lib.F32(59.5)),
      @lib.Instruction::f64_const(@lib.F64(87.25)),
    ],
  )
}

///|
test "command optimize-instructions cleans carried tuple lanes on its raw return path" {
  let output = cmd_deep_audit_run(
    "(module (type (func (result i32 i64))) (global (mut i64) (i64.const 0)) (func (export \"run\") (result i32 i64) block (type 0) i32.const 7 call 1 end try_table nop end) (func (result i64) i64.const 123 global.set 0 i64.const 9))",
    "optimize-instructions",
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.length(), 3)
  assert_eq(body[0], @lib.Instruction::i32_const(@lib.I32(7)))
  assert_eq(body[1], @lib.Instruction::call(@lib.FuncIdx::new(1U)))
  assert_true(body[2] is @lib.TryTable(_, _, _))
}
