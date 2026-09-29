///|
test "HOT lowering preserves the entry operands of a parameterized if" {
  let module_ = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32) i32.const 4 local.get 0 if (param i32) (result i32) i32.const 3 i32.add else i32.const 2 i32.add end))",
  ).unwrap()
  @validate.validate_module(module_).unwrap()
  let func = hot_lift_func_with_context_result(
    module_,
    @lib.FuncIdx::new(0U),
    hot_module_context_from_module(module_),
  ).unwrap()
  let lowered = hot_lower_func(func)
  match
    @validate.validate_module(
      module_.with_code_sec(@lib.CodeSec::new([lowered])),
    ) {
    Ok(_) => ()
    Err(err) => fail("parameterized if lost its entry operands: \{err}")
  }
}

///|
fn if_parameters_roundtrip(wat : String, func_index? : UInt = 0U) -> Unit raise {
  let module_ = @wast.wast_to_binary_module(wat).unwrap()
  @validate.validate_module(module_).unwrap()
  let func = hot_lift_func_with_context_result(
    module_,
    @lib.FuncIdx::new(func_index),
    hot_module_context_from_module(module_),
  ).unwrap()
  let lowered = hot_lower_func(func)
  let @lib.CodeSec(codes) = module_.code_sec.unwrap()
  let original = codes[0]
  // Exact instructions also prove that entry calls happen once, before the
  // condition, and are not moved into either arm or replaced by extra locals.
  let @lib.Func(lowered_locals, lowered_body) = lowered
  let @lib.Func(original_locals, original_body) = original
  @debug.assert_eq(lowered_locals.runs, original_locals.runs)
  @debug.assert_eq(lowered_body, original_body)
  @validate.validate_module(module_.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
}

///|
test "HOT parameterized if evaluates effectful entries before its condition" {
  if_parameters_roundtrip(
    "(module (import \"m\" \"value\" (func $value (result i32))) (import \"m\" \"condition\" (func $condition (result i32))) (func (result i32) call $value call $condition if (param i32) (result i32) i32.const 3 i32.add else i32.const 2 i32.add end))",
    func_index=2U,
  )
}

///|
test "HOT parameterized if preserves tuple producer lanes in both arms" {
  if_parameters_roundtrip(
    "(module (import \"m\" \"pair\" (func $pair (result i32 i64))) (func (param i32) (result i32 i64) call $pair local.get 0 if (param i32 i64) (result i32 i64) i64.const 3 i64.add else i64.const 2 i64.add end))",
    func_index=1U,
  )
}

///|
test "HOT parameterized if without else forwards entry values on the false path" {
  if_parameters_roundtrip(
    "(module (func (param i32) (result i32) i32.const 4 local.get 0 if (param i32) (result i32) i32.const 3 i32.add end))",
  )
}

///|
test "HOT parameterized if retains dropped entry effects in both arms" {
  if_parameters_roundtrip(
    "(module (import \"m\" \"value\" (func $value (result i32))) (func (param i32) call $value local.get 0 if (param i32) drop else drop end))",
    func_index=1U,
  )
}

///|
fn if_parameters_local_flow(expanded : Bool) -> Unit raise {
  let module_ = @wast.wast_to_binary_module(
    "(module (func (result i32) (local i32) i32.const 7 local.tee 0 i32.const 0 local.tee 0 if (param i32) (result i32) local.get 0 i32.add else local.get 0 i32.add end))",
  ).unwrap()
  @validate.validate_module(module_).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let mut if_id = HOT_NONE_NODE
  for id in 0..<hot_node_count(func) {
    if hot_node_get(func, id).op is HotOp::If {
      if_id = id
    }
  }
  assert_true(if_id >= 0)
  let condition = hot_child_get(func, if_id, 0)
  assert_true(hot_node_get(func, condition).op is HotOp::LocalTee)
  let graph = local_graph_build_full_flow(
    func,
    cfg_build(func, expand_operand_control=expanded),
  )
  let mut reads = 0
  for id in 0..<hot_node_count(func) {
    let node = hot_node_get(func, id)
    if node.op is HotOp::LocalGet && node.imm0 == 0 {
      let sources = local_graph_reaching_sources_for_get(graph, id)
      @debug.assert_eq(sources, [HotLocalGraphSource::SetSource(condition)])
      reads += 1
    }
  }
  @debug.assert_eq(reads, 2)
}

///|
test "HOT parameterized if compact CFG keeps condition writes after entry writes" {
  if_parameters_local_flow(false)
}

///|
test "HOT parameterized if expanded CFG keeps condition writes after entry writes" {
  if_parameters_local_flow(true)
}

///|
test "HOT parameterized if CFG evaluates entry calls before condition calls" {
  let module_ = @wast.wast_to_binary_module(
    "(module (import \"m\" \"value\" (func $value (result i32))) (import \"m\" \"condition\" (func $condition (result i32))) (func (result i32) call $value call $condition if (param i32) (result i32) i32.const 3 i32.add else i32.const 2 i32.add end))",
  ).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(2U))
  let cfg = cfg_build(func, expand_operand_control=true)
  let calls : Array[Int] = []
  for block in cfg.blocks {
    for id in block.nodes {
      let node = hot_node_get(func, id)
      if node.op is HotOp::Call {
        calls.push(node.imm0)
      }
    }
  }
  @debug.assert_eq(calls, [0, 1])
}

///|
test "HOT folded typed if keeps entry producers in CFG and use-def" {
  let module_ = @wast.wast_to_binary_module(
    "(module (import \"m\" \"value\" (func $value (result i32))) (func (result i32) call $value i32.const 0 if (param i32) (result i32) i32.const 3 i32.add end))",
  ).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(1U))
  let if_id = hot_root_get(func, 0)
  let entry = hot_child_get(func, if_id, 3)
  hot_control_demote_if_to_block(func, if_id, [])
  @debug.assert_eq(
    hot_region_root_count(func, hot_region_body_ref(func, if_id)),
    0,
  )
  let cfg = cfg_build(func, expand_operand_control=true)
  assert_true(cfg_block_for_node(cfg, entry) is Some(_))
  let uses = use_def_build(func, cfg=Some(cfg))
  @debug.assert_eq(node_use_count(uses, entry), 1)
  let lowered = hot_lower_func(func)
  @validate.validate_module(module_.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
}

///|
test "HOT parameterized if forwards leading effectful scalar entries in place" {
  if_parameters_roundtrip(
    "(module (import \"m\" \"first\" (func $first (result i32))) (import \"m\" \"second\" (func $second (result i64))) (func (param i32) (result i32 i64) call $first call $second local.get 0 if (param i32 i64) (result i32 i64) i64.const 3 i64.add else i64.const 2 i64.add end))",
    func_index=2U,
  )
}
