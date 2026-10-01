///|
test "statement cleanup consumers preserve wide independent call order" {
  let locals = Array::make(128, "i32").join(" ")
  let middle = Array::makei(127, fn(i) { "local.get \{i + 1} call $consume" }).join(
    " ",
  )
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (local \{locals}) call $produce local.set 0 \{middle} local.get 0 call $consume))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
  let calls = original.filter(fn(i) { i is @lib.Call(_) })
  for
    pass in [
      "dae2-optimizing", "dae-optimizing", "simplify-locals", "simplify-locals-nonesting",
      "simplify-locals-notee", "simplify-locals-nostructure", "simplify-locals-notee-nostructure",
      "inlining-optimizing", "simplify-globals-optimizing",
    ] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(body.filter(fn(i) { i is @lib.Call(_) }), calls)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
