///|
test "inlining combined binary size guard matches default threshold" {
  assert_true(inl_combined_binary_size_within_limit(1, 1))
  assert_true(inl_combined_binary_size_within_limit(100000, 63840))
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
