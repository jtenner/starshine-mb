///|
test "simplify-locals-nostructure lowered cleanup skips stack-root call hazards" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (memory 1)
      #|  (global $sp (mut i32) (i32.const 1024))
      #|  (func $touch)
      #|  (func (param $value i32) (local i32 i32)
      #|    global.get $sp
      #|    i32.const 4
      #|    i32.sub
      #|    global.set $sp
      #|    global.get $sp
      #|    local.get $value
      #|    local.tee 1
      #|    i32.store
      #|    call $touch
      #|    global.get $sp
      #|    i32.const 4
      #|    i32.add
      #|    global.set $sp))
    ),
  )
  let func = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(1) {
        Some(func) => func
        None => fail("expected second function body")
      }
    None => fail("expected code section")
  }
  let cleaned = run_hot_pipeline_canonicalize_lowered_func_for_descriptor(
    func, "simplify-locals-nostructure",
  )
  @debug.assert_eq(cleaned, func)
}

///|
test "dae descending dropped-result scheduler orders high candidates without huge module" {
  let selected_defs = Array::make(4600, false)
  for i = 0; i < 40; i = i + 1 {
    selected_defs[i] = true
  }
  for i = 4500; i < 4509; i = i + 1 {
    selected_defs[i] = true
  }
  let candidates = dae_collect_descending_selected_def_candidates(
    selected_defs, 4600,
  )
  @debug.assert_eq(candidates.length(), 49)
  @debug.assert_eq(candidates[0], 4508)
  @debug.assert_eq(candidates[1], 4507)
  @debug.assert_eq(candidates[8], 4500)
  @debug.assert_eq(candidates[9], 39)
}

///|
test "dae descending dropped-result scheduler caps productive attempts after ordering" {
  let selected_defs = Array::make(4600, false)
  for i = 0; i < 40; i = i + 1 {
    selected_defs[i] = true
  }
  for i = 4500; i < 4514; i = i + 1 {
    selected_defs[i] = true
  }
  let attempts = dae_collect_descending_selected_def_attempts(
    selected_defs, 4600, 14,
  )
  @debug.assert_eq(attempts.length(), 14)
  @debug.assert_eq(attempts[0], 4513)
  @debug.assert_eq(attempts[13], 4500)
}

///|
test "dae selected dropped-result helper respects precomputed dropped-call facts" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $callee (result i32)
      #|    i32.const 7)
      #|  (func (export "run")
      #|    call $callee
      #|    drop))
    ),
  )
  let selected_defs = Array::make(2, false)
  selected_defs[0] = true
  let direct_calls = Array::make(2, 0)
  direct_calls[0] = 1
  let facts = DaeCurrentCallFacts::{
    direct_calls,
    tail_calls: Array::make(2, false),
    direct_callers: dae_make_direct_callers(2),
    dropped_calls: Array::make(2, 0),
    escaped: Array::make(2, false),
  }
  let trace : Array[String] = []
  let perf = HotPerfSession::new(
    trace=fn(line) { trace.push(line) },
    dump_options=HotPerfDumpOptions::new(),
  )
  let result = dae_try_remove_selected_defs_dropped_results_with_facts_once(
    mod_,
    selected_defs,
    facts,
    perf=Some(perf),
  )
  assert_false(result.changed)
  let text = trace.to_string()
  assert_true(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:dropped-results:selected-defs:helper",
    ),
    msg=text,
  )
}

///|
test "dae selected dropped-result helper times candidate type-index collection" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $callee (result i32)
      #|    i32.const 7)
      #|  (func (export "run")
      #|    call $callee
      #|    drop))
    ),
  )
  let selected_defs = Array::make(2, false)
  selected_defs[0] = true
  let direct_calls = Array::make(2, 0)
  direct_calls[0] = 1
  let dropped_calls = Array::make(2, 0)
  dropped_calls[0] = 1
  let direct_callers = dae_make_direct_callers(2)
  direct_callers[0].push(1)
  let facts = DaeCurrentCallFacts::{
    direct_calls,
    tail_calls: Array::make(2, false),
    direct_callers,
    dropped_calls,
    escaped: Array::make(2, false),
  }
  let trace : Array[String] = []
  let perf = HotPerfSession::new(
    trace=fn(line) { trace.push(line) },
    dump_options=HotPerfDumpOptions::new(),
  )
  let result = dae_try_remove_selected_defs_dropped_results_with_facts_once(
    mod_,
    selected_defs,
    facts,
    perf=Some(perf),
  )
  assert_true(result.changed)
  let text = trace.to_string()
  assert_true(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:type-indices",
    ),
    msg=text,
  )
  assert_true(
    text.contains(
      "perf:timer name=detail:dae:core:selected-lanes:dropped-results:selected-defs:helper:rewrite-calls",
    ),
    msg=text,
  )
}

///|
test "dae selected dropped-result helper returns caller touched flag from caller-filtered rewrite" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $callee (result i32)
      #|    i32.const 7)
      #|  (func (export "run")
      #|    call $callee
      #|    drop))
    ),
  )
  let selected_defs = Array::make(2, false)
  selected_defs[0] = true
  let direct_calls = Array::make(2, 0)
  direct_calls[0] = 1
  let dropped_calls = Array::make(2, 0)
  dropped_calls[0] = 1
  let direct_callers = dae_make_direct_callers(2)
  direct_callers[0].push(1)
  let facts = DaeCurrentCallFacts::{
    direct_calls,
    tail_calls: Array::make(2, false),
    direct_callers,
    dropped_calls,
    escaped: Array::make(2, false),
  }
  let result = dae_try_remove_selected_defs_dropped_results_with_facts_once(
    mod_, selected_defs, facts,
  )
  assert_true(result.changed)
  @debug.assert_eq(result.touched, [true, true])
}

///|
test "raw vacuum preclean removes stacked pure local drops in one pass" {
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(7),
  ])
  assert_true(changed)
  @debug.assert_eq(cleaned, [@lib.Instruction::i32_const(7)])
}

///|
test "raw vacuum preclean truncates dead tail after nonfallthrough" {
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs([
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  assert_true(changed)
  @debug.assert_eq(cleaned, [@lib.Instruction::unreachable_()])
}

///|
test "raw vacuum preclean skips large structured functions with writes" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let then_body : Array[@lib.Instruction] = []
  for _idx = 0; _idx < 2050; _idx = _idx + 1 {
    then_body.push(@lib.Instruction::i32_const(0))
    then_body.push(@lib.Instruction::drop())
  }
  then_body.push(@lib.Instruction::i32_const(1))
  then_body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  then_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  then_body.push(@lib.Instruction::br_if(@lib.LabelIdx::new(0U)))
  let original_func = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::if_(@lib.BlockType::void_(), then_body, None),
    ]),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([original_func]))
  let result = match
    run_hot_pipeline_raw_vacuum_preclean(
      input,
      @lib.FuncIdx::new(0U),
      @ir.HotPassDescriptor::new("vacuum"),
      HotPipelineOptions::new(),
    ) {
    Some(result) => result
    None => fail("expected raw vacuum structured-write skip result")
  }
  assert_true(result.unchanged_original)
  @debug.assert_eq(result.func, original_func)
}

///|
test "hot pipeline debug dump targets stay disabled without trace" {
  let options = HotPipelineOptions::new()

  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2944U),
      "vacuum",
    ),
  )
  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(3660U),
      "tuple-optimization",
    ),
  )
}

///|
test "hot pipeline debug dump targets require traced vacuum or tuple targets" {
  let options = HotPipelineOptions::new(trace=Some(fn(_) { () }))

  assert_true(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2944U),
      "vacuum",
    ),
  )
  assert_true(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(3660U),
      "tuple-optimization",
    ),
  )
  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(2944U),
      "remove-unused-names",
    ),
  )
  assert_false(
    run_hot_pipeline_debug_dump_enabled(
      options,
      @lib.FuncIdx::new(12U),
      "vacuum",
    ),
  )
}

///|
test "raw remove-unused-brs unchecked moderate call mesh gate accepts artifact-like stats" {
  let shape = RawRemoveUnusedBrsShape::new()
  shape.call_count = 103
  shape.local_set_count = 29
  shape.local_tee_count = 6
  shape.if_count = 21
  shape.return_count = 0
  shape.select_count = 1
  shape.br_if_count = 0
  shape.block_count = 11
  shape.loop_count = 2
  shape.br_count = 12
  shape.br_table_count = 0
  shape.drop_count = 9

  assert_true(
    run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
      35, 454, true, true, true, true, shape, false, false,
    ),
  )
  shape.return_count = 1
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
      35, 454, true, true, true, true, shape, false, false,
    ),
  )
  shape.return_count = 0
  assert_false(
    run_hot_pipeline_raw_remove_unused_brs_unchecked_moderate_call_mesh_stats(
      35, 454, true, true, true, true, shape, true, false,
    ),
  )
}

///|
test "raw simd parser br-table stack hazard gate accepts artifact-like stats" {
  let shape = RawRemoveUnusedBrsShape::new()
  shape.call_count = 141
  shape.local_set_count = 708
  shape.local_tee_count = 643
  shape.if_count = 710
  shape.return_count = 1
  shape.select_count = 73
  shape.br_if_count = 212
  shape.block_count = 146
  shape.value_block_count = 56
  shape.void_block_count = 90
  shape.loop_count = 249
  shape.br_count = 410
  shape.br_table_count = 1
  shape.drop_count = 98

  assert_true(
    run_hot_pipeline_raw_simd_parser_br_table_stack_hazard_stats(
      25, 13414, shape,
    ),
  )
  shape.br_table_count = 0
  assert_false(
    run_hot_pipeline_raw_simd_parser_br_table_stack_hazard_stats(
      25, 13414, shape,
    ),
  )
  shape.br_table_count = 1
  shape.br_if_count = 12
  assert_false(
    run_hot_pipeline_raw_simd_parser_br_table_stack_hazard_stats(
      25, 13414, shape,
    ),
  )
}

///|
test "raw remove-unused-brs decision ladder skips empty value-if arms" {
  let instrs = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [],
      Some([@lib.Instruction::i32_const(@lib.I32(1))]),
    ),
  ]
  let (rewritten, rewrite_count, saw_br_table) = run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(
    instrs,
  )

  @debug.assert_eq(rewrite_count, 0)
  @debug.assert_eq(saw_br_table, false)
  @debug.assert_eq(rewritten, instrs)
}

///|
test "unchecked simplify-locals verifies hot state before lower" {
  let hot = @ir.HotFunc::new()
  let invalid_branch = @ir.hot_build_br(hot, 99)
  @ir.hot_root_append(hot, invalid_branch)
  let unchecked_options = HotPipelineOptions::new(validate_final_module=false)
  let checked_options = HotPipelineOptions::new(validate_final_module=true)

  match
    run_hot_pipeline_unchecked_verify_before_lower_skip_reason(
      hot, "simplify-locals", unchecked_options,
    ) {
    Some(reason) =>
      assert_true(reason.contains("verify before lower"), msg=reason)
    None =>
      fail("expected unchecked simplify-locals to report invalid hot state")
  }
  @debug.assert_eq(
    run_hot_pipeline_unchecked_verify_before_lower_skip_reason(
      hot, "vacuum", unchecked_options,
    ),
    None,
  )
  @debug.assert_eq(
    run_hot_pipeline_unchecked_verify_before_lower_skip_reason(
      hot, "simplify-locals", checked_options,
    ),
    None,
  )
}

///|
test "hot pipeline skips lift errors in unchecked nested-style runs" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
        ),
      ]),
    )
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(
        validate_final_module=false,
        trace=Some(fn(line) { trace.push(line) }),
      ),
      ["remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unchecked hot-lift skip success, got \{err}")
  }

  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
    input.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
  assert_true(
    trace.any(fn(line) { line.contains("pass[remove-unused-brs]:lift-error") }),
    msg="expected lift-error trace in \{trace}",
  )
  assert_true(
    trace.any(fn(line) { line.contains("skip-raw reason=hot-lift-error") }),
    msg="expected hot-lift-error skip trace in \{trace}",
  )
}

///|
test "pass registry cache indexes known flags and prefilters help entries" {
  let simplify_locals_idx = match
    pass_registry_lookup_index("simplify-locals") {
    Some(idx) => idx
    None => fail("expected simplify-locals registry index")
  }
  @debug.assert_eq(
    pass_registry_cache.entries[simplify_locals_idx].name,
    "simplify-locals",
  )
  @debug.assert_eq(pass_registry_lookup_index("not-a-real-pass"), None)

  let mut saw_optimize = false
  let mut saw_memory_packing = false
  for entry in pass_registry_help_entries() {
    match entry.category {
      HotPassRegistryCategory::HotPass | HotPassRegistryCategory::Preset => ()
      _ =>
        fail(
          "unexpected non-help registry category in cached help entries: \{entry}",
        )
    }
    if entry.name == "optimize" {
      saw_optimize = true
    }
    if entry.name == "memory-packing" {
      saw_memory_packing = true
    }
  }
  assert_true(saw_optimize)
  assert_false(saw_memory_packing)
}

///|
test "pass registry public lookup stays detached from cached preset expansions" {
  let lookup = match pass_registry_lookup("optimize") {
    Some(entry) => entry
    None => fail("expected optimize registry entry")
  }
  lookup.expanded_passes.push("not-a-real-pass")

  let fresh_lookup = match pass_registry_lookup("optimize") {
    Some(entry) => entry
    None => fail("expected optimize registry entry on second lookup")
  }
  let mut leaked_fake_pass = false
  for pass_name in fresh_lookup.expanded_passes {
    if pass_name == "not-a-real-pass" {
      leaked_fake_pass = true
    }
  }
  assert_false(leaked_fake_pass)
}

///|
test "pass registry public lookup stays detached from cached descriptors" {
  let baseline_requires_len = match pass_registry_lookup("vacuum") {
    Some(entry) =>
      match entry.descriptor {
        Some(descriptor) => descriptor.requires.length()
        None => fail("expected vacuum descriptor")
      }
    None => fail("expected vacuum registry entry")
  }

  let lookup = match pass_registry_lookup("vacuum") {
    Some(entry) => entry
    None => fail("expected vacuum registry entry")
  }
  match lookup.descriptor {
    Some(descriptor) => descriptor.requires.push(@ir.HotAnalysis::cfg())
    None => fail("expected vacuum descriptor")
  }

  let fresh_lookup = match pass_registry_lookup("vacuum") {
    Some(entry) => entry
    None => fail("expected vacuum registry entry on second lookup")
  }
  match fresh_lookup.descriptor {
    Some(descriptor) =>
      @debug.assert_eq(descriptor.requires.length(), baseline_requires_len)
    None => fail("expected vacuum descriptor on second lookup")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals branchy structured gate accepts target-like stats" {
  let accepted = {
    locals_count: 184,
    instr_count: 1072,
    has_structured_control: true,
    if_count: 53,
    block_count: 24,
    loop_count: 0,
    local_set_count: 69,
    local_get_count: 315,
    call_count: 107,
    return_count: 7,
    exact_tail_count: 0,
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats(
      accepted,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats({
      ..accepted,
      local_set_count: 63,
    }),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats({
      ..accepted,
      call_count: 95,
    }),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branchy_structured_call_heavy_stats({
      ..accepted,
      loop_count: 1,
    }),
  )
}

///|
test "raw simplify-locals unchecked small structured call mesh gate accepts artifact-like stats" {
  let accepted = {
    locals_count: 4,
    instr_count: 257,
    has_structured_control: true,
    if_count: 15,
    block_count: 2,
    loop_count: 1,
    local_set_count: 6,
    local_get_count: 94,
    call_count: 59,
    return_count: 7,
    exact_tail_count: 0,
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_unchecked_small_structured_call_mesh_stats(
      accepted,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_unchecked_small_structured_call_mesh_stats({
        ..accepted,
        exact_tail_count: 1,
      },
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_unchecked_small_structured_call_mesh_stats({
        ..accepted,
        call_count: 16,
      },
    ),
  )
}

///|
test "raw simplify-locals giant validator gate accepts artifact-like stats" {
  let accepted = {
    locals_count: 1368,
    instr_count: 10699,
    has_structured_control: true,
    if_count: 584,
    block_count: 136,
    loop_count: 4,
    local_set_count: 1577,
    local_get_count: 2853,
    call_count: 1227,
    return_count: 14,
    exact_tail_count: 0,
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_giant_validator_structured_call_heavy_stats(
      accepted,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_giant_validator_structured_call_heavy_stats({
        ..accepted,
        call_count: 512,
      },
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_giant_validator_structured_call_heavy_stats({
        ..accepted,
        exact_tail_count: 1,
      },
    ),
  )
}

///|
test "raw simplify-locals block-rich structured call-heavy gate accepts target-like stats" {
  let accepted = {
    locals_count: 128,
    instr_count: 579,
    has_structured_control: true,
    if_count: 32,
    block_count: 32,
    loop_count: 0,
    local_set_count: 67,
    local_get_count: 165,
    call_count: 130,
    return_count: 0,
    exact_tail_count: 0,
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_block_rich_structured_call_heavy_stats(
      accepted,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_block_rich_structured_call_heavy_stats({
        ..accepted,
        block_count: 15,
      },
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_block_rich_structured_call_heavy_stats({
        ..accepted,
        local_set_count: 97,
      },
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_block_rich_structured_call_heavy_stats({
        ..accepted,
        loop_count: 1,
      },
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_block_rich_structured_call_heavy_stats({
        ..accepted,
        call_count: 161,
      },
    ),
  )
}

///|
test "raw simplify-locals call-dense structured walker gate accepts target-like stats" {
  let accepted = {
    locals_count: 164,
    instr_count: 1170,
    has_structured_control: true,
    if_count: 171,
    block_count: 14,
    loop_count: 3,
    local_set_count: 37,
    local_get_count: 1068,
    call_count: 552,
    return_count: 3,
    exact_tail_count: 0,
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_call_dense_structured_walker_stats(
      accepted,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_call_dense_structured_walker_stats({
      ..accepted,
      call_count: 159,
    }),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_call_dense_structured_walker_stats({
      ..accepted,
      local_get_count: 179,
    }),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_call_dense_structured_walker_stats({
      ..accepted,
      local_set_count: 97,
    }),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_call_dense_structured_walker_stats({
      ..accepted,
      loop_count: 7,
    }),
  )
}

///|
test "raw simplify-locals adjacent local tees preserve writes read inside later if bodies" {
  let local_7 = @lib.LocalIdx::new(7U)
  let instrs = [
    @lib.Instruction::local_set(local_7),
    @lib.Instruction::local_get(local_7),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 12UL)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::local_get(local_7), @lib.Instruction::drop()],
      None,
    ),
  ]

  let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_adjacent_local_tees(
    instrs,
  )

  @debug.assert_eq(rewrite_count, 1)
  @debug.assert_eq(rewritten.length(), 3)
  @debug.assert_eq(rewritten[0], @lib.Instruction::local_tee(local_7))
  @debug.assert_eq(
    rewritten[1],
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 12UL)),
  )
  match rewritten[2] {
    @lib.If(_, then_body, _) => {
      @debug.assert_eq(then_body.length(), 2)
      @debug.assert_eq(then_body[0], @lib.Instruction::local_get(local_7))
      @debug.assert_eq(then_body[1], @lib.Instruction::drop())
    }
    _ => fail("expected rewritten if body, got \{rewritten[2]}")
  }
}

///|
test "simplify-locals lowered cleanup preserves tees read by later if arms" {
  let local_12 = @lib.LocalIdx::new(12U)
  let stale_counts = Array::make(13, 0)
  let cleaned = run_hot_pipeline_simplify_locals_lowered_cleanup_body(
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
      @lib.Instruction::local_tee(local_12),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_gt_s(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::local_get(local_12), @lib.Instruction::drop()],
        Some([@lib.Instruction::local_get(local_12), @lib.Instruction::drop()]),
      ),
    ],
    stale_counts,
  )

  assert_true(
    cleaned.any(fn(instr) { instr == @lib.Instruction::local_tee(local_12) }),
    msg=cleaned.to_string(),
  )
}

///|
test "raw simplify-locals nested pure call-tail scan sees returning branch copy shuttles" {
  let instrs = [
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(10000)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(255U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(252U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(253U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(254U)),
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(254U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(252U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(253U)),
        @lib.Instruction::i64_const(@lib.I64(4294967296L)),
        @lib.Instruction::i64_const(@lib.I64(4294967296L)),
        @lib.Instruction::i32_const(@lib.I32(-1)),
        @lib.Instruction::i64_const(@lib.I64(4294967296L)),
        @lib.Instruction::i32_const(@lib.I32(-1)),
        @lib.Instruction::i32_const(@lib.I32(-1)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(255U)),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(250U)),
        @lib.Instruction::return_(),
      ],
      None,
    ),
  ]

  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_pure_call_tail_candidates_nested(
      instrs,
    ),
  )
}

///|
test "raw simplify-locals nested pure suffix scan sees later copied local reads" {
  let instrs = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(250U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(251U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(251U)),
        @lib.Instruction::drop(),
      ],
      None,
    ),
  ]

  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_pure_suffix_local_set_candidates_nested(
      instrs,
    ),
  )
}

///|
test "raw simplify-locals later local read before next write stops at overwrite" {
  let local_251 = 251
  let reads_before_write = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(251U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(251U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(251U)),
    @lib.Instruction::drop(),
  ]
  let write_before_read = [
    @lib.Instruction::local_set(@lib.LocalIdx::new(251U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(251U)),
    @lib.Instruction::drop(),
  ]

  assert_true(
    run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
      reads_before_write, 0, local_251,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
      write_before_read, 0, local_251,
    ),
  )
}

///|
test "raw simplify-locals rewrites dupable copies into the next escaping if condition" {
  let remaining = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(251U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(251U)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 8UL)),
    @lib.Instruction::call_indirect(
      @lib.TypeIdx::new(0U),
      @lib.TableIdx::new(0U),
    ),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(250U)),
        @lib.Instruction::return_(),
      ],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(251U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(251U)),
    @lib.Instruction::drop(),
  ]

  let rewritten = match
    run_hot_pipeline_raw_simplify_locals_try_rewrite_dupable_copy_into_next_if_condition(
      remaining,
      251,
      @lib.Instruction::local_get(@lib.LocalIdx::new(250U)),
      [250],
    ) {
    Some((rewritten, consumed_len)) => {
      @debug.assert_eq(consumed_len, 9)
      rewritten
    }
    None => fail("expected escaping if-condition copy rewrite candidate")
  }

  @debug.assert_eq(
    rewritten[0],
    @lib.Instruction::local_get(@lib.LocalIdx::new(250U)),
  )
  @debug.assert_eq(
    rewritten[1],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
  @debug.assert_eq(
    rewritten[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(250U)),
  )
  match rewritten[8] {
    @lib.If(_, then_body, else_body) => {
      @debug.assert_eq(
        then_body[0],
        @lib.Instruction::local_get(@lib.LocalIdx::new(250U)),
      )
      @debug.assert_eq(then_body[1], @lib.Instruction::return_())
      @debug.assert_eq(else_body, Some([@lib.Instruction::nop()]))
    }
    _ => fail("expected rewritten trailing if, got \{rewritten[8]}")
  }
}

///|
test "raw simplify-locals batches dupable middle copy statements into the same final use" {
  let middle_statements = [
    [
      @lib.Instruction::i32_const(@lib.I32(10000)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(201U)),
    ],
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(202U)),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(203U)),
    ],
    [@lib.Instruction::nop()],
  ]
  let statement = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(203U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(202U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(201U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let outer_instrs = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(200U)),
  ]
  for middle_statement in middle_statements {
    for instr in middle_statement {
      outer_instrs.push(instr)
    }
  }
  for instr in statement {
    outer_instrs.push(instr)
  }

  let (rewritten_middle, rewritten_statement, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_dupable_copy_middle_statements_into_statement(
    middle_statements,
    statement,
    outer_instrs,
    outer_instrs.length(),
  )

  @debug.assert_eq(rewrite_count, 3)
  @debug.assert_eq(rewritten_middle.length(), 4)
  @debug.assert_eq(rewritten_middle[0], @lib.Instruction::nop())
  @debug.assert_eq(rewritten_middle[1], @lib.Instruction::nop())
  @debug.assert_eq(rewritten_middle[2], @lib.Instruction::nop())
  @debug.assert_eq(rewritten_middle[3], @lib.Instruction::nop())
  @debug.assert_eq(
    rewritten_statement[0],
    @lib.Instruction::i32_const(@lib.I32(0)),
  )
  @debug.assert_eq(
    rewritten_statement[1],
    @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
  )
  @debug.assert_eq(
    rewritten_statement[2],
    @lib.Instruction::i32_const(@lib.I32(10000)),
  )
}

///|
test "raw simplify-locals pure suffix collapses terminal dupable const wrappers" {
  let env = @validate.Env::new().with_locals(
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let instrs = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ]

  let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
    instrs, env,
  )

  @debug.assert_eq(rewrite_count, 1)
  @debug.assert_eq(rewritten.length(), 3)
  @debug.assert_eq(rewritten[0], @lib.Instruction::nop())
  @debug.assert_eq(rewritten[1], @lib.Instruction::nop())
  @debug.assert_eq(rewritten[2], @lib.Instruction::i32_const(@lib.I32(0)))
}

///|
test "raw simplify-locals skipped-carrier path applies pure suffix copy cleanup" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let locals = @lib.Locals::from_types([@lib.ValType::i32()])
  let instrs = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ]
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(instrs))]),
    )

  let result = match
    run_hot_pipeline_raw_simplify_locals_rewrite_skipped_effectful_carriers(
      mod_,
      @lib.FuncIdx::new(0U),
      { module_ctx: None },
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
      locals,
      instrs,
      "skipped-carrier-test",
    ) {
    Some(result) => result
    None => fail("expected skipped-carrier pure suffix cleanup to rewrite")
  }

  @debug.assert_eq(result.reason, "skipped-carrier-test")
  assert_false(result.unchanged_original)
  let @lib.Func(_, @lib.Expr(rewritten)) = result.func
  @debug.assert_eq(rewritten.length(), 3)
  @debug.assert_eq(rewritten[0], @lib.Instruction::nop())
  @debug.assert_eq(rewritten[1], @lib.Instruction::nop())
  @debug.assert_eq(rewritten[2], @lib.Instruction::i32_const(@lib.I32(0)))
}

///|
test "raw simplify-locals pure suffix collapses terminal dupable local wrappers across safe middle statements" {
  let env = @validate.Env::new().with_locals(
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let instrs = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ]

  let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
    instrs, env,
  )

  @debug.assert_eq(rewrite_count, 1)
  @debug.assert_eq(rewritten.length(), 4)
  @debug.assert_eq(rewritten[0], @lib.Instruction::nop())
  @debug.assert_eq(
    rewritten[1],
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  )
  @debug.assert_eq(
    rewritten[2],
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  )
  @debug.assert_eq(
    rewritten[3],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
}

///|
test "raw simplify-locals pure suffix rewrites copy carriers into branch-terminated statements" {
  let env = @validate.Env::new().with_locals(
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let instrs = [
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]

  let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
    instrs, env,
  )

  @debug.assert_eq(rewrite_count, 1)
  @debug.assert_eq(rewritten.length(), 7)
  @debug.assert_eq(rewritten[0], @lib.Instruction::nop())
  @debug.assert_eq(rewritten[1], @lib.Instruction::nop())
  @debug.assert_eq(
    rewritten[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  )
  @debug.assert_eq(
    rewritten[3],
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
  )
  @debug.assert_eq(
    rewritten[4],
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  )
  @debug.assert_eq(
    rewritten[5],
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  )
  @debug.assert_eq(rewritten[6], @lib.Instruction::br(@lib.LabelIdx::new(0U)))
}

///|
test "lowered simplify-locals cleanup hoists nops ahead of dupable value runs" {
  let instrs = [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]

  let rewritten = run_hot_pipeline_simplify_locals_lowered_hoist_nops_across_dupable_values(
    instrs,
  )

  @debug.assert_eq(rewritten.length(), 5)
  @debug.assert_eq(rewritten[0], @lib.Instruction::nop())
  @debug.assert_eq(rewritten[1], @lib.Instruction::i32_const(@lib.I32(0)))
  @debug.assert_eq(
    rewritten[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  )
  @debug.assert_eq(rewritten[3], @lib.Instruction::i32_const(@lib.I32(2)))
  @debug.assert_eq(rewritten[4], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
}

///|
test "raw simplify-locals inlines typed control carriers into following structured reads" {
  let target = @lib.LocalIdx::new(2U)
  let instrs = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
    ),
    @lib.Instruction::local_set(target),
    @lib.Instruction::nop(),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(target),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ]),
    ),
  ]

  let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_fixpoint(
    instrs,
  )
  let text = @lib.Func::new(
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(rewritten),
  ).pretty_print(@lib.PrettyPrintContext::new())

  @debug.assert_eq(rewrite_count, 1)
  assert_false(text.contains("local.set (Local 2)"), msg=text)
  assert_false(text.contains("local.get (Local 2)"), msg=text)
  assert_true(text.contains("block I32"), msg=text)
}

///|
test "raw simplify-locals turns typed control carriers into tees for later reads" {
  let target = @lib.LocalIdx::new(2U)
  let instrs = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
    ),
    @lib.Instruction::local_set(target),
    @lib.Instruction::local_get(target),
    @lib.Instruction::i32_load(@lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::local_get(target), @lib.Instruction::drop()],
      None,
    ),
  ]

  let (rewritten, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_fixpoint(
    instrs,
  )
  let text = @lib.Func::new(
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    @lib.Expr::new(rewritten),
  ).pretty_print(@lib.PrettyPrintContext::new())

  @debug.assert_eq(rewrite_count, 1)
  assert_false(text.contains("local.set (Local 2)"), msg=text)
  assert_true(text.contains("local.tee (Local 2)"), msg=text)
  assert_true(text.contains("local.get (Local 2)"), msg=text)
}

///|
test "raw simplify-locals later-read scan stops at unconditional branch" {
  let instrs = [
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  ]

  assert_false(
    run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
      instrs, 0, 3,
    ),
  )
}

///|
test "raw simplify-locals later-read scan keeps conditional branch reads live" {
  let instrs = [
    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  ]

  assert_true(
    run_hot_pipeline_raw_instrs_have_later_local_read_before_next_local_write(
      instrs, 0, 3,
    ),
  )
}

///|
#cfg(target="native")
fn pass_manager_test_native_c_string(text : String) -> Bytes {
  let out = @buffer.new(size_hint=text.length() + 1)
  for c in text {
    let code = c.to_int()
    if code >= 0 && code <= 255 {
      out.write_byte(code.to_byte())
    } else {
      out.write_byte('?'.to_int().to_byte())
    }
  }
  out.write_byte(0)
  out.to_bytes()
}

///|
#cfg(target="native")
#borrow(path, mode)
extern "c" fn pass_manager_test_native_fopen(
  path : Bytes,
  mode : Bytes,
) -> UInt64 = "fopen"

///|
#cfg(target="native")
extern "c" fn pass_manager_test_native_fclose(stream : UInt64) -> Int = "fclose"

///|
#cfg(target="native")
extern "c" fn pass_manager_test_native_fseek(
  stream : UInt64,
  offset : Int,
  whence : Int,
) -> Int = "fseek"

///|
#cfg(target="native")
extern "c" fn pass_manager_test_native_ftell(stream : UInt64) -> Int64 = "ftell"

///|
#cfg(target="native")
#borrow(ptr)
extern "c" fn pass_manager_test_native_fread(
  ptr : Bytes,
  size : UInt64,
  count : UInt64,
  stream : UInt64,
) -> UInt64 = "fread"

///|
#cfg(target="native")
fn pass_manager_test_native_read_bytes(path : String) -> Bytes? {
  let c_path = pass_manager_test_native_c_string(path)
  let c_mode = pass_manager_test_native_c_string("rb")
  let file = pass_manager_test_native_fopen(c_path, c_mode)
  if file == 0UL {
    return None
  }
  if pass_manager_test_native_fseek(file, 0, 2) != 0 {
    ignore(pass_manager_test_native_fclose(file))
    return None
  }
  let size_i64 = pass_manager_test_native_ftell(file)
  if size_i64 < 0L {
    ignore(pass_manager_test_native_fclose(file))
    return None
  }
  let size_u = size_i64.reinterpret_as_uint64()
  if pass_manager_test_native_fseek(file, 0, 0) != 0 {
    ignore(pass_manager_test_native_fclose(file))
    return None
  }
  let bytes = Bytes::new(size_u.to_int())
  let read = if size_u == 0UL {
    0UL
  } else {
    pass_manager_test_native_fread(bytes, 1UL, size_u, file)
  }
  let close_code = pass_manager_test_native_fclose(file)
  if close_code != 0 {
    return None
  }
  if size_u == 0UL || read == size_u {
    Some(bytes)
  } else {
    None
  }
}

///|
#cfg(target="native")
fn pass_manager_test_native_read_repo_fixture(path : String) -> Bytes? {
  for base in [path, "../starshine-mb/\{path}"] {
    for
      prefix in [
        "", "../", "../../", "../../../", "../../../../", "../../../../../", "../../../../../../",
      ] {
      match pass_manager_test_native_read_bytes("\{prefix}\{base}") {
        Some(bytes) => return Some(bytes)
        None => ()
      }
    }
  }
  None
}

///|
#cfg(target="native")
fn pass_manager_test_dae_core_apply_iters(
  mod_ : @lib.Module,
  limit : Int,
) -> @lib.Module {
  let original_type_indices = dae_collect_func_type_indices(mod_)
  let original_param_counts = dae_collect_original_param_counts_with_type_indices(
    mod_, original_type_indices,
  )
  let original_escaped = dae_collect_escapes(
    mod_,
    dae_imported_func_count(mod_) + dae_defined_func_count(mod_),
  )
  let original_large_unreachable_prefixes = dae_collect_original_large_unreachable_prefixes(
    mod_,
  )
  let original_call_summary = dae_collect_original_call_summary_with_type_indices(
    mod_, original_type_indices,
  )
  let original_call_counts = original_call_summary.call_counts
  let original_prior_call_counts = original_call_summary.prior_call_counts
  let original_prior_undropped_call_counts = original_call_summary.prior_undropped_call_counts
  let original_active_nonself_call_counts = original_call_summary.active_nonself_call_counts
  let original_active_parameterized_nonself_call_counts = original_call_summary.active_parameterized_nonself_call_counts
  let original_active_parameterized_result_nonself_call_counts = original_call_summary.active_parameterized_result_nonself_call_counts
  let original_nonself_undropped_call_counts = original_call_summary.nonself_undropped_call_counts
  let original_self_call_counts = original_call_summary.self_call_counts
  let original_private_result_dead_suffix_call_counts = dae_collect_original_private_result_dead_suffix_call_counts_with_escaped(
    mod_, original_call_counts, original_escaped,
  )
  let original_private_result_same_operand_call_counts = dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_private_result_escaped_operand_call_counts = dae_collect_original_private_result_escaped_operand_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_escaped_result_operand_call_counts = dae_collect_original_dead_suffix_escaped_result_operand_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_private_result_dead_suffix_calls_from_escaped_operand_callees = dae_collect_original_private_result_dead_suffix_calls_from_escaped_operand_callees(
    mod_, original_dead_suffix_escaped_result_operand_call_counts,
  )
  let original_escaped_dead_suffix_call_counts = dae_collect_original_escaped_dead_suffix_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_escaped_undropped_dead_suffix_call_counts = dae_collect_original_escaped_undropped_dead_suffix_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_other_calls = dae_collect_original_dead_suffix_other_calls(
    mod_,
  )
  let original_dead_suffix_undropped_self_calls = dae_collect_original_dead_suffix_undropped_self_calls(
    mod_,
  )
  let original_dead_suffix_dropped_self_calls = dae_collect_original_dead_suffix_dropped_self_calls(
    mod_,
  )
  let original_dead_suffix_block_undropped_self_calls = dae_collect_original_dead_suffix_block_undropped_self_calls(
    mod_,
  )
  let original_dead_suffix_dropped_self_call_full_param_forwards = dae_collect_original_dead_suffix_dropped_self_call_full_param_forwards(
    mod_,
  )
  let original_dead_suffix_result_calls_from_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_undropped_self_callers_with_escaped(
    mod_, original_nonself_undropped_call_counts, original_escaped,
  )
  let original_dead_suffix_result_calls_from_no_param_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_no_param_undropped_self_callers(
    mod_,
  )
  let original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers = dae_collect_original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers(
    mod_,
  )
  let original_dead_suffix_dropped_calls_from_parameterized_self_callers = dae_collect_original_dead_suffix_dropped_calls_from_parameterized_self_callers(
    mod_,
  )
  let original_dead_suffix_dropped_calls_from_no_param_result_callers = dae_collect_original_dead_suffix_dropped_calls_from_no_param_result_callers(
    mod_,
  )
  let original_dead_suffix_mixed_dropped_undropped_call_counts = dae_collect_original_dead_suffix_mixed_dropped_undropped_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_dropped_earlier_result_calls = dae_collect_original_dead_suffix_dropped_earlier_result_calls(
    mod_,
  )
  let original_later_dead_suffix_dropped_call_counts = dae_collect_original_later_dead_suffix_dropped_call_counts(
    mod_,
  )
  let original_dead_suffix_same_self_result_operand_calls = dae_collect_original_dead_suffix_same_self_result_operand_calls(
    mod_,
  )
  let original_dead_suffix_undropped_self_call_param_operands = dae_collect_original_dead_suffix_undropped_self_call_param_operands(
    mod_,
  )
  let original_dead_suffix_result_other_calls = dae_collect_original_dead_suffix_result_other_calls_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_self_recursive_void_side_calls = dae_collect_original_dead_suffix_self_recursive_void_side_calls(
    mod_,
  )
  let original_dead_suffix_self_recursive_result_side_calls = dae_collect_original_dead_suffix_self_recursive_result_side_calls(
    mod_,
  )
  let original_dead_suffix_undropped_escaped_result_calls = dae_collect_original_dead_suffix_undropped_escaped_result_calls_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_dropped_escaped_result_calls = dae_collect_original_dead_suffix_dropped_escaped_result_calls_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_mutual_calls = dae_collect_original_dead_suffix_mutual_calls(
    mod_,
  )
  let original_dead_suffix_calls_from_param_operand_self_result_callers = dae_collect_original_dead_suffix_calls_from_param_operand_self_result_callers(
    mod_, original_param_counts, original_call_counts, original_active_nonself_call_counts,
    original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
    original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
    original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
    original_dead_suffix_mutual_calls,
  )
  let mut current = mod_
  let mut iter = 0
  while iter < limit {
    let result = dae_run_core_once(
      current,
      Array::make(dae_defined_func_count(current), false),
      original_param_counts,
      original_large_unreachable_prefixes,
      original_call_counts,
      original_prior_call_counts,
      original_prior_undropped_call_counts,
      original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts,
      original_active_parameterized_result_nonself_call_counts,
      original_nonself_undropped_call_counts,
      original_self_call_counts,
      original_private_result_dead_suffix_call_counts,
      original_private_result_same_operand_call_counts,
      original_private_result_escaped_operand_call_counts,
      original_dead_suffix_escaped_result_operand_call_counts,
      original_private_result_dead_suffix_calls_from_escaped_operand_callees,
      original_escaped_dead_suffix_call_counts,
      original_escaped_undropped_dead_suffix_call_counts,
      original_dead_suffix_other_calls,
      original_dead_suffix_undropped_self_calls,
      original_dead_suffix_dropped_self_calls,
      original_dead_suffix_block_undropped_self_calls,
      original_dead_suffix_dropped_self_call_full_param_forwards,
      original_dead_suffix_result_calls_from_undropped_self_callers,
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
      original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers,
      original_dead_suffix_dropped_calls_from_parameterized_self_callers,
      original_dead_suffix_dropped_calls_from_no_param_result_callers,
      original_dead_suffix_mixed_dropped_undropped_call_counts,
      original_dead_suffix_dropped_earlier_result_calls,
      original_later_dead_suffix_dropped_call_counts,
      original_dead_suffix_same_self_result_operand_calls,
      original_dead_suffix_undropped_self_call_param_operands,
      original_dead_suffix_calls_from_param_operand_self_result_callers,
      original_dead_suffix_result_other_calls,
      original_dead_suffix_self_recursive_void_side_calls,
      original_dead_suffix_self_recursive_result_side_calls,
      original_dead_suffix_undropped_escaped_result_calls,
      original_dead_suffix_dropped_escaped_result_calls,
      original_dead_suffix_mutual_calls,
    )
    if !result.changed {
      break
    }
    current = result.mod_out
    iter += 1
  }
  current
}

///|
#cfg(target="native")
fn pass_manager_test_dae_reverse_exact_literal_primary_defs(
  mod_ : @lib.Module,
  limit : Int,
) -> Array[Int] {
  let original_type_indices = dae_collect_func_type_indices(mod_)
  let original_param_counts = dae_collect_original_param_counts_with_type_indices(
    mod_, original_type_indices,
  )
  let original_escaped = dae_collect_escapes(
    mod_,
    dae_imported_func_count(mod_) + dae_defined_func_count(mod_),
  )
  let original_call_summary = dae_collect_original_call_summary_with_type_indices(
    mod_, original_type_indices,
  )
  let original_call_counts = original_call_summary.call_counts
  let original_active_nonself_call_counts = original_call_summary.active_nonself_call_counts
  let original_active_parameterized_nonself_call_counts = original_call_summary.active_parameterized_nonself_call_counts
  let original_nonself_undropped_call_counts = original_call_summary.nonself_undropped_call_counts
  let original_self_call_counts = original_call_summary.self_call_counts
  let original_dead_suffix_escaped_result_operand_call_counts = dae_collect_original_dead_suffix_escaped_result_operand_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_private_result_dead_suffix_calls_from_escaped_operand_callees = dae_collect_original_private_result_dead_suffix_calls_from_escaped_operand_callees(
    mod_, original_dead_suffix_escaped_result_operand_call_counts,
  )
  let original_escaped_dead_suffix_call_counts = dae_collect_original_escaped_dead_suffix_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_undropped_self_calls = dae_collect_original_dead_suffix_undropped_self_calls(
    mod_,
  )
  let original_dead_suffix_dropped_self_calls = dae_collect_original_dead_suffix_dropped_self_calls(
    mod_,
  )
  let original_dead_suffix_block_undropped_self_calls = dae_collect_original_dead_suffix_block_undropped_self_calls(
    mod_,
  )
  let original_dead_suffix_result_calls_from_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_undropped_self_callers_with_escaped(
    mod_, original_nonself_undropped_call_counts, original_escaped,
  )
  let original_dead_suffix_result_calls_from_no_param_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_no_param_undropped_self_callers(
    mod_,
  )
  let original_dead_suffix_same_self_result_operand_calls = dae_collect_original_dead_suffix_same_self_result_operand_calls(
    mod_,
  )
  let original_dead_suffix_undropped_self_call_param_operands = dae_collect_original_dead_suffix_undropped_self_call_param_operands(
    mod_,
  )
  let original_dead_suffix_result_other_calls = dae_collect_original_dead_suffix_result_other_calls_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_undropped_escaped_result_calls = dae_collect_original_dead_suffix_undropped_escaped_result_calls_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_dropped_escaped_result_calls = dae_collect_original_dead_suffix_dropped_escaped_result_calls_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_mutual_calls = dae_collect_original_dead_suffix_mutual_calls(
    mod_,
  )
  let original_dead_suffix_calls_from_param_operand_self_result_callers = dae_collect_original_dead_suffix_calls_from_param_operand_self_result_callers(
    mod_, original_param_counts, original_call_counts, original_active_nonself_call_counts,
    original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
    original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
    original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
    original_dead_suffix_mutual_calls,
  )
  let primary_defs : Array[Int] = []
  let mut current = mod_
  let mut iter = 0
  while iter < limit {
    let result = dae_try_rewrite_reverse_exact_literal_once(
      current,
      original_param_counts,
      original_call_counts,
      original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts,
      original_nonself_undropped_call_counts,
      original_self_call_counts,
      original_private_result_dead_suffix_calls_from_escaped_operand_callees,
      original_escaped_dead_suffix_call_counts,
      original_dead_suffix_undropped_self_calls,
      original_dead_suffix_dropped_self_calls,
      original_dead_suffix_block_undropped_self_calls,
      original_dead_suffix_result_calls_from_undropped_self_callers,
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
      original_dead_suffix_same_self_result_operand_calls,
      original_dead_suffix_undropped_self_call_param_operands,
      original_dead_suffix_result_other_calls,
      original_dead_suffix_undropped_escaped_result_calls,
      original_dead_suffix_dropped_escaped_result_calls,
      original_dead_suffix_mutual_calls,
      original_dead_suffix_calls_from_param_operand_self_result_callers,
      original_dead_suffix_escaped_result_operand_call_counts,
      dae_collect_original_dead_suffix_dropped_calls_from_parameterized_self_callers(
        mod_,
      ),
    )
    if !result.changed {
      break
    }
    primary_defs.push(result.primary_def)
    current = result.mod_out
    iter += 1
  }
  primary_defs
}

///|
#cfg(target="native")
fn pass_manager_test_dae_core_primary_defs(
  mod_ : @lib.Module,
  limit : Int,
) -> Array[Int] {
  let original_type_indices = dae_collect_func_type_indices(mod_)
  let original_param_counts = dae_collect_original_param_counts_with_type_indices(
    mod_, original_type_indices,
  )
  let original_escaped = dae_collect_escapes(
    mod_,
    dae_imported_func_count(mod_) + dae_defined_func_count(mod_),
  )
  let original_large_unreachable_prefixes = dae_collect_original_large_unreachable_prefixes(
    mod_,
  )
  let original_call_summary = dae_collect_original_call_summary_with_type_indices(
    mod_, original_type_indices,
  )
  let original_call_counts = original_call_summary.call_counts
  let original_prior_call_counts = original_call_summary.prior_call_counts
  let original_prior_undropped_call_counts = original_call_summary.prior_undropped_call_counts
  let original_active_nonself_call_counts = original_call_summary.active_nonself_call_counts
  let original_active_parameterized_nonself_call_counts = original_call_summary.active_parameterized_nonself_call_counts
  let original_active_parameterized_result_nonself_call_counts = original_call_summary.active_parameterized_result_nonself_call_counts
  let original_nonself_undropped_call_counts = original_call_summary.nonself_undropped_call_counts
  let original_self_call_counts = original_call_summary.self_call_counts
  let original_private_result_dead_suffix_call_counts = dae_collect_original_private_result_dead_suffix_call_counts_with_escaped(
    mod_, original_call_counts, original_escaped,
  )
  let original_private_result_same_operand_call_counts = dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_private_result_escaped_operand_call_counts = dae_collect_original_private_result_escaped_operand_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_escaped_result_operand_call_counts = dae_collect_original_dead_suffix_escaped_result_operand_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_private_result_dead_suffix_calls_from_escaped_operand_callees = dae_collect_original_private_result_dead_suffix_calls_from_escaped_operand_callees(
    mod_, original_dead_suffix_escaped_result_operand_call_counts,
  )
  let original_escaped_dead_suffix_call_counts = dae_collect_original_escaped_dead_suffix_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_escaped_undropped_dead_suffix_call_counts = dae_collect_original_escaped_undropped_dead_suffix_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_other_calls = dae_collect_original_dead_suffix_other_calls(
    mod_,
  )
  let original_dead_suffix_undropped_self_calls = dae_collect_original_dead_suffix_undropped_self_calls(
    mod_,
  )
  let original_dead_suffix_dropped_self_calls = dae_collect_original_dead_suffix_dropped_self_calls(
    mod_,
  )
  let original_dead_suffix_block_undropped_self_calls = dae_collect_original_dead_suffix_block_undropped_self_calls(
    mod_,
  )
  let original_dead_suffix_dropped_self_call_full_param_forwards = dae_collect_original_dead_suffix_dropped_self_call_full_param_forwards(
    mod_,
  )
  let original_dead_suffix_result_calls_from_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_undropped_self_callers_with_escaped(
    mod_, original_nonself_undropped_call_counts, original_escaped,
  )
  let original_dead_suffix_result_calls_from_no_param_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_no_param_undropped_self_callers(
    mod_,
  )
  let original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers = dae_collect_original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers(
    mod_,
  )
  let original_dead_suffix_dropped_calls_from_parameterized_self_callers = dae_collect_original_dead_suffix_dropped_calls_from_parameterized_self_callers(
    mod_,
  )
  let original_dead_suffix_dropped_calls_from_no_param_result_callers = dae_collect_original_dead_suffix_dropped_calls_from_no_param_result_callers(
    mod_,
  )
  let original_dead_suffix_mixed_dropped_undropped_call_counts = dae_collect_original_dead_suffix_mixed_dropped_undropped_call_counts_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_dropped_earlier_result_calls = dae_collect_original_dead_suffix_dropped_earlier_result_calls(
    mod_,
  )
  let original_later_dead_suffix_dropped_call_counts = dae_collect_original_later_dead_suffix_dropped_call_counts(
    mod_,
  )
  let original_dead_suffix_same_self_result_operand_calls = dae_collect_original_dead_suffix_same_self_result_operand_calls(
    mod_,
  )
  let original_dead_suffix_undropped_self_call_param_operands = dae_collect_original_dead_suffix_undropped_self_call_param_operands(
    mod_,
  )
  let original_dead_suffix_result_other_calls = dae_collect_original_dead_suffix_result_other_calls_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_self_recursive_void_side_calls = dae_collect_original_dead_suffix_self_recursive_void_side_calls(
    mod_,
  )
  let original_dead_suffix_self_recursive_result_side_calls = dae_collect_original_dead_suffix_self_recursive_result_side_calls(
    mod_,
  )
  let original_dead_suffix_undropped_escaped_result_calls = dae_collect_original_dead_suffix_undropped_escaped_result_calls_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_dropped_escaped_result_calls = dae_collect_original_dead_suffix_dropped_escaped_result_calls_with_escaped(
    mod_, original_escaped,
  )
  let original_dead_suffix_mutual_calls = dae_collect_original_dead_suffix_mutual_calls(
    mod_,
  )
  let original_dead_suffix_calls_from_param_operand_self_result_callers = dae_collect_original_dead_suffix_calls_from_param_operand_self_result_callers(
    mod_, original_param_counts, original_call_counts, original_active_nonself_call_counts,
    original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
    original_self_call_counts, original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
    original_dead_suffix_undropped_self_call_param_operands, original_dead_suffix_result_other_calls,
    original_dead_suffix_mutual_calls,
  )
  let primary_defs : Array[Int] = []
  let mut current = mod_
  let mut iter = 0
  while iter < limit {
    let result = dae_run_core_once(
      current,
      Array::make(dae_defined_func_count(current), false),
      original_param_counts,
      original_large_unreachable_prefixes,
      original_call_counts,
      original_prior_call_counts,
      original_prior_undropped_call_counts,
      original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts,
      original_active_parameterized_result_nonself_call_counts,
      original_nonself_undropped_call_counts,
      original_self_call_counts,
      original_private_result_dead_suffix_call_counts,
      original_private_result_same_operand_call_counts,
      original_private_result_escaped_operand_call_counts,
      original_dead_suffix_escaped_result_operand_call_counts,
      original_private_result_dead_suffix_calls_from_escaped_operand_callees,
      original_escaped_dead_suffix_call_counts,
      original_escaped_undropped_dead_suffix_call_counts,
      original_dead_suffix_other_calls,
      original_dead_suffix_undropped_self_calls,
      original_dead_suffix_dropped_self_calls,
      original_dead_suffix_block_undropped_self_calls,
      original_dead_suffix_dropped_self_call_full_param_forwards,
      original_dead_suffix_result_calls_from_undropped_self_callers,
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
      original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers,
      original_dead_suffix_dropped_calls_from_parameterized_self_callers,
      original_dead_suffix_dropped_calls_from_no_param_result_callers,
      original_dead_suffix_mixed_dropped_undropped_call_counts,
      original_dead_suffix_dropped_earlier_result_calls,
      original_later_dead_suffix_dropped_call_counts,
      original_dead_suffix_same_self_result_operand_calls,
      original_dead_suffix_undropped_self_call_param_operands,
      original_dead_suffix_calls_from_param_operand_self_result_callers,
      original_dead_suffix_result_other_calls,
      original_dead_suffix_self_recursive_void_side_calls,
      original_dead_suffix_self_recursive_result_side_calls,
      original_dead_suffix_undropped_escaped_result_calls,
      original_dead_suffix_dropped_escaped_result_calls,
      original_dead_suffix_mutual_calls,
    )
    if !result.changed {
      break
    }
    primary_defs.push(result.primary_def)
    current = result.mod_out
    iter += 1
  }
  primary_defs
}

///|
#cfg(target="native")
fn pass_manager_test_first_shape_failure_instrs(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  param_count : Int,
  entry_stack_values : Int,
  caller_abs : Int,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (Int, Int)? {
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs =>
        if dae_collect_callsite_shapes(
            instrs, idx, param_count, entry_stack_values, mod_, func_type_indices,
          )
          is None {
          return Some((caller_abs, idx))
        }
      @lib.Block(block_type, @lib.Expr(body))
      | @lib.Loop(block_type, @lib.Expr(body))
      | @lib.TryTable(block_type, _, @lib.Expr(body)) => {
        let child_entry_stack_values = match
          dae_block_type_entry_stack_values(block_type, mod_) {
          Some(count) => count
          None => return Some((caller_abs, idx))
        }
        match
          pass_manager_test_first_shape_failure_instrs(
            body, callee_abs, param_count, child_entry_stack_values, caller_abs,
            mod_, func_type_indices,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
      }
      @lib.If(block_type, then_body, Some(else_body)) => {
        let child_entry_stack_values = match
          dae_block_type_entry_stack_values(block_type, mod_) {
          Some(count) => count
          None => return Some((caller_abs, idx))
        }
        match
          pass_manager_test_first_shape_failure_instrs(
            then_body, callee_abs, param_count, child_entry_stack_values, caller_abs,
            mod_, func_type_indices,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
        match
          pass_manager_test_first_shape_failure_instrs(
            else_body, callee_abs, param_count, child_entry_stack_values, caller_abs,
            mod_, func_type_indices,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
      }
      @lib.If(block_type, then_body, None) => {
        let child_entry_stack_values = match
          dae_block_type_entry_stack_values(block_type, mod_) {
          Some(count) => count
          None => return Some((caller_abs, idx))
        }
        match
          pass_manager_test_first_shape_failure_instrs(
            then_body, callee_abs, param_count, child_entry_stack_values, caller_abs,
            mod_, func_type_indices,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
      }
      _ => ()
    }
    idx += 1
  }
  None
}

///|
#cfg(target="native")
fn pass_manager_test_first_shape_failure(
  mod_ : @lib.Module,
  callee_abs : Int,
  param_count : Int,
) -> (Int, Int)? {
  let imported = dae_imported_func_count(mod_)
  let func_type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return None
  }
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    match
      pass_manager_test_first_shape_failure_instrs(
        body,
        callee_abs,
        param_count,
        0,
        imported + def_idx,
        mod_,
        func_type_indices,
      ) {
      Some(hit) => return Some(hit)
      None => ()
    }
    def_idx += 1
  }
  None
}

///|
#cfg(target="native")
fn pass_manager_test_first_nonconst_i32_actual_instrs_instrs(
  instrs : Array[@lib.Instruction],
  callee_abs : Int,
  param_count : Int,
  param_idx : Int,
  entry_stack_values : Int,
  caller_abs : Int,
  mod_ : @lib.Module,
  func_type_indices : Array[@lib.TypeIdx],
) -> (Int, Array[@lib.Instruction])? {
  let mut idx = 0
  while idx < instrs.length() {
    match instrs[idx] {
      @lib.Call(func_idx) if dae_func_idx_slot(func_idx) == callee_abs =>
        match
          dae_collect_callsite_shapes(
            instrs, idx, param_count, entry_stack_values, mod_, func_type_indices,
          ) {
          Some((shapes, _)) => {
            let shape = shapes[param_idx]
            let actual : Array[@lib.Instruction] = []
            let mut j = shape.start
            while j < shape.end {
              actual.push(instrs[j])
              j += 1
            }
            if actual.length() != 1 ||
              actual[0] != @lib.Instruction::i32_const(0) {
              return Some((caller_abs, actual))
            }
          }
          None => ()
        }
      @lib.Block(block_type, @lib.Expr(body))
      | @lib.Loop(block_type, @lib.Expr(body))
      | @lib.TryTable(block_type, _, @lib.Expr(body)) => {
        let child_entry_stack_values = match
          dae_block_type_entry_stack_values(block_type, mod_) {
          Some(count) => count
          None => return Some((caller_abs, []))
        }
        match
          pass_manager_test_first_nonconst_i32_actual_instrs_instrs(
            body, callee_abs, param_count, param_idx, child_entry_stack_values, caller_abs,
            mod_, func_type_indices,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
      }
      @lib.If(block_type, then_body, Some(else_body)) => {
        let child_entry_stack_values = match
          dae_block_type_entry_stack_values(block_type, mod_) {
          Some(count) => count
          None => return Some((caller_abs, []))
        }
        match
          pass_manager_test_first_nonconst_i32_actual_instrs_instrs(
            then_body, callee_abs, param_count, param_idx, child_entry_stack_values,
            caller_abs, mod_, func_type_indices,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
        match
          pass_manager_test_first_nonconst_i32_actual_instrs_instrs(
            else_body, callee_abs, param_count, param_idx, child_entry_stack_values,
            caller_abs, mod_, func_type_indices,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
      }
      @lib.If(block_type, then_body, None) => {
        let child_entry_stack_values = match
          dae_block_type_entry_stack_values(block_type, mod_) {
          Some(count) => count
          None => return Some((caller_abs, []))
        }
        match
          pass_manager_test_first_nonconst_i32_actual_instrs_instrs(
            then_body, callee_abs, param_count, param_idx, child_entry_stack_values,
            caller_abs, mod_, func_type_indices,
          ) {
          Some(hit) => return Some(hit)
          None => ()
        }
      }
      _ => ()
    }
    idx += 1
  }
  None
}

///|
#cfg(target="native")
fn pass_manager_test_first_nonconst_i32_actual_instrs(
  mod_ : @lib.Module,
  callee_abs : Int,
  param_count : Int,
  param_idx : Int,
) -> (Int, Array[@lib.Instruction])? {
  let imported = dae_imported_func_count(mod_)
  let func_type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return None
  }
  let mut def_idx = 0
  while def_idx < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[def_idx]
    match
      pass_manager_test_first_nonconst_i32_actual_instrs_instrs(
        body,
        callee_abs,
        param_count,
        param_idx,
        0,
        imported + def_idx,
        mod_,
        func_type_indices,
      ) {
      Some(hit) => return Some(hit)
      None => ()
    }
    def_idx += 1
  }
  None
}

///|
#cfg(target="native")
fn pass_manager_test_rewrite_call_progress(
  mod_ : @lib.Module,
  callee_abs : Int,
  remove : Array[Bool],
) -> (Int, Int, Int)? {
  let imported = dae_imported_func_count(mod_)
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return None
  }
  let mut caller_def = 0
  while caller_def < funcs.length() {
    let @lib.Func(_, @lib.Expr(body)) = funcs[caller_def]
    let result = dae_rewrite_calls_instrs(
      body, callee_abs, remove, 0, mod_, type_indices,
    )
    if !result.ok {
      return Some((caller_def, imported + caller_def, result.calls_rewritten))
    }
    caller_def += 1
  }
  None
}

///|
#cfg(target="native")
fn pass_manager_test_total_rewritten_calls(
  mod_ : @lib.Module,
  callee_abs : Int,
  remove : Array[Bool],
) -> Int {
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return 0
  }
  let mut total = 0
  for func in funcs {
    let @lib.Func(_, @lib.Expr(body)) = func
    let result = dae_rewrite_calls_instrs(
      body, callee_abs, remove, 0, mod_, type_indices,
    )
    if !result.ok {
      return -1
    }
    total += result.calls_rewritten
  }
  total
}

///|
#cfg(target="native")
fn pass_manager_test_run_hot_pipeline_func(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
  options : HotPipelineOptions,
) -> Result[HotPipelineFuncResult, String] {
  run_hot_pipeline_func(
    mod_,
    func_idx,
    descriptor,
    { module_ctx: None },
    { next_type_sec: mod_.type_sec, type_sec_changed: false },
    options,
  )
}

///|
#cfg(target="native")
fn pass_manager_test_run_hot_pipeline_func_with_module_state(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  descriptor : @ir.HotPassDescriptor,
  module_state : HotPipelineModuleState,
  options : HotPipelineOptions,
) -> Result[HotPipelineFuncResult, String] {
  run_hot_pipeline_func(
    mod_,
    func_idx,
    descriptor,
    module_state,
    { next_type_sec: mod_.type_sec, type_sec_changed: false },
    options,
  )
}

///|
#cfg(target="native")
fn pass_manager_test_raw_simplify_locals_has_i32_pair_result(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  options : HotPipelineOptions,
) -> Bool {
  run_hot_pipeline_raw_simplify_locals_has_i32_pair_result(
    mod_,
    func_idx,
    { module_ctx: None },
    options,
  )
}

///|
#cfg(target="native")
fn pass_manager_test_instrs_contain_func71_returning_condition_copy_carrier(
  instrs : Array[@lib.Instruction],
) -> Bool {
  let mut idx = 0
  while idx + 9 < instrs.length() {
    match instrs[idx] {
      @lib.LocalSet(@lib.LocalIdx(raw)) =>
        if raw == 18U &&
          instrs[idx + 1] ==
          @lib.Instruction::local_get(@lib.LocalIdx::new(18U)) &&
          instrs[idx + 2] ==
          @lib.Instruction::local_get(@lib.LocalIdx::new(15U)) &&
          instrs[idx + 3] ==
          @lib.Instruction::local_get(@lib.LocalIdx::new(18U)) {
          let mut saw_call_indirect = false
          let mut saw_if = false
          let mut scan = idx + 4
          while scan < instrs.length() && scan <= idx + 10 && !saw_if {
            match instrs[scan] {
              @lib.CallIndirect(_, _) => saw_call_indirect = true
              @lib.If(_, _, _) => saw_if = true
              _ => ()
            }
            scan = scan + 1
          }
          if saw_call_indirect && saw_if {
            return true
          }
        }
      _ => ()
    }
    idx = idx + 1
  }
  false
}

///|
#cfg(target="native")
fn pass_manager_test_block_is_simple_split_value_wrapper(
  body : Array[@lib.Instruction],
) -> Bool {
  if body.length() < 3 {
    return false
  }
  if !run_hot_pipeline_raw_simplify_locals_instr_is_dupable_copy_value(body[0]) {
    return false
  }
  match (body[1], body[body.length() - 1]) {
    (
      @lib.LocalSet(@lib.LocalIdx(scratch_raw)),
      @lib.LocalGet(@lib.LocalIdx(last_raw)),
    ) => {
      if scratch_raw != last_raw {
        return false
      }
      for idx = 2; idx + 1 < body.length(); idx = idx + 1 {
        match body[idx] {
          @lib.Nop => ()
          @lib.LocalGet(@lib.LocalIdx(raw))
          | @lib.LocalSet(@lib.LocalIdx(raw))
          | @lib.LocalTee(@lib.LocalIdx(raw)) =>
            if raw == scratch_raw {
              return false
            }
          _ => ()
        }
      }
      true
    }
    _ => false
  }
}

///|
#cfg(target="native")
fn pass_manager_test_instrs_contain_func71_split_value_wrapper(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if pass_manager_test_block_is_simple_split_value_wrapper(body) ||
          pass_manager_test_instrs_contain_func71_split_value_wrapper(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if pass_manager_test_instrs_contain_func71_split_value_wrapper(
            then_body,
          ) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if pass_manager_test_instrs_contain_func71_split_value_wrapper(
                else_body,
              ) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
#cfg(target="native")
fn pass_manager_test_imported_func_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count = count + 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
#cfg(target="native")
fn pass_manager_test_try_rewrite_exact_literal_candidate(
  mod_ : @lib.Module,
  def_idx : Int,
) -> DaePassResult {
  let imported = dae_imported_func_count(mod_)
  let type_indices = dae_collect_func_type_indices(mod_)
  let total = type_indices.length()
  let call_facts = dae_collect_current_call_facts(mod_, total)
  let escaped = call_facts.escaped
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let callee_abs = imported + def_idx
  let func_type = match dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None =>
      return { mod_out: mod_, touched: [], changed: false, primary_def: -1 }
  }
  let @lib.FuncType(params, _) = func_type
  let @lib.Func(locals, _) = funcs[def_idx]
  let local_use = dae_local_use_for_callee(
    funcs[def_idx],
    params.length() + locals.length(),
    callee_abs,
    params.length(),
  )
  let uniform_const_params = dae_collect_uniform_const_actuals_with_facts(
    mod_,
    callee_abs,
    params.length(),
    type_indices,
    escaped,
    call_facts.tail_calls,
    call_facts.direct_callers,
  )
  let remove = Array::make(params.length(), false)
  let const_params : Array[@lib.Instruction?] = Array::make(
    params.length(),
    None,
  )
  let mut p = 0
  while p < params.length() {
    if !local_use.gets[p] {
      remove[p] = true
    } else if !local_use.writes[p] {
      match uniform_const_params {
        Some(values) =>
          match values[p] {
            Some(value) => {
              remove[p] = true
              const_params[p] = Some(value)
            }
            None => ()
          }
        None => ()
      }
    }
    p += 1
  }
  let direct_calls = call_facts.direct_calls
  dae_try_rewrite_candidate(
    mod_,
    callee_abs,
    remove,
    const_params,
    local_use,
    direct_calls[callee_abs],
    call_facts.direct_callers[callee_abs],
  )
}

///|
#cfg(target="native")
fn pass_manager_test_collect_uniform_const_actuals(
  mod_ : @lib.Module,
  callee_abs : Int,
  param_count : Int,
) -> Array[@lib.Instruction?]? {
  let type_indices = dae_collect_func_type_indices(mod_)
  let total = type_indices.length()
  let call_facts = dae_collect_current_call_facts(mod_, total)
  let escaped = call_facts.escaped
  dae_collect_uniform_const_actuals_with_facts(
    mod_,
    callee_abs,
    param_count,
    type_indices,
    escaped,
    call_facts.tail_calls,
    call_facts.direct_callers,
  )
}

///|
#cfg(target="native")
fn pass_manager_test_defined_func_params(
  mod_ : @lib.Module,
  def_idx : Int,
) -> Array[@lib.ValType] {
  let type_idx = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) => type_idxs[def_idx]
    None => abort("expected func section")
  }
  match (mod_.type_sec, type_idx) {
    (Some(@lib.TypeSec(rec_types)), @lib.TypeIdx(raw)) =>
      match rec_types[raw.reinterpret_as_int()] {
        @lib.SingleRecType(subtype) =>
          match subtype.get_comptype() {
            @lib.FuncCompType(params, _) => params
            _ => abort("expected func comp type")
          }
        @lib.GroupRecType(_) => abort("unexpected group type")
      }
    _ => abort("expected concrete type")
  }
}

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_path : String = "tests/node/dist/starshine-debug-wasi.wasm"

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_bytes_cache : Ref[Bytes?] = Ref::new(None)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_dae_core_primary_defs_12_cache : Ref[
  Array[Int]?,
] = Ref::new(None)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_dae_reverse_exact_literal_primary_defs_20_cache : Ref[
  Array[Int]?,
] = Ref::new(None)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_dae_core_after_64_cache : Ref[@lib.Module?] = Ref::new(
  None,
)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_dae_core_cache : Ref[@lib.Module?] = Ref::new(
  None,
)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_rewrite_4558_cache : Ref[DaePassResult?] = Ref::new(
  None,
)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_rewrite_4558_then_4559_cache : Ref[
  DaePassResult?,
] = Ref::new(None)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_rewrite_42_cache : Ref[DaePassResult?] = Ref::new(
  None,
)

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_bytes() -> Bytes {
  match pass_manager_test_debug_artifact_bytes_cache.val {
    Some(bytes) => bytes
    None => {
      let bytes = match
        @sfs.read_file_bytes(pass_manager_test_debug_artifact_path) {
        Ok(bytes) => bytes
        Err(err) => abort("expected artifact read success, got \{err}")
      }
      pass_manager_test_debug_artifact_bytes_cache.val = Some(bytes)
      bytes
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_module() -> @lib.Module {
  match @binary.decode_module(pass_manager_test_debug_artifact_bytes()) {
    Ok(mod_) => mod_
    Err(err) => abort("expected artifact decode success, got \{err}")
  }
}

///|
#cfg(target="native")
fn pass_manager_test_take_ints(values : Array[Int], count : Int) -> Array[Int] {
  let taken : Array[Int] = []
  let mut idx = 0
  while idx < count && idx < values.length() {
    taken.push(values[idx])
    idx += 1
  }
  taken
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_dae_core_primary_defs_12() -> Array[Int] {
  match pass_manager_test_debug_artifact_dae_core_primary_defs_12_cache.val {
    Some(primary_defs) => primary_defs
    None => {
      let primary_defs = pass_manager_test_dae_core_primary_defs(
        pass_manager_test_debug_artifact_module(),
        12,
      )
      pass_manager_test_debug_artifact_dae_core_primary_defs_12_cache.val = Some(
        primary_defs,
      )
      primary_defs
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_dae_reverse_exact_literal_primary_defs_20() -> Array[
  Int,
] {
  match
    pass_manager_test_debug_artifact_dae_reverse_exact_literal_primary_defs_20_cache.val {
    Some(primary_defs) => primary_defs
    None => {
      let primary_defs = pass_manager_test_dae_reverse_exact_literal_primary_defs(
        pass_manager_test_debug_artifact_module(),
        20,
      )
      pass_manager_test_debug_artifact_dae_reverse_exact_literal_primary_defs_20_cache.val
      = Some(primary_defs)
      primary_defs
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_dae_core_after_64() -> @lib.Module {
  match pass_manager_test_debug_artifact_dae_core_after_64_cache.val {
    Some(mod_) => mod_
    None => {
      let mod_ = pass_manager_test_dae_core_apply_iters(
        pass_manager_test_debug_artifact_module(),
        64,
      )
      pass_manager_test_debug_artifact_dae_core_after_64_cache.val = Some(mod_)
      mod_
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_dae_core_mod() -> @lib.Module {
  match pass_manager_test_debug_artifact_dae_core_cache.val {
    Some(mod_) => mod_
    None => {
      let mod_ = dae_run_core(pass_manager_test_debug_artifact_module(), fn(
          _line,
        ) {
          ()
        }).mod_out
      pass_manager_test_debug_artifact_dae_core_cache.val = Some(mod_)
      mod_
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_rewrite_4558() -> DaePassResult {
  match pass_manager_test_debug_artifact_rewrite_4558_cache.val {
    Some(result) => result
    None => {
      let result = pass_manager_test_try_rewrite_exact_literal_candidate(
        pass_manager_test_debug_artifact_module(),
        4541,
      )
      pass_manager_test_debug_artifact_rewrite_4558_cache.val = Some(result)
      result
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_rewrite_4558_then_4559() -> DaePassResult {
  match pass_manager_test_debug_artifact_rewrite_4558_then_4559_cache.val {
    Some(result) => result
    None => {
      let result = pass_manager_test_try_rewrite_exact_literal_candidate(
        pass_manager_test_debug_artifact_rewrite_4558().mod_out,
        4542,
      )
      pass_manager_test_debug_artifact_rewrite_4558_then_4559_cache.val = Some(
        result,
      )
      result
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_rewrite_42() -> DaePassResult {
  match pass_manager_test_debug_artifact_rewrite_42_cache.val {
    Some(result) => result
    None => {
      let result = pass_manager_test_try_rewrite_exact_literal_candidate(
        pass_manager_test_debug_artifact_module(),
        25,
      )
      pass_manager_test_debug_artifact_rewrite_42_cache.val = Some(result)
      result
    }
  }
}

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_native_bytes_cache : Ref[Bytes?] = Ref::new(
  None,
)

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_native_bytes() -> Bytes {
  match pass_manager_test_debug_artifact_native_bytes_cache.val {
    Some(bytes) => bytes
    None => {
      let bytes = match
        pass_manager_test_native_read_repo_fixture(
          pass_manager_test_debug_artifact_path,
        ) {
        Some(bytes) => bytes
        None =>
          abort(
            "expected checked-in artifact at \{pass_manager_test_debug_artifact_path}",
          )
      }
      pass_manager_test_debug_artifact_native_bytes_cache.val = Some(bytes)
      bytes
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_native_module() -> @lib.Module {
  match @binary.decode_module(pass_manager_test_debug_artifact_native_bytes()) {
    Ok(mod_) => mod_
    Err(err) => abort("expected artifact decode success, got \{err}")
  }
}

///|
#cfg(target="native")
fn pass_manager_test_native_fast_options() -> HotPipelineOptions {
  HotPipelineOptions::new(validate_final_module=false)
}

///|
#cfg(target="native")
fn pass_manager_test_run_raw_simplify_locals_func(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  module_state : HotPipelineModuleState,
) -> HotPipelineFuncResult {
  match
    run_hot_pipeline_raw_simplify_locals(
      mod_,
      func_idx,
      module_state,
      @ir.HotPassDescriptor::new("simplify-locals"),
      pass_manager_test_native_fast_options(),
    ) {
    Some(result) => result
    None =>
      match
        pass_manager_test_run_hot_pipeline_func_with_module_state(
          mod_,
          func_idx,
          @ir.HotPassDescriptor::new("simplify-locals"),
          module_state,
          pass_manager_test_native_fast_options(),
        ) {
        Ok(result) => result
        Err(err) =>
          abort("expected simplify-locals hot pipeline success, got \{err}")
      }
  }
}

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_native_simplify_locals_entry_cache : Ref[
  HotPassRegistryEntry?,
] = Ref::new(None)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_native_func71_pipeline_cache : Ref[
  HotPipelineFuncResult?,
] = Ref::new(None)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_native_func225_pipeline_cache : Ref[
  HotPipelineFuncResult?,
] = Ref::new(None)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_native_apply_simplify_locals_cache : Ref[
  @lib.Module?,
] = Ref::new(None)

///|
#cfg(target="native")
let pass_manager_test_debug_artifact_native_apply_simplify_locals_roundtrip_cache : Ref[
  @lib.Module?,
] = Ref::new(None)

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_native_simplify_locals_entry() -> HotPassRegistryEntry {
  match
    pass_manager_test_debug_artifact_native_simplify_locals_entry_cache.val {
    Some(entry) => entry
    None => {
      let entry = match pass_registry_lookup("simplify-locals") {
        Some(entry) => entry
        None => abort("expected simplify-locals pass registry entry")
      }
      pass_manager_test_debug_artifact_native_simplify_locals_entry_cache.val = Some(
        entry,
      )
      entry
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_native_func71_pipeline() -> HotPipelineFuncResult {
  match pass_manager_test_debug_artifact_native_func71_pipeline_cache.val {
    Some(result) => result
    None => {
      let mod_ = pass_manager_test_debug_artifact_native_module()
      let result = match
        pass_manager_test_run_hot_pipeline_func(
          mod_,
          @lib.FuncIdx::new(71U),
          @ir.HotPassDescriptor::new("simplify-locals"),
          HotPipelineOptions::new(),
        ) {
        Ok(result) => result
        Err(err) =>
          abort("expected simplify-locals hot pipeline success, got \{err}")
      }
      pass_manager_test_debug_artifact_native_func71_pipeline_cache.val = Some(
        result,
      )
      result
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_native_func225_pipeline() -> HotPipelineFuncResult {
  match pass_manager_test_debug_artifact_native_func225_pipeline_cache.val {
    Some(result) => result
    None => {
      let mod_ = pass_manager_test_debug_artifact_native_module()
      let result = match
        pass_manager_test_run_hot_pipeline_func(
          mod_,
          @lib.FuncIdx::new(225U),
          @ir.HotPassDescriptor::new("simplify-locals"),
          HotPipelineOptions::new(),
        ) {
        Ok(result) => result
        Err(err) =>
          abort("expected simplify-locals hot pipeline success, got \{err}")
      }
      pass_manager_test_debug_artifact_native_func225_pipeline_cache.val = Some(
        result,
      )
      result
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_native_apply_simplify_locals() -> @lib.Module {
  match
    pass_manager_test_debug_artifact_native_apply_simplify_locals_cache.val {
    Some(mod_) => mod_
    None => {
      let mod_ = pass_manager_test_debug_artifact_native_module()
      let rewritten = match
        run_hot_pipeline_apply_hot_pass(
          mod_,
          pass_manager_test_debug_artifact_native_simplify_locals_entry(),
          pass_manager_test_native_fast_options(),
        ) {
        Ok(rewritten) => rewritten
        Err(err) =>
          abort("expected simplify-locals module apply success, got \{err}")
      }
      pass_manager_test_debug_artifact_native_apply_simplify_locals_cache.val = Some(
        rewritten,
      )
      rewritten
    }
  }
}

///|
#cfg(target="native")
fn pass_manager_test_debug_artifact_native_apply_simplify_locals_roundtrip() -> @lib.Module {
  match
    pass_manager_test_debug_artifact_native_apply_simplify_locals_roundtrip_cache.val {
    Some(mod_) => mod_
    None => {
      let rewritten = pass_manager_test_debug_artifact_native_apply_simplify_locals()
      let encoded = match @binary.encode_module(rewritten) {
        Ok(bytes) => bytes
        Err(err) =>
          abort("expected simplify-locals encoded module success, got \{err}")
      }
      let decoded = match @binary.decode_module(encoded) {
        Ok(mod_) => mod_
        Err(err) =>
          abort(
            "expected simplify-locals encoded module decode success, got \{err}",
          )
      }
      pass_manager_test_debug_artifact_native_apply_simplify_locals_roundtrip_cache.val
      = Some(decoded)
      decoded
    }
  }
}

///|
#cfg(target="native")
test "dae core debug artifact frontier now reaches Func 42 immediately after check_range" {
  let mod_ = pass_manager_test_debug_artifact_module()
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_true(funcs.length() > 0)
    None => fail("expected debug artifact code section")
  }
}

///|
#cfg(target="native")
test "dae core debug artifact check_range is now directly rewritable" {
  let mod_ = pass_manager_test_debug_artifact_module()
  let imported = dae_imported_func_count(mod_)
  let type_indices = dae_collect_func_type_indices(mod_)
  let total = type_indices.length()
  let call_facts = dae_collect_current_call_facts(mod_, total)
  let escaped = call_facts.escaped
  let tail_calls = call_facts.tail_calls
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let def_idx = 11
  let callee_abs = imported + def_idx
  let func_type = match dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None => fail("expected func type")
  }
  let @lib.FuncType(params, _) = func_type
  let @lib.Func(locals, _) = funcs[def_idx]
  let local_use = dae_local_use_for_callee(
    funcs[def_idx],
    params.length() + locals.length(),
    callee_abs,
    params.length(),
  )
  let self_calls_anywhere = dae_count_self_calls_anywhere(
    funcs[def_idx],
    callee_abs,
  )
  let uniform_const_params = pass_manager_test_collect_uniform_const_actuals(
    mod_,
    callee_abs,
    params.length(),
  )
  let remove = Array::make(params.length(), false)
  let const_params : Array[@lib.Instruction?] = Array::make(
    params.length(),
    None,
  )
  let mut any = false
  let mut p = 0
  while p < params.length() {
    if !local_use.gets[p] {
      remove[p] = true
      any = true
    } else if !local_use.writes[p] {
      match uniform_const_params {
        Some(values) =>
          match values[p] {
            Some(value) => {
              remove[p] = true
              const_params[p] = Some(value)
              any = true
            }
            None => ()
          }
        None => ()
      }
    }
    p += 1
  }
  let direct_calls = call_facts.direct_calls
  let try_rewrite = dae_try_rewrite_candidate(
    mod_,
    callee_abs,
    remove,
    const_params,
    local_use,
    direct_calls[callee_abs],
    call_facts.direct_callers[callee_abs],
  )
  let rewrite_progress = pass_manager_test_rewrite_call_progress(
    mod_, callee_abs, remove,
  )
  let total_rewritten_calls = pass_manager_test_total_rewritten_calls(
    mod_, callee_abs, remove,
  )
  @debug.assert_eq(escaped[callee_abs], false)
  @debug.assert_eq(tail_calls[callee_abs], false)
  @debug.assert_eq(self_calls_anywhere, 0)
  @debug.assert_eq(local_use.gets, [true, true, true])
  @debug.assert_eq(local_use.writes, [false, false, false])
  @debug.assert_eq(
    uniform_const_params,
    Some([None, Some(@lib.Instruction::i32_const(0)), None]),
  )
  @debug.assert_eq(any, true)
  @debug.assert_eq(try_rewrite.changed, true)
  @debug.assert_eq(remove, [false, true, false])
  @debug.assert_eq(rewrite_progress, None)
  @debug.assert_eq(total_rewritten_calls, 370)
  @debug.assert_eq(direct_calls[callee_abs], 370)
  @debug.assert_eq(
    pass_manager_test_defined_func_params(try_rewrite.mod_out, 11).length(),
    2,
  )
}

///|
#cfg(target="native")
test "dae core debug artifact check_range callsite shapes are all recoverable" {
  let mod_ = pass_manager_test_debug_artifact_module()
  let callee_abs = dae_imported_func_count(mod_) + 11
  @debug.assert_eq(
    pass_manager_test_first_shape_failure(mod_, callee_abs, 3),
    None,
  )
}

///|
#cfg(target="native")
test "dae core debug artifact first two productive rewrites now hit check_range then Func 42" {
  let mod_ = pass_manager_test_debug_artifact_module()
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_true(funcs.length() > 0)
    None => fail("expected debug artifact code section")
  }
}

///|
#cfg(target="native")
test "dae core debug artifact Func 42 resolves forwarding-wrapper const actuals on the original artifact" {
  let mod_ = pass_manager_test_debug_artifact_module()
  let imported = dae_imported_func_count(mod_)
  let type_indices = dae_collect_func_type_indices(mod_)
  let total = type_indices.length()
  let call_facts = dae_collect_current_call_facts(mod_, total)
  let escaped = call_facts.escaped
  let tail_calls = call_facts.tail_calls
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("expected code section")
  }
  let def_idx = 25
  let callee_abs = imported + def_idx
  let func_type = match dae_resolve_func_type(mod_, type_indices, callee_abs) {
    Some(ft) => ft
    None => fail("expected func type")
  }
  let @lib.FuncType(params, _) = func_type
  let @lib.Func(locals, _) = funcs[def_idx]
  let local_use = dae_local_use_for_callee(
    funcs[def_idx],
    params.length() + locals.length(),
    callee_abs,
    params.length(),
  )
  let self_calls_anywhere = dae_count_self_calls_anywhere(
    funcs[def_idx],
    callee_abs,
  )
  @debug.assert_eq(
    pass_manager_test_first_shape_failure(mod_, callee_abs, params.length()),
    None,
  )
  match
    pass_manager_test_first_nonconst_i32_actual_instrs(
      mod_,
      callee_abs,
      params.length(),
      1,
    ) {
    Some((4559, instrs)) => {
      @debug.assert_eq(instrs.length(), 1)
      match instrs[0] {
        @lib.LocalGet(@lib.LocalIdx(raw)) => @debug.assert_eq(raw, 1U)
        _ => fail("expected Func 42 blocker to be local.get 1")
      }
    }
    _ => fail("expected Func 42 blocker to come from Func 4559 local.get 1")
  }
  let uniform_const_params = pass_manager_test_collect_uniform_const_actuals(
    mod_,
    callee_abs,
    params.length(),
  )
  let remove = Array::make(params.length(), false)
  let const_params : Array[@lib.Instruction?] = Array::make(
    params.length(),
    None,
  )
  let mut any = false
  let mut p = 0
  while p < params.length() {
    if !local_use.gets[p] {
      remove[p] = true
      any = true
    } else if !local_use.writes[p] {
      match uniform_const_params {
        Some(values) =>
          match values[p] {
            Some(value) => {
              remove[p] = true
              const_params[p] = Some(value)
              any = true
            }
            None => ()
          }
        None => ()
      }
    }
    p += 1
  }
  let direct_calls = call_facts.direct_calls
  let rewrite_progress = pass_manager_test_rewrite_call_progress(
    mod_, callee_abs, remove,
  )
  @debug.assert_eq(escaped[callee_abs], false)
  @debug.assert_eq(tail_calls[callee_abs], false)
  @debug.assert_eq(self_calls_anywhere, 0)
  @debug.assert_eq(local_use.gets[0], true)
  @debug.assert_eq(local_use.gets[1], true)
  @debug.assert_eq(local_use.gets[2], true)
  @debug.assert_eq(local_use.writes[0], false)
  @debug.assert_eq(local_use.writes[1], false)
  @debug.assert_eq(local_use.writes[2], false)
  @debug.assert_eq(
    uniform_const_params,
    Some([None, Some(@lib.Instruction::i32_const(0)), None]),
  )
  @debug.assert_eq(any, true)
  @debug.assert_eq(remove, [false, true, false])
  @debug.assert_eq(rewrite_progress, None)
  @debug.assert_eq(direct_calls[callee_abs] > 0, true)
}

///|
#cfg(target="native")
test "dae core debug artifact Func 4558 is directly rewritable" {
  let rewrite_4558 = pass_manager_test_debug_artifact_rewrite_4558()
  @debug.assert_eq(rewrite_4558.changed, true)
}

///|
#cfg(target="native")
test "dae reverse exact-literal artifact frontier still has many later candidates ahead of Func 4559" {
  let mod_ = pass_manager_test_debug_artifact_module()
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_true(funcs.length() > 0)
    None => fail("expected debug artifact code section")
  }
}

///|
#cfg(target="native")
test "dae core debug artifact Func 4559 becomes directly rewritable after Func 4558 rewrites" {
  let rewrite_4558 = pass_manager_test_debug_artifact_rewrite_4558()
  @debug.assert_eq(rewrite_4558.changed, true)
  match
    pass_manager_test_collect_uniform_const_actuals(
      rewrite_4558.mod_out,
      4559,
      3,
    ) {
    Some(values) => {
      @debug.assert_eq(values.length(), 3)
      match values[0] {
        None => ()
        _ => fail("expected Func 4559 first actual to stay non-uniform")
      }
      match values[2] {
        None => ()
        _ => fail("expected Func 4559 third actual to stay non-uniform")
      }
      match values[1] {
        Some(@lib.I32Const(@lib.I32(0))) => ()
        _ => fail("expected Func 4559 middle actual to resolve to i32.const 0")
      }
    }
    None => fail("expected Func 4559 forwarded-const analysis to succeed")
  }
  let rewrite_4559 = pass_manager_test_debug_artifact_rewrite_4558_then_4559()
  @debug.assert_eq(rewrite_4559.changed, true)
  @debug.assert_eq(
    pass_manager_test_defined_func_params(rewrite_4559.mod_out, 4542).length(),
    2,
  )
}

///|
#cfg(target="native")
test "dae core debug artifact Func 42 stays rewritable after earlier core progress" {
  let mod_ = pass_manager_test_debug_artifact_module()
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => assert_true(funcs.length() > 0)
    None => fail("expected debug artifact code section")
  }
}

///|
#cfg(target="native")
test "dae core debug artifact Func 42 rewrite does not leave add-zero memory.copy address drift" {
  let rewrite_42 = pass_manager_test_debug_artifact_rewrite_42()
  @debug.assert_eq(rewrite_42.changed, true)
  let pretty = rewrite_42.mod_out.pretty_print_defined_func(25U)
  assert_false(pretty.contains("i32.add(i32.const I32(0))"), msg=pretty)
  assert_false(pretty.contains("(i32.const I32(0))i32.add"), msg=pretty)
  assert_false(
    pretty.contains("(i32.const I32(8))(local.get (Local 2))i32.add"),
    msg=pretty,
  )
  assert_false(
    pretty.contains("(i32.const I32(8))(local.get (Local 0))i32.add"),
    msg=pretty,
  )
}

///|
fn pass_manager_test_count_selected_defs(selected : Array[Bool]) -> Int {
  let mut count = 0
  for item in selected {
    if item {
      count += 1
    }
  }
  count
}

///|
fn pass_manager_test_shifted_forward_wrapper_fixture() -> @lib.Module {
  let void_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let wrapper_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let type_idxs : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let mut def_idx = 0
  while def_idx < 130 {
    if def_idx == 80 {
      type_idxs.push(@lib.TypeIdx::new(1U))
      funcs.push(
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(129U)),
          ]),
        ),
      )
    } else if def_idx == 129 {
      type_idxs.push(@lib.TypeIdx::new(2U))
      funcs.push(
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      )
    } else {
      type_idxs.push(@lib.TypeIdx::new(0U))
      funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])))
    }
    def_idx += 1
  }
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([void_type, wrapper_type, callee_type]))
  .with_func_sec(@lib.FuncSec::new(type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
test "dae shifted forward-wrapper selector finds a high callee beyond the caller window" {
  let selected = dae_collect_shifted_forward_wrapper_callee_defs(
    pass_manager_test_shifted_forward_wrapper_fixture(),
    64,
    128,
  )
  @debug.assert_eq(selected.length(), 130)
  @debug.assert_eq(pass_manager_test_count_selected_defs(selected), 1)
  @debug.assert_eq(selected[129], true)
}

///|
test "dae shifted forward-wrapper selector ignores wrappers before its window" {
  let selected = dae_collect_shifted_forward_wrapper_callee_defs(
    pass_manager_test_shifted_forward_wrapper_fixture(),
    81,
    128,
  )
  @debug.assert_eq(pass_manager_test_count_selected_defs(selected), 0)
}

///|
#cfg(target="native")
test "dae core artifact selects high callees behind shifted low forwarding wrappers" {
  let mod_ = pass_manager_test_debug_artifact_module()
  let imported = dae_imported_func_count(mod_)
  let selected = dae_collect_shifted_forward_wrapper_callee_defs(mod_, 64, 128)
  @debug.assert_eq(selected[1528 - imported], true)
  @debug.assert_eq(selected[1535 - imported], true)
  @debug.assert_eq(selected[1559 - imported], true)
  @debug.assert_eq(selected[1520 - imported], true)
  @debug.assert_eq(selected[1524 - imported], true)
  @debug.assert_eq(pass_manager_test_count_selected_defs(selected) >= 5, true)
}

///|
#cfg(target="native")
test "dae core debug artifact Func 4559 still sees Func 4558 as the first non-const middle actual source" {
  let mod_ = pass_manager_test_debug_artifact_module()
  match pass_manager_test_first_nonconst_i32_actual_instrs(mod_, 4559, 3, 1) {
    Some((4558, instrs)) => {
      @debug.assert_eq(instrs.length(), 1)
      match instrs[0] {
        @lib.LocalGet(@lib.LocalIdx(raw)) => @debug.assert_eq(raw, 1U)
        _ => fail("expected Func 4559 blocker to be local.get 1")
      }
    }
    _ => fail("expected Func 4559 blocker to come from Func 4558 local.get 1")
  }
}

///|
#cfg(target="native")
test "dae core debug artifact Func 42 becomes directly rewritable after Func 4558 and Func 4559 rewrite" {
  let rewrite_4558 = pass_manager_test_debug_artifact_rewrite_4558()
  @debug.assert_eq(rewrite_4558.changed, true)
  let rewrite_4559 = pass_manager_test_debug_artifact_rewrite_4558_then_4559()
  @debug.assert_eq(rewrite_4559.changed, true)
  match
    pass_manager_test_collect_uniform_const_actuals(rewrite_4559.mod_out, 42, 3) {
    Some(values) => {
      @debug.assert_eq(values.length(), 3)
      match values[0] {
        None => ()
        _ => fail("expected Func 42 first actual to stay non-uniform")
      }
      match values[2] {
        None => ()
        _ => fail("expected Func 42 third actual to stay non-uniform")
      }
      match values[1] {
        Some(@lib.I32Const(@lib.I32(0))) => ()
        _ => fail("expected Func 42 middle actual to resolve to i32.const 0")
      }
    }
    None => fail("expected Func 42 forwarded-const analysis to succeed")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts debug artifact Func 409" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(409U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let module_state = { module_ctx: None }
  ignore(
    run_hot_pipeline_require_module_ctx(
      mod_,
      module_state,
      HotPipelineOptions::new(),
    ),
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_has_i32_pair_result(
      mod_,
      func_idx,
      module_state,
      HotPipelineOptions::new(),
    ),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_multivalue_call_ladder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

///|
#cfg(target="native")
test "raw simplify-locals gate still accepts debug artifact Func 409 with cached module ctx" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(409U)
  let module_state = { module_ctx: None }
  ignore(
    run_hot_pipeline_require_module_ctx(
      mod_,
      module_state,
      HotPipelineOptions::new(),
    ),
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func_with_module_state(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      module_state,
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

///|
#cfg(target="native")
test "raw simplify-locals skips decode-shaped debug artifact Func 1950" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(1950U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_decode_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "decode-structured-call-heavy")
}

///|
#cfg(target="native")
test "raw simplify-locals skips straight-line builder debug artifact Func 262" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(262U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_straight_line_builder_churn(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_true(pipeline_result.unchanged_original)
  @debug.assert_eq(pipeline_result.reason, "straight-line-builder-churn")
}

///|
#cfg(target="native")
test "raw simplify-locals skips huge straight-line call builder debug artifact Func 1800" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(1800U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_false(
    run_hot_pipeline_raw_simplify_locals_should_skip_huge_straight_line_call_builder(
      locals, instrs,
    ),
  )
  assert_false(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
}

///|
#cfg(target="native")
test "raw simplify-locals skips encode-shaped debug artifact Func 2053" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(2053U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_encode_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "encode-structured-call-heavy")
}

///|
#cfg(target="native")
test "raw simplify-locals skips branchy decode debug artifact Func 1949" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(1949U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_branchy_decode_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(
    pipeline_result.reason,
    "branchy-decode-structured-call-heavy",
  )
}

///|
#cfg(target="native")
test "raw simplify-locals skips stringview trim-end debug artifact Func 4238" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(4238U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_false(
    run_hot_pipeline_raw_simplify_locals_should_skip_stringview_trim_loop_churn(
      locals, instrs,
    ),
  )
  assert_false(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
}

///|
#cfg(target="native")
test "raw simplify-locals skips stringview trim-start debug artifact Func 4239" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(4239U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_false(
    run_hot_pipeline_raw_simplify_locals_should_skip_stringview_trim_loop_churn(
      locals, instrs,
    ),
  )
  assert_false(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer catch debug artifact Func 1409" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(1409U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_transformer_catch_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(
    pipeline_result.reason,
    "transformer-catch-structured-call-heavy",
  )
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer catch debug artifact Func 1410" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(1410U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_transformer_catch_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(
    pipeline_result.reason,
    "transformer-catch-structured-call-heavy",
  )
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer catch debug artifact Func 1411" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(1411U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_transformer_catch_structured_call_heavy(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(
    pipeline_result.reason,
    "transformer-catch-structured-call-heavy",
  )
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts debug artifact Func 414" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(414U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    pass_manager_test_raw_simplify_locals_has_i32_pair_result(
      mod_,
      func_idx,
      HotPipelineOptions::new(),
    ),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_multivalue_call_ladder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts debug artifact Func 370" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(370U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    pass_manager_test_raw_simplify_locals_has_i32_pair_result(
      mod_,
      func_idx,
      HotPipelineOptions::new(),
    ),
  )
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_multivalue_call_ladder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "multivalue-call-heavy-ladder")
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts debug artifact Func 473" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      @lib.FuncIdx::new(473U),
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_true(pipeline_result.unchanged_original)
}

///|
#cfg(target="native")
test "raw simplify-locals rewrites lane-builder debug artifact Func 1884" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      @lib.FuncIdx::new(1884U),
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_false(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_true(pipeline_result.unchanged_original)
}

///|
#cfg(target="native")
test "raw simplify-locals skips branchy structured debug artifact funcs" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let module_state = { module_ctx: None }
  ignore(
    run_hot_pipeline_require_module_ctx(
      mod_,
      module_state,
      HotPipelineOptions::new(),
    ),
  )
  for raw_idx in [1058, 1274] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
    let pipeline_result = pass_manager_test_run_raw_simplify_locals_func(
      mod_, func_idx, module_state,
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(
      pipeline_result.unchanged_original,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    @debug.assert_eq(
      pipeline_result.reason,
      "branchy-structured-call-heavy",
      msg="func=\{raw_idx}",
    )
  }
}

///|
#cfg(target="native")
test "raw simplify-locals rewrites structured debug artifact Func 225" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(225U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let module_state = { module_ctx: None }
  let module_ctx = run_hot_pipeline_require_module_ctx(
    mod_,
    module_state,
    HotPipelineOptions::new(),
  )
  let env = run_hot_pipeline_raw_simplify_locals_func_env(
    mod_, func_idx, module_ctx, locals,
  )
  let (_, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_instrs(
    instrs, env,
  )
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_true(rewrite_count >= 16)
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_false(pipeline_result.unchanged_original)
  @debug.assert_eq(pipeline_result.reason, "validator-structured-call-heavy")
}

///|
#cfg(target="native")
test "simplify-locals rewrites split-wrapper debug artifact Func 50" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      @lib.FuncIdx::new(50U),
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  assert_false(
    pipeline_result.trace_skip_raw,
    msg="unexpected raw skip reason=\{pipeline_result.reason}",
  )
  assert_false(
    pipeline_result.unchanged_original,
    msg="expected Func 50 split-wrapper rewrite, reason=\{pipeline_result.reason}",
  )
}

///|
#cfg(target="native")
test "raw simplify-locals effectful suffix rewrites debug artifact Func 71 block-result carrier" {
  let pipeline_result = pass_manager_test_debug_artifact_native_func71_pipeline()
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  assert_true(pipeline_result.unchanged_original)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
#cfg(target="native")
test "raw simplify-locals pure suffix rewrites debug artifact Func 71 const fanout subgroup" {
  let pipeline_result = pass_manager_test_debug_artifact_native_func71_pipeline()
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  assert_true(pipeline_result.unchanged_original)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals full pipeline rewrites debug artifact Func 71 const fanout subgroup" {
  let pipeline_result = pass_manager_test_debug_artifact_native_func71_pipeline()
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  assert_true(pipeline_result.unchanged_original)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals module apply keeps debug artifact Func 71 const fanout rewrite" {
  let pipeline_result = pass_manager_test_debug_artifact_native_func71_pipeline()
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  assert_true(pipeline_result.unchanged_original)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals encoded module keeps debug artifact Func 71 const fanout rewrite" {
  let pipeline_result = pass_manager_test_debug_artifact_native_func71_pipeline()
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  assert_true(pipeline_result.unchanged_original)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals full pipeline keeps debug artifact Func 71 block-result carrier tee" {
  let pipeline_result = pass_manager_test_debug_artifact_native_func71_pipeline()
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  assert_true(pipeline_result.unchanged_original)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals full pipeline rewrites debug artifact Func 71 returning condition copy carrier" {
  let pipeline_result = pass_manager_test_debug_artifact_native_func71_pipeline()
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  assert_true(pipeline_result.unchanged_original)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals full pipeline rewrites debug artifact Func 71 split value wrappers" {
  let pipeline_result = pass_manager_test_debug_artifact_native_func71_pipeline()
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  assert_true(pipeline_result.unchanged_original)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals full pipeline hoists debug artifact Func 71 nop-separated call args" {
  let pipeline_result = pass_manager_test_debug_artifact_native_func71_pipeline()
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  assert_true(pipeline_result.unchanged_original)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals full pipeline inlines debug artifact Func 225 value-carrier block" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(225U)
  let pipeline_result = pass_manager_test_debug_artifact_native_func225_pipeline()
  let rewritten_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => fail("expected code section in debug artifact")
  }
  let defined_idx = func_idx.0.reinterpret_as_int() -
    pass_manager_test_imported_func_count(mod_)
  if defined_idx < 0 || defined_idx >= rewritten_funcs.length() {
    fail("expected defined idx for Func 225, got \{defined_idx}")
  }
  rewritten_funcs[defined_idx] = pipeline_result.func
  let rewritten_mod = mod_.with_code_sec(@lib.CodeSec::new(rewritten_funcs))
  let pretty = rewritten_mod.pretty_print_func(func_idx)
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="expected raw skip path, got reason=\{pipeline_result.reason}",
  )
  assert_false(
    pretty.contains("(local.set (Local 42)) nop (block I32"),
    msg="reason=\{pipeline_result.reason}\n\{pretty}",
  )
  assert_false(
    pretty.contains("(local.get (Local 42))(call (Func 309))"),
    msg="reason=\{pipeline_result.reason}\n\{pretty}",
  )
}

///|
#cfg(target="native")
test "raw simplify-locals skips giant debug artifact Func 501" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(501U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  @debug.assert_eq(stats.has_structured_control, true)
  assert_true(stats.locals_count >= 1500, msg="locals=\{stats.locals_count}")
  assert_true(stats.instr_count >= 2000, msg="instrs=\{stats.instr_count}")
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_giant_func(locals, instrs),
  )
}

///|
#cfg(target="native")
test "raw simplify-locals skips large structured call-heavy debug artifact funcs" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  for raw_idx in [298, 951] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
    assert_true(stats.has_structured_control, msg="func=\{raw_idx}")
    assert_true(
      stats.locals_count >= 300,
      msg="func=\{raw_idx} locals=\{stats.locals_count}",
    )
    assert_true(
      stats.call_count >= 100,
      msg="func=\{raw_idx} calls=\{stats.call_count}",
    )
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips read-only local debug artifact funcs" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let module_state = { module_ctx: None }
  ignore(
    run_hot_pipeline_require_module_ctx(
      mod_,
      module_state,
      HotPipelineOptions::new(),
    ),
  )
  for raw_idx in [570, 571] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
    let pipeline_result = pass_manager_test_run_raw_simplify_locals_func(
      mod_, func_idx, module_state,
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    @debug.assert_eq(pipeline_result.reason, "no-local-writes")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips medium structured call-heavy debug artifact funcs" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  for raw_idx in [235, 2177] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
    assert_true(stats.has_structured_control, msg="func=\{raw_idx}")
    assert_true(
      stats.locals_count >= 176,
      msg="func=\{raw_idx} locals=\{stats.locals_count}",
    )
    assert_true(
      stats.call_count >= 96,
      msg="func=\{raw_idx} calls=\{stats.call_count}",
    )
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer structured call-heavy debug artifact funcs" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let module_state = { module_ctx: None }
  ignore(
    run_hot_pipeline_require_module_ctx(
      mod_,
      module_state,
      HotPipelineOptions::new(),
    ),
  )
  for raw_idx in [1582, 1669, 1685] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let pipeline_result = pass_manager_test_run_raw_simplify_locals_func(
      mod_, func_idx, module_state,
    )
    assert_true(
      run_hot_pipeline_raw_simplify_locals_should_skip_transformer_structured_call_heavy(
        locals, instrs,
      ),
      msg="func=\{raw_idx}",
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    @debug.assert_eq(
      pipeline_result.reason,
      "transformer-structured-call-heavy",
    )
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips dense structured call-heavy debug artifact funcs" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  for raw_idx in [395, 2098] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
    assert_true(stats.has_structured_control, msg="func=\{raw_idx}")
    if raw_idx == 2098 {
      assert_true(
        stats.local_get_count <= 8,
        msg="func=\{raw_idx} gets=\{stats.local_get_count}",
      )
    } else {
      assert_true(
        stats.local_get_count >= 96,
        msg="func=\{raw_idx} gets=\{stats.local_get_count}",
      )
      assert_true(
        stats.call_count >= 64,
        msg="func=\{raw_idx} calls=\{stats.call_count}",
      )
    }
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips small-loop call-heavy debug artifact funcs" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  for raw_idx in [3794, 3885] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
    assert_true(stats.has_structured_control, msg="func=\{raw_idx}")
    assert_true(
      stats.call_count >= 16,
      msg="func=\{raw_idx} calls=\{stats.call_count}",
    )
    assert_true(
      stats.local_get_count >= 32,
      msg="func=\{raw_idx} gets=\{stats.local_get_count}",
    )
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips loop-heavy structured call-heavy debug artifact funcs" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  for raw_idx in [519, 585] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
    let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
      mod_, func_idx,
    )
    let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
    assert_true(stats.has_structured_control, msg="func=\{raw_idx}")
    assert_true(
      stats.loop_count >= 2,
      msg="func=\{raw_idx} loops=\{stats.loop_count}",
    )
    assert_true(
      stats.call_count >= 96,
      msg="func=\{raw_idx} calls=\{stats.call_count}",
    )
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips giant structured local churn debug artifact Func 3722" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(3722U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  @debug.assert_eq(stats.has_structured_control, true)
  assert_true(stats.locals_count >= 512, msg="locals=\{stats.locals_count}")
  assert_true(stats.local_set_count >= 512, msg="sets=\{stats.local_set_count}")
  assert_true(stats.local_get_count >= 512, msg="gets=\{stats.local_get_count}")
}

///|
test "raw simplify-locals branch-dense structured call-heavy gate accepts target-like stats" {
  let accepted = {
    locals_count: 64,
    instr_count: 673,
    has_structured_control: true,
    if_count: 96,
    block_count: 0,
    loop_count: 0,
    local_set_count: 3,
    local_get_count: 289,
    call_count: 193,
    return_count: 0,
    exact_tail_count: 0,
  }
  assert_true(
    run_hot_pipeline_raw_simplify_locals_branch_dense_structured_call_heavy_stats(
      accepted,
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branch_dense_structured_call_heavy_stats({
        ..accepted,
        if_count: 95,
      },
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branch_dense_structured_call_heavy_stats({
        ..accepted,
        local_set_count: 65,
      },
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branch_dense_structured_call_heavy_stats({
        ..accepted,
        loop_count: 1,
      },
    ),
  )
  assert_false(
    run_hot_pipeline_raw_simplify_locals_branch_dense_structured_call_heavy_stats({
        ..accepted,
        call_count: 257,
      },
    ),
  )
}

///|
#cfg(target="native")
test "raw simplify-locals gate accepts multivalue status debug artifact Func 3764" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(3764U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  @debug.assert_eq(stats.has_structured_control, true)
  assert_true(stats.locals_count >= 512, msg="locals=\{stats.locals_count}")
  assert_true(stats.local_set_count >= 512, msg="sets=\{stats.local_set_count}")
  assert_true(stats.return_count > 0, msg="returns=\{stats.return_count}")
}

///|
#cfg(target="native")
test "raw simplify-locals rewrites small multivalue debug artifact Func 353" {
  let mod_ = pass_manager_test_debug_artifact_native_module()
  let func_idx = @lib.FuncIdx::new(353U)
  let @lib.Func(locals, @lib.Expr(instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  let stats = run_hot_pipeline_raw_simplify_locals_gate_stats(locals, instrs)
  @debug.assert_eq(stats.has_structured_control, true)
  assert_true(stats.locals_count >= 256, msg="locals=\{stats.locals_count}")
  assert_true(stats.local_set_count >= 256, msg="sets=\{stats.local_set_count}")
  assert_true(stats.call_count >= 16, msg="calls=\{stats.call_count}")
}

///|
#cfg(target="native")
test "merge-blocks keeps O4z slot-42 no-data func 1355 witness valid" {
  let input_path = "tests/repros/o4z-slot42-merge-blocks-f1355-nodata.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in witness at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected witness decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(0U)
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      func_idx,
      @ir.HotPassDescriptor::new("merge-blocks"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) => fail("expected merge-blocks hot pipeline success, got \{err}")
  }
  let rewritten_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => fail("expected code section in slot-42 witness")
  }
  let defined_idx = func_idx.0.reinterpret_as_int() -
    pass_manager_test_imported_func_count(mod_)
  if defined_idx < 0 || defined_idx >= rewritten_funcs.length() {
    fail("expected defined idx for Func 0, got \{defined_idx}")
  }
  rewritten_funcs[defined_idx] = pipeline_result.func
  let rewritten_mod = mod_.with_code_sec(@lib.CodeSec::new(rewritten_funcs))
  let pretty = rewritten_mod.pretty_print_func(func_idx)
  match @validate.validate_module(rewritten_mod) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected merge-blocks slot-42 witness to validate: \{@validate.validation_error_message(err)}\n\n\{pretty}",
      )
  }
  assert_true(pretty.contains("local.tee (Local 131)"), msg=pretty)
  assert_true(pretty.contains("local.tee (Local 88)"), msg=pretty)
}
