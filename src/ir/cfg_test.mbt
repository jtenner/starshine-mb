///|
fn[S : Show] cfg_test_show_edges(edges : Array[S]) -> Array[String] {
  let out : Array[String] = []
  for edge in edges {
    out.push(edge.to_string())
  }
  out
}

///|
fn[S : Show] cfg_test_show_one(value : S) -> String {
  value.to_string()
}

///|
fn cfg_test_nested_fixture() -> HotFunc {
  hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::loop_(
                @lib.BlockType::void_(),
                @lib.Expr::new([@lib.Instruction::nop()]),
              ),
            ],
            Some([@lib.Instruction::return_()]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
  )
}

///|
test "cfg build maps nested block if and loop regions deterministically" {
  let func = cfg_test_nested_fixture()
  let cfg = cfg_build(func)
  let block_id = hot_root_get(func, 0)
  let block_body = hot_region_body_ref(func, block_id)
  let if_id = hot_region_get(func, block_body, 0)
  let then_region = hot_region_then_ref(func, if_id)
  let loop_id = hot_region_get(func, then_region, 0)
  let loop_body = hot_region_body_ref(func, loop_id)
  let else_region = hot_region_else_ref(func, if_id).unwrap()
  let entry_block = cfg_entry_block(cfg)
  let block_header = cfg_block_for_node(cfg, block_id).unwrap()
  let if_header = cfg_block_for_region_root(cfg, block_body, 0).unwrap()
  let loop_header = cfg_block_for_node(cfg, loop_id).unwrap()
  let loop_body_block = cfg_block_for_region_root(cfg, loop_body, 0).unwrap()
  let return_block = cfg_block_for_region_root(cfg, else_region, 0).unwrap()

  @debug.assert_eq(cfg_test_show_edges(cfg_successors(cfg, entry_block)), [
    "{kind: FallthroughEdge, block: \{block_header}}",
  ])
  @debug.assert_eq(cfg_test_show_edges(cfg_successors(cfg, block_header)), [
    "{kind: FallthroughEdge, block: \{if_header}}",
  ])
  @debug.assert_eq(cfg_test_show_edges(cfg_successors(cfg, if_header)), [
    "{kind: FallthroughEdge, block: \{loop_header}}",
    "{kind: FallthroughEdge, block: \{return_block}}",
  ])
  @debug.assert_eq(cfg_test_show_edges(cfg_successors(cfg, loop_header)), [
    "{kind: FallthroughEdge, block: \{loop_body_block}}",
  ])
}

///|
fn cfg_test_try_table_fixture() -> HotFunc {
  hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::try_table(
            @lib.BlockType::void_(),
            [@lib.Catch::all(@lib.LabelIdx::new(0U))],
            @lib.Expr::new([@lib.Instruction::nop()]),
          ),
          @lib.Instruction::nop(),
        ]),
      ),
    ]),
    HotLocals::new(),
  )
}

///|
test "cfg build materializes try_table body and exceptional catch-list edges" {
  let func = cfg_test_try_table_fixture()
  let cfg = cfg_build(func)
  let block_id = hot_root_get(func, 0)
  let block_body = hot_region_body_ref(func, block_id)
  let try_table_id = hot_region_get(func, block_body, 0)
  let try_table_block = cfg_block_for_node(cfg, try_table_id).unwrap()
  let body_region = hot_region_body_ref(func, try_table_id)
  let body_block = cfg_block_for_region_root(cfg, body_region, 0).unwrap()
  let continuation_block = cfg_block_for_region_root(cfg, block_body, 1).unwrap()
  let succs = cfg_successors(cfg, try_table_block)

  @debug.assert_eq(succs.length(), 2)
  @debug.assert_eq(
    cfg_test_show_one(succs[0]),
    "{kind: FallthroughEdge, block: \{body_block}}",
  )
  @debug.assert_eq(cfg_test_show_one(succs[1].kind), "ExceptionalEdge")
  assert_true(cfg_block_get(cfg, succs[1].block).is_synthetic)
  @debug.assert_eq(cfg_test_show_edges(cfg_successors(cfg, body_block)), [
    "{kind: FallthroughEdge, block: \{continuation_block}}",
  ])
  @debug.assert_eq(cfg_exceptional_exit_block(cfg), None)
}

///|
fn cfg_test_drop_result_if_fixture() -> (HotFunc, NodeId, NodeId) {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    hot_build_local_get(func, 0),
    [
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(7))),
      hot_build_local_get(func, 1),
    ],
    else_body=Some([
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(9))),
      hot_build_local_get(func, 1),
    ]),
  )
  let drop = hot_build_drop(func, result_if)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, hot_build_local_get(func, 1)))
  (func, drop, result_if)
}

///|
test "cfg build maps drop operand result-if arms to join continuation" {
  let (func, drop, result_if) = cfg_test_drop_result_if_fixture()
  let operand_id = hot_child_get(func, drop, 0)
  @debug.assert_eq(operand_id, result_if)
  assert_true(
    ssa_simple_drop_result_if_allowed(func, drop, 0, operand_id),
    msg="expected drop operand result-if shape to be allowed",
  )
  let cfg = cfg_build(func)
  assert_true(cfg_block_count(cfg) >= 3)
  let drop_block = cfg_block_for_node(cfg, drop).unwrap()
  @debug.assert_eq(cfg_successors(cfg, drop_block).length(), 2)
  let then_region = hot_region_then_ref(func, result_if)
  let then_set = hot_region_get(func, then_region, 0)
  let then_block = cfg_block_for_node(cfg, then_set).unwrap()
  let else_region = hot_region_else_ref(func, result_if).unwrap()
  let else_set = hot_region_get(func, else_region, 0)
  let else_block = cfg_block_for_node(cfg, else_set).unwrap()
  let join_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()
  let dom = dom_build(cfg)

  @debug.assert_eq(cfg_successors(cfg, drop_block).length(), 2)
  @debug.assert_eq(dom_idom(dom, then_block), Some(drop_block))
  @debug.assert_eq(dom_idom(dom, else_block), Some(drop_block))
  @debug.assert_eq(dom_idom(dom, join_block), Some(drop_block))
  assert_true(dom_children(dom, drop_block).length() >= 2)
}

///|
test "cfg build places condition local writes in drop operand result-if predecessor" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    hot_build_local_tee(func, 1, hot_build_const_i32(func, @lib.I32(1))),
    [
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(7))),
      hot_build_local_get(func, 1),
    ],
    else_body=Some([
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(9))),
      hot_build_local_get(func, 1),
    ]),
  )
  let drop = hot_build_drop(func, result_if)
  hot_root_append(func, drop)
  hot_root_append(func, hot_build_drop(func, hot_build_local_get(func, 1)))
  assert_true(
    ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="expected condition local.tee result-if shape to be allowed",
  )
  let cfg = cfg_build(func)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let drop_block = cfg_block_for_node(cfg, drop).unwrap()
  let writes = local_write_block_ids(use_def, 1)
  assert_true(
    writes.length() >= 2,
    msg="expected condition and arm local writes",
  )
  @debug.assert_eq(writes[0], drop_block)
}

///|
test "ssa simple drop result-if rejects missing else arm" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let result_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    hot_build_local_get(func, 0),
    [
      hot_build_local_set(func, 1, hot_build_const_i32(func, @lib.I32(7))),
      hot_build_local_get(func, 1),
    ],
    else_body=None,
  )
  let drop = hot_build_drop(func, result_if)
  hot_root_append(func, drop)
  assert_false(
    ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="result-if without else must stay fail-closed",
  )
}

///|
test "cfg build keeps unreachable roots in distinct predless blocks" {
  let func = hot_lift_body(
    @lib.Expr::new([@lib.Instruction::return_(), @lib.Instruction::nop()]),
    HotLocals::new(),
  )
  let cfg = cfg_build(func)
  let root_region = HotRegionRef::root()
  let return_block = cfg_block_for_region_root(cfg, root_region, 0).unwrap()
  let nop_block = cfg_block_for_region_root(cfg, root_region, 1).unwrap()

  @debug.assert_eq(cfg_test_show_edges(cfg_successors(cfg, return_block)), [
    "{kind: ReturnEdge, block: \{cfg_exit_block(cfg)}}",
  ])
  @debug.assert_eq(cfg_predecessors(cfg, nop_block), [])
}

///|
test "cfg build splits tail calls before later unreachable roots" {
  let func = HotFunc::new()
  let return_call = hot_build_return_call(func, 0, [])
  let nop = hot_build_nop(func)
  hot_root_append(func, return_call)
  hot_root_append(func, nop)
  let cfg = cfg_build(func)
  let return_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 0).unwrap()
  let nop_block = cfg_block_for_region_root(cfg, HotRegionRef::root(), 1).unwrap()

  @debug.assert_eq(cfg_test_show_edges(cfg_successors(cfg, return_block)), [
    "{kind: ReturnEdge, block: \{cfg_exit_block(cfg)}}",
  ])
  @debug.assert_eq(cfg_predecessors(cfg, nop_block), [])
}

///|
test "cfg build gives synthetic continuations a concrete insertion span" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::nop()],
            Some([@lib.Instruction::nop()]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
  )
  let cfg = cfg_build(func)
  let outer_block = hot_root_get(func, 0)
  let mut found = false
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    let block = cfg_block_get(cfg, block_id)
    if block.is_synthetic &&
      block.region_holder == outer_block &&
      block.start_slot == 1 &&
      block.end_slot == 1 {
      found = true
      break
    }
  }
  assert_true(found)
}
