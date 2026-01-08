struct AlignmentLoweringContext {
  mut locals : Array[ValType]
  memories : Array[MemType]
}

enum ChunkSize {
  ChunkSize8
  ChunkSize16
  ChunkSize32
  ChunkSize64
}

enum StackSize {
  StackSize32
  StackSize64
}

fn ChunkSize::byte_count(self : ChunkSize) -> UInt {
  match self {
    ChunkSize8 => 1
    ChunkSize16 => 2
    ChunkSize32 => 4
    ChunkSize64 => 8
  }
}

fn load_op_with_chunk_size(stack_size : StackSize, chunk_size : ChunkSize) -> Result[LoadOp, String] {
  match (stack_size, chunk_size) {
    (StackSize32, ChunkSize8) => Ok(I32Load8UOp)
    (StackSize32, ChunkSize16) => Ok(I32Load16UOp)
    (StackSize64, ChunkSize8) => Ok(I64Load8UOp)
    (StackSize64, ChunkSize16) => Ok(I64Load16UOp)
    (StackSize64, ChunkSize32) => Ok(I64Load32UOp)
    // Impossible!
    _ => Err("Invalid chunk size for value")
  }
}

fn get_valid_chunksize(remaining : UInt, align : UInt, addr : UInt64) -> ChunkSize {
  if remaining >= 8 && align >= 8 && (addr % 8) == 0 {
    ChunkSize64
  } else if remaining >= 4 && align >= 4 && (addr % 4) == 0 {
    ChunkSize32
  } else if remaining >= 2 && align >= 2 && (addr % 2) == 0 {
    ChunkSize16
  } else {
    ChunkSize8
  }
}

fn load_op_stack_size(op : LoadOp) -> StackSize {
  match op {
    V128Load64SplatOp => StackSize64
    I64Load32UOp => StackSize64
    I64Load32SOp => StackSize64
    I64Load16UOp => StackSize64
    I64Load16SOp => StackSize64
    I64Load8UOp => StackSize64
    I64Load8SOp => StackSize64
    F64LoadOp => StackSize64
    I64LoadOp => StackSize64
    V128Load64ZeroOp => StackSize64
    V128Load8x8SOp => StackSize64
    V128Load8x8UOp => StackSize64
    V128Load16x4SOp => StackSize64
    V128Load16x4UOp => StackSize64
    V128Load32x2SOp => StackSize64
    V128Load32x2UOp => StackSize64

    _ => StackSize32
  }
}

fn chunks(op_size : UInt, align : UInt, offset : UInt64) -> Array[(ChunkSize, UInt64)] {
  let acc = []
  
  loop 0U {
    pos if pos < op_size => {
      let addr = offset + pos.to_uint64()
      let remaining = op_size - pos
      let result = get_valid_chunksize(remaining, align, addr)
      acc.push((result, pos.to_uint64()))
      continue pos + result.byte_count()
    }
    _ => break acc
  }
}

fn size_of_load_op(t : LoadOp) -> UInt {
  match t {
    V128Load32ZeroOp => 4
    V128Load64SplatOp => 8
    V128Load32SplatOp => 4
    V128Load16SplatOp => 2
    V128Load8SplatOp => 1
    V128Load32x2UOp => 8
    V128Load32x2SOp => 8
    V128Load16x4UOp => 8
    V128Load16x4SOp => 8
    V128Load8x8UOp => 8
    V128Load8x8SOp => 8
    V128LoadOp => 16
    I64Load32UOp => 4
    I64Load32SOp => 4
    I64Load16UOp => 2
    I64Load16SOp => 2
    I64Load8UOp => 1
    I64Load8SOp => 1
    I32Load16UOp => 2
    I32Load16SOp => 2
    I32Load8UOp => 1
    I32Load8SOp => 1
    F64LoadOp => 8
    F32LoadOp => 4
    I64LoadOp => 8
    I32LoadOp => 4
    V128Load64ZeroOp => 8
  }
}

fn size_of_store_op(t : StoreOp) -> UInt {
  match t {
    I64Store32Op => 4
    I64Store16Op => 2
    I64Store8Op => 1
    I32Store16Op => 2
    I32Store8Op => 1
    F64StoreOp => 8
    F32StoreOp => 4
    I64StoreOp => 8
    I32StoreOp => 4
    V128StoreOp => 16
  }
}

fn size_of_v128_load_lane_op(t : V128LoadLaneOp) -> UInt {
  match t {
    V128Load32LaneOp => 4
    V128Load16LaneOp => 2
    V128Load8LaneOp => 1
    V128Load64LaneOp => 8
  }
}

fn load_shift_op(stack_size : StackSize, offset : UInt64, op : TInstr) -> TInstr {
  match stack_size {
    StackSize32 => TBinary(@lib.I32ShlOp, op, TI32Const(I32(offset.to_int() * 8)))
    StackSize64 => TBinary(@lib.I64ShlOp, op, TI64Const(I64(offset.reinterpret_as_int64() * 8)))
  }
}

fn load_or_op(stack_size : StackSize, l : TInstr, r : TInstr) -> TInstr {
  match stack_size {
    StackSize32 => TBinary(@lib.I32OrOp, l, r)
    StackSize64 => TBinary(@lib.I64OrOp, l, r)
  }
}

fn finalize_load_op(op : LoadOp, i : TInstr) -> TInstr {
  match op {
    V128Load64SplatOp => TI64x2Splat(i)
    V128Load32SplatOp => TI32x4Splat(i)
    V128Load16SplatOp => TI16x8Splat(i)
    V128Load8SplatOp => TI8x16Splat(i)
    V128Load32ZeroOp => TReplaceLane(I32x4ReplaceLaneOp, LaneIdx(0), TV128Const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), i)
    V128Load32x2UOp => TBinary(@lib.V128AndOp, TI32x4Splat(i), TV128Const(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0))
    // Signed vector lane loads
    /// TODO: V128Load32x2SOp =>

    /// TODO: V128Load16x4SOp =>

    /// TODO: V128Load8x8SOp =>

    // Unsigned vector lane loads (mask optional)
    /// TODO: V128Load32x2UOp =>

    /// TODO: V128Load16x4UOp =>

    /// TODO: V128Load8x8UOp =>
    // for sign extension, i32s are already correctly sized, no need to do a sign extend

    V128LoadOp => i
    I64Load32UOp => i
    I64Load32SOp => TUnary(I64Extend32SOp, i)
    I64Load16UOp => i
    I64Load16SOp => TUnary(I64Extend16SOp, i)
    I64Load8UOp => i
    I64Load8SOp => TUnary(I64Extend8SOp, i)
    I32Load16UOp => i
    I32Load16SOp => TUnary(I32Extend16SOp, i)
    I32Load8UOp => i
    I32Load8SOp => TUnary(I32Extend8SOp, i)
    F64LoadOp => TUnary(I64ReinterpretF64Op, i)
    F32LoadOp => TUnary(I32ReinterpretF32Op, i)
    I64LoadOp => i
    I32LoadOp => i
    V128Load64ZeroOp => TReplaceLane(I64x2ReplaceLaneOp, LaneIdx(0), TV128Const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), i)
  }
}

pub fn alignment_lowering_pass() -> ModuleTransformer[AlignmentLoweringContext] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_func: Some(fn (self, t, i) {
      match i {
        Func(_) => Err("Expected TFunc")
        TFunc(locals, b) => {
          t.locals = locals
          match self.walk_func_default(t, TFunc(locals, b)) {
            Ok(Some((t, func))) => match func {
              TFunc(_, b) => change(t, TFunc(t.locals, b))
              _ => Err("Expected TFunc")
            }
            Err(t) => Err(t)
          }
        }
      }
    }),
    on_tinstruction: Some(fn (self, t, i) {
      match i {
        TLoad(op, MemArg(U32(align), mem_option, U64(offset)), a) => {
          let a = match self.walk_tinstruction_default(t, a) {
            Ok(Some((_, a))) => a
            Ok(None) => a
            Err(t) => return Err(t)
          }
          let op_size = size_of_load_op(op)
          if (op_size > 8) {
            return change(t, TLoad(op, MemArg(U32(align), mem_option, U64(offset)), a))
          }

          let align = @cmp.minimum(align, op_size)
          let c = chunks(op_size, align, offset)
          if c.length() == 1 {
            return change(t, TLoad(op, MemArg(U32(align), mem_option, U64(offset)), a))
          }

          // Introduce a temporary local variable that should be optimized away at some point.
          // The memory pointer type must be whatever the limits valtype is for that memory
          let mem_idx = match mem_option {
            Some(MemIdx(mem_idx)) => mem_idx.reinterpret_as_int()
            None => 0
          }
          let ptr_valtype = match t.memories.get(mem_idx) {
            Some(mem_type) => mem_type.0.addr_valtype()
            None => return Err("Invalid memory index")
          }
          let next = t.locals.length().reinterpret_as_uint()
          t.locals.push(ptr_valtype)
          let local_idx = @lib.LocalIdx(next)
          let ptr_start_set = @lib.TLocalTee(local_idx, a)

          let value_stack_size = load_op_stack_size(op)
          let first = c[0]
        
          let chunk_byte_count = first.0.byte_count()
          let load_op = match load_op_with_chunk_size(value_stack_size, first.0) {
            Ok(t) => t
            Err(t) => return Err(t)
          }

          let first_load = @lib.TLoad(
            load_op,
            MemArg(U32(chunk_byte_count), mem_option, U64(offset + first.1)),
            ptr_start_set
          )

          let mut acc = load_shift_op(value_stack_size, first.1, first_load)

          loop 1 {
            n if c.get(n) is Some((chunk_size, relative_offset)) => {
              let chunk_byte_count = chunk_size.byte_count()
              let load_op = match load_op_with_chunk_size(value_stack_size, chunk_size) {
                Ok(t) => t
                Err(t) => return Err(t)
              }
              let load_op = @lib.TLoad(load_op, MemArg(U32(chunk_byte_count), mem_option, U64(relative_offset + offset)), TLocalGet(local_idx))
              let shift_op = load_shift_op(value_stack_size, relative_offset, load_op)

              acc = load_or_op(value_stack_size, shift_op, acc)
              continue n + 1
            }
            _ => {
              break change(t, finalize_load_op(op, acc))
            }
          }  
        }
        TStore(op, MemArg(U32(align), mem_option, U64(offset)), a, b) => {
          let a = match self.walk_tinstruction_default(t, a) {
            Ok(Some((_, a))) => a
            Ok(None) => a
            Err(t) => return Err(t)
          }
          let b = match self.walk_tinstruction_default(t, b) {
            Ok(Some((_, a))) => a
            Ok(None) => a
            Err(t) => return Err(t)
          }
          let op_size = size_of_store_op(op)
          if (op_size > 8) {
            return change(t, TStore(op, MemArg(U32(align), mem_option, U64(offset)), a, b))
          }
          let align = @cmp.minimum(align, op_size)
          let c = chunks(op_size, align, offset)
          if c.length() == 1 {
            return change(t, TStore(op, MemArg(U32(align), mem_option, U64(offset)), a, b))
          }

        }
        TV128LoadLane(op, MemArg(U32(align), mem_option, U64(offset)), lane, a, b) => {
          let op_size = size_of_v128_load_lane_op(op)
          let align = @cmp.minimum(align, op_size)
          let a = match self.walk_tinstruction_default(t, a) {
            Ok(Some((_, a))) => a
            Ok(None) => a
            Err(t) => return Err(t)
          }
          let b = match self.walk_tinstruction_default(t, b) {
            Ok(Some((_, a))) => a
            Ok(None) => a
            Err(t) => return Err(t)
          }
          let c = chunks(op_size, align, offset)
          if c.length() == 1 {
            return change(t, TV128LoadLane(op, MemArg(U32(align), mem_option, U64(offset)), lane, a, b))
          }
        }
        _ => self.walk_tinstruction_default(t, i)
      }
    })
  }
}
