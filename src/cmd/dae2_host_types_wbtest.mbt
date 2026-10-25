///|
test "command DAE2 retains host ref.test and ref.cast target signatures" {
  for cast in [false, true] {
    let input = @passes.pass_test_module_from_wat(
      "(module (type $B (func (param i64))) (import \"env\" \"get\" (func $get (result funcref))) (func $b (type $B) (param i64)) (func (export \"run\") (result i32) unreachable))",
    )
    let target = @lib.HeapType::new(@lib.TypeIdx::new(0U))
    let body = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
    if cast {
      body.push(@lib.Instruction::ref_cast(false, target))
      body.push(@lib.Instruction::ref_is_null())
    } else {
      body.push(@lib.Instruction::ref_test(false, target))
    }
    let bodies = input.code_sec.unwrap().0.copy()
    bodies[1] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
    let input = input.with_code_sec(@lib.CodeSec::new(bodies))
    assert_true(@validate.validate_module(input).is_ok())
    for pass in ["dae2", "dae2-optimizing"] {
      let output = optimize_module_with_pass_flags(
        input,
        [pass],
        OptimizeOptions::new(closed_world=true),
      ).unwrap()
      assert_true(@validate.validate_module(output).is_ok())
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
      let target = match body[1] {
        @lib.RefTest(false, false, @lib.HeapType(target)) if !cast => target
        @lib.RefCast(false, false, @lib.HeapType(target)) if cast => target
        other => fail("expected retained runtime type target, got \{other}")
      }
      let env = @validate.Env::new().with_module(output)
      @debug.assert_eq(
        env.resolve_functype(target),
        Some(@lib.FuncType::new([@lib.ValType::i64()], [])),
      )
    }
  }
}
