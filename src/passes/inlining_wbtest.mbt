///|
test "inlining iteration requires a touched body or function-count change" {
  assert_false(inl_iteration_has_progress([false, false], 4, 4))
  assert_true(inl_iteration_has_progress([false, true], 4, 4))
  assert_true(inl_iteration_has_progress([false, false], 4, 3))
}

///|
test "inlining graph reachability preserves cycle-only self reachability" {
  let graph : Array[Array[Int]] = [[1], [2], [1], []]
  let reachability = inl_build_graph_reachability(graph)
  assert_true(inl_reachability_reaches(reachability, 0, 1))
  assert_true(inl_reachability_reaches(reachability, 0, 2))
  assert_true(inl_reachability_reaches(reachability, 1, 1))
  assert_true(inl_reachability_reaches(reachability, 2, 2))
  assert_false(inl_reachability_reaches(reachability, 0, 0))
  assert_false(inl_reachability_reaches(reachability, 0, 3))
  assert_false(inl_reachability_reaches(reachability, 3, 3))
}

///|
test "inlining nested cleanup intentionally rejects invalid pass output" {
  let valid = pass_test_module_from_wat(
    "(module (func (local i32) local.get 0 drop))",
  )
  let invalid = match valid.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, body)])) =>
      valid.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(@lib.Locals::new([]), body)]),
      )
    other => fail("expected one parsed function, got \{other}")
  }
  let trace : Array[String] = []
  match
    inl_validate_nested_cleanup_pass_output(
      invalid,
      "coalesce-locals",
      Some(fn(line) { trace.push(line) }),
    ) {
    Err(err) => assert_true(err.contains("produced invalid module"), msg=err)
    Ok(_) => fail("expected invalid nested cleanup output to reject")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[inlining-optimizing]:nested-pass-invalid name=coalesce-locals",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "inlining shape scanner treats only direct calls as flexible call blockers" {
  let (direct_calls, _, _, _) = inl_scan_shape_instrs([
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  assert_true(direct_calls)
  let (indirect_calls, _, _, _) = inl_scan_shape_instrs([
    @lib.Instruction::call_indirect(
      @lib.TypeIdx::new(0U),
      @lib.TableIdx::new(0U),
    ),
  ])
  assert_false(indirect_calls)
  let (ref_calls, _, _, _) = inl_scan_shape_instrs([
    @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
  ])
  assert_false(ref_calls)
}

///|
test "inlining combined binary size guard matches strict Binaryen default threshold" {
  assert_true(inl_combined_binary_size_within_limit(1, 1))
  assert_true(inl_combined_binary_size_within_limit(100000, 63839))
  assert_false(inl_combined_binary_size_within_limit(100000, 63840))
  assert_false(inl_combined_binary_size_within_limit(100000, 63841))
}

///|
test "inlining prunes dead unreachable drops before terminal unreachable" {
  let body = [
    @lib.Instruction::loop_(
      @lib.BlockType::val_type(@lib.ValType::i64()),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::drop(),
        @lib.Instruction::unreachable_(),
      ]),
    ),
  ]
  let pruned = inl_prune_dead_unreachable_drops_in_instrs(body)
  match pruned {
    [@lib.Loop(_, @lib.Expr([@lib.Unreachable]))] => ()
    other => fail("expected pruned loop body, got \{other}")
  }
}

///|
test "inlining prunes dead value block before terminal unreachable" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::v128()),
      @lib.Expr::new([
        @lib.Instruction::unreachable_(),
        @lib.Instruction::unreachable_(),
      ]),
    ),
    @lib.Instruction::unreachable_(),
  ]
  let pruned = inl_prune_dead_unreachable_drops_in_instrs(body)
  match pruned {
    [@lib.Unreachable] => ()
    other => fail("expected pruned value block, got \{other}")
  }
}

///|
test "inlining pads exact unreachable helpers to predicted signature counts" {
  let source =
    #|(module
    #|  (type $root (func (result i32)))
    #|  (func (export "run") (type $root)
    #|    unreachable))
  let mod_ = pass_test_module_from_wat(source)
  let predicted : @hashmap.HashMap[String, Int] = @hashmap.new()
  let key = inl_func_signature_key(mod_, inl_collect_func_type_indices(mod_), 0)
  predicted.set(key, 2)
  let padded = inl_pad_unreachable_to_predicted_counts(mod_, predicted)
  match padded.func_sec {
    Some(@lib.FuncSec(type_idxs)) => @debug.assert_eq(type_idxs.length(), 2)
    None => fail("expected func section")
  }
}

///|
test "inlining predicts helper signature for self-loop root cycle peer" {
  let source =
    #|(module
    #|  (type $root (func (param i64) (result f64)))
    #|  (type $helper (func (param f64 f32) (result f64)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    call $run
    #|    drop
    #|    f64.const 0
    #|    f32.const 0
    #|    call $helper)
    #|  (func $peer (type $helper)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $helper)
    #|  (func $helper (type $helper)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $peer
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    call $helper
    #|    drop
    #|    i64.const 0
    #|    call $shadow
    #|    drop
    #|    f64.const 0)
    #|  (func $shadow (type $root)
    #|    block unreachable end
    #|    f64.const 0
    #|    f32.const 0
    #|    call $helper
    #|    drop
    #|    f64.const 1
    #|    f32.const 1
    #|    call $peer
    #|    drop
    #|    local.get 0
    #|    call $run))
  let mod_ = pass_test_module_from_wat(source)
  let graph = inl_original_reachable_private_cycle_funcs(mod_)
  let types = inl_collect_func_type_indices(mod_)
  let key = inl_func_signature_key(mod_, types, 1)
  @debug.assert_eq(inl_hash_get_int(graph.predicted_unreachable_counts, key), 1)
  @debug.assert_eq(inl_hash_get_int(graph.final_trim_counts, key), 0)
}

///|
test "inlining predicts helper representative behind self-loop root helper cycle" {
  let source =
    #|(module
    #|  (type $root (func (param f32) (result i64)))
    #|  (type $helper (func (param f64)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    f64.const 0
    #|    call $c
    #|    local.get 0
    #|    call $run)
    #|  (func $a (type $helper)
    #|    block unreachable end
    #|    f64.const 0
    #|    call $b)
    #|  (func $b (type $helper)
    #|    block unreachable end
    #|    f64.const 0
    #|    call $c)
    #|  (func $c (type $helper)
    #|    block unreachable end
    #|    f64.const 0
    #|    call $a))
  let mod_ = pass_test_module_from_wat(source)
  let graph = inl_original_reachable_private_cycle_funcs(mod_)
  let types = inl_collect_func_type_indices(mod_)
  let helper_key = inl_func_signature_key(mod_, types, 1)
  @debug.assert_eq(
    inl_hash_get_int(graph.predicted_unreachable_counts, helper_key),
    1,
  )
  @debug.assert_eq(inl_hash_get_int(graph.final_trim_counts, helper_key), 1)
}

///|
test "inlining detects same-signature root cycle dead suffix preservation shape" {
  let source =
    #|(module
    #|  (type $root (func (param i64 f32) (result i64)))
    #|  (func $run (export "main") (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $helper
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    call $helper)
    #|  (func $orphan_a (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $orphan_b
    #|    drop
    #|    i64.const 1)
    #|  (func $orphan_b (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $helper
    #|    drop
    #|    i64.const 2)
    #|  (func $helper (type $root)
    #|    block unreachable end
    #|    local.get 0
    #|    local.get 1
    #|    call $run
    #|    drop
    #|    i64.const 3))
  let mod_ = pass_test_module_from_wat(source)
  assert_true(inl_has_same_sig_root_cycle_dead_suffix(mod_))
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let imports = inl_imported_func_count(mod_)
      let facts = inl_build_dead_suffix_preserve_facts(mod_, funcs, imports)
      assert_true(
        inl_dead_suffix_preserve_facts_should_preserve(facts, imports + 3),
      )
      assert_false(
        inl_dead_suffix_preserve_facts_should_preserve(facts, imports + 1),
      )
    }
    None => abort("expected code section")
  }
}

///|
test "inlining detects polymorphic self-call suffixes before hot cleanup" {
  let body = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i64_const(@lib.I64::new(900L)),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ]
  assert_true(inl_suffix_has_polymorphic_self_call(body, 1, 1))
  assert_false(inl_suffix_has_polymorphic_self_call(body, 1, 0))
  let func = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  assert_true(inl_func_has_hot_unsafe_self_suffix(func, 1))
}

///|
test "partial inlining simple unary classification matches Binaryen Unary" {
  assert_true(inl_partial_simple_unary(@lib.Instruction::i32_trunc_f32s()))
  assert_true(inl_partial_simple_unary(@lib.Instruction::v128_any_true()))
  assert_true(
    inl_partial_simple_unary(@lib.Instruction::i16x8_extend_low_i8x16s()),
  )
  assert_true(
    inl_partial_simple_unary(
      @lib.Instruction::i32x4_relaxed_trunc_zero_f64x2s(),
    ),
  )
  assert_false(inl_partial_simple_unary(@lib.Instruction::ref_as_non_null()))
  assert_false(inl_partial_simple_unary(@lib.Instruction::any_convert_extern()))
  assert_false(inl_partial_simple_unary(@lib.Instruction::i31_get_s()))
  assert_false(
    inl_partial_simple_unary(
      @lib.Instruction::i32_load(
        @lib.MemArg::new(@lib.U32::new(0U), None, @lib.U64::new(0UL)),
      ),
    ),
  )
}

///|
test "inlining function-label escape scanner distinguishes local and caller targets" {
  assert_true(
    inl_instrs_have_function_label_escape([
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [@lib.Catch::all(@lib.LabelIdx::new(0U))],
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    ]),
  )
  assert_false(
    inl_instrs_have_function_label_escape([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::try_table(
            @lib.BlockType::void_(),
            [@lib.Catch::all(@lib.LabelIdx::new(0U))],
            @lib.Expr::new([@lib.Instruction::nop()]),
          ),
        ]),
      ),
    ]),
  )
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let nullable_any = @lib.RefType::new(true, any_heap)
  let nullable_eq = @lib.RefType::new(true, eq_heap)
  let branch_ops : Array[@lib.Instruction] = [
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::br_on_cast(
      @lib.LabelIdx::new(0U),
      true,
      any_heap,
      true,
      eq_heap,
    ),
    @lib.Instruction::br_on_cast_fail(
      @lib.LabelIdx::new(0U),
      true,
      any_heap,
      true,
      eq_heap,
    ),
    @lib.Instruction::br_on_cast_desc_eq(
      @lib.LabelIdx::new(0U),
      nullable_any,
      nullable_eq,
    ),
    @lib.Instruction::br_on_cast_desc_eq_fail(
      @lib.LabelIdx::new(0U),
      nullable_any,
      nullable_eq,
    ),
  ]
  for instr in branch_ops {
    assert_true(inl_instrs_have_function_label_escape([instr]))
  }
}

///|
test "inlining appended-local entry liveness scans legacy try bodies and catches" {
  let local_idx = @lib.LocalIdx::new(0U)
  assert_true(
    inl_local_may_read_before_write(
      [
        @lib.Instruction::try_(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::local_get(local_idx)]),
          [],
        ),
      ],
      0,
    ),
  )
  assert_true(
    inl_local_may_read_before_write(
      [
        @lib.Instruction::try_(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::nop()]),
          [
            @lib.LegacyCatch::all(
              @lib.Expr::new([@lib.Instruction::local_get(local_idx)]),
            ),
          ],
        ),
      ],
      0,
    ),
  )
}

///|
test "inlining appended-local entry liveness proves only definite writes" {
  let local_idx = @lib.LocalIdx::new(0U)
  assert_false(
    inl_local_may_read_before_write(
      [
        @lib.Instruction::i32_const(@lib.I32::new(1)),
        @lib.Instruction::local_set(local_idx),
        @lib.Instruction::local_get(local_idx),
      ],
      0,
    ),
  )
  assert_true(
    inl_local_may_read_before_write(
      [
        @lib.Instruction::i32_const(@lib.I32::new(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32::new(2)),
            @lib.Instruction::local_set(local_idx),
          ],
          Some([
            @lib.Instruction::i32_const(@lib.I32::new(3)),
            @lib.Instruction::local_set(local_idx),
          ]),
        ),
        @lib.Instruction::local_get(local_idx),
      ],
      0,
    ),
  )
  assert_true(
    inl_local_may_read_before_write(
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(4)),
            @lib.Instruction::local_set(local_idx),
          ]),
        ),
        @lib.Instruction::local_get(local_idx),
      ],
      0,
    ),
  )
}

///|
test "inlining hoist wrappers preserve branches to the function label" {
  let body = [
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [@lib.Catch::all(@lib.LabelIdx::new(0U))],
      @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
    ),
  ]
  match inl_shift_outer_target_branches(body, 2) {
    [
      @lib.Br(@lib.LabelIdx(2U)),
      @lib.Block(
        _,
        @lib.Expr([@lib.Br(@lib.LabelIdx(0U)), @lib.BrIf(@lib.LabelIdx(3U))])
      ),
      @lib.TryTable(
        _,
        [@lib.CatchAll(@lib.LabelIdx(2U))],
        @lib.Expr([@lib.Br(@lib.LabelIdx(3U))])
      ),
    ] => ()
    other =>
      fail(
        "expected only function-target depths to shift, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "inlining uses the selected table address width for indirect tail hoists" {
  let type_idx = @lib.TypeIdx::new(0U)
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
  ])
  let table_type = @lib.TableType::new(
    @lib.RefType::abs(@lib.AbsHeapType::func()),
    @lib.Limits::i64(1UL, None),
  )
  let mod_ = @lib.Module::new(
    type_sec=Some(type_sec),
    table_sec=Some(@lib.TableSec::new([@lib.Table::new(table_type, None)])),
  )
  let infos : Array[InlFunctionInfo] = []
  match
    inl_nested_return_call_operand_types(
      @lib.Instruction::return_call_indirect(type_idx, @lib.TableIdx::new(0U)),
      mod_,
      infos,
    ) {
    Some(types) =>
      @debug.assert_eq(types, [@lib.ValType::i32(), @lib.ValType::i64()])
    None => fail("expected table64 indirect tail-call operand types")
  }
}

///|
test "inlining classifies GC heap wrappers as shrinking trivial" {
  let ty = @lib.TypeIdx::new(0U)
  let data = @lib.DataIdx::new(0U)
  let elem = @lib.ElemIdx::new(0U)
  let body2 = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::struct_set(ty, @lib.U32::new(0U)),
  ]
  assert_true(inl_body_is_shrinking_trivial(body2, 2), msg="struct.set")
  let body3 = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::array_set(ty),
  ]
  assert_true(inl_body_is_shrinking_trivial(body3, 3), msg="array.set")
  let body4 = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::array_init_data(ty, data),
  ]
  assert_true(inl_body_is_shrinking_trivial(body4, 4), msg="array.init_data")
  let body4_elem = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::array_init_elem(ty, elem),
  ]
  assert_true(
    inl_body_is_shrinking_trivial(body4_elem, 4),
    msg="array.init_elem",
  )
  let body5 = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::array_copy(ty, ty),
  ]
  assert_true(inl_body_is_shrinking_trivial(body5, 5), msg="array.copy")
}
