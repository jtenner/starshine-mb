///|
test "dae2 optimizing command removes a repeated local copy of a call result" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result i64))) (import \"env\" \"consume\" (func $consume (param i64))) (func (export \"run\") (local i64 i64) call $produce local.set 0 local.get 0 call $consume local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume))",
  ).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  assert_eq(body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(0U)) }).length(), 1)
  assert_eq(body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(1U)) }).length(), 3)
}
