///|
test "OI command tuple parity removes branchless lowering wrappers" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type (func (result i32 i64 f32 f64))) (global (mut i64) (i64.const 0)) (func (export \"run\") (result i64) (local i32 i64 f32 f64) block (type 0) i32.const 1159 call 1 f32.const 59.5 f64.const 87.25 end local.set 3 local.set 2 local.set 1 local.set 0 local.get 1) (func (result i64) i64.const 123 global.set 0 i64.const 22))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_false(body.any(fn(i) { i is @lib.Block(_, _) }))
  @debug.assert_eq(body.filter(fn(i) { i is @lib.Call(_) }).length(), 1)
}
