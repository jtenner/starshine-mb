///|
test "command Coalesce indexed coloring preserves argument order" {
  let source = StringBuilder::new()
  source.write_string(
    "(module (import \"host\" \"use\" (func $use (param i32))) (func (export \"run\") (local",
  )
  for _ in 0..<128 {
    source.write_string(" i32")
  }
  source.write_string(") ")
  for idx in 0..<128 {
    source.write_string(
      "i32.const \{idx} local.set \{idx} local.get \{idx} call $use ",
    )
  }
  source.write_string("))")
  let output = cmd_deep_audit_run(source.to_string(), "coalesce-locals")
  assert_true(@validate.validate_module(output) is Ok(_))
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_true(locals.length() < 128)
  let body = cmd_deep_audit_body(output)
  let mut calls = 0
  let constants : Array[@lib.I32] = []
  for instr in body {
    match instr {
      @lib.Call(@lib.FuncIdx(0U)) => calls += 1
      @lib.I32Const(value) => constants.push(value)
      _ => ()
    }
  }
  assert_eq(calls, 128)
  assert_eq(constants, Array::makei(128, fn(i) { @lib.I32(i) }))
}
