///|
test "command coalesce branch joins retain distinct selected values" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module (func (export "run") (param i32) (result i32)
      #| (local i32 i32 i32)
      #| i32.const 7 local.set 1 i32.const 9 local.set 2
      #| local.get 0 if local.get 1 local.set 3
      #| else local.get 2 local.set 3 end local.get 3))
    ),
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["coalesce-locals"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_true(locals.length() < 3)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
