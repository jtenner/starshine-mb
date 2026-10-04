///|
test "command coalesce packed liveness preserves wide branch outputs and ownership" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"host\" \"f\" (func (param i32) (result i32))) (global (export \"state\") (mut i32) (i32.const 0)) (func (export \"run\") (param i32) (result i32) (local \{Array::make(128, "i32").join(" ")}) i32.const 7 local.set 64 i32.const 9 local.set 128 local.get 0 if local.get 64 call 0 global.set 0 else local.get 128 call 0 global.set 0 end local.get 64 local.get 128 i32.add global.get 0 i32.add))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["coalesce-locals"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(locals.length() < 128)
  assert_eq(cmd_deep_audit_count(body, fn(instr) { instr is @lib.Call(_) }), 2)
  assert_eq(
    cmd_deep_audit_count(body, fn(instr) { instr is @lib.GlobalSet(_) }),
    2,
  )
  let repeated = optimize_module_with_pass_flags(
    input,
    ["coalesce-locals"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(repeated).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
