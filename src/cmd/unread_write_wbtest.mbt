///|
test "command optimizing DAE2 removes unread load and counter tees inside loops" {
  let wat = "(module (import \"env\" \"produce\" (func $produce (param i32) (result i32))) (memory 1) (func (export \"run\") (param i32) (result i32) (local i32 i32 i32) i32.const 0 local.set 1 loop local.get 1 local.get 0 i32.lt_s if i32.const 0 i32.load local.tee 2 call $produce drop local.get 1 local.tee 3 i32.const 1 i32.add local.set 1 br 1 end end local.get 1))"
  let output = cmd_deep_audit_run(wat, "dae2-optimizing")
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 1)
  // The complete command fixture's effectful call, trapping load and mutable
  // loop counter survive; the removed locals have no reads anywhere.
  let input = @wast.wast_to_binary_module(wat).unwrap()
  assert_eq(output.import_sec, input.import_sec)
  assert_eq(output.mem_sec, input.mem_sec)
  assert_eq(output.func_sec, input.func_sec)
  assert_eq(output.export_sec, input.export_sec)
}
