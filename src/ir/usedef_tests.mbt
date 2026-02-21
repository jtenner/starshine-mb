///|
fn has_instr_use(uses : Array[SSAUse], block_id : BlockId, idx : Int) -> Bool {
  for use_ in uses {
    if use_ is InInstr(b, i) && b == block_id && i == idx {
      return true
    }
  }
  false
}

///|
fn has_phi_use(
  uses : Array[SSAUse],
  block_id : BlockId,
  local_idx : LocalIdx,
  pred_id : BlockId,
) -> Bool {
  for use_ in uses {
    if use_ is InPhi(b, l, p) && b == block_id && l == local_idx && p == pred_id {
      return true
    }
  }
  false
}

///|
fn has_terminator_use(uses : Array[SSAUse], block_id : BlockId) -> Bool {
  for use_ in uses {
    if use_ is InTerminator(b) && b == block_id {
      return true
    }
  }
  false
}

///|
test "build_use_def records param phi instr and terminator use sites" {
  let b0 = BlockId(0)
  let b1 = BlockId(1)
  let l0 = LocalIdx::new(0)
  let v0 = SSAValue(0) // param
  let v1 = SSAValue(1) // copy of param in b0
  let v2 = SSAValue(2) // phi result in b1
  let v3 = SSAValue(3) // binary result in b1

  let phi_args : Map[BlockId, SSAValue] = {}
  phi_args[b0] = v1

  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [Assign(v1, SSAOp::Copy(v0))],
    terminator: SSATerminator::Br(b1),
  }
  blocks[b1] = SSABlock::{
    id: b1,
    phis: [PhiNode::{ local_idx: l0, result: v2, args: phi_args }],
    instrs: [Assign(v3, SSAOp::Binary(BinaryOp::i32_add(), v2, v2))],
    terminator: SSATerminator::Return([v3]),
  }

  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  preds[b1] = [b0]

  let params : Map[LocalIdx, SSAValue] = {}
  params[l0] = v0

  let ssa = SSACFG::{
    entry: b0,
    blocks,
    preds,
    param_values: params,
    next_value: 4,
  }
  let use_def = ssa.build_use_def()

  match use_def.get_def(v0) {
    Some((def_block, SSADef::Param(local_idx))) => {
      assert_eq(def_block, b0)
      assert_eq(local_idx, l0)
    }
    _ => fail("expected param definition for v0")
  }
  match use_def.get_def(v2) {
    Some((def_block, SSADef::Phi(local_idx))) => {
      assert_eq(def_block, b1)
      assert_eq(local_idx, l0)
    }
    _ => fail("expected phi definition for v2")
  }
  match use_def.get_def(v3) {
    Some((def_block, SSADef::Instr(0))) => assert_eq(def_block, b1)
    _ => fail("expected instruction definition for v3")
  }

  assert_true(has_phi_use(use_def.get_uses(v1), b1, l0, b0))
  assert_true(has_instr_use(use_def.get_uses(v2), b1, 0))
  assert_true(has_terminator_use(use_def.get_uses(v3), b1))
}

///|
test "build_use_def marks unreferenced assigned values as dead" {
  let b0 = BlockId(0)
  let v0 = SSAValue(0)
  let v1 = SSAValue(1)
  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [
      Assign(v0, SSAOp::I32Const(I32(1))),
      Assign(v1, SSAOp::I32Const(I32(2))),
    ],
    terminator: SSATerminator::Return([v0]),
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
  let use_def = ssa.build_use_def()
  assert_false(use_def.is_dead(v0))
  assert_true(use_def.is_dead(v1))
}
