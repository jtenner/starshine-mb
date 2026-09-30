///|
test "dae2 optimizing command cleans nested scalar forwarding captures" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result f64))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (result f64) (local f64) block (result f64) call $produce end local.set 0 i32.const 7 call $consume block (result f64) block (result f64) local.get 0 end end))",
  ).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_false(body.any(fn(instr) { instr is @lib.Block(_, _) }))
  assert_eq(body.filter(fn(instr) { instr is @lib.Call(_) }).length(), 2)
}
