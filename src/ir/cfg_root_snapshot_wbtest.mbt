///|
fn cfg_root_snapshot_fixture(width : Int, depth : Int) -> HotFunc {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let roots : Array[NodeId] = []
  for _ in 0..<width {
    let mut value = hot_build_local_get(func, 0)
    for step in 0..<depth {
      value = hot_build_binary(
        func,
        @lib.ValType::i32(),
        value,
        hot_build_const_i32(func, @lib.I32(step)),
      )
      hot_node_exact_instr_set(func, value, @lib.Instruction::i32_add())
    }
    roots.push(hot_build_drop(func, value))
  }
  hot_root_append(func, hot_build_block(func, @lib.BlockType::void_(), roots))
  func
}

///|
test "CFG region roots exclude indexed inputs and preserve exact body slots" {
  let module_ = ir_test_module_from_wat(
    "(module (type $s (func (param i32) (result i32))) (func (param i32) (result i32) local.get 0 block (type $s) i32.const 1 i32.add block local.get 0 drop end end))",
  )
  let func = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  for expanded in [false, true] {
    let cfg = cfg_build(func, expand_operand_control=expanded)
    let mut expected = hot_root_count(func)
    for node in 0..<hot_node_count(func) {
      if hot_node_is_live(func, node) && hot_node_op(func, node) is HotOp::Block {
        expected += hot_region_root_count(func, hot_region_body_ref(func, node))
      }
    }
    assert_eq(cfg.region_roots.length(), expected)
    for entry in cfg.region_roots {
      let region = if entry.region_holder == HOT_NONE_NODE {
        HotRegionRef::root()
      } else {
        hot_region_body_ref(func, entry.region_holder)
      }
      let root = hot_region_get(func, region, entry.slot)
      assert_true(cfg.blocks[entry.block].nodes.contains(root))
    }
  }
}
