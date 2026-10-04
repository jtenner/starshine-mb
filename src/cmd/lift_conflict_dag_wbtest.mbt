///|
test "command passes preserve shared multivalue producers and active signature cleanup" {
  let chain = Array::make(8, "i64.const 99 call $dup i32.add").join(" ")
  let input = @wast.wast_to_binary_module(
    "(module (import \"host\" \"f\" (func (param i32) (result i32))) (global (export \"state\") (mut i32) (i32.const 0)) (func $dup (param i32 i64) (result i32 i32) global.get 0 i32.const 1 i32.add global.set 0 local.get 0 local.get 0) (func (export \"run\") (param i32) (result i32) (local \{Array::make(128, "i32").join(" ")}) i32.const 7 local.set 64 i32.const 9 local.set 128 local.get 64 local.get 128 i32.add \{chain} i32.const 17 local.set 0 local.get 0 i32.add call 0))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
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
    let @lib.Func(_, @lib.Expr(dup_body)) = output.code_sec.unwrap().0[0]
    assert_eq(
      cmd_deep_audit_count(dup_body, fn(instr) { instr is @lib.GlobalSet(_) }),
      1,
    )
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    assert_eq(
      cmd_deep_audit_count(body, fn(instr) { instr is @lib.Call(_) }),
      9,
    )
    if pass == "dae2" || pass == "dae2-optimizing" {
      assert_eq(
        @validate.Env::new()
        .with_module(output)
        .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
        Some(
          @lib.FuncType::new([@lib.ValType::i32()], [
            @lib.ValType::i32(),
            @lib.ValType::i32(),
          ]),
        ),
      )
    } else if pass == "coalesce-locals" {
      assert_true(locals.length() < 128)
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
