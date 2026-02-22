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

///|
test "compute_liveness handles branch-on-ref with atomic value flow" {
  let b0 = BlockId(0)
  let b1 = BlockId(1)
  let b2 = BlockId(2)
  let b3 = BlockId(3)

  let v_addr = SSAValue(0)
  let v_expected = SSAValue(1)
  let v_timeout = SSAValue(2)
  let v_wait = SSAValue(3)
  let v_ref = SSAValue(4)
  let v_then = SSAValue(5)
  let v_else = SSAValue(6)
  let v_phi = SSAValue(7)
  let memarg = MemArg::new(U32(0), None, U64(0))

  let phi_args : Map[BlockId, SSAValue] = {}
  phi_args[b1] = v_then
  phi_args[b2] = v_else

  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [
      Assign(v_addr, SSAOp::I32Const(I32(0))),
      Assign(v_expected, SSAOp::I32Const(I32(1))),
      Assign(v_timeout, SSAOp::I64Const(I64(2L))),
      Assign(
        v_wait,
        SSAOp::MemoryAtomicWait32(memarg, v_addr, v_expected, v_timeout),
      ),
      Assign(v_ref, SSAOp::RefNull(HeapType::abs(AbsHeapType::extern_()))),
    ],
    terminator: SSATerminator::BrOnNonNull(v_ref, b1, b2),
  }
  blocks[b1] = SSABlock::{
    id: b1,
    phis: [],
    instrs: [
      Assign(
        v_then,
        SSAOp::AtomicRmw(AtomicRmwOp::i32_add(), memarg, v_addr, v_wait),
      ),
    ],
    terminator: SSATerminator::Br(b3),
  }
  blocks[b2] = SSABlock::{
    id: b2,
    phis: [],
    instrs: [
      Assign(
        v_else,
        SSAOp::AtomicCmpxchg(
          AtomicCmpxchgOp::i32(),
          memarg,
          v_addr,
          v_expected,
          v_wait,
        ),
      ),
    ],
    terminator: SSATerminator::Br(b3),
  }
  blocks[b3] = SSABlock::{
    id: b3,
    phis: [
      PhiNode::{ local_idx: LocalIdx::new(0U), result: v_phi, args: phi_args },
    ],
    instrs: [],
    terminator: SSATerminator::Return([v_phi]),
  }

  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  preds[b1] = [b0]
  preds[b2] = [b0]
  preds[b3] = [b1, b2]

  let ssa = SSACFG::{
    entry: b0,
    blocks,
    preds,
    param_values: {},
    next_value: 8,
  }
  let liveness = ssa.compute_liveness()
  assert_true(liveness.is_live_out(b0, v_addr))
  assert_true(liveness.is_live_out(b0, v_wait))
  assert_false(liveness.is_live_out(b0, v_ref))
  assert_true(liveness.is_live_out(b1, v_then))
  assert_true(liveness.is_live_out(b2, v_else))
  assert_false(liveness.is_live_in(b3, v_phi))
}
