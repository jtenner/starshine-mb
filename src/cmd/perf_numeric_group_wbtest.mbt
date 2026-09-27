///|
test "command OI groups compressed numeric declarations without moving parameters or effects" {
  let output = cmd_deep_audit_run(
    "(module (import \"env\" \"r32\" (func $r32 (result i32))) (import \"env\" \"r64\" (func $r64 (result f64))) (import \"env\" \"s32\" (func $s32 (param i32))) (import \"env\" \"s64\" (func $s64 (param f64))) (func (export \"run\") (param i32) (local i32 f64 i32 f64) call $r32 local.set 1 call $r64 local.set 2 call $r32 local.set 3 call $r64 local.set 4 local.get 0 i32.const 0 i32.add call $s32 local.get 1 call $s32 local.get 2 call $s64 local.get 3 call $s32 local.get 4 call $s64))",
    "optimize-instructions",
  )
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.runs(), [
    @lib.LocalRun::new(2U, @lib.ValType::i32()),
    @lib.LocalRun::new(2U, @lib.ValType::f64()),
  ])
  let reads : Array[UInt] = []
  let calls : Array[UInt] = []
  for instr in body {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) => reads.push(raw)
      @lib.Call(@lib.FuncIdx(raw)) => calls.push(raw)
      _ => ()
    }
  }
  assert_eq(reads, [0U, 1U, 3U, 2U, 4U])
  assert_eq(calls, [0U, 1U, 0U, 1U, 2U, 2U, 3U, 2U, 3U])
}
