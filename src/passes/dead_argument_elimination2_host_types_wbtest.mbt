///|
test "dae2 preserves concrete ref.test signature for host-origin funcref" {
  // Round-2 source review: host values may have the original $B runtime type.
  let source =
    #|(module
    #|  (type $B (func (param i64)))
    #|  (import "env" "get" (func $get (result funcref)))
    #|  (func $b (type $B) (param i64))
    #|  (func (export "run") (result i32)
    #|    unreachable))
  let input = match @wast.wast_to_binary_module(source) {
    Ok(mod_) => mod_
    Err(err) => fail("fixture parse failed: \{err}")
  }
  // The WAT parser lacks ref.test; install the exact review instruction sequence.
  let bodies = input.code_sec.unwrap().0.copy()
  let @lib.Func(locals, _) = bodies[1]
  bodies[1] = @lib.Func::new(locals, @lib.Expr::new([
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::ref_test(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  ]))
  let input = input.with_code_sec(@lib.CodeSec::new(bodies))
  assert_true(@validate.validate_module(input).is_ok())
  let original = @validate.Env::new().with_module(input)
  @debug.assert_eq(
    original.resolve_functype(@lib.TypeIdx::new(0U)),
    Some(@lib.FuncType::new([@lib.ValType::i64()], [])),
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  let target = match body.last() {
    Some(@lib.RefTest(_, _, @lib.HeapType(target))) => target
    other => fail("expected retained ref.test, got \{other}")
  }
  let env = @validate.Env::new().with_module(output)
  @debug.assert_eq(
    env.resolve_functype(target),
    Some(@lib.FuncType::new([@lib.ValType::i64()], [])),
  )
}
