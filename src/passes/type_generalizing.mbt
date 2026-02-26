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
priv struct TGState {
  original_locals : Array[ValType]
  requirements : Array[ValType]
  param_count : Int
  return_types : Array[ValType]
  mut changed : Bool
}

///|
fn tg_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn tg_ref_requirement(vt : ValType) -> ValType? {
  if vt.is_ref_type() {
    Some(vt)
  } else {
    None
  }
}

///|
fn tg_single_ref_requirement(ts : Array[ValType]) -> ValType? {
  if ts.length() != 1 {
    return None
  }
  tg_ref_requirement(ts[0])
}

///|
fn tg_abs_heap_top(abs : AbsHeapType) -> AbsHeapType {
  match abs {
    FuncAbsHeapType | NoFuncAbsHeapType => AbsHeapType::func()
    ExternAbsHeapType | NoExternAbsHeapType => AbsHeapType::extern_()
    ExnAbsHeapType | NoExnAbsHeapType => AbsHeapType::exn()
    _ => AbsHeapType::any()
  }
}

///|
fn tg_heap_top(ht : HeapType, env : Env) -> HeapType {
  match ht {
    AbsHeapTypeHeapType(abs) => HeapType::abs(tg_abs_heap_top(abs))
    HeapType(type_idx) =>
      match env.resolve_comptype(type_idx) {
        Some(FuncCompType(_, _)) => HeapType::abs(AbsHeapType::func())
        Some(StructCompType(_)) | Some(ArrayCompType(_)) =>
          HeapType::abs(AbsHeapType::any())
        None => ht
      }
    DefTypeHeapType(def_type) =>
      match def_type.project() {
        Some(st) =>
          match st.get_comptype() {
            FuncCompType(_, _) => HeapType::abs(AbsHeapType::func())
            StructCompType(_) | ArrayCompType(_) =>
              HeapType::abs(AbsHeapType::any())
          }
        None => ht
      }
  }
}

///|
fn tg_ref_top(vt : ValType, env : Env) -> ValType {
  match vt {
    RefTypeValType(rt) =>
      ValType::ref_type(
        RefType::new(true, tg_heap_top(rt.get_heap_type(), env)),
      )
    _ => vt
  }
}

///|
fn tg_count_imported_funcs(mod : Module) -> UInt {
  let mut n : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn tg_init_requirements(
  params : Array[ValType],
  locals : Array[ValType],
  env : Env,
) -> Array[ValType] {
  let reqs = params.copy()
  for vt in locals {
    if vt.is_ref_type() {
      reqs.push(tg_ref_top(vt, env))
    } else {
      reqs.push(vt)
    }
  }
  reqs
}

///|
fn tg_get_local_requirement(st : TGState, idx : LocalIdx) -> ValType? {
  let i = tg_local_idx_to_int(idx)
  if i < 0 || i >= st.requirements.length() {
    return None
  }
  tg_ref_requirement(st.requirements[i])
}

///|
fn tg_merge_requirement(
  existing : ValType,
  incoming : ValType,
  fallback : ValType,
  env : Env,
) -> ValType {
  if Match::matches(existing, incoming, env) {
    return existing
  }
  if Match::matches(incoming, existing, env) {
    return incoming
  }
  if Match::matches(fallback, existing, env) &&
    Match::matches(fallback, incoming, env) {
    return fallback
  }
  existing
}

///|
fn tg_update_local_requirement(
  st : TGState,
  idx : LocalIdx,
  incoming : ValType,
  env : Env,
) -> Unit {
  let i = tg_local_idx_to_int(idx)
  if i < 0 || i >= st.requirements.length() || i < st.param_count {
    return
  }
  let old_local_type = st.original_locals[i]
  if !old_local_type.is_ref_type() {
    return
  }
  let merged = tg_merge_requirement(
    st.requirements[i],
    incoming,
    old_local_type,
    env,
  )
  if merged != st.requirements[i] {
    st.requirements[i] = merged
    st.changed = true
  }
}

///|
fn tg_ref_null_typeidx(type_idx : TypeIdx) -> ValType {
  ValType::ref_type(RefType::new(true, HeapType::new(type_idx)))
}

///|
fn tg_struct_field_type(
  env : Env,
  type_idx : TypeIdx,
  field_idx : U32,
) -> ValType? {
  match env.resolve_struct_fields(type_idx) {
    Ok(fields) => {
      let U32(raw) = field_idx
      let i = raw.reinterpret_as_int()
      if i < 0 || i >= fields.length() {
        return None
      }
      let FieldType(sto, _) = fields[i]
      Some(sto.unpack())
    }
    Err(_) => None
  }
}

///|
fn tg_array_elem_type(env : Env, type_idx : TypeIdx) -> ValType? {
  match env.resolve_array_field(type_idx) {
    Ok(FieldType(sto, _)) => Some(sto.unpack())
    Err(_) => None
  }
}

///|
fn tg_label_types(env : Env, label : LabelIdx) -> Array[ValType] {
  match env.get_label_types(label) {
    Some(ts) => ts
    None => []
  }
}

///|
fn tg_prefix_types(types : Array[ValType]) -> Array[ValType] {
  if types.length() <= 1 {
    return []
  }
  let out : Array[ValType] = []
  for i = 0; i < types.length() - 1; i = i + 1 {
    out.push(types[i])
  }
  out
}

///|
fn tg_tag_payload_types(env : Env, tag : TagIdx) -> Array[ValType] {
  match env.resolve_tag_functype(tag) {
    Some(FuncType(params, _)) => params
    None => []
  }
}

///|
fn tg_require_args(
  args : Array[TInstr],
  expected : Array[ValType],
  env : Env,
  st : TGState,
) -> Unit {
  let mut i = args.length() - 1
  while i >= 0 {
    let req = if i < expected.length() {
      tg_ref_requirement(expected[i])
    } else {
      None
    }
    tg_require_instr(args[i], req, env, st)
    i = i - 1
  }
}

///|
fn tg_require_texpr(
  body : TExpr,
  req : ValType?,
  env : Env,
  st : TGState,
) -> Unit {
  let { instrs, .. } = body
  if instrs.is_empty() {
    return
  }
  let mut i = instrs.length() - 1
  while i >= 0 {
    let curr_req = if i == instrs.length() - 1 { req } else { None }
    tg_require_instr(instrs[i], curr_req, env, st)
    i = i - 1
  }
}

///|
fn tg_eval_children(instr : TInstr) -> Array[TInstr] {
  match instr.kind {
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
    | TInstrKind::TStructNewDefault(_) => []
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
    | TInstrKind::TRefCastDescEq(_, _, child) => [child]
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
    | TInstrKind::TV128StoreLane(_, _, _, left, right) => [left, right]
    TInstrKind::TMemoryFill(_, a, b, c)
    | TInstrKind::TMemoryCopy(_, _, a, b, c)
    | TInstrKind::TMemoryInit(_, _, a, b, c)
    | TInstrKind::TMemoryAtomicWait32(_, a, b, c)
    | TInstrKind::TMemoryAtomicWait64(_, a, b, c)
    | TInstrKind::TAtomicCmpxchg(_, _, a, b, c)
    | TInstrKind::TTableFill(_, a, b, c)
    | TInstrKind::TTableCopy(_, _, a, b, c)
    | TInstrKind::TTableInit(_, _, a, b, c)
    | TInstrKind::TSelect(_, c, a, b)
    | TInstrKind::TV128Ternary(_, a, b, c) => [a, b, c]
    TInstrKind::TCall(_, args)
    | TInstrKind::TReturnCall(_, args)
    | TInstrKind::TThrow(_, args)
    | TInstrKind::TBr(_, args)
    | TInstrKind::TReturn(args)
    | TInstrKind::TStructNew(_, args)
    | TInstrKind::TArrayNewFixed(_, args) => args.copy()
    TInstrKind::TCallIndirect(_, _, args, index)
    | TInstrKind::TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TInstrKind::TCallRef(_, args, ref_)
    | TInstrKind::TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TInstrKind::TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TInstrKind::TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TInstrKind::TBrOnNull(_, ref_, values)
    | TInstrKind::TBrOnNonNull(_, ref_, values)
    | TInstrKind::TBrOnCast(_, _, _, _, ref_, values)
    | TInstrKind::TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TInstrKind::TArraySet(_, a, b, c) => [a, b, c]
    TInstrKind::TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TInstrKind::TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TInstrKind::TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TInstrKind::TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
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
    ) => [left, right]
    TInstrKind::TBlock(_, _)
    | TInstrKind::TLoop(_, _)
    | TInstrKind::TIf(_, _, _, _)
    | TInstrKind::TTryTable(_, _, _) => []
  }
}

///|
fn tg_require_instr(
  instr : TInstr,
  req : ValType?,
  env : Env,
  st : TGState,
) -> Unit {
  match instr.kind {
    TInstrKind::TLocalGet(idx) =>
      match req {
        Some(vt) =>
          if vt.is_ref_type() {
            tg_update_local_requirement(st, idx, vt, env)
          }
        None => ()
      }
    TInstrKind::TLocalSet(idx, value) =>
      tg_require_instr(value, tg_get_local_requirement(st, idx), env, st)
    TInstrKind::TLocalTee(idx, value) => {
      match req {
        Some(vt) =>
          if vt.is_ref_type() {
            tg_update_local_requirement(st, idx, vt, env)
          }
        None => ()
      }
      tg_require_instr(value, tg_get_local_requirement(st, idx), env, st)
    }
    TInstrKind::TGlobalSet(idx, value) => {
      let value_req = match env.get_global_type(idx) {
        Some(GlobalType(vt, _)) => tg_ref_requirement(vt)
        None => None
      }
      tg_require_instr(value, value_req, env, st)
    }
    TInstrKind::TCall(target, args) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(params, _)) => tg_require_args(args, params, env, st)
        None => tg_require_args(args, [], env, st)
      }
    TInstrKind::TCallIndirect(type_idx, _, args, index) => {
      let params = match env.resolve_functype(type_idx) {
        Some(FuncType(ps, _)) => ps
        None => []
      }
      tg_require_instr(index, None, env, st)
      tg_require_args(args, params, env, st)
    }
    TInstrKind::TCallRef(type_idx, args, ref_) => {
      let params = match env.resolve_functype(type_idx) {
        Some(FuncType(ps, _)) => ps
        None => []
      }
      tg_require_instr(ref_, Some(tg_ref_null_typeidx(type_idx)), env, st)
      tg_require_args(args, params, env, st)
    }
    TInstrKind::TReturnCall(target, args) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(params, _)) => tg_require_args(args, params, env, st)
        None => tg_require_args(args, [], env, st)
      }
    TInstrKind::TReturnCallIndirect(type_idx, _, args, index) => {
      let params = match env.resolve_functype(type_idx) {
        Some(FuncType(ps, _)) => ps
        None => []
      }
      tg_require_instr(index, None, env, st)
      tg_require_args(args, params, env, st)
    }
    TInstrKind::TReturnCallRef(type_idx, args, ref_) => {
      let params = match env.resolve_functype(type_idx) {
        Some(FuncType(ps, _)) => ps
        None => []
      }
      tg_require_instr(ref_, Some(tg_ref_null_typeidx(type_idx)), env, st)
      tg_require_args(args, params, env, st)
    }
    TInstrKind::TReturn(args) => tg_require_args(args, st.return_types, env, st)
    TInstrKind::TBr(label, args) =>
      tg_require_args(args, tg_label_types(env, label), env, st)
    TInstrKind::TBrIf(label, cond, args) => {
      tg_require_args(args, tg_label_types(env, label), env, st)
      tg_require_instr(cond, None, env, st)
    }
    TInstrKind::TBrTable(_, default_label, index, args) => {
      tg_require_args(args, tg_label_types(env, default_label), env, st)
      tg_require_instr(index, None, env, st)
    }
    TInstrKind::TBrOnNull(label, ref_, args) => {
      tg_require_args(args, tg_label_types(env, label), env, st)
      let ref_req = match req {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(true, rt.get_heap_type())))
        _ => None
      }
      tg_require_instr(ref_, ref_req, env, st)
    }
    TInstrKind::TBrOnNonNull(label, ref_, args) => {
      let label_types = tg_label_types(env, label)
      tg_require_args(args, tg_prefix_types(label_types), env, st)
      let ref_req = match label_types.get(label_types.length() - 1) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(true, rt.get_heap_type())))
        _ => None
      }
      tg_require_instr(ref_, ref_req, env, st)
    }
    TInstrKind::TBrOnCast(label, CastOp(nullable, _), ht1, _, ref_, args) => {
      let label_types = tg_label_types(env, label)
      tg_require_args(args, tg_prefix_types(label_types), env, st)
      tg_require_instr(
        ref_,
        Some(ValType::ref_type(RefType::new(nullable, ht1))),
        env,
        st,
      )
    }
    TInstrKind::TBrOnCastFail(label, CastOp(nullable, _), ht1, _, ref_, args) => {
      let label_types = tg_label_types(env, label)
      tg_require_args(args, tg_prefix_types(label_types), env, st)
      tg_require_instr(
        ref_,
        Some(ValType::ref_type(RefType::new(nullable, ht1))),
        env,
        st,
      )
    }
    TInstrKind::TBlock(bt, body) =>
      match env.expand_blocktype(bt) {
        Ok((_, results)) =>
          tg_require_texpr(
            body,
            tg_single_ref_requirement(results),
            env.with_label(results),
            st,
          )
        Err(_) => tg_require_texpr(body, None, env, st)
      }
    TInstrKind::TLoop(bt, body) =>
      match env.expand_blocktype(bt) {
        Ok((params, results)) =>
          tg_require_texpr(
            body,
            tg_single_ref_requirement(results),
            env.with_label(params),
            st,
          )
        Err(_) => tg_require_texpr(body, None, env, st)
      }
    TInstrKind::TIf(bt, cond, then_body, else_body) => {
      tg_require_instr(cond, None, env, st)
      match env.expand_blocktype(bt) {
        Ok((_, results)) => {
          let env2 = env.with_label(results)
          let branch_req = tg_single_ref_requirement(results)
          tg_require_texpr(then_body, branch_req, env2, st)
          match else_body {
            Some(else_expr) => tg_require_texpr(else_expr, branch_req, env2, st)
            None => ()
          }
        }
        Err(_) => {
          tg_require_texpr(then_body, None, env, st)
          match else_body {
            Some(else_expr) => tg_require_texpr(else_expr, None, env, st)
            None => ()
          }
        }
      }
    }
    TInstrKind::TTryTable(bt, _, body) =>
      match env.expand_blocktype(bt) {
        Ok((_, results)) =>
          tg_require_texpr(
            body,
            tg_single_ref_requirement(results),
            env.with_label(results),
            st,
          )
        Err(_) => tg_require_texpr(body, None, env, st)
      }
    TInstrKind::TThrow(tag, args) =>
      tg_require_args(args, tg_tag_payload_types(env, tag), env, st)
    TInstrKind::TSelect(types_opt, cond, tval, fval) => {
      let value_req = match types_opt {
        Some([vt]) => tg_ref_requirement(vt)
        _ => req
      }
      tg_require_instr(tval, value_req, env, st)
      tg_require_instr(fval, value_req, env, st)
      tg_require_instr(cond, None, env, st)
    }
    TInstrKind::TRefEq(left, right) => {
      let eqref = ValType::ref_type(
        RefType::new(true, HeapType::abs(AbsHeapType::eq())),
      )
      tg_require_instr(left, Some(eqref), env, st)
      tg_require_instr(right, Some(eqref), env, st)
    }
    TInstrKind::TRefAsNonNull(value) => {
      let in_req = match req {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(true, rt.get_heap_type())))
        _ => None
      }
      tg_require_instr(value, in_req, env, st)
    }
    TInstrKind::TAnyConvertExtern(value) => {
      let in_req = match req {
        Some(RefTypeValType(rt)) =>
          Some(
            ValType::ref_type(
              RefType::new(
                rt.is_nullable(),
                HeapType::abs(AbsHeapType::extern_()),
              ),
            ),
          )
        _ => None
      }
      tg_require_instr(value, in_req, env, st)
    }
    TInstrKind::TExternConvertAny(value) => {
      let in_req = match req {
        Some(RefTypeValType(rt)) =>
          Some(
            ValType::ref_type(
              RefType::new(rt.is_nullable(), HeapType::abs(AbsHeapType::any())),
            ),
          )
        _ => None
      }
      tg_require_instr(value, in_req, env, st)
    }
    TInstrKind::TI31GetS(value) | TInstrKind::TI31GetU(value) =>
      tg_require_instr(
        value,
        Some(ValType::ref_null(HeapType::abs(AbsHeapType::i31()))),
        env,
        st,
      )
    TInstrKind::TArrayLen(value) =>
      tg_require_instr(
        value,
        Some(ValType::ref_null(HeapType::abs(AbsHeapType::array()))),
        env,
        st,
      )
    TInstrKind::TTableGet(_, index) => tg_require_instr(index, None, env, st)
    TInstrKind::TTableSet(table_idx, index, value) => {
      tg_require_instr(index, None, env, st)
      let value_req = match env.get_table_type(table_idx) {
        Some(TableType(rt, _)) => Some(ValType::ref_type(rt))
        None => None
      }
      tg_require_instr(value, value_req, env, st)
    }
    TInstrKind::TTableGrow(table_idx, value, size) => {
      tg_require_instr(size, None, env, st)
      let value_req = match env.get_table_type(table_idx) {
        Some(TableType(rt, _)) => Some(ValType::ref_type(rt))
        None => None
      }
      tg_require_instr(value, value_req, env, st)
    }
    TInstrKind::TTableFill(table_idx, start, value, len) => {
      tg_require_instr(start, None, env, st)
      tg_require_instr(len, None, env, st)
      let value_req = match env.get_table_type(table_idx) {
        Some(TableType(rt, _)) => Some(ValType::ref_type(rt))
        None => None
      }
      tg_require_instr(value, value_req, env, st)
    }
    TInstrKind::TStructNew(type_idx, args) =>
      match env.resolve_struct_fields(type_idx) {
        Ok(fields) => {
          let types : Array[ValType] = []
          for field in fields {
            let FieldType(sto, _) = field
            types.push(sto.unpack())
          }
          tg_require_args(args, types, env, st)
        }
        Err(_) => tg_require_args(args, [], env, st)
      }
    TInstrKind::TStructGet(type_idx, _, ref_)
    | TInstrKind::TStructGetS(type_idx, _, ref_)
    | TInstrKind::TStructGetU(type_idx, _, ref_) =>
      tg_require_instr(ref_, Some(tg_ref_null_typeidx(type_idx)), env, st)
    TInstrKind::TStructSet(type_idx, field_idx, ref_, value) => {
      tg_require_instr(ref_, Some(tg_ref_null_typeidx(type_idx)), env, st)
      let value_req = match tg_struct_field_type(env, type_idx, field_idx) {
        Some(vt) => tg_ref_requirement(vt)
        None => None
      }
      tg_require_instr(value, value_req, env, st)
    }
    TInstrKind::TArrayNew(type_idx, init, len) => {
      let init_req = match tg_array_elem_type(env, type_idx) {
        Some(vt) => tg_ref_requirement(vt)
        None => None
      }
      tg_require_instr(init, init_req, env, st)
      tg_require_instr(len, None, env, st)
    }
    TInstrKind::TArrayNewDefault(_, len) => tg_require_instr(len, None, env, st)
    TInstrKind::TArrayNewFixed(type_idx, values) => {
      let elem_req = match tg_array_elem_type(env, type_idx) {
        Some(vt) => tg_ref_requirement(vt)
        None => None
      }
      for value in values {
        tg_require_instr(value, elem_req, env, st)
      }
    }
    TInstrKind::TArrayNewData(_, _, offset, len)
    | TInstrKind::TArrayNewElem(_, _, offset, len) => {
      tg_require_instr(offset, None, env, st)
      tg_require_instr(len, None, env, st)
    }
    TInstrKind::TArrayGet(type_idx, ref_, idx)
    | TInstrKind::TArrayGetS(type_idx, ref_, idx)
    | TInstrKind::TArrayGetU(type_idx, ref_, idx) => {
      tg_require_instr(ref_, Some(tg_ref_null_typeidx(type_idx)), env, st)
      tg_require_instr(idx, None, env, st)
    }
    TInstrKind::TArraySet(type_idx, ref_, idx, value) => {
      tg_require_instr(ref_, Some(tg_ref_null_typeidx(type_idx)), env, st)
      tg_require_instr(idx, None, env, st)
      let value_req = match tg_array_elem_type(env, type_idx) {
        Some(vt) => tg_ref_requirement(vt)
        None => None
      }
      tg_require_instr(value, value_req, env, st)
    }
    TInstrKind::TArrayFill(type_idx, ref_, idx, value, len) => {
      tg_require_instr(ref_, Some(tg_ref_null_typeidx(type_idx)), env, st)
      tg_require_instr(idx, None, env, st)
      tg_require_instr(len, None, env, st)
      let value_req = match tg_array_elem_type(env, type_idx) {
        Some(vt) => tg_ref_requirement(vt)
        None => None
      }
      tg_require_instr(value, value_req, env, st)
    }
    TInstrKind::TArrayCopy(
      dest_type,
      src_type,
      dest_ref,
      dest_idx,
      src_ref,
      src_idx,
      len
    ) => {
      tg_require_instr(dest_ref, Some(tg_ref_null_typeidx(dest_type)), env, st)
      tg_require_instr(src_ref, Some(tg_ref_null_typeidx(src_type)), env, st)
      tg_require_instr(dest_idx, None, env, st)
      tg_require_instr(src_idx, None, env, st)
      tg_require_instr(len, None, env, st)
    }
    TInstrKind::TArrayInitData(type_idx, _, ref_, dest_idx, src_idx, len)
    | TInstrKind::TArrayInitElem(type_idx, _, ref_, dest_idx, src_idx, len) => {
      tg_require_instr(ref_, Some(tg_ref_null_typeidx(type_idx)), env, st)
      tg_require_instr(dest_idx, None, env, st)
      tg_require_instr(src_idx, None, env, st)
      tg_require_instr(len, None, env, st)
    }
    TInstrKind::TRefTest(_, _, value)
    | TInstrKind::TRefCast(_, _, value)
    | TInstrKind::TRefTestDesc(_, _, value)
    | TInstrKind::TRefCastDescEq(_, _, value)
    | TInstrKind::TRefGetDesc(value)
    | TInstrKind::TRefIsNull(value) => tg_require_instr(value, None, env, st)
    _ => {
      let children = tg_eval_children(instr)
      let mut i = children.length() - 1
      while i >= 0 {
        tg_require_instr(children[i], None, env, st)
        i = i - 1
      }
    }
  }
}

///|
fn tg_run_dce_body(body : TExpr) -> TExpr {
  let pass = dead_code_elimination_pass()
  match pass.walk_texpr((), body) {
    Ok(Some((_, out))) => out
    _ => body
  }
}

///|
fn tg_generalize_function(
  params : Array[ValType],
  results : Array[ValType],
  locals : Array[ValType],
  body : TExpr,
  base_env : Env,
) -> (Array[ValType], TExpr, Bool) {
  let normalized_body = tg_run_dce_body(body)
  let full_locals = params.copy()
  for vt in locals {
    full_locals.push(vt)
  }
  let func_env = base_env
    .with_locals(full_locals)
    .with_labels([results])
    .with_return_type(Some(results))
  let state : TGState = {
    original_locals: full_locals,
    requirements: tg_init_requirements(params, locals, func_env),
    param_count: params.length(),
    return_types: results,
    changed: false,
  }
  let mut fuel = full_locals.length() * 8 + 16
  let mut iterate = true
  while iterate && fuel > 0 {
    state.changed = false
    tg_require_texpr(
      normalized_body,
      tg_single_ref_requirement(results),
      func_env,
      state,
    )
    iterate = state.changed
    fuel = fuel - 1
  }

  let mut locals_changed = false
  let new_locals : Array[ValType] = []
  for i = params.length(); i < full_locals.length(); i = i + 1 {
    let old_type = full_locals[i]
    let new_type = match old_type {
      RefTypeValType(_) => {
        let candidate = state.requirements[i]
        if Match::matches(old_type, candidate, func_env) {
          candidate
        } else {
          old_type
        }
      }
      _ => old_type
    }
    if new_type != old_type {
      locals_changed = true
    }
    new_locals.push(new_type)
  }
  let body_changed = normalized_body != body
  (new_locals, normalized_body, locals_changed || body_changed)
}

///|
fn type_generalizing(mod : Module) -> Result[Module, String] {
  let env = Env::new().with_module(mod)
  let imported_funcs = tg_count_imported_funcs(mod)
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      let out_funcs = funcs.copy()
      let mut changed = false
      for i = 0; i < funcs.length(); i = i + 1 {
        let abs_idx = FuncIdx::new(imported_funcs + i.reinterpret_as_uint())
        let (params, results) = match env.get_functype_by_funcidx(abs_idx) {
          Some(FuncType(ps, rs)) => (ps, rs)
          None => ([], [])
        }
        match funcs[i] {
          TFunc(locals, body) => {
            let (new_locals, new_body, func_changed) = tg_generalize_function(
              params, results, locals, body, env,
            )
            if func_changed {
              out_funcs[i] = Func::t_func(new_locals, new_body)
              changed = true
            }
          }
          _ => return Err("type_generalizing: expected TFunc")
        }
      }
      if changed {
        Ok(mod.with_code_sec(CodeSec::new(out_funcs)))
      } else {
        Ok(mod)
      }
    }
    None => Ok(mod)
  }
}

///|
fn run_type_generalizing(mod : Module) -> Module {
  match type_generalizing(mod) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
fn tg_void_type() -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type([], [])))
}

///|
fn tg_func_type(params : Array[ValType], results : Array[ValType]) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn tg_funcref_to_type0_nullable() -> ValType {
  ValType::ref_null(HeapType::new(TypeIdx::new(0)))
}

///|
fn tg_single_func_module(
  types : Array[RecType],
  func_type_idx : TypeIdx,
  locals : Array[ValType],
  body : TExpr,
) -> Module {
  Module::new()
  .with_type_sec(TypeSec::new(types))
  .with_func_sec(FuncSec::new([func_type_idx]))
  .with_code_sec(CodeSec::new([Func::t_func(locals, body)]))
}

///|
test "type generalizing lifts unused typed function-ref local to top funcref" {
  let mod = tg_single_func_module(
    [tg_void_type()],
    TypeIdx::new(0),
    [tg_funcref_to_type0_nullable()],
    TExpr::new([TInstr::nop()]),
  )
  let out = run_type_generalizing(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([vt], _)])) => assert_eq(vt, ValType::funcref())
    _ => fail("expected one transformed function")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("optimized module should validate: \{e}")
  }
}

///|
test "type generalizing keeps call_ref target local at typed function reference" {
  let mod = tg_single_func_module(
    [tg_void_type()],
    TypeIdx::new(0),
    [tg_funcref_to_type0_nullable()],
    TExpr::new([
      TInstr::call_ref(TypeIdx::new(0), [], TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let out = run_type_generalizing(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([vt], _)])) =>
      assert_eq(vt, tg_funcref_to_type0_nullable())
    _ => fail("expected one transformed function")
  }
}

///|
test "type generalizing propagates requirements through local.set chains" {
  let mod = tg_single_func_module(
    [tg_void_type()],
    TypeIdx::new(0),
    [tg_funcref_to_type0_nullable(), tg_funcref_to_type0_nullable()],
    TExpr::new([
      TInstr::local_set(LocalIdx::new(1), TInstr::local_get(LocalIdx::new(0))),
      TInstr::call_ref(TypeIdx::new(0), [], TInstr::local_get(LocalIdx::new(1))),
    ]),
  )
  let out = run_type_generalizing(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([vt0, vt1], _)])) => {
      assert_eq(vt0, tg_funcref_to_type0_nullable())
      assert_eq(vt1, tg_funcref_to_type0_nullable())
    }
    _ => fail("expected one transformed function")
  }
}

///|
test "type generalizing allows ref.is_null users to generalize to top funcref" {
  let mod = tg_single_func_module(
    [tg_void_type()],
    TypeIdx::new(0),
    [tg_funcref_to_type0_nullable()],
    TExpr::new([
      TInstr::drop(TInstr::ref_is_null(TInstr::local_get(LocalIdx::new(0)))),
    ]),
  )
  let out = run_type_generalizing(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([vt], _)])) => assert_eq(vt, ValType::funcref())
    _ => fail("expected one transformed function")
  }
}

///|
test "type generalizing preserves branch value requirements from block labels" {
  let mod = tg_single_func_module(
    [tg_void_type()],
    TypeIdx::new(0),
    [tg_funcref_to_type0_nullable()],
    TExpr::new([
      TInstr::drop(
        TInstr::block(
          BlockType::val_type(tg_funcref_to_type0_nullable()),
          TExpr::new([
            TInstr::br(LabelIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
            TInstr::ref_null(HeapType::new(TypeIdx::new(0))),
          ]),
        ),
      ),
    ]),
  )
  let out = run_type_generalizing(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([vt], _)])) =>
      assert_eq(vt, tg_funcref_to_type0_nullable())
    _ => fail("expected one transformed function")
  }
}

///|
test "type generalizing generalizes concrete struct local when only anyref is required" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        struct_type,
        tg_func_type([ValType::anyref()], []),
        tg_void_type(),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func([], TExpr::new([TInstr::nop()])),
        Func::t_func(
          [ValType::ref_null(HeapType::new(TypeIdx::new(0)))],
          TExpr::new([
            TInstr::call(FuncIdx::new(0), [TInstr::local_get(LocalIdx::new(0))]),
          ]),
        ),
      ]),
    )
  let out = run_type_generalizing(mod)
  match out.code_sec {
    Some(CodeSec([_, TFunc([vt], _)])) => assert_eq(vt, ValType::anyref())
    _ => fail("expected transformed second function")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("optimized module should validate: \{e}")
  }
}
