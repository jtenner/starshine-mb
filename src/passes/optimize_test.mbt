///|
test "run_hot_pipeline applies optimize preset through the hot pass manager" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) nop i32.const 7))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"))
  assert_true(pretty.contains("i32.const"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "vacuum removes dropped pure scalar expressions" {
  let input = pass_test_module_from_wat(
    "(module (func (local i32) (drop (i32.add (i32.const 1) (i32.const 2))) (local.set 0 (i32.const 4))))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected vacuumed module to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ])
    other => fail("expected single vacuumed function output, got \{other}")
  }
}

///|
test "vacuum unwraps block that only contains unreachable" {
  let input = pass_test_module_from_wat("(module (func block unreachable end))")
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr([instr]))])) =>
      match instr {
        @lib.Instruction::Unreachable => ()
        other => fail("expected unwrapped unreachable, got \{other}")
      }
    other => fail("expected single vacuumed unreachable output, got \{other}")
  }
}

///|
test "repeated vacuum slots keep empty cleanup byte-stable" {
  let input = pass_test_module_from_wat(
    "(module (func nop block unreachable end nop))",
  )
  let once = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected first vacuum cleanup success, got \{err}")
  }
  let twice = match
    run_hot_pipeline(once, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected second vacuum cleanup success, got \{err}")
  }
  match @validate.validate_module(twice) {
    Ok(_) => ()
    Err(err) => fail("expected repeated-vacuum module to validate, got \{err}")
  }
  match twice.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr([instr]))])) =>
      match instr {
        @lib.Instruction::Unreachable => ()
        other =>
          fail(
            "expected repeated vacuum to leave only unreachable, got \{other}",
          )
      }
    other =>
      fail("expected single repeated-vacuum function output, got \{other}")
  }
}

///|
test "vacuum repeated-slot matrix drops detached pure residues" {
  let input = pass_test_module_from_wat(
    "(module (func (local i32) (drop (i32.add (i32.const 1) (i32.const 2))) nop (local.set 0 (i32.const 4)) nop))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum", "vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected repeated vacuum residue cleanup success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected residue-cleaned module to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ])
    other =>
      fail("expected single residue-cleaned function output, got \{other}")
  }
}

///|
test "run_hot_pipeline emits trace markers for hot passes" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) nop i32.const 9))",
  )
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected traced hot pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected traced module to validate, got \{err}")
  }
  assert_true(trace.any(fn(line) { line.contains("pass[vacuum]:start") }))
  assert_true(trace.any(fn(line) { line.contains("pass[vacuum]:done") }))
}

///|
test "run_hot_pipeline accepts remove-unused-names as an active hot pass" {
  let input = pass_test_module_from_wat(
    "(module (func block block nop end end))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["remove-unused-names"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected remove-unused-names pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected remove-unused-names module to validate, got \{err}")
  }
}

///|
test "run_hot_pipeline accepts tuple-optimization as an active hot pass" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["tuple-optimization"]) {
    Ok(mod) => mod
    Err(err) => fail("expected tuple-optimization pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-optimization module to validate, got \{err}")
  }
}

///|
test "run_hot_pipeline keeps tuple-optimization as a no-op on scalar-only input" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["tuple-optimization"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected scalar-only tuple-optimization success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scalar-only tuple-optimization module to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, @lib.Expr(instrs))])) => {
      assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
      assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    }
    other =>
      fail(
        "expected scalar-only tuple-optimization single-function output, got \{other}",
      )
  }
}

///|
test "run_hot_pipeline lowers scrambled tuple copy carriers through a typed multivalue block" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 11 local.set 9 local.set 10 local.get 10 local.get 9 local.get 11 call 1))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["tuple-optimization"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected scrambled tuple-optimization pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scrambled tuple-optimization module to validate, got \{err}",
      )
  }
  match optimized.type_sec {
    Some(@lib.TypeSec(types)) => assert_eq(types.length(), 4)
    None => fail("expected scrambled tuple-optimization output type sec")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("(block (Type 3)"), msg=pretty)
  assert_false(
    pretty.contains("(local.set (Local 14))(local.get (Local 6))"),
    msg=pretty,
  )
}

///|
test "run_hot_pipeline stages nested branch-exit triple-result roots through split locals under tuple-optimization" {
  let source =
    #|(module
    #|  (type (func (result i32 i32 i32)))
    #|  (func (type 0) (result i32 i32 i32)
    #|    (i32.const 10)
    #|    (i32.const 20)
    #|    (i32.const 30))
    #|  (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (block $exit (result i32)
    #|      (if
    #|        (local.get 0)
    #|        (then
    #|          (call 0)
    #|          (local.set 4)
    #|          (local.set 3)
    #|          (local.set 2)
    #|          (local.set 7 (local.get 4))
    #|          (local.set 6 (local.get 3))
    #|          (local.set 1 (local.get 2))
    #|          (local.set 5 (local.get 7))
    #|          (local.set 0 (local.get 6))
    #|          (br $exit (local.get 5))))
    #|      (i32.const 99))))
  let input = match
    @wast.wast_to_binary_module(
      source,
      filename="tuple-temp-copy-stability.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("unexpected tuple temp copy stability fixture parse failure: \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["tuple-optimization"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected tuple-optimization temp-copy pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-optimization temp-copy module to validate, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(local.set (Local 7))"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 2))"), msg=pretty)
  assert_false(
    pretty.contains(
      "(call (Func 0))(local.set (Local 4))(local.set (Local 3))(local.set (Local 2))",
    ),
    msg=pretty,
  )
}

///|
test "tuple-optimization exact preset prereqs see no-structure pass but presets stay conservative" {
  assert_true(tuple_optimization_exact_slot_prereqs_ready())
  assert_false(
    optimize_preset_passes(HotPipelineOptions::new()).contains(
      "tuple-optimization",
    ),
  )
  assert_false(
    shrink_preset_passes(HotPipelineOptions::new()).contains(
      "tuple-optimization",
    ),
  )
}

///|
test "optimize preset replays remove-unused-names in all RUN slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat("(module (func loop br 0 end))")
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["optimize"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let run_starts = trace.filter(fn(line) {
    line.contains("pass[remove-unused-names]:start")
  })
  assert_eq(run_starts.length(), 3)
}

///|
test "optimize preset replays remove-unused-brs in all RUB slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (block $exit (if (local.get 0) (then (br $exit))))))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["optimize"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let rub_starts = trace.filter(fn(line) {
    line.contains("pass[remove-unused-brs]:start")
  })
  assert_eq(rub_starts.length(), 4)
}

///|
test "shrink preset replays remove-unused-brs in all RUB slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (block $exit (if (local.get 0) (then (br $exit))))))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["shrink"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected shrink pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected shrink module to validate, got \{err}")
  }
  let rub_starts = trace.filter(fn(line) {
    line.contains("pass[remove-unused-brs]:start")
  })
  assert_eq(rub_starts.length(), 4)
}

///|
test "optimize preset replays precompute in both PC slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.add))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["optimize"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let pc_starts = trace.filter(fn(line) {
    line.contains("pass[precompute]:start")
  })
  assert_eq(pc_starts.length(), 2)
}

///|
test "shrink preset replays precompute in both PC slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.add))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["shrink"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected shrink pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected shrink module to validate, got \{err}")
  }
  let pc_starts = trace.filter(fn(line) {
    line.contains("pass[precompute]:start")
  })
  assert_eq(pc_starts.length(), 2)
}

///|
test "optimize preset replays merge-blocks in both late MB slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (block (result i32) (block (result i32) i32.const 7))))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["optimize"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let mb_starts = trace.filter(fn(line) {
    line.contains("pass[merge-blocks]:start")
  })
  assert_eq(mb_starts.length(), 2)
}

///|
test "shrink preset replays merge-blocks in both late MB slots" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (block (result i32) (block (result i32) i32.const 7))))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["shrink"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected shrink pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected shrink module to validate, got \{err}")
  }
  let mb_starts = trace.filter(fn(line) {
    line.contains("pass[merge-blocks]:start")
  })
  assert_eq(mb_starts.length(), 2)
}

///|
test "optimize and shrink presets do not schedule reorder-locals before its neighboring local passes land" {
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  let shrink = shrink_preset_passes(HotPipelineOptions::new())
  assert_false(optimize.contains("reorder-locals"))
  assert_false(shrink.contains("reorder-locals"))
}

///|
test "simplify-locals-notee-nostructure exact neighborhood waits for flatten and local-cse" {
  assert_false(simplify_locals_notee_nostructure_exact_neighborhood_ready())
  assert_eq(
    pass_registry_category("simplify-locals-notee-nostructure"),
    Some(HotPassRegistryCategory::hot_pass()),
  )
  assert_eq(
    pass_registry_category("flatten"),
    Some(HotPassRegistryCategory::removed()),
  )
  assert_eq(
    pass_registry_category("local-cse"),
    Some(HotPassRegistryCategory::removed()),
  )
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  let shrink = shrink_preset_passes(HotPipelineOptions::new())
  assert_false(optimize.contains("simplify-locals-notee-nostructure"))
  assert_false(shrink.contains("simplify-locals-notee-nostructure"))
}

///|
test "optimize preset schedules heap2local in the mid-function GC slot" {
  let optimize = optimize_preset_passes(HotPipelineOptions::new())
  assert_eq(optimize[15], "remove-unused-brs")
  assert_eq(optimize[16], "heap2local")
  assert_eq(optimize[17], "simplify-locals")
}

///|
test "optimize preset hands simplify-locals output to the late merge-blocks cleanup cluster" {
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["optimize"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }

  let starts : Array[String] = []
  for line in trace {
    if line.contains(":start") {
      starts.push(line)
    }
  }
  let mut sl_idx = -1
  let mut sl_count = 0
  for idx = 0; idx < starts.length(); idx = idx + 1 {
    if starts[idx].contains("pass[simplify-locals]:start") {
      sl_count += 1
      sl_idx = idx
    }
  }
  assert_eq(sl_count, 1)
  assert_true(sl_idx > 0, msg=starts.to_string())
  assert_true(
    starts[sl_idx - 1].contains("pass[heap2local]:start"),
    msg=starts.to_string(),
  )
  assert_true(
    sl_idx + 1 < starts.length() &&
    starts[sl_idx + 1].contains("pass[merge-blocks]:start"),
    msg=starts.to_string(),
  )
}

///|
test "vacuum cleans simplify-locals structured return residue in the late cleanup pair" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        "(module (func (param i32) (result i32) (local i32) block $exit local.get 0 if i32.const 1 local.set 1 br $exit end i32.const 2 local.set 1 end local.get 1))",
      ),
      HotPipelineOptions::new(),
      ["simplify-locals", "vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected simplify-locals/vacuum cleanup success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected cleanup pair module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("block I32"), msg=pretty)
}

///|
test "vacuum roundtrips dead simd prefixes before unreachable" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        "(module (func (export \"f\") v128.const i32x4 1 2 3 4 i64x2.extend_low_i32x4_s i8x16.popcnt i64x2.extend_high_i32x4_u unreachable))",
      ),
      HotPipelineOptions::new(),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected vacuum simd/unreachable roundtrip success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected simd/unreachable module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64x2.extend_low_i32x4s"), msg=pretty)
  assert_true(pretty.contains("i8x16.popcnt"), msg=pretty)
  assert_true(pretty.contains("i64x2.extend_high_i32x4u"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "vacuum roundtrips top-level try_table catches that target the implicit function label" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        "(module (func (export \"f\") try_table (catch_all 0) end))",
      ),
      HotPipelineOptions::new(),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected top-level try_table roundtrip success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected top-level try_table module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("catch_all (Label 0)"), msg=pretty)
}

///|
test "remove-unused-names can clean up stale labels exposed by remove-unused-brs" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat("(module (func block block br 1 end end))"),
      HotPipelineOptions::new(),
      ["remove-unused-names", "remove-unused-brs", "remove-unused-names"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected remove-unused-names/remove-unused-brs replay success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("Block("), msg=pretty)
}
