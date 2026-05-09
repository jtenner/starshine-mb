///|
test "simplify-locals-nostructure sinks straight-line single-use sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure accepts O4z spelling" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure does not create tees for multi-use locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0 local.get 0 i32.add))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure preserves Binaryen const-nop loop shape" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result f64) loop (result f64) f64.const 1.0 nop end))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(locals, @lib.Expr([@lib.Loop(_, @lib.Expr(body))]))]
      )
    ) => {
      @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f64()]))
      @debug.assert_eq(body.length(), 3)
      @debug.assert_eq(body[0], @lib.Instruction::nop())
      @debug.assert_eq(body[1], @lib.Instruction::nop())
      match body[2] {
        @lib.F64Const(_) => ()
        other => fail("expected trailing f64 const after nops, got \{other}")
      }
    }
    other =>
      fail(
        "expected one loop body after no-tee no-structure pass, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "simplify-locals-nostructure does not synthesize if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure exact slot replays code-pushing and tuple cleanup before vacuum and reorder-locals" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      simplify_locals_nostructure_exact_slot_passes(),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure exact slot replay success, got \{err}",
      )
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected exact slot replay module to validate, got \{err}")
  }

  let starts = trace.filter(fn(line) {
    line.contains("pass[") && line.contains(":start")
  })
  assert_true(starts.length() >= 5, msg=starts.to_string())
  assert_true(
    starts[0].contains("pass[code-pushing]:start"),
    msg=starts.to_string(),
  )
  assert_true(
    starts[1].contains("pass[tuple-optimization]:start"),
    msg=starts.to_string(),
  )
  assert_true(
    starts[2].contains("pass[simplify-locals-nostructure]:start"),
    msg=starts.to_string(),
  )
  assert_true(starts[3].contains("pass[vacuum]:start"), msg=starts.to_string())
  assert_true(
    starts[4].contains("pass[reorder-locals]:start"),
    msg=starts.to_string(),
  )

  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, _)])) =>
      @debug.assert_eq(locals, @lib.Locals::empty())
    other =>
      fail(
        "expected exact slot replay single-function output, got \{@debug.to_string(other)}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
}

///|
test "simplify-locals-nostructure exact slot keeps the no-structure if boundary" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      simplify_locals_nostructure_exact_slot_passes(),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure exact slot no-structure replay success, got \{err}",
      )
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact slot no-structure replay module to validate, got \{err}",
      )
  }

  let starts = trace.filter(fn(line) {
    line.contains("pass[") && line.contains(":start")
  })
  assert_true(starts.length() >= 5, msg=starts.to_string())
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
}
