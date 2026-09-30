///|
test "dae2 optimizing command removes repeated immutable parameter aliases" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"consume\" (func $consume (param f64))) (func (export \"run\") (param f64) (result f64) (local f64) local.get 0 local.set 1 local.get 1 call $consume local.get 1 call $consume local.get 1))",
  ).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_eq(body.filter(fn(i) { i is @lib.Call(_) }).length(), 2)
  assert_eq(
    body.filter(fn(i) { i is @lib.LocalGet(@lib.LocalIdx(0U)) }).length(),
    3,
  )
}
