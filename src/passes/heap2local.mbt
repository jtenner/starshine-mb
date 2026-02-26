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
priv enum H2LShape {
  StructShape(TypeIdx, Array[FieldType])
  ArrayShape(TypeIdx, FieldType, Int)
} derive(Eq)

///|
priv enum H2LUse {
  StructGet(TypeIdx, @lib.U32)
  StructGetS(TypeIdx, @lib.U32)
  StructGetU(TypeIdx, @lib.U32)
  StructSet(TypeIdx, @lib.U32)
  ArrayGet(TypeIdx, Int)
  ArrayGetS(TypeIdx, Int)
  ArrayGetU(TypeIdx, Int)
  ArraySet(TypeIdx, Int)
  ArrayLen
  RefIsNull
  RefTest
  RefGetDesc
  RefTestDesc
  RefCastDescEq
  RefEq
  DropOnly
}

///|
priv struct H2LAnalyzeState {
  env : Env
  shapes : Map[Int, H2LShape]
  invalid : Map[Int, Bool]
  set_counts : Map[Int, Int]
  total_get_counts : Map[Int, Int]
  safe_get_counts : Map[Int, Int]
  uses : Map[Int, Array[H2LUse]]
  mut has_sync_atomic : Bool
}

///|
priv struct H2LPlan {
  shape : H2LShape
  slots : Array[LocalIdx]
}

///|
priv struct H2LRewriteState {
  plans : Map[Int, H2LPlan]
  base_local_count : Int
  new_locals : Array[ValType]
}

///|
fn h2l_local_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(i) = idx
  i.reinterpret_as_int()
}

///|
fn h2l_u32_to_int(i : @lib.U32) -> Int {
  let @lib.U32(raw) = i
  raw.reinterpret_as_int()
}

///|
fn h2l_is_valid_array_size(size : Int) -> Bool {
  size >= 0 && size < 20
}

///|
fn h2l_const_i32_nonneg(instr : TInstr) -> Int? {
  match instr {
    TI32Const(I32(v)) => if v >= 0 { Some(v) } else { None }
    _ => None
  }
}

///|
fn h2l_load_is_atomic(op : LoadOp) -> Bool {
  match op {
    I32AtomicLoadOp
    | I64AtomicLoadOp
    | I32AtomicLoad8UOp
    | I32AtomicLoad16UOp
    | I64AtomicLoad8UOp
    | I64AtomicLoad16UOp
    | I64AtomicLoad32UOp => true
    _ => false
  }
}

///|
fn h2l_store_is_atomic(op : StoreOp) -> Bool {
  match op {
    I32AtomicStoreOp
    | I64AtomicStoreOp
    | I32AtomicStore8Op
    | I32AtomicStore16Op
    | I64AtomicStore8Op
    | I64AtomicStore16Op
    | I64AtomicStore32Op => true
    _ => false
  }
}

///|
fn h2l_inc_count(map : Map[Int, Int], key : Int) -> Unit {
  map[key] = map.get(key).unwrap_or(0) + 1
}

///|
fn h2l_add_use(
  uses : Map[Int, Array[H2LUse]],
  key : Int,
  use_kind : H2LUse,
) -> Unit {
  let next = uses.get(key).unwrap_or([])
  next.push(use_kind)
  uses[key] = next
}

///|
fn h2l_mark_invalid(state : H2LAnalyzeState, loc : Int) -> Unit {
  state.invalid[loc] = true
}

///|
fn h2l_field_has_local_representation(field : FieldType) -> Bool {
  match field.unpack() {
    NumTypeValType(_) => true
    VecTypeValType => true
    RefTypeValType(_) => true
    BotValType => false
  }
}

///|
fn h2l_pack_mask(field : FieldType) -> Int? {
  match field.get_storage_type() {
    PackTypeStorageType(I8PackType) => Some(0xFF)
    PackTypeStorageType(I16PackType) => Some(0xFFFF)
    _ => None
  }
}

///|
fn h2l_pack_for_store(value : TInstr, field : FieldType) -> TInstr {
  match h2l_pack_mask(field) {
    Some(mask) =>
      TInstr::binary(BinaryOp::i32_and(), value, TInstr::i32_const(I32(mask)))
    None => value
  }
}

///|
fn h2l_unpack_from_slot(
  value : TInstr,
  field : FieldType,
  signed : Bool,
) -> TInstr {
  match field.get_storage_type() {
    PackTypeStorageType(I8PackType) =>
      if signed {
        TInstr::unary(UnaryOp::i32_extend8s(), value)
      } else {
        TInstr::binary(BinaryOp::i32_and(), value, TInstr::i32_const(I32(0xFF)))
      }
    PackTypeStorageType(I16PackType) =>
      if signed {
        TInstr::unary(UnaryOp::i32_extend16s(), value)
      } else {
        TInstr::binary(
          BinaryOp::i32_and(),
          value,
          TInstr::i32_const(I32(0xFFFF)),
        )
      }
    _ => value
  }
}

///|
fn h2l_extract_shape(env : Env, value : TInstr) -> H2LShape? {
  match value {
    TStructNew(type_idx, _) | TStructNewDefault(type_idx) =>
      match env.resolve_struct_fields(type_idx) {
        Ok(fields) => {
          for field in fields {
            if !h2l_field_has_local_representation(field) {
              return None
            }
          }
          Some(StructShape(type_idx, fields))
        }
        Err(_) => None
      }
    TArrayNew(type_idx, _, len) | TArrayNewDefault(type_idx, len) =>
      match (env.resolve_array_field(type_idx), h2l_const_i32_nonneg(len)) {
        (Ok(field), Some(size)) =>
          if h2l_field_has_local_representation(field) &&
            h2l_is_valid_array_size(size) {
            Some(ArrayShape(type_idx, field, size))
          } else {
            None
          }
        _ => None
      }
    TArrayNewFixed(type_idx, values) =>
      match env.resolve_array_field(type_idx) {
        Ok(field) => {
          let size = values.length()
          if h2l_field_has_local_representation(field) &&
            h2l_is_valid_array_size(size) {
            Some(ArrayShape(type_idx, field, size))
          } else {
            None
          }
        }
        Err(_) => None
      }
    TArrayNewData(type_idx, _, offset, len) =>
      match
        (
          env.resolve_array_field(type_idx),
          h2l_const_i32_nonneg(offset),
          h2l_const_i32_nonneg(len),
        ) {
        (Ok(field), Some(_), Some(size)) =>
          if h2l_field_has_local_representation(field) &&
            h2l_is_valid_array_size(size) {
            Some(ArrayShape(type_idx, field, size))
          } else {
            None
          }
        _ => None
      }
    TArrayNewElem(type_idx, _, offset, len) =>
      match
        (
          env.resolve_array_field(type_idx),
          h2l_const_i32_nonneg(offset),
          h2l_const_i32_nonneg(len),
        ) {
        (Ok(field), Some(_), Some(size)) =>
          if h2l_field_has_local_representation(field) &&
            h2l_is_valid_array_size(size) {
            Some(ArrayShape(type_idx, field, size))
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn h2l_note_set_shape(
  state : H2LAnalyzeState,
  idx : Int,
  shape : H2LShape,
) -> Unit {
  if state.invalid.contains(idx) {
    return
  }
  match state.shapes.get(idx) {
    Some(existing) => if existing != shape { h2l_mark_invalid(state, idx) }
    None => state.shapes[idx] = shape
  }
}

///|
fn h2l_scan_body(env : Env, body : TExpr) -> H2LAnalyzeState {
  let state : H2LAnalyzeState = {
    env,
    shapes: Map::new(),
    invalid: Map::new(),
    set_counts: Map::new(),
    total_get_counts: Map::new(),
    safe_get_counts: Map::new(),
    uses: Map::new(),
    has_sync_atomic: false,
  }
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    s : H2LAnalyzeState,
    instr : TInstr,
  ) {
    match instr {
      TLoad(op, _, _) => if h2l_load_is_atomic(op) { s.has_sync_atomic = true }
      TStore(op, _, _, _) =>
        if h2l_store_is_atomic(op) {
          s.has_sync_atomic = true
        }
      TMemoryAtomicNotify(_, _, _)
      | TMemoryAtomicWait32(_, _, _, _)
      | TMemoryAtomicWait64(_, _, _, _)
      | TAtomicFence
      | TAtomicRmw(_, _, _, _)
      | TAtomicCmpxchg(_, _, _, _, _) => s.has_sync_atomic = true
      TLocalSet(loc, value) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.set_counts, idx)
        match h2l_extract_shape(s.env, value) {
          Some(shape) => h2l_note_set_shape(s, idx, shape)
          None => h2l_mark_invalid(s, idx)
        }
      }
      TLocalTee(loc, _) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.set_counts, idx)
        h2l_mark_invalid(s, idx)
      }
      TLocalGet(loc) => h2l_inc_count(s.total_get_counts, h2l_local_to_int(loc))
      TStructGet(type_idx, field_idx, TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::StructGet(type_idx, field_idx))
      }
      TStructGet(type_idx, field_idx, TRefAsNonNull(TLocalGet(loc))) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::StructGet(type_idx, field_idx))
      }
      TStructGetS(type_idx, field_idx, TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::StructGetS(type_idx, field_idx))
      }
      TStructGetS(type_idx, field_idx, TRefAsNonNull(TLocalGet(loc))) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::StructGetS(type_idx, field_idx))
      }
      TStructGetU(type_idx, field_idx, TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::StructGetU(type_idx, field_idx))
      }
      TStructGetU(type_idx, field_idx, TRefAsNonNull(TLocalGet(loc))) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::StructGetU(type_idx, field_idx))
      }
      TStructSet(type_idx, field_idx, TLocalGet(loc), _) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::StructSet(type_idx, field_idx))
      }
      TStructSet(type_idx, field_idx, TRefAsNonNull(TLocalGet(loc)), _) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::StructSet(type_idx, field_idx))
      }
      TArrayGet(type_idx, TLocalGet(loc), index) =>
        match h2l_const_i32_nonneg(index) {
          Some(i) => {
            let idx = h2l_local_to_int(loc)
            h2l_inc_count(s.safe_get_counts, idx)
            h2l_add_use(s.uses, idx, H2LUse::ArrayGet(type_idx, i))
          }
          None => ()
        }
      TArrayGet(type_idx, TRefAsNonNull(TLocalGet(loc)), index) =>
        match h2l_const_i32_nonneg(index) {
          Some(i) => {
            let idx = h2l_local_to_int(loc)
            h2l_inc_count(s.safe_get_counts, idx)
            h2l_add_use(s.uses, idx, H2LUse::ArrayGet(type_idx, i))
          }
          None => ()
        }
      TArrayGetS(type_idx, TLocalGet(loc), index) =>
        match h2l_const_i32_nonneg(index) {
          Some(i) => {
            let idx = h2l_local_to_int(loc)
            h2l_inc_count(s.safe_get_counts, idx)
            h2l_add_use(s.uses, idx, H2LUse::ArrayGetS(type_idx, i))
          }
          None => ()
        }
      TArrayGetS(type_idx, TRefAsNonNull(TLocalGet(loc)), index) =>
        match h2l_const_i32_nonneg(index) {
          Some(i) => {
            let idx = h2l_local_to_int(loc)
            h2l_inc_count(s.safe_get_counts, idx)
            h2l_add_use(s.uses, idx, H2LUse::ArrayGetS(type_idx, i))
          }
          None => ()
        }
      TArrayGetU(type_idx, TLocalGet(loc), index) =>
        match h2l_const_i32_nonneg(index) {
          Some(i) => {
            let idx = h2l_local_to_int(loc)
            h2l_inc_count(s.safe_get_counts, idx)
            h2l_add_use(s.uses, idx, H2LUse::ArrayGetU(type_idx, i))
          }
          None => ()
        }
      TArrayGetU(type_idx, TRefAsNonNull(TLocalGet(loc)), index) =>
        match h2l_const_i32_nonneg(index) {
          Some(i) => {
            let idx = h2l_local_to_int(loc)
            h2l_inc_count(s.safe_get_counts, idx)
            h2l_add_use(s.uses, idx, H2LUse::ArrayGetU(type_idx, i))
          }
          None => ()
        }
      TArraySet(type_idx, TLocalGet(loc), index, _) =>
        match h2l_const_i32_nonneg(index) {
          Some(i) => {
            let idx = h2l_local_to_int(loc)
            h2l_inc_count(s.safe_get_counts, idx)
            h2l_add_use(s.uses, idx, H2LUse::ArraySet(type_idx, i))
          }
          None => ()
        }
      TArraySet(type_idx, TRefAsNonNull(TLocalGet(loc)), index, _) =>
        match h2l_const_i32_nonneg(index) {
          Some(i) => {
            let idx = h2l_local_to_int(loc)
            h2l_inc_count(s.safe_get_counts, idx)
            h2l_add_use(s.uses, idx, H2LUse::ArraySet(type_idx, i))
          }
          None => ()
        }
      TArrayLen(TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::ArrayLen)
      }
      TArrayLen(TRefAsNonNull(TLocalGet(loc))) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::ArrayLen)
      }
      TDrop(TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::DropOnly)
      }
      TDrop(TRefAsNonNull(TLocalGet(loc))) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::DropOnly)
      }
      TRefIsNull(TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefIsNull)
      }
      TRefIsNull(TRefAsNonNull(TLocalGet(loc))) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefIsNull)
      }
      TRefTest(_, _, TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefTest)
      }
      TRefGetDesc(TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefGetDesc)
      }
      TRefGetDesc(TRefAsNonNull(TLocalGet(loc))) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefGetDesc)
      }
      TRefTestDesc(_, _, TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefTestDesc)
      }
      TRefTestDesc(_, _, TRefAsNonNull(TLocalGet(loc))) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefTestDesc)
      }
      TRefCastDescEq(_, _, TLocalGet(loc)) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefCastDescEq)
      }
      TRefCastDescEq(_, _, TRefAsNonNull(TLocalGet(loc))) => {
        let idx = h2l_local_to_int(loc)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefCastDescEq)
      }
      TRefEq(TLocalGet(left), right) => {
        let idx = h2l_local_to_int(left)
        h2l_inc_count(s.safe_get_counts, idx)
        h2l_add_use(s.uses, idx, H2LUse::RefEq)
        match right {
          TLocalGet(right_loc) => {
            let right_idx = h2l_local_to_int(right_loc)
            h2l_inc_count(s.safe_get_counts, right_idx)
            h2l_add_use(s.uses, right_idx, H2LUse::RefEq)
          }
          _ => ()
        }
      }
      TRefEq(left, TLocalGet(right)) =>
        match left {
          TLocalGet(_) => ()
          _ => {
            let idx = h2l_local_to_int(right)
            h2l_inc_count(s.safe_get_counts, idx)
            h2l_add_use(s.uses, idx, H2LUse::RefEq)
          }
        }
      _ => ()
    }
    self.walk_tinstruction_default(s, instr)
  })
  match walker.walk_texpr(state, body) {
    Ok(Some((out, _))) => out
    Ok(None) => state
    Err(_) => state
  }
}

///|
fn h2l_shape_slots_valtypes(shape : H2LShape) -> Array[ValType] {
  match shape {
    StructShape(_, fields) => {
      let out : Array[ValType] = []
      for field in fields {
        out.push(field.unpack())
      }
      out
    }
    ArrayShape(_, field, size) => {
      let out : Array[ValType] = []
      for _ in 0..<size {
        out.push(field.unpack())
      }
      out
    }
  }
}

///|
fn h2l_uses_compatible(shape : H2LShape, uses : Array[H2LUse]) -> Bool {
  match shape {
    StructShape(type_idx, fields) => {
      for use_kind in uses {
        match use_kind {
          H2LUse::StructGet(used_type, field_idx)
          | H2LUse::StructGetS(used_type, field_idx)
          | H2LUse::StructGetU(used_type, field_idx)
          | H2LUse::StructSet(used_type, field_idx) => {
            if used_type != type_idx {
              return false
            }
            let idx = h2l_u32_to_int(field_idx)
            if idx < 0 || idx >= fields.length() {
              return false
            }
          }
          H2LUse::RefIsNull
          | H2LUse::RefEq
          | H2LUse::RefTest
          | H2LUse::RefGetDesc
          | H2LUse::RefTestDesc
          | H2LUse::RefCastDescEq => ()
          H2LUse::DropOnly => ()
          _ => return false
        }
      }
      true
    }
    ArrayShape(type_idx, _, _) => {
      for use_kind in uses {
        match use_kind {
          H2LUse::ArrayGet(used_type, idx)
          | H2LUse::ArrayGetS(used_type, idx)
          | H2LUse::ArrayGetU(used_type, idx)
          | H2LUse::ArraySet(used_type, idx) =>
            if used_type != type_idx || idx < 0 {
              return false
            }
          H2LUse::ArrayLen
          | H2LUse::RefIsNull
          | H2LUse::RefTest
          | H2LUse::RefGetDesc
          | H2LUse::RefTestDesc
          | H2LUse::RefCastDescEq
          | H2LUse::RefEq
          | H2LUse::DropOnly => ()
          _ => return false
        }
      }
      true
    }
  }
}

///|
fn h2l_collect_candidates(analysis : H2LAnalyzeState) -> Map[Int, H2LShape] {
  let out : Map[Int, H2LShape] = Map::new()
  if analysis.has_sync_atomic {
    return out
  }
  for entry in analysis.shapes {
    let (loc, shape) = entry
    if analysis.invalid.contains(loc) {
      continue
    }
    if analysis.set_counts.get(loc).unwrap_or(0) == 0 {
      continue
    }
    let total_gets = analysis.total_get_counts.get(loc).unwrap_or(0)
    let safe_gets = analysis.safe_get_counts.get(loc).unwrap_or(0)
    if total_gets != safe_gets {
      continue
    }
    let uses = analysis.uses.get(loc).unwrap_or([])
    if !h2l_uses_compatible(shape, uses) {
      continue
    }
    out[loc] = shape
  }
  out
}

///|
fn h2l_flatten_instrs(instrs : Array[TInstr]) -> Array[TInstr] {
  let out : Array[TInstr] = []
  for instr in instrs {
    match instr {
      TIf(bt, cond, then_expr, else_expr) => {
        out.push(TInstr::if_(bt, cond, TExpr::new([]), None))
        for child in h2l_flatten_instrs(then_expr.instrs) {
          out.push(child)
        }
        if else_expr is Some(e) {
          for child in h2l_flatten_instrs(e.instrs) {
            out.push(child)
          }
        }
      }
      _ => out.push(instr)
    }
  }
  out
}

///|
fn h2l_local_graph_get_order(body : TExpr) -> Array[LocalIdx] {
  let out : Array[LocalIdx] = []
  let flat = h2l_flatten_instrs(body.instrs)
  for instr in flat {
    let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
      self,
      _,
      curr,
    ) {
      match curr {
        TLocalGet(idx) => out.push(idx)
        _ => ()
      }
      self.walk_tinstruction_default((), curr)
    })
    ignore(walker.walk_texpr((), TExpr::new([instr])))
  }
  out
}

///|
fn h2l_shape_matches_allocation_value(
  env : Env,
  shape : H2LShape,
  value : TInstr,
) -> Bool {
  match h2l_extract_shape(env, value) {
    Some(found) => found == shape
    None => false
  }
}

///|
fn h2l_root_has_matching_set(
  env : Env,
  root : TInstr,
  target : LocalIdx,
  shape : H2LShape,
) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalSet(idx, value) =>
        if idx == target &&
          h2l_shape_matches_allocation_value(env, shape, value) {
          found.update(fn(_) { true })
        }
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), TExpr::new([root])))
  found.val
}

///|
fn h2l_filter_by_local_graph(
  env : Env,
  body : TExpr,
  graph : LocalGraph,
  candidates : Map[Int, H2LShape],
) -> Map[Int, H2LShape] {
  let out : Map[Int, H2LShape] = Map::new()
  let get_order = h2l_local_graph_get_order(body)
  for entry in candidates {
    let (loc, shape) = entry
    let target = LocalIdx::new(loc.reinterpret_as_uint())
    let mut ok = true
    for get_id in 0..<get_order.length() {
      if get_order[get_id] != target {
        continue
      }
      let sets = graph.get_sets(get_id)
      if sets.is_empty() {
        ok = false
        break
      }
      for set_src in sets {
        match set_src {
          LocalSet::InitValue => {
            ok = false
            break
          }
          LocalSet::Set(set_loc, root) =>
            if set_loc != target ||
              !h2l_root_has_matching_set(env, root, target, shape) {
              ok = false
              break
            }
        }
      }
      if !ok {
        break
      }
    }
    if ok {
      out[loc] = shape
    }
  }
  out
}

///|
fn h2l_texpr_has_local_set(expr : TExpr, target : LocalIdx) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalSet(idx, _) if idx == target => found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), expr))
  found.val
}

///|
fn h2l_has_nonuniform_if_set(expr : TExpr, target : LocalIdx) -> Bool {
  for instr in expr.instrs {
    match instr {
      TIf(_, _, then_expr, else_expr) => {
        let then_has = h2l_texpr_has_local_set(then_expr, target)
        let else_has = match else_expr {
          Some(e) => h2l_texpr_has_local_set(e, target)
          None => false
        }
        if then_has != else_has && (then_has || else_has) {
          return true
        }
        if h2l_has_nonuniform_if_set(then_expr, target) {
          return true
        }
        if else_expr is Some(e) && h2l_has_nonuniform_if_set(e, target) {
          return true
        }
      }
      TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
        if h2l_has_nonuniform_if_set(body, target) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn h2l_filter_nonuniform_if_sets(
  body : TExpr,
  candidates : Map[Int, H2LShape],
) -> Map[Int, H2LShape] {
  let out : Map[Int, H2LShape] = Map::new()
  for entry in candidates {
    let (loc, shape) = entry
    let target = LocalIdx::new(loc.reinterpret_as_uint())
    if !h2l_has_nonuniform_if_set(body, target) {
      out[loc] = shape
    }
  }
  out
}

///|
fn h2l_instr_transfers_control_flow(instr : TInstr) -> Bool {
  let transfers = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TBr(_, _)
      | TBrIf(_, _, _)
      | TBrTable(_, _, _, _)
      | TBrOnNull(_, _, _)
      | TBrOnNonNull(_, _, _)
      | TBrOnCast(_, _, _, _, _, _)
      | TBrOnCastFail(_, _, _, _, _, _)
      | TReturn(_)
      | TThrow(_, _)
      | TThrowRef(_)
      | TReturnCall(_, _)
      | TReturnCallIndirect(_, _, _, _)
      | TReturnCallRef(_, _, _) => transfers.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), TExpr::new([instr])))
  transfers.val
}

///|
fn h2l_tinstr_has_local_get_for(instr : TInstr, target : LocalIdx) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalGet(idx) if idx == target => found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), TExpr::new([instr])))
  found.val
}

///|
fn h2l_tinstr_has_branchy_set_for(
  instr : TInstr,
  target : LocalIdx,
  shape : H2LShape,
  env : Env,
) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, curr) {
    match curr {
      TLocalSet(idx, value) =>
        if idx == target &&
          h2l_shape_matches_allocation_value(env, shape, value) &&
          h2l_instr_transfers_control_flow(value) {
          found.update(fn(_) { true })
        }
      _ => ()
    }
    self.walk_tinstruction_default((), curr)
  })
  ignore(walker.walk_texpr((), TExpr::new([instr])))
  found.val
}

///|
fn h2l_filter_branchy_sets(
  env : Env,
  body : TExpr,
  candidates : Map[Int, H2LShape],
) -> Map[Int, H2LShape] {
  let out : Map[Int, H2LShape] = Map::new()
  let flat = h2l_flatten_instrs(body.instrs)
  for entry in candidates {
    let (loc, shape) = entry
    let target = LocalIdx::new(loc.reinterpret_as_uint())
    let mut seen_branchy_set = false
    let mut ok = true
    for instr in flat {
      if h2l_tinstr_has_branchy_set_for(instr, target, shape, env) {
        seen_branchy_set = true
      }
      if seen_branchy_set && h2l_tinstr_has_local_get_for(instr, target) {
        ok = false
        break
      }
    }
    if ok {
      out[loc] = shape
    }
  }
  out
}

///|
fn h2l_default_tinstr(vt : ValType) -> TInstr? {
  match vt {
    NumTypeValType(nt) =>
      match nt {
        I32NumType => Some(TInstr::i32_const(I32(0)))
        I64NumType => Some(TInstr::i64_const(I64(0L)))
        F32NumType => Some(TInstr::f32_const(F32(0.0)))
        F64NumType => Some(TInstr::f64_const(F64(0.0)))
      }
    VecTypeValType =>
      Some(TInstr::v128_const(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    RefTypeValType(rt) =>
      if rt.is_nullable() {
        Some(TInstr::ref_null(rt.get_heap_type()))
      } else {
        None
      }
    BotValType => None
  }
}

///|
fn h2l_shape_heap_type(shape : H2LShape) -> HeapType {
  match shape {
    StructShape(type_idx, _) | ArrayShape(type_idx, _, _) =>
      HeapType::new(type_idx)
  }
}

///|
fn h2l_is_exact_descriptor_target(shape : H2LShape, target : HeapType) -> Bool {
  h2l_shape_heap_type(shape) == target
}

///|
fn h2l_is_indexed_heap_subtype(
  env : Env,
  sub : TypeIdx,
  target : TypeIdx,
) -> Bool {
  if sub == target {
    return true
  }
  match env.resolve_subtype(sub) {
    Some(st) => {
      for super_idx in st.super_types() {
        if h2l_is_indexed_heap_subtype(env, super_idx, target) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn h2l_is_heap_subtype(env : Env, sub : HeapType, target : HeapType) -> Bool {
  if sub == target {
    return true
  }
  match target {
    AbsHeapTypeHeapType(AnyAbsHeapType) => true
    AbsHeapTypeHeapType(EqAbsHeapType) => sub.is_gc_aggregate()
    AbsHeapTypeHeapType(StructAbsHeapType) => sub.is_struct()
    AbsHeapTypeHeapType(ArrayAbsHeapType) => sub.is_array()
    AbsHeapTypeHeapType(_) => false
    HeapType(target_idx) =>
      match sub {
        HeapType(sub_idx) =>
          h2l_is_indexed_heap_subtype(env, sub_idx, target_idx)
        _ => false
      }
    DefTypeHeapType(_) => false
  }
}

///|
priv enum H2LArrayInitResult {
  Init(Array[TInstr])
  Trap
}

///|
fn h2l_data_idx_to_int(idx : DataIdx) -> Int {
  let DataIdx(i) = idx
  i.reinterpret_as_int()
}

///|
fn h2l_read_u32_le(bytes : Bytes, at : Int) -> UInt {
  bytes[at].to_uint() |
  (bytes[at + 1].to_uint() << 8) |
  (bytes[at + 2].to_uint() << 16) |
  (bytes[at + 3].to_uint() << 24)
}

///|
fn h2l_read_u64_le(bytes : Bytes, at : Int) -> UInt64 {
  bytes[at].to_uint64() |
  (bytes[at + 1].to_uint64() << 8) |
  (bytes[at + 2].to_uint64() << 16) |
  (bytes[at + 3].to_uint64() << 24) |
  (bytes[at + 4].to_uint64() << 32) |
  (bytes[at + 5].to_uint64() << 40) |
  (bytes[at + 6].to_uint64() << 48) |
  (bytes[at + 7].to_uint64() << 56)
}

///|
fn h2l_array_new_data_init(
  mod : Module,
  field : FieldType,
  data_idx : DataIdx,
  offset : Int,
  len : Int,
) -> H2LArrayInitResult? {
  let bytes = match mod.data_sec {
    Some(DataSec(datas)) =>
      match datas.get(h2l_data_idx_to_int(data_idx)) {
        Some(Data(_, content)) => content
        None => return None
      }
    None => return None
  }
  let width = match field.get_storage_type() {
    PackTypeStorageType(I8PackType) => 1
    PackTypeStorageType(I16PackType) => 2
    ValTypeStorageType(vt) =>
      match vt {
        NumTypeValType(I32NumType) => 4
        NumTypeValType(I64NumType) => 8
        NumTypeValType(F32NumType) => 4
        NumTypeValType(F64NumType) => 8
        _ => return None
      }
  }
  if offset < 0 || len < 0 {
    return None
  }
  let end = offset + len * width
  if end > bytes.length() {
    return Some(H2LArrayInitResult::Trap)
  }
  let out : Array[TInstr] = []
  for i in 0..<len {
    let at = offset + i * width
    match field.get_storage_type() {
      PackTypeStorageType(I8PackType) =>
        out.push(TInstr::i32_const(I32(bytes[at].to_int())))
      PackTypeStorageType(I16PackType) =>
        out.push(
          TInstr::i32_const(
            I32(bytes[at].to_int() | (bytes[at + 1].to_int() << 8)),
          ),
        )
      ValTypeStorageType(vt) =>
        match vt {
          NumTypeValType(I32NumType) =>
            out.push(
              TInstr::i32_const(
                I32(h2l_read_u32_le(bytes, at).reinterpret_as_int()),
              ),
            )
          NumTypeValType(I64NumType) =>
            out.push(
              TInstr::i64_const(
                I64(h2l_read_u64_le(bytes, at).reinterpret_as_int64()),
              ),
            )
          NumTypeValType(F32NumType) =>
            out.push(
              TInstr::f32_const(
                F32(Float::reinterpret_from_uint(h2l_read_u32_le(bytes, at))),
              ),
            )
          NumTypeValType(F64NumType) =>
            out.push(
              TInstr::f64_const(
                F64(h2l_read_u64_le(bytes, at).reinterpret_as_double()),
              ),
            )
          _ => return None
        }
    }
  }
  Some(H2LArrayInitResult::Init(out))
}

///|
fn h2l_const_expr_to_tinstr(expr : Expr, env : Env) -> TInstr? {
  match to_texpr(expr, env) {
    Ok({ instrs, .. }) =>
      if instrs.length() == 1 {
        match instrs[0] {
          TRefNull(_) | TRefFunc(_) => Some(instrs[0])
          _ => None
        }
      } else {
        None
      }
    Err(_) => None
  }
}

///|
fn h2l_array_new_elem_init(
  env : Env,
  elem_idx : ElemIdx,
  offset : Int,
  len : Int,
) -> H2LArrayInitResult? {
  if offset < 0 || len < 0 {
    return None
  }
  let values = match env.get_elem(elem_idx) {
    Some(Elem(_, kind)) =>
      match kind {
        FuncsElemKind(funcs) => {
          let out : Array[TInstr] = []
          for fi in funcs {
            out.push(TInstr::ref_func(fi))
          }
          out
        }
        FuncExprsElemKind(exprs) => {
          let out : Array[TInstr] = []
          for expr in exprs {
            match h2l_const_expr_to_tinstr(expr, env) {
              Some(value) => out.push(value)
              None => return None
            }
          }
          out
        }
        TypedExprsElemKind(_, exprs) => {
          let out : Array[TInstr] = []
          for expr in exprs {
            match h2l_const_expr_to_tinstr(expr, env) {
              Some(value) => out.push(value)
              None => return None
            }
          }
          out
        }
      }
    None => return None
  }
  let end = offset + len
  if end > values.length() {
    return Some(H2LArrayInitResult::Trap)
  }
  let out : Array[TInstr] = []
  for i in offset..<end {
    out.push(values[i])
  }
  Some(H2LArrayInitResult::Init(out))
}

///|
fn h2l_new_state(
  locals : Array[ValType],
  candidates : Map[Int, H2LShape],
) -> H2LRewriteState {
  let plans : Map[Int, H2LPlan] = Map::new()
  let new_locals : Array[ValType] = []
  for entry in candidates {
    let (loc, shape) = entry
    let slots : Array[LocalIdx] = []
    for vt in h2l_shape_slots_valtypes(shape) {
      let idx = locals.length() + new_locals.length()
      slots.push(LocalIdx::new(idx.reinterpret_as_uint()))
      new_locals.push(vt)
    }
    plans[loc] = { shape, slots }
  }
  { plans, base_local_count: locals.length(), new_locals }
}

///|
fn h2l_alloc_temp(state : H2LRewriteState, ty : ValType) -> LocalIdx {
  let idx = state.base_local_count + state.new_locals.length()
  state.new_locals.push(ty)
  LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn h2l_plan_for(state : H2LRewriteState, loc : LocalIdx) -> H2LPlan? {
  state.plans.get(h2l_local_to_int(loc))
}

///|
fn h2l_void_block(instrs : Array[TInstr]) -> TInstr {
  if instrs.is_empty() {
    TInstr::nop()
  } else {
    TInstr::block(BlockType::void_(), TExpr::new(instrs))
  }
}

///|
fn h2l_materialize_plan_ref(plan : H2LPlan) -> TInstr {
  match plan.shape {
    StructShape(type_idx, fields) => {
      let operands : Array[TInstr] = []
      for i in 0..<fields.length() {
        operands.push(TInstr::local_get(plan.slots[i]))
      }
      TInstr::struct_new(type_idx, operands)
    }
    ArrayShape(type_idx, _, size) => {
      let values : Array[TInstr] = []
      for i in 0..<size {
        values.push(TInstr::local_get(plan.slots[i]))
      }
      TInstr::array_new_fixed(type_idx, values)
    }
  }
}

///|
fn h2l_rewrite_struct_local_set(
  state : H2LRewriteState,
  plan : H2LPlan,
  type_idx : TypeIdx,
  value : TInstr,
) -> (H2LRewriteState, TInstr)? {
  let slots = plan.slots
  match plan.shape {
    StructShape(shape_type_idx, fields) => {
      if shape_type_idx != type_idx || fields.length() != slots.length() {
        return None
      }
      let slot_types = h2l_shape_slots_valtypes(plan.shape)
      let out : Array[TInstr] = []
      match value {
        TStructNew(set_type_idx, operands) => {
          if set_type_idx != shape_type_idx ||
            operands.length() != slots.length() {
            return None
          }
          let temps : Array[LocalIdx] = []
          for i in 0..<operands.length() {
            let temp = h2l_alloc_temp(state, slot_types[i])
            temps.push(temp)
            out.push(TInstr::local_set(temp, operands[i]))
          }
          for i in 0..<slots.length() {
            out.push(
              TInstr::local_set(
                slots[i],
                h2l_pack_for_store(TInstr::local_get(temps[i]), fields[i]),
              ),
            )
          }
          Some((state, h2l_void_block(out)))
        }
        TStructNewDefault(set_type_idx) => {
          if set_type_idx != shape_type_idx {
            return None
          }
          for i in 0..<slots.length() {
            match h2l_default_tinstr(slot_types[i]) {
              Some(default_value) =>
                out.push(TInstr::local_set(slots[i], default_value))
              None => return None
            }
          }
          Some((state, h2l_void_block(out)))
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn h2l_rewrite_array_local_set(
  state : H2LRewriteState,
  plan : H2LPlan,
  env : Env,
  mod : Module,
  type_idx : TypeIdx,
  value : TInstr,
) -> (H2LRewriteState, TInstr)? {
  match plan.shape {
    ArrayShape(shape_type_idx, field, size) => {
      if shape_type_idx != type_idx || plan.slots.length() != size {
        return None
      }
      let elem_ty = field.unpack()
      let out : Array[TInstr] = []
      match value {
        TArrayNew(set_type_idx, init, len) => {
          if set_type_idx != shape_type_idx {
            return None
          }
          if h2l_const_i32_nonneg(len) != Some(size) {
            return None
          }
          let temp = h2l_alloc_temp(state, elem_ty)
          out.push(TInstr::local_set(temp, init))
          for slot in plan.slots {
            out.push(
              TInstr::local_set(
                slot,
                h2l_pack_for_store(TInstr::local_get(temp), field),
              ),
            )
          }
          Some((state, h2l_void_block(out)))
        }
        TArrayNewDefault(set_type_idx, len) => {
          if set_type_idx != shape_type_idx {
            return None
          }
          if h2l_const_i32_nonneg(len) != Some(size) {
            return None
          }
          match h2l_default_tinstr(elem_ty) {
            Some(default_value) => {
              for slot in plan.slots {
                out.push(TInstr::local_set(slot, default_value))
              }
              Some((state, h2l_void_block(out)))
            }
            None => None
          }
        }
        TArrayNewFixed(set_type_idx, values) => {
          if set_type_idx != shape_type_idx || values.length() != size {
            return None
          }
          let temps : Array[LocalIdx] = []
          for value in values {
            let temp = h2l_alloc_temp(state, elem_ty)
            temps.push(temp)
            out.push(TInstr::local_set(temp, value))
          }
          for i in 0..<plan.slots.length() {
            out.push(
              TInstr::local_set(
                plan.slots[i],
                h2l_pack_for_store(TInstr::local_get(temps[i]), field),
              ),
            )
          }
          Some((state, h2l_void_block(out)))
        }
        TArrayNewData(set_type_idx, data_idx, offset, len) => {
          if set_type_idx != shape_type_idx {
            return None
          }
          let offset_val = match h2l_const_i32_nonneg(offset) {
            Some(v) => v
            None => return None
          }
          if h2l_const_i32_nonneg(len) != Some(size) {
            return None
          }
          match
            h2l_array_new_data_init(mod, field, data_idx, offset_val, size) {
            Some(H2LArrayInitResult::Trap) =>
              Some((state, TInstr::unreachable_()))
            Some(H2LArrayInitResult::Init(values)) => {
              if values.length() != size {
                return None
              }
              for i in 0..<plan.slots.length() {
                out.push(
                  TInstr::local_set(
                    plan.slots[i],
                    h2l_pack_for_store(values[i], field),
                  ),
                )
              }
              Some((state, h2l_void_block(out)))
            }
            None => None
          }
        }
        TArrayNewElem(set_type_idx, elem_idx, offset, len) => {
          if set_type_idx != shape_type_idx {
            return None
          }
          let offset_val = match h2l_const_i32_nonneg(offset) {
            Some(v) => v
            None => return None
          }
          if h2l_const_i32_nonneg(len) != Some(size) {
            return None
          }
          match h2l_array_new_elem_init(env, elem_idx, offset_val, size) {
            Some(H2LArrayInitResult::Trap) =>
              Some((state, TInstr::unreachable_()))
            Some(H2LArrayInitResult::Init(values)) => {
              if values.length() != size {
                return None
              }
              for i in 0..<plan.slots.length() {
                out.push(TInstr::local_set(plan.slots[i], values[i]))
              }
              Some((state, h2l_void_block(out)))
            }
            None => None
          }
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn h2l_rewrite_tinstr(
  transformer : ModuleTransformer[H2LRewriteState],
  state : H2LRewriteState,
  env : Env,
  mod : Module,
  instr : TInstr,
) -> TransformerResult[H2LRewriteState, TInstr] {
  let (state_after_walk, walked, walked_changed) = match
    transformer.walk_tinstruction_default(state, instr) {
    Ok(Some((next_state, next_instr))) => (next_state, next_instr, true)
    Ok(None) => (state, instr, false)
    Err(e) => return Err(e)
  }
  match walked {
    TLocalSet(loc, value) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            StructShape(type_idx, _) =>
              match
                h2l_rewrite_struct_local_set(
                  state_after_walk, plan, type_idx, value,
                ) {
                Some((next_state, rewritten)) => change(next_state, rewritten)
                None =>
                  if walked_changed {
                    change(state_after_walk, walked)
                  } else {
                    unchanged()
                  }
              }
            ArrayShape(type_idx, _, _) =>
              match
                h2l_rewrite_array_local_set(
                  state_after_walk, plan, env, mod, type_idx, value,
                ) {
                Some((next_state, rewritten)) => change(next_state, rewritten)
                None =>
                  if walked_changed {
                    change(state_after_walk, walked)
                  } else {
                    unchanged()
                  }
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TStructGet(type_idx, field_idx, TLocalGet(loc)) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            StructShape(shape_type_idx, fields) =>
              if type_idx == shape_type_idx {
                let idx = h2l_u32_to_int(field_idx)
                if idx >= 0 && idx < fields.length() {
                  change(state_after_walk, TInstr::local_get(plan.slots[idx]))
                } else if walked_changed {
                  change(state_after_walk, walked)
                } else {
                  unchanged()
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TStructGet(type_idx, field_idx, TRefAsNonNull(TLocalGet(loc))) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            StructShape(shape_type_idx, fields) =>
              if type_idx == shape_type_idx {
                let idx = h2l_u32_to_int(field_idx)
                if idx >= 0 && idx < fields.length() {
                  change(state_after_walk, TInstr::local_get(plan.slots[idx]))
                } else if walked_changed {
                  change(state_after_walk, walked)
                } else {
                  unchanged()
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TStructGetS(type_idx, field_idx, TLocalGet(loc)) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            StructShape(shape_type_idx, fields) =>
              if type_idx == shape_type_idx {
                let idx = h2l_u32_to_int(field_idx)
                if idx >= 0 && idx < fields.length() {
                  change(
                    state_after_walk,
                    h2l_unpack_from_slot(
                      TInstr::local_get(plan.slots[idx]),
                      fields[idx],
                      true,
                    ),
                  )
                } else if walked_changed {
                  change(state_after_walk, walked)
                } else {
                  unchanged()
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TStructGetS(type_idx, field_idx, TRefAsNonNull(TLocalGet(loc))) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            StructShape(shape_type_idx, fields) =>
              if type_idx == shape_type_idx {
                let idx = h2l_u32_to_int(field_idx)
                if idx >= 0 && idx < fields.length() {
                  change(
                    state_after_walk,
                    h2l_unpack_from_slot(
                      TInstr::local_get(plan.slots[idx]),
                      fields[idx],
                      true,
                    ),
                  )
                } else if walked_changed {
                  change(state_after_walk, walked)
                } else {
                  unchanged()
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TStructGetU(type_idx, field_idx, TLocalGet(loc)) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            StructShape(shape_type_idx, fields) =>
              if type_idx == shape_type_idx {
                let idx = h2l_u32_to_int(field_idx)
                if idx >= 0 && idx < fields.length() {
                  change(
                    state_after_walk,
                    h2l_unpack_from_slot(
                      TInstr::local_get(plan.slots[idx]),
                      fields[idx],
                      false,
                    ),
                  )
                } else if walked_changed {
                  change(state_after_walk, walked)
                } else {
                  unchanged()
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TStructGetU(type_idx, field_idx, TRefAsNonNull(TLocalGet(loc))) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            StructShape(shape_type_idx, fields) =>
              if type_idx == shape_type_idx {
                let idx = h2l_u32_to_int(field_idx)
                if idx >= 0 && idx < fields.length() {
                  change(
                    state_after_walk,
                    h2l_unpack_from_slot(
                      TInstr::local_get(plan.slots[idx]),
                      fields[idx],
                      false,
                    ),
                  )
                } else if walked_changed {
                  change(state_after_walk, walked)
                } else {
                  unchanged()
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TStructSet(type_idx, field_idx, TLocalGet(loc), value) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            StructShape(shape_type_idx, fields) =>
              if type_idx == shape_type_idx {
                let idx = h2l_u32_to_int(field_idx)
                if idx >= 0 && idx < fields.length() {
                  change(
                    state_after_walk,
                    TInstr::local_set(
                      plan.slots[idx],
                      h2l_pack_for_store(value, fields[idx]),
                    ),
                  )
                } else if walked_changed {
                  change(state_after_walk, walked)
                } else {
                  unchanged()
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TStructSet(type_idx, field_idx, TRefAsNonNull(TLocalGet(loc)), value) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            StructShape(shape_type_idx, fields) =>
              if type_idx == shape_type_idx {
                let idx = h2l_u32_to_int(field_idx)
                if idx >= 0 && idx < fields.length() {
                  change(
                    state_after_walk,
                    TInstr::local_set(
                      plan.slots[idx],
                      h2l_pack_for_store(value, fields[idx]),
                    ),
                  )
                } else if walked_changed {
                  change(state_after_walk, walked)
                } else {
                  unchanged()
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArrayGet(type_idx, TLocalGet(loc), index) =>
      match (h2l_plan_for(state_after_walk, loc), h2l_const_i32_nonneg(index)) {
        (Some(plan), Some(idx)) =>
          match plan.shape {
            ArrayShape(shape_type_idx, _, size) =>
              if type_idx == shape_type_idx {
                if idx < size {
                  change(state_after_walk, TInstr::local_get(plan.slots[idx]))
                } else {
                  change(state_after_walk, TInstr::unreachable_())
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        _ =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArrayGet(type_idx, TRefAsNonNull(TLocalGet(loc)), index) =>
      match (h2l_plan_for(state_after_walk, loc), h2l_const_i32_nonneg(index)) {
        (Some(plan), Some(idx)) =>
          match plan.shape {
            ArrayShape(shape_type_idx, _, size) =>
              if type_idx == shape_type_idx {
                if idx < size {
                  change(state_after_walk, TInstr::local_get(plan.slots[idx]))
                } else {
                  change(state_after_walk, TInstr::unreachable_())
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        _ =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArrayGetS(type_idx, TLocalGet(loc), index) =>
      match (h2l_plan_for(state_after_walk, loc), h2l_const_i32_nonneg(index)) {
        (Some(plan), Some(idx)) =>
          match plan.shape {
            ArrayShape(shape_type_idx, field, size) =>
              if type_idx == shape_type_idx {
                if idx < size {
                  change(
                    state_after_walk,
                    h2l_unpack_from_slot(
                      TInstr::local_get(plan.slots[idx]),
                      field,
                      true,
                    ),
                  )
                } else {
                  change(state_after_walk, TInstr::unreachable_())
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        _ =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArrayGetS(type_idx, TRefAsNonNull(TLocalGet(loc)), index) =>
      match (h2l_plan_for(state_after_walk, loc), h2l_const_i32_nonneg(index)) {
        (Some(plan), Some(idx)) =>
          match plan.shape {
            ArrayShape(shape_type_idx, field, size) =>
              if type_idx == shape_type_idx {
                if idx < size {
                  change(
                    state_after_walk,
                    h2l_unpack_from_slot(
                      TInstr::local_get(plan.slots[idx]),
                      field,
                      true,
                    ),
                  )
                } else {
                  change(state_after_walk, TInstr::unreachable_())
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        _ =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArrayGetU(type_idx, TLocalGet(loc), index) =>
      match (h2l_plan_for(state_after_walk, loc), h2l_const_i32_nonneg(index)) {
        (Some(plan), Some(idx)) =>
          match plan.shape {
            ArrayShape(shape_type_idx, field, size) =>
              if type_idx == shape_type_idx {
                if idx < size {
                  change(
                    state_after_walk,
                    h2l_unpack_from_slot(
                      TInstr::local_get(plan.slots[idx]),
                      field,
                      false,
                    ),
                  )
                } else {
                  change(state_after_walk, TInstr::unreachable_())
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        _ =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArrayGetU(type_idx, TRefAsNonNull(TLocalGet(loc)), index) =>
      match (h2l_plan_for(state_after_walk, loc), h2l_const_i32_nonneg(index)) {
        (Some(plan), Some(idx)) =>
          match plan.shape {
            ArrayShape(shape_type_idx, field, size) =>
              if type_idx == shape_type_idx {
                if idx < size {
                  change(
                    state_after_walk,
                    h2l_unpack_from_slot(
                      TInstr::local_get(plan.slots[idx]),
                      field,
                      false,
                    ),
                  )
                } else {
                  change(state_after_walk, TInstr::unreachable_())
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        _ =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArraySet(type_idx, TLocalGet(loc), index, value) =>
      match (h2l_plan_for(state_after_walk, loc), h2l_const_i32_nonneg(index)) {
        (Some(plan), Some(idx)) =>
          match plan.shape {
            ArrayShape(shape_type_idx, field, size) =>
              if type_idx == shape_type_idx {
                if idx < size {
                  change(
                    state_after_walk,
                    TInstr::local_set(
                      plan.slots[idx],
                      h2l_pack_for_store(value, field),
                    ),
                  )
                } else {
                  change(
                    state_after_walk,
                    TInstr::block(
                      BlockType::void_(),
                      TExpr::new([TInstr::drop(value), TInstr::unreachable_()]),
                    ),
                  )
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        _ =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArraySet(type_idx, TRefAsNonNull(TLocalGet(loc)), index, value) =>
      match (h2l_plan_for(state_after_walk, loc), h2l_const_i32_nonneg(index)) {
        (Some(plan), Some(idx)) =>
          match plan.shape {
            ArrayShape(shape_type_idx, field, size) =>
              if type_idx == shape_type_idx {
                if idx < size {
                  change(
                    state_after_walk,
                    TInstr::local_set(
                      plan.slots[idx],
                      h2l_pack_for_store(value, field),
                    ),
                  )
                } else {
                  change(
                    state_after_walk,
                    TInstr::block(
                      BlockType::void_(),
                      TExpr::new([TInstr::drop(value), TInstr::unreachable_()]),
                    ),
                  )
                }
              } else if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        _ =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArrayLen(TLocalGet(loc)) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            ArrayShape(_, _, size) =>
              change(state_after_walk, TInstr::i32_const(I32(size)))
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TArrayLen(TRefAsNonNull(TLocalGet(loc))) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          match plan.shape {
            ArrayShape(_, _, size) =>
              change(state_after_walk, TInstr::i32_const(I32(size)))
            _ =>
              if walked_changed {
                change(state_after_walk, walked)
              } else {
                unchanged()
              }
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TDrop(TLocalGet(loc)) =>
      if h2l_plan_for(state_after_walk, loc) is Some(_) {
        change(state_after_walk, TInstr::nop())
      } else if walked_changed {
        change(state_after_walk, walked)
      } else {
        unchanged()
      }
    TDrop(TRefAsNonNull(TLocalGet(loc))) =>
      if h2l_plan_for(state_after_walk, loc) is Some(_) {
        change(state_after_walk, TInstr::nop())
      } else if walked_changed {
        change(state_after_walk, walked)
      } else {
        unchanged()
      }
    TRefIsNull(TLocalGet(loc)) =>
      if h2l_plan_for(state_after_walk, loc) is Some(_) {
        change(state_after_walk, TInstr::i32_const(I32(0)))
      } else if walked_changed {
        change(state_after_walk, walked)
      } else {
        unchanged()
      }
    TRefIsNull(TRefAsNonNull(TLocalGet(loc))) =>
      if h2l_plan_for(state_after_walk, loc) is Some(_) {
        change(state_after_walk, TInstr::i32_const(I32(0)))
      } else if walked_changed {
        change(state_after_walk, walked)
      } else {
        unchanged()
      }
    TRefGetDesc(TLocalGet(loc)) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          change(
            state_after_walk,
            TInstr::ref_get_desc(h2l_materialize_plan_ref(plan)),
          )
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TRefGetDesc(TRefAsNonNull(TLocalGet(loc))) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          change(
            state_after_walk,
            TInstr::ref_get_desc(h2l_materialize_plan_ref(plan)),
          )
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TRefTest(_, target_ht, TLocalGet(loc)) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          change(
            state_after_walk,
            TInstr::i32_const(
              I32(
                if h2l_is_heap_subtype(
                    env,
                    h2l_shape_heap_type(plan.shape),
                    target_ht,
                  ) {
                  1
                } else {
                  0
                },
              ),
            ),
          )
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TRefTest(_, target_ht, TRefAsNonNull(TLocalGet(loc))) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          change(
            state_after_walk,
            TInstr::i32_const(
              I32(
                if h2l_is_heap_subtype(
                    env,
                    h2l_shape_heap_type(plan.shape),
                    target_ht,
                  ) {
                  1
                } else {
                  0
                },
              ),
            ),
          )
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TRefTestDesc(_, target_ht, TLocalGet(loc)) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          change(
            state_after_walk,
            TInstr::i32_const(
              I32(
                if h2l_is_exact_descriptor_target(plan.shape, target_ht) {
                  1
                } else {
                  0
                },
              ),
            ),
          )
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TRefTestDesc(_, target_ht, TRefAsNonNull(TLocalGet(loc))) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          change(
            state_after_walk,
            TInstr::i32_const(
              I32(
                if h2l_is_exact_descriptor_target(plan.shape, target_ht) {
                  1
                } else {
                  0
                },
              ),
            ),
          )
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TRefCastDescEq(_, target_ht, TLocalGet(loc)) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          if h2l_is_exact_descriptor_target(plan.shape, target_ht) {
            change(state_after_walk, h2l_materialize_plan_ref(plan))
          } else {
            change(state_after_walk, TInstr::unreachable_())
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TRefCastDescEq(_, target_ht, TRefAsNonNull(TLocalGet(loc))) =>
      match h2l_plan_for(state_after_walk, loc) {
        Some(plan) =>
          if h2l_is_exact_descriptor_target(plan.shape, target_ht) {
            change(state_after_walk, h2l_materialize_plan_ref(plan))
          } else {
            change(state_after_walk, TInstr::unreachable_())
          }
        None =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TRefEq(TLocalGet(left), TLocalGet(right)) =>
      match
        (
          h2l_plan_for(state_after_walk, left),
          h2l_plan_for(state_after_walk, right),
        ) {
        (Some(_), Some(_)) =>
          if left == right {
            change(state_after_walk, TInstr::i32_const(I32(1)))
          } else {
            change(state_after_walk, TInstr::i32_const(I32(0)))
          }
        (Some(_), None) | (None, Some(_)) =>
          change(state_after_walk, TInstr::i32_const(I32(0)))
        _ =>
          if walked_changed {
            change(state_after_walk, walked)
          } else {
            unchanged()
          }
      }
    TRefEq(TLocalGet(left), right) =>
      if h2l_plan_for(state_after_walk, left) is Some(_) {
        change(
          state_after_walk,
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([TInstr::drop(right), TInstr::i32_const(I32(0))]),
          ),
        )
      } else if walked_changed {
        change(state_after_walk, walked)
      } else {
        unchanged()
      }
    TRefEq(left, TLocalGet(right)) =>
      if h2l_plan_for(state_after_walk, right) is Some(_) {
        change(
          state_after_walk,
          TInstr::block(
            BlockType::val_type(ValType::i32()),
            TExpr::new([TInstr::drop(left), TInstr::i32_const(I32(0))]),
          ),
        )
      } else if walked_changed {
        change(state_after_walk, walked)
      } else {
        unchanged()
      }
    _ =>
      if walked_changed {
        change(state_after_walk, walked)
      } else {
        unchanged()
      }
  }
}

///|
fn h2l_optimize_func_once(
  func : Func,
  env : Env,
  mod : Module,
  graph : LocalGraph?,
) -> Func? {
  match func {
    Func(_) => None
    TFunc(locals, body) => {
      let analysis = h2l_scan_body(env.with_locals(locals), body)
      let candidates = h2l_collect_candidates(analysis)
      let candidates = h2l_filter_nonuniform_if_sets(body, candidates)
      let candidates = h2l_filter_branchy_sets(analysis.env, body, candidates)
      let candidates = match graph {
        Some(g) => h2l_filter_by_local_graph(analysis.env, body, g, candidates)
        None => candidates
      }
      if candidates.is_empty() {
        return None
      }
      let state = h2l_new_state(locals, candidates)
      let rewrite = ModuleTransformer::new().on_tinstruction_evt(fn(
        transformer,
        st,
        instr,
      ) {
        h2l_rewrite_tinstr(transformer, st, analysis.env, mod, instr)
      })
      let (final_state, rewritten, changed_body) = match
        rewrite.walk_texpr(state, body) {
        Ok(Some((s, expr))) => (s, expr, true)
        Ok(None) => (state, body, false)
        Err(_) => return None
      }
      if !changed_body {
        return None
      }
      let new_locals = locals.copy()
      for local_ty in final_state.new_locals {
        new_locals.push(local_ty)
      }
      Some(Func::t_func(new_locals, rewritten))
    }
  }
}

///|
fn h2l_optimize_func(func : Func, env : Env, mod : Module) -> Func? {
  let mut curr = func
  let mut changed = false
  for _ in 0..<4 {
    let graph = match curr {
      TFunc(_, body) => Some(LocalGraph::new(body.instrs))
      _ => None
    }
    match h2l_optimize_func_once(curr, env, mod, graph) {
      Some(next) => {
        curr = next
        changed = true
      }
      None => break
    }
  }
  if changed {
    Some(curr)
  } else {
    None
  }
}

///|
fn heap2local_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  let env = Env::new().with_module(mod)
  ModuleTransformer::new().on_func_evt(fn(_, ctx, func) {
    match h2l_optimize_func(func, env, mod) {
      Some(new_func) => change(ctx, new_func)
      None => unchanged()
    }
  })
}

///|
fn run_heap2local(mod : Module) -> Module {
  let pass = heap2local_ir_pass(mod)
  match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, new_mod))) => new_mod
    _ => mod
  }
}

///|
fn h2l_count_gc_ops(body : TExpr) -> Int {
  let mut count = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TStructNew(_, _)
      | TStructNewDefault(_)
      | TStructGet(_, _, _)
      | TStructGetS(_, _, _)
      | TStructGetU(_, _, _)
      | TStructSet(_, _, _, _)
      | TArrayNew(_, _, _)
      | TArrayNewDefault(_, _)
      | TArrayNewFixed(_, _)
      | TArrayGet(_, _, _)
      | TArrayGetS(_, _, _)
      | TArrayGetU(_, _, _)
      | TArraySet(_, _, _, _)
      | TArrayLen(_) => count += 1
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  count
}

///|
fn h2l_has_unary(body : TExpr, op : UnaryOp) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TUnary(found_op, _) if found_op == op => found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  found.val
}

///|
fn h2l_has_binary(body : TExpr, op : BinaryOp) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TBinary(found_op, _, _) if found_op == op => found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  found.val
}

///|
fn h2l_has_unreachable(body : TExpr) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TUnreachable => found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  found.val
}

///|
fn h2l_has_i32_const(body : TExpr, target : Int) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TI32Const(I32(v)) if v == target => found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  found.val
}

///|
fn h2l_has_local_get(body : TExpr, idx : UInt) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TLocalGet(LocalIdx(i)) if i == idx => found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  found.val
}

///|
fn h2l_has_ref_get_desc(body : TExpr) -> Bool {
  let found = Ref::new(false)
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TRefGetDesc(_) => found.update(fn(_) { true })
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  found.val
}

///|
test "heap2local rewrites struct loc allocation/get/set" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(7)),
      ),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(locals, body)])) => {
      assert_true(locals.length() >= 2)
      assert_eq(h2l_count_gc_ops(body), 0)
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local does not optimize escaping struct reference in call" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(9))]),
      ),
      TInstr::drop(
        TInstr::call(FuncIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(h2l_count_gc_ops(body) > 0)
    _ => fail("expected function")
  }
}

///|
test "heap2local rejects mixed loc sets for candidate loc" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::ref_null(HeapType::new(TypeIdx::new(0))),
      ),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(h2l_count_gc_ops(body) > 0)
    _ => fail("expected function")
  }
}

///|
test "heap2local rewrites fixed-size array to locals" {
  let array_ty = single_rec_type(
    comp_type_sub_type(
      @lib.array_comp_type(
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::array_new_fixed(TypeIdx::new(0), [
          TInstr::i32_const(I32(1)),
          TInstr::i32_const(I32(2)),
          TInstr::i32_const(I32(3)),
        ]),
      ),
      TInstr::array_set(
        TypeIdx::new(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(1)),
        TInstr::i32_const(I32(9)),
      ),
      TInstr::drop(
        TInstr::array_get(
          TypeIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(1)),
        ),
      ),
      TInstr::drop(TInstr::array_len(TInstr::local_get(LocalIdx::new(0)))),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([array_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(locals, body)])) => {
      assert_true(locals.length() >= 4)
      assert_eq(h2l_count_gc_ops(body), 0)
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local does not optimize array with non-constant index" {
  let array_ty = single_rec_type(
    comp_type_sub_type(
      @lib.array_comp_type(
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref, ValType::i32()],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::array_new_fixed(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::local_set(LocalIdx::new(1), TInstr::i32_const(I32(0))),
      TInstr::drop(
        TInstr::array_get(
          TypeIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(1)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([array_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(h2l_count_gc_ops(body) > 0)
    _ => fail("expected function")
  }
}

///|
test "heap2local rewrites dropped loc.get of optimized allocation" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(4))]),
      ),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, { instrs, .. })])) =>
      match instrs[1] {
        TNop => ()
        _ => fail("expected drop(loc.get) to become nop")
      }
    _ => fail("expected function")
  }
}

///|
test "heap2local supports packed struct get_s/get_u semantics" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::pack_type(PackType::i8()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(255))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(511)),
      ),
      TInstr::drop(
        TInstr::struct_get_u(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
      TInstr::drop(
        TInstr::struct_get_s(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_unary(body, UnaryOp::i32_extend8s()))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local supports packed array get_s/get_u semantics" {
  let array_ty = single_rec_type(
    comp_type_sub_type(
      @lib.array_comp_type(
        FieldType::new(StorageType::pack_type(PackType::i16()), Var),
      ),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::array_new_fixed(TypeIdx::new(0), [
          TInstr::i32_const(I32(65535)),
          TInstr::i32_const(I32(32769)),
        ]),
      ),
      TInstr::drop(
        TInstr::array_get_u(
          TypeIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(0)),
        ),
      ),
      TInstr::drop(
        TInstr::array_get_s(
          TypeIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(1)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([array_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_unary(body, UnaryOp::i32_extend16s()))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rewrites ref.is_null/ref.eq over optimized allocation" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(4))]),
      ),
      TInstr::drop(TInstr::ref_is_null(TInstr::local_get(LocalIdx::new(0)))),
      TInstr::drop(
        TInstr::ref_eq(
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, { instrs, .. })])) => {
      assert_eq(h2l_count_gc_ops(TExpr::new(instrs)), 0)
      match instrs[1] {
        TDrop(TI32Const(I32(v))) => assert_eq(v, 0)
        _ => fail("expected ref.is_null rewrite to i32.const 0")
      }
      match instrs[2] {
        TDrop(TI32Const(I32(v))) => assert_eq(v, 1)
        _ => fail("expected ref.eq rewrite to i32.const 1")
      }
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rejects candidate when get can read init value through branch" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(0)),
        TExpr::new([
          TInstr::local_set(
            LocalIdx::new(0),
            TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
          ),
        ]),
        None,
      ),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(h2l_count_gc_ops(body) > 0)
    _ => fail("expected function")
  }
}

///|
test "heap2local optimizes array get OOB into trap" {
  let array_ty = single_rec_type(
    comp_type_sub_type(
      @lib.array_comp_type(
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::array_new_fixed(TypeIdx::new(0), [TInstr::i32_const(I32(9))]),
      ),
      TInstr::drop(
        TInstr::array_get(
          TypeIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(99)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([array_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_unreachable(body))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local masks packed writes" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::pack_type(PackType::i8()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(1))]),
      ),
      TInstr::struct_set(
        TypeIdx::new(0),
        @lib.U32(0),
        TInstr::local_get(LocalIdx::new(0)),
        TInstr::i32_const(I32(300)),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) =>
      assert_true(h2l_has_binary(body, BinaryOp::i32_and()))
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rewrites ref.test and ref.as_non_null wrapped accesses" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(10))]),
      ),
      TInstr::drop(
        TInstr::ref_test(
          false,
          HeapType::new(TypeIdx::new(0)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::ref_as_non_null(TInstr::local_get(LocalIdx::new(0))),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_i32_const(body, 1))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rewrites ref.test false case to i32.const 0" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(3))]),
      ),
      TInstr::drop(
        TInstr::ref_test(
          false,
          HeapType::abs(AbsHeapType::array()),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_i32_const(body, 0))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local preserves optimization with ref.get_desc uses" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(14))]),
      ),
      TInstr::drop(TInstr::ref_get_desc(TInstr::local_get(LocalIdx::new(0)))),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_true(h2l_has_ref_get_desc(body))
      assert_false(h2l_has_local_get(body, 0U))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rewrites ref.test_desc with known allocation type" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(21))]),
      ),
      TInstr::drop(
        TInstr::ref_test_desc(
          false,
          HeapType::new(TypeIdx::new(0)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
      TInstr::drop(
        TInstr::ref_test_desc(
          false,
          HeapType::abs(AbsHeapType::array()),
          TInstr::ref_as_non_null(TInstr::local_get(LocalIdx::new(0))),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_i32_const(body, 1))
      assert_true(h2l_has_i32_const(body, 0))
      assert_false(h2l_has_local_get(body, 0U))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rewrites ref.cast_desc_eq outcomes for known allocation type" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let impossible = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(31))]),
      ),
      TInstr::drop(
        TInstr::ref_cast_desc_eq(
          false,
          HeapType::abs(AbsHeapType::array()),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let compatible = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(32))]),
      ),
      TInstr::drop(
        TInstr::ref_cast_desc_eq(
          false,
          HeapType::new(TypeIdx::new(0)),
          TInstr::ref_as_non_null(TInstr::local_get(LocalIdx::new(0))),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([impossible, compatible]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, impossible_body), TFunc(_, compatible_body)])) => {
      assert_true(h2l_has_unreachable(impossible_body))
      assert_false(h2l_has_local_get(impossible_body, 0U))
      assert_true(h2l_count_gc_ops(compatible_body) > 0)
      assert_false(h2l_has_local_get(compatible_body, 0U))
    }
    _ => fail("expected transformed functions")
  }
}

///|
test "heap2local treats ref.test_desc as exact and rejects strict-subtype allocations" {
  let top_struct = single_rec_type(comp_type_sub_type(struct_comp_type([])))
  let sub_struct = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(1), []),
      ),
      TInstr::drop(
        TInstr::ref_test_desc(
          false,
          HeapType::new(TypeIdx::new(0)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([top_struct, sub_struct]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_i32_const(body, 0))
      assert_false(h2l_has_local_get(body, 0U))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local treats ref.cast_desc_eq as exact and traps on strict-subtype allocations" {
  let top_struct = single_rec_type(comp_type_sub_type(struct_comp_type([])))
  let sub_struct = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(1), []),
      ),
      TInstr::drop(
        TInstr::ref_cast_desc_eq(
          false,
          HeapType::new(TypeIdx::new(0)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([top_struct, sub_struct]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_unreachable(body))
      assert_false(h2l_has_local_get(body, 0U))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rewrites array.new_data for fixed-size nonescaping arrays" {
  let array_ty = single_rec_type(
    comp_type_sub_type(
      @lib.array_comp_type(
        FieldType::new(StorageType::pack_type(PackType::i8()), Var),
      ),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let data = Data::new(DataMode::passive(), [
    (9).to_byte(),
    (20).to_byte(),
    (30).to_byte(),
    (40).to_byte(),
  ])
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::array_new_data(
          TypeIdx::new(0),
          DataIdx::new(0),
          TInstr::i32_const(I32(1)),
          TInstr::i32_const(I32(2)),
        ),
      ),
      TInstr::drop(
        TInstr::array_get_u(
          TypeIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(0)),
        ),
      ),
      TInstr::drop(
        TInstr::array_get_u(
          TypeIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(1)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([array_ty]))
    .with_data_sec(DataSec::new([data]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_i32_const(body, 20))
      assert_true(h2l_has_i32_const(body, 30))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rewrites OOB array.new_data to trap" {
  let array_ty = single_rec_type(
    comp_type_sub_type(
      @lib.array_comp_type(
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let data = Data::new(DataMode::passive(), [(1).to_byte(), (2).to_byte()])
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::array_new_data(
          TypeIdx::new(0),
          DataIdx::new(0),
          TInstr::i32_const(I32(0)),
          TInstr::i32_const(I32(3)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([array_ty]))
    .with_data_sec(DataSec::new([data]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => {
      assert_eq(h2l_count_gc_ops(body), 0)
      assert_true(h2l_has_unreachable(body))
    }
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rewrites array.new_elem for fixed-size nonescaping arrays" {
  let array_ty = single_rec_type(
    comp_type_sub_type(
      @lib.array_comp_type(
        FieldType::new(StorageType::val_type(ValType::funcref()), Var),
      ),
    ),
  )
  let elem = Elem::new(
    ElemMode::passive(),
    ElemKind::funcs([FuncIdx::new(0), FuncIdx::new(0)]),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::array_new_elem(
          TypeIdx::new(0),
          ElemIdx::new(0),
          TInstr::i32_const(I32(0)),
          TInstr::i32_const(I32(2)),
        ),
      ),
      TInstr::drop(
        TInstr::array_get(
          TypeIdx::new(0),
          TInstr::local_get(LocalIdx::new(0)),
          TInstr::i32_const(I32(1)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([array_ty]))
    .with_elem_sec(ElemSec::new([elem]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_eq(h2l_count_gc_ops(body), 0)
    _ => fail("expected transformed function")
  }
}

///|
test "heap2local rejects branchy allocation sets with later gets" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::local_set(
            LocalIdx::new(0),
            TInstr::struct_new(TypeIdx::new(0), [
              TInstr::br(LabelIdx::new(0), []),
            ]),
          ),
        ]),
      ),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(h2l_count_gc_ops(body) > 0)
    _ => fail("expected function")
  }
}

///|
test "heap2local skips optimization in synchronization-sensitive atomic contexts" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(4))]),
      ),
      TInstr::atomic_fence(),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(h2l_count_gc_ops(body) > 0)
    _ => fail("expected function")
  }
}

///|
test "heap2local skips optimization when atomic.rmw appears in function" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ma = MemArg::new(0, None, 0)
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(7))]),
      ),
      TInstr::drop(
        TInstr::atomic_rmw(
          AtomicRmwOp::i32_add(),
          ma,
          TInstr::i32_const(I32(0)),
          TInstr::i32_const(I32(1)),
        ),
      ),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(h2l_count_gc_ops(body) > 0)
    _ => fail("expected function")
  }
}

///|
test "heap2local skips optimization when atomic load/store appears in function" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let ma = MemArg::new(0, None, 0)
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(11))]),
      ),
      TInstr::drop(
        TInstr::load(LoadOp::i32_atomic_load(), ma, TInstr::i32_const(I32(0))),
      ),
      TInstr::store(
        StoreOp::i32_atomic_store(),
        ma,
        TInstr::i32_const(I32(0)),
        TInstr::i32_const(I32(1)),
      ),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1, None))]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(h2l_count_gc_ops(body) > 0)
    _ => fail("expected function")
  }
}

///|
test "heap2local rejects candidate local when local.tee is used" {
  let struct_ty = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let local_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let func = Func::t_func(
    [local_ref],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(13))]),
      ),
      TInstr::drop(
        TInstr::local_tee(LocalIdx::new(0), TInstr::local_get(LocalIdx::new(0))),
      ),
      TInstr::drop(
        TInstr::struct_get(
          TypeIdx::new(0),
          @lib.U32(0),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_ty]))
    .with_code_sec(CodeSec::new([func]))
  let out = run_heap2local(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, body)])) => assert_true(h2l_count_gc_ops(body) > 0)
    _ => fail("expected function")
  }
}
