///|
fn dae_branch_payload_fixture(
  branch : String,
  overwrite_first : Bool,
) -> @lib.Module {
  let prefix = if overwrite_first { "i32.const 7 local.set 0" } else { "" }
  pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 1)) (func (export \"run\") (param i32) (result i32) global.get $g local.get 0 call $callee) (func $callee (param i32 i32) (result i32) \{prefix} block (result i32) local.get 0 \{branch} end i32.const 5 local.set 0))",
  )
}

///|
test "DAE entry liveness includes carried branch payload reads before later writes" {
  for branch in ["br 0", "local.get 1 br_if 0", "local.get 1 br_table 0 0"] {
    let input = dae_branch_payload_fixture(branch, false)
    @validate.validate_module(input).unwrap()
    let live = dae_hot_param_entry_liveness(input, 1, 2).unwrap()
    assert_true(
      live[0],
      msg="branch payload consumes parameter entry: \{branch}",
    )
    assert_true(dae_incoming_parameter_liveness(input, 1, 2)[0])
  }
}

///|
test "DAE branch payload analysis still removes entries overwritten before use" {
  for branch in ["br 0", "local.get 1 br_if 0", "local.get 1 br_table 0 0"] {
    let input = dae_branch_payload_fixture(branch, true)
    @validate.validate_module(input).unwrap()
    let live = dae_hot_param_entry_liveness(input, 1, 2).unwrap()
    assert_false(live[0], msg="earlier write kills parameter entry: \{branch}")
  }
}

///|
test "DAE entry liveness sees self tee under an if operand with unrelated branch" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 1)) (func (export \"f\") (result i32) (drop (call $callee (i32.const 127))) (global.get $g)) (func $callee (param i32) (result i32) (global.set $g (if (result i32) (global.get $g) (then (local.tee 0 (local.get 0))) (else (i32.const 0)))) (block $B (result i32) (br_if $B (i32.const 0) (i32.const 0)))))",
  )
  @validate.validate_module(input).unwrap()
  assert_true(dae_hot_param_entry_liveness(input, 1, 1).unwrap()[0])
  assert_true(dae_incoming_parameter_liveness(input, 1, 1)[0])
}

///|
test "DAE entry liveness includes GC branch payload before a null overwrite" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (func (export \"run\") (result i32) i32.const 23 struct.new $s call $callee ref.as_non_null struct.get $s 0) (func $callee (param (ref null $s)) (result (ref null $s)) block (result (ref null $s)) local.get 0 br 0 end ref.null $s local.set 0))",
  )
  @validate.validate_module(input).unwrap()
  assert_true(dae_hot_param_entry_liveness(input, 1, 1).unwrap()[0])
  assert_true(dae_incoming_parameter_liveness(input, 1, 1)[0])
}
