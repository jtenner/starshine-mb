///|
// Frozen boxed-tuple reference; only the private return representation differs.
fn lift_shape_reference_direct(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
) -> (HotOp, TypeId, Int, Int) {
  let ty = hot_lift_impl_result_type(func, result_types)
  match instr {
    Instruction::LocalGet(LocalIdx(raw))
    | Instruction::LocalSet(LocalIdx(raw))
    | Instruction::LocalTee(LocalIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::GlobalGet(GlobalIdx(raw))
    | Instruction::GlobalSet(GlobalIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::TableGet(TableIdx(raw))
    | Instruction::TableSet(TableIdx(raw))
    | Instruction::TableSize(TableIdx(raw))
    | Instruction::TableGrow(TableIdx(raw))
    | Instruction::TableFill(TableIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::TableCopy(TableIdx(dst), TableIdx(src)) =>
      (op, ty, dst.reinterpret_as_int(), src.reinterpret_as_int())
    Instruction::TableInit(ElemIdx(elem), TableIdx(table)) =>
      (op, ty, elem.reinterpret_as_int(), table.reinterpret_as_int())
    Instruction::ElemDrop(ElemIdx(raw)) => (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::MemorySize(MemIdx(raw))
    | Instruction::MemoryGrow(MemIdx(raw))
    | Instruction::MemoryFill(MemIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::MemoryCopy(MemIdx(dst), MemIdx(src)) =>
      (op, ty, dst.reinterpret_as_int(), src.reinterpret_as_int())
    Instruction::MemoryInit(DataIdx(data), MemIdx(mem)) =>
      (op, ty, data.reinterpret_as_int(), mem.reinterpret_as_int())
    Instruction::DataDrop(DataIdx(raw)) => (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::Call(FuncIdx(raw)) | Instruction::ReturnCall(FuncIdx(raw)) =>
      (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::CallIndirect(type_idx, table_idx)
    | Instruction::ReturnCallIndirect(type_idx, table_idx) => {
      let sig_id = hot_alloc_call_sig(
        func,
        HotCallSig::new(type_idx, table_idx=Some(table_idx)),
      )
      (op, ty, sig_id, 0)
    }
    Instruction::CallRef(type_idx) | Instruction::ReturnCallRef(type_idx) => {
      let sig_id = hot_alloc_call_sig(func, HotCallSig::new(type_idx))
      (op, ty, sig_id, 0)
    }
    Instruction::I32Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::i32_const(v))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::I64Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::i64_const(v))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::F32Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::f32_const(v))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::F64Const(v) => {
      let const_id = hot_alloc_const(func, HotConstPayload::f64_const(v))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::RefNull(rt) => {
      let const_id = hot_alloc_const(func, HotConstPayload::ref_null_const(rt))
      (HotOp::RefNull, ty, const_id, 0)
    }
    Instruction::StringConst(bytes) => {
      let const_id = hot_alloc_const(func, HotConstPayload::string_const(bytes))
      (HotOp::Const, ty, const_id, 0)
    }
    Instruction::RefFunc(FuncIdx(raw)) => (op, ty, raw.reinterpret_as_int(), 0)
    Instruction::Throw(TagIdx(raw)) => (op, ty, raw.reinterpret_as_int(), 0)
    _ => (op, ty, 0, 0)
  }
}

///|
// Frozen boxed-tuple reference; only the private return representation differs.
fn lift_shape_reference_exact(
  func : HotFunc,
  op : HotOp,
  instr : Instruction,
  result_types : Array[ValType],
) -> (HotOp, TypeId, Int, Int) {
  let ty = hot_lift_impl_result_type(func, result_types)
  let payload_id = hot_alloc_instr_payload(func, HotInstrPayload::new(instr))
  match instr {
    Instruction::I32Load(memarg)
    | Instruction::I64Load(memarg)
    | Instruction::F32Load(memarg)
    | Instruction::F64Load(memarg)
    | Instruction::I32Load8S(memarg)
    | Instruction::I32Load8U(memarg)
    | Instruction::I32Load16S(memarg)
    | Instruction::I32Load16U(memarg)
    | Instruction::I64Load8S(memarg)
    | Instruction::I64Load8U(memarg)
    | Instruction::I64Load16S(memarg)
    | Instruction::I64Load16U(memarg)
    | Instruction::I64Load32S(memarg)
    | Instruction::I64Load32U(memarg)
    | Instruction::I32Store(memarg)
    | Instruction::I64Store(memarg)
    | Instruction::F32Store(memarg)
    | Instruction::F64Store(memarg)
    | Instruction::I32Store8(memarg)
    | Instruction::I32Store16(memarg)
    | Instruction::I64Store8(memarg)
    | Instruction::I64Store16(memarg)
    | Instruction::I64Store32(memarg) => {
      let memarg_id = hot_alloc_memarg(func, HotMemArg::new(memarg))
      (op, ty, memarg_id, payload_id)
    }
    Instruction::AtomicFence(_)
    | Instruction::WaitqueueNotify
    | Instruction::StructWait(_, _)
    | Instruction::StructAtomicSet(_, _, _)
    | Instruction::ArrayAtomicSet(_, _)
    | Instruction::StructAtomicGet(_, _, _)
    | Instruction::StructAtomicGetS(_, _, _)
    | Instruction::StructAtomicGetU(_, _, _)
    | Instruction::StructAtomicRmw(_, _, _, _)
    | Instruction::StructAtomicCmpxchg(_, _, _)
    | Instruction::ArrayAtomicGet(_, _)
    | Instruction::ArrayAtomicGetS(_, _)
    | Instruction::ArrayAtomicGetU(_, _)
    | Instruction::ArrayAtomicRmw(_, _, _)
    | Instruction::ArrayAtomicCmpxchg(_, _) => (op, ty, 0, payload_id)
    Instruction::MemoryAtomicNotify(memarg)
    | Instruction::MemoryAtomicWait32(memarg)
    | Instruction::MemoryAtomicWait64(memarg)
    | Instruction::I32AtomicLoad(_, memarg)
    | Instruction::I64AtomicLoad(_, memarg)
    | Instruction::I32AtomicLoad8U(_, memarg)
    | Instruction::I32AtomicLoad16U(_, memarg)
    | Instruction::I64AtomicLoad8U(_, memarg)
    | Instruction::I64AtomicLoad16U(_, memarg)
    | Instruction::I64AtomicLoad32U(_, memarg)
    | Instruction::I32AtomicStore(_, memarg)
    | Instruction::I64AtomicStore(_, memarg)
    | Instruction::I32AtomicStore8(_, memarg)
    | Instruction::I32AtomicStore16(_, memarg)
    | Instruction::I64AtomicStore8(_, memarg)
    | Instruction::I64AtomicStore16(_, memarg)
    | Instruction::I64AtomicStore32(_, memarg)
    | Instruction::AtomicRmw(_, _, memarg)
    | Instruction::AtomicCmpxchg(_, _, memarg) => {
      let memarg_id = hot_alloc_memarg(func, HotMemArg::new(memarg))
      (op, ty, memarg_id, payload_id)
    }
    Instruction::RefTest(_, _, _)
    | Instruction::RefCast(_, _, _)
    | Instruction::RefTestDesc(_, _)
    | Instruction::RefCastDescEq(_, _, _)
    | Instruction::BrOnCast(_, _, _, _)
    | Instruction::BrOnCastFail(_, _, _, _)
    | Instruction::BrOnCastDescEq(_, _, _)
    | Instruction::BrOnCastDescEqFail(_, _, _) => (op, ty, 0, payload_id)
    _ => (op, ty, payload_id, 0)
  }
}

///|
fn lift_shape_value_bench(
  it : @bench.T,
  kind : Int,
  before : Bool,
) -> Unit raise {
  let func = HotFunc::new()
  let width = if kind == 0 { 0 } else { 128 }
  let results = [@lib.ValType::i32()]
  ignore(hot_lift_impl_result_type(func, results))
  let instructions : Array[Instruction] = []
  for i in 0..<width {
    instructions.push(
      match kind {
        1 => Instruction::local_get(@lib.LocalIdx::new(i.to_uint()))
        2 => Instruction::i32_const(@lib.I32(i))
        3 => Instruction::call_ref(@lib.TypeIdx::new(i.to_uint()))
        4 => Instruction::i32_load(@lib.MemArg::new(2U, None, i.to_uint64()))
        _ => Instruction::i32x4_abs()
      },
    )
  }
  let op = match kind {
    1 => HotOp::LocalGet
    2 => HotOp::Const
    3 => HotOp::CallRef
    4 => HotOp::Load
    _ => HotOp::Simd
  }
  let reference = HotFunc::new()
  for instruction in instructions {
    let (expected_op, expected_ty, expected_a, expected_b) = if kind >= 4 {
      lift_shape_reference_exact(reference, op, instruction, results)
    } else {
      lift_shape_reference_direct(reference, op, instruction, results)
    }
    let shape = if kind >= 4 {
      hot_lift_impl_exact_node_shape(func, op, instruction, results)
    } else {
      hot_lift_impl_direct_node_shape(func, op, instruction, results)
    }
    assert_eq(shape.op, expected_op)
    assert_eq(shape.ty, expected_ty)
    assert_eq(shape.imm0, expected_a)
    assert_eq(shape.imm1, expected_b)
  }
  assert_eq(func.consts, reference.consts)
  assert_eq(func.call_sigs, reference.call_sigs)
  assert_eq(func.memargs, reference.memargs)
  assert_eq(func.instr_payloads, reference.instr_payloads)
  func.consts.clear()
  func.call_sigs.clear()
  func.memargs.clear()
  func.instr_payloads.clear()
  it.bench(fn() {
    let mut total = 0
    for instruction in instructions {
      if before {
        let (_, ty, a, b) = if kind >= 4 {
          lift_shape_reference_exact(func, op, instruction, results)
        } else {
          lift_shape_reference_direct(func, op, instruction, results)
        }
        total += ty + a + b
      } else {
        let shape = if kind >= 4 {
          hot_lift_impl_exact_node_shape(func, op, instruction, results)
        } else {
          hot_lift_impl_direct_node_shape(func, op, instruction, results)
        }
        total += shape.ty + shape.imm0 + shape.imm1
      }
    }
    it.keep(total)
    // Payload allocation is required in both paths; bound retained storage.
    func.consts.clear()
    func.call_sigs.clear()
    func.memargs.clear()
    func.instr_payloads.clear()
  })
}

///|
test "bench lift shape empty before" (it : @bench.T) {
  lift_shape_value_bench(it, 0, true)
}

///|
test "bench lift shape empty current" (it : @bench.T) {
  lift_shape_value_bench(it, 0, false)
}

///|
test "bench lift shape indices before" (it : @bench.T) {
  lift_shape_value_bench(it, 1, true)
}

///|
test "bench lift shape indices current" (it : @bench.T) {
  lift_shape_value_bench(it, 1, false)
}

///|
test "bench lift shape constants before" (it : @bench.T) {
  lift_shape_value_bench(it, 2, true)
}

///|
test "bench lift shape constants current" (it : @bench.T) {
  lift_shape_value_bench(it, 2, false)
}

///|
test "bench lift shape call-signatures before" (it : @bench.T) {
  lift_shape_value_bench(it, 3, true)
}

///|
test "bench lift shape call-signatures current" (it : @bench.T) {
  lift_shape_value_bench(it, 3, false)
}

///|
test "bench lift shape memory before" (it : @bench.T) {
  lift_shape_value_bench(it, 4, true)
}

///|
test "bench lift shape memory current" (it : @bench.T) {
  lift_shape_value_bench(it, 4, false)
}

///|
test "bench lift shape exact-opcode before" (it : @bench.T) {
  lift_shape_value_bench(it, 5, true)
}

///|
test "bench lift shape exact-opcode current" (it : @bench.T) {
  lift_shape_value_bench(it, 5, false)
}
