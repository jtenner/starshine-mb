///|
test "ssa-nomerge indexes supported drop-result-if parents in one node scan" {
  let source = StringBuilder()
  source.write_string("(module (func ")
  for _ in 0..<128 {
    source.write_string(
      "(drop (if (result i32) (i32.const 1) (then (i32.const 2)) (else (i32.const 3)))) ",
    )
  }
  source.write_string("))")
  let func = pass_test_lift_first_func(source.to_string())
  let visits = [0]
  let supported = ssa_nomerge_supported_drop_result_ifs(
    func,
    visits=Some(visits),
  )
  assert_eq(visits[0], @ir.hot_node_count(func))
  assert_eq(supported.filter(fn(value) { value }).length(), 128)
}
