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
priv enum PCLiteral {
  PCI32(Int)
  PCI64(Int64)
  PCF32(Float)
  PCF64(Double)
  PCRefNull(HeapType)
  PCRefFunc(FuncIdx)
} derive(Eq)

///|
priv struct PCSetKey {
  local_idx : LocalIdx
  set_id : Int
} derive(Eq, Hash)

///|
priv struct PCSetSite {
  key : PCSetKey
  value : TInstr
  start_get_id : Int
}

///|
priv struct PCSetLookupKey {
  local_idx : LocalIdx
  root_hash : UInt64
} derive(Eq, Hash)

///|
priv enum PCSlowPhase {
  Walk
  Fold
} derive(Eq, Hash)

///|
priv struct PCSlowKey {
  phase : PCSlowPhase
  tag : String
  hash : UInt64
} derive(Eq, Hash)

///|
priv struct PCSlowStat {
  count : Int
  total_ms : UInt64
  max_ms : UInt64
}

///|
fn pc_wrap_i32(x : Int) -> Int {
  (x.reinterpret_as_uint() & 0xffffffffU).reinterpret_as_int()
}

///|
fn pc_wrap_i64(x : Int64) -> Int64 {
  x.reinterpret_as_uint64().reinterpret_as_int64()
}

///|
fn pc_trace_normalize_env_now_ms(raw : UInt64) -> UInt64 {
  if raw >= 100000000000000000UL {
    raw / 1000000UL
  } else if raw >= 100000000000000UL {
    raw / 1000UL
  } else {
    raw
  }
}

///|
#cfg(target="native")
#borrow(tv)
extern "c" fn pc_trace_native_gettimeofday(tv : Bytes, tz : UInt64) -> Int = "gettimeofday"

///|
#cfg(target="native")
fn pc_trace_read_u64_le(bytes : Bytes, start : Int) -> UInt64 {
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
fn pc_trace_now_ms() -> UInt64 {
  let tv = Bytes::new(16)
  if pc_trace_native_gettimeofday(tv, 0UL) != 0 {
    return pc_trace_normalize_env_now_ms(@env.now())
  }
  let sec = pc_trace_read_u64_le(tv, 0)
  let usec = pc_trace_read_u64_le(tv, 8)
  sec * 1000UL + usec / 1000UL
}

///|
#cfg(target="wasm-gc")
fn pc_trace_now_ms() -> UInt64 {
  pc_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="wasm")
fn pc_trace_now_ms() -> UInt64 {
  pc_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="js")
fn pc_trace_now_ms() -> UInt64 {
  pc_trace_normalize_env_now_ms(@env.now())
}

///|
#cfg(target="llvm")
fn pc_trace_now_ms() -> UInt64 {
  pc_trace_normalize_env_now_ms(@env.now())
}

///|
fn pc_trace_elapsed_ms(start_ms : UInt64) -> UInt64 {
  let end_ms = pc_trace_now_ms()
  if end_ms >= start_ms {
    end_ms - start_ms
  } else {
    0UL
  }
}

///|
fn pc_trace_instr_tag(instr : TInstr) -> String {
  match instr.kind {
    TInstrKind::TI32Const(_) => "i32.const"
    TInstrKind::TI64Const(_) => "i64.const"
    TInstrKind::TF32Const(_) => "f32.const"
    TInstrKind::TF64Const(_) => "f64.const"
    TInstrKind::TUnreachable => "unreachable"
    TInstrKind::TNop => "nop"
    TInstrKind::TLocalGet(_) => "local.get"
    TInstrKind::TGlobalGet(_) => "global.get"
    TInstrKind::TUnary(_, _) => "unary"
    TInstrKind::TBinary(_, _, _) => "binary"
    TInstrKind::TDrop(_) => "drop"
    TInstrKind::TLocalSet(_, _) => "local.set"
    TInstrKind::TLocalTee(_, _) => "local.tee"
    TInstrKind::TGlobalSet(_, _) => "global.set"
    TInstrKind::TLoad(_, _, _) => "load"
    TInstrKind::TStore(_, _, _, _) => "store"
    TInstrKind::TCall(_, _) => "call"
    TInstrKind::TCallIndirect(_, _, _, _) => "call_indirect"
    TInstrKind::TReturnCall(_, _) => "return_call"
    TInstrKind::TBlock(_, _) => "block"
    TInstrKind::TLoop(_, _) => "loop"
    TInstrKind::TIf(_, _, _, _) => "if"
    TInstrKind::TBr(_, _) => "br"
    TInstrKind::TBrIf(_, _, _) => "br_if"
    TInstrKind::TBrTable(_, _, _, _) => "br_table"
    TInstrKind::TReturn(_) => "return"
    TInstrKind::TSelect(_, _, _, _) => "select"
    _ => "other"
  }
}

///|
fn pc_instr_hash_u64(instr : TInstr) -> UInt64 {
  instr.hash().reinterpret_as_uint().to_uint64()
}

///|
fn pc_slow_phase_label(phase : PCSlowPhase) -> String {
  match phase {
    Walk => "walk_slow"
    Fold => "fold_slow"
  }
}

///|
fn pc_record_slow_trace(
  stats : Map[PCSlowKey, PCSlowStat],
  order : Array[PCSlowKey],
  phase : PCSlowPhase,
  instr : TInstr,
  elapsed_ms : UInt64,
) -> Unit {
  let key = {
    phase,
    tag: pc_trace_instr_tag(instr),
    hash: pc_instr_hash_u64(instr),
  }
  match stats.get(key) {
    Some(existing) =>
      stats[key] = {
        count: existing.count + 1,
        total_ms: existing.total_ms + elapsed_ms,
        max_ms: if existing.max_ms >= elapsed_ms {
          existing.max_ms
        } else {
          elapsed_ms
        },
      }
    None => {
      order.push(key)
      stats[key] = { count: 1, total_ms: elapsed_ms, max_ms: elapsed_ms }
    }
  }
}

///|
fn pc_slow_summary_lines(
  stats : Map[PCSlowKey, PCSlowStat],
  order : Array[PCSlowKey],
  limit? : Int = 6,
) -> Array[String] {
  let out : Array[String] = []
  let picked : Map[PCSlowKey, Unit] = Map::new()
  let mut emitted = 0
  while emitted < limit {
    let mut best : PCSlowKey? = None
    let mut best_total_ms = 0UL
    let mut best_count = 0
    for key in order {
      if picked.contains(key) {
        continue
      }
      let stat = match stats.get(key) {
        Some(stat) => stat
        None => continue
      }
      if stat.count <= 1 {
        continue
      }
      if best is None ||
        stat.total_ms > best_total_ms ||
        (stat.total_ms == best_total_ms && stat.count > best_count) {
        best = Some(key)
        best_total_ms = stat.total_ms
        best_count = stat.count
      }
    }
    match best {
      Some(key) =>
        match stats.get(key) {
          Some(stat) => {
            picked[key] = ()
            out.push(
              "\{pc_slow_phase_label(key.phase)} count=\{stat.count} total_ms=\{stat.total_ms} max_ms=\{stat.max_ms} tag=\{key.tag} hash=\{key.hash}",
            )
            emitted += 1
          }
          None => break
        }
      None => break
    }
  }
  if stats.length() > out.length() {
    out.push("slow_summary_omitted entries=\{stats.length() - out.length()}")
  }
  out
}

///|
fn pc_push_texpr_instrs_reversed(stack : Array[TInstr], expr : TExpr) -> Unit {
  for i = expr.instrs.length() - 1; i >= 0; i = i - 1 {
    stack.push(expr.instrs[i])
  }
}

///|
fn pc_push_full_children_reversed(
  stack : Array[TInstr],
  instr : TInstr,
) -> Unit {
  match instr.kind {
    TInstrKind::TBlock(_, expr) | TInstrKind::TLoop(_, expr) =>
      pc_push_texpr_instrs_reversed(stack, expr)
    TInstrKind::TIf(_, cond, then_expr, else_expr) => {
      if else_expr is Some(else_body) {
        pc_push_texpr_instrs_reversed(stack, else_body)
      }
      pc_push_texpr_instrs_reversed(stack, then_expr)
      stack.push(cond)
    }
    TInstrKind::TTryTable(_, _, expr) =>
      pc_push_texpr_instrs_reversed(stack, expr)
    _ => {
      let children = eval_children(instr)
      for i = children.length() - 1; i >= 0; i = i - 1 {
        stack.push(children[i])
      }
    }
  }
}

///|
fn pc_round_half_to_even_f32(x : Float) -> Float {
  let d = x.to_double()
  let r = pc_round_half_to_even_f64(d)
  Float::from_double(r)
}

///|
fn pc_round_half_to_even_f64(x : Double) -> Double {
  if compat_is_f64_non_finite(x) {
    return x
  }
  let t = x.trunc()
  let frac = (x - t).abs()
  if frac < 0.5 {
    t
  } else if frac > 0.5 {
    t + (if x >= 0.0 { 1.0 } else { -1.0 })
  } else {
    let ti = t.to_int64()
    if (ti & 1L) == 0L {
      t
    } else {
      t + (if x >= 0.0 { 1.0 } else { -1.0 })
    }
  }
}

///|
fn pc_trunc_f64_to_i64_s(x : Double) -> Int64? {
  compat_trunc_f64_to_i64_s(x)
}

///|
fn pc_trunc_f64_to_i64_u(x : Double) -> Int64? {
  compat_trunc_f64_to_i64_u(x)
}

///|
fn pc_literal_from_instr(instr : TInstr) -> PCLiteral? {
  match instr.kind {
    TInstrKind::TI32Const(I32(v)) => Some(PCI32(v))
    TInstrKind::TI64Const(I64(v)) => Some(PCI64(v))
    TInstrKind::TF32Const(F32(v)) => Some(PCF32(v))
    TInstrKind::TF64Const(F64(v)) => Some(PCF64(v))
    TInstrKind::TRefNull(ht) => Some(PCRefNull(ht))
    TInstrKind::TRefFunc(fi) => Some(PCRefFunc(fi))
    _ => None
  }
}

///|
fn pc_instr_from_literal(value : PCLiteral) -> TInstr {
  match value {
    PCI32(v) => TInstr::i32_const(I32(v))
    PCI64(v) => TInstr::i64_const(I64(v))
    PCF32(v) => TInstr::f32_const(F32(v))
    PCF64(v) => TInstr::f64_const(F64(v))
    PCRefNull(ht) => TInstr::ref_null(ht)
    PCRefFunc(fi) => TInstr::ref_func(fi)
  }
}

///|
fn pc_imported_global_count(mod : Module) -> UInt {
  let mut count : UInt = 0U
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(_)) => count += 1U
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn pc_collect_immutable_globals(mod : Module) -> Map[GlobalIdx, PCLiteral] {
  let out : Map[GlobalIdx, PCLiteral] = Map::new()
  let imported = pc_imported_global_count(mod)
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for i = 0; i < globals.length(); i = i + 1 {
        match globals[i] {
          Global(GlobalType(_, is_mut), Expr(init_instrs)) =>
            if !is_mut {
              match init_instrs {
                [I32Const(I32(v))] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCI32(
                    v,
                  )
                [I64Const(I64(v))] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCI64(
                    v,
                  )
                [F32Const(F32(v))] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCF32(
                    v,
                  )
                [F64Const(F64(v))] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCF64(
                    v,
                  )
                [RefNull(ht)] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCRefNull(
                    ht,
                  )
                [RefFunc(fi)] =>
                  out[GlobalIdx::new(imported + i.reinterpret_as_uint())] = PCRefFunc(
                    fi,
                  )
                _ => ()
              }
            }
        }
      }
    None => ()
  }
  out
}

///|
fn pc_eval_unary(op : UnaryOp, value : PCLiteral) -> PCLiteral? {
  match (op, value) {
    (I32EqzOp, PCI32(x)) => Some(PCI32(if x == 0 { 1 } else { 0 }))
    (I32ClzOp, PCI32(x)) => Some(PCI32(x.clz()))
    (I32CtzOp, PCI32(x)) => Some(PCI32(x.ctz()))
    (I32PopcntOp, PCI32(x)) => Some(PCI32(x.popcnt()))
    (I32WrapI64Op, PCI64(x)) => Some(PCI32(x.to_int()))
    (I32Extend8SOp, PCI32(x)) => Some(PCI32(x << 24 >> 24))
    (I32Extend16SOp, PCI32(x)) => Some(PCI32(x << 16 >> 16))
    (I64EqzOp, PCI64(x)) => Some(PCI32(if x == 0L { 1 } else { 0 }))
    (I64ClzOp, PCI64(x)) => Some(PCI64(x.clz().to_int64()))
    (I64CtzOp, PCI64(x)) => Some(PCI64(x.ctz().to_int64()))
    (I64PopcntOp, PCI64(x)) => Some(PCI64(x.popcnt().to_int64()))
    (I64ExtendI32SOp, PCI32(x)) => Some(PCI64(x.to_int64()))
    (I64ExtendI32UOp, PCI32(x)) =>
      Some(PCI64(x.reinterpret_as_uint().to_uint64().reinterpret_as_int64()))
    (I64TruncF32SOp, PCF32(x)) =>
      match pc_trunc_f64_to_i64_s(x.to_double()) {
        Some(v) => Some(PCI64(v))
        None => None
      }
    (I64TruncF32UOp, PCF32(x)) =>
      match pc_trunc_f64_to_i64_u(x.to_double()) {
        Some(v) => Some(PCI64(v))
        None => None
      }
    (I64TruncF64SOp, PCF64(x)) =>
      match pc_trunc_f64_to_i64_s(x) {
        Some(v) => Some(PCI64(v))
        None => None
      }
    (I64TruncF64UOp, PCF64(x)) =>
      match pc_trunc_f64_to_i64_u(x) {
        Some(v) => Some(PCI64(v))
        None => None
      }
    (I64Extend8SOp, PCI64(x)) => Some(PCI64(x << 56 >> 56))
    (I64Extend16SOp, PCI64(x)) => Some(PCI64(x << 48 >> 48))
    (I64Extend32SOp, PCI64(x)) => Some(PCI64(x << 32 >> 32))
    (F32AbsOp, PCF32(x)) => Some(PCF32(x.abs()))
    (F32NegOp, PCF32(x)) => Some(PCF32(-x))
    (F32CeilOp, PCF32(x)) =>
      Some(PCF32(Float::from_double(x.to_double().ceil())))
    (F32FloorOp, PCF32(x)) =>
      Some(PCF32(Float::from_double(x.to_double().floor())))
    (F32TruncOp, PCF32(x)) =>
      Some(PCF32(Float::from_double(x.to_double().trunc())))
    (F32NearestOp, PCF32(x)) => Some(PCF32(pc_round_half_to_even_f32(x)))
    (F32SqrtOp, PCF32(x)) => Some(PCF32(x.sqrt()))
    (F64AbsOp, PCF64(x)) => Some(PCF64(x.abs()))
    (F64NegOp, PCF64(x)) => Some(PCF64(-x))
    (F64CeilOp, PCF64(x)) => Some(PCF64(x.ceil()))
    (F64FloorOp, PCF64(x)) => Some(PCF64(x.floor()))
    (F64TruncOp, PCF64(x)) => Some(PCF64(x.trunc()))
    (F64NearestOp, PCF64(x)) => Some(PCF64(pc_round_half_to_even_f64(x)))
    (F64SqrtOp, PCF64(x)) => Some(PCF64(x.sqrt()))
    (F32ReinterpretI32Op, PCI32(x)) =>
      Some(PCF32(Float::reinterpret_from_int(x)))
    (I32ReinterpretF32Op, PCF32(x)) => Some(PCI32(x.reinterpret_as_int()))
    (F64ReinterpretI64Op, PCI64(x)) => Some(PCF64(x.reinterpret_as_double()))
    (I64ReinterpretF64Op, PCF64(x)) => Some(PCI64(x.reinterpret_as_int64()))
    (F32ConvertI32SOp, PCI32(x)) =>
      Some(PCF32(Float::from_double(x.to_double())))
    (F32ConvertI32UOp, PCI32(x)) =>
      Some(PCF32(Float::from_double(x.reinterpret_as_uint().to_double())))
    (F32ConvertI64SOp, PCI64(x)) =>
      Some(PCF32(Float::from_double(x.to_double())))
    (F32ConvertI64UOp, PCI64(x)) =>
      Some(PCF32(Float::from_double(x.reinterpret_as_uint64().to_double())))
    (F32DemoteF64Op, PCF64(x)) => Some(PCF32(Float::from_double(x)))
    (F64ConvertI32SOp, PCI32(x)) => Some(PCF64(x.to_double()))
    (F64ConvertI32UOp, PCI32(x)) =>
      Some(PCF64(x.reinterpret_as_uint().to_double()))
    (F64ConvertI64SOp, PCI64(x)) => Some(PCF64(x.to_double()))
    (F64ConvertI64UOp, PCI64(x)) =>
      Some(PCF64(x.reinterpret_as_uint64().to_double()))
    (F64PromoteF32Op, PCF32(x)) => Some(PCF64(x.to_double()))
    _ => None
  }
}

///|
fn pc_eval_binary(
  op : BinaryOp,
  left : PCLiteral,
  right : PCLiteral,
) -> PCLiteral? {
  match (op, left, right) {
    (I32AddOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x + y)))
    (I32SubOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x - y)))
    (I32MulOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x * y)))
    (I32DivSOp, PCI32(x), PCI32(y)) =>
      if y == 0 || (x == -2147483648 && y == -1) {
        None
      } else {
        Some(PCI32(pc_wrap_i32(x / y)))
      }
    (I32DivUOp, PCI32(x), PCI32(y)) =>
      if y == 0 {
        None
      } else {
        let xu = x.reinterpret_as_uint()
        let yu = y.reinterpret_as_uint()
        Some(PCI32((xu / yu).reinterpret_as_int()))
      }
    (I32RemSOp, PCI32(x), PCI32(y)) =>
      if y == 0 {
        None
      } else {
        Some(PCI32(pc_wrap_i32(x % y)))
      }
    (I32RemUOp, PCI32(x), PCI32(y)) =>
      if y == 0 {
        None
      } else {
        let xu = x.reinterpret_as_uint()
        let yu = y.reinterpret_as_uint()
        Some(PCI32((xu % yu).reinterpret_as_int()))
      }
    (I32AndOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x & y)))
    (I32OrOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x | y)))
    (I32XorOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x ^ y)))
    (I32ShlOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x << (y & 31))))
    (I32ShrSOp, PCI32(x), PCI32(y)) => Some(PCI32(pc_wrap_i32(x >> (y & 31))))
    (I32ShrUOp, PCI32(x), PCI32(y)) =>
      Some(PCI32((x.reinterpret_as_uint() >> (y & 31)).reinterpret_as_int()))
    (I32RotlOp, PCI32(x), PCI32(y)) => {
      let k = y & 31
      if k == 0 {
        Some(PCI32(x))
      } else {
        let xu = x.reinterpret_as_uint()
        Some(PCI32(((xu << k) | (xu >> (32 - k))).reinterpret_as_int()))
      }
    }
    (I32RotrOp, PCI32(x), PCI32(y)) => {
      let k = y & 31
      if k == 0 {
        Some(PCI32(x))
      } else {
        let xu = x.reinterpret_as_uint()
        Some(PCI32(((xu >> k) | (xu << (32 - k))).reinterpret_as_int()))
      }
    }
    (I32EqOp, PCI32(x), PCI32(y)) => Some(PCI32(if x == y { 1 } else { 0 }))
    (I32NeOp, PCI32(x), PCI32(y)) => Some(PCI32(if x != y { 1 } else { 0 }))
    (I32LtSOp, PCI32(x), PCI32(y)) => Some(PCI32(if x < y { 1 } else { 0 }))
    (I32LtUOp, PCI32(x), PCI32(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint() < y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I32GtSOp, PCI32(x), PCI32(y)) => Some(PCI32(if x > y { 1 } else { 0 }))
    (I32GtUOp, PCI32(x), PCI32(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint() > y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I32LeSOp, PCI32(x), PCI32(y)) => Some(PCI32(if x <= y { 1 } else { 0 }))
    (I32LeUOp, PCI32(x), PCI32(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint() <= y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I32GeSOp, PCI32(x), PCI32(y)) => Some(PCI32(if x >= y { 1 } else { 0 }))
    (I32GeUOp, PCI32(x), PCI32(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint() >= y.reinterpret_as_uint() {
            1
          } else {
            0
          },
        ),
      )
    (I64AddOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x + y)))
    (I64SubOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x - y)))
    (I64MulOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x * y)))
    (I64DivSOp, PCI64(x), PCI64(y)) =>
      if y == 0L || (x == -9223372036854775808L && y == -1L) {
        None
      } else {
        Some(PCI64(pc_wrap_i64(x / y)))
      }
    (I64DivUOp, PCI64(x), PCI64(y)) =>
      if y == 0L {
        None
      } else {
        let xu = x.reinterpret_as_uint64()
        let yu = y.reinterpret_as_uint64()
        Some(PCI64((xu / yu).reinterpret_as_int64()))
      }
    (I64RemSOp, PCI64(x), PCI64(y)) =>
      if y == 0L {
        None
      } else {
        Some(PCI64(pc_wrap_i64(x % y)))
      }
    (I64RemUOp, PCI64(x), PCI64(y)) =>
      if y == 0L {
        None
      } else {
        let xu = x.reinterpret_as_uint64()
        let yu = y.reinterpret_as_uint64()
        Some(PCI64((xu % yu).reinterpret_as_int64()))
      }
    (I64AndOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x & y)))
    (I64OrOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x | y)))
    (I64XorOp, PCI64(x), PCI64(y)) => Some(PCI64(pc_wrap_i64(x ^ y)))
    (I64ShlOp, PCI64(x), PCI64(y)) =>
      Some(PCI64(pc_wrap_i64(x << (y & 63L).to_int())))
    (I64ShrSOp, PCI64(x), PCI64(y)) =>
      Some(PCI64(pc_wrap_i64(x >> (y & 63L).to_int())))
    (I64ShrUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI64(
          (x.reinterpret_as_uint64() >> (y & 63L).to_int()).reinterpret_as_int64(),
        ),
      )
    (I64RotlOp, PCI64(x), PCI64(y)) => {
      let k = (y & 63L).to_int()
      if k == 0 {
        Some(PCI64(x))
      } else {
        let xu = x.reinterpret_as_uint64()
        Some(PCI64(((xu << k) | (xu >> (64 - k))).reinterpret_as_int64()))
      }
    }
    (I64RotrOp, PCI64(x), PCI64(y)) => {
      let k = (y & 63L).to_int()
      if k == 0 {
        Some(PCI64(x))
      } else {
        let xu = x.reinterpret_as_uint64()
        Some(PCI64(((xu >> k) | (xu << (64 - k))).reinterpret_as_int64()))
      }
    }
    (I64EqOp, PCI64(x), PCI64(y)) => Some(PCI32(if x == y { 1 } else { 0 }))
    (I64NeOp, PCI64(x), PCI64(y)) => Some(PCI32(if x != y { 1 } else { 0 }))
    (I64LtSOp, PCI64(x), PCI64(y)) => Some(PCI32(if x < y { 1 } else { 0 }))
    (I64LtUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint64() < y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (I64GtSOp, PCI64(x), PCI64(y)) => Some(PCI32(if x > y { 1 } else { 0 }))
    (I64GtUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint64() > y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (I64LeSOp, PCI64(x), PCI64(y)) => Some(PCI32(if x <= y { 1 } else { 0 }))
    (I64LeUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint64() <= y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (I64GeSOp, PCI64(x), PCI64(y)) => Some(PCI32(if x >= y { 1 } else { 0 }))
    (I64GeUOp, PCI64(x), PCI64(y)) =>
      Some(
        PCI32(
          if x.reinterpret_as_uint64() >= y.reinterpret_as_uint64() {
            1
          } else {
            0
          },
        ),
      )
    (F32AddOp, PCF32(x), PCF32(y)) => Some(PCF32(x + y))
    (F32SubOp, PCF32(x), PCF32(y)) => Some(PCF32(x - y))
    (F32MulOp, PCF32(x), PCF32(y)) => Some(PCF32(x * y))
    (F32DivOp, PCF32(x), PCF32(y)) => Some(PCF32(x / y))
    (F32MinOp, PCF32(x), PCF32(y)) =>
      Some(
        PCF32(
          if compat_is_f32_nan(x) || compat_is_f32_nan(y) {
            @float.not_a_number
          } else if x < y {
            x
          } else {
            y
          },
        ),
      )
    (F32MaxOp, PCF32(x), PCF32(y)) =>
      Some(
        PCF32(
          if compat_is_f32_nan(x) || compat_is_f32_nan(y) {
            @float.not_a_number
          } else if x > y {
            x
          } else {
            y
          },
        ),
      )
    (F32CopysignOp, PCF32(x), PCF32(y)) => {
      let x_abs = x.abs()
      Some(PCF32(if y.reinterpret_as_int() < 0 { -x_abs } else { x_abs }))
    }
    (F32EqOp, PCF32(x), PCF32(y)) => Some(PCI32(if x == y { 1 } else { 0 }))
    (F32NeOp, PCF32(x), PCF32(y)) => Some(PCI32(if x != y { 1 } else { 0 }))
    (F32LtOp, PCF32(x), PCF32(y)) => Some(PCI32(if x < y { 1 } else { 0 }))
    (F32GtOp, PCF32(x), PCF32(y)) => Some(PCI32(if x > y { 1 } else { 0 }))
    (F32LeOp, PCF32(x), PCF32(y)) => Some(PCI32(if x <= y { 1 } else { 0 }))
    (F32GeOp, PCF32(x), PCF32(y)) => Some(PCI32(if x >= y { 1 } else { 0 }))
    (F64AddOp, PCF64(x), PCF64(y)) => Some(PCF64(x + y))
    (F64SubOp, PCF64(x), PCF64(y)) => Some(PCF64(x - y))
    (F64MulOp, PCF64(x), PCF64(y)) => Some(PCF64(x * y))
    (F64DivOp, PCF64(x), PCF64(y)) => Some(PCF64(x / y))
    (F64MinOp, PCF64(x), PCF64(y)) =>
      Some(
        PCF64(
          if compat_is_f64_nan(x) || compat_is_f64_nan(y) {
            @double.not_a_number
          } else if x < y {
            x
          } else {
            y
          },
        ),
      )
    (F64MaxOp, PCF64(x), PCF64(y)) =>
      Some(
        PCF64(
          if compat_is_f64_nan(x) || compat_is_f64_nan(y) {
            @double.not_a_number
          } else if x > y {
            x
          } else {
            y
          },
        ),
      )
    (F64CopysignOp, PCF64(x), PCF64(y)) => {
      let x_abs = x.abs()
      Some(PCF64(if y.reinterpret_as_int64() < 0L { -x_abs } else { x_abs }))
    }
    (F64EqOp, PCF64(x), PCF64(y)) => Some(PCI32(if x == y { 1 } else { 0 }))
    (F64NeOp, PCF64(x), PCF64(y)) => Some(PCI32(if x != y { 1 } else { 0 }))
    (F64LtOp, PCF64(x), PCF64(y)) => Some(PCI32(if x < y { 1 } else { 0 }))
    (F64GtOp, PCF64(x), PCF64(y)) => Some(PCI32(if x > y { 1 } else { 0 }))
    (F64LeOp, PCF64(x), PCF64(y)) => Some(PCI32(if x <= y { 1 } else { 0 }))
    (F64GeOp, PCF64(x), PCF64(y)) => Some(PCI32(if x >= y { 1 } else { 0 }))
    _ => None
  }
}

///|
fn pc_lookup_cached_literal(
  instr : TInstr,
  values : Map[UInt64, PCLiteral],
  cache : Map[UInt64, PCLiteral],
) -> PCLiteral? {
  let h = pc_instr_hash_u64(instr)
  match values.get(h) {
    Some(v) => Some(v)
    None => cache.get(h)
  }
}

///|
fn pc_eval_texpr_const_cached(
  expr : TExpr,
  values : Map[UInt64, PCLiteral],
  cache : Map[UInt64, PCLiteral],
) -> PCLiteral? {
  if expr.instrs.is_empty() {
    return None
  }
  let mut last : PCLiteral? = None
  for instr in expr.instrs {
    match pc_lookup_cached_literal(instr, values, cache) {
      Some(v) => last = Some(v)
      None => return None
    }
  }
  last
}

///|
fn pc_eval_const_expr_cached(
  instr : TInstr,
  imm_globals : Map[GlobalIdx, PCLiteral],
  cache : Map[UInt64, PCLiteral],
) -> PCLiteral? {
  let stack : Array[(TInstr, Bool)] = [(instr, false)]
  let post_order : Array[TInstr] = []
  while !stack.is_empty() {
    let (curr, expanded) = stack.pop().unwrap()
    if expanded {
      post_order.push(curr)
      continue
    }
    stack.push((curr, true))
    let children = eval_children(curr)
    let mut i = children.length() - 1
    while i >= 0 {
      stack.push((children[i], false))
      i = i - 1
    }
  }

  let values : Map[UInt64, PCLiteral] = Map::new()
  for curr in post_order {
    let h = pc_instr_hash_u64(curr)
    match cache.get(h) {
      Some(v) => values[h] = v
      None =>
        match pc_literal_from_instr(curr) {
          Some(v) => {
            values[h] = v
            cache[h] = v
          }
          None => {
            let next = match curr.kind {
              TInstrKind::TGlobalGet(idx) => imm_globals.get(idx)
              TInstrKind::TUnary(op, child) =>
                match pc_lookup_cached_literal(child, values, cache) {
                  Some(v) => pc_eval_unary(op, v)
                  None => None
                }
              TInstrKind::TBinary(op, left, right) =>
                match
                  (
                    pc_lookup_cached_literal(left, values, cache),
                    pc_lookup_cached_literal(right, values, cache),
                  ) {
                  (Some(a), Some(b)) => pc_eval_binary(op, a, b)
                  _ => None
                }
              TInstrKind::TRefEq(left, right) =>
                match
                  (
                    pc_lookup_cached_literal(left, values, cache),
                    pc_lookup_cached_literal(right, values, cache),
                  ) {
                  (Some(PCRefNull(_)), Some(PCRefNull(_))) => Some(PCI32(1))
                  (Some(PCRefFunc(a)), Some(PCRefFunc(b))) =>
                    Some(PCI32(if a == b { 1 } else { 0 }))
                  (Some(PCRefNull(_)), Some(PCRefFunc(_)))
                  | (Some(PCRefFunc(_)), Some(PCRefNull(_))) => Some(PCI32(0))
                  _ => None
                }
              TInstrKind::TRefIsNull(value) =>
                match pc_lookup_cached_literal(value, values, cache) {
                  Some(PCRefNull(_)) => Some(PCI32(1))
                  Some(PCRefFunc(_)) => Some(PCI32(0))
                  _ => None
                }
              TInstrKind::TSelect(_, cond, if_true, if_false) =>
                match
                  (
                    pc_lookup_cached_literal(cond, values, cache),
                    pc_lookup_cached_literal(if_true, values, cache),
                    pc_lookup_cached_literal(if_false, values, cache),
                  ) {
                  (Some(PCI32(c)), Some(t), Some(f)) =>
                    if c == 0 {
                      Some(f)
                    } else {
                      Some(t)
                    }
                  _ => None
                }
              TInstrKind::TBlock(_, body) =>
                pc_eval_texpr_const_cached(body, values, cache)
              TInstrKind::TIf(_, cond, then_body, else_body) =>
                match pc_lookup_cached_literal(cond, values, cache) {
                  Some(PCI32(v)) =>
                    if v == 0 {
                      match else_body {
                        Some(other) =>
                          pc_eval_texpr_const_cached(other, values, cache)
                        None => None
                      }
                    } else {
                      pc_eval_texpr_const_cached(then_body, values, cache)
                    }
                  _ => None
                }
              _ => None
            }
            match next {
              Some(v) => {
                values[h] = v
                cache[h] = v
              }
              None => ()
            }
          }
        }
    }
  }
  pc_lookup_cached_literal(instr, values, cache)
}

///|
fn pc_literal_maps_equal(
  a : Map[Int, PCLiteral],
  b : Map[Int, PCLiteral],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for k, v in a {
    match b.get(k) {
      Some(other) if other == v => ()
      _ => return false
    }
  }
  true
}

///|
fn pc_set_literal_maps_equal(
  a : Map[PCSetKey, PCLiteral],
  b : Map[PCSetKey, PCLiteral],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for k, v in a {
    match b.get(k) {
      Some(other) if other == v => ()
      _ => return false
    }
  }
  true
}

///|
fn pc_count_local_gets_iterative(instr : TInstr) -> Int {
  let mut count = 0
  let stack : Array[TInstr] = [instr]
  while !stack.is_empty() {
    let curr = stack.pop().unwrap()
    match curr.kind {
      TInstrKind::TLocalGet(_) => count += 1
      _ => ()
    }
    pc_push_full_children_reversed(stack, curr)
  }
  count
}

///|
fn pc_get_constant_for_get_id(
  graph : LocalGraph,
  get_id : Int,
  set_values : Map[PCSetKey, PCLiteral],
  set_lookup : Map[PCSetLookupKey, Int],
  branchy_locals : Set[LocalIdx],
) -> PCLiteral? {
  let sets = graph.get_sets(get_id)
  if sets.is_empty() {
    return None
  }
  let mut value : PCLiteral? = None
  for set_ in sets {
    let current = match set_ {
      LocalSet::InitValue => return None
      LocalSet::Set(local_idx, root) =>
        if branchy_locals.contains(local_idx) {
          return None
        } else {
          let root_hash = pc_instr_hash_u64(root)
          let key = { local_idx, root_hash }
          match set_lookup.get(key) {
            Some(set_id) =>
              match set_values.get({ local_idx, set_id }) {
                Some(v) => v
                None => return None
              }
            None => return None
          }
        }
    }
    match value {
      Some(existing) if existing != current => return None
      None => value = Some(current)
      _ => ()
    }
  }
  value
}

///|
fn pc_eval_expr_for_prop(
  instr : TInstr,
  graph : LocalGraph,
  set_values : Map[PCSetKey, PCLiteral],
  set_lookup : Map[PCSetLookupKey, Int],
  imm_globals : Map[GlobalIdx, PCLiteral],
  branchy_locals : Set[LocalIdx],
  get_id_ref : Ref[Int],
  eval_cache : Map[UInt64, PCLiteral],
) -> PCLiteral? {
  let work : Array[(TInstr, Int)] = [(instr, 0)]
  let values : Array[PCLiteral?] = []
  while !work.is_empty() {
    let (curr, stage) = work.pop().unwrap()
    if stage == 0 {
      match pc_eval_const_expr_cached(curr, imm_globals, eval_cache) {
        Some(v) => {
          values.push(Some(v))
          continue
        }
        None => ()
      }
      match curr.kind {
        TInstrKind::TLocalGet(_) => {
          let id = get_id_ref.val
          get_id_ref.update(fn(n) { n + 1 })
          values.push(
            pc_get_constant_for_get_id(
              graph, id, set_values, set_lookup, branchy_locals,
            ),
          )
        }
        TInstrKind::TGlobalGet(idx) => values.push(imm_globals.get(idx))
        TInstrKind::TUnary(_, child) => {
          work.push((curr, 1))
          work.push((child, 0))
        }
        TInstrKind::TBinary(_, left, right) => {
          work.push((curr, 1))
          work.push((right, 0))
          work.push((left, 0))
        }
        TInstrKind::TRefEq(left, right) => {
          work.push((curr, 1))
          work.push((right, 0))
          work.push((left, 0))
        }
        TInstrKind::TRefIsNull(value) => {
          work.push((curr, 1))
          work.push((value, 0))
        }
        TInstrKind::TSelect(_, cond, if_true, if_false) => {
          work.push((curr, 1))
          work.push((if_false, 0))
          work.push((if_true, 0))
          work.push((cond, 0))
        }
        _ => {
          let advanced = pc_count_local_gets_iterative(curr)
          get_id_ref.update(fn(n) { n + advanced })
          values.push(None)
        }
      }
      continue
    }
    match curr.kind {
      TInstrKind::TUnary(op, _) => {
        let child_v = values.pop().unwrap()
        match child_v {
          Some(v) => values.push(pc_eval_unary(op, v))
          None => values.push(None)
        }
      }
      TInstrKind::TBinary(op, _, _) => {
        let right_v = values.pop().unwrap()
        let left_v = values.pop().unwrap()
        match (left_v, right_v) {
          (Some(a), Some(b)) => values.push(pc_eval_binary(op, a, b))
          _ => values.push(None)
        }
      }
      TInstrKind::TRefEq(_, _) => {
        let right_v = values.pop().unwrap()
        let left_v = values.pop().unwrap()
        let out = match (left_v, right_v) {
          (Some(PCRefNull(_)), Some(PCRefNull(_))) => Some(PCLiteral::PCI32(1))
          (Some(PCRefFunc(a)), Some(PCRefFunc(b))) =>
            Some(PCLiteral::PCI32(if a == b { 1 } else { 0 }))
          (Some(PCRefNull(_)), Some(PCRefFunc(_)))
          | (Some(PCRefFunc(_)), Some(PCRefNull(_))) =>
            Some(PCLiteral::PCI32(0))
          _ => None
        }
        values.push(out)
      }
      TInstrKind::TRefIsNull(_) => {
        let value_v = values.pop().unwrap()
        let out = match value_v {
          Some(PCRefNull(_)) => Some(PCLiteral::PCI32(1))
          Some(PCRefFunc(_)) => Some(PCLiteral::PCI32(0))
          _ => None
        }
        values.push(out)
      }
      TInstrKind::TSelect(_, _, _, _) => {
        let false_v = values.pop().unwrap()
        let true_v = values.pop().unwrap()
        let cond_v = values.pop().unwrap()
        let out = match (cond_v, true_v, false_v) {
          (Some(PCI32(c)), Some(t), Some(f)) =>
            if c == 0 {
              Some(f)
            } else {
              Some(t)
            }
          _ => None
        }
        values.push(out)
      }
      _ => values.push(None)
    }
  }
  if values.is_empty() {
    None
  } else {
    values[values.length() - 1]
  }
}

///|
fn pc_collect_analysis_data(
  body : TExpr,
) -> (Array[PCSetSite], Map[PCSetLookupKey, Int], Set[LocalIdx], Int) {
  let sites : Array[PCSetSite] = []
  let set_lookup : Map[PCSetLookupKey, Int] = Map::new()
  let branchy_locals : Set[LocalIdx] = Set::new()
  let mut get_id = 0
  let mut set_id = 0

  let stack : Array[(TInstr, Bool, Bool)] = []
  for i = body.instrs.length() - 1; i >= 0; i = i - 1 {
    stack.push((body.instrs[i], false, false))
  }

  while !stack.is_empty() {
    let (curr, expanded, in_if) = stack.pop().unwrap()
    if expanded {
      match curr.kind {
        TInstrKind::TLocalGet(_) => get_id += 1
        _ => ()
      }
      continue
    }

    match curr.kind {
      TInstrKind::TLocalSet(local_idx, value) => {
        let sid = set_id
        set_id += 1
        let root_hash = pc_instr_hash_u64(curr)
        set_lookup[{ local_idx, root_hash }] = sid
        sites.push({
          key: { local_idx, set_id: sid },
          value,
          start_get_id: get_id,
        })
        if in_if {
          branchy_locals.add(local_idx)
        }
      }
      _ => ()
    }

    let enters_if = match curr.kind {
      TInstrKind::TIf(_, _, _, _) => true
      _ => false
    }
    let new_in_if = if in_if { true } else { enters_if }
    stack.push((curr, true, new_in_if))
    match curr.kind {
      TInstrKind::TBlock(_, expr) | TInstrKind::TLoop(_, expr) =>
        for i = expr.instrs.length() - 1; i >= 0; i = i - 1 {
          stack.push((expr.instrs[i], false, new_in_if))
        }
      TInstrKind::TIf(_, cond, then_expr, else_expr) => {
        if else_expr is Some(else_body) {
          for i = else_body.instrs.length() - 1; i >= 0; i = i - 1 {
            stack.push((else_body.instrs[i], false, new_in_if))
          }
        }
        for i = then_expr.instrs.length() - 1; i >= 0; i = i - 1 {
          stack.push((then_expr.instrs[i], false, new_in_if))
        }
        stack.push((cond, false, new_in_if))
      }
      TInstrKind::TTryTable(_, _, expr) =>
        for i = expr.instrs.length() - 1; i >= 0; i = i - 1 {
          stack.push((expr.instrs[i], false, new_in_if))
        }
      _ => {
        let children = eval_children(curr)
        for i = children.length() - 1; i >= 0; i = i - 1 {
          stack.push((children[i], false, new_in_if))
        }
      }
    }
  }

  (sites, set_lookup, branchy_locals, get_id)
}

///|
fn pc_analyze_get_values_from_data(
  sites : Array[PCSetSite],
  set_lookup : Map[PCSetLookupKey, Int],
  branchy_locals : Set[LocalIdx],
  total_gets : Int,
  graph : LocalGraph,
  imm_globals : Map[GlobalIdx, PCLiteral],
  eval_cache : Map[UInt64, PCLiteral],
  max_rounds : Int,
  trace? : (String) -> Unit = fn(_) {  },
) -> Map[Int, PCLiteral] {
  let mut prev_set_values : Map[PCSetKey, PCLiteral] = Map::new()
  let mut prev_get_values : Map[Int, PCLiteral] = Map::new()
  let mut rounds = 0
  while rounds < max_rounds {
    rounds += 1
    let round_start_ms = pc_trace_now_ms()
    let set_values : Map[PCSetKey, PCLiteral] = Map::new()
    let set_eval_start_ms = round_start_ms
    for site in sites {
      let get_ref = Ref::new(site.start_get_id)
      match
        pc_eval_expr_for_prop(
          site.value,
          graph,
          prev_set_values,
          set_lookup,
          imm_globals,
          branchy_locals,
          get_ref,
          eval_cache,
        ) {
        Some(v) => set_values[site.key] = v
        None => ()
      }
    }
    let set_eval_elapsed_ms = pc_trace_elapsed_ms(set_eval_start_ms)
    let get_values : Map[Int, PCLiteral] = Map::new()
    let get_scan_start_ms = pc_trace_now_ms()
    for id in 0..<total_gets {
      match
        pc_get_constant_for_get_id(
          graph, id, set_values, set_lookup, branchy_locals,
        ) {
        Some(v) => get_values[id] = v
        None => ()
      }
    }
    let get_scan_elapsed_ms = pc_trace_elapsed_ms(get_scan_start_ms)
    let changed = !pc_set_literal_maps_equal(prev_set_values, set_values) ||
      !pc_literal_maps_equal(prev_get_values, get_values)
    trace(
      "prop round[\{rounds}/\{max_rounds}] elapsed_ms=\{pc_trace_elapsed_ms(round_start_ms)} set_eval_ms=\{set_eval_elapsed_ms} get_scan_ms=\{get_scan_elapsed_ms} set_constants=\{set_values.length()} get_constants=\{get_values.length()} changed=\{changed}",
    )
    prev_set_values = set_values
    prev_get_values = get_values
    if !changed {
      break
    }
  }
  prev_get_values
}

///|
fn pc_count_local_sets_and_gets(body : TExpr) -> (Int, Int) {
  let mut sets = 0
  let mut gets = 0
  let stack : Array[TInstr] = body.instrs.copy()
  while !stack.is_empty() {
    let curr = stack.pop().unwrap()
    match curr.kind {
      TInstrKind::TLocalSet(_, _) => sets += 1
      TInstrKind::TLocalGet(_) => gets += 1
      _ => ()
    }
    pc_push_full_children_reversed(stack, curr)
  }
  (sets, gets)
}

///|
fn pc_count_body_nodes_up_to_limit(body : TExpr, limit : Int) -> (Int, Bool) {
  let stack : Array[TInstr] = body.instrs.copy()
  let mut count = 0
  while !stack.is_empty() {
    let curr = stack.pop().unwrap()
    count += 1
    if count > limit {
      return (count, true)
    }
    pc_push_full_children_reversed(stack, curr)
  }
  (count, false)
}

///|
fn pc_replace_gets_with_constants(
  body : TExpr,
  get_values : Map[Int, PCLiteral],
) -> TExpr {
  if get_values.is_empty() {
    return body
  }
  let next_get_id = Ref::new(0)
  let replacer = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    curr,
  ) {
    match curr.kind {
      TInstrKind::TLocalGet(_) => {
        let current_id = next_get_id.val
        next_get_id.update(fn(n) { n + 1 })
        match get_values.get(current_id) {
          Some(v) => change((), pc_instr_from_literal(v))
          None => unchanged()
        }
      }
      _ => self.walk_tinstruction_default((), curr)
    }
  })
  match replacer.walk_texpr((), body) {
    Ok(Some((_, out))) => out
    _ => body
  }
}

///|
fn pc_is_effectively_pure(instr : TInstr) -> Bool {
  let effects = lcs_collect_effects(instr)
  !effects.writes_memory &&
  !effects.reads_memory &&
  !effects.writes_globals &&
  !effects.reads_globals &&
  !effects.calls &&
  !effects.branches &&
  !effects.throws &&
  !effects.traps &&
  effects.locals_written.length() == 0
}

///|
fn pc_is_constant_like(
  instr : TInstr,
  imm_globals : Map[GlobalIdx, PCLiteral],
  eval_cache : Map[UInt64, PCLiteral],
) -> Bool {
  pc_eval_const_expr_cached(instr, imm_globals, eval_cache) is Some(_)
}

///|
fn pc_try_partial_precompute(
  instr : TInstr,
  imm_globals : Map[GlobalIdx, PCLiteral],
  eval_cache : Map[UInt64, PCLiteral],
) -> TInstr? {
  match instr.kind {
    TInstrKind::TUnary(
      op,
      { kind: TInstrKind::TSelect(types, cond, if_true, if_false), .. }
    ) =>
      if pc_is_constant_like(if_true, imm_globals, eval_cache) &&
        pc_is_constant_like(if_false, imm_globals, eval_cache) {
        let true_eval = pc_eval_const_expr_cached(
          TInstr::unary(op, if_true),
          imm_globals,
          eval_cache,
        )
        let false_eval = pc_eval_const_expr_cached(
          TInstr::unary(op, if_false),
          imm_globals,
          eval_cache,
        )
        match (true_eval, false_eval) {
          (Some(t), Some(f)) =>
            Some(
              TInstr::select(
                types,
                cond,
                pc_instr_from_literal(t),
                pc_instr_from_literal(f),
              ),
            )
          _ => None
        }
      } else {
        None
      }
    TInstrKind::TBinary(
      op,
      { kind: TInstrKind::TSelect(types, cond, if_true, if_false), .. },
      right
    ) =>
      if pc_is_constant_like(if_true, imm_globals, eval_cache) &&
        pc_is_constant_like(if_false, imm_globals, eval_cache) &&
        pc_is_constant_like(right, imm_globals, eval_cache) {
        let true_eval = pc_eval_const_expr_cached(
          TInstr::binary(op, if_true, right),
          imm_globals,
          eval_cache,
        )
        let false_eval = pc_eval_const_expr_cached(
          TInstr::binary(op, if_false, right),
          imm_globals,
          eval_cache,
        )
        match (true_eval, false_eval) {
          (Some(t), Some(f)) =>
            Some(
              TInstr::select(
                types,
                cond,
                pc_instr_from_literal(t),
                pc_instr_from_literal(f),
              ),
            )
          _ => None
        }
      } else {
        None
      }
    TInstrKind::TBinary(
      op,
      left,
      { kind: TInstrKind::TSelect(types, cond, if_true, if_false), .. }
    ) =>
      if pc_is_constant_like(if_true, imm_globals, eval_cache) &&
        pc_is_constant_like(if_false, imm_globals, eval_cache) &&
        pc_is_constant_like(left, imm_globals, eval_cache) {
        let true_eval = pc_eval_const_expr_cached(
          TInstr::binary(op, left, if_true),
          imm_globals,
          eval_cache,
        )
        let false_eval = pc_eval_const_expr_cached(
          TInstr::binary(op, left, if_false),
          imm_globals,
          eval_cache,
        )
        match (true_eval, false_eval) {
          (Some(t), Some(f)) =>
            Some(
              TInstr::select(
                types,
                cond,
                pc_instr_from_literal(t),
                pc_instr_from_literal(f),
              ),
            )
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn pc_fold_instr(
  instr : TInstr,
  imm_globals : Map[GlobalIdx, PCLiteral],
  options : OptimizeOptions,
  eval_cache : Map[UInt64, PCLiteral],
  allow_partial_precompute : Bool,
) -> TInstr {
  match instr.kind {
    TInstrKind::TGlobalGet(idx) =>
      match imm_globals.get(idx) {
        Some(v) => return pc_instr_from_literal(v)
        None => ()
      }
    _ => ()
  }
  match instr.kind {
    TInstrKind::TSelect(_, cond, if_true, if_false) =>
      match pc_eval_const_expr_cached(cond, imm_globals, eval_cache) {
        Some(PCI32(v)) =>
          if pc_is_effectively_pure(if_true) && pc_is_effectively_pure(if_false) {
            return if v == 0 { if_false } else { if_true }
          }
        _ => ()
      }
    _ => ()
  }
  if options.optimize_level >= 2 && allow_partial_precompute {
    match pc_try_partial_precompute(instr, imm_globals, eval_cache) {
      Some(next) => return next
      None => ()
    }
  }
  if pc_is_effectively_pure(instr) {
    match pc_eval_const_expr_cached(instr, imm_globals, eval_cache) {
      Some(v) => return pc_instr_from_literal(v)
      None => ()
    }
  }
  instr
}

///|
fn pc_simplify_body(
  body : TExpr,
  imm_globals : Map[GlobalIdx, PCLiteral],
  options : OptimizeOptions,
  eval_cache : Map[UInt64, PCLiteral],
  allow_partial_precompute : Bool,
  trace? : (String) -> Unit = fn(_) {  },
) -> (TExpr, Bool) {
  let body_start_ms = pc_trace_now_ms()
  let changed = Ref::new(false)
  let visited = Ref::new(0)
  let rewritten = Ref::new(0)
  let cache_hits = Ref::new(0)
  let last_progress_ms = Ref::new(body_start_ms)
  let simplify_cache : Map[TInstr, TInstr] = Map::new()
  let slow_stats : Map[PCSlowKey, PCSlowStat] = Map::new()
  let slow_order : Array[PCSlowKey] = []
  trace(
    "start top=\{body.instrs.length()} allow_partial=\{allow_partial_precompute}",
  )
  let pass = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    visited.update(fn(n) { n + 1 })
    let visit_id = visited.val
    match simplify_cache.get(curr) {
      Some(cached) => {
        cache_hits.update(fn(n) { n + 1 })
        let now_ms = pc_trace_now_ms()
        let total_elapsed_ms = pc_trace_elapsed_ms(body_start_ms)
        let progress_elapsed_ms = if now_ms >= last_progress_ms.val {
          now_ms - last_progress_ms.val
        } else {
          0UL
        }
        let should_trace_progress = (visit_id <= 1024 && visit_id % 64 == 0) ||
          visit_id % 4096 == 0 ||
          progress_elapsed_ms >= 1000UL
        if should_trace_progress {
          trace(
            "progress visited=\{visit_id} rewritten=\{rewritten.val} cache_hits=\{cache_hits.val} elapsed_ms=\{total_elapsed_ms} tag=\{pc_trace_instr_tag(curr)} hash=\{pc_instr_hash_u64(curr)}",
          )
          last_progress_ms.val = now_ms
        }
        if cached == curr {
          unchanged()
        } else {
          changed.update(fn(_) { true })
          rewritten.update(fn(n) { n + 1 })
          change((), cached)
        }
      }
      None => {
        let walk_start_ms = pc_trace_now_ms()
        let walked = match self.walk_tinstruction_default((), curr) {
          Ok(Some((_, out))) => out
          Ok(None) => curr
          Err(_) => curr
        }
        let walk_elapsed_ms = pc_trace_elapsed_ms(walk_start_ms)
        if walk_elapsed_ms >= 25UL {
          pc_record_slow_trace(
            slow_stats,
            slow_order,
            Walk,
            curr,
            walk_elapsed_ms,
          )
        }
        let fold_start_ms = pc_trace_now_ms()
        let next = pc_fold_instr(
          walked, imm_globals, options, eval_cache, allow_partial_precompute,
        )
        let fold_elapsed_ms = pc_trace_elapsed_ms(fold_start_ms)
        if fold_elapsed_ms >= 25UL {
          pc_record_slow_trace(
            slow_stats,
            slow_order,
            Fold,
            walked,
            fold_elapsed_ms,
          )
        }
        simplify_cache[curr] = next
        let now_ms = pc_trace_now_ms()
        let total_elapsed_ms = pc_trace_elapsed_ms(body_start_ms)
        let progress_elapsed_ms = if now_ms >= last_progress_ms.val {
          now_ms - last_progress_ms.val
        } else {
          0UL
        }
        let should_trace_progress = (visit_id <= 1024 && visit_id % 64 == 0) ||
          visit_id % 4096 == 0 ||
          progress_elapsed_ms >= 1000UL
        if should_trace_progress {
          trace(
            "progress visited=\{visit_id} rewritten=\{rewritten.val} cache_hits=\{cache_hits.val} elapsed_ms=\{total_elapsed_ms} tag=\{pc_trace_instr_tag(curr)} hash=\{pc_instr_hash_u64(curr)}",
          )
          last_progress_ms.val = now_ms
        }
        if next != walked {
          rewritten.update(fn(n) { n + 1 })
        }
        if next == curr {
          unchanged()
        } else {
          changed.update(fn(_) { true })
          change((), next)
        }
      }
    }
  })
  match pass.walk_texpr((), body) {
    Ok(Some((_, out))) => {
      for line in pc_slow_summary_lines(slow_stats, slow_order) {
        trace(line)
      }
      trace(
        "done elapsed_ms=\{pc_trace_elapsed_ms(body_start_ms)} visited=\{visited.val} rewritten=\{rewritten.val} cache_hits=\{cache_hits.val} cache_entries=\{simplify_cache.length()} changed=\{changed.val} top=\{body.instrs.length()}->\{out.instrs.length()}",
      )
      (out, changed.val)
    }
    Ok(None) => {
      for line in pc_slow_summary_lines(slow_stats, slow_order) {
        trace(line)
      }
      trace(
        "done elapsed_ms=\{pc_trace_elapsed_ms(body_start_ms)} visited=\{visited.val} rewritten=\{rewritten.val} cache_hits=\{cache_hits.val} cache_entries=\{simplify_cache.length()} changed=false top=\{body.instrs.length()}->\{body.instrs.length()}",
      )
      (body, false)
    }
    Err(_) => {
      for line in pc_slow_summary_lines(slow_stats, slow_order) {
        trace(line)
      }
      trace(
        "error elapsed_ms=\{pc_trace_elapsed_ms(body_start_ms)} visited=\{visited.val} rewritten=\{rewritten.val} cache_hits=\{cache_hits.val} cache_entries=\{simplify_cache.length()}",
      )
      (body, false)
    }
  }
}

///|
fn precompute_on_func(
  ordinal : Int,
  func : Func,
  mod : Module,
  options : OptimizeOptions,
  propagate : Bool,
  trace : (String) -> Unit,
  trace_all_funcs : Bool,
) -> Result[Func, String] {
  let func_start_ms = pc_trace_now_ms()
  match func {
    Func(_) => {
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] skip non-typed-func elapsed_ms=\{pc_trace_elapsed_ms(func_start_ms)}",
        )
      }
      Ok(func)
    }
    TFunc(locals, initial_body) => {
      let imm_globals_start_ms = pc_trace_now_ms()
      let imm_globals = pc_collect_immutable_globals(mod)
      let imm_globals_elapsed_ms = pc_trace_elapsed_ms(imm_globals_start_ms)
      let top_instrs = initial_body.instrs.length()
      let num_locals = locals.length()

      if top_instrs > 16000 {
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] skip top_instrs=\{top_instrs} > 16000 imm_globals_ms=\{imm_globals_elapsed_ms} elapsed_ms=\{pc_trace_elapsed_ms(func_start_ms)}",
          )
        }
        return Ok(func)
      }
      if num_locals > 2000 {
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] skip num_locals=\{num_locals} > 2000 imm_globals_ms=\{imm_globals_elapsed_ms} elapsed_ms=\{pc_trace_elapsed_ms(func_start_ms)}",
          )
        }
        return Ok(func)
      }

      let count_start_ms = pc_trace_now_ms()
      let (num_sets, num_gets) = pc_count_local_sets_and_gets(initial_body)
      let count_elapsed_ms = pc_trace_elapsed_ms(count_start_ms)
      let total_node_limit = if propagate { 50000 } else { 20000 }
      let node_count_start_ms = pc_trace_now_ms()
      let (total_nodes, total_nodes_over_limit) = pc_count_body_nodes_up_to_limit(
        initial_body, total_node_limit,
      )
      let node_count_elapsed_ms = pc_trace_elapsed_ms(node_count_start_ms)

      // FINAL STRICT GATING — tuned on your real traces
      let density = if top_instrs == 0 {
        0.0
      } else {
        num_sets.to_double() / top_instrs.to_double()
      }

      let do_propagate = propagate &&
        top_instrs <= 6000 &&
        num_sets >= 20 &&
        num_gets >= 80 &&
        num_locals <= 2000 &&
        num_sets <= 120 &&
        density <= 0.50

      let max_rounds = if num_sets > 60 { 2 } else { 4 }

      if trace_all_funcs {
        trace(
          "func[\{ordinal}] start top=\{top_instrs} locals=\{num_locals} sets=\{num_sets} gets=\{num_gets} total_nodes=\{total_nodes} total_nodes_over_limit=\{total_nodes_over_limit} total_node_limit=\{total_node_limit} density=\{density} propagate=\{do_propagate} maxr=\{max_rounds} imm_globals=\{imm_globals.length()} imm_globals_ms=\{imm_globals_elapsed_ms} count_ms=\{count_elapsed_ms} node_count_ms=\{node_count_elapsed_ms}",
        )
      }

      if total_nodes_over_limit {
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] skip total_nodes=\{total_nodes} > \{total_node_limit} elapsed_ms=\{pc_trace_elapsed_ms(func_start_ms)}",
          )
        }
        return Ok(func)
      }

      let mut body = initial_body
      let eval_cache : Map[UInt64, PCLiteral] = Map::new()
      let allow_partial = do_propagate && num_sets <= 80

      if trace_all_funcs {
        trace("func[\{ordinal}] config partial=\{allow_partial}")
      }

      if do_propagate {
        let graph_start_ms = pc_trace_now_ms()
        let graph = LocalGraph::new(body.instrs)
        let graph_elapsed_ms = pc_trace_elapsed_ms(graph_start_ms)
        let analysis_start_ms = pc_trace_now_ms()
        let (sites, set_lookup, branchy_locals, total_gets) = pc_collect_analysis_data(
          body,
        )
        let analysis_elapsed_ms = pc_trace_elapsed_ms(analysis_start_ms)
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] prop setup graph_ms=\{graph_elapsed_ms} analysis_ms=\{analysis_elapsed_ms} sites=\{sites.length()} set_lookup=\{set_lookup.length()} branchy=\{branchy_locals.length()} gets=\{total_gets}",
          )
        }
        let analyze_start_ms = pc_trace_now_ms()
        let get_values = pc_analyze_get_values_from_data(
          sites,
          set_lookup,
          branchy_locals,
          total_gets,
          graph,
          imm_globals,
          eval_cache,
          max_rounds,
          trace=if trace_all_funcs {
            fn(msg) { trace("func[\{ordinal}] \{msg}") }
          } else {
            fn(_) {  }
          },
        )
        let analyze_elapsed_ms = pc_trace_elapsed_ms(analyze_start_ms)
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] prop analyze elapsed_ms=\{analyze_elapsed_ms} constants_found=\{get_values.length()}",
          )
        }
        if !get_values.is_empty() {
          let replace_start_ms = pc_trace_now_ms()
          body = pc_replace_gets_with_constants(body, get_values)
          let replace_elapsed_ms = pc_trace_elapsed_ms(replace_start_ms)
          if trace_all_funcs {
            trace(
              "func[\{ordinal}] prop replace elapsed_ms=\{replace_elapsed_ms} replaced=true",
            )
          }
        } else if trace_all_funcs {
          trace("func[\{ordinal}] prop replace elapsed_ms=0 replaced=false")
        }
      } else if trace_all_funcs {
        trace("func[\{ordinal}] propagate skipped")
      }

      // BROADER CHEAP SKIP — covers the remaining medium tail
      if !do_propagate && top_instrs <= 512 && num_sets <= 40 {
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] simplify skipped (medium body + moderate sets)",
          )
        }
        return Ok(Func::t_func(locals, body))
      }

      let simplify_rounds = if do_propagate { 2 } else { 1 }
      let mut rounds = 0
      while rounds < simplify_rounds {
        rounds += 1
        let simplify_round_start_ms = pc_trace_now_ms()
        let (next, changed) = pc_simplify_body(
          body,
          imm_globals,
          options,
          eval_cache,
          allow_partial,
          trace=if trace_all_funcs {
            fn(msg) {
              trace(
                "func[\{ordinal}] simplify round[\{rounds}/\{simplify_rounds}] \{msg}",
              )
            }
          } else {
            fn(_) {  }
          },
        )
        if trace_all_funcs {
          trace(
            "func[\{ordinal}] simplify round[\{rounds}/\{simplify_rounds}] summary elapsed_ms=\{pc_trace_elapsed_ms(simplify_round_start_ms)} changed=\{changed} top=\{body.instrs.length()}->\{next.instrs.length()}",
          )
        }
        if !changed {
          break
        }
        body = next
      }
      if trace_all_funcs {
        trace(
          "func[\{ordinal}] done changed=\{body != initial_body} rounds=\{rounds} final_top=\{body.instrs.length()} elapsed_ms=\{pc_trace_elapsed_ms(func_start_ms)}",
        )
      }
      Ok(Func::t_func(locals, body))
    }
  }
}

///|
fn precompute_ir_pass(
  mod : Module,
  options : OptimizeOptions,
  propagate : Bool,
  trace? : (String) -> Unit = fn(_) {  },
  trace_all_funcs? : Bool = false,
) -> ModuleTransformer[IRContext] {
  let ordinal = Ref::new(0)
  ModuleTransformer::new().on_func_evt(fn(_self, ctx : IRContext, func) {
    let curr_ordinal = ordinal.val
    ordinal.update(fn(n) { n + 1 })
    match
      precompute_on_func(
        curr_ordinal, func, mod, options, propagate, trace, trace_all_funcs,
      ) {
      Ok(next_func) =>
        match (func, next_func) {
          (TFunc(orig_locals, orig_body), TFunc(next_locals, next_body)) => {
            ctx.set_body(next_body)
            if orig_locals == next_locals && orig_body == next_body {
              unchanged()
            } else {
              change(ctx, Func::t_func(next_locals, next_body))
            }
          }
          _ => change(ctx, next_func)
        }
      Err(e) => Err(e)
    }
  })
}

///|
fn createPrecomputePass() -> ModulePass {
  ModulePass::Precompute
}

///|
fn createPrecomputePropagatePass() -> ModulePass {
  ModulePass::PrecomputePropagate
}

///|
fn pc_run_module(
  mod : Module,
  propagate? : Bool = false,
  options? : OptimizeOptions = OptimizeOptions::new(optimize_level=2),
) -> Result[Module, String] {
  let pass = if propagate {
    ModulePass::PrecomputePropagate
  } else {
    ModulePass::Precompute
  }
  optimize_module_with_options(mod, [pass], options)
}

///|
fn pc_top_level_result_types(
  body : Array[TInstr],
  locals : Array[ValType],
  mod : Module,
) -> Array[ValType] {
  let out : Array[ValType] = []
  let env = Env::new().with_module(mod).with_locals(locals)
  for instr in body {
    match lcs_infer_tinstr_type(instr, env) {
      Some(vt) => out.push(vt)
      None => ()
    }
  }
  out
}

///|
fn pc_single_func_module(
  body : Array[TInstr],
  locals? : Array[ValType] = [],
  base_mod? : Module = Module::new(),
) -> Module {
  let results = pc_top_level_result_types(body, locals, base_mod)
  let sig = single_rec_type(comp_type_sub_type(func_comp_type([], results)))
  base_mod
  .with_type_sec(TypeSec::new([sig]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func(locals, TExpr::new(body))]))
}

///|
fn pc_expect_literal(actual : PCLiteral?, expected : PCLiteral) -> Unit raise {
  match actual {
    Some(v) => assert_true(v == expected)
    None => fail("expected literal result")
  }
}

///|
test "precompute constructors return expected module pass variants" {
  match createPrecomputePass() {
    ModulePass::Precompute => ()
    _ => fail("expected createPrecomputePass to return ModulePass::Precompute")
  }
  match createPrecomputePropagatePass() {
    ModulePass::PrecomputePropagate => ()
    _ =>
      fail(
        "expected createPrecomputePropagatePass to return ModulePass::PrecomputePropagate",
      )
  }
}

///|
test "precompute counts body nodes up to a limit" {
  let body = TExpr::new([
    TInstr::block(
      BlockType::void_(),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1))),
        TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      ]),
    ),
  ])
  let (full_count, full_over_limit) = pc_count_body_nodes_up_to_limit(body, 10)
  assert_eq(full_count, 5)
  assert_false(full_over_limit)

  let (limited_count, limited_over_limit) = pc_count_body_nodes_up_to_limit(
    body, 3,
  )
  assert_eq(limited_count, 4)
  assert_true(limited_over_limit)
}

///|
test "precompute counters descend into nested control flow" {
  let body = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([
        TInstr::local_set(LocalIdx::new(1), TInstr::local_get(LocalIdx::new(2))),
      ]),
      Some(TExpr::new([TInstr::drop(TInstr::local_get(LocalIdx::new(3)))])),
    ),
  ])

  let (sets, gets) = pc_count_local_sets_and_gets(body)
  assert_eq(sets, 1)
  assert_eq(gets, 3)

  let (count, over_limit) = pc_count_body_nodes_up_to_limit(body, 16)
  assert_eq(count, 6)
  assert_false(over_limit)
}

///|
test "precompute trace covers function lifecycle timings" {
  let body : Array[TInstr] = []
  let locals : Array[ValType] = []
  for i in 0..<20 {
    locals.push(ValType::i32())
    body.push(
      TInstr::local_set(
        LocalIdx::new(i.reinterpret_as_uint()),
        TInstr::i32_const(I32(i + 1)),
      ),
    )
  }
  for _ in 0..<80 {
    body.push(TInstr::drop(TInstr::local_get(LocalIdx::new(0))))
  }

  let mod = pc_single_func_module(body, locals~)
  let trace_logs : Array[String] = []
  match
    optimize_module_with_options_trace(
      mod,
      [ModulePass::PrecomputePropagate],
      OptimizeOptions::new(optimize_level=2),
      fn(msg) { trace_logs.push(msg) },
    ) {
    Ok(_) => ()
    Err(e) => fail("unexpected precompute trace error: \{e}")
  }

  let mut saw_setup = false
  let mut saw_round = false
  let mut saw_replace = false
  let mut saw_simplify = false
  let mut saw_done = false
  for msg in trace_logs {
    if msg.contains("precompute:func[0] prop setup") {
      saw_setup = true
    }
    if msg.contains("precompute:func[0] prop round[") {
      saw_round = true
    }
    if msg.contains("precompute:func[0] prop replace elapsed_ms=") {
      saw_replace = true
    }
    if msg.contains("precompute:func[0] simplify round[") {
      saw_simplify = true
    }
    if msg.contains("precompute:func[0] done changed=") &&
      msg.contains("elapsed_ms=") {
      saw_done = true
    }
  }
  assert_true(saw_setup)
  assert_true(saw_round)
  assert_true(saw_replace)
  assert_true(saw_simplify)
  assert_true(saw_done)
}

///|
test "precompute simplify propagates child rewrite without rewalking parent" {
  let (out, changed) = pc_simplify_body(
    TExpr::new([
      TInstr::drop(
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::i32_const(I32(1)),
          TInstr::i32_const(I32(2)),
        ),
      ),
    ]),
    Map::new(),
    OptimizeOptions::new(optimize_level=2),
    Map::new(),
    false,
  )
  assert_true(changed)
  match out.instrs {
    [
      {
        kind: TInstrKind::TDrop({ kind: TInstrKind::TI32Const(I32(3)), .. }),
        ..,
      },
    ] => ()
    _ => fail("expected folded child rewrite to be preserved at parent")
  }
}

///|
test "precompute simplify trace reports cache hits for repeated identical subtrees" {
  let repeated = TInstr::drop(
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::i32_const(I32(1)),
      TInstr::i32_const(I32(2)),
    ),
  )
  let logs : Array[String] = []
  let (_, changed) = pc_simplify_body(
    TExpr::new([repeated, repeated]),
    Map::new(),
    OptimizeOptions::new(optimize_level=2),
    Map::new(),
    false,
    trace=fn(msg) { logs.push(msg) },
  )
  assert_true(changed)
  let done = logs.last().unwrap_or("")
  assert_true(done.contains("cache_hits="))
  assert_true(done.contains("cache_entries="))
}

///|
test "precompute slow summary lines aggregate repeated hashes" {
  let stats : Map[PCSlowKey, PCSlowStat] = Map::new()
  let order : Array[PCSlowKey] = []
  let repeated = TInstr::block(
    BlockType::void_(),
    TExpr::new([TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(1)))]),
  )
  pc_record_slow_trace(stats, order, Walk, repeated, 30UL)
  pc_record_slow_trace(stats, order, Walk, repeated, 45UL)
  let lines = pc_slow_summary_lines(stats, order, limit=4)
  assert_eq(lines.length(), 1)
  assert_true(lines[0].contains("walk_slow count=2"))
  assert_true(lines[0].contains("tag=block"))
}

///|
test "precompute skips simplify for tiny non-propagating body" {
  let mod = pc_single_func_module([
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::i32_const(I32(1)),
      TInstr::i32_const(I32(2)),
    ),
    TInstr::unary(UnaryOp::i32_eqz(), TInstr::i32_const(I32(0))),
  ])
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TBinary(
                    I32AddOp,
                    { kind: TInstrKind::TI32Const(I32(1)), .. },
                    { kind: TInstrKind::TI32Const(I32(2)), .. }
                  ),
                  ..,
                },
                {
                  kind: TInstrKind::TUnary(
                    I32EqzOp,
                    { kind: TInstrKind::TI32Const(I32(0)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("expected tiny non-propagating body to remain unchanged")
  }
}

///|
test "precompute leaves nested constant tree unchanged for tiny body" {
  let mod = pc_single_func_module([
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::i32_const(I32(2)),
        TInstr::i32_const(I32(3)),
      ),
      TInstr::i32_const(I32(4)),
    ),
  ])
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TBinary(
                    I32AddOp,
                    { kind: TInstrKind::TBinary(I32MulOp, _, _), .. },
                    { kind: TInstrKind::TI32Const(I32(4)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("expected nested constant expression to remain unchanged")
  }
}

///|
test "precompute does not fold trapping integer division by zero" {
  let mod = pc_single_func_module([
    TInstr::binary(
      BinaryOp::i32_div_s(),
      TInstr::i32_const(I32(10)),
      TInstr::i32_const(I32(0)),
    ),
  ])
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            { instrs: [{ kind: TInstrKind::TBinary(I32DivSOp, _, _), .. }], .. }
          ),
        ]
      )
    ) => ()
    _ => fail("expected i32.div_s by zero to remain")
  }
}

///|
test "precompute leaves immutable global.get unchanged for tiny body" {
  let mod = pc_single_func_module(
    [TInstr::drop(TInstr::global_get(GlobalIdx::new(0)))],
    base_mod=Module::new().with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i32(), false),
          Expr::new([Instruction::i32_const(I32(7))]),
        ),
      ]),
    ),
  )
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TDrop(
                    { kind: TInstrKind::TGlobalGet(GlobalIdx(0U)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("expected tiny-body global.get to remain unchanged")
  }
}

///|
test "precompute propagate skips tiny function under strict gating" {
  let x = LocalIdx::new(0)
  let mod = pc_single_func_module(
    [
      TInstr::local_set(x, TInstr::i32_const(I32(42))),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(x),
        TInstr::i32_const(I32(1)),
      ),
    ],
    locals=[ValType::i32()],
  )
  let out = pc_run_module(mod, propagate=true).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TLocalSet(_, _), .. },
                {
                  kind: TInstrKind::TBinary(
                    I32AddOp,
                    { kind: TInstrKind::TLocalGet(_), .. },
                    { kind: TInstrKind::TI32Const(I32(1)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("expected strict gating to skip tiny-function propagation")
  }
}

///|
test "precompute propagate skips chained tiny function under strict gating" {
  let a = LocalIdx::new(0)
  let b = LocalIdx::new(1)
  let c = LocalIdx::new(2)
  let mod = pc_single_func_module(
    [
      TInstr::local_set(a, TInstr::i32_const(I32(10))),
      TInstr::local_set(
        b,
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(a),
          TInstr::i32_const(I32(5)),
        ),
      ),
      TInstr::local_set(
        c,
        TInstr::binary(
          BinaryOp::i32_add(),
          TInstr::local_get(b),
          TInstr::i32_const(I32(7)),
        ),
      ),
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::local_get(c),
        TInstr::i32_const(I32(1)),
      ),
    ],
    locals=[ValType::i32(), ValType::i32(), ValType::i32()],
  )
  let out = pc_run_module(mod, propagate=true).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TLocalSet(_, _), .. },
                { kind: TInstrKind::TLocalSet(_, _), .. },
                { kind: TInstrKind::TLocalSet(_, _), .. },
                {
                  kind: TInstrKind::TBinary(
                    I32AddOp,
                    { kind: TInstrKind::TLocalGet(_), .. },
                    { kind: TInstrKind::TI32Const(I32(1)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ =>
      fail("expected strict gating to skip chained tiny-function propagation")
  }
}

///|
test "precompute propagate is conservative on conflicting if-merge sets" {
  let x = LocalIdx::new(0)
  let cond = LocalIdx::new(1)
  let mod = pc_single_func_module(
    [
      TInstr::if_(
        BlockType::void_(),
        TInstr::local_get(cond),
        TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(1)))]),
        Some(TExpr::new([TInstr::local_set(x, TInstr::i32_const(I32(2)))])),
      ),
      TInstr::local_get(x),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  let out = pc_run_module(mod, propagate=true).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                { kind: TInstrKind::TIf(_, _, _, _), .. },
                { kind: TInstrKind::TLocalGet(_), .. },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("expected local.get after conflicting merge to remain")
  }
}

///|
test "precompute unary over select arms remains unchanged without propagation" {
  let cond = LocalIdx::new(0)
  let mod = pc_single_func_module(
    [
      TInstr::unary(
        UnaryOp::i32_eqz(),
        TInstr::select(
          None,
          TInstr::local_get(cond),
          TInstr::i32_const(I32(10)),
          TInstr::i32_const(I32(0)),
        ),
      ),
    ],
    locals=[ValType::i32()],
  )
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TUnary(
                    I32EqzOp,
                    {
                      kind: TInstrKind::TSelect(
                        _,
                        { kind: TInstrKind::TLocalGet(_), .. },
                        { kind: TInstrKind::TI32Const(I32(10)), .. },
                        { kind: TInstrKind::TI32Const(I32(0)), .. }
                      ),
                      ..,
                    }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ =>
      fail("expected unary/select to remain unchanged when propagation is off")
  }
}

///|
test "precompute binary over select arms remains unchanged without propagation" {
  let cond = LocalIdx::new(0)
  let mod = pc_single_func_module(
    [
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::select(
          None,
          TInstr::local_get(cond),
          TInstr::i32_const(I32(2)),
          TInstr::i32_const(I32(5)),
        ),
        TInstr::i32_const(I32(8)),
      ),
    ],
    locals=[ValType::i32()],
  )
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TBinary(
                    I32AddOp,
                    { kind: TInstrKind::TSelect(_, _, _, _), .. },
                    { kind: TInstrKind::TI32Const(I32(8)), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ =>
      fail("expected binary/select to remain unchanged when propagation is off")
  }
}

///|
test "precompute partial precompute keeps non-constant sibling case unchanged" {
  let cond = LocalIdx::new(0)
  let rhs = LocalIdx::new(1)
  let mod = pc_single_func_module(
    [
      TInstr::binary(
        BinaryOp::i32_add(),
        TInstr::select(
          None,
          TInstr::local_get(cond),
          TInstr::i32_const(I32(2)),
          TInstr::i32_const(I32(5)),
        ),
        TInstr::local_get(rhs),
      ),
    ],
    locals=[ValType::i32(), ValType::i32()],
  )
  let out = pc_run_module(mod).unwrap()
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            {
              instrs: [
                {
                  kind: TInstrKind::TBinary(
                    I32AddOp,
                    { kind: TInstrKind::TSelect(_, _, _, _), .. },
                    { kind: TInstrKind::TLocalGet(_), .. }
                  ),
                  ..,
                },
              ],
              ..,
            }
          ),
        ]
      )
    ) => ()
    _ => fail("expected non-constant sibling to block partial precompute")
  }
}

///|
test "precompute pass is idempotent in propagate mode" {
  let x = LocalIdx::new(0)
  let mod = pc_single_func_module(
    [
      TInstr::local_set(x, TInstr::i32_const(I32(9))),
      TInstr::binary(
        BinaryOp::i32_mul(),
        TInstr::local_get(x),
        TInstr::i32_const(I32(2)),
      ),
    ],
    locals=[ValType::i32()],
  )
  let once = pc_run_module(mod, propagate=true).unwrap()
  let twice = pc_run_module(once, propagate=true).unwrap()
  assert_eq(once, twice)
}

///|
test "precompute helper rounding and literal conversion paths" {
  assert_eq(pc_wrap_i64(-1L), -1L)
  assert_eq(pc_round_half_to_even_f64(2.5), 2.0)
  assert_eq(pc_round_half_to_even_f64(3.5), 4.0)
  assert_eq(pc_round_half_to_even_f32(2.5), 2.0)

  pc_expect_literal(
    pc_literal_from_instr(TInstr::i64_const(I64(9L))),
    PCI64(9L),
  )
  assert_eq(pc_instr_from_literal(PCI64(9L)), TInstr::i64_const(I64(9L)))
}

///|
test "precompute immutable global collection includes all literal kinds and import offset" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_import_sec(
      ImportSec::new([
        Import::new(
          Name::new("env"),
          Name::new("f"),
          ExternType::func(TypeIdx::new(0)),
        ),
        Import::new(
          Name::new("env"),
          Name::new("g"),
          ExternType::global(GlobalType::new(ValType::i32(), false)),
        ),
      ]),
    )
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(ValType::i64(), false),
          Expr::new([Instruction::i64_const(I64(1))]),
        ),
        Global::new(
          GlobalType::new(ValType::f32(), false),
          Expr::new([Instruction::f32_const(F32(1.25))]),
        ),
        Global::new(
          GlobalType::new(ValType::f64(), false),
          Expr::new([Instruction::f64_const(F64(2.5))]),
        ),
        Global::new(
          GlobalType::new(
            ValType::ref_type(RefType::abs(AbsHeapType::func())),
            false,
          ),
          Expr::new([Instruction::ref_null(HeapType::abs(AbsHeapType::func()))]),
        ),
        Global::new(
          GlobalType::new(
            ValType::ref_type(RefType::abs(AbsHeapType::func())),
            false,
          ),
          Expr::new([Instruction::ref_func(FuncIdx::new(0))]),
        ),
        Global::new(
          GlobalType::new(ValType::i32(), true),
          Expr::new([Instruction::i32_const(I32(99))]),
        ),
      ]),
    )
  assert_eq(pc_imported_global_count(mod), 1U)
  let imm = pc_collect_immutable_globals(mod)
  assert_eq(imm.length(), 5)
  assert_true(imm.contains(GlobalIdx::new(1)))
  assert_true(imm.contains(GlobalIdx::new(2)))
  assert_true(imm.contains(GlobalIdx::new(3)))
  assert_true(imm.contains(GlobalIdx::new(4)))
  assert_true(imm.contains(GlobalIdx::new(5)))
}

///|
test "precompute unary and binary evaluators cover i64 float conversion and trap guards" {
  pc_expect_literal(pc_eval_unary(UnaryOp::i32_clz(), PCI32(1)), PCI32(31))
  pc_expect_literal(
    pc_eval_unary(UnaryOp::i64_extend_i32u(), PCI32(-1)),
    PCI64(4294967295L),
  )
  pc_expect_literal(
    pc_eval_unary(UnaryOp::f32_reinterpret_i32(), PCI32(0)),
    PCF32(Float::reinterpret_from_int(0)),
  )
  pc_expect_literal(
    pc_eval_unary(UnaryOp::f64_convert_i32u(), PCI32(-1)),
    PCF64(4294967295.0),
  )

  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_sub(), PCI32(9), PCI32(4)),
    PCI32(5),
  )
  match pc_eval_binary(BinaryOp::i32_div_s(), PCI32(9), PCI32(0)) {
    None => ()
    _ => fail("expected i32.div_s by zero to remain non-foldable")
  }
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_div_s(), PCI32(9), PCI32(3)),
    PCI32(3),
  )
  match pc_eval_binary(BinaryOp::i32_div_u(), PCI32(9), PCI32(0)) {
    None => ()
    _ => fail("expected i32.div_u by zero to remain non-foldable")
  }
  match pc_eval_binary(BinaryOp::i32_rem_s(), PCI32(9), PCI32(0)) {
    None => ()
    _ => fail("expected i32.rem_s by zero to remain non-foldable")
  }
  match pc_eval_binary(BinaryOp::i32_rem_u(), PCI32(9), PCI32(0)) {
    None => ()
    _ => fail("expected i32.rem_u by zero to remain non-foldable")
  }
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_and(), PCI32(6), PCI32(3)),
    PCI32(2),
  )
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_shr_u(), PCI32(-2), PCI32(1)),
    PCI32(2147483647),
  )
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_rotr(), PCI32(1), PCI32(0)),
    PCI32(1),
  )
  pc_expect_literal(
    pc_eval_binary(BinaryOp::i32_eq(), PCI32(7), PCI32(7)),
    PCI32(1),
  )
}

///|
test "precompute unary evaluator folds i64 trunc float conversions with trap guards" {
  pc_expect_literal(
    pc_eval_unary(
      UnaryOp::i64_trunc_f32s(),
      PCF32(Float::from_double(3000000000.0)),
    ),
    PCI64(3000000000L),
  )
  pc_expect_literal(
    pc_eval_unary(
      UnaryOp::i64_trunc_f32s(),
      PCF32(Float::from_double(-3000000000.0)),
    ),
    PCI64(-3000000000L),
  )
  pc_expect_literal(
    pc_eval_unary(UnaryOp::i64_trunc_f64s(), PCF64(-42.9)),
    PCI64(-42L),
  )
  pc_expect_literal(
    pc_eval_unary(UnaryOp::i64_trunc_f64u(), PCF64(3000000000.0)),
    PCI64(3000000000L),
  )
  match pc_eval_unary(UnaryOp::i64_trunc_f64s(), PCF64(9223372036854775808.0)) {
    None => ()
    _ =>
      fail("expected i64.trunc_f64_s out-of-range input to remain non-foldable")
  }
  match pc_eval_unary(UnaryOp::i64_trunc_f64u(), PCF64(-1.0)) {
    None => ()
    _ => fail("expected i64.trunc_f64_u negative input to remain non-foldable")
  }
  match
    pc_eval_unary(
      UnaryOp::i64_trunc_f32s(),
      PCF32(Float::from_double(@double.not_a_number)),
    ) {
    None => ()
    _ => fail("expected i64.trunc_f32_s NaN input to remain non-foldable")
  }
}

///|
test "precompute unary evaluator rejects signaling and signed NaN payloads for trunc ops" {
  let nan32_payloads : Array[Float] = [
    Float::reinterpret_from_uint(0x7F800001),
    Float::reinterpret_from_uint(0xFFC00000),
  ]
  let f32_ops : Array[UnaryOp] = [
    UnaryOp::i32_trunc_f32s(),
    UnaryOp::i32_trunc_f32u(),
    UnaryOp::i64_trunc_f32s(),
    UnaryOp::i64_trunc_f32u(),
  ]
  for payload in nan32_payloads {
    for op in f32_ops {
      match pc_eval_unary(op, PCF32(payload)) {
        None => ()
        _ => fail("expected f32 NaN payload trunc op to remain non-foldable")
      }
    }
  }

  let nan64_payloads : Array[Double] = [
    0x7FF0000000000001UL.reinterpret_as_double(),
    0xFFF8000000000000UL.reinterpret_as_double(),
  ]
  let f64_ops : Array[UnaryOp] = [
    UnaryOp::i32_trunc_f64s(),
    UnaryOp::i32_trunc_f64u(),
    UnaryOp::i64_trunc_f64s(),
    UnaryOp::i64_trunc_f64u(),
  ]
  for payload in nan64_payloads {
    for op in f64_ops {
      match pc_eval_unary(op, PCF64(payload)) {
        None => ()
        _ => fail("expected f64 NaN payload trunc op to remain non-foldable")
      }
    }
  }
}

///|
test "precompute binary min/max folds payload NaNs for f32 and f64" {
  let snan32 = Float::reinterpret_from_uint(0x7F800001)
  let neg_qnan32 = Float::reinterpret_from_uint(0xFFC00000)
  let finite32 = Float::reinterpret_from_uint(0x3F800000)
  let f32_cases : Array[(BinaryOp, Float, Float)] = [
    (BinaryOp::f32_min(), snan32, finite32),
    (BinaryOp::f32_max(), finite32, neg_qnan32),
  ]
  for case_ in f32_cases {
    let (op, lhs, rhs) = case_
    match pc_eval_binary(op, PCF32(lhs), PCF32(rhs)) {
      Some(PCF32(v)) =>
        assert_true(
          compat_is_f32_nan(v),
          msg="expected f32 min/max with payload NaN to fold to NaN",
        )
      _ => fail("expected f32 min/max to fold to f32 NaN literal")
    }
  }

  let snan64 = 0x7FF0000000000001UL.reinterpret_as_double()
  let neg_qnan64 = 0xFFF8000000000000UL.reinterpret_as_double()
  let finite64 = 1.0
  let f64_cases : Array[(BinaryOp, Double, Double)] = [
    (BinaryOp::f64_min(), snan64, finite64),
    (BinaryOp::f64_max(), finite64, neg_qnan64),
  ]
  for case_ in f64_cases {
    let (op, lhs, rhs) = case_
    match pc_eval_binary(op, PCF64(lhs), PCF64(rhs)) {
      Some(PCF64(v)) =>
        assert_true(
          compat_is_f64_nan(v),
          msg="expected f64 min/max with payload NaN to fold to NaN",
        )
      _ => fail("expected f64 min/max to fold to f64 NaN literal")
    }
  }
}
