///|
pub struct SSATypeInfo {
  value_types : Map[SSAValue, ValType]
}

///|
pub struct TypeContext {
  func_types : Array[FuncType]
  global_types : Array[GlobalType]
  table_types : Array[TableType]
  struct_types : Array[Array[FieldType]]
  array_types : Array[FieldType]
  tag_types : Array[TagType]
  local_types : Array[ValType] // For the current function
}

///|
pub fn TypeContext::empty() -> Self {
  {
    func_types: [],
    global_types: [],
    table_types: [],
    struct_types: [],
    array_types: [],
    tag_types: [],
    local_types: [],
  }
}

///|
pub fn infer_ssa_types(cfg : SSACFG, ctx : TypeContext) -> SSATypeInfo {
  let types : Map[SSAValue, ValType] = Map::new()

  // Type parameters
  for entry in cfg.param_values {
    let (local_idx, val) = entry
    types[val] = ctx.local_types[local_idx.0.reinterpret_as_int()]
  }

  // Walk blocks and type each instruction
  for entry in cfg.blocks {
    let (_, block) = entry

    // Type phi nodes (assume first arg type)
    for phi in block.phis {
      let local_idx = phi.local_idx.0.reinterpret_as_int()
      if local_idx < ctx.local_types.length() {
        types[phi.result] = ctx.local_types[local_idx]
      }
    }

    // Type instructions
    for instr in block.instrs {
      if instr is SSAInstr::Assign(result, op) {
        match infer_op_type(op, types, ctx) {
          Some(ty) => types[result] = ty
          None => ()
        }
      }
    }
  }
  SSATypeInfo::{ value_types: types }
}

///|
fn infer_op_type(
  op : SSAOp,
  types : Map[SSAValue, ValType],
  ctx : TypeContext,
) -> ValType? {
  match op {
    SSAOp::Copy(v) => types.get(v)
    SSAOp::I32Const(_) => Some(ValType::i32())
    SSAOp::I64Const(_) => Some(ValType::i64())
    SSAOp::F32Const(_) => Some(ValType::f32())
    SSAOp::F64Const(_) => Some(ValType::f64())
    SSAOp::V128Const(_) => Some(ValType::v128())
    SSAOp::RefNull(ht) => Some(ValType::ref_null(ht))
    SSAOp::RefFunc(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::func())),
        ),
      )
    SSAOp::Unary(op, _) => Some(unary_result_type(op))
    SSAOp::Binary(op, _, _) => Some(binary_result_type(op))
    SSAOp::Select(tys, _, _, _) =>
      match tys {
        None => None
        Some(tys) => Some(tys[0])
      }
    SSAOp::GlobalGet(idx) => {
      let i = idx.0.reinterpret_as_int()
      if i < ctx.global_types.length() {
        Some(ctx.global_types[i].0)
      } else {
        None
      }
    }
    SSAOp::Load(op, _, _) => Some(load_result_type(op))
    SSAOp::MemorySize(_) => Some(ValType::i32())
    SSAOp::MemoryGrow(_, _) => Some(ValType::i32())
    SSAOp::TableSize(_) => Some(ValType::i32())
    SSAOp::TableGet(idx, _) => {
      let i = idx.0.reinterpret_as_int()
      if i < ctx.table_types.length() {
        Some(ValType::ref_type(ctx.table_types[i].0))
      } else {
        None
      }
    }
    SSAOp::TableGrow(_, _, _) => Some(ValType::i32())
    SSAOp::Call(func_idx, _) => {
      let i = func_idx.0.reinterpret_as_int()
      if i < ctx.func_types.length() {
        let ft = ctx.func_types[i]
        if ft.1.length() == 1 {
          Some(ft.1[0])
        } else {
          None // Multi-value not directly supported
        }
      } else {
        None
      }
    }
    SSAOp::RefIsNull(_) | SSAOp::RefEq(_, _) => Some(ValType::i32())
    SSAOp::RefAsNonNull(v) =>
      match types.get(v) {
        Some(ValType::RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    SSAOp::RefI31(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::i31())),
        ),
      )
    SSAOp::I31GetS(_) | SSAOp::I31GetU(_) => Some(ValType::i32())
    SSAOp::RefTest(_, _, _) => Some(ValType::i32())
    SSAOp::RefCast(nullable, ht, _) =>
      Some(ValType::ref_type(RefType::new(nullable, ht)))
    SSAOp::AnyConvertExtern(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::any())),
        ),
      )
    SSAOp::ExternConvertAny(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::extern_())),
        ),
      )
    SSAOp::StructNew(ty, _) | SSAOp::StructNewDefault(ty) =>
      Some(ValType::ref_type(RefType::new(false, HeapType::new(ty))))
    SSAOp::StructGet(ty, field, _)
    | SSAOp::StructGetS(ty, field, _)
    | SSAOp::StructGetU(ty, field, _) => {
      let i = match ty {
        TypeIdx(i) => i.reinterpret_as_int()
        RecIdx(_) => return None
      }
      let f = field.0.reinterpret_as_int()
      if i < ctx.struct_types.length() && f < ctx.struct_types[i].length() {
        Some(ctx.struct_types[i][f].unpack())
      } else {
        None
      }
    }
    SSAOp::ArrayNew(ty, _, _)
    | SSAOp::ArrayNewDefault(ty, _)
    | SSAOp::ArrayNewFixed(ty, _)
    | SSAOp::ArrayNewData(ty, _, _, _)
    | SSAOp::ArrayNewElem(ty, _, _, _) =>
      Some(ValType::ref_type(RefType::new(false, HeapType::new(ty))))
    SSAOp::ArrayGet(ty, _, _)
    | SSAOp::ArrayGetS(ty, _, _)
    | SSAOp::ArrayGetU(ty, _, _) => {
      let i = match ty {
        TypeIdx(i) => i.reinterpret_as_int()
        RecIdx(_) => return None
      }
      if i < ctx.array_types.length() {
        Some(ctx.array_types[i].unpack())
      } else {
        None
      }
    }
    SSAOp::ArrayLen(_) => Some(ValType::i32())
    SSAOp::Splat(_, _) => Some(ValType::v128())
    SSAOp::ExtractLane(op, _, _) => Some(extract_lane_result_type(op))
    SSAOp::ReplaceLane(_, _, _, _) => Some(ValType::v128())
    SSAOp::Shuffle(_, _, _) | SSAOp::Swizzle(_, _) => Some(ValType::v128())
    SSAOp::V128Shift(_, _, _) | SSAOp::V128Ternary(_, _, _, _) =>
      Some(ValType::v128())
    SSAOp::V128LoadLane(_, _, _, _, _) => Some(ValType::v128())

    // Effects - no result type
    SSAOp::GlobalSet(_, _)
    | SSAOp::Store(_, _, _, _)
    | SSAOp::MemoryFill(_, _, _, _)
    | SSAOp::MemoryCopy(_, _, _, _, _)
    | SSAOp::MemoryInit(_, _, _, _, _)
    | SSAOp::DataDrop(_)
    | SSAOp::TableSet(_, _, _)
    | SSAOp::TableFill(_, _, _, _)
    | SSAOp::TableCopy(_, _, _, _, _)
    | SSAOp::TableInit(_, _, _, _, _)
    | SSAOp::ElemDrop(_)
    | SSAOp::StructSet(_, _, _, _)
    | SSAOp::ArraySet(_, _, _, _)
    | SSAOp::ArrayFill(_, _, _, _, _)
    | SSAOp::ArrayCopy(_, _, _, _, _, _, _)
    | SSAOp::ArrayInitData(_, _, _, _, _, _)
    | SSAOp::ArrayInitElem(_, _, _, _, _, _)
    | SSAOp::V128StoreLane(_, _, _, _, _)
    | SSAOp::Throw(_, _) => None
    _ => None
  }
}

///|
fn unary_result_type(op : UnaryOp) -> ValType {
  match op {
    I32ClzOp
    | I32CtzOp
    | I32PopcntOp
    | I32EqzOp
    | I32Extend8SOp
    | I32Extend16SOp
    | I32WrapI64Op
    | I32TruncF32SOp
    | I32TruncF32UOp
    | I32TruncF64SOp
    | I32TruncF64UOp
    | I32TruncSatF32SOp
    | I32TruncSatF32UOp
    | I32TruncSatF64SOp
    | I32TruncSatF64UOp
    | I32ReinterpretF32Op => ValType::i32()
    I64ClzOp
    | I64CtzOp
    | I64PopcntOp
    | I64EqzOp
    | I64Extend8SOp
    | I64Extend16SOp
    | I64Extend32SOp
    | I64ExtendI32SOp
    | I64ExtendI32UOp
    | I64TruncF32SOp
    | I64TruncF32UOp
    | I64TruncF64SOp
    | I64TruncF64UOp
    | I64TruncSatF32SOp
    | I64TruncSatF32UOp
    | I64TruncSatF64SOp
    | I64TruncSatF64UOp
    | I64ReinterpretF64Op => ValType::i64()
    F32AbsOp
    | F32NegOp
    | F32CeilOp
    | F32FloorOp
    | F32TruncOp
    | F32NearestOp
    | F32SqrtOp
    | F32ConvertI32SOp
    | F32ConvertI32UOp
    | F32ConvertI64SOp
    | F32ConvertI64UOp
    | F32DemoteF64Op
    | F32ReinterpretI32Op => ValType::f32()
    F64AbsOp
    | F64NegOp
    | F64CeilOp
    | F64FloorOp
    | F64TruncOp
    | F64NearestOp
    | F64SqrtOp
    | F64ConvertI32SOp
    | F64ConvertI32UOp
    | F64ConvertI64SOp
    | F64ConvertI64UOp
    | F64PromoteF32Op
    | F64ReinterpretI64Op => ValType::f64()
    _ => ValType::i32() // Default fallback
  }
}

///|
fn binary_result_type(op : BinaryOp) -> ValType {
  match op {
    I32AddOp
    | I32SubOp
    | I32MulOp
    | I32DivSOp
    | I32DivUOp
    | I32RemSOp
    | I32RemUOp
    | I32AndOp
    | I32OrOp
    | I32XorOp
    | I32ShlOp
    | I32ShrSOp
    | I32ShrUOp
    | I32RotlOp
    | I32RotrOp
    | I32EqOp
    | I32NeOp
    | I32LtSOp
    | I32LtUOp
    | I32GtSOp
    | I32GtUOp
    | I32LeSOp
    | I32LeUOp
    | I32GeSOp
    | I32GeUOp
    | I64EqOp
    | I64NeOp
    | I64LtSOp
    | I64LtUOp
    | I64GtSOp
    | I64GtUOp
    | I64LeSOp
    | I64LeUOp
    | I64GeSOp
    | I64GeUOp
    | F32EqOp
    | F32NeOp
    | F32LtOp
    | F32GtOp
    | F32LeOp
    | F32GeOp
    | F64EqOp
    | F64NeOp
    | F64LtOp
    | F64GtOp
    | F64LeOp
    | F64GeOp => ValType::i32()
    I64AddOp
    | I64SubOp
    | I64MulOp
    | I64DivSOp
    | I64DivUOp
    | I64RemSOp
    | I64RemUOp
    | I64AndOp
    | I64OrOp
    | I64XorOp
    | I64ShlOp
    | I64ShrSOp
    | I64ShrUOp
    | I64RotlOp
    | I64RotrOp => ValType::i64()
    F32AddOp
    | F32SubOp
    | F32MulOp
    | F32DivOp
    | F32MinOp
    | F32MaxOp
    | F32CopysignOp => ValType::f32()
    F64AddOp
    | F64SubOp
    | F64MulOp
    | F64DivOp
    | F64MinOp
    | F64MaxOp
    | F64CopysignOp => ValType::f64()
    _ => ValType::i32() // Default fallback
  }
}

///|
fn load_result_type(op : LoadOp) -> ValType {
  match op {
    I32LoadOp | I32Load8SOp | I32Load8UOp | I32Load16SOp | I32Load16UOp =>
      ValType::i32()
    I64LoadOp
    | I64Load8SOp
    | I64Load8UOp
    | I64Load16SOp
    | I64Load16UOp
    | I64Load32SOp
    | I64Load32UOp => ValType::i64()
    F32LoadOp => ValType::f32()
    F64LoadOp => ValType::f64()
    V128LoadOp
    | V128Load8x8SOp
    | V128Load8x8UOp
    | V128Load16x4SOp
    | V128Load16x4UOp
    | V128Load32ZeroOp
    | V128Load64SplatOp
    | V128Load32SplatOp
    | V128Load16SplatOp
    | V128Load8SplatOp
    | V128Load32x2UOp
    | V128Load32x2SOp
    | V128Load64ZeroOp => ValType::v128()
  }
}

///|
fn extract_lane_result_type(op : ExtractLaneOp) -> ValType {
  match op {
    ExtractLaneOp::I8x16ExtractLaneSOp
    | ExtractLaneOp::I8x16ExtractLaneUOp
    | ExtractLaneOp::I16x8ExtractLaneSOp
    | ExtractLaneOp::I16x8ExtractLaneUOp
    | ExtractLaneOp::I32x4ExtractLaneOp => ValType::i32()
    ExtractLaneOp::I64x2ExtractLaneOp => ValType::i64()
    ExtractLaneOp::F32x4ExtractLaneOp => ValType::f32()
    ExtractLaneOp::F64x2ExtractLaneOp => ValType::f64()
  }
}

///|
pub fn SSATypeInfo::get(self : SSATypeInfo, val : SSAValue) -> ValType? {
  self.value_types.get(val)
}
