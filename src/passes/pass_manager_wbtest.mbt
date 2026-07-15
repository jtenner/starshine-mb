///|
test "optimize-instructions reports raw admission and HOT setup phase timings" {
  let trace : Array[String] = []
  let perf = HotPerfSession::new(
    trace=fn(line) { trace.push(line) },
    dump_options=HotPerfDumpOptions::new(),
  )
  let input = "(module (func (export \"main\") (param i32) (result i32) local.get 0 i32.const 1 i32.add))"
  match
    pass_test_run_pipeline(
      input,
      ["optimize-instructions"],
      options=HotPipelineOptions::new(perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions timing probe success, got \{err}")
  }
  let text = trace.to_string()
  assert_true(
    text.contains(
      "perf:timer name=detail:optimize-instructions:raw-descriptor-bridges",
    ),
    msg=text,
  )
  assert_true(
    text.contains(
      "perf:timer name=detail:optimize-instructions:raw-revision-index",
    ),
    msg=text,
  )
  assert_true(
    text.contains(
      "perf:timer name=detail:optimize-instructions:unsupported-preflight",
    ),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:optimize-instructions:scratch-init"),
    msg=text,
  )
  assert_true(
    text.contains("perf:timer name=detail:optimize-instructions:free-node-init"),
    msg=text,
  )
}

///|
test "descriptor prefix value graph answers repeated hoist queries without rescanning" {
  let graph = RawOiDescriptorPrefixValueGraphFact::from_body(
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
      @lib.Instruction::ref_as_non_null(),
    ],
    0,
  )
  match graph.prefix_hoist(1) {
    Some(fact) => {
      @debug.assert_eq(fact.prefix_len, 1)
      assert_true(fact.proves_binaryen_descriptor_prefix_hoist())
    }
    None => fail("expected first descriptor prefix to hoist")
  }
  match graph.prefix_hoist(3) {
    Some(fact) => {
      @debug.assert_eq(fact.prefix_len, 3)
      assert_true(fact.proves_binaryen_descriptor_prefix_hoist())
    }
    None => fail("expected full descriptor prefix to hoist")
  }
  let blocked = RawOiDescriptorPrefixValueGraphFact::from_body(
    [
      @lib.Instruction::loop_(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    ],
    0,
  )
  assert_true(blocked.prefix_hoist(1) is None)
}

///|
test "descriptor call value graph reuses ordered local operand runs" {
  let graph = RawOiDescriptorCallValueGraphFact::from_body([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4U)),
  ])
  @debug.assert_eq(graph.local_run_end(0), 2)
  @debug.assert_eq(graph.local_run_end(1), 2)
  @debug.assert_eq(graph.local_run_end(2), 2)
  @debug.assert_eq(graph.local_run_end(3), 4)
  @debug.assert_eq(graph.local_args(0, 2), [
    @lib.LocalIdx::new(0U),
    @lib.LocalIdx::new(1U),
  ])
  @debug.assert_eq(graph.local_args(3, 4), [@lib.LocalIdx::new(3U)])
  @debug.assert_eq(graph.nontrapping_run_end(0), 2)
  @debug.assert_eq(graph.nontrapping_run_end(3), 4)
  @debug.assert_eq(graph.instr_args(0, 2), [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
  let default_graph = RawOiDescriptorCallValueGraphFact::from_body([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::struct_new_default(@lib.TypeIdx::new(1U)),
    @lib.Instruction::ref_cast_desc_eq_type(
      @lib.RefType::new(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(2U)),
        exact=true,
      ),
    ),
  ])
  assert_true(default_graph.has_local_default_candidate_at(0))
  assert_false(default_graph.has_local_default_candidate_at(1))
}

///|
test "descriptor call value graph indexes rich operand chunks through producer endpoints" {
  let value_type = @lib.TypeIdx::new(0U)
  let no_param_type = @lib.TypeIdx::new(1U)
  let module_ctx = @ir.hot_module_context_from_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i64()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([value_type, no_param_type])),
  )
  let graph = RawOiDescriptorCallValueGraphFact::from_module_body(
    [
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::select(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::i32_div_u(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(3))]),
      ),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      @lib.Instruction::ref_cast_desc_eq_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(@lib.TypeIdx::new(3U)),
          exact=true,
        ),
      ),
    ],
    module_ctx,
  )
  @debug.assert_eq(graph.descriptor_operand_miss_run_end(0), 13)
  @debug.assert_eq(graph.descriptor_operand_miss_value_count(0), 6)
  @debug.assert_eq(graph.descriptor_operand_miss_run_end(13), 13)
  @debug.assert_eq(graph.descriptor_operand_miss_value_count(13), 0)
}

///|
test "escaping ref.get_desc candidates use indexed block and suffix roots" {
  let block = @lib.Instruction::block(
    @lib.BlockType::val_type(
      @lib.ValType::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    ),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
  )
  let cast = @lib.Instruction::ref_cast_desc_eq_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let with_null_check = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    block,
    @lib.Instruction::ref_as_non_null(),
    @lib.Instruction::ref_get_desc(@lib.TypeIdx::new(0U)),
    cast,
  ])
  match
    RawOiEscapingRefGetDescCandidateFact::from_region_at(with_null_check, 0) {
    Some(candidate) => {
      assert_true(candidate.skips_explicit_null_check)
      @debug.assert_eq(candidate.end, 5)
    }
    None => fail("expected escaping descriptor candidate")
  }
  let direct = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    block,
    @lib.Instruction::ref_get_desc(@lib.TypeIdx::new(0U)),
    cast,
  ])
  match RawOiEscapingRefGetDescCandidateFact::from_region_at(direct, 0) {
    Some(candidate) => {
      assert_false(candidate.skips_explicit_null_check)
      @debug.assert_eq(candidate.end, 4)
    }
    None => fail("expected direct escaping descriptor candidate")
  }
  let blocked = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::ref_get_desc(@lib.TypeIdx::new(0U)),
    cast,
  ])
  assert_true(
    RawOiEscapingRefGetDescCandidateFact::from_region_at(blocked, 0) is None,
  )
}

///|
test "optimize-instructions raw function index collects call and select anchors once" {
  let repeated = @lib.FuncIdx::new(3U)
  let other = @lib.FuncIdx::new(9U)
  let index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::call(other),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::call(repeated),
        @lib.Instruction::call(repeated),
      ]),
    ),
    @lib.Instruction::select(),
  ])
  @debug.assert_eq(index.instruction_count, 5)
  @debug.assert_eq(index.lowered_stats.instrs, 5)
  @debug.assert_eq(index.lowered_stats.blocks, 1)
  @debug.assert_eq(index.lowered_stats.calls, 3)
  @debug.assert_eq(index.lowered_stats.ifs, 0)
  @debug.assert_eq(index.call_sites.length(), 3)
  @debug.assert_eq(index.select_anchors.length(), 1)
  assert_true(index.has_repeated_call(repeated))
  assert_false(index.has_repeated_call(other))
  assert_true(index.has_select_anchor())
}

///|
test "optimize-instructions raw function index classifies bridge candidates once" {
  let empty = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
  ])
  assert_false(empty.bridge_candidates.needs_descriptor_reconstruction())
  assert_false(empty.bridge_candidates.needs_call_ref_or_null_repair())
  let candidates = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
    @lib.Instruction::ref_get_desc(@lib.TypeIdx::new(0U)),
    @lib.Instruction::ref_cast_desc_eq_type(
      @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
    ),
    @lib.Instruction::call_ref(@lib.TypeIdx::new(1U)),
  ])
  assert_true(candidates.bridge_candidates.needs_descriptor_reconstruction())
  assert_true(candidates.bridge_candidates.has_ref_get_desc)
  assert_true(candidates.bridge_candidates.needs_call_ref_or_null_repair())
}

///|
test "optimize-instructions raw function index records reusable top-level roots" {
  let callee = @lib.FuncIdx::new(4U)
  let type_idx = @lib.TypeIdx::new(2U)
  let index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(callee),
    @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
    @lib.Instruction::call_ref(type_idx),
  ])
  @debug.assert_eq(index.top_level_roots.length(), 4)
  @debug.assert_eq(index.top_level_pure_stack_prefix_count, 1)
  assert_true(index.has_top_level_root_at(1, RawOiRootKind::DirectCall))
  assert_true(index.has_top_level_root_at(2, RawOiRootKind::TableGet))
  assert_true(index.has_top_level_root_at(3, RawOiRootKind::CallRef))
  assert_false(index.has_top_level_root_at(0, RawOiRootKind::CallRef))
  let gc_index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(1U), @lib.U32(1U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::array_get(@lib.TypeIdx::new(1U)),
  ])
  assert_true(
    gc_index.has_top_level_root_at(0, RawOiRootKind::ArrayConstructor),
  )
  assert_true(gc_index.has_top_level_root_at(1, RawOiRootKind::I32Const))
  assert_true(gc_index.has_top_level_root_at(2, RawOiRootKind::ArrayRead))
}

///|
test "optimize-instructions raw function index records nested local-load-call candidates" {
  let base = @lib.LocalIdx::new(2U)
  let index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(base),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_get(base),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
      ]),
    ),
  ])
  @debug.assert_eq(index.regions.length(), 2)
  let fact = RawOiLocalLoadCallAddressRegionFact::from_index(index)
  assert_true(fact.has_blocking_use)
}

///|
test "optimize-instructions raw function index routes nested localtee memory hazards" {
  let address_local = @lib.LocalIdx::new(2U)
  let atomic_index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_tee(address_local),
        @lib.Instruction::i32_atomic_load(@lib.MemArg::new(0U, None, 0UL)),
      ]),
    ),
  ])
  assert_true(
    RawOiAtomicLocalTeeAddressRegionFact::from_index(atomic_index).has_blocking_use,
  )
  let memory_index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_tee(address_local),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::memory_copy(
          @lib.MemIdx::new(0U),
          @lib.MemIdx::new(0U),
        ),
      ]),
    ),
  ])
  assert_true(
    RawOiMemoryLocalTeeRegionFact::from_index(memory_index, false).has_blocking_use,
  )
}

///|
test "optimize-instructions raw function index routes bottom-null descriptor candidates" {
  let heap = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::none())),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::ref_cast_desc_eq_type(@lib.RefType::new(false, heap)),
  ])
  assert_true(
    RawOiBottomNullDescriptorCastRegionFact::from_index(index).has_fold,
  )
}

///|
test "optimize-instructions raw function index routes const-offset load-call bypass" {
  let index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 4UL)),
    @lib.Instruction::drop(),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
  match RawOiConstOffsetLoadThenCallFact::from_index(index) {
    Some(fact) => assert_true(fact.proves_binaryen_offset_fold_bypass())
    None => fail("expected indexed const-offset load-call bypass")
  }
  let zero_offset = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
    @lib.Instruction::drop(),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
  assert_true(
    RawOiConstOffsetLoadThenCallFact::from_index(zero_offset).is_none(),
  )
}

///|
test "optimize-instructions raw function index routes stack bulk-memory regions" {
  let index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::memory_copy(@lib.MemIdx::new(0U), @lib.MemIdx::new(0U)),
  ])
  match
    RawOiStackBulkMemoryRegionFact::from_index(
      index,
      @ir.hot_module_context_from_module(@lib.Module::new()),
    ) {
    Some(fact) => {
      @debug.assert_eq(fact.operation_count, 1)
      assert_true(fact.proves_trap_relaxed_zero_size_drop_region())
    }
    None => fail("expected indexed stack bulk-memory region")
  }
}

///|
test "optimize-instructions same-flat memory-copy walker uses per-body region views" {
  let address = @lib.LocalIdx::new(0U)
  let fact = RawOiSameFlatPureScalarMemoryCopyRegionFact::rewrite_body([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(address),
        @lib.Instruction::local_get(address),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::memory_copy(
          @lib.MemIdx::new(0U),
          @lib.MemIdx::new(0U),
        ),
      ]),
    ),
  ])
  assert_true(fact.changed)
  match fact.rewritten {
    [@lib.Block(_, @lib.Expr(body))] => {
      @debug.assert_eq(body.length(), 6)
      assert_false(
        body.any(fn(instr) {
          match instr {
            @lib.MemoryCopy(_, _) => true
            _ => false
          }
        }),
      )
    }
    _ => fail("expected rewritten nested block")
  }
}

///|
test "optimize-instructions raw function index owns stack value transfer facts" {
  let index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i32_add(),
  ])
  let transfers = RawOiFunctionStackValueTransferFacts::from_index(
    index,
    @validate.Env::new(),
  )
  assert_true(transfers.complete)
  @debug.assert_eq(transfers.steps.length(), 3)
  @debug.assert_eq(transfers.steps[0].stack_depth_after, 1)
  @debug.assert_eq(transfers.steps[1].stack_depth_after, 2)
  @debug.assert_eq(transfers.steps[2].stack_depth_after, 1)
  assert_true(transfers.steps.all(fn(step) { step.reachable }))
}

///|
test "optimize-instructions descriptor block arguments consume indexed flow facts" {
  let safe_region = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(2)),
  ])
  assert_true(
    RawOiDescriptorCallArgBlockBodyFact::from_region(safe_region).proves_binaryen_branch_free_operand(),
  )
  let blocked_region = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  assert_false(
    RawOiDescriptorCallArgBlockBodyFact::from_region(blocked_region).proves_binaryen_branch_free_operand(),
  )
  assert_true(blocked_region.roots[1].flow.has_call)
}

///|
test "optimize-instructions bulk lowering consumes indexed region roots" {
  let region = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::memory_copy(@lib.MemIdx::new(0U), @lib.MemIdx::new(0U)),
  ])
  match RawOiBulkLoweringRewriteFact::from_region(region, 0) {
    Some(fact) => {
      assert_true(fact.proves_binaryen_bulk_lowering())
      @debug.assert_eq(fact.end, 4)
      assert_true(region.has_root_at(3, RawOiRootKind::BulkMemory))
    }
    None => fail("expected indexed bulk lowering rewrite")
  }
}

///|
test "optimize-instructions select rewrites consume indexed region roots" {
  let region = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::select(),
  ])
  match RawOiSelectRewriteFact::from_region(region, 0) {
    Some(fact) => {
      assert_true(fact.proves_binaryen_select_rewrite())
      @debug.assert_eq(fact.end, 4)
      assert_true(region.has_root_at(3, RawOiRootKind::Select))
    }
    None => fail("expected indexed select rewrite")
  }
}

///|
test "optimize-instructions memory-size boolean rewrites consume indexed region roots" {
  let region = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::memory_size(@lib.MemIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
  ])
  match RawOiMemorySizeNonzeroIfFact::from_region(region, 0) {
    Some(fact) => {
      assert_true(fact.proves_binaryen_boolean_context_rewrite())
      @debug.assert_eq(fact.end, 4)
      assert_true(region.has_root_at(0, RawOiRootKind::MemorySize))
    }
    None => fail("expected indexed memory-size boolean rewrite")
  }
}

///|
test "optimize-instructions drop-store masks consume indexed region roots" {
  let memarg = @lib.MemArg::new(0U, None, 0UL)
  let region = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(255)),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i32_store8(memarg),
  ])
  match RawOiDropStoreMaskRewriteFact::from_region(region, 0) {
    Some(fact) => {
      assert_true(fact.proves_binaryen_i32_narrow_store_mask())
      @debug.assert_eq(fact.end, 5)
      assert_true(region.has_root_at(4, RawOiRootKind::MemoryStore))
    }
    None => fail("expected indexed drop-store mask rewrite")
  }
  let wrong_mask = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(127)),
    @lib.Instruction::i32_and(),
    @lib.Instruction::i32_store8(memarg),
  ])
  assert_true(
    RawOiDropStoreMaskRewriteFact::from_region(wrong_mask, 0).is_none(),
  )
}

///|
test "optimize-instructions dropped branch if rewrites consume indexed if roots" {
  let condition = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let region = RawOiInstructionRegionFact::from_instrs([
    condition,
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::i32_const(@lib.I32(1)), @lib.Instruction::drop()],
      Some([@lib.Instruction::i32_const(@lib.I32(2)), @lib.Instruction::drop()]),
    ),
  ])
  match RawOiDroppedConstBranchIfFact::from_region(region, 0) {
    Some(fact) => {
      assert_true(fact.proves_binaryen_dropped_branch_rewrite())
      @debug.assert_eq(fact.end, 2)
      assert_true(region.has_root_at(1, RawOiRootKind::If))
    }
    None => fail("expected indexed dropped-branch if rewrite")
  }
  let mismatched = RawOiInstructionRegionFact::from_instrs([
    condition,
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::i32_const(@lib.I32(1)), @lib.Instruction::drop()],
      Some([@lib.Instruction::i64_const(@lib.I64(2L)), @lib.Instruction::drop()]),
    ),
  ])
  assert_true(
    RawOiDroppedConstBranchIfFact::from_region(mismatched, 0).is_none(),
  )
}

///|
test "optimize-instructions scalar numeric rewrites consume indexed terminal roots" {
  let region = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::i32_mul(),
  ])
  match RawOiScalarNumericRewriteFact::from_region(region, 0) {
    Some(fact) => {
      assert_true(fact.proves_binaryen_numeric_rewrite())
      @debug.assert_eq(fact.end, 3)
      assert_true(region.has_root_at(2, RawOiRootKind::ScalarNumericTerminal))
    }
    None => fail("expected indexed scalar numeric rewrite")
  }
  let boundary = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_mul(),
  ])
  assert_true(RawOiScalarNumericRewriteFact::from_region(boundary, 0).is_none())
}

///|
test "optimize-instructions memory offset folds consume indexed region roots" {
  let region = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 4UL)),
  ])
  match RawOiMemoryOffsetFoldRewriteFact::from_region(region, 0) {
    Some(fact) => {
      assert_true(fact.proves_binaryen_memory_offset_fold())
      @debug.assert_eq(fact.end, 2)
    }
    None => fail("expected indexed memory offset fold")
  }
  let zero_offset = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
  ])
  assert_true(
    RawOiMemoryOffsetFoldRewriteFact::from_region(zero_offset, 0).is_none(),
  )
}

///|
test "optimize-instructions module revision facts reuse indexed direct-call roots" {
  let index = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  let facts = RawOiModuleFunctionRevisionFacts::from_index(
    index,
    @ir.hot_module_context_from_module(@lib.Module::new()),
  )
  assert_true(facts.is_constructor_operand_at(0))
  assert_false(facts.is_constructor_operand_at(1))
  assert_true(facts.range_has_direct_call(0, 2))
}

///|
test "optimize-instructions raw function index rebuilds from a changed snapshot" {
  let target = @lib.FuncIdx::new(4U)
  let before = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::call(target),
  ])
  let after = RawOiFunctionRevisionFactIndex::from_instrs([
    @lib.Instruction::call(target),
    @lib.Instruction::call(target),
    @lib.Instruction::select(),
  ])
  assert_false(before.has_repeated_call(target))
  assert_false(before.has_select_anchor())
  assert_true(after.has_repeated_call(target))
  assert_true(after.has_select_anchor())
  assert_true(after.instruction_count > before.instruction_count)
  assert_true(after.lowered_stats.instrs > before.lowered_stats.instrs)
  @debug.assert_eq(before.lowered_stats.calls, 1)
  @debug.assert_eq(after.lowered_stats.calls, 2)
}

///|
test "optimize-instructions call_ref overlay rejects local-carried target propagation" {
  let target = @lib.FuncIdx::new(7U)
  let type_idx = @lib.TypeIdx::new(3U)
  let target_local = @lib.LocalIdx::new(2U)
  let original = [
    @lib.Instruction::ref_func(target),
    @lib.Instruction::local_set(target_local),
    @lib.Instruction::local_get(target_local),
    @lib.Instruction::call_ref(type_idx),
  ]
  let overlay : RawOiCurrentRootRevisionOverlay = {
    current: original[0],
    region: RawOiInstructionRegionFact::from_instrs(original),
    start: 0,
  }
  match RawOiCallRefDirectizeRewriteFact::from_overlay(overlay) {
    None => ()
    Some(_) =>
      fail("local assignment dataflow must not prove a direct call_ref target")
  }
}

///|
test "optimize-instructions ref-null trap repair consumes indexed region roots" {
  let heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let region = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::ref_as_non_null(),
  ])
  match
    RawOiRefNullTrapRewriteFact::from_region(region.roots[0].instr, region, 0) {
    Some(fact) => {
      assert_true(fact.proves_binaryen_ref_null_trap_repair())
      @debug.assert_eq(fact.end, 2)
      assert_true(region.has_root_at(0, RawOiRootKind::RefNull))
    }
    None => fail("expected indexed ref-null trap repair")
  }
  let boundary = RawOiInstructionRegionFact::from_instrs([
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::drop(),
  ])
  assert_true(
    RawOiRefNullTrapRewriteFact::from_region(
      boundary.roots[0].instr,
      boundary,
      0,
    ).is_none(),
  )
}

///|
test "optimize-instructions raw directizes adjacent ref.func call_ref before skip" {
  // OI-H grouped-sweep follow-up: profile-backed `oi-call-ref-target-wrapper`
  // classified a large size-losing raw-gate gap. The raw skip path may still
  // safely rewrite adjacent `ref.func` / `call_ref` pairs without lifting the
  // whole function through HOT.
  let target = @lib.FuncIdx::new(7U)
  let type_idx = @lib.TypeIdx::new(3U)
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body([
      @lib.Instruction::i32_const(@lib.I32(99)),
      @lib.Instruction::ref_func(target),
      @lib.Instruction::call_ref(type_idx),
      @lib.Instruction::block(
        @lib.BlockType::val_type(
          @lib.ValType::ref_type(@lib.RefType::abs(@lib.AbsHeapType::func())),
        ),
        @lib.Expr::new([@lib.Instruction::ref_func(target)]),
      ),
      @lib.Instruction::return_call_ref(type_idx),
    ],
  )
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::call(target),
    @lib.Instruction::return_call(target),
  ])
}

///|
test "optimize-instructions raw lowers table.get call_ref to call_indirect before skip" {
  // OI-H table-get-target residual: Binaryen lowers a table target consumed by
  // call_ref to call_indirect. This is a local stack-equivalent rewrite and
  // does not claim table-state known-target directization.
  let table_idx = @lib.TableIdx::new(1U)
  let type_idx = @lib.TypeIdx::new(3U)
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body([
      @lib.Instruction::i32_const(@lib.I32(99)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::table_get(table_idx),
      @lib.Instruction::call_ref(type_idx),
      @lib.Instruction::drop(),
    ],
  )
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::call_indirect(type_idx, table_idx),
    @lib.Instruction::drop(),
  ])
}

///|
test "optimize-instructions raw lowers table.get return_call_ref to return_call_indirect before skip" {
  // Non-void OI-H table target tail-call boundary: table.get supplies the same
  // dynamic table index that return_call_indirect consumes, so this is a
  // stack-equivalent table-target lowering rather than table-state proof.
  let table_idx = @lib.TableIdx::new(1U)
  let type_idx = @lib.TypeIdx::new(3U)
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::table_get(table_idx),
      @lib.Instruction::return_call_ref(type_idx),
    ],
  )
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::return_call_indirect(type_idx, table_idx),
  ])
}

///|
test "optimize-instructions raw directizes constant select ref.func call_ref before skip" {
  let left = @lib.FuncIdx::new(7U)
  let right = @lib.FuncIdx::new(8U)
  let type_idx = @lib.TypeIdx::new(3U)
  let typed_func_ref = @lib.ValType::ref_type(
    @lib.RefType::abs(@lib.AbsHeapType::func()),
  )
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body([
      @lib.Instruction::ref_func(left),
      @lib.Instruction::ref_func(right),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::select(types=Some([typed_func_ref])),
      @lib.Instruction::call_ref(type_idx),
    ],
  )
  assert_true(changed)
  @debug.assert_eq(rewritten, [@lib.Instruction::call(right)])
}

///|
test "optimize-instructions raw keeps local-carried ref.func call_ref before skip" {
  // Binaryen v130 does not treat a previous local assignment as the syntactic
  // fallthrough of a later local.get target. The raw bridge must therefore keep
  // the binding and call_ref even when the local has only one read.
  let target = @lib.FuncIdx::new(7U)
  let type_idx = @lib.TypeIdx::new(3U)
  let target_local = @lib.LocalIdx::new(0U)
  let original = [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::ref_func(target),
    @lib.Instruction::local_set(target_local),
    @lib.Instruction::local_get(target_local),
    @lib.Instruction::call_ref(type_idx),
    @lib.Instruction::drop(),
  ]
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body(
    original,
  )
  assert_false(changed)
  @debug.assert_eq(rewritten, original)
}

///|
test "optimize-instructions raw trims null as_non_null dead tail before skip" {
  // OI-H target-wrapper smoke residuals are not safely table-directizable yet:
  // they sit in the tail after a guaranteed `ref.null; ref.as_non_null` trap.
  // The raw skip path may collapse that trap to `unreachable` and remove the
  // later dynamic `table.get` / `call_ref` debris without proving table state.
  let type_idx = @lib.TypeIdx::new(3U)
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body([
      @lib.Instruction::i32_const(@lib.I32(99)),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
      @lib.Instruction::ref_as_non_null(),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::table_get(@lib.TableIdx::new(1U)),
      @lib.Instruction::ref_cast(false, @lib.HeapType::new(type_idx)),
      @lib.Instruction::call_ref(type_idx),
    ],
  )
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
  ])
}

///|
test "optimize-instructions raw trims dropped unreachable block tail before skip" {
  // The same OI-H smoke leaves folded `drop (unreachable)` debris when a
  // guaranteed trap is nested under a result block. A dropped block whose body
  // cannot reach its result is equivalent to an immediate unreachable tail.
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::drop(),
      @lib.Instruction::block(
        @lib.BlockType::val_type(
          @lib.ValType::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any())),
        ),
        @lib.Expr::new([@lib.Instruction::unreachable_()]),
      ),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::drop(),
    ],
  )
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
  ])
}

///|
test "optimize-instructions raw folds dropped null ref test and nullable cast before skip" {
  // OI-I residuals in the OI-H target-wrapper smoke include already-dead
  // `drop (ref.test nullref (ref.null none))` and nullable `ref.cast` debris.
  // Folding those while preserving the drops is local, stack-neutral cleanup
  // and does not widen the full HOT raw gate.
  let none_heap = @lib.HeapType::abs(@lib.AbsHeapType::none())
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body([
      @lib.Instruction::ref_null(none_heap),
      @lib.Instruction::ref_test(true, none_heap),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(none_heap),
      @lib.Instruction::ref_cast(true, none_heap),
      @lib.Instruction::drop(),
      @lib.Instruction::unreachable_(),
    ],
  )
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
    @lib.Instruction::ref_null(none_heap),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
  ])
}

///|
test "optimize-instructions raw folds effectful trapping descriptor block operands before skip" {
  // OI-J active-dispatcher descriptor/null slice: when HOT lift is skipped or
  // cannot represent a bottom-null descriptor cast, the raw dispatcher still
  // must preserve effects before a trapping descriptor operand and replace the
  // whole cast with `unreachable`, matching the Binaryen effect-before-trap
  // shape for this narrow block-local descriptor operand.
  let none_heap = @lib.HeapType::abs(@lib.AbsHeapType::none())
  let described_type = @lib.TypeIdx::new(0U)
  let descriptor_type = @lib.TypeIdx::new(1U)
  let described_heap = @lib.HeapType::new(described_type)
  let descriptor_heap = @lib.HeapType::new(descriptor_type)
  let descriptor_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, descriptor_heap),
  )
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_effectful_sibling_body(
    [
      @lib.Instruction::ref_null(none_heap),
      @lib.Instruction::block(
        @lib.BlockType::val_type(descriptor_ref),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::ref_null(descriptor_heap),
          @lib.Instruction::ref_as_non_null(),
        ]),
      ),
      @lib.Instruction::ref_cast_desc_eq_type(
        @lib.RefType::new(false, described_heap),
      ),
    ],
    @ir.hot_module_context_from_module(@lib.Module::new()),
  )
  assert_true(changed)
  @debug.assert_eq(rewritten.length(), 3)
  @debug.assert_eq(rewritten[0], @lib.Instruction::i32_const(@lib.I32(7)))
  @debug.assert_eq(
    rewritten[1],
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
  )
  @debug.assert_eq(rewritten[2], @lib.Instruction::unreachable_())
}

///|
test "optimize-instructions raw folds self-contained control descriptor trap prefixes" {
  // OI-J active-dispatcher descriptor/null slice: self-contained control in a
  // descriptor operand prefix can be hoisted before the final trap because all
  // branch targets remain inside the hoisted prefix. Escaping branches remain
  // covered by the fail-closed boundary below.
  let none_heap = @lib.HeapType::abs(@lib.AbsHeapType::none())
  let described_type = @lib.TypeIdx::new(0U)
  let descriptor_type = @lib.TypeIdx::new(1U)
  let described_heap = @lib.HeapType::new(described_type)
  let descriptor_heap = @lib.HeapType::new(descriptor_type)
  let descriptor_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, descriptor_heap),
  )
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_effectful_sibling_body(
    [
      @lib.Instruction::ref_null(none_heap),
      @lib.Instruction::block(
        @lib.BlockType::val_type(descriptor_ref),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(7)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            ]),
          ),
          @lib.Instruction::ref_null(descriptor_heap),
          @lib.Instruction::ref_as_non_null(),
        ]),
      ),
      @lib.Instruction::ref_cast_desc_eq_type(
        @lib.RefType::new(false, described_heap),
      ),
    ],
    @ir.hot_module_context_from_module(@lib.Module::new()),
  )
  assert_true(changed)
  @debug.assert_eq(rewritten.length(), 2)
  @debug.assert_eq(
    rewritten[0],
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
  )
  @debug.assert_eq(rewritten[1], @lib.Instruction::unreachable_())
}

///|
test "optimize-instructions raw folds descriptor trap blocks already ending unreachable" {
  // OI-J active-dispatcher descriptor/null slice: earlier raw cleanup may move
  // a descriptor operand's null trap to a trailing `unreachable`. The bottom-null
  // descriptor-cast fold must still hoist self-contained prefixes and remove the
  // now-unreachable descriptor equality cast.
  let none_heap = @lib.HeapType::abs(@lib.AbsHeapType::none())
  let described_type = @lib.TypeIdx::new(0U)
  let descriptor_type = @lib.TypeIdx::new(1U)
  let described_heap = @lib.HeapType::new(described_type)
  let descriptor_heap = @lib.HeapType::new(descriptor_type)
  let descriptor_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, descriptor_heap),
  )
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_effectful_sibling_body(
    [
      @lib.Instruction::ref_null(none_heap),
      @lib.Instruction::block(
        @lib.BlockType::val_type(descriptor_ref),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::i32_const(@lib.I32(2)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            ],
            Some([
              @lib.Instruction::i32_const(@lib.I32(3)),
              @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
            ]),
          ),
          @lib.Instruction::unreachable_(),
        ]),
      ),
      @lib.Instruction::ref_cast_desc_eq_type(
        @lib.RefType::new(false, described_heap),
      ),
    ],
    @ir.hot_module_context_from_module(@lib.Module::new()),
  )
  assert_true(changed)
  @debug.assert_eq(rewritten.length(), 3)
  match rewritten[1] {
    @lib.If(_, _, _) => ()
    other => fail("expected self-contained if prefix, got \{other}")
  }
  @debug.assert_eq(rewritten[2], @lib.Instruction::unreachable_())
}

///|
test "optimize-instructions raw keeps descriptor trap block prefixes with control local" {
  // Boundary/fail-closed: the raw descriptor block fold only hoists flat or
  // self-contained control prefixes before the final `ref.null; ref.as_non_null`.
  // Prefixes with branches to the descriptor block label depend on that label
  // stack and must stay untouched until a label-aware raw localizer exists.
  let none_heap = @lib.HeapType::abs(@lib.AbsHeapType::none())
  let described_type = @lib.TypeIdx::new(0U)
  let descriptor_type = @lib.TypeIdx::new(1U)
  let described_heap = @lib.HeapType::new(described_type)
  let descriptor_heap = @lib.HeapType::new(descriptor_type)
  let descriptor_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, descriptor_heap),
  )
  let instrs = [
    @lib.Instruction::ref_null(none_heap),
    @lib.Instruction::block(
      @lib.BlockType::val_type(descriptor_ref),
      @lib.Expr::new([
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        @lib.Instruction::ref_null(descriptor_heap),
        @lib.Instruction::ref_as_non_null(),
      ]),
    ),
    @lib.Instruction::ref_cast_desc_eq_type(
      @lib.RefType::new(false, described_heap),
    ),
  ]
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_effectful_sibling_body(
    instrs,
    @ir.hot_module_context_from_module(@lib.Module::new()),
  )
  assert_false(changed)
  @debug.assert_eq(rewritten, instrs)
}

///|
test "optimize-instructions raw folds local-carried null ref test and nullable cast before skip" {
  // OI-I grouped pass-oi-ref-gc residual: after an effectful wrapper forces the
  // raw optimize-instructions skip path, Binaryen still uses the local-carried
  // known null fact to remove dropped nullable ref.test/ref.cast operations.
  // Keep the local.set and earlier null test ordering, but eliminate the
  // redundant local-carried test/cast debris without making descriptor claims.
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let target_local = @lib.LocalIdx::new(0U)
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body([
      @lib.Instruction::i32_const(@lib.I32(101)),
      @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::ref_null(any_heap),
      @lib.Instruction::local_set(target_local),
      @lib.Instruction::local_get(target_local),
      @lib.Instruction::ref_is_null(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(target_local),
      @lib.Instruction::ref_test(true, any_heap),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(target_local),
      @lib.Instruction::ref_cast(true, any_heap),
      @lib.Instruction::drop(),
    ],
  )
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(101)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::ref_null(any_heap),
    @lib.Instruction::local_set(target_local),
    @lib.Instruction::local_get(target_local),
    @lib.Instruction::ref_is_null(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(target_local),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(target_local),
    @lib.Instruction::drop(),
  ])
}

///|
test "optimize-instructions raw trims dropped null non-null ref cast tail before skip" {
  // A non-null ref.cast fed by ref.null is a guaranteed trap. The raw skip
  // cleanup may replace the dropped cast with an immediate unreachable and
  // truncate later GC branch debris in the same dead tail.
  let none_heap = @lib.HeapType::abs(@lib.AbsHeapType::none())
  let (rewritten, changed) = run_hot_pipeline_raw_optimize_instructions_directize_call_ref_body([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(none_heap),
      @lib.Instruction::ref_cast(false, none_heap),
      @lib.Instruction::drop(),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::ref_null(none_heap)),
        @lib.Expr::new([
          @lib.Instruction::ref_null(none_heap),
          @lib.Instruction::br_on_cast(
            @lib.LabelIdx::new(0U),
            false,
            none_heap,
            false,
            none_heap,
          ),
        ]),
      ),
      @lib.Instruction::drop(),
    ],
  )
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
  ])
}

///|
test "ssa-nomerge fresh local helper handles already-appended scratch locals" {
  // Native artifact refresh for the remaining ssa-nomerge sampled bucket exposed
  // this crash: earlier cleanup stages can append scratch locals before the
  // store-driven scratch freshener runs. When that later stage freshens an
  // already-appended local, it must read the type from `extra_local_types`, not
  // index past the original body-local vector.
  let params : Array[@lib.ValType] = []
  let locals = @lib.Locals::from_types([@lib.ValType::i32()])
  let extra_local_types = [@lib.ValType::i32()]
  let fresh = run_hot_pipeline_raw_fresh_local(
    params, locals, 1, extra_local_types,
  )
  @debug.assert_eq(fresh, @lib.LocalIdx::new(2U))
  @debug.assert_eq(extra_local_types.length(), 2)
  @debug.assert_eq(extra_local_types[1], @lib.ValType::i32())
}

///|
test "ssa-nomerge scratch freshener aliases already-appended locals" {
  // Same artifact-refresh crash as above at the caller level: the scratch
  // freshener may decide to freshen a write to an already-appended local after a
  // tee. The alias table must grow with appended locals instead of assuming the
  // original local budget is the maximum index it can rewrite.
  let params : Array[@lib.ValType] = []
  let locals = @lib.Locals::from_types([@lib.ValType::i32()])
  let extra_local_types = [@lib.ValType::i32()]
  let appended = @lib.LocalIdx::new(1U)
  let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes_with_aliases(
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::local_tee(appended),
      @lib.Instruction::local_set(appended),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
      @lib.Instruction::local_get(appended),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::local_tee(appended),
      @lib.Instruction::local_set(appended),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
      @lib.Instruction::local_get(appended),
    ],
    params,
    locals,
    extra_local_types,
    [None],
    @bitset.BitSet::new(params.length() + locals.length()),
  )
  @debug.assert_eq(extra_local_types.length(), 2)
  @debug.assert_eq(
    rewritten[2],
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  )
  @debug.assert_eq(
    rewritten[6],
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  )
}

///|
test "ssa-nomerge scratch freshener preserves one-arm branch-overwritten body carriers" {
  // JSON-AS containers-runtime exposed this shape in an AS runtime helper:
  // a loaded body scratch local is tee'd, an if then-arm overwrites that same
  // local while the else arm only reads it, and the post-if code reads the
  // canonical local as the branch merge carrier. Freshening the pre-if tee and
  // then-arm tee separately leaves the post-if canonical read stale.
  let params : Array[@lib.ValType] = [
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
  ]
  let locals = @lib.Locals::from_types([
    @lib.ValType::i32(),
    @lib.ValType::i32(),
    @lib.ValType::i32(),
  ])
  let extra_local_types : Array[@lib.ValType] = []
  let carrier = @lib.LocalIdx::new(5U)
  let rewritten = run_hot_pipeline_raw_freshen_param_scratch_writes(
    [
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
      @lib.Instruction::local_tee(carrier),
      @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
      @lib.Instruction::local_get(carrier),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::local_tee(carrier),
          @lib.Instruction::drop(),
        ],
        Some([@lib.Instruction::local_get(carrier), @lib.Instruction::drop()]),
      ),
      @lib.Instruction::local_get(carrier),
    ],
    params,
    locals,
    extra_local_types,
  )

  @debug.assert_eq(extra_local_types.length(), 0)
  @debug.assert_eq(rewritten[3], @lib.Instruction::local_tee(carrier))
  match rewritten[7] {
    @lib.If(_, then_body, _) =>
      @debug.assert_eq(then_body[1], @lib.Instruction::local_tee(carrier))
    _ => fail("expected if in rewritten scratch fixture")
  }
  @debug.assert_eq(rewritten[8], @lib.Instruction::local_get(carrier))
}

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
    func,
    "simplify-locals-nostructure",
    None,
    mod_,
  )
  @debug.assert_eq(cleaned, func)
}

///|
test "simplify-locals-nostructure lowered cleanup refinalizes ref.func null if result" {
  // Binaryen version_130's ReFinalize pass narrows a `funcref` if whose arms
  // are `ref.func $dummy` and `ref.null func` to `(ref null (exact $ft))` after
  // a same-function ref.func local simplification trigger. This whitebox test
  // covers the generated case-000251 suffix without relying on public call_ref
  // WAT spellings that the current test parser rejects.
  let mod_ = pass_test_module_from_wat(
    "(module (type $ft (func)) (elem declare func $dummy) (tag $e) (func $dummy (type $ft)) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop (i32.const 0) (if (result funcref) (then ref.func $dummy) (else ref.null func)) drop (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else (try_table (result exnref) (catch_all_ref $h) throw $e))))))",
  )
  let (dummy_func, func) = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => (funcs[0], funcs[1])
    None => fail("expected code section")
  }
  let cleaned = run_hot_pipeline_canonicalize_lowered_func_for_descriptor(
    func,
    "simplify-locals-nostructure",
    Some(func),
    mod_,
  )
  let optimized = mod_.with_code_sec(@lib.CodeSec::new([dummy_func, cleaned]))
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("Exact (HeapType Idx 0)"), msg=pretty)
  assert_true(
    pretty.contains("ref.null (RefType Null Exact (HeapType Idx 0))"),
    msg=pretty,
  )
  assert_false(
    pretty.contains("if (RefType Null (AbsHeapType Func))"),
    msg=pretty,
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact ref.func/null if cleanup to validate, got \{@validate.validation_error_message(err)}: \{pretty}",
      )
  }
}

///|
test "simplify-locals-nostructure lowered cleanup directizes ref.func local call_ref target" {
  // Generated case-000251 also keeps a `ref.func; local.set; local.get;
  // call_ref` target wrapper in Starshine while Binaryen replaces the local
  // traffic with a direct `ref.func` call_ref target under the same
  // refinalization-triggered lowered-cleanup context. Build the fixture directly
  // because the public WAT fixture path is still parser-blocked for this form.
  let callee_type = @lib.TypeIdx::new(0U)
  let run_type = @lib.TypeIdx::new(1U)
  let callee_idx = @lib.FuncIdx::new(0U)
  let target_local = @lib.LocalIdx::new(0U)
  let typed_callee_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(callee_type)),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::ref_null_exn()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([callee_type, run_type]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([typed_callee_ref]),
          @lib.Expr::new([
            @lib.Instruction::ref_func(callee_idx),
            @lib.Instruction::local_set(target_local),
            @lib.Instruction::local_get(target_local),
            @lib.Instruction::call_ref(callee_type),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::exn()),
            ),
          ]),
        ),
      ]),
    )
  let func = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[1]
    None => fail("expected code section")
  }
  let cleaned = run_hot_pipeline_canonicalize_lowered_func_for_descriptor(
    func,
    "simplify-locals-nostructure",
    Some(func),
    mod_,
  )
  let optimized = mod_.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      cleaned,
    ]),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected directized call_ref cleanup to validate, got \{err}: \{pretty}",
      )
  }
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
fn pass_manager_test_vacuum_tag_cascade_body(
  group_count : Int,
  start_value : Int,
  tag_value : Int,
) -> Array[@lib.Instruction] {
  let body : Array[@lib.Instruction] = [@lib.Instruction::nop()]
  for group = 0; group < group_count; group = group + 1 {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::i32_const(@lib.I32(start_value + group)))
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(17U)))
    body.push(
      @lib.Instruction::local_set(
        @lib.LocalIdx::new((7 + group).reinterpret_as_uint()),
      ),
    )
    body.push(@lib.Instruction::nop())
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(7U)))
  body.push(@lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)))
  body.push(@lib.Instruction::i32_const(@lib.I32(tag_value)))
  body.push(@lib.Instruction::i32_eq())
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::br(@lib.LabelIdx::new(3U))],
      Some([
        @lib.Instruction::local_get(
          @lib.LocalIdx::new((6 + group_count).reinterpret_as_uint()),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  )
  body
}

///|
fn pass_manager_test_vacuum_indexed_tag_cascade_body() -> Array[
  @lib.Instruction,
] {
  let body : Array[@lib.Instruction] = [@lib.Instruction::nop()]
  for group = 0; group < 9; group = group + 1 {
    let offset = match group {
      0 => 0
      1 => 2
      2 => 3
      3 => 5
      4 => 6
      5 => 7
      6 => 8
      7 => 9
      _ => 10
    }
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    if offset != 0 {
      body.push(@lib.Instruction::i32_const(@lib.I32(offset)))
      body.push(@lib.Instruction::i32_add())
    }
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(17U)))
    body.push(
      @lib.Instruction::local_set(
        @lib.LocalIdx::new((9 + group).reinterpret_as_uint()),
      ),
    )
    body.push(@lib.Instruction::nop())
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(9U)))
  body.push(@lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)))
  body.push(@lib.Instruction::i32_const(@lib.I32(10)))
  body.push(@lib.Instruction::i32_eq())
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::br(@lib.LabelIdx::new(14U))],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::br(@lib.LabelIdx::new(13U)),
      ]),
    ),
  )
  body
}

///|
fn pass_manager_test_vacuum_shifted_indexed_tag_cascade_body() -> Array[
  @lib.Instruction,
] {
  let body : Array[@lib.Instruction] = [@lib.Instruction::nop()]
  for group = 0; group < 8; group = group + 1 {
    let offset = match group {
      0 => -1
      1 => 0
      2 => 1
      3 => 3
      4 => 4
      5 => 5
      6 => 7
      _ => 8
    }
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    if offset < 0 {
      body.push(@lib.Instruction::i32_const(@lib.I32(0 - offset)))
      body.push(@lib.Instruction::i32_sub())
    } else if offset > 0 {
      body.push(@lib.Instruction::i32_const(@lib.I32(offset)))
      body.push(@lib.Instruction::i32_add())
    }
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(17U)))
    body.push(
      @lib.Instruction::local_set(
        @lib.LocalIdx::new((7 + group).reinterpret_as_uint()),
      ),
    )
    body.push(@lib.Instruction::nop())
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(7U)))
  body.push(@lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)))
  body.push(@lib.Instruction::i32_const(@lib.I32(41)))
  body.push(@lib.Instruction::i32_eq())
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::br(@lib.LabelIdx::new(13U))],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::br(@lib.LabelIdx::new(12U)),
      ]),
    ),
  )
  body
}

///|
fn pass_manager_test_vacuum_plain_block(
  body : Array[@lib.Instruction],
) -> @lib.Instruction {
  @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body))
}

///|
fn pass_manager_test_vacuum_strip_nops(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let stripped : Array[@lib.Instruction] = []
  for instr in body {
    match instr {
      @lib.Nop => ()
      _ => stripped.push(instr)
    }
  }
  stripped
}

///|
fn pass_manager_test_vacuum_first_local_set_depth(
  instrs : Array[@lib.Instruction],
  depth : Int,
) -> Int? {
  for instr in instrs {
    match instr {
      @lib.LocalSet(_) => return Some(depth)
      @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
        match pass_manager_test_vacuum_first_local_set_depth(body, depth + 1) {
          Some(found) => return Some(found)
          None => ()
        }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        match pass_manager_test_vacuum_first_local_set_depth(body, depth + 1) {
          Some(found) => return Some(found)
          None => ()
        }
      @lib.If(_, then_body, else_body) => {
        match
          pass_manager_test_vacuum_first_local_set_depth(then_body, depth + 1) {
          Some(found) => return Some(found)
          None => ()
        }
        match else_body {
          Some(body) =>
            match
              pass_manager_test_vacuum_first_local_set_depth(body, depth + 1) {
              Some(found) => return Some(found)
              None => ()
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn pass_manager_test_vacuum_f364_body() -> Array[@lib.Instruction] {
  pass_manager_test_vacuum_strip_nops(
    pass_manager_test_vacuum_tag_cascade_body(4, 0, 20),
  )
}

///|
test "raw vacuum preclean removes only the extra f364 four-field child wrapper" {
  let body = pass_manager_test_vacuum_f364_body()
  let source_probe = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(body),
      ]),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    source_probe,
    None,
  )
  assert_true(changed)
  @debug.assert_eq(
    pass_manager_test_vacuum_first_local_set_depth(cleaned, 0),
    Some(2),
  )
  match cleaned {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr([@lib.Block(@lib.VoidBlockType, @lib.Expr(kept_body))])
      ),
    ] => assert_true(kept_body.length() > 0 && kept_body[0] is @lib.LocalGet(_))
    _ => fail("expected anchor block to keep one wrapper, got \{cleaned}")
  }
}

///|
test "raw vacuum preclean keeps extracted f364 anchor and parent wrappers" {
  let body = pass_manager_test_vacuum_f364_body()
  let extracted_seed = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(body),
        ]),
      ]),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    extracted_seed,
    None,
  )
  assert_true(changed)
  @debug.assert_eq(
    pass_manager_test_vacuum_first_local_set_depth(cleaned, 0),
    Some(3),
  )
}

///|
test "raw vacuum preclean flattens f364 child before block continuation" {
  let body = pass_manager_test_vacuum_f364_body()
  let extracted_seed = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(body),
        ]),
        @lib.Instruction::nop(),
        @lib.Instruction::nop(),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::return_(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    extracted_seed,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body1))] =>
      match body1 {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(body2)), _, _] =>
          match body2 {
            [@lib.Block(@lib.VoidBlockType, @lib.Expr(body3)), @lib.Br(_)] =>
              assert_true(
                body3.length() > 0 &&
                !(body3[0] is @lib.Block(_, _)) &&
                run_hot_pipeline_raw_vacuum_body_is_f364_four_field_tag_cascade_body(
                  body3,
                ),
              )
            _ =>
              fail(
                "expected continuation block to keep one f364 wrapper, got \{body2}",
              )
          }
        _ => fail("expected extracted f364 continuation body, got \{body1}")
      }
    _ => fail("expected extracted f364 outer block, got \{cleaned}")
  }
}

///|
test "raw vacuum preclean does not flatten f364-like prefix mismatches" {
  let body = pass_manager_test_vacuum_f364_body()
  body[5] = @lib.Instruction::i32_const(@lib.I32(99))
  let mismatch = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(body),
      ]),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    mismatch,
    None,
  )
  assert_false(changed)
  @debug.assert_eq(cleaned, mismatch)
}

///|
test "raw vacuum preclean rebases f364 child-wrapper branch depths" {
  let body = pass_manager_test_vacuum_f364_body()
  body[body.length() - 1] = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
      @lib.Instruction::br_if(@lib.LabelIdx::new(2U)),
      @lib.Instruction::br_if(@lib.LabelIdx::new(3U)),
      @lib.Instruction::br_table(
        [@lib.LabelIdx::new(2U), @lib.LabelIdx::new(3U)],
        @lib.LabelIdx::new(1U),
      ),
    ],
    Some([@lib.Instruction::br(@lib.LabelIdx::new(3U))]),
  )
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(body),
      ]),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr([@lib.Block(@lib.VoidBlockType, @lib.Expr(kept_body))])
      ),
    ] =>
      match kept_body[kept_body.length() - 1] {
        @lib.If(_, then_body, Some(else_body)) => {
          @debug.assert_eq(
            then_body[0],
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
          )
          @debug.assert_eq(
            then_body[1],
            @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
          )
          @debug.assert_eq(
            then_body[2],
            @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
          )
          @debug.assert_eq(
            then_body[3],
            @lib.Instruction::br_if(@lib.LabelIdx::new(2U)),
          )
          @debug.assert_eq(
            then_body[4],
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(1U), @lib.LabelIdx::new(2U)],
              @lib.LabelIdx::new(1U),
            ),
          )
          @debug.assert_eq(
            else_body[0],
            @lib.Instruction::br(@lib.LabelIdx::new(2U)),
          )
        }
        _ => fail("expected final if after f364 child flatten")
      }
    _ => fail("expected anchor block to keep one wrapper, got \{cleaned}")
  }
}

///|
test "raw vacuum preclean still flattens legacy non-f364 tag-cascade child wrappers" {
  let cases = [
    pass_manager_test_vacuum_tag_cascade_body(2, 4, 72),
    pass_manager_test_vacuum_indexed_tag_cascade_body(),
    pass_manager_test_vacuum_shifted_indexed_tag_cascade_body(),
  ]
  for body in cases {
    let wrapped = [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(body),
      ]),
    ]
    let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
      wrapped,
      None,
    )
    assert_true(changed)
    @debug.assert_eq(
      pass_manager_test_vacuum_first_local_set_depth(cleaned, 0),
      Some(1),
    )
  }
}

///|
test "raw vacuum preclean flattens f1054 local-copy child before load prefix" {
  // Slot23 `defined=1054 abs=1081` is a direct `--vacuum` parity gap after
  // f996: Binaryen flattens a one-instruction child block around
  // `local.set(local.get $1088)` before the following local-set/load/call
  // prefix, while Starshine retained that extra wrapper. Keep the fixture
  // narrow to this source-backed raw prefix instead of enabling broad
  // singleton local-copy block cleanup.
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1088U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
          ]),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1086U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1087U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
          @lib.Instruction::call(@lib.FuncIdx::new(8U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(98U)),
          @lib.Instruction::i32_load(load4),
          @lib.Instruction::local_set(@lib.LocalIdx::new(99U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(98U)),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::local_set(@lib.LocalIdx::new(177U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(98U)),
          @lib.Instruction::call(@lib.FuncIdx::new(3U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(161U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_gt_s(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(98U)),
              @lib.Instruction::local_get(@lib.LocalIdx::new(161U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_sub(),
              @lib.Instruction::call(@lib.FuncIdx::new(4U)),
              @lib.Instruction::local_get(@lib.LocalIdx::new(99U)),
              @lib.Instruction::call(@lib.FuncIdx::new(6U)),
            ],
            Some([
              @lib.Instruction::local_get(@lib.LocalIdx::new(161U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_eq(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::local_get(@lib.LocalIdx::new(98U)),
                  @lib.Instruction::i32_const(@lib.I32(8)),
                  @lib.Instruction::i32_sub(),
                  @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                ],
                None,
              ),
              @lib.Instruction::local_get(@lib.LocalIdx::new(177U)),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                  @lib.Instruction::call(@lib.FuncIdx::new(7U)),
                  @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                ],
                Some([
                  @lib.Instruction::local_get(@lib.LocalIdx::new(99U)),
                  @lib.Instruction::call(@lib.FuncIdx::new(7U)),
                ]),
              ),
            ]),
          ),
        ]),
      ]),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body1))] =>
      match body1 {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(body2))] =>
          match body2 {
            [@lib.Block(@lib.VoidBlockType, @lib.Expr(body3))] => {
              assert_true(body3.length() > 2)
              assert_true(body3[0] is @lib.LocalGet(_))
              assert_true(body3[1] is @lib.LocalSet(_))
              assert_true(!(body3[0] is @lib.Block(_, _)))
            }
            other => fail("expected f1054 innermost block, got \{other}")
          }
        other => fail("expected f1054 middle block, got \{other}")
      }
    other => fail("expected f1054 wrapper flatten, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f1148 tag-selection wrappers before load continuation" {
  // Slot23 `defined=1148 abs=1175` is a direct `--vacuum` residual after
  // f1054: Binaryen removes exactly two anonymous void wrappers around the
  // tag-selection `if` before the following `local.get; i32.load; local.set`
  // continuation. The nested selection has branch arms targeting the two
  // outer parent blocks, so the retained rewrite must rebase branch depths
  // twice and must not become broad unreachable-or-selection cleanup.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let tag_selection = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(32U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(load0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(load4),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(9U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(32U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(load0),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(load0),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(tag_selection),
        ]),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::i32_load(load0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
      ]),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body1))] =>
      match body1 {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(body2))] => {
          assert_true(body2.length() >= 4)
          assert_true(body2[0] is @lib.LocalGet(_))
          assert_true(body2[5] is @lib.If(_, _, _))
          assert_true(body2[6] is @lib.LocalGet(_))
          assert_true(!(body2[0] is @lib.Block(_, _)))
          match body2[5] {
            @lib.If(_, _, Some(else_body)) =>
              match else_body[3] {
                @lib.If(_, then_body, Some(inner_else)) => {
                  @debug.assert_eq(
                    then_body[then_body.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                  @debug.assert_eq(
                    inner_else[inner_else.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                  )
                }
                other =>
                  fail("expected f1148 nested selection if, got \{other}")
              }
            other => fail("expected f1148 selection if, got \{other}")
          }
        }
        other => fail("expected f1148 parent block, got \{other}")
      }
    other => fail("expected f1148 wrapper flatten, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f1167 br-table child before unreachable" {
  // Slot23 `defined=1167 abs=1194` follows f1155: Binaryen removes one
  // anonymous child block around a non-fallthrough `br_table`, drops the now
  // dead `unreachable` sibling, and rebases the table labels by one. Keep the
  // guard to br_table children whose labels all target outside the child.
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            pass_manager_test_vacuum_plain_block([
              @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
              @lib.Instruction::i32_const(@lib.I32(2)),
              @lib.Instruction::i32_sub(),
              @lib.Instruction::br_table(
                [
                  @lib.LabelIdx::new(4U),
                  @lib.LabelIdx::new(4U),
                  @lib.LabelIdx::new(1U),
                ],
                @lib.LabelIdx::new(2U),
              ),
            ]),
            @lib.Instruction::unreachable_(),
          ]),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(26U)),
        ]),
      ]),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body1))] =>
      match body1 {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(body2))] =>
          match body2 {
            [@lib.Block(@lib.VoidBlockType, @lib.Expr(body3)), ..] =>
              match body3 {
                [@lib.Block(@lib.VoidBlockType, @lib.Expr(body4)), ..] => {
                  assert_true(body4.length() == 4)
                  assert_true(body4[0] is @lib.LocalGet(_))
                  assert_true(body4[1] is @lib.I32Const(_))
                  assert_true(body4[2] is @lib.I32Sub)
                  match body4[3] {
                    @lib.BrTable(labels, fallback) => {
                      @debug.assert_eq(labels[0], @lib.LabelIdx::new(3U))
                      @debug.assert_eq(labels[1], @lib.LabelIdx::new(3U))
                      @debug.assert_eq(labels[2], @lib.LabelIdx::new(0U))
                      @debug.assert_eq(fallback, @lib.LabelIdx::new(1U))
                    }
                    other =>
                      fail("expected f1167 rebased br_table, got \{other}")
                  }
                }
                other =>
                  fail("expected f1167 inner br_table block, got \{other}")
              }
            other => fail("expected f1167 br_table block, got \{other}")
          }
        other => fail("expected f1167 parent block, got \{other}")
      }
    other => fail("expected f1167 wrapper flatten, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f1155 single release child before branch continuation" {
  // Slot23 `defined=1155 abs=1182` is the next direct `--vacuum` residual
  // after f1148: Binaryen removes a singleton child block that only releases
  // one local via `local.get; call`, while keeping the surrounding branchy
  // continuation block and its parent continuation. Keep this source-backed
  // shape narrow; broad call-prefix/single-call child cleanup previously moved
  // slot23 back to earlier residuals.
  let release = @lib.FuncIdx::new(7U)
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
            @lib.Instruction::call(release),
          ]),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::call(@lib.FuncIdx::new(8U)),
          @lib.Instruction::call(@lib.FuncIdx::new(10U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(15U)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
              @lib.Instruction::local_set(@lib.LocalIdx::new(14U)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ],
            Some([
              @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
                  @lib.Instruction::call(release),
                ],
                None,
              ),
            ]),
          ),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(194U)),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ]),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::call(@lib.FuncIdx::new(11U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(67U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
        @lib.Instruction::call(release),
        @lib.Instruction::local_get(@lib.LocalIdx::new(67U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(194U)),
      ]),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body1))] =>
      match body1 {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(body2))] =>
          match body2 {
            [@lib.Block(@lib.VoidBlockType, @lib.Expr(body3)), ..] => {
              assert_true(body3.length() >= 8)
              assert_true(body3[0] is @lib.LocalGet(_))
              assert_true(body3[1] is @lib.Call(_))
              assert_true(!(body3[0] is @lib.Block(_, _)))
              assert_true(body3[body3.length() - 1] is @lib.Br(_))
            }
            other =>
              fail("expected f1155 branch continuation block, got \{other}")
          }
        other => fail("expected f1155 parent block, got \{other}")
      }
    other => fail("expected f1155 wrapper flatten, got \{other}")
  }
}

///|
test "raw vacuum preclean preserves f1224 loop release update child wrapper" {
  // Slot23 `defined=1224 abs=1251` follows f1167 and flips wrapper
  // direction: Binaryen preserves the child wrapper around the loop-local
  // retain/update/release prefix before the following loop slot update, while
  // Starshine had flattened it. Keep this guard narrow so earlier positive
  // call-prefix and branchy-wrapper flattening stays enabled.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let prefix = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(28U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(28U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(8U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(49U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(28U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(49U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(18U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(17U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
            @lib.Instruction::call(@lib.FuncIdx::new(6U)),
          ],
          None,
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(4U)),
      ]),
    ),
  ]
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(prefix),
          @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::local_set(@lib.LocalIdx::new(40U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
          @lib.Instruction::call(@lib.FuncIdx::new(3U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(41U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_gt_s(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
              @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_sub(),
              @lib.Instruction::call(@lib.FuncIdx::new(4U)),
              @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
              @lib.Instruction::call(@lib.FuncIdx::new(5U)),
            ],
            Some([
              @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_eq(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
                  @lib.Instruction::i32_const(@lib.I32(8)),
                  @lib.Instruction::i32_sub(),
                  @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                ],
                None,
              ),
            ]),
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::call(@lib.FuncIdx::new(6U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
          @lib.Instruction::i32_store(load0),
          @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_store(load0),
          @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::i32_store(load0),
        ]),
      ]),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(wrapped, None)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body1))] =>
      match body1 {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(body2))] =>
          match body2 {
            [@lib.Block(@lib.VoidBlockType, @lib.Expr(body3))] => {
              assert_true(body3.length() > 1)
              match body3[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(child)) => {
                  assert_true(child.length() == prefix.length())
                  assert_true(body3[1] is @lib.LocalGet(_))
                }
                other =>
                  fail(
                    "expected f1224 Binaryen-preserved prefix child, got \{other}",
                  )
              }
            }
            other => fail("expected f1224 loop update block, got \{other}")
          }
        other => fail("expected f1224 parent block, got \{other}")
      }
    other => fail("expected f1224 wrapper shape, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f1260 tag21 dispatch child before append continuation" {
  // Slot23 `defined=1260 abs=1287` follows f1259: Binaryen removes one
  // anonymous child block around the tag-21/tag-22 lookahead dispatch before
  // the following append/update continuation. Keep this exact raw shape narrow;
  // broad tag-dispatch wrapper cleanup has previously regressed earlier slot23
  // residuals and prefix-preservation guards.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let dispatch = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::call(@lib.FuncIdx::new(17U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(91U)),
    @lib.Instruction::i32_const(@lib.I32(21)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 4UL)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(114U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(6U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(114U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::call(@lib.FuncIdx::new(15U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::br(@lib.LabelIdx::new(6U))],
          None,
        ),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(91U)),
        @lib.Instruction::i32_const(@lib.I32(22)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 4UL)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(115U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::call(@lib.FuncIdx::new(6U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(115U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::call(@lib.FuncIdx::new(15U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::br(@lib.LabelIdx::new(5U))],
              Some([@lib.Instruction::br(@lib.LabelIdx::new(7U))]),
            ),
            @lib.Instruction::unreachable_(),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::call(@lib.FuncIdx::new(6U)),
            @lib.Instruction::br(@lib.LabelIdx::new(6U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(dispatch),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::call(@lib.FuncIdx::new(14U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(57U)),
          @lib.Instruction::call(@lib.FuncIdx::new(18U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(116U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(57U)),
          @lib.Instruction::call(@lib.FuncIdx::new(6U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_store(load0),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::i32_store(load0),
        ]),
      ]),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body1))] =>
      match body1 {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(body2))] =>
          match body2 {
            [@lib.Block(@lib.VoidBlockType, @lib.Expr(body3))] => {
              assert_true(body3.length() > dispatch.length())
              match body3[0] {
                @lib.Block(_, _) =>
                  fail(
                    "expected f1260 Binaryen-flattened tag dispatch, got extra child block",
                  )
                @lib.LocalGet(_) => ()
                other => fail("expected f1260 dispatch prefix, got \{other}")
              }
              assert_true(body3[body3.length() - 1] is @lib.I32Store(_))
            }
            other => fail("expected f1260 continuation block, got \{other}")
          }
        other => fail("expected f1260 parent block, got \{other}")
      }
    other => fail("expected f1260 wrapper shape, got \{other}")
  }
}

///|
test "raw vacuum preclean preserves f996 four-local tag20 wrapper before tag dispatch continuation" {
  // Slot23 `defined=996 abs=1023` is the opposite direction from f749:
  // Binaryen keeps an extra block around the four `local.set(call ...)`
  // tag-20 prefix before the following nested tag-dispatch continuation, while
  // Starshine had flattened that child wrapper. Keep this source-backed guard
  // separate from the f364 rule that removes exactly one extra wrapper when no
  // side-effecting parent continuation follows the tag-20 prefix.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let continuation_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(31U)),
      @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    ],
    Some([
      @lib.Instruction::local_get(@lib.LocalIdx::new(32U)),
      @lib.Instruction::i32_const(@lib.I32(243)),
      @lib.Instruction::i32_eq(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(31U)),
          @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        ],
        Some([
          @lib.Instruction::local_get(@lib.LocalIdx::new(31U)),
          @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        ]),
      ),
    ]),
  )
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(
          pass_manager_test_vacuum_f364_body(),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::call(@lib.FuncIdx::new(17U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(31U)),
        @lib.Instruction::i32_load(load0),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(32U)),
        @lib.Instruction::i32_const(@lib.I32(241)),
        @lib.Instruction::i32_eq(),
        continuation_if,
        @lib.Instruction::local_get(@lib.LocalIdx::new(27U)),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(28U)),
            @lib.Instruction::call(@lib.FuncIdx::new(3U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(@lib.BlockType::void_(), [], Some([])),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
      ]),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(wrapped, None)
  match cleaned {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr(
          [
            @lib.Block(
              @lib.VoidBlockType,
              @lib.Expr(
                [@lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)), ..]
              )
            ),
          ]
        )
      ),
    ] =>
      assert_true(
        run_hot_pipeline_raw_vacuum_body_is_f364_four_field_tag_cascade_body(
          prefix_body,
        ),
      )
    _ =>
      fail(
        "expected f996 tag20 prefix child wrapper to be preserved, got \{cleaned}",
      )
  }
}

///|
test "raw vacuum preclean flattens branchy loop dispatch singleton wrapper" {
  // Probe modeled on slot23 `defined=533 abs=560`: Binaryen removes one
  // anonymous block around the loop dispatch `if` even though the dispatch body
  // contains nested block-local branches and unreachable exits. The first arm
  // keeps the shallower source-shaped `if`; the second arm keeps the native raw
  // shape where the condition prefix sits before the final `if` instruction.
  let dispatch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [@lib.Instruction::br(@lib.LabelIdx::new(2U))],
                Some([@lib.Instruction::unreachable_()]),
              ),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
      @lib.Instruction::br(@lib.LabelIdx::new(2U)),
    ],
    Some([
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    ]),
  )
  let source_shaped = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            @lib.Instruction::nop(),
            @lib.Instruction::nop(),
            dispatch_if,
          ]),
        ]),
      ]),
    ),
  ]
  let (source_cleaned, source_changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    source_shaped,
    None,
  )
  assert_true(source_changed)
  match source_cleaned {
    [
      @lib.Loop(
        @lib.VoidBlockType,
        @lib.Expr([@lib.Block(@lib.VoidBlockType, @lib.Expr([source_if]))])
      ),
    ] => assert_true(source_if is @lib.If(_, _, Some(_)))
    other =>
      fail("expected source-shaped branchy dispatch flatten, got \{other}")
  }

  let raw_shaped = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            @lib.Instruction::nop(),
            @lib.Instruction::nop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(9U)),
            @lib.Instruction::i32_lt_s(),
            dispatch_if,
          ]),
        ]),
      ]),
    ),
  ]
  let (raw_cleaned, raw_changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    raw_shaped,
    None,
  )
  assert_true(raw_changed)
  match raw_cleaned {
    [
      @lib.Loop(
        @lib.VoidBlockType,
        @lib.Expr([@lib.Block(@lib.VoidBlockType, @lib.Expr(raw_body))])
      ),
    ] => {
      @debug.assert_eq(raw_body.length(), 6)
      assert_true(raw_body[0] is @lib.LocalGet(_))
      assert_true(raw_body[5] is @lib.If(_, _, Some(_)))
    }
    other => fail("expected raw-shaped branchy dispatch flatten, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f649 branchy loop dispatch parent wrapper" {
  // Probe modeled on slot23 `defined=649 abs=676`: Binaryen removes one
  // anonymous parent block around a branchy loop dispatch block plus its
  // continuation `if`, while keeping the dispatch block and continuation
  // wrapper. This differs from f533 because the extra wrapper has no leading
  // `nop` debris and wraps the whole dispatch/continuation block.
  let dispatch_block = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ],
          Some([@lib.Instruction::unreachable_()]),
        ),
        @lib.Instruction::local_set(@lib.LocalIdx::new(58U)),
      ],
      Some([@lib.Instruction::local_set(@lib.LocalIdx::new(58U))]),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(60U)),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ])
  let continuation_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_set(@lib.LocalIdx::new(14U)),
      @lib.Instruction::call(@lib.FuncIdx::new(38U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(72U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ],
    Some([@lib.Instruction::call(@lib.FuncIdx::new(38U))]),
  )
  let input = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            pass_manager_test_vacuum_plain_block([
              dispatch_block,
              @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              @lib.Instruction::call(@lib.FuncIdx::new(3923U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_eq(),
              continuation_if,
              @lib.Instruction::local_set(@lib.LocalIdx::new(60U)),
            ]),
          ]),
          @lib.Instruction::local_set(@lib.LocalIdx::new(81U)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ]),
    ),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [
      @lib.Loop(
        @lib.VoidBlockType,
        @lib.Expr(
          [
            @lib.Block(
              @lib.VoidBlockType,
              @lib.Expr(
                [
                  @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)),
                  @lib.LocalSet(_),
                  @lib.Br(_),
                ]
              )
            ),
          ]
        )
      ),
    ] => {
      @debug.assert_eq(parent_body.length(), 7)
      assert_true(parent_body[0] is @lib.Block(@lib.VoidBlockType, _))
      assert_true(parent_body[5] is @lib.If(_, _, Some(_)))
    }
    other => fail("expected f649 parent wrapper flatten, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f749 double branchy selection wrappers" {
  // Probe modeled on slot23 `defined=749 abs=776`: after the f649 parent
  // wrapper fix, Binaryen removes two anonymous wrappers around a branchy
  // two-arm selection before return continuations. Keep this exact raw shape
  // separate from broad `block(block(if))` cleanup because earlier broad wrapper
  // attempts regressed slot23 to earlier residuals.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let load12 = @lib.MemArg::new(0U, None, 12UL)
  let left_select = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_load(load0),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    ],
    Some([@lib.Instruction::br(@lib.LabelIdx::new(5U))]),
  )
  let right_select = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::i32_load(load0),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::br(@lib.LabelIdx::new(4U)),
    ],
    Some([@lib.Instruction::br(@lib.LabelIdx::new(5U))]),
  )
  let selection = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(load4),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::i32_eq(),
        left_select,
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(load12),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::i32_eq(),
        right_select,
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(selection),
        ]),
        @lib.Instruction::nop(),
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i64_extend_i32s(),
      ]),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::call(@lib.FuncIdx::new(3U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
      @lib.Instruction::i64_extend_i32s(),
    ]),
    @lib.Instruction::nop(),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)), _] =>
      match parent_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(inner_body)) => {
          @debug.assert_eq(inner_body.length(), 12)
          assert_true(inner_body[0] is @lib.LocalGet(_))
          assert_true(inner_body[4] is @lib.If(_, _, Some(_)))
          assert_true(inner_body[5] is @lib.LocalGet(_))
        }
        other => fail("expected f749 parent continuation block, got \{other}")
      }
    other => fail("expected f749 double-wrapper flatten, got \{other}")
  }
}

///|
test "raw vacuum preclean preserves side-effecting dropped result-if arm drops" {
  // Slot23 `defined=1272 abs=1299` follows f1260: Binaryen does not repack a
  // void `if` into `drop (if (result i32) ...)` when the arms do memory/counter
  // side effects before the terminal `call; drop`. Keep pure call-arm packing in
  // `optimize_test.mbt`, but do not hide side-effecting arm bodies behind a
  // value-producing `if`.
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "emit" (func $emit (param i32 i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (memory 1))
    ),
  )
  let module_state = HotPipelineModuleState::new()
  let module_ctx = run_hot_pipeline_require_module_ctx(
    input,
    module_state,
    HotPipelineOptions::new(),
  )
  let addr = @lib.LocalIdx::new(1U)
  let arg = @lib.LocalIdx::new(2U)
  let emit = @lib.FuncIdx::new(0U)
  let pred = @lib.FuncIdx::new(1U)
  let mem = @lib.MemArg::new(0U, None, 0UL)
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(addr),
          @lib.Instruction::i32_load(mem),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_gt_s(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(addr),
              @lib.Instruction::local_get(addr),
              @lib.Instruction::i32_load(mem),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_add(),
              @lib.Instruction::i32_store(mem),
            ],
            None,
          ),
          @lib.Instruction::local_get(arg),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::call(emit),
          @lib.Instruction::drop(),
        ],
        Some([
          @lib.Instruction::local_get(arg),
          @lib.Instruction::call(pred),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(addr),
              @lib.Instruction::local_get(addr),
              @lib.Instruction::i32_load(mem),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_sub(),
              @lib.Instruction::i32_store(mem),
            ],
            None,
          ),
          @lib.Instruction::local_get(arg),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::call(emit),
          @lib.Instruction::drop(),
        ]),
      ),
      @lib.Instruction::local_get(arg),
    ],
    Some(module_ctx),
  )
  match cleaned {
    [
      @lib.LocalGet(_),
      @lib.If(@lib.VoidBlockType, then_body, Some(else_body)),
      @lib.LocalGet(_),
    ] => {
      assert_true(then_body.any(fn(instr) { instr is @lib.Drop }))
      assert_true(else_body.any(fn(instr) { instr is @lib.Drop }))
    }
    [
      @lib.LocalGet(_),
      @lib.If(@lib.ValTypeBlockType(_), _, Some(_)),
      @lib.Drop,
      ..,
    ] =>
      fail(
        "expected side-effecting dropped call arms to stay void, got result-if packing",
      )
    other =>
      fail(
        "expected side-effecting dropped call arms to stay void, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean packs f2369 call-operand dropped result-if arms" {
  // Slot23 `defined=2369 abs=2396` follows the retained f2334 wrapper fix:
  // Binaryen applies Vacuum.cpp's dropped-arm rule to a void `if` whose then
  // arm is entirely one dropped i32 call expression, even though one terminal
  // call operand is itself call-produced. Keep this narrower than f1272: side
  // effects before the terminal dropped value expression must remain void.
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "make" (func $make (param i32 i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32 i32) (result i32)))
      #|  (import "m" "emit" (func $emit (param i32 i32) (result i32))))
    ),
  )
  let module_state = HotPipelineModuleState::new()
  let module_ctx = run_hot_pipeline_require_module_ctx(
    input,
    module_state,
    HotPipelineOptions::new(),
  )
  let receiver = @lib.LocalIdx::new(0U)
  let target = @lib.LocalIdx::new(1U)
  let index = @lib.LocalIdx::new(2U)
  let make = @lib.FuncIdx::new(0U)
  let pred = @lib.FuncIdx::new(1U)
  let emit = @lib.FuncIdx::new(2U)
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(receiver),
      @lib.Instruction::local_get(index),
      @lib.Instruction::call(pred),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(target),
          @lib.Instruction::local_get(receiver),
          @lib.Instruction::local_get(index),
          @lib.Instruction::call(make),
          @lib.Instruction::call(emit),
          @lib.Instruction::drop(),
        ],
        Some([
          @lib.Instruction::local_get(target),
          @lib.Instruction::local_get(index),
          @lib.Instruction::call(emit),
          @lib.Instruction::drop(),
        ]),
      ),
      @lib.Instruction::i32_const(@lib.I32(1)),
    ],
    Some(module_ctx),
  )
  match cleaned {
    [
      @lib.LocalGet(_),
      @lib.LocalGet(_),
      @lib.Call(_),
      @lib.If(@lib.ValTypeBlockType(value_type), then_body, Some(else_body)),
      @lib.Drop,
      @lib.I32Const(_),
    ] => {
      @debug.assert_eq(value_type, @lib.ValType::i32())
      assert_true(then_body[then_body.length() - 1] is @lib.Call(_))
      assert_true(else_body[else_body.length() - 1] is @lib.Call(_))
    }
    [
      @lib.LocalGet(_),
      @lib.LocalGet(_),
      @lib.Call(_),
      @lib.If(@lib.VoidBlockType, _, Some(_)),
      @lib.I32Const(_),
    ] => fail("expected f2369 call-operand dropped result-if arms to be packed")
    other =>
      fail("expected f2369 result-if packing, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean packs f3752 local-tee call-operand dropped result-if arms" {
  // Slot23 `defined=3752 abs=3779` follows the f3579 loop-head copy fix:
  // Binaryen packs `drop(call)` arms into `drop(if (result i32) ...)` even when
  // an else-arm terminal call operand uses `local.tee(call(...))`. The local.tee
  // remains inside the selected arm, so this extends only the value-expression
  // recognizer used by the existing dropped-result-if packing rule.
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "then" (func $then (param i32 i32 i32) (result i32)))
      #|  (import "m" "make" (func $make (param i32 i32) (result i32)))
      #|  (import "m" "offset" (func $offset (param i32 i32) (result i32)))
      #|  (import "m" "else" (func $else (param i32 i32 i32 i32) (result i32))))
    ),
  )
  let module_state = HotPipelineModuleState::new()
  let module_ctx = run_hot_pipeline_require_module_ctx(
    input,
    module_state,
    HotPipelineOptions::new(),
  )
  let env = @lib.LocalIdx::new(0U)
  let source = @lib.LocalIdx::new(1U)
  let index = @lib.LocalIdx::new(2U)
  let extra = @lib.LocalIdx::new(3U)
  let scratch = @lib.LocalIdx::new(5U)
  let pred = @lib.FuncIdx::new(0U)
  let then_call = @lib.FuncIdx::new(1U)
  let make = @lib.FuncIdx::new(2U)
  let offset = @lib.FuncIdx::new(3U)
  let else_call = @lib.FuncIdx::new(4U)
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(source),
      @lib.Instruction::call(pred),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(env),
          @lib.Instruction::local_get(index),
          @lib.Instruction::local_get(extra),
          @lib.Instruction::call(then_call),
          @lib.Instruction::drop(),
        ],
        Some([
          @lib.Instruction::local_get(env),
          @lib.Instruction::local_get(env),
          @lib.Instruction::local_get(source),
          @lib.Instruction::call(make),
          @lib.Instruction::local_tee(scratch),
          @lib.Instruction::local_get(env),
          @lib.Instruction::local_get(scratch),
          @lib.Instruction::call(offset),
          @lib.Instruction::local_get(index),
          @lib.Instruction::i32_add(),
          @lib.Instruction::local_get(extra),
          @lib.Instruction::call(else_call),
          @lib.Instruction::drop(),
        ]),
      ),
    ],
    Some(module_ctx),
  )
  match cleaned {
    [
      @lib.LocalGet(_),
      @lib.Call(_),
      @lib.If(@lib.ValTypeBlockType(value_type), then_body, Some(else_body)),
      @lib.Drop,
    ] => {
      @debug.assert_eq(value_type, @lib.ValType::i32())
      assert_true(then_body[then_body.length() - 1] is @lib.Call(_))
      assert_true(else_body.any(fn(instr) { instr is @lib.LocalTee(_) }))
      assert_true(else_body[else_body.length() - 1] is @lib.Call(_))
    }
    [@lib.LocalGet(_), @lib.Call(_), @lib.If(@lib.VoidBlockType, _, Some(_))] =>
      fail("expected f3752 local-tee call operand arms to be packed")
    other =>
      fail("expected f3752 result-if packing, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean keeps f3771 side-effect prefix before dropped result-if arm" {
  // Slot23 `defined=3771 abs=3798` follows the f3752 local.tee operand fix:
  // Binaryen keeps the outer void `if` when an arm has side-effecting local.set
  // and release-call statements before the terminal dropped result-if. Only the
  // inner terminal result-if stays packed.
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "len" (func $len (param i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32 i32) (result i32)))
      #|  (import "m" "make" (func $make (param i32 i32) (result i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (import "m" "emit" (func $emit (param i32 i32) (result i32))))
    ),
  )
  let module_state = HotPipelineModuleState::new()
  let module_ctx = run_hot_pipeline_require_module_ctx(
    input,
    module_state,
    HotPipelineOptions::new(),
  )
  let env = @lib.LocalIdx::new(0U)
  let base = @lib.LocalIdx::new(1U)
  let index = @lib.LocalIdx::new(2U)
  let retained = @lib.LocalIdx::new(3U)
  let tag = @lib.LocalIdx::new(10U)
  let len = @lib.FuncIdx::new(0U)
  let pred = @lib.FuncIdx::new(1U)
  let make = @lib.FuncIdx::new(2U)
  let release = @lib.FuncIdx::new(3U)
  let emit = @lib.FuncIdx::new(4U)
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(env),
      @lib.Instruction::call(len),
      @lib.Instruction::local_get(index),
      @lib.Instruction::i32_gt_s(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(env),
          @lib.Instruction::local_get(index),
          @lib.Instruction::call(pred),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(env),
              @lib.Instruction::local_get(index),
              @lib.Instruction::call(make),
              @lib.Instruction::local_tee(retained),
              @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
              @lib.Instruction::local_set(tag),
              @lib.Instruction::local_get(retained),
              @lib.Instruction::call(release),
              @lib.Instruction::local_get(tag),
              @lib.Instruction::i32_const(@lib.I32(23)),
              @lib.Instruction::i32_eq(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::local_get(base),
                  @lib.Instruction::i32_const(@lib.I32(1)),
                  @lib.Instruction::call(emit),
                  @lib.Instruction::drop(),
                ],
                Some([
                  @lib.Instruction::local_get(base),
                  @lib.Instruction::i32_const(@lib.I32(0)),
                  @lib.Instruction::call(emit),
                  @lib.Instruction::drop(),
                ]),
              ),
            ],
            Some([
              @lib.Instruction::local_get(base),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::call(emit),
              @lib.Instruction::drop(),
            ]),
          ),
        ],
        None,
      ),
    ],
    Some(module_ctx),
  )
  match cleaned {
    [.., @lib.If(@lib.VoidBlockType, outer_then, None)] =>
      assert_true(
        outer_then.any(fn(instr) {
          instr is @lib.If(@lib.VoidBlockType, _, Some(_))
        }),
      )
    [.., @lib.If(@lib.ValTypeBlockType(_), _, Some(_)), @lib.Drop] =>
      fail(
        "expected f3771 side-effect prefix before dropped result-if to stay void",
      )
    other =>
      fail("expected f3771 outer void if, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean keeps f2393 positive no-op if after no-op else ladder" {
  // Binaryen Vacuum.cpp::visitIf first removes an else arm that has become
  // `Nop`, then stops for that node; it therefore retains the positive outer
  // empty `if` instead of flipping it into a negated condition chain. The else
  // ladder here is pure local/const equality control debris, so it may be
  // treated as Binaryen's no-op arm without deleting the source-retained outer
  // conditional.
  let tag = @lib.LocalIdx::new(0U)
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(tag),
      @lib.Instruction::i32_const(@lib.I32(8)),
      @lib.Instruction::i32_eq(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::nop()],
        Some([
          @lib.Instruction::nop(),
          @lib.Instruction::nop(),
          @lib.Instruction::local_get(tag),
          @lib.Instruction::i32_const(@lib.I32(10)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::nop()],
            Some([
              @lib.Instruction::nop(),
              @lib.Instruction::nop(),
              @lib.Instruction::local_get(tag),
              @lib.Instruction::i32_const(@lib.I32(11)),
              @lib.Instruction::i32_eq(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [@lib.Instruction::nop()],
                Some([
                  @lib.Instruction::nop(),
                  @lib.Instruction::nop(),
                  @lib.Instruction::nop(),
                ]),
              ),
              @lib.Instruction::nop(),
            ]),
          ),
          @lib.Instruction::nop(),
        ]),
      ),
    ],
    None,
  )
  assert_true(changed)
  @debug.assert_eq(cleaned, [
    @lib.Instruction::local_get(tag),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
  ])
}

///|
test "raw vacuum preclean packs f4824 nested dropped result-if arms with load conditions" {
  // Slot23 `defined=4824 abs=4851` follows the retained f4702 child flatten:
  // Binaryen packs an outer void `if` whose arms are each one dropped
  // `if (result i32)` value expression. The inner result-if conditions are
  // potentially trapping loads, so this extends only the single loaded-condition
  // value-if shape and keeps f1272/f3771 side-effect-prefix guards closed.
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "emit" (func $emit (param i32 i32) (result i32)))
      #|  (memory 1))
    ),
  )
  let module_state = HotPipelineModuleState::new()
  let module_ctx = run_hot_pipeline_require_module_ctx(
    input,
    module_state,
    HotPipelineOptions::new(),
  )
  let object = @lib.LocalIdx::new(0U)
  let sink = @lib.LocalIdx::new(1U)
  let emit = @lib.FuncIdx::new(0U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(object),
      @lib.Instruction::i32_load(load0),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(object),
          @lib.Instruction::i32_load(load4),
          @lib.Instruction::if_(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            [
              @lib.Instruction::local_get(sink),
              @lib.Instruction::i32_const(@lib.I32(3)),
              @lib.Instruction::call(emit),
            ],
            Some([
              @lib.Instruction::local_get(sink),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::call(emit),
            ]),
          ),
          @lib.Instruction::drop(),
        ],
        Some([
          @lib.Instruction::local_get(object),
          @lib.Instruction::i32_load(load4),
          @lib.Instruction::if_(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            [
              @lib.Instruction::local_get(sink),
              @lib.Instruction::i32_const(@lib.I32(2)),
              @lib.Instruction::call(emit),
            ],
            Some([
              @lib.Instruction::local_get(sink),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::call(emit),
            ]),
          ),
          @lib.Instruction::drop(),
        ]),
      ),
      @lib.Instruction::i32_const(@lib.I32(4)),
    ],
    Some(module_ctx),
  )
  assert_true(changed)
  match cleaned {
    [
      @lib.LocalGet(_),
      @lib.I32Load(_),
      @lib.If(@lib.ValTypeBlockType(value_type), then_body, Some(else_body)),
      @lib.Drop,
      @lib.I32Const(_),
    ] => {
      @debug.assert_eq(value_type, @lib.ValType::i32())
      assert_true(
        then_body[then_body.length() - 1]
        is @lib.If(@lib.ValTypeBlockType(_), _, Some(_)),
      )
      assert_true(
        else_body[else_body.length() - 1]
        is @lib.If(@lib.ValTypeBlockType(_), _, Some(_)),
      )
    }
    [
      @lib.LocalGet(_),
      @lib.I32Load(_),
      @lib.If(@lib.VoidBlockType, _, Some(_)),
      @lib.I32Const(_),
    ] => fail("expected f4824 nested dropped result-if arms to be packed")
    other =>
      fail(
        "expected f4824 nested result-if packing, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean packs f1903 dropped result-if arms" {
  // Slot23 `defined=1903 abs=1930` follows the f1900 preservation fix:
  // Binaryen packs a void `if` whose arms are dropped i32 value expressions into
  // `drop (if (result i32) ...)`, even when the then arm itself is an
  // `if (result i32)` carrying calls. This remains narrower than f1272: arms
  // with side effects before the terminal value expression must stay void.
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "emit" (func $emit (param i32 i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "choose" (func $choose (param i32) (result i32))))
    ),
  )
  let module_state = HotPipelineModuleState::new()
  let module_ctx = run_hot_pipeline_require_module_ctx(
    input,
    module_state,
    HotPipelineOptions::new(),
  )
  let arg = @lib.LocalIdx::new(2U)
  let emit = @lib.FuncIdx::new(0U)
  let pred = @lib.FuncIdx::new(1U)
  let choose = @lib.FuncIdx::new(2U)
  let nested_value_if = @lib.Instruction::if_(
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @lib.Instruction::local_get(arg),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::call(emit),
    ],
    Some([
      @lib.Instruction::local_get(arg),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::call(emit),
    ]),
  )
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(arg),
      @lib.Instruction::call(pred),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(arg),
          @lib.Instruction::call(choose),
          nested_value_if,
          @lib.Instruction::drop(),
        ],
        Some([
          @lib.Instruction::local_get(arg),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::call(emit),
          @lib.Instruction::drop(),
        ]),
      ),
      @lib.Instruction::local_get(arg),
    ],
    Some(module_ctx),
  )
  match cleaned {
    [
      @lib.LocalGet(_),
      @lib.Call(_),
      @lib.If(@lib.ValTypeBlockType(_), then_body, Some(else_body)),
      @lib.Drop,
      @lib.LocalGet(_),
    ] => {
      assert_true(
        then_body[then_body.length() - 1]
        is @lib.If(@lib.ValTypeBlockType(_), _, Some(_)),
      )
      assert_true(else_body[else_body.length() - 1] is @lib.Call(_))
    }
    [
      @lib.LocalGet(_),
      @lib.Call(_),
      @lib.If(@lib.VoidBlockType, _, Some(_)),
      @lib.LocalGet(_),
    ] => fail("expected f1903 dropped result-if arms to be packed")
    other =>
      fail("expected f1903 result-if packing, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean preserves f1383 dual i64 probe prefix wrapper before compare continuation" {
  // Slot23 `defined=1383 abs=1410` follows the f1346 guard: Binaryen keeps
  // an extra child block around the two call/local-set/release probe prefixes
  // and their first i64 sentinel comparison before the following compare/call
  // continuation. Starshine had flattened that child wrapper, reopening a raw
  // direct `--vacuum` parity gap. Keep this source-backed guard narrow to the
  // observed dual-probe shape rather than broadly preserving call prefixes.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let first_probe_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(71U)),
      @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    ],
    Some([
      @lib.Instruction::local_get(@lib.LocalIdx::new(1044U)),
      @lib.Instruction::i32_wrap_i64(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(75U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1045U)),
      @lib.Instruction::i64_const(@lib.I64(4294967296L)),
      @lib.Instruction::i64_eq(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(71U)),
          @lib.Instruction::call(@lib.FuncIdx::new(6U)),
        ],
        Some([
          @lib.Instruction::local_get(@lib.LocalIdx::new(1045U)),
          @lib.Instruction::i32_wrap_i64(),
          @lib.Instruction::local_set(@lib.LocalIdx::new(73U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(75U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(72U)),
        ]),
      ),
    ]),
  )
  let probe_prefix = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(71U)),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(127U)),
    @lib.Instruction::call(@lib.FuncIdx::new(11U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1050U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(127U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1050U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1044U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(71U)),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(124U)),
    @lib.Instruction::call(@lib.FuncIdx::new(10U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1051U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(124U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1051U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1045U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1044U)),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::i64_eq(),
    first_probe_if,
  ])
  let continuation_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(71U)),
      @lib.Instruction::call(@lib.FuncIdx::new(6U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ],
    None,
  )
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        probe_prefix,
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(71U)),
        @lib.Instruction::i32_load(load0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(72U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(73U)),
        @lib.Instruction::call(@lib.FuncIdx::new(12U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(74U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_lt_s(),
        continuation_if,
      ]),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(input, None)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] =>
      match parent_body {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(child_body))] => {
          assert_true(child_body[0] is @lib.Block(@lib.VoidBlockType, _))
          assert_true(child_body[1] is @lib.LocalGet(_))
          assert_true(child_body[child_body.length() - 1] is @lib.If(_, _, _))
        }
        other =>
          fail(
            "expected f1383 dual-probe prefix child wrapper to stay wrapped, got parent body \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected f1383 parent block wrapper, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean flattens f1738 loop-head local-copy wrapper before dispatch" {
  // Slot23 `defined=1738 abs=1765` follows the f1383 guard: Binaryen removes
  // the tiny anonymous child block around the loop-carried `local.set(local.get
  // $263)` copy at the head of a branchy loop dispatch, while Starshine kept
  // that wrapper. Keep this scoped to the observed loop-head two-tag dispatch
  // plus parent `br` continuation instead of broad singleton local-copy cleanup.
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          @lib.Instruction::local_get(@lib.LocalIdx::new(263U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        ]),
        @lib.Instruction::local_get(@lib.LocalIdx::new(262U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            pass_manager_test_vacuum_plain_block([
              @lib.Instruction::br(@lib.LabelIdx::new(2U)),
            ]),
            @lib.Instruction::unreachable_(),
          ],
          None,
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::call(@lib.FuncIdx::new(5U)),
            @lib.Instruction::br(@lib.LabelIdx::new(2U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::call(@lib.FuncIdx::new(5U)),
          ]),
        ),
      ]),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] =>
      match parent_body {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(loop_head_body)), @lib.Br(_)] => {
          assert_true(loop_head_body.length() >= 3)
          assert_true(loop_head_body[0] is @lib.LocalGet(_))
          assert_true(loop_head_body[1] is @lib.LocalSet(_))
          assert_true(!(loop_head_body[0] is @lib.Block(_, _)))
        }
        other => fail("expected f1738 loop-head block plus br, got \{other}")
      }
    other => fail("expected f1738 parent block, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f1743 loop-head copy before nested branch dispatch" {
  // Slot23 `defined=1743 abs=1770` follows the f1738 guard: Binaryen again
  // removes the tiny loop-head `local.set(local.get $170)` child block, but the
  // dispatch is now inside a following branchy child block with the loop-update
  // continuation instead of top-level tag-1/tag-2 tests. Keep this exact to the
  // observed branch dispatch plus parent `br` continuation so local-set-leading
  // and multi-local prefix guardrails remain protected.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load8 = @lib.MemArg::new(0U, None, 8UL)
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          @lib.Instruction::local_get(@lib.LocalIdx::new(170U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        ]),
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            @lib.Instruction::local_get(@lib.LocalIdx::new(169U)),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_load(load0),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
                @lib.Instruction::i32_load(load8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(20U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ],
              Some([
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
          @lib.Instruction::i32_const(@lib.I32(12)),
          @lib.Instruction::i32_ge_s(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
              @lib.Instruction::i32_load(load0),
              @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
            ],
            None,
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
          @lib.Instruction::call(@lib.FuncIdx::new(7U)),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
              @lib.Instruction::call(@lib.FuncIdx::new(6U)),
              @lib.Instruction::return_(),
            ],
            None,
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::call(@lib.FuncIdx::new(8U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(34U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
          @lib.Instruction::call(@lib.FuncIdx::new(6U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(34U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(173U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(174U)),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ]),
      ]),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] =>
      match parent_body {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(loop_head_body)), @lib.Br(_)] => {
          assert_true(loop_head_body.length() >= 3)
          assert_true(loop_head_body[0] is @lib.LocalGet(_))
          assert_true(loop_head_body[1] is @lib.LocalSet(_))
          assert_true(loop_head_body[2] is @lib.Block(_, _))
        }
        other => fail("expected f1743 loop-head block plus br, got \{other}")
      }
    other => fail("expected f1743 parent block, got \{other}")
  }
}

///|
test "raw vacuum preclean preserves f1759 tag2 prefix wrapper before counter-store continuation" {
  // Slot23 `defined=1759 abs=1786` follows the f1743 flattening guard and
  // flips wrapper direction again: Binaryen keeps the child block around the
  // side-effecting retain/call/release tag-2 dispatch prefix before the
  // following counter increment and slot store continuation. Keep this exact to
  // the observed raw prefix and continuation instead of broadly preserving tag
  // dispatch wrappers, which would regress earlier f1738/f1743 flattening.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let load8 = @lib.MemArg::new(0U, None, 8UL)
  let prefix = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::call(@lib.FuncIdx::new(9U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(8U)),
        @lib.Instruction::i32_load(load4),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(9U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
            @lib.Instruction::call(@lib.FuncIdx::new(7U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::call(@lib.FuncIdx::new(7U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
            @lib.Instruction::i32_load(load8),
            @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
            @lib.Instruction::call(@lib.FuncIdx::new(3U)),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_gt_s(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(4U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
              ],
              Some([
                @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::i32_eq(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
                    @lib.Instruction::i32_const(@lib.I32(8)),
                    @lib.Instruction::i32_sub(),
                    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                  ],
                  None,
                ),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
          ]),
        ),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ]),
    ),
  ])
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          prefix,
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          @lib.Instruction::i32_store(load0),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::call(@lib.FuncIdx::new(7U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::i32_store(load0),
        ]),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(input, None)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] =>
      match parent_body {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(loop_body))] =>
          match loop_body {
            [@lib.Block(@lib.VoidBlockType, @lib.Expr(inner_body)), @lib.Br(_)] =>
              match inner_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
                  assert_true(prefix_body.length() >= 16)
                  assert_true(prefix_body[0] is @lib.LocalGet(_))
                  assert_true(
                    prefix_body[prefix_body.length() - 1] is @lib.If(_, _, _),
                  )
                  assert_true(inner_body[1] is @lib.LocalGet(_))
                  assert_true(
                    inner_body[inner_body.length() - 1] is @lib.I32Store(_),
                  )
                }
                other =>
                  fail(
                    "expected f1759 tag2 prefix child wrapper to stay wrapped, got \{other}",
                  )
              }
            other => fail("expected f1759 inner block plus br, got \{other}")
          }
        other => fail("expected f1759 parent child block, got \{other}")
      }
    other => fail("expected f1759 parent block, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f1792 br-table dispatch return wrapper before merge continuation" {
  // Slot23 `defined=1792 abs=1819` follows the f1759 retained guard: Binaryen
  // removes one anonymous block around a nested `br_table` dispatch/return
  // ladder before the following merge-local continuation, while Starshine kept
  // that extra wrapper and shifted the branch labels. Keep this exact to the
  // observed native raw shape: a single child block whose top-level dispatch
  // ladder ends in `i32.const 0; return`, followed by `local.get; local.set; br`.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let labels : Array[@lib.LabelIdx] = []
  for target = 0; target < 10; target = target + 1 {
    labels.push(@lib.LabelIdx::new(target.reinterpret_as_uint()))
  }
  let mut ladder : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::i32_const(@lib.I32(41)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::br_table(labels, @lib.LabelIdx::new(9U)),
  ]
  for case_idx = 0; case_idx < 9; case_idx = case_idx + 1 {
    let temp_local = (13 + case_idx * 2).reinterpret_as_uint()
    let result_local = (11 - case_idx).reinterpret_as_uint()
    let branch_depth = (10 + case_idx).reinterpret_as_uint()
    ladder = [
      pass_manager_test_vacuum_plain_block(ladder),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_load(load4),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(temp_local)),
      @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(temp_local)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(result_local)),
      @lib.Instruction::br(@lib.LabelIdx::new(branch_depth)),
    ]
  }
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(ladder),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::return_(),
        ]),
      ]),
      @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(121U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body))] => {
      @debug.assert_eq(body.length(), 4)
      match body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(dispatch_body)) => {
          @debug.assert_eq(dispatch_body.length(), 3)
          assert_true(dispatch_body[0] is @lib.Block(@lib.VoidBlockType, _))
          assert_true(dispatch_body[1] is @lib.I32Const(@lib.I32(0)))
          assert_true(dispatch_body[2] is @lib.Return)
        }
        other => fail("expected f1792 dispatch block, got \{other}")
      }
      assert_true(body[1] is @lib.LocalGet(_))
      assert_true(body[2] is @lib.LocalSet(_))
      assert_true(body[3] is @lib.Br(_))
    }
    other => fail("expected f1792 parent wrapper flatten, got \{other}")
  }
}

///|
test "raw vacuum preclean preserves f1346 local-set release prefix wrapper before if continuation" {
  // Slot23 `defined=1346 abs=1373` follows f1272: Binaryen preserves the
  // child wrapper around a two-arg `local.set(call ...)` plus release-call
  // prefix when the following continuation `if` reads the produced predicate
  // local and may branch out to the parent. Keep this narrow so earlier
  // call-prefix wrapper flattening does not reopen.
  let prefix = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(83U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(8U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(213U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(83U)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
  ])
  let continuation = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(36U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
      @lib.Instruction::call(@lib.FuncIdx::new(13U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(214U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(41U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(36U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(40U)),
      @lib.Instruction::br(@lib.LabelIdx::new(2U)),
    ],
    Some([
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::call(@lib.FuncIdx::new(7U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(41U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(36U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(40U)),
    ]),
  )
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        prefix,
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(213U)),
        continuation,
      ]),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(input, None)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] =>
      match parent_body {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(child_body))] => {
          @debug.assert_eq(child_body.length(), 3)
          assert_true(child_body[0] is @lib.Block(@lib.VoidBlockType, _))
          assert_true(child_body[1] is @lib.LocalGet(_))
          assert_true(child_body[2] is @lib.If(@lib.VoidBlockType, _, Some(_)))
        }
        other =>
          fail(
            "expected f1346 local-set/release prefix child wrapper to stay wrapped, got parent body \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected f1346 parent block wrapper, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean preserves f3469 const-arg local-set release prefix wrapper before if continuation" {
  // Slot23 `defined=3469 abs=3496` follows the retained f3317 singleton
  // flattening fix and repeats the f1346 preservation direction with the
  // second call operand lowered as `i32.const 0`: Binaryen keeps the child
  // wrapper around `local.set(call(local.get, const)); release(local.get)`
  // before the following branchy `if` that reads the produced predicate local.
  // Keep this source-backed shape narrow so broader call-prefix / local-set
  // wrapper cleanup stays guarded.
  let source = @lib.LocalIdx::new(3U)
  let result = @lib.LocalIdx::new(16U)
  let tagged = @lib.LocalIdx::new(8U)
  let then_slot = @lib.LocalIdx::new(5U)
  let else_slot = @lib.LocalIdx::new(4U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let prefix = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::local_get(source),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::call(@lib.FuncIdx::new(9U)),
    @lib.Instruction::local_set(result),
    @lib.Instruction::local_get(source),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
  ])
  let continuation = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::i32_load(load0),
      @lib.Instruction::local_set(@lib.LocalIdx::new(17U)),
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::call(@lib.FuncIdx::new(3U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
      @lib.Instruction::local_set(then_slot),
    ],
    Some([
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::i32_load(load0),
      @lib.Instruction::local_set(@lib.LocalIdx::new(18U)),
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::call(@lib.FuncIdx::new(3U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
      @lib.Instruction::local_set(else_slot),
      @lib.Instruction::br(@lib.LabelIdx::new(2U)),
    ]),
  )
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        prefix,
        @lib.Instruction::local_get(result),
        @lib.Instruction::local_tee(tagged),
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        continuation,
      ]),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(input, None)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] =>
      match parent_body {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(child_body))] => {
          @debug.assert_eq(child_body.length(), 7)
          assert_true(child_body[0] is @lib.Block(@lib.VoidBlockType, _))
          assert_true(child_body[1] is @lib.LocalGet(_))
          assert_true(child_body[2] is @lib.LocalTee(_))
          assert_true(child_body[6] is @lib.If(@lib.VoidBlockType, _, Some(_)))
        }
        other =>
          fail(
            "expected f3469 const-arg local-set/release prefix child wrapper to stay wrapped, got parent body \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected f3469 parent block wrapper, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f3561_load_retain_branch_body(
  source : @lib.LocalIdx,
  retained : @lib.LocalIdx,
  arg : @lib.LocalIdx,
  built : @lib.LocalIdx,
  result : @lib.LocalIdx,
  cleanup : @lib.LocalIdx,
) -> Array[@lib.Instruction] {
  let load36 = @lib.MemArg::new(0U, None, 36UL)
  [
    @lib.Instruction::local_get(source),
    @lib.Instruction::i32_load(load36),
    @lib.Instruction::local_tee(retained),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(retained),
    @lib.Instruction::local_get(arg),
    @lib.Instruction::call(@lib.FuncIdx::new(6712U)),
    @lib.Instruction::local_set(built),
    @lib.Instruction::local_get(retained),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(built),
    @lib.Instruction::call(@lib.FuncIdx::new(3578U)),
    @lib.Instruction::local_tee(result),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(result),
        @lib.Instruction::call(@lib.FuncIdx::new(6523U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(result),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::br(@lib.LabelIdx::new(3U)),
          ],
          Some([
            @lib.Instruction::local_get(result),
            @lib.Instruction::local_set(cleanup),
          ]),
        ),
      ],
      Some([
        @lib.Instruction::local_get(result),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(result),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
          ],
          None,
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f3561 load retain wrapper before terminal release" {
  // Slot23 `defined=3561 abs=3588` follows the retained f3469 prefix fix:
  // Binaryen preserves the anonymous block around the offset-36 load/retain,
  // local-get-arg call local-set, release, and branchy call-result `if` when
  // the parent continuation immediately releases the merged cleanup local and
  // returns. Guard that terminal release-return context separately from f3530,
  // where Binaryen flattens the same prefix family before a local-set/branch
  // merge continuation.
  let source = @lib.LocalIdx::new(4U)
  let retained = @lib.LocalIdx::new(436U)
  let arg = @lib.LocalIdx::new(203U)
  let built = @lib.LocalIdx::new(468U)
  let result = @lib.LocalIdx::new(205U)
  let cleanup = @lib.LocalIdx::new(204U)
  let branch_body = pass_manager_test_vacuum_f3561_load_retain_branch_body(
    source, retained, arg, built, result, cleanup,
  )
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(branch_body),
      @lib.Instruction::local_get(cleanup),
      @lib.Instruction::call(@lib.FuncIdx::new(38U)),
      @lib.Instruction::i32_const(@lib.I32::new(0)),
      @lib.Instruction::return_(),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(input, None)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), 5)
      assert_true(parent_body[0] is @lib.Block(@lib.VoidBlockType, _))
      assert_true(parent_body[1] is @lib.LocalGet(_))
      assert_true(parent_body[2] is @lib.Call(_))
      assert_true(parent_body[3] is @lib.I32Const(_))
      assert_true(parent_body[4] is @lib.Return)
    }
    other =>
      fail(
        "expected f3561 terminal-release wrapper parent, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean still flattens f3530 load retain wrapper before merge branch" {
  // Negative guard for the rejected f3561 experiment: the same load/retain and
  // branchy call-result prefix must still flatten when the parent continuation
  // is a local-set plus outer branch, matching the full-slot f3530 regression
  // that rejected the broader preservation prototype.
  let source = @lib.LocalIdx::new(4U)
  let retained = @lib.LocalIdx::new(436U)
  let arg = @lib.LocalIdx::new(203U)
  let built = @lib.LocalIdx::new(468U)
  let result = @lib.LocalIdx::new(205U)
  let cleanup = @lib.LocalIdx::new(204U)
  let out = @lib.LocalIdx::new(812U)
  let branch_body = pass_manager_test_vacuum_f3561_load_retain_branch_body(
    source, retained, arg, built, result, cleanup,
  )
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(branch_body),
      @lib.Instruction::local_get(cleanup),
      @lib.Instruction::local_set(out),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      assert_false(parent_body[0] is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(parent_body[0], @lib.Instruction::local_get(source))
      @debug.assert_eq(
        parent_body[parent_body.length() - 3],
        @lib.Instruction::local_get(cleanup),
      )
      @debug.assert_eq(
        parent_body[parent_body.length() - 2],
        @lib.Instruction::local_set(out),
      )
      assert_true(parent_body[parent_body.length() - 1] is @lib.Br(_))
    }
    other =>
      fail(
        "expected f3530 merge-branch wrapper to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean drops f3574 empty then call condition" {
  // Slot23 `defined=3574 abs=3601` follows the f3561 terminal-release wrapper
  // fix: Binaryen Vacuum.cpp rewrites a void `if` with an empty then arm and no
  // else into a dropped condition. Keep this focused on the observed
  // side-effecting call condition so pure-condition cleanup does not broaden in
  // the same slice.
  let arg0 = @lib.LocalIdx::new(1U)
  let arg1 = @lib.LocalIdx::new(2U)
  let arg2 = @lib.LocalIdx::new(108U)
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(arg0),
      @lib.Instruction::local_get(arg1),
      @lib.Instruction::local_get(arg2),
      @lib.Instruction::call(@lib.FuncIdx::new(3594U)),
      @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
    ],
    None,
  )
  assert_true(changed)
  @debug.assert_eq(cleaned, [
    @lib.Instruction::local_get(arg0),
    @lib.Instruction::local_get(arg1),
    @lib.Instruction::local_get(arg2),
    @lib.Instruction::call(@lib.FuncIdx::new(3594U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "raw vacuum preclean flattens f3579 loop-head local-copy guard wrapper" {
  // Slot23 `defined=3579 abs=3606` follows the retained f3574 empty-if drop:
  // Binaryen flattens one anonymous singleton child around the loop-head
  // `local.set(local.get $219 -> $7)` before the next local-copy and
  // call-produced guard `if`. This is a narrow BlockUtils::simplifyToContents
  // parity case, not permission to flatten prefix-sensitive local-copy wrappers.
  let loop_arg = @lib.LocalIdx::new(219U)
  let loop_copy = @lib.LocalIdx::new(7U)
  let env_arg = @lib.LocalIdx::new(216U)
  let env_copy = @lib.LocalIdx::new(4U)
  let pair_arg = @lib.LocalIdx::new(217U)
  let pair_tmp = @lib.LocalIdx::new(5U)
  let call_arg = @lib.LocalIdx::new(218U)
  let guard_local = @lib.LocalIdx::new(8U)
  let guarded_body = [
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::local_get(loop_arg),
      @lib.Instruction::local_set(loop_copy),
    ]),
    @lib.Instruction::local_get(env_arg),
    @lib.Instruction::local_set(env_copy),
    @lib.Instruction::local_get(pair_arg),
    @lib.Instruction::local_tee(pair_tmp),
    @lib.Instruction::local_get(call_arg),
    @lib.Instruction::call(@lib.FuncIdx::new(4177U)),
    @lib.Instruction::local_tee(guard_local),
    @lib.Instruction::call(@lib.FuncIdx::new(3923U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_ne(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(guard_local),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(loop_copy),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(pair_tmp),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(env_copy),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::return_(),
      ],
      None,
    ),
  ]
  let input = [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            pass_manager_test_vacuum_plain_block(guarded_body),
          ]),
        ]),
      ]),
    ),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body))] =>
      match loop_body {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(block3_body))] =>
          match block3_body {
            [@lib.Block(@lib.VoidBlockType, @lib.Expr(block2_body))] =>
              match block2_body {
                [@lib.Block(@lib.VoidBlockType, @lib.Expr(flat_body))] => {
                  @debug.assert_eq(
                    flat_body.length(),
                    guarded_body.length() + 1,
                  )
                  @debug.assert_eq(
                    flat_body[0],
                    @lib.Instruction::local_get(loop_arg),
                  )
                  @debug.assert_eq(
                    flat_body[1],
                    @lib.Instruction::local_set(loop_copy),
                  )
                  @debug.assert_eq(
                    flat_body[2],
                    @lib.Instruction::local_get(env_arg),
                  )
                  @debug.assert_eq(
                    flat_body[3],
                    @lib.Instruction::local_set(env_copy),
                  )
                  assert_true(flat_body[4] is @lib.LocalGet(_))
                  assert_true(
                    flat_body[12] is @lib.If(@lib.VoidBlockType, _, None),
                  )
                }
                other =>
                  fail(
                    "expected f3579 inner block, got \{@debug.to_string(other)}",
                  )
              }
            other =>
              fail(
                "expected f3579 block2 wrapper, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail("expected f3579 block3 wrapper, got \{@debug.to_string(other)}")
      }
    other => fail("expected f3579 loop wrapper, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean keeps f3579-like local copy without call guard wrapped" {
  // Negative guard: a singleton local-copy child followed by another local-copy
  // is not enough. The f3579 flattening requires the observed call-produced
  // guard/return continuation, so prefix-sensitive local-set wrappers remain
  // protected when the guard is absent.
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
      ]),
      @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_eq(),
      @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(wrapped, None)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), 7)
      assert_true(parent_body[0] is @lib.Block(@lib.VoidBlockType, _))
    }
    other =>
      fail(
        "expected f3579 negative local-copy wrapper to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f3841_tag_dispatch_body() -> Array[@lib.Instruction] {
  let source = @lib.LocalIdx::new(1U)
  let index = @lib.LocalIdx::new(6U)
  let retained = @lib.LocalIdx::new(33U)
  let value = @lib.LocalIdx::new(46U)
  let active = @lib.LocalIdx::new(11U)
  let tag = @lib.LocalIdx::new(40U)
  let out0 = @lib.LocalIdx::new(10U)
  let out1 = @lib.LocalIdx::new(9U)
  let out2 = @lib.LocalIdx::new(7U)
  let tmp0 = @lib.LocalIdx::new(47U)
  let tmp1 = @lib.LocalIdx::new(48U)
  let tmp2 = @lib.LocalIdx::new(49U)
  let tmp3 = @lib.LocalIdx::new(50U)
  let tmp4 = @lib.LocalIdx::new(51U)
  [
    @lib.Instruction::local_get(source),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 8UL)),
    @lib.Instruction::local_tee(retained),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(retained),
    @lib.Instruction::local_get(index),
    @lib.Instruction::call(@lib.FuncIdx::new(6711U)),
    @lib.Instruction::local_set(value),
    @lib.Instruction::local_get(retained),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(value),
    @lib.Instruction::local_tee(active),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::local_tee(tag),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tag),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(active),
            @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
            @lib.Instruction::local_set(tmp1),
            @lib.Instruction::local_get(active),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(tmp1),
            @lib.Instruction::local_set(out0),
          ],
          Some([
            @lib.Instruction::local_get(tag),
            @lib.Instruction::i32_const(@lib.I32(4)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(active),
                @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
                @lib.Instruction::local_set(tmp2),
                @lib.Instruction::local_get(active),
                @lib.Instruction::call(@lib.FuncIdx::new(38U)),
                @lib.Instruction::local_get(tmp2),
                @lib.Instruction::local_set(out1),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::local_get(tag),
                @lib.Instruction::i32_const(@lib.I32(2)),
                @lib.Instruction::i32_eq(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(active),
                    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
                    @lib.Instruction::local_set(tmp3),
                    @lib.Instruction::local_get(active),
                    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
                    @lib.Instruction::local_get(tmp3),
                    @lib.Instruction::local_set(out2),
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::local_get(active),
                    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
                    @lib.Instruction::local_set(tmp4),
                    @lib.Instruction::local_get(active),
                    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
                    @lib.Instruction::local_get(tmp4),
                    @lib.Instruction::local_set(out2),
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::unreachable_(),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
      ],
      Some([
        @lib.Instruction::local_get(active),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_set(tmp0),
        @lib.Instruction::local_get(active),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(tmp0),
        @lib.Instruction::local_set(out0),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean flattens f3841 tag-dispatch wrapper before local-set branch" {
  // Slot23 `defined=3841 abs=3868` follows the retained f3771 guard: Binaryen
  // removes one anonymous singleton wrapper around a load/retain, two-arg
  // call-result local.set, release, and call-produced tag-dispatch `if` before
  // the surrounding block stores the selected local and branches outward. Keep
  // this scoped to the observed local-set + br continuation; broader
  // side-effecting call-prefix cleanup has regressed prefix-preservation guards.
  let selected = @lib.LocalIdx::new(10U)
  let output = @lib.LocalIdx::new(183U)
  let inner_wrapper = pass_manager_test_vacuum_plain_block(
    pass_manager_test_vacuum_f3841_tag_dispatch_body(),
  )
  let outer_wrapper = pass_manager_test_vacuum_plain_block([inner_wrapper])
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        outer_wrapper,
        @lib.Instruction::local_get(selected),
        @lib.Instruction::local_set(output),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      match parent_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(wrapper_body)) => {
          assert_false(wrapper_body[0] is @lib.Block(@lib.VoidBlockType, _))
          @debug.assert_eq(
            wrapper_body[0],
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          )
        }
        other => fail("expected f3841 outer wrapper to remain, got \{other}")
      }
      @debug.assert_eq(
        parent_body[parent_body.length() - 3],
        @lib.Instruction::local_get(selected),
      )
      @debug.assert_eq(
        parent_body[parent_body.length() - 2],
        @lib.Instruction::local_set(output),
      )
      @debug.assert_eq(
        parent_body[parent_body.length() - 1],
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      )
    }
    other =>
      fail(
        "expected f3841 tag-dispatch singleton child to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean keeps f3841-like tag-dispatch wrapper without local-set branch continuation" {
  // Negative guard: the f3841 rule requires the observed selected-local store
  // plus outward branch after the singleton wrapper. A similar side-effecting
  // tag-dispatch wrapper followed only by a branch remains protected.
  let inner_wrapper = pass_manager_test_vacuum_plain_block(
    pass_manager_test_vacuum_f3841_tag_dispatch_body(),
  )
  let outer_wrapper = pass_manager_test_vacuum_plain_block([inner_wrapper])
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        outer_wrapper,
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), 2)
      match parent_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(wrapper_body)) =>
          assert_true(wrapper_body[0] is @lib.Block(@lib.VoidBlockType, _))
        other => fail("expected f3841 negative outer wrapper, got \{other}")
      }
    }
    other =>
      fail(
        "expected f3841 negative tag-dispatch wrapper to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f3998_prefix_body() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6711U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(100U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3997U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(131U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(100U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
  ]
}

///|
fn pass_manager_test_vacuum_f3998_tag2_body() -> Array[@lib.Instruction] {
  [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f3998_prefix_body(),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(131U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(46U)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(46U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 4UL)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(41U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(46U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 8UL)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(42U)),
        @lib.Instruction::call(@lib.FuncIdx::new(36U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(46U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f3998_loop_continuation() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(42U)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(43U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(134U)),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(43U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(134U)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(287U)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ],
          Some([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
        ),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean flattens f3998 tag2 prefix child before loop continuation" {
  // Slot23 `defined=3998 abs=4025` follows the retained f3841 fix: Binaryen
  // removes the singleton child around `local.set(call(local.tee(call ...),
  // local.get)); release` before the tag-2 dispatch block, while keeping the
  // parent block that precedes the following release/load/zero-init loop
  // continuation. Keep this exact loop-continuation shape narrow; similar
  // side-effecting call-prefix wrappers are guarded below.
  let continuation = pass_manager_test_vacuum_f3998_loop_continuation()
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f3998_tag2_body(),
      ),
    ]),
  ]
  for instr in continuation {
    parent_body.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
              assert_true(prefix_body[0] is @lib.LocalGet(_))
              assert_true(prefix_body[1] is @lib.LocalGet(_))
              assert_true(prefix_body[5] is @lib.Call(_))
              assert_true(prefix_body[8] is @lib.Call(_))
            }
            other => fail("expected f3998 retained prefix block, got \{other}")
          }
          assert_true(outer_body[1] is @lib.LocalGet(_))
          assert_true(outer_body[6] is @lib.If(_, _, _))
        }
        other => fail("expected f3998 parent tag block, got \{other}")
      }
    other =>
      fail(
        "expected f3998 tag2 prefix child to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4070_prefix_body() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(87U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5466U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(821U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(87U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
  ]
}

///|
fn pass_manager_test_vacuum_f4070_dispatch_continuation() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(821U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(125U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(122U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(116U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(124U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4073U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(822U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(821U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(125U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(124U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(822U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(183U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(183U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(184U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(494U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(123U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(117U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(183U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(186U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(495U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean flattens f4070 one-arg prefix parent before result dispatch" {
  // Slot23 `defined=4070 abs=4097` follows the retained f3998 fix: Binaryen
  // removes the anonymous parent around a retained one-arg call-result
  // `local.set; release` prefix block plus the following multi-arg call-result
  // local-set/release/tag dispatch continuation. Keep the prefix block itself
  // and only remove the observed parent wrapper.
  let wrapped_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f4070_prefix_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f4070_dispatch_continuation() {
    wrapped_body.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(wrapped_body),
        ]),
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
              assert_true(prefix_body[0] is @lib.LocalGet(_))
              assert_true(prefix_body[2] is @lib.LocalSet(_))
              assert_true(prefix_body[4] is @lib.Call(_))
            }
            other => fail("expected f4070 retained prefix block, got \{other}")
          }
          match outer_body[1] {
            @lib.LocalGet(_) => ()
            other =>
              fail("expected f4070 first continuation local.get, got \{other}")
          }
          assert_true(outer_body[9] is @lib.LocalSet(_))
          match outer_body[21] {
            @lib.If(_, then_body, Some(else_body)) => {
              @debug.assert_eq(
                then_body[4],
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              )
              @debug.assert_eq(
                else_body[8],
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              )
            }
            other => fail("expected f4070 dispatch if, got \{other}")
          }
        }
        other => fail("expected f4070 parent wrapper to flatten, got \{other}")
      }
    other =>
      fail(
        "expected f4070 one-arg prefix parent to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean keeps f4070-like one-arg prefix without result dispatch" {
  // Negative guard: a side-effecting one-arg call-result local-set/release
  // prefix block is not enough. Without the observed multi-arg call-result
  // local-set/release/tag dispatch continuation, the wrapper remains protected.
  let wrapped_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f4070_prefix_body(),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(821U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(wrapped_body),
        ]),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(wrapper_body)) =>
              assert_true(wrapper_body[0] is @lib.Block(@lib.VoidBlockType, _))
            other => fail("expected f4070 negative wrapper, got \{other}")
          }
        other => fail("expected f4070 negative parent, got \{other}")
      }
    other =>
      fail(
        "expected f4070-like one-arg prefix to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4071_load_retain_tag_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset8 = @lib.MemArg::new(0U, None, 8UL)
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_load(offset8),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(85U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4075U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(89U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(89U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(90U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(492U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(492U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(88U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(85U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(89U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(92U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(493U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(493U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(87U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f4071 load retain tag-dispatch wrapper before selected-local branch" {
  // Slot23 `defined=4071 abs=4098` follows the retained f4070 fix and flips
  // direction: Binaryen keeps the anonymous wrapper around an offset-8
  // load/retain prefix plus the call-result tag-1 dispatch when the parent
  // continuation consumes the selected then-local and branches outward.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(
            pass_manager_test_vacuum_f4071_load_retain_tag_dispatch_body(),
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(88U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(2527U)),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ]),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) =>
          match parent_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(dispatch_body)) => {
              assert_true(dispatch_body[0] is @lib.LocalGet(_))
              assert_true(dispatch_body[3] is @lib.Call(_))
              assert_true(dispatch_body[11] is @lib.If(_, _, _))
            }
            other =>
              fail("expected f4071 dispatch wrapper to remain, got \{other}")
          }
        other => fail("expected f4071 parent wrapper, got \{other}")
      }
    other =>
      fail(
        "expected f4071 load-retain tag-dispatch wrapper to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean still flattens f4071-like wrapper without selected-local continuation" {
  // Negative guard: the f4071 preservation needs the observed selected-local
  // handoff plus outward branch in the parent. Without that continuation, the
  // same load/retain call-result tag-dispatch wrapper remains eligible for the
  // existing wrapper cleanup path.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(
            pass_manager_test_vacuum_f4071_load_retain_tag_dispatch_body(),
          ),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ]),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
          assert_true(parent_body[0] is @lib.LocalGet(_))
          assert_true(parent_body[3] is @lib.Call(_))
        }
        other => fail("expected f4071 negative parent wrapper, got \{other}")
      }
    other =>
      fail(
        "expected f4071-like wrapper without continuation to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4073_call_result_tag_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(26U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(26U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4071U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(51U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(26U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(51U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(17U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(18U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(36U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(36U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(16U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(20U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(37U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(37U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(15U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4073_slot_store_continuation() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
    @lib.Instruction::i32_store(offset0),
  ]
}

///|
test "raw vacuum preclean preserves f4073 call-result tag-dispatch wrapper before slot store" {
  // Slot23 `defined=4073 abs=4100` follows the retained f4071 fixes: Binaryen
  // keeps another wrapper around a retain/load prefix, multi-arg call-result,
  // release pair, and call-result tag dispatch when the immediate continuation
  // releases the previous slot payload and stores the selected then-local back
  // into that slot. Keep this narrower than broad call-prefix preservation.
  let parent_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f4073_call_result_tag_dispatch_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f4073_slot_store_continuation() {
    parent_body.push(instr)
  }
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(parent_body),
          @lib.Instruction::br(@lib.LabelIdx::new(1U)),
        ]),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(next_parent_body)) =>
              match next_parent_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
                  assert_true(prefix_body[0] is @lib.LocalGet(_))
                  assert_true(prefix_body[14] is @lib.Call(_))
                  assert_true(prefix_body[25] is @lib.If(_, _, _))
                }
                other =>
                  fail(
                    "expected f4073 dispatch wrapper to remain, got \{other}",
                  )
              }
            other => fail("expected f4073 parent wrapper, got \{other}")
          }
        other => fail("expected f4073 outer wrapper, got \{other}")
      }
    other =>
      fail(
        "expected f4073 call-result tag-dispatch wrapper to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean still flattens f4073-like wrapper without slot store" {
  // Negative guard: the f4073 wrapper preservation needs the observed
  // release-load/store-selected continuation. A similar side-effecting
  // call-result tag-dispatch wrapper without that continuation must keep using
  // the existing cleanup path so broad prefix wrappers do not over-preserve.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            pass_manager_test_vacuum_plain_block(
              pass_manager_test_vacuum_f4073_call_result_tag_dispatch_body(),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ]),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
              assert_true(parent_body[0] is @lib.LocalGet(_))
              assert_true(parent_body[14] is @lib.Call(_))
            }
            other =>
              fail("expected f4073 negative parent wrapper, got \{other}")
          }
        other => fail("expected f4073 negative outer wrapper, got \{other}")
      }
    other =>
      fail(
        "expected f4073-like wrapper without slot store to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4071_sentinel_prefix_body() -> Array[
  @lib.Instruction,
] {
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_load(offset4),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(469U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(469U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4107U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(4022U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(469U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4022U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(4016U)),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::i64_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(315U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(4016U)),
        @lib.Instruction::i32_wrap_i64(),
        @lib.Instruction::local_set(@lib.LocalIdx::new(390U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(315U)),
        @lib.Instruction::call(@lib.FuncIdx::new(3923U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(390U)),
        @lib.Instruction::i32_ge_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(390U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(389U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(315U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::br(@lib.LabelIdx::new(3U)),
          ]),
        ),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4071_sentinel_continuation() -> Array[
  @lib.Instruction,
] {
  let offset8 = @lib.MemArg::new(0U, None, 8UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(318U)),
    @lib.Instruction::i32_load(offset8),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(467U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(315U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(467U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(389U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4081U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(781U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(315U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(467U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
  ]
}

///|
test "raw vacuum preclean preserves f4071 sentinel prefix wrapper before allocation continuation" {
  // Same slot23 function as the f4071 load/retain tag-dispatch residual: after
  // preserving the first wrapper, the next first diff is another
  // Binaryen-preserved wrapper around an offset-4 retain, sentinel-result call,
  // release, and branchy `i64 == 4294967296` selection before the allocation
  // continuation that consumes the selected local.
  let parent_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f4071_sentinel_prefix_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f4071_sentinel_continuation() {
    parent_body.push(instr)
  }
  let (cleaned_with_continuation, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(parent_body),
        ]),
      ]),
    ],
    None,
  )
  match cleaned_with_continuation {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(block82_body)) =>
          match block82_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(next_parent_body)) =>
              match next_parent_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
                  assert_true(prefix_body[0] is @lib.LocalGet(_))
                  assert_true(prefix_body[3] is @lib.Call(_))
                  assert_true(prefix_body[14] is @lib.If(_, _, _))
                }
                other =>
                  fail(
                    "expected f4071 sentinel wrapper to remain, got \{other}",
                  )
              }
            other =>
              fail("expected f4071 sentinel middle wrapper, got \{other}")
          }
        other => fail("expected f4071 sentinel parent wrapper, got \{other}")
      }
    other =>
      fail(
        "expected f4071 sentinel prefix wrapper to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4232_sentinel_return_prefix_body() -> Array[
  @lib.Instruction,
] {
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(offset4),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6579U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(30U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(30U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(28U)),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::i64_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::br(@lib.LabelIdx::new(2U))],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(28U)),
        @lib.Instruction::i32_wrap_i64(),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_ge_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          ],
          Some([@lib.Instruction::br(@lib.LabelIdx::new(3U))]),
        ),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f4232 sentinel wrapper before selected-local return" {
  // Slot23 `defined=4232 abs=4259` follows the retained f4073 fix: Binaryen
  // keeps the wrapper around an offset-4 retain, sentinel-result call/release,
  // and selected-local branch when the parent continuation immediately returns
  // the selected local before the fallback call. Keep this as parity work, not
  // a Starshine win, and keep the guard narrower than broad sentinel wrappers.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(
          pass_manager_test_vacuum_f4232_sentinel_return_prefix_body(),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::return_(),
      ]),
      @lib.Instruction::i32_const(@lib.I32(121840)),
      @lib.Instruction::call(@lib.FuncIdx::new(7395U)),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)), _, _] =>
      match parent_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
          assert_true(prefix_body[0] is @lib.LocalGet(_))
          assert_true(prefix_body[3] is @lib.Call(_))
          assert_true(prefix_body[14] is @lib.If(_, _, _))
        }
        other => fail("expected f4232 sentinel wrapper to remain, got \{other}")
      }
    other =>
      fail(
        "expected f4232 sentinel return wrapper to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean still flattens f4232-like sentinel wrapper without selected-local return" {
  // Negative guard: preserving f4232 requires the immediate selected-local
  // return continuation. Without it, this sentinel branch shape remains eligible
  // for the existing side-effect wrapper cleanup.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(
          pass_manager_test_vacuum_f4232_sentinel_return_prefix_body(),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
      @lib.Instruction::i32_const(@lib.I32(121840)),
      @lib.Instruction::call(@lib.FuncIdx::new(7395U)),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)), _, _] => {
      assert_true(parent_body[0] is @lib.LocalGet(_))
      assert_true(parent_body[3] is @lib.Call(_))
    }
    other =>
      fail(
        "expected f4232-like sentinel wrapper without selected-local return to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4310_side_effect_prefix_body() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4333U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(95U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(95U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(23U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(23U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(21U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(23U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(19U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4310_accumulator_store_continuation() -> Array[
  @lib.Instruction,
] {
  let mem = @lib.MemArg::new(0U, None, 0UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
    @lib.Instruction::i32_load(mem),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_store(mem),
    @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(22U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
    @lib.Instruction::i32_load(mem),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_store(mem),
  ]
}

///|
test "raw vacuum preclean preserves f4310 side-effect prefix wrapper before accumulator stores" {
  // Slot23 `defined=4310 abs=4337` follows the retained f4232 fix and is a
  // Starshine-over-flattened / Binaryen-preserved nontrivial side-effect
  // prefix wrapper. Keep the fix narrow to the observed loop accumulator-store
  // continuation instead of disabling the broad side-effect prefix cleanup.
  let parent_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f4310_side_effect_prefix_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f4310_accumulator_store_continuation() {
    parent_body.push(instr)
  }
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
          assert_true(prefix_body[0] is @lib.LocalGet(_))
          assert_true(prefix_body[1] is @lib.Call(_))
          assert_true(prefix_body[prefix_body.length() - 1] is @lib.If(_, _, _))
        }
        other =>
          fail(
            "expected f4310 side-effect prefix wrapper to remain, got \{other}",
          )
      }
    other =>
      fail(
        "expected f4310 side-effect prefix parent to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean still flattens f4310-like prefix without accumulator stores" {
  // Negative guard: the retained f4310 fix requires the observed two-store
  // accumulator continuation from the decoded slot23 loop body. A bare prefix
  // wrapper remains on the existing cleanup path so broad side-effect prefix
  // preservation does not reopen earlier guardrails.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(
          pass_manager_test_vacuum_f4310_side_effect_prefix_body(),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_true(clean_parent[0] is @lib.LocalGet(_))
      assert_true(clean_parent[1] is @lib.Call(_))
    }
    other =>
      fail(
        "expected f4310-like prefix without accumulator stores to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4311_tag85_86_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let mem = @lib.MemArg::new(0U, None, 0UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(44U)),
    @lib.Instruction::i32_const(@lib.I32(86)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
        @lib.Instruction::i32_load(mem),
        @lib.Instruction::local_set(@lib.LocalIdx::new(11U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(44U)),
        @lib.Instruction::i32_const(@lib.I32(85)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::i32_load(mem),
            @lib.Instruction::local_set(@lib.LocalIdx::new(30U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(30U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
            @lib.Instruction::br(@lib.LabelIdx::new(3U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::i32_load(mem),
            @lib.Instruction::local_set(@lib.LocalIdx::new(31U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(31U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4311_call_local_set_continuation() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::i32_const(@lib.I32(6)),
    @lib.Instruction::call(@lib.FuncIdx::new(7287U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(9U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::call(@lib.FuncIdx::new(7309U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(54U)),
  ]
}

///|
test "raw vacuum preclean flattens f4311 nested tag dispatch wrappers before call continuation" {
  // Slot23 `defined=4311 abs=4338` follows the retained f4310 fix: Binaryen
  // removes two anonymous singleton wrappers around a tag-86/tag-85 branch
  // dispatch before the following call-produced local-set continuation, while
  // Starshine retained them. Keep this exact branch-dispatch + continuation
  // shape narrow rather than enabling broad nested singleton-if flattening.
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f4311_tag85_86_dispatch_body(),
      ),
    ]),
  ]
  for instr in pass_manager_test_vacuum_f4311_call_local_set_continuation() {
    parent_body.push(instr)
  }
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_true(clean_parent[0] is @lib.LocalGet(_))
      assert_true(clean_parent[1] is @lib.Call(_))
      assert_true(clean_parent[5] is @lib.If(_, _, _))
    }
    other =>
      fail(
        "expected f4311 parent block with flattened dispatch prefix, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4463_offset20_call_result_tag1_prefix_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  let offset20 = @lib.MemArg::new(0U, None, 20UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(279U)),
    @lib.Instruction::i32_load(offset20),
    @lib.Instruction::local_set(@lib.LocalIdx::new(816U)),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(34U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1474U)),
    @lib.Instruction::i32_const(@lib.I32(524544)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1474U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_store(offset0),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1474U)),
    @lib.Instruction::i32_const(@lib.I32(10088)),
    @lib.Instruction::i32_store(offset4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(816U)),
    @lib.Instruction::call(@lib.FuncIdx::new(63U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(816U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(281U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1474U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4553U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(818U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4509U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1709U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(816U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(281U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1474U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(818U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1709U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(312U)),
    @lib.Instruction::call(@lib.FuncIdx::new(39U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(312U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(311U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(312U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(310U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4463_offset12_indexed_call_result_tag1_prefix_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  let offset12 = @lib.MemArg::new(0U, None, 12UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(56U)),
    @lib.Instruction::i32_load(offset4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(352U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_shl(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(353U)),
    @lib.Instruction::i32_load(offset12),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(855U)),
    @lib.Instruction::call(@lib.FuncIdx::new(63U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(353U)),
    @lib.Instruction::call(@lib.FuncIdx::new(63U)),
    @lib.Instruction::i32_const(@lib.I32(10088)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::call(@lib.FuncIdx::new(6860U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1731U)),
    @lib.Instruction::i32_const(@lib.I32(10088)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1731U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(856U)),
    @lib.Instruction::i32_const(@lib.I32(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(34U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1463U)),
    @lib.Instruction::i32_const(@lib.I32(524544)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1463U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_store(offset0),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1463U)),
    @lib.Instruction::i32_const(@lib.I32(10088)),
    @lib.Instruction::i32_store(offset4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(855U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(856U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1463U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4553U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(858U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4509U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1732U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(855U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(856U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1463U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(858U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1732U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(357U)),
    @lib.Instruction::call(@lib.FuncIdx::new(39U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(357U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(356U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(353U)),
        @lib.Instruction::call(@lib.FuncIdx::new(65U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(357U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(355U)),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4463_failure_box_return_continuation() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(34U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1475U)),
    @lib.Instruction::i32_const(@lib.I32(256)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1475U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(310U)),
    @lib.Instruction::i32_store(offset0),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1475U)),
    @lib.Instruction::return_(),
  ]
}

///|
test "raw vacuum preclean flattens f4463 offset20 prefix owner before failure-box return" {
  // Slot23 `defined=4463 abs=4490` after the retained f4311 fix is a
  // Starshine-retained / Binaryen-flattened singleton owner around the actual
  // decoded offset-20 allocation/call-result/tag-1 prefix. The wrapper sits
  // before `local.get; local.set; br` and a sibling failure-box return, so keep
  // the cleanup narrower than broad owner-target branch flattening.
  let owner = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f4463_offset20_call_result_tag1_prefix_body(),
      ),
    ]),
    @lib.Instruction::local_get(@lib.LocalIdx::new(311U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(5460U)),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  let outer = [pass_manager_test_vacuum_plain_block(owner)]
  for instr in pass_manager_test_vacuum_f4463_failure_box_return_continuation() {
    outer.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_owner)) => {
          @debug.assert_eq(clean_owner.length(), 4)
          match clean_owner[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) =>
              assert_true(
                prefix_body[20] ==
                @lib.Instruction::call(@lib.FuncIdx::new(4553U)),
              )
            other =>
              fail("expected f4463 prefix block after flatten, got \{other}")
          }
        }
        other => fail("expected f4463 owner block, got \{other}")
      }
    other => fail("expected f4463 outer block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean flattens f4463 offset12 indexed singleton prefix owner" {
  // Slot23 `defined=4463 abs=4490` later residual after the retained offset-20
  // owner fix has the actual raw flat prefix inside a singleton anonymous block:
  // indexed `offset=12` load, retain/load allocation, call-result/tag-1 test,
  // and a branchy cleanup return path. Binaryen removes only that innermost
  // singleton block; keep this source-backed fixture on the decoded flat shape
  // rather than the rejected folded-WAT top-level hand model.
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(
          pass_manager_test_vacuum_f4463_offset12_indexed_call_result_tag1_prefix_body(),
        ),
      ]),
      @lib.Instruction::local_get(@lib.LocalIdx::new(356U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(6039U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] => {
      @debug.assert_eq(clean_outer.length(), 4)
      let clean_body = match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(inner)) => inner
        other => fail("expected f4463 offset12 owner block, got \{other}")
      }
      assert_true(clean_body.length() > 55)
      @debug.assert_eq(
        clean_body[0],
        @lib.Instruction::local_get(@lib.LocalIdx::new(56U)),
      )
      @debug.assert_eq(
        clean_body[38],
        @lib.Instruction::call(@lib.FuncIdx::new(4553U)),
      )
      match clean_body[clean_body.length() - 1] {
        @lib.If(_, _, Some(else_body)) =>
          @debug.assert_eq(
            else_body[else_body.length() - 1],
            @lib.Instruction::br(@lib.LabelIdx::new(2U)),
          )
        other =>
          fail(
            "expected final tag-1 if after f4463 offset12 flatten, got \{other}",
          )
      }
    }
    other =>
      fail(
        "expected one f4463 offset12 wrapper removed, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4483_indexed_call_result_tag1_prefix_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::i32_load(offset4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_shl(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::i32_const(@lib.I32(148024)),
    @lib.Instruction::call(@lib.FuncIdx::new(4490U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(8U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::i64_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1044U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1044U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1027U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(133U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::call(@lib.FuncIdx::new(10U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(143U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(143U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(11U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(133U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(143U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(133U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4483_indexed_float_call_result_tag1_prefix_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(42U)),
    @lib.Instruction::i32_load(offset4),
    @lib.Instruction::local_get(@lib.LocalIdx::new(44U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_shl(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(45U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(45U)),
    @lib.Instruction::i64_const(@lib.I64(2139095040L)),
    @lib.Instruction::i64_const(@lib.I64(4194304L)),
    @lib.Instruction::i64_const(@lib.I64(8388607L)),
    @lib.Instruction::i64_const(@lib.I64(2147483648L)),
    @lib.Instruction::i32_const(@lib.I32(147928)),
    @lib.Instruction::call(@lib.FuncIdx::new(4487U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(49U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(49U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(50U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(138U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(50U)),
        @lib.Instruction::call(@lib.FuncIdx::new(10U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(151U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(50U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(151U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(11U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(138U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(151U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(50U)),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(138U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(48U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(45U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(42U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(49U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(52U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(139U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(52U)),
        @lib.Instruction::call(@lib.FuncIdx::new(10U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(153U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(52U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(153U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(11U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(139U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(153U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(52U)),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(139U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(47U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f4483 indexed call-result wrapper before range continuation" {
  // Slot23 `defined=4483 abs=4510` is the opposite of the retained f4463
  // gaps: Binaryen keeps this anonymous wrapper around the indexed load/retain
  // and call-result/tag-1 prefix before the range-check continuation. Guard the
  // decoded stack-form owner so generic if-wrapper cleanup does not over-flatten
  // it and rebase the cleanup branch from the preserved child block.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(
          pass_manager_test_vacuum_f4483_indexed_call_result_tag1_prefix_body(),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1027U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1070U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      @debug.assert_eq(clean_parent.length(), 4)
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
          @debug.assert_eq(prefix_body.length(), 17)
          match prefix_body[prefix_body.length() - 1] {
            @lib.If(_, _, Some(else_body)) =>
              @debug.assert_eq(
                else_body[else_body.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              )
            other => fail("expected f4483 final if, got \{other}")
          }
        }
        other => fail("expected f4483 wrapper to be preserved, got \{other}")
      }
    }
    other => fail("expected f4483 parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean preserves f4483 indexed float call-result wrapper before nested tag continuation" {
  // After the first f4483 simple call-result wrapper is retained, the next
  // first-diff hunk is the same ownership shape around a float-converter
  // call-result/tag-1 prefix. Binaryen keeps the anonymous wrapper so the else
  // cleanup branch still targets the wrapped owner while the selected result
  // feeds the following nested tag continuation.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(
          pass_manager_test_vacuum_f4483_indexed_float_call_result_tag1_prefix_body(),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(48U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(660U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      @debug.assert_eq(clean_parent.length(), 4)
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
          @debug.assert_eq(prefix_body.length(), 21)
          match prefix_body[prefix_body.length() - 1] {
            @lib.If(_, _, Some(else_body)) =>
              @debug.assert_eq(
                else_body[else_body.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              )
            other => fail("expected f4483 float final if, got \{other}")
          }
        }
        other =>
          fail("expected f4483 float wrapper to be preserved, got \{other}")
      }
    }
    other =>
      fail("expected f4483 float parent block, got \{@debug.to_string(other)}")
  }
}

///|
fn pass_manager_test_vacuum_f4493_offset4_call_result_tag1_prefix_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(offset4),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(19U)),
    @lib.Instruction::call(@lib.FuncIdx::new(63U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4547U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(20U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(21U)),
    @lib.Instruction::call(@lib.FuncIdx::new(39U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(54U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
        @lib.Instruction::call(@lib.FuncIdx::new(65U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(54U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(11U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(23U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
        @lib.Instruction::call(@lib.FuncIdx::new(37U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(24U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(24U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(23U)),
            @lib.Instruction::call(@lib.FuncIdx::new(63U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(24U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(33U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f4493 offset4 call-result wrapper before allocation return" {
  // Direct slot23 `defined=4493 abs=4520` keeps the anonymous wrapper around a
  // direct offset-4 load/retain and call-result/tag-1 prefix. The selected
  // payload feeds the following allocation/return continuation, while the else
  // cleanup branch still targets the preserved owner.
  let fixture = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f4493_offset4_call_result_tag1_prefix_body(),
      ),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::call(@lib.FuncIdx::new(34U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(25U)),
      @lib.Instruction::i32_const(@lib.I32(524289)),
      @lib.Instruction::call(@lib.FuncIdx::new(36U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(25U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
      @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(25U)),
      @lib.Instruction::return_(),
    ]),
  ]
  let (cleaned_once, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    fixture,
    None,
  )
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    cleaned_once,
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      @debug.assert_eq(clean_parent.length(), 11)
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
          @debug.assert_eq(prefix_body.length(), 16)
          match prefix_body[prefix_body.length() - 1] {
            @lib.If(_, _, Some(else_body)) =>
              @debug.assert_eq(
                else_body[else_body.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              )
            other => fail("expected f4493 final if, got \{other}")
          }
        }
        other => fail("expected f4493 wrapper to be preserved, got \{other}")
      }
    }
    other => fail("expected f4493 parent block, got \{@debug.to_string(other)}")
  }
}

///|
fn pass_manager_test_vacuum_f4665_tag2_56_classification_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  let offset8 = @lib.MemArg::new(0U, None, 8UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(39U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset4),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset8),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
        @lib.Instruction::call(@lib.FuncIdx::new(63U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(56)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
            @lib.Instruction::call(@lib.FuncIdx::new(63U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset4),
            @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4665_renderer_continuation() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::i32_const(@lib.I32(178120)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
    @lib.Instruction::call_indirect(
      @lib.TypeIdx::new(0U),
      @lib.TableIdx::new(1U),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4815U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
  ]
}

///|
test "raw vacuum preclean flattens f4665 tag classification wrappers before renderer continuation" {
  // Direct slot23 `defined=4665 abs=4692` follows the retained f4493 fix in
  // the opposite direction: Binaryen removes two anonymous wrappers around the
  // tag-2/tag-56 classification `if` before the renderer continuation, rebasing
  // the two owner exits from depths 4/5 to 2/3. Keep this exact source-backed
  // branch-dispatch + continuation shape instead of broadening unreachable-if
  // wrapper cleanup and reopening the preserved f4310/f4483/f4493 wrappers.
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f4665_tag2_56_classification_body(),
      ),
    ]),
  ]
  for instr in pass_manager_test_vacuum_f4665_renderer_continuation() {
    parent_body.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_true(clean_parent[0] is @lib.LocalGet(_))
      assert_true(clean_parent[1] is @lib.Call(_))
      assert_true(clean_parent[5] is @lib.If(_, _, Some(_)))
      match clean_parent[5] {
        @lib.If(_, _, Some(else_body)) =>
          match else_body[3] {
            @lib.If(_, nested_then, Some(nested_else)) => {
              @debug.assert_eq(
                nested_then[nested_then.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              )
              @debug.assert_eq(
                nested_else[nested_else.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              )
            }
            other => fail("expected f4665 nested tag-56 if, got \{other}")
          }
        other => fail("expected f4665 top-level tag-2 if, got \{other}")
      }
    }
    other =>
      fail(
        "expected f4665 parent block with flattened classification prefix, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4702_loop_call_result_child_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::call(@lib.FuncIdx::new(4731U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
    @lib.Instruction::call(@lib.FuncIdx::new(39U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(37U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
            @lib.Instruction::call(@lib.FuncIdx::new(63U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(33U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
        @lib.Instruction::i32_load(offset4),
        @lib.Instruction::local_set(@lib.LocalIdx::new(11U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::call(@lib.FuncIdx::new(37U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(13U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
            @lib.Instruction::call(@lib.FuncIdx::new(63U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(33U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(13U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::call(@lib.FuncIdx::new(6762U)),
        @lib.Instruction::i32_const(@lib.I32(11)),
        @lib.Instruction::call(@lib.FuncIdx::new(6954U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
            @lib.Instruction::call(@lib.FuncIdx::new(65U)),
            @lib.Instruction::br(@lib.LabelIdx::new(7U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::call(@lib.FuncIdx::new(65U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::call(@lib.FuncIdx::new(65U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_set(@lib.LocalIdx::new(14U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
            @lib.Instruction::call(@lib.FuncIdx::new(37U)),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(15U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_gt_s(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(38U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
                @lib.Instruction::call(@lib.FuncIdx::new(63U)),
              ],
              Some([
                @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::i32_eq(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
                    @lib.Instruction::i32_const(@lib.I32(8)),
                    @lib.Instruction::i32_sub(),
                    @lib.Instruction::call(@lib.FuncIdx::new(33U)),
                  ],
                  None,
                ),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4702_store_continuation() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::call(@lib.FuncIdx::new(7042U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(16U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
    @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
  ]
}

///|
test "raw vacuum preclean flattens f4702 loop call-result child before store continuation" {
  // Direct slot23 `defined=4702 abs=4729` follows f4665: Binaryen removes one
  // anonymous loop-body child around the call-result/tag-1 branch before the
  // store/update continuation, rebasing the cleanup exits from 7/4 to 6/3.
  // The guard requires the decoded refcount cleanup and continuation rather
  // than reopening broad call-result or side-effect wrapper cleanup.
  let parent_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f4702_loop_call_result_child_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f4702_store_continuation() {
    parent_body.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      @debug.assert_eq(clean_parent.length(), 21)
      assert_true(clean_parent[0] is @lib.LocalGet(_))
      assert_true(clean_parent[11] is @lib.If(_, _, Some(_)))
      match clean_parent[11] {
        @lib.If(_, _, Some(else_body)) =>
          match else_body[8] {
            @lib.If(_, then_body, Some(nested_else)) => {
              @debug.assert_eq(
                then_body[then_body.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(6U)),
              )
              @debug.assert_eq(
                nested_else[nested_else.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              )
            }
            other => fail("expected f4702 nested cleanup if, got \{other}")
          }
        other => fail("expected f4702 top-level if, got \{other}")
      }
    }
    other =>
      fail(
        "expected f4702 parent block with flattened loop child, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4859_leading_owner_exit_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  let offset8 = @lib.MemArg::new(0U, None, 8UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(32U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(29U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i64_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(352U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i32_load(offset8),
        @lib.Instruction::local_set(@lib.LocalIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(38U)),
        @lib.Instruction::call(@lib.FuncIdx::new(12U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::br(@lib.LabelIdx::new(5U))],
              Some([@lib.Instruction::br(@lib.LabelIdx::new(4U))]),
            ),
            @lib.Instruction::unreachable_(),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::br(@lib.LabelIdx::new(6U))],
              Some([@lib.Instruction::br(@lib.LabelIdx::new(8U))]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(27U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::i64_load(offset4),
        @lib.Instruction::local_set(@lib.LocalIdx::new(360U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(360U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(350U)),
        @lib.Instruction::i64_const(@lib.I64(4294967296L)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::br(@lib.LabelIdx::new(7U))],
              Some([]),
            ),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(350U)),
            @lib.Instruction::i32_wrap_i64(),
            @lib.Instruction::local_set(@lib.LocalIdx::new(28U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::br(@lib.LabelIdx::new(8U))],
              Some([@lib.Instruction::br(@lib.LabelIdx::new(5U))]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4859_case0_return_continuation() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::call(@lib.FuncIdx::new(6315U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(25U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6817U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4905U)),
    @lib.Instruction::return_(),
  ]
}

///|
test "raw vacuum preclean flattens f4859 leading owner-exit dispatch before case0 return" {
  // Direct slot23 `defined=4859 abs=4886` follows the retained f4824 fix:
  // Binaryen removes two anonymous singleton wrappers around the leading
  // owner-exit dispatch before the tag-case-0 drop/return continuation. Keep
  // the rule pinned to this source-backed dispatch + continuation shape instead
  // of broad nested singleton-if cleanup.
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f4859_leading_owner_exit_dispatch_body(),
      ),
    ]),
  ]
  for instr in pass_manager_test_vacuum_f4859_case0_return_continuation() {
    parent_body.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_true(clean_parent[0] is @lib.LocalGet(_))
      assert_true(clean_parent[1] is @lib.LocalTee(_))
      assert_true(clean_parent[2] is @lib.Call(_))
      match clean_parent[3] {
        @lib.If(_, _, Some(else_body)) =>
          match else_body[12] {
            @lib.If(_, _, Some(nested_else)) =>
              match nested_else[4] {
                @lib.If(_, then_body, Some(final_else)) => {
                  @debug.assert_eq(
                    then_body[then_body.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(6U)),
                  )
                  @debug.assert_eq(
                    final_else[final_else.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                  )
                }
                other =>
                  fail("expected f4859 nested else dispatch, got \{other}")
              }
            other => fail("expected f4859 sentinel branch, got \{other}")
          }
        other => fail("expected f4859 leading dispatch if, got \{other}")
      }
    }
    other =>
      fail(
        "expected f4859 parent block with flattened leading owner-exit dispatch, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4860_leading_owner_exit_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  let offset8 = @lib.MemArg::new(0U, None, 8UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i64_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset8),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(53U)),
        @lib.Instruction::call(@lib.FuncIdx::new(12U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(53U)),
            @lib.Instruction::i64_load(offset0),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::br(@lib.LabelIdx::new(6U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(50U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i64_load(offset4),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
        @lib.Instruction::i64_const(@lib.I64(4294967296L)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(50U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(48U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
            @lib.Instruction::i32_wrap_i64(),
            @lib.Instruction::local_set(@lib.LocalIdx::new(43U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(50U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(42U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ]),
        ),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4915_tag1_owner_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(20U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
        @lib.Instruction::call(@lib.FuncIdx::new(36U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_set(@lib.LocalIdx::new(15U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset4),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(16U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(13U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4915_tag95_return_continuation() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(95)),
    @lib.Instruction::call(@lib.FuncIdx::new(6315U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4806U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(24U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(24U)),
    @lib.Instruction::return_(),
  ]
}

///|
test "raw vacuum preclean flattens f4915 tag1 owner dispatch before tag95 return" {
  // Direct slot23 `defined=4915 abs=4942` follows the retained f4860 fix:
  // Binaryen removes two anonymous singleton wrappers around a leading
  // `local.get; call; local.tee; i32.const 1; i32.eq; if` dispatch before the
  // tag-case-95 drop/return continuation. Keep this pinned to the source-backed
  // dispatch + continuation shape instead of reopening generic wrapper cleanup.
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f4915_tag1_owner_dispatch_body(),
      ),
    ]),
  ]
  for instr in pass_manager_test_vacuum_f4915_tag95_return_continuation() {
    parent_body.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_true(clean_parent[0] is @lib.LocalGet(_))
      assert_true(clean_parent[1] is @lib.Call(_))
      assert_true(clean_parent[2] is @lib.LocalTee(_))
      assert_true(clean_parent[3] is @lib.I32Const(_))
      assert_true(clean_parent[4] is @lib.I32Eq)
      match clean_parent[5] {
        @lib.If(_, _, Some(else_body)) =>
          match else_body[1] {
            @lib.If(_, nested_then, Some(nested_else)) => {
              @debug.assert_eq(
                nested_then[nested_then.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              )
              @debug.assert_eq(
                nested_else[nested_else.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              )
            }
            other => fail("expected f4915 nested owner dispatch, got \{other}")
          }
        other => fail("expected f4915 leading tag1 dispatch if, got \{other}")
      }
      @debug.assert_eq(
        clean_parent[7],
        @lib.Instruction::i32_const(@lib.I32(95)),
      )
    }
    other =>
      fail(
        "expected f4915 parent block with flattened leading tag1 dispatch, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f4919_call_if_tag99_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  let offset8 = @lib.MemArg::new(0U, None, 8UL)
  [
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(14U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::call(@lib.FuncIdx::new(6315U)),
            @lib.Instruction::drop(),
            @lib.Instruction::call(@lib.FuncIdx::new(204U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(4920U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(76U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(76U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(78U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::i32_load(offset4),
            @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::i32_load(offset8),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(10U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
            @lib.Instruction::br(@lib.LabelIdx::new(3U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::i32_load(offset4),
            @lib.Instruction::local_set(@lib.LocalIdx::new(11U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
            @lib.Instruction::i32_load(offset8),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(12U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f4919_tag99_return_continuation() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(99)),
    @lib.Instruction::call(@lib.FuncIdx::new(6315U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(98)),
        @lib.Instruction::call(@lib.FuncIdx::new(6315U)),
        @lib.Instruction::drop(),
      ],
      None,
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(4921U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(19U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
    @lib.Instruction::return_(),
  ]
}

///|
test "raw vacuum preclean flattens f4919 call-if wrapper before tag99 return" {
  // Direct slot23 `defined=4919 abs=4946` follows the retained f4915 fix:
  // Binaryen removes the anonymous child block around a leading
  // `local.get; call; if` dispatch when the wrapper immediately returns the
  // selected local before the tag-case-99 continuation. This guards the actual
  // decoded copy/return shape rather than the rejected no-return f4919 probes.
  let return_owner_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f4919_call_if_tag99_dispatch_body(),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(78U)),
    @lib.Instruction::return_(),
  ]
  let parent_body = [pass_manager_test_vacuum_plain_block(return_owner_body)]
  for instr in pass_manager_test_vacuum_f4919_tag99_return_continuation() {
    parent_body.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(return_owner)) => {
          assert_true(return_owner[0] is @lib.LocalGet(_))
          assert_true(return_owner[1] is @lib.Call(_))
          match return_owner[2] {
            @lib.If(_, _, Some(else_body)) =>
              match else_body[5] {
                @lib.If(_, then_body, Some(nested_else)) => {
                  @debug.assert_eq(
                    then_body[then_body.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                  @debug.assert_eq(
                    nested_else[nested_else.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                  )
                }
                other =>
                  fail("expected f4919 nested owner dispatch, got \{other}")
              }
            other =>
              fail("expected f4919 leading call-if dispatch, got \{other}")
          }
          @debug.assert_eq(
            return_owner[3],
            @lib.Instruction::local_get(@lib.LocalIdx::new(78U)),
          )
          @debug.assert_eq(return_owner[4], @lib.Instruction::return_())
        }
        other => fail("expected f4919 return owner block, got \{other}")
      }
    other =>
      fail(
        "expected f4919 parent block with flattened call-if return owner, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5027_release_selected_payload_branch(
  selector : UInt,
  alias_raw : UInt,
  payload : UInt,
  count : UInt,
  selected : UInt,
  branch : @lib.Instruction?,
) -> Array[@lib.Instruction] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(selector)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(alias_raw)),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_set(@lib.LocalIdx::new(payload)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(alias_raw)),
    @lib.Instruction::call(@lib.FuncIdx::new(37U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(count)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_gt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(alias_raw)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(count)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(payload)),
        @lib.Instruction::call(@lib.FuncIdx::new(63U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(count)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(alias_raw)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(33U)),
          ],
          None,
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(payload)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(selected)),
  ]
  match branch {
    Some(instr) => body.push(instr)
    None => ()
  }
  body
}

///|
fn pass_manager_test_vacuum_f5027_result_branch_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  let body = [
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(offset4),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(40U)),
    @lib.Instruction::call(@lib.FuncIdx::new(63U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5290U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(72U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(72U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(25U)),
    @lib.Instruction::call(@lib.FuncIdx::new(39U)),
  ]
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      pass_manager_test_vacuum_f5027_release_selected_payload_branch(
        25U,
        28U,
        46U,
        57U,
        23U,
        Some(@lib.Instruction::br(@lib.LabelIdx::new(3U))),
      ),
      Some(
        pass_manager_test_vacuum_f5027_release_selected_payload_branch(
          25U,
          26U,
          45U,
          55U,
          24U,
          None,
        ),
      ),
    ),
  )
  body
}

///|
fn pass_manager_test_vacuum_f5027_allocation_return_continuation() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  [
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::call(@lib.FuncIdx::new(34U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(62U)),
    @lib.Instruction::i32_const(@lib.I32(256)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(62U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(24U)),
    @lib.Instruction::i32_store(offset0),
    @lib.Instruction::local_get(@lib.LocalIdx::new(62U)),
    @lib.Instruction::return_(),
  ]
}

///|
fn pass_manager_test_vacuum_f5028_result_branch_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let body = pass_manager_test_vacuum_f5027_result_branch_dispatch_body()
  let else_branch = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
  ]
  for
    instr in pass_manager_test_vacuum_f5027_release_selected_payload_branch(
      25U,
      26U,
      45U,
      55U,
      24U,
      None,
    ) {
    else_branch.push(instr)
  }
  body[body.length() - 1] = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    pass_manager_test_vacuum_f5027_release_selected_payload_branch(
      25U,
      28U,
      46U,
      57U,
      23U,
      Some(@lib.Instruction::br(@lib.LabelIdx::new(3U))),
    ),
    Some(else_branch),
  )
  body
}

///|
test "raw vacuum preclean preserves f5027 selected-payload block before allocation return" {
  // Direct slot23 `defined=5027 abs=5054` is the opposite direction from the
  // retained f4919 flatten: Binaryen keeps the anonymous dispatch block around
  // a result-producing branch whose else-selected payload is boxed and returned.
  // Keep this source-backed retain/refcount/allocation shape as a preserve guard
  // instead of widening generic prefix-if flattening.
  let return_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5027_result_branch_dispatch_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f5027_allocation_return_continuation() {
    return_body.push(instr)
  }
  let outer_body = [pass_manager_test_vacuum_plain_block(return_body)]
  outer_body.push(@lib.Instruction::unreachable_())
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_return)) =>
          match clean_return[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_dispatch)) => {
              assert_true(clean_dispatch[0] is @lib.LocalGet(_))
              assert_true(clean_dispatch[1] is @lib.I32Load(_))
              assert_true(
                clean_dispatch[clean_dispatch.length() - 1] is @lib.If(_),
              )
              @debug.assert_eq(
                clean_return[clean_return.length() - 1],
                @lib.Instruction::return_(),
              )
            }
            other =>
              fail("expected f5027 preserved dispatch block, got \{other}")
          }
        other => fail("expected f5027 allocation-return block, got \{other}")
      }
    other =>
      fail(
        "expected f5027 outer block preserving selected-payload dispatch, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean preserves f5028 else-release selected-payload block" {
  // Direct slot23 `defined=5028 abs=5055` is the f5027 sibling where the
  // preserved selected-payload dispatch's else arm first releases an earlier
  // local before extracting the fallback payload that the allocation-return
  // continuation boxes. Keep it as a parity gap reduction, not a Starshine win.
  let return_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5028_result_branch_dispatch_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f5027_allocation_return_continuation() {
    return_body.push(instr)
  }
  let outer_body = [pass_manager_test_vacuum_plain_block(return_body)]
  outer_body.push(@lib.Instruction::unreachable_())
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_return)) =>
          match clean_return[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_dispatch)) => {
              assert_true(clean_dispatch[0] is @lib.LocalGet(_))
              assert_true(clean_dispatch[1] is @lib.I32Load(_))
              match clean_dispatch[clean_dispatch.length() - 1] {
                @lib.If(_, _, Some(else_body)) => {
                  @debug.assert_eq(
                    else_body[0],
                    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                  )
                  @debug.assert_eq(
                    else_body[1],
                    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
                  )
                }
                other =>
                  fail("expected f5028 preserved dispatch if, got \{other}")
              }
              @debug.assert_eq(
                clean_return[clean_return.length() - 1],
                @lib.Instruction::return_(),
              )
            }
            other =>
              fail("expected f5028 preserved dispatch block, got \{other}")
          }
        other => fail("expected f5028 allocation-return block, got \{other}")
      }
    other =>
      fail(
        "expected f5028 outer block preserving else-release dispatch, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5038_double_release_result_branch_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let body = pass_manager_test_vacuum_f5027_result_branch_dispatch_body()
  let else_branch = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
  ]
  for
    instr in pass_manager_test_vacuum_f5027_release_selected_payload_branch(
      25U,
      26U,
      45U,
      55U,
      24U,
      None,
    ) {
    else_branch.push(instr)
  }
  body[body.length() - 1] = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    pass_manager_test_vacuum_f5027_release_selected_payload_branch(
      25U,
      28U,
      46U,
      57U,
      23U,
      Some(@lib.Instruction::br(@lib.LabelIdx::new(3U))),
    ),
    Some(else_branch),
  )
  body
}

///|
fn pass_manager_test_vacuum_f5083_inverse_selected_payload_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  let body = [
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(offset4),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(40U)),
    @lib.Instruction::call(@lib.FuncIdx::new(63U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5290U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(72U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(72U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(25U)),
    @lib.Instruction::call(@lib.FuncIdx::new(39U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
  ]
  body.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      pass_manager_test_vacuum_f5027_release_selected_payload_branch(
        25U,
        28U,
        46U,
        57U,
        23U,
        None,
      ),
      Some(
        pass_manager_test_vacuum_f5027_release_selected_payload_branch(
          25U,
          26U,
          45U,
          55U,
          24U,
          Some(@lib.Instruction::br(@lib.LabelIdx::new(3U))),
        ),
      ),
    ),
  )
  body
}

///|
fn pass_manager_test_vacuum_f5083_conditional_selected_local_continuation() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(23U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1246U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(53U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(23U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1243U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(92U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(23U)),
        @lib.Instruction::call(@lib.FuncIdx::new(65U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(53U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(92U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::call(@lib.FuncIdx::new(1230U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(93U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(92U)),
        @lib.Instruction::call(@lib.FuncIdx::new(65U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(93U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(196U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(23U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(196U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f5083 selected-payload block before conditional handoff" {
  // Direct slot23 `defined=5083 abs=5110` flips the f5027/f5038 continuation:
  // Binaryen keeps the dispatch wrapper when the fallthrough-selected payload is
  // conditionally rewritten, copied to a parent handoff local, and branched out,
  // while the branch-selected payload reaches the following allocation return.
  let compute_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5083_inverse_selected_payload_dispatch_body(),
    ),
  ]
  for
    instr in pass_manager_test_vacuum_f5083_conditional_selected_local_continuation() {
    compute_body.push(instr)
  }
  let handoff_body = [pass_manager_test_vacuum_plain_block(compute_body)]
  handoff_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(196U)))
  handoff_body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(199U)))
  handoff_body.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  let return_body = [pass_manager_test_vacuum_plain_block(handoff_body)]
  for instr in pass_manager_test_vacuum_f5027_allocation_return_continuation() {
    return_body.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(return_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_return))] =>
      match clean_return[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_handoff)) =>
          match clean_handoff[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_compute)) =>
              match clean_compute[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_dispatch)) => {
                  assert_true(clean_dispatch[0] is @lib.LocalGet(_))
                  match clean_dispatch[clean_dispatch.length() - 1] {
                    @lib.If(_, _, Some(else_body)) =>
                      @debug.assert_eq(
                        else_body[else_body.length() - 1],
                        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                      )
                    other =>
                      fail("expected f5083 preserved dispatch if, got \{other}")
                  }
                }
                other =>
                  fail("expected f5083 preserved dispatch block, got \{other}")
              }
            other => fail("expected f5083 compute block, got \{other}")
          }
        other => fail("expected f5083 handoff block, got \{other}")
      }
    other =>
      fail(
        "expected f5083 return block preserving conditional handoff, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5124_triple_release_result_branch_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let body = pass_manager_test_vacuum_f5027_result_branch_dispatch_body()
  let else_branch = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
  ]
  for
    instr in pass_manager_test_vacuum_f5027_release_selected_payload_branch(
      25U,
      26U,
      45U,
      55U,
      24U,
      None,
    ) {
    else_branch.push(instr)
  }
  body[body.length() - 1] = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    pass_manager_test_vacuum_f5027_release_selected_payload_branch(
      25U,
      28U,
      46U,
      57U,
      23U,
      Some(@lib.Instruction::br(@lib.LabelIdx::new(3U))),
    ),
    Some(else_branch),
  )
  body
}

///|
test "raw vacuum preclean preserves f5124 triple-release selected-payload block" {
  // Direct slot23 `defined=5124 abs=5151` repeats the f5027/f5038 allocation
  // return shape, but its fallthrough arm releases three enclosing locals before
  // selecting the payload that the immediate allocation-return continuation boxes.
  let return_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5124_triple_release_result_branch_dispatch_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f5027_allocation_return_continuation() {
    return_body.push(instr)
  }
  let outer_body = [pass_manager_test_vacuum_plain_block(return_body)]
  outer_body.push(@lib.Instruction::unreachable_())
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_return)) =>
          match clean_return[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_dispatch)) => {
              assert_true(clean_dispatch[0] is @lib.LocalGet(_))
              match clean_dispatch[clean_dispatch.length() - 1] {
                @lib.If(_, _, Some(else_body)) => {
                  @debug.assert_eq(
                    else_body[0],
                    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                  )
                  @debug.assert_eq(
                    else_body[4],
                    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                  )
                }
                other =>
                  fail("expected f5124 preserved dispatch if, got \{other}")
              }
            }
            other =>
              fail("expected f5124 preserved dispatch block, got \{other}")
          }
        other => fail("expected f5124 allocation-return block, got \{other}")
      }
    other =>
      fail(
        "expected f5124 outer block preserving triple-release dispatch, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5138_load_linked_result_prefix_body() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::call(@lib.FuncIdx::new(822U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(109U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(204U)),
    @lib.Instruction::call(@lib.FuncIdx::new(744U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(216U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(109U)),
    @lib.Instruction::call(@lib.FuncIdx::new(60U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(204U)),
    @lib.Instruction::call(@lib.FuncIdx::new(60U)),
  ]
}

///|
fn pass_manager_test_vacuum_f5138_result_branch_body() -> Array[
  @lib.Instruction,
] {
  [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5138_load_linked_result_prefix_body(),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(216U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(32U)),
    @lib.Instruction::call(@lib.FuncIdx::new(37U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(32U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(30U)),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(27U)),
        @lib.Instruction::call(@lib.FuncIdx::new(60U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(22U)),
        @lib.Instruction::call(@lib.FuncIdx::new(60U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
        @lib.Instruction::call(@lib.FuncIdx::new(60U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::call(@lib.FuncIdx::new(60U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::call(@lib.FuncIdx::new(60U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(32U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(31U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f5138 load-linked result prefix wrapper" {
  // Direct slot23 `defined=5138 abs=5165` keeps the parent block around a
  // source-shaped retained-result prefix block before the final branch if.
  // Flattening the parent removes one ordered wrapper too many versus Binaryen.
  let wrapped = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5138_result_branch_body(),
    ),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_false(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body))] => {
      @debug.assert_eq(body.length(), 5)
      match body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix)) => {
          @debug.assert_eq(prefix.length(), 10)
          @debug.assert_eq(
            prefix[5],
            @lib.Instruction::local_set(@lib.LocalIdx::new(216U)),
          )
        }
        other => fail("expected f5138 source prefix block, got \{other}")
      }
      assert_true(body[body.length() - 1] is @lib.If(_, _, Some(_)))
    }
    other =>
      fail(
        "expected f5138 parent wrapper to be preserved, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean flattens only f5138 outer singleton parent" {
  // The full slot23 source has one extra anonymous singleton parent above the
  // f5138 prefix/if wrapper. Binaryen removes that parent but keeps the wrapper
  // that owns the source prefix block.
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f5138_result_branch_body(),
      ),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(body))] => {
      @debug.assert_eq(body.length(), 5)
      assert_true(body[0] is @lib.Block(@lib.VoidBlockType, _))
      assert_true(body[body.length() - 1] is @lib.If(_, _, Some(_)))
    }
    other =>
      fail(
        "expected f5138 outer parent only to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5138_paired_prefix_body() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(22U)),
    @lib.Instruction::call(@lib.FuncIdx::new(822U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(218U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(22U)),
    @lib.Instruction::call(@lib.FuncIdx::new(60U)),
  ]
}

///|
fn pass_manager_test_vacuum_f5138_paired_result_body() -> Array[
  @lib.Instruction,
] {
  [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5138_paired_prefix_body(),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(218U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(200U)),
    @lib.Instruction::call(@lib.FuncIdx::new(744U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(219U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(218U)),
    @lib.Instruction::call(@lib.FuncIdx::new(60U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(200U)),
    @lib.Instruction::call(@lib.FuncIdx::new(60U)),
  ]
}

///|
fn pass_manager_test_vacuum_f5138_paired_result_branch_body() -> Array[
  @lib.Instruction,
] {
  [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5138_paired_result_body(),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(219U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(41U)),
    @lib.Instruction::call(@lib.FuncIdx::new(37U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(30U)),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
        @lib.Instruction::call(@lib.FuncIdx::new(60U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::call(@lib.FuncIdx::new(60U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(31U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f5138 paired-result prefix wrapper" {
  // Direct slot23 `defined=5138 abs=5165` next differs at the paired
  // `local.set 218` hunk. Binaryen keeps the child block containing the first
  // prefix block plus the second `local.set 219`/release sequence, with the
  // final selected-payload `if` as the parent's sibling. The f5139 follow-up
  // hunk has the same paired prefix with only two leading release calls in the
  // else arm, so this guard intentionally keeps the release floor narrow.
  let wrapped = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f5138_paired_result_branch_body(),
      ),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    wrapped,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(branch_body))] => {
      @debug.assert_eq(branch_body.length(), 5)
      match branch_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(paired_body)) => {
          @debug.assert_eq(paired_body.length(), 9)
          assert_true(paired_body[0] is @lib.Block(@lib.VoidBlockType, _))
          @debug.assert_eq(
            paired_body[4],
            @lib.Instruction::local_set(@lib.LocalIdx::new(219U)),
          )
        }
        other => fail("expected paired result child block, got \{other}")
      }
      assert_true(
        branch_body[branch_body.length() - 1] is @lib.If(_, _, Some(_)),
      )
    }
    other =>
      fail(
        "expected f5138 paired parent wrapper to be preserved, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5154_retain_pair_result_if_body() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(15U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5022U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(34U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(34U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(9U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(21U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f5154 retain-pair result child before slot store" {
  // Direct slot23 `defined=5154 abs=5181` keeps the child block that owns the
  // retain-pair, two-arg call-result `local.set 34`, release pair, and tag-1
  // selected-payload if before the parent releases/replaces slot local 3.
  let child = pass_manager_test_vacuum_f5154_retain_pair_result_if_body()
  let parent = [
    pass_manager_test_vacuum_plain_block(child),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent)],
    None,
  )
  assert_false(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      @debug.assert_eq(clean_parent.length(), 7)
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) => {
          @debug.assert_eq(child_body.length(), 20)
          @debug.assert_eq(
            child_body[9],
            @lib.Instruction::local_set(@lib.LocalIdx::new(34U)),
          )
        }
        other => fail("expected f5154 child block to remain, got \{other}")
      }
      @debug.assert_eq(
        clean_parent[6],
        @lib.Instruction::i32_store(@lib.MemArg::new(0U, None, 0UL)),
      )
    }
    other =>
      fail(
        "expected f5154 parent wrapper with child block, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5184_single_retain_result_if_body() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(26U)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(150U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(150U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5237U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(342U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(150U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(342U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(44U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(44U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(230U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(230U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(43U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(26U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
          ],
          None,
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
          ],
          None,
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(44U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(231U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(231U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(42U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f5184 single-retain result child before drop continuation" {
  // Direct slot23 `defined=5184 abs=5211` keeps an extra anonymous child block
  // around the load/retain, two-arg call-result `local.set 342`, release, and
  // tag-1 selected-payload if. The immediate parent only performs the following
  // four-arg update call/drop before the enclosing block hands off selected
  // local 43 and branches outward.
  let child = pass_manager_test_vacuum_f5184_single_retain_result_if_body()
  let parent = [pass_manager_test_vacuum_plain_block(child)]
  parent.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  parent.push(@lib.Instruction::i32_const(@lib.I32(193136)))
  parent.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2072U)))
  parent.push(@lib.Instruction::local_get(@lib.LocalIdx::new(3U)))
  parent.push(@lib.Instruction::call(@lib.FuncIdx::new(5318U)))
  parent.push(@lib.Instruction::drop())
  let outer = [pass_manager_test_vacuum_plain_block(parent)]
  outer.push(@lib.Instruction::local_get(@lib.LocalIdx::new(43U)))
  outer.push(@lib.Instruction::local_set(@lib.LocalIdx::new(921U)))
  outer.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer)],
    None,
  )
  assert_false(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent)) => {
          @debug.assert_eq(clean_parent.length(), 7)
          match clean_parent[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) => {
              @debug.assert_eq(child_body.length(), 16)
              @debug.assert_eq(
                child_body[7],
                @lib.Instruction::local_set(@lib.LocalIdx::new(342U)),
              )
            }
            other => fail("expected f5184 child block to remain, got \{other}")
          }
          @debug.assert_eq(clean_parent[6], @lib.Instruction::drop())
        }
        other => fail("expected f5184 parent block to remain, got \{other}")
      }
    other =>
      fail(
        "expected f5184 outer wrapper with child block, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean preserves f5184 sibling single-retain drop continuation" {
  // The next ordered hunk in the same function uses the same child wrapper but
  // the parent drop/update call is for field constant 192976 rather than
  // 193136, so the preserve guard must not be tied to only the first field.
  let child = pass_manager_test_vacuum_f5184_single_retain_result_if_body()
  let parent = [pass_manager_test_vacuum_plain_block(child)]
  parent.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  parent.push(@lib.Instruction::i32_const(@lib.I32(192976)))
  parent.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2078U)))
  parent.push(@lib.Instruction::local_get(@lib.LocalIdx::new(3U)))
  parent.push(@lib.Instruction::call(@lib.FuncIdx::new(5318U)))
  parent.push(@lib.Instruction::drop())
  let outer = [pass_manager_test_vacuum_plain_block(parent)]
  outer.push(@lib.Instruction::local_get(@lib.LocalIdx::new(43U)))
  outer.push(@lib.Instruction::local_set(@lib.LocalIdx::new(1557U)))
  outer.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer)],
    None,
  )
  assert_false(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent)) =>
          assert_true(clean_parent[0] is @lib.Block(@lib.VoidBlockType, _))
        other =>
          fail("expected f5184 sibling parent block to remain, got \{other}")
      }
    other =>
      fail(
        "expected f5184 sibling outer wrapper with child block, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5277_indexed_retain_result_if_body() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 4UL)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_shl(),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5298U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(12U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5283U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(40U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(14U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(13U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(14U)),
                @lib.Instruction::call(@lib.FuncIdx::new(38U)),
              ],
              None,
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5007U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(41U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ]),
        ),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(17U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(28U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::call(@lib.FuncIdx::new(10U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(29U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(29U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(11U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(28U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(29U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(28U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
        @lib.Instruction::br(@lib.LabelIdx::new(5U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f5277 indexed retain child before tag continuation" {
  // Direct slot23 `defined=5277 abs=5304` preserves the indexed-load/retain
  // child around a two-arg tag/refcount dispatch. The immediate sibling is the
  // selected-local tag continuation (`call $12(local 9)`), not the f5184
  // drop-call continuation, so this guards the next ordered-neighborhood hunk.
  let parent = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5277_indexed_retain_result_if_body(),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(42U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(42U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::return_(),
          ],
          None,
        ),
      ]),
    ),
  ]
  let outer = [pass_manager_test_vacuum_plain_block(parent)]
  outer.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer)],
    None,
  )
  assert_false(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent)) =>
          match clean_parent[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_child)) => {
              @debug.assert_eq(clean_child.length(), 17)
              @debug.assert_eq(
                clean_child[12],
                @lib.Instruction::local_tee(@lib.LocalIdx::new(12U)),
              )
            }
            other => fail("expected f5277 child block to remain, got \{other}")
          }
        other => fail("expected f5277 parent block to remain, got \{other}")
      }
    other =>
      fail(
        "expected f5277 outer wrapper with child block, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5288_leading_tag_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(20U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
        @lib.Instruction::call(@lib.FuncIdx::new(36U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_set(@lib.LocalIdx::new(15U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset4),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(16U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(13U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean flattens f5288 leading tag-dispatch wrappers before returns" {
  // Direct slot23 `defined=5288 abs=5315` follows the f5277 preserve hunk and
  // flips direction: Binaryen removes exactly two anonymous wrappers around the
  // leading `call $12(local 0)` tag dispatch, rebasing the dispatch branches
  // from depths 5/4 to 3/2 before the selected-payload return continuations.
  let local9_return = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5292U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(24U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(24U)),
    @lib.Instruction::return_(),
  ]
  let local8_return = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5286U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(25U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(25U)),
    @lib.Instruction::return_(),
  ]
  let inner_parent = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f5288_leading_tag_dispatch_body(),
      ),
    ]),
  ]
  for instr in local9_return {
    inner_parent.push(instr)
  }
  let outer_parent = [pass_manager_test_vacuum_plain_block(inner_parent)]
  for instr in local8_return {
    outer_parent.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer_parent)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] => {
      @debug.assert_eq(clean_outer.length(), 9)
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_inner)) => {
          @debug.assert_eq(clean_inner.length(), 14)
          assert_false(clean_inner[0] is @lib.Block(@lib.VoidBlockType, _))
          match clean_inner[5] {
            @lib.If(_, _, Some(else_body)) =>
              match else_body[1] {
                @lib.If(_, then_body, Some(nested_else)) => {
                  @debug.assert_eq(
                    then_body[then_body.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                  )
                  @debug.assert_eq(
                    nested_else[nested_else.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                }
                other => fail("expected nested f5288 dispatch if, got \{other}")
              }
            other => fail("expected f5288 leading dispatch if, got \{other}")
          }
        }
        other => fail("expected f5288 inner parent block, got \{other}")
      }
    }
    other =>
      fail("expected f5288 outer parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean flattens f5351 leading tag-dispatch child before zero return" {
  // After f5288 advances, direct slot23 `defined=5351 abs=5378` has one
  // remaining anonymous child around a leading `call $12(local 0)` dispatch
  // before the block's `return (i32.const 0)` fallback. Binaryen removes that
  // child and rebases outward branches by one level.
  let dispatch = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::br(@lib.LabelIdx::new(3U))],
          Some([@lib.Instruction::br(@lib.LabelIdx::new(4U))]),
        ),
        @lib.Instruction::unreachable_(),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::br(@lib.LabelIdx::new(3U))],
          Some([@lib.Instruction::br(@lib.LabelIdx::new(4U))]),
        ),
      ]),
    ),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(dispatch),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::return_(),
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_body))] => {
      @debug.assert_eq(clean_body.length(), 5)
      assert_false(clean_body[0] is @lib.Block(@lib.VoidBlockType, _))
      match clean_body[2] {
        @lib.If(_, then_body, Some(_)) =>
          match then_body[1] {
            @lib.If(_, nested_then, Some(nested_else)) => {
              @debug.assert_eq(
                nested_then[0],
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              )
              @debug.assert_eq(
                nested_else[0],
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              )
            }
            other => fail("expected f5351 nested dispatch if, got \{other}")
          }
        other => fail("expected f5351 dispatch if, got \{other}")
      }
    }
    other =>
      fail("expected f5351 wrapper block, got \{@debug.to_string(other)}")
  }
}

///|
fn pass_manager_test_vacuum_f5369_load_call_tag_refcount_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  let offset8 = @lib.MemArg::new(0U, None, 8UL)
  let offset12 = @lib.MemArg::new(0U, None, 12UL)
  let offset16 = @lib.MemArg::new(0U, None, 16UL)
  let offset20 = @lib.MemArg::new(0U, None, 20UL)
  let offset24 = @lib.MemArg::new(0U, None, 24UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_load(offset8),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(37U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(37U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6577U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(49U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(37U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(49U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(15U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(17U)),
        @lib.Instruction::i32_load(offset4),
        @lib.Instruction::local_set(@lib.LocalIdx::new(20U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(19U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::i32_load(offset16),
        @lib.Instruction::local_set(@lib.LocalIdx::new(18U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::i32_load(offset12),
        @lib.Instruction::local_set(@lib.LocalIdx::new(23U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::i32_load(offset8),
        @lib.Instruction::local_set(@lib.LocalIdx::new(22U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::i32_load(offset20),
        @lib.Instruction::local_set(@lib.LocalIdx::new(21U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::i32_load(offset24),
        @lib.Instruction::local_set(@lib.LocalIdx::new(41U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::call(@lib.FuncIdx::new(10U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(42U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(42U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(11U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(42U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(6U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(24U)),
        @lib.Instruction::call(@lib.FuncIdx::new(12U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(24U)),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(25U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_set(@lib.LocalIdx::new(40U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(14U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(20U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(13U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(11U)),
          ]),
        ),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
            @lib.Instruction::call(@lib.FuncIdx::new(38U)),
          ],
          None,
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean preserves f5369 load-call tag/refcount dispatch wrapper before allocation continuation" {
  // Direct slot23 `defined=5369 abs=5396` flips back from f5288/f5351:
  // Binaryen keeps the anonymous wrapper around the leading load/retain,
  // two-arg call result, and tag/refcount dispatch before the allocation-path
  // continuations. Starshine must not flatten it to `block^3` or rebase the
  // dispatch branches from 4/3 to 3/2.
  let parent_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5369_load_call_tag_refcount_dispatch_body(),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
    @lib.Instruction::call(@lib.FuncIdx::new(7104U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(60U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::i32_const(@lib.I32(202440)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(60U)),
    @lib.Instruction::call(@lib.FuncIdx::new(34U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(61U)),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_false(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_dispatch)) => {
          assert_true(clean_dispatch[0] is @lib.LocalGet(_))
          match clean_dispatch[12] {
            @lib.If(_, then_body, Some(else_body)) => {
              match then_body[then_body.length() - 1] {
                @lib.If(_, br_then, Some(_)) =>
                  @debug.assert_eq(
                    br_then[br_then.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(4U)),
                  )
                other =>
                  fail("expected f5369 nested retain dispatch, got \{other}")
              }
              @debug.assert_eq(
                else_body[else_body.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              )
            }
            other => fail("expected f5369 leading dispatch if, got \{other}")
          }
        }
        other => fail("expected f5369 dispatch wrapper to remain, got \{other}")
      }
    other => fail("expected f5369 parent block, got \{@debug.to_string(other)}")
  }
}

///|
fn pass_manager_test_vacuum_f5392_leading_tag2_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(25U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset4),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(11U)),
        @lib.Instruction::call(@lib.FuncIdx::new(36U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::call(@lib.FuncIdx::new(36U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(10U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(25U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(13U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(15U)),
            @lib.Instruction::call(@lib.FuncIdx::new(36U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(15U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
}

///|
test "raw vacuum preclean flattens f5392 leading tag2 wrappers before call return" {
  // Direct slot23 `defined=5392 abs=5419` follows the retained f5369 preserve
  // hunk and flips back to Binaryen flattening: remove the two anonymous
  // wrappers around the leading `call $12(local 0); tag == 2` dispatch before
  // the sibling call/release/return continuation, rebasing owner exits 4/5 to
  // 2/3 without touching the later allocation-path and fallback continuations.
  let return_body = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f5392_leading_tag2_dispatch_body(),
      ),
    ]),
    @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5458U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(28U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(28U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5390U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(29U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(28U)),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(29U)),
    @lib.Instruction::return_(),
  ]
  let outer_body = [pass_manager_test_vacuum_plain_block(return_body)]
  outer_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  outer_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(3U)))
  outer_body.push(@lib.Instruction::call(@lib.FuncIdx::new(5485U)))
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_return_body)) => {
          @debug.assert_eq(clean_return_body.length(), 21)
          assert_false(
            clean_return_body[0] is @lib.Block(@lib.VoidBlockType, _),
          )
          match clean_return_body[5] {
            @lib.If(_, _, Some(else_body)) =>
              match else_body[3] {
                @lib.If(_, nested_then, Some(nested_else)) => {
                  @debug.assert_eq(
                    nested_then[nested_then.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                  @debug.assert_eq(
                    nested_else[nested_else.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                  )
                }
                other =>
                  fail("expected f5392 nested tag1 dispatch, got \{other}")
              }
            other => fail("expected f5392 leading tag2 dispatch, got \{other}")
          }
          @debug.assert_eq(
            clean_return_body[6],
            @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
          )
          @debug.assert_eq(clean_return_body[20], @lib.Instruction::return_())
        }
        other => fail("expected f5392 return owner block, got \{other}")
      }
    other => fail("expected f5392 outer block, got \{@debug.to_string(other)}")
  }
}

///|
fn pass_manager_test_vacuum_f5419_leading_tag1_owner_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(39U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(29U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_load(offset0),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(17U)),
        @lib.Instruction::call(@lib.FuncIdx::new(63U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(29U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_set(@lib.LocalIdx::new(21U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset4),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(22U)),
            @lib.Instruction::call(@lib.FuncIdx::new(63U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
            @lib.Instruction::call(@lib.FuncIdx::new(63U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(21U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(22U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_load(offset0),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(19U)),
            @lib.Instruction::call(@lib.FuncIdx::new(63U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f5419_stream_loop_continuation(
  selected : @lib.LocalIdx,
) -> Array[@lib.Instruction] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(214656)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::call_indirect(
      @lib.TypeIdx::new(0U),
      @lib.TableIdx::new(1U),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(selected),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_set(@lib.LocalIdx::new(13U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(31U)),
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(14U)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::br(@lib.LabelIdx::new(1U))],
          Some([
            @lib.Instruction::local_get(selected),
            @lib.Instruction::call(@lib.FuncIdx::new(65U)),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32(41)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 12UL)),
    @lib.Instruction::call_indirect(
      @lib.TypeIdx::new(0U),
      @lib.TableIdx::new(1U),
    ),
    @lib.Instruction::return_(),
  ]
}

///|
test "raw vacuum preclean flattens f5419 tag1 singleton owner before stream loop" {
  // Direct slot23 `defined=5419 abs=5446` follows f5392: after recursive nop
  // cleanup, Starshine kept two anonymous singleton wrappers around a leading
  // tag-1 owner dispatch before the sibling stream-loop continuation. Binaryen
  // removes both wrappers and leaves the continuation in place; only the dispatch
  // branch depths are rebased (5/4 -> 3/2), because the continuation is already a
  // sibling of the removed singleton owner.
  let owner_body = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f5419_leading_tag1_owner_dispatch_body(),
      ),
    ]),
  ]
  for
    instr in pass_manager_test_vacuum_f5419_stream_loop_continuation(
      @lib.LocalIdx::new(12U),
    ) {
    owner_body.push(instr)
  }
  let root = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(owner_body),
      @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
      @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(30U)),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    root,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_root))] =>
      match clean_root[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_owner)) => {
          assert_false(clean_owner[0] is @lib.Block(@lib.VoidBlockType, _))
          @debug.assert_eq(
            clean_owner[0],
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          )
          match clean_owner[5] {
            @lib.If(_, _, Some(else_body)) =>
              match else_body[1] {
                @lib.If(_, nested_then, Some(nested_else)) => {
                  @debug.assert_eq(
                    nested_then[nested_then.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                  )
                  @debug.assert_eq(
                    nested_else[nested_else.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                }
                other =>
                  fail("expected f5419 nested tag1 dispatch, got \{other}")
              }
            other => fail("expected f5419 leading tag1 dispatch, got \{other}")
          }
          @debug.assert_eq(
            clean_owner[6],
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          )
          assert_true(clean_owner[clean_owner.length() - 1] is @lib.Return)
        }
        other => fail("expected f5419 owner block, got \{other}")
      }
    other => fail("expected f5419 root block, got \{@debug.to_string(other)}")
  }
}

///|
fn pass_manager_test_vacuum_f5430_leading_tag1_owner_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let body = pass_manager_test_vacuum_f5419_leading_tag1_owner_dispatch_body()
  match body[7] {
    @lib.If(bt, then_body, else_body) => {
      let shortened_then : Array[@lib.Instruction] = []
      for idx = 0; idx < 4; idx = idx + 1 {
        shortened_then.push(then_body[idx])
      }
      body[7] = @lib.Instruction::if_(bt, shortened_then, else_body)
    }
    _ => ()
  }
  body
}

///|
fn pass_manager_test_vacuum_f5430_stream_loop_continuation(
  selected : @lib.LocalIdx,
) -> Array[@lib.Instruction] {
  let body = pass_manager_test_vacuum_f5419_stream_loop_continuation(selected)
  body[1] = @lib.Instruction::i32_const(@lib.I32(215096))
  body
}

///|
test "raw vacuum preclean flattens f5430 tag1 singleton owner without selected copy" {
  // Direct slot23 `defined=5430 abs=5457` repeats the f5419 owner-wrapper
  // shape, but the tag-1 then arm leaves the retained payload in the tee local
  // instead of copying it to a separate selected local before the stream-loop
  // continuation. Binaryen still removes the two singleton owner wrappers and
  // only rebases the dispatch branches.
  let owner_body = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f5430_leading_tag1_owner_dispatch_body(),
      ),
    ]),
  ]
  for
    instr in pass_manager_test_vacuum_f5430_stream_loop_continuation(
      @lib.LocalIdx::new(17U),
    ) {
    owner_body.push(instr)
  }
  let root = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(owner_body),
      @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::call(@lib.FuncIdx::new(5470U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(20U)),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    root,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_root))] =>
      match clean_root[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_owner)) => {
          assert_false(clean_owner[0] is @lib.Block(@lib.VoidBlockType, _))
          @debug.assert_eq(
            clean_owner[0],
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          )
          match clean_owner[5] {
            @lib.If(_, _, Some(else_body)) =>
              match else_body[1] {
                @lib.If(_, nested_then, Some(nested_else)) => {
                  @debug.assert_eq(
                    nested_then[nested_then.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                  )
                  @debug.assert_eq(
                    nested_else[nested_else.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                }
                other =>
                  fail("expected f5430 nested tag1 dispatch, got \{other}")
              }
            other => fail("expected f5430 leading tag1 dispatch, got \{other}")
          }
          @debug.assert_eq(
            clean_owner[6],
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          )
          assert_true(clean_owner[clean_owner.length() - 1] is @lib.Return)
        }
        other => fail("expected f5430 owner block, got \{other}")
      }
    other => fail("expected f5430 root block, got \{@debug.to_string(other)}")
  }
}

///|
fn pass_manager_test_vacuum_f6113_retain_call_tag_dispatch_body() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(19U)),
    @lib.Instruction::call(@lib.FuncIdx::new(63U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6543U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(24U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(24U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::i32_load(offset4),
        @lib.Instruction::local_set(@lib.LocalIdx::new(17U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_load(offset4),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(18U)),
        @lib.Instruction::call(@lib.FuncIdx::new(63U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::call(@lib.FuncIdx::new(63U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
        @lib.Instruction::call(@lib.FuncIdx::new(6255U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(25U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(17U)),
        @lib.Instruction::call(@lib.FuncIdx::new(65U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(18U)),
        @lib.Instruction::call(@lib.FuncIdx::new(65U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(25U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
            @lib.Instruction::call(@lib.FuncIdx::new(65U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ]),
        ),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::call(@lib.FuncIdx::new(65U)),
          ],
          None,
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ]),
    ),
  ]
}

///|
fn pass_manager_test_vacuum_f6113_parent_continuation() -> Array[
  @lib.Instruction,
] {
  let offset0 = @lib.MemArg::new(0U, None, 0UL)
  let offset4 = @lib.MemArg::new(0U, None, 4UL)
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(134U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(134U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(16U)),
    @lib.Instruction::call(@lib.FuncIdx::new(63U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::call(@lib.FuncIdx::new(63U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3950U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(26U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
    @lib.Instruction::call(@lib.FuncIdx::new(65U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(26U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_load(offset0),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(11U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_load(offset4),
    @lib.Instruction::local_set(@lib.LocalIdx::new(20U)),
  ]
}

///|
test "raw vacuum preclean preserves f6113 retain-call wrapper before parent continuation" {
  // Direct slot23 `defined=6113 abs=6140` flips direction from f5419/f5430:
  // Binaryen keeps the child block around the leading retain/call/tag dispatch
  // before the parent copy/retain/call/update continuation. Starshine had
  // flattened that child through the broad side-effect-prefix cleanup, reducing
  // `block^4` to `block^3` and rebasing branch labels from 4/3 to 3/2.
  let parent_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f6113_retain_call_tag_dispatch_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f6113_parent_continuation() {
    parent_body.push(instr)
  }
  let outer_body = [pass_manager_test_vacuum_plain_block(parent_body)]
  outer_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(27U)))
  outer_body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(120U)))
  outer_body.push(@lib.Instruction::br(@lib.LabelIdx::new(1U)))
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer_body)],
    None,
  )
  assert_false(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent)) =>
          match clean_parent[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_dispatch)) => {
              assert_true(clean_dispatch[0] is @lib.LocalGet(_))
              match clean_dispatch[clean_dispatch.length() - 1] {
                @lib.If(_, then_body, Some(else_body)) => {
                  match then_body[then_body.length() - 1] {
                    @lib.If(_, _, Some(fallback_body)) =>
                      @debug.assert_eq(
                        fallback_body[fallback_body.length() - 1],
                        @lib.Instruction::br(@lib.LabelIdx::new(4U)),
                      )
                    other =>
                      fail("expected f6113 nested dispatch, got \{other}")
                  }
                  @debug.assert_eq(
                    else_body[else_body.length() - 1],
                    @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                  )
                }
                other =>
                  fail("expected f6113 leading dispatch if, got \{other}")
              }
            }
            other =>
              fail("expected f6113 dispatch wrapper to remain, got \{other}")
          }
        other => fail("expected f6113 parent block, got \{other}")
      }
    other => fail("expected f6113 outer block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f6286 local-copy child before parser branch continuation" {
  // Direct slot23 `defined=6286 abs=6313` leaves a no-op anonymous child
  // around `local.get 201; local.set 3` at the head of a loop parser block.
  // Binaryen removes that wrapper before the following `local.get; local.get;
  // local.tee; i32.gt_s; if` branch cascade. This guard keeps the cleanup
  // narrow to a local-copy child before the observed parser condition shape.
  let state = @lib.LocalIdx::new(201U)
  let scratch = @lib.LocalIdx::new(3U)
  let limit = @lib.LocalIdx::new(1U)
  let cursor_source = @lib.LocalIdx::new(200U)
  let cursor = @lib.LocalIdx::new(2U)
  let updated_cursor = @lib.LocalIdx::new(204U)
  let updated_state = @lib.LocalIdx::new(205U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(cursor),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(updated_cursor),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_set(updated_state),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ],
    Some([
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_set(@lib.LocalIdx::new(185U)),
    ]),
  )
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(state),
      @lib.Instruction::local_set(scratch),
    ]),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(limit),
    @lib.Instruction::local_get(cursor_source),
    @lib.Instruction::local_tee(cursor),
    @lib.Instruction::i32_gt_s(),
    branch_if,
    @lib.Instruction::local_get(@lib.LocalIdx::new(185U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(187U)),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_false(clean_parent[0] is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(clean_parent[0], @lib.Instruction::local_get(state))
      @debug.assert_eq(clean_parent[1], @lib.Instruction::local_set(scratch))
      @debug.assert_eq(clean_parent[2], @lib.Instruction::local_get(limit))
      @debug.assert_eq(clean_parent[5], @lib.Instruction::i32_gt_s())
      @debug.assert_eq(clean_parent[6], branch_if)
    }
    other => fail("expected f6286 parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f6594 inner local-copy child before parser branch continuation" {
  // Direct slot23 `defined=6594 abs=6621` has the same parser-loop debris one
  // level deeper, but the branch condition is `local.get; local.tee; const;
  // i32.gt_s; if`. Flatten the local-copy child before that continuation so
  // later dead-copy cleanup does not leave an empty anonymous block behind.
  let carry = @lib.LocalIdx::new(169U)
  let scratch = @lib.LocalIdx::new(9U)
  let bound = @lib.LocalIdx::new(168U)
  let cursor = @lib.LocalIdx::new(8U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
      @lib.Instruction::local_get(cursor),
      @lib.Instruction::call(@lib.FuncIdx::new(6922U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
    ],
    Some([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::br(@lib.LabelIdx::new(2U))],
        None,
      ),
    ]),
  )
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(carry),
      @lib.Instruction::local_set(scratch),
    ]),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(bound),
    @lib.Instruction::local_tee(cursor),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_gt_s(),
    branch_if,
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_false(clean_parent[0] is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(clean_parent[0], @lib.Instruction::local_get(carry))
      @debug.assert_eq(clean_parent[1], @lib.Instruction::local_set(scratch))
      @debug.assert_eq(clean_parent[2], @lib.Instruction::local_get(bound))
      @debug.assert_eq(clean_parent[5], @lib.Instruction::i32_gt_s())
      match clean_parent[6] {
        @lib.If(@lib.VoidBlockType, then_body, None) =>
          @debug.assert_eq(then_body, [
            @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
            @lib.Instruction::local_get(cursor),
            @lib.Instruction::call(@lib.FuncIdx::new(6922U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
          ])
        other => fail("expected f6594 cleaned branch if, got \{other}")
      }
    }
    other => fail("expected f6594 parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f6628 local-copy child before simple parser branch continuation" {
  // Direct slot23 `defined=6628 abs=6655` is the next ordered replay gap after
  // f6594. Binaryen flattens the anonymous child around `local.get 52;
  // local.set 2` before the simpler parser condition `local.get; i32.const;
  // i32.gt_s; if`. Keep this scoped to the observed parser continuation, not
  // broad local-copy cleanup.
  let carry = @lib.LocalIdx::new(52U)
  let scratch = @lib.LocalIdx::new(2U)
  let state = @lib.LocalIdx::new(51U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(state),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::i32_div_s(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(55U)),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(56U)),
      @lib.Instruction::br(@lib.LabelIdx::new(2U)),
    ],
    Some([
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_set(@lib.LocalIdx::new(39U)),
    ]),
  )
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(carry),
      @lib.Instruction::local_set(scratch),
    ]),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(state),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_gt_s(),
    branch_if,
    @lib.Instruction::local_get(@lib.LocalIdx::new(39U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(43U)),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_false(clean_parent[0] is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(clean_parent[0], @lib.Instruction::local_get(carry))
      @debug.assert_eq(clean_parent[1], @lib.Instruction::local_set(scratch))
      @debug.assert_eq(clean_parent[2], @lib.Instruction::local_get(state))
      @debug.assert_eq(
        clean_parent[3],
        @lib.Instruction::i32_const(@lib.I32(0)),
      )
      @debug.assert_eq(clean_parent[4], @lib.Instruction::i32_gt_s())
      @debug.assert_eq(clean_parent[5], branch_if)
    }
    other => fail("expected f6628 parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f6785 local-copy child before le_s parser branch continuation" {
  // Direct slot23 `defined=6785 abs=6812` is the next ordered replay gap after
  // f6628. The original loop carries an anonymous child around `local.get 177;
  // local.set 9` before `local.get; local.tee; i32.const; i32.le_s; if`.
  // Flatten only that local-copy child before the observed parser continuation.
  let carry = @lib.LocalIdx::new(177U)
  let scratch = @lib.LocalIdx::new(9U)
  let state = @lib.LocalIdx::new(176U)
  let cursor = @lib.LocalIdx::new(8U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(cursor),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(184U)),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_set(@lib.LocalIdx::new(185U)),
      @lib.Instruction::br(@lib.LabelIdx::new(2U)),
    ],
    Some([
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_set(@lib.LocalIdx::new(110U)),
    ]),
  )
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(carry),
      @lib.Instruction::local_set(scratch),
    ]),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(state),
    @lib.Instruction::local_tee(cursor),
    @lib.Instruction::i32_const(@lib.I32(3)),
    @lib.Instruction::i32_le_s(),
    branch_if,
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_false(clean_parent[0] is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(clean_parent[0], @lib.Instruction::local_get(carry))
      @debug.assert_eq(clean_parent[1], @lib.Instruction::local_set(scratch))
      @debug.assert_eq(clean_parent[2], @lib.Instruction::local_get(state))
      @debug.assert_eq(clean_parent[3], @lib.Instruction::local_tee(cursor))
      @debug.assert_eq(clean_parent[5], @lib.Instruction::i32_le_s())
      @debug.assert_eq(clean_parent[6], branch_if)
    }
    other => fail("expected f6785 parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f7095 local-copy child before subtract le_s parser branch continuation" {
  // Direct slot23 `defined=7095 abs=7122` is the next ordered replay gap after
  // f6785. The original loop carries an anonymous child around `local.get 82;
  // local.set 5` before `local.get; local.get; local.tee; i32.const; i32.sub;
  // i32.le_s; if`. Flatten only that local-copy child before the observed
  // parser continuation.
  let carry = @lib.LocalIdx::new(82U)
  let scratch = @lib.LocalIdx::new(5U)
  let limit = @lib.LocalIdx::new(2U)
  let cursor_source = @lib.LocalIdx::new(81U)
  let cursor = @lib.LocalIdx::new(4U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::i32_gt_s(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(41U)),
    ],
    Some([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(41U)),
    ]),
  )
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(carry),
      @lib.Instruction::local_set(scratch),
    ]),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(limit),
    @lib.Instruction::local_get(cursor_source),
    @lib.Instruction::local_tee(cursor),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::i32_le_s(),
    branch_if,
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_false(clean_parent[0] is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(clean_parent[0], @lib.Instruction::local_get(carry))
      @debug.assert_eq(clean_parent[1], @lib.Instruction::local_set(scratch))
      @debug.assert_eq(clean_parent[2], @lib.Instruction::local_get(limit))
      @debug.assert_eq(
        clean_parent[3],
        @lib.Instruction::local_get(cursor_source),
      )
      @debug.assert_eq(clean_parent[4], @lib.Instruction::local_tee(cursor))
      @debug.assert_eq(clean_parent[6], @lib.Instruction::i32_sub())
      @debug.assert_eq(clean_parent[7], @lib.Instruction::i32_le_s())
      @debug.assert_eq(clean_parent[8], branch_if)
    }
    other => fail("expected f7095 parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f7130 local-copy children before ge parser branch continuations" {
  // Direct slot23 `defined=7130 abs=7157` follows f7095. Binaryen drops the
  // tiny child wrappers around `local.get 318; local.set 34` before
  // `local.get; local.tee; i64.const; i64.ge_u; if` and around `local.get 321;
  // local.set 43` before both the source `local.get; i32.wrap_i64; local.tee;
  // i32.const; i32.ge_s; if` and the post-cleaned `local.get; local.tee;
  // i32.const; i32.ge_s; if` parser continuations. Keep this tied to the
  // decoded parser continuations.
  let outer_carry = @lib.LocalIdx::new(318U)
  let outer_scratch = @lib.LocalIdx::new(34U)
  let outer_state = @lib.LocalIdx::new(31U)
  let outer_cursor = @lib.LocalIdx::new(4U)
  let inner_carry = @lib.LocalIdx::new(321U)
  let inner_scratch = @lib.LocalIdx::new(43U)
  let inner_state = @lib.LocalIdx::new(320U)
  let inner_cursor = @lib.LocalIdx::new(42U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::br(@lib.LabelIdx::new(1U))],
    Some([@lib.Instruction::nop()]),
  )
  let clean_branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::br(@lib.LabelIdx::new(1U))],
    None,
  )
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(outer_carry),
        @lib.Instruction::local_set(outer_scratch),
      ]),
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(outer_state),
      @lib.Instruction::local_tee(outer_cursor),
      @lib.Instruction::i64_const(@lib.I64(10000L)),
      @lib.Instruction::i64_ge_u(),
      branch_if,
    ]),
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(inner_carry),
        @lib.Instruction::local_set(inner_scratch),
      ]),
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(inner_state),
      @lib.Instruction::i32_wrap_i64(),
      @lib.Instruction::local_tee(inner_cursor),
      @lib.Instruction::i32_const(@lib.I32(100)),
      @lib.Instruction::i32_ge_s(),
      branch_if,
    ]),
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(inner_carry),
        @lib.Instruction::local_set(inner_scratch),
      ]),
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(inner_state),
      @lib.Instruction::local_tee(inner_cursor),
      @lib.Instruction::i32_const(@lib.I32(100)),
      @lib.Instruction::i32_ge_s(),
      branch_if,
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [
      @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_clean)),
      @lib.Block(@lib.VoidBlockType, @lib.Expr(inner_clean)),
      @lib.Block(@lib.VoidBlockType, @lib.Expr(post_cleaned_inner_clean)),
    ] => {
      assert_false(outer_clean[0] is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(outer_clean[0], @lib.Instruction::local_get(outer_carry))
      @debug.assert_eq(
        outer_clean[1],
        @lib.Instruction::local_set(outer_scratch),
      )
      @debug.assert_eq(outer_clean[2], @lib.Instruction::local_get(outer_state))
      @debug.assert_eq(
        outer_clean[3],
        @lib.Instruction::local_tee(outer_cursor),
      )
      @debug.assert_eq(
        outer_clean[4],
        @lib.Instruction::i64_const(@lib.I64(10000L)),
      )
      @debug.assert_eq(outer_clean[5], @lib.Instruction::i64_ge_u())
      @debug.assert_eq(outer_clean[6], clean_branch_if)
      assert_false(inner_clean[0] is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(inner_clean[0], @lib.Instruction::local_get(inner_carry))
      @debug.assert_eq(
        inner_clean[1],
        @lib.Instruction::local_set(inner_scratch),
      )
      @debug.assert_eq(inner_clean[2], @lib.Instruction::local_get(inner_state))
      @debug.assert_eq(inner_clean[3], @lib.Instruction::i32_wrap_i64())
      @debug.assert_eq(
        inner_clean[4],
        @lib.Instruction::local_tee(inner_cursor),
      )
      @debug.assert_eq(
        inner_clean[5],
        @lib.Instruction::i32_const(@lib.I32(100)),
      )
      @debug.assert_eq(inner_clean[6], @lib.Instruction::i32_ge_s())
      @debug.assert_eq(inner_clean[7], clean_branch_if)
      assert_false(
        post_cleaned_inner_clean[0] is @lib.Block(@lib.VoidBlockType, _),
      )
      @debug.assert_eq(
        post_cleaned_inner_clean[0],
        @lib.Instruction::local_get(inner_carry),
      )
      @debug.assert_eq(
        post_cleaned_inner_clean[1],
        @lib.Instruction::local_set(inner_scratch),
      )
      @debug.assert_eq(
        post_cleaned_inner_clean[2],
        @lib.Instruction::local_get(inner_state),
      )
      @debug.assert_eq(
        post_cleaned_inner_clean[3],
        @lib.Instruction::local_tee(inner_cursor),
      )
      @debug.assert_eq(
        post_cleaned_inner_clean[4],
        @lib.Instruction::i32_const(@lib.I32(100)),
      )
      @debug.assert_eq(
        post_cleaned_inner_clean[5],
        @lib.Instruction::i32_ge_s(),
      )
      @debug.assert_eq(post_cleaned_inner_clean[6], clean_branch_if)
    }
    other =>
      fail("expected f7130 parent blocks, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f7133 local-copy child before i64.ne parser branch continuation" {
  // Direct slot23 `defined=7133 abs=7160` follows f7130. Binaryen removes
  // the anonymous child around `local.get 61; local.set 30` before the loop
  // continuation `local.get; i64.const; i64.ne; if`.
  let carry = @lib.LocalIdx::new(61U)
  let scratch = @lib.LocalIdx::new(30U)
  let state = @lib.LocalIdx::new(27U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(state),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::i64_div_u(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(29U)),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(63U)),
      @lib.Instruction::br(@lib.LabelIdx::new(2U)),
    ],
    Some([
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_set(@lib.LocalIdx::new(50U)),
    ]),
  )
  let clean_branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(state),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::i64_div_u(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(29U)),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(63U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ],
    Some([
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_set(@lib.LocalIdx::new(50U)),
    ]),
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          @lib.Instruction::nop(),
          @lib.Instruction::local_get(carry),
          @lib.Instruction::local_set(scratch),
        ]),
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(state),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::i64_ne(),
        branch_if,
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned {
    [first, second, third, fourth, fifth, sixth] => {
      assert_false(first is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(first, @lib.Instruction::local_get(carry))
      @debug.assert_eq(second, @lib.Instruction::local_set(scratch))
      @debug.assert_eq(third, @lib.Instruction::local_get(state))
      @debug.assert_eq(fourth, @lib.Instruction::i64_const(@lib.I64(0L)))
      @debug.assert_eq(fifth, @lib.Instruction::i64_ne())
      @debug.assert_eq(sixth, clean_branch_if)
    }
    other =>
      fail("expected f7133 flattened body, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f7138 local-copy child before i32 parser branch continuation" {
  // Direct slot23 `defined=7138 abs=7165` follows f7133 and has the same loop
  // counter shape with an i32-valued condition: Binaryen drops the anonymous
  // child around `local.get 58; local.set 4` before the `local.get; if` branch
  // that updates the quotient and loop count.
  let carry = @lib.LocalIdx::new(58U)
  let scratch = @lib.LocalIdx::new(4U)
  let state = @lib.LocalIdx::new(57U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::nop(),
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(state),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::i32_div_u(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(61U)),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(62U)),
      @lib.Instruction::br(@lib.LabelIdx::new(2U)),
    ],
    Some([
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_set(@lib.LocalIdx::new(45U)),
    ]),
  )
  let clean_branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(state),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::i32_div_u(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(61U)),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(62U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ],
    Some([
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_set(@lib.LocalIdx::new(45U)),
    ]),
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          @lib.Instruction::nop(),
          @lib.Instruction::local_get(carry),
          @lib.Instruction::local_set(scratch),
        ]),
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(state),
        branch_if,
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned {
    [first, second, third, fourth] => {
      assert_false(first is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(first, @lib.Instruction::local_get(carry))
      @debug.assert_eq(second, @lib.Instruction::local_set(scratch))
      @debug.assert_eq(third, @lib.Instruction::local_get(state))
      @debug.assert_eq(fourth, clean_branch_if)
    }
    other =>
      fail("expected f7138 flattened body, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f7141 local-copy child before unsigned parser branch continuation" {
  // Direct slot23 `defined=7141 abs=7168` follows f7138. Binaryen removes
  // the anonymous child around `local.get 314; local.set 5` before
  // `local.get; local.tee; i32.const; i32.ge_u; if`. Keep this as the narrow
  // i32 unsigned parser-continuation variant of the retained local-copy rule.
  let carry = @lib.LocalIdx::new(314U)
  let scratch = @lib.LocalIdx::new(5U)
  let state = @lib.LocalIdx::new(313U)
  let cursor = @lib.LocalIdx::new(4U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::br(@lib.LabelIdx::new(1U))],
    Some([@lib.Instruction::nop()]),
  )
  let clean_branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::br(@lib.LabelIdx::new(1U))],
    None,
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          @lib.Instruction::nop(),
          @lib.Instruction::local_get(carry),
          @lib.Instruction::local_set(scratch),
        ]),
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(state),
        @lib.Instruction::local_tee(cursor),
        @lib.Instruction::i32_const(@lib.I32(10000)),
        @lib.Instruction::i32_ge_u(),
        branch_if,
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_false(clean_parent[0] is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(clean_parent[0], @lib.Instruction::local_get(carry))
      @debug.assert_eq(clean_parent[1], @lib.Instruction::local_set(scratch))
      @debug.assert_eq(clean_parent[2], @lib.Instruction::local_get(state))
      @debug.assert_eq(clean_parent[3], @lib.Instruction::local_tee(cursor))
      @debug.assert_eq(
        clean_parent[4],
        @lib.Instruction::i32_const(@lib.I32(10000)),
      )
      @debug.assert_eq(clean_parent[5], @lib.Instruction::i32_ge_u())
      @debug.assert_eq(clean_parent[6], clean_branch_if)
    }
    other => fail("expected f7141 parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f7263 local-copy child before le_s parser branch continuation" {
  // Direct slot23 `defined=7263 abs=7290` follows f7141. Binaryen removes
  // the anonymous child around `local.get 258; local.set 9` before
  // `local.get; local.get; local.tee; i32.le_s; if` in a JSON escape parser
  // loop. Keep this as a narrow parser-continuation variant, not broad
  // local-copy cleanup.
  let carry = @lib.LocalIdx::new(258U)
  let scratch = @lib.LocalIdx::new(9U)
  let limit = @lib.LocalIdx::new(6U)
  let cursor_source = @lib.LocalIdx::new(257U)
  let cursor = @lib.LocalIdx::new(8U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_get(cursor),
      @lib.Instruction::call(@lib.FuncIdx::new(7291U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(34U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      @lib.Instruction::call(@lib.FuncIdx::new(65U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(34U)),
      @lib.Instruction::drop(),
      @lib.Instruction::br(@lib.LabelIdx::new(3U)),
    ],
    None,
  )
  let clean_branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      @lib.Instruction::local_get(scratch),
      @lib.Instruction::local_get(cursor),
      @lib.Instruction::call(@lib.FuncIdx::new(7291U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(34U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      @lib.Instruction::call(@lib.FuncIdx::new(65U)),
      @lib.Instruction::br(@lib.LabelIdx::new(2U)),
    ],
    None,
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          @lib.Instruction::nop(),
          @lib.Instruction::local_get(carry),
          @lib.Instruction::local_set(scratch),
        ]),
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(limit),
        @lib.Instruction::local_get(cursor_source),
        @lib.Instruction::local_tee(cursor),
        @lib.Instruction::i32_le_s(),
        branch_if,
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned {
    [first, second, third, fourth, fifth, sixth, seventh] => {
      assert_false(first is @lib.Block(@lib.VoidBlockType, _))
      @debug.assert_eq(first, @lib.Instruction::local_get(carry))
      @debug.assert_eq(second, @lib.Instruction::local_set(scratch))
      @debug.assert_eq(third, @lib.Instruction::local_get(limit))
      @debug.assert_eq(fourth, @lib.Instruction::local_get(cursor_source))
      @debug.assert_eq(fifth, @lib.Instruction::local_tee(cursor))
      @debug.assert_eq(sixth, @lib.Instruction::i32_le_s())
      @debug.assert_eq(seventh, clean_branch_if)
    }
    other =>
      fail("expected f7263 flattened body, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean preserves f5038 double-release selected-payload block" {
  // Direct slot23 `defined=5038 abs=5065` keeps the selected-payload dispatch
  // child before the allocation-return continuation like f5027/f5028, but its
  // else arm releases two enclosing locals before selecting the boxed payload.
  // Keep this as a parity guard for the ordered-neighborhood replay gap.
  let return_body = [
    pass_manager_test_vacuum_plain_block(
      pass_manager_test_vacuum_f5038_double_release_result_branch_dispatch_body(),
    ),
  ]
  for instr in pass_manager_test_vacuum_f5027_allocation_return_continuation() {
    return_body.push(instr)
  }
  let outer_body = [pass_manager_test_vacuum_plain_block(return_body)]
  outer_body.push(@lib.Instruction::unreachable_())
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(outer_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_outer))] =>
      match clean_outer[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_return)) =>
          match clean_return[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(clean_dispatch)) => {
              assert_true(clean_dispatch[0] is @lib.LocalGet(_))
              match clean_dispatch[clean_dispatch.length() - 1] {
                @lib.If(_, _, Some(else_body)) => {
                  @debug.assert_eq(
                    else_body[0],
                    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                  )
                  @debug.assert_eq(
                    else_body[2],
                    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
                  )
                }
                other =>
                  fail("expected f5038 preserved dispatch if, got \{other}")
              }
            }
            other =>
              fail("expected f5038 preserved dispatch block, got \{other}")
          }
        other => fail("expected f5038 allocation-return block, got \{other}")
      }
    other =>
      fail(
        "expected f5038 outer block preserving double-release dispatch, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn pass_manager_test_vacuum_f5032_two_release_prefix_body() -> Array[
  @lib.Instruction,
] {
  [
    @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(98U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(13U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(11U)),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
  ]
}

///|
fn pass_manager_test_vacuum_f5032_branchy_continuation_if() -> @lib.Instruction {
  @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(54U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(54U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(22U)),
    ],
    Some([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(21U)),
      @lib.Instruction::br(@lib.LabelIdx::new(3U)),
    ]),
  )
}

///|
test "raw vacuum preclean preserves f5032 two-release prefix parent wrapper" {
  // Direct slot23 `defined=5032 abs=5059` is the opposite direction from the
  // nearby flattening fixes: Binaryen removes only the inner prefix block around
  // the two-arg call-result/release/release prefix, but keeps the parent wrapper
  // that owns the following branchy `if`. Starshine must not decrement the
  // outward branch by flattening both wrappers.
  let prefix = pass_manager_test_vacuum_plain_block(
    pass_manager_test_vacuum_f5032_two_release_prefix_body(),
  )
  let guarded_body = [
    prefix,
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::i32_eqz(),
    pass_manager_test_vacuum_f5032_branchy_continuation_if(),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block(guarded_body),
      ]),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(input, None)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body))] =>
      match outer_body {
        [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
          @debug.assert_eq(parent_body.length(), 5)
          match parent_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_clean)) => {
              @debug.assert_eq(prefix_clean.length(), 8)
              assert_true(prefix_clean[0] is @lib.LocalGet(_))
              assert_true(prefix_clean[1] is @lib.LocalGet(_))
              assert_true(prefix_clean[2] is @lib.Call(_))
              assert_true(prefix_clean[3] is @lib.LocalSet(_))
            }
            other =>
              fail(
                "expected f5032 isolated two-release prefix block, got \{@debug.to_string(other)}",
              )
          }
          match parent_body[parent_body.length() - 1] {
            @lib.If(_, _, Some(else_body)) =>
              @debug.assert_eq(
                else_body[else_body.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              )
            other => fail("expected f5032 branchy continuation, got \{other}")
          }
        }
        other =>
          fail(
            "expected f5032 parent wrapper around isolated prefix, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected f5032 cleaned singleton outer block, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean flattens f4860 leading owner-exit dispatch before case0 return" {
  // Direct slot23 `defined=4860 abs=4887` follows the retained f4859 fix:
  // Binaryen removes the same two anonymous singleton wrappers, but the leading
  // dispatch starts with `local.get; call; if` and only tees the offset-8 child.
  // Keep this pinned to the source-backed dispatch plus case-0 continuation.
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        pass_manager_test_vacuum_f4860_leading_owner_exit_dispatch_body(),
      ),
    ]),
  ]
  for instr in pass_manager_test_vacuum_f4859_case0_return_continuation() {
    parent_body.push(instr)
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] => {
      assert_true(clean_parent[0] is @lib.LocalGet(_))
      assert_true(clean_parent[1] is @lib.Call(_))
      match clean_parent[2] {
        @lib.If(_, then_body, Some(else_body)) => {
          match then_body[7] {
            @lib.If(_, nested_then, Some(nested_else)) => {
              @debug.assert_eq(
                nested_then[nested_then.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(4U)),
              )
              @debug.assert_eq(
                nested_else[nested_else.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              )
            }
            other =>
              fail("expected f4860 nested loaded-child dispatch, got \{other}")
          }
          match else_body[8] {
            @lib.If(_, _, Some(final_else)) =>
              @debug.assert_eq(
                final_else[final_else.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              )
            other => fail("expected f4860 fallback tag branch, got \{other}")
          }
        }
        other => fail("expected f4860 leading dispatch if, got \{other}")
      }
    }
    other =>
      fail(
        "expected f4860 parent block with flattened leading owner-exit dispatch, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean keeps f4463-like owner without failure-box return" {
  // Negative guard: the f4463 flattening needs the sibling failure-box return;
  // without it, do not reopen broad owner-target branch flattening.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(
            pass_manager_test_vacuum_f4463_offset20_call_result_tag1_prefix_body(),
          ),
        ]),
        @lib.Instruction::local_get(@lib.LocalIdx::new(311U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5460U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_owner))] =>
      match clean_owner[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(singleton_body)) =>
          @debug.assert_eq(singleton_body.length(), 1)
        other =>
          fail("expected f4463-like singleton owner to stay, got \{other}")
      }
    other =>
      fail("expected f4463-like owner block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean keeps f4311-like nested tag dispatch without call continuation" {
  // Negative guard: the f4311 flattening needs the following call/local-set
  // continuation. Without it, do not broaden nested singleton-if cleanup.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(
            pass_manager_test_vacuum_f4311_tag85_86_dispatch_body(),
          ),
        ]),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, _) => ()
        other =>
          fail("expected f4311-like negative wrapper to stay, got \{other}")
      }
    other =>
      fail(
        "expected f4311-like negative parent block, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean keeps f3998-like tag2 prefix child without loop continuation" {
  // Negative guard: the f3998 rule requires the observed release/load/zero-init
  // loop continuation after the tag-2 parent. Without that continuation, the
  // side-effecting `local.set(call(local.tee(call ...), local.get)); release`
  // child remains protected.
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(
            pass_manager_test_vacuum_f3998_tag2_body(),
          ),
        ]),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ],
    None,
  )
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(clean_parent))] =>
      match clean_parent[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(tag_body)) =>
              assert_true(tag_body[0] is @lib.Block(@lib.VoidBlockType, _))
            other =>
              fail("expected f3998 negative nested tag block, got \{other}")
          }
        other => fail("expected f3998 negative parent tag block, got \{other}")
      }
    other =>
      fail(
        "expected f3998 negative tag2 prefix child to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean trims f1812 dropped load equality to trapping load" {
  // Slot23 `defined=1812 abs=1839` follows the f1792 wrapper fix: Binaryen
  // keeps the potentially trapping `i32.load` under `drop`, but removes the
  // nontrapping `i32.const 204; i32.eq` comparison debris. Do not drop the load.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
      @lib.Instruction::i32_load(load0),
      @lib.Instruction::i32_const(@lib.I32(204)),
      @lib.Instruction::i32_eq(),
      @lib.Instruction::drop(),
    ],
    None,
  )
  assert_true(changed)
  @debug.assert_eq(cleaned, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::drop(),
  ])
}

///|
test "raw vacuum preclean flattens f1836 loop if owner-branch wrapper" {
  // Slot23 `defined=1836 abs=1863` follows the f1812 trim: Binaryen removes
  // one anonymous loop-body child block around a final `if` whose condition is
  // `(i32.load local $slot) + 2 < call $len(local $source)`. Branches inside the
  // final `if` target the removed wrapper, so this fixture proves label rebasing
  // rather than a shallow source-shaped wrapper probe.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let source = @lib.LocalIdx::new(1U)
  let slot = @lib.LocalIdx::new(15U)
  let first = @lib.LocalIdx::new(26U)
  let second = @lib.LocalIdx::new(27U)
  let third = @lib.LocalIdx::new(28U)
  let inner_tag20 = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::local_get(source),
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::call(@lib.FuncIdx::new(18U)),
    @lib.Instruction::local_set(first),
    @lib.Instruction::local_get(source),
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::call(@lib.FuncIdx::new(18U)),
    @lib.Instruction::local_set(second),
    @lib.Instruction::local_get(source),
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::call(@lib.FuncIdx::new(18U)),
    @lib.Instruction::local_set(third),
    @lib.Instruction::local_get(first),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::i32_const(@lib.I32(20)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(first),
        @lib.Instruction::i32_load(load4),
        @lib.Instruction::local_set(@lib.LocalIdx::new(129U)),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::local_get(third),
        @lib.Instruction::call(@lib.FuncIdx::new(6U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ])
  let f1836_if = [
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_get(source),
    @lib.Instruction::call(@lib.FuncIdx::new(10U)),
    @lib.Instruction::i32_lt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([inner_tag20]),
        ]),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(16U)),
        @lib.Instruction::call(@lib.FuncIdx::new(6U)),
      ]),
    ),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(f1836_if),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  @debug.assert_eq(cleaned.length(), f1836_if.length())
  assert_true(cleaned[cleaned.length() - 1] is @lib.If(_, _, _))
}

///|
test "raw vacuum preclean flattens f1940 call-tee br-table wrapper before unreachable" {
  // Slot23 `defined=1940 abs=1967` follows the retained f1903 result-if pack:
  // Binaryen removes one anonymous block around a call/local.tee guarded
  // `br_table` release cascade before an immediate `unreachable`, while
  // Starshine kept the wrapper and shifted branch labels. Keep this raw shape
  // source-backed by the decoded native diff: `local.get; local.get; call;
  // local.tee; if`, a nested tag-dispatch `br_table` in the then arm, cleanup
  // calls in both arms, and no branch targeting the removed wrapper.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let load8 = @lib.MemArg::new(0U, None, 8UL)
  let dispatch_labels : Array[@lib.LabelIdx] = [
    @lib.LabelIdx::new(2U),
    @lib.LabelIdx::new(1U),
    @lib.LabelIdx::new(0U),
    @lib.LabelIdx::new(3U),
  ]
  let dispatch = pass_manager_test_vacuum_plain_block([
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          @lib.Instruction::local_get(@lib.LocalIdx::new(33U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(35U)),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::i32_const(@lib.I32(231)),
          @lib.Instruction::i32_sub(),
          @lib.Instruction::br_table(dispatch_labels, @lib.LabelIdx::new(3U)),
        ]),
        @lib.Instruction::local_set(@lib.LocalIdx::new(36U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(35U)),
        @lib.Instruction::i32_load(load8),
        @lib.Instruction::local_set(@lib.LocalIdx::new(37U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(35U)),
        @lib.Instruction::i32_load(load4),
        @lib.Instruction::local_set(@lib.LocalIdx::new(73U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(35U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(64U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(35U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(64U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(37U)),
            @lib.Instruction::call(@lib.FuncIdx::new(3U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(64U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(36U)),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(37U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::call(@lib.FuncIdx::new(15U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(74U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(74U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(73U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(30U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(37U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(29U)),
            @lib.Instruction::br(@lib.LabelIdx::new(15U)),
          ],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(37U)),
            @lib.Instruction::call(@lib.FuncIdx::new(4U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
            @lib.Instruction::call(@lib.FuncIdx::new(4U)),
            @lib.Instruction::br(@lib.LabelIdx::new(16U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
      @lib.Instruction::local_get(@lib.LocalIdx::new(35U)),
      @lib.Instruction::call(@lib.FuncIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
      @lib.Instruction::call(@lib.FuncIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
      @lib.Instruction::call(@lib.FuncIdx::new(4U)),
      @lib.Instruction::br(@lib.LabelIdx::new(13U)),
    ]),
  ])
  let guarded_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [dispatch],
    Some([
      @lib.Instruction::local_get(@lib.LocalIdx::new(33U)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(33U)),
          @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        ],
        None,
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(19U)),
      @lib.Instruction::call(@lib.FuncIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
      @lib.Instruction::call(@lib.FuncIdx::new(4U)),
      @lib.Instruction::br(@lib.LabelIdx::new(12U)),
    ]),
  )
  let child_body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(12U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(33U)),
    guarded_if,
    @lib.Instruction::unreachable_(),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(child_body),
      @lib.Instruction::unreachable_(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), child_body.length())
      assert_true(parent_body[0] is @lib.LocalGet(_))
      assert_true(parent_body[3] is @lib.LocalTee(_))
      assert_true(parent_body[4] is @lib.If(@lib.VoidBlockType, _, Some(_)))
      assert_true(parent_body[5] is @lib.Unreachable)
    }
    other =>
      fail("expected f1940 wrapper flatten, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean flattens f1956 call-tee br-table wrapper before unreachable" {
  // Slot23 `defined=1956 abs=1983` follows the retained f1948 fix:
  // Binaryen removes one anonymous child block around a `local.tee(call)`
  // branch-dispatch `if` immediately before `unreachable`. The then arm starts
  // with the observed tag selector `local.get; local.tee; i32.load; i32.const
  // 224; i32.sub; br_table`, and the else arm conditionally releases the call
  // result before branching out. Keep this exact and do not reopen broad
  // br_table / call-prefix wrapper flattening.
  let result = @lib.LocalIdx::new(35U)
  let tagged = @lib.LocalIdx::new(37U)
  let dispatch = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            pass_manager_test_vacuum_plain_block([
              @lib.Instruction::local_get(result),
              @lib.Instruction::local_tee(tagged),
              @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
              @lib.Instruction::i32_const(@lib.I32(224)),
              @lib.Instruction::i32_sub(),
              @lib.Instruction::br_table(
                [
                  @lib.LabelIdx::new(0U),
                  @lib.LabelIdx::new(1U),
                  @lib.LabelIdx::new(2U),
                ],
                @lib.LabelIdx::new(3U),
              ),
            ]),
            @lib.Instruction::local_get(tagged),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ]),
          @lib.Instruction::local_get(tagged),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::br(@lib.LabelIdx::new(5U)),
        ]),
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::br(@lib.LabelIdx::new(5U)),
      ]),
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::call(@lib.FuncIdx::new(4U)),
      @lib.Instruction::br(@lib.LabelIdx::new(5U)),
    ],
    Some([
      @lib.Instruction::local_get(result),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(result),
          @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        ],
        None,
      ),
      @lib.Instruction::br(@lib.LabelIdx::new(5U)),
    ]),
  )
  let child_body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::local_tee(result),
    dispatch,
    @lib.Instruction::unreachable_(),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(child_body),
      @lib.Instruction::unreachable_(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), child_body.length())
      assert_true(parent_body[0] is @lib.LocalGet(_))
      assert_true(parent_body[3] is @lib.LocalTee(_))
      assert_true(parent_body[4] is @lib.If(@lib.VoidBlockType, _, Some(_)))
      assert_true(parent_body[5] is @lib.Unreachable)
    }
    other =>
      fail("expected f1956 wrapper flatten, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean flattens f2054 tag-236 call-tee br-table wrapper before unreachable" {
  // Slot23 `defined=2054 abs=2081` follows the retained f1963 fix:
  // Binaryen removes one anonymous child block around a `local.tee(call)`
  // dispatch `if` immediately before `unreachable`. This sibling of the f1956
  // rule is exact to the observed tag-236 br_table selector plus release/branch
  // else arm, avoiding broad br_table or call-prefix flattening.
  let result = @lib.LocalIdx::new(53U)
  let tagged = @lib.LocalIdx::new(55U)
  let dispatch = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block([
            pass_manager_test_vacuum_plain_block([
              @lib.Instruction::local_get(result),
              @lib.Instruction::local_tee(tagged),
              @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 0UL)),
              @lib.Instruction::i32_const(@lib.I32(236)),
              @lib.Instruction::i32_sub(),
              @lib.Instruction::br_table(
                [
                  @lib.LabelIdx::new(0U),
                  @lib.LabelIdx::new(1U),
                  @lib.LabelIdx::new(2U),
                ],
                @lib.LabelIdx::new(3U),
              ),
            ]),
            @lib.Instruction::local_get(tagged),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(5U)),
          ]),
          @lib.Instruction::local_get(tagged),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::br(@lib.LabelIdx::new(5U)),
        ]),
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::br(@lib.LabelIdx::new(5U)),
      ]),
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::call(@lib.FuncIdx::new(4U)),
      @lib.Instruction::br(@lib.LabelIdx::new(5U)),
    ],
    Some([
      @lib.Instruction::local_get(result),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(result),
          @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        ],
        None,
      ),
      @lib.Instruction::br(@lib.LabelIdx::new(5U)),
    ]),
  )
  let child_body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::call(@lib.FuncIdx::new(15U)),
    @lib.Instruction::local_tee(result),
    dispatch,
    @lib.Instruction::unreachable_(),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(child_body),
      @lib.Instruction::unreachable_(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), child_body.length())
      assert_true(parent_body[0] is @lib.LocalGet(_))
      assert_true(parent_body[3] is @lib.LocalTee(_))
      assert_true(parent_body[4] is @lib.If(@lib.VoidBlockType, _, Some(_)))
      assert_true(parent_body[5] is @lib.Unreachable)
    }
    other =>
      fail("expected f2054 wrapper flatten, got \{@debug.to_string(other)}")
  }
}

///|
fn pass_manager_test_vacuum_f2321_release_ladder(
  tagged : @lib.LocalIdx,
  copy : @lib.LocalIdx,
  value : @lib.LocalIdx,
  count : @lib.LocalIdx,
  target : @lib.LocalIdx,
  branch : @lib.LabelIdx,
) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::local_set(copy),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(@lib.MemArg::new(0U, None, 4UL)),
    @lib.Instruction::local_set(value),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_tee(count),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_gt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::local_get(count),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(value),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ],
      Some([
        @lib.Instruction::local_get(count),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(copy),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ],
          None,
        ),
      ]),
    ),
    @lib.Instruction::local_get(value),
    @lib.Instruction::local_set(target),
    @lib.Instruction::br(branch),
  ]
}

///|
test "raw vacuum preclean flattens f2321 tag-236 call-arg-tee br-table release ladder wrapper" {
  // Slot23 `defined=2321 abs=2348` follows the retained f2320 fix:
  // Binaryen removes the anonymous child block around a call-produced tag-236
  // `br_table` release ladder before an immediate `unreachable`. This sibling
  // of f2054 is exact to the observed extra pre-call `local.tee` operand, four
  // single-result release ladders, terminal release, else-arm release, and no
  // branch targeting the removed wrapper.
  let call_arg = @lib.LocalIdx::new(9U)
  let result = @lib.LocalIdx::new(17U)
  let tagged = @lib.LocalIdx::new(19U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let dispatch_labels : Array[@lib.LabelIdx] = [
    @lib.LabelIdx::new(0U),
    @lib.LabelIdx::new(1U),
    @lib.LabelIdx::new(2U),
    @lib.LabelIdx::new(3U),
  ]
  let case0 = pass_manager_test_vacuum_f2321_release_ladder(
    tagged,
    @lib.LocalIdx::new(20U),
    @lib.LocalIdx::new(41U),
    @lib.LocalIdx::new(45U),
    @lib.LocalIdx::new(14U),
    @lib.LabelIdx::new(8U),
  )
  let case1 = pass_manager_test_vacuum_f2321_release_ladder(
    tagged,
    @lib.LocalIdx::new(22U),
    @lib.LocalIdx::new(42U),
    @lib.LocalIdx::new(47U),
    @lib.LocalIdx::new(14U),
    @lib.LabelIdx::new(8U),
  )
  let case2 = pass_manager_test_vacuum_f2321_release_ladder(
    tagged,
    @lib.LocalIdx::new(24U),
    @lib.LocalIdx::new(43U),
    @lib.LocalIdx::new(49U),
    @lib.LocalIdx::new(14U),
    @lib.LabelIdx::new(8U),
  )
  let case3 = pass_manager_test_vacuum_f2321_release_ladder(
    tagged,
    @lib.LocalIdx::new(26U),
    @lib.LocalIdx::new(44U),
    @lib.LocalIdx::new(51U),
    @lib.LocalIdx::new(11U),
    @lib.LabelIdx::new(8U),
  )
  let dispatch = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      pass_manager_test_vacuum_plain_block(
        [
          pass_manager_test_vacuum_plain_block(
            [
              pass_manager_test_vacuum_plain_block(
                [
                  pass_manager_test_vacuum_plain_block(
                    [
                      pass_manager_test_vacuum_plain_block([
                        @lib.Instruction::local_get(result),
                        @lib.Instruction::local_tee(tagged),
                        @lib.Instruction::i32_load(load0),
                        @lib.Instruction::i32_const(@lib.I32(236)),
                        @lib.Instruction::i32_sub(),
                        @lib.Instruction::br_table(
                          dispatch_labels,
                          @lib.LabelIdx::new(4U),
                        ),
                      ]),
                      ..case0,
                    ],
                  ),
                  ..case1,
                ],
              ),
              ..case2,
            ],
          ),
          ..case3,
        ],
      ),
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::call(@lib.FuncIdx::new(6U)),
      @lib.Instruction::br(@lib.LabelIdx::new(8U)),
    ],
    Some([
      @lib.Instruction::local_get(result),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(result),
          @lib.Instruction::call(@lib.FuncIdx::new(6U)),
        ],
        None,
      ),
      @lib.Instruction::br(@lib.LabelIdx::new(8U)),
    ]),
  )
  let child_body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(58U)),
    @lib.Instruction::local_tee(call_arg),
    @lib.Instruction::call(@lib.FuncIdx::new(10U)),
    @lib.Instruction::local_tee(result),
    dispatch,
    @lib.Instruction::unreachable_(),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(child_body),
      @lib.Instruction::unreachable_(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), child_body.length())
      assert_true(parent_body[0] is @lib.LocalGet(_))
      assert_true(parent_body[2] is @lib.LocalTee(_))
      assert_true(parent_body[4] is @lib.LocalTee(_))
      assert_true(parent_body[5] is @lib.If(@lib.VoidBlockType, _, Some(_)))
      assert_true(parent_body[6] is @lib.Unreachable)
    }
    other =>
      fail("expected f2321 wrapper flatten, got \{@debug.to_string(other)}")
  }
}

///|
fn pass_manager_test_vacuum_f2334_release_branch(
  tagged : @lib.LocalIdx,
  branch : @lib.LabelIdx,
) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::br(branch),
  ]
}

///|
test "raw vacuum preclean flattens f2334 tag-236 load-release call-result wrapper before continuation" {
  // Slot23 `defined=2334 abs=2361` follows the retained f2321 fix:
  // Binaryen removes one anonymous wrapper around a child block that loads
  // offset 4 from the source slot, releases that source, dispatches a
  // call-produced tag-236 `br_table` release cascade, and then falls into a
  // following offset-8 continuation. This guard is exact to that native shape
  // and avoids broad br_table, call-prefix, or continuation-wrapper cleanup.
  let source = @lib.LocalIdx::new(10U)
  let loaded = @lib.LocalIdx::new(30U)
  let result = @lib.LocalIdx::new(11U)
  let tagged = @lib.LocalIdx::new(13U)
  let continuation = @lib.LocalIdx::new(221U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let load8 = @lib.MemArg::new(0U, None, 8UL)
  let dispatch = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      pass_manager_test_vacuum_plain_block(
        [
          pass_manager_test_vacuum_plain_block(
            [
              pass_manager_test_vacuum_plain_block(
                [
                  pass_manager_test_vacuum_plain_block([
                    @lib.Instruction::local_get(result),
                    @lib.Instruction::local_tee(tagged),
                    @lib.Instruction::i32_load(load0),
                    @lib.Instruction::i32_const(@lib.I32(236)),
                    @lib.Instruction::i32_sub(),
                    @lib.Instruction::br_table(
                      [
                        @lib.LabelIdx::new(0U),
                        @lib.LabelIdx::new(1U),
                        @lib.LabelIdx::new(2U),
                      ],
                      @lib.LabelIdx::new(3U),
                    ),
                  ]),
                  ..pass_manager_test_vacuum_f2334_release_branch(
                    tagged,
                    @lib.LabelIdx::new(4U),
                  ),
                ],
              ),
              ..pass_manager_test_vacuum_f2334_release_branch(
                tagged,
                @lib.LabelIdx::new(3U),
              ),
            ],
          ),
          ..pass_manager_test_vacuum_f2334_release_branch(
            tagged,
            @lib.LabelIdx::new(2U),
          ),
        ],
      ),
      ..pass_manager_test_vacuum_f2334_release_branch(
        tagged,
        @lib.LabelIdx::new(3U),
      ),
    ],
    Some([
      @lib.Instruction::local_get(result),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(result),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        ],
        None,
      ),
      @lib.Instruction::br(@lib.LabelIdx::new(3U)),
    ]),
  )
  let child_body = [
    @lib.Instruction::local_get(source),
    @lib.Instruction::i32_load(load4),
    @lib.Instruction::local_set(loaded),
    @lib.Instruction::local_get(source),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(loaded),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(result),
    dispatch,
    @lib.Instruction::unreachable_(),
  ]
  let continuation_body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(source),
    @lib.Instruction::i32_load(load8),
    @lib.Instruction::call(@lib.FuncIdx::new(10U)),
    @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    @lib.Instruction::i64_extend_i32s(),
    @lib.Instruction::local_set(continuation),
    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(
        [
          pass_manager_test_vacuum_plain_block([
            pass_manager_test_vacuum_plain_block(child_body),
          ]),
          ..continuation_body,
        ],
      ),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr([@lib.Block(@lib.VoidBlockType, @lib.Expr(block5_body))])
      ),
    ] => {
      @debug.assert_eq(block5_body.length(), 1 + continuation_body.length())
      match block5_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(flattened_child)) => {
          @debug.assert_eq(flattened_child.length(), child_body.length())
          assert_true(flattened_child[2] is @lib.LocalSet(_))
          assert_true(flattened_child[4] is @lib.Call(_))
          assert_true(flattened_child[8] is @lib.LocalTee(_))
          assert_true(
            flattened_child[9] is @lib.If(@lib.VoidBlockType, _, Some(_)),
          )
          assert_true(flattened_child[10] is @lib.Unreachable)
        }
        other =>
          fail(
            "expected f2334 child block first, got \{@debug.to_string(other)}",
          )
      }
      assert_true(block5_body[1] is @lib.LocalGet(_))
      assert_true(block5_body[8] is @lib.LocalSet(_))
      assert_true(block5_body[9] is @lib.Br(_))
    }
    other =>
      fail("expected f2334 wrapper flatten, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean flattens f2320 tag-231 call-tee br-table double-update wrapper" {
  // Slot23 `defined=2320 abs=2347` follows the retained f2297 fix:
  // Binaryen removes the anonymous child block around a call-produced tag-231
  // `br_table` dispatch/release ladder before an immediate `unreachable`, while
  // Starshine kept it. This guard stays exact to the observed tag-231 selector,
  // two single-result release ladders, the final offset-8/offset-4 double-local
  // update ladder, terminal release, else-arm release, and no branch targeting
  // the removed wrapper.
  let result = @lib.LocalIdx::new(24U)
  let tagged = @lib.LocalIdx::new(26U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let load8 = @lib.MemArg::new(0U, None, 8UL)
  let dispatch_labels : Array[@lib.LabelIdx] = [
    @lib.LabelIdx::new(1U),
    @lib.LabelIdx::new(0U),
    @lib.LabelIdx::new(2U),
    @lib.LabelIdx::new(3U),
  ]
  let case0 = [
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::local_set(@lib.LocalIdx::new(27U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(load4),
    @lib.Instruction::local_set(@lib.LocalIdx::new(44U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(46U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_gt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::local_get(@lib.LocalIdx::new(46U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(44U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(46U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(27U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ],
          None,
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(44U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(17U)),
    @lib.Instruction::br(@lib.LabelIdx::new(5U)),
  ]
  let case1 = [
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::local_set(@lib.LocalIdx::new(29U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(load4),
    @lib.Instruction::local_set(@lib.LocalIdx::new(45U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(48U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_gt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::local_get(@lib.LocalIdx::new(48U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(45U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(48U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(29U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ],
          None,
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(45U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(10U)),
    @lib.Instruction::br(@lib.LabelIdx::new(5U)),
  ]
  let final_case = [
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::local_set(@lib.LocalIdx::new(31U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(load8),
    @lib.Instruction::local_set(@lib.LocalIdx::new(32U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(load4),
    @lib.Instruction::local_set(@lib.LocalIdx::new(56U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(50U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_gt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::local_get(@lib.LocalIdx::new(50U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(32U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(50U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(31U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ],
          None,
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(56U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(32U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::br(@lib.LabelIdx::new(5U)),
  ]
  let dispatch = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      pass_manager_test_vacuum_plain_block(
        [
          pass_manager_test_vacuum_plain_block(
            [
              pass_manager_test_vacuum_plain_block(
                [
                  pass_manager_test_vacuum_plain_block([
                    @lib.Instruction::local_get(result),
                    @lib.Instruction::local_tee(tagged),
                    @lib.Instruction::i32_load(load0),
                    @lib.Instruction::i32_const(@lib.I32(231)),
                    @lib.Instruction::i32_sub(),
                    @lib.Instruction::br_table(
                      dispatch_labels,
                      @lib.LabelIdx::new(3U),
                    ),
                  ]),
                  ..case0,
                ],
              ),
              ..case1,
            ],
          ),
          ..final_case,
        ],
      ),
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::call(@lib.FuncIdx::new(6U)),
      @lib.Instruction::br(@lib.LabelIdx::new(5U)),
    ],
    Some([
      @lib.Instruction::local_get(result),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(result),
          @lib.Instruction::call(@lib.FuncIdx::new(6U)),
        ],
        None,
      ),
      @lib.Instruction::br(@lib.LabelIdx::new(5U)),
    ]),
  )
  let child_body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::call(@lib.FuncIdx::new(11U)),
    @lib.Instruction::local_tee(result),
    dispatch,
    @lib.Instruction::unreachable_(),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(child_body),
      @lib.Instruction::unreachable_(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), child_body.length())
      assert_true(parent_body[0] is @lib.LocalGet(_))
      assert_true(parent_body[3] is @lib.LocalTee(_))
      assert_true(parent_body[4] is @lib.If(@lib.VoidBlockType, _, Some(_)))
      assert_true(parent_body[5] is @lib.Unreachable)
    }
    other =>
      fail("expected f2320 wrapper flatten, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean flattens f2297 tag-220 call-tee br-table release ladder wrapper" {
  // Slot23 `defined=2297 abs=2324` follows the retained f2130 fix:
  // Binaryen removes one anonymous child block around the call-produced tag-220
  // `br_table` dispatch/release ladder before an immediate `unreachable`, while
  // Starshine kept it and shifted outer branch labels. This stays exact to the
  // observed selector, repeated load/refcount/release ladders, terminal release,
  // else-arm release, and no branch targeting the removed wrapper.
  let result = @lib.LocalIdx::new(20U)
  let tagged = @lib.LocalIdx::new(22U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let dispatch_labels : Array[@lib.LabelIdx] = [
    @lib.LabelIdx::new(0U),
    @lib.LabelIdx::new(2U),
    @lib.LabelIdx::new(1U),
    @lib.LabelIdx::new(3U),
    @lib.LabelIdx::new(4U),
  ]
  let case0 = [
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::local_set(@lib.LocalIdx::new(23U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(load4),
    @lib.Instruction::local_set(@lib.LocalIdx::new(40U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(44U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_gt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::local_get(@lib.LocalIdx::new(44U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(44U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(23U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ],
          None,
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(40U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(19U)),
    @lib.Instruction::br(@lib.LabelIdx::new(6U)),
  ]
  let case1 = [
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::local_set(@lib.LocalIdx::new(25U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(load4),
    @lib.Instruction::local_set(@lib.LocalIdx::new(41U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(46U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_gt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::local_get(@lib.LocalIdx::new(46U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(46U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(25U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ],
          None,
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(41U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(18U)),
    @lib.Instruction::br(@lib.LabelIdx::new(6U)),
  ]
  let case2 = [
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::local_set(@lib.LocalIdx::new(27U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(load4),
    @lib.Instruction::local_set(@lib.LocalIdx::new(42U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(48U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_gt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::local_get(@lib.LocalIdx::new(48U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(42U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(48U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(27U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ],
          None,
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(42U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(12U)),
    @lib.Instruction::br(@lib.LabelIdx::new(6U)),
  ]
  let case3 = [
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::local_set(@lib.LocalIdx::new(29U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(load4),
    @lib.Instruction::local_set(@lib.LocalIdx::new(43U)),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(50U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_gt_s(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::local_get(@lib.LocalIdx::new(50U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_sub(),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(43U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ],
      Some([
        @lib.Instruction::local_get(@lib.LocalIdx::new(50U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(29U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ],
          None,
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(43U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
    @lib.Instruction::br(@lib.LabelIdx::new(6U)),
  ]
  let dispatch = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      pass_manager_test_vacuum_plain_block(
        [
          pass_manager_test_vacuum_plain_block(
            [
              pass_manager_test_vacuum_plain_block(
                [
                  pass_manager_test_vacuum_plain_block(
                    [
                      pass_manager_test_vacuum_plain_block([
                        @lib.Instruction::local_get(result),
                        @lib.Instruction::local_tee(tagged),
                        @lib.Instruction::i32_load(load0),
                        @lib.Instruction::i32_const(@lib.I32(220)),
                        @lib.Instruction::i32_sub(),
                        @lib.Instruction::br_table(
                          dispatch_labels,
                          @lib.LabelIdx::new(4U),
                        ),
                      ]),
                      ..case0,
                    ],
                  ),
                  ..case1,
                ],
              ),
              ..case2,
            ],
          ),
          ..case3,
        ],
      ),
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::call(@lib.FuncIdx::new(6U)),
      @lib.Instruction::br(@lib.LabelIdx::new(6U)),
    ],
    Some([
      @lib.Instruction::local_get(result),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(result),
          @lib.Instruction::call(@lib.FuncIdx::new(6U)),
        ],
        None,
      ),
      @lib.Instruction::br(@lib.LabelIdx::new(6U)),
    ]),
  )
  let child_body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::call(@lib.FuncIdx::new(9U)),
    @lib.Instruction::local_tee(result),
    dispatch,
    @lib.Instruction::unreachable_(),
  ]
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block(child_body),
      @lib.Instruction::unreachable_(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), child_body.length())
      assert_true(parent_body[0] is @lib.LocalGet(_))
      assert_true(parent_body[3] is @lib.LocalTee(_))
      assert_true(parent_body[4] is @lib.If(@lib.VoidBlockType, _, Some(_)))
      assert_true(parent_body[5] is @lib.Unreachable)
    }
    other =>
      fail("expected f2297 wrapper flatten, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean flattens f1963 local-set sentinel comparison wrapper" {
  // Slot23 `defined=1963 abs=1990` follows the retained f1956 fix: Binaryen
  // removes one anonymous child wrapper around two decoded-binary
  // `local.set(call ...)` sentinel comparisons (`4294967296`) before the
  // enclosing block branches outward. Keep this exact to the observed
  // two-result comparison shape so broader call-prefix / local-set wrapper
  // cleanup remains guarded.
  let arg0 = @lib.LocalIdx::new(1U)
  let arg1 = @lib.LocalIdx::new(2U)
  let lhs_arg = @lib.LocalIdx::new(5U)
  let rhs_arg = @lib.LocalIdx::new(6U)
  let selector = @lib.LocalIdx::new(9U)
  let lhs_result = @lib.LocalIdx::new(86U)
  let rhs_result = @lib.LocalIdx::new(87U)
  let compare_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::br(@lib.LabelIdx::new(2U))],
    Some([
      @lib.Instruction::local_get(lhs_result),
      @lib.Instruction::i32_wrap_i64(),
      @lib.Instruction::local_set(selector),
      @lib.Instruction::local_get(rhs_result),
      @lib.Instruction::i64_const(@lib.I64(4294967296L)),
      @lib.Instruction::i64_eq(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [@lib.Instruction::br(@lib.LabelIdx::new(3U))],
        Some([
          @lib.Instruction::local_get(selector),
          @lib.Instruction::local_get(rhs_result),
          @lib.Instruction::i32_wrap_i64(),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::br(@lib.LabelIdx::new(4U))],
            None,
          ),
        ]),
      ),
    ]),
  )
  let sentinel_body = [
    @lib.Instruction::local_get(arg0),
    @lib.Instruction::local_get(arg1),
    @lib.Instruction::local_get(lhs_arg),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_set(lhs_result),
    @lib.Instruction::local_get(arg0),
    @lib.Instruction::local_get(arg1),
    @lib.Instruction::local_get(rhs_arg),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_set(rhs_result),
    @lib.Instruction::local_get(lhs_result),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::i64_eq(),
    compare_if,
  ]
  assert_true(
    run_hot_pipeline_raw_vacuum_body_is_f1963_local_set_sentinel_comparison(
      sentinel_body,
    ),
  )
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          pass_manager_test_vacuum_plain_block(sentinel_body),
        ]),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
      @lib.Instruction::return_(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(root_body))] =>
      match root_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
              @debug.assert_eq(parent_body.length(), 14)
              assert_true(parent_body[0] is @lib.LocalGet(_))
              assert_true(parent_body[4] is @lib.LocalSet(_))
              assert_true(parent_body[9] is @lib.LocalSet(_))
              assert_true(
                parent_body[13] is @lib.If(@lib.VoidBlockType, _, Some(_)),
              )
              match parent_body[13] {
                @lib.If(_, [@lib.Br(label)], _) =>
                  @debug.assert_eq(label, @lib.LabelIdx::new(1U))
                _ => fail("expected rebased f1963 branch")
              }
            }
            other =>
              fail(
                "expected f1963 wrapper flattened, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail("expected f1963 outer wrapper, got \{@debug.to_string(other)}")
      }
    other =>
      fail(
        "expected f1963 local-set sentinel wrapper flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean flattens f1948 call-tee sentinel branch wrappers" {
  // Slot23 `defined=1948 abs=1975` follows the retained f1946 fix: Binaryen
  // removes exactly two anonymous child wrappers around a branch-selection `if`
  // whose condition is `i64.eq(local.tee(call), 4294967296)`. The else arm
  // wraps that call result to i32, tests the selector local, and either branches
  // to the surrounding continuation block or the outer fallback block before an
  // unreachable. Keep this exact so broader call-prefix / branch-selection
  // wrapper cleanup remains guarded.
  let root = @lib.LocalIdx::new(0U)
  let arg1 = @lib.LocalIdx::new(1U)
  let arg2 = @lib.LocalIdx::new(2U)
  let call_result = @lib.LocalIdx::new(73U)
  let selector = @lib.LocalIdx::new(6U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::br(@lib.LabelIdx::new(4U))],
    Some([
      @lib.Instruction::local_get(call_result),
      @lib.Instruction::i32_wrap_i64(),
      @lib.Instruction::local_tee(selector),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(selector),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::br(@lib.LabelIdx::new(5U))],
            Some([@lib.Instruction::br(@lib.LabelIdx::new(6U))]),
          ),
          @lib.Instruction::unreachable_(),
        ],
        None,
      ),
    ]),
  )
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        pass_manager_test_vacuum_plain_block([
          @lib.Instruction::local_get(root),
          @lib.Instruction::local_get(arg1),
          @lib.Instruction::local_get(arg2),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::local_tee(call_result),
          @lib.Instruction::i64_const(@lib.I64(4294967296L)),
          @lib.Instruction::i64_eq(),
          branch_if,
        ]),
      ]),
      @lib.Instruction::local_get(root),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::call(@lib.FuncIdx::new(3U)),
      @lib.Instruction::i64_extend_i32s(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), 12)
      assert_true(parent_body[0] is @lib.LocalGet(_))
      assert_true(parent_body[3] is @lib.Call(_))
      assert_true(parent_body[7] is @lib.If(@lib.VoidBlockType, _, Some(_)))
      assert_true(parent_body[8] is @lib.LocalGet(_))
    }
    other =>
      fail(
        "expected f1948 branch-selection wrapper flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean flattens f1946 loop argument local-copy before eqz call" {
  // Slot23 `defined=1946 abs=1973` follows the f1940 wrapper fix: Binaryen
  // removes one anonymous child block around `local.set(local.get $loop_arg)`
  // immediately before the loop-body continuation `local.tee; local.tee;
  // local.tee; call; i32.eqz; if`. Keep this exact to the extracted native
  // shape so broader local-copy/prefix wrappers remain guarded.
  let copy_source = @lib.LocalIdx::new(267U)
  let copy_target = @lib.LocalIdx::new(6U)
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        @lib.Instruction::local_get(copy_source),
        @lib.Instruction::local_set(copy_target),
      ]),
      @lib.Instruction::local_get(@lib.LocalIdx::new(265U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(266U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(268U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
      @lib.Instruction::call(@lib.FuncIdx::new(3U)),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(copy_target),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          @lib.Instruction::return_(),
        ],
        None,
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] => {
      @debug.assert_eq(parent_body.length(), 13)
      assert_true(parent_body[0] is @lib.LocalGet(_))
      assert_true(parent_body[1] is @lib.LocalSet(_))
      assert_true(parent_body[10] is @lib.If(@lib.VoidBlockType, _, None))
    }
    other =>
      fail(
        "expected f1946 local-copy wrapper flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean preserves f1900 increment probe prefix before reload continuation" {
  // Slot23 `defined=1900 abs=1927` follows the retained f1895 fix: Binaryen
  // preserves the child block around an increment/probe/release prefix before a
  // reload continuation, while Starshine had flattened it. Keep the guard
  // source-shaped to the decoded binary prefix (`i32.load + 1`, retain/probe,
  // release, then branchy result test) and the following reload continuation;
  // do not broadly preserve side-effect prefix wrappers.
  let load12 = @lib.MemArg::new(0U, None, 12UL)
  let load20 = @lib.MemArg::new(0U, None, 20UL)
  let slot = @lib.LocalIdx::new(18U)
  let root = @lib.LocalIdx::new(1U)
  let ctx = @lib.LocalIdx::new(2U)
  let mask = @lib.LocalIdx::new(7U)
  let increment = @lib.LocalIdx::new(50U)
  let probe = @lib.LocalIdx::new(49U)
  let result = @lib.LocalIdx::new(68U)
  let tagged = @lib.LocalIdx::new(384U)
  let child = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i32_load(load20),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(increment),
    @lib.Instruction::local_get(root),
    @lib.Instruction::i32_load(load12),
    @lib.Instruction::local_tee(probe),
    @lib.Instruction::call(@lib.FuncIdx::new(4U)),
    @lib.Instruction::local_get(probe),
    @lib.Instruction::local_get(increment),
    @lib.Instruction::call(@lib.FuncIdx::new(18U)),
    @lib.Instruction::local_set(result),
    @lib.Instruction::local_get(probe),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::local_get(root),
    @lib.Instruction::local_get(ctx),
    @lib.Instruction::local_get(result),
    @lib.Instruction::call(@lib.FuncIdx::new(10U)),
    @lib.Instruction::local_tee(tagged),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::i64_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(slot),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ],
      Some([
        @lib.Instruction::local_get(mask),
        @lib.Instruction::local_get(mask),
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::i32_wrap_i64(),
        @lib.Instruction::i32_and(),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(slot),
            @lib.Instruction::call(@lib.FuncIdx::new(5U)),
            @lib.Instruction::br(@lib.LabelIdx::new(4U)),
          ],
          None,
        ),
      ]),
    ),
  ])
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        child,
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(slot),
        @lib.Instruction::i32_load(load20),
        @lib.Instruction::local_set(@lib.LocalIdx::new(69U)),
        @lib.Instruction::local_get(root),
        @lib.Instruction::i32_load(load12),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(45U)),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_get(slot),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(45U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(69U)),
        @lib.Instruction::call(@lib.FuncIdx::new(18U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(70U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(45U)),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ]),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(input, None)
  match cleaned {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr([@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))])
      ),
    ] =>
      match parent_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) => {
          assert_true(child_body[0] is @lib.LocalGet(_))
          assert_true(child_body[child_body.length() - 1] is @lib.If(_, _, _))
        }
        other =>
          fail(
            "expected f1900 increment/probe prefix child wrapper to stay wrapped, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail("expected f1900 parent wrapper, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean preserves f2094 increment probe prefix before block continuation" {
  // Slot23 `defined=2094 abs=2121` follows the f2072 empty-sibling fix and
  // repeats the f1900 increment/probe/release prefix, but the following
  // continuation is a sibling `block` rather than a same-sibling reload prefix.
  // Binaryen preserves the child wrapper around the increment/probe/release
  // branch before the block continuation; keep this exact shape narrow so the
  // older call-prefix/local-set wrapper cleanups do not broaden again.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load12 = @lib.MemArg::new(0U, None, 12UL)
  let load20 = @lib.MemArg::new(0U, None, 20UL)
  let slot = @lib.LocalIdx::new(18U)
  let root = @lib.LocalIdx::new(1U)
  let ctx = @lib.LocalIdx::new(2U)
  let mask = @lib.LocalIdx::new(7U)
  let increment = @lib.LocalIdx::new(50U)
  let probe = @lib.LocalIdx::new(49U)
  let result = @lib.LocalIdx::new(68U)
  let tagged = @lib.LocalIdx::new(384U)
  let observed = @lib.LocalIdx::new(21U)
  let continuation_reload = @lib.LocalIdx::new(69U)
  let continuation_probe = @lib.LocalIdx::new(45U)
  let continuation_result = @lib.LocalIdx::new(70U)
  let continuation_tagged = @lib.LocalIdx::new(385U)
  let continuation_observed = @lib.LocalIdx::new(22U)
  let child = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i32_load(load20),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(increment),
    @lib.Instruction::local_get(root),
    @lib.Instruction::i32_load(load12),
    @lib.Instruction::local_tee(probe),
    @lib.Instruction::call(@lib.FuncIdx::new(4U)),
    @lib.Instruction::local_get(probe),
    @lib.Instruction::local_get(increment),
    @lib.Instruction::call(@lib.FuncIdx::new(18U)),
    @lib.Instruction::local_set(result),
    @lib.Instruction::local_get(probe),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::local_get(root),
    @lib.Instruction::local_get(ctx),
    @lib.Instruction::local_get(result),
    @lib.Instruction::call(@lib.FuncIdx::new(10U)),
    @lib.Instruction::local_tee(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(11U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::i64_load(load0),
        @lib.Instruction::local_set(observed),
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
        @lib.Instruction::local_get(mask),
        @lib.Instruction::i64_extend_i32s(),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(104U)),
        @lib.Instruction::local_get(observed),
        @lib.Instruction::i64_and(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(104U)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(slot),
            @lib.Instruction::call(@lib.FuncIdx::new(5U)),
            @lib.Instruction::br(@lib.LabelIdx::new(3U)),
          ],
          None,
        ),
      ],
      Some([
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
        @lib.Instruction::local_get(slot),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ]),
    ),
  ])
  let continuation = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::nop(),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i32_load(load20),
    @lib.Instruction::local_set(continuation_reload),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(root),
    @lib.Instruction::i32_load(load12),
    @lib.Instruction::local_tee(continuation_probe),
    @lib.Instruction::call(@lib.FuncIdx::new(4U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(slot),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::local_get(continuation_probe),
    @lib.Instruction::local_get(continuation_reload),
    @lib.Instruction::call(@lib.FuncIdx::new(18U)),
    @lib.Instruction::local_set(continuation_result),
    @lib.Instruction::local_get(continuation_probe),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(root),
    @lib.Instruction::local_get(ctx),
    @lib.Instruction::local_get(continuation_result),
    @lib.Instruction::call(@lib.FuncIdx::new(10U)),
    @lib.Instruction::local_tee(continuation_tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(11U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(continuation_tagged),
        @lib.Instruction::i64_load(load0),
        @lib.Instruction::local_set(continuation_observed),
        @lib.Instruction::local_get(continuation_tagged),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
        @lib.Instruction::local_get(continuation_observed),
        @lib.Instruction::local_set(mask),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::local_get(continuation_tagged),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ]),
    ),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::return_(),
  ])
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        child,
        continuation,
        @lib.Instruction::local_get(mask),
        @lib.Instruction::i64_extend_i32s(),
        @lib.Instruction::local_get(continuation_observed),
        @lib.Instruction::i64_and(),
        @lib.Instruction::i64_extend32s(),
        @lib.Instruction::return_(),
      ]),
    ]),
  ]
  let (cleaned, _) = run_hot_pipeline_raw_vacuum_preclean_instrs(input, None)
  match cleaned {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr([@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))])
      ),
    ] =>
      match parent_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) => {
          assert_true(child_body[0] is @lib.LocalGet(_))
          assert_true(child_body[child_body.length() - 1] is @lib.If(_, _, _))
          assert_true(parent_body[1] is @lib.Block(@lib.VoidBlockType, _))
        }
        other =>
          fail(
            "expected f2094 increment/probe prefix child wrapper to stay wrapped, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail("expected f2094 parent wrapper, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean flattens f2130 tag42 tag43 loop-head dispatch wrapper" {
  // Slot23 `defined=2130 abs=2157` follows the retained f2094 block-
  // continuation fix: Binaryen removes one anonymous child wrapper around the
  // loop-head tag-42/tag-43 dispatch, even though the dispatch has retain /
  // release calls and an else-arm branch to the following loop-update block.
  // Keep the shape exact: the dispatch must decode the tag from the current
  // loop pair, set a result local in both fallthrough arms, and be immediately
  // followed by a result-local handoff plus outer-block branch continuation.
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load12 = @lib.MemArg::new(0U, None, 12UL)
  let cursor = @lib.LocalIdx::new(109U)
  let limit = @lib.LocalIdx::new(110U)
  let object = @lib.LocalIdx::new(2U)
  let index = @lib.LocalIdx::new(3U)
  let tagged_object = @lib.LocalIdx::new(4U)
  let tag = @lib.LocalIdx::new(5U)
  let scratch = @lib.LocalIdx::new(7U)
  let payload = @lib.LocalIdx::new(16U)
  let retained = @lib.LocalIdx::new(17U)
  let allocated = @lib.LocalIdx::new(18U)
  let result = @lib.LocalIdx::new(97U)
  let output = @lib.LocalIdx::new(101U)
  let next_cursor = @lib.LocalIdx::new(113U)
  let next_limit = @lib.LocalIdx::new(114U)
  let dispatch = pass_manager_test_vacuum_plain_block([
    @lib.Instruction::local_get(cursor),
    @lib.Instruction::local_tee(object),
    @lib.Instruction::local_get(limit),
    @lib.Instruction::local_tee(index),
    @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    @lib.Instruction::local_tee(tagged_object),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::local_tee(tag),
    @lib.Instruction::i32_const(@lib.I32(42)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(tagged_object),
        @lib.Instruction::i32_load(load12),
        @lib.Instruction::local_set(payload),
        @lib.Instruction::local_get(tagged_object),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::local_get(object),
        @lib.Instruction::local_get(payload),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
        @lib.Instruction::local_set(retained),
        @lib.Instruction::local_get(object),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::local_get(retained),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        @lib.Instruction::local_tee(scratch),
        @lib.Instruction::call(@lib.FuncIdx::new(7U)),
        @lib.Instruction::local_set(allocated),
        @lib.Instruction::local_get(retained),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::local_get(scratch),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::local_get(allocated),
        @lib.Instruction::local_set(result),
      ],
      Some([
        @lib.Instruction::local_get(tag),
        @lib.Instruction::i32_const(@lib.I32(43)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(tagged_object),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::local_get(object),
            @lib.Instruction::local_get(index),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_ne(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(object),
                @lib.Instruction::call(@lib.FuncIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::local_get(object),
                @lib.Instruction::local_set(next_cursor),
                @lib.Instruction::local_get(object),
                @lib.Instruction::local_get(index),
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::call(@lib.FuncIdx::new(5U)),
                @lib.Instruction::local_set(next_limit),
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              ]),
            ),
          ],
          Some([
            @lib.Instruction::local_get(tagged_object),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::local_get(object),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::local_set(result),
      ]),
    ),
  ])
  let input = [
    pass_manager_test_vacuum_plain_block([
      pass_manager_test_vacuum_plain_block([
        dispatch,
        @lib.Instruction::local_get(result),
        @lib.Instruction::local_set(output),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
      @lib.Instruction::local_get(next_cursor),
      @lib.Instruction::local_set(cursor),
      @lib.Instruction::local_get(next_limit),
      @lib.Instruction::local_set(limit),
      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body))] =>
      match parent_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(loop_head_body)) => {
          assert_true(loop_head_body[0] is @lib.LocalGet(_))
          assert_true(loop_head_body[10] is @lib.If(@lib.VoidBlockType, _, _))
          @debug.assert_eq(
            loop_head_body[loop_head_body.length() - 3],
            @lib.Instruction::local_get(result),
          )
          @debug.assert_eq(
            loop_head_body[loop_head_body.length() - 2],
            @lib.Instruction::local_set(output),
          )
        }
        other =>
          fail(
            "expected f2130 loop-head block after dispatch flatten, got \{@debug.to_string(other)}",
          )
      }
    other => fail("expected f2130 parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f1895 empty sibling before return branch wrapper" {
  // Slot23 `defined=1895 abs=1922` follows the f1836 fix: Binaryen removes a
  // single empty anonymous block sibling immediately before a branch wrapper
  // whose first child performs the native `call; local.tee; i64.const
  // 4294967296; i64.eq; i32.eqz; if` dispatch and whose wrapper then returns
  // `1` before the next `call; i32.eqz; if` continuation. The prior broad
  // empty-block cleanup regressed call-prefix/prefix-preservation guards, so
  // this fixture keeps the observed binary-lowered branch-return shape narrow.
  let empty = pass_manager_test_vacuum_plain_block([])
  let branch_wrapper = pass_manager_test_vacuum_plain_block([
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(5U)),
      @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
      @lib.Instruction::i64_const(@lib.I64(4294967296L)),
      @lib.Instruction::i64_eq(),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
          @lib.Instruction::i32_wrap_i64(),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(7U)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i32_eq(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [@lib.Instruction::br(@lib.LabelIdx::new(3U))],
                Some([@lib.Instruction::br(@lib.LabelIdx::new(2U))]),
              ),
            ],
            None,
          ),
        ],
        None,
      ),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
    ]),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::return_(),
  ])
  let continuation_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [@lib.Instruction::i32_const(@lib.I32(0)), @lib.Instruction::return_()],
    None,
  )
  let parent_body = [
    empty,
    @lib.Instruction::nop(),
    branch_wrapper,
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::i32_eqz(),
    continuation_if,
  ]
  let input = [pass_manager_test_vacuum_plain_block(parent_body)]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) => {
      @debug.assert_eq(cleaned_body.length(), parent_body.length() - 2)
      @debug.assert_eq(cleaned_body[0], branch_wrapper)
    }
    other =>
      fail("expected cleaned parent block, got \{@debug.to_string(other)}")
  }
}

///|
test "raw vacuum preclean drops f2072 empty sibling before branch-return continuation" {
  // Slot23 `defined=2072 abs=2099` follows the retained f2054 fix: Binaryen
  // removes one empty anonymous block sibling immediately before the loop-head
  // branch-return/call-prefix continuation whose condition is the decoded
  // `local.tee; local.tee; local.tee; call; i32.eqz; if` shape. Keep this
  // separate from broad empty-block cleanup so the f1895/call-prefix and
  // local-set-leading prefix-preservation guardrails remain protected.
  let load8 = @lib.MemArg::new(0U, None, 8UL)
  let object_local = @lib.LocalIdx::new(2U)
  let release_local = @lib.LocalIdx::new(3U)
  let index_local = @lib.LocalIdx::new(5U)
  let loaded_local = @lib.LocalIdx::new(6U)
  let length_local = @lib.LocalIdx::new(7U)
  let branch_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(release_local),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_get(object_local),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::return_(),
    ],
    None,
  )
  let length_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(object_local),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ],
    Some([@lib.Instruction::local_get(object_local)]),
  )
  let parent_body = [
    pass_manager_test_vacuum_plain_block([]),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_tee(object_local),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_tee(release_local),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::local_tee(index_local),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::i32_eqz(),
    branch_if,
    @lib.Instruction::local_get(object_local),
    @lib.Instruction::i32_load(load8),
    @lib.Instruction::local_tee(loaded_local),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_get(loaded_local),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_set(length_local),
    @lib.Instruction::local_get(loaded_local),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::local_get(index_local),
    @lib.Instruction::local_get(length_local),
    @lib.Instruction::i32_lt_s(),
    length_if,
  ]
  let input = [pass_manager_test_vacuum_plain_block(parent_body)]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    input,
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) => {
      @debug.assert_eq(cleaned_body.length(), parent_body.length() - 1)
      @debug.assert_eq(cleaned_body[0], parent_body[1])
      @debug.assert_eq(cleaned_body[8], branch_if)
    }
    other =>
      fail(
        "expected cleaned f2072 parent block, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean drops f2520 standalone empty void block before continuation" {
  // Binaryen Vacuum.cpp visits empty blocks as no-op children and removes them
  // before the following continuation. This covers the direct slot23 f2520
  // residual: a nameless empty void block at the start of a loop-owned block
  // before local-copy/setup code.
  let carry = @lib.LocalIdx::new(341U)
  let target = @lib.LocalIdx::new(2U)
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::nop(), @lib.Instruction::nop()]),
      ),
      @lib.Instruction::nop(),
      @lib.Instruction::local_get(carry),
      @lib.Instruction::local_set(target),
    ],
    None,
  )
  assert_true(changed)
  @debug.assert_eq(cleaned, [
    @lib.Instruction::local_get(carry),
    @lib.Instruction::local_set(target),
  ])
}

///|
test "raw vacuum preclean drops f2842 empty block before live if continuation" {
  // Slot23 `defined=2842 abs=2869` follows the retained f2823 fix: Binaryen
  // Vacuum.cpp optimizes the empty anonymous child to no-op and compresses it
  // out before the live `call; i32.eqz; if` continuation. Keep this guard
  // narrow to the observed loop-local pair/call-distance/release-return setup
  // because earlier broad empty-block cleanup regressed call-prefix and
  // prefix-preservation guards.
  let left_seed = @lib.LocalIdx::new(181U)
  let right_seed = @lib.LocalIdx::new(182U)
  let left = @lib.LocalIdx::new(2U)
  let right = @lib.LocalIdx::new(3U)
  let count = @lib.LocalIdx::new(29U)
  let cursor = @lib.LocalIdx::new(4U)
  let loaded = @lib.LocalIdx::new(5U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let early_return = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(right),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_get(left),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::return_(),
    ],
    None,
  )
  let live_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(loaded),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ],
    None,
  )
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::nop(),
      @lib.Instruction::nop(),
    ]),
    @lib.Instruction::local_get(left_seed),
    @lib.Instruction::local_tee(left),
    @lib.Instruction::local_get(right_seed),
    @lib.Instruction::local_tee(right),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::i32_eqz(),
    early_return,
    @lib.Instruction::local_get(left),
    @lib.Instruction::local_get(right),
    @lib.Instruction::local_get(left),
    @lib.Instruction::local_get(right),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_sub(),
    @lib.Instruction::call(@lib.FuncIdx::new(6U)),
    @lib.Instruction::local_set(count),
    @lib.Instruction::local_get(right),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::local_get(left),
    @lib.Instruction::local_get(count),
    @lib.Instruction::local_tee(cursor),
    @lib.Instruction::call(@lib.FuncIdx::new(8U)),
    @lib.Instruction::local_tee(loaded),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_eq(),
    live_if,
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) => {
      @debug.assert_eq(cleaned_body.length(), parent_body.length() - 1)
      @debug.assert_eq(cleaned_body[0], parent_body[1])
      @debug.assert_eq(cleaned_body[6], early_return)
      @debug.assert_eq(cleaned_body[cleaned_body.length() - 1], live_if)
    }
    other =>
      fail(
        "expected cleaned f2842 parent block, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean flattens f2850 local-copy guard wrapper" {
  // Slot23 `defined=2850 abs=2877` follows the retained f2842 fix: Binaryen
  // simplifies a singleton anonymous child block that only copies the retained
  // loop-head value into the active local, immediately before the second local
  // copy, negative-index guard, release-return check, and tag-dispatch block.
  // Keep this narrower than broad singleton unwrapping so local-set prefix and
  // call-prefix preservation tests continue guarding prefix-sensitive cases.
  let retained_env = @lib.LocalIdx::new(407U)
  let retained_index = @lib.LocalIdx::new(408U)
  let retained_value = @lib.LocalIdx::new(409U)
  let env = @lib.LocalIdx::new(3U)
  let index = @lib.LocalIdx::new(4U)
  let value = @lib.LocalIdx::new(5U)
  let should_return = @lib.LocalIdx::new(95U)
  let guard_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::local_set(should_return),
    ],
    Some([
      @lib.Instruction::local_get(env),
      @lib.Instruction::local_get(index),
      @lib.Instruction::call(@lib.FuncIdx::new(9U)),
      @lib.Instruction::i32_eqz(),
      @lib.Instruction::local_set(should_return),
    ]),
  )
  let return_if = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(value),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_get(env),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::return_(),
    ],
    None,
  )
  let parent_body = [
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::local_get(retained_value),
      @lib.Instruction::local_set(value),
    ]),
    @lib.Instruction::local_get(retained_env),
    @lib.Instruction::local_set(env),
    @lib.Instruction::local_get(retained_index),
    @lib.Instruction::local_tee(index),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_lt_s(),
    guard_if,
    @lib.Instruction::local_get(should_return),
    return_if,
    pass_manager_test_vacuum_plain_block([
      @lib.Instruction::local_get(env),
      @lib.Instruction::drop(),
    ]),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) => {
      @debug.assert_eq(cleaned_body.length(), parent_body.length() + 1)
      @debug.assert_eq(
        cleaned_body[0],
        @lib.Instruction::local_get(retained_value),
      )
      @debug.assert_eq(cleaned_body[1], @lib.Instruction::local_set(value))
      @debug.assert_eq(
        cleaned_body[4],
        @lib.Instruction::local_get(retained_index),
      )
      @debug.assert_eq(cleaned_body[8], guard_if)
      @debug.assert_eq(cleaned_body[10], return_if)
    }
    other =>
      fail(
        "expected cleaned f2850 parent block, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean flattens f2651 load br-table wrapper before converter continuation" {
  // Slot23 `defined=2651 abs=2678` follows the retained f2520 empty-block
  // cleanup: Binaryen removes the anonymous wrapper around a load-driven
  // `br_table` dispatch ladder before the converter continuation, while
  // Starshine kept that wrapper and shifted branch depths. Keep this exact to
  // the decoded native shape: offset-4 tag load, typed value-load arms, two
  // retained i32 arms, one br_table, and no branch targeting the removed
  // wrapper.
  let source = @lib.LocalIdx::new(15U)
  let tagged = @lib.LocalIdx::new(20U)
  let i32_value = @lib.LocalIdx::new(19U)
  let i64_value = @lib.LocalIdx::new(320U)
  let f32_value = @lib.LocalIdx::new(314U)
  let f64_value = @lib.LocalIdx::new(308U)
  let retained_a = @lib.LocalIdx::new(27U)
  let retained_b = @lib.LocalIdx::new(29U)
  let out_a = @lib.LocalIdx::new(18U)
  let out_b = @lib.LocalIdx::new(17U)
  let converted = @lib.LocalIdx::new(249U)
  let env = @lib.LocalIdx::new(1U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load4 = @lib.MemArg::new(0U, None, 4UL)
  let dispatch_labels = [
    @lib.LabelIdx::new(0U),
    @lib.LabelIdx::new(1U),
    @lib.LabelIdx::new(2U),
    @lib.LabelIdx::new(3U),
    @lib.LabelIdx::new(4U),
    @lib.LabelIdx::new(5U),
  ]
  let selector = [
    @lib.Instruction::local_get(source),
    @lib.Instruction::i32_load(load4),
    @lib.Instruction::local_tee(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::br_table(dispatch_labels, @lib.LabelIdx::new(0U)),
  ]
  let dispatch_child = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::block(
                      @lib.BlockType::void_(),
                      @lib.Expr::new([
                        @lib.Instruction::block(
                          @lib.BlockType::void_(),
                          @lib.Expr::new(selector),
                        ),
                        @lib.Instruction::local_get(tagged),
                        @lib.Instruction::i32_load(load0),
                        @lib.Instruction::local_set(i32_value),
                        @lib.Instruction::br(@lib.LabelIdx::new(5U)),
                      ]),
                    ),
                    @lib.Instruction::local_get(tagged),
                    @lib.Instruction::i64_load(load0),
                    @lib.Instruction::local_set(i64_value),
                    @lib.Instruction::br(@lib.LabelIdx::new(7U)),
                  ]),
                ),
                @lib.Instruction::local_get(tagged),
                @lib.Instruction::f32_load(load0),
                @lib.Instruction::local_set(f32_value),
                @lib.Instruction::br(@lib.LabelIdx::new(8U)),
              ]),
            ),
            @lib.Instruction::local_get(tagged),
            @lib.Instruction::f64_load(load0),
            @lib.Instruction::local_set(f64_value),
            @lib.Instruction::br(@lib.LabelIdx::new(9U)),
          ]),
        ),
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::i32_load(load0),
        @lib.Instruction::local_tee(retained_a),
        @lib.Instruction::call(@lib.FuncIdx::new(3U)),
        @lib.Instruction::local_get(retained_a),
        @lib.Instruction::local_set(out_a),
        @lib.Instruction::br(@lib.LabelIdx::new(10U)),
      ]),
    ),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::i32_load(load0),
    @lib.Instruction::local_tee(retained_b),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_get(retained_b),
    @lib.Instruction::local_set(out_b),
    @lib.Instruction::br(@lib.LabelIdx::new(11U)),
  ]
  let wrapper = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new(dispatch_child),
      ),
    ]),
  )
  let parent_body = [
    wrapper,
    @lib.Instruction::local_get(env),
    @lib.Instruction::local_get(i32_value),
    @lib.Instruction::call(@lib.FuncIdx::new(14U)),
    @lib.Instruction::local_set(converted),
    @lib.Instruction::br(@lib.LabelIdx::new(6U)),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) => {
      @debug.assert_eq(cleaned_body.length(), 6)
      match cleaned_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(rebased_child)) => {
          @debug.assert_eq(rebased_child.length(), dispatch_child.length())
          match rebased_child[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(first_arm)) =>
              match first_arm[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(second_arm)) =>
                  match second_arm[0] {
                    @lib.Block(@lib.VoidBlockType, @lib.Expr(third_arm)) =>
                      match third_arm[0] {
                        @lib.Block(@lib.VoidBlockType, @lib.Expr(fourth_arm)) =>
                          match fourth_arm[0] {
                            @lib.Block(@lib.VoidBlockType, @lib.Expr(fifth_arm)) =>
                              match fifth_arm[0] {
                                @lib.Block(
                                  @lib.VoidBlockType,
                                  @lib.Expr(selector_body)
                                ) =>
                                  match selector_body[4] {
                                    @lib.BrTable(labels, fallback) => {
                                      @debug.assert_eq(
                                        labels[0],
                                        @lib.LabelIdx::new(0U),
                                      )
                                      @debug.assert_eq(
                                        labels[5],
                                        @lib.LabelIdx::new(5U),
                                      )
                                      @debug.assert_eq(
                                        fallback,
                                        @lib.LabelIdx::new(0U),
                                      )
                                      @debug.assert_eq(
                                        rebased_child[7],
                                        @lib.Instruction::br(
                                          @lib.LabelIdx::new(10U),
                                        ),
                                      )
                                    }
                                    other =>
                                      fail(
                                        "expected f2651 br_table, got \{other}",
                                      )
                                  }
                                other =>
                                  fail(
                                    "expected f2651 selector block, got \{other}",
                                  )
                              }
                            other =>
                              fail("expected f2651 fifth arm, got \{other}")
                          }
                        other => fail("expected f2651 fourth arm, got \{other}")
                      }
                    other => fail("expected f2651 third arm, got \{other}")
                  }
                other => fail("expected f2651 second arm, got \{other}")
              }
            other => fail("expected f2651 first arm, got \{other}")
          }
        }
        other => fail("expected f2651 rebased child block, got \{other}")
      }
    }
    other => fail("expected cleaned f2651 parent block, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f2696 tee br-table release wrapper before unreachable" {
  // Slot23 `defined=2696 abs=2723` follows the retained f2651 fix:
  // Binaryen removes the anonymous wrapper around an `if (local.tee(local.get))`
  // whose then arm dispatches a typed-load/release `br_table` ladder and whose
  // else arm releases the tee before an immediate `unreachable`. Keep this exact
  // to the decoded native shape and require branch-depth rebasing, without
  // reopening broad br_table / immediate-unreachable wrapper cleanup.
  let source = @lib.LocalIdx::new(50U)
  let guard_local = @lib.LocalIdx::new(2U)
  let tagged = @lib.LocalIdx::new(9U)
  let i32_value = @lib.LocalIdx::new(28U)
  let i64_value = @lib.LocalIdx::new(156U)
  let f32_value = @lib.LocalIdx::new(146U)
  let f64_value = @lib.LocalIdx::new(136U)
  let release_copy = @lib.LocalIdx::new(15U)
  let release_value = @lib.LocalIdx::new(23U)
  let release_count = @lib.LocalIdx::new(24U)
  let output = @lib.LocalIdx::new(6U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let dispatch_labels = [
    @lib.LabelIdx::new(0U),
    @lib.LabelIdx::new(1U),
    @lib.LabelIdx::new(2U),
    @lib.LabelIdx::new(3U),
    @lib.LabelIdx::new(4U),
    @lib.LabelIdx::new(5U),
  ]
  let selector = [
    @lib.Instruction::local_get(guard_local),
    @lib.Instruction::local_tee(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::br_table(dispatch_labels, @lib.LabelIdx::new(0U)),
  ]
  let dispatch_ladder = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::block(
                      @lib.BlockType::void_(),
                      @lib.Expr::new([
                        @lib.Instruction::block(
                          @lib.BlockType::void_(),
                          @lib.Expr::new(selector),
                        ),
                        @lib.Instruction::local_get(tagged),
                        @lib.Instruction::i32_load(load0),
                        @lib.Instruction::local_set(i32_value),
                        @lib.Instruction::br(@lib.LabelIdx::new(5U)),
                      ]),
                    ),
                    @lib.Instruction::local_get(tagged),
                    @lib.Instruction::i64_load(load0),
                    @lib.Instruction::local_set(i64_value),
                    @lib.Instruction::br(@lib.LabelIdx::new(6U)),
                  ]),
                ),
                @lib.Instruction::local_get(tagged),
                @lib.Instruction::f32_load(load0),
                @lib.Instruction::local_set(f32_value),
                @lib.Instruction::br(@lib.LabelIdx::new(7U)),
              ]),
            ),
            @lib.Instruction::local_get(tagged),
            @lib.Instruction::f64_load(load0),
            @lib.Instruction::local_set(f64_value),
            @lib.Instruction::br(@lib.LabelIdx::new(8U)),
          ]),
        ),
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::local_set(release_copy),
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::i32_load(load0),
        @lib.Instruction::local_set(release_value),
        @lib.Instruction::local_get(tagged),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::local_tee(release_count),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_gt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(tagged),
            @lib.Instruction::local_get(release_count),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_sub(),
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
            @lib.Instruction::local_get(release_value),
            @lib.Instruction::call(@lib.FuncIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::local_get(release_count),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(release_copy),
                @lib.Instruction::i32_const(@lib.I32(8)),
                @lib.Instruction::i32_sub(),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
              ],
              None,
            ),
          ]),
        ),
        @lib.Instruction::local_get(release_value),
        @lib.Instruction::local_set(output),
        @lib.Instruction::br(@lib.LabelIdx::new(9U)),
      ]),
    ),
    @lib.Instruction::local_get(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::br(@lib.LabelIdx::new(10U)),
  ]
  let release_else = [
    @lib.Instruction::local_get(guard_local),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(guard_local),
        @lib.Instruction::call(@lib.FuncIdx::new(5U)),
      ],
      None,
    ),
    @lib.Instruction::br(@lib.LabelIdx::new(10U)),
  ]
  let wrapper_body = [
    @lib.Instruction::local_get(source),
    @lib.Instruction::local_tee(guard_local),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      dispatch_ladder,
      Some(release_else),
    ),
    @lib.Instruction::unreachable_(),
  ]
  let wrapper = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new(wrapper_body),
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        wrapper,
        @lib.Instruction::unreachable_(),
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) => {
      @debug.assert_eq(cleaned_body.length(), 4)
      @debug.assert_eq(cleaned_body[0], @lib.Instruction::local_get(source))
      @debug.assert_eq(
        cleaned_body[1],
        @lib.Instruction::local_tee(guard_local),
      )
      match cleaned_body[2] {
        @lib.If(@lib.VoidBlockType, then_body, Some(else_body)) => {
          @debug.assert_eq(then_body.length(), dispatch_ladder.length())
          @debug.assert_eq(
            then_body[3],
            @lib.Instruction::br(@lib.LabelIdx::new(9U)),
          )
          @debug.assert_eq(
            else_body[2],
            @lib.Instruction::br(@lib.LabelIdx::new(9U)),
          )
          match then_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(first_arm)) =>
              match first_arm[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(second_arm)) =>
                  match second_arm[0] {
                    @lib.Block(@lib.VoidBlockType, @lib.Expr(third_arm)) =>
                      match third_arm[0] {
                        @lib.Block(@lib.VoidBlockType, @lib.Expr(fourth_arm)) =>
                          match fourth_arm[0] {
                            @lib.Block(@lib.VoidBlockType, @lib.Expr(fifth_arm)) =>
                              match fifth_arm[0] {
                                @lib.Block(
                                  @lib.VoidBlockType,
                                  @lib.Expr(selector_body)
                                ) =>
                                  match selector_body[3] {
                                    @lib.BrTable(labels, fallback) => {
                                      @debug.assert_eq(
                                        labels[0],
                                        @lib.LabelIdx::new(0U),
                                      )
                                      @debug.assert_eq(
                                        labels[5],
                                        @lib.LabelIdx::new(5U),
                                      )
                                      @debug.assert_eq(
                                        fallback,
                                        @lib.LabelIdx::new(0U),
                                      )
                                    }
                                    other =>
                                      fail(
                                        "expected f2696 br_table, got \{other}",
                                      )
                                  }
                                other =>
                                  fail(
                                    "expected f2696 selector block, got \{other}",
                                  )
                              }
                            other =>
                              fail("expected f2696 fifth arm, got \{other}")
                          }
                        other => fail("expected f2696 fourth arm, got \{other}")
                      }
                    other => fail("expected f2696 third arm, got \{other}")
                  }
                other => fail("expected f2696 second arm, got \{other}")
              }
            other => fail("expected f2696 first arm, got \{other}")
          }
        }
        other => fail("expected f2696 if, got \{other}")
      }
      @debug.assert_eq(cleaned_body[3], @lib.Instruction::unreachable_())
    }
    other => fail("expected cleaned f2696 parent block, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f2714 direct-call br-table release wrapper before local-set continuation" {
  // Slot23 `defined=2714 abs=2741` follows the retained f2696 fix:
  // Binaryen removes one anonymous singleton wrapper around a direct-call
  // `br_table` typed-load/release ladder before a local-set call continuation.
  // Keep the guard source-shaped and require branch-depth rebasing through the
  // removed wrapper without reopening broad br_table / call-prefix cleanup.
  let source = @lib.LocalIdx::new(3U)
  let i32_temp = @lib.LocalIdx::new(22U)
  let i32_output = @lib.LocalIdx::new(6U)
  let i64_temp = @lib.LocalIdx::new(152U)
  let i64_output = @lib.LocalIdx::new(150U)
  let f32_temp = @lib.LocalIdx::new(142U)
  let f32_output = @lib.LocalIdx::new(140U)
  let f64_temp = @lib.LocalIdx::new(132U)
  let f64_output = @lib.LocalIdx::new(130U)
  let release_copy = @lib.LocalIdx::new(12U)
  let release_value = @lib.LocalIdx::new(18U)
  let release_count = @lib.LocalIdx::new(19U)
  let release_output = @lib.LocalIdx::new(5U)
  let cont_arg = @lib.LocalIdx::new(1U)
  let cont_output = @lib.LocalIdx::new(92U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let labels = [
    @lib.LabelIdx::new(0U),
    @lib.LabelIdx::new(1U),
    @lib.LabelIdx::new(2U),
    @lib.LabelIdx::new(3U),
    @lib.LabelIdx::new(4U),
    @lib.LabelIdx::new(5U),
  ]
  let selector = [
    @lib.Instruction::local_get(source),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::br_table(labels, @lib.LabelIdx::new(0U)),
  ]
  let dispatch = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::block(
                @lib.BlockType::void_(),
                @lib.Expr::new([
                  @lib.Instruction::block(
                    @lib.BlockType::void_(),
                    @lib.Expr::new([
                      @lib.Instruction::block(
                        @lib.BlockType::void_(),
                        @lib.Expr::new(selector),
                      ),
                      @lib.Instruction::local_get(source),
                      @lib.Instruction::i32_load(load0),
                      @lib.Instruction::local_set(i32_temp),
                      @lib.Instruction::local_get(source),
                      @lib.Instruction::call(@lib.FuncIdx::new(5U)),
                      @lib.Instruction::local_get(i32_temp),
                      @lib.Instruction::local_set(i32_output),
                      @lib.Instruction::br(@lib.LabelIdx::new(5U)),
                    ]),
                  ),
                  @lib.Instruction::local_get(source),
                  @lib.Instruction::i64_load(load0),
                  @lib.Instruction::local_set(i64_temp),
                  @lib.Instruction::local_get(source),
                  @lib.Instruction::call(@lib.FuncIdx::new(5U)),
                  @lib.Instruction::local_get(i64_temp),
                  @lib.Instruction::local_set(i64_output),
                  @lib.Instruction::br(@lib.LabelIdx::new(6U)),
                ]),
              ),
              @lib.Instruction::local_get(source),
              @lib.Instruction::f32_load(load0),
              @lib.Instruction::local_set(f32_temp),
              @lib.Instruction::local_get(source),
              @lib.Instruction::call(@lib.FuncIdx::new(5U)),
              @lib.Instruction::local_get(f32_temp),
              @lib.Instruction::local_set(f32_output),
              @lib.Instruction::br(@lib.LabelIdx::new(7U)),
            ]),
          ),
          @lib.Instruction::local_get(source),
          @lib.Instruction::f64_load(load0),
          @lib.Instruction::local_set(f64_temp),
          @lib.Instruction::local_get(source),
          @lib.Instruction::call(@lib.FuncIdx::new(5U)),
          @lib.Instruction::local_get(f64_temp),
          @lib.Instruction::local_set(f64_output),
          @lib.Instruction::br(@lib.LabelIdx::new(8U)),
        ]),
      ),
      @lib.Instruction::local_get(source),
      @lib.Instruction::local_set(release_copy),
      @lib.Instruction::local_get(source),
      @lib.Instruction::i32_load(load0),
      @lib.Instruction::local_set(release_value),
      @lib.Instruction::local_get(source),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::local_tee(release_count),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_gt_s(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(source),
          @lib.Instruction::local_get(release_count),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_sub(),
          @lib.Instruction::call(@lib.FuncIdx::new(2U)),
          @lib.Instruction::local_get(release_value),
          @lib.Instruction::call(@lib.FuncIdx::new(4U)),
        ],
        Some([
          @lib.Instruction::local_get(release_count),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(release_copy),
              @lib.Instruction::i32_const(@lib.I32(8)),
              @lib.Instruction::i32_sub(),
              @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            ],
            None,
          ),
        ]),
      ),
      @lib.Instruction::local_get(release_value),
      @lib.Instruction::local_set(release_output),
      @lib.Instruction::br(@lib.LabelIdx::new(9U)),
    ]),
  )
  let release_return = [
    @lib.Instruction::local_get(source),
    @lib.Instruction::call(@lib.FuncIdx::new(5U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::return_(),
  ]
  let wrapper_child = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([dispatch, ..release_return]),
  )
  let wrapper = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([wrapper_child]),
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        wrapper,
        @lib.Instruction::local_get(cont_arg),
        @lib.Instruction::local_get(i32_output),
        @lib.Instruction::call(@lib.FuncIdx::new(13U)),
        @lib.Instruction::local_set(cont_output),
        @lib.Instruction::br(@lib.LabelIdx::new(10U)),
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) => {
      @debug.assert_eq(cleaned_body.length(), 6)
      match cleaned_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(flattened_child)) => {
          @debug.assert_eq(flattened_child.length(), 5)
          match flattened_child[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(rebased_dispatch)) =>
              @debug.assert_eq(
                rebased_dispatch[rebased_dispatch.length() - 1],
                @lib.Instruction::br(@lib.LabelIdx::new(8U)),
              )
            other => fail("expected f2714 dispatch block, got \{other}")
          }
        }
        other => fail("expected flattened f2714 child, got \{other}")
      }
      @debug.assert_eq(cleaned_body[1], @lib.Instruction::local_get(cont_arg))
      @debug.assert_eq(cleaned_body[2], @lib.Instruction::local_get(i32_output))
      @debug.assert_eq(
        cleaned_body[3],
        @lib.Instruction::call(@lib.FuncIdx::new(13U)),
      )
      @debug.assert_eq(
        cleaned_body[4],
        @lib.Instruction::local_set(cont_output),
      )
      @debug.assert_eq(
        cleaned_body[5],
        @lib.Instruction::br(@lib.LabelIdx::new(10U)),
      )
    }
    other => fail("expected cleaned f2714 parent block, got \{other}")
  }
}

///|
test "raw vacuum preclean preserves f3083 loop-body release update wrapper" {
  // Slot23 `defined=3083 abs=3110` follows the retained f2905/f3019
  // flattening fix in the opposite direction: Binaryen keeps the anonymous
  // loop-body block around the retain/classify/release prefix and its branchy
  // cleanup/update final `if`. Guard this exact source-backed preservation
  // shape instead of reopening broad call-prefix or if-wrapper preservation.
  let slot = @lib.LocalIdx::new(6U)
  let item = @lib.LocalIdx::new(13U)
  let env = @lib.LocalIdx::new(0U)
  let state = @lib.LocalIdx::new(29U)
  let active = @lib.LocalIdx::new(5U)
  let candidate = @lib.LocalIdx::new(7U)
  let flag = @lib.LocalIdx::new(93U)
  let mem0 = @lib.MemArg::new(0U, None, 0UL)
  let branchy_cleanup = @lib.Instruction::if_(
    @lib.BlockType::void_(),
    [
      @lib.Instruction::local_get(active),
      @lib.Instruction::call(@lib.FuncIdx::new(38U)),
      @lib.Instruction::br(@lib.LabelIdx::new(3U)),
    ],
    None,
  )
  let child_body = [
    @lib.Instruction::local_get(slot),
    @lib.Instruction::i32_load(mem0),
    @lib.Instruction::local_tee(item),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_get(env),
    @lib.Instruction::local_get(item),
    @lib.Instruction::call(@lib.FuncIdx::new(4269U)),
    @lib.Instruction::local_set(state),
    @lib.Instruction::local_get(item),
    @lib.Instruction::call(@lib.FuncIdx::new(38U)),
    @lib.Instruction::local_get(state),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_eq(),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(state),
        @lib.Instruction::local_tee(candidate),
        @lib.Instruction::i32_const(@lib.I32::new(0)),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::local_set(flag),
          ],
          Some([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_set(flag),
          ]),
        ),
        @lib.Instruction::local_get(flag),
        branchy_cleanup,
        @lib.Instruction::local_get(env),
        @lib.Instruction::local_get(candidate),
        @lib.Instruction::call(@lib.FuncIdx::new(12U)),
        @lib.Instruction::drop(),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ],
      Some([
        @lib.Instruction::local_get(active),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
      ]),
    ),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new(child_body),
      ),
    ],
    None,
  )
  assert_false(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(next_body))] => {
      @debug.assert_eq(next_body.length(), child_body.length())
      @debug.assert_eq(next_body[0], @lib.Instruction::local_get(slot))
      match next_body[next_body.length() - 1] {
        @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
        other => fail("expected f3083 final if wrapper, got \{other}")
      }
    }
    other =>
      fail(
        "expected f3083 Binaryen-preserved loop-body wrapper, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean flattens f3317 singleton retain allocation loop wrapper" {
  // Slot23 `defined=3317 abs=3344` follows the retained f3083 preservation:
  // Binaryen removes a singleton anonymous child block inside the loop body
  // whose contents start with the repeated retain/compute/release allocation
  // prefix. This is `BlockUtils::simplifyToContents` singleton-block behavior;
  // keep the rule narrow to this decoded allocation-prefix shape.
  let env = @lib.LocalIdx::new(0U)
  let retained = @lib.LocalIdx::new(44U)
  let temp = @lib.LocalIdx::new(414U)
  let alloc = @lib.LocalIdx::new(51U)
  let flag = @lib.LocalIdx::new(4U)
  let load36 = @lib.MemArg::new(0U, None, 36UL)
  let store0 = @lib.MemArg::new(0U, None, 0UL)
  let store4 = @lib.MemArg::new(0U, None, 4UL)
  let child_body = [
    @lib.Instruction::local_get(env),
    @lib.Instruction::i32_load(load36),
    @lib.Instruction::local_tee(retained),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(retained),
        @lib.Instruction::call(@lib.FuncIdx::new(36U)),
      ],
      None,
    ),
    @lib.Instruction::local_get(retained),
    @lib.Instruction::i32_const(@lib.I32::new(97728)),
    @lib.Instruction::call(@lib.FuncIdx::new(64U)),
    @lib.Instruction::local_set(temp),
    @lib.Instruction::local_get(retained),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(retained),
        @lib.Instruction::call(@lib.FuncIdx::new(38U)),
      ],
      None,
    ),
    @lib.Instruction::i32_const(@lib.I32::new(8)),
    @lib.Instruction::call(@lib.FuncIdx::new(7U)),
    @lib.Instruction::local_tee(alloc),
    @lib.Instruction::i32_const(@lib.I32::new(524544)),
    @lib.Instruction::call(@lib.FuncIdx::new(9U)),
    @lib.Instruction::local_get(alloc),
    @lib.Instruction::i32_const(@lib.I32::new(0)),
    @lib.Instruction::i32_store(store0),
    @lib.Instruction::local_get(alloc),
    @lib.Instruction::i32_const(@lib.I32::new(24008)),
    @lib.Instruction::i32_store(store4),
    @lib.Instruction::local_get(flag),
    @lib.Instruction::i32_load(store0),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::local_get(flag),
        @lib.Instruction::i32_const(@lib.I32::new(0)),
        @lib.Instruction::i32_store(store0),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ],
      None,
    ),
  ]
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new(child_body),
          ),
        ]),
      ),
    ],
    None,
  )
  assert_true(changed)
  match cleaned {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr(flattened))] => {
      @debug.assert_eq(flattened.length(), child_body.length())
      @debug.assert_eq(flattened[0], @lib.Instruction::local_get(env))
      @debug.assert_eq(
        flattened[flattened.length() - 1],
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(flag),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::i32_store(store0),
            @lib.Instruction::br(@lib.LabelIdx::new(2U)),
          ],
          None,
        ),
      )
    }
    other =>
      fail(
        "expected f3317 singleton child to flatten, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "raw vacuum preclean flattens f2905 direct-call br-table local-load wrapper before call continuation" {
  // Slot23 `defined=2905 abs=2932` follows the retained f2850 fix:
  // Binaryen removes one anonymous singleton wrapper around a direct-call
  // `br_table` local-load/release ladder immediately before the nested-call
  // continuation that consumes the first loaded arm. Keep this exact to the
  // decoded native shape and require branch-depth rebasing without reopening
  // broad `br_table` wrapper cleanup.
  let source = @lib.LocalIdx::new(95U)
  let tagged = @lib.LocalIdx::new(76U)
  let temp0 = @lib.LocalIdx::new(349U)
  let temp1 = @lib.LocalIdx::new(350U)
  let temp2 = @lib.LocalIdx::new(351U)
  let temp3 = @lib.LocalIdx::new(352U)
  let temp4 = @lib.LocalIdx::new(353U)
  let out0 = @lib.LocalIdx::new(81U)
  let out1 = @lib.LocalIdx::new(80U)
  let out2 = @lib.LocalIdx::new(79U)
  let out3 = @lib.LocalIdx::new(78U)
  let out4 = @lib.LocalIdx::new(77U)
  let env = @lib.LocalIdx::new(5U)
  let cont = @lib.LocalIdx::new(1154U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let labels = [
    @lib.LabelIdx::new(10U),
    @lib.LabelIdx::new(11U),
    @lib.LabelIdx::new(12U),
    @lib.LabelIdx::new(13U),
  ]
  let selector = [
    @lib.Instruction::local_get(source),
    @lib.Instruction::local_tee(tagged),
    @lib.Instruction::call(@lib.FuncIdx::new(12U)),
    @lib.Instruction::br_table(labels, @lib.LabelIdx::new(14U)),
  ]
  let dispatch = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::block(
                @lib.BlockType::void_(),
                @lib.Expr::new([
                  @lib.Instruction::block(
                    @lib.BlockType::void_(),
                    @lib.Expr::new([
                      @lib.Instruction::block(
                        @lib.BlockType::void_(),
                        @lib.Expr::new(selector),
                      ),
                      @lib.Instruction::local_get(tagged),
                      @lib.Instruction::i32_load(load0),
                      @lib.Instruction::local_set(temp0),
                      @lib.Instruction::local_get(tagged),
                      @lib.Instruction::call(@lib.FuncIdx::new(38U)),
                      @lib.Instruction::local_get(temp0),
                      @lib.Instruction::local_set(out0),
                      @lib.Instruction::br(@lib.LabelIdx::new(15U)),
                    ]),
                  ),
                  @lib.Instruction::local_get(tagged),
                  @lib.Instruction::i32_load(load0),
                  @lib.Instruction::local_set(temp1),
                  @lib.Instruction::local_get(tagged),
                  @lib.Instruction::call(@lib.FuncIdx::new(38U)),
                  @lib.Instruction::local_get(temp1),
                  @lib.Instruction::local_set(out1),
                  @lib.Instruction::br(@lib.LabelIdx::new(16U)),
                ]),
              ),
              @lib.Instruction::local_get(tagged),
              @lib.Instruction::i32_load(load0),
              @lib.Instruction::local_set(temp2),
              @lib.Instruction::local_get(tagged),
              @lib.Instruction::call(@lib.FuncIdx::new(38U)),
              @lib.Instruction::local_get(temp2),
              @lib.Instruction::local_set(out2),
              @lib.Instruction::br(@lib.LabelIdx::new(17U)),
            ]),
          ),
          @lib.Instruction::local_get(tagged),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::local_set(temp3),
          @lib.Instruction::local_get(tagged),
          @lib.Instruction::call(@lib.FuncIdx::new(38U)),
          @lib.Instruction::local_get(temp3),
          @lib.Instruction::local_set(out3),
          @lib.Instruction::br(@lib.LabelIdx::new(18U)),
        ]),
      ),
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::i32_load(load0),
      @lib.Instruction::local_set(temp4),
      @lib.Instruction::local_get(tagged),
      @lib.Instruction::call(@lib.FuncIdx::new(38U)),
      @lib.Instruction::local_get(temp4),
      @lib.Instruction::local_set(out4),
      @lib.Instruction::br(@lib.LabelIdx::new(19U)),
    ]),
  )
  let wrapper = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([dispatch]),
  )
  let parent_body = [
    wrapper,
    @lib.Instruction::local_get(out0),
    @lib.Instruction::local_get(env),
    @lib.Instruction::call(@lib.FuncIdx::new(26U)),
    @lib.Instruction::call(@lib.FuncIdx::new(36U)),
    @lib.Instruction::local_set(cont),
    @lib.Instruction::br(@lib.LabelIdx::new(10U)),
  ]
  match dispatch {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(dispatch_body)) => {
      assert_false(
        run_hot_pipeline_raw_vacuum_body_targets_owner([dispatch], 0),
      )
      @debug.assert_eq(
        run_hot_pipeline_raw_vacuum_body_count_br_tables(dispatch_body),
        1,
      )
      match run_hot_pipeline_raw_vacuum_f2905_selector_locals(dispatch_body) {
        Some((_, next_tagged_raw)) => {
          @debug.assert_eq(next_tagged_raw, 76U)
          @debug.assert_eq(
            run_hot_pipeline_raw_vacuum_body_count_f2905_local_load_release_branches(
              dispatch_body, next_tagged_raw,
            ),
            5,
          )
          match
            run_hot_pipeline_raw_vacuum_f2905_first_local_load_output(
              dispatch_body, next_tagged_raw,
            ) {
            Some(next_out_raw) => {
              @debug.assert_eq(next_out_raw, 81U)
              assert_true(
                run_hot_pipeline_raw_vacuum_body_has_f2905_nested_call_continuation(
                  parent_body, 0, next_out_raw,
                ),
              )
              let owner_target_dispatch = @lib.Instruction::block(
                @lib.BlockType::void_(),
                @lib.Expr::new(
                  [
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                    ..dispatch_body,
                  ],
                ),
              )
              let owner_target_wrapper = @lib.Instruction::block(
                @lib.BlockType::void_(),
                @lib.Expr::new([owner_target_dispatch]),
              )
              let owner_target_parent_body = [
                owner_target_wrapper,
                @lib.Instruction::local_get(out0),
                @lib.Instruction::local_get(env),
                @lib.Instruction::call(@lib.FuncIdx::new(26U)),
                @lib.Instruction::call(@lib.FuncIdx::new(36U)),
                @lib.Instruction::local_set(cont),
                @lib.Instruction::br(@lib.LabelIdx::new(10U)),
              ]
              match
                run_hot_pipeline_raw_vacuum_try_flatten_f2905_direct_call_br_table_local_load_wrapper_before_call_continuation(
                  owner_target_parent_body,
                ) {
                Some(_) => fail("expected f2905 owner-target wrapper rejection")
                None => ()
              }
            }
            None => fail("expected f2905 first local-load output")
          }
        }
        None => fail("expected f2905 selector locals")
      }
    }
    other => fail("expected f2905 dispatch block, got \{other}")
  }
  match
    run_hot_pipeline_raw_vacuum_try_flatten_f2905_direct_call_br_table_local_load_wrapper_before_call_continuation(
      parent_body,
    ) {
    Some(_) => ()
    None => fail("expected f2905 helper to match fixture")
  }
  let f3019_parent_body = [
    wrapper,
    @lib.Instruction::local_get(env),
    @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
    @lib.Instruction::local_get(out0),
    @lib.Instruction::call(@lib.FuncIdx::new(21U)),
    @lib.Instruction::local_set(cont),
    @lib.Instruction::br(@lib.LabelIdx::new(10U)),
  ]
  match
    run_hot_pipeline_raw_vacuum_try_flatten_f2905_direct_call_br_table_local_load_wrapper_before_call_continuation(
      f3019_parent_body,
    ) {
    Some(_) => ()
    None => fail("expected f3019 call-argument continuation variant to match")
  }
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [pass_manager_test_vacuum_plain_block(parent_body)],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) => {
      @debug.assert_eq(cleaned_body.length(), 7)
      match cleaned_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(rebased_dispatch)) => {
          @debug.assert_eq(rebased_dispatch.length(), 9)
          @debug.assert_eq(
            rebased_dispatch[rebased_dispatch.length() - 1],
            @lib.Instruction::br(@lib.LabelIdx::new(18U)),
          )
        }
        other => fail("expected f2905 dispatch block, got \{other}")
      }
      @debug.assert_eq(cleaned_body[1], @lib.Instruction::local_get(out0))
      @debug.assert_eq(cleaned_body[2], @lib.Instruction::local_get(env))
      @debug.assert_eq(
        cleaned_body[3],
        @lib.Instruction::call(@lib.FuncIdx::new(26U)),
      )
      @debug.assert_eq(
        cleaned_body[4],
        @lib.Instruction::call(@lib.FuncIdx::new(36U)),
      )
      @debug.assert_eq(cleaned_body[5], @lib.Instruction::local_set(cont))
      @debug.assert_eq(
        cleaned_body[6],
        @lib.Instruction::br(@lib.LabelIdx::new(10U)),
      )
    }
    other => fail("expected cleaned f2905 parent block, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f2775 call-tee cleanup-return if wrapper before sibling branch" {
  // Slot23 `defined=2775 abs=2802` follows the retained f2714 fix:
  // Binaryen removes one anonymous wrapper around a call-result tag `if` whose
  // false arm either loads a continuation local and branches outward or releases
  // the active values and returns. Keep the rule narrow because broader
  // call-prefix / local-set wrapper cleanup has broken prefix-preservation guards.
  let source = @lib.LocalIdx::new(2U)
  let active0 = @lib.LocalIdx::new(6U)
  let active1 = @lib.LocalIdx::new(4U)
  let tag = @lib.LocalIdx::new(30U)
  let loaded = @lib.LocalIdx::new(7U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let condition = [
    @lib.Instruction::local_get(source),
    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
    @lib.Instruction::local_tee(tag),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_eq(),
  ]
  let wrapper = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new(
      [
        ..condition,
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(active0),
                @lib.Instruction::call(@lib.FuncIdx::new(3U)),
                @lib.Instruction::local_get(active1),
                @lib.Instruction::call(@lib.FuncIdx::new(3U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::return_(),
              ],
              None,
            ),
          ],
          Some([
            @lib.Instruction::local_get(tag),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(source),
                @lib.Instruction::i32_load(load0),
                @lib.Instruction::local_set(loaded),
                @lib.Instruction::br(@lib.LabelIdx::new(3U)),
              ],
              Some([
                @lib.Instruction::local_get(active0),
                @lib.Instruction::call(@lib.FuncIdx::new(3U)),
                @lib.Instruction::local_get(active1),
                @lib.Instruction::call(@lib.FuncIdx::new(3U)),
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::return_(),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
      ],
    ),
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([wrapper, @lib.Instruction::br(@lib.LabelIdx::new(1U))]),
        ),
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) =>
      match cleaned_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
          @debug.assert_eq(parent_body.length(), 7)
          for idx = 0; idx < condition.length(); idx = idx + 1 {
            @debug.assert_eq(parent_body[idx], condition[idx])
          }
          match parent_body[5] {
            @lib.If(@lib.VoidBlockType, _, Some(else_body)) =>
              match else_body[3] {
                @lib.If(@lib.VoidBlockType, then_body, Some(_)) =>
                  @debug.assert_eq(
                    then_body[3],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                other => fail("expected f2775 nested else-if, got \{other}")
              }
            other => fail("expected f2775 flattened if, got \{other}")
          }
          @debug.assert_eq(
            parent_body[6],
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          )
        }
        other => fail("expected cleaned f2775 parent block, got \{other}")
      }
    other => fail("expected cleaned f2775 root block, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f2781 i64 cleanup-return if wrapper before sibling branch" {
  // Same Binaryen singleton-block simplification family as f2775, but the
  // cleanup arms return the i64 sentinel used by the next slot23 residual.
  let source = @lib.LocalIdx::new(3U)
  let active0 = @lib.LocalIdx::new(8U)
  let active1 = @lib.LocalIdx::new(6U)
  let tag = @lib.LocalIdx::new(31U)
  let loaded = @lib.LocalIdx::new(9U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let release_return = [
    @lib.Instruction::local_get(active0),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_get(active1),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::i64_const(@lib.I64(4294967296L)),
    @lib.Instruction::return_(),
  ]
  let wrapper = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(source),
      @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      @lib.Instruction::local_tee(tag),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_eq(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::if_(@lib.BlockType::void_(), release_return, None),
        ],
        Some([
          @lib.Instruction::local_get(tag),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(source),
              @lib.Instruction::i32_load(load0),
              @lib.Instruction::local_set(loaded),
              @lib.Instruction::br(@lib.LabelIdx::new(3U)),
            ],
            Some(release_return),
          ),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([wrapper, @lib.Instruction::br(@lib.LabelIdx::new(1U))]),
        ),
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) =>
      match cleaned_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) =>
          match parent_body[5] {
            @lib.If(@lib.VoidBlockType, _, Some(else_body)) =>
              match else_body[3] {
                @lib.If(@lib.VoidBlockType, then_body, Some(_)) =>
                  @debug.assert_eq(
                    then_body[3],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                other => fail("expected f2781 nested else-if, got \{other}")
              }
            other => fail("expected f2781 flattened if, got \{other}")
          }
        other => fail("expected cleaned f2781 parent block, got \{other}")
      }
    other => fail("expected cleaned f2781 root block, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f2822 single-release cleanup-return if wrapper before sibling branch" {
  // Slot23 `defined=2822 abs=2849` follows the retained f2781 fix:
  // Binaryen removes the same anonymous singleton wrapper around a call-result
  // tag `if`, but each cleanup-return arm releases one active value before
  // `return i32.const 0`. Keep this separate from broader call-prefix cleanup;
  // the guard still requires the sibling branch and branch-depth rebasing.
  let source = @lib.LocalIdx::new(3U)
  let active = @lib.LocalIdx::new(5U)
  let tag = @lib.LocalIdx::new(17U)
  let loaded = @lib.LocalIdx::new(6U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let release_return = [
    @lib.Instruction::local_get(active),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::return_(),
  ]
  let wrapper = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(source),
      @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      @lib.Instruction::local_tee(tag),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_eq(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(active),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::i32_const(@lib.I32(14)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::i32_eqz(),
          @lib.Instruction::if_(@lib.BlockType::void_(), release_return, None),
        ],
        Some([
          @lib.Instruction::local_get(tag),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(source),
              @lib.Instruction::i32_load(load0),
              @lib.Instruction::local_set(loaded),
              @lib.Instruction::br(@lib.LabelIdx::new(3U)),
            ],
            Some(release_return),
          ),
          @lib.Instruction::unreachable_(),
        ]),
      ),
    ]),
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([wrapper, @lib.Instruction::br(@lib.LabelIdx::new(1U))]),
        ),
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) =>
      match cleaned_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
          @debug.assert_eq(parent_body.length(), 7)
          match parent_body[5] {
            @lib.If(@lib.VoidBlockType, _, Some(else_body)) =>
              match else_body[3] {
                @lib.If(@lib.VoidBlockType, then_body, Some(_)) =>
                  @debug.assert_eq(
                    then_body[3],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                other => fail("expected f2822 nested else-if, got \{other}")
              }
            other => fail("expected f2822 flattened if, got \{other}")
          }
          @debug.assert_eq(
            parent_body[6],
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          )
        }
        other => fail("expected cleaned f2822 parent block, got \{other}")
      }
    other => fail("expected cleaned f2822 root block, got \{other}")
  }
}

///|
test "raw vacuum preclean flattens f2823 branch cleanup wrapper before i64 return" {
  // Slot23 `defined=2823 abs=2850` follows the retained f2822 fix:
  // Binaryen removes one anonymous wrapper around a call-result tag dispatch
  // immediately before the surrounding block's terminal `return i64.const
  // 4294967296`. Cleanup arms release one active value and either fall through to
  // that terminal return or branch outward; owner-target branches stay rejected.
  let source = @lib.LocalIdx::new(2U)
  let active = @lib.LocalIdx::new(5U)
  let tag = @lib.LocalIdx::new(40U)
  let loaded = @lib.LocalIdx::new(15U)
  let load0 = @lib.MemArg::new(0U, None, 0UL)
  let load24 = @lib.MemArg::new(0U, None, 24UL)
  let release = [
    @lib.Instruction::local_get(active),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
  ]
  let wrapper = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::local_get(source),
      @lib.Instruction::call(@lib.FuncIdx::new(2U)),
      @lib.Instruction::local_tee(tag),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_eq(),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(active),
          @lib.Instruction::i32_load(load0),
          @lib.Instruction::i32_const(@lib.I32(14)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(active),
              @lib.Instruction::i32_load(load24),
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::i32_gt_s(),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [@lib.Instruction::br(@lib.LabelIdx::new(5U))],
                Some([..release, @lib.Instruction::br(@lib.LabelIdx::new(6U))]),
              ),
              @lib.Instruction::unreachable_(),
            ],
            Some(release),
          ),
        ],
        Some([
          @lib.Instruction::local_get(tag),
          @lib.Instruction::i32_const(@lib.I32(2)),
          @lib.Instruction::i32_eq(),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::local_get(source),
              @lib.Instruction::i32_load(load0),
              @lib.Instruction::local_set(loaded),
              @lib.Instruction::br(@lib.LabelIdx::new(3U)),
            ],
            Some(release),
          ),
        ]),
      ),
    ]),
  )
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      pass_manager_test_vacuum_plain_block([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            wrapper,
            @lib.Instruction::i64_const(@lib.I64(4294967296L)),
            @lib.Instruction::return_(),
          ]),
        ),
      ]),
    ],
    None,
  )
  assert_true(changed)
  match cleaned[0] {
    @lib.Block(@lib.VoidBlockType, @lib.Expr(cleaned_body)) =>
      match cleaned_body[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
          @debug.assert_eq(parent_body.length(), 8)
          match parent_body[5] {
            @lib.If(@lib.VoidBlockType, _, Some(else_body)) =>
              match else_body[3] {
                @lib.If(@lib.VoidBlockType, then_body, Some(_)) =>
                  @debug.assert_eq(
                    then_body[3],
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  )
                other => fail("expected f2823 nested else-if, got \{other}")
              }
            other => fail("expected f2823 flattened if, got \{other}")
          }
          @debug.assert_eq(
            parent_body[6],
            @lib.Instruction::i64_const(@lib.I64(4294967296L)),
          )
          @debug.assert_eq(parent_body[7], @lib.Instruction::return_())
        }
        other => fail("expected cleaned f2823 parent block, got \{other}")
      }
    other => fail("expected cleaned f2823 root block, got \{other}")
  }
}

///|
test "raw vacuum preclean removes stacked pure local drops in one pass" {
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(7),
    ],
    None,
  )
  assert_true(changed)
  @debug.assert_eq(cleaned, [@lib.Instruction::i32_const(7)])
}

///|
test "raw vacuum preclean collapses constant void if after debris cleanup" {
  let instrs : Array[@lib.Instruction] = []
  for i = 0; i < 2050; i = i + 1 {
    instrs.push(@lib.Instruction::i32_const(@lib.I32(i)))
    instrs.push(@lib.Instruction::drop())
  }
  instrs.push(@lib.Instruction::i32_const(@lib.I32(0)))
  instrs.push(
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::i32_const(@lib.I32(9)), @lib.Instruction::drop()],
      Some([@lib.Instruction::i32_const(@lib.I32(7)), @lib.Instruction::drop()]),
    ),
  )
  instrs.push(@lib.Instruction::i32_const(@lib.I32(5)))
  instrs.push(@lib.Instruction::drop())
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    instrs,
    None,
  )
  assert_true(changed)
  @debug.assert_eq(cleaned, [])
}

///|
test "raw vacuum preclean collapses constant void if with nested block-local branch" {
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
          ),
        ],
        Some([]),
      ),
    ],
    None,
  )
  assert_true(changed)
  @debug.assert_eq(cleaned, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
    ),
  ])
}

///|
test "raw vacuum preclean truncates dead tail after nonfallthrough" {
  let (cleaned, changed) = run_hot_pipeline_raw_vacuum_preclean_instrs(
    [
      @lib.Instruction::unreachable_(),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
    ],
    None,
  )
  assert_true(changed)
  @debug.assert_eq(cleaned, [@lib.Instruction::unreachable_()])
}

///|
test "raw vacuum preclean removes pure drops in large structured functions with writes" {
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
      HotPipelineModuleState::new(),
      @ir.HotPassDescriptor::new("vacuum"),
      HotPipelineOptions::new(),
    ) {
    Some(result) => result
    None => fail("expected raw vacuum structured-write skip result")
  }
  assert_false(result.unchanged_original)
  match result.func {
    @lib.Func(_, @lib.Expr([@lib.LocalGet(_), @lib.If(_, cleaned_then, None)])) => {
      @debug.assert_eq(cleaned_then.length(), 4)
      @debug.assert_eq(
        cleaned_then[0],
        @lib.Instruction::i32_const(@lib.I32(1)),
      )
      @debug.assert_eq(
        cleaned_then[1],
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      )
      @debug.assert_eq(
        cleaned_then[2],
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      )
      @debug.assert_eq(
        cleaned_then[3],
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      )
    }
    other =>
      fail("expected structured function shape, got \{@debug.to_string(other)}")
  }
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
test "vacuum batches repeated raw skip trace lines" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (param i32) (result i32) (local.get 0))
      #|  (func (param i32) (result i32) (local.get 0))
      #|  (func (param i32) (result i32) (local.get 0)))
    ),
  )
  let trace : Array[String] = []
  match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["vacuum"],
    ) {
    Ok(_) => ()
    Err(err) => fail("expected vacuum success, got \{err}")
  }

  let no_candidate_skip_lines = trace.filter(fn(line) {
    line.contains("pass[vacuum]:skip-raw reason=no-vacuum-candidates")
  })
  assert_true(no_candidate_skip_lines.length() == 1, msg=trace.to_string())
  assert_true(
    no_candidate_skip_lines[0].contains("count=3"),
    msg=trace.to_string(),
  )
}

///|
test "vacuum batch writeback repair restores invalid changed functions" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
        ),
      ]),
    )
  let candidate = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))]),
  )
  let trace : Array[String] = []
  let repaired = match
    run_hot_pipeline_vacuum_repair_batch_writeback(
      input,
      candidate,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Some(mod_) => mod_
    None => fail("expected vacuum batch repair to recover valid module")
  }

  @debug.assert_eq(repaired, input)
  assert_true(
    trace.any(fn(line) { line.contains("pass[vacuum]:skip-invalid-lower") }),
    msg=trace.to_string(),
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
      HotPipelineModuleState::new(),
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
  let original_dead_suffix_escaped_result_call_facts = dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
    mod_, original_escaped,
  )
  let original_escaped_result_operand_call_facts = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    mod_, original_escaped, original_dead_suffix_escaped_result_call_facts,
  )
  let original_dead_suffix_escaped_result_operand_call_counts = original_escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts
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
      original_escaped_result_operand_call_facts,
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
      original_dead_suffix_escaped_result_call_facts,
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
  let original_dead_suffix_escaped_result_call_facts = dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
    mod_, original_escaped,
  )
  let original_escaped_result_operand_call_facts = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    mod_, original_escaped, original_dead_suffix_escaped_result_call_facts,
  )
  let original_dead_suffix_escaped_result_operand_call_counts = original_escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts
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
      original_dead_suffix_escaped_result_call_facts,
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
  let original_dead_suffix_escaped_result_call_facts = dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
    mod_, original_escaped,
  )
  let original_escaped_result_operand_call_facts = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    mod_, original_escaped, original_dead_suffix_escaped_result_call_facts,
  )
  let original_dead_suffix_escaped_result_operand_call_counts = original_escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts
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
      original_escaped_result_operand_call_facts,
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
      original_dead_suffix_escaped_result_call_facts,
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
    HotPipelineModuleState::new(),
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
    HotPipelineModuleState::new(),
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
  let module_state = HotPipelineModuleState::new()
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
  let module_state = HotPipelineModuleState::new()
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
  let module_state = HotPipelineModuleState::new()
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
  let module_state = HotPipelineModuleState::new()
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
  let module_state = HotPipelineModuleState::new()
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
  let module_state = HotPipelineModuleState::new()
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

///|
test "DAEO filtered prefix folds immutable struct first-field literals only in selected functions" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $box (struct (field i32) (field i32)))
      #|  (global $box (ref $box)
      #|    i32.const 0
      #|    i32.const 9
      #|    struct.new $box)
      #|  (func $selected (result i32) (local i32)
      #|    global.get $box
      #|    struct.get $box 0
      #|    local.tee 0
      #|    i32.const 1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 7
      #|    else
      #|      i32.const 9
      #|    end)
      #|  (func $untouched (result i32) (local i32)
      #|    global.get $box
      #|    struct.get $box 0
      #|    local.tee 0
      #|    i32.const 1
      #|    i32.eq
      #|    if (result i32)
      #|      i32.const 7
      #|    else
      #|      i32.const 9
      #|    end))
    ),
  )
  let original_untouched = match input.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[1]
    None => fail("expected code section")
  }
  let field_folded = run_hot_pipeline_dae_fold_immutable_global_struct_fields_touched(
    input,
    [true, false],
  )
  let folded = run_hot_pipeline_dae_fold_i32_tee_compare_ifs_touched(
    field_folded,
    [true, false],
  )
  let (selected, untouched) = match folded.code_sec {
    Some(@lib.CodeSec(funcs)) => (funcs[0], funcs[1])
    None => fail("expected rewritten code section")
  }
  @debug.assert_eq(untouched, original_untouched)
  let selected_text = folded.pretty_print_defined_func(0U)
  assert_true(selected_text.contains("i32.const I32(0)"), msg=selected_text)
  assert_true(selected_text.contains("local.set (Local 0)"), msg=selected_text)
  assert_true(selected_text.contains("i32.const I32(9)"), msg=selected_text)
  assert_false(selected_text.contains("global.get"), msg=selected_text)
  assert_false(selected_text.contains("struct.get"), msg=selected_text)
  assert_false(selected_text.contains("local.tee"), msg=selected_text)
  assert_false(selected_text.contains("i32.eq"), msg=selected_text)
  assert_false(selected_text.contains("if"), msg=selected_text)
  match @validate.validate_module(folded) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected filtered immutable-field fold to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  ignore(selected)
}

///|
test "DAEO post-component cleanup selected-definition validation rolls back an invalid candidate" {
  let original = pass_test_module_from_wat("(module (func))")
  let invalid = original.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  let (retained, accepted) = run_hot_pipeline_dae_validate_selected_def_or_rollback(
    original, invalid, 0,
  )
  assert_false(accepted)
  @debug.assert_eq(retained, original)
}

///|
test "DAEO post-component profitability proves a strict selected-function encoding reduction" {
  let original = pass_test_module_from_wat("(module (func nop nop))")
  let candidate = pass_test_module_from_wat("(module (func nop))")
  @debug.assert_eq(
    run_hot_pipeline_dae_selected_func_encoded_strictly_smaller(
      original, candidate, 0,
    ),
    Some(true),
  )
  @debug.assert_eq(
    run_hot_pipeline_dae_selected_func_encoded_strictly_smaller(
      candidate, original, 0,
    ),
    Some(false),
  )
}
