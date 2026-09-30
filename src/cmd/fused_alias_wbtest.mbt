///|
test "dae2 optimizing alias replay preserves earlier reference default consumption" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result externref))) (import \"env\" \"consume\" (func $consume (param externref))) (func (export \"run\") (local externref externref) local.get 0 call $consume call $produce local.set 1 local.get 1 call $consume local.get 1 local.set 0 local.get 0 call $consume local.get 0 call $consume))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(0U)) }).length(), 1)
  assert_eq(body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(1U)) }).length(), 4)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
