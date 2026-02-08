///|
test "build_cfg lowers if into branch blocks and merge" {
  let expr = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::i32_const(I32(1)),
      TExpr::new([TInstr::nop()]),
      Some(TExpr::new([TInstr::nop()])),
    ),
    TInstr::nop(),
  ])
  let cfg = build_cfg(expr)
  let entry = cfg.entry()
  let entry_succs = cfg.successors(entry)
  assert_eq(entry_succs.length(), 2)
  let then_block = entry_succs[0]
  let else_block = entry_succs[1]
  assert_true(cfg.predecessors(then_block).contains(entry))
  assert_true(cfg.predecessors(else_block).contains(entry))
  let then_succs = cfg.successors(then_block)
  let else_succs = cfg.successors(else_block)
  assert_eq(then_succs.length(), 1)
  assert_eq(else_succs.length(), 1)
  let merge_block = then_succs[0]
  assert_eq(else_succs[0], merge_block)
  assert_true(cfg.predecessors(merge_block).contains(then_block))
  assert_true(cfg.predecessors(merge_block).contains(else_block))
  let idom = cfg.dominators()
  assert_eq(idom[entry], entry)
  assert_true(cfg.dominates(entry, merge_block))
  assert_false(cfg.dominates(then_block, else_block))
}

///|
test "CFG successors and predecessors include br_table default edge" {
  let b0 = BlockId(0)
  let b1 = BlockId(1)
  let b2 = BlockId(2)
  let b3 = BlockId(3)
  let blocks : Map[BlockId, BasicBlock] = {}
  blocks[b0] = BasicBlock::{
    id: b0,
    instrs: [],
    terminator: BrTable(TInstr::i32_const(I32(0)), [b1, b2], b3),
  }
  blocks[b1] = BasicBlock::{ id: b1, instrs: [], terminator: Unreachable }
  blocks[b2] = BasicBlock::{ id: b2, instrs: [], terminator: Unreachable }
  blocks[b3] = BasicBlock::{ id: b3, instrs: [], terminator: Unreachable }
  let preds = compute_predecessors(blocks)
  let cfg = CFG::{ entry: b0, blocks, preds }
  let succs = cfg.successors(b0)
  assert_eq(succs, [b1, b2, b3])
  assert_eq(cfg.predecessors(b1), [b0])
  assert_eq(cfg.predecessors(b2), [b0])
  assert_eq(cfg.predecessors(b3), [b0])
}
