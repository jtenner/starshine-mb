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
fn oi_is_power_of_2_i32(x : Int) -> Bool {
  x > 0 && (x & (x - 1)) == 0
}

///|
fn oi_is_power_of_2_i64(x : Int64) -> Bool {
  x > 0L && (x & (x - 1L)) == 0L
}

///|
fn oi_log2_i32(x : Int) -> Int {
  x.ctz()
}

///|
fn oi_log2_i64(x : Int64) -> Int64 {
  x.ctz().to_int64()
}

///|
fn oi_wrap_i32(x : Int) -> Int {
  (x.reinterpret_as_uint() & 0xffffffff).reinterpret_as_int()
}

///|
fn oi_wrap_i64(x : Int64) -> Int64 {
  x.reinterpret_as_uint64().reinterpret_as_int64()
}

///|
fn oi_const_i32(instr : TInstr) -> Int? {
  match instr.kind {
    TInstrKind::TI32Const(I32(v)) => Some(v)
    _ => None
  }
}

///|
fn oi_is_const(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_) => true
    _ => false
  }
}

///|
fn oi_instr_stmt(instr : TInstr, env : Env) -> TInstr {
  match lcs_infer_tinstr_type(instr, env) {
    Some(_) => TInstr::drop(instr)
    None => instr
  }
}

///|
fn oi_seq(stmts : Array[TInstr], result : TInstr, env : Env) -> TInstr {
  if stmts.is_empty() {
    result
  } else if stmts.length() == 1 {
    let bt = match lcs_infer_tinstr_type(result, env) {
      Some(vt) => BlockType::val_type(vt)
      None => BlockType::void_()
    }
    TInstr::block(bt, TExpr::new([stmts[0], result]))
  } else {
    let list = stmts.copy()
    list.push(result)
    let bt = match lcs_infer_tinstr_type(result, env) {
      Some(vt) => BlockType::val_type(vt)
      None => BlockType::void_()
    }
    TInstr::block(bt, TExpr::new(list))
  }
}

///|
priv struct OIEffectsSummary {
  locals_read : Array[UInt64]
  locals_written : Array[UInt64]
  unknown_locals_read : Bool
  unknown_locals_written : Bool
  reads_memory : Bool
  writes_memory : Bool
  reads_globals : Bool
  writes_globals : Bool
  calls : Bool
  branches : Bool
  traps : Bool
  throws : Bool
  has_side_effects : Bool
}

///|
fn OIEffectsSummary::transfers_control_flow(self : OIEffectsSummary) -> Bool {
  self.branches || self.throws
}

///|
fn OIEffectsSummary::has_local_reads(self : OIEffectsSummary) -> Bool {
  self.unknown_locals_read || oi_local_bits_any(self.locals_read)
}

///|
fn OIEffectsSummary::has_local_writes(self : OIEffectsSummary) -> Bool {
  self.unknown_locals_written || oi_local_bits_any(self.locals_written)
}

///|
fn OIEffectsSummary::has_local_access(self : OIEffectsSummary) -> Bool {
  self.has_local_reads() || self.has_local_writes()
}

///|
fn OIEffectsSummary::invalidates(
  self : OIEffectsSummary,
  other : OIEffectsSummary,
) -> Bool {
  if self.unknown_locals_written && other.has_local_access() {
    return true
  }
  if other.unknown_locals_written && self.has_local_access() {
    return true
  }
  if self.unknown_locals_read && other.has_local_writes() {
    return true
  }
  if other.unknown_locals_read && self.has_local_writes() {
    return true
  }
  if oi_local_bits_intersects(self.locals_written, other.locals_read) ||
    oi_local_bits_intersects(self.locals_written, other.locals_written) ||
    oi_local_bits_intersects(self.locals_read, other.locals_written) {
    return true
  }
  if (self.reads_memory && other.writes_memory) ||
    (self.writes_memory && other.reads_memory) ||
    (self.writes_memory && other.writes_memory) {
    return true
  }
  if (self.reads_globals && other.writes_globals) ||
    (self.writes_globals && other.reads_globals) ||
    (self.writes_globals && other.writes_globals) {
    return true
  }
  if self.calls || other.calls {
    if self.reads_memory ||
      self.writes_memory ||
      other.reads_memory ||
      other.writes_memory ||
      self.reads_globals ||
      self.writes_globals ||
      other.reads_globals ||
      other.writes_globals {
      return true
    }
  }
  if self.transfers_control_flow() || other.transfers_control_flow() {
    return true
  }
  if (self.traps && other.has_side_effects) ||
    (other.traps && self.has_side_effects) {
    return true
  }
  false
}

///|
priv struct OIPairCacheEntry {
  low_id : Int
  high_id : Int
  value : Bool
  valid : Bool
}

///|
priv struct OINodeIdEntry {
  instr : TInstr
  node_id : Int
  fingerprint : UInt64
}

///|
priv struct OIRewriteCache {
  node_ids_by_hash : Map[UInt64, Array[OINodeIdEntry]]
  size_by_id : Array[Int]
  effects_by_id : Array[OIEffectsSummary]
  fingerprint_by_id : Array[UInt64]
  reorder_by_pair : Array[OIPairCacheEntry]
  eq_by_pair : Array[OIPairCacheEntry]
  local_bit_words : Int
  local_bits_pool : Map[UInt64, Array[Array[UInt64]]]
  mut node_id_get_calls : Int
  mut node_id_put_calls : Int
  mut eq_calls : Int
  mut reorder_calls : Int
  mut node_id_lookup_us : UInt64
  mut fingerprint_us : UInt64
  mut register_us : UInt64
  mut eq_us : UInt64
  mut reorder_us : UInt64
  mut max_body_len : Int
}

///|
let oi_hash_seed = 1469598103934665603UL

///|
let oi_hash_prime = 1099511628211UL

///|
fn oi_hash_mix(seed : UInt64, value : UInt64) -> UInt64 {
  (seed ^ value) * oi_hash_prime
}

///|
fn oi_trace_elapsed_us_since(start_us : UInt64) -> UInt64 {
  let end_us = oi_trace_now_us()
  if end_us >= start_us {
    end_us - start_us
  } else {
    0UL
  }
}

///|
fn oi_hash_bool(value : Bool) -> UInt64 {
  if value {
    1UL
  } else {
    0UL
  }
}

///|
fn oi_hash_int(value : Int) -> UInt64 {
  value.reinterpret_as_uint().to_uint64()
}

///|
fn oi_instr_shallow_tag_hash(instr : TInstr) -> UInt64 {
  let tag : UInt64 = match instr.kind {
    TInstrKind::TI32Const(_) => 1UL
    TInstrKind::TI64Const(_) => 2UL
    TInstrKind::TF32Const(_) => 3UL
    TInstrKind::TF64Const(_) => 4UL
    TInstrKind::TRefNull(_) => 5UL
    TInstrKind::TRefFunc(_) => 6UL
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      7UL
    TInstrKind::TUnreachable => 8UL
    TInstrKind::TNop => 9UL
    TInstrKind::TLocalGet(_) => 10UL
    TInstrKind::TGlobalGet(_) => 11UL
    TInstrKind::TMemorySize(_) => 12UL
    TInstrKind::TTableSize(_) => 13UL
    TInstrKind::TUnary(_, _) => 14UL
    TInstrKind::TDrop(_) => 15UL
    TInstrKind::TLocalSet(_, _) => 16UL
    TInstrKind::TLocalTee(_, _) => 17UL
    TInstrKind::TGlobalSet(_, _) => 18UL
    TInstrKind::TRefIsNull(_) => 19UL
    TInstrKind::TRefAsNonNull(_) => 20UL
    TInstrKind::TI31GetS(_) => 21UL
    TInstrKind::TI31GetU(_) => 22UL
    TInstrKind::TRefI31(_) => 23UL
    TInstrKind::TArrayLen(_) => 24UL
    TInstrKind::TAnyConvertExtern(_) => 25UL
    TInstrKind::TExternConvertAny(_) => 26UL
    TInstrKind::TThrowRef(_) => 27UL
    TInstrKind::TBinary(_, _, _) => 28UL
    TInstrKind::TRefEq(_, _) => 29UL
    TInstrKind::TStore(_, _, _, _) => 30UL
    TInstrKind::TLoad(_, _, _) => 31UL
    TInstrKind::TMemoryGrow(_, _) => 32UL
    TInstrKind::TMemoryAtomicNotify(_, _, _) => 33UL
    TInstrKind::TMemoryAtomicWait32(_, _, _, _) => 34UL
    TInstrKind::TMemoryAtomicWait64(_, _, _, _) => 35UL
    TInstrKind::TAtomicFence => 36UL
    TInstrKind::TAtomicRmw(_, _, _, _) => 37UL
    TInstrKind::TAtomicCmpxchg(_, _, _, _, _) => 38UL
    TInstrKind::TMemoryFill(_, _, _, _) => 39UL
    TInstrKind::TMemoryCopy(_, _, _, _, _) => 40UL
    TInstrKind::TMemoryInit(_, _, _, _, _) => 41UL
    TInstrKind::TDataDrop(_) => 42UL
    TInstrKind::TTableGet(_, _) => 43UL
    TInstrKind::TTableSet(_, _, _) => 44UL
    TInstrKind::TTableGrow(_, _, _) => 45UL
    TInstrKind::TTableFill(_, _, _, _) => 46UL
    TInstrKind::TTableCopy(_, _, _, _, _) => 47UL
    TInstrKind::TTableInit(_, _, _, _, _) => 48UL
    TInstrKind::TElemDrop(_) => 49UL
    TInstrKind::TCall(_, _) => 50UL
    TInstrKind::TCallIndirect(_, _, _, _) => 51UL
    TInstrKind::TCallRef(_, _, _) => 52UL
    TInstrKind::TReturnCall(_, _) => 53UL
    TInstrKind::TReturnCallIndirect(_, _, _, _) => 54UL
    TInstrKind::TReturnCallRef(_, _, _) => 55UL
    TInstrKind::TBlock(_, _) => 56UL
    TInstrKind::TLoop(_, _) => 57UL
    TInstrKind::TIf(_, _, _, _) => 58UL
    TInstrKind::TTryTable(_, _, _) => 59UL
    TInstrKind::TThrow(_, _) => 60UL
    TInstrKind::TBr(_, _) => 61UL
    TInstrKind::TBrIf(_, _, _) => 62UL
    TInstrKind::TBrTable(_, _, _, _) => 63UL
    TInstrKind::TBrOnNull(_, _, _) => 64UL
    TInstrKind::TBrOnNonNull(_, _, _) => 65UL
    TInstrKind::TBrOnCast(_, _, _, _, _, _) => 66UL
    TInstrKind::TBrOnCastFail(_, _, _, _, _, _) => 67UL
    TInstrKind::TReturn(_) => 68UL
    TInstrKind::TSelect(_, _, _, _) => 69UL
    TInstrKind::TStructNew(_, _) => 70UL
    TInstrKind::TStructNewDefault(_) => 71UL
    TInstrKind::TStructGet(_, _, _) => 72UL
    TInstrKind::TStructGetS(_, _, _) => 73UL
    TInstrKind::TStructGetU(_, _, _) => 74UL
    TInstrKind::TStructSet(_, _, _, _) => 75UL
    TInstrKind::TArrayNew(_, _, _) => 76UL
    TInstrKind::TArrayNewDefault(_, _) => 77UL
    TInstrKind::TArrayNewFixed(_, _) => 78UL
    TInstrKind::TArrayNewData(_, _, _, _) => 79UL
    TInstrKind::TArrayNewElem(_, _, _, _) => 80UL
    TInstrKind::TArrayGet(_, _, _) => 81UL
    TInstrKind::TArrayGetS(_, _, _) => 82UL
    TInstrKind::TArrayGetU(_, _, _) => 83UL
    TInstrKind::TArraySet(_, _, _, _) => 84UL
    TInstrKind::TArrayFill(_, _, _, _, _) => 85UL
    TInstrKind::TArrayCopy(_, _, _, _, _, _, _) => 86UL
    TInstrKind::TArrayInitData(_, _, _, _, _, _) => 87UL
    TInstrKind::TArrayInitElem(_, _, _, _, _, _) => 88UL
    TInstrKind::TRefTest(_, _, _) => 89UL
    TInstrKind::TRefCast(_, _, _) => 90UL
    TInstrKind::TRefGetDesc(_) => 91UL
    TInstrKind::TRefTestDesc(_, _, _) => 92UL
    TInstrKind::TRefCastDescEq(_, _, _) => 93UL
    TInstrKind::TI8x16Splat(_) => 94UL
    TInstrKind::TI16x8Splat(_) => 95UL
    TInstrKind::TI32x4Splat(_) => 96UL
    TInstrKind::TI64x2Splat(_) => 97UL
    TInstrKind::TF32x4Splat(_) => 98UL
    TInstrKind::TF64x2Splat(_) => 99UL
    TInstrKind::TExtractLane(_, _, _) => 100UL
    TInstrKind::TReplaceLane(_, _, _, _) => 101UL
    TInstrKind::TI8x16Shuffle(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    ) => 102UL
    TInstrKind::TI8x16Swizzle(_, _) => 103UL
    TInstrKind::TI8x16RelaxedSwizzle(_, _) => 104UL
    TInstrKind::TV128Shift(_, _, _) => 105UL
    TInstrKind::TV128Ternary(_, _, _, _) => 106UL
    TInstrKind::TV128LoadLane(_, _, _, _, _) => 107UL
    TInstrKind::TV128StoreLane(_, _, _, _, _) => 108UL
  }
  tag * 11400714819323198485UL
}

///|
fn oi_instr_shallow_hash(instr : TInstr) -> UInt64 {
  let mut digest = oi_instr_shallow_tag_hash(instr)
  match instr.kind {
    TInstrKind::TI32Const(v) =>
      digest = oi_hash_mix(digest, oi_hash_int(v.hash()))
    TInstrKind::TI64Const(v) =>
      digest = oi_hash_mix(digest, oi_hash_int(v.hash()))
    TInstrKind::TF32Const(v) =>
      digest = oi_hash_mix(digest, oi_hash_int(v.hash()))
    TInstrKind::TF64Const(v) =>
      digest = oi_hash_mix(digest, oi_hash_int(v.hash()))
    TInstrKind::TRefNull(ht) =>
      digest = oi_hash_mix(digest, oi_hash_int(ht.hash()))
    TInstrKind::TRefFunc(idx) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TV128Const(
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
      l15
    ) => {
      digest = oi_hash_mix(digest, oi_hash_int(l0.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l1.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l2.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l3.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l4.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l5.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l6.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l7.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l8.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l9.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l10.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l11.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l12.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l13.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l14.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l15.hash()))
    }
    TInstrKind::TLocalGet(idx) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TMemorySize(idx) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TTableSize(idx) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TMemoryGrow(idx, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TTableGet(idx, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TTableSet(idx, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TTableGrow(idx, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TTableFill(idx, _, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TStructNewDefault(idx) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TStructNew(idx, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TArrayNewDefault(idx, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TArrayNewFixed(idx, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TArrayNew(idx, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TArrayGet(idx, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TArrayGetS(idx, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TArrayGetU(idx, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TArraySet(idx, _, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TArrayFill(idx, _, _, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TGlobalGet(idx) | TInstrKind::TGlobalSet(idx, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TDataDrop(idx) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TElemDrop(idx) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TUnary(op, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
    TInstrKind::TBinary(op, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
    TInstrKind::TV128Shift(op, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
    TInstrKind::TV128Ternary(op, _, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
    TInstrKind::TLocalSet(idx, _) | TInstrKind::TLocalTee(idx, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(idx.hash()))
    TInstrKind::TStore(op, memarg, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(memarg.hash()))
    }
    TInstrKind::TLoad(op, memarg, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(memarg.hash()))
    }
    TInstrKind::TMemoryAtomicNotify(memarg, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(memarg.hash()))
    TInstrKind::TMemoryAtomicWait32(memarg, _, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(memarg.hash()))
    TInstrKind::TMemoryAtomicWait64(memarg, _, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(memarg.hash()))
    TInstrKind::TAtomicRmw(op, memarg, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(memarg.hash()))
    }
    TInstrKind::TAtomicCmpxchg(op, memarg, _, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(memarg.hash()))
    }
    TInstrKind::TMemoryFill(mem_idx, _, _, _) =>
      digest = oi_hash_mix(digest, oi_hash_int(mem_idx.hash()))
    TInstrKind::TMemoryCopy(dst_mem, src_mem, _, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(dst_mem.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(src_mem.hash()))
    }
    TInstrKind::TMemoryInit(data_idx, mem_idx, _, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(data_idx.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(mem_idx.hash()))
    }
    TInstrKind::TTableCopy(dst, src, _, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(dst.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(src.hash()))
    }
    TInstrKind::TTableInit(elem_idx, table_idx, _, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(elem_idx.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(table_idx.hash()))
    }
    TInstrKind::TCall(func_idx, args)
    | TInstrKind::TReturnCall(func_idx, args) => {
      digest = oi_hash_mix(digest, oi_hash_int(func_idx.hash()))
      digest = oi_hash_mix(digest, args.length().to_uint64())
    }
    TInstrKind::TCallIndirect(type_idx, table_idx, args, _)
    | TInstrKind::TReturnCallIndirect(type_idx, table_idx, args, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(type_idx.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(table_idx.hash()))
      digest = oi_hash_mix(digest, args.length().to_uint64())
    }
    TInstrKind::TCallRef(type_idx, args, _)
    | TInstrKind::TReturnCallRef(type_idx, args, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(type_idx.hash()))
      digest = oi_hash_mix(digest, args.length().to_uint64())
    }
    TInstrKind::TBlock(bt, body) | TInstrKind::TLoop(bt, body) => {
      digest = oi_hash_mix(digest, oi_hash_int(bt.hash()))
      digest = oi_hash_mix(digest, body.instrs.length().to_uint64())
    }
    TInstrKind::TIf(bt, _, then_, else_) => {
      digest = oi_hash_mix(digest, oi_hash_int(bt.hash()))
      digest = oi_hash_mix(digest, then_.instrs.length().to_uint64())
      digest = oi_hash_mix(digest, oi_hash_bool(else_ is Some(_)))
      match else_ {
        Some(other) =>
          digest = oi_hash_mix(digest, other.instrs.length().to_uint64())
        None => ()
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      digest = oi_hash_mix(digest, oi_hash_int(bt.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(catches.hash()))
      digest = oi_hash_mix(digest, body.instrs.length().to_uint64())
    }
    TInstrKind::TThrow(tag_idx, args) => {
      digest = oi_hash_mix(digest, oi_hash_int(tag_idx.hash()))
      digest = oi_hash_mix(digest, args.length().to_uint64())
    }
    TInstrKind::TBr(label_idx, args) => {
      digest = oi_hash_mix(digest, oi_hash_int(label_idx.hash()))
      digest = oi_hash_mix(digest, args.length().to_uint64())
    }
    TInstrKind::TBrIf(label_idx, _, values)
    | TInstrKind::TBrOnNull(label_idx, _, values)
    | TInstrKind::TBrOnNonNull(label_idx, _, values) => {
      digest = oi_hash_mix(digest, oi_hash_int(label_idx.hash()))
      digest = oi_hash_mix(digest, values.length().to_uint64())
    }
    TInstrKind::TBrTable(labels, default_, _, values) => {
      digest = oi_hash_mix(digest, oi_hash_int(labels.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(default_.hash()))
      digest = oi_hash_mix(digest, values.length().to_uint64())
    }
    TInstrKind::TBrOnCast(label_idx, castop, ht1, ht2, _, values)
    | TInstrKind::TBrOnCastFail(label_idx, castop, ht1, ht2, _, values) => {
      digest = oi_hash_mix(digest, oi_hash_int(label_idx.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(castop.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(ht1.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(ht2.hash()))
      digest = oi_hash_mix(digest, values.length().to_uint64())
    }
    TInstrKind::TReturn(values) =>
      digest = oi_hash_mix(digest, values.length().to_uint64())
    TInstrKind::TSelect(types, _, _, _) =>
      match types {
        Some(values) => {
          digest = oi_hash_mix(digest, 1UL)
          digest = oi_hash_mix(digest, oi_hash_int(values.hash()))
        }
        None => digest = oi_hash_mix(digest, 0UL)
      }
    TInstrKind::TStructGet(type_idx, field_idx, _)
    | TInstrKind::TStructGetS(type_idx, field_idx, _)
    | TInstrKind::TStructGetU(type_idx, field_idx, _)
    | TInstrKind::TStructSet(type_idx, field_idx, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(type_idx.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(field_idx.hash()))
    }
    TInstrKind::TArrayNewData(type_idx, data_idx, _, _)
    | TInstrKind::TArrayInitData(type_idx, data_idx, _, _, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(type_idx.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(data_idx.hash()))
    }
    TInstrKind::TArrayNewElem(type_idx, elem_idx, _, _)
    | TInstrKind::TArrayInitElem(type_idx, elem_idx, _, _, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(type_idx.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(elem_idx.hash()))
    }
    TInstrKind::TArrayCopy(dst_type, src_type, _, _, _, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(dst_type.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(src_type.hash()))
    }
    TInstrKind::TRefTest(nullable, ht, _)
    | TInstrKind::TRefCast(nullable, ht, _)
    | TInstrKind::TRefTestDesc(nullable, ht, _)
    | TInstrKind::TRefCastDescEq(nullable, ht, _) => {
      digest = oi_hash_mix(digest, oi_hash_bool(nullable))
      digest = oi_hash_mix(digest, oi_hash_int(ht.hash()))
    }
    TInstrKind::TExtractLane(op, lane, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(lane.hash()))
    }
    TInstrKind::TReplaceLane(op, lane, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(lane.hash()))
    }
    TInstrKind::TI8x16Shuffle(
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
      _,
      _
    ) => {
      digest = oi_hash_mix(digest, oi_hash_int(l0.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l1.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l2.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l3.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l4.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l5.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l6.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l7.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l8.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l9.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l10.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l11.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l12.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l13.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l14.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(l15.hash()))
    }
    TInstrKind::TV128LoadLane(op, memarg, lane, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(memarg.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(lane.hash()))
    }
    TInstrKind::TV128StoreLane(op, memarg, lane, _, _) => {
      digest = oi_hash_mix(digest, oi_hash_int(op.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(memarg.hash()))
      digest = oi_hash_mix(digest, oi_hash_int(lane.hash()))
    }
    _ => ()
  }
  digest
}

///|
fn oi_pair_cache_init(size : Int) -> Array[OIPairCacheEntry] {
  let out : Array[OIPairCacheEntry] = Array::new(capacity=size)
  let mut i = 0
  while i < size {
    out.push(OIPairCacheEntry::{
      low_id: 0,
      high_id: 0,
      value: false,
      valid: false,
    })
    i += 1
  }
  out
}

///|
fn oi_pair_cache_key(left_id : Int, right_id : Int) -> (Int, Int) {
  if left_id <= right_id {
    (left_id, right_id)
  } else {
    (right_id, left_id)
  }
}

///|
fn oi_pair_cache_index(low_id : Int, high_id : Int, size : Int) -> Int {
  let low_hash = low_id.to_uint64()
  let high_hash = high_id.to_uint64()
  let mixed = low_hash ^ (high_hash << 1) ^ (high_hash >> 1)
  let folded = (mixed ^ (mixed >> 32)) & 0x7fffffffUL
  folded.to_int() % size
}

///|
fn oi_local_bit_words(local_count : Int) -> Int {
  if local_count <= 0 {
    0
  } else {
    (local_count + 63) / 64
  }
}

///|
fn oi_local_bit_words_tracked(local_count : Int) -> Int {
  let words = oi_local_bit_words(local_count)
  if words <= 16 {
    words
  } else {
    16
  }
}

///|
fn oi_local_idx_to_int(local_idx : LocalIdx) -> Int {
  let LocalIdx(raw) = local_idx
  raw.reinterpret_as_int()
}

///|
fn oi_local_bits_new(word_count : Int) -> Array[UInt64] {
  Array::make(word_count, 0UL)
}

///|
fn oi_local_bits_set(bits : Array[UInt64], local_idx : LocalIdx) -> Bool {
  if bits.length() == 0 {
    return false
  }
  let idx = oi_local_idx_to_int(local_idx)
  if idx < 0 {
    return false
  }
  let word = idx / 64
  if word >= bits.length() {
    return false
  }
  let bit = idx % 64
  bits[word] = bits[word] | (1UL << bit)
  true
}

///|
fn oi_local_bits_or_inplace(dst : Array[UInt64], src : Array[UInt64]) -> Unit {
  let limit = if dst.length() < src.length() {
    dst.length()
  } else {
    src.length()
  }
  for i = 0; i < limit; i = i + 1 {
    dst[i] = dst[i] | src[i]
  }
}

///|
fn oi_local_bits_intersects(a : Array[UInt64], b : Array[UInt64]) -> Bool {
  let limit = if a.length() < b.length() { a.length() } else { b.length() }
  for i = 0; i < limit; i = i + 1 {
    if (a[i] & b[i]) != 0UL {
      return true
    }
  }
  false
}

///|
fn oi_local_bits_any(bits : Array[UInt64]) -> Bool {
  for word in bits {
    if word != 0UL {
      return true
    }
  }
  false
}

///|
fn oi_local_bits_hash(bits : Array[UInt64]) -> UInt64 {
  let mut h = oi_hash_seed
  for word in bits {
    h = h ^ word
    h = h * oi_hash_prime
  }
  h ^ bits.length().to_uint64()
}

///|
fn oi_local_bits_eq(a : Array[UInt64], b : Array[UInt64]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn oi_local_bits_intern(
  bits : Array[UInt64],
  cache : OIRewriteCache,
) -> Array[UInt64] {
  if bits.length() == 0 {
    return bits
  }
  let h = oi_local_bits_hash(bits)
  match cache.local_bits_pool.get(h) {
    Some(existing) => {
      for candidate in existing {
        if oi_local_bits_eq(candidate, bits) {
          return candidate
        }
      }
      existing.push(bits)
      bits
    }
    None => {
      cache.local_bits_pool[h] = [bits]
      bits
    }
  }
}

///|
fn oi_for_each_non_control_child(instr : TInstr, f : (TInstr) -> Unit) -> Unit {
  match instr.kind {
    // Zero-operand instructions.
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TUnreachable
    | TInstrKind::TNop
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TMemorySize(_)
    | TInstrKind::TAtomicFence
    | TInstrKind::TTableSize(_)
    | TInstrKind::TDataDrop(_)
    | TInstrKind::TElemDrop(_)
    | TInstrKind::TStructNewDefault(_) => ()

    // Unary operands.
    TInstrKind::TUnary(_, child)
    | TInstrKind::TDrop(child)
    | TInstrKind::TLocalSet(_, child)
    | TInstrKind::TLocalTee(_, child)
    | TInstrKind::TGlobalSet(_, child)
    | TInstrKind::TRefIsNull(child)
    | TInstrKind::TRefAsNonNull(child)
    | TInstrKind::TI31GetS(child)
    | TInstrKind::TI31GetU(child)
    | TInstrKind::TRefI31(child)
    | TInstrKind::TArrayLen(child)
    | TInstrKind::TAnyConvertExtern(child)
    | TInstrKind::TExternConvertAny(child)
    | TInstrKind::TThrowRef(child)
    | TInstrKind::TMemoryGrow(_, child)
    | TInstrKind::TTableGet(_, child)
    | TInstrKind::TLoad(_, _, child)
    | TInstrKind::TArrayNewDefault(_, child)
    | TInstrKind::TStructGet(_, _, child)
    | TInstrKind::TStructGetS(_, _, child)
    | TInstrKind::TStructGetU(_, _, child)
    | TInstrKind::TI8x16Splat(child)
    | TInstrKind::TI16x8Splat(child)
    | TInstrKind::TI32x4Splat(child)
    | TInstrKind::TI64x2Splat(child)
    | TInstrKind::TF32x4Splat(child)
    | TInstrKind::TF64x2Splat(child)
    | TInstrKind::TExtractLane(_, _, child)
    | TInstrKind::TRefTest(_, _, child)
    | TInstrKind::TRefCast(_, _, child)
    | TInstrKind::TRefGetDesc(child)
    | TInstrKind::TRefTestDesc(_, _, child)
    | TInstrKind::TRefCastDescEq(_, _, child) => f(child)

    // Two operands.
    TInstrKind::TBinary(_, left, right)
    | TInstrKind::TRefEq(left, right)
    | TInstrKind::TStore(_, _, left, right)
    | TInstrKind::TMemoryAtomicNotify(_, left, right)
    | TInstrKind::TAtomicRmw(_, _, left, right)
    | TInstrKind::TTableSet(_, left, right)
    | TInstrKind::TTableGrow(_, left, right)
    | TInstrKind::TStructSet(_, _, left, right)
    | TInstrKind::TArrayNew(_, left, right)
    | TInstrKind::TArrayNewData(_, _, left, right)
    | TInstrKind::TArrayNewElem(_, _, left, right)
    | TInstrKind::TArrayGet(_, left, right)
    | TInstrKind::TArrayGetS(_, left, right)
    | TInstrKind::TArrayGetU(_, left, right)
    | TInstrKind::TReplaceLane(_, _, left, right)
    | TInstrKind::TI8x16Swizzle(left, right)
    | TInstrKind::TI8x16RelaxedSwizzle(left, right)
    | TInstrKind::TV128Shift(_, left, right)
    | TInstrKind::TV128LoadLane(_, _, _, left, right)
    | TInstrKind::TV128StoreLane(_, _, _, left, right) => {
      f(left)
      f(right)
    }

    // Three operands.
    TInstrKind::TMemoryFill(_, a, b, c)
    | TInstrKind::TMemoryCopy(_, _, a, b, c)
    | TInstrKind::TMemoryInit(_, _, a, b, c)
    | TInstrKind::TMemoryAtomicWait32(_, a, b, c)
    | TInstrKind::TMemoryAtomicWait64(_, a, b, c)
    | TInstrKind::TAtomicCmpxchg(_, _, a, b, c)
    | TInstrKind::TTableFill(_, a, b, c)
    | TInstrKind::TTableCopy(_, _, a, b, c)
    | TInstrKind::TTableInit(_, _, a, b, c)
    | TInstrKind::TV128Ternary(_, a, b, c) => {
      f(a)
      f(b)
      f(c)
    }
    TInstrKind::TSelect(_, cond, if_true, if_false) => {
      f(if_true)
      f(if_false)
      f(cond)
    }

    // Variable-length operands.
    TInstrKind::TCall(_, args)
    | TInstrKind::TReturnCall(_, args)
    | TInstrKind::TThrow(_, args)
    | TInstrKind::TBr(_, args)
    | TInstrKind::TReturn(args)
    | TInstrKind::TStructNew(_, args)
    | TInstrKind::TArrayNewFixed(_, args) =>
      for arg in args {
        f(arg)
      }
    TInstrKind::TCallIndirect(_, _, args, index)
    | TInstrKind::TReturnCallIndirect(_, _, args, index) => {
      for arg in args {
        f(arg)
      }
      f(index)
    }
    TInstrKind::TCallRef(_, args, ref_)
    | TInstrKind::TReturnCallRef(_, args, ref_) => {
      for arg in args {
        f(arg)
      }
      f(ref_)
    }
    TInstrKind::TBrIf(_, cond, values) => {
      for value in values {
        f(value)
      }
      f(cond)
    }
    TInstrKind::TBrTable(_, _, index, values) => {
      for value in values {
        f(value)
      }
      f(index)
    }
    TInstrKind::TBrOnNull(_, ref_, values)
    | TInstrKind::TBrOnNonNull(_, ref_, values)
    | TInstrKind::TBrOnCast(_, _, _, _, ref_, values)
    | TInstrKind::TBrOnCastFail(_, _, _, _, ref_, values) => {
      for value in values {
        f(value)
      }
      f(ref_)
    }
    TInstrKind::TArraySet(_, a, b, c) => {
      f(a)
      f(b)
      f(c)
    }
    TInstrKind::TArrayFill(_, a, b, c, d)
    | TInstrKind::TArrayInitData(_, _, a, b, c, d)
    | TInstrKind::TArrayInitElem(_, _, a, b, c, d) => {
      f(a)
      f(b)
      f(c)
      f(d)
    }
    TInstrKind::TArrayCopy(_, _, a, b, c, d, e) => {
      f(a)
      f(b)
      f(c)
      f(d)
      f(e)
    }
    TInstrKind::TI8x16Shuffle(
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      left,
      right
    ) => {
      f(left)
      f(right)
    }

    // Control-flow structures are handled directly by the dedicated walker.
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => ()
  }
}

///|
fn oi_rebuild_non_control(instr : TInstr, children : Array[TInstr]) -> TInstr {
  match instr.kind {
    // Zero-operand instructions.
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_)
    | TInstrKind::TRefNull(_)
    | TInstrKind::TRefFunc(_)
    | TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TInstrKind::TUnreachable
    | TInstrKind::TNop
    | TInstrKind::TLocalGet(_)
    | TInstrKind::TGlobalGet(_)
    | TInstrKind::TMemorySize(_)
    | TInstrKind::TAtomicFence
    | TInstrKind::TTableSize(_)
    | TInstrKind::TDataDrop(_)
    | TInstrKind::TElemDrop(_)
    | TInstrKind::TStructNewDefault(_) => instr

    // Unary operands.
    TInstrKind::TUnary(op, _) => TInstr::unary(op, children[0])
    TInstrKind::TDrop(_) => TInstr::drop(children[0])
    TInstrKind::TLocalSet(idx, _) => TInstr::local_set(idx, children[0])
    TInstrKind::TLocalTee(idx, _) => TInstr::local_tee(idx, children[0])
    TInstrKind::TGlobalSet(idx, _) => TInstr::global_set(idx, children[0])
    TInstrKind::TRefIsNull(_) => TInstr::ref_is_null(children[0])
    TInstrKind::TRefAsNonNull(_) => TInstr::ref_as_non_null(children[0])
    TInstrKind::TI31GetS(_) => TInstr::i31_get_s(children[0])
    TInstrKind::TI31GetU(_) => TInstr::i31_get_u(children[0])
    TInstrKind::TRefI31(_) => TInstr::ref_i31(children[0])
    TInstrKind::TArrayLen(_) => TInstr::array_len(children[0])
    TInstrKind::TAnyConvertExtern(_) => TInstr::any_convert_extern(children[0])
    TInstrKind::TExternConvertAny(_) => TInstr::extern_convert_any(children[0])
    TInstrKind::TThrowRef(_) => TInstr::throw_ref(children[0])
    TInstrKind::TMemoryGrow(idx, _) => TInstr::memory_grow(idx, children[0])
    TInstrKind::TTableGet(idx, _) => TInstr::table_get(idx, children[0])
    TInstrKind::TLoad(op, memarg, _) => TInstr::load(op, memarg, children[0])
    TInstrKind::TArrayNewDefault(type_idx, _) =>
      TInstr::array_new_default(type_idx, children[0])
    TInstrKind::TStructGet(type_idx, field_idx, _) =>
      TInstr::struct_get(type_idx, field_idx, children[0])
    TInstrKind::TStructGetS(type_idx, field_idx, _) =>
      TInstr::struct_get_s(type_idx, field_idx, children[0])
    TInstrKind::TStructGetU(type_idx, field_idx, _) =>
      TInstr::struct_get_u(type_idx, field_idx, children[0])
    TInstrKind::TI8x16Splat(_) => TInstr::i8x16_splat(children[0])
    TInstrKind::TI16x8Splat(_) => TInstr::i16x8_splat(children[0])
    TInstrKind::TI32x4Splat(_) => TInstr::i32x4_splat(children[0])
    TInstrKind::TI64x2Splat(_) => TInstr::i64x2_splat(children[0])
    TInstrKind::TF32x4Splat(_) => TInstr::f32x4_splat(children[0])
    TInstrKind::TF64x2Splat(_) => TInstr::f64x2_splat(children[0])
    TInstrKind::TExtractLane(op, lane, _) =>
      TInstr::extract_lane(op, lane, children[0])
    TInstrKind::TRefTest(nullable, ht, _) =>
      TInstr::ref_test(nullable, ht, children[0])
    TInstrKind::TRefCast(nullable, ht, _) =>
      TInstr::ref_cast(nullable, ht, children[0])
    TInstrKind::TRefGetDesc(_) => TInstr::ref_get_desc(children[0])
    TInstrKind::TRefTestDesc(nullable, ht, _) =>
      TInstr::ref_test_desc(nullable, ht, children[0])
    TInstrKind::TRefCastDescEq(nullable, ht, _) =>
      TInstr::ref_cast_desc_eq(nullable, ht, children[0])

    // Two operands.
    TInstrKind::TBinary(op, _, _) =>
      TInstr::binary(op, children[0], children[1])
    TInstrKind::TRefEq(_, _) => TInstr::ref_eq(children[0], children[1])
    TInstrKind::TStore(op, memarg, _, _) =>
      TInstr::store(op, memarg, children[0], children[1])
    TInstrKind::TMemoryAtomicNotify(memarg, _, _) =>
      TInstr::memory_atomic_notify(memarg, children[0], children[1])
    TInstrKind::TAtomicRmw(op, memarg, _, _) =>
      TInstr::atomic_rmw(op, memarg, children[0], children[1])
    TInstrKind::TTableSet(table_idx, _, _) =>
      TInstr::table_set(table_idx, children[0], children[1])
    TInstrKind::TTableGrow(table_idx, _, _) =>
      TInstr::table_grow(table_idx, children[0], children[1])
    TInstrKind::TStructSet(type_idx, field_idx, _, _) =>
      TInstr::struct_set(type_idx, field_idx, children[0], children[1])
    TInstrKind::TArrayNew(type_idx, _, _) =>
      TInstr::array_new(type_idx, children[0], children[1])
    TInstrKind::TArrayNewData(type_idx, data_idx, _, _) =>
      TInstr::array_new_data(type_idx, data_idx, children[0], children[1])
    TInstrKind::TArrayNewElem(type_idx, elem_idx, _, _) =>
      TInstr::array_new_elem(type_idx, elem_idx, children[0], children[1])
    TInstrKind::TArrayGet(type_idx, _, _) =>
      TInstr::array_get(type_idx, children[0], children[1])
    TInstrKind::TArrayGetS(type_idx, _, _) =>
      TInstr::array_get_s(type_idx, children[0], children[1])
    TInstrKind::TArrayGetU(type_idx, _, _) =>
      TInstr::array_get_u(type_idx, children[0], children[1])
    TInstrKind::TReplaceLane(op, lane, _, _) =>
      TInstr::replace_lane(op, lane, children[0], children[1])
    TInstrKind::TI8x16Swizzle(_, _) =>
      TInstr::i8x16_swizzle(children[0], children[1])
    TInstrKind::TI8x16RelaxedSwizzle(_, _) =>
      TInstr::i8x16_relaxed_swizzle(children[0], children[1])
    TInstrKind::TV128Shift(op, _, _) =>
      TInstr::v128_shift(op, children[0], children[1])
    TInstrKind::TV128LoadLane(op, memarg, lane, _, _) =>
      TInstr::v128_load_lane(op, memarg, lane, children[0], children[1])
    TInstrKind::TV128StoreLane(op, memarg, lane, _, _) =>
      TInstr::v128_store_lane(op, memarg, lane, children[0], children[1])

    // Three operands.
    TInstrKind::TMemoryFill(mem_idx, _, _, _) =>
      TInstr::memory_fill(mem_idx, children[0], children[1], children[2])
    TInstrKind::TMemoryCopy(dst, src, _, _, _) =>
      TInstr::memory_copy(dst, src, children[0], children[1], children[2])
    TInstrKind::TMemoryInit(data_idx, mem_idx, _, _, _) =>
      TInstr::memory_init(
        data_idx,
        mem_idx,
        children[0],
        children[1],
        children[2],
      )
    TInstrKind::TMemoryAtomicWait32(memarg, _, _, _) =>
      TInstr::memory_atomic_wait32(
        memarg,
        children[0],
        children[1],
        children[2],
      )
    TInstrKind::TMemoryAtomicWait64(memarg, _, _, _) =>
      TInstr::memory_atomic_wait64(
        memarg,
        children[0],
        children[1],
        children[2],
      )
    TInstrKind::TAtomicCmpxchg(op, memarg, _, _, _) =>
      TInstr::atomic_cmpxchg(op, memarg, children[0], children[1], children[2])
    TInstrKind::TTableFill(table_idx, _, _, _) =>
      TInstr::table_fill(table_idx, children[0], children[1], children[2])
    TInstrKind::TTableCopy(dst, src, _, _, _) =>
      TInstr::table_copy(dst, src, children[0], children[1], children[2])
    TInstrKind::TTableInit(elem_idx, table_idx, _, _, _) =>
      TInstr::table_init(
        elem_idx,
        table_idx,
        children[0],
        children[1],
        children[2],
      )
    TInstrKind::TSelect(types, _, _, _) =>
      TInstr::select(types, children[2], children[0], children[1])
    TInstrKind::TV128Ternary(op, _, _, _) =>
      TInstr::v128_ternary(op, children[0], children[1], children[2])

    // Variable-length operands.
    TInstrKind::TCall(func_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::call(func_idx, rebuilt)
    }
    TInstrKind::TReturnCall(func_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::return_call(func_idx, rebuilt)
    }
    TInstrKind::TThrow(tag_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::throw_(tag_idx, rebuilt)
    }
    TInstrKind::TBr(label_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::br(label_idx, rebuilt)
    }
    TInstrKind::TReturn(args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::return_(rebuilt)
    }
    TInstrKind::TStructNew(type_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::struct_new(type_idx, rebuilt)
    }
    TInstrKind::TArrayNewFixed(type_idx, args) => {
      let rebuilt = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt.push(children[i])
      }
      TInstr::array_new_fixed(type_idx, rebuilt)
    }
    TInstrKind::TCallIndirect(type_idx, table_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::call_indirect(
        type_idx,
        table_idx,
        rebuilt_args,
        children[args.length()],
      )
    }
    TInstrKind::TReturnCallIndirect(type_idx, table_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::return_call_indirect(
        type_idx,
        table_idx,
        rebuilt_args,
        children[args.length()],
      )
    }
    TInstrKind::TCallRef(type_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::call_ref(type_idx, rebuilt_args, children[args.length()])
    }
    TInstrKind::TReturnCallRef(type_idx, args, _) => {
      let rebuilt_args = []
      for i = 0; i < args.length(); i = i + 1 {
        rebuilt_args.push(children[i])
      }
      TInstr::return_call_ref(type_idx, rebuilt_args, children[args.length()])
    }
    TInstrKind::TBrIf(label_idx, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_if(label_idx, children[values.length()], rebuilt_values)
    }
    TInstrKind::TBrTable(labels, default, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_table(
        labels,
        default,
        children[values.length()],
        rebuilt_values,
      )
    }
    TInstrKind::TBrOnNull(label_idx, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_null(label_idx, children[values.length()], rebuilt_values)
    }
    TInstrKind::TBrOnNonNull(label_idx, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_non_null(
        label_idx,
        children[values.length()],
        rebuilt_values,
      )
    }
    TInstrKind::TBrOnCast(label_idx, castop, ht1, ht2, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_cast(
        label_idx,
        castop.0,
        ht1,
        castop.1,
        ht2,
        children[values.length()],
        rebuilt_values,
      )
    }
    TInstrKind::TBrOnCastFail(label_idx, castop, ht1, ht2, _, values) => {
      let rebuilt_values = []
      for i = 0; i < values.length(); i = i + 1 {
        rebuilt_values.push(children[i])
      }
      TInstr::br_on_cast_fail(
        label_idx,
        castop.0,
        ht1,
        castop.1,
        ht2,
        children[values.length()],
        rebuilt_values,
      )
    }
    TInstrKind::TArraySet(type_idx, _, _, _) =>
      TInstr::array_set(type_idx, children[0], children[1], children[2])
    TInstrKind::TArrayFill(type_idx, _, _, _, _) =>
      TInstr::array_fill(
        type_idx,
        children[0],
        children[1],
        children[2],
        children[3],
      )
    TInstrKind::TArrayCopy(dst_type, src_type, _, _, _, _, _) =>
      TInstr::array_copy(
        dst_type,
        src_type,
        children[0],
        children[1],
        children[2],
        children[3],
        children[4],
      )
    TInstrKind::TArrayInitData(type_idx, data_idx, _, _, _, _) =>
      TInstr::array_init_data(
        type_idx,
        data_idx,
        children[0],
        children[1],
        children[2],
        children[3],
      )
    TInstrKind::TArrayInitElem(type_idx, elem_idx, _, _, _, _) =>
      TInstr::array_init_elem(
        type_idx,
        elem_idx,
        children[0],
        children[1],
        children[2],
        children[3],
      )
    TInstrKind::TI8x16Shuffle(
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
      _,
      _
    ) =>
      TInstr::i8x16_shuffle(
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
        children[0],
        children[1],
      )

    // Control-flow structures are rebuilt in dedicated handlers.
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => instr
  }
}

///|
fn oi_rewrite_cache_new(
  local_count? : Int = 0,
  pair_cache_size? : Int = 2048,
) -> OIRewriteCache {
  let words = oi_local_bit_words_tracked(local_count)
  OIRewriteCache::{
    node_ids_by_hash: Map::new(),
    size_by_id: [],
    effects_by_id: [],
    fingerprint_by_id: [],
    reorder_by_pair: oi_pair_cache_init(pair_cache_size),
    eq_by_pair: oi_pair_cache_init(pair_cache_size),
    local_bit_words: words,
    local_bits_pool: Map::new(),
    node_id_get_calls: 0,
    node_id_put_calls: 0,
    eq_calls: 0,
    reorder_calls: 0,
    node_id_lookup_us: 0UL,
    fingerprint_us: 0UL,
    register_us: 0UL,
    eq_us: 0UL,
    reorder_us: 0UL,
    max_body_len: 0,
  }
}

///|
priv struct OINodeAggregate {
  mut size : Int
  locals_read : Array[UInt64]
  locals_written : Array[UInt64]
  mut unknown_locals_read : Bool
  mut unknown_locals_written : Bool
  mut reads_memory : Bool
  mut writes_memory : Bool
  mut reads_globals : Bool
  mut writes_globals : Bool
  mut calls : Bool
  mut branches : Bool
  mut traps : Bool
  mut throws : Bool
}

///|
fn oi_node_aggregate_new(
  shallow : LCSEffects,
  cache : OIRewriteCache,
) -> OINodeAggregate {
  let locals_read = oi_local_bits_new(cache.local_bit_words)
  let locals_written = oi_local_bits_new(cache.local_bit_words)
  let mut unknown_locals_read = false
  let mut unknown_locals_written = false
  for idx in shallow.locals_read {
    if !oi_local_bits_set(locals_read, idx) {
      unknown_locals_read = true
    }
  }
  for idx in shallow.locals_written {
    if !oi_local_bits_set(locals_written, idx) {
      unknown_locals_written = true
    }
  }
  OINodeAggregate::{
    size: 1,
    locals_read,
    locals_written,
    unknown_locals_read,
    unknown_locals_written,
    reads_memory: shallow.reads_memory,
    writes_memory: shallow.writes_memory,
    reads_globals: shallow.reads_globals,
    writes_globals: shallow.writes_globals,
    calls: shallow.calls,
    branches: shallow.branches,
    traps: shallow.traps,
    throws: shallow.throws,
  }
}

///|
fn OINodeAggregate::merge_child(
  self : OINodeAggregate,
  child_id : Int,
  cache : OIRewriteCache,
) -> Unit {
  self.size = self.size + cache.size_by_id[child_id]
  let child_summary = cache.effects_by_id[child_id]
  oi_local_bits_or_inplace(self.locals_read, child_summary.locals_read)
  oi_local_bits_or_inplace(self.locals_written, child_summary.locals_written)
  self.unknown_locals_read = self.unknown_locals_read ||
    child_summary.unknown_locals_read
  self.unknown_locals_written = self.unknown_locals_written ||
    child_summary.unknown_locals_written
  self.reads_memory = self.reads_memory || child_summary.reads_memory
  self.writes_memory = self.writes_memory || child_summary.writes_memory
  self.reads_globals = self.reads_globals || child_summary.reads_globals
  self.writes_globals = self.writes_globals || child_summary.writes_globals
  self.calls = self.calls || child_summary.calls
  self.branches = self.branches || child_summary.branches
  self.traps = self.traps || child_summary.traps
  self.throws = self.throws || child_summary.throws
}

///|
fn OINodeAggregate::finish(
  self : OINodeAggregate,
  cache : OIRewriteCache,
) -> (Int, OIEffectsSummary) {
  let summary = OIEffectsSummary::{
    locals_read: oi_local_bits_intern(self.locals_read, cache),
    locals_written: oi_local_bits_intern(self.locals_written, cache),
    unknown_locals_read: self.unknown_locals_read,
    unknown_locals_written: self.unknown_locals_written,
    reads_memory: self.reads_memory,
    writes_memory: self.writes_memory,
    reads_globals: self.reads_globals,
    writes_globals: self.writes_globals,
    calls: self.calls,
    branches: self.branches,
    traps: self.traps,
    throws: self.throws,
    has_side_effects: false,
  }
  let with_side_effects = OIEffectsSummary::{
    ..summary,
    has_side_effects: oi_effects_has_side_effects(summary),
  }
  (self.size, with_side_effects)
}

///|
fn oi_fingerprint_merge_child(
  fingerprint : UInt64,
  child : TInstr,
  aggregate : OINodeAggregate,
  cache : OIRewriteCache,
) -> UInt64 {
  let child_id = oi_instr_node_id(child, cache)
  aggregate.merge_child(child_id, cache)
  oi_hash_mix(fingerprint, cache.fingerprint_by_id[child_id])
}

///|
fn oi_fingerprint_merge_texpr(
  fingerprint : UInt64,
  body : TExpr,
  aggregate : OINodeAggregate,
  cache : OIRewriteCache,
) -> UInt64 {
  if body.instrs.length() > cache.max_body_len {
    cache.max_body_len = body.instrs.length()
  }
  let mut fingerprint = oi_hash_mix(
    fingerprint,
    body.instrs.length().to_uint64(),
  )
  for instr in body.instrs {
    fingerprint = oi_fingerprint_merge_child(
      fingerprint, instr, aggregate, cache,
    )
  }
  fingerprint
}

///|
fn oi_instr_fingerprint(
  instr : TInstr,
  aggregate : OINodeAggregate,
  cache : OIRewriteCache,
) -> UInt64 {
  let mut fingerprint = oi_instr_shallow_hash(instr)
  match instr.kind {
    TInstrKind::TBlock(_, body) | TInstrKind::TLoop(_, body) =>
      oi_fingerprint_merge_texpr(fingerprint, body, aggregate, cache)
    TInstrKind::TIf(_, cond, then_, else_) => {
      fingerprint = oi_fingerprint_merge_child(
        fingerprint, cond, aggregate, cache,
      )
      fingerprint = oi_hash_mix(fingerprint, 0x7468656eUL)
      fingerprint = oi_fingerprint_merge_texpr(
        fingerprint, then_, aggregate, cache,
      )
      match else_ {
        Some(other) => {
          fingerprint = oi_hash_mix(fingerprint, 0x656c7365UL)
          oi_fingerprint_merge_texpr(fingerprint, other, aggregate, cache)
        }
        None => oi_hash_mix(fingerprint, 0x6e6f656c7365UL)
      }
    }
    TInstrKind::TTryTable(_, _, body) =>
      oi_fingerprint_merge_texpr(fingerprint, body, aggregate, cache)
    _ => {
      oi_for_each_non_control_child(instr, fn(child) {
        fingerprint = oi_fingerprint_merge_child(
          fingerprint, child, aggregate, cache,
        )
      })
      fingerprint
    }
  }
}

///|
fn oi_node_id_get(
  instr : TInstr,
  fingerprint : UInt64,
  cache : OIRewriteCache,
) -> Int? {
  cache.node_id_get_calls = cache.node_id_get_calls + 1
  let start_us = oi_trace_now_us()
  let h = oi_instr_shallow_hash(instr)
  let out = match cache.node_ids_by_hash.get(h) {
    Some(entries) => {
      for entry in entries {
        if physical_equal(entry.instr, instr) {
          return Some(entry.node_id)
        }
      }
      for entry in entries {
        if entry.fingerprint == fingerprint && entry.instr == instr {
          return Some(entry.node_id)
        }
      }
      None
    }
    None => None
  }
  cache.node_id_lookup_us = cache.node_id_lookup_us +
    oi_trace_elapsed_us_since(start_us)
  out
}

///|
fn oi_node_id_put(
  instr : TInstr,
  node_id : Int,
  fingerprint : UInt64,
  cache : OIRewriteCache,
) -> Unit {
  cache.node_id_put_calls = cache.node_id_put_calls + 1
  let h = oi_instr_shallow_hash(instr)
  match cache.node_ids_by_hash.get(h) {
    Some(entries) =>
      entries.push(OINodeIdEntry::{ instr, node_id, fingerprint })
    None =>
      cache.node_ids_by_hash[h] = [
        OINodeIdEntry::{ instr, node_id, fingerprint },
      ]
  }
}

///|
fn oi_effects_has_side_effects(summary : OIEffectsSummary) -> Bool {
  summary.writes_memory ||
  summary.writes_globals ||
  summary.calls ||
  summary.branches ||
  summary.throws ||
  summary.traps ||
  summary.unknown_locals_written ||
  oi_local_bits_any(summary.locals_written) ||
  summary.reads_memory ||
  summary.reads_globals
}

///|
fn oi_register_instr(instr : TInstr, cache : OIRewriteCache) -> Int {
  let start_us = oi_trace_now_us()
  let shallow = lcs_collect_shallow_effects(instr)
  let aggregate = oi_node_aggregate_new(shallow, cache)
  let fingerprint_start_us = oi_trace_now_us()
  let fingerprint = oi_instr_fingerprint(instr, aggregate, cache)
  cache.fingerprint_us = cache.fingerprint_us +
    oi_trace_elapsed_us_since(fingerprint_start_us)
  match oi_node_id_get(instr, fingerprint, cache) {
    Some(node_id) => {
      cache.register_us = cache.register_us +
        oi_trace_elapsed_us_since(start_us)
      node_id
    }
    None => {
      let (size, summary) = aggregate.finish(cache)
      let node_id = cache.size_by_id.length()
      cache.size_by_id.push(size)
      cache.effects_by_id.push(summary)
      cache.fingerprint_by_id.push(fingerprint)
      oi_node_id_put(instr, node_id, fingerprint, cache)
      cache.register_us = cache.register_us +
        oi_trace_elapsed_us_since(start_us)
      node_id
    }
  }
}

///|
fn oi_instr_node_id(instr : TInstr, cache : OIRewriteCache) -> Int {
  oi_register_instr(instr, cache)
}

///|
fn oi_instr_size_cached(instr : TInstr, cache : OIRewriteCache) -> Int {
  let node_id = oi_instr_node_id(instr, cache)
  cache.size_by_id[node_id]
}

///|
fn oi_effects_summary_cached(
  instr : TInstr,
  cache : OIRewriteCache,
) -> OIEffectsSummary {
  let node_id = oi_instr_node_id(instr, cache)
  cache.effects_by_id[node_id]
}

///|
fn oi_can_reorder_cached(
  a : TInstr,
  b : TInstr,
  cache : OIRewriteCache,
) -> Bool {
  cache.reorder_calls = cache.reorder_calls + 1
  let start_us = oi_trace_now_us()
  let left_id = oi_instr_node_id(a, cache)
  if cache.size_by_id[left_id] > 256 {
    cache.reorder_us = cache.reorder_us + oi_trace_elapsed_us_since(start_us)
    return false
  }
  let right_id = oi_instr_node_id(b, cache)
  if cache.size_by_id[right_id] > 256 {
    cache.reorder_us = cache.reorder_us + oi_trace_elapsed_us_since(start_us)
    return false
  }
  let (low_id, high_id) = oi_pair_cache_key(left_id, right_id)
  let index = oi_pair_cache_index(
    low_id,
    high_id,
    cache.reorder_by_pair.length(),
  )
  let entry = cache.reorder_by_pair[index]
  if entry.valid && entry.low_id == low_id && entry.high_id == high_id {
    cache.reorder_us = cache.reorder_us + oi_trace_elapsed_us_since(start_us)
    return entry.value
  }
  let ea = cache.effects_by_id[left_id]
  let eb = cache.effects_by_id[right_id]
  let value = !ea.invalidates(eb) && !eb.invalidates(ea)
  cache.reorder_by_pair[index] = OIPairCacheEntry::{
    low_id,
    high_id,
    value,
    valid: true,
  }
  cache.reorder_us = cache.reorder_us + oi_trace_elapsed_us_since(start_us)
  value
}

///|
fn oi_instr_eq_cached(
  left : TInstr,
  right : TInstr,
  cache : OIRewriteCache,
) -> Bool {
  cache.eq_calls = cache.eq_calls + 1
  let start_us = oi_trace_now_us()
  match oi_instr_quick_eq_or_mismatch(left, right) {
    Some(value) => {
      cache.eq_us = cache.eq_us + oi_trace_elapsed_us_since(start_us)
      return value
    }
    None => ()
  }
  if physical_equal(left, right) {
    cache.eq_us = cache.eq_us + oi_trace_elapsed_us_since(start_us)
    return true
  }
  let left_hash = oi_instr_shallow_hash(left)
  let right_hash = oi_instr_shallow_hash(right)
  if left_hash != right_hash {
    cache.eq_us = cache.eq_us + oi_trace_elapsed_us_since(start_us)
    return false
  }
  let left_id = oi_instr_node_id(left, cache)
  if cache.size_by_id[left_id] > 256 {
    cache.eq_us = cache.eq_us + oi_trace_elapsed_us_since(start_us)
    return false
  }
  let right_id = oi_instr_node_id(right, cache)
  if cache.size_by_id[right_id] > 256 {
    cache.eq_us = cache.eq_us + oi_trace_elapsed_us_since(start_us)
    return false
  }
  if left_id == right_id {
    cache.eq_us = cache.eq_us + oi_trace_elapsed_us_since(start_us)
    return true
  }
  let (low_id, high_id) = oi_pair_cache_key(left_id, right_id)
  let index = oi_pair_cache_index(low_id, high_id, cache.eq_by_pair.length())
  let entry = cache.eq_by_pair[index]
  if entry.valid && entry.low_id == low_id && entry.high_id == high_id {
    cache.eq_us = cache.eq_us + oi_trace_elapsed_us_since(start_us)
    return entry.value
  }
  let value = left == right
  cache.eq_by_pair[index] = OIPairCacheEntry::{
    low_id,
    high_id,
    value,
    valid: true,
  }
  cache.eq_us = cache.eq_us + oi_trace_elapsed_us_since(start_us)
  value
}

///|
fn oi_instr_eq_for_change(
  left : TInstr,
  right : TInstr,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> Bool {
  match oi_instr_quick_eq_or_mismatch(left, right) {
    Some(value) => value
    None =>
      if allow_expensive_eq {
        oi_instr_eq_cached(left, right, cache)
      } else {
        let budget = 96
        if !oi_instr_within_eq_budget(left, budget, cache) ||
          !oi_instr_within_eq_budget(right, budget, cache) {
          false
        } else {
          left == right
        }
      }
  }
}

///|
fn oi_instr_quick_eq_or_mismatch(left : TInstr, right : TInstr) -> Bool? {
  match (left, right) {
    (
      { kind: TInstrKind::TLocalGet(l_idx), .. },
      { kind: TInstrKind::TLocalGet(r_idx), .. },
    ) => Some(l_idx == r_idx)
    ({ kind: TInstrKind::TLocalGet(_), .. }, _)
    | (_, { kind: TInstrKind::TLocalGet(_), .. }) => Some(false)
    (
      { kind: TInstrKind::TI32Const(lv), .. },
      { kind: TInstrKind::TI32Const(rv), .. },
    ) => Some(lv == rv)
    ({ kind: TInstrKind::TI32Const(_), .. }, _)
    | (_, { kind: TInstrKind::TI32Const(_), .. }) => Some(false)
    (
      { kind: TInstrKind::TI64Const(lv), .. },
      { kind: TInstrKind::TI64Const(rv), .. },
    ) => Some(lv == rv)
    ({ kind: TInstrKind::TI64Const(_), .. }, _)
    | (_, { kind: TInstrKind::TI64Const(_), .. }) => Some(false)
    (
      { kind: TInstrKind::TF32Const(lv), .. },
      { kind: TInstrKind::TF32Const(rv), .. },
    ) => Some(lv == rv)
    ({ kind: TInstrKind::TF32Const(_), .. }, _)
    | (_, { kind: TInstrKind::TF32Const(_), .. }) => Some(false)
    (
      { kind: TInstrKind::TF64Const(lv), .. },
      { kind: TInstrKind::TF64Const(rv), .. },
    ) => Some(lv == rv)
    ({ kind: TInstrKind::TF64Const(_), .. }, _)
    | (_, { kind: TInstrKind::TF64Const(_), .. }) => Some(false)
    _ => None
  }
}

///|
fn oi_instr_is_large_blockish(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBlock(_, texpr) | TInstrKind::TLoop(_, texpr) =>
      texpr.instrs.length() > 128
    TInstrKind::TIf(_, _, then_, Some(else_)) =>
      then_.instrs.length() > 128 || else_.instrs.length() > 128
    TInstrKind::TIf(_, _, then_, None) => then_.instrs.length() > 128
    _ => false
  }
}

///|
fn oi_instr_within_eq_budget(
  instr : TInstr,
  budget : Int,
  cache : OIRewriteCache,
) -> Bool {
  oi_instr_size_cached(instr, cache) <= budget
}

///|
fn oi_texpr_within_eq_budget(
  texpr : TExpr,
  budget : Int,
  cache : OIRewriteCache,
) -> Bool {
  let mut size = 0
  for instr in texpr.instrs {
    size += oi_instr_size_cached(instr, cache)
    if size > budget {
      return false
    }
  }
  true
}

///|
fn oi_instr_eq_budgeted(
  left : TInstr,
  right : TInstr,
  cache : OIRewriteCache,
  budget : Int,
) -> Bool {
  match oi_instr_quick_eq_or_mismatch(left, right) {
    Some(value) => return value
    None => ()
  }
  if !oi_instr_within_eq_budget(left, budget, cache) ||
    !oi_instr_within_eq_budget(right, budget, cache) {
    return false
  }
  oi_instr_eq_cached(left, right, cache)
}

///|
fn oi_texpr_eq_budgeted(
  left : TExpr,
  right : TExpr,
  cache : OIRewriteCache,
  budget : Int,
) -> Bool {
  if left.instrs.length() != right.instrs.length() {
    return false
  }
  if left.instrs.is_empty() {
    return true
  }
  if left.instrs.length() == 1 {
    match oi_instr_quick_eq_or_mismatch(left.instrs[0], right.instrs[0]) {
      Some(value) => return value
      None => ()
    }
  }
  if !oi_texpr_within_eq_budget(left, budget, cache) ||
    !oi_texpr_within_eq_budget(right, budget, cache) {
    return false
  }
  for i = 0; i < left.instrs.length(); i = i + 1 {
    let l = left.instrs[i]
    let r = right.instrs[i]
    match oi_instr_quick_eq_or_mismatch(l, r) {
      Some(value) => if !value { return false }
      None => if !oi_instr_eq_cached(l, r, cache) { return false }
    }
  }
  true
}

///|
fn oi_instr_equal_for_fold(
  left : TInstr,
  right : TInstr,
  cache : OIRewriteCache,
  budget : Int,
  allow_expensive_eq : Bool,
  allow_fold_equal_operands : Bool,
) -> Bool {
  if !allow_fold_equal_operands {
    return false
  }
  match oi_instr_quick_eq_or_mismatch(left, right) {
    Some(value) => value
    None => {
      if !allow_expensive_eq ||
        oi_instr_is_large_blockish(left) ||
        oi_instr_is_large_blockish(right) {
        return false
      }
      oi_instr_eq_budgeted(left, right, cache, budget)
    }
  }
}

///|
fn oi_texpr_equal_for_fold(
  left : TExpr,
  right : TExpr,
  cache : OIRewriteCache,
  budget : Int,
  allow_expensive_eq : Bool,
) -> Bool {
  if left.instrs.length() != right.instrs.length() {
    return false
  }
  if left.instrs.is_empty() {
    return true
  }
  if left.instrs.length() == 1 {
    match oi_instr_quick_eq_or_mismatch(left.instrs[0], right.instrs[0]) {
      Some(value) => return value
      None => ()
    }
  }
  if !allow_expensive_eq {
    return false
  }
  if left.instrs.length() > 128 || right.instrs.length() > 128 {
    return false
  }
  oi_texpr_eq_budgeted(left, right, cache, budget)
}

///|
fn oi_can_reorder(a : TInstr, b : TInstr) -> Bool {
  let cache = oi_rewrite_cache_new()
  oi_can_reorder_cached(a, b, cache)
}

///|
fn oi_has_side_effects_cached(instr : TInstr, cache : OIRewriteCache) -> Bool {
  oi_effects_summary_cached(instr, cache).has_side_effects
}

///|
fn oi_is_symmetric(op : BinaryOp) -> Bool {
  match op {
    I32EqOp
    | I32NeOp
    | I64EqOp
    | I64NeOp
    | F32EqOp
    | F32NeOp
    | F64EqOp
    | F64NeOp
    | I32AddOp
    | I32MulOp
    | I32AndOp
    | I32OrOp
    | I32XorOp
    | I64AddOp
    | I64MulOp
    | I64AndOp
    | I64OrOp
    | I64XorOp
    | F32AddOp
    | F32MulOp
    | F64AddOp
    | F64MulOp => true
    _ => false
  }
}

///|
fn oi_is_relational(op : BinaryOp) -> Bool {
  match op {
    I32EqOp
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
    | F64GeOp => true
    _ => false
  }
}

///|
fn oi_reverse_relational(op : BinaryOp) -> BinaryOp? {
  match op {
    I32EqOp => Some(BinaryOp::i32_eq())
    I32NeOp => Some(BinaryOp::i32_ne())
    I32LtSOp => Some(BinaryOp::i32_gt_s())
    I32LtUOp => Some(BinaryOp::i32_gt_u())
    I32LeSOp => Some(BinaryOp::i32_ge_s())
    I32LeUOp => Some(BinaryOp::i32_ge_u())
    I32GtSOp => Some(BinaryOp::i32_lt_s())
    I32GtUOp => Some(BinaryOp::i32_lt_u())
    I32GeSOp => Some(BinaryOp::i32_le_s())
    I32GeUOp => Some(BinaryOp::i32_le_u())
    I64EqOp => Some(BinaryOp::i64_eq())
    I64NeOp => Some(BinaryOp::i64_ne())
    I64LtSOp => Some(BinaryOp::i64_gt_s())
    I64LtUOp => Some(BinaryOp::i64_gt_u())
    I64LeSOp => Some(BinaryOp::i64_ge_s())
    I64LeUOp => Some(BinaryOp::i64_ge_u())
    I64GtSOp => Some(BinaryOp::i64_lt_s())
    I64GtUOp => Some(BinaryOp::i64_lt_u())
    I64GeSOp => Some(BinaryOp::i64_le_s())
    I64GeUOp => Some(BinaryOp::i64_le_u())
    F32EqOp => Some(BinaryOp::f32_eq())
    F32NeOp => Some(BinaryOp::f32_ne())
    F32LtOp => Some(BinaryOp::f32_gt())
    F32LeOp => Some(BinaryOp::f32_ge())
    F32GtOp => Some(BinaryOp::f32_lt())
    F32GeOp => Some(BinaryOp::f32_le())
    F64EqOp => Some(BinaryOp::f64_eq())
    F64NeOp => Some(BinaryOp::f64_ne())
    F64LtOp => Some(BinaryOp::f64_gt())
    F64LeOp => Some(BinaryOp::f64_ge())
    F64GtOp => Some(BinaryOp::f64_lt())
    F64GeOp => Some(BinaryOp::f64_le())
    _ => None
  }
}

///|
fn oi_invert_relational(op : BinaryOp) -> BinaryOp? {
  match op {
    I32EqOp => Some(BinaryOp::i32_ne())
    I32NeOp => Some(BinaryOp::i32_eq())
    I32LtSOp => Some(BinaryOp::i32_ge_s())
    I32LtUOp => Some(BinaryOp::i32_ge_u())
    I32LeSOp => Some(BinaryOp::i32_gt_s())
    I32LeUOp => Some(BinaryOp::i32_gt_u())
    I32GtSOp => Some(BinaryOp::i32_le_s())
    I32GtUOp => Some(BinaryOp::i32_le_u())
    I32GeSOp => Some(BinaryOp::i32_lt_s())
    I32GeUOp => Some(BinaryOp::i32_lt_u())
    I64EqOp => Some(BinaryOp::i64_ne())
    I64NeOp => Some(BinaryOp::i64_eq())
    I64LtSOp => Some(BinaryOp::i64_ge_s())
    I64LtUOp => Some(BinaryOp::i64_ge_u())
    I64LeSOp => Some(BinaryOp::i64_gt_s())
    I64LeUOp => Some(BinaryOp::i64_gt_u())
    I64GtSOp => Some(BinaryOp::i64_le_s())
    I64GtUOp => Some(BinaryOp::i64_le_u())
    I64GeSOp => Some(BinaryOp::i64_lt_s())
    I64GeUOp => Some(BinaryOp::i64_lt_u())
    F32EqOp => Some(BinaryOp::f32_ne())
    F32NeOp => Some(BinaryOp::f32_eq())
    F64EqOp => Some(BinaryOp::f64_ne())
    F64NeOp => Some(BinaryOp::f64_eq())
    _ => None
  }
}

///|
fn oi_is_shift(op : BinaryOp) -> Bool {
  match op {
    I32ShlOp
    | I32ShrSOp
    | I32ShrUOp
    | I32RotlOp
    | I32RotrOp
    | I64ShlOp
    | I64ShrSOp
    | I64ShrUOp
    | I64RotlOp
    | I64RotrOp => true
    _ => false
  }
}

///|
fn oi_is_i32_shift(op : BinaryOp) -> Bool {
  match op {
    I32ShlOp | I32ShrSOp | I32ShrUOp | I32RotlOp | I32RotrOp => true
    _ => false
  }
}

///|
fn oi_is_i64_shift(op : BinaryOp) -> Bool {
  match op {
    I64ShlOp | I64ShrSOp | I64ShrUOp | I64RotlOp | I64RotrOp => true
    _ => false
  }
}

///|
fn oi_binary_maybe_rewrite(op : BinaryOp) -> Bool {
  oi_is_shift(op) ||
  oi_is_relational(op) ||
  op == BinaryOp::i32_add() ||
  op == BinaryOp::i32_sub() ||
  op == BinaryOp::i32_mul() ||
  op == BinaryOp::i32_div_s() ||
  op == BinaryOp::i32_div_u() ||
  op == BinaryOp::i32_rem_s() ||
  op == BinaryOp::i32_rem_u() ||
  op == BinaryOp::i32_and() ||
  op == BinaryOp::i32_or() ||
  op == BinaryOp::i32_xor() ||
  op == BinaryOp::i64_add() ||
  op == BinaryOp::i64_sub() ||
  op == BinaryOp::i64_mul() ||
  op == BinaryOp::i64_div_s() ||
  op == BinaryOp::i64_div_u() ||
  op == BinaryOp::i64_rem_s() ||
  op == BinaryOp::i64_rem_u() ||
  op == BinaryOp::i64_and() ||
  op == BinaryOp::i64_or() ||
  op == BinaryOp::i64_xor() ||
  op == BinaryOp::f32_add() ||
  op == BinaryOp::f32_sub() ||
  op == BinaryOp::f32_mul() ||
  op == BinaryOp::f32_div() ||
  op == BinaryOp::f64_add() ||
  op == BinaryOp::f64_sub() ||
  op == BinaryOp::f64_mul() ||
  op == BinaryOp::f64_div()
}

///|
fn oi_binary_can_fold_equal_operands(op : BinaryOp) -> Bool {
  match op {
    I32SubOp
    | I32XorOp
    | I64SubOp
    | I64XorOp
    | I32AndOp
    | I32OrOp
    | I64AndOp
    | I64OrOp
    | I32EqOp
    | I32LeSOp
    | I32LeUOp
    | I32GeSOp
    | I32GeUOp
    | I64EqOp
    | I64LeSOp
    | I64LeUOp
    | I64GeSOp
    | I64GeUOp
    | I32NeOp
    | I32LtSOp
    | I32LtUOp
    | I32GtSOp
    | I32GtUOp
    | I64NeOp
    | I64LtSOp
    | I64LtUOp
    | I64GtSOp
    | I64GtUOp => true
    _ => false
  }
}

///|
fn oi_unary_maybe_rewrite(op : UnaryOp) -> Bool {
  op == UnaryOp::i32_eqz() ||
  op == UnaryOp::i64_eqz() ||
  op == UnaryOp::i32_wrap_i64() ||
  op == UnaryOp::i64_extend_i32s() ||
  op == UnaryOp::i64_extend_i32u() ||
  op == UnaryOp::i32_reinterpret_f32() ||
  op == UnaryOp::i64_reinterpret_f64() ||
  op == UnaryOp::f32_reinterpret_i32() ||
  op == UnaryOp::f64_reinterpret_i64() ||
  op == UnaryOp::f32_abs() ||
  op == UnaryOp::f32_neg() ||
  op == UnaryOp::f32_ceil() ||
  op == UnaryOp::f32_floor() ||
  op == UnaryOp::f32_trunc() ||
  op == UnaryOp::f32_nearest() ||
  op == UnaryOp::f64_abs() ||
  op == UnaryOp::f64_neg() ||
  op == UnaryOp::f64_ceil() ||
  op == UnaryOp::f64_floor() ||
  op == UnaryOp::f64_trunc() ||
  op == UnaryOp::f64_nearest() ||
  op == UnaryOp::i32_extend8s() ||
  op == UnaryOp::i32_extend16s() ||
  op == UnaryOp::i64_extend8s() ||
  op == UnaryOp::i64_extend16s() ||
  op == UnaryOp::i64_extend32s()
}

///|
fn oi_instr_is_rewrite_candidate(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBinary(op, _, _) => oi_binary_maybe_rewrite(op)
    TInstrKind::TUnary(op, _) => oi_unary_maybe_rewrite(op)
    TInstrKind::TSelect(_, _, _, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TGlobalSet(_, _)
    | TInstrKind::TBrIf(_, _, _)
    | TInstrKind::TLoad(_, _, _)
    | TInstrKind::TStore(_, _, _, _)
    | TInstrKind::TMemoryCopy(_, _, _, _, _)
    | TInstrKind::TMemoryFill(_, _, _, _)
    | TInstrKind::TCallRef(_, _, _) => true
    _ => false
  }
}

///|
fn oi_binary_has_masked_shift_rhs(rhs : TInstr) -> Bool {
  match rhs.kind {
    TInstrKind::TBinary(I32AndOp, _, { kind: TInstrKind::TI32Const(_), .. })
    | TInstrKind::TBinary(I64AndOp, _, { kind: TInstrKind::TI64Const(_), .. }) =>
      true
    _ => false
  }
}

///|
fn oi_should_attempt_fixpoint(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBinary(op, left, right) => {
      if !oi_binary_maybe_rewrite(op) {
        return false
      }
      if oi_is_shift(op) {
        return oi_is_const(left) ||
          oi_is_const(right) ||
          oi_binary_has_masked_shift_rhs(right)
      }
      true
    }
    TInstrKind::TUnary(op, _) => oi_unary_maybe_rewrite(op)
    _ => oi_instr_is_rewrite_candidate(instr)
  }
}

///|
fn oi_rewrite_candidate_scan_budget(top_instrs : Int) -> Int {
  if top_instrs >= 10000 {
    12
  } else {
    6
  }
}

///|
let oi_rewrite_need_has_candidate = 1

///|
let oi_rewrite_need_expensive_eq = 2

///|
let oi_rewrite_need_reorder = 4

///|
let oi_rewrite_need_fold_equal_operands = 8

///|
let oi_rewrite_need_all_flags = 15

///|
fn oi_rewrite_needs_has(flags : Int, flag : Int) -> Bool {
  (flags & flag) != 0
}

///|
fn oi_instr_needs_expensive_eq(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBinary(op, _, _) => oi_binary_can_fold_equal_operands(op)
    TInstrKind::TUnary(
      F32AbsOp,
      { kind: TInstrKind::TBinary(F32MulOp, _, _), .. }
    )
    | TInstrKind::TUnary(
      F32AbsOp,
      { kind: TInstrKind::TBinary(F32DivOp, _, _), .. }
    )
    | TInstrKind::TUnary(
      F64AbsOp,
      { kind: TInstrKind::TBinary(F64MulOp, _, _), .. }
    )
    | TInstrKind::TUnary(
      F64AbsOp,
      { kind: TInstrKind::TBinary(F64DivOp, _, _), .. }
    )
    | TInstrKind::TSelect(_, _, _, _)
    | TInstrKind::TIf(_, _, _, Some(_)) => true
    _ => false
  }
}

///|
fn oi_instr_needs_reorder(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBinary(
      F32AddOp,
      { kind: TInstrKind::TUnary(F32NegOp, _), .. },
      _
    )
    | TInstrKind::TBinary(
      F64AddOp,
      { kind: TInstrKind::TUnary(F64NegOp, _), .. },
      _
    ) => true
    _ => false
  }
}

///|
fn oi_instr_needs_fold_equal_operands(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TBinary(op, _, _) => oi_binary_can_fold_equal_operands(op)
    TInstrKind::TSelect(_, _, _, _) => true
    _ => false
  }
}

///|
fn oi_texpr_scan_rewrite_needs(body : TExpr, scan_budget : Int) -> Int {
  let stack = body.instrs.copy()
  let mut scanned = 0
  let mut flags = 0
  while !stack.is_empty() && scanned < scan_budget {
    scanned += 1
    let curr = stack.pop().unwrap()
    if oi_should_attempt_fixpoint(curr) {
      flags = flags | oi_rewrite_need_has_candidate
    }
    if oi_instr_needs_expensive_eq(curr) {
      flags = flags | oi_rewrite_need_expensive_eq
    }
    if oi_instr_needs_reorder(curr) {
      flags = flags | oi_rewrite_need_reorder
      flags = flags | oi_rewrite_need_expensive_eq
    }
    if oi_instr_needs_fold_equal_operands(curr) {
      flags = flags | oi_rewrite_need_fold_equal_operands
    }
    if (flags & oi_rewrite_need_all_flags) == oi_rewrite_need_all_flags {
      break
    }
    oi_for_each_non_control_child(curr, fn(child) { stack.push(child) })
  }
  flags
}

///|
fn oi_negate_const(instr : TInstr) -> TInstr? {
  match instr.kind {
    TInstrKind::TI32Const(I32(v)) =>
      Some(TInstr::i32_const(I32(oi_wrap_i32(-v))))
    TInstrKind::TI64Const(I64(v)) =>
      Some(TInstr::i64_const(I64(oi_wrap_i64(-v))))
    TInstrKind::TF32Const(F32(v)) => Some(TInstr::f32_const(F32(-v)))
    TInstrKind::TF64Const(F64(v)) => Some(TInstr::f64_const(F64(-v)))
    _ => None
  }
}

///|
fn oi_make_binary(op : BinaryOp, left : TInstr, right : TInstr) -> TInstr {
  TInstr::binary(op, left, right)
}

///|
fn oi_optimize_boolean(
  cond : TInstr,
  _env : Env,
  _options : OptimizeOptions,
) -> TInstr {
  match cond.kind {
    TInstrKind::TUnary(
      I32EqzOp,
      { kind: TInstrKind::TUnary(I32EqzOp, value), .. }
    ) => value
    TInstrKind::TUnary(
      I32EqzOp,
      { kind: TInstrKind::TBinary(op, left, right), .. }
    ) =>
      match oi_invert_relational(op) {
        Some(inv) => TInstr::binary(inv, left, right)
        None => cond
      }
    TInstrKind::TUnary(I32EqzOp, value) =>
      match value.kind {
        TInstrKind::TI32Const(I32(v)) =>
          TInstr::i32_const(I32(if v == 0 { 1 } else { 0 }))
        _ => cond
      }
    TInstrKind::TBinary(
      I32NeOp,
      value,
      { kind: TInstrKind::TI32Const(I32(0)), .. }
    ) => value
    TInstrKind::TBinary(
      I32SubOp,
      { kind: TInstrKind::TI32Const(I32(0)), .. },
      value
    ) => value
    _ => cond
  }
}

///|
fn oi_optimize_with_const_right(
  op : BinaryOp,
  left : TInstr,
  right : TInstr,
  env : Env,
  options : OptimizeOptions,
) -> TInstr? {
  match (op, right) {
    (I32ShlOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32ShrSOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32ShrUOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32RotlOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32RotrOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64ShlOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64ShrSOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64ShrUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64RotlOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64RotrOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I32OrOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32XorOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64OrOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64XorOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I32AddOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64AddOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I32SubOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64SubOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) => Some(left)
    (I32AndOp, { kind: TInstrKind::TI32Const(I32(-1)), .. })
    | (I64AndOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) => Some(left)
    (I32AndOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64AndOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(0L)), env))
    (I32OrOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(-1)), env))
    (I64OrOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(-1L)), env))
    (I32EqOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(TInstr::unary(UnaryOp::i32_eqz(), left))
    (I64EqOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(TInstr::unary(UnaryOp::i64_eqz(), left))
    (I32MulOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I64MulOp, { kind: TInstrKind::TI64Const(I64(1L)), .. })
    | (I32DivSOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I32DivUOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I64DivSOp, { kind: TInstrKind::TI64Const(I64(1L)), .. })
    | (I64DivUOp, { kind: TInstrKind::TI64Const(I64(1L)), .. }) => Some(left)
    (I32MulOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64MulOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(0L)), env))
    (I32RemSOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I32RemUOp, { kind: TInstrKind::TI32Const(I32(1)), .. })
    | (I32RemSOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64RemSOp, { kind: TInstrKind::TI64Const(I64(1L)), .. })
    | (I64RemUOp, { kind: TInstrKind::TI64Const(I64(1L)), .. })
    | (I64RemSOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i64_const(I64(0L)), env))
    (I32GeUOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I64GeUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I32LtUOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64LtUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I32LeUOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I64LeUOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(1)), env))
    (I32GtUOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I64GtUOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(oi_seq([oi_instr_stmt(left, env)], TInstr::i32_const(I32(0)), env))
    (I32LtUOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_ne(), left, TInstr::i32_const(I32(-1))))
    (I64LtUOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(
        TInstr::binary(BinaryOp::i64_ne(), left, TInstr::i64_const(I64(-1L))),
      )
    (I32LeUOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_eq(), left, TInstr::i32_const(I32(0))))
    (I64LeUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(TInstr::binary(BinaryOp::i64_eq(), left, TInstr::i64_const(I64(0L))))
    (I32GtUOp, { kind: TInstrKind::TI32Const(I32(0)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_ne(), left, TInstr::i32_const(I32(0))))
    (I64GtUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      Some(TInstr::binary(BinaryOp::i64_ne(), left, TInstr::i64_const(I64(0L))))
    (I32GeUOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_eq(), left, TInstr::i32_const(I32(-1))))
    (I64GeUOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(
        TInstr::binary(BinaryOp::i64_eq(), left, TInstr::i64_const(I64(-1L))),
      )
    (I32MulOp, { kind: TInstrKind::TI32Const(I32(-1)), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_sub(), TInstr::i32_const(I32(0)), left))
    (I64MulOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      Some(
        TInstr::binary(BinaryOp::i64_sub(), TInstr::i64_const(I64(0L)), left),
      )
    (I32DivUOp, { kind: TInstrKind::TI32Const(I32(c)), .. }) =>
      if oi_is_power_of_2_i32(c) {
        Some(
          TInstr::binary(
            BinaryOp::i32_shr_u(),
            left,
            TInstr::i32_const(I32(oi_log2_i32(c))),
          ),
        )
      } else {
        None
      }
    (I64DivUOp, { kind: TInstrKind::TI64Const(I64(c)), .. }) =>
      if oi_is_power_of_2_i64(c) {
        Some(
          TInstr::binary(
            BinaryOp::i64_shr_u(),
            left,
            TInstr::i64_const(I64(oi_log2_i64(c))),
          ),
        )
      } else {
        None
      }
    (I32RemUOp, { kind: TInstrKind::TI32Const(I32(c)), .. }) =>
      if oi_is_power_of_2_i32(c) {
        Some(
          TInstr::binary(
            BinaryOp::i32_and(),
            left,
            TInstr::i32_const(I32(oi_wrap_i32(c - 1))),
          ),
        )
      } else {
        None
      }
    (I64RemUOp, { kind: TInstrKind::TI64Const(I64(c)), .. }) =>
      if oi_is_power_of_2_i64(c) {
        Some(
          TInstr::binary(
            BinaryOp::i64_and(),
            left,
            TInstr::i64_const(I64(oi_wrap_i64(c - 1L))),
          ),
        )
      } else {
        None
      }
    (I32MulOp, { kind: TInstrKind::TI32Const(I32(c)), .. }) =>
      if oi_is_power_of_2_i32(c) {
        Some(
          TInstr::binary(
            BinaryOp::i32_shl(),
            left,
            TInstr::i32_const(I32(oi_log2_i32(c))),
          ),
        )
      } else {
        None
      }
    (I64MulOp, { kind: TInstrKind::TI64Const(I64(c)), .. }) =>
      if oi_is_power_of_2_i64(c) {
        Some(
          TInstr::binary(
            BinaryOp::i64_shl(),
            left,
            TInstr::i64_const(I64(oi_log2_i64(c))),
          ),
        )
      } else {
        None
      }
    (F32MulOp, { kind: TInstrKind::TF32Const(F32(-1.0)), .. }) =>
      Some(TInstr::unary(UnaryOp::f32_neg(), left))
    (F64MulOp, { kind: TInstrKind::TF64Const(F64(-1.0)), .. }) =>
      Some(TInstr::unary(UnaryOp::f64_neg(), left))
    (F32AddOp, { kind: TInstrKind::TF32Const(F32(v)), .. }) =>
      if options.optimize_level > 0 && v == 0.0 {
        Some(left)
      } else {
        None
      }
    (F64AddOp, { kind: TInstrKind::TF64Const(F64(v)), .. }) =>
      if options.optimize_level > 0 && v == 0.0 {
        Some(left)
      } else {
        None
      }
    _ => None
  }
}

///|
fn oi_optimize_with_const_left(
  op : BinaryOp,
  left : TInstr,
  right : TInstr,
  _env : Env,
  cache : OIRewriteCache,
  allow_effect_queries : Bool,
) -> TInstr? {
  match (op, left) {
    (I32ShlOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32ShrSOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I32ShrUOp, { kind: TInstrKind::TI32Const(I32(0)), .. })
    | (I64ShlOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64ShrSOp, { kind: TInstrKind::TI64Const(I64(0L)), .. })
    | (I64ShrUOp, { kind: TInstrKind::TI64Const(I64(0L)), .. }) =>
      if allow_effect_queries && !oi_has_side_effects_cached(right, cache) {
        Some(left)
      } else {
        None
      }
    (I32ShrSOp, { kind: TInstrKind::TI32Const(I32(-1)), .. })
    | (I32RotlOp, { kind: TInstrKind::TI32Const(I32(-1)), .. })
    | (I32RotrOp, { kind: TInstrKind::TI32Const(I32(-1)), .. })
    | (I64ShrSOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. })
    | (I64RotlOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. })
    | (I64RotrOp, { kind: TInstrKind::TI64Const(I64(-1L)), .. }) =>
      if allow_effect_queries && !oi_has_side_effects_cached(right, cache) {
        Some(left)
      } else {
        None
      }
    (I32SubOp, { kind: TInstrKind::TI32Const(I32(c1)), .. }) =>
      match right.kind {
        TInstrKind::TBinary(
          I32AddOp,
          x,
          { kind: TInstrKind::TI32Const(I32(c2)), .. }
        ) =>
          Some(
            TInstr::binary(
              BinaryOp::i32_sub(),
              TInstr::i32_const(I32(oi_wrap_i32(c1 - c2))),
              x,
            ),
          )
        TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(c2)), .. },
          x
        ) =>
          Some(
            TInstr::binary(
              BinaryOp::i32_add(),
              x,
              TInstr::i32_const(I32(oi_wrap_i32(c1 - c2))),
            ),
          )
        _ => None
      }
    (I64SubOp, { kind: TInstrKind::TI64Const(I64(c1)), .. }) =>
      match right.kind {
        TInstrKind::TBinary(
          I64AddOp,
          x,
          { kind: TInstrKind::TI64Const(I64(c2)), .. }
        ) =>
          Some(
            TInstr::binary(
              BinaryOp::i64_sub(),
              TInstr::i64_const(I64(oi_wrap_i64(c1 - c2))),
              x,
            ),
          )
        TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(c2)), .. },
          x
        ) =>
          Some(
            TInstr::binary(
              BinaryOp::i64_add(),
              x,
              TInstr::i64_const(I64(oi_wrap_i64(c1 - c2))),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn oi_optimize_binary(
  op0 : BinaryOp,
  left0 : TInstr,
  right0 : TInstr,
  env : Env,
  options : OptimizeOptions,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
  allow_reorder : Bool,
  allow_fold_equal_operands : Bool,
) -> TInstr? {
  let mut op = op0
  let mut left = left0
  let mut right = right0
  let mut changed = false
  if oi_is_symmetric(op) && oi_is_const(left) && !oi_is_const(right) {
    // Constants are always side-effect-free and cannot trap, so swapping is safe.
    let tmp = left
    left = right
    right = tmp
    changed = true
  }
  if oi_is_relational(op) && oi_is_const(left) && !oi_is_const(right) {
    match oi_reverse_relational(op) {
      Some(next) => {
        op = next
        let tmp = left
        left = right
        right = tmp
        changed = true
      }
      None => ()
    }
  }
  if (
      op == BinaryOp::i32_sub() ||
      op == BinaryOp::i64_sub() ||
      op == BinaryOp::f32_sub() ||
      op == BinaryOp::f64_sub()
    ) &&
    oi_is_const(right) {
    match oi_negate_const(right) {
      Some(neg_right) => {
        right = neg_right
        op = match op {
          I32SubOp => BinaryOp::i32_add()
          I64SubOp => BinaryOp::i64_add()
          F32SubOp => BinaryOp::f32_add()
          F64SubOp => BinaryOp::f64_add()
          _ => op
        }
        changed = true
      }
      None => ()
    }
  }
  if oi_is_shift(op) {
    match (op, right) {
      (op, { kind: TInstrKind::TI32Const(I32(v)), .. }) if oi_is_i32_shift(op) => {
        let eff = v & 31
        if eff != v {
          right = TInstr::i32_const(I32(eff))
          changed = true
        }
        if eff == 0 {
          return Some(left)
        }
      }
      (op, { kind: TInstrKind::TI64Const(I64(v)), .. }) if oi_is_i64_shift(op) => {
        let eff = v & 63L
        if eff != v {
          right = TInstr::i64_const(I64(eff))
          changed = true
        }
        if eff == 0L {
          return Some(left)
        }
      }
      (
        _,
        {
          kind: TInstrKind::TBinary(
            I32AndOp,
            y,
            { kind: TInstrKind::TI32Const(I32(mask)), .. }
          ),
          ..,
        },
      ) if oi_is_i32_shift(op) =>
        if (mask & 31) == 31 {
          right = y
          changed = true
        }
      (
        _,
        {
          kind: TInstrKind::TBinary(
            I64AndOp,
            y,
            { kind: TInstrKind::TI64Const(I64(mask)), .. }
          ),
          ..,
        },
      ) if oi_is_i64_shift(op) =>
        if (mask & 63L) == 63L {
          right = y
          changed = true
        }
      _ => ()
    }
  }
  if op == BinaryOp::i32_and() {
    match (left, right) {
      (
        { kind: TInstrKind::TUnary(I32EqzOp, x), .. },
        { kind: TInstrKind::TUnary(I32EqzOp, y), .. },
      ) =>
        return Some(
          TInstr::unary(
            UnaryOp::i32_eqz(),
            TInstr::binary(BinaryOp::i32_or(), x, y),
          ),
        )
      _ => ()
    }
  }
  match (op, left, right) {
    (F32AddOp, { kind: TInstrKind::TUnary(F32NegOp, x), .. }, y) =>
      if allow_reorder &&
        allow_expensive_eq &&
        oi_can_reorder_cached(x, y, cache) {
        return Some(TInstr::binary(BinaryOp::f32_sub(), y, x))
      }
    (F64AddOp, { kind: TInstrKind::TUnary(F64NegOp, x), .. }, y) =>
      if allow_reorder &&
        allow_expensive_eq &&
        oi_can_reorder_cached(x, y, cache) {
        return Some(TInstr::binary(BinaryOp::f64_sub(), y, x))
      }
    (F32AddOp, x, { kind: TInstrKind::TUnary(F32NegOp, y), .. }) =>
      return Some(TInstr::binary(BinaryOp::f32_sub(), x, y))
    (F64AddOp, x, { kind: TInstrKind::TUnary(F64NegOp, y), .. }) =>
      return Some(TInstr::binary(BinaryOp::f64_sub(), x, y))
    (F32SubOp, x, { kind: TInstrKind::TUnary(F32NegOp, y), .. }) =>
      return Some(TInstr::binary(BinaryOp::f32_add(), x, y))
    (F64SubOp, x, { kind: TInstrKind::TUnary(F64NegOp, y), .. }) =>
      return Some(TInstr::binary(BinaryOp::f64_add(), x, y))
    (
      I32MulOp,
      {
        kind: TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          x
        ),
        ..,
      },
      {
        kind: TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          y
        ),
        ..,
      },
    ) => return Some(TInstr::binary(BinaryOp::i32_mul(), x, y))
    (
      I64MulOp,
      {
        kind: TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          x
        ),
        ..,
      },
      {
        kind: TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          y
        ),
        ..,
      },
    ) => return Some(TInstr::binary(BinaryOp::i64_mul(), x, y))
    (
      I32MulOp,
      {
        kind: TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          x
        ),
        ..,
      },
      y,
    ) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i32_sub(),
            TInstr::i32_const(I32(0)),
            TInstr::binary(BinaryOp::i32_mul(), x, y),
          ),
        )
      }
    (
      I32MulOp,
      x,
      {
        kind: TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          y
        ),
        ..,
      },
    ) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i32_sub(),
            TInstr::i32_const(I32(0)),
            TInstr::binary(BinaryOp::i32_mul(), x, y),
          ),
        )
      }
    (
      I64MulOp,
      {
        kind: TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          x
        ),
        ..,
      },
      y,
    ) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i64_sub(),
            TInstr::i64_const(I64(0L)),
            TInstr::binary(BinaryOp::i64_mul(), x, y),
          ),
        )
      }
    (
      I64MulOp,
      x,
      {
        kind: TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          y
        ),
        ..,
      },
    ) =>
      if !oi_is_const(x) && !oi_is_const(y) {
        return Some(
          TInstr::binary(
            BinaryOp::i64_sub(),
            TInstr::i64_const(I64(0L)),
            TInstr::binary(BinaryOp::i64_mul(), x, y),
          ),
        )
      }
    (
      F32MulOp,
      { kind: TInstrKind::TUnary(F32AbsOp, x), .. },
      { kind: TInstrKind::TUnary(F32AbsOp, y), .. },
    ) =>
      return Some(
        TInstr::unary(
          UnaryOp::f32_abs(),
          TInstr::binary(BinaryOp::f32_mul(), x, y),
        ),
      )
    (
      F64MulOp,
      { kind: TInstrKind::TUnary(F64AbsOp, x), .. },
      { kind: TInstrKind::TUnary(F64AbsOp, y), .. },
    ) =>
      return Some(
        TInstr::unary(
          UnaryOp::f64_abs(),
          TInstr::binary(BinaryOp::f64_mul(), x, y),
        ),
      )
    (
      F32DivOp,
      { kind: TInstrKind::TUnary(F32AbsOp, x), .. },
      { kind: TInstrKind::TUnary(F32AbsOp, y), .. },
    ) =>
      return Some(
        TInstr::unary(
          UnaryOp::f32_abs(),
          TInstr::binary(BinaryOp::f32_div(), x, y),
        ),
      )
    (
      F64DivOp,
      { kind: TInstrKind::TUnary(F64AbsOp, x), .. },
      { kind: TInstrKind::TUnary(F64AbsOp, y), .. },
    ) =>
      return Some(
        TInstr::unary(
          UnaryOp::f64_abs(),
          TInstr::binary(BinaryOp::f64_div(), x, y),
        ),
      )
    _ => ()
  }
  if oi_is_const(right) {
    match oi_optimize_with_const_right(op, left, right, env, options) {
      Some(rep) => return Some(rep)
      None => ()
    }
  }
  if oi_is_const(left) {
    match
      oi_optimize_with_const_left(
        op, left, right, env, cache, allow_expensive_eq,
      ) {
      Some(rep) => return Some(rep)
      None => ()
    }
  }
  match (op, left, right) {
    (
      I32EqOp,
      { kind: TInstrKind::TBinary(I32SubOp, x, y), .. },
      { kind: TInstrKind::TI32Const(I32(0)), .. },
    )
    | (
      I32NeOp,
      { kind: TInstrKind::TBinary(I32SubOp, x, y), .. },
      { kind: TInstrKind::TI32Const(I32(0)), .. },
    )
    | (
      I32GtUOp,
      { kind: TInstrKind::TBinary(I32SubOp, x, y), .. },
      { kind: TInstrKind::TI32Const(I32(0)), .. },
    )
    | (
      I32LeUOp,
      { kind: TInstrKind::TBinary(I32SubOp, x, y), .. },
      { kind: TInstrKind::TI32Const(I32(0)), .. },
    ) => {
      let new_op = match op {
        I32GtUOp => BinaryOp::i32_ne()
        I32LeUOp => BinaryOp::i32_eq()
        _ => op
      }
      return Some(TInstr::binary(new_op, x, y))
    }
    (
      I64EqOp,
      { kind: TInstrKind::TBinary(I64SubOp, x, y), .. },
      { kind: TInstrKind::TI64Const(I64(0L)), .. },
    )
    | (
      I64NeOp,
      { kind: TInstrKind::TBinary(I64SubOp, x, y), .. },
      { kind: TInstrKind::TI64Const(I64(0L)), .. },
    )
    | (
      I64GtUOp,
      { kind: TInstrKind::TBinary(I64SubOp, x, y), .. },
      { kind: TInstrKind::TI64Const(I64(0L)), .. },
    )
    | (
      I64LeUOp,
      { kind: TInstrKind::TBinary(I64SubOp, x, y), .. },
      { kind: TInstrKind::TI64Const(I64(0L)), .. },
    ) => {
      let new_op = match op {
        I64GtUOp => BinaryOp::i64_ne()
        I64LeUOp => BinaryOp::i64_eq()
        _ => op
      }
      return Some(TInstr::binary(new_op, x, y))
    }
    _ => ()
  }
  if allow_fold_equal_operands &&
    oi_binary_can_fold_equal_operands(op) &&
    oi_instr_equal_for_fold(
      left, right, cache, 128, allow_expensive_eq, allow_fold_equal_operands,
    ) &&
    !oi_has_side_effects_cached(left, cache) {
    match op {
      I32SubOp | I32XorOp => return Some(TInstr::i32_const(I32(0)))
      I64SubOp | I64XorOp => return Some(TInstr::i64_const(I64(0L)))
      I32AndOp | I32OrOp | I64AndOp | I64OrOp => return Some(left)
      I32EqOp
      | I32LeSOp
      | I32LeUOp
      | I32GeSOp
      | I32GeUOp
      | I64EqOp
      | I64LeSOp
      | I64LeUOp
      | I64GeSOp
      | I64GeUOp => return Some(TInstr::i32_const(I32(1)))
      I32NeOp
      | I32LtSOp
      | I32LtUOp
      | I32GtSOp
      | I32GtUOp
      | I64NeOp
      | I64LtSOp
      | I64LtUOp
      | I64GtSOp
      | I64GtUOp => return Some(TInstr::i32_const(I32(0)))
      _ => ()
    }
  }
  if changed {
    Some(oi_make_binary(op, left, right))
  } else {
    None
  }
}

///|
fn oi_optimize_unary(
  op : UnaryOp,
  value : TInstr,
  _env : Env,
  options : OptimizeOptions,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> TInstr? {
  match (op, value) {
    (I32EqzOp, { kind: TInstrKind::TBinary(I32SubOp, x, y), .. }) =>
      Some(TInstr::binary(BinaryOp::i32_eq(), x, y))
    (I64EqzOp, { kind: TInstrKind::TBinary(I64SubOp, x, y), .. }) =>
      Some(TInstr::binary(BinaryOp::i64_eq(), x, y))
    (
      I32EqzOp,
      {
        kind: TInstrKind::TBinary(
          I32AddOp,
          x,
          { kind: TInstrKind::TI32Const(I32(c)), .. }
        ),
        ..,
      },
    ) =>
      Some(
        TInstr::binary(
          BinaryOp::i32_eq(),
          x,
          TInstr::i32_const(I32(oi_wrap_i32(-c))),
        ),
      )
    (
      I64EqzOp,
      {
        kind: TInstrKind::TBinary(
          I64AddOp,
          x,
          { kind: TInstrKind::TI64Const(I64(c)), .. }
        ),
        ..,
      },
    ) =>
      Some(
        TInstr::binary(
          BinaryOp::i64_eq(),
          x,
          TInstr::i64_const(I64(oi_wrap_i64(-c))),
        ),
      )
    (I32EqzOp, { kind: TInstrKind::TUnary(I32EqzOp, x), .. }) =>
      if options.shrink_level == 0 {
        Some(TInstr::binary(BinaryOp::i32_ne(), x, TInstr::i32_const(I32(0))))
      } else {
        None
      }
    (I32WrapI64Op, { kind: TInstrKind::TUnary(I64ExtendI32SOp, x), .. })
    | (I32WrapI64Op, { kind: TInstrKind::TUnary(I64ExtendI32UOp, x), .. }) =>
      Some(x)
    (I64ExtendI32SOp, { kind: TInstrKind::TUnary(I32WrapI64Op, x), .. }) =>
      Some(TInstr::unary(UnaryOp::i64_extend32s(), x))
    (
      I32ReinterpretF32Op,
      { kind: TInstrKind::TUnary(F32ReinterpretI32Op, x), .. },
    )
    | (
      I64ReinterpretF64Op,
      { kind: TInstrKind::TUnary(F64ReinterpretI64Op, x), .. },
    )
    | (
      F32ReinterpretI32Op,
      { kind: TInstrKind::TUnary(I32ReinterpretF32Op, x), .. },
    )
    | (
      F64ReinterpretI64Op,
      { kind: TInstrKind::TUnary(I64ReinterpretF64Op, x), .. },
    ) => Some(x)
    (
      I32ReinterpretF32Op,
      { kind: TInstrKind::TLoad(F32LoadOp, memarg, ptr), .. },
    ) => Some(TInstr::load(LoadOp::i32_load(), memarg, ptr))
    (
      F32ReinterpretI32Op,
      { kind: TInstrKind::TLoad(I32LoadOp, memarg, ptr), .. },
    ) => Some(TInstr::load(LoadOp::f32_load(), memarg, ptr))
    (
      I64ReinterpretF64Op,
      { kind: TInstrKind::TLoad(F64LoadOp, memarg, ptr), .. },
    ) => Some(TInstr::load(LoadOp::i64_load(), memarg, ptr))
    (
      F64ReinterpretI64Op,
      { kind: TInstrKind::TLoad(I64LoadOp, memarg, ptr), .. },
    ) => Some(TInstr::load(LoadOp::f64_load(), memarg, ptr))
    (F32AbsOp, { kind: TInstrKind::TUnary(F32NegOp, x), .. }) =>
      Some(TInstr::unary(UnaryOp::f32_abs(), x))
    (F64AbsOp, { kind: TInstrKind::TUnary(F64NegOp, x), .. }) =>
      Some(TInstr::unary(UnaryOp::f64_abs(), x))
    (F32AbsOp, { kind: TInstrKind::TBinary(F32MulOp, x, y), .. }) if allow_expensive_eq &&
      oi_instr_eq_budgeted(x, y, cache, 128) =>
      Some(TInstr::binary(BinaryOp::f32_mul(), x, y))
    (F64AbsOp, { kind: TInstrKind::TBinary(F64MulOp, x, y), .. }) if allow_expensive_eq &&
      oi_instr_eq_budgeted(x, y, cache, 128) =>
      Some(TInstr::binary(BinaryOp::f64_mul(), x, y))
    (F32AbsOp, { kind: TInstrKind::TBinary(F32DivOp, x, y), .. }) if allow_expensive_eq &&
      oi_instr_eq_budgeted(x, y, cache, 128) =>
      Some(TInstr::binary(BinaryOp::f32_div(), x, y))
    (F64AbsOp, { kind: TInstrKind::TBinary(F64DivOp, x, y), .. }) if allow_expensive_eq &&
      oi_instr_eq_budgeted(x, y, cache, 128) =>
      Some(TInstr::binary(BinaryOp::f64_div(), x, y))
    (_, { kind: TInstrKind::TUnary(inner_op, x), .. }) =>
      if inner_op == op {
        match op {
          F32AbsOp
          | F32CeilOp
          | F32FloorOp
          | F32TruncOp
          | F32NearestOp
          | F64AbsOp
          | F64CeilOp
          | F64FloorOp
          | F64TruncOp
          | F64NearestOp
          | I32Extend8SOp
          | I32Extend16SOp
          | I64Extend8SOp
          | I64Extend16SOp
          | I64Extend32SOp => Some(TInstr::unary(op, x))
          F32NegOp | F64NegOp => Some(x)
          _ => None
        }
      } else {
        None
      }
    (I32EqzOp, { kind: TInstrKind::TBinary(bin_op, x, y), .. }) =>
      match oi_invert_relational(bin_op) {
        Some(inv) => Some(TInstr::binary(inv, x, y))
        None => None
      }
    _ => None
  }
}

///|
fn oi_memory_is_64(mod : Module, memarg : MemArg) -> Bool {
  let MemArg(_, mem_idx, _) = memarg
  match mem_idx {
    Some(MemIdx(raw)) =>
      match mod.mem_sec {
        Some(MemSec(memories)) =>
          match memories.get(raw.reinterpret_as_int()) {
            Some(MemType(I64Limits(_, _))) => true
            _ => false
          }
        None => false
      }
    None =>
      match mod.mem_sec {
        Some(MemSec(memories)) =>
          match memories.get(0) {
            Some(MemType(I64Limits(_, _))) => true
            _ => false
          }
        None => false
      }
  }
}

///|
fn oi_fold_const_ptr_offset(
  ptr : TInstr,
  memarg : MemArg,
  mod : Module,
) -> (TInstr, MemArg) {
  let MemArg(align, mem, U64(offset)) = memarg
  if offset == 0UL {
    return (ptr, memarg)
  }
  match ptr.kind {
    TInstrKind::TI32Const(I32(v)) if !oi_memory_is_64(mod, memarg) => {
      let value64 = v.reinterpret_as_uint().to_uint64()
      let max32 = 0x7fffffffUL
      if value64 <= max32 && offset <= max32 && value64 + offset <= max32 {
        let total = value64 + offset
        let out = total.to_uint().reinterpret_as_int()
        (TInstr::i32_const(I32(out)), MemArg::new(align, mem, U64(0UL)))
      } else {
        (ptr, memarg)
      }
    }
    TInstrKind::TI64Const(I64(v)) if oi_memory_is_64(mod, memarg) => {
      let value64 = v.reinterpret_as_uint64()
      let total = value64 + offset
      if total >= value64 {
        (
          TInstr::i64_const(I64(total.reinterpret_as_int64())),
          MemArg::new(align, mem, U64(0UL)),
        )
      } else {
        (ptr, memarg)
      }
    }
    _ => (ptr, memarg)
  }
}

///|
fn oi_store_bytes(op : StoreOp) -> Int {
  match op {
    I32Store8Op | I64Store8Op | I32AtomicStore8Op | I64AtomicStore8Op => 1
    I32Store16Op | I64Store16Op | I32AtomicStore16Op | I64AtomicStore16Op => 2
    I32StoreOp
    | F32StoreOp
    | I64Store32Op
    | I32AtomicStoreOp
    | I64AtomicStore32Op => 4
    I64StoreOp | F64StoreOp | I64AtomicStoreOp => 8
    V128StoreOp => 16
  }
}

///|
fn oi_store_wrap_upgrade(op : StoreOp) -> StoreOp? {
  match op {
    I32StoreOp => Some(StoreOp::i64_store32())
    I32Store16Op => Some(StoreOp::i64_store16())
    I32Store8Op => Some(StoreOp::i64_store8())
    _ => None
  }
}

///|
fn oi_reinterpret_store(op : StoreOp, value : TInstr) -> (StoreOp, TInstr)? {
  match (op, value) {
    (F32StoreOp, { kind: TInstrKind::TUnary(F32ReinterpretI32Op, x), .. }) =>
      Some((StoreOp::i32_store(), x))
    (I32StoreOp, { kind: TInstrKind::TUnary(I32ReinterpretF32Op, x), .. }) =>
      Some((StoreOp::f32_store(), x))
    (F64StoreOp, { kind: TInstrKind::TUnary(F64ReinterpretI64Op, x), .. }) =>
      Some((StoreOp::i64_store(), x))
    (I64StoreOp, { kind: TInstrKind::TUnary(I64ReinterpretF64Op, x), .. }) =>
      Some((StoreOp::f64_store(), x))
    _ => None
  }
}

///|
fn oi_optimize_store_value(op : StoreOp, value : TInstr) -> (TInstr, Bool) {
  let bytes = oi_store_bytes(op)
  let mut changed = false
  let value = match value.kind {
    TInstrKind::TI32Const(I32(v)) if bytes < 4 => {
      let mask = match bytes {
        1 => 0xff
        2 => 0xffff
        _ => 0xffffffff
      }
      let next = oi_wrap_i32(v & mask)
      if next != v {
        changed = true
      }
      TInstr::i32_const(I32(next))
    }
    TInstrKind::TI64Const(I64(v)) if bytes < 8 => {
      let mask = match bytes {
        1 => 0xffL
        2 => 0xffffL
        4 => 0xffffffffL
        _ => -1L
      }
      let next = oi_wrap_i64(v & mask)
      if next != v {
        changed = true
      }
      TInstr::i64_const(I64(next))
    }
    _ => value
  }
  match value.kind {
    TInstrKind::TBinary(
      I32AndOp,
      x,
      { kind: TInstrKind::TI32Const(I32(mask)), .. }
    ) =>
      if (bytes == 1 && mask == 0xff) || (bytes == 2 && mask == 0xffff) {
        (x, true)
      } else {
        (value, changed)
      }
    TInstrKind::TBinary(
      I64AndOp,
      x,
      { kind: TInstrKind::TI64Const(I64(mask)), .. }
    ) =>
      if (bytes == 1 && mask == 0xffL) ||
        (bytes == 2 && mask == 0xffffL) ||
        (bytes == 4 && mask == 0xffffffffL) {
        (x, true)
      } else {
        (value, changed)
      }
    _ => (value, changed)
  }
}

///|
fn oi_optimize_memory_copy(
  dst_mem : MemIdx,
  src_mem : MemIdx,
  dest : TInstr,
  source : TInstr,
  size : TInstr,
  env : Env,
) -> TInstr? {
  match size.kind {
    TInstrKind::TI32Const(I32(0)) =>
      Some(
        TInstr::block(
          BlockType::void_(),
          TExpr::new([oi_instr_stmt(dest, env), oi_instr_stmt(source, env)]),
        ),
      )
    TInstrKind::TI32Const(I32(bytes)) =>
      match bytes {
        1 => {
          let load_memarg = MemArg::new(U32(1), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(1), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i32_store8(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i32_load8u(), load_memarg, source),
            ),
          )
        }
        2 => {
          let load_memarg = MemArg::new(U32(2), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(2), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i32_store16(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i32_load16u(), load_memarg, source),
            ),
          )
        }
        4 => {
          let load_memarg = MemArg::new(U32(4), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(4), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i32_store(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i32_load(), load_memarg, source),
            ),
          )
        }
        8 => {
          let load_memarg = MemArg::new(U32(8), Some(src_mem), U64(0UL))
          let store_memarg = MemArg::new(U32(8), Some(dst_mem), U64(0UL))
          Some(
            TInstr::store(
              StoreOp::i64_store(),
              store_memarg,
              dest,
              TInstr::load(LoadOp::i64_load(), load_memarg, source),
            ),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn oi_optimize_memory_fill(
  mem_idx : MemIdx,
  dest : TInstr,
  value : TInstr,
  size : TInstr,
  env : Env,
) -> TInstr? {
  match size.kind {
    TInstrKind::TI32Const(I32(0)) =>
      Some(
        TInstr::block(
          BlockType::void_(),
          TExpr::new([oi_instr_stmt(dest, env), oi_instr_stmt(value, env)]),
        ),
      )
    TInstrKind::TI32Const(I32(1)) =>
      Some(
        TInstr::store(
          StoreOp::i32_store8(),
          MemArg::new(U32(1), Some(mem_idx), U64(0UL)),
          dest,
          value,
        ),
      )
    TInstrKind::TI32Const(I32(bytes)) =>
      match (bytes, value) {
        (1, { kind: TInstrKind::TI32Const(I32(v)), .. }) =>
          Some(
            TInstr::store(
              StoreOp::i32_store8(),
              MemArg::new(U32(1), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i32_const(I32(v & 0xff)),
            ),
          )
        (2, { kind: TInstrKind::TI32Const(I32(v)), .. }) => {
          let x = v & 0xff
          Some(
            TInstr::store(
              StoreOp::i32_store16(),
              MemArg::new(U32(2), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i32_const(I32(oi_wrap_i32(x * 0x0101))),
            ),
          )
        }
        (4, { kind: TInstrKind::TI32Const(I32(v)), .. }) => {
          let x = v & 0xff
          Some(
            TInstr::store(
              StoreOp::i32_store(),
              MemArg::new(U32(4), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i32_const(I32(oi_wrap_i32(x * 0x01010101))),
            ),
          )
        }
        (8, { kind: TInstrKind::TI32Const(I32(v)), .. }) => {
          let x = (v & 0xff).to_int64()
          Some(
            TInstr::store(
              StoreOp::i64_store(),
              MemArg::new(U32(8), Some(mem_idx), U64(0UL)),
              dest,
              TInstr::i64_const(I64(oi_wrap_i64(x * 0x0101010101010101L))),
            ),
          )
        }
        _ => None
      }
    _ => None
  }
}

///|
fn oi_optimize_select(
  _types : Array[ValType]?,
  cond : TInstr,
  if_true : TInstr,
  if_false : TInstr,
  env : Env,
  options : OptimizeOptions,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
  allow_fold_equal_operands : Bool,
) -> TInstr? {
  let cond = oi_optimize_boolean(cond, env, options)
  match cond.kind {
    TInstrKind::TI32Const(I32(v)) =>
      if v == 0 {
        Some(oi_seq([oi_instr_stmt(if_true, env)], if_false, env))
      } else {
        Some(oi_seq([oi_instr_stmt(if_false, env)], if_true, env))
      }
    _ =>
      if allow_expensive_eq &&
        oi_instr_equal_for_fold(
          if_true, if_false, cache, 128, allow_expensive_eq, allow_fold_equal_operands,
        ) {
        if oi_has_side_effects_cached(cond, cache) {
          Some(oi_seq([oi_instr_stmt(cond, env)], if_true, env))
        } else {
          Some(if_true)
        }
      } else {
        let max_bits = match (oi_const_i32(if_true), oi_const_i32(if_false)) {
          (Some(1), Some(0)) => true
          _ => false
        }
        if max_bits {
          Some(cond)
        } else {
          None
        }
      }
  }
}

///|
fn oi_optimize_if(
  bt : BlockType,
  cond : TInstr,
  then_ : TExpr,
  else_ : TExpr?,
  env : Env,
  options : OptimizeOptions,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
) -> TInstr? {
  let next_cond = oi_optimize_boolean(cond, env, options)
  match else_ {
    Some(else_expr) =>
      match next_cond.kind {
        TInstrKind::TUnary(I32EqzOp, value) =>
          Some(TInstr::if_(bt, value, else_expr, Some(then_)))
        _ =>
          if allow_expensive_eq &&
            then_.instrs.length() == else_expr.instrs.length() &&
            oi_texpr_equal_for_fold(
              then_, else_expr, cache, 256, allow_expensive_eq,
            ) {
            if oi_has_side_effects_cached(next_cond, cache) {
              let list = [oi_instr_stmt(next_cond, env)]
              for instr in then_.instrs {
                list.push(instr)
              }
              Some(TInstr::block(bt, TExpr::new(list)))
            } else {
              Some(TInstr::block(bt, then_))
            }
          } else if oi_instr_eq_for_change(
              next_cond, cond, cache, allow_expensive_eq,
            ) {
            None
          } else {
            Some(TInstr::if_(bt, next_cond, then_, Some(else_expr)))
          }
      }
    None =>
      if oi_instr_eq_for_change(next_cond, cond, cache, allow_expensive_eq) {
        None
      } else {
        Some(TInstr::if_(bt, next_cond, then_, None))
      }
  }
}

///|
fn oi_optimize_once(
  instr : TInstr,
  env : Env,
  options : OptimizeOptions,
  mod : Module,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
  allow_reorder : Bool,
  allow_fold_equal_operands : Bool,
) -> (TInstr, Bool) {
  match instr.kind {
    TInstrKind::TBinary(op, left, right) =>
      match
        oi_optimize_binary(
          op, left, right, env, options, cache, allow_expensive_eq, allow_reorder,
          allow_fold_equal_operands,
        ) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TUnary(op, value) =>
      match
        oi_optimize_unary(op, value, env, options, cache, allow_expensive_eq) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TSelect(types, cond, if_true, if_false) =>
      match
        oi_optimize_select(
          types, cond, if_true, if_false, env, options, cache, allow_expensive_eq,
          allow_fold_equal_operands,
        ) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TIf(bt, cond, then_, else_) =>
      match
        oi_optimize_if(
          bt, cond, then_, else_, env, options, cache, allow_expensive_eq,
        ) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TGlobalSet(idx, { kind: TInstrKind::TGlobalGet(get_idx), .. }) if idx ==
      get_idx => (TInstr::nop(), true)
    TInstrKind::TBrIf(label, cond, values) => {
      let next_cond = oi_optimize_boolean(cond, env, options)
      if oi_instr_eq_for_change(next_cond, cond, cache, allow_expensive_eq) {
        (instr, false)
      } else {
        (TInstr::br_if(label, next_cond, values), true)
      }
    }
    TInstrKind::TLoad(op, memarg, ptr) => {
      let (next_ptr, next_memarg) = oi_fold_const_ptr_offset(ptr, memarg, mod)
      if next_ptr == ptr && next_memarg == memarg {
        (instr, false)
      } else {
        (TInstr::load(op, next_memarg, next_ptr), true)
      }
    }
    TInstrKind::TStore(op, memarg, ptr, value) => {
      let (next_ptr, next_memarg) = oi_fold_const_ptr_offset(ptr, memarg, mod)
      let mut changed = next_ptr != ptr || next_memarg != memarg
      let mut next_op = op
      let (store_value, value_changed) = oi_optimize_store_value(op, value)
      let mut next_value = store_value
      if value_changed {
        changed = true
      }
      match next_value.kind {
        TInstrKind::TUnary(I32WrapI64Op, inner) =>
          match oi_store_wrap_upgrade(next_op) {
            Some(upgraded) => {
              next_op = upgraded
              next_value = inner
              changed = true
            }
            None => ()
          }
        _ => ()
      }
      match oi_reinterpret_store(next_op, next_value) {
        Some((rewritten_op, rewritten_value)) => {
          next_op = rewritten_op
          next_value = rewritten_value
          changed = true
        }
        None => ()
      }
      if changed {
        (TInstr::store(next_op, next_memarg, next_ptr, next_value), true)
      } else {
        (instr, false)
      }
    }
    TInstrKind::TMemoryCopy(dst_mem, src_mem, dest, source, size) =>
      match oi_optimize_memory_copy(dst_mem, src_mem, dest, source, size, env) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TMemoryFill(mem_idx, dest, value, size) =>
      match oi_optimize_memory_fill(mem_idx, dest, value, size, env) {
        Some(rep) => (rep, true)
        None => (instr, false)
      }
    TInstrKind::TCallRef(type_idx, args, target) =>
      match target.kind {
        TInstrKind::TRefFunc(func_idx) => (TInstr::call(func_idx, args), true)
        TInstrKind::TTableGet(table_idx, index) =>
          (TInstr::call_indirect(type_idx, table_idx, args, index), true)
        _ => (instr, false)
      }
    _ => (instr, false)
  }
}

///|
fn oi_optimize_fixpoint(
  instr : TInstr,
  env : Env,
  options : OptimizeOptions,
  mod : Module,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
  allow_reorder : Bool,
  allow_fold_equal_operands : Bool,
  max_fixpoint_rounds : Int,
) -> (TInstr, Int, Bool) {
  let mut curr = instr
  let mut rounds = 0
  let mut changed = false
  while rounds < max_fixpoint_rounds {
    rounds += 1
    let (next, step_changed) = oi_optimize_once(
      curr, env, options, mod, cache, allow_expensive_eq, allow_reorder, allow_fold_equal_operands,
    )
    if !step_changed {
      break
    }
    changed = true
    curr = next
    if !oi_instr_is_rewrite_candidate(curr) {
      break
    }
  }
  (curr, rounds, changed)
}

///|
priv struct OIRewriteState {
  env : Env
  options : OptimizeOptions
  module_ : Module
  cache : OIRewriteCache
  allow_expensive_eq : Bool
  allow_reorder : Bool
  allow_fold_equal_operands : Bool
  max_fixpoint_rounds : Int
  visited_instr_budget : Int
  candidate_size_budget : Int
  mut visited_instrs : Int
  mut candidate_instrs : Int
  mut rewritten_instrs : Int
  mut max_rounds : Int
  mut did_change : Bool
}

///|
fn oi_rewrite_state_new(
  env : Env,
  options : OptimizeOptions,
  module_ : Module,
  cache : OIRewriteCache,
  allow_expensive_eq : Bool,
  allow_reorder : Bool,
  allow_fold_equal_operands : Bool,
  max_fixpoint_rounds : Int,
  visited_instr_budget : Int,
  candidate_size_budget : Int,
) -> OIRewriteState {
  OIRewriteState::{
    env,
    options,
    module_,
    cache,
    allow_expensive_eq,
    allow_reorder,
    allow_fold_equal_operands,
    max_fixpoint_rounds,
    visited_instr_budget,
    candidate_size_budget,
    visited_instrs: 0,
    candidate_instrs: 0,
    rewritten_instrs: 0,
    max_rounds: 0,
    did_change: false,
  }
}

///|
fn oi_rewrite_non_control_children(
  instr : TInstr,
  state : OIRewriteState,
) -> (TInstr, Bool) {
  let children : Array[TInstr] = []
  let mut changed = false
  oi_for_each_non_control_child(instr, fn(child) {
    let (next_child, child_changed) = oi_rewrite_instr_bottom_up(child, state)
    if child_changed {
      changed = true
    }
    children.push(next_child)
  })
  if changed {
    (oi_rebuild_non_control(instr, children), true)
  } else {
    (instr, false)
  }
}

///|
fn oi_rewrite_texpr_bottom_up(
  body : TExpr,
  state : OIRewriteState,
) -> (TExpr, Bool) {
  if body.instrs.is_empty() {
    return (body, false)
  }
  let out : Array[TInstr] = Array::new(capacity=body.instrs.length())
  let mut changed = false
  for instr in body.instrs {
    if state.visited_instrs >= state.visited_instr_budget {
      out.push(instr)
      continue
    }
    let (next_instr, instr_changed) = oi_rewrite_instr_bottom_up(instr, state)
    if instr_changed {
      changed = true
    }
    out.push(next_instr)
  }
  if changed {
    (TExpr::new(out), true)
  } else {
    (body, false)
  }
}

///|
fn oi_rewrite_instr_bottom_up(
  instr : TInstr,
  state : OIRewriteState,
) -> (TInstr, Bool) {
  if state.visited_instrs >= state.visited_instr_budget {
    return (instr, false)
  }
  let (walked, child_changed) = match instr.kind {
    TInstrKind::TBlock(bt, body) => {
      let (next_body, body_changed) = oi_rewrite_texpr_bottom_up(body, state)
      if body_changed {
        (TInstr::block(bt, next_body), true)
      } else {
        (instr, false)
      }
    }
    TInstrKind::TLoop(bt, body) => {
      let (next_body, body_changed) = oi_rewrite_texpr_bottom_up(body, state)
      if body_changed {
        (TInstr::loop_(bt, next_body), true)
      } else {
        (instr, false)
      }
    }
    TInstrKind::TIf(bt, cond, then_, else_) => {
      let (next_cond, cond_changed) = oi_rewrite_instr_bottom_up(cond, state)
      let (next_then, then_changed) = oi_rewrite_texpr_bottom_up(then_, state)
      let mut else_changed = false
      let next_else = match else_ {
        Some(other) => {
          let (next_other, other_changed) = oi_rewrite_texpr_bottom_up(
            other, state,
          )
          else_changed = other_changed
          Some(next_other)
        }
        None => None
      }
      if cond_changed || then_changed || else_changed {
        (TInstr::if_(bt, next_cond, next_then, next_else), true)
      } else {
        (instr, false)
      }
    }
    TInstrKind::TTryTable(bt, catches, body) => {
      let (next_body, body_changed) = oi_rewrite_texpr_bottom_up(body, state)
      if body_changed {
        (TInstr::try_table(bt, catches, next_body), true)
      } else {
        (instr, false)
      }
    }
    _ => oi_rewrite_non_control_children(instr, state)
  }
  state.visited_instrs = state.visited_instrs + 1
  if !oi_should_attempt_fixpoint(walked) {
    return (walked, child_changed)
  }
  if state.allow_expensive_eq &&
    oi_instr_size_cached(walked, state.cache) > state.candidate_size_budget {
    return (walked, child_changed)
  }
  state.candidate_instrs = state.candidate_instrs + 1
  let (rewritten, rounds, rewritten_here) = oi_optimize_fixpoint(
    walked,
    state.env,
    state.options,
    state.module_,
    state.cache,
    state.allow_expensive_eq,
    state.allow_reorder,
    state.allow_fold_equal_operands,
    state.max_fixpoint_rounds,
  )
  if rounds > state.max_rounds {
    state.max_rounds = rounds
  }
  if rewritten_here {
    state.rewritten_instrs = state.rewritten_instrs + 1
    state.did_change = true
    (rewritten, true)
  } else {
    (walked, child_changed)
  }
}

///|
priv struct OITransformStats {
  top_instrs : Int
  skipped_no_candidates : Bool
  did_change : Bool
  visited_instrs : Int
  candidate_instrs : Int
  rewritten_instrs : Int
  max_rounds : Int
  node_id_get_calls : Int
  node_id_put_calls : Int
  eq_calls : Int
  reorder_calls : Int
  node_id_lookup_us : UInt64
  fingerprint_us : UInt64
  register_us : UInt64
  eq_us : UInt64
  reorder_us : UInt64
  max_body_len : Int
  prescan_us : UInt64
  env_us : UInt64
  rewrite_us : UInt64
}

///|
fn oi_transform_stats_new(top_instrs : Int) -> OITransformStats {
  OITransformStats::{
    top_instrs,
    skipped_no_candidates: false,
    did_change: false,
    visited_instrs: 0,
    candidate_instrs: 0,
    rewritten_instrs: 0,
    max_rounds: 0,
    node_id_get_calls: 0,
    node_id_put_calls: 0,
    eq_calls: 0,
    reorder_calls: 0,
    node_id_lookup_us: 0UL,
    fingerprint_us: 0UL,
    register_us: 0UL,
    eq_us: 0UL,
    reorder_us: 0UL,
    max_body_len: 0,
    prescan_us: 0UL,
    env_us: 0UL,
    rewrite_us: 0UL,
  }
}

///|
fn oi_trace_noop(_ : String) -> Unit {
  ()
}

///|
fn oi_trace_delta_us_to_ms(delta_us : UInt64) -> UInt64 {
  delta_us / 1000UL
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn oi_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn oi_trace_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
  let mut out = 0UL
  let mut i = 0
  while i < 8 {
    out = out | (bytes[start + i].to_uint64() << (i * 8))
    i += 1
  }
  out
}

///|
#cfg(target="native")
fn oi_trace_now_us() -> UInt64 {
  let tv = Bytes::new(16)
  if oi_native_gettimeofday(tv, 0UL) != 0 {
    return @env.now() * 1000UL
  }
  let sec = oi_trace_read_u64_le(tv, 0)
  let usec = oi_trace_read_u64_le(tv, 8)
  sec * 1000000UL + usec
}

///|
#cfg(target="wasm-gc")
fn oi_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="wasm")
fn oi_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="js")
fn oi_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
#cfg(target="llvm")
fn oi_trace_now_us() -> UInt64 {
  @env.now() * 1000UL
}

///|
fn optimize_instructions_on_func(
  func : Func,
  mod : Module,
  options : OptimizeOptions,
  base_env : Env,
) -> (Func, OITransformStats) {
  match func {
    TFunc(locals, body) => {
      let top_instrs = body.instrs.length()
      if top_instrs > 25000 {
        return (
          func,
          OITransformStats::{
            top_instrs,
            skipped_no_candidates: true,
            did_change: false,
            visited_instrs: 0,
            candidate_instrs: 0,
            rewritten_instrs: 0,
            max_rounds: 0,
            node_id_get_calls: 0,
            node_id_put_calls: 0,
            eq_calls: 0,
            reorder_calls: 0,
            node_id_lookup_us: 0UL,
            fingerprint_us: 0UL,
            register_us: 0UL,
            eq_us: 0UL,
            reorder_us: 0UL,
            max_body_len: 0,
            prescan_us: 0UL,
            env_us: 0UL,
            rewrite_us: 0UL,
          },
        )
      }
      let max_fixpoint_rounds = if top_instrs > 3000 { 1 } else { 2 }
      let prescan_start_us = oi_trace_now_us()
      let scan_budget = oi_rewrite_candidate_scan_budget(top_instrs)
      let rewrite_needs_flags = oi_texpr_scan_rewrite_needs(body, scan_budget)
      let prescan_us = oi_trace_elapsed_us_since(prescan_start_us)
      if !oi_rewrite_needs_has(
          rewrite_needs_flags, oi_rewrite_need_has_candidate,
        ) {
        return (
          func,
          OITransformStats::{
            top_instrs,
            skipped_no_candidates: true,
            did_change: false,
            visited_instrs: 0,
            candidate_instrs: 0,
            rewritten_instrs: 0,
            max_rounds: 0,
            node_id_get_calls: 0,
            node_id_put_calls: 0,
            eq_calls: 0,
            reorder_calls: 0,
            node_id_lookup_us: 0UL,
            fingerprint_us: 0UL,
            register_us: 0UL,
            eq_us: 0UL,
            reorder_us: 0UL,
            max_body_len: 0,
            prescan_us,
            env_us: 0UL,
            rewrite_us: 0UL,
          },
        )
      }
      let allow_expensive_eq = top_instrs <= 2000 &&
        oi_rewrite_needs_has(rewrite_needs_flags, oi_rewrite_need_expensive_eq)
      let allow_reorder = top_instrs <= 3000 &&
        oi_rewrite_needs_has(rewrite_needs_flags, oi_rewrite_need_reorder) &&
        allow_expensive_eq
      let allow_fold_equal_operands = top_instrs <= 5000 &&
        oi_rewrite_needs_has(
          rewrite_needs_flags, oi_rewrite_need_fold_equal_operands,
        )
      let env_start_us = oi_trace_now_us()
      let env = base_env.with_locals(locals)
      let env_us = oi_trace_elapsed_us_since(env_start_us)
      let visited_instr_budget = if top_instrs > 12000 {
        top_instrs / 6
      } else if top_instrs > 6000 {
        top_instrs / 2
      } else {
        50000
      }
      let candidate_size_budget = if top_instrs > 12000 {
        24
      } else if top_instrs > 6000 {
        32
      } else {
        128
      }
      let pair_cache_size = if top_instrs > 12000 {
        8192
      } else if top_instrs > 4000 {
        4096
      } else {
        2048
      }
      let cache = oi_rewrite_cache_new(
        local_count=locals.length(),
        pair_cache_size~,
      )
      let state = oi_rewrite_state_new(
        env, options, mod, cache, allow_expensive_eq, allow_reorder, allow_fold_equal_operands,
        max_fixpoint_rounds, visited_instr_budget, candidate_size_budget,
      )
      let rewrite_start_us = oi_trace_now_us()
      let (new_body, body_changed) = oi_rewrite_texpr_bottom_up(body, state)
      let rewrite_us = oi_trace_elapsed_us_since(rewrite_start_us)
      let did_change = state.did_change || body_changed
      (
        if did_change {
          Func::t_func(locals, new_body)
        } else {
          func
        },
        OITransformStats::{
          top_instrs,
          skipped_no_candidates: false,
          did_change,
          visited_instrs: state.visited_instrs,
          candidate_instrs: state.candidate_instrs,
          rewritten_instrs: state.rewritten_instrs,
          max_rounds: state.max_rounds,
          node_id_get_calls: cache.node_id_get_calls,
          node_id_put_calls: cache.node_id_put_calls,
          eq_calls: cache.eq_calls,
          reorder_calls: cache.reorder_calls,
          node_id_lookup_us: cache.node_id_lookup_us,
          fingerprint_us: cache.fingerprint_us,
          register_us: cache.register_us,
          eq_us: cache.eq_us,
          reorder_us: cache.reorder_us,
          max_body_len: cache.max_body_len,
          prescan_us,
          env_us,
          rewrite_us,
        },
      )
    }
    _ => (func, oi_transform_stats_new(0))
  }
}

///|
fn optimize_instructions_ir_pass(
  mod : Module,
  options : OptimizeOptions,
  trace? : (String) -> Unit = oi_trace_noop,
  trace_all_funcs? : Bool = true,
) -> ModuleTransformer[IRContext] {
  let mut seen_funcs = 0
  let base_env = Env::new().with_module(mod)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    seen_funcs += 1
    let ordinal = seen_funcs
    let log_func = trace_all_funcs || ordinal <= 5 || ordinal % 50 == 0
    let top_instrs = match func {
      TFunc(_, body) => body.instrs.length()
      _ => 0
    }
    let locals_count = match func {
      TFunc(locals, _) => locals.length()
      _ => 0
    }
    let tracked_words = oi_local_bit_words_tracked(locals_count)
    if log_func {
      trace(
        "func[\{ordinal}] start top_instrs=\{top_instrs} locals=\{locals_count} local_bit_words=\{tracked_words}",
      )
    }
    let start_us = oi_trace_now_us()
    let (next, stats) = optimize_instructions_on_func(
      func, mod, options, base_env,
    )
    let end_us = oi_trace_now_us()
    let elapsed_us = if end_us >= start_us { end_us - start_us } else { 0UL }
    let elapsed_ms = oi_trace_delta_us_to_ms(elapsed_us)
    let log_heavy_func = stats.visited_instrs >= 20000 ||
      stats.candidate_instrs >= 5000
    let lookup_ms = oi_trace_delta_us_to_ms(stats.node_id_lookup_us)
    let fingerprint_ms = oi_trace_delta_us_to_ms(stats.fingerprint_us)
    let register_ms = oi_trace_delta_us_to_ms(stats.register_us)
    let eq_ms = oi_trace_delta_us_to_ms(stats.eq_us)
    let reorder_ms = oi_trace_delta_us_to_ms(stats.reorder_us)
    let prescan_ms = oi_trace_delta_us_to_ms(stats.prescan_us)
    let env_ms = oi_trace_delta_us_to_ms(stats.env_us)
    let rewrite_ms = oi_trace_delta_us_to_ms(stats.rewrite_us)
    let log_slow_measurement = elapsed_ms >= 250 ||
      prescan_ms >= 50 ||
      env_ms >= 50 ||
      rewrite_ms >= 50 ||
      lookup_ms >= 50 ||
      fingerprint_ms >= 50 ||
      register_ms >= 50 ||
      eq_ms >= 50 ||
      reorder_ms >= 50
    if log_func || log_heavy_func || log_slow_measurement {
      trace(
        "func[\{ordinal}] done elapsed_ms=\{elapsed_ms} elapsed_us=\{elapsed_us} start_us=\{start_us} end_us=\{end_us} changed=\{stats.did_change} skipped=\{stats.skipped_no_candidates} top_instrs=\{stats.top_instrs} visited=\{stats.visited_instrs} candidates=\{stats.candidate_instrs} rewritten=\{stats.rewritten_instrs} max_rounds=\{stats.max_rounds}",
      )
      if log_slow_measurement {
        trace(
          "func[\{ordinal}] slow-path max_body_len=\{stats.max_body_len} prescan_ms=\{prescan_ms} env_ms=\{env_ms} rewrite_ms=\{rewrite_ms} node_id_get_calls=\{stats.node_id_get_calls} node_id_put_calls=\{stats.node_id_put_calls} eq_calls=\{stats.eq_calls} reorder_calls=\{stats.reorder_calls} lookup_ms=\{lookup_ms} fingerprint_ms=\{fingerprint_ms} register_ms=\{register_ms} eq_ms=\{eq_ms} reorder_ms=\{reorder_ms}",
        )
      }
    }
    // Returning `unchanged()` here would trigger `walk_func_default`,
    // causing a second traversal of this function.
    change(ctx, next)
  })
}

///|
fn oi_run_func(
  body : Array[TInstr],
  locals? : Array[ValType] = [],
  options? : OptimizeOptions = OptimizeOptions::new(),
  with_memory? : Bool = false,
) -> TExpr {
  let mut mod_ = Module::new().with_code_sec(
    CodeSec::new([Func::t_func(locals, TExpr::new(body))]),
  )
  if with_memory {
    mod_ = mod_.with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
  }
  let out = optimize_module_with_options(
    mod_,
    [ModulePass::OptimizeInstructions],
    options,
  ).unwrap()
  match out.code_sec {
    Some(CodeSec([TFunc(_, out_body)])) => out_body
    _ => abort("expected one transformed function")
  }
}

///|
test "optimize instructions eqz(sub) to eq" {
  let body = oi_run_func(
    [
      TInstr::unary(
        UnaryOp::i32_eqz(),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32EqOp,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. },
            { kind: TInstrKind::TLocalGet(LocalIdx(j)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => {
      assert_eq(i.reinterpret_as_int(), 0)
      assert_eq(j.reinterpret_as_int(), 1)
    }
    _ => fail("expected i32.eq")
  }
}

///|
test "optimize instructions eqz(add const) to eq neg const" {
  let body = oi_run_func(
    [
      TInstr::unary(
        UnaryOp::i32_eqz(),
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(5)),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32EqOp,
            { kind: TInstrKind::TLocalGet(_), .. },
            { kind: TInstrKind::TI32Const(I32(v)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(v, -5)
    _ => fail("expected i32.eq with negated constant")
  }
}

///|
test "optimize instructions de-morgan eqz and" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_and(),
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(1))),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TUnary(
            I32EqzOp,
            { kind: TInstrKind::TBinary(I32OrOp, _, _), .. }
          ),
          ..,
        },
      ],
      ..,
    } => ()
    _ => fail("expected eqz(or)")
  }
}

///|
test "optimize instructions masks shift constants and removes zero shifts" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_shl(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(32)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [{ kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }], .. } =>
      assert_eq(i.reinterpret_as_int(), 0)
    _ => fail("expected shift-by-32 to collapse to lhs")
  }
}

///|
test "optimize instructions removes rhs mask in shifts" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_shl(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::binary(
          BinaryOp::i32_and(),
          TInstr::local_get(LocalIdx::new(1)),
          TInstr::i32_const(I32(31)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32ShlOp,
            _,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(i.reinterpret_as_int(), 1)
    _ => fail("expected shift rhs to be simplified to local.get")
  }
}

///|
test "optimize instructions float add neg rhs to sub" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::f32_add(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::unary(UnaryOp::f32_neg(), TInstr::local_get(LocalIdx::new(1))),
      ),
    ],
    locals=[ValType::f32(), ValType::f32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            F32SubOp,
            _,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(i.reinterpret_as_int(), 1)
    _ => fail("expected f32.sub")
  }
}

///|
test "optimize instructions int neg multiply patterns" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::i32_const(I32(0)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::i32_const(I32(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32MulOp,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. },
            { kind: TInstrKind::TLocalGet(LocalIdx(j)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => {
      assert_eq(i.reinterpret_as_int(), 0)
      assert_eq(j.reinterpret_as_int(), 1)
    }
    _ => fail("expected -x * -y => x * y")
  }
}

///|
test "optimize instructions unsigned compare constants" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_ge_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::binary(
        BinaryOp::i32_lt_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [_, _], .. } => ()
    _ => fail("expected two instructions")
  }
  match body {
    { instrs: [first, second], .. } => {
      match first.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TDrop({ kind: TInstrKind::TLocalGet(_), .. }),
                ..,
              },
              { kind: TInstrKind::TI32Const(I32(v)), .. },
            ],
            ..,
          }
        ) => assert_eq(v, 1)
        _ => fail("expected ge_u 0 => 1 preserving lhs")
      }
      match second.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TDrop({ kind: TInstrKind::TLocalGet(_), .. }),
                ..,
              },
              { kind: TInstrKind::TI32Const(I32(v)), .. },
            ],
            ..,
          }
        ) => assert_eq(v, 0)
        _ => fail("expected lt_u 0 => 0 preserving lhs")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions power-of-two integer arithmetic" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
      TInstr::binary(
        BinaryOp::i32_div_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
      TInstr::binary(
        BinaryOp::i32_rem_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(8)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [mul_i, div_i, rem_i], .. } => {
      match mul_i.kind {
        TInstrKind::TBinary(
          I32ShlOp,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 3)
        _ => fail("expected mul by 8 => shl 3")
      }
      match div_i.kind {
        TInstrKind::TBinary(
          I32ShrUOp,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 3)
        _ => fail("expected div_u by 8 => shr_u 3")
      }
      match rem_i.kind {
        TInstrKind::TBinary(
          I32AndOp,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 7)
        _ => fail("expected rem_u by 8 => and 7")
      }
    }
    _ => fail("expected three rewritten instructions")
  }
}

///|
test "optimize instructions arithmetic trivial constants" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_and(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(-1)),
      ),
      TInstr::binary(
        BinaryOp::i32_or(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(-1)),
      ),
      TInstr::binary(
        BinaryOp::i32_eq(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(-1)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [a0, a1, a2, a3], .. } => {
      match a0.kind {
        TInstrKind::TLocalGet(_) => ()
        _ => fail("expected and -1 => x")
      }
      match a1.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TDrop(_), .. },
              { kind: TInstrKind::TI32Const(I32(-1)), .. },
            ],
            ..,
          }
        ) => ()
        _ => fail("expected or -1 => -1 with drop")
      }
      match a2.kind {
        TInstrKind::TUnary(I32EqzOp, _) => ()
        _ => fail("expected eq 0 => eqz")
      }
      match a3.kind {
        TInstrKind::TBinary(
          I32SubOp,
          { kind: TInstrKind::TI32Const(I32(0)), .. },
          _
        ) => ()
        _ => fail("expected mul -1 => 0 - x")
      }
    }
    _ => fail("expected four rewritten instructions")
  }
}

///|
test "optimize instructions constant-left subtraction patterns" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_sub(),
        TInstr::i32_const(I32(10)),
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(4)),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32SubOp,
            { kind: TInstrKind::TI32Const(I32(c)), .. },
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => {
      assert_eq(c, 6)
      assert_eq(i.reinterpret_as_int(), 0)
    }
    _ => fail("expected C1 - (x + C2) rewrite")
  }
}

///|
test "optimize instructions relational x-y compare to zero" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_eq(),
        TInstr::binary(
          BinaryOp::i32_sub(),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
        TInstr::i32_const(I32(0)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TBinary(
            I32EqOp,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. },
            { kind: TInstrKind::TLocalGet(LocalIdx(j)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => {
      assert_eq(i.reinterpret_as_int(), 0)
      assert_eq(j.reinterpret_as_int(), 1)
    }
    _ => fail("expected x-y==0 => x==y")
  }
}

///|
test "optimize instructions deduplicate equal binary children" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i32_xor(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
      TInstr::binary(
        BinaryOp::i32_eq(),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::local_get(LocalIdx::new(1)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  match body {
    { instrs: [a0, a1], .. } => {
      match a0.kind {
        TInstrKind::TI32Const(I32(0)) => ()
        _ => fail("expected x xor x => 0")
      }
      match a1.kind {
        TInstrKind::TI32Const(I32(1)) => ()
        _ => fail("expected x eq x => 1")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions reinterpret chains and load reinterpret" {
  let body = oi_run_func(
    [
      TInstr::unary(
        UnaryOp::i32_reinterpret_f32(),
        TInstr::unary(
          UnaryOp::f32_reinterpret_i32(),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
      TInstr::unary(
        UnaryOp::i32_reinterpret_f32(),
        TInstr::load(
          LoadOp::f32_load(),
          MemArg::new(U32(4), None, U64(0UL)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    { instrs: [a0, a1], .. } => {
      match a0.kind {
        TInstrKind::TLocalGet(LocalIdx(i)) =>
          assert_eq(i.reinterpret_as_int(), 0)
        _ => fail("expected reinterpret(reinterpret(x)) => x")
      }
      match a1.kind {
        TInstrKind::TLoad(I32LoadOp, _, _) => ()
        _ => fail("expected reinterpret(f32.load) => i32.load")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions if eqz arm flip and fold identical arms" {
  let body = oi_run_func(
    [
      TInstr::if_(
        BlockType::void_(),
        TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
        TExpr::new([TInstr::i32_const(I32(1))]),
        Some(TExpr::new([TInstr::i32_const(I32(2))])),
      ),
      TInstr::if_(
        BlockType::val_type(ValType::i32()),
        TInstr::local_get(LocalIdx::new(0)),
        TExpr::new([TInstr::i32_const(I32(7))]),
        Some(TExpr::new([TInstr::i32_const(I32(7))])),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [a0, a1], .. } => {
      match a0.kind {
        TInstrKind::TIf(
          _,
          { kind: TInstrKind::TLocalGet(_), .. },
          { instrs: [{ kind: TInstrKind::TI32Const(I32(2)), .. }], .. },
          Some({ instrs: [{ kind: TInstrKind::TI32Const(I32(1)), .. }], .. })
        ) => ()
        _ => fail("expected if eqz flip")
      }
      match a1.kind {
        TInstrKind::TBlock(
          _,
          { instrs: [{ kind: TInstrKind::TI32Const(I32(7)), .. }], .. }
        ) => ()
        _ => fail("expected identical-arm if fold")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions global.set same global.get becomes nop" {
  let body = oi_run_func([
    TInstr::global_set(GlobalIdx::new(0), TInstr::global_get(GlobalIdx::new(0))),
  ])
  match body {
    { instrs: [{ kind: TInstrKind::TNop, .. }], .. } => ()
    _ => fail("expected global.set g (global.get g) => nop")
  }
}

///|
test "optimize instructions memory access folds const pointer into offset" {
  let body = oi_run_func(
    [
      TInstr::load(
        LoadOp::i32_load(),
        MemArg::new(U32(4), None, U64(8UL)),
        TInstr::i32_const(I32(10)),
      ),
      TInstr::store(
        StoreOp::i32_store(),
        MemArg::new(U32(4), None, U64(6UL)),
        TInstr::i32_const(I32(4)),
        TInstr::i32_const(I32(1)),
      ),
    ],
    with_memory=true,
  )
  match body {
    { instrs: [l0, s0], .. } => {
      match l0.kind {
        TInstrKind::TLoad(
          _,
          MemArg(_, _, U64(off)),
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => {
          assert_eq(off, 0UL)
          assert_eq(v, 18)
        }
        _ => fail("expected folded load pointer")
      }
      match s0.kind {
        TInstrKind::TStore(
          _,
          MemArg(_, _, U64(off)),
          { kind: TInstrKind::TI32Const(I32(v)), .. },
          _
        ) => {
          assert_eq(off, 0UL)
          assert_eq(v, 10)
        }
        _ => fail("expected folded store pointer")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions store value truncation and wrap upgrade" {
  let body = oi_run_func(
    [
      TInstr::store(
        StoreOp::i32_store8(),
        MemArg::new(U32(1), None, U64(0UL)),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0x1234)),
      ),
      TInstr::store(
        StoreOp::i32_store(),
        MemArg::new(U32(4), None, U64(0UL)),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::unary(
          UnaryOp::i32_wrap_i64(),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i64()],
    with_memory=true,
  )
  match body {
    { instrs: [s0, s1], .. } => {
      match s0.kind {
        TInstrKind::TStore(
          I32Store8Op,
          _,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 0x34)
        _ => fail("expected store8 const truncation")
      }
      match s1.kind {
        TInstrKind::TStore(
          I64Store32Op,
          _,
          _,
          { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
        ) => assert_eq(i.reinterpret_as_int(), 1)
        _ => fail("expected wrap_i64 store upgrade to i64.store32")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions reinterpret store rewrites value type" {
  let body = oi_run_func(
    [
      TInstr::store(
        StoreOp::f32_store(),
        MemArg::new(U32(4), None, U64(0UL)),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::unary(
          UnaryOp::f32_reinterpret_i32(),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TStore(
            I32StoreOp,
            _,
            _,
            { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(i.reinterpret_as_int(), 1)
    _ => fail("expected f32.store(reinterpret_i32) => i32.store")
  }
}

///|
test "optimize instructions memory.copy rewrites constants" {
  let body = oi_run_func(
    [
      TInstr::memory_copy(
        MemIdx::new(0),
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::memory_copy(
        MemIdx::new(0),
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(4)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    { instrs: [c0, c1], .. } => {
      match c0.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TDrop(_), .. },
              { kind: TInstrKind::TDrop(_), .. },
            ],
            ..,
          }
        ) => ()
        _ => fail("expected memory.copy size 0 rewrite")
      }
      match c1.kind {
        TInstrKind::TStore(
          I32StoreOp,
          _,
          _,
          { kind: TInstrKind::TLoad(I32LoadOp, _, _), .. }
        ) => ()
        _ => fail("expected memory.copy size 4 => store(load)")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions memory.fill rewrites constants" {
  let body = oi_run_func(
    [
      TInstr::memory_fill(
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(0)),
      ),
      TInstr::memory_fill(
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::local_get(LocalIdx::new(1)),
        TInstr::i32_const(I32(1)),
      ),
      TInstr::memory_fill(
        MemIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(0xaa)),
        TInstr::i32_const(I32(4)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
    with_memory=true,
  )
  match body {
    { instrs: [f0, f1, f2], .. } => {
      match f0.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TDrop(_), .. },
              { kind: TInstrKind::TDrop(_), .. },
            ],
            ..,
          }
        ) => ()
        _ => fail("expected memory.fill size 0 rewrite")
      }
      match f1.kind {
        TInstrKind::TStore(I32Store8Op, _, _, _) => ()
        _ => fail("expected memory.fill size 1 => store8")
      }
      match f2.kind {
        TInstrKind::TStore(
          I32StoreOp,
          _,
          _,
          { kind: TInstrKind::TI32Const(I32(v)), .. }
        ) => assert_eq(v, 0xaaaaaaaa)
        _ =>
          fail("expected memory.fill const size 4 => i32.store const pattern")
      }
    }
    _ => fail("expected three rewritten instructions")
  }
}

///|
test "optimize instructions select constant condition and equal arms" {
  let body = oi_run_func(
    [
      TInstr::select(
        None,
        TInstr::i32_const(I32(0)),
        TInstr::i32_const(I32(1)),
        TInstr::local_get(LocalIdx::new(0)),
      ),
      TInstr::select(
        Some([ValType::i32()]),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(7)),
        TInstr::i32_const(I32(7)),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    { instrs: [s0, s1], .. } => {
      match s0.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              {
                kind: TInstrKind::TDrop(
                  { kind: TInstrKind::TI32Const(I32(1)), .. }
                ),
                ..,
              },
              { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. },
            ],
            ..,
          }
        ) => assert_eq(i.reinterpret_as_int(), 0)
        _ => fail("expected select cond=0 rewrite")
      }
      match s1.kind {
        TInstrKind::TI32Const(I32(7)) => ()
        _ => fail("expected select equal arms fold")
      }
    }
    _ => fail("expected two rewritten instructions")
  }
}

///|
test "optimize instructions call_ref direct simplifications" {
  let type_sec = TypeSec::new([
    single_rec_type(comp_type_sub_type(func_comp_type([], [ValType::i32()]))),
  ])
  let func_sec = FuncSec::new([TypeIdx::new(0)])
  let code_sec = CodeSec::new([
    Func::t_func(
      [],
      TExpr::new([
        TInstr::call_ref(TypeIdx::new(0), [], TInstr::ref_func(FuncIdx::new(0))),
      ]),
    ),
  ])
  let mod_ = Module::new()
    .with_type_sec(type_sec)
    .with_func_sec(func_sec)
    .with_code_sec(code_sec)
  let out = optimize_module(mod_, [ModulePass::OptimizeInstructions]).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            { instrs: [{ kind: TInstrKind::TCall(FuncIdx(raw), _), .. }], .. }
          ),
        ]
      )
    ) => assert_eq(raw.reinterpret_as_int(), 0)
    _ => fail("expected call_ref(ref.func) => call")
  }
}

///|
test "optimize instructions helper arithmetic and relational utilities cover i64 and negative paths" {
  assert_true(oi_is_power_of_2_i64(8L))
  assert_false(oi_is_power_of_2_i64(0L))
  assert_eq(oi_log2_i64(8L), 3L)
  assert_eq(oi_wrap_i64(-1L), -1L)

  assert_eq(oi_const_i32(TInstr::i32_const(I32(11))), Some(11))
  assert_eq(oi_const_i32(TInstr::i64_const(I64(11L))), None)

  assert_eq(
    oi_reverse_relational(BinaryOp::i32_lt_s()),
    Some(BinaryOp::i32_gt_s()),
  )
  assert_eq(oi_invert_relational(BinaryOp::i32_eq()), Some(BinaryOp::i32_ne()))
  assert_eq(oi_invert_relational(BinaryOp::i32_add()), None)

  assert_true(oi_is_i64_shift(BinaryOp::i64_shl()))
  assert_false(oi_is_i32_shift(BinaryOp::i64_shl()))
  assert_true(oi_negate_const(TInstr::i64_const(I64(5L))) is Some(_))
}

///|
test "optimize instructions helper sequencing boolean and reorder checks" {
  let env = Env::new()
  assert_eq(oi_instr_stmt(TInstr::nop(), env), TInstr::nop())
  assert_eq(oi_seq([], TInstr::nop(), env), TInstr::nop())
  match oi_seq([TInstr::i32_const(I32(1))], TInstr::nop(), env).kind {
    TInstrKind::TBlock(
      VoidBlockType,
      { instrs: [_, { kind: TInstrKind::TNop, .. }], .. }
    ) => ()
    _ => fail("expected oi_seq to emit block for non-empty statements")
  }

  assert_true(
    oi_can_reorder(TInstr::i32_const(I32(1)), TInstr::i32_const(I32(2))),
  )
  assert_false(
    oi_can_reorder(
      TInstr::global_set(GlobalIdx::new(0), TInstr::i32_const(I32(1))),
      TInstr::global_get(GlobalIdx::new(0)),
    ),
  )

  let eqz_eqz = oi_optimize_boolean(
    TInstr::unary(
      UnaryOp::i32_eqz(),
      TInstr::unary(UnaryOp::i32_eqz(), TInstr::local_get(LocalIdx::new(0))),
    ),
    env,
    OptimizeOptions::new(),
  )
  assert_eq(eqz_eqz, TInstr::local_get(LocalIdx::new(0)))

  let eqz_const = oi_optimize_boolean(
    TInstr::unary(UnaryOp::i32_eqz(), TInstr::i32_const(I32(0))),
    env,
    OptimizeOptions::new(),
  )
  assert_eq(eqz_const, TInstr::i32_const(I32(1)))
}

///|
test "optimize instructions i64 constant-right simplifications mirror i32 coverage" {
  let body = oi_run_func(
    [
      TInstr::binary(
        BinaryOp::i64_div_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(8L)),
      ),
      TInstr::binary(
        BinaryOp::i64_rem_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(8L)),
      ),
      TInstr::binary(
        BinaryOp::i64_ge_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(0L)),
      ),
      TInstr::binary(
        BinaryOp::i64_lt_u(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(-1L)),
      ),
      TInstr::binary(
        BinaryOp::i64_mul(),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i64_const(I64(-1L)),
      ),
    ],
    locals=[ValType::i64()],
  )
  match body {
    { instrs: [a0, a1, a2, a3, a4], .. } => {
      match a0.kind {
        TInstrKind::TBinary(
          I64ShrUOp,
          _,
          { kind: TInstrKind::TI64Const(I64(v)), .. }
        ) => assert_eq(v, 3L)
        _ => fail("expected i64.div_u by pow2 => shr_u")
      }
      match a1.kind {
        TInstrKind::TBinary(
          I64AndOp,
          _,
          { kind: TInstrKind::TI64Const(I64(v)), .. }
        ) => assert_eq(v, 7L)
        _ => fail("expected i64.rem_u by pow2 => and")
      }
      match a2.kind {
        TInstrKind::TBlock(
          _,
          {
            instrs: [
              { kind: TInstrKind::TDrop(_), .. },
              { kind: TInstrKind::TI32Const(I32(v)), .. },
            ],
            ..,
          }
        ) => assert_eq(v, 1)
        _ => fail("expected i64.ge_u 0 => true with dropped lhs")
      }
      match a3.kind {
        TInstrKind::TBinary(
          I64NeOp,
          _,
          { kind: TInstrKind::TI64Const(I64(v)), .. }
        ) => assert_eq(v, -1L)
        _ => fail("expected i64.lt_u -1 => ne -1")
      }
      match a4.kind {
        TInstrKind::TBinary(
          I64SubOp,
          { kind: TInstrKind::TI64Const(I64(0L)), .. },
          _
        ) => ()
        _ => fail("expected i64.mul -1 => 0 - x")
      }
    }
    _ => fail("expected five rewritten i64 instructions")
  }
}

///|
test "optimize instructions candidate pre-scan reaches deeper nested candidates" {
  let body = oi_run_func(
    [
      TInstr::drop(
        TInstr::drop(
          TInstr::binary(
            BinaryOp::i32_add(),
            TInstr::local_get(LocalIdx::new(0)),
            TInstr::i32_const(I32(0)),
          ),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  match body {
    {
      instrs: [
        {
          kind: TInstrKind::TDrop(
            {
              kind: TInstrKind::TDrop(
                { kind: TInstrKind::TLocalGet(LocalIdx(i)), .. }
              ),
              ..,
            }
          ),
          ..,
        },
      ],
      ..,
    } => assert_eq(i.reinterpret_as_int(), 0)
    _ =>
      fail("expected nested i32.add with const zero to simplify to local.get")
  }
}

///|
test "optimize instructions keeps local effects conservative above tracking cap" {
  let cache = oi_rewrite_cache_new(local_count=1100)
  let high_tee = TInstr::local_tee(
    LocalIdx::new(1050),
    TInstr::i32_const(I32(1)),
  )
  let high_get = TInstr::local_get(LocalIdx::new(1050))
  let low_set = TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(0)))

  let write_summary = oi_effects_summary_cached(high_tee, cache)
  assert_true(write_summary.unknown_locals_written)
  assert_true(write_summary.has_side_effects)

  let read_summary = oi_effects_summary_cached(high_get, cache)
  assert_true(read_summary.unknown_locals_read)

  assert_false(oi_can_reorder_cached(high_tee, high_get, cache))
  assert_false(oi_can_reorder_cached(high_get, low_set, cache))
}
