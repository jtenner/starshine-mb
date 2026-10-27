///|
fn instruction_review_reference_purity(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int32,
) -> OiSideEffectFreeExpressionFact {
  // Represented subset of Binaryen v130 `EffectAnalyzer` /
  // `ExpressionAnalyzer` purity queries used by OI when it can erase an
  // operand, collapse identical select arms, move a null check, or replace an
  // expression with a constant while preserving effects. The fact preserves the
  // previous Starshine-supported set exactly: direct pure leaves, exact
  // `ref.null`, byte-constant SIMD leaves, `ref.i31` over side-effect-free
  // payloads, direct SIMD splats over side-effect-free payloads, branchless
  // scalar shells whose children are all side-effect-free, pure dropped payloads,
  // the single-value block fallthrough shape Binaryen's maxBits path can erase
  // after folding, and pure block regions with no effectful roots.
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return OiSideEffectFreeExpressionFact::empty()
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  let trivial_leaf = OiTriviallyPureOperandFact::from_node(func, node_id)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.I32DivS | @lib.I32DivU | @lib.I32RemS | @lib.I32RemU) => {
      if node.child_count != 2 {
        return OiSideEffectFreeExpressionFact::empty()
      }
      let divisor = optimize_instructions_i32_const(
        func,
        dead,
        @ir.hot_child_get(func, node_id, 1),
      )
      let signed_div = @ir.hot_node_exact_instr(func, node_id)
        is Some(@lib.I32DivS)
      match divisor {
        Some(@lib.I32(value)) if value != 0 && (!signed_div || value != -1) =>
          ()
        _ => return OiSideEffectFreeExpressionFact::empty()
      }
    }
    Some(@lib.I64DivS | @lib.I64DivU | @lib.I64RemS | @lib.I64RemU) => {
      if node.child_count != 2 {
        return OiSideEffectFreeExpressionFact::empty()
      }
      let divisor = optimize_instructions_i64_const(
        func,
        dead,
        @ir.hot_child_get(func, node_id, 1),
      )
      let signed_div = @ir.hot_node_exact_instr(func, node_id)
        is Some(@lib.I64DivS)
      match divisor {
        Some(@lib.I64(value)) if value != 0L && (!signed_div || value != -1L) =>
          ()
        _ => return OiSideEffectFreeExpressionFact::empty()
      }
    }
    Some(
      @lib.I32TruncF32S
      | @lib.I32TruncF32U
      | @lib.I32TruncF64S
      | @lib.I32TruncF64U
      | @lib.I64TruncF32S
      | @lib.I64TruncF32U
      | @lib.I64TruncF64S
      | @lib.I64TruncF64U
    ) => return OiSideEffectFreeExpressionFact::empty()
    Some(@lib.Instruction::RefNull(_)) =>
      return {
        kind: SideEffectFreeExactRefNullLeaf,
        trivial_leaf,
        children_effect_free: true,
      }
    Some(@lib.Instruction::RefI31) if node.child_count == 1 => {
      let child_fact = instruction_review_reference_purity(
        func,
        dead,
        func.children[node.child_base],
      )
      return {
        kind: SideEffectFreeRefI31Payload,
        trivial_leaf,
        children_effect_free: child_fact.proves_free(),
      }
    }
    Some(instr) =>
      match OiSideEffectFreeInstructionFact::from_instruction(instr).kind {
        SideEffectFreeV128ConstLeafInstruction =>
          return {
            kind: SideEffectFreeExactV128ConstLeaf,
            trivial_leaf,
            children_effect_free: true,
          }
        SideEffectFreeSimdSplatPayloadInstruction if node.child_count == 1 => {
          let child_fact = instruction_review_reference_purity(
            func,
            dead,
            func.children[node.child_base],
          )
          return {
            kind: SideEffectFreeSimdSplatPayload,
            trivial_leaf,
            children_effect_free: child_fact.proves_free(),
          }
        }
        _ => ()
      }
    _ => ()
  }
  if trivial_leaf.proves_pure() {
    return {
      kind: SideEffectFreeTrivialLeaf,
      trivial_leaf,
      children_effect_free: true,
    }
  }
  match node.op {
    @ir.HotOp::Drop if node.child_count == 1 => {
      let child_fact = instruction_review_reference_purity(
        func,
        dead,
        func.children[node.child_base],
      )
      {
        kind: SideEffectFreeDropPayload,
        trivial_leaf,
        children_effect_free: child_fact.proves_free(),
      }
    }
    @ir.HotOp::Block if node.child_count == 1 => {
      let child_fact = instruction_review_reference_purity(
        func,
        dead,
        func.children[node.child_base],
      )
      {
        kind: SideEffectFreeSingleValueBlock,
        trivial_leaf,
        children_effect_free: child_fact.proves_free(),
      }
    }
    @ir.HotOp::Block => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      let root_count = @ir.hot_region_root_count(func, body_ref)
      let mut roots_effect_free = root_count > 0
      for slot = 0; slot < root_count; slot = slot + 1 {
        let root_id = @ir.hot_region_get(func, body_ref, slot)
        let root_fact = instruction_review_reference_purity(func, dead, root_id)
        if !root_fact.proves_free() {
          roots_effect_free = false
        }
      }
      {
        kind: SideEffectFreeBlockRegion,
        trivial_leaf,
        children_effect_free: roots_effect_free,
      }
    }
    @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Select => {
      // Erasure requires the scalar operation itself to be nontrapping, as
      // well as all eagerly evaluated operands. Division and truncation can
      // trap even when their operands are pure local reads or constants.
      let mut children_effect_free = !@ir.hot_may_trap(func, node_id)
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        let child_fact = instruction_review_reference_purity(
          func,
          dead,
          func.children[node.child_base + slot],
        )
        if !child_fact.proves_free() {
          children_effect_free = false
        }
      }
      {
        kind: SideEffectFreeBranchlessScalarShell,
        trivial_leaf,
        children_effect_free,
      }
    }
    _ =>
      {
        kind: SideEffectFreeExpressionNoProof,
        trivial_leaf,
        children_effect_free: false,
      }
  }
}

///|
fn code_pushing_review_reference_safe_to_cross(
  func : @ir.HotFunc,
  node_id : Int32,
  value_id : Int32,
  module_ctx~ : @ir.HotModuleContext? = None,
  depth~ : Int32 = 64,
) -> Bool {
  if depth <= 0 || node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if code_pushing_review_reference_has_rethrow(func, node_id) {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, value_id); slot = slot + 1 {
    if !code_pushing_review_reference_safe_to_cross(
        func,
        node_id,
        @ir.hot_child_get(func, value_id, slot),
        module_ctx~,
        depth=depth - 1,
      ) {
      return false
    }
  }
  if code_pushing_node_is_global_get(func, value_id) {
    code_pushing_effects_safe_to_cross_for_value(
      @ir.effects_for_node(func, node_id),
    ) ||
    code_pushing_node_is_disjoint_global_set_for_global_get(
      func,
      node_id,
      value_id,
      module_ctx~,
    )
  } else if code_pushing_node_is_local_get(func, value_id) {
    let (_, writes) = code_pushing_count_local_gets_writes_in_node_bounded(
      func,
      node_id,
      @ir.hot_node_get(func, value_id).imm0,
      0,
      0,
    )
    writes == 0
  } else {
    if code_pushing_node_is_memory_load(func, value_id) {
      return code_pushing_effects_safe_to_cross_for_heap_read(
        @ir.effects_for_node(func, node_id),
      )
    }
    let source_local = code_pushing_nonnull_struct_get_source_local(
      func, value_id,
    )
    if source_local >= 0 {
      let (_, writes) = code_pushing_count_local_gets_writes_in_node_bounded(
        func, node_id, source_local, 0, 0,
      )
      writes == 0 &&
      code_pushing_effects_safe_to_cross_for_heap_read(
        @ir.effects_for_node(func, node_id),
      )
    } else {
      true
    }
  }
}

///|
fn code_pushing_review_reference_push_point_kind(
  func : @ir.HotFunc,
  node_id : Int32,
) -> String {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return "none"
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => "if"
    @ir.HotOp::BrTable => "switch"
    @ir.HotOp::BrIf
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail => "conditional-branch"
    @ir.HotOp::Drop => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return "none"
      }
      let child_kind = code_pushing_review_reference_push_point_kind(
        func,
        @ir.hot_child_get(func, node_id, 0),
      )
      if child_kind == "none" {
        "none"
      } else {
        "dropped-" + child_kind
      }
    }
    _ => "none"
  }
}

///|
fn code_pushing_review_reference_has_rethrow_with_visited(
  func : @ir.HotFunc,
  node_id : Int32,
  visited : Array[Bool],
) -> Bool {
  if node_id < 0 ||
    node_id >= visited.length() ||
    visited[node_id] ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  visited[node_id] = true
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Rethrow => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if code_pushing_review_reference_has_rethrow_with_visited(
        func,
        @ir.hot_child_get(func, node_id, slot),
        visited,
      ) {
      return true
    }
  }
  let region_has_rethrow = fn(region_ref : @ir.HotRegionRef) -> Bool {
    for idx = 0
        idx < @ir.hot_region_root_count(func, region_ref)
        idx = idx + 1 {
      if code_pushing_review_reference_has_rethrow_with_visited(
          func,
          @ir.hot_region_get(func, region_ref, idx),
          visited,
        ) {
        return true
      }
    }
    false
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      region_has_rethrow(@ir.hot_region_body_ref(func, node_id))
    @ir.HotOp::If => {
      if region_has_rethrow(@ir.hot_region_then_ref(func, node_id)) {
        return true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => region_has_rethrow(else_ref)
        None => false
      }
    }
    @ir.HotOp::Try => {
      if region_has_rethrow(@ir.hot_region_body_ref(func, node_id)) {
        return true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) => region_has_rethrow(catch_ref)
        None => false
      }
    }
    @ir.HotOp::TryTable =>
      region_has_rethrow(@ir.hot_region_body_ref(func, node_id)) ||
      region_has_rethrow(@ir.hot_region_catch_list_ref(func, node_id))
    _ => false
  }
}

///|
fn code_pushing_review_reference_has_rethrow(
  func : @ir.HotFunc,
  node_id : Int32,
) -> Bool {
  code_pushing_review_reference_has_rethrow_with_visited(
    func,
    node_id,
    Array::make(@ir.hot_node_count(func), false),
  )
}

///|
fn instruction_review_purity_bench(
  it : @bench.T,
  cached : Bool,
  padding~ : Int32 = 0,
) -> Unit raise {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) " +
    Array::make(padding, "i32.const 0 drop ").join("") +
    "local.get 0 " +
    Array::make(128, "i32.eqz").join(" ") +
    "))",
  )
  let dead = @bitset.BitSet::new(@ir.hot_node_count(func))
  let root = @ir.hot_root_get(func, @ir.hot_root_count(func) - 1)
  assert_true(
    OiSideEffectFreeExpressionFact::proves_node_free(func, dead, root),
  )
  if cached && padding > 0 {
    let cache = OiPurityCache::new()
    assert_true(
      OiSideEffectFreeExpressionFact::proves_node_free(
        func,
        dead,
        root,
        purity_cache=Some(cache),
      ),
    )
    let original = @ir.hot_child_get(func, root, 0)
    let effect = @ir.hot_build_local_tee(func, 0, original)
    @ir.hot_child_set(func, root, 0, effect)
    assert_false(
      OiSideEffectFreeExpressionFact::proves_node_free(
        func,
        dead,
        root,
        purity_cache=Some(cache),
      ),
    )
    @ir.hot_child_set(func, root, 0, original)
    assert_true(
      OiSideEffectFreeExpressionFact::proves_node_free(
        func,
        dead,
        root,
        purity_cache=Some(cache),
      ),
    )
  }
  it.bench(fn() {
    let purity_cache = if cached { Some(OiPurityCache::new()) } else { None }
    let mut node = root
    while node >= 0 {
      it.keep(
        if cached {
          OiSideEffectFreeExpressionFact::proves_node_free(
            func,
            dead,
            node,
            purity_cache~,
          )
        } else {
          instruction_review_reference_purity(func, dead, node).proves_free()
        },
      )
      node = if @ir.hot_child_count(func, node) == 0 {
        -1
      } else {
        @ir.hot_child_get(func, node, 0)
      }
    }
  })
}

///|
#skip("dedicated native performance lane")
test "bench OI overlapping purity uncached" (it : @bench.T) {
  instruction_review_purity_bench(it, false)
}

///|
#skip("dedicated native performance lane")
test "bench OI overlapping purity cached" (it : @bench.T) {
  instruction_review_purity_bench(it, true)
}

///|
fn instruction_review_rethrow_bench(
  it : @bench.T,
  reference : Bool,
) -> Unit raise {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) local.get 0 i32.eqz))",
  )
  let root = @ir.hot_root_get(func, 0)
  for _ in 0..<8192 {
    ignore(@ir.hot_build_const_i32(func, @lib.I32(1)))
  }
  assert_eq(
    code_pushing_node_has_rethrow(func, root),
    code_pushing_review_reference_has_rethrow(func, root),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        code_pushing_review_reference_has_rethrow(func, root)
      } else {
        code_pushing_node_has_rethrow(func, root)
      },
    )
  })
}

///|
#skip("dedicated native performance lane")
test "bench code pushing rethrow full arena reference" (it : @bench.T) {
  instruction_review_rethrow_bench(it, true)
}

///|
#skip("dedicated native performance lane")
test "bench code pushing rethrow subtree scratch" (it : @bench.T) {
  instruction_review_rethrow_bench(it, false)
}

///|
fn instruction_review_swap_bench(
  it : @bench.T,
  incremental : Bool,
  compound~ : Bool = false,
) -> Unit raise {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32) (result i32) " +
    Array::make(256, "local.get 0 local.get 1 i32.add drop").join(" ") +
    (if compound {
      " local.get 0 i32.eqz local.get 1 i32.eqz i32.add))"
    } else {
      " local.get 0 local.get 1 i32.add))"
    }),
  )
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let root = @ir.hot_root_get(func, @ir.hot_root_count(func) - 1)
  it.bench(fn() {
    ignore(pass_require_use_def(ctx, func))
    ignore(pass_require_effects(ctx, func))
    if incremental {
      if !pass_swap_scalar_operands(ctx, func, root) {
        abort("expected scalar swap")
      }
    } else {
      let lhs = @ir.hot_child_get(func, root, 0)
      let rhs = @ir.hot_child_get(func, root, 1)
      @ir.hot_child_set(func, root, 0, rhs)
      @ir.hot_child_set(func, root, 1, lhs)
      pass_mark_mutated(ctx, func)
    }
    it.keep(pass_require_use_def(ctx, func))
    it.keep(pass_require_effects(ctx, func))
  })
  assert_true(@ir.hot_verify_cached_analyses(func, ctx.cache) is Ok(_))
}

///|
#skip("dedicated native performance lane")
test "bench OI leaf swaps full analysis rebuild" (it : @bench.T) {
  instruction_review_swap_bench(it, false)
}

///|
#skip("dedicated native performance lane")
test "bench OI leaf swaps retained analysis" (it : @bench.T) {
  instruction_review_swap_bench(it, true)
}

///|
#skip("dedicated native performance lane")
test "bench OI compound swaps full analysis rebuild" (it : @bench.T) {
  instruction_review_swap_bench(it, false, compound=true)
}

///|
#skip("dedicated native performance lane")
test "bench OI compound swaps retained analysis" (it : @bench.T) {
  instruction_review_swap_bench(it, true, compound=true)
}

///|
fn instruction_review_push_point_bench(
  it : @bench.T,
  reference : Bool,
) -> Unit raise {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (drop (if (result i32) (local.get 0) (then (i32.const 1)) (else (i32.const 2))))))",
  )
  let root = @ir.hot_root_get(func, 0)
  assert_eq(
    code_pushing_push_point_kind(func, root).diagnostic(),
    code_pushing_review_reference_push_point_kind(func, root),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        code_pushing_review_reference_push_point_kind(func, root) != "none"
      } else {
        code_pushing_push_point_kind(func, root) != NoPushPoint
      },
    )
  })
}

///|
#skip("dedicated native performance lane")
test "bench code pushing dropped push point string reference" (it : @bench.T) {
  instruction_review_push_point_bench(it, true)
}

///|
#skip("dedicated native performance lane")
test "bench code pushing dropped push point typed kind" (it : @bench.T) {
  instruction_review_push_point_bench(it, false)
}

///|
fn instruction_review_crossing_bench(
  it : @bench.T,
  reference : Bool,
) -> Unit raise {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let crossed = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let value = @ir.hot_build_global_get(func, 0, @lib.ValType::i32())
  for _ in 0..<8192 {
    ignore(@ir.hot_build_const_i32(func, @lib.I32(1)))
  }
  assert_eq(
    code_pushing_node_safe_to_cross_for_value(func, crossed, value),
    code_pushing_review_reference_safe_to_cross(func, crossed, value),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        code_pushing_review_reference_safe_to_cross(func, crossed, value)
      } else {
        code_pushing_node_safe_to_cross_for_value(func, crossed, value)
      },
    )
  })
}

///|
#skip("dedicated native performance lane")
test "bench code pushing full crossing arena scratch reference" (it : @bench.T) {
  instruction_review_crossing_bench(it, true)
}

///|
#skip("dedicated native performance lane")
test "bench code pushing full crossing subtree queries" (it : @bench.T) {
  instruction_review_crossing_bench(it, false)
}

///|
#skip("dedicated native performance lane")
test "bench OI sparse arena purity pre-review reference" (it : @bench.T) {
  instruction_review_purity_bench(it, false, padding=8192)
}

///|
#skip("dedicated native performance lane")
test "bench OI sparse arena purity cached" (it : @bench.T) {
  instruction_review_purity_bench(it, true, padding=8192)
}

///|
fn instruction_review_balanced_tree(leaves : Int32) -> (@ir.HotFunc, Int32) {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) i32.const 0))",
  )
  let mut layer = Array::makei(leaves, fn(idx) {
    @ir.hot_build_const_i32(func, @lib.I32(idx))
  })
  while layer.length() > 1 {
    let next : Array[Int32] = []
    for idx = 0; idx < layer.length(); idx = idx + 2 {
      let node = @ir.hot_build_binary(
        func,
        @lib.ValType::i32(),
        layer[idx],
        layer[idx + 1],
      )
      @ir.hot_node_exact_instr_set(func, node, @lib.Instruction::i32_add())
      next.push(node)
    }
    layer = next
  }
  @ir.hot_root_set(func, 0, layer[0])
  (func, layer[0])
}

///|
fn instruction_review_effect_density_bench(
  it : @bench.T,
  reference : Bool,
  shape : Int32,
) -> Unit raise {
  let (func, whole_root) = if shape == 1 {
    let func = pass_test_lift_first_func(
      "(module (func (result i32) i32.const 0))",
    )
    let mut node = @ir.hot_root_get(func, 0)
    for _ in 0..<1024 {
      node = @ir.hot_build_unary(func, @lib.ValType::i32(), node)
      @ir.hot_node_exact_instr_set(func, node, @lib.Instruction::i32_eqz())
    }
    @ir.hot_root_set(func, 0, node)
    (func, node)
  } else {
    instruction_review_balanced_tree(4096)
  }
  let mut queried_root = whole_root
  if shape == 2 {
    // Query 127 nodes in the 8192-node arena, between shallow and full probes.
    for _ in 0..<6 {
      queried_root = @ir.hot_child_get(func, queried_root, 0)
    }
  }
  assert_eq(@ir.effects_for_node(func, queried_root), 0U)
  assert_eq(
    @ir.effects_for_node_subtree(func, queried_root),
    @ir.effects_for_node(func, queried_root),
  )
  if shape != 1 {
    let mut nested = queried_root
    while @ir.hot_child_count(func, @ir.hot_child_get(func, nested, 0)) != 0 {
      nested = @ir.hot_child_get(func, nested, 0)
    }
    @ir.hot_node_exact_instr_set(func, nested, @lib.Instruction::i32_div_s())
    let expected = @ir.effects_for_node(func, queried_root)
    assert_true((expected & @ir.EFFECT_MASK_TRAP) != 0U)
    assert_eq(@ir.effects_for_node_subtree(func, queried_root), expected)
    @ir.hot_node_exact_instr_set(func, nested, @lib.Instruction::i32_add())
  }
  it.bench(fn() {
    it.keep(
      if reference {
        @ir.effects_for_node(func, queried_root)
      } else {
        @ir.effects_for_node_subtree(func, queried_root)
      },
    )
  })
}

///|
#skip("dedicated native performance lane")
test "bench full arena effect query dense mask reference" (it : @bench.T) {
  instruction_review_effect_density_bench(it, true, 0)
}

///|
#skip("dedicated native performance lane")
test "bench full arena effect query adaptive visited bits" (it : @bench.T) {
  instruction_review_effect_density_bench(it, false, 0)
}

///|
#skip("dedicated native performance lane")
test "bench deep chain effect query dense mask reference" (it : @bench.T) {
  instruction_review_effect_density_bench(it, true, 1)
}

///|
#skip("dedicated native performance lane")
test "bench deep chain effect query adaptive visited bits" (it : @bench.T) {
  instruction_review_effect_density_bench(it, false, 1)
}

///|
fn instruction_review_dense_purity_bench(
  it : @bench.T,
  reference : Bool,
) -> Unit raise {
  let (func, root) = instruction_review_balanced_tree(4096)
  let dead = @bitset.BitSet::new(@ir.hot_node_count(func))
  assert_true(
    instruction_review_reference_purity(func, dead, root).proves_free(),
  )
  assert_true(
    OiSideEffectFreeExpressionFact::proves_node_free(
      func,
      dead,
      root,
      purity_cache=Some(OiPurityCache::new()),
    ),
  )
  it.bench(fn() {
    let cache = OiPurityCache::new()
    for node in 0..<@ir.hot_node_count(func) {
      it.keep(
        if reference {
          instruction_review_reference_purity(func, dead, node).proves_free()
        } else {
          OiSideEffectFreeExpressionFact::proves_node_free(
            func,
            dead,
            node,
            purity_cache=Some(cache),
          )
        },
      )
    }
  })
}

///|
#skip("dedicated native performance lane")
test "bench dense balanced purity pre-review reference" (it : @bench.T) {
  instruction_review_dense_purity_bench(it, true)
}

///|
#skip("dedicated native performance lane")
test "bench dense balanced purity adaptive memo" (it : @bench.T) {
  instruction_review_dense_purity_bench(it, false)
}

///|
#skip("dedicated native performance lane")
test "bench sparse medium effect query dense mask reference" (it : @bench.T) {
  instruction_review_effect_density_bench(it, true, 2)
}

///|
#skip("dedicated native performance lane")
test "bench sparse medium effect query adaptive visited bits" (it : @bench.T) {
  instruction_review_effect_density_bench(it, false, 2)
}

///|
fn instruction_review_rethrow_density_bench(
  it : @bench.T,
  reference : Bool,
  shape : Int32,
) -> Unit raise {
  let (func, whole_root) = if shape == 1 || shape == 3 {
    let func = pass_test_lift_first_func(
      "(module (func (result i32) i32.const 0))",
    )
    let mut node = @ir.hot_root_get(func, 0)
    for _ in 0..<(if shape == 3 { 32 } else { 1024 }) {
      node = @ir.hot_build_unary(func, @lib.ValType::i32(), node)
      @ir.hot_node_exact_instr_set(func, node, @lib.Instruction::i32_eqz())
    }
    @ir.hot_root_set(func, 0, node)
    (func, node)
  } else {
    instruction_review_balanced_tree(4096)
  }
  let mut root = whole_root
  if shape == 2 {
    for _ in 0..<6 {
      root = @ir.hot_child_get(func, root, 0)
    }
  }
  assert_false(code_pushing_review_reference_has_rethrow(func, root))
  assert_false(code_pushing_node_has_rethrow(func, root))
  // This graph-only reachability check puts the barrier after dense traversal.
  // Restore the scalar graph before timing; no invalid graph is lowered.
  let mut last_parent = root
  while @ir.hot_child_count(
          func,
          @ir.hot_child_get(
            func,
            last_parent,
            @ir.hot_child_count(func, last_parent) - 1,
          ),
        ) !=
        0 {
    last_parent = @ir.hot_child_get(
      func,
      last_parent,
      @ir.hot_child_count(func, last_parent) - 1,
    )
  }
  let slot = @ir.hot_child_count(func, last_parent) - 1
  let original = @ir.hot_child_get(func, last_parent, slot)
  let barrier = @ir.hot_build_node(
    func,
    @ir.HotOp::rethrow(),
    @ir.hot_type_void(func),
  )
  @ir.hot_child_set(func, last_parent, slot, barrier)
  assert_true(code_pushing_review_reference_has_rethrow(func, root))
  assert_true(code_pushing_node_has_rethrow(func, root))
  @ir.hot_child_set(func, last_parent, slot, original)
  it.bench(fn() {
    it.keep(
      if reference {
        code_pushing_review_reference_has_rethrow(func, root)
      } else {
        code_pushing_node_has_rethrow(func, root)
      },
    )
  })
}

///|
#skip("dedicated native performance lane")
test "bench full arena rethrow dense reference" (it : @bench.T) {
  instruction_review_rethrow_density_bench(it, true, 0)
}

///|
#skip("dedicated native performance lane")
test "bench full arena rethrow adaptive visited" (it : @bench.T) {
  instruction_review_rethrow_density_bench(it, false, 0)
}

///|
#skip("dedicated native performance lane")
test "bench deep chain rethrow dense reference" (it : @bench.T) {
  instruction_review_rethrow_density_bench(it, true, 1)
}

///|
#skip("dedicated native performance lane")
test "bench deep chain rethrow adaptive visited" (it : @bench.T) {
  instruction_review_rethrow_density_bench(it, false, 1)
}

///|
#skip("dedicated native performance lane")
test "bench sparse medium rethrow dense reference" (it : @bench.T) {
  instruction_review_rethrow_density_bench(it, true, 2)
}

///|
#skip("dedicated native performance lane")
test "bench sparse medium rethrow adaptive visited" (it : @bench.T) {
  instruction_review_rethrow_density_bench(it, false, 2)
}

///|
#skip("dedicated native performance lane")
test "bench small chain rethrow dense reference" (it : @bench.T) {
  instruction_review_rethrow_density_bench(it, true, 3)
}

///|
#skip("dedicated native performance lane")
test "bench small chain rethrow direct compact bits" (it : @bench.T) {
  instruction_review_rethrow_density_bench(it, false, 3)
}
