///|
fn mass_audit_ir_count_local_tees(body : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.LocalTee(_) => count += 1
      @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
        count += mass_audit_ir_count_local_tees(nested)
      _ => ()
    }
  }
  count
}

///|
test "mass audit IR expanded CFG preserves repeated tuple entry read sources" {
  let input = @wast.wast_to_binary_module(
    "(module (type $pair (func (result i32 i32))) (type $entry (func (param i32 i32 i32 i32))) (func (result i32) (local i32) i32.const 1 i32.const 2 i32.const 3 i32.const 4 loop (type $entry) drop drop drop drop end local.get 0))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let loop_id = hot_root_get(func, 0)
  assert_true(hot_node_get(func, loop_id).op is HotOp::Loop)
  let read = hot_build_local_get(func, 0)
  let add = hot_build_binary(
    func,
    @lib.ValType::i32(),
    read,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  let write = hot_build_local_tee(func, 0, add)
  let tuple = hot_build_resolved_block(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [],
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [write, hot_build_const_i32(func, @lib.I32(0))],
  )
  let body : Array[NodeId] = []
  for slot in 4..<8 {
    let drop = hot_child_get(func, loop_id, slot)
    hot_child_set(func, drop, 0, tuple)
    body.push(drop)
  }
  let children = [tuple, tuple, tuple, tuple]
  children.append(body)
  ignore(hot_replace_child_span(func, loop_id, children))
  hot_verify_all(func).unwrap()
  let lowered = hot_lower_func(func)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
  let @lib.Func(_, @lib.Expr(instructions)) = lowered
  assert_eq(mass_audit_ir_count_local_tees(instructions), 2)
  for expanded in [false, true] {
    let graph = local_graph_build_full_flow(
      func,
      cfg_build(func, expand_operand_control=expanded),
    )
    let sources = local_graph_reaching_sources_for_get(graph, read)
    assert_true(sources.contains(HotLocalGraphSource::EntrySource(0)))
    assert_true(sources.contains(HotLocalGraphSource::SetSource(write)))
  }
}

///|
test "mass audit IR type interning owns its caller result row" {
  let func = HotFunc::new()
  let results = [@lib.ValType::i32(), @lib.ValType::i64()]
  let ty = hot_type_intern_results(func, results)
  results[1] = @lib.ValType::f64()
  assert_eq(hot_type_results(func, ty), [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])
  hot_verify_core(func).unwrap()
}

///|
test "mass audit IR core verifier rejects an invalid operand cycle" {
  // This intentionally invalid graph must fail before lowering recurses.
  let func = HotFunc::new()
  let value = hot_build_const_i32(func, @lib.I32(1))
  let drop = hot_build_drop(func, value)
  hot_root_append(func, drop)
  hot_child_set(func, drop, 0, drop)
  assert_true(hot_verify_core(func) is Err(_))
}

///|
test "mass audit IR analysis cache distinguishes functions at equal revisions" {
  let pure = HotFunc::new()
  hot_root_append(
    pure,
    hot_build_drop(pure, hot_build_const_i32(pure, @lib.I32(7))),
  )
  let calling = HotFunc::new()
  hot_root_append(
    calling,
    hot_build_call(calling, 0, [], [hot_build_const_i32(calling, @lib.I32(7))]),
  )
  assert_eq(hot_revision_current(pure), hot_revision_current(calling))
  let cache = HotAnalysisCache::new()
  let before = cache_get_or_build_effects(cache, pure)
  let after = cache_get_or_build_effects(cache, calling)
  assert_eq(before.root_region_mask & EFFECT_MASK_CALL, 0U)
  assert_true((after.root_region_mask & EFFECT_MASK_CALL) != 0U)
}

///|
test "mass audit IR control verifier rejects a branch to a sibling label" {
  // This intentionally invalid transfer has a live label outside its scope.
  let func = HotFunc::new()
  let first = hot_build_block(func, @lib.BlockType::void_(), [])
  let branch = hot_build_br(func, hot_control_node_label(func, first))
  let second = hot_build_block(func, @lib.BlockType::void_(), [branch])
  hot_root_append(func, first)
  hot_root_append(func, second)
  assert_true(hot_verify_control(func) is Err(_))
}

///|
test "mass audit IR tuple materialization keeps one capture per lane" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"host\" \"pair\" (func (result i32 i32))) (func (result i32 i32 i32 i32 i32 i32 i32 i32) call 0 call 0 call 0 call 0))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let func = hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(1U),
    hot_module_context_from_module(input),
    materialize_multi_values=true,
  ).unwrap()
  hot_verify_all(func).unwrap()
  assert_eq(hot_local_count(func), 8)
  let lowered = hot_lower_func(func)
  let @lib.Func(_, @lib.Expr(instructions)) = lowered
  let mut calls = 0
  for instruction in instructions {
    if instruction is @lib.Call(_) {
      calls += 1
    }
  }
  assert_eq(calls, 4)
  let output = input.with_code_sec(@lib.CodeSec::new([lowered]))
  @validate.validate_module(
    @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
  ).unwrap()
}

///|
test "mass audit IR shared control rejects an outer target absent from one context" {
  let func = HotFunc::new()
  let outer = hot_build_block(func, @lib.BlockType::void_(), [])
  let branch = hot_build_br(func, hot_control_node_label(func, outer))
  let inner = hot_build_block(func, @lib.BlockType::void_(), [branch])
  ignore(hot_replace_child_span(func, outer, [inner]))
  hot_root_append(func, outer)
  hot_root_append(func, inner)
  // One occurrence is inside outer; the other is outside its active scope.
  assert_true(hot_verify_control(func) is Err(_))
}

///|
test "mass audit IR shared control permits its own label in each occurrence" {
  let func = HotFunc::new()
  let block = hot_build_block(func, @lib.BlockType::void_(), [])
  let branch = hot_build_br(func, hot_control_node_label(func, block))
  ignore(hot_replace_child_span(func, block, [branch]))
  hot_root_append(func, block)
  hot_root_append(func, block)
  hot_verify_control(func).unwrap()
}

///|
test "mass audit IR resolved type owns both caller rows" {
  let func = HotFunc::new()
  let params = [@lib.ValType::i32()]
  let results = [@lib.ValType::i64()]
  let ty = hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    params,
    results,
  )
  params[0] = @lib.ValType::f32()
  results[0] = @lib.ValType::f64()
  match hot_type_get(func, ty) {
    HotTypeInfo::BlockResultResolved(_, stored_params, stored_results) => {
      assert_eq(stored_params, [@lib.ValType::i32()])
      assert_eq(stored_results, [@lib.ValType::i64()])
    }
    _ => fail("expected a resolved block signature")
  }
  hot_verify_core(func).unwrap()
}

///|
test "mass audit IR tuple materialization restores non-null reference lanes" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"host\" \"pair\" (func (result (ref i31) (ref i31)))) (func (result (ref i31) (ref i31) (ref i31) (ref i31)) call 0 call 0))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let func = hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(1U),
    hot_module_context_from_module(input),
    materialize_multi_values=true,
  ).unwrap()
  assert_eq(hot_local_count(func), 4)
  for capture_type in func.locals.locals {
    match capture_type {
      @lib.RefTypeValType(ref_type) => assert_true(ref_type.is_nullable())
      _ => fail("expected nullable reference capture storage")
    }
  }
  let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
  @validate.validate_module(
    @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
  ).unwrap()
}

///|
test "mass audit IR cached verifier rejects a different function owner" {
  let first = HotFunc::new()
  let second = HotFunc::new()
  hot_root_append(first, hot_build_nop(first))
  hot_root_append(second, hot_build_nop(second))
  assert_eq(hot_revision_current(first), hot_revision_current(second))
  let cache = HotAnalysisCache::new()
  ignore(cache_get_or_build_cfg(cache, first))
  hot_verify_cached_analyses(first, cache).unwrap()
  assert_true(hot_verify_cached_analyses(second, cache) is Err(_))
}

///|
test "mass audit IR observable prefix does not recapture stable non-null tuple reads" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"host\" \"pair\" (func (result (ref i31) (ref i31)))) (import \"host\" \"scalar\" (func (result i32))) (func (result (ref i31) (ref i31)) call 0 call 1 nop drop))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let func = hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(2U),
    hot_module_context_from_module(input),
    capture_stack_locals=true,
    materialize_multi_values=true,
  ).unwrap()
  // Two saved pair lanes and the pending scalar call each need one capture.
  assert_eq(hot_local_count(func), 3)
  for capture_type in func.locals.locals {
    if capture_type is @lib.RefTypeValType(ref_type) {
      assert_true(ref_type.is_nullable())
    }
  }
  let lowered = hot_lower_func(func)
  let @lib.Func(_, @lib.Expr(body)) = lowered
  assert_eq(body.filter(fn(instr) { instr is @lib.Call(_) }).length(), 2)
  @validate.validate_module(
    @binary.decode_module(
      @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap(),
    ).unwrap(),
  ).unwrap()
}

///|
test "mass audit IR local conflict does not recapture stable non-null tuple reads" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"host\" \"pair\" (func (result (ref i31) (ref i31)))) (func (param i32) (result (ref i31) (ref i31)) call 0 local.get 0 i32.const 2 local.set 0 drop))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let func = hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(1U),
    hot_module_context_from_module(input),
    capture_stack_locals=true,
    materialize_multi_values=true,
  ).unwrap()
  // One parameter, two saved pair lanes, and the source read across its write.
  assert_eq(hot_local_count(func), 4)
  for capture_type in func.locals.locals {
    if capture_type is @lib.RefTypeValType(ref_type) {
      assert_true(ref_type.is_nullable())
    }
  }
  let lowered = hot_lower_func(func)
  let @lib.Func(_, @lib.Expr(body)) = lowered
  assert_eq(body.filter(fn(instr) { instr is @lib.Call(_) }).length(), 1)
  @validate.validate_module(
    @binary.decode_module(
      @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap(),
    ).unwrap(),
  ).unwrap()
}
