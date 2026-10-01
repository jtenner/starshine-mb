///|
test "DAE2 optimizing removes the sole literal capture across legacy try" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"combine\" (func $combine (param i32 i32))) (import \"env\" \"release\" (func $release (param i32))) (memory 1) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32 i32 i32 i32) block i32.const 99 local.set 5 local.get 5 drop end local.get 0 i32.load offset=4 local.set 3 local.get 1 local.get 3 i32.ge_s local.set 4 (try (result i32) (do local.get 5) (catch_all i32.const 13)) local.set 6 local.get 0 local.get 1 call $combine local.get 2 if local.get 0 call $release local.get 1 call $release end local.get 4 local.get 6 i32.add))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(legacy_release_cmd_has_99(body))
  assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
