///|
/// Convert tree-based TypedInstr bodies back to flat Expr.
pub fn typed_instrs_to_expr(body : Array[TypedInstr]) -> Expr {
  let instrs : Array[Instruction] = []
  for value in body {
    typed_instr_to_instr(value, instrs)
  }
  Expr(instrs)
}

// ============================================================================
// TypedInstr tree -> Expr helpers
// ============================================================================

///|
fn typed_instr_to_instr(
  typed_instr : TypedInstr,
  instrs : Array[Instruction],
) -> Unit {
  match typed_instr.kind {
    // === Constants ===
    TypedInstrKind::TI32Const(v) => instrs.push(I32Const(v))
    TypedInstrKind::TI64Const(v) => instrs.push(I64Const(v))
    TypedInstrKind::TF32Const(v) => instrs.push(F32Const(v))
    TypedInstrKind::TF64Const(v) => instrs.push(F64Const(v))
    TypedInstrKind::TRefNull(rt) => instrs.push(RefNull(rt))
    TypedInstrKind::TRefFunc(idx) => instrs.push(RefFunc(idx))
    TypedInstrKind::TStringConst(bytes) => instrs.push(StringConst(bytes))
    TypedInstrKind::TV128Const(
      b0,
      b1,
      b2,
      b3,
      b4,
      b5,
      b6,
      b7,
      b8,
      b9,
      b10,
      b11,
      b12,
      b13,
      b14,
      b15
    ) =>
      instrs.push(
        V128Const(
          b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
        ),
      )

    // === Nullary ===
    TypedInstrKind::TUnreachable => instrs.push(Unreachable)
    TypedInstrKind::TNop => instrs.push(Nop)
    TypedInstrKind::TLocalGet(idx) => instrs.push(LocalGet(idx))
    TypedInstrKind::TGlobalGet(idx) => instrs.push(GlobalGet(idx))
    TypedInstrKind::TMemorySize(idx) => instrs.push(MemorySize(idx))
    TypedInstrKind::TTableSize(idx) => instrs.push(TableSize(idx))

    // === Unary ===
    TypedInstrKind::TUnary(op, child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(unary_op_to_instr(op))
    }
    TypedInstrKind::TDrop(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(Drop)
    }
    TypedInstrKind::TLocalSet(idx, child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(LocalSet(idx))
    }
    TypedInstrKind::TLocalTee(idx, child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(LocalTee(idx))
    }
    TypedInstrKind::TGlobalSet(idx, child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(GlobalSet(idx))
    }
    TypedInstrKind::TRefIsNull(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(RefIsNull)
    }
    TypedInstrKind::TRefAsNonNull(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(RefAsNonNull)
    }
    TypedInstrKind::TI31GetS(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(I31GetS)
    }
    TypedInstrKind::TI31GetU(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(I31GetU)
    }
    TypedInstrKind::TRefI31(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(RefI31)
    }
    TypedInstrKind::TArrayLen(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(ArrayLen)
    }
    TypedInstrKind::TAnyConvertExtern(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(AnyConvertExtern)
    }
    TypedInstrKind::TExternConvertAny(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(ExternConvertAny)
    }
    TypedInstrKind::TThrowRef(child) => {
      typed_instr_to_instr(child, instrs)
      instrs.push(ThrowRef)
    }

    // === Binary ===
    TypedInstrKind::TBinary(op, lhs, rhs) => {
      typed_instr_to_instr(lhs, instrs)
      typed_instr_to_instr(rhs, instrs)
      instrs.push(binary_op_to_instr(op))
    }
    TypedInstrKind::TRefEq(lhs, rhs) => {
      typed_instr_to_instr(lhs, instrs)
      typed_instr_to_instr(rhs, instrs)
      instrs.push(RefEq)
    }
    TypedInstrKind::TStore(op, memarg, addr, value) => {
      typed_instr_to_instr(addr, instrs)
      typed_instr_to_instr(value, instrs)
      instrs.push(store_op_to_instr(op, memarg))
    }

    // === Load ===
    TypedInstrKind::TLoad(op, memarg, addr) => {
      typed_instr_to_instr(addr, instrs)
      instrs.push(load_op_to_instr(op, memarg))
    }

    // === Memory operations ===
    TypedInstrKind::TMemoryGrow(idx, pages) => {
      typed_instr_to_instr(pages, instrs)
      instrs.push(MemoryGrow(idx))
    }
    TypedInstrKind::TMemoryFill(idx, dest, val, len) => {
      typed_instr_to_instr(dest, instrs)
      typed_instr_to_instr(val, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(MemoryFill(idx))
    }
    TypedInstrKind::TMemoryCopy(dst, src, dst_addr, src_addr, len) => {
      typed_instr_to_instr(dst_addr, instrs)
      typed_instr_to_instr(src_addr, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(MemoryCopy(dst, src))
    }
    TypedInstrKind::TMemoryInit(data_idx, mem_idx, dst, src, len) => {
      typed_instr_to_instr(dst, instrs)
      typed_instr_to_instr(src, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(MemoryInit(data_idx, mem_idx))
    }
    TypedInstrKind::TDataDrop(idx) => instrs.push(DataDrop(idx))
    TypedInstrKind::TMemoryAtomicNotify(memarg, addr, count) => {
      typed_instr_to_instr(addr, instrs)
      typed_instr_to_instr(count, instrs)
      instrs.push(MemoryAtomicNotify(memarg))
    }
    TypedInstrKind::TMemoryAtomicWait32(memarg, addr, expected, timeout) => {
      typed_instr_to_instr(addr, instrs)
      typed_instr_to_instr(expected, instrs)
      typed_instr_to_instr(timeout, instrs)
      instrs.push(MemoryAtomicWait32(memarg))
    }
    TypedInstrKind::TMemoryAtomicWait64(memarg, addr, expected, timeout) => {
      typed_instr_to_instr(addr, instrs)
      typed_instr_to_instr(expected, instrs)
      typed_instr_to_instr(timeout, instrs)
      instrs.push(MemoryAtomicWait64(memarg))
    }
    TypedInstrKind::TAtomicFence => instrs.push(AtomicFence)
    TypedInstrKind::TAtomicRmw(op, memarg, addr, value) => {
      typed_instr_to_instr(addr, instrs)
      typed_instr_to_instr(value, instrs)
      instrs.push(AtomicRmw(op, memarg))
    }
    TypedInstrKind::TAtomicCmpxchg(op, memarg, addr, expected, replacement) => {
      typed_instr_to_instr(addr, instrs)
      typed_instr_to_instr(expected, instrs)
      typed_instr_to_instr(replacement, instrs)
      instrs.push(AtomicCmpxchg(op, memarg))
    }

    // === Table operations ===
    TypedInstrKind::TTableGet(idx, i) => {
      typed_instr_to_instr(i, instrs)
      instrs.push(TableGet(idx))
    }
    TypedInstrKind::TTableSet(idx, i, val) => {
      typed_instr_to_instr(i, instrs)
      typed_instr_to_instr(val, instrs)
      instrs.push(TableSet(idx))
    }
    TypedInstrKind::TTableGrow(idx, val, n) => {
      typed_instr_to_instr(val, instrs)
      typed_instr_to_instr(n, instrs)
      instrs.push(TableGrow(idx))
    }
    TypedInstrKind::TTableFill(idx, i, val, n) => {
      typed_instr_to_instr(i, instrs)
      typed_instr_to_instr(val, instrs)
      typed_instr_to_instr(n, instrs)
      instrs.push(TableFill(idx))
    }
    TypedInstrKind::TTableCopy(dst, src, d, s, n) => {
      typed_instr_to_instr(d, instrs)
      typed_instr_to_instr(s, instrs)
      typed_instr_to_instr(n, instrs)
      instrs.push(TableCopy(dst, src))
    }
    TypedInstrKind::TTableInit(elem_idx, table_idx, d, s, n) => {
      typed_instr_to_instr(d, instrs)
      typed_instr_to_instr(s, instrs)
      typed_instr_to_instr(n, instrs)
      instrs.push(TableInit(elem_idx, table_idx))
    }
    TypedInstrKind::TElemDrop(idx) => instrs.push(ElemDrop(idx))

    // === Calls ===
    TypedInstrKind::TCall(func_idx, args) => {
      for arg in args {
        typed_instr_to_instr(arg, instrs)
      }
      instrs.push(Call(func_idx))
    }
    TypedInstrKind::TCallIndirect(type_idx, table_idx, args, idx) => {
      for arg in args {
        typed_instr_to_instr(arg, instrs)
      }
      typed_instr_to_instr(idx, instrs)
      instrs.push(CallIndirect(type_idx, table_idx))
    }
    TypedInstrKind::TCallRef(type_idx, args, ref_) => {
      for arg in args {
        typed_instr_to_instr(arg, instrs)
      }
      typed_instr_to_instr(ref_, instrs)
      instrs.push(CallRef(type_idx))
    }
    TypedInstrKind::TReturnCall(func_idx, args) => {
      for arg in args {
        typed_instr_to_instr(arg, instrs)
      }
      instrs.push(ReturnCall(func_idx))
    }
    TypedInstrKind::TReturnCallIndirect(type_idx, table_idx, args, idx) => {
      for arg in args {
        typed_instr_to_instr(arg, instrs)
      }
      typed_instr_to_instr(idx, instrs)
      instrs.push(ReturnCallIndirect(type_idx, table_idx))
    }
    TypedInstrKind::TReturnCallRef(type_idx, args, ref_) => {
      for arg in args {
        typed_instr_to_instr(arg, instrs)
      }
      typed_instr_to_instr(ref_, instrs)
      instrs.push(ReturnCallRef(type_idx))
    }

    // === Control flow ===
    TypedInstrKind::TBlock(bt, body) => {
      let body_instrs : Array[Instruction] = []
      for value in body {
        typed_instr_to_instr(value, body_instrs)
      }
      instrs.push(Block(bt, Expr(body_instrs)))
    }
    TypedInstrKind::TLoop(bt, body) => {
      let body_instrs : Array[Instruction] = []
      for value in body {
        typed_instr_to_instr(value, body_instrs)
      }
      instrs.push(Loop(bt, Expr(body_instrs)))
    }
    TypedInstrKind::TIf(bt, cond, then_branch, else_branch) => {
      typed_instr_to_instr(cond, instrs)
      let then_instrs : Array[Instruction] = []
      for value in then_branch {
        typed_instr_to_instr(value, then_instrs)
      }
      let else_instrs : Array[Instruction]? = match else_branch {
        Some(else_body) => {
          let els : Array[Instruction] = []
          for value in else_body {
            typed_instr_to_instr(value, els)
          }
          Some(els)
        }
        None => None
      }
      instrs.push(If(bt, then_instrs, else_instrs))
    }
    TypedInstrKind::TTryTable(bt, catches, body) => {
      let body_instrs : Array[Instruction] = []
      for value in body {
        typed_instr_to_instr(value, body_instrs)
      }
      instrs.push(TryTable(bt, catches, Expr(body_instrs)))
    }
    TypedInstrKind::TThrow(tag_idx, args) => {
      for arg in args {
        typed_instr_to_instr(arg, instrs)
      }
      instrs.push(Throw(tag_idx))
    }

    // === Branches ===
    TypedInstrKind::TBr(label, values) => {
      for value in values {
        typed_instr_to_instr(value, instrs)
      }
      instrs.push(Br(label))
    }
    TypedInstrKind::TBrIf(label, cond, values) => {
      for value in values {
        typed_instr_to_instr(value, instrs)
      }
      typed_instr_to_instr(cond, instrs)
      instrs.push(BrIf(label))
    }
    TypedInstrKind::TBrTable(labels, default, idx, values) => {
      for value in values {
        typed_instr_to_instr(value, instrs)
      }
      typed_instr_to_instr(idx, instrs)
      instrs.push(BrTable(labels, default))
    }
    TypedInstrKind::TBrOnNull(label, ref_, values) => {
      for value in values {
        typed_instr_to_instr(value, instrs)
      }
      typed_instr_to_instr(ref_, instrs)
      instrs.push(BrOnNull(label))
    }
    TypedInstrKind::TBrOnNonNull(label, ref_, values) => {
      for value in values {
        typed_instr_to_instr(value, instrs)
      }
      typed_instr_to_instr(ref_, instrs)
      instrs.push(BrOnNonNull(label))
    }
    TypedInstrKind::TBrOnCast(label, castop, ht1, ht2, ref_, values) => {
      for value in values {
        typed_instr_to_instr(value, instrs)
      }
      typed_instr_to_instr(ref_, instrs)
      instrs.push(BrOnCast(label, castop, ht1, ht2))
    }
    TypedInstrKind::TBrOnCastFail(label, castop, ht1, ht2, ref_, values) => {
      for value in values {
        typed_instr_to_instr(value, instrs)
      }
      typed_instr_to_instr(ref_, instrs)
      instrs.push(BrOnCastFail(label, castop, ht1, ht2))
    }
    TypedInstrKind::TReturn(values) => {
      for value in values {
        typed_instr_to_instr(value, instrs)
      }
      instrs.push(Return)
    }
    // === Select ===
    TypedInstrKind::TSelect(types, cond, val1, val2) => {
      typed_instr_to_instr(val1, instrs)
      typed_instr_to_instr(val2, instrs)
      typed_instr_to_instr(cond, instrs)
      instrs.push(Select(types))
    }

    // === Strings ===
    TypedInstrKind::TStringNewUtf8Array(array, start, end_) => {
      typed_instr_to_instr(array, instrs)
      typed_instr_to_instr(start, instrs)
      typed_instr_to_instr(end_, instrs)
      instrs.push(StringNewUtf8Array)
    }
    TypedInstrKind::TStringNewWtf16Array(array, start, end_) => {
      typed_instr_to_instr(array, instrs)
      typed_instr_to_instr(start, instrs)
      typed_instr_to_instr(end_, instrs)
      instrs.push(StringNewWtf16Array)
    }
    TypedInstrKind::TStringEncodeUtf8Array(string, array, start) => {
      typed_instr_to_instr(string, instrs)
      typed_instr_to_instr(array, instrs)
      typed_instr_to_instr(start, instrs)
      instrs.push(StringEncodeUtf8Array)
    }
    TypedInstrKind::TStringEncodeWtf16Array(string, array, start) => {
      typed_instr_to_instr(string, instrs)
      typed_instr_to_instr(array, instrs)
      typed_instr_to_instr(start, instrs)
      instrs.push(StringEncodeWtf16Array)
    }
    TypedInstrKind::TStringNewLossyUtf8Array(array, start, end_) => {
      typed_instr_to_instr(array, instrs)
      typed_instr_to_instr(start, instrs)
      typed_instr_to_instr(end_, instrs)
      instrs.push(StringNewLossyUtf8Array)
    }
    TypedInstrKind::TStringNewWtf8Array(array, start, end_) => {
      typed_instr_to_instr(array, instrs)
      typed_instr_to_instr(start, instrs)
      typed_instr_to_instr(end_, instrs)
      instrs.push(StringNewWtf8Array)
    }
    TypedInstrKind::TStringEncodeLossyUtf8Array(string, array, start) => {
      typed_instr_to_instr(string, instrs)
      typed_instr_to_instr(array, instrs)
      typed_instr_to_instr(start, instrs)
      instrs.push(StringEncodeLossyUtf8Array)
    }
    TypedInstrKind::TStringEncodeWtf8Array(string, array, start) => {
      typed_instr_to_instr(string, instrs)
      typed_instr_to_instr(array, instrs)
      typed_instr_to_instr(start, instrs)
      instrs.push(StringEncodeWtf8Array)
    }

    // === GC: Structs ===
    TypedInstrKind::TStructNew(type_idx, fields) => {
      for field in fields {
        typed_instr_to_instr(field, instrs)
      }
      instrs.push(StructNew(type_idx))
    }
    TypedInstrKind::TStructNewDefault(type_idx) =>
      instrs.push(StructNewDefault(type_idx))
    TypedInstrKind::TStructNewDesc(type_idx, fields) => {
      for field in fields {
        typed_instr_to_instr(field, instrs)
      }
      instrs.push(StructNewDesc(type_idx))
    }
    TypedInstrKind::TStructNewDefaultDesc(type_idx, descriptor) => {
      typed_instr_to_instr(descriptor, instrs)
      instrs.push(StructNewDefaultDesc(type_idx))
    }
    TypedInstrKind::TStructGet(type_idx, field_idx, struct_ref) => {
      typed_instr_to_instr(struct_ref, instrs)
      instrs.push(StructGet(type_idx, field_idx))
    }
    TypedInstrKind::TStructGetS(type_idx, field_idx, struct_ref) => {
      typed_instr_to_instr(struct_ref, instrs)
      instrs.push(StructGetS(type_idx, field_idx))
    }
    TypedInstrKind::TStructGetU(type_idx, field_idx, struct_ref) => {
      typed_instr_to_instr(struct_ref, instrs)
      instrs.push(StructGetU(type_idx, field_idx))
    }
    TypedInstrKind::TStructSet(type_idx, field_idx, struct_ref, val) => {
      typed_instr_to_instr(struct_ref, instrs)
      typed_instr_to_instr(val, instrs)
      instrs.push(StructSet(type_idx, field_idx))
    }

    // === GC: Arrays ===
    TypedInstrKind::TArrayNew(type_idx, init, len) => {
      typed_instr_to_instr(init, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(ArrayNew(type_idx))
    }
    TypedInstrKind::TArrayNewDefault(type_idx, len) => {
      typed_instr_to_instr(len, instrs)
      instrs.push(ArrayNewDefault(type_idx))
    }
    TypedInstrKind::TArrayNewFixed(type_idx, elems) => {
      for elem in elems {
        typed_instr_to_instr(elem, instrs)
      }
      instrs.push(
        ArrayNewFixed(type_idx, U32(elems.length().reinterpret_as_uint())),
      )
    }
    TypedInstrKind::TArrayNewData(type_idx, data_idx, offset, len) => {
      typed_instr_to_instr(offset, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(ArrayNewData(type_idx, data_idx))
    }
    TypedInstrKind::TArrayNewElem(type_idx, elem_idx, offset, len) => {
      typed_instr_to_instr(offset, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(ArrayNewElem(type_idx, elem_idx))
    }
    TypedInstrKind::TArrayGet(type_idx, arr, idx) => {
      typed_instr_to_instr(arr, instrs)
      typed_instr_to_instr(idx, instrs)
      instrs.push(ArrayGet(type_idx))
    }
    TypedInstrKind::TArrayGetS(type_idx, arr, idx) => {
      typed_instr_to_instr(arr, instrs)
      typed_instr_to_instr(idx, instrs)
      instrs.push(ArrayGetS(type_idx))
    }
    TypedInstrKind::TArrayGetU(type_idx, arr, idx) => {
      typed_instr_to_instr(arr, instrs)
      typed_instr_to_instr(idx, instrs)
      instrs.push(ArrayGetU(type_idx))
    }
    TypedInstrKind::TArraySet(type_idx, arr, idx, val) => {
      typed_instr_to_instr(arr, instrs)
      typed_instr_to_instr(idx, instrs)
      typed_instr_to_instr(val, instrs)
      instrs.push(ArraySet(type_idx))
    }
    TypedInstrKind::TArrayFill(type_idx, arr, offset, val, len) => {
      typed_instr_to_instr(arr, instrs)
      typed_instr_to_instr(offset, instrs)
      typed_instr_to_instr(val, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(ArrayFill(type_idx))
    }
    TypedInstrKind::TArrayCopy(
      dst_type,
      src_type,
      dst,
      dst_offset,
      src,
      src_offset,
      len
    ) => {
      typed_instr_to_instr(dst, instrs)
      typed_instr_to_instr(dst_offset, instrs)
      typed_instr_to_instr(src, instrs)
      typed_instr_to_instr(src_offset, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(ArrayCopy(dst_type, src_type))
    }
    TypedInstrKind::TArrayInitData(type_idx, data_idx, arr, dst, src, len) => {
      typed_instr_to_instr(arr, instrs)
      typed_instr_to_instr(dst, instrs)
      typed_instr_to_instr(src, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(ArrayInitData(type_idx, data_idx))
    }
    TypedInstrKind::TArrayInitElem(type_idx, elem_idx, arr, dst, src, len) => {
      typed_instr_to_instr(arr, instrs)
      typed_instr_to_instr(dst, instrs)
      typed_instr_to_instr(src, instrs)
      typed_instr_to_instr(len, instrs)
      instrs.push(ArrayInitElem(type_idx, elem_idx))
    }

    // === GC: Casts ===
    TypedInstrKind::TRefGetDesc(type_idx, ref_) => {
      typed_instr_to_instr(ref_, instrs)
      instrs.push(RefGetDesc(type_idx))
    }
    TypedInstrKind::TRefTest(nullable, ht, ref_) => {
      typed_instr_to_instr(ref_, instrs)
      instrs.push(RefTest(nullable, ht))
    }
    TypedInstrKind::TRefCast(nullable, ht, ref_) => {
      typed_instr_to_instr(ref_, instrs)
      instrs.push(RefCast(nullable, ht))
    }
    TypedInstrKind::TRefTestDesc(nullable, ht, ref_) => {
      typed_instr_to_instr(ref_, instrs)
      instrs.push(RefTestDesc(nullable, ht))
    }
    TypedInstrKind::TRefCastDescEq(nullable, ht, ref_) => {
      typed_instr_to_instr(ref_, instrs)
      instrs.push(RefCastDescEq(nullable, ht))
    }

    // === SIMD: Splat ===
    TypedInstrKind::TI8x16Splat(val) => {
      typed_instr_to_instr(val, instrs)
      instrs.push(I8x16Splat)
    }
    TypedInstrKind::TI16x8Splat(val) => {
      typed_instr_to_instr(val, instrs)
      instrs.push(I16x8Splat)
    }
    TypedInstrKind::TI32x4Splat(val) => {
      typed_instr_to_instr(val, instrs)
      instrs.push(I32x4Splat)
    }
    TypedInstrKind::TI64x2Splat(val) => {
      typed_instr_to_instr(val, instrs)
      instrs.push(I64x2Splat)
    }
    TypedInstrKind::TF32x4Splat(val) => {
      typed_instr_to_instr(val, instrs)
      instrs.push(F32x4Splat)
    }
    TypedInstrKind::TF64x2Splat(val) => {
      typed_instr_to_instr(val, instrs)
      instrs.push(F64x2Splat)
    }

    // === SIMD: Extract lane ===
    TypedInstrKind::TExtractLane(op, lane, vec) => {
      typed_instr_to_instr(vec, instrs)
      instrs.push(extract_lane_op_to_instr(op, lane))
    }

    // === SIMD: Replace lane ===
    TypedInstrKind::TReplaceLane(op, lane, vec, val) => {
      typed_instr_to_instr(vec, instrs)
      typed_instr_to_instr(val, instrs)
      instrs.push(replace_lane_op_to_instr(op, lane))
    }

    // === SIMD: Shuffle ===
    TypedInstrKind::TI8x16Shuffle(
      l0,
      l1,
      l2,
      l3,
      l4,
      l5,
      l6,
      l7,
      l8,
      l9,
      l10,
      l11,
      l12,
      l13,
      l14,
      l15,
      v1,
      v2
    ) => {
      typed_instr_to_instr(v1, instrs)
      typed_instr_to_instr(v2, instrs)
      instrs.push(
        I8x16Shuffle(
          l0, l1, l2, l3, l4, l5, l6, l7, l8, l9, l10, l11, l12, l13, l14, l15,
        ),
      )
    }

    // === SIMD: Swizzle ===
    TypedInstrKind::TI8x16Swizzle(vec, indices) => {
      typed_instr_to_instr(vec, instrs)
      typed_instr_to_instr(indices, instrs)
      instrs.push(I8x16Swizzle)
    }
    TypedInstrKind::TI8x16RelaxedSwizzle(vec, indices) => {
      typed_instr_to_instr(vec, instrs)
      typed_instr_to_instr(indices, instrs)
      instrs.push(I8x16RelaxedSwizzle)
    }

    // === SIMD: Shift ===
    TypedInstrKind::TV128Shift(op, vec, shift) => {
      typed_instr_to_instr(vec, instrs)
      typed_instr_to_instr(shift, instrs)
      instrs.push(v128_shift_op_to_instr(op))
    }

    // === SIMD: Ternary ===
    TypedInstrKind::TV128Ternary(op, v1, v2, v3) => {
      typed_instr_to_instr(v1, instrs)
      typed_instr_to_instr(v2, instrs)
      typed_instr_to_instr(v3, instrs)
      instrs.push(v128_ternary_op_to_instr(op))
    }

    // === SIMD: Lane load ===
    TypedInstrKind::TV128LoadLane(op, memarg, lane, addr, vec) => {
      typed_instr_to_instr(addr, instrs)
      typed_instr_to_instr(vec, instrs)
      instrs.push(v128_load_lane_op_to_instr(op, memarg, lane))
    }

    // === SIMD: Lane store ===
    TypedInstrKind::TV128StoreLane(op, memarg, lane, addr, vec) => {
      typed_instr_to_instr(addr, instrs)
      typed_instr_to_instr(vec, instrs)
      instrs.push(v128_store_lane_op_to_instr(op, memarg, lane))
    }
  }
}

// ============================================================================
// Op to Instruction helpers
// ============================================================================

///|
fn unary_op_to_instr(op : UnaryOp) -> Instruction {
  match op {
    I32EqzOp => I32Eqz
    I64EqzOp => I64Eqz
    I32ClzOp => I32Clz
    I32CtzOp => I32Ctz
    I32PopcntOp => I32Popcnt
    I64ClzOp => I64Clz
    I64CtzOp => I64Ctz
    I64PopcntOp => I64Popcnt
    F32AbsOp => F32Abs
    F32NegOp => F32Neg
    F32CeilOp => F32Ceil
    F32FloorOp => F32Floor
    F32TruncOp => F32Trunc
    F32NearestOp => F32Nearest
    F32SqrtOp => F32Sqrt
    F64AbsOp => F64Abs
    F64NegOp => F64Neg
    F64CeilOp => F64Ceil
    F64FloorOp => F64Floor
    F64TruncOp => F64Trunc
    F64NearestOp => F64Nearest
    F64SqrtOp => F64Sqrt
    I32WrapI64Op => I32WrapI64
    I32TruncF32SOp => I32TruncF32S
    I32TruncF32UOp => I32TruncF32U
    I32TruncF64SOp => I32TruncF64S
    I32TruncF64UOp => I32TruncF64U
    I64ExtendI32SOp => I64ExtendI32S
    I64ExtendI32UOp => I64ExtendI32U
    I64TruncF32SOp => I64TruncF32S
    I64TruncF32UOp => I64TruncF32U
    I64TruncF64SOp => I64TruncF64S
    I64TruncF64UOp => I64TruncF64U
    F32ConvertI32SOp => F32ConvertI32S
    F32ConvertI32UOp => F32ConvertI32U
    F32ConvertI64SOp => F32ConvertI64S
    F32ConvertI64UOp => F32ConvertI64U
    F32DemoteF64Op => F32DemoteF64
    F64ConvertI32SOp => F64ConvertI32S
    F64ConvertI32UOp => F64ConvertI32U
    F64ConvertI64SOp => F64ConvertI64S
    F64ConvertI64UOp => F64ConvertI64U
    F64PromoteF32Op => F64PromoteF32
    I32ReinterpretF32Op => I32ReinterpretF32
    I64ReinterpretF64Op => I64ReinterpretF64
    F32ReinterpretI32Op => F32ReinterpretI32
    F64ReinterpretI64Op => F64ReinterpretI64
    I32Extend8SOp => I32Extend8S
    I32Extend16SOp => I32Extend16S
    I64Extend8SOp => I64Extend8S
    I64Extend16SOp => I64Extend16S
    I64Extend32SOp => I64Extend32S
    I32TruncSatF32SOp => I32TruncSatF32S
    I32TruncSatF32UOp => I32TruncSatF32U
    I32TruncSatF64SOp => I32TruncSatF64S
    I32TruncSatF64UOp => I32TruncSatF64U
    I64TruncSatF32SOp => I64TruncSatF32S
    I64TruncSatF32UOp => I64TruncSatF32U
    I64TruncSatF64SOp => I64TruncSatF64S
    I64TruncSatF64UOp => I64TruncSatF64U
    // SIMD v128 -> v128
    V128NotOp => V128Not
    I8x16AbsOp => I8x16Abs
    I8x16NegOp => I8x16Neg
    I8x16PopcntOp => I8x16Popcnt
    I16x8AbsOp => I16x8Abs
    I16x8NegOp => I16x8Neg
    I32x4AbsOp => I32x4Abs
    I32x4NegOp => I32x4Neg
    I64x2AbsOp => I64x2Abs
    I64x2NegOp => I64x2Neg
    F32x4AbsOp => F32x4Abs
    F32x4NegOp => F32x4Neg
    F32x4SqrtOp => F32x4Sqrt
    F32x4CeilOp => F32x4Ceil
    F32x4FloorOp => F32x4Floor
    F32x4TruncOp => F32x4Trunc
    F32x4NearestOp => F32x4Nearest
    F64x2AbsOp => F64x2Abs
    F64x2NegOp => F64x2Neg
    F64x2SqrtOp => F64x2Sqrt
    F64x2CeilOp => F64x2Ceil
    F64x2FloorOp => F64x2Floor
    F64x2TruncOp => F64x2Trunc
    F64x2NearestOp => F64x2Nearest
    // SIMD v128 -> i32
    V128AnyTrueOp => V128AnyTrue
    I8x16AllTrueOp => I8x16AllTrue
    I8x16BitmaskOp => I8x16Bitmask
    I16x8AllTrueOp => I16x8AllTrue
    I16x8BitmaskOp => I16x8Bitmask
    I32x4AllTrueOp => I32x4AllTrue
    I32x4BitmaskOp => I32x4Bitmask
    I64x2AllTrueOp => I64x2AllTrue
    I64x2BitmaskOp => I64x2Bitmask
    // SIMD extend
    I16x8ExtendLowI8x16SOp => I16x8ExtendLowI8x16S
    I16x8ExtendHighI8x16SOp => I16x8ExtendHighI8x16S
    I16x8ExtendLowI8x16UOp => I16x8ExtendLowI8x16U
    I16x8ExtendHighI8x16UOp => I16x8ExtendHighI8x16U
    I32x4ExtendLowI16x8SOp => I32x4ExtendLowI16x8S
    I32x4ExtendHighI16x8SOp => I32x4ExtendHighI16x8S
    I32x4ExtendLowI16x8UOp => I32x4ExtendLowI16x8U
    I32x4ExtendHighI16x8UOp => I32x4ExtendHighI16x8U
    I64x2ExtendLowI32x4SOp => I64x2ExtendLowI32x4S
    I64x2ExtendHighI32x4SOp => I64x2ExtendHighI32x4S
    I64x2ExtendLowI32x4UOp => I64x2ExtendLowI32x4U
    I64x2ExtendHighI32x4UOp => I64x2ExtendHighI32x4U
    // SIMD pairwise add
    I16x8ExtaddPairwiseI8x16SOp => I16x8ExtaddPairwiseI8x16S
    I16x8ExtaddPairwiseI8x16UOp => I16x8ExtaddPairwiseI8x16U
    I32x4ExtaddPairwiseI16x8SOp => I32x4ExtaddPairwiseI16x8S
    I32x4ExtaddPairwiseI16x8UOp => I32x4ExtaddPairwiseI16x8U
    // SIMD conversion
    F32x4DemoteF64x2ZeroOp => F32x4DemoteF64x2Zero
    F64x2PromoteLowF32x4Op => F64x2PromoteLowF32x4
    I32x4TruncSatF32x4SOp => I32x4TruncSatF32x4S
    I32x4TruncSatF32x4UOp => I32x4TruncSatF32x4U
    F32x4ConvertI32x4SOp => F32x4ConvertI32x4S
    F32x4ConvertI32x4UOp => F32x4ConvertI32x4U
    I32x4TruncSatF64x2SZeroOp => I32x4TruncSatF64x2SZero
    I32x4TruncSatF64x2UZeroOp => I32x4TruncSatF64x2UZero
    F64x2ConvertLowI32x4SOp => F64x2ConvertLowI32x4S
    F64x2ConvertLowI32x4UOp => F64x2ConvertLowI32x4U
    // SIMD relaxed truncation
    I32x4RelaxedTruncF32x4SOp => I32x4RelaxedTruncF32x4S
    I32x4RelaxedTruncF32x4UOp => I32x4RelaxedTruncF32x4U
    I32x4RelaxedTruncZeroF64x2SOp => I32x4RelaxedTruncZeroF64x2S
    I32x4RelaxedTruncZeroF64x2UOp => I32x4RelaxedTruncZeroF64x2U
  }
}

///|
fn binary_op_to_instr(op : BinaryOp) -> Instruction {
  match op {
    I32EqOp => I32Eq
    I32NeOp => I32Ne
    I32LtSOp => I32LtS
    I32LtUOp => I32LtU
    I32GtSOp => I32GtS
    I32GtUOp => I32GtU
    I32LeSOp => I32LeS
    I32LeUOp => I32LeU
    I32GeSOp => I32GeS
    I32GeUOp => I32GeU
    I64EqOp => I64Eq
    I64NeOp => I64Ne
    I64LtSOp => I64LtS
    I64LtUOp => I64LtU
    I64GtSOp => I64GtS
    I64GtUOp => I64GtU
    I64LeSOp => I64LeS
    I64LeUOp => I64LeU
    I64GeSOp => I64GeS
    I64GeUOp => I64GeU
    F32EqOp => F32Eq
    F32NeOp => F32Ne
    F32LtOp => F32Lt
    F32GtOp => F32Gt
    F32LeOp => F32Le
    F32GeOp => F32Ge
    F64EqOp => F64Eq
    F64NeOp => F64Ne
    F64LtOp => F64Lt
    F64GtOp => F64Gt
    F64LeOp => F64Le
    F64GeOp => F64Ge
    I32AddOp => I32Add
    I32SubOp => I32Sub
    I32MulOp => I32Mul
    I32DivSOp => I32DivS
    I32DivUOp => I32DivU
    I32RemSOp => I32RemS
    I32RemUOp => I32RemU
    I32AndOp => I32And
    I32OrOp => I32Or
    I32XorOp => I32Xor
    I32ShlOp => I32Shl
    I32ShrSOp => I32ShrS
    I32ShrUOp => I32ShrU
    I32RotlOp => I32Rotl
    I32RotrOp => I32Rotr
    I64AddOp => I64Add
    I64SubOp => I64Sub
    I64MulOp => I64Mul
    I64DivSOp => I64DivS
    I64DivUOp => I64DivU
    I64RemSOp => I64RemS
    I64RemUOp => I64RemU
    I64AndOp => I64And
    I64OrOp => I64Or
    I64XorOp => I64Xor
    I64ShlOp => I64Shl
    I64ShrSOp => I64ShrS
    I64ShrUOp => I64ShrU
    I64RotlOp => I64Rotl
    I64RotrOp => I64Rotr
    F32AddOp => F32Add
    F32SubOp => F32Sub
    F32MulOp => F32Mul
    F32DivOp => F32Div
    F32MinOp => F32Min
    F32MaxOp => F32Max
    F32CopysignOp => F32Copysign
    F64AddOp => F64Add
    F64SubOp => F64Sub
    F64MulOp => F64Mul
    F64DivOp => F64Div
    F64MinOp => F64Min
    F64MaxOp => F64Max
    F64CopysignOp => F64Copysign
    // SIMD bitwise
    V128AndOp => V128And
    V128AndnotOp => V128Andnot
    V128OrOp => V128Or
    V128XorOp => V128Xor
    // SIMD i8x16 comparisons
    I8x16EqOp => I8x16Eq
    I8x16NeOp => I8x16Ne
    I8x16LtSOp => I8x16LtS
    I8x16LtUOp => I8x16LtU
    I8x16GtSOp => I8x16GtS
    I8x16GtUOp => I8x16GtU
    I8x16LeSOp => I8x16LeS
    I8x16LeUOp => I8x16LeU
    I8x16GeSOp => I8x16GeS
    I8x16GeUOp => I8x16GeU
    // SIMD i16x8 comparisons
    I16x8EqOp => I16x8Eq
    I16x8NeOp => I16x8Ne
    I16x8LtSOp => I16x8LtS
    I16x8LtUOp => I16x8LtU
    I16x8GtSOp => I16x8GtS
    I16x8GtUOp => I16x8GtU
    I16x8LeSOp => I16x8LeS
    I16x8LeUOp => I16x8LeU
    I16x8GeSOp => I16x8GeS
    I16x8GeUOp => I16x8GeU
    // SIMD i32x4 comparisons
    I32x4EqOp => I32x4Eq
    I32x4NeOp => I32x4Ne
    I32x4LtSOp => I32x4LtS
    I32x4LtUOp => I32x4LtU
    I32x4GtSOp => I32x4GtS
    I32x4GtUOp => I32x4GtU
    I32x4LeSOp => I32x4LeS
    I32x4LeUOp => I32x4LeU
    I32x4GeSOp => I32x4GeS
    I32x4GeUOp => I32x4GeU
    // SIMD i64x2 comparisons
    I64x2EqOp => I64x2Eq
    I64x2NeOp => I64x2Ne
    I64x2LtSOp => I64x2LtS
    I64x2GtSOp => I64x2GtS
    I64x2LeSOp => I64x2LeS
    I64x2GeSOp => I64x2GeS
    // SIMD f32x4 comparisons
    F32x4EqOp => F32x4Eq
    F32x4NeOp => F32x4Ne
    F32x4LtOp => F32x4Lt
    F32x4GtOp => F32x4Gt
    F32x4LeOp => F32x4Le
    F32x4GeOp => F32x4Ge
    // SIMD f64x2 comparisons
    F64x2EqOp => F64x2Eq
    F64x2NeOp => F64x2Ne
    F64x2LtOp => F64x2Lt
    F64x2GtOp => F64x2Gt
    F64x2LeOp => F64x2Le
    F64x2GeOp => F64x2Ge
    // SIMD i8x16 arithmetic
    I8x16AddOp => I8x16Add
    I8x16AddSatSOp => I8x16AddSatS
    I8x16AddSatUOp => I8x16AddSatU
    I8x16SubOp => I8x16Sub
    I8x16SubSatSOp => I8x16SubSatS
    I8x16SubSatUOp => I8x16SubSatU
    I8x16MinSOp => I8x16MinS
    I8x16MinUOp => I8x16MinU
    I8x16MaxSOp => I8x16MaxS
    I8x16MaxUOp => I8x16MaxU
    I8x16AvgrUOp => I8x16AvgrU
    I8x16NarrowI16x8SOp => I8x16NarrowI16x8S
    I8x16NarrowI16x8UOp => I8x16NarrowI16x8U
    // SIMD i16x8 arithmetic
    I16x8AddOp => I16x8Add
    I16x8AddSatSOp => I16x8AddSatS
    I16x8AddSatUOp => I16x8AddSatU
    I16x8SubOp => I16x8Sub
    I16x8SubSatSOp => I16x8SubSatS
    I16x8SubSatUOp => I16x8SubSatU
    I16x8MulOp => I16x8Mul
    I16x8MinSOp => I16x8MinS
    I16x8MinUOp => I16x8MinU
    I16x8MaxSOp => I16x8MaxS
    I16x8MaxUOp => I16x8MaxU
    I16x8AvgrUOp => I16x8AvgrU
    I16x8Q15mulrSatSOp => I16x8Q15mulrSatS
    I16x8NarrowI32x4SOp => I16x8NarrowI32x4S
    I16x8NarrowI32x4UOp => I16x8NarrowI32x4U
    I16x8ExtmulLowI8x16SOp => I16x8ExtmulLowI8x16S
    I16x8ExtmulHighI8x16SOp => I16x8ExtmulHighI8x16S
    I16x8ExtmulLowI8x16UOp => I16x8ExtmulLowI8x16U
    I16x8ExtmulHighI8x16UOp => I16x8ExtmulHighI8x16U
    // SIMD i32x4 arithmetic
    I32x4AddOp => I32x4Add
    I32x4SubOp => I32x4Sub
    I32x4MulOp => I32x4Mul
    I32x4MinSOp => I32x4MinS
    I32x4MinUOp => I32x4MinU
    I32x4MaxSOp => I32x4MaxS
    I32x4MaxUOp => I32x4MaxU
    I32x4DotI16x8SOp => I32x4DotI16x8S
    I32x4ExtmulLowI16x8SOp => I32x4ExtmulLowI16x8S
    I32x4ExtmulHighI16x8SOp => I32x4ExtmulHighI16x8S
    I32x4ExtmulLowI16x8UOp => I32x4ExtmulLowI16x8U
    I32x4ExtmulHighI16x8UOp => I32x4ExtmulHighI16x8U
    // SIMD i64x2 arithmetic
    I64x2AddOp => I64x2Add
    I64x2SubOp => I64x2Sub
    I64x2MulOp => I64x2Mul
    I64x2ExtmulLowI32x4SOp => I64x2ExtmulLowI32x4S
    I64x2ExtmulHighI32x4SOp => I64x2ExtmulHighI32x4S
    I64x2ExtmulLowI32x4UOp => I64x2ExtmulLowI32x4U
    I64x2ExtmulHighI32x4UOp => I64x2ExtmulHighI32x4U
    // SIMD f32x4 arithmetic
    F32x4AddOp => F32x4Add
    F32x4SubOp => F32x4Sub
    F32x4MulOp => F32x4Mul
    F32x4DivOp => F32x4Div
    F32x4MinOp => F32x4Min
    F32x4MaxOp => F32x4Max
    F32x4PminOp => F32x4Pmin
    F32x4PmaxOp => F32x4Pmax
    // SIMD f64x2 arithmetic
    F64x2AddOp => F64x2Add
    F64x2SubOp => F64x2Sub
    F64x2MulOp => F64x2Mul
    F64x2DivOp => F64x2Div
    F64x2MinOp => F64x2Min
    F64x2MaxOp => F64x2Max
    F64x2PminOp => F64x2Pmin
    F64x2PmaxOp => F64x2Pmax
    // SIMD relaxed
    F32x4RelaxedMinOp => F32x4RelaxedMin
    F32x4RelaxedMaxOp => F32x4RelaxedMax
    F64x2RelaxedMinOp => F64x2RelaxedMin
    F64x2RelaxedMaxOp => F64x2RelaxedMax
    I16x8RelaxedQ15mulrSOp => I16x8RelaxedQ15mulrS
    I16x8RelaxedDotI8x16I7x16SOp => I16x8RelaxedDotI8x16I7x16S
  }
}

///|
fn load_op_to_instr(op : LoadOp, memarg : MemArg) -> Instruction {
  match op {
    I32LoadOp => I32Load(memarg)
    I64LoadOp => I64Load(memarg)
    F32LoadOp => F32Load(memarg)
    F64LoadOp => F64Load(memarg)
    I32Load8SOp => I32Load8S(memarg)
    I32Load8UOp => I32Load8U(memarg)
    I32Load16SOp => I32Load16S(memarg)
    I32Load16UOp => I32Load16U(memarg)
    I64Load8SOp => I64Load8S(memarg)
    I64Load8UOp => I64Load8U(memarg)
    I64Load16SOp => I64Load16S(memarg)
    I64Load16UOp => I64Load16U(memarg)
    I64Load32SOp => I64Load32S(memarg)
    I64Load32UOp => I64Load32U(memarg)
    I32AtomicLoadOp => I32AtomicLoad(memarg)
    I64AtomicLoadOp => I64AtomicLoad(memarg)
    I32AtomicLoad8UOp => I32AtomicLoad8U(memarg)
    I32AtomicLoad16UOp => I32AtomicLoad16U(memarg)
    I64AtomicLoad8UOp => I64AtomicLoad8U(memarg)
    I64AtomicLoad16UOp => I64AtomicLoad16U(memarg)
    I64AtomicLoad32UOp => I64AtomicLoad32U(memarg)
    V128LoadOp => V128Load(memarg)
    V128Load8x8SOp => V128Load8x8S(memarg)
    V128Load8x8UOp => V128Load8x8U(memarg)
    V128Load16x4SOp => V128Load16x4S(memarg)
    V128Load16x4UOp => V128Load16x4U(memarg)
    V128Load32x2SOp => V128Load32x2S(memarg)
    V128Load32x2UOp => V128Load32x2U(memarg)
    V128Load8SplatOp => V128Load8Splat(memarg)
    V128Load16SplatOp => V128Load16Splat(memarg)
    V128Load32SplatOp => V128Load32Splat(memarg)
    V128Load64SplatOp => V128Load64Splat(memarg)
    V128Load32ZeroOp => V128Load32Zero(memarg)
    V128Load64ZeroOp => V128Load64Zero(memarg)
  }
}

///|
fn store_op_to_instr(op : StoreOp, memarg : MemArg) -> Instruction {
  match op {
    I32StoreOp => I32Store(memarg)
    I64StoreOp => I64Store(memarg)
    F32StoreOp => F32Store(memarg)
    F64StoreOp => F64Store(memarg)
    I32Store8Op => I32Store8(memarg)
    I32Store16Op => I32Store16(memarg)
    I64Store8Op => I64Store8(memarg)
    I64Store16Op => I64Store16(memarg)
    I64Store32Op => I64Store32(memarg)
    I32AtomicStoreOp => I32AtomicStore(memarg)
    I64AtomicStoreOp => I64AtomicStore(memarg)
    I32AtomicStore8Op => I32AtomicStore8(memarg)
    I32AtomicStore16Op => I32AtomicStore16(memarg)
    I64AtomicStore8Op => I64AtomicStore8(memarg)
    I64AtomicStore16Op => I64AtomicStore16(memarg)
    I64AtomicStore32Op => I64AtomicStore32(memarg)
    V128StoreOp => V128Store(memarg)
  }
}

///|
fn extract_lane_op_to_instr(op : ExtractLaneOp, lane : LaneIdx) -> Instruction {
  match op {
    I8x16ExtractLaneSOp => I8x16ExtractLaneS(lane)
    I8x16ExtractLaneUOp => I8x16ExtractLaneU(lane)
    I16x8ExtractLaneSOp => I16x8ExtractLaneS(lane)
    I16x8ExtractLaneUOp => I16x8ExtractLaneU(lane)
    I32x4ExtractLaneOp => I32x4ExtractLane(lane)
    I64x2ExtractLaneOp => I64x2ExtractLane(lane)
    F32x4ExtractLaneOp => F32x4ExtractLane(lane)
    F64x2ExtractLaneOp => F64x2ExtractLane(lane)
  }
}

///|
fn replace_lane_op_to_instr(op : ReplaceLaneOp, lane : LaneIdx) -> Instruction {
  match op {
    I8x16ReplaceLaneOp => I8x16ReplaceLane(lane)
    I16x8ReplaceLaneOp => I16x8ReplaceLane(lane)
    I32x4ReplaceLaneOp => I32x4ReplaceLane(lane)
    I64x2ReplaceLaneOp => I64x2ReplaceLane(lane)
    F32x4ReplaceLaneOp => F32x4ReplaceLane(lane)
    F64x2ReplaceLaneOp => F64x2ReplaceLane(lane)
  }
}

///|
fn v128_shift_op_to_instr(op : V128ShiftOp) -> Instruction {
  match op {
    I8x16ShlOp => I8x16Shl
    I8x16ShrSOp => I8x16ShrS
    I8x16ShrUOp => I8x16ShrU
    I16x8ShlOp => I16x8Shl
    I16x8ShrSOp => I16x8ShrS
    I16x8ShrUOp => I16x8ShrU
    I32x4ShlOp => I32x4Shl
    I32x4ShrSOp => I32x4ShrS
    I32x4ShrUOp => I32x4ShrU
    I64x2ShlOp => I64x2Shl
    I64x2ShrSOp => I64x2ShrS
    I64x2ShrUOp => I64x2ShrU
  }
}

///|
fn v128_ternary_op_to_instr(op : V128TernaryOp) -> Instruction {
  match op {
    V128BitselectOp => V128Bitselect
    I8x16RelaxedLaneselectOp => I8x16RelaxedLaneselect
    I16x8RelaxedLaneselectOp => I16x8RelaxedLaneselect
    I32x4RelaxedLaneselectOp => I32x4RelaxedLaneselect
    I64x2RelaxedLaneselectOp => I64x2RelaxedLaneselect
    F32x4RelaxedMaddOp => F32x4RelaxedMadd
    F32x4RelaxedNmaddOp => F32x4RelaxedNmadd
    F64x2RelaxedMaddOp => F64x2RelaxedMadd
    F64x2RelaxedNmaddOp => F64x2RelaxedNmadd
    I32x4RelaxedDotI8x16I7x16AddSOp => I32x4RelaxedDotI8x16I7x16AddS
  }
}

///|
fn v128_load_lane_op_to_instr(
  op : V128LoadLaneOp,
  memarg : MemArg,
  lane : LaneIdx,
) -> Instruction {
  match op {
    V128Load8LaneOp => V128Load8Lane(memarg, lane)
    V128Load16LaneOp => V128Load16Lane(memarg, lane)
    V128Load32LaneOp => V128Load32Lane(memarg, lane)
    V128Load64LaneOp => V128Load64Lane(memarg, lane)
  }
}

///|
fn v128_store_lane_op_to_instr(
  op : V128StoreLaneOp,
  memarg : MemArg,
  lane : LaneIdx,
) -> Instruction {
  match op {
    V128Store8LaneOp => V128Store8Lane(memarg, lane)
    V128Store16LaneOp => V128Store16Lane(memarg, lane)
    V128Store32LaneOp => V128Store32Lane(memarg, lane)
    V128Store64LaneOp => V128Store64Lane(memarg, lane)
  }
}

///|
