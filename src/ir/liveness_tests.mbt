///|
test "compute_liveness tracks phi args on matching predecessor edges" {
  let b0 = BlockId(0)
  let b1 = BlockId(1)
  let b2 = BlockId(2)

  let v0 = SSAValue(0)
  let v1 = SSAValue(1)
  let v_phi = SSAValue(2)

  let phi_args : Map[BlockId, SSAValue] = {}
  phi_args[b0] = v0
  phi_args[b1] = v1

  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [Assign(v0, SSAOp::I32Const(I32(1)))],
    terminator: SSATerminator::Br(b2),
  }
  blocks[b1] = SSABlock::{
    id: b1,
    phis: [],
    instrs: [Assign(v1, SSAOp::I32Const(I32(2)))],
    terminator: SSATerminator::Br(b2),
  }
  blocks[b2] = SSABlock::{
    id: b2,
    phis: [
      PhiNode::{ local_idx: LocalIdx::new(0), result: v_phi, args: phi_args },
    ],
    instrs: [],
    terminator: SSATerminator::Return([v_phi]),
  }

  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  preds[b1] = []
  preds[b2] = [b0, b1]

  let ssa = SSACFG::{
    entry: b0,
    blocks,
    preds,
    param_values: {},
    next_value: 3,
  }
  let liveness = ssa.compute_liveness()
  assert_true(liveness.is_live_out(b0, v0))
  assert_false(liveness.is_live_out(b0, v1))
  assert_true(liveness.is_live_out(b1, v1))
  assert_false(liveness.is_live_out(b1, v0))
  assert_false(liveness.is_live_in(b2, v_phi))
}

///|
test "compute_liveness does not mark same-block definitions live-in" {
  let b0 = BlockId(0)
  let v0 = SSAValue(0)
  let v1 = SSAValue(1)

  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [Assign(v0, SSAOp::I32Const(I32(42))), Assign(v1, SSAOp::Copy(v0))],
    terminator: SSATerminator::Return([v1]),
  }

  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []

  let ssa = SSACFG::{
    entry: b0,
    blocks,
    preds,
    param_values: {},
    next_value: 2,
  }
  let liveness = ssa.compute_liveness()
  assert_eq(liveness.get_live_in(b0).length(), 0)
  assert_eq(liveness.get_live_out(b0).length(), 0)
}
