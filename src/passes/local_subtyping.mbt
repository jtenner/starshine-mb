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
priv struct LocalSubtypingScan {
  sets_for_local : Map[Int, Array[TInstr]]
  gets_for_local : Map[Int, Array[Int]]
}

///|
fn LocalSubtypingScan::new() -> LocalSubtypingScan {
  { sets_for_local: Map::new(), gets_for_local: Map::new() }
}

///|
fn ls_count_imported_funcs(mod : Module) -> UInt {
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
fn ls_collect_func_type_idx_by_func(mod : Module) -> Map[FuncIdx, TypeIdx] {
  let out : Map[FuncIdx, TypeIdx] = Map::new()
  let mut next_idx : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) => {
            out[FuncIdx::new(next_idx)] = type_idx
            next_idx += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out[FuncIdx::new(next_idx)] = type_idx
        next_idx += 1
      }
    None => ()
  }
  out
}

///|
fn ls_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn ls_push_tinstr(
  map : Map[Int, Array[TInstr]],
  key : Int,
  value : TInstr,
) -> Unit {
  let arr = map.get(key).unwrap_or([])
  arr.push(value)
  map[key] = arr
}

///|
fn ls_push_int(map : Map[Int, Array[Int]], key : Int, value : Int) -> Unit {
  let arr = map.get(key).unwrap_or([])
  arr.push(value)
  map[key] = arr
}

///|
fn ls_is_none_ref_type(vt : ValType) -> Bool {
  match vt {
    RefTypeValType(rt) =>
      match rt.get_heap_type() {
        AbsHeapTypeHeapType(NoneAbsHeapType) => true
        _ => false
      }
    _ => false
  }
}

///|
fn ls_common_ref_heap_supertype(
  a : HeapType,
  b : HeapType,
  env : Env,
) -> HeapType? {
  fn is_func_heap(ht : HeapType) -> Bool {
    match ht {
      AbsHeapTypeHeapType(FuncAbsHeapType) => true
      HeapType(tidx) =>
        match env.resolve_comptype(tidx) {
          Some(FuncCompType(_, _)) => true
          _ => false
        }
      _ => false
    }
  }

  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  let candidates = [
    AbsHeapType::i31(),
    AbsHeapType::struct_(),
    AbsHeapType::array(),
    AbsHeapType::eq(),
    AbsHeapType::func(),
    AbsHeapType::extern_(),
    AbsHeapType::exn(),
    AbsHeapType::any(),
  ]
  for abs in candidates {
    let super_ht = HeapType::abs(abs)
    if Match::matches(a, super_ht, env) && Match::matches(b, super_ht, env) {
      return Some(super_ht)
    }
  }
  if is_func_heap(a) && is_func_heap(b) {
    return Some(HeapType::abs(AbsHeapType::func()))
  }
  None
}

///|
fn ls_common_ref_type_supertype(
  a : RefType,
  b : RefType,
  env : Env,
) -> RefType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  match
    ls_common_ref_heap_supertype(a.get_heap_type(), b.get_heap_type(), env) {
    Some(ht) => Some(RefType::new(a.is_nullable() || b.is_nullable(), ht))
    None => None
  }
}

///|
fn ls_common_val_supertype(a : ValType, b : ValType, env : Env) -> ValType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  match (a, b) {
    (RefTypeValType(r0), RefTypeValType(r1)) =>
      match ls_common_ref_type_supertype(r0, r1, env) {
        Some(rt) => Some(ValType::ref_type(rt))
        None => None
      }
    _ => None
  }
}

///|
fn ls_lub_for_refining(
  a : ValType,
  b : ValType,
  old_type : ValType,
  env : Env,
) -> ValType {
  match ls_common_val_supertype(a, b, env) {
    Some(candidate) =>
      if Match::matches(candidate, old_type, env) {
        candidate
      } else {
        old_type
      }
    None => old_type
  }
}

///|
fn ls_infer_tinstr_type(
  instr : TInstr,
  env : Env,
  func_type_idx_by_func : Map[FuncIdx, TypeIdx],
) -> ValType? {
  fn single_result_of_blocktype(bt : BlockType) -> ValType? {
    match env.expand_blocktype(bt) {
      Ok((_, [vt])) => Some(vt)
      _ => None
    }
  }

  fn infer_texpr_type(texpr : TExpr) -> ValType? {
    let TExpr(instrs) = texpr
    if instrs.is_empty() {
      None
    } else {
      ls_infer_tinstr_type(
        instrs[instrs.length() - 1],
        env,
        func_type_idx_by_func,
      )
    }
  }

  match instr {
    TI32Const(_) => Some(ValType::i32())
    TI64Const(_) => Some(ValType::i64())
    TF32Const(_) => Some(ValType::f32())
    TF64Const(_) => Some(ValType::f64())
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    TRefNull(ht) => Some(ValType::ref_type(RefType::new(true, ht)))
    TRefFunc(_) => Some(ValType::funcref())
    TLocalGet(idx) => env.get_local_type(idx)
    TGlobalGet(idx) =>
      match env.get_global_type(idx) {
        Some(GlobalType(vt, _)) => Some(vt)
        None => None
      }
    TLocalTee(_, value) =>
      ls_infer_tinstr_type(value, env, func_type_idx_by_func)
    TRefAsNonNull(value) =>
      match ls_infer_tinstr_type(value, env, func_type_idx_by_func) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    TRefCast(nullable, ht, _) =>
      Some(ValType::ref_type(RefType::new(nullable, ht)))
    TStructNew(type_idx, _)
    | TStructNewDefault(type_idx)
    | TArrayNew(type_idx, _, _)
    | TArrayNewDefault(type_idx, _)
    | TArrayNewFixed(type_idx, _)
    | TArrayNewData(type_idx, _, _, _)
    | TArrayNewElem(type_idx, _, _, _) =>
      Some(ValType::ref_type(RefType::new(false, HeapType::new(type_idx))))
    TStructGet(type_idx, field_idx, _)
    | TStructGetS(type_idx, field_idx, _)
    | TStructGetU(type_idx, field_idx, _) =>
      match env.resolve_struct_fields(type_idx) {
        Ok(fields) =>
          match field_idx {
            U32(raw_idx) =>
              match fields.get(raw_idx.reinterpret_as_int()) {
                Some(field_ty) => Some(field_ty.unpack())
                None => None
              }
          }
        Err(_) => None
      }
    TArrayGet(type_idx, _, _)
    | TArrayGetS(type_idx, _, _)
    | TArrayGetU(type_idx, _, _) =>
      match env.resolve_array_field(type_idx) {
        Ok(field_ty) => Some(field_ty.unpack())
        Err(_) => None
      }
    TSelect(types, _, if_true, if_false) => {
      let from_decl = match types {
        Some(vts) if vts.length() == 1 => Some(vts[0])
        _ => None
      }
      let from_branches = match
        (
          ls_infer_tinstr_type(if_true, env, func_type_idx_by_func),
          ls_infer_tinstr_type(if_false, env, func_type_idx_by_func),
        ) {
        (Some(t), Some(f)) => ls_common_val_supertype(t, f, env)
        _ => None
      }
      match (from_branches, from_decl) {
        (Some(t), Some(vt)) =>
          if Match::matches(t, vt, env) {
            Some(t)
          } else {
            Some(vt)
          }
        (Some(t), None) => Some(t)
        (None, Some(vt)) => Some(vt)
        _ => None
      }
    }
    TCall(target, _) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, [r])) => Some(r)
        _ => None
      }
    TBlock(bt, body) | TLoop(bt, body) | TTryTable(bt, _, body) => {
      let from_body = infer_texpr_type(body)
      let from_bt = single_result_of_blocktype(bt)
      match (from_body, from_bt) {
        (Some(t), Some(vt)) =>
          if Match::matches(t, vt, env) {
            Some(t)
          } else {
            Some(vt)
          }
        (Some(t), None) => Some(t)
        (None, Some(vt)) => Some(vt)
        _ => None
      }
    }
    TIf(bt, _, then_, else_) => {
      let from_bt = single_result_of_blocktype(bt)
      let from_branches = match else_ {
        Some(else_expr) =>
          match (infer_texpr_type(then_), infer_texpr_type(else_expr)) {
            (Some(t), Some(e)) => ls_common_val_supertype(t, e, env)
            _ => None
          }
        None => None
      }
      match (from_branches, from_bt) {
        (Some(t), Some(vt)) =>
          if Match::matches(t, vt, env) {
            Some(t)
          } else {
            Some(vt)
          }
        (Some(t), None) => Some(t)
        (None, Some(vt)) => Some(vt)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn ls_scan_body(body : TExpr, relevant_locals : Set[Int]) -> LocalSubtypingScan {
  let scan = LocalSubtypingScan::new()
  let mut get_id = 0
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TLocalGet(idx) => {
        let local_idx = ls_local_idx_to_int(idx)
        if relevant_locals.contains(local_idx) {
          ls_push_int(scan.gets_for_local, local_idx, get_id)
        }
        get_id += 1
      }
      TLocalSet(idx, value) => {
        let local_idx = ls_local_idx_to_int(idx)
        if relevant_locals.contains(local_idx) {
          ls_push_tinstr(scan.sets_for_local, local_idx, value)
        }
      }
      TLocalTee(idx, value) => {
        let local_idx = ls_local_idx_to_int(idx)
        if relevant_locals.contains(local_idx) {
          ls_push_tinstr(scan.sets_for_local, local_idx, value)
        }
      }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  scan
}

///|
fn ls_eval_children(instr : TInstr) -> Array[TInstr] {
  match instr {
    TI32Const(_)
    | TI64Const(_)
    | TF32Const(_)
    | TF64Const(_)
    | TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | TUnreachable
    | TNop
    | TLocalGet(_)
    | TGlobalGet(_)
    | TMemorySize(_)
    | TAtomicFence
    | TTableSize(_)
    | TDataDrop(_)
    | TElemDrop(_)
    | TStructNewDefault(_) => []
    TUnary(_, child)
    | TDrop(child)
    | TLocalSet(_, child)
    | TLocalTee(_, child)
    | TGlobalSet(_, child)
    | TRefIsNull(child)
    | TRefAsNonNull(child)
    | TI31GetS(child)
    | TI31GetU(child)
    | TRefI31(child)
    | TArrayLen(child)
    | TAnyConvertExtern(child)
    | TExternConvertAny(child)
    | TThrowRef(child)
    | TMemoryGrow(_, child)
    | TTableGet(_, child)
    | TLoad(_, _, child)
    | TArrayNewDefault(_, child)
    | TStructGet(_, _, child)
    | TStructGetS(_, _, child)
    | TStructGetU(_, _, child)
    | TI8x16Splat(child)
    | TI16x8Splat(child)
    | TI32x4Splat(child)
    | TI64x2Splat(child)
    | TF32x4Splat(child)
    | TF64x2Splat(child)
    | TExtractLane(_, _, child)
    | TRefTest(_, _, child)
    | TRefCast(_, _, child)
    | TRefGetDesc(child)
    | TRefTestDesc(_, _, child)
    | TRefCastDescEq(_, _, child) => [child]
    TBinary(_, left, right)
    | TRefEq(left, right)
    | TStore(_, _, left, right)
    | TMemoryAtomicNotify(_, left, right)
    | TAtomicRmw(_, _, left, right)
    | TTableSet(_, left, right)
    | TTableGrow(_, left, right)
    | TStructSet(_, _, left, right)
    | TArrayNew(_, left, right)
    | TArrayNewData(_, _, left, right)
    | TArrayNewElem(_, _, left, right)
    | TArrayGet(_, left, right)
    | TArrayGetS(_, left, right)
    | TArrayGetU(_, left, right)
    | TReplaceLane(_, _, left, right)
    | TI8x16Swizzle(left, right)
    | TI8x16RelaxedSwizzle(left, right)
    | TV128Shift(_, left, right)
    | TV128LoadLane(_, _, _, left, right)
    | TV128StoreLane(_, _, _, left, right) => [left, right]
    TMemoryFill(_, a, b, c)
    | TMemoryCopy(_, _, a, b, c)
    | TMemoryInit(_, _, a, b, c)
    | TMemoryAtomicWait32(_, a, b, c)
    | TMemoryAtomicWait64(_, a, b, c)
    | TAtomicCmpxchg(_, _, a, b, c)
    | TTableFill(_, a, b, c)
    | TTableCopy(_, _, a, b, c)
    | TTableInit(_, _, a, b, c)
    | TSelect(_, c, a, b)
    | TV128Ternary(_, a, b, c) => [a, b, c]
    TCall(_, args)
    | TReturnCall(_, args)
    | TThrow(_, args)
    | TBr(_, args)
    | TReturn(args)
    | TStructNew(_, args)
    | TArrayNewFixed(_, args) => args.copy()
    TCallIndirect(_, _, args, index) | TReturnCallIndirect(_, _, args, index) => {
      let out = args.copy()
      out.push(index)
      out
    }
    TCallRef(_, args, ref_) | TReturnCallRef(_, args, ref_) => {
      let out = args.copy()
      out.push(ref_)
      out
    }
    TBrIf(_, cond, values) => {
      let out = values.copy()
      out.push(cond)
      out
    }
    TBrTable(_, _, index, values) => {
      let out = values.copy()
      out.push(index)
      out
    }
    TBrOnNull(_, ref_, values)
    | TBrOnNonNull(_, ref_, values)
    | TBrOnCast(_, _, _, _, ref_, values)
    | TBrOnCastFail(_, _, _, _, ref_, values) => {
      let out = values.copy()
      out.push(ref_)
      out
    }
    TArraySet(_, a, b, c) => [a, b, c]
    TArrayFill(_, a, b, c, d) => [a, b, c, d]
    TArrayCopy(_, _, a, b, c, d, e) => [a, b, c, d, e]
    TArrayInitData(_, _, a, b, c, d) => [a, b, c, d]
    TArrayInitElem(_, _, a, b, c, d) => [a, b, c, d]
    TI8x16Shuffle(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, left, right) =>
      [left, right]
    TBlock(_, _) | TLoop(_, _) | TIf(_, _, _, _) | TTryTable(_, _, _) => []
  }
}

///|
fn ls_structural_dominance_instr(
  instr : TInstr,
  definitely_set : Set[Int],
  relevant_locals : Set[Int],
  cannot_be_non_nullable : Set[Int],
) -> Set[Int] {
  match instr {
    TLocalGet(idx) => {
      let local_idx = ls_local_idx_to_int(idx)
      if relevant_locals.contains(local_idx) &&
        !definitely_set.contains(local_idx) {
        cannot_be_non_nullable.add(local_idx)
      }
      definitely_set
    }
    TLocalSet(idx, value) | TLocalTee(idx, value) => {
      let after_value = ls_structural_dominance_instr(
        value, definitely_set, relevant_locals, cannot_be_non_nullable,
      )
      let local_idx = ls_local_idx_to_int(idx)
      let out = after_value.copy()
      if relevant_locals.contains(local_idx) {
        out.add(local_idx)
      }
      out
    }
    TBlock(_, body) | TLoop(_, body) | TTryTable(_, _, body) =>
      ls_structural_dominance_texpr(
        body, definitely_set, relevant_locals, cannot_be_non_nullable,
      )
    TIf(_, cond, then_, else_) => {
      let after_cond = ls_structural_dominance_instr(
        cond, definitely_set, relevant_locals, cannot_be_non_nullable,
      )
      let after_then = ls_structural_dominance_texpr(
        then_, after_cond, relevant_locals, cannot_be_non_nullable,
      )
      let after_else = match else_ {
        Some(other) =>
          ls_structural_dominance_texpr(
            other, after_cond, relevant_locals, cannot_be_non_nullable,
          )
        None => after_cond
      }
      let merged : Set[Int] = Set::new()
      for local_idx in relevant_locals {
        if after_then.contains(local_idx) && after_else.contains(local_idx) {
          merged.add(local_idx)
        }
      }
      merged
    }
    _ => {
      let mut state = definitely_set
      for child in ls_eval_children(instr) {
        state = ls_structural_dominance_instr(
          child, state, relevant_locals, cannot_be_non_nullable,
        )
      }
      state
    }
  }
}

///|
fn ls_structural_dominance_texpr(
  expr : TExpr,
  definitely_set : Set[Int],
  relevant_locals : Set[Int],
  cannot_be_non_nullable : Set[Int],
) -> Set[Int] {
  let mut state = definitely_set
  for instr in expr.0 {
    state = ls_structural_dominance_instr(
      instr, state, relevant_locals, cannot_be_non_nullable,
    )
  }
  state
}

///|
fn ls_compute_cannot_be_non_nullable(
  scan : LocalSubtypingScan,
  graph : LocalGraph,
  body : TExpr,
  relevant_locals : Set[Int],
) -> Set[Int] {
  let cannot : Set[Int] = Set::new()
  for local_idx in relevant_locals {
    match scan.gets_for_local.get(local_idx) {
      Some(get_ids) =>
        for get_id in get_ids {
          let sets = graph.get_sets(get_id)
          if sets.is_empty() {
            cannot.add(local_idx)
            break
          }
          let mut hit_init = false
          for set_ in sets {
            match set_ {
              InitValue => {
                hit_init = true
                break
              }
              _ => ()
            }
          }
          if hit_init {
            cannot.add(local_idx)
            break
          }
        }
      None => ()
    }
  }
  ignore(
    ls_structural_dominance_texpr(body, Set::new(), relevant_locals, cannot),
  )
  cannot
}

///|
fn ls_compute_assigned_lub(
  local_idx : Int,
  old_type : ValType,
  scan : LocalSubtypingScan,
  env : Env,
  func_type_idx_by_func : Map[FuncIdx, TypeIdx],
) -> ValType? {
  match scan.sets_for_local.get(local_idx) {
    Some(values) if !values.is_empty() => {
      let mut candidate : ValType? = None
      for value in values {
        let observed = match
          ls_infer_tinstr_type(value, env, func_type_idx_by_func) {
          Some(vt) if Match::matches(vt, old_type, env) => vt
          _ => old_type
        }
        candidate = match candidate {
          Some(prev) => Some(ls_lub_for_refining(prev, observed, old_type, env))
          None => Some(observed)
        }
      }
      candidate
    }
    _ => None
  }
}

///|
fn ls_refine_function_locals(
  params : Array[ValType],
  locals : Array[ValType],
  body : TExpr,
  base_env : Env,
  func_type_idx_by_func : Map[FuncIdx, TypeIdx],
) -> (Array[ValType], Bool) {
  let param_count = params.length()
  let full_locals = params.copy()
  full_locals.append(locals)
  let relevant_locals : Set[Int] = Set::new()
  for i = param_count; i < full_locals.length(); i = i + 1 {
    if full_locals[i].is_ref_type() {
      relevant_locals.add(i)
    }
  }
  if relevant_locals.is_empty() {
    return (locals, false)
  }
  let scan = ls_scan_body(body, relevant_locals)
  let graph = LocalGraph::new(body.0)
  let cannot_be_non_nullable = ls_compute_cannot_be_non_nullable(
    scan, graph, body, relevant_locals,
  )
  let mut changed = false
  let mut more = true
  while more {
    more = false
    let env = base_env.with_locals(full_locals)
    for i = param_count; i < full_locals.length(); i = i + 1 {
      if !relevant_locals.contains(i) {
        continue
      }
      let old_type = full_locals[i]
      let mut new_type = match
        ls_compute_assigned_lub(i, old_type, scan, env, func_type_idx_by_func) {
        Some(vt) => vt
        None => continue
      }
      if ls_is_none_ref_type(new_type) {
        continue
      }
      let may_be_non_nullable = !cannot_be_non_nullable.contains(i)
      let mut allowed_non_nullable_case = false
      match new_type {
        RefTypeValType(rt) =>
          if rt.is_non_nullable() {
            if may_be_non_nullable {
              allowed_non_nullable_case = true
            } else {
              new_type = ValType::ref_type(rt.make_nullable())
            }
          }
        _ => ()
      }
      if !@lib.has_default(new_type) && !allowed_non_nullable_case {
        continue
      }
      if !Match::matches(new_type, old_type, env) {
        continue
      }
      if Match::matches(old_type, new_type, env) {
        continue
      }
      full_locals[i] = new_type
      changed = true
      more = true
    }
  }
  if !changed {
    return (locals, false)
  }
  let new_locals : Array[ValType] = []
  for i = param_count; i < full_locals.length(); i = i + 1 {
    new_locals.push(full_locals[i])
  }
  (new_locals, true)
}

///|
fn local_subtyping(mod : Module) -> Result[Module, String] {
  let env = Env::new().with_module(mod)
  let func_type_idx_by_func = ls_collect_func_type_idx_by_func(mod)
  let imported_funcs = ls_count_imported_funcs(mod)
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      let out_funcs = funcs.copy()
      let mut changed = false
      for i = 0; i < funcs.length(); i = i + 1 {
        let func_abs_idx = FuncIdx::new(
          imported_funcs + i.reinterpret_as_uint(),
        )
        match funcs[i] {
          TFunc(locals, body) => {
            let params = match env.get_functype_by_funcidx(func_abs_idx) {
              Some(FuncType(ps, _)) => ps
              None => []
            }
            let (new_locals, local_changed) = ls_refine_function_locals(
              params, locals, body, env, func_type_idx_by_func,
            )
            if local_changed {
              out_funcs[i] = Func::t_func(new_locals, body)
              changed = true
            }
          }
          _ => return Err("local_subtyping: expected TFunc")
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
fn run_local_subtyping(mod : Module) -> Module {
  match local_subtyping(mod) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
fn ls_single_void_type() -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type([], [])))
}

///|
fn ls_single_func_module(locals : Array[ValType], body : TExpr) -> Module {
  Module::new()
  .with_type_sec(TypeSec::new([ls_single_void_type()]))
  .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
  .with_code_sec(CodeSec::new([Func::t_func(locals, body)]))
}

///|
fn ls_non_null_func_ref_value() -> TInstr {
  TInstr::ref_as_non_null(TInstr::ref_null(HeapType::new(TypeIdx::new(0))))
}

///|
test "local subtyping basic lub refinement and module validation" {
  let mod = ls_single_func_module(
    [ValType::funcref()],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::ref_null(HeapType::new(TypeIdx::new(0))),
      ),
      TInstr::local_set(LocalIdx::new(0), ls_non_null_func_ref_value()),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let out = run_local_subtyping(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([vt], _)])) =>
      assert_eq(
        vt,
        ValType::ref_type(RefType::new(true, HeapType::new(TypeIdx::new(0)))),
      )
    _ => fail("expected one transformed function")
  }
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("refined module should validate: \{e}")
  }
}

///|
test "local subtyping allows non-nullable refinement when safely dominated" {
  let mod = ls_single_func_module(
    [ValType::funcref()],
    TExpr::new([
      TInstr::local_set(LocalIdx::new(0), ls_non_null_func_ref_value()),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let out = run_local_subtyping(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([RefTypeValType(rt)], _)])) =>
      assert_false(rt.is_nullable())
    _ => fail("expected refined ref local")
  }
}

///|
test "local subtyping rejects non-nullable refinement when default can be observed" {
  let mod = ls_single_func_module(
    [ValType::funcref()],
    TExpr::new([
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      TInstr::local_set(LocalIdx::new(0), ls_non_null_func_ref_value()),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let out = run_local_subtyping(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([RefTypeValType(rt)], _)])) =>
      assert_true(rt.is_nullable())
    _ => fail("expected transformed function")
  }
}

///|
test "local subtyping rejects non-nullable refinement when dominance fails across if" {
  let mod = ls_single_func_module(
    [ValType::funcref()],
    TExpr::new([
      TInstr::if_(
        BlockType::void_(),
        TInstr::i32_const(I32(0)),
        TExpr::new([
          TInstr::local_set(LocalIdx::new(0), ls_non_null_func_ref_value()),
        ]),
        None,
      ),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let out = run_local_subtyping(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([RefTypeValType(rt)], _)])) =>
      assert_true(rt.is_nullable())
    _ => fail("expected transformed function")
  }
}

///|
test "local subtyping defaultability guard keeps incompatible non-defaultable type unchanged" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let mod = ls_single_func_module(
    [non_null_funcref],
    TExpr::new([
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      TInstr::local_set(LocalIdx::new(0), ls_non_null_func_ref_value()),
    ]),
  )
  let out = run_local_subtyping(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([vt], _)])) => assert_eq(vt, non_null_funcref)
    _ => fail("expected transformed function")
  }
}

///|
test "local subtyping includes local tee assignments in refinement" {
  let mod = ls_single_func_module(
    [ValType::anyref()],
    TExpr::new([
      TInstr::drop(
        TInstr::local_tee(LocalIdx::new(0), ls_non_null_func_ref_value()),
      ),
    ]),
  )
  let out = run_local_subtyping(mod)
  match out.code_sec {
    Some(
      CodeSec([TFunc([RefTypeValType(rt)], TExpr([TDrop(TLocalTee(_, _))]))])
    ) => assert_false(rt.is_nullable())
    _ => fail("expected tee-driven refinement")
  }
}

///|
test "local subtyping iterates to convergence across local-get dependency chain" {
  let mod = ls_single_func_module(
    [ValType::anyref(), ValType::anyref(), ValType::anyref()],
    TExpr::new([
      TInstr::local_set(LocalIdx::new(0), ls_non_null_func_ref_value()),
      TInstr::local_set(LocalIdx::new(1), TInstr::local_get(LocalIdx::new(0))),
      TInstr::local_set(LocalIdx::new(2), TInstr::local_get(LocalIdx::new(1))),
      TInstr::drop(TInstr::local_get(LocalIdx::new(2))),
    ]),
  )
  let out = run_local_subtyping(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([vt0, vt1, vt2], _)])) =>
      match (vt0, vt1, vt2) {
        (RefTypeValType(r0), RefTypeValType(r1), RefTypeValType(r2)) => {
          assert_false(r0.is_nullable())
          assert_false(r1.is_nullable())
          assert_false(r2.is_nullable())
        }
        _ => fail("expected three refined ref locals")
      }
    _ => fail("expected transformed function")
  }
}

///|
test "local subtyping ignores non-ref locals" {
  let mod = ls_single_func_module(
    [ValType::i32()],
    TExpr::new([
      TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(7))),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let out = run_local_subtyping(mod)
  assert_eq(out, mod)
}

///|
test "local subtyping ignores locals without sets" {
  let mod = ls_single_func_module(
    [ValType::anyref()],
    TExpr::new([TInstr::drop(TInstr::local_get(LocalIdx::new(0)))]),
  )
  let out = run_local_subtyping(mod)
  match out.code_sec {
    Some(CodeSec([TFunc([vt], _)])) => assert_eq(vt, ValType::anyref())
    _ => fail("expected one function")
  }
}
