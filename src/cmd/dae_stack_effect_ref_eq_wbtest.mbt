///|
test "dae2 optimizing command retains the reference capture across observed binary equality" {
  let input = @wast.wast_to_binary_module(
    "(module (type $s (struct (field i32))) (import \"env\" \"base\" (func $base (result (ref null eq)))) (import \"env\" \"produce\" (func $produce (result (ref null eq)))) (import \"env\" \"observe\" (func $observe (param i32))) (func (export \"make\") (result (ref $s)) i32.const 7 struct.new $s) (func (export \"run\") (result (ref null eq)) (local (ref null eq)) call $base call $produce local.set 0 ref.null eq ref.eq call $observe local.get 0))",
  ).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(locals.length(), 1)
  assert_eq(
    body.last(),
    Some(@lib.Instruction::local_get(@lib.LocalIdx::new(0U))),
  )
  assert_eq(body.filter(fn(i) { i is @lib.RefEq }).length(), 1)
}
