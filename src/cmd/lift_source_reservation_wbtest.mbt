///|
test "shared lift source reservations retain active large-pass dispatch work" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (func $callee (param i32 i64) (result i32) (local i32 i32)
      #|  local.get 0 local.set 2 local.get 2 local.set 3
      #|  i32.const 2 i32.const 3 i32.add local.get 3 i32.add)
      #| (func (export "run") (param i32) (result i32)
      #|  local.get 0 i64.const 99 call $callee))
    ),
  ).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for
    pass in [
      "dae2", "dae2-optimizing", "coalesce-locals", "optimize-instructions",
    ] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass],
      OptimizeOptions::new(),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    if pass == "dae2" || pass == "dae2-optimizing" {
      assert_eq(
        @validate.Env::new()
        .with_module(output)
        .get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
        Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
      )
    } else if pass == "coalesce-locals" {
      assert_true(locals.length() < 2)
    } else {
      assert_eq(
        cmd_deep_audit_count(body, fn(instr) {
          instr is @lib.I32Const(@lib.I32(5))
        }),
        1,
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
