///|
test "OI tuple parity removes branchless lowering wrappers without reordering lanes" {
  for (result_type, selected) in [("i32", 0), ("i64", 1)] {
    let input = pass_test_module_from_wat(
      "(module (type (func (result i32 i64 f32 f64))) (global (mut i64) (i64.const 0)) (func (export \"run\") (result \{result_type}) (local i32 i64 f32 f64) block (type 0) i32.const 1159 call 1 f32.const 59.5 f64.const 87.25 end local.set 3 local.set 2 local.set 1 local.set 0 local.get \{selected}) (func (result i64) i64.const 123 global.set 0 i64.const 22))",
    )
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "optimize-instructions",
    ]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(body.filter(fn(i) { i is @lib.Block(_, _) }), [])
    let producers = body.filter(fn(i) {
      match i {
        @lib.I32Const(_)
        | @lib.I64Const(_)
        | @lib.F32Const(_)
        | @lib.F64Const(_)
        | @lib.Call(_) => true
        _ => false
      }
    })
    @debug.assert_eq(producers, [
      @lib.Instruction::i32_const(@lib.I32(1159)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::f32_const(@lib.F32(59.5)),
      @lib.Instruction::f64_const(@lib.F64(87.25)),
    ])
  }
}
