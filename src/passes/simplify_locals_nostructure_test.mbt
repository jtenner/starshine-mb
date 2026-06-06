///|
fn simplify_locals_nostructure_test_many_i32_locals(count : Int) -> String {
  let out = StringBuilder::new()
  for i = 0; i < count; i = i + 1 {
    out.write_string(" (local i32)")
  }
  out.to_string()
}

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
test "simplify-locals-nostructure skips root stack/local-set call hazards" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      "(module (func $alloc (param i32 i32) (result i32) (local.get 0)) (func (param i32 i32) (local i32) local.get 0 i32.const 2 call $alloc local.set 2 local.get 2 local.get 1 call $alloc drop))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure stack/local-set hazard success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
  )
}

///|
test "simplify-locals-notee-nostructure skips root stack/local-set call hazards" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      "(module (func $alloc (param i32 i32) (result i32) (local.get 0)) (func (param i32 i32) (local i32) local.get 0 i32.const 2 call $alloc local.set 2 local.get 2 local.get 1 call $alloc drop))",
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure stack/local-set hazard success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-notee-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
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
fn simplify_locals_nostructure_test_large_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  let mut idx = 0
  while idx < 101 {
    out.write_string("  (func $f")
    out.write_string(idx.to_string())
    out.write_string(" (result i32) (local i32) i32.const ")
    out.write_string((idx & 1).to_string())
    out.write_string(" local.set 0 local.get 0)\n")
    idx += 1
  }
  out.write_string(")")
  out.to_string()
}

///|
test "simplify-locals-notee-nostructure runs safe large modules" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      simplify_locals_nostructure_test_large_module(),
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure large module success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[simplify-locals-notee-nostructure]:skip-large-module")
    }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(100U))
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure folds dead exact-slot set-copy local" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) (local.set 2 (block $block (result i32) (if (local.get 0) (then (i32.const 7) (br $block))) (i32.const 9))) (local.set 1 (local.get 2)) (i32.add (local.get 1) (local.get 1))))",
      ["simplify-locals-nostructure", "reorder-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure set-copy fold success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("Local 1"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure folds exact-slot set-copy across cleanup nop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) loop $l block $block (result i32) (if (local.get 0) (then (return (i32.const 0)))) (i32.const 9) end local.set 2 nop local.get 2 local.set 1 (br_if $l (local.get 0)) end (i32.add (local.get 1) (local.get 1))))",
      ["simplify-locals-nostructure", "vacuum", "reorder-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure nop-separated set-copy fold success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("Local 1"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps tee before dependent loads" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) local.get 0 local.tee 5 i32.load offset=20 align=1 local.get 5 i32.load offset=12 align=1 local.get 5 i32.load offset=16 align=1 local.set 4 local.set 3 local.set 2 local.get 2 local.get 3 local.get 4 i32.add i32.add))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dependent-load success, got \{err}",
      )
  }

  let instrs = match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(@lib.Func(_, @lib.Expr(instrs))) => instrs
        None => fail("expected first function body")
      }
    None => fail("expected code section")
  }
  match instrs[0] {
    @lib.LocalGet(@lib.LocalIdx(local_id)) => @debug.assert_eq(local_id, 0U)
    _ => fail("expected source pointer local.get to remain first")
  }
  match instrs[1] {
    @lib.LocalTee(@lib.LocalIdx(local_id)) => @debug.assert_eq(local_id, 5U)
    _ => fail("expected dependent-load local.tee to remain before loads")
  }
}

///|
test "simplify-locals-nostructure preserves used condition load tee" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $incref (param i32)) (func $decref (param i32)) (func $free (param i32)) (func (param $io i32) (result i32) (local $field i32)" +
      simplify_locals_nostructure_test_many_i32_locals(110) +
      " (local $cnt i32) (block $block (if (i32.const 0) (then (return (i32.const 0))) (else (br $block))) (unreachable)) (local.set $field (i32.load offset=32 align=1 (local.get $io))) (if (i32.gt_s (local.tee $cnt (i32.load align=1 (local.get $io))) (i32.const 1)) (then nop (i32.store align=1 (local.get $io) (i32.sub (local.get $cnt) (i32.const 1))) (call $incref (local.get $field))) (else (if (i32.eq (local.get $cnt) (i32.const 1)) (then (call $decref (i32.load offset=40 align=1 (local.get $io))) (call $free (local.get $io)))))) (call $decref (local.get $field)) (i32.const 1)))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure condition tee preservation success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 112)"), msg=pretty)
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
