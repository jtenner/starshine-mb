///|
test "DAE2 optimizing dispatcher removes wide reverse aliases without duplicating calls" {
  let prefix = Array::makei(128, fn(i) {
    "call $produce local.set \{i} local.get \{i} call $consume local.get \{i} call $consume"
  }).join(" ")
  let locals = Array::make(130, "i32").join(" ")
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (export \"run\") (local \{locals}) \{prefix} call $produce local.set 129 local.get 129 call $consume local.get 129 local.set 128 local.get 128 call $consume local.get 128 call $consume))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 129)
  assert_eq(
    body
    .filter(fn(i) { i is @lib.LocalSet(_) || i is @lib.LocalTee(_) })
    .length(),
    129,
  )
  assert_eq(
    body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(0U)) }).length(),
    129,
  )
  assert_eq(
    body.filter(fn(i) { i is @lib.Call(@lib.FuncIdx(1U)) }).length(),
    259,
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
