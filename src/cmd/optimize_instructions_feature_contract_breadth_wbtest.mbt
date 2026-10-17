///|
test "dispatcher tiny SIMD fill and copy honor target feature contracts" {
  let base = @passes.pass_test_module_from_wat(
    "(module (memory 1) (func (param i32 i32) local.get 0 i32.const 171 i32.const 16 memory.fill local.get 0 local.get 1 i32.const 16 memory.copy))",
  )
  for
    (payloads, allowed) in [
      ([], true),
      ([b"\x00"], true),
      ([b"\x01\x2b\x07simd128"], true),
      ([b"\x01\x2d\x07simd128"], false),
      ([b"\x01\x2b\x07simd128", b"\x01\x2d\x07simd128"], false),
      ([b"\x01\x2d\x07simd128", b"\x01\x2b\x07simd128"], false),
      ([b"\x00\xff"], false),
    ] {
    let input = base.with_custom_secs(
      payloads.map(fn(payload) {
        @lib.CustomSec::new(@lib.Name::new("target_features"), payload)
      }),
    )
    let output = optimize_module_with_pass_flags(
      input,
      ["optimize-instructions", "optimize-instructions"],
      OptimizeOptions::new(),
    ).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(
      cmd_deep_audit_count(body, fn(instr) { instr is @lib.V128Store(_) }),
      if allowed {
        2
      } else {
        0
      },
    )
    @debug.assert_eq(
      cmd_deep_audit_count(body, fn(instr) { instr is @lib.MemoryFill(_) }),
      if allowed {
        0
      } else {
        1
      },
    )
    @debug.assert_eq(
      cmd_deep_audit_count(body, fn(instr) { instr is @lib.MemoryCopy(_, _) }),
      if allowed {
        0
      } else {
        1
      },
    )
    @debug.assert_eq(output.custom_secs, input.custom_secs)
  }
}
