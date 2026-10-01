///|
test "DAE2 optimizing cleans a load capture without dropping structured argument releases" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"env\" \"combine\" (func $combine (param i32 i32))) (import \"env\" \"release\" (func $release (param i32))) (memory 1) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32 i32) local.get 0 i32.load offset=4 local.set 3 local.get 1 local.get 3 i32.ge_s local.set 4 local.get 0 local.get 1 call $combine local.get 2 if local.get 0 call $release local.get 1 call $release end local.get 4))",
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["dae2-optimizing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  let calls : Array[@lib.Instruction] = []
  profitable_alias_test_calls(body, calls)
  assert_eq(
    calls,
    [0U, 1U, 1U].map(fn(index) {
      @lib.Instruction::call(@lib.FuncIdx::new(index))
    }),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
