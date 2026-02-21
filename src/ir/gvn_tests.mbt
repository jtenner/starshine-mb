///|
fn make_single_block_gvn_cfg(
  instrs : Array[SSAInstr],
  term : SSATerminator,
  next_value : Int,
) -> SSACFG {
  let b0 = BlockId(0)
  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{ id: b0, phis: [], instrs, terminator: term }
  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  SSACFG::{ entry: b0, blocks, preds, param_values: {}, next_value }
}

///|
test "run_gvn canonicalizes commutative binary expressions" {
  let v0 = SSAValue(0)
  let v1 = SSAValue(1)
  let v2 = SSAValue(2)
  let v3 = SSAValue(3)
  let cfg = make_single_block_gvn_cfg(
    [
      Assign(v0, SSAOp::I32Const(I32(1))),
      Assign(v1, SSAOp::I32Const(I32(2))),
      Assign(v2, SSAOp::Binary(BinaryOp::i32_add(), v0, v1)),
      Assign(v3, SSAOp::Binary(BinaryOp::i32_add(), v1, v0)),
    ],
    SSATerminator::Return([v3]),
    4,
  )
  let idom : Map[BlockId, BlockId] = {}
  idom[BlockId(0)] = BlockId(0)
  let optimized = run_gvn(cfg, idom)
  let block = optimized.blocks[BlockId(0)]
  assert_eq(block.instrs.length(), 3)
  match block.terminator {
    Return(vals) => {
      assert_eq(vals.length(), 1)
      assert_eq(vals[0], v2)
    }
    _ => fail("expected return terminator")
  }
}

///|
test "run_gvn invalidates global-get numbering after global-set" {
  let g0 = GlobalIdx::new(0U)
  let v0 = SSAValue(0)
  let v1 = SSAValue(1)
  let v2 = SSAValue(2)
  let cfg = make_single_block_gvn_cfg(
    [
      Assign(v0, SSAOp::I32Const(I32(0))),
      Assign(v1, SSAOp::GlobalGet(g0)),
      Effect(SSAOp::GlobalSet(g0, v0)),
      Assign(v2, SSAOp::GlobalGet(g0)),
    ],
    SSATerminator::Return([v1, v2]),
    3,
  )
  let idom : Map[BlockId, BlockId] = {}
  idom[BlockId(0)] = BlockId(0)
  let optimized = run_gvn(cfg, idom)
  let block = optimized.blocks[BlockId(0)]

  let mut global_get_count = 0
  for instr in block.instrs {
    match instr {
      Assign(_, SSAOp::GlobalGet(_)) => global_get_count = global_get_count + 1
      _ => ()
    }
  }
  assert_eq(global_get_count, 2)
  match block.terminator {
    Return(vals) => {
      assert_eq(vals.length(), 2)
      assert_eq(vals[0], v1)
      assert_eq(vals[1], v2)
    }
    _ => fail("expected return terminator")
  }
}
