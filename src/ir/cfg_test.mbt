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

  assert_eq(cfg_test_show_edges(cfg_successors(cfg, entry_block)), [
    "{kind: FallthroughEdge, block: \{block_header}}",
  ])
  assert_eq(cfg_test_show_edges(cfg_successors(cfg, block_header)), [
    "{kind: FallthroughEdge, block: \{if_header}}",
  ])
  assert_eq(cfg_test_show_edges(cfg_successors(cfg, if_header)), [
    "{kind: FallthroughEdge, block: \{loop_header}}",
    "{kind: FallthroughEdge, block: \{return_block}}",
  ])
  assert_eq(cfg_test_show_edges(cfg_successors(cfg, loop_header)), [
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

  assert_eq(succs.length(), 2)
  assert_eq(
    cfg_test_show_one(succs[0]),
    "{kind: FallthroughEdge, block: \{body_block}}",
  )
  assert_eq(cfg_test_show_one(succs[1].kind), "ExceptionalEdge")
  assert_true(cfg_block_get(cfg, succs[1].block).is_synthetic)
  assert_eq(cfg_test_show_edges(cfg_successors(cfg, body_block)), [
    "{kind: FallthroughEdge, block: \{continuation_block}}",
  ])
  assert_eq(cfg_exceptional_exit_block(cfg), None)
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

  assert_eq(cfg_test_show_edges(cfg_successors(cfg, return_block)), [
    "{kind: ReturnEdge, block: \{cfg_exit_block(cfg)}}",
  ])
  assert_eq(cfg_predecessors(cfg, nop_block), [])
}
