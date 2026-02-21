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
