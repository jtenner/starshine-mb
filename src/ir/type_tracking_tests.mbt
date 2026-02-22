///|
fn empty_type_ctx_with_locals(local_types : Array[ValType]) -> TypeContext {
  TypeContext::{
    func_types: [],
    global_types: [],
    table_types: [],
    struct_types: [],
    array_types: [],
    tag_types: [],
    local_types,
  }
}

///|
test "infer_ssa_types infers ref_as_non_null from nullable input" {
  let b0 = BlockId(0)
  let v0 = SSAValue(0)
  let v1 = SSAValue(1)
  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [Assign(v1, SSAOp::RefAsNonNull(v0))],
    terminator: SSATerminator::Return([v1]),
  }
  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  let params : Map[LocalIdx, SSAValue] = {}
  params[LocalIdx::new(0)] = v0
  let cfg = SSACFG::{
    entry: b0,
    blocks,
    preds,
    param_values: params,
    next_value: 2,
  }
  let ctx = empty_type_ctx_with_locals([
    ValType::ref_null(HeapType::abs(AbsHeapType::extern_())),
  ])
  let types = infer_ssa_types(cfg, ctx)
  let expected = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::extern_())),
  )
  assert_eq(types.get(v1), Some(expected))
}

///|
test "infer_ssa_types select with empty annotation yields unknown type" {
  let b0 = BlockId(0)
  let v0 = SSAValue(0)
  let v1 = SSAValue(1)
  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [Assign(v1, SSAOp::Select(Some([]), v0, v0, v0))],
    terminator: SSATerminator::Return([v1]),
  }
  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  let params : Map[LocalIdx, SSAValue] = {}
  params[LocalIdx::new(0)] = v0
  let cfg = SSACFG::{
    entry: b0,
    blocks,
    preds,
    param_values: params,
    next_value: 2,
  }
  let types = infer_ssa_types(cfg, empty_type_ctx_with_locals([ValType::i32()]))
  assert_eq(types.get(v1), None)
}

///|
test "infer_ssa_types ignores out-of-range local index in param_values" {
  let b0 = BlockId(0)
  let v0 = SSAValue(0)
  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [],
    terminator: SSATerminator::Return([]),
  }
  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  let params : Map[LocalIdx, SSAValue] = {}
  params[LocalIdx::new(3)] = v0
  let cfg = SSACFG::{
    entry: b0,
    blocks,
    preds,
    param_values: params,
    next_value: 1,
  }
  let types = infer_ssa_types(cfg, empty_type_ctx_with_locals([]))
  assert_eq(types.get(v0), None)
}

///|
test "infer_ssa_types infers atomic results across branch-on-ref edges" {
  let b0 = BlockId(0)
  let b1 = BlockId(1)
  let b2 = BlockId(2)
  let memarg = MemArg::new(U32(0), None, U64(0))

  let v_addr = SSAValue(0)
  let v_expected = SSAValue(1)
  let v_timeout = SSAValue(2)
  let v_wait = SSAValue(3)
  let v_ref = SSAValue(4)
  let v_notify = SSAValue(5)
  let v_rmw = SSAValue(6)
  let v_cmp = SSAValue(7)

  let blocks : Map[BlockId, SSABlock] = {}
  blocks[b0] = SSABlock::{
    id: b0,
    phis: [],
    instrs: [
      Assign(v_addr, SSAOp::I32Const(I32(0))),
      Assign(v_expected, SSAOp::I32Const(I32(1))),
      Assign(v_timeout, SSAOp::I64Const(I64(9L))),
      Assign(
        v_wait,
        SSAOp::MemoryAtomicWait64(memarg, v_addr, v_timeout, v_timeout),
      ),
      Assign(v_ref, SSAOp::RefNull(HeapType::abs(AbsHeapType::extern_()))),
    ],
    terminator: SSATerminator::BrOnNull(v_ref, b1, b2),
  }
  blocks[b1] = SSABlock::{
    id: b1,
    phis: [],
    instrs: [
      Assign(v_notify, SSAOp::MemoryAtomicNotify(memarg, v_addr, v_expected)),
    ],
    terminator: SSATerminator::Return([v_notify]),
  }
  blocks[b2] = SSABlock::{
    id: b2,
    phis: [],
    instrs: [
      Assign(
        v_rmw,
        SSAOp::AtomicRmw(AtomicRmwOp::i32_add(), memarg, v_addr, v_expected),
      ),
      Assign(
        v_cmp,
        SSAOp::AtomicCmpxchg(
          AtomicCmpxchgOp::i32(),
          memarg,
          v_addr,
          v_expected,
          v_expected,
        ),
      ),
    ],
    terminator: SSATerminator::Return([v_rmw, v_cmp]),
  }

  let preds : Map[BlockId, Array[BlockId]] = {}
  preds[b0] = []
  preds[b1] = [b0]
  preds[b2] = [b0]

  let cfg = SSACFG::{
    entry: b0,
    blocks,
    preds,
    param_values: {},
    next_value: 8,
  }
  let types = infer_ssa_types(cfg, empty_type_ctx_with_locals([]))

  assert_eq(types.get(v_wait), Some(ValType::i32()))
  assert_eq(types.get(v_notify), Some(ValType::i32()))
  assert_eq(types.get(v_rmw), Some(ValType::i32()))
  assert_eq(types.get(v_cmp), Some(ValType::i32()))
  assert_eq(
    types.get(v_ref),
    Some(ValType::ref_null(HeapType::abs(AbsHeapType::extern_()))),
  )
}
