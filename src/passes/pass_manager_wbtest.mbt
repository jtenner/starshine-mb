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
test "raw simplify-locals gate accepts debug artifact Func 409" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_huge_straight_line_call_builder(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_true(pipeline_result.unchanged_original)
  @debug.assert_eq(pipeline_result.reason, "huge-straight-line-call-builder")
}

///|
#cfg(target="native")
test "raw simplify-locals skips encode-shaped debug artifact Func 2053" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_stringview_trim_loop_churn(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "stringview-trim-loop-churn")
}

///|
#cfg(target="native")
test "raw simplify-locals skips stringview trim-start debug artifact Func 4239" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  assert_true(
    run_hot_pipeline_raw_simplify_locals_should_skip_stringview_trim_loop_churn(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "stringview-trim-loop-churn")
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer catch debug artifact Func 1409" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(473U)
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
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_false(pipeline_result.unchanged_original)
  @debug.assert_eq(pipeline_result.reason, "straight-line-adjacent-local-tee")
}

///|
#cfg(target="native")
test "raw simplify-locals rewrites lane-builder debug artifact Func 1884" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(1884U)
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
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_false(pipeline_result.unchanged_original)
  @debug.assert_eq(pipeline_result.reason, "straight-line-lane-builder")
}

///|
#cfg(target="native")
test "raw simplify-locals skips branchy structured debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [1058, 1274] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  @debug.assert_eq(pipeline_result.reason, "structured-pure-copy-call-tail")
}

///|
#cfg(target="native")
test "simplify-locals rewrites split-wrapper debug artifact Func 50" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(71U)
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
  let (pure_suffix_instrs, _) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets(
    instrs, env,
  )
  let (rewritten_instrs, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_fixpoint(
    pure_suffix_instrs, env,
  )
  let rewritten_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => fail("expected code section in debug artifact")
  }
  let defined_idx = func_idx.0.reinterpret_as_int() -
    pass_manager_test_imported_func_count(mod_)
  if defined_idx < 0 || defined_idx >= rewritten_funcs.length() {
    fail("expected defined idx for Func 71, got \{defined_idx}")
  }
  rewritten_funcs[defined_idx] = @lib.Func::new(
    locals,
    @lib.Expr::new(rewritten_instrs),
  )
  let rewritten_mod = mod_.with_code_sec(@lib.CodeSec::new(rewritten_funcs))
  let pretty = rewritten_mod.pretty_print_func(func_idx)
  assert_true(rewrite_count > 0)
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_true(pretty.contains("local.tee (Local 7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 7)"), msg=pretty)
}

///|
#cfg(target="native")
test "raw simplify-locals pure suffix rewrites debug artifact Func 71 const fanout subgroup" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(71U)
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
  let (rewritten_instrs, rewrite_count) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
    instrs, env,
  )
  let rewritten_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => fail("expected code section in debug artifact")
  }
  let defined_idx = func_idx.0.reinterpret_as_int() -
    pass_manager_test_imported_func_count(mod_)
  if defined_idx < 0 || defined_idx >= rewritten_funcs.length() {
    fail("expected defined idx for Func 71, got \{defined_idx}")
  }
  rewritten_funcs[defined_idx] = @lib.Func::new(
    locals,
    @lib.Expr::new(rewritten_instrs),
  )
  let rewritten_mod = mod_.with_code_sec(@lib.CodeSec::new(rewritten_funcs))
  let pretty = rewritten_mod.pretty_print_func(func_idx)
  assert_true(rewrite_count > 0)
  assert_false(pretty.contains("local.set (Local 930)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 931)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 932)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 933)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 934)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 557)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 558)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 559)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 560)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 561)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 562)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 563)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 564)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 540)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 541)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 542)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 543)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 544)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 545)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 546)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 547)"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals full pipeline rewrites debug artifact Func 71 const fanout subgroup" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      @lib.FuncIdx::new(71U),
      @ir.HotPassDescriptor::new("simplify-locals"),
      HotPipelineOptions::new(),
    ) {
    Ok(result) => result
    Err(err) =>
      fail("expected simplify-locals hot pipeline success, got \{err}")
  }
  let pretty = pipeline_result.func.pretty_print(@lib.PrettyPrintContext::new())
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="unexpected raw skip reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "validator-structured-call-heavy")
  assert_false(pretty.contains("local.set (Local 930)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 931)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 932)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 933)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 934)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 557)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 558)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 559)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 560)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 561)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 562)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 563)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 564)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 540)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 541)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 542)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 543)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 544)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 545)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 546)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 547)"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals module apply keeps debug artifact Func 71 const fanout rewrite" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let entry = match pass_registry_lookup("simplify-locals") {
    Some(entry) => entry
    None => fail("expected simplify-locals pass registry entry")
  }
  let rewritten = match
    run_hot_pipeline_apply_hot_pass(mod_, entry, HotPipelineOptions::new()) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals module apply success, got \{err}")
  }
  let pretty = rewritten.pretty_print_func(@lib.FuncIdx::new(71U))
  assert_false(pretty.contains("local.set (Local 930)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 931)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 932)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 933)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 934)"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals encoded module keeps debug artifact Func 71 const fanout rewrite" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let entry = match pass_registry_lookup("simplify-locals") {
    Some(entry) => entry
    None => fail("expected simplify-locals pass registry entry")
  }
  let rewritten = match
    run_hot_pipeline_apply_hot_pass(mod_, entry, HotPipelineOptions::new()) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals module apply success, got \{err}")
  }
  let encoded = match @binary.encode_module(rewritten) {
    Ok(bytes) => bytes
    Err(err) =>
      fail("expected simplify-locals encoded module success, got \{err}")
  }
  let decoded = match @binary.decode_module(encoded) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals encoded module decode success, got \{err}")
  }
  let pretty = decoded.pretty_print_func(@lib.FuncIdx::new(71U))
  assert_false(pretty.contains("local.set (Local 930)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 931)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 932)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 933)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 934)"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals full pipeline keeps debug artifact Func 71 block-result carrier tee" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(71U)
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
  let rewritten_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => fail("expected code section in debug artifact")
  }
  let defined_idx = func_idx.0.reinterpret_as_int() -
    pass_manager_test_imported_func_count(mod_)
  if defined_idx < 0 || defined_idx >= rewritten_funcs.length() {
    fail("expected defined idx for Func 71, got \{defined_idx}")
  }
  rewritten_funcs[defined_idx] = pipeline_result.func
  let rewritten_mod = mod_.with_code_sec(@lib.CodeSec::new(rewritten_funcs))
  let pretty = rewritten_mod.pretty_print_func(func_idx)
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="expected raw skip path, got reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "validator-structured-call-heavy")
  assert_false(pipeline_result.unchanged_original)
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_true(pretty.contains("local.tee (Local 7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 7)"), msg=pretty)
}

///|
#cfg(target="native")
test "simplify-locals full pipeline rewrites debug artifact Func 71 returning condition copy carrier" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(71U)
  let @lib.Func(_, @lib.Expr(original_instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  assert_true(
    pass_manager_test_instrs_contain_func71_returning_condition_copy_carrier(
      original_instrs,
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
  let @lib.Func(_, @lib.Expr(rewritten_instrs)) = pipeline_result.func

  assert_true(
    pipeline_result.trace_skip_raw,
    msg="expected raw skip path, got reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "validator-structured-call-heavy")
  assert_false(
    pass_manager_test_instrs_contain_func71_returning_condition_copy_carrier(
      rewritten_instrs,
    ),
  )
}

///|
#cfg(target="native")
test "simplify-locals full pipeline rewrites debug artifact Func 71 split value wrappers" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(71U)
  let @lib.Func(_, @lib.Expr(original_instrs)) = run_hot_pipeline_original_func(
    mod_, func_idx,
  )
  assert_true(
    pass_manager_test_instrs_contain_func71_split_value_wrapper(original_instrs),
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
  let @lib.Func(_, @lib.Expr(rewritten_instrs)) = pipeline_result.func

  assert_true(
    pipeline_result.trace_skip_raw,
    msg="expected raw skip path, got reason=\{pipeline_result.reason}",
  )
  @debug.assert_eq(pipeline_result.reason, "validator-structured-call-heavy")
  assert_false(
    pass_manager_test_instrs_contain_func71_split_value_wrapper(
      rewritten_instrs,
    ),
  )
}

///|
#cfg(target="native")
test "simplify-locals full pipeline hoists debug artifact Func 71 nop-separated call args" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(71U)
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
  let rewritten_funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs.copy()
    None => fail("expected code section in debug artifact")
  }
  let defined_idx = func_idx.0.reinterpret_as_int() -
    pass_manager_test_imported_func_count(mod_)
  if defined_idx < 0 || defined_idx >= rewritten_funcs.length() {
    fail("expected defined idx for Func 71, got \{defined_idx}")
  }
  rewritten_funcs[defined_idx] = pipeline_result.func
  let rewritten_mod = mod_.with_code_sec(@lib.CodeSec::new(rewritten_funcs))
  let pretty = rewritten_mod.pretty_print_func(func_idx)

  assert_false(
    pretty.contains(
      "(local.get (Local 17)) (call (Func 49)) (i32.const I32(0)) nop (i32.const I32(0))",
    ),
    msg=pretty,
  )
  assert_true(
    pretty.contains("(local.get (Local 17)) (call (Func 49)) nop"),
    msg=pretty,
  )
}

///|
#cfg(target="native")
test "simplify-locals full pipeline inlines debug artifact Func 225 value-carrier block" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(225U)
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let pipeline_result = match
    pass_manager_test_run_hot_pipeline_func(
      mod_,
      @lib.FuncIdx::new(501U),
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
  @debug.assert_eq(pipeline_result.reason, "giant-local-func-noop")
}

///|
#cfg(target="native")
test "raw simplify-locals skips large structured call-heavy debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [298, 871, 901, 951] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
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
      run_hot_pipeline_raw_simplify_locals_should_skip_giant_structured_call_heavy(
        locals, instrs,
      ),
      msg="func=\{raw_idx}",
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    @debug.assert_eq(pipeline_result.reason, "giant-structured-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips read-only local debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [570, 571] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [235, 297, 713, 2177] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
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
      run_hot_pipeline_raw_simplify_locals_should_skip_medium_structured_call_heavy(
        locals, instrs,
      ),
      msg="func=\{raw_idx}",
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    @debug.assert_eq(pipeline_result.reason, "medium-structured-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips transformer structured call-heavy debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for
    raw_idx in [
      1582, 1647, 1648, 1652, 1661, 1662, 1664, 1669, 1673, 1674, 1675, 1676, 1677,
      1678, 1685,
    ] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [395, 430, 2098] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
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
      run_hot_pipeline_raw_simplify_locals_should_skip_dense_structured_call_heavy(
        locals, instrs,
      ),
      msg="func=\{raw_idx}",
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    @debug.assert_eq(pipeline_result.reason, "dense-structured-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips small-loop call-heavy debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [3794, 3885] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
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
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    @debug.assert_eq(pipeline_result.reason, "small-loop-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips loop-heavy structured call-heavy debug artifact funcs" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  for raw_idx in [519, 585] {
    let func_idx = @lib.FuncIdx::new(raw_idx.reinterpret_as_uint())
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
      run_hot_pipeline_raw_simplify_locals_should_skip_loop_heavy_structured_call_heavy(
        locals, instrs,
      ),
      msg="func=\{raw_idx}",
    )
    assert_true(
      pipeline_result.trace_skip_raw,
      msg="func=\{raw_idx} reason=\{pipeline_result.reason}",
    )
    assert_true(pipeline_result.unchanged_original, msg="func=\{raw_idx}")
    @debug.assert_eq(pipeline_result.reason, "loop-heavy-structured-call-heavy")
  }
}

///|
#cfg(target="native")
test "raw simplify-locals skips giant structured local churn debug artifact Func 3722" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(3722U)
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
    run_hot_pipeline_raw_simplify_locals_should_skip_giant_structured_local_churn(
      locals, instrs,
    ),
  )
  assert_true(
    pipeline_result.trace_skip_raw,
    msg="reason=\{pipeline_result.reason}",
  )
  assert_true(pipeline_result.unchanged_original)
  @debug.assert_eq(pipeline_result.reason, "giant-structured-local-churn")
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
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(3764U)
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
test "raw simplify-locals rewrites small multivalue debug artifact Func 353" {
  let input_path = "tests/node/dist/starshine-debug-wasi.wasm"
  let bytes = match pass_manager_test_native_read_repo_fixture(input_path) {
    Some(bytes) => bytes
    None => fail("expected checked-in artifact at \{input_path}")
  }
  let mod_ = match @binary.decode_module(bytes) {
    Ok(mod_) => mod_
    Err(err) => fail("expected artifact decode success, got \{err}")
  }
  let func_idx = @lib.FuncIdx::new(353U)
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
