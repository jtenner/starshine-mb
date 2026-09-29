///|
fn sl_stacked_block_const_source(
  func : @ir.HotFunc,
  node : Int,
) -> @lib.Instruction? {
  let data = @ir.hot_node_get(func, node)
  if data.op is @ir.Const {
    match @ir.hot_const_get(func, data.imm0) {
      @ir.I32Const(value) => Some(@lib.Instruction::i32_const(value))
      _ => None
    }
  } else {
    None
  }
}

///|
fn sl_stacked_block_first_operand_source(
  output : @lib.Module,
) -> @lib.Instruction? {
  let func = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
  let add = @ir.hot_root_get(func, @ir.hot_root_count(func) - 1)
  let first = @ir.hot_child_get(func, add, 0)
  let flow = @ir.local_graph_build_full_flow(
    func,
    @ir.cfg_build(func, expand_operand_control=true),
  )
  let seen = Array::make(@ir.hot_node_count(func), false)
  fn source(node : Int) -> @lib.Instruction? {
    if node < 0 || seen[node] {
      return None
    }
    seen[node] = true
    if @ir.hot_node_get(func, node).op is @ir.LocalGet {
      let sources = @ir.local_graph_reaching_sources_for_get(flow, node)
      if sources.length() != 1 {
        return None
      }
      match sources[0] {
        @ir.EntrySource(local) =>
          Some(@lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())))
        @ir.SetSource(write) => source(@ir.hot_child_get(func, write, 0))
      }
    } else {
      sl_stacked_block_const_source(func, node)
    }
  }
  source(first)
}

///|
test "SL modes preserve entry and earlier-write values stacked across a block overwrite" {
  for
    (body, expected) in [
      (
        "local.get 1 block i32.const 11 local.set 1 end local.get 1 i32.add",
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      ),
      (
        "i32.const 5 local.set 1 local.get 1 block i32.const 11 local.set 1 end local.get 1 i32.add",
        @lib.Instruction::i32_const(@lib.I32(5)),
      ),
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (export \"run\") (param i32 i32 i32) (result i32) \{body}))",
    )
    let saved = @binary.encode_module(input).unwrap()
    for (_, policy) in sl_get_count_policies() {
      let direct = sl_get_count_run_fixture(input, policy, true)
      @validate.validate_module(direct).unwrap()
      assert_eq(sl_stacked_block_first_operand_source(direct), Some(expected))
    }
    for
      pass in [
        "simplify-locals", "simplify-locals-nonesting", "simplify-locals-notee",
        "simplify-locals-nostructure", "simplify-locals-notee-nostructure",
      ] {
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
      @validate.validate_module(output).unwrap()
      assert_eq(sl_stacked_block_first_operand_source(output), Some(expected))
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}

///|
test "SL modes preserve a one-armed branch exit before the assigned value" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) i32.const 5 local.set 3 local.get 0 if local.get 0 i32.const 1 i32.and br_if 0 local.get 0 i32.const 1 i32.add local.set 3 end local.get 3 i32.const 2 i32.add))",
  )
  let saved = @binary.encode_module(input).unwrap()
  for (_, policy) in sl_get_count_policies() {
    let output = sl_get_count_run_fixture(input, policy, true)
    @validate.validate_module(output).unwrap()
  }
  for
    pass in [
      "simplify-locals", "simplify-locals-nonesting", "simplify-locals-notee", "simplify-locals-nostructure",
      "simplify-locals-notee-nostructure",
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
