///|
fn dae_reverse_signature_fixture(
  types : Int,
  helpers : Int,
  active : Bool,
) -> @lib.Module {
  let wat = ["(module"]
  for index in 0..<types {
    wat.push("(type $s\{index} (struct (field i32)))")
  }
  wat.push(
    "(type $sig (func (param i32) (result i32))) (import \"m\" \"value\" (func $value (result i32)))",
  )
  for index in 0..<helpers {
    wat.push("(func $h\{index} (type $sig) local.get 0 i32.const 1 i32.add)")
    wat.push("(func (export \"run\{index}\") (param i32) (result i32)")
    wat.push(if active { "i32.const 7" } else { "local.get 0" })
    wat.push("call $h\{index})")
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
test "DAE reverse literal reuse prunes an imported-offset signature without repeated type walks" {
  let input = dae_reverse_signature_fixture(24, 1, true)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let resolutions = [0]
  let output = dae_literal_replay_fixture_run(
    input,
    original,
    [0],
    type_resolutions=Some(resolutions),
  )
  let reference = dae_literal_replay_fixture_run(
    input,
    original,
    [0],
    reuse_function_types=false,
  )
  assert_true(output.changed)
  assert_eq(output.primary_def, 0)
  assert_eq(dae_wb_param_count(output.mod_out, 1), 0)
  assert_eq(
    @binary.encode_module(output.mod_out).unwrap(),
    @binary.encode_module(reference.mod_out).unwrap(),
  )
  assert_eq(resolutions[0], 0)
  @validate.validate_module(output.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE reverse literal reuse preserves nonconstant calls across a wide ordered candidate scan" {
  let input = dae_reverse_signature_fixture(24, 8, false)
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let resolutions = [0]
  let output = dae_literal_replay_fixture_run(
    input,
    original,
    [0],
    type_resolutions=Some(resolutions),
  )
  assert_false(output.changed)
  assert_eq(@binary.encode_module(output.mod_out).unwrap(), saved)
  assert_eq(resolutions[0], 0)
  @validate.validate_module(output.mod_out).unwrap()
}
