///|
// Frozen subtree-call scan for exact result comparisons and native controls.

///|
fn hso_query_reference_region(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext?,
  region_ref : @ir.HotRegionRef,
  effects : HsoOrderEffects,
) -> Unit {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    hso_order_effects_merge(
      effects,
      hso_query_reference(
        cache,
        func,
        module_ctx,
        @ir.hot_region_get(func, region_ref, idx),
      ),
    )
  }
}

///|
fn hso_query_reference(
  cache : HsoPredicateCache,
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext?,
  node_id : Int32,
) -> HsoOrderEffects {
  if node_id < 0 ||
    node_id >= @ir.hot_node_count(func) ||
    !@ir.hot_node_is_live(func, node_id) {
    return hso_new_order_effects()
  }
  hso_ensure_predicate_cache_capacity(cache, node_id)
  let revision = @ir.hot_revision_current(func)
  if cache.order_revision[node_id] == revision {
    match cache.order_result[node_id] {
      Some(effects) => return effects
      None => return hso_new_order_effects()
    }
  }

  let effects = hso_new_order_effects()
  // Publish an empty in-progress summary before recursion so a malformed cyclic
  // HOT graph terminates; verified HOT graphs are structurally acyclic.
  cache.order_revision[node_id] = revision
  cache.order_result[node_id] = Some(effects)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) =>
      hso_order_effects_note_exact_instr(effects, module_ctx, instr)
    None => ()
  }
  if (@ir.effects_for_node(func, node_id) & @ir.EFFECT_MASK_CALL) != 0U {
    effects.shared_memory_read = true
    effects.shared_memory_write = true
    effects.shared_struct_read = true
    effects.shared_struct_write = true
    effects.shared_array_read = true
    effects.shared_array_write = true
  }
  let operand_node = @ir.hot_node_get(func, node_id)
  let operand_count = pass_value_operand_count(func, node_id)
  for idx = 0; idx < operand_count; idx = idx + 1 {
    hso_order_effects_merge(
      effects,
      hso_query_reference(
        cache,
        func,
        module_ctx,
        @ir.hot_child_get(
          func,
          node_id,
          pass_value_operand_slot(operand_node, idx),
        ),
      ),
    )
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      hso_query_reference_region(
        cache,
        func,
        module_ctx,
        @ir.hot_region_body_ref(func, node_id),
        effects,
      )
    @ir.HotOp::If => {
      hso_query_reference_region(
        cache,
        func,
        module_ctx,
        @ir.hot_region_then_ref(func, node_id),
        effects,
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          hso_query_reference_region(
            cache, func, module_ctx, region_ref, effects,
          )
        None => ()
      }
    }
    @ir.HotOp::Try => {
      hso_query_reference_region(
        cache,
        func,
        module_ctx,
        @ir.hot_region_body_ref(func, node_id),
        effects,
      )
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(region_ref) =>
          hso_query_reference_region(
            cache, func, module_ctx, region_ref, effects,
          )
        None => ()
      }
    }
    @ir.HotOp::TryTable => {
      hso_query_reference_region(
        cache,
        func,
        module_ctx,
        @ir.hot_region_body_ref(func, node_id),
        effects,
      )
      hso_query_reference_region(
        cache,
        func,
        module_ctx,
        @ir.hot_region_catch_list_ref(func, node_id),
        effects,
      )
    }
    _ => ()
  }
  effects
}

///|
fn hso_query_assert_equal(
  actual : HsoOrderEffects,
  expected : HsoOrderEffects,
) -> Unit raise {
  assert_eq(
    [
      actual.shared_memory_read,
      actual.shared_memory_write,
      actual.shared_struct_read,
      actual.shared_struct_write,
      actual.shared_array_read,
      actual.shared_array_write,
      actual.acquire_read,
      actual.release_write,
      actual.seq_cst,
    ],
    [
      expected.shared_memory_read,
      expected.shared_memory_write,
      expected.shared_struct_read,
      expected.shared_struct_write,
      expected.shared_array_read,
      expected.shared_array_write,
      expected.acquire_read,
      expected.release_write,
      expected.seq_cst,
    ],
  )
  assert_eq(actual.atomic_order_mask, expected.atomic_order_mask)
}

///|
test "heap store order queries preserve nested call and atomic effects" {
  let call = @lib.Instruction::call(@lib.FuncIdx::new(0U))
  let one = @lib.Instruction::i32_const(@lib.I32(1))
  let result = @lib.BlockType::val_type(@lib.ValType::i32())
  let bodies : Array[Array[@lib.Instruction]] = [
    [one, call, @lib.Instruction::i32_add()],
    [@lib.Instruction::block(result, @lib.Expr::new([call]))],
    [one, @lib.Instruction::if_(result, [call], Some([one]))],
    [@lib.Instruction::loop_(result, @lib.Expr::new([call]))],
    [
      @lib.Instruction::try_(result, @lib.Expr::new([one]), [
        @lib.LegacyCatch::all(@lib.Expr::new([call])),
      ]),
    ],
    [@lib.Instruction::try_table(result, [], @lib.Expr::new([call]))],
    [call, one, one, @lib.Instruction::select()],
    [
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_atomic_load(@lib.MemArg::new(2U, None, 0UL)),
      call,
      @lib.Instruction::i32_add(),
    ],
    [@lib.Instruction::atomic_fence(), one],
    [call],
    [
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::call_indirect(
        @lib.TypeIdx::new(0U),
        @lib.TableIdx::new(0U),
      ),
    ],
    [
      @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
      @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
    ],
    [@lib.Instruction::return_call(@lib.FuncIdx::new(0U))],
    [
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::return_call_indirect(
        @lib.TypeIdx::new(0U),
        @lib.TableIdx::new(0U),
      ),
    ],
    [
      @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
      @lib.Instruction::return_call_ref(@lib.TypeIdx::new(0U)),
    ],
    // Calls in typed control entry values must merge just like calls in bodies.
    [
      call,
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
        @lib.Expr::new([]),
      ),
    ],
    [
      call,
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
        @lib.Expr::new([]),
      ),
    ],
    [
      call,
      one,
      @lib.Instruction::if_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
        [],
        Some([]),
      ),
    ],
  ]
  let base = pass_test_module_from_wat(
    "(module (type $sig (func (result i32))) (type $entry (func (param i32) (result i32))) (import \"env\" \"f\" (func $f (type $sig))) (memory 1 1 shared) (table 1 funcref) (elem declare func $f) (func (result i32) i32.const 1))",
  )
  for body in bodies {
    let input = base.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    )
    ignore(@validate.validate_module(input).unwrap())
    let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(1U))
    @ir.hot_verify_core(func).unwrap()
    @ir.hot_verify_control(func).unwrap()
    let ctx = Some(@ir.hot_module_context_from_module(input))
    let selected_cache = hso_new_predicate_cache()
    let reference_cache = hso_new_predicate_cache()
    for node in 0..<@ir.hot_node_count(func) {
      if !@ir.hot_node_is_live(func, node) {
        continue
      }
      let selected = hso_order_effects_for_node(selected_cache, func, ctx, node)
      let reference = hso_query_reference(reference_cache, func, ctx, node)
      hso_query_assert_equal(selected, reference)
      if (@ir.effects_for_node(func, node) & @ir.EFFECT_MASK_CALL) != 0U {
        assert_true(selected.shared_memory_read && selected.shared_memory_write)
        assert_true(selected.shared_struct_read && selected.shared_struct_write)
        assert_true(selected.shared_array_read && selected.shared_array_write)
        let fence = hso_new_order_effects()
        hso_order_effects_note_exact_instr(
          fence,
          ctx,
          @lib.Instruction::atomic_fence(),
        )
        assert_true(hso_order_effects_ordered_before(selected, fence))
        assert_true(hso_order_effects_ordered_before(fence, selected))
      }
    }
  }
}

///|
test "heap store order query call barriers follow mutation revisions" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (import \"env\" \"f\" (func $f (result i32))) (func (result i32) i32.const 1 i32.const 2 i32.add))",
  )
  let func = fixture.hot_func
  let root = @ir.hot_root_get(func, 0)
  let leaf = @ir.hot_child_get(func, root, 0)
  let ctx = Some(@ir.hot_module_context_from_module(fixture.mod_))
  let cache = hso_new_predicate_cache()
  let initial = hso_order_effects_for_node(cache, func, ctx, root)
  assert_false(initial.shared_memory_write)
  let call = @ir.hot_build_call(func, 0, [@lib.ValType::i32()], [])
  @ir.hot_replace_node(func, leaf, @ir.hot_node_get(func, call))
  let changed = hso_order_effects_for_node(cache, func, ctx, root)
  assert_true(
    changed.shared_memory_write &&
    changed.shared_struct_write &&
    changed.shared_array_write,
  )
  hso_query_assert_equal(
    changed,
    hso_query_reference(hso_new_predicate_cache(), func, ctx, root),
  )
  let constant = @ir.hot_build_const_i32(func, @lib.I32(1))
  @ir.hot_replace_node(func, leaf, @ir.hot_node_get(func, constant))
  let restored = hso_order_effects_for_node(cache, func, ctx, root)
  assert_false(restored.shared_memory_write)
  hso_query_assert_equal(restored, initial)
  ignore(@ir.ir_test_assert_verify_and_lower(fixture))
}

///|
test "heap store order queries preserve call barriers in shared operand DAGs" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (import \"env\" \"f\" (func $f (result i32))) (func (result i32) call $f))",
  )
  let func = fixture.hot_func
  let ctx = Some(@ir.hot_module_context_from_module(fixture.mod_))
  let mut root = @ir.hot_root_get(func, 0)
  for _ in 0..<10 {
    root = @ir.hot_build_binary(func, @lib.ValType::i32(), root, root)
    @ir.hot_node_exact_instr_set(func, root, @lib.Instruction::i32_add())
  }
  let cache = hso_new_predicate_cache()
  let summary = hso_order_effects_for_node(cache, func, ctx, root)
  hso_query_assert_equal(
    summary,
    hso_query_reference(hso_new_predicate_cache(), func, ctx, root),
  )
  assert_true(
    summary.shared_memory_write &&
    summary.shared_struct_write &&
    summary.shared_array_write,
  )
  for _ in 0..<32 {
    ignore(@ir.hot_build_const_i32(func, @lib.I32(1)))
  }
  let after_growth = hso_order_effects_for_node(cache, func, ctx, root)
  hso_query_assert_equal(after_growth, summary)
  hso_query_assert_equal(
    after_growth,
    hso_query_reference(hso_new_predicate_cache(), func, ctx, root),
  )
}

///|
test "heap store optimization keeps observable stores around nested host calls" {
  let get = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let call = @lib.Instruction::call(@lib.FuncIdx::new(0U))
  let call_bodies : Array[Array[@lib.Instruction]] = [
    [get, call],
    [
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([get, call]),
      ),
    ],
    [
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [get, call],
        Some([@lib.Instruction::nop()]),
      ),
    ],
    [
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([get, call]),
        [@lib.LegacyCatch::all(@lib.Expr::new([@lib.Instruction::nop()]))],
      ),
    ],
  ]
  let base = pass_test_module_from_wat(
    "(module (type $s (struct (field (mut i32)))) (import \"env\" \"observe\" (func $observe (param (ref $s)))) (func (param (ref $s)) (result i32) i32.const 0))",
  )
  let type_idx = @lib.TypeIdx::new(0U)
  for call_body in call_bodies {
    let body = [
      get,
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::struct_set(type_idx, @lib.U32(0U)),
    ]
    body.append(call_body)
    body.append([
      get,
      @lib.Instruction::i32_const(@lib.I32(9)),
      @lib.Instruction::struct_set(type_idx, @lib.U32(0U)),
      get,
      @lib.Instruction::struct_get(type_idx, @lib.U32(0U)),
    ])
    let input = base.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    )
    ignore(@validate.validate_module(input).unwrap())
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "heap-store-optimization",
    ]).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    let hot = @ir.hot_lift_func(output, @lib.FuncIdx::new(1U))
    let mut stores = 0
    let mut calls = 0
    for node in 0..<@ir.hot_node_count(hot) {
      if !@ir.hot_node_is_live(hot, node) {
        continue
      }
      match @ir.hot_node_exact_instr(hot, node) {
        Some(@lib.StructSet(_, _)) => stores += 1
        _ => ()
      }
      if @ir.hot_node_get(hot, node).op is @ir.HotOp::Call {
        calls += 1
      }
    }
    assert_eq(stores, 2)
    assert_eq(calls, 1)
  }
}

///|
fn hso_query_bench(it : @bench.T, depth : Int32, reference : Bool) -> Unit {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (import \"env\" \"f\" (func $f (result i32))) (func (result i32) call $f))",
  )
  let func = fixture.hot_func
  let ctx = Some(@ir.hot_module_context_from_module(fixture.mod_))
  let mut root = @ir.hot_root_get(func, 0)
  for _ in 0..<depth {
    root = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      root,
      @ir.hot_build_const_i32(func, @lib.I32(1)),
    )
    @ir.hot_node_exact_instr_set(func, root, @lib.Instruction::i32_add())
  }
  let selected = hso_order_effects_for_node(
    hso_new_predicate_cache(),
    func,
    ctx,
    root,
  )
  let control = hso_query_reference(hso_new_predicate_cache(), func, ctx, root)
  if selected.shared_memory_read != control.shared_memory_read ||
    selected.shared_memory_write != control.shared_memory_write ||
    selected.shared_struct_read != control.shared_struct_read ||
    selected.shared_struct_write != control.shared_struct_write ||
    selected.shared_array_read != control.shared_array_read ||
    selected.shared_array_write != control.shared_array_write ||
    selected.acquire_read != control.acquire_read ||
    selected.release_write != control.release_write ||
    selected.seq_cst != control.seq_cst ||
    selected.atomic_order_mask != control.atomic_order_mask {
    abort("heap store query benchmark changed order effects")
  }
  // A count of one keeps each calibrated sample visible without winsorization.
  for sample in 0..<7 {
    it.bench(
      fn() {
        let cache = hso_new_predicate_cache()
        it.keep(
          if reference {
            hso_query_reference(cache, func, ctx, root)
          } else {
            hso_order_effects_for_node(cache, func, ctx, root)
          },
        )
      },
      name="raw-\{sample}",
      count=1,
    )
  }
}

///|
#skip
test "bench heap store call effects depth=8 subtree reference" (it : @bench.T) {
  hso_query_bench(it, 8, true)
}

///|
#skip
test "bench heap store call effects depth=8 selected" (it : @bench.T) {
  hso_query_bench(it, 8, false)
}

///|
#skip
test "bench heap store call effects depth=128 subtree reference" (it : @bench.T) {
  hso_query_bench(it, 128, true)
}

///|
#skip
test "bench heap store call effects depth=128 selected" (it : @bench.T) {
  hso_query_bench(it, 128, false)
}
