///|
fn ssa_term_successors(term : SSATerminator) -> Array[BlockId] {
  match term {
    Br(t) => [t]
    BrIf(_, t, f)
    | BrOnNull(_, t, f)
    | BrOnNonNull(_, t, f)
    | BrOnCast(_, _, _, _, t, f)
    | BrOnCastFail(_, _, _, _, t, f) => [t, f]
    BrTable(_, targets, d) => {
      let out = targets.copy()
      out.push(d)
      out
    }
    Return(_)
    | ReturnCall(_, _)
    | ReturnCallIndirect(_, _, _, _)
    | ReturnCallRef(_, _, _)
    | ThrowRef(_)
    | Unreachable => []
  }
}

///|
fn has_critical_edge(cfg : SSACFG) -> Bool {
  for entry in cfg.blocks {
    let (pred, block) = entry
    let succs = ssa_term_successors(block.terminator)
    for succ in succs {
      let succ_preds = cfg.preds.get(succ).unwrap_or([])
      if succs.length() > 1 && succ_preds.length() > 1 {
        return true
      }
    }
    ignore(pred)
  }
  false
}

///|
fn ends_with_local_copy(instrs : Array[TInstr]) -> Bool {
  if instrs.is_empty() {
    return false
  }
  match instrs[instrs.length() - 1].kind {
    TInstrKind::TLocalSet(_, { kind: TInstrKind::TLocalGet(_), .. }) => true
    _ => false
  }
}

///|
test "split_critical_edges rewires br_on_null critical edges" {
  let b0 = BlockId(0)
  let b1 = BlockId(1)
  let b2 = BlockId(2)

  let v_cond = SSAValue(0)
  let v_then = SSAValue(1)
  let v_else = SSAValue(2)
  let v_phi = SSAValue(3)

  let phi_args : Map[BlockId, SSAValue] = {}
  phi_args[b0] = v_then
  phi_args[b2] = v_else

  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [
      Assign(v_then, SSAOp::I32Const(I32(10))),
      Assign(v_cond, SSAOp::RefNull(HeapType::abs(AbsHeapType::extern_()))),
    ],
    terminator: SSATerminator::BrOnNull(v_cond, b1, b2),
  }
  blocks[b1] = SSABlock::{
    id: b1,
    phis: [
      PhiNode::{ local_idx: LocalIdx::new(0), result: v_phi, args: phi_args },
    ],
    instrs: [],
    terminator: SSATerminator::Return([v_phi]),
  }
  blocks[b2] = SSABlock::{
    id: b2,
    phis: [],
    instrs: [Assign(v_else, SSAOp::I32Const(I32(20)))],
    terminator: SSATerminator::Br(b1),
  }

  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  preds[b1] = [b0, b2]
  preds[b2] = [b0]

  let cfg = SSACFG::{
    entry: b0,
    blocks,
    preds,
    param_values: {},
    next_value: 4,
  }
  assert_true(has_critical_edge(cfg))

  let split = cfg.split_critical_edges()
  assert_false(has_critical_edge(split))
}

///|
test "to_cfg inserts phi copies into predecessor blocks" {
  let b0 = BlockId(0)
  let b1 = BlockId(1)
  let b2 = BlockId(2)

  let v0 = SSAValue(0)
  let v1 = SSAValue(1)
  let v2 = SSAValue(2)

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
    phis: [PhiNode::{ local_idx: LocalIdx::new(0), result: v2, args: phi_args }],
    instrs: [],
    terminator: SSATerminator::Return([v2]),
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
  let (_, cfg) = ssa.to_cfg_with_locals(
    [ValType::i32()],
    0,
    infer_ssa_types(ssa, ssa_destruction_type_ctx([ValType::i32()])),
  )

  assert_true(ends_with_local_copy(cfg.blocks[b0].instrs))
  assert_true(ends_with_local_copy(cfg.blocks[b1].instrs))
  match cfg.blocks[b2].terminator {
    Return(values) => {
      assert_eq(values.length(), 1)
      assert_true(values[0].kind is TInstrKind::TLocalGet(_))
    }
    _ => fail("expected return terminator in join block")
  }
}

///|
fn ssa_destruction_type_ctx(local_types : Array[ValType]) -> TypeContext {
  {
    func_types: [],
    global_types: [],
    table_types: [],
    struct_types: [],
    array_types: [],
    tag_types: [],
    local_types,
  }
}
