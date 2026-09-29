///|
fn dae_loop_signature_fixture(count : Int, parameterized : Bool) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string("(module")
  for _ in 0..<(count - 1) {
    wat.write_string(" (type (func))")
  }
  wat.write_string(
    if parameterized {
      " (type (func (param i32)))"
    } else {
      " (type (func))"
    },
  )
  for _ in 0..<count {
    wat.write_string(
      if parameterized {
        " (func (type 0) i32.const 1 loop (type \{count - 1}) drop end)"
      } else {
        " (func (type 0) loop (type \{count - 1}) end)"
      },
    )
  }
  wat.write_string(")")
  pass_test_module_from_wat(wat.to_string())
}

///|
test "DAE loop admission shares one signature prefix and refreshes changed types" {
  let input = dae_loop_signature_fixture(16, true)
  let infos = dae_collect_current_function_analysis(input, 16).function_infos
  let visits = [0]
  assert_eq(
    dae_parameter_loop_admission(input, 0, 16, infos, type_visits=Some(visits)),
    Array::make(16, false),
  )
  assert_true(visits[0] <= 16)
  let changed = dae_loop_signature_fixture(16, false)
  let changed_infos = dae_collect_current_function_analysis(changed, 16).function_infos
  assert_eq(
    dae_parameter_loop_admission(changed, 0, 16, changed_infos),
    Array::make(16, true),
  )
}
