///|
// Frozen constructor and complete graph builder retain the original arena scan.
fn cfg_presence_reference_new(
  func : HotFunc,
  conservative_exception_entries : Bool,
  expand_operand_control : Bool,
) -> CfgBuilder {
  let node_count = hot_node_count(func)
  let node_to_block = Array::make(node_count, -1)
  let mut has_continuations = false
  for node in 0..<node_count {
    if hot_node_is_live(func, node) &&
      hot_node_get(func, node).op == HotOp::Continuation {
      has_continuations = true
    }
  }
  let label_targets = Array::make(func.labels.length(), -1)
  {
    cfg: {
      operands_expanded: expand_operand_control,
      blocks: [],
      node_to_block,
      region_roots: [],
      entry_block: -1,
      exit_block: -1,
      exceptional_exit_block: None,
    },
    label_targets,
    conservative_exception_entries,
    operand_seen: if expand_operand_control {
      Some(Array::make(node_count, false))
    } else {
      None
    },
    // A region with no later root cannot select a preceding dependency.
    // Delay the whole-function walk until an actual multi-root query.
    source_order: None,
    operand_minima: None,
    continuation_targets: if has_continuations {
      Array::make(node_count, None)
    } else {
      []
    },
  }
}

///|
fn cfg_presence_reference_build(
  func : HotFunc,
  conservative_exception_entries? : Bool = true,
  expand_operand_control? : Bool = false,
) -> HotCfg {
  hot_verify_all_or_abort(func)
  let builder = cfg_presence_reference_new(
    func, conservative_exception_entries, expand_operand_control,
  )
  let entry_block = cfg_builder_add_block(builder, [], true)
  let exit_block = cfg_builder_add_block(builder, [], true)
  builder.cfg.entry_block = entry_block
  builder.cfg.exit_block = exit_block

  let root_build = cfg_builder_build_region(
    builder,
    func,
    HotRegionRef::root(),
    None,
  )
  match root_build.entry_block {
    Some(block_id) =>
      cfg_builder_add_edge(
        builder,
        entry_block,
        block_id,
        CfgEdgeKind::FallthroughEdge,
      )
    None =>
      cfg_builder_add_edge(
        builder,
        entry_block,
        exit_block,
        CfgEdgeKind::FallthroughEdge,
      )
  }
  cfg_builder_connect_exits(builder, root_build.exit_blocks, Some(exit_block))

  cfg_verify(builder.cfg)
  builder.cfg
}

///|
fn cfg_presence_continuation_module() -> @lib.Module {
  let cont_sig = @lib.TypeIdx::new(0U)
  let cont = @lib.TypeIdx::new(1U)
  let tag_sig = @lib.TypeIdx::new(2U)
  let func_sig = @lib.TypeIdx::new(3U)
  let cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
        ),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::cont(cont_sig))),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([cont_ref], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([func_sig]))
  .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(tag_sig)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(cont_ref),
            @lib.Expr::new([
              @lib.Instruction::block(
                @lib.BlockType::void_(),
                @lib.Expr::new([
                  @lib.Instruction::i32_const(7),
                  @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  @lib.Instruction::i32_const(0),
                  @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                  @lib.Instruction::resume_(cont, [
                    @lib.ResumeHandler::on_label(
                      @lib.TagIdx::new(0U),
                      @lib.LabelIdx::new(1U),
                    ),
                  ]),
                  @lib.Instruction::drop(),
                ]),
              ),
              @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
              @lib.Instruction::drop(),
              @lib.Instruction::ref_null(@lib.HeapType::new(cont)),
            ]),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        ]),
      ),
    ]),
  )
}

///|
fn cfg_presence_lift(module_ : @lib.Module) -> HotFunc {
  @validate.validate_module(module_).unwrap()
  hot_lift_func_with_context_result(
    module_,
    @lib.FuncIdx::new(0U),
    hot_module_context_from_module(module_),
  ).unwrap()
}

///|
test "CFG presence proof preserves complete graphs and resume handler edges" {
  let simple = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 block local.get 0 br_if 0 i32.const 3 local.set 1 end local.get 1))",
  ).unwrap()
  let table = @wast.wast_to_binary_module(
    "(module (func (param i32) block local.get 0 br_table 0 end))",
  ).unwrap()
  let continuation = cfg_presence_continuation_module()
  for module_ in [simple, table, continuation] {
    let func = cfg_presence_lift(module_)
    for expanded in [false, true] {
      let actual = cfg_build(func, expand_operand_control=expanded)
      let expected = cfg_presence_reference_build(
        func,
        expand_operand_control=expanded,
      )
      assert_eq(actual, expected)
      cfg_verify(actual)
    }
  }
  let func = cfg_presence_lift(continuation)
  let a = cfg_builder_new(func, true, true)
  let b = cfg_builder_new(func, true, true)
  assert_eq(a.continuation_targets.length(), hot_node_count(func))
  assert_false(physical_equal(a.continuation_targets, b.continuation_targets))
  let cfg = cfg_build(func, expand_operand_control=true)
  let mut branch = false
  for block in cfg.blocks {
    for edge in block.succs {
      if edge.kind == CfgEdgeKind::BranchEdge {
        branch = true
      }
    }
  }
  assert_true(branch)
}

///|
test "CFG presence proof keeps dead slots and unused branch tables conservative" {
  let func = HotFunc::new()
  for _ in 0..<9 {
    hot_root_append(func, hot_build_nop(func))
  }
  let dead = hot_build_nop(func)
  hot_delete_node(func, dead)
  assert_eq(func.branch_tables, [])
  for unused_table in [false, true] {
    if unused_table {
      ignore(
        hot_alloc_branch_table(
          func,
          HotBranchTable::new([], HOT_IMPLICIT_FUNCTION_LABEL),
        ),
      )
    }
    for expanded in [false, true] {
      let actual = cfg_builder_new(func, false, expanded)
      let expected = cfg_presence_reference_new(func, false, expanded)
      assert_eq(actual.continuation_targets, expected.continuation_targets)
      assert_eq(actual.continuation_targets, [])
      assert_eq(actual.cfg.node_to_block, expected.cfg.node_to_block)
      assert_eq(actual.cfg.node_to_block[dead], -1)
      assert_eq(
        cfg_build(func, expand_operand_control=expanded),
        cfg_presence_reference_build(func, expand_operand_control=expanded),
      )
    }
  }
}
