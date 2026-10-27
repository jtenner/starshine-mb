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
  bodies[1] = @lib.Func::new(
    locals,
    @lib.Expr::new([
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::ref_test(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  let input = input.with_code_sec(@lib.CodeSec::new(bodies))
  assert_true(@validate.validate_module(input) is Ok(_))
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
  assert_true(@validate.validate_module(output) is Ok(_))
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

///|
fn dae2_host_type_fixture(cast : Bool, nested : Bool) -> @lib.Module {
  let input = pass_test_module_from_wat(
    "(module (type $B (func (param i64) (result i32))) (import \"env\" \"get\" (func $get (result funcref))) (func $b (type $B) (param i64) (result i32) i32.const 7) (func (export \"run\") (result i32) unreachable))",
  )
  let target = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let body = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  if cast {
    body.push(@lib.Instruction::ref_cast(true, target))
    body.push(@lib.Instruction::ref_is_null())
  } else {
    body.push(@lib.Instruction::ref_test(true, target))
  }
  let body = if nested {
    [
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new(body),
      ),
    ]
  } else {
    body
  }
  let bodies = input.code_sec.unwrap().0.copy()
  bodies[1] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  input.with_code_sec(@lib.CodeSec::new(bodies))
}

///|
fn dae2_host_target(
  body : Array[@lib.Instruction],
  cast : Bool,
) -> @lib.TypeIdx raise {
  for instruction in body {
    match instruction {
      @lib.Block(_, @lib.Expr(child)) => return dae2_host_target(child, cast)
      @lib.RefTest(nullable, exact, @lib.HeapType(target)) if !cast => {
        assert_true(nullable)
        assert_false(exact)
        return target
      }
      @lib.RefCast(nullable, exact, @lib.HeapType(target)) if cast => {
        assert_true(nullable)
        assert_false(exact)
        return target
      }
      _ => ()
    }
  }
  fail("expected retained runtime type target")
}

///|
test "dae2 retains host ref.test parameter and result types in both modes" {
  for pass in ["dae2", "dae2-optimizing"] {
    for nested in [false, true] {
      let input = dae2_host_type_fixture(false, nested)
      assert_true(@validate.validate_module(input) is Ok(_))
      let output = run_hot_pipeline(
        input,
        HotPipelineOptions::new(closed_world=true),
        [pass],
      ).unwrap()
      assert_true(@validate.validate_module(output) is Ok(_))
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
      let target = dae2_host_target(body, false)
      let env = @validate.Env::new().with_module(output)
      @debug.assert_eq(
        env.resolve_functype(target),
        Some(@lib.FuncType::new([@lib.ValType::i64()], [@lib.ValType::i32()])),
      )
      // Pin the runtime type, while still optimizing an unrelated direct body.
      @debug.assert_eq(
        dae2_test_signature(output, 1),
        @lib.FuncType::new([], []),
      )
    }
  }
}

///|
test "dae2 retains host ref.cast parameter and result types in both modes" {
  for pass in ["dae2", "dae2-optimizing"] {
    for nested in [false, true] {
      let input = dae2_host_type_fixture(true, nested)
      assert_true(@validate.validate_module(input) is Ok(_))
      let output = run_hot_pipeline(
        input,
        HotPipelineOptions::new(closed_world=true),
        [pass],
      ).unwrap()
      assert_true(@validate.validate_module(output) is Ok(_))
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
      let target = dae2_host_target(body, true)
      let env = @validate.Env::new().with_module(output)
      @debug.assert_eq(
        env.resolve_functype(target),
        Some(@lib.FuncType::new([@lib.ValType::i64()], [@lib.ValType::i32()])),
      )
    }
  }
}
