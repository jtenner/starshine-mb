///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
priv enum ChunkSize {
  ChunkSize8
  ChunkSize16
  ChunkSize32
  ChunkSize64
} derive(Eq, Show)

///|
priv enum StackSize {
  StackSize32
  StackSize64
} derive(Eq, Show)

///|
fn ChunkSize::byte_count(self : ChunkSize) -> UInt {
  match self {
    ChunkSize8 => 1
    ChunkSize16 => 2
    ChunkSize32 => 4
    ChunkSize64 => 8
  }
}

///|
fn store_op_stack_size(op : StoreOp) -> StackSize {
  match op {
    I64StoreOp => StackSize64
    I64AtomicStoreOp => StackSize64
    I64Store32Op => StackSize64
    I64AtomicStore32Op => StackSize64
    I64Store16Op => StackSize64
    I64AtomicStore16Op => StackSize64
    I64Store8Op => StackSize64
    I64AtomicStore8Op => StackSize64
    F64StoreOp => StackSize64
    _ => StackSize32
  }
}

///|
fn load_op_with_chunk_size(
  stack_size : StackSize,
  chunk_size : ChunkSize,
) -> Result[LoadOp, String] {
  match (stack_size, chunk_size) {
    (StackSize32, ChunkSize8) => Ok(LoadOp::i32_load8u())
    (StackSize32, ChunkSize16) => Ok(LoadOp::i32_load16u())
    (StackSize64, ChunkSize8) => Ok(LoadOp::i64_load8u())
    (StackSize64, ChunkSize16) => Ok(LoadOp::i64_load16u())
    (StackSize64, ChunkSize32) => Ok(LoadOp::i64_load32u())
    // Impossible!
    _ => Err("Invalid chunk size for value")
  }
}

///|
fn store_op_with_chunk_size(
  stack_size : StackSize,
  chunk_size : ChunkSize,
) -> Result[StoreOp, String] {
  match (stack_size, chunk_size) {
    (StackSize32, ChunkSize8) => Ok(StoreOp::i32_store8())
    (StackSize32, ChunkSize16) => Ok(StoreOp::i32_store16())
    (StackSize64, ChunkSize8) => Ok(StoreOp::i64_store8())
    (StackSize64, ChunkSize16) => Ok(StoreOp::i64_store16())
    (StackSize64, ChunkSize32) => Ok(StoreOp::i64_store32())
    _ => Err("Invalid chunk size for store")
  }
}

///|
fn get_valid_chunksize(
  remaining : UInt,
  align : UInt,
  addr : UInt64,
) -> ChunkSize {
  if remaining >= 8 && align >= 8 && addr % 8 == 0 {
    ChunkSize64
  } else if remaining >= 4 && align >= 4 && addr % 4 == 0 {
    ChunkSize32
  } else if remaining >= 2 && align >= 2 && addr % 2 == 0 {
    ChunkSize16
  } else {
    ChunkSize8
  }
}

///|
fn load_op_stack_size(op : LoadOp) -> StackSize {
  match op {
    V128Load64SplatOp => StackSize64
    I64Load32UOp => StackSize64
    I64AtomicLoad32UOp => StackSize64
    I64Load32SOp => StackSize64
    I64Load16UOp => StackSize64
    I64AtomicLoad16UOp => StackSize64
    I64Load16SOp => StackSize64
    I64Load8UOp => StackSize64
    I64AtomicLoad8UOp => StackSize64
    I64Load8SOp => StackSize64
    F64LoadOp => StackSize64
    I64LoadOp => StackSize64
    I64AtomicLoadOp => StackSize64
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

///|
fn chunks(
  op_size : UInt,
  align : UInt,
  offset : UInt64,
) -> Array[(ChunkSize, UInt64)] {
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

///|
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
    I64AtomicLoad32UOp => 4
    I64Load32SOp => 4
    I64Load16UOp => 2
    I64AtomicLoad16UOp => 2
    I64Load16SOp => 2
    I64Load8UOp => 1
    I64AtomicLoad8UOp => 1
    I64Load8SOp => 1
    I32Load16UOp => 2
    I32AtomicLoad16UOp => 2
    I32Load16SOp => 2
    I32Load8UOp => 1
    I32AtomicLoad8UOp => 1
    I32Load8SOp => 1
    F64LoadOp => 8
    F32LoadOp => 4
    I64LoadOp => 8
    I64AtomicLoadOp => 8
    I32LoadOp => 4
    I32AtomicLoadOp => 4
    V128Load64ZeroOp => 8
  }
}

///|
fn size_of_store_op(t : StoreOp) -> UInt {
  match t {
    I64Store32Op => 4
    I64AtomicStore32Op => 4
    I64Store16Op => 2
    I64AtomicStore16Op => 2
    I64Store8Op => 1
    I64AtomicStore8Op => 1
    I32Store16Op => 2
    I32AtomicStore16Op => 2
    I32Store8Op => 1
    I32AtomicStore8Op => 1
    F64StoreOp => 8
    F32StoreOp => 4
    I64StoreOp => 8
    I64AtomicStoreOp => 8
    I32StoreOp => 4
    I32AtomicStoreOp => 4
    V128StoreOp => 16
  }
}

///|
fn size_of_v128_load_lane_op(t : V128LoadLaneOp) -> UInt {
  match t {
    V128Load32LaneOp => 4
    V128Load16LaneOp => 2
    V128Load8LaneOp => 1
    V128Load64LaneOp => 8
  }
}

///|
fn load_shift_op(
  stack_size : StackSize,
  offset : UInt64,
  op : TInstr,
) -> TInstr {
  match stack_size {
    StackSize32 =>
      TInstr::binary(
        BinaryOp::i32_shl(),
        op,
        TInstr::i32_const(I32(offset.to_int() * 8)),
      )
    StackSize64 =>
      TInstr::binary(
        BinaryOp::i64_shl(),
        op,
        TInstr::i64_const(I64(offset.reinterpret_as_int64() * 8)),
      )
  }
}

///|
fn store_shift_op(
  stack_size : StackSize,
  offset : UInt64,
  op : TInstr,
) -> TInstr {
  if offset == 0UL {
    return op
  }
  match stack_size {
    StackSize32 =>
      TInstr::binary(
        BinaryOp::i32_shr_u(),
        op,
        TInstr::i32_const(I32(offset.to_int() * 8)),
      )
    StackSize64 =>
      TInstr::binary(
        BinaryOp::i64_shr_u(),
        op,
        TInstr::i64_const(I64(offset.reinterpret_as_int64() * 8)),
      )
  }
}

///|
fn prepare_store_value(op : StoreOp, value : TInstr) -> TInstr {
  match op {
    F64StoreOp => TInstr::unary(UnaryOp::i64_reinterpret_f64(), value)
    F32StoreOp => TInstr::unary(UnaryOp::i32_reinterpret_f32(), value)
    _ => value
  }
}

///|
fn finalize_v128_extending_load(op : LoadOp, i : TInstr) -> TInstr {
  let low64_in_v128 = TInstr::replace_lane(
    ReplaceLaneOp::i64x2_replace_lane(),
    LaneIdx::new(0),
    TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    i,
  )
  match op {
    V128Load8x8SOp =>
      TInstr::unary(UnaryOp::i16x8_extend_low_i8x16s(), low64_in_v128)
    V128Load8x8UOp =>
      TInstr::unary(UnaryOp::i16x8_extend_low_i8x16u(), low64_in_v128)
    V128Load16x4SOp =>
      TInstr::unary(UnaryOp::i32x4_extend_low_i16x8s(), low64_in_v128)
    V128Load16x4UOp =>
      TInstr::unary(UnaryOp::i32x4_extend_low_i16x8u(), low64_in_v128)
    V128Load32x2SOp =>
      TInstr::unary(UnaryOp::i64x2_extend_low_i32x4s(), low64_in_v128)
    V128Load32x2UOp =>
      TInstr::unary(UnaryOp::i64x2_extend_low_i32x4u(), low64_in_v128)
    _ => low64_in_v128
  }
}

///|
fn finalize_load_op(op : LoadOp, i : TInstr) -> TInstr {
  match op {
    V128Load64SplatOp => TInstr::i64x2_splat(i)
    V128Load32SplatOp => TInstr::i32x4_splat(i)
    V128Load16SplatOp => TInstr::i16x8_splat(i)
    V128Load8SplatOp => TInstr::i8x16_splat(i)
    V128Load32ZeroOp =>
      TInstr::replace_lane(
        ReplaceLaneOp::i32x4_replace_lane(),
        LaneIdx::new(0),
        TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        i,
      )
    V128Load64ZeroOp =>
      TInstr::replace_lane(
        ReplaceLaneOp::i64x2_replace_lane(),
        LaneIdx::new(0),
        TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        i,
      )
    V128LoadOp => i
    I64Load32UOp => i
    I64AtomicLoad32UOp => i
    I64Load32SOp => TInstr::unary(UnaryOp::i64_extend32s(), i)
    I64Load16UOp => i
    I64AtomicLoad16UOp => i
    I64Load16SOp => TInstr::unary(UnaryOp::i64_extend16s(), i)
    I64Load8UOp => i
    I64AtomicLoad8UOp => i
    I64Load8SOp => TInstr::unary(UnaryOp::i64_extend8s(), i)
    I32Load16UOp => i
    I32AtomicLoad16UOp => i
    I32Load16SOp => TInstr::unary(UnaryOp::i32_extend16s(), i)
    I32Load8UOp => i
    I32AtomicLoad8UOp => i
    I32Load8SOp => TInstr::unary(UnaryOp::i32_extend8s(), i)
    F64LoadOp => TInstr::unary(UnaryOp::f64_reinterpret_i64(), i)
    F32LoadOp => TInstr::unary(UnaryOp::f32_reinterpret_i32(), i)
    I64LoadOp => i
    I64AtomicLoadOp => i
    I32LoadOp => i
    I32AtomicLoadOp => i
    V128Load32x2SOp => finalize_v128_extending_load(op, i)
    V128Load16x4SOp => finalize_v128_extending_load(op, i)
    V128Load8x8SOp => finalize_v128_extending_load(op, i)
    V128Load32x2UOp => finalize_v128_extending_load(op, i)
    V128Load16x4UOp => finalize_v128_extending_load(op, i)
    V128Load8x8UOp => finalize_v128_extending_load(op, i)
  }
}

///|
fn load_or_op(stack_size : StackSize, l : TInstr, r : TInstr) -> TInstr {
  match stack_size {
    StackSize32 => TInstr::binary(BinaryOp::i32_or(), l, r)
    StackSize64 => TInstr::binary(BinaryOp::i64_or(), l, r)
  }
}

///|
fn alignment_lowering_pass(mod : Module) -> ModuleTransformer[IRContext] {
  let memories = match mod.mem_sec {
    Some(sec) => sec.0
    None => []
  }
  let mut temp_locals : Array[ValType] = []
  ModuleTransformer::new()
  .on_func_evt(fn(self, t : IRContext, i) {
    match i {
      Func(_) => Err("Expected TFunc")
      TFunc(locals, b) => {
        temp_locals = locals
        match self.walk_func_default(t, Func::t_func(locals, b)) {
          Ok(Some((t, func))) =>
            match func {
              TFunc(_, b) => {
                let result_locals = temp_locals
                temp_locals = []
                change(t, Func::t_func(result_locals, b))
              }
              _ => Err("Expected TFunc")
            }
          Err(t) => Err(t)
          Ok(None) => unchanged()
        }
      }
    }
  })
  .on_tinstruction_evt(fn(self, t, i) {
    match i {
      TLoad(op, MemArg(U32(align), mem_option, U64(offset)), a) => {
        let a = match self.walk_tinstruction_default(t, a) {
          Ok(Some((_, a))) => a
          Ok(None) => a
          Err(e) => return Err(e)
        }
        let op_size = size_of_load_op(op)
        if op_size > 8 {
          return change(
            t,
            TInstr::load(
              op,
              MemArg::new(U32(align), mem_option, U64(offset)),
              a,
            ),
          )
        }
        let effective_align = @cmp.minimum(align, op_size)
        let c = chunks(op_size, effective_align, offset)
        if c.length() == 1 {
          return change(
            t,
            TInstr::load(
              op,
              MemArg::new(U32(align), mem_option, U64(offset)),
              a,
            ),
          )
        }
        let mem_idx = match mem_option {
          Some(MemIdx(mem_idx)) => mem_idx.reinterpret_as_int()
          None => 0
        }
        let ptr_valtype = match memories.get(mem_idx) {
          Some(mem_type) => mem_type.0.addr_valtype()
          None => return Err("Invalid memory index")
        }
        let next = temp_locals.length().reinterpret_as_uint()
        temp_locals.push(ptr_valtype)
        let local_idx = LocalIdx::new(next)
        let ptr_start_set = TInstr::local_tee(local_idx, a)
        let value_stack_size = load_op_stack_size(op)
        let first = c[0]
        let chunk_byte_count = first.0.byte_count()
        let load_op = match load_op_with_chunk_size(value_stack_size, first.0) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        let first_load = TInstr::load(
          load_op,
          MemArg::new(U32(chunk_byte_count), mem_option, U64(offset + first.1)),
          ptr_start_set,
        )
        let mut acc = load_shift_op(value_stack_size, first.1, first_load)
        loop 1 {
          n if c.get(n) is Some((chunk_size, relative_offset)) => {
            let chunk_byte_count = chunk_size.byte_count()
            let load_op = match
              load_op_with_chunk_size(value_stack_size, chunk_size) {
              Ok(t) => t
              Err(e) => return Err(e)
            }
            let load_instr = TInstr::load(
              load_op,
              MemArg::new(
                U32(chunk_byte_count),
                mem_option,
                U64(relative_offset + offset),
              ),
              TInstr::local_get(local_idx),
            )
            let shift_op = load_shift_op(
              value_stack_size, relative_offset, load_instr,
            )
            acc = load_or_op(value_stack_size, shift_op, acc)
            continue n + 1
          }
          _ => break change(t, finalize_load_op(op, acc))
        }
      }
      TStore(op, MemArg(U32(align), mem_option, U64(offset)), a, b) => {
        let a = match self.walk_tinstruction(t, a) {
          Ok(Some((_, a))) => a
          Ok(None) => a
          Err(e) => return Err(e)
        }
        let b = match self.walk_tinstruction(t, b) {
          Ok(Some((_, b))) => b
          Ok(None) => b
          Err(e) => return Err(e)
        }
        let op_size = size_of_store_op(op)
        if op_size > 8 {
          return change(
            t,
            TInstr::store(
              op,
              MemArg::new(U32(align), mem_option, U64(offset)),
              a,
              b,
            ),
          )
        }
        let effective_align = @cmp.minimum(align, op_size)
        let c = chunks(op_size, effective_align, offset)
        if c.length() == 1 {
          return change(
            t,
            TInstr::store(
              op,
              MemArg::new(U32(align), mem_option, U64(offset)),
              a,
              b,
            ),
          )
        }

        // Need locals for both pointer and value
        let mem_idx = match mem_option {
          Some(MemIdx(mem_idx)) => mem_idx.reinterpret_as_int()
          None => 0
        }
        let ptr_valtype = match memories.get(mem_idx) {
          Some(mem_type) => mem_type.0.addr_valtype()
          None => return Err("Invalid memory index")
        }
        let ptr_local_idx = temp_locals.length().reinterpret_as_uint()
        temp_locals.push(ptr_valtype)
        let ptr_local = LocalIdx::new(ptr_local_idx)
        let value_stack_size = store_op_stack_size(op)
        let value_valtype = match value_stack_size {
          StackSize32 => ValType::i32()
          StackSize64 => ValType::i64()
        }
        let value_local_idx = temp_locals.length().reinterpret_as_uint()
        temp_locals.push(value_valtype)
        let value_local = LocalIdx::new(value_local_idx)

        // Prepare the value (reinterpret floats to ints)
        let prepared_value = prepare_store_value(op, b)

        // Build a block containing all the stores
        let stores : Array[TInstr] = []

        // First instruction: set both locals
        // We'll use TLocalSet for ptr and TLocalTee for value, then drop
        stores.push(TInstr::local_set(ptr_local, a))
        stores.push(TInstr::local_set(value_local, prepared_value))
        for i = 0; i < c.length(); i = i + 1 {
          let (chunk_size, relative_offset) = c[i]
          let chunk_byte_count = chunk_size.byte_count()
          let store_op = match
            store_op_with_chunk_size(value_stack_size, chunk_size) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          let shifted_value = store_shift_op(
            value_stack_size,
            relative_offset,
            TInstr::local_get(value_local),
          )
          let store_instr = TInstr::store(
            store_op,
            MemArg::new(
              U32(chunk_byte_count),
              mem_option,
              U64(offset + relative_offset),
            ),
            TInstr::local_get(ptr_local),
            shifted_value,
          )
          stores.push(store_instr)
        }

        // Wrap in a block with empty result type
        change(t, TInstr::block(BlockType::void_(), TExpr::new(stores)))
      }
      TV128LoadLane(op, MemArg(U32(align), mem_option, U64(offset)), lane, a, b) => {
        let op_size = size_of_v128_load_lane_op(op)
        let effective_align = @cmp.minimum(align, op_size)
        let a = match self.walk_tinstruction_default(t, a) {
          Ok(Some((_, a))) => a
          Ok(None) => a
          Err(e) => return Err(e)
        }
        let b = match self.walk_tinstruction_default(t, b) {
          Ok(Some((_, b))) => b
          Ok(None) => b
          Err(e) => return Err(e)
        }
        let c = chunks(op_size, effective_align, offset)
        if c.length() == 1 {
          return change(
            t,
            TInstr::v128_load_lane(
              op,
              MemArg::new(U32(align), mem_option, U64(offset)),
              lane,
              a,
              b,
            ),
          )
        }

        // For V128LoadLane with unaligned access, we load the value using
        // regular unaligned load logic, then use replace_lane
        let mem_idx = match mem_option {
          Some(MemIdx(mem_idx)) => mem_idx.reinterpret_as_int()
          None => 0
        }
        let ptr_valtype = match memories.get(mem_idx) {
          Some(mem_type) => mem_type.0.addr_valtype()
          None => return Err("Invalid memory index")
        }
        let ptr_local_idx = temp_locals.length().reinterpret_as_uint()
        temp_locals.push(ptr_valtype)
        let ptr_local = LocalIdx::new(ptr_local_idx)

        // Determine the load operation based on lane size
        let (replace_op, stack_size) = match op {
          V128Load8LaneOp => (ReplaceLaneOp::i8x16_replace_lane(), StackSize32)
          V128Load16LaneOp => (ReplaceLaneOp::i16x8_replace_lane(), StackSize32)
          V128Load32LaneOp => (ReplaceLaneOp::i32x4_replace_lane(), StackSize32)
          V128Load64LaneOp => (ReplaceLaneOp::i64x2_replace_lane(), StackSize64)
        }

        // Build the chunked load
        let first = c[0]
        let chunk_byte_count = first.0.byte_count()
        let chunk_load_op = match load_op_with_chunk_size(stack_size, first.0) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        let first_load = TInstr::load(
          chunk_load_op,
          MemArg::new(U32(chunk_byte_count), mem_option, U64(offset + first.1)),
          TInstr::local_tee(ptr_local, a),
        )
        let mut acc = load_shift_op(stack_size, first.1, first_load)
        for i = 1; i < c.length(); i = i + 1 {
          let (chunk_size, relative_offset) = c[i]
          let chunk_byte_count = chunk_size.byte_count()
          let chunk_load_op = match
            load_op_with_chunk_size(stack_size, chunk_size) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          let load_instr = TInstr::load(
            chunk_load_op,
            MemArg::new(
              U32(chunk_byte_count),
              mem_option,
              U64(relative_offset + offset),
            ),
            TInstr::local_get(ptr_local),
          )
          let shift_op = load_shift_op(stack_size, relative_offset, load_instr)
          acc = load_or_op(stack_size, shift_op, acc)
        }

        // Use replace_lane to put the loaded value into the vector
        change(t, TInstr::replace_lane(replace_op, lane, b, acc))
      }
      _ => self.walk_tinstruction_default(t, i)
    }
  })
}
// alignment_lowering_test.mbt

///|
fn make_i32_mem() -> Array[MemType] {
  [MemType::new(Limits::i32(1, None))]
}

///|
fn make_test_module(memories : Array[MemType]) -> Module {
  Module::new().with_mem_sec(MemSec::new(memories))
}

///|
fn run_pass(
  memories : Array[MemType],
  instr : TInstr,
) -> Result[TInstr, String] {
  let mod = make_test_module(memories)
  let ctx = IRContext::new()
  ctx.set_mod(mod)
  let pass = alignment_lowering_pass(mod)
  match pass.walk_tinstruction(ctx, instr) {
    Ok(Some((_, result))) => Ok(result)
    Ok(None) => Ok(instr)
    Err(e) => Err(e)
  }
}

///|
fn run_func_pass(
  memories : Array[MemType],
  locals : Array[ValType],
  body : Array[TInstr],
) -> Result[(Array[ValType], TExpr), String] {
  let mod = make_test_module(memories)
  let ctx = IRContext::new()
  ctx.set_mod(mod)
  let pass = alignment_lowering_pass(mod)
  let func = Func::t_func(locals, TExpr::new(body))
  match pass.walk_func(ctx, func) {
    Ok(Some((_, TFunc(new_locals, new_body)))) => Ok((new_locals, new_body))
    Ok(None) => Ok((locals, TExpr::new(body)))
    Ok(Some(_)) => Err("Expected TFunc")
    Err(e) => Err(e)
  }
}

///|
fn assert_v128_extending_load_passes_through(
  op : LoadOp,
) -> Result[Unit, String] {
  let instr = TInstr::load(
    op,
    MemArg::new(U32(8), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TLoad(load_op, _, _)) if load_op == op => Ok(())
    Ok(other) =>
      Err("Expected aligned extending load to pass through: \{other}")
    Err(e) => Err("Error: \{e}")
  }
}

///|
fn assert_v128_extending_load_is_lowered(
  op : LoadOp,
  expected_unary : UnaryOp,
  memarg : MemArg,
) -> Result[Unit, String] {
  let instr = TInstr::load(op, memarg, TInstr::local_get(LocalIdx::new(0)))
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TUnary(unary_op, TReplaceLane(I64x2ReplaceLaneOp, LaneIdx(0), _, _))) if unary_op ==
      expected_unary => Ok(())
    Ok(TLoad(load_op, _, _)) if load_op == op =>
      Err("Expected extending load to be lowered")
    Ok(other) => Err("Unexpected result: \{other}")
    Err(e) => Err("Error: \{e}")
  }
}

// ============================================================
// Tests for `chunks` function
// ============================================================

///|
test "chunks: aligned 4-byte access produces single chunk" {
  let c = chunks(4, 4, 0)
  assert_eq(c.length(), 1)
  assert_eq(c[0], (ChunkSize32, 0UL))
}

///|
test "chunks: aligned 8-byte access produces single chunk" {
  let c = chunks(8, 8, 0)
  assert_eq(c.length(), 1)
  assert_eq(c[0], (ChunkSize64, 0UL))
}

///|
test "chunks: 4-byte access with 1-byte alignment produces 4 chunks" {
  let c = chunks(4, 1, 0)
  assert_eq(c.length(), 4)
  assert_eq(c[0], (ChunkSize8, 0UL))
  assert_eq(c[1], (ChunkSize8, 1UL))
  assert_eq(c[2], (ChunkSize8, 2UL))
  assert_eq(c[3], (ChunkSize8, 3UL))
}

///|
test "chunks: 4-byte access with 2-byte alignment produces 2 chunks" {
  let c = chunks(4, 2, 0)
  assert_eq(c.length(), 2)
  assert_eq(c[0], (ChunkSize16, 0UL))
  assert_eq(c[1], (ChunkSize16, 2UL))
}

///|
test "chunks: 8-byte access with 1-byte alignment produces 8 chunks" {
  let c = chunks(8, 1, 0)
  assert_eq(c.length(), 8)
  for i = 0; i < 8; i = i + 1 {
    assert_eq(c[i], (ChunkSize8, i.to_uint64()))
  }
}

///|
test "chunks: 8-byte access with 2-byte alignment produces 4 chunks" {
  let c = chunks(8, 2, 0)
  assert_eq(c.length(), 4)
  assert_eq(c[0], (ChunkSize16, 0UL))
  assert_eq(c[1], (ChunkSize16, 2UL))
  assert_eq(c[2], (ChunkSize16, 4UL))
  assert_eq(c[3], (ChunkSize16, 6UL))
}

///|
test "chunks: 8-byte access with 4-byte alignment produces 2 chunks" {
  let c = chunks(8, 4, 0)
  assert_eq(c.length(), 2)
  assert_eq(c[0], (ChunkSize32, 0UL))
  assert_eq(c[1], (ChunkSize32, 4UL))
}

///|
test "chunks: unaligned offset affects chunking" {
  let c = chunks(4, 4, 1)
  assert_true(c.length() > 1)
}

// ============================================================
// Tests for aligned loads (should pass through unchanged)
// ============================================================

///|
test "aligned i32 load passes through" {
  let instr = TInstr::load(
    LoadOp::i32_load(),
    MemArg::new(U32(4), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TLoad(I32LoadOp, MemArg(U32(4), None, U64(0)), _)) => ()
    _ => fail("Expected unchanged aligned load")
  }
}

///|
test "aligned i64 load passes through" {
  let instr = TInstr::load(
    LoadOp::i64_load(),
    MemArg::new(U32(8), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TLoad(I64LoadOp, MemArg(U32(8), None, U64(0)), _)) => ()
    _ => fail("Expected unchanged aligned load")
  }
}

///|
test "aligned f32 load passes through" {
  let instr = TInstr::load(
    LoadOp::f32_load(),
    MemArg::new(U32(4), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TLoad(F32LoadOp, MemArg(U32(4), None, U64(0)), _)) => ()
    _ => fail("Expected unchanged aligned load")
  }
}

///|
test "aligned f64 load passes through" {
  let instr = TInstr::load(
    LoadOp::f64_load(),
    MemArg::new(U32(8), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TLoad(F64LoadOp, MemArg(U32(8), None, U64(0)), _)) => ()
    _ => fail("Expected unchanged aligned load")
  }
}

// ============================================================
// Tests for unaligned loads (should be split)
// ============================================================

///|
test "unaligned i32 load with align=1 is split" {
  let instr = TInstr::load(
    LoadOp::i32_load(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TLoad(_, _, _)) => fail("Expected split load, got single load")
    Ok(TBinary(I32OrOp, _, _)) => ()
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned i32 load with align=2 is split into 2 loads" {
  let instr = TInstr::load(
    LoadOp::i32_load(),
    MemArg::new(U32(2), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBinary(I32OrOp, _, _)) => ()
    Ok(TLoad(_, _, _)) => fail("Expected split load")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned i64 load with align=1 is split" {
  let instr = TInstr::load(
    LoadOp::i64_load(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBinary(I64OrOp, _, _)) => ()
    Ok(TLoad(_, _, _)) => fail("Expected split load")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned i64 load with align=4 is split into 2 loads" {
  let instr = TInstr::load(
    LoadOp::i64_load(),
    MemArg::new(U32(4), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBinary(I64OrOp, _, _)) => ()
    Ok(TLoad(_, _, _)) => fail("Expected split load")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned f32 load produces reinterpret wrapper" {
  let instr = TInstr::load(
    LoadOp::f32_load(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TUnary(F32ReinterpretI32Op, _)) => ()
    Ok(TLoad(_, _, _)) => fail("Expected split load with reinterpret")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned f64 load produces reinterpret wrapper" {
  let instr = TInstr::load(
    LoadOp::f64_load(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TUnary(F64ReinterpretI64Op, _)) => ()
    Ok(TLoad(_, _, _)) => fail("Expected split load with reinterpret")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for partial loads (i32.load8, i32.load16, etc.)
// ============================================================

///|
test "i32.load8 always passes through (naturally aligned)" {
  let instr = TInstr::load(
    LoadOp::i32_load8u(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TLoad(I32Load8UOp, _, _)) => ()
    _ => fail("Expected unchanged i32.load8")
  }
}

///|
test "i32.load16 with align=1 is split" {
  let instr = TInstr::load(
    LoadOp::i32_load16u(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBinary(I32OrOp, _, _)) => ()
    Ok(TLoad(I32Load16UOp, MemArg(U32(2), _, _), _)) =>
      fail("Expected split load")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "i64.load32 with align=2 is split" {
  let instr = TInstr::load(
    LoadOp::i64_load32u(),
    MemArg::new(U32(2), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBinary(I64OrOp, _, _)) => ()
    Ok(TLoad(_, _, _)) => fail("Expected split load")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for aligned stores (should pass through unchanged)
// ============================================================

///|
test "aligned i32 store passes through" {
  let instr = TInstr::store(
    StoreOp::i32_store(),
    MemArg::new(U32(4), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(42)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TStore(I32StoreOp, MemArg(U32(4), None, U64(0)), _, _)) => ()
    _ => fail("Expected unchanged aligned store")
  }
}

///|
test "aligned i64 store passes through" {
  let instr = TInstr::store(
    StoreOp::i64_store(),
    MemArg::new(U32(8), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i64_const(I64(42)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TStore(I64StoreOp, MemArg(U32(8), None, U64(0)), _, _)) => ()
    _ => fail("Expected unchanged aligned store")
  }
}

///|
test "aligned f32 store passes through" {
  let instr = TInstr::store(
    StoreOp::f32_store(),
    MemArg::new(U32(4), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::f32_const(F32(3.14)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TStore(F32StoreOp, MemArg(U32(4), None, U64(0)), _, _)) => ()
    _ => fail("Expected unchanged aligned store")
  }
}

// ============================================================
// Tests for unaligned stores (should be split into block)
// ============================================================

///|
test "unaligned i32 store with align=1 produces block" {
  let instr = TInstr::store(
    StoreOp::i32_store(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(42)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBlock(VoidBlockType, _)) => ()
    Ok(TStore(_, _, _, _)) => fail("Expected block with split stores")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned i32 store with align=2 produces block" {
  let instr = TInstr::store(
    StoreOp::i32_store(),
    MemArg::new(U32(2), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(42)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBlock(VoidBlockType, _)) => ()
    Ok(TStore(_, _, _, _)) => fail("Expected block with split stores")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned i64 store with align=1 produces block" {
  let instr = TInstr::store(
    StoreOp::i64_store(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i64_const(I64(42)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBlock(VoidBlockType, _)) => ()
    Ok(TStore(_, _, _, _)) => fail("Expected block with split stores")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned f32 store produces block with reinterpret" {
  let instr = TInstr::store(
    StoreOp::f32_store(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::f32_const(F32(3.14)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBlock(VoidBlockType, { instrs, .. })) =>
      assert_true(instrs.length() > 2)
    Ok(TStore(_, _, _, _)) => fail("Expected block with split stores")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned f64 store produces block with reinterpret" {
  let instr = TInstr::store(
    StoreOp::f64_store(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::f64_const(F64(3.14)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBlock(VoidBlockType, { instrs, .. })) =>
      assert_true(instrs.length() > 2)
    Ok(TStore(_, _, _, _)) => fail("Expected block with split stores")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for store block structure
// ============================================================

///|
test "unaligned i32 store block has correct structure" {
  let instr = TInstr::store(
    StoreOp::i32_store(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(0x12345678)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBlock(VoidBlockType, { instrs, .. })) => {
      match instrs[0] {
        TLocalSet(_, _) => ()
        other => fail("Expected TLocalSet, got \{other}")
      }
      match instrs[1] {
        TLocalSet(_, _) => ()
        other => fail("Expected TLocalSet, got \{other}")
      }
      for i = 2; i < instrs.length(); i = i + 1 {
        match instrs[i] {
          TStore(_, _, _, _) => ()
          other => fail("Expected TStore at index \{i}, got \{other}")
        }
      }
      // 2 local.set + 4 byte stores for align=1
      assert_eq(instrs.length(), 6)
    }
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for V128 operations
// ============================================================

///|
test "v128 load with size > 8 passes through" {
  let instr = TInstr::load(
    LoadOp::v128_load(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TLoad(V128LoadOp, _, _)) => ()
    _ => fail("Expected v128 load to pass through (size > 8)")
  }
}

///|
test "v128 store with size > 8 passes through" {
  let instr = TInstr::store(
    StoreOp::v128_store(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TStore(V128StoreOp, _, _, _)) => ()
    _ => fail("Expected v128 store to pass through (size > 8)")
  }
}

// ============================================================
// Tests for V128 load splat operations
// ============================================================

///|
test "v128.load64_splat aligned passes through" {
  let instr = TInstr::load(
    LoadOp::v128_load64_splat(),
    MemArg::new(U32(8), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TLoad(V128Load64SplatOp, _, _)) => ()
    _ => fail("Expected aligned v128.load64_splat to pass through")
  }
}

///|
test "v128.load64_splat unaligned produces splat wrapper" {
  let instr = TInstr::load(
    LoadOp::v128_load64_splat(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TI64x2Splat(_)) => ()
    Ok(TLoad(V128Load64SplatOp, _, _)) => fail("Expected unaligned to be split")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "v128.load32_splat unaligned produces splat wrapper" {
  let instr = TInstr::load(
    LoadOp::v128_load32_splat(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TI32x4Splat(_)) => ()
    Ok(TLoad(V128Load32SplatOp, _, _)) => fail("Expected unaligned to be split")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for V128 load zero operations
// ============================================================

///|
test "v128.load64_zero unaligned produces replace_lane" {
  let instr = TInstr::load(
    LoadOp::v128_load64_zero(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TReplaceLane(I64x2ReplaceLaneOp, LaneIdx(0), _, _)) => ()
    Ok(TLoad(V128Load64ZeroOp, _, _)) => fail("Expected unaligned to be split")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "v128.load32_zero unaligned produces replace_lane" {
  let instr = TInstr::load(
    LoadOp::v128_load32_zero(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TReplaceLane(I32x4ReplaceLaneOp, LaneIdx(0), _, _)) => ()
    Ok(TLoad(V128Load32ZeroOp, _, _)) => fail("Expected unaligned to be split")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "v128 extending loads aligned pass through for all variants" {
  match assert_v128_extending_load_passes_through(LoadOp::v128_load8x8s()) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match assert_v128_extending_load_passes_through(LoadOp::v128_load8x8u()) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match assert_v128_extending_load_passes_through(LoadOp::v128_load16x4s()) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match assert_v128_extending_load_passes_through(LoadOp::v128_load16x4u()) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match assert_v128_extending_load_passes_through(LoadOp::v128_load32x2s()) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match assert_v128_extending_load_passes_through(LoadOp::v128_load32x2u()) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
}

///|
test "v128 extending loads unaligned use extend-low lowering" {
  let unaligned = MemArg::new(U32(1), None, U64(0))
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load8x8s(),
      UnaryOp::i16x8_extend_low_i8x16s(),
      unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load8x8u(),
      UnaryOp::i16x8_extend_low_i8x16u(),
      unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load16x4s(),
      UnaryOp::i32x4_extend_low_i16x8s(),
      unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load16x4u(),
      UnaryOp::i32x4_extend_low_i16x8u(),
      unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load32x2s(),
      UnaryOp::i64x2_extend_low_i32x4s(),
      unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load32x2u(),
      UnaryOp::i64x2_extend_low_i32x4u(),
      unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
}

///|
test "v128 extending loads lower on offset misalignment with max align" {
  let offset_unaligned = MemArg::new(U32(8), None, U64(1))
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load8x8s(),
      UnaryOp::i16x8_extend_low_i8x16s(),
      offset_unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load8x8u(),
      UnaryOp::i16x8_extend_low_i8x16u(),
      offset_unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load16x4s(),
      UnaryOp::i32x4_extend_low_i16x8s(),
      offset_unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load16x4u(),
      UnaryOp::i32x4_extend_low_i16x8u(),
      offset_unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load32x2s(),
      UnaryOp::i64x2_extend_low_i32x4s(),
      offset_unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
  match
    assert_v128_extending_load_is_lowered(
      LoadOp::v128_load32x2u(),
      UnaryOp::i64x2_extend_low_i32x4u(),
      offset_unaligned,
    ) {
    Ok(_) => ()
    Err(e) => fail(e)
  }
}

// ============================================================
// Tests for V128LoadLane operations
// ============================================================

///|
test "v128.load8_lane aligned passes through" {
  let instr = TInstr::v128_load_lane(
    V128LoadLaneOp::v128_load8_lane(),
    MemArg::new(U32(1), None, U64(0)),
    LaneIdx::new(0),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TV128LoadLane(V128Load8LaneOp, _, _, _, _)) => ()
    _ => fail("Expected aligned v128.load8_lane to pass through")
  }
}

///|
test "v128.load16_lane unaligned produces replace_lane" {
  let instr = TInstr::v128_load_lane(
    V128LoadLaneOp::v128_load16_lane(),
    MemArg::new(U32(1), None, U64(0)),
    LaneIdx::new(0),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TReplaceLane(I16x8ReplaceLaneOp, LaneIdx(0), _, _)) => ()
    Ok(TV128LoadLane(_, _, _, _, _)) => fail("Expected unaligned to be split")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "v128.load32_lane unaligned produces replace_lane" {
  let instr = TInstr::v128_load_lane(
    V128LoadLaneOp::v128_load32_lane(),
    MemArg::new(U32(1), None, U64(0)),
    LaneIdx::new(0),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TReplaceLane(I32x4ReplaceLaneOp, LaneIdx(0), _, _)) => ()
    Ok(TV128LoadLane(_, _, _, _, _)) => fail("Expected unaligned to be split")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "v128.load64_lane unaligned produces replace_lane" {
  let instr = TInstr::v128_load_lane(
    V128LoadLaneOp::v128_load64_lane(),
    MemArg::new(U32(1), None, U64(0)),
    LaneIdx::new(0),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TReplaceLane(I64x2ReplaceLaneOp, LaneIdx(0), _, _)) => ()
    Ok(TV128LoadLane(_, _, _, _, _)) => fail("Expected unaligned to be split")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for memory index handling
// ============================================================

///|
test "load with explicit memory index" {
  let memories = [
    MemType::new(Limits::i32(1, None)),
    MemType::new(Limits::i64(1, None)),
  ]
  let instr = TInstr::load(
    LoadOp::i32_load(),
    MemArg::new(U32(1), Some(MemIdx::new(1)), U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(memories, instr)
  match result {
    Ok(_) => ()
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "store with explicit memory index" {
  let memories = [
    MemType::new(Limits::i32(1, None)),
    MemType::new(Limits::i64(1, None)),
  ]
  let instr = TInstr::store(
    StoreOp::i32_store(),
    MemArg::new(U32(1), Some(MemIdx::new(1)), U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(42)),
  )
  let result = run_pass(memories, instr)
  match result {
    Ok(_) => ()
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "invalid memory index returns error" {
  let instr = TInstr::load(
    LoadOp::i32_load(),
    MemArg::new(U32(1), Some(MemIdx::new(99)), U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Err(_) => ()
    Ok(_) => fail("Expected error for invalid memory index")
  }
}

// ============================================================
// Tests for local allocation in function context
// ============================================================

///|
test "unaligned load allocates new local for pointer" {
  let initial_locals : Array[ValType] = [ValType::i32()]
  let body = [
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(1), None, U64(0)),
      TInstr::local_get(LocalIdx::new(0)),
    ),
  ]
  let result = run_func_pass(make_i32_mem(), initial_locals, body)
  match result {
    Ok((new_locals, _)) => {
      // Original local + 1 pointer local
      assert_eq(new_locals.length(), 2)
      assert_eq(new_locals[1], ValType::i32())
    }
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "unaligned store allocates locals for pointer and value" {
  let initial_locals : Array[ValType] = [ValType::i32()]
  let body = [
    TInstr::store(
      StoreOp::i32_store(),
      MemArg::new(U32(1), None, U64(0)),
      TInstr::local_get(LocalIdx::new(0)),
      TInstr::i32_const(I32(42)),
    ),
  ]
  let result = run_func_pass(make_i32_mem(), initial_locals, body)
  match result {
    Ok((new_locals, _)) =>
      // Original local + pointer local + value local
      assert_eq(new_locals.length(), 3)
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "i64 store allocates i64 value local" {
  let initial_locals : Array[ValType] = [ValType::i32()]
  let body = [
    TInstr::store(
      StoreOp::i64_store(),
      MemArg::new(U32(1), None, U64(0)),
      TInstr::local_get(LocalIdx::new(0)),
      TInstr::i64_const(I64(42)),
    ),
  ]
  let result = run_func_pass(make_i32_mem(), initial_locals, body)
  match result {
    Ok((new_locals, _)) => {
      assert_eq(new_locals.length(), 3)
      assert_eq(new_locals[1], ValType::i32()) // pointer
      assert_eq(new_locals[2], ValType::i64()) // value
    }
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for sign extension in loads
// ============================================================

///|
test "i32.load8_s unaligned produces sign extension" {
  let instr = TInstr::load(
    LoadOp::i32_load8s(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TUnary(I32Extend8SOp, _)) => ()
    Ok(TLoad(I32Load8SOp, _, _)) => () // Also valid - single byte is already aligned
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "i32.load16_s unaligned produces sign extension" {
  let instr = TInstr::load(
    LoadOp::i32_load16s(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TUnary(I32Extend16SOp, _)) => ()
    Ok(TLoad(I32Load16SOp, _, _)) => fail("Expected sign extension wrapper")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "i64.load32_s unaligned produces sign extension" {
  let instr = TInstr::load(
    LoadOp::i64_load32s(),
    MemArg::new(U32(1), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TUnary(I64Extend32SOp, _)) => ()
    Ok(TLoad(I64Load32SOp, _, _)) => fail("Expected sign extension wrapper")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for offset handling
// ============================================================

///|
test "load with non-zero offset" {
  let instr = TInstr::load(
    LoadOp::i32_load(),
    MemArg::new(U32(1), None, U64(100)),
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBinary(I32OrOp, _, _)) => ()
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

///|
test "store with non-zero offset" {
  let instr = TInstr::store(
    StoreOp::i32_store(),
    MemArg::new(U32(1), None, U64(100)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::i32_const(I32(42)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBlock(VoidBlockType, _)) => ()
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for nested instruction transformation
// ============================================================

///|
test "nested instructions are transformed" {
  // Load inside a store
  let instr = TInstr::store(
    StoreOp::i32_store(),
    MemArg::new(U32(4), None, U64(0)),
    TInstr::local_get(LocalIdx::new(0)),
    TInstr::load(
      LoadOp::i32_load(),
      MemArg::new(U32(1), None, U64(0)),
      TInstr::local_get(LocalIdx::new(1)),
    ),
  )
  let result = run_pass(make_i32_mem(), instr)
  // The inner load should be transformed even if outer store is aligned
  match result {
    Ok(TStore(I32StoreOp, _, _, TBinary(I32OrOp, _, _))) => ()
    Ok(TStore(I32StoreOp, _, _, TLoad(I32LoadOp, _, _))) =>
      fail("Inner load should have been transformed")
    Ok(other) => fail("Unexpected result: \{other}")
    Err(e) => fail("Error: \{e}")
  }
}

// ============================================================
// Tests for helper functions
// ============================================================

///|
test "size_of_load_op returns correct sizes" {
  assert_eq(size_of_load_op(LoadOp::i32_load()), 4)
  assert_eq(size_of_load_op(LoadOp::i64_load()), 8)
  assert_eq(size_of_load_op(LoadOp::f32_load()), 4)
  assert_eq(size_of_load_op(LoadOp::f64_load()), 8)
  assert_eq(size_of_load_op(LoadOp::i32_load8u()), 1)
  assert_eq(size_of_load_op(LoadOp::i32_load8s()), 1)
  assert_eq(size_of_load_op(LoadOp::i32_load16u()), 2)
  assert_eq(size_of_load_op(LoadOp::i32_load16s()), 2)
  assert_eq(size_of_load_op(LoadOp::i64_load8u()), 1)
  assert_eq(size_of_load_op(LoadOp::i64_load16u()), 2)
  assert_eq(size_of_load_op(LoadOp::i64_load32u()), 4)
  assert_eq(size_of_load_op(LoadOp::v128_load()), 16)
}

///|
test "size_of_store_op returns correct sizes" {
  assert_eq(size_of_store_op(StoreOp::i32_store()), 4)
  assert_eq(size_of_store_op(StoreOp::i64_store()), 8)
  assert_eq(size_of_store_op(StoreOp::f32_store()), 4)
  assert_eq(size_of_store_op(StoreOp::f64_store()), 8)
  assert_eq(size_of_store_op(StoreOp::i32_store8()), 1)
  assert_eq(size_of_store_op(StoreOp::i32_store16()), 2)
  assert_eq(size_of_store_op(StoreOp::i64_store8()), 1)
  assert_eq(size_of_store_op(StoreOp::i64_store16()), 2)
  assert_eq(size_of_store_op(StoreOp::i64_store32()), 4)
  assert_eq(size_of_store_op(StoreOp::v128_store()), 16)
}

///|
test "ChunkSize::byte_count returns correct values" {
  assert_eq(ChunkSize8.byte_count(), 1)
  assert_eq(ChunkSize16.byte_count(), 2)
  assert_eq(ChunkSize32.byte_count(), 4)
  assert_eq(ChunkSize64.byte_count(), 8)
}

///|
test "load_op_stack_size returns correct stack sizes" {
  assert_eq(load_op_stack_size(LoadOp::i32_load()), StackSize32)
  assert_eq(load_op_stack_size(LoadOp::i64_load()), StackSize64)
  assert_eq(load_op_stack_size(LoadOp::f32_load()), StackSize32)
  assert_eq(load_op_stack_size(LoadOp::f64_load()), StackSize64)
  assert_eq(load_op_stack_size(LoadOp::i32_load()), StackSize32)
  assert_eq(load_op_stack_size(LoadOp::i64_load8u()), StackSize64)
}

///|
test "store_op_stack_size returns correct stack sizes" {
  assert_eq(store_op_stack_size(StoreOp::i32_store()), StackSize32)
  assert_eq(store_op_stack_size(StoreOp::i64_store()), StackSize64)
  assert_eq(store_op_stack_size(StoreOp::f32_store()), StackSize32)
  assert_eq(store_op_stack_size(StoreOp::f64_store()), StackSize64)
  assert_eq(store_op_stack_size(StoreOp::i32_store8()), StackSize32)
  assert_eq(store_op_stack_size(StoreOp::i64_store8()), StackSize64)
}

// ============================================================
// Tests for edge cases
// ============================================================

///|
test "align clamped to op_size" {
  // If align > op_size, it should be clamped to op_size
  let instr = TInstr::load(
    LoadOp::i32_load(),
    MemArg::new(U32(8), None, U64(0)), // align=8 but i32 is only 4 bytes
    TInstr::local_get(LocalIdx::new(0)),
  )
  let result = run_pass(make_i32_mem(), instr)
  // Should be treated as aligned (4 >= 4)
  match result {
    Ok(TLoad(I32LoadOp, MemArg(U32(8), _, _), _)) => ()
    _ => fail("Expected load to pass through")
  }
}

///|
test "other instructions pass through unchanged" {
  let instr = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
  )
  let result = run_pass(make_i32_mem(), instr)
  match result {
    Ok(TBinary(I32AddOp, TI32Const(I32(1)), TI32Const(I32(2)))) => ()
    _ => fail("Expected binary op to pass through unchanged")
  }
}

///|
test "nop passes through unchanged" {
  let result = run_pass(make_i32_mem(), TInstr::nop())
  match result {
    Ok(TNop) => ()
    _ => fail("Expected nop to pass through")
  }
}

///|
test "unreachable passes through unchanged" {
  let result = run_pass(make_i32_mem(), TInstr::unreachable_())
  match result {
    Ok(TUnreachable) => ()
    _ => fail("Expected unreachable to pass through")
  }
}
