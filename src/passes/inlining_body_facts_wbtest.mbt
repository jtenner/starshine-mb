///|
test "inlining body facts preserve tail-call eligibility with one traversal" {
  let modules = [
    "(module (func $f (param i32) (result i32) loop local.get 0 br_if 0 end local.get 0))",
    "(module (func $f (result i32) block (result i32) i32.const 7 end))", "(module (func $f (param i32) (result i32) local.get 0 if (result i32) i32.const 1 else i32.const 2 end))",
    "(module (func $f (result i32) try_table (result i32) return_call $f end))",
  ]
  for source in modules {
    let mod_ = pass_test_module_from_wat(source)
    let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
    let expected_shape = inl_scan_shape_instrs(body)
    let expected_size = inl_count_instrs(body)
    let visits = [0]
    let (calls, loops, tries, tails, size) = inl_measure_body(
      body,
      visits=Some(visits),
    )
    assert_eq((calls, loops, tries, tails), expected_shape)
    assert_eq(size, expected_size)
    assert_eq(visits[0], size)
  }
}
