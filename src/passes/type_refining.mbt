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
fn tr_make_func_type(
  params : Array[ValType],
  results : Array[ValType],
) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn tr_extract_comp_type(sub_type : SubType) -> CompType {
  match sub_type {
    SubType(_, _, comp) => comp
    CompTypeSubType(comp) => comp
  }
}

///|
fn tr_resolve_func_type(
  comp_types : Array[CompType],
  idx : TypeIdx,
) -> FuncType? {
  let i = match idx {
    TypeIdx(n) => n
    RecIdx(n) => n
  }
  let j = i.reinterpret_as_int()
  if j < 0 || j >= comp_types.length() {
    return None
  }
  match comp_types[j] {
    FuncCompType(params, results) => Some(FuncType::new(params, results))
    _ => None
  }
}

///|
fn tr_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(_) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn tr_collect_func_types(mod : Module) -> Array[FuncType] {
  let comp_types : Array[CompType] = []
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) =>
            comp_types.push(tr_extract_comp_type(sub_type))
          GroupRecType(sub_types) =>
            for sub_type in sub_types {
              comp_types.push(tr_extract_comp_type(sub_type))
            }
        }
      }
    None => ()
  }
  let func_types : Array[FuncType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(type_idx) =>
            match tr_resolve_func_type(comp_types, type_idx) {
              Some(ft) => func_types.push(ft)
              None => func_types.push(FuncType::new([], []))
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        match tr_resolve_func_type(comp_types, type_idx) {
          Some(ft) => func_types.push(ft)
          None => func_types.push(FuncType::new([], []))
        }
      }
    None => ()
  }
  func_types
}

///|
fn tr_flattened_type_count(rec_types : Array[RecType]) -> Int {
  let mut n = 0
  for rec_type in rec_types {
    match rec_type {
      SingleRecType(_) => n += 1
      GroupRecType(sub_types) => n += sub_types.length()
    }
  }
  n
}

///|
fn tr_mark_exports_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        let Export(_, extern_idx) = export_
        match extern_idx {
          FuncExternIdx(FuncIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < has_unseen.length() {
              has_unseen[idx] = true
            }
          }
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn tr_mark_start_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
  match mod.start_sec {
    Some(StartSec(FuncIdx(raw))) => {
      let idx = raw.reinterpret_as_int()
      if idx >= 0 && idx < has_unseen.length() {
        has_unseen[idx] = true
      }
    }
    None => ()
  }
}

///|
fn tr_mark_elem_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(_, kind) = elem
        match kind {
          FuncsElemKind(funcs) =>
            for func_idx in funcs {
              let FuncIdx(raw) = func_idx
              let idx = raw.reinterpret_as_int()
              if idx >= 0 && idx < has_unseen.length() {
                has_unseen[idx] = true
              }
            }
          FuncExprsElemKind(exprs) | TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              for instr in expr.0 {
                match instr {
                  RefFunc(FuncIdx(raw)) => {
                    let idx = raw.reinterpret_as_int()
                    if idx >= 0 && idx < has_unseen.length() {
                      has_unseen[idx] = true
                    }
                  }
                  _ => ()
                }
              }
            }
        }
      }
    None => ()
  }
}

///|
priv struct TRCallSite {
  caller_abs_idx : Int
  args : Array[TInstr]
}

///|
fn tr_callsite(caller_abs_idx : Int, args : Array[TInstr]) -> TRCallSite {
  { caller_abs_idx, args }
}

///|
fn tr_record_call(
  caller_abs_idx : Int,
  target : FuncIdx,
  args : Array[TInstr],
  calls_by_target : Array[Array[TRCallSite]],
) -> Unit {
  let FuncIdx(raw) = target
  let idx = raw.reinterpret_as_int()
  if idx < 0 || idx >= calls_by_target.length() {
    return
  }
  calls_by_target[idx].push(tr_callsite(caller_abs_idx, args.copy()))
}

///|
fn tr_analyze_function_body(
  abs_func_idx : Int,
  body : TExpr,
  calls_by_target : Array[Array[TRCallSite]],
  has_unseen_calls : Array[Bool],
) -> Unit {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TCall(target, args) =>
        tr_record_call(abs_func_idx, target, args, calls_by_target)
      TRefFunc(FuncIdx(raw)) => {
        let idx = raw.reinterpret_as_int()
        if idx >= 0 && idx < has_unseen_calls.length() {
          has_unseen_calls[idx] = true
        }
      }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
}

///|
fn tr_collect_global_types(mod : Module) -> Array[ValType] {
  let out : Array[ValType] = []
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(GlobalType(vt, _), _) = global
        out.push(vt)
      }
    None => ()
  }
  out
}

///|
fn tr_build_local_types_by_abs(
  func_types : Array[FuncType],
  funcs : Array[Func],
  import_func_count : Int,
) -> Array[Array[ValType]] {
  let out : Array[Array[ValType]] = []
  for abs_idx = 0; abs_idx < func_types.length(); abs_idx = abs_idx + 1 {
    let FuncType(params, _) = func_types[abs_idx]
    let locals = params.copy()
    let def_idx = abs_idx - import_func_count
    if def_idx >= 0 && def_idx < funcs.length() {
      match funcs[def_idx] {
        TFunc(extra_locals, _) =>
          for vt in extra_locals {
            locals.push(vt)
          }
        _ => ()
      }
    }
    out.push(locals)
  }
  out
}

///|
fn tr_known_instr_type(
  instr : TInstr,
  caller_abs_idx : Int,
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  env : Env,
) -> ValType? {
  match instr {
    TI32Const(_) => Some(ValType::i32())
    TI64Const(_) => Some(ValType::i64())
    TF32Const(_) => Some(ValType::f32())
    TF64Const(_) => Some(ValType::f64())
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      Some(ValType::v128())
    TRefNull(ht) => Some(ValType::ref_type(RefType::new(true, ht)))
    TRefFunc(_) =>
      Some(
        ValType::ref_type(
          RefType::new(false, HeapType::abs(AbsHeapType::func())),
        ),
      )
    TLocalGet(LocalIdx(raw)) => {
      let idx = raw.reinterpret_as_int()
      if caller_abs_idx < 0 || caller_abs_idx >= local_types_by_abs.length() {
        return None
      }
      let locals = local_types_by_abs[caller_abs_idx]
      if idx < 0 || idx >= locals.length() {
        return None
      }
      Some(locals[idx])
    }
    TGlobalGet(GlobalIdx(raw)) => {
      let idx = raw.reinterpret_as_int()
      if idx < 0 || idx >= global_types.length() {
        return None
      }
      Some(global_types[idx])
    }
    TRefAsNonNull(value) =>
      match
        tr_known_instr_type(
          value, caller_abs_idx, local_types_by_abs, global_types, env,
        ) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    TRefCast(nullable, ht, _) =>
      Some(ValType::ref_type(RefType::new(nullable, ht)))
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
    _ => None
  }
}

///|
fn tr_common_supertype(a : ValType, b : ValType, env : Env) -> ValType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  None
}

///|
fn tr_refine_param_types(
  old_params : Array[ValType],
  calls : Array[TRCallSite],
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  env : Env,
) -> Array[ValType] {
  let new_params = old_params.copy()
  if calls.is_empty() {
    return new_params
  }
  for p = 0; p < old_params.length(); p = p + 1 {
    let old_param = old_params[p]
    match old_param {
      RefTypeValType(_) => ()
      _ => continue
    }
    let mut candidate : ValType? = None
    let mut can_refine = true
    for callsite in calls {
      let args = callsite.args
      if p >= args.length() {
        can_refine = false
        break
      }
      let arg = args[p]
      match
        tr_known_instr_type(
          arg,
          callsite.caller_abs_idx,
          local_types_by_abs,
          global_types,
          env,
        ) {
        Some(arg_ty) => {
          if not(Match::matches(arg_ty, old_param, env)) {
            can_refine = false
            break
          }
          candidate = match candidate {
            None => Some(arg_ty)
            Some(prev) => tr_common_supertype(prev, arg_ty, env)
          }
          if candidate is None {
            can_refine = false
            break
          }
        }
        None => {
          can_refine = false
          break
        }
      }
    }
    if not(can_refine) {
      continue
    }
    match candidate {
      Some(new_ty) if new_ty != old_param &&
        Match::matches(new_ty, old_param, env) => new_params[p] = new_ty
      _ => ()
    }
  }
  new_params
}

///|
fn tr_local_idx_to_int(idx : LocalIdx) -> Int {
  let LocalIdx(raw) = idx
  raw.reinterpret_as_int()
}

///|
fn tr_local_idx_from_int(i : Int) -> LocalIdx {
  LocalIdx::new(i.reinterpret_as_uint())
}

///|
fn tr_update_param_types(
  body : TExpr,
  old_param_types : Array[ValType],
  new_param_types : Array[ValType],
  locals : Array[ValType],
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  env : Env,
  abs_idx : Int,
) -> (Array[ValType], TExpr) {
  let param_fixups : Map[Int, Int] = Map::new()
  let next_local = [old_param_types.length() + locals.length()]

  let scan_sets = ModuleTransformer::new().on_tinstruction_evt(fn(
    self,
    _,
    instr,
  ) {
    match instr {
      TLocalSet(idx, value) | TLocalTee(idx, value) => {
        let local_i = tr_local_idx_to_int(idx)
        if local_i >= 0 &&
          local_i < old_param_types.length() &&
          !param_fixups.contains(local_i) {
          let compatible = match
            tr_known_instr_type(
              value, abs_idx, local_types_by_abs, global_types, env,
            ) {
            Some(vt) => Match::matches(vt, new_param_types[local_i], env)
            None => false
          }
          if !compatible {
            let fixup = next_local[0]
            next_local[0] = fixup + 1
            param_fixups[local_i] = fixup
          }
        }
      }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(scan_sets.walk_texpr((), body))

  let next_locals = locals.copy()
  let param_count = old_param_types.length()
  for i = 0; i < param_count; i = i + 1 {
    match param_fixups.get(i) {
      Some(_) => next_locals.push(old_param_types[i])
      None => ()
    }
  }

  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let walked = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, out))) => out
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    match walked {
      TLocalGet(idx) => {
        let local_i = tr_local_idx_to_int(idx)
        match param_fixups.get(local_i) {
          Some(fixup) =>
            change((), TInstr::local_get(tr_local_idx_from_int(fixup)))
          None => if walked == instr { unchanged() } else { change((), walked) }
        }
      }
      TLocalSet(idx, value) => {
        let local_i = tr_local_idx_to_int(idx)
        match param_fixups.get(local_i) {
          Some(fixup) =>
            change((), TInstr::local_set(tr_local_idx_from_int(fixup), value))
          None => if walked == instr { unchanged() } else { change((), walked) }
        }
      }
      TLocalTee(idx, value) => {
        let local_i = tr_local_idx_to_int(idx)
        match param_fixups.get(local_i) {
          Some(fixup) =>
            change((), TInstr::local_tee(tr_local_idx_from_int(fixup), value))
          None => if walked == instr { unchanged() } else { change((), walked) }
        }
      }
      _ => if walked == instr { unchanged() } else { change((), walked) }
    }
  })

  let rewritten = match walker.walk_texpr((), body) {
    Ok(Some((_, out))) => out
    _ => body
  }

  if param_fixups.is_empty() {
    return (next_locals, rewritten)
  }

  let prologue : Array[TInstr] = []
  for i = 0; i < param_count; i = i + 1 {
    match param_fixups.get(i) {
      Some(fixup) =>
        prologue.push(
          TInstr::local_set(
            tr_local_idx_from_int(fixup),
            TInstr::local_get(tr_local_idx_from_int(i)),
          ),
        )
      None => ()
    }
  }

  let next_body = TExpr::new([..prologue, ..rewritten.instrs])
  (next_locals, next_body)
}

///|
fn type_refining(mod : Module) -> Result[Module, String] {
  let funcs = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs
    None => return Ok(mod)
  }
  let func_sec = match mod.func_sec {
    Some(FuncSec(type_idxs)) => type_idxs
    None => return Ok(mod)
  }
  let func_types = tr_collect_func_types(mod)
  let total_func_count = func_types.length()
  if funcs.is_empty() || total_func_count == 0 {
    return Ok(mod)
  }

  let import_func_count = tr_count_imported_funcs(mod)
  let calls_by_target : Array[Array[TRCallSite]] = []
  for _ in 0..<total_func_count {
    calls_by_target.push([])
  }

  let has_unseen_calls : Array[Bool] = Array::make(total_func_count, false)
  tr_mark_exports_unseen(mod, has_unseen_calls)
  tr_mark_start_unseen(mod, has_unseen_calls)
  tr_mark_elem_unseen(mod, has_unseen_calls)

  for i = 0; i < funcs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    match funcs[i] {
      TFunc(_, body) =>
        tr_analyze_function_body(
          abs_idx, body, calls_by_target, has_unseen_calls,
        )
      _ => ()
    }
  }

  let env = Env::new().with_module(mod)
  let global_types = tr_collect_global_types(mod)
  let local_types_by_abs = tr_build_local_types_by_abs(
    func_types, funcs, import_func_count,
  )

  let refined_params_by_defined : Array[Array[ValType]?] = Array::make(
    funcs.length(),
    None,
  )

  for i = 0; i < funcs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    if abs_idx < 0 || abs_idx >= total_func_count || has_unseen_calls[abs_idx] {
      continue
    }
    let FuncType(params, _) = func_types[abs_idx]
    let refined = tr_refine_param_types(
      params,
      calls_by_target[abs_idx],
      local_types_by_abs,
      global_types,
      env,
    )
    if refined != params {
      refined_params_by_defined[i] = Some(refined)
    }
  }

  let mut has_change = false
  let type_recs = match mod.type_sec {
    Some(TypeSec(rs)) => rs.copy()
    None => []
  }
  let next_func_sec = func_sec.copy()
  let mut flat_type_count = tr_flattened_type_count(type_recs)

  for i = 0; i < funcs.length() && i < next_func_sec.length(); i = i + 1 {
    match refined_params_by_defined[i] {
      Some(new_params) => {
        let abs_idx = import_func_count + i
        if abs_idx < 0 || abs_idx >= func_types.length() {
          continue
        }
        let FuncType(_, old_results) = func_types[abs_idx]
        type_recs.push(tr_make_func_type(new_params, old_results))
        next_func_sec[i] = TypeIdx::new(flat_type_count.reinterpret_as_uint())
        flat_type_count += 1
        has_change = true
      }
      None => ()
    }
  }

  if !has_change {
    return Ok(mod)
  }

  let next_funcs = funcs.copy()
  for i = 0; i < funcs.length(); i = i + 1 {
    match (funcs[i], refined_params_by_defined[i]) {
      (TFunc(locals, body), Some(new_params)) => {
        let abs_idx = import_func_count + i
        if abs_idx < 0 || abs_idx >= func_types.length() {
          continue
        }
        let FuncType(old_params, _) = func_types[abs_idx]
        let (next_locals, next_body) = tr_update_param_types(
          body, old_params, new_params, locals, local_types_by_abs, global_types,
          env, abs_idx,
        )
        next_funcs[i] = Func::t_func(next_locals, next_body)
      }
      _ => ()
    }
  }

  Ok(
    mod
    .with_type_sec(TypeSec::new(type_recs))
    .with_func_sec(FuncSec::new(next_func_sec))
    .with_code_sec(CodeSec::new(next_funcs)),
  )
}

///|
fn run_type_refining(mod : Module) -> Module {
  match type_refining(mod) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
test "type refining refines parameter reference types" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::return_([])]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        tr_make_func_type([non_null_funcref], []),
        tr_make_func_type([nullable_funcref], []),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let out = run_type_refining(mod)
  let func_types = tr_collect_func_types(out)
  let FuncType(params, _) = func_types[1]
  assert_eq(params[0], non_null_funcref)
}

///|
test "type refining inserts param fixup local for incompatible param.set" {
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
      ),
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        tr_make_func_type([non_null_funcref], []),
        tr_make_func_type([nullable_funcref], []),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let out = run_type_refining(mod)
  match out.code_sec {
    Some(CodeSec([_, TFunc(locals, { instrs, .. })])) => {
      assert_eq(locals.length(), 1)
      assert_eq(locals[0], nullable_funcref)
      assert_eq(
        instrs[0],
        TInstr::local_set(LocalIdx::new(1), TInstr::local_get(LocalIdx::new(0))),
      )
      assert_eq(
        instrs[1],
        TInstr::local_set(
          LocalIdx::new(1),
          TInstr::ref_null(HeapType::abs(AbsHeapType::func())),
        ),
      )
    }
    _ => fail("expected rewritten callee with fixup local")
  }
  assert_eq(@validate.validate_module(out), Ok(()))
}
